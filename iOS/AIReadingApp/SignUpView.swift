import SwiftUI
import FirebaseAuth

struct SignUpView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Avatar and Header
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "F5B5A8"))
                                .frame(width: 100, height: 100)
                            
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 80, height: 80)
                                .foregroundColor(.white)
                        }
                        .padding(.top, 40)
                        
                        Text("Create Account")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Color(hex: "1F2937"))
                        
                        Text("Sign up to start your reading journey")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "6B7280"))
                    }
                    .padding(.bottom, 20)
                    
                    // Form Fields
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
                            
                            // Password requirements
                            Text("At least 6 characters")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "9CA3AF"))
                        }
                        
                        // Confirm Password Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Confirm Password")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hex: "374151"))
                            
                            HStack {
                                if showConfirmPassword {
                                    TextField("Confirm your password", text: $confirmPassword)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                } else {
                                    SecureField("Confirm your password", text: $confirmPassword)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                }
                                
                                Button(action: { showConfirmPassword.toggle() }) {
                                    Image(systemName: showConfirmPassword ? "eye.slash.fill" : "eye.fill")
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
                    
                    // Sign Up Button
                    Button(action: signUp) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Sign Up")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(hex: "1F2937"))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(hex: "F5B5A8"))
                    .cornerRadius(12)
                    .disabled(isLoading)
                    
                    // Sign In Link
                    HStack(spacing: 4) {
                        Text("Already have an account?")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "6B7280"))
                        
                        Button(action: { dismiss() }) {
                            Text("Sign In")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(hex: "EF7461"))
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .background(Color(hex: "FFF5F5"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(Color(hex: "6B7280"))
                    }
                }
            }
        }
    }
    
    // MARK: - Sign Up Method
    
    private func signUp() {
        errorMessage = ""
        
        // Validation
        guard !email.isEmpty, !password.isEmpty, !confirmPassword.isEmpty else {
            errorMessage = "Please fill in all fields"
            return
        }
        
        guard isValidEmail(email) else {
            errorMessage = "Please enter a valid email address"
            return
        }
        
        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters"
            return
        }
        
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match"
            return
        }
        
        isLoading = true
        
        Task {
            do {
                try await authManager.signUp(email: email, password: password)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
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
    SignUpView()
        .environmentObject(AuthenticationManager())
}

