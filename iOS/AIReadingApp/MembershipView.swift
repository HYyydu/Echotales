import SwiftUI
import StoreKit

struct MembershipView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var membershipManager = MembershipManager()
    @State private var selectedPlan: PlanType = .freeTrial
    @State private var isProcessing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    
    // Design tokens
    private let primaryPink = Color(hex: "F9DAD2")
    private let secondaryPink = Color(hex: "F5B5A8")
    private let textPrimary = Color(hex: "0F172A")
    private let textSecondary = Color(hex: "475569")
    private let textTertiary = Color(hex: "6B7280")
    private let accentGold = Color(hex: "F59E0B")
    private let accentBlue = Color(hex: "3B82F6")
    
    enum PlanType {
        case freeTrial
        case premium
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Plans Section
                    VStack(spacing: 20) {
                        // Free Trial Plan
                        PlanCard(
                            title: "Free Trial",
                            subtitle: "30 minutes for one month",
                            price: "FREE",
                            period: "1 month",
                            features: [
                                "30 minutes of listening time",
                                "Full access to all features",
                                "No credit card required",
                                "Cancel anytime"
                            ],
                            isSelected: selectedPlan == .freeTrial,
                            isPremium: false,
                            onSelect: {
                                selectedPlan = .freeTrial
                            }
                        )
                        
                        // Premium Plan
                        PlanCard(
                            title: "Premium",
                            subtitle: "Unlimited access",
                            price: membershipManager.getPremiumProduct()?.displayPrice ?? "$9.99",
                            period: "per month",
                            features: [
                                "Unlimited listening time",
                                "All premium features",
                                "Priority support",
                                "Cancel anytime"
                            ],
                            isSelected: selectedPlan == .premium,
                            isPremium: true,
                            onSelect: {
                                selectedPlan = .premium
                            }
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                    .background(Color(hex: "F9FAFB"))
                    
                    // Continue Button
                    Button(action: {
                        Task {
                            await handlePlanSelection()
                        }
                    }) {
                        HStack {
                            if isProcessing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Text("Continue")
                                    .font(.system(size: 18, weight: .semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            selectedPlan == .premium
                                ? LinearGradient(
                                    gradient: Gradient(colors: [accentGold, Color(hex: "F97316")]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                : LinearGradient(
                                    gradient: Gradient(colors: [accentBlue, Color(hex: "2563EB")]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(16)
                    }
                    .disabled(isProcessing)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                    .background(Color.white)
                    
                    // Terms
                    VStack(spacing: 8) {
                        Text("By continuing, you agree to our Terms of Service and Privacy Policy")
                            .font(.system(size: 12))
                            .foregroundColor(textTertiary)
                            .multilineTextAlignment(.center)
                        
                        Text("Subscriptions will auto-renew unless cancelled at least 24 hours before the end of the current period")
                            .font(.system(size: 11))
                            .foregroundColor(textTertiary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                    .background(Color.white)
                }
            }
            .background(Color(hex: "F9FAFB"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(textPrimary)
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .alert("Success", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text(selectedPlan == .freeTrial
                     ? "Free trial activated! You now have 30 minutes of listening time for one month."
                     : "Premium membership activated! Enjoy unlimited access.")
            }
            .task {
                await membershipManager.loadMembershipStatus()
            }
        }
    }
    
    private func handlePlanSelection() async {
        isProcessing = true
        
        do {
            switch selectedPlan {
            case .freeTrial:
                try await membershipManager.startFreeTrial()
                showSuccess = true
                
            case .premium:
                try await membershipManager.purchasePremium()
                showSuccess = true
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        
        isProcessing = false
    }
}

// MARK: - Plan Card Component
struct PlanCard: View {
    let title: String
    let subtitle: String
    let price: String
    let period: String
    let features: [String]
    let isSelected: Bool
    let isPremium: Bool
    let onSelect: () -> Void
    
    private let accentGold = Color(hex: "F59E0B")
    private let accentBlue = Color(hex: "3B82F6")
    private let textPrimary = Color(hex: "0F172A")
    private let textSecondary = Color(hex: "475569")
    private let borderColor = Color(hex: "E5E7EB")
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(title)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(textPrimary)
                            
                            if isPremium {
                                Text("POPULAR")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(accentGold)
                                    .cornerRadius(4)
                            }
                        }
                        
                        Text(subtitle)
                            .font(.system(size: 14))
                            .foregroundColor(textSecondary)
                    }
                    
                    Spacer()
                    
                    // Price
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(price)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(isPremium ? accentGold : accentBlue)
                        
                        Text(period)
                            .font(.system(size: 12))
                            .foregroundColor(textSecondary)
                    }
                }
                .padding(20)
                
                Divider()
                    .padding(.horizontal, 20)
                
                // Features
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(features, id: \.self) { feature in
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(isPremium ? accentGold : accentBlue)
                            
                            Text(feature)
                                .font(.system(size: 14))
                                .foregroundColor(textPrimary)
                            
                            Spacer()
                        }
                    }
                }
                .padding(20)
            }
            .background(Color.white)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected
                            ? (isPremium ? accentGold : accentBlue)
                            : borderColor,
                        lineWidth: isSelected ? 3 : 1
                    )
            )
            .shadow(
                color: isSelected
                    ? (isPremium ? accentGold.opacity(0.3) : accentBlue.opacity(0.3))
                    : Color.black.opacity(0.05),
                radius: isSelected ? 12 : 4,
                x: 0,
                y: isSelected ? 4 : 2
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    MembershipView()
}

