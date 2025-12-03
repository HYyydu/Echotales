import SwiftUI
import FirebaseAuth
import AuthenticationServices

struct SignInView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    @State private var showSignUp = false
    @State private var showForgotPassword = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Avatar and Welcome Section
                    VStack(spacing: 12) {
                        Image("LoginIcon")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                            .padding(.top, 40)
                        
                        Text("Welcome")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Color(hex: "1F2937"))
                    }
                    .padding(.bottom, 20)
                    
                    // Email and Password Fields
                    VStack(spacing: 16) {
                        // Email Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hex: "374151"))
                            
                            TextField("Enter your email", text: $email)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                                .autocorrectionDisabled()
                                .padding()
                                .background(Color.white)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
                                )
                        }
                        
                        // Password Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hex: "374151"))
                            
                            HStack {
                                if showPassword {
                                    TextField("Enter your password", text: $password)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                } else {
                                    SecureField("Enter your password", text: $password)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                }
                                
                                Button(action: { showPassword.toggle() }) {
                                    Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                        .foregroundColor(Color(hex: "9CA3AF"))
                                }
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
                            )
                        }
                        
                        // Forgot Password
                        HStack {
                            Spacer()
                            Button(action: { showForgotPassword = true }) {
                                Text("Forgot Password?")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color(hex: "EF7461"))
                            }
                        }
                    }
                    
                    // Error Message
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    // Sign In Button
                    Button(action: signIn) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Sign In")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(hex: "1F2937"))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(hex: "F5B5A8"))
                    .cornerRadius(12)
                    .disabled(isLoading)
                    
                    // Sign Up Link
                    HStack(spacing: 4) {
                        Text("Don't have an account?")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "6B7280"))
                        
                        Button(action: { showSignUp = true }) {
                            Text("Sign Up")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(hex: "EF7461"))
                        }
                    }
                    
                    // Divider
                    HStack {
                        Rectangle()
                            .fill(Color(hex: "E5E7EB"))
                            .frame(height: 1)
                        Text("OR")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "9CA3AF"))
                            .padding(.horizontal, 12)
                        Rectangle()
                            .fill(Color(hex: "E5E7EB"))
                            .frame(height: 1)
                    }
                    .padding(.vertical, 8)
                    
                    // Social Login Buttons
                    VStack(spacing: 12) {
                        // Google Sign In
                        Button(action: signInWithGoogle) {
                            HStack(spacing: 8) {
                                Image(systemName: "g.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.red)
                                Text("Continue with Google")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Color(hex: "1F2937"))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.white)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
                            )
                        }
                        .disabled(isLoading)
                        
                        // Apple Sign In - Custom Button
                        Button(action: signInWithApple) {
                            HStack(spacing: 8) {
                                Image(systemName: "apple.logo")
                                    .font(.system(size: 20))
                                    .foregroundColor(.black)
                                Text("Sign in with Apple")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Color(hex: "1F2937"))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.white)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
                            )
                        }
                        .disabled(isLoading)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .background(Color(hex: "FFF5F5"))
            .navigationBarHidden(true)
            .sheet(isPresented: $showSignUp) {
                SignUpView()
                    .environmentObject(authManager)
            }
            .sheet(isPresented: $showForgotPassword) {
                ForgotPasswordView()
            }
        }
    }
    
    // MARK: - Sign In Methods
    
    private func signIn() {
        errorMessage = ""
        
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter both email and password"
            return
        }
        
        guard isValidEmail(email) else {
            errorMessage = "Please enter a valid email address"
            return
        }
        
        isLoading = true
        
        Task {
            do {
                try await authManager.signIn(email: email, password: password)
                await MainActor.run {
                    isLoading = false
                    // Clear form on success
                    email = ""
                    password = ""
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
    
    private func signInWithGoogle() {
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                try await authManager.signInWithGoogle()
                await MainActor.run {
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Google sign-in failed: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
    
    private func signInWithApple() {
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                try await authManager.signInWithApple()
                await MainActor.run {
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    // Don't show error if user cancelled
                    if let authError = error as? ASAuthorizationError,
                       authError.code == .canceled {
                        isLoading = false
                        return
                    }
                    errorMessage = "Apple sign-in failed: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
}

#Preview {
    SignInView()
        .environmentObject(AuthenticationManager())
}

