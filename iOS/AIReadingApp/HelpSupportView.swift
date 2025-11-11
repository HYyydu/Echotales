import SwiftUI
import MessageUI

struct HelpSupportView: View {
    @Environment(\.dismiss) var dismiss
    @State private var showMailComposer = false
    @State private var showCannotSendMail = false
    @State private var selectedFAQ: FAQItem? = nil
    
    // Design tokens
    private let textPrimary = Color(hex: "0F172A")
    private let textSecondary = Color(hex: "475569")
    private let textTertiary = Color(hex: "6B7280")
    private let borderColor = Color(hex: "E5E7EB")
    private let bgGray = Color(hex: "F9FAFB")
    private let accentBlue = Color(hex: "3B82F6")
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // FAQ Section
                    VStack(spacing: 0) {
                        // Section Header
                        Text("FREQUENTLY ASKED QUESTIONS")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(textTertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(bgGray)
                        
                        ForEach(Array(faqItems.enumerated()), id: \.element.id) { index, faq in
                            FAQRow(faq: faq, isExpanded: selectedFAQ?.id == faq.id) {
                                withAnimation {
                                    if selectedFAQ?.id == faq.id {
                                        selectedFAQ = nil
                                    } else {
                                        selectedFAQ = faq
                                    }
                                }
                            }
                            
                            if index < faqItems.count - 1 {
                                Divider()
                                    .padding(.leading, 20)
                            }
                        }
                    }
                    .background(Color.white)
                    
                    // Divider
                    Rectangle()
                        .fill(borderColor)
                        .frame(height: 8)
                    
                    // Contact Section
                    VStack(spacing: 0) {
                        // Section Header
                        Text("GET IN TOUCH")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(textTertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(bgGray)
                        
                        // Contact Support
                        HelpActionRow(
                            icon: "envelope.circle.fill",
                            iconColor: accentBlue,
                            title: "Contact Support",
                            subtitle: "Get help with your account",
                            action: {
                                composeEmail(subject: "Support Request")
                            }
                        )
                        
                        Divider()
                            .padding(.leading, 84)
                        
                        // Report a Bug
                        HelpActionRow(
                            icon: "ladybug.circle.fill",
                            iconColor: Color(hex: "EF4444"),
                            title: "Report a Bug",
                            subtitle: "Let us know about issues",
                            action: {
                                composeEmail(subject: "Bug Report")
                            }
                        )
                        
                        Divider()
                            .padding(.leading, 84)
                        
                        // Feature Request
                        HelpActionRow(
                            icon: "lightbulb.circle.fill",
                            iconColor: Color(hex: "F59E0B"),
                            title: "Feature Request",
                            subtitle: "Suggest new features",
                            action: {
                                composeEmail(subject: "Feature Request")
                            }
                        )
                    }
                    .background(Color.white)
                    
                    // Divider
                    Rectangle()
                        .fill(borderColor)
                        .frame(height: 8)
                    
                    // App Section
                    VStack(spacing: 0) {
                        // Section Header
                        Text("ABOUT")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(textTertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(bgGray)
                        
                        // Rate the App
                        HelpActionRow(
                            icon: "star.circle.fill",
                            iconColor: Color(hex: "F59E0B"),
                            title: "Rate the App",
                            subtitle: "Share your experience",
                            action: {
                                // Open App Store rating
                                if let url = URL(string: "itms-apps://itunes.apple.com/app/idYOUR_APP_ID") {
                                    UIApplication.shared.open(url)
                                }
                            }
                        )
                        
                        Divider()
                            .padding(.leading, 84)
                        
                        // Share with Friends
                        HelpActionRow(
                            icon: "square.and.arrow.up.circle.fill",
                            iconColor: Color(hex: "8B5CF6"),
                            title: "Share with Friends",
                            subtitle: "Invite others to join",
                            action: {
                                shareApp()
                            }
                        )
                        
                        Divider()
                            .padding(.leading, 84)
                        
                        // App Version
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: "6B7280").opacity(0.12))
                                    .frame(width: 56, height: 56)
                                
                                Image(systemName: "info.circle.fill")
                                    .font(.system(size: 26))
                                    .foregroundColor(Color(hex: "6B7280"))
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("App Version")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(textPrimary)
                                
                                Text("Version \(appVersion()) (\(buildNumber()))")
                                    .font(.system(size: 13))
                                    .foregroundColor(textSecondary)
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 18)
                    }
                    .background(Color.white)
                    
