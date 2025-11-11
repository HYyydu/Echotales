import SwiftUI
import LocalAuthentication
import FirebaseAuth
import FirebaseFirestore

extension Color {
    static let ps_textPrimary = Color(hex: "0F172A")
    static let ps_textSecondary = Color(hex: "475569")
    static let ps_textTertiary = Color(hex: "6B7280")
    static let ps_borderColor = Color(hex: "E5E7EB")
    static let ps_bgGray = Color(hex: "F9FAFB")
    static let ps_accentBlue = Color(hex: "3B82F6")
    static let ps_accentPurple = Color(hex: "8B5CF6")
    static let ps_green = Color(hex: "10B981")
    static let ps_orange = Color(hex: "F59E0B")
    static let ps_red = Color(hex: "EF4444")
    static let ps_gray = Color(hex: "6B7280")
}

struct PrivacySecurityView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthenticationManager
    @AppStorage("security.biometric") private var useBiometric = false
    @State private var showChangePassword = false
    @State private var showDeleteAccount = false
    @State private var biometricType: LABiometryType = .none
    @State private var showBiometricError = false
    @State private var isExportingData = false
    @State private var showExportSuccess = false
    @State private var exportErrorMessage: String?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    accountSection
                    Rectangle()
                        .fill(Color.ps_borderColor)
                        .frame(height: 8)
                    securitySection
                    Rectangle()
                        .fill(Color.ps_borderColor)
                        .frame(height: 8)
                    privacySection
                    Rectangle()
                        .fill(Color.ps_borderColor)
                        .frame(height: 8)
                    dangerZoneSection
                    Color.clear
                        .frame(height: 24)
                }
            }
            .background(Color.ps_bgGray)
            .navigationTitle("Privacy & Security")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 17, weight: .semibold))
                            Text("Back")
                                .font(.system(size: 17))
                        }
                        .foregroundColor(Color.ps_accentBlue)
                    }
                }
            }
            .sheet(isPresented: $showChangePassword) {
                ChangePasswordView()
            }
            .alert("Delete Account", isPresented: $showDeleteAccount) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteAccount()
                }
            } message: {
                Text("Are you sure you want to permanently delete your account? This action cannot be undone and all your data will be lost.")
            }
            .alert("Biometric Authentication Unavailable", isPresented: $showBiometricError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Biometric authentication is not available on this device or not set up.")
            }
            .alert("Data Export Complete", isPresented: $showExportSuccess) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your data has been exported successfully. Check your Files app in the 'AI Reading App' folder.")
            }
            .alert("Export Error", isPresented: .constant(exportErrorMessage != nil), presenting: exportErrorMessage) { _ in
                Button("OK") {
                    exportErrorMessage = nil
                }
            } message: { error in
                Text(error)
            }
        }
        .onAppear {
            checkBiometricAvailability()
        }
    }
    
    @ViewBuilder
    private var accountSection: some View {
        VStack(spacing: 0) {
            // Section Header
            Text("ACCOUNT")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color.ps_textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.ps_bgGray)
            
            // Current Email Display
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.ps_accentBlue.opacity(0.12))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: "envelope.circle.fill")
                        .font(.system(size: 26))
                        .foregroundColor(Color.ps_accentBlue)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Email Address")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.ps_textPrimary)
                    
                    Text(Auth.auth().currentUser?.email ?? "Not available")
                        .font(.system(size: 13))
                        .foregroundColor(Color.ps_textSecondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            
            Divider()
                .padding(.leading, 84)
            
            // Change Password
            SettingActionRow(
                icon: "key.circle.fill",
                iconColor: Color.ps_green,
                title: "Change Password",
                subtitle: "Update your password",
                action: {
                    showChangePassword = true
                }
            )
        }
        .background(Color.white)
    }
    
    @ViewBuilder
    private var securitySection: some View {
        VStack(spacing: 0) {
            // Section Header
            Text("SECURITY")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color.ps_textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.ps_bgGray)
            
            // Biometric Authentication
            if biometricType != .none {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.ps_accentPurple.opacity(0.12))
                            .frame(width: 56, height: 56)
                        
                        Image(systemName: biometricType == .faceID ? "faceid" : "touchid")
                            .font(.system(size: 26))
                            .foregroundColor(Color.ps_accentPurple)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(biometricType == .faceID ? "Face ID" : "Touch ID")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color.ps_textPrimary)
                        
                        Text("Use \(biometricType == .faceID ? "Face ID" : "Touch ID") to unlock")
                            .font(.system(size: 13))
                            .foregroundColor(Color.ps_textSecondary)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $useBiometric)
                        .labelsHidden()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                
                Divider()
                    .padding(.leading, 84)
            }
            
            // Connected Devices (Placeholder)
            SettingActionRow(
                icon: "iphone.circle.fill",
                iconColor: Color.ps_orange,
                title: "Connected Devices",
                subtitle: "Manage devices with access",
                action: {
                    // Navigate to connected devices
                }
            )
        }
        .background(Color.white)
    }
    
    @ViewBuilder
    private var privacySection: some View {
        VStack(spacing: 0) {
            // Section Header
            Text("PRIVACY")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color.ps_textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.ps_bgGray)
            
            // Download Your Data
            DataExportButton(
                isExporting: isExportingData,
                onTap: exportUserData
            )
            
            Divider()
                .padding(.leading, 84)
            
            // Privacy Policy
            SettingActionRow(
                icon: "doc.text.circle.fill",
                iconColor: Color.ps_gray,
                title: "Privacy Policy",
                subtitle: "Learn how we protect your data",
                action: {
                    if let url = URL(string: "https://yourapp.com/privacy") {
                        UIApplication.shared.open(url)
                    }
                }
            )
            
            Divider()
                .padding(.leading, 84)
            
            // Terms of Service
            SettingActionRow(
                icon: "checkmark.shield.circle.fill",
                iconColor: Color.ps_green,
                title: "Terms of Service",
                subtitle: "Read our terms and conditions",
                action: {
                    if let url = URL(string: "https://yourapp.com/terms") {
                        UIApplication.shared.open(url)
                    }
                }
            )
        }
        .background(Color.white)
    }
    
    @ViewBuilder
    private var dangerZoneSection: some View {
        VStack(spacing: 0) {
            // Section Header
            Text("DANGER ZONE")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color.ps_red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.ps_bgGray)
            
            // Delete Account
            Button(action: {
                showDeleteAccount = true
            }) {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.ps_red.opacity(0.12))
                            .frame(width: 56, height: 56)
                        
                        Image(systemName: "trash.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(Color.ps_red)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Delete Account")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color.ps_red)
                        
                        Text("Permanently delete your account and data")
                            .font(.system(size: 13))
                            .foregroundColor(Color.ps_textSecondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color.ps_gray)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .background(Color.white)
    }
    
    private func checkBiometricAvailability() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            biometricType = context.biometryType
        }
    }
    
    private func deleteAccount() {
        Task {
            do {
                try await Auth.auth().currentUser?.delete()
                try authManager.signOut()
            } catch {
                print("❌ Error deleting account: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - GDPR Data Export
    private func exportUserData() {
        guard let userId = Auth.auth().currentUser?.uid else {
            exportErrorMessage = "No user logged in"
            return
        }
        
        guard let userEmail = Auth.auth().currentUser?.email else {
            exportErrorMessage = "Could not retrieve user email"
            return
        }
        
        isExportingData = true
        
        Task {
            do {
                print("📦 Starting GDPR data export for user: \(userId)")
                
                let db = Firestore.firestore()
                var exportData: [String: Any] = [:]
                
                exportData["user_profile"] = [
                    "user_id": userId,
                    "email": userEmail,
                    "display_name": Auth.auth().currentUser?.displayName ?? "Not set",
                    "account_created": Auth.auth().currentUser?.metadata.creationDate?.ISO8601Format() ?? "Unknown",
                    "last_sign_in": Auth.auth().currentUser?.metadata.lastSignInDate?.ISO8601Format() ?? "Unknown",
                    "export_date": Date().ISO8601Format()
                ]
                
                let recordingsSnapshot = try await db.collection("voiceRecordings")
                    .whereField("userId", isEqualTo: userId)
                    .getDocuments()
                
                let recordings = recordingsSnapshot.documents.map { doc -> [String: Any] in
                    var data = doc.data()
                    data["document_id"] = doc.documentID
                    return data
                }
                exportData["voice_recordings"] = recordings
                print("   ✅ Exported \(recordings.count) voice recordings")
                
                let shelfSnapshot = try await db.collection("userShelfBooks")
                    .whereField("userId", isEqualTo: userId)
                    .getDocuments()
                
                let shelfBooks = shelfSnapshot.documents.map { doc -> [String: Any] in
                    var data = doc.data()
                    data["document_id"] = doc.documentID
                    if let timestamp = data["addedAt"] as? Timestamp {
                        data["addedAt"] = timestamp.dateValue().ISO8601Format()
                    }
                    return data
                }
                exportData["shelf_books"] = shelfBooks
                print("   ✅ Exported \(shelfBooks.count) shelf books")
                
                let historySnapshot = try await db.collection("readingHistory")
                    .whereField("userId", isEqualTo: userId)
                    .getDocuments()
                
                let history = historySnapshot.documents.map { doc -> [String: Any] in
                    var data = doc.data()
                    data["document_id"] = doc.documentID
                    if let timestamp = data["clickedAt"] as? Timestamp {
                        data["clickedAt"] = timestamp.dateValue().ISO8601Format()
                    }
                    return data
                }
                exportData["reading_history"] = history
                print("   ✅ Exported \(history.count) reading history entries")
                
                let statsDoc = try? await db.collection("userStats").document(userId).getDocument()
                if let statsData = statsDoc?.data() {
                    var stats = statsData
                    if let timestamp = stats["lastUpdated"] as? Timestamp {
                        stats["lastUpdated"] = timestamp.dateValue().ISO8601Format()
                    }
                    exportData["user_statistics"] = stats
                    print("   ✅ Exported user statistics")
                }
                
                exportData["gdpr_info"] = [
                    "export_format": "JSON",
                    "export_date": Date().ISO8601Format(),
                    "data_controller": "AI Reading App",
                    "purpose": "GDPR Article 15 - Right of Access",
                    "note": "This export contains all personal data we have stored about you."
                ]
                
                let jsonData = try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
                
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let exportFolder = documentsPath.appendingPathComponent("AI Reading App Exports", isDirectory: true)
                try FileManager.default.createDirectory(at: exportFolder, withIntermediateDirectories: true)
                
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
                let timestamp = dateFormatter.string(from: Date())
                let fileName = "user_data_export_\(timestamp).json"
                let fileURL = exportFolder.appendingPathComponent(fileName)
                
                try jsonData.write(to: fileURL)
                
                print("✅ Data export completed successfully")
                print("   📁 File saved to: \(fileURL.path)")
                
                await MainActor.run {
                    isExportingData = false
                    showExportSuccess = true
                }
                
                await MainActor.run {
                    shareFile(url: fileURL)
                }
                
            } catch {
                print("❌ Data export failed: \(error.localizedDescription)")
                await MainActor.run {
                    isExportingData = false
                    exportErrorMessage = "Failed to export data: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func shareFile(url: URL) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

// MARK: - Setting Action Row Component
struct SettingActionRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.12))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: icon)
                        .font(.system(size: 26))
                        .foregroundColor(iconColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.ps_textPrimary)
                
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(Color.ps_textTertiary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color.ps_gray)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Data Export Button Component
struct DataExportButton: View {
    let isExporting: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            buttonContent
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isExporting)
    }
    
    private var buttonContent: some View {
        HStack(spacing: 16) {
            iconSection
            textSection
            Spacer()
            trailingIcon
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
    }
    
    private var iconSection: some View {
        ZStack {
            Circle()
                .fill(Color.ps_accentBlue.opacity(0.12))
                .frame(width: 56, height: 56)
            
            Group {
                if isExporting {
                    ProgressView()
                        .tint(Color.ps_accentBlue)
                } else {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 26))
                        .foregroundColor(Color.ps_accentBlue)
                }
            }
        }
    }
    
    private var textSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Download Your Data")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.ps_textPrimary)
            
            Text(isExporting ? "Exporting your data..." : "Get a copy of your information")
                .font(.system(size: 13))
                .foregroundColor(Color.ps_textTertiary)
        }
    }
    
    @ViewBuilder
    private var trailingIcon: some View {
        if !isExporting {
            Image(systemName: "chevron.right")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color.ps_gray)
        }
    }
}

