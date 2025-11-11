import SwiftUI
import FirebaseAuth

struct ForgotPasswordView: View {
    @Environment(\.dismiss) var dismiss
    @State private var email = ""
    @State private var errorMessage = ""
    @State private var successMessage = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Icon and Header
                    VStack(spacing: 12) {
                        Image(systemName: "lock.rotation")
                            .font(.system(size: 60))
                            .foregroundColor(Color(hex: "F5B5A8"))
                            .padding(.top, 40)
                        
                        Text("Forgot Password?")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Color(hex: "1F2937"))
                        
                        Text("Enter your email address and we'll send you a link to reset your password")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "6B7280"))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.bottom, 20)
                    
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
                    
                    // Success Message
                    if !successMessage.isEmpty {
                        Text(successMessage)
                            .font(.system(size: 14))
                            .foregroundColor(.green)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
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
                    
                    // Reset Password Button
                    Button(action: resetPassword) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Send Reset Link")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(hex: "1F2937"))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(hex: "F5B5A8"))
                    .cornerRadius(12)
                    .disabled(isLoading)
                    
                    // Back to Sign In
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.left")
                            Text("Back to Sign In")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "EF7461"))
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
    
    // MARK: - Reset Password Method
    
    private func resetPassword() {
        errorMessage = ""
        successMessage = ""
        
        guard !email.isEmpty else {
            errorMessage = "Please enter your email address"
            return
        }
        
        guard isValidEmail(email) else {
            errorMessage = "Please enter a valid email address"
            return
        }
        
        isLoading = true
        
        Task {
            do {
                try await Auth.auth().sendPasswordReset(withEmail: email)
                await MainActor.run {
                    successMessage = "Password reset link has been sent to your email"
                    isLoading = false
                    email = ""
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
    ForgotPasswordView()
}

