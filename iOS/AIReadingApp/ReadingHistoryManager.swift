import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - Reading History Entry Model
struct ReadingHistoryEntry: Identifiable, Codable {
    let id: String
    let bookId: String
    let bookTitle: String
    let bookAuthor: String
    let bookCoverUrl: String
    let bookAge: String
    let bookGenre: String
    let timestamp: Date
    let userId: String
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    var dayKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: timestamp)
    }
    
    var monthKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: timestamp)
    }
    
    var yearKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: timestamp)
    }
}

// MARK: - Time Period Enum
enum TimePeriod: String, CaseIterable {
    case day = "Day"
    case month = "Month"
    case year = "Year"
    case all = "All Time"
}

// MARK: - Grouped Reading History
struct GroupedHistory: Identifiable {
    let id: String
    let title: String
    let entries: [ReadingHistoryEntry]
    let date: Date
}

// MARK: - Reading History Manager
class ReadingHistoryManager: ObservableObject {
    @Published var allHistory: [ReadingHistoryEntry] = []
    @Published var groupedHistory: [GroupedHistory] = []
    @Published var isLoading = false
    @Published var selectedPeriod: TimePeriod = .day
    
    private let db = Firestore.firestore()
    
    // MARK: - Track Book Click
    func trackBookClick(book: Book) async {
        guard let userId = Auth.auth().currentUser?.uid else {
            return
        }
        
        do {
            let historyEntry: [String: Any] = [
                "bookId": book.id,
                "bookTitle": book.title,
                "bookAuthor": book.author,
                "bookCoverUrl": book.coverUrl,
                "bookAge": book.age,
                "bookGenre": book.genre,
                "timestamp": FieldValue.serverTimestamp(),
                "userId": userId
            ]
            
            try await db.collection("readingHistory").addDocument(data: historyEntry)
            
            // Wait a moment for Firebase to process the server timestamp
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // Refresh history after tracking
            await fetchHistory()
        } catch {
            print("❌ Error tracking reading history: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Fetch Reading History
    func fetchHistory() async {
        await MainActor.run {
            isLoading = true
        }
        
        guard let userId = Auth.auth().currentUser?.uid else {
            await MainActor.run {
                allHistory = []
                groupedHistory = []
                isLoading = false
            }
            return
        }
        
        do {
            // Query without ordering (sorted in memory instead)
            // To use Firebase ordering, create a composite index for userId + timestamp
            let snapshot = try await db.collection("readingHistory")
                .whereField("userId", isEqualTo: userId)
                .getDocuments()
            
            let history = snapshot.documents.compactMap { doc -> ReadingHistoryEntry? in
                let data = doc.data()
                
                guard let bookId = data["bookId"] as? String,
                      let bookTitle = data["bookTitle"] as? String,
                      let bookAuthor = data["bookAuthor"] as? String,
                      let bookCoverUrl = data["bookCoverUrl"] as? String,
                      let bookAge = data["bookAge"] as? String,
                      let bookGenre = data["bookGenre"] as? String,
                      let timestamp = (data["timestamp"] as? Timestamp)?.dateValue(),
                      let userId = data["userId"] as? String else {
                    return nil
                }
                
                return ReadingHistoryEntry(
                    id: doc.documentID,
                    bookId: bookId,
                    bookTitle: bookTitle,
                    bookAuthor: bookAuthor,
                    bookCoverUrl: bookCoverUrl,
                    bookAge: bookAge,
                    bookGenre: bookGenre,
                    timestamp: timestamp,
                    userId: userId
                )
            }
            
            // Sort in memory since we're not using Firebase ordering
            let sortedHistory = history.sorted { $0.timestamp > $1.timestamp }
            
            await MainActor.run {
                allHistory = sortedHistory
                groupHistory()
                isLoading = false
            }
        } catch {
            print("❌ Error fetching reading history: \(error.localizedDescription)")
            await MainActor.run {
                allHistory = []
                groupedHistory = []
                isLoading = false
            }
        }
    }
    
    // MARK: - Group History by Time Period
    func groupHistory() {
        var groups: [String: [ReadingHistoryEntry]] = [:]
        
        for entry in allHistory {
            let key: String
            switch selectedPeriod {
            case .day:
                key = entry.dayKey
            case .month:
                key = entry.monthKey
            case .year:
                key = entry.yearKey
            case .all:
                key = "all"
            }
            
            if groups[key] != nil {
                groups[key]?.append(entry)
            } else {
                groups[key] = [entry]
            }
        }
        
        // Convert to sorted array
        groupedHistory = groups.map { key, entries in
            let title = formatGroupTitle(key: key, period: selectedPeriod)
            let date = entries.first?.timestamp ?? Date()
            return GroupedHistory(id: key, title: title, entries: entries, date: date)
        }.sorted { $0.date > $1.date }
    }
    
    // MARK: - Format Group Title
    private func formatGroupTitle(key: String, period: TimePeriod) -> String {
        switch period {
        case .day:
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            if let date = formatter.date(from: key) {
                let displayFormatter = DateFormatter()
                displayFormatter.dateStyle = .full
                return displayFormatter.string(from: date)
            }
            return key
        case .month:
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM"
            if let date = formatter.date(from: key) {
                let displayFormatter = DateFormatter()
                displayFormatter.dateFormat = "MMMM yyyy"
                return displayFormatter.string(from: date)
            }
            return key
        case .year:
            return key
        case .all:
            return "All History"
        }
    }
    
    // MARK: - Delete History Entry
    func deleteEntry(entryId: String) async {
        do {
            try await db.collection("readingHistory").document(entryId).delete()
            await fetchHistory()
        } catch {
            print("❌ Error deleting history entry: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Clear All History
    func clearAllHistory() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        do {
            let snapshot = try await db.collection("readingHistory")
                .whereField("userId", isEqualTo: userId)
                .getDocuments()
            
            // Delete all documents
            for doc in snapshot.documents {
                try await doc.reference.delete()
            }
            
            await fetchHistory()
        } catch {
            print("❌ Error clearing history: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Get Statistics
    func getStatistics() -> (totalBooks: Int, uniqueBooks: Int, mostReadGenre: String) {
        let total = allHistory.count
        let unique = Set(allHistory.map { $0.bookId }).count
        
        // Find most read genre
        var genreCounts: [String: Int] = [:]
        for entry in allHistory {
            genreCounts[entry.bookGenre, default: 0] += 1
        }
        let mostReadGenre = genreCounts.max(by: { $0.value < $1.value })?.key ?? "None"
        
        return (total, unique, mostReadGenre)
    }
}