// MARK: - Change Password View
struct ChangePasswordView: View {
    @Environment(\.dismiss) var dismiss
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    SecureField("Current Password", text: $currentPassword)
                    SecureField("New Password", text: $newPassword)
                    SecureField("Confirm New Password", text: $confirmPassword)
                } header: {
                    Text("Change Password")
                } footer: {
                    Text("Password must be at least 8 characters long")
                }
                
                Section {
                    Button(action: changePassword) {
                        HStack {
                            Spacer()
                            if isLoading {
                                ProgressView()
                            } else {
                                Text("Update Password")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(isLoading || currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty)
                }
            }
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func changePassword() {
        guard newPassword == confirmPassword else {
            errorMessage = "New passwords don't match"
            showError = true
            return
        }
        
        guard newPassword.count >= 8 else {
            errorMessage = "Password must be at least 8 characters long"
            showError = true
            return
        }
        
        isLoading = true
        
        guard let user = Auth.auth().currentUser,
              let email = user.email else {
            errorMessage = "Unable to authenticate user"
            showError = true
            isLoading = false
            return
        }
        
        let credential = EmailAuthProvider.credential(withEmail: email, password: currentPassword)
        
        user.reauthenticate(with: credential) { _, error in
            if let error = error {
                errorMessage = error.localizedDescription
                showError = true
                isLoading = false
                return
            }
            
            user.updatePassword(to: newPassword) { error in
                isLoading = false
                if let error = error {
                    errorMessage = error.localizedDescription
                    showError = true
                } else {
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    PrivacySecurityView()
        .environmentObject(AuthenticationManager())
}
