import SwiftUI
import UserNotifications

struct NotificationsSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("notifications.newBooks") private var notifyNewBooks = true
    @AppStorage("notifications.readingReminders") private var notifyReadingReminders = true
    @AppStorage("notifications.weeklyProgress") private var notifyWeeklyProgress = true
    @AppStorage("notifications.recordingComplete") private var notifyRecordingComplete = true
    @State private var notificationsEnabled = false
    @State private var showSettingsAlert = false
    
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
                    // Permission Status Banner
                    if !notificationsEnabled {
                        VStack(spacing: 12) {
                            Image(systemName: "bell.slash.fill")
                                .font(.system(size: 40))
                                .foregroundColor(Color(hex: "F59E0B"))
                            
                            Text("Notifications Disabled")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(textPrimary)
                            
                            Text("Enable notifications in Settings to receive updates about your reading progress.")
                                .font(.system(size: 14))
                                .foregroundColor(textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                            
                            Button(action: {
                                showSettingsAlert = true
                            }) {
                                Text("Open Settings")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(accentBlue)
                                    .cornerRadius(10)
                            }
                        }
                        .padding(.vertical, 32)
                        .frame(maxWidth: .infinity)
                        .background(Color(hex: "FEF3C7"))
                    }
                    
                    // Reading Notifications Section
                    VStack(spacing: 0) {
                        // Section Header
                        Text("READING")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(textTertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(bgGray)
                        
                        // New Books
                        SettingToggleRow(
                            icon: "book.circle.fill",
                            iconColor: Color(hex: "10B981"),
                            title: "New Books",
                            subtitle: "Get notified when new books are added to your interests",
                            isOn: $notifyNewBooks
                        )
                        
                        Divider()
                            .padding(.leading, 84)
                        
                        // Reading Reminders
                        SettingToggleRow(
                            icon: "clock.circle.fill",
                            iconColor: accentBlue,
                            title: "Reading Reminders",
                            subtitle: "Daily reminders to keep your reading habit",
                            isOn: $notifyReadingReminders
                        )
                        
                        Divider()
                            .padding(.leading, 84)
                        
                        // Weekly Progress
                        SettingToggleRow(
                            icon: "chart.bar.circle.fill",
                            iconColor: Color(hex: "8B5CF6"),
                            title: "Weekly Progress",
                            subtitle: "Weekly summary of your reading achievements",
                            isOn: $notifyWeeklyProgress
                        )
                    }
                    .background(Color.white)
                    
                    // Divider
                    Rectangle()
                        .fill(borderColor)
                        .frame(height: 8)
                    
                    // Audio Notifications Section
                    VStack(spacing: 0) {
                        // Section Header
                        Text("AUDIO")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(textTertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(bgGray)
                        
                        // Recording Complete
                        SettingToggleRow(
                            icon: "waveform.circle.fill",
                            iconColor: Color(hex: "F5B5A8"),
                            title: "Recording Complete",
                            subtitle: "Notify when audio generation is finished",
                            isOn: $notifyRecordingComplete
                        )
                    }
                    .background(Color.white)
                    
                    // Bottom Padding
                    Color.clear
                        .frame(height: 24)
                }
            }
            .background(bgGray)
            .navigationTitle("Notifications")
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
            .alert("Enable Notifications", isPresented: $showSettingsAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            } message: {
                Text("To receive notifications, please enable them in your device settings.")
            }
        }
        .onAppear {
            checkNotificationPermission()
        }
    }
    
    private func checkNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationsEnabled = settings.authorizationStatus == .authorized
            }
        }
    }
}

// MARK: - Setting Toggle Row Component
struct SettingToggleRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 56, height: 56)
                
                Image(systemName: icon)
                    .font(.system(size: 26))
                    .foregroundColor(iconColor)
            }
            
            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "0F172A"))
                
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "6B7280"))
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Toggle
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
    }
}

#Preview {
    NotificationsSettingsView()
}

