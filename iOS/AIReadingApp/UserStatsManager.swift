import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - User Stats Model
struct UserStats {
    var recordingsCount: Int = 0
    var booksInShelfCount: Int = 0
    var listeningTime: TimeInterval = 0 // In seconds
    var daysActive: Int = 0
    
    var formattedListeningTime: String {
        if listeningTime == 0 {
            return "0h 0m"
        }
        let hours = Int(listeningTime) / 3600
        let minutes = (Int(listeningTime) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
}

// MARK: - User Stats Manager
class UserStatsManager: ObservableObject {
    @Published var stats = UserStats()
    @Published var isLoading = false
    
    private let db = Firestore.firestore()
    
    // Fetch all user stats
    func fetchUserStats() async {
        await MainActor.run {
            isLoading = true
        }
        
        guard let userId = Auth.auth().currentUser?.uid else {
            print("⚠️ No user logged in - cannot fetch stats")
            await MainActor.run {
                stats = UserStats() // Empty stats for non-logged-in users
                isLoading = false
            }
            return
        }
        
        async let recordings = fetchRecordingsCount(userId: userId)
        async let shelfBooks = fetchShelfBooksCount(userId: userId)
        async let userStats = fetchUserMetadata(userId: userId)
        
        let (recordingsCount, booksCount, metadata) = await (recordings, shelfBooks, userStats)
        
        await MainActor.run {
            stats.recordingsCount = recordingsCount
            stats.booksInShelfCount = booksCount
            stats.listeningTime = metadata.listeningTime
            stats.daysActive = metadata.daysActive
            isLoading = false
            print("📊 Stats updated:")
            print("   - Listening Time: \(stats.formattedListeningTime) (\(Int(metadata.listeningTime)) seconds)")
            print("   - Days Active: \(metadata.daysActive)")
            print("   - Recordings: \(recordingsCount)")
            print("   - Books in Shelf: \(booksCount)")
        }
    }
    
    // Fetch count of voice recordings
    private func fetchRecordingsCount(userId: String) async -> Int {
        do {
            let snapshot = try await db.collection("voiceRecordings")
                .whereField("userId", isEqualTo: userId)
                .getDocuments()
            return snapshot.documents.count
        } catch {
            print("❌ Error fetching recordings count: \(error.localizedDescription)")
            return 0
        }
    }
    
    // Fetch count of books in shelf (both library books and user-imported books)
    private func fetchShelfBooksCount(userId: String) async -> Int {
        do {
            // Count books from library added to shelf
            let shelfBooksSnapshot = try await db.collection("userShelfBooks")
                .whereField("userId", isEqualTo: userId)
                .getDocuments()
            
            // Count user-imported books (stored locally - would need different approach)
            // For now, we'll only count Firebase shelf books
            // TODO: Add UserDefaults or local storage count if needed
            
            return shelfBooksSnapshot.documents.count
        } catch {
            print("❌ Error fetching shelf books count: \(error.localizedDescription)")
            return 0
        }
    }
    
    // Fetch user metadata (listening time, days active)
    private func fetchUserMetadata(userId: String) async -> (listeningTime: TimeInterval, daysActive: Int) {
        do {
            let document = try await db.collection("users").document(userId).getDocument()
            
            guard let data = document.data() else {
                print("⚠️ User document doesn't exist yet")
                // User document doesn't exist yet - try to fetch from Firebase Auth
                if let user = Auth.auth().currentUser {
                    if let creationDate = user.metadata.creationDate {
                        let days = Calendar.current.dateComponents([.day], from: creationDate, to: Date()).day ?? 0
                        return (0, max(1, days)) // At least 1 day active if user exists
                    }
                }
                return (0, 1) // Default to 1 day if user exists but no data
            }
            
            // Get listening time
            let listeningTime = data["totalListeningTime"] as? TimeInterval ?? 0
            print("📊 Fetched listening time from Firestore: \(Int(listeningTime)) seconds")
            
            // Get createdAt timestamp
            var createdAt: Date? = nil
            if let timestamp = data["createdAt"] as? Timestamp {
                createdAt = timestamp.dateValue()
            }
            
            // If createdAt is not in user document, fall back to Firebase Auth metadata
            if createdAt == nil {
                if let user = Auth.auth().currentUser {
                    createdAt = user.metadata.creationDate
                }
            }
            
            // Calculate days active
            let daysActive: Int
            if let createdDate = createdAt {
                let days = Calendar.current.dateComponents([.day], from: createdDate, to: Date()).day ?? 0
                daysActive = max(1, days) // At least 1 day if account exists
                print("📊 Days active calculated: \(daysActive) (created: \(createdDate))")
            } else {
                daysActive = 1 // Default to 1 if no creation date found
                print("⚠️ No creation date found, defaulting to 1 day active")
            }
            
            return (listeningTime, daysActive)
        } catch {
            print("❌ Error fetching user metadata: \(error.localizedDescription)")
            // On error, try to at least get days from Firebase Auth
            if let user = Auth.auth().currentUser, let creationDate = user.metadata.creationDate {
                let days = Calendar.current.dateComponents([.day], from: creationDate, to: Date()).day ?? 0
                return (0, max(1, days))
            }
            return (0, 1)
        }
    }
    
    // Update listening time (call this when user finishes listening to a book)
    func updateListeningTime(additionalSeconds: TimeInterval) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        do {
            let userRef = db.collection("users").document(userId)
            let document = try await userRef.getDocument()
            
            if document.exists {
                // Update existing listening time
                try await userRef.updateData([
                    "totalListeningTime": FieldValue.increment(Int64(additionalSeconds))
                ])
            } else {
                // Create user document with initial listening time
                try await userRef.setData([
                    "totalListeningTime": additionalSeconds,
                    "createdAt": FieldValue.serverTimestamp()
                ])
            }
            
            // Refresh stats
            await fetchUserStats()
        } catch {
            print("❌ Error updating listening time: \(error.localizedDescription)")
        }
    }
}