                    // Bottom Padding
                    Color.clear
                        .frame(height: 24)
                }
            }
            .background(bgGray)
            .navigationTitle("Help & Support")
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
                        .foregroundColor(accentBlue)
                    }
                }
            }
            .sheet(isPresented: $showMailComposer) {
                MailComposeView(subject: "Support Request")
            }
            .alert("Cannot Send Email", isPresented: $showCannotSendMail) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Please configure an email account in your device settings to send email.")
            }
        }
    }
    
    private func composeEmail(subject: String) {
        if MFMailComposeViewController.canSendMail() {
            showMailComposer = true
        } else {
            showCannotSendMail = true
        }
    }
    
    private func shareApp() {
        let text = "Check out this amazing AI Reading App!"
        let url = URL(string: "https://yourapp.com")!
        let activityVC = UIActivityViewController(activityItems: [text, url], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
    
    private func appVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    private func buildNumber() -> String {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}

// MARK: - FAQ Item Model
struct FAQItem: Identifiable {
    let id = UUID()
    let question: String
    let answer: String
}

// Sample FAQ data
private let faqItems = [
    FAQItem(
        question: "How do I add books to my shelf?",
        answer: "Navigate to the Discover tab, find a book you like, and tap the 'like' button (heart icon) on the book card to add it to your bookshelf."
    ),
    FAQItem(
        question: "How does AI narration work?",
        answer: "Our AI technology converts text to natural-sounding speech. You can even clone your own voice by creating a voice profile in the 'My Recordings' section."
    ),
    FAQItem(
        question: "Can I read offline?",
        answer: "Books need to be downloaded for offline reading. Tap the download icon on any book in your shelf to save it for offline access."
    ),
    FAQItem(
        question: "How do I create a voice profile?",
        answer: "Go to the Me tab, tap 'My Recordings', then follow the prompts to record your voice samples. The AI will learn from your recordings to create your personalized voice."
    ),
    FAQItem(
        question: "What's included in Premium?",
        answer: "Premium members get unlimited voice profiles, ad-free listening, offline downloads, early access to new features, and priority support."
    )
]

// MARK: - FAQ Row Component
struct FAQRow: View {
    let faq: FAQItem
    let isExpanded: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(faq.question)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "0F172A"))
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "6B7280"))
                }
                
                if isExpanded {
                    Text(faq.answer)
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "475569"))
                        .multilineTextAlignment(.leading)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Help Action Row Component
struct HelpActionRow: View {
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
                        .foregroundColor(Color(hex: "0F172A"))
                    
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "6B7280"))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(hex: "9CA3AF"))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Mail Compose View
struct MailComposeView: UIViewControllerRepresentable {
    @Environment(\.dismiss) var dismiss
    let subject: String
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        composer.setSubject(subject)
        composer.setToRecipients(["support@yourapp.com"])
        
        // Add device and app info for better support
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        let systemVersion = UIDevice.current.systemVersion
        let deviceModel = UIDevice.current.model
        
        let messageBody = """
        
        
        ---
        App Version: \(appVersion) (\(buildNumber))
        iOS Version: \(systemVersion)
        Device: \(deviceModel)
        """
        
        composer.setMessageBody(messageBody, isHTML: false)
        return composer
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: MailComposeView
        
        init(_ parent: MailComposeView) {
            self.parent = parent
        }
        
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            parent.dismiss()
        }
    }
}

#Preview {
    HelpSupportView()
}

