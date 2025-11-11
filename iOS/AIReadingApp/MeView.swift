import SwiftUI
import FirebaseAuth

struct MeView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var statsManager = UserStatsManager()
    @State private var showRecordings = false
    @State private var showReadingHistory = false
    @State private var showNotifications = false
    @State private var showPrivacySecurity = false
    @State private var showHelpSupport = false
    @State private var userName: String = "Reader"
    @State private var memberSince: String = "2024"
    @State private var showSignOutAlert = false
    
    // Design tokens
    private let primaryPink = Color(hex: "F9DAD2")
    private let secondaryPink = Color(hex: "F5B5A8")
    private let textPrimary = Color(hex: "0F172A")
    private let textSecondary = Color(hex: "475569")
    private let textTertiary = Color(hex: "6B7280")
    private let borderColor = Color(hex: "E5E7EB")
    private let bgGray = Color(hex: "F9FAFB")
    private let accentBlue = Color(hex: "3B82F6")
    private let accentPurple = Color(hex: "8B5CF6")
    private let accentOrange = Color(hex: "F97316")
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // User Profile Header
                HStack(spacing: 16) {
                    // Avatar
                    ZStack {
                        Circle()
                            .fill(primaryPink)
                            .frame(width: 60, height: 60)
                        
                        Text(userName.prefix(1).uppercased())
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(textPrimary)
                    }
                    
                    // User Info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(userName)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(textPrimary)
                        
                    Text("Free Member • Since \(memberSince)")
                        .font(.system(size: 14))
                        .foregroundColor(textSecondary)
                }
                
                Spacer()
            }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
                .padding(.top, 60) // Clear status bar
                .background(Color.white)
                
                // Stats Cards Section
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        // Listening Time Card
                        StatCard(
                            icon: "headphones.circle.fill",
                            iconColor: accentPurple,
                            value: statsManager.stats.formattedListeningTime,
                            label: "Listening Time",
                            isLoading: statsManager.isLoading
                        )
                        
                        // Books in Shelf Card
                        StatCard(
                            icon: "books.vertical.circle.fill",
                            iconColor: Color(hex: "10B981"),
                            value: "\(statsManager.stats.booksInShelfCount)",
                            label: "Books in Shelf",
                            isLoading: statsManager.isLoading
                        )
                    }
                    
                    HStack(spacing: 12) {
                        // Recordings Card
                        StatCard(
                            icon: "waveform.circle.fill",
                            iconColor: secondaryPink,
                            value: "\(statsManager.stats.recordingsCount)",
                            label: "Voice Profiles",
                            isLoading: statsManager.isLoading
                        )
                        
                        // Days Active Card
                        StatCard(
                            icon: "calendar.circle.fill",
                            iconColor: accentOrange,
                            value: "\(statsManager.stats.daysActive)",
                            label: "Days Active",
                            isLoading: statsManager.isLoading
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
                .background(bgGray)
                
                // Divider
                Rectangle()
                    .fill(borderColor)
                    .frame(height: 8)
                
                // Main Options Section
                VStack(spacing: 0) {
                    // Section Header
                    Text("MY CONTENT")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(bgGray)
                    
                    // My Recordings
                    NavigationButton(
                        icon: "mic.circle.fill",
                        iconColor: secondaryPink,
                        title: "My Recordings",
                        subtitle: "View all your voice recordings",
                        action: {
                            showRecordings = true
                        }
                    )
                    
                    Divider()
                        .padding(.leading, 84)
                    
                    // Reading History
                    NavigationButton(
                        icon: "book.circle.fill",
                        iconColor: Color(hex: "10B981"),
                        title: "Reading History",
                        subtitle: "Books you've read",
                        action: {
                            showReadingHistory = true
                        }
                    )
                }
                .background(Color.white)
                
                // Divider
                Rectangle()
                    .fill(borderColor)
                    .frame(height: 8)
                
                // Account Section
                VStack(spacing: 0) {
                    // Section Header
                    Text("ACCOUNT")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(bgGray)
                    
                    // Become Member CTA
                    BecomeMemberButton()
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(Color.white)
                    
                    Divider()
                        .padding(.horizontal, 20)
                    
                    // Notifications
                    NavigationButton(
                        icon: "bell.circle.fill",
                        iconColor: accentBlue,
                        title: "Notifications",
                        subtitle: "Manage your preferences",
                        action: {
                            showNotifications = true
                        }
                    )
                    
                    Divider()
                        .padding(.leading, 84)
                    
                    // Privacy & Security
                    NavigationButton(
                        icon: "lock.circle.fill",
                        iconColor: textTertiary,
                        title: "Privacy & Security",
                        subtitle: "Control your data",
                        action: {
                            showPrivacySecurity = true
                        }
                    )
                    
                    Divider()
                        .padding(.leading, 84)
                    
                    // Help & Support
                    NavigationButton(
                        icon: "questionmark.circle.fill",
                        iconColor: accentPurple,
                        title: "Help & Support",
                        subtitle: "Get help and send feedback",
                        action: {
                            showHelpSupport = true
                        }
                    )
                }
                .background(Color.white)
                
                // Divider
                Rectangle()
                    .fill(borderColor)
                    .frame(height: 8)
                
                // Logout Button
                Button(action: {
                    showSignOutAlert = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(Color(hex: "EF4444"))
                        
                        Text("Log Out")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(hex: "EF4444"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.white)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Bottom Padding
                Color.clear
                    .frame(height: 24)
            }
        }
        .background(bgGray)
        .fullScreenCover(isPresented: $showRecordings) {
            MyRecordingsView()
        }
        .fullScreenCover(isPresented: $showReadingHistory) {
            ReadingHistoryView()
        }
        .fullScreenCover(isPresented: $showNotifications) {
            NotificationsSettingsView()
        }
        .fullScreenCover(isPresented: $showPrivacySecurity) {
            PrivacySecurityView()
                .environmentObject(authManager)
        }
        .fullScreenCover(isPresented: $showHelpSupport) {
            HelpSupportView()
        }
        .onAppear {
            loadUserInfo()
            // Always refresh stats when Me tab appears to catch any updates
            Task {
                print("📊 MeView appeared - refreshing stats...")
                await statsManager.fetchUserStats()
            }
        }
        .refreshable {
            await statsManager.fetchUserStats()
        }
        .alert("Sign Out", isPresented: $showSignOutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                signOut()
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }
    
    private func signOut() {
        do {
            try authManager.signOut()
        } catch {
            print("❌ Error signing out: \(error.localizedDescription)")
        }
    }
    
    private func loadUserInfo() {
        // Get user email or display name
        if let user = Auth.auth().currentUser {
            if let displayName = user.displayName, !displayName.isEmpty {
                userName = displayName
            } else if let email = user.email {
                // Use email prefix as username
                userName = String(email.split(separator: "@").first ?? "Reader")
            }
            
            // Get member since year from user creation date
            if let creationDate = user.metadata.creationDate {
                let year = Calendar.current.component(.year, from: creationDate)
                memberSince = "\(year)"
            }
        }
    }
}

// MARK: - Stat Card Component
struct StatCard: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String
    var isLoading: Bool = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 56, height: 56)
                
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(iconColor)
            }
            
            // Value and Label
            VStack(spacing: 4) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(height: 24)
                } else {
                    Text(value)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color(hex: "0F172A"))
                }
                
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "6B7280"))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Become Member Button Component
struct BecomeMemberButton: View {
    var body: some View {
        Button(action: {
            // Upgrade to premium action
        }) {
            HStack(spacing: 16) {
                // Crown Icon
                ZStack {
                    Circle()
                        .fill(Color(hex: "FEF3C7")) // Yellow background
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: "crown.fill")
                        .font(.system(size: 26))
                        .foregroundColor(Color(hex: "F59E0B")) // Amber
                }
                
                // Text Content
                VStack(alignment: .leading, spacing: 4) {
                    Text("Become a Premium Member")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "0F172A"))
                    
                    Text("Unlock unlimited features")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "6B7280"))
                }
                
                Spacer()
                
                // Arrow
                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "F59E0B"))
            }
            .padding(16)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(hex: "FEF3C7").opacity(0.3),
                        Color(hex: "FDE68A").opacity(0.2)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(hex: "FDE68A"), lineWidth: 1.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Navigation Button Component
struct NavigationButton: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
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
                }
                
                Spacer()
                
                // Chevron
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

#Preview {
    MeView()
}

