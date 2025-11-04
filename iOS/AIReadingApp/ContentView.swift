import SwiftUI

struct ContentView: View {
    @State private var recordedVoiceId: String? = nil
    @State private var selectedTab = 2 // Record tab is active
    
    var body: some View {
        VStack(spacing: 0) {
            // Main Content
            if selectedTab == 2 {
                // Record Tab
                VoiceRecorderView(onVoiceRecorded: { voiceId in
                    recordedVoiceId = voiceId
                })
            } else if selectedTab == 0 {
                // Read Tab
                BookReaderView(voiceId: recordedVoiceId)
            } else {
                // Shelf or Me Tab
                PlaceholderTabView(tabName: selectedTab == 1 ? "Shelf" : "Me")
            }
            
            // Bottom Navigation
            BottomNavigationView(selectedTab: $selectedTab)
            
            // Home Indicator
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: "0F172A"))
                .frame(width: 128, height: 4)
                .padding(.bottom, 4)
        }
        .background(Color.white)
        .statusBar(hidden: true)
        .ignoresSafeArea(.all, edges: [.top, .bottom])
    }
}

// MARK: - Bottom Navigation (Redesigned)
struct BottomNavigationView: View {
    @Binding var selectedTab: Int
    
    private let activeBackground = Color(hex: "F9DAD2")  // Light pink background
    private let activeLabelColor = Color(hex: "F5B5A8")  // Darker pink label
    private let activeIconColor = Color(hex: "334155")    // Slate-700
    private let inactiveColor = Color(hex: "9CA3AF")      // Gray-400
    private let borderColor = Color(hex: "E5E7EB")
    
    var body: some View {
        VStack(spacing: 0) {
            // Border
            Rectangle()
                .frame(height: 1)
                .foregroundColor(borderColor)
            
            // Navigation Tabs
            HStack(spacing: 0) {
                TabButton(
                    icon: "book.fill",
                    label: "Read",
                    isActive: selectedTab == 0,
                    activeBackground: activeBackground,
                    activeLabelColor: activeLabelColor,
                    activeIconColor: activeIconColor,
                    inactiveColor: inactiveColor
                ) {
                    selectedTab = 0
                }
                
                TabButton(
                    icon: "books.vertical.fill",
                    label: "Shelf",
                    isActive: selectedTab == 1,
                    activeBackground: activeBackground,
                    activeLabelColor: activeLabelColor,
                    activeIconColor: activeIconColor,
                    inactiveColor: inactiveColor
                ) {
                    selectedTab = 1
                }
                
                TabButton(
                    icon: "mic.fill",
                    label: "Record",
                    isActive: selectedTab == 2,
                    activeBackground: activeBackground,
                    activeLabelColor: activeLabelColor,
                    activeIconColor: activeIconColor,
                    inactiveColor: inactiveColor
                ) {
                    selectedTab = 2
                }
                
                TabButton(
                    icon: "person.fill",
                    label: "Me",
                    isActive: selectedTab == 3,
                    activeBackground: activeBackground,
                    activeLabelColor: activeLabelColor,
                    activeIconColor: activeIconColor,
                    inactiveColor: inactiveColor
                ) {
                    selectedTab = 3
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
        .background(Color.white)
    }
}

struct TabButton: View {
    let icon: String
    let label: String
    let isActive: Bool
    let activeBackground: Color
    let activeLabelColor: Color
    let activeIconColor: Color
    let inactiveColor: Color
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {  // gap-1 (4px between icon and label)
                // Icon Container
                ZStack {
                    if isActive {
                        // ACTIVE STATE: 40x40px rounded background
                        RoundedRectangle(cornerRadius: 16)  // rounded-2xl
                            .fill(activeBackground)
                            .frame(width: 40, height: 40)  // w-10 h-10
                    }
                    
                    // Icon
                    Image(systemName: icon)
                        .font(.system(
                            size: isActive ? 20 : 24,  // Active: 20px (w-5), Inactive: 24px (w-6)
                            weight: isActive ? .semibold : .regular  // strokeWidth 2.5 vs default
                        ))
                        .foregroundColor(isActive ? activeIconColor : inactiveColor)
                }
                .frame(width: 40, height: 40)
                .animation(.easeInOut(duration: 0.3), value: isActive)  // transition-all duration-300
                
                // Label Text
                Text(label)
                    .font(.system(size: 12, weight: isActive ? .medium : .regular))  // text-xs
                    .foregroundColor(isActive ? activeLabelColor : inactiveColor)
                    .animation(.easeInOut(duration: 0.3), value: isActive)  // transition-all duration-300
            }
        }
        .frame(maxWidth: .infinity)
        .buttonStyle(TabButtonStyle())  // active:scale-95
    }
}

// Custom button style for scale effect
struct TabButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)  // active:scale-95
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)  // transition-transform
    }
}

// MARK: - Placeholder Tab View
struct PlaceholderTabView: View {
    let tabName: String
    
    var body: some View {
        VStack {
            Spacer()
            Text(tabName)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(Color(hex: "9CA3AF"))
            Text("Coming Soon")
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "9CA3AF"))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "F9FAFB"))
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    ContentView()
}
