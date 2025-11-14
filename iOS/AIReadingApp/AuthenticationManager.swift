import Foundation
import FirebaseAuth
import FirebaseFirestore

class AuthenticationManager: ObservableObject {
    @Published var user: User?
    @Published var isAuthenticated = false
    @Published var userEmail: String = ""
    
    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    
    init() {
        // Check if user is already signed in
        self.user = auth.currentUser
        self.isAuthenticated = user != nil
        self.userEmail = user?.email ?? ""
        
        // Listen for auth state changes
        auth.addStateDidChangeListener { [weak self] _, user in
            self?.user = user
            self?.isAuthenticated = user != nil
            self?.userEmail = user?.email ?? ""
        }
    }
    
    // MARK: - Sign In
    func signIn(email: String, password: String) async throws {
        do {
            let result = try await auth.signIn(withEmail: email, password: password)
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
        // Note: This requires Google Sign-In SDK to be properly configured
        // For now, throw a not implemented error
        throw AuthError.signInFailed("Google Sign-In not yet implemented. Please use email/password authentication.")
    }
    
    // MARK: - Sign In with Apple
    func signInWithApple() async throws {
        // Note: This requires Apple Sign-In to be properly configured
        // For now, throw a not implemented error
        throw AuthError.signInFailed("Apple Sign-In not yet implemented. Please use email/password authentication.")
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
            try await db.collection("users").document(result.user.uid).setData([
                "email": email,
                "displayName": name,
                "createdAt": Timestamp(date: Date()),
                "memberSince": Date().formatted(.dateTime.year())
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
            user = nil
            isAuthenticated = false
            userEmail = ""
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

