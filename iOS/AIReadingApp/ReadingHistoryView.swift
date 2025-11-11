import SwiftUI
import FirebaseAuth

struct ReadingHistoryView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var historyManager = ReadingHistoryManager()
    @State private var showClearConfirmation = false
    @State private var selectedBook: Book?
    @State private var showBookDetails = false
    
    // Design tokens
    private let primaryPink = Color(hex: "F9DAD2")
    private let secondaryPink = Color(hex: "F5B5A8")
    private let textPrimary = Color(hex: "0F172A")
    private let textSecondary = Color(hex: "475569")
    private let textTertiary = Color(hex: "6B7280")
    private let borderColor = Color(hex: "E5E7EB")
    private let bgGray = Color(hex: "F9FAFB")
    private let accentGreen = Color(hex: "10B981")
    
    var body: some View {
        NavigationStack {
            ZStack {
                bgGray.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Custom Header
                    HStack {
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(textPrimary)
                                .frame(width: 40, height: 40)
                        }
                        
                        Spacer()
                        
                        Text("Reading History")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(textPrimary)
                        
                        Spacer()
                        
                        Button(action: {
                            showClearConfirmation = true
                        }) {
                            Image(systemName: "trash")
                                .font(.system(size: 20))
                                .foregroundColor(textPrimary)
                                .frame(width: 40, height: 40)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 60)
                    .padding(.bottom, 16)
                    .background(Color.white)
                    
                    if historyManager.isLoading {
                        // Loading State
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(secondaryPink)
                        Text("Loading history...")
                            .font(.system(size: 16))
                            .foregroundColor(textSecondary)
                            .padding(.top, 16)
                        Spacer()
                    } else if historyManager.allHistory.isEmpty {
                        // Empty State
                        Spacer()
                        VStack(spacing: 16) {
                            Image(systemName: "book.closed")
                                .font(.system(size: 64))
                                .foregroundColor(textTertiary)
                            
                            Text("No Reading History")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(textPrimary)
                        }
                        .padding(.horizontal, 40)
                        Spacer()
                    } else {
                        // Content
                        VStack(spacing: 0) {
                            // Statistics Bar
                            StatisticsBar(
                                historyManager: historyManager,
                                textPrimary: textPrimary,
                                textSecondary: textSecondary,
                                accentGreen: accentGreen,
                                primaryPink: primaryPink
                            )
                            
                            // Time Period Selector
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(TimePeriod.allCases, id: \.self) { period in
                                        PeriodButton(
                                            period: period,
                                            isSelected: historyManager.selectedPeriod == period,
                                            primaryPink: primaryPink,
                                            secondaryPink: secondaryPink,
                                            textPrimary: textPrimary,
                                            textSecondary: textSecondary
                                        ) {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                historyManager.selectedPeriod = period
                                                historyManager.groupHistory()
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                            }
                            .background(Color.white)
                            
                            // History List
                            ScrollView {
                                LazyVStack(spacing: 0) {
                                    ForEach(historyManager.groupedHistory) { group in
                                        VStack(spacing: 0) {
                                            // Group Header
                                            HStack {
                                                Text(group.title)
                                                    .font(.system(size: 16, weight: .bold))
                                                    .foregroundColor(textPrimary)
                                                
                                                Spacer()
                                                
                                                Text("\(group.entries.count) \(group.entries.count == 1 ? "book" : "books")")
                                                    .font(.system(size: 12, weight: .medium))
                                                    .foregroundColor(textTertiary)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(bgGray)
                                                    .cornerRadius(8)
                                            }
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 12)
                                            .background(Color.white)
                                            
                                            // Group Entries
                                            ForEach(group.entries) { entry in
                                                HistoryEntryRow(
                                                    entry: entry,
                                                    textPrimary: textPrimary,
                                                    textSecondary: textSecondary,
                                                    textTertiary: textTertiary,
                                                    borderColor: borderColor,
                                                    bgGray: bgGray,
                                                    historyManager: historyManager,
                                                    onTap: {
                                                        // Create Book from entry and show details
                                                        let book = Book(
                                                            id: entry.bookId,
                                                            title: entry.bookTitle,
                                                            author: entry.bookAuthor,
                                                            age: entry.bookAge,
                                                            genre: entry.bookGenre,
                                                            coverUrl: entry.bookCoverUrl,
                                                            tags: [],
                                                            textContent: nil,
                                                            chapters: nil
                                                        )
                                                        selectedBook = book
                                                        showBookDetails = true
                                                    }
                                                )
                                            }
                                        }
                                        .background(Color.white)
                                        .padding(.bottom, 8)
                                    }
                                }
                                .padding(.top, 8)
                            }
                        }
                    }
                }
            }
            .confirmationDialog("Clear All History", isPresented: $showClearConfirmation) {
                Button("Clear All History", role: .destructive) {
                    Task {
                        await historyManager.clearAllHistory()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all your reading history. This action cannot be undone.")
            }
            .fullScreenCover(isPresented: $showBookDetails) {
                if let book = selectedBook {
                    BookDetailsView(book: book, voiceId: nil)
                }
            }
            .onAppear {
                Task {
                    await historyManager.fetchHistory()
                }
            }
            .refreshable {
                await historyManager.fetchHistory()
            }
        }
    }
}

