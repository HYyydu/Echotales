import SwiftUI
import FirebaseAuth

struct MyDownloadBooksView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var cloudService = CloudBookService.shared
    @State private var downloadedBookMetadata: [CloudBookMetadata] = []
    @State private var isLoading = true
    @State private var selectedBook: CloudBookMetadata?
    @State private var showBookReader = false
    @State private var selectedBookContent: EPUBContent?
    
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
                        
                        Text("My Download Books")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(textPrimary)
                        
                        Spacer()
                        
                        // Placeholder for symmetry
                        Color.clear
                            .frame(width: 40, height: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 60)
                    .padding(.bottom, 16)
                    .background(Color.white)
                    
                    if isLoading {
                        // Loading State
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(secondaryPink)
                        Text("Loading downloads...")
                            .font(.system(size: 16))
                            .foregroundColor(textSecondary)
                            .padding(.top, 16)
                        Spacer()
                    } else if downloadedBookMetadata.isEmpty {
                        // Empty State
                        Spacer()
                        VStack(spacing: 16) {
                            Image(systemName: "arrow.down.circle")
                                .font(.system(size: 64))
                                .foregroundColor(textTertiary)
                            
                            Text("No Downloaded Books")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(textPrimary)
                            
                            Text("Download books from the Read tab to read them offline")
                                .font(.system(size: 14))
                                .foregroundColor(textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        Spacer()
                    } else {
                        // Content
                        VStack(spacing: 0) {
                            // Statistics Bar
                            HStack(spacing: 0) {
                                StatItem(
                                    value: "\(downloadedBookMetadata.count)",
                                    label: downloadedBookMetadata.count == 1 ? "Book" : "Books",
                                    textPrimary: textPrimary,
                                    textSecondary: textSecondary
                                )
                                
                                Divider()
                                    .frame(height: 40)
                                
                                StatItem(
                                    value: formatSize(getTotalSize()),
                                    label: "Total Size",
                                    textPrimary: textPrimary,
                                    textSecondary: textSecondary
                                )
                                
                                Divider()
                                    .frame(height: 40)
                                
                                StatItem(
                                    value: "Offline",
                                    label: "Available",
                                    textPrimary: textPrimary,
                                    textSecondary: textSecondary
                                )
                            }
                            .padding(.vertical, 16)
                            .background(Color.white)
                            .overlay(
                                Rectangle()
                                    .fill(borderColor)
                                    .frame(height: 1),
                                alignment: .bottom
                            )
                            
                            // Books List
                            ScrollView {
                                LazyVStack(spacing: 0) {
                                    ForEach(downloadedBookMetadata) { book in
                                        DownloadedBookRow(
                                            book: book,
                                            textPrimary: textPrimary,
                                            textSecondary: textSecondary,
                                            textTertiary: textTertiary,
                                            borderColor: borderColor,
                                            bgGray: bgGray,
                                            cloudService: cloudService,
                                            onTap: {
                                                selectedBook = book
                                                loadBookForReading(book)
                                            },
                                            onDelete: {
                                                deleteBook(book)
                                            }
                                        )
                                    }
                                }
                                .padding(.top, 8)
                            }
                        }
                    }
                }
            }
            .onAppear {
                loadDownloadedBooks()
            }
            .refreshable {
                loadDownloadedBooks()
            }
            .fullScreenCover(isPresented: $showBookReader) {
                if let book = selectedBook, let content = selectedBookContent {
                    // Create a text-only reader view for offline books
                    OfflineBookReaderView(
                        bookMetadata: book,
                        bookContent: content,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        bgSecondary: bgGray
                    )
                }
            }
        }
    }
    
    private func loadDownloadedBooks() {
        isLoading = true
        Task {
            // Get list of downloaded book IDs
            let downloadedIds = cloudService.downloadedBooks
            
            // Load catalog to get metadata
            if let catalog = await cloudService.loadCloudCatalog() {
                let metadata = catalog.books.filter { downloadedIds.contains($0.id) }
                
                await MainActor.run {
                    self.downloadedBookMetadata = metadata.sorted { $0.title < $1.title }
                    self.isLoading = false
                }
            } else {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    private func loadBookForReading(_ book: CloudBookMetadata) {
        Task {
            do {
                // Load the book content from local storage
                let content = try await cloudService.loadBook(metadata: book)
                
                await MainActor.run {
                    self.selectedBookContent = content
                    self.showBookReader = true
                }
            } catch {
                print("❌ Failed to load book: \(error)")
            }
        }
    }
    
    private func deleteBook(_ book: CloudBookMetadata) {
        do {
            try cloudService.deleteDownloadedBook(bookId: book.id)
            // Refresh the list
            loadDownloadedBooks()
        } catch {
            print("❌ Failed to delete book: \(error)")
        }
    }
    
    private func getTotalSize() -> Int64 {
        cloudService.getDownloadedBooksSize()
    }
    
    private func formatSize(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

// MARK: - Downloaded Book Row
struct DownloadedBookRow: View {
    let book: CloudBookMetadata
    let textPrimary: Color
    let textSecondary: Color
    let textTertiary: Color
    let borderColor: Color
    let bgGray: Color
    let cloudService: CloudBookService
    let onTap: () -> Void
    let onDelete: () -> Void
    
    @State private var showDeleteAlert = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Book Cover
                if let coverImage = book.localCoverImage {
                    Image(uiImage: coverImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 56, height: 84)
                        .clipped()
                        .cornerRadius(8)
                } else {
                    Rectangle()
                        .fill(bgGray)
                        .frame(width: 56, height: 84)
                        .cornerRadius(8)
                        .overlay(
                            Image(systemName: "book.fill")
                                .foregroundColor(textTertiary)
                        )
                }
                
                // Book Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(book.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(textPrimary)
                        .lineLimit(2)
                    
                    Text(book.author)
                        .font(.system(size: 13))
                        .foregroundColor(textSecondary)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        Text(book.genre)
                            .font(.system(size: 11))
                            .foregroundColor(textTertiary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(bgGray)
                            .cornerRadius(4)
                        
                        Text(book.fileSizeFormatted)
                            .font(.system(size: 11))
                            .foregroundColor(textTertiary)
                        
                        Spacer()
                        
                        // Offline indicator
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.green)
                            Text("Offline")
                                .font(.system(size: 11))
                                .foregroundColor(.green)
                        }
                    }
                }
                
                Spacer()
                
                // Delete Button
                Button(action: {
                    showDeleteAlert = true
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.red)
                        .frame(width: 32, height: 32)
                        .background(Color.red.opacity(0.1))
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
        .alert("Delete Download", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("This will remove '\(book.title)' from your device. You can download it again from the Read tab.")
        }
    }
}

// MARK: - Offline Book Reader View
struct OfflineBookReaderView: View {
    let bookMetadata: CloudBookMetadata
    let bookContent: EPUBContent
    let textPrimary: Color
    let textSecondary: Color
    let bgSecondary: Color
    
    @Environment(\.dismiss) var dismiss
    @State private var selectedChapter: Chapter?
    @State private var showChapterPicker = false
    @State private var showTextReader = false
    
    private let primaryPink = Color(hex: "F9DAD2")
    private let secondaryPink = Color(hex: "F5B5A8")
    private let textTertiary = Color(hex: "6B7280")
    private let bgTertiary = Color(hex: "F3F4F6")
    
    var chapters: [Chapter] {
        bookContent.chapters
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Book Cover
                        if let coverPath = bookContent.coverImageURL,
                           let image = UIImage(contentsOfFile: coverPath) {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 200, height: 300)
                                .cornerRadius(12)
                                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                        } else if let coverImage = bookMetadata.localCoverImage {
                            Image(uiImage: coverImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 200, height: 300)
                                .cornerRadius(12)
                                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                        }
                        
                        // Book Information
                        VStack(spacing: 8) {
                            Text(bookMetadata.title)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(textPrimary)
                                .multilineTextAlignment(.center)
                            
                            Text("by \(bookMetadata.author)")
                                .font(.system(size: 16))
                                .foregroundColor(textSecondary)
                            
                            HStack(spacing: 8) {
                                if !chapters.isEmpty {
                                    Text("\(chapters.count) Chapters")
                                        .font(.system(size: 14))
                                        .foregroundColor(textTertiary)
                                }
                                
                                // Offline badge
                                HStack(spacing: 4) {
                                    Image(systemName: "wifi.slash")
                                        .font(.system(size: 12))
                                    Text("Offline")
                                        .font(.system(size: 14))
                                }
                                .foregroundColor(.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal, 24)
                        
                        // Chapter Selector (if chapters exist)
                        if !chapters.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Selected Chapter")
                                    .font(.system(size: 12))
                                    .foregroundColor(textTertiary)
                                    .padding(.horizontal, 16)
                                
                                Button(action: { showChapterPicker = true }) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(selectedChapter?.title ?? chapters[0].title)
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(textPrimary)
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(textSecondary)
                                    }
                                    .padding(16)
                                    .background(bgTertiary)
                                    .cornerRadius(12)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        
                        // Read Button (Audio is not available offline)
                        VStack(spacing: 12) {
                            Button(action: { showTextReader = true }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "book.fill")
                                        .font(.system(size: 18))
                                    
                                    Text("Read Text")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(secondaryPink)
                                .cornerRadius(12)
                            }
                            .padding(.horizontal, 16)
                            
                            // Info about audio not being available offline
                            HStack(spacing: 8) {
                                Image(systemName: "headphones.slash")
                                    .font(.system(size: 14))
                                    .foregroundColor(textTertiary)
                                
                                Text("Audio playback requires internet connection")
                                    .font(.system(size: 12))
                                    .foregroundColor(textTertiary)
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.vertical, 24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(textPrimary)
                    }
                }
            }
            .sheet(isPresented: $showChapterPicker) {
                if !chapters.isEmpty {
                    ChapterPickerView(
                        chapters: chapters,
                        selectedChapter: $selectedChapter,
                        primaryPink: primaryPink,
                        secondaryPink: secondaryPink,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary
                    )
                }
            }
            .fullScreenCover(isPresented: $showTextReader) {
                // Create a Book object for the TextReaderView
                let book = Book(
                    id: bookMetadata.id,
                    title: bookMetadata.title,
                    author: bookMetadata.author,
                    age: bookMetadata.age,
                    genre: bookMetadata.genre,
                    coverUrl: bookContent.coverImageURL,
                    tags: bookMetadata.tags,
                    textContent: nil,
                    chapters: chapters
                )
                
                TextReaderView(
                    book: book,
                    selectedChapter: selectedChapter,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    bgSecondary: bgSecondary
                )
            }
            .onAppear {
                // Set default chapter if available
                if !chapters.isEmpty, selectedChapter == nil {
                    selectedChapter = chapters[0]
                }
            }
        }
    }
}

#Preview {
    MyDownloadBooksView()
}

