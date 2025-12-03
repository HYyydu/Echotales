import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseCore
import AuthenticationServices
import CryptoKit
import GoogleSignIn

class AuthenticationManager: ObservableObject {
    @Published var user: User?
    @Published var isAuthenticated = false
    @Published var userEmail: String = ""
    
    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    
    // Store the current raw nonce for Sign in with Apple
    private var currentNonce: String?
    
    // Store the delegate to keep it alive during authorization flow
    private var currentAppleSignInDelegate: AppleSignInDelegate?
    
    init() {
        // Check if user is already signed in
        self.user = auth.currentUser
        self.isAuthenticated = user != nil
        self.userEmail = user?.email ?? ""
        
        // Listen for auth state changes
        _ = auth.addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.user = user
                self?.isAuthenticated = user != nil
                self?.userEmail = user?.email ?? ""
            }
        }
    }
    
    // MARK: - Nonce helpers for Sign in with Apple
    // Generate and store a new raw nonce (to be called before starting Apple sign-in)
    func prepareNewAppleSignInNonce() -> String {
        let nonce = AuthenticationManager.randomNonceString()
        self.currentNonce = nonce
        return nonce
    }
    
    // Provide SHA256 of a string (used to set request.nonce)
    static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    // Random nonce generator
    // From Firebase docs: https://firebase.google.com/docs/auth/ios/apple
    static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] =
            Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            let errorCode = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            if errorCode != errSecSuccess {
                fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
            }

            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }

                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }
    
    // MARK: - Sign In
    func signIn(email: String, password: String) async throws {
        do {
            let result = try await auth.signIn(withEmail: email, password: password)
            
            // Ensure user document exists in Firestore
            let userRef = db.collection("users").document(result.user.uid)
            let userDoc = try? await userRef.getDocument()
            
            if userDoc?.exists == false {
                // Create user document if it doesn't exist
                let memberSince = Date().formatted(.dateTime.year())
                try await userRef.setData([
                    "email": result.user.email ?? email,
                    "displayName": result.user.displayName ?? "Reader",
                    "createdAt": Timestamp(date: Date()),
                    "memberSince": memberSince
                ])
            }
            
            await MainActor.run {
                self.user = result.user
                self.isAuthenticated = true
                self.userEmail = result.user.email ?? ""
            }
        } catch {
            throw AuthError.signInFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Sign In with Google
    func signInWithGoogle() async throws {
        // Get the CLIENT_ID from GoogleService-Info.plist
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthError.signInFailed("Failed to get Google Client ID from Firebase configuration")
        }
        
        // Configure Google Sign-In
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        // Get the presenting view controller
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            throw AuthError.signInFailed("Unable to get root view controller")
        }
        
        // Start Google Sign-In flow
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
        let user = result.user
        
        // Get the ID token and access token
        guard let idToken = user.idToken?.tokenString else {
            throw AuthError.signInFailed("Failed to get ID token from Google")
        }
        
        let accessToken = user.accessToken.tokenString
        
        // Create Firebase credential with Google tokens
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
        
        // Sign in to Firebase with the Google credential
        let authResult = try await auth.signIn(with: credential)
        
        // Get user info
        let email = authResult.user.email ?? user.profile?.email ?? ""
        let displayName = authResult.user.displayName ?? user.profile?.name ?? "Google User"
        
        // Create or update user document in Firestore
        let userRef = db.collection("users").document(authResult.user.uid)
        let userDoc = try? await userRef.getDocument()
        
        if userDoc?.exists == false {
            // Create new user document
            let memberSince = Date().formatted(.dateTime.year())
            try await userRef.setData([
                "email": email,
                "displayName": displayName,
                "createdAt": Timestamp(date: Date()),
                "memberSince": memberSince
            ])
        } else if let existingData = userDoc?.data() {
            // Update display name if it's not set or empty
            if existingData["displayName"] == nil || (existingData["displayName"] as? String)?.isEmpty == true {
                try await userRef.updateData([
                    "displayName": displayName
                ])
            }
        }
        
        // Update auth state
        await MainActor.run {
            self.user = authResult.user
            self.isAuthenticated = true
            self.userEmail = email
        }
    }
    
    // MARK: - Sign In with Apple
    func signInWithApple() async throws {
        // Generate a nonce for this sign-in request
        let nonce = prepareNewAppleSignInNonce()
        let hashedNonce = AuthenticationManager.sha256(nonce)
        
        // Create the Apple Sign-In request
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = hashedNonce
        
        // Use a continuation to bridge delegate-based API to async/await
        let authorization = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ASAuthorization, Error>) in
            let controller = ASAuthorizationController(authorizationRequests: [request])
            let delegate = AppleSignInDelegate(continuation: continuation)
            
            // Store delegate to keep it alive during the authorization flow
            self.currentAppleSignInDelegate = delegate
            
            controller.delegate = delegate
            controller.presentationContextProvider = delegate
            controller.performRequests()
        }
        
        // Process the authorization result
        try await handleAppleSignInAuthorization(authorization)
    }
    
    // Helper to handle the authorization after receiving it
    private func handleAppleSignInAuthorization(_ authorization: ASAuthorization) async throws {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityToken = appleIDCredential.identityToken,
              let idTokenString = String(data: identityToken, encoding: .utf8) else {
            throw AuthError.signInFailed("Failed to get Apple ID token")
        }
        
        // Ensure we have a raw nonce that was generated and set on the request
        guard let rawNonce = currentNonce else {
            throw AuthError.signInFailed("Invalid state: Missing login nonce. Please try again.")
        }
        
        // Create Firebase credential for Apple Sign-In
        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: rawNonce,
            fullName: appleIDCredential.fullName
        )
        
        // Sign in with Firebase
        let authResult = try await auth.signIn(with: credential)
        
        // Get user info
        let email: String = {
            if let email = appleIDCredential.email {
                return email
            } else if let email = authResult.user.email {
                return email
            } else {
                return ""
            }
        }()
        let displayName = appleIDCredential.fullName
        
        // Update display name if available
        let nameFormatter = PersonNameComponentsFormatter()
        if let fullName = displayName {
            let changeRequest = authResult.user.createProfileChangeRequest()
            let formattedName = nameFormatter.string(from: fullName)
            if !formattedName.isEmpty {
                changeRequest.displayName = formattedName
                try? await changeRequest.commitChanges()
            }
        }
        
        // Create or update user document in Firestore
        let userRef = db.collection("users").document(authResult.user.uid)
        let userDoc = try? await userRef.getDocument()
        
        if userDoc?.exists == false {
            // Create new user document
            let formattedDisplayName: String = {
                if let displayName = displayName {
                    return nameFormatter.string(from: displayName)
                } else {
                    return "Apple User"
                }
            }()
            let memberSince = Date().formatted(.dateTime.year())
            try await userRef.setData([
                "email": email,
                "displayName": formattedDisplayName,
                "createdAt": Timestamp(date: Date()),
                "memberSince": memberSince
            ])
        } else if let fullName = displayName, let existingData = userDoc?.data() {
            // Update display name if it's not set
            if existingData["displayName"] == nil || (existingData["displayName"] as? String)?.isEmpty == true {
                let formattedName = nameFormatter.string(from: fullName)
                try await userRef.updateData([
                    "displayName": formattedName
                ])
            }
        }
        
        await MainActor.run {
            self.user = authResult.user
            self.isAuthenticated = true
            self.userEmail = email
            // Clear nonce after successful use
            self.currentNonce = nil
            self.currentAppleSignInDelegate = nil
        }
    }
    
    // MARK: - Sign Up
    func signUp(email: String, password: String, name: String) async throws {
        do {
            let result = try await auth.createUser(withEmail: email, password: password)
            
            // Update display name
            let changeRequest = result.user.createProfileChangeRequest()
            changeRequest.displayName = name
            try await changeRequest.commitChanges()
            
            // Create user document in Firestore
            let memberSince = Date().formatted(.dateTime.year())
            try await db.collection("users").document(result.user.uid).setData([
                "email": email,
                "displayName": name,
                "createdAt": Timestamp(date: Date()),
                "memberSince": memberSince
            ])
            
            await MainActor.run {
                self.user = result.user
                self.isAuthenticated = true
                self.userEmail = result.user.email ?? ""
            }
        } catch {
            throw AuthError.signUpFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Sign Out
    func signOut() throws {
        do {
            try auth.signOut()
            // Update state immediately on main thread
            // Note: The auth state listener will also update these, but we set them
            // immediately to ensure UI updates right away
            DispatchQueue.main.async { [weak self] in
                self?.user = nil
                self?.isAuthenticated = false
                self?.userEmail = ""
                self?.currentNonce = nil
                self?.currentAppleSignInDelegate = nil
            }
        } catch {
            throw AuthError.signOutFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Password Reset
    func sendPasswordReset(email: String) async throws {
        do {
            try await auth.sendPasswordReset(withEmail: email)
        } catch {
            throw AuthError.passwordResetFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Delete Account
    func deleteAccount() async throws {
        guard let user = user else {
            throw AuthError.noUserSignedIn
        }
        
        do {
            // Delete user document from Firestore
            try await db.collection("users").document(user.uid).delete()
            
            // Delete Firebase Auth user
            try await user.delete()
            
            await MainActor.run {
                self.user = nil
                self.isAuthenticated = false
                self.userEmail = ""
                self.currentNonce = nil
                self.currentAppleSignInDelegate = nil
            }
        } catch {
            throw AuthError.deleteAccountFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Update Password
    func updatePassword(newPassword: String) async throws {
        guard let user = user else {
            throw AuthError.noUserSignedIn
        }
        
        do {
            try await user.updatePassword(to: newPassword)
        } catch {
            throw AuthError.updatePasswordFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Get User Data
    func getUserData() async throws -> UserData? {
        guard let userId = user?.uid else {
            throw AuthError.noUserSignedIn
        }
        
        do {
            let document = try await db.collection("users").document(userId).getDocument()
            
            guard let data = document.data() else {
                return nil
            }
            
            return UserData(
                id: userId,
                email: data["email"] as? String ?? "",
                displayName: data["displayName"] as? String ?? "",
                memberSince: data["memberSince"] as? String ?? ""
            )
        } catch {
            throw AuthError.fetchUserDataFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Helper Properties
    var userId: String? {
        user?.uid
    }
    
    var displayName: String {
        user?.displayName ?? "Reader"
    }
}

// MARK: - Apple Sign-In Delegate
class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private let continuation: CheckedContinuation<ASAuthorization, Error>
    
    init(continuation: CheckedContinuation<ASAuthorization, Error>) {
        self.continuation = continuation
    }
    
    // Called when authorization completes successfully
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        continuation.resume(returning: authorization)
    }
    
    // Called when authorization fails
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation.resume(throwing: error)
    }
    
    // Provide the window for presenting the authorization UI
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return UIWindow()
        }
        return window
    }
}

// MARK: - User Data Model
struct UserData {
    let id: String
    let email: String
    let displayName: String
    let memberSince: String
}

// MARK: - Auth Errors
enum AuthError: LocalizedError {
    case signInFailed(String)
    case signUpFailed(String)
    case signOutFailed(String)
    case passwordResetFailed(String)
    case deleteAccountFailed(String)
    case updatePasswordFailed(String)
    case fetchUserDataFailed(String)
    case noUserSignedIn
    
    var errorDescription: String? {
        switch self {
        case .signInFailed(let message):
            return "Sign in failed: \(message)"
        case .signUpFailed(let message):
            return "Sign up failed: \(message)"
        case .signOutFailed(let message):
            return "Sign out failed: \(message)"
        case .passwordResetFailed(let message):
            return "Password reset failed: \(message)"
        case .deleteAccountFailed(let message):
            return "Delete account failed: \(message)"
        case .updatePasswordFailed(let message):
            return "Update password failed: \(message)"
        case .fetchUserDataFailed(let message):
            return "Failed to fetch user data: \(message)"
        case .noUserSignedIn:
            return "No user is currently signed in"
        }
    }
}
