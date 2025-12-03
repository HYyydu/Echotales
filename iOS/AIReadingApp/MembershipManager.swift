import Foundation
import FirebaseFirestore
import FirebaseAuth
import StoreKit

// MARK: - Membership Types
enum MembershipType: String, Codable {
    case free = "free" // 30 minutes per month, resets monthly
    case freeTrial = "free_trial" // 30 minutes for one month (one-time offer)
    case premium = "premium" // $9.99 unlimited for one month
}

// MARK: - Membership Status
struct MembershipStatus: Codable {
    var type: MembershipType
    var startDate: Date
    var endDate: Date?
    var usedTimeInSeconds: TimeInterval // For usage tracking
    var monthlyUsageResetDate: Date? // When to reset monthly usage for free users
    var isActive: Bool
    
    var remainingTimeInSeconds: TimeInterval {
        guard let endDate = endDate else { return 0 }
        let now = Date()
        if now > endDate {
            return 0
        }
        return endDate.timeIntervalSince(now)
    }
    
    var hasExpired: Bool {
        guard let endDate = endDate else { return false }
        return Date() > endDate
    }
    
    var isUnlimited: Bool {
        return type == .premium
    }
    
    var needsMonthlyReset: Bool {
        guard type == .free, let resetDate = monthlyUsageResetDate else {
            return false
        }
        return Date() > resetDate
    }
    
    var canUseFeature: Bool {
        // Premium users have unlimited access
        if type == .premium && isActive && !hasExpired {
            return true
        }
        
        // Free trial users: check if active, not expired, and under 30 minutes
        if type == .freeTrial && isActive && !hasExpired {
            return usedTimeInSeconds < 1800 // 30 minutes
        }
        
        // Free users: always active, check monthly limit
        if type == .free {
            return usedTimeInSeconds < 1800 // 30 minutes per month
        }
        
        return false
    }
    
    var remainingFreeMinutes: Int {
        let remainingSeconds = max(0, 1800 - usedTimeInSeconds)
        return Int(remainingSeconds / 60)
    }
    
    var usedMinutes: Int {
        return Int(usedTimeInSeconds / 60)
    }
}

// MARK: - Membership Manager
@MainActor
class MembershipManager: ObservableObject {
    @Published var membershipStatus: MembershipStatus?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    private var products: [Product] = []
    
    // Product ID for the premium subscription
    // Note: This needs to be configured in App Store Connect
    private let premiumProductID = "com.aireadingapp.premium_monthly"
    
    init() {
        Task {
            await loadMembershipStatus()
            await checkAndResetMonthlyUsage() // Check if reset needed on app start
            await loadProducts()
        }
    }
    