// MARK: - Statistics Bar
struct StatisticsBar: View {
    let historyManager: ReadingHistoryManager
    let textPrimary: Color
    let textSecondary: Color
    let accentGreen: Color
    let primaryPink: Color
    
    var body: some View {
        let stats = historyManager.getStatistics()
        
        HStack(spacing: 0) {
            // Total Clicks
            StatItem(
                value: "\(stats.totalBooks)",
                label: "Total Clicks",
                textPrimary: textPrimary,
                textSecondary: textSecondary
            )
            
            Divider()
                .frame(height: 40)
            
            // Unique Books
            StatItem(
                value: "\(stats.uniqueBooks)",
                label: "Unique Books",
                textPrimary: textPrimary,
                textSecondary: textSecondary
            )
            
            Divider()
                .frame(height: 40)
            
            // Most Read Genre
            StatItem(
                value: stats.mostReadGenre,
                label: "Top Genre",
                textPrimary: textPrimary,
                textSecondary: textSecondary
            )
        }
        .padding(.vertical, 16)
        .background(Color.white)
        .overlay(
            Rectangle()
                .fill(Color(hex: "E5E7EB"))
                .frame(height: 1),
            alignment: .bottom
        )
    }
}

struct StatItem: View {
    let value: String
    let label: String
    let textPrimary: Color
    let textSecondary: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Period Button
struct PeriodButton: View {
    let period: TimePeriod
    let isSelected: Bool
    let primaryPink: Color
    let secondaryPink: Color
    let textPrimary: Color
    let textSecondary: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(period.rawValue)
                .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? textPrimary : textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? primaryPink : Color.clear)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? Color.clear : Color(hex: "E5E7EB"), lineWidth: 1)
                )
        }
    }
}

// MARK: - History Entry Row
struct HistoryEntryRow: View {
    let entry: ReadingHistoryEntry
    let textPrimary: Color
    let textSecondary: Color
    let textTertiary: Color
    let borderColor: Color
    let bgGray: Color
    let historyManager: ReadingHistoryManager
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Book Cover
                if !entry.bookCoverUrl.isEmpty, let url = URL(string: entry.bookCoverUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            Rectangle()
                                .fill(bgGray)
                                .frame(width: 56, height: 84)
                                .cornerRadius(8)
                                .overlay(ProgressView().scaleEffect(0.7))
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 56, height: 84)
                                .clipped()
                                .cornerRadius(8)
                        case .failure(_):
                            Rectangle()
                                .fill(Color(hex: "F3F4F6"))
                                .frame(width: 56, height: 84)
                                .cornerRadius(8)
                                .overlay(
                                    Image(systemName: "book.fill")
                                        .foregroundColor(textTertiary)
                                )
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    Rectangle()
                        .fill(bgGray)
                        .frame(width: 56, height: 84)
                        .cornerRadius(8)
                }
                
                // Book Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.bookTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(textPrimary)
                        .lineLimit(2)
                    
                    Text(entry.bookAuthor)
                        .font(.system(size: 13))
                        .foregroundColor(textSecondary)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        Text(entry.bookGenre)
                            .font(.system(size: 11))
                            .foregroundColor(textTertiary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(bgGray)
                            .cornerRadius(4)
                        
                        Text(entry.formattedDate)
                            .font(.system(size: 11))
                            .foregroundColor(textTertiary)
                    }
                }
                
                Spacer()
                
                // Delete Button
                Button(action: {
                    Task {
                        await historyManager.deleteEntry(entryId: entry.id)
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(textTertiary)
                        .frame(width: 24, height: 24)
                        .background(bgGray)
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
        .background(Color.white)
        .overlay(
            Rectangle()
                .fill(borderColor)
                .frame(height: 1)
                .padding(.leading, 88),
            alignment: .bottom
        )
    }
}

#Preview {
    ReadingHistoryView()
}