    // MARK: - Load Membership Status
    func loadMembershipStatus() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("⚠️ No user logged in - cannot load membership")
            return
        }
        
        isLoading = true
        
        do {
            let docRef = db.collection("users").document(userId).collection("membership").document("status")
            let document = try await docRef.getDocument()
            
            if let data = document.data(),
               let typeString = data["type"] as? String,
               let type = MembershipType(rawValue: typeString),
               let startTimestamp = data["startDate"] as? Timestamp {
                
                let startDate = startTimestamp.dateValue()
                let endDate = (data["endDate"] as? Timestamp)?.dateValue()
                let usedTime = data["usedTimeInSeconds"] as? TimeInterval ?? 0
                let isActive = data["isActive"] as? Bool ?? false
                let monthlyResetDate = (data["monthlyUsageResetDate"] as? Timestamp)?.dateValue()
                
                membershipStatus = MembershipStatus(
                    type: type,
                    startDate: startDate,
                    endDate: endDate,
                    usedTimeInSeconds: usedTime,
                    monthlyUsageResetDate: monthlyResetDate,
                    isActive: isActive
                )
                
                // Check if monthly reset is needed for free users
                if membershipStatus?.needsMonthlyReset == true {
                    await checkAndResetMonthlyUsage()
                }
                
                // Check if expired and update (for premium/trial)
                if membershipStatus?.hasExpired == true {
                    await deactivateMembership()
                }
            } else {
                // No membership found, initialize free plan with monthly reset
                let resetDate = Calendar.current.date(byAdding: .month, value: 1, to: Date())!
                membershipStatus = MembershipStatus(
                    type: .free,
                    startDate: Date(),
                    endDate: nil,
                    usedTimeInSeconds: 0,
                    monthlyUsageResetDate: resetDate,
                    isActive: true // Free users are always active
                )
                
                // Save the initial free membership status
                do {
                    try await saveMembershipStatus(status: membershipStatus!, userId: userId)
                } catch {
                    print("⚠️ Failed to save initial free membership: \(error.localizedDescription)")
                }
            }
        } catch {
            print("❌ Error loading membership status: \(error.localizedDescription)")
            errorMessage = "Failed to load membership status"
        }
        
        isLoading = false
    }
    
    // MARK: - Start Free Trial
    func startFreeTrial() async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw MembershipError.noUserSignedIn
        }
        
        // Check if user already had a free trial
        let hasUsedTrial = await checkIfTrialUsed(userId: userId)
        if hasUsedTrial {
            throw MembershipError.trialAlreadyUsed
        }
        
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .month, value: 1, to: startDate)!
        
        let status = MembershipStatus(
            type: .freeTrial,
            startDate: startDate,
            endDate: endDate,
            usedTimeInSeconds: 0,
            monthlyUsageResetDate: nil, // One-time trial doesn't reset
            isActive: true
        )
        
        try await saveMembershipStatus(status: status, userId: userId)
        
        // Mark that user has used trial
        try await db.collection("users").document(userId).updateData([
            "hasUsedFreeTrial": true
        ])
        
        membershipStatus = status
    }
    
    // MARK: - Purchase Premium
    func purchasePremium() async throws {
        guard let product = products.first(where: { $0.id == premiumProductID }) else {
            throw MembershipError.productNotFound
        }
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                
                // Update membership status
                let startDate = Date()
                let endDate = Calendar.current.date(byAdding: .month, value: 1, to: startDate)!
                
                guard let userId = Auth.auth().currentUser?.uid else {
                    throw MembershipError.noUserSignedIn
                }
                
                let status = MembershipStatus(
                    type: .premium,
                    startDate: startDate,
                    endDate: endDate,
                    usedTimeInSeconds: 0,
                    monthlyUsageResetDate: nil, // Premium doesn't track usage
                    isActive: true
                )
                
                try await saveMembershipStatus(status: status, userId: userId)
                membershipStatus = status
                
                // Finish the transaction
                await transaction.finish()
                
            case .userCancelled:
                throw MembershipError.purchaseCancelled
            case .pending:
                throw MembershipError.purchasePending
            @unknown default:
                throw MembershipError.unknownError
            }
        } catch {
            if error is MembershipError {
                throw error
            }
            throw MembershipError.purchaseFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Check and Reset Monthly Usage
    func checkAndResetMonthlyUsage() async {
        guard var status = membershipStatus else { return }
        
        // Only reset for free users
        guard status.type == .free, status.needsMonthlyReset else {
            return
        }
        
        print("📅 Resetting monthly usage for free user")
        
        // Reset usage and update reset date
        status.usedTimeInSeconds = 0
        status.monthlyUsageResetDate = Calendar.current.date(byAdding: .month, value: 1, to: Date())
        
        guard let userId = Auth.auth().currentUser?.uid else {
            return
        }
        
        do {
            try await saveMembershipStatus(status: status, userId: userId)
            membershipStatus = status
            print("✅ Monthly usage reset successfully")
        } catch {
            print("❌ Error resetting monthly usage: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Track Usage Time
    func trackUsageTime(seconds: TimeInterval) async {
        guard var status = membershipStatus else { return }
        
        // Check if monthly reset is needed for free users
        if status.type == .free && status.needsMonthlyReset {
            await checkAndResetMonthlyUsage()
            // Reload status after reset
            guard let updatedStatus = membershipStatus else { return }
            status = updatedStatus
        }
        
        // Track time for free and freeTrial users only (premium is unlimited)
        guard status.type == .free || status.type == .freeTrial else {
            return
        }
        
        // For free trial, must be active and not expired
        if status.type == .freeTrial {
            guard status.isActive && !status.hasExpired else {
                return
            }
        }
        
        // Add usage time
        status.usedTimeInSeconds += seconds
        
        guard let userId = Auth.auth().currentUser?.uid else {
            return
        }
        
        do {
            try await saveMembershipStatus(status: status, userId: userId)
            membershipStatus = status
            print("⏱️ Tracked \(Int(seconds))s of usage. Total: \(Int(status.usedTimeInSeconds))s / 1800s")
        } catch {
            print("❌ Error tracking usage time: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Check If Feature Can Be Used
    func canUseFeature() -> Bool {
        return membershipStatus?.canUseFeature ?? false
    }
    
    // MARK: - Get Remaining Time
    func getRemainingTimeInSeconds() -> TimeInterval {
        guard let status = membershipStatus else { return 0 }
        
        if status.isUnlimited {
            return Double.infinity
        }
        
        if status.type == .freeTrial {
            // Return the minimum of remaining trial time and remaining usage time
            let remainingUsage = 1800 - status.usedTimeInSeconds // 30 minutes = 1800 seconds
            let remainingTrial = status.remainingTimeInSeconds
            return min(remainingUsage, remainingTrial)
        }
        
        return 0
    }
    
    // MARK: - Helper Methods
    private func checkIfTrialUsed(userId: String) async -> Bool {
        do {
            let doc = try await db.collection("users").document(userId).getDocument()
            return doc.data()?["hasUsedFreeTrial"] as? Bool ?? false
        } catch {
            return false
        }
    }
    
    private func saveMembershipStatus(status: MembershipStatus, userId: String) async throws {
        let docRef = db.collection("users").document(userId).collection("membership").document("status")
        
        var data: [String: Any] = [
            "type": status.type.rawValue,
            "startDate": Timestamp(date: status.startDate),
            "usedTimeInSeconds": status.usedTimeInSeconds,
            "isActive": status.isActive
        ]
        
        if let endDate = status.endDate {
            data["endDate"] = Timestamp(date: endDate)
        }
        
        if let resetDate = status.monthlyUsageResetDate {
            data["monthlyUsageResetDate"] = Timestamp(date: resetDate)
        }
        
        try await docRef.setData(data)
    }
    
    private func deactivateMembership() async {
        guard var status = membershipStatus,
              let userId = Auth.auth().currentUser?.uid else {
            return
        }
        
        print("📅 Membership expired, converting to free plan")
        
        // Convert to free plan with monthly limit
        status.isActive = true  // Free users are always active
        status.type = .free
        status.usedTimeInSeconds = 0  // Reset usage
        status.endDate = nil
        status.monthlyUsageResetDate = Calendar.current.date(byAdding: .month, value: 1, to: Date())
        
        do {
            try await saveMembershipStatus(status: status, userId: userId)
            membershipStatus = status
            print("✅ Converted to free plan with 30 min/month limit")
        } catch {
            print("❌ Error deactivating membership: \(error.localizedDescription)")
        }
    }
    
    private func loadProducts() async {
        do {
            let productIDs = [premiumProductID]
            products = try await Product.products(for: productIDs)
        } catch {
            print("❌ Error loading products: \(error.localizedDescription)")
        }
    }
    
    func getPremiumProduct() -> Product? {
        return products.first(where: { $0.id == premiumProductID })
    }
    
    // MARK: - StoreKit Helpers
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw MembershipError.purchaseVerificationFailed
        case .verified(let safe):
            return safe
        }
    }
}

// MARK: - Membership Errors
enum MembershipError: LocalizedError {
    case noUserSignedIn
    case trialAlreadyUsed
    case productNotFound
    case purchaseCancelled
    case purchasePending
    case purchaseFailed(String)
    case purchaseVerificationFailed
    case unknownError
    
    var errorDescription: String? {
        switch self {
        case .noUserSignedIn:
            return "Please sign in to continue"
        case .trialAlreadyUsed:
            return "You have already used your free trial"
        case .productNotFound:
            return "Premium subscription not available"
        case .purchaseCancelled:
            return "Purchase was cancelled"
        case .purchasePending:
            return "Purchase is pending approval"
        case .purchaseFailed(let message):
            return "Purchase failed: \(message)"
        case .purchaseVerificationFailed:
            return "Purchase verification failed"
        case .unknownError:
            return "An unknown error occurred"
        }
    }
}

