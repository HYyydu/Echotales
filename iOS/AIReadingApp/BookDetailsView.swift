import SwiftUI
import AVFoundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - Book Details View
struct BookDetailsView: View {
    let book: Book
    let voiceId: String?
    let cloudMetadata: CloudBookMetadata? // Optional: for cloud books
    
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedChapter: Chapter?
    @State private var showChapterPicker = false
    @State private var showChapterCreator = false
    @State private var showTextReader = false
    @State private var showVoiceSelector = false
    @State private var showAudioPlayer = false
    @State private var selectedRecording: VoiceRecording?
    @State private var errorMessage: String?
    @State private var isFavorited = false
    @State private var isCheckingFavorite = true
    @State private var isSavingForOffline = false
    @State private var showDeleteConfirmation = false
    
    @StateObject private var historyManager = ReadingHistoryManager()
    @StateObject private var streamingService = StreamingEPUBService.shared
    @StateObject private var cloudService = CloudBookService.shared
    @StateObject private var networkMonitor = NetworkMonitor.shared
    
    // Computed properties for cloud books
    var isCloudBook: Bool {
        cloudMetadata != nil
    }
    
    var isDownloadedLocally: Bool {
        guard let metadata = cloudMetadata else { return false }
        return cloudService.isBookDownloaded(bookId: metadata.id)
    }
    
    var isInStreamingCache: Bool {
        guard let metadata = cloudMetadata else { return false }
        return streamingService.isBookInStreamingCache(bookId: metadata.id)
    }
    
    // Check if book can be read offline
    var canReadOffline: Bool {
        // User-uploaded books can always be read
        if !isCloudBook { return true }
        // Cloud books need to be downloaded
        return isDownloadedLocally
    }
    
    // Check if user needs internet to read this book
    var requiresInternetToRead: Bool {
        isCloudBook && !isDownloadedLocally && !networkMonitor.isConnected
    }
    
    init(book: Book, voiceId: String?, cloudMetadata: CloudBookMetadata? = nil) {
        self.book = book
        self.voiceId = voiceId
        self.cloudMetadata = cloudMetadata
    }
    
    // Design tokens
    private let primaryPink = Color(hex: "F9DAD2")
    private let secondaryPink = Color(hex: "F5B5A8")
    private let textPrimary = Color(hex: "0F172A")
    private let textSecondary = Color(hex: "475569")
    private let textTertiary = Color(hex: "6B7280")
    private let bgSecondary = Color(hex: "F9FAFB")
    private let bgTertiary = Color(hex: "F3F4F6")
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Book Cover - handles both local files and remote URLs
                    if let coverUrl = book.coverUrl, !coverUrl.isEmpty {
                        BookCoverImage(coverUrl: coverUrl)
                            .frame(width: 200, height: 300)
                    }
                        
                        // Book Information
                        VStack(spacing: 8) {
                            Text(book.title)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(textPrimary)
                                .multilineTextAlignment(.center)
                            
                            Text("by \(book.author)")
                                .font(.system(size: 16))
                                .foregroundColor(textSecondary)
                            
                            HStack(spacing: 8) {
                                if !book.chapters.isEmpty {
                                    Text("\(book.chapters.count) Chapters")
                                        .font(.system(size: 14))
                                        .foregroundColor(textTertiary)
                                    
                                    Text("•")
                                        .foregroundColor(textTertiary)
                                    
                                    Text("~\(estimatedReadingTime(chapters: book.chapters)) hours")
                                        .font(.system(size: 14))
                                        .foregroundColor(textTertiary)
                                } else if book.textContent != nil {
                                    Text("Full Book")
                                        .font(.system(size: 14))
                                        .foregroundColor(textTertiary)
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        
                        // Chapter Selector Button (for full book without chapters)
                        if book.chapters.isEmpty {
                            Button(action: {
                                showChapterCreator = true
                            }) {
                                HStack {
                                    Image(systemName: "list.bullet")
                                        .font(.system(size: 16))
                                        .foregroundColor(textSecondary)
                                    
                                    Text("No Chapters")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(textPrimary)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(textSecondary)
                                }
                                .padding(16)
                                .background(bgTertiary)
                                .cornerRadius(12)
                            }
                            .padding(.horizontal, 16)
                        }
                        
                        // Chapter Selector (if chapters exist)
                        if !book.chapters.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Selected Chapter")
                                    .font(.system(size: 12))
                                    .foregroundColor(textTertiary)
                                    .padding(.horizontal, 16)
                                
                                Button(action: { showChapterPicker = true }) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(selectedChapter?.title ?? book.chapters[0].title)
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(textPrimary)
                                            
                                            Text("\(estimatedChapterMinutes(content: selectedChapter?.content ?? book.chapters[0].content)) min")
                                                .font(.system(size: 12))
                                                .foregroundColor(textSecondary)
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
                        
                        // Error Message
                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 14))
                                .foregroundColor(.red)
                                .padding(.horizontal, 16)
                        }
                        
                        // Action Buttons
                        HStack(spacing: 12) {
                            // Listen Now Button
                            Button(action: { 
                                if requiresInternetToRead {
                                    errorMessage = "This book is not downloaded for offline reading. Audio playback requires internet connection or downloaded book."
                                } else if !networkMonitor.isConnected {
                                    errorMessage = "Audio playback requires an internet connection. Please connect to the internet or use the text reader for offline reading."
                                } else {
                                    showVoiceSelector = true
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "headphones")
                                        .font(.system(size: 18))
                                    
                                    Text("Listen Now")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(!networkMonitor.isConnected ? Color.gray : secondaryPink)
                                .cornerRadius(12)
                                .opacity(!networkMonitor.isConnected ? 0.5 : 1.0)
                            }
                            
                            // Read Text Button
                            Button(action: { 
                                if requiresInternetToRead {
                                    errorMessage = "This book is not downloaded for offline reading. Please connect to the internet or download the book first."
                                } else {
                                    showTextReader = true
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "book.fill")
                                        .font(.system(size: 18))
                                    
                                    Text("Read Text")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundColor(requiresInternetToRead ? .gray : secondaryPink)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.white)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(requiresInternetToRead ? Color.gray : secondaryPink, lineWidth: 2)
                                )
                                .opacity(requiresInternetToRead ? 0.5 : 1.0)
                            }
                        }
                        .padding(.horizontal, 16)
                        
                        // Show offline warning if needed
                        if requiresInternetToRead {
                            HStack(spacing: 8) {
                                Image(systemName: "wifi.slash")
                                    .font(.system(size: 12))
                                    .foregroundColor(.red)
                                Text("No internet connection - Download this book to read offline")
                                    .font(.system(size: 12))
                                    .foregroundColor(.red)
                            }
                            .padding(.horizontal, 16)
                        }
                        
                        // Cloud Book - Save for Offline / Download Status
                        if isCloudBook {
                            VStack(spacing: 12) {
                                if isDownloadedLocally {
                                    // Show downloaded status and option to delete
                                    HStack(spacing: 8) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 16))
                                            .foregroundColor(.green)
                                        
                                        Text("Downloaded for Offline Reading")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.green)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.green.opacity(0.1))
                                    .cornerRadius(12)
                                    .padding(.horizontal, 16)
                                    
                                    // Delete download button
                                    Button(action: { showDeleteConfirmation = true }) {
                                        HStack(spacing: 8) {
                                            Image(systemName: "trash")
                                                .font(.system(size: 14))
                                            
                                            Text("Remove Download")
                                                .font(.system(size: 14, weight: .medium))
                                        }
                                        .foregroundColor(.red)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color.white)
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                        )
                                    }
                                    .padding(.horizontal, 16)
                                    
                                } else {
                                    // Show save for offline button
                                    Button(action: { saveForOffline() }) {
                                        HStack(spacing: 8) {
                                            if isSavingForOffline {
                                                ProgressView()
                                                    .tint(.white)
                                            } else {
                                                Image(systemName: "arrow.down.circle.fill")
                                                    .font(.system(size: 18))
                                            }
                                            
                                            Text(isSavingForOffline ? "Saving..." : "Save for Offline")
                                                .font(.system(size: 16, weight: .semibold))
                                        }
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .background(
                                            LinearGradient(
                                                gradient: Gradient(colors: [secondaryPink, primaryPink]),
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .cornerRadius(12)
                                        .shadow(color: secondaryPink.opacity(0.3), radius: 8, x: 0, y: 4)
                                    }
                                    .disabled(isSavingForOffline)
                                    .padding(.horizontal, 16)
                                    
                                    // Simple explanation
                                    Text("Download this book to read without internet connection")
                                        .font(.system(size: 12))
                                        .foregroundColor(textTertiary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 16)
                                }
                            }
                        } else {
                            Text("Choose from your recorded voices for AI narration")
                                .font(.system(size: 12))
                                .foregroundColor(textTertiary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)
                        }
                    }
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle("Book Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { toggleFavorite() }) {
                        Image(systemName: isFavorited ? "heart.fill" : "heart")
                            .font(.system(size: 18))
                            .foregroundColor(isFavorited ? .red : textPrimary)
                    }
                    .disabled(isCheckingFavorite)
                }
            }
            .sheet(isPresented: $showChapterPicker) {
                if !book.chapters.isEmpty {
                    ChapterPickerView(
                        chapters: book.chapters,
                        selectedChapter: $selectedChapter,
                        primaryPink: primaryPink,
                        secondaryPink: secondaryPink,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary
                    )
                }
            }
            .sheet(isPresented: $showChapterCreator) {
                ChapterCreatorView(
                    bookText: book.textContent ?? "",
                    bookId: book.id,
                    bookTitle: book.title,
                    primaryPink: primaryPink,
                    secondaryPink: secondaryPink,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    textTertiary: textTertiary,
                    bgTertiary: bgTertiary
                )
            }
            .fullScreenCover(isPresented: $showTextReader) {
                TextReaderView(
                    book: book,
                    selectedChapter: selectedChapter,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    bgSecondary: bgSecondary
                )
            }
            .sheet(isPresented: $showVoiceSelector) {
                VoiceSelectorView(
                    onSelectVoice: { recording in
                        selectedRecording = recording
                        showVoiceSelector = false
                        showAudioPlayer = true
                    }
                )
            }
            .fullScreenCover(isPresented: $showAudioPlayer) {
                if let recording = selectedRecording {
                    AudioPlayerView(
                        book: book,
                        recording: recording,
                        selectedChapter: selectedChapter
                    )
                }
            }
            .alert("Remove Download", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Remove", role: .destructive) {
                    deleteDownload()
                }
            } message: {
                Text("This will remove the downloaded book from your device. You can still stream it when connected to the internet.")
            }
            .onAppear {
                // Set default chapter if available
                if !book.chapters.isEmpty, selectedChapter == nil {
                    selectedChapter = book.chapters[0]
                }
                // Check if book is favorited
                checkIfFavorited()
                // Track reading history
                Task {
                    await historyManager.trackBookClick(book: book)
                }
            }
    }
    
    // MARK: - Helper Functions
    
    private func estimatedReadingTime(chapters: [Chapter]) -> Int {
        let totalWords = chapters.reduce(0) { $0 + $1.content.split(separator: " ").count }
        let wordsPerMinute = 200
        let minutes = totalWords / wordsPerMinute
        return Int(ceil(Double(minutes) / 60.0))
    }
    
    private func estimatedChapterMinutes(content: String) -> Int {
        let words = content.split(separator: " ").count
        let wordsPerMinute = 200
        return max(1, words / wordsPerMinute)
    }
    
    // MARK: - Cloud Book Management
    
    private func saveForOffline() {
        guard let metadata = cloudMetadata else { return }
        
        isSavingForOffline = true
        Task {
            do {
                try await streamingService.saveForOffline(metadata: metadata)
                
                await MainActor.run {
                    isSavingForOffline = false
                    // Trigger UI update by changing state
                }
                
                print("✅ Book saved for offline reading")
            } catch {
                await MainActor.run {
                    isSavingForOffline = false
                    errorMessage = "Failed to save: \(error.localizedDescription)"
                }
                print("❌ Failed to save for offline: \(error)")
            }
        }
    }
    
    private func deleteDownload() {
        guard let metadata = cloudMetadata else { return }
        
        do {
            try cloudService.deleteDownloadedBook(bookId: metadata.id)
            print("✅ Download removed")
        } catch {
            errorMessage = "Failed to delete: \(error.localizedDescription)"
            print("❌ Failed to delete download: \(error)")
        }
    }
    
    private func checkIfFavorited() {
        guard let userId = Auth.auth().currentUser?.uid else {
            isCheckingFavorite = false
            return
        }
        
        let db = Firestore.firestore()
        db.collection("userShelfBooks")
            .whereField("userId", isEqualTo: userId)
            .whereField("bookId", isEqualTo: book.id)
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    isCheckingFavorite = false
                    if let documents = snapshot?.documents, !documents.isEmpty {
                        isFavorited = true
                    } else {
                        isFavorited = false
                    }
                }
            }
    }
    
    private func toggleFavorite() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("⚠️ BookDetails: No authenticated user")
            errorMessage = "Please sign in to add books to your shelf"
            return
        }
        
        print("📚 BookDetails: Toggle favorite for book '\(book.title)' (userId: \(userId))")
        
        let db = Firestore.firestore()
        
        if isFavorited {
            // Remove from shelf
            print("🗑️ BookDetails: Removing from shelf")
            db.collection("userShelfBooks")
                .whereField("userId", isEqualTo: userId)
                .whereField("bookId", isEqualTo: book.id)
                .getDocuments { snapshot, error in
                    if let error = error {
                        print("❌ BookDetails: Error removing from shelf: \(error.localizedDescription)")
                        return
                    }
                    
                    guard let documents = snapshot?.documents else { return }
                    
                    print("🗑️ BookDetails: Found \(documents.count) documents to delete")
                    
                    for document in documents {
                        document.reference.delete()
                    }
                    
                    DispatchQueue.main.async {
                        isFavorited = false
                        print("✅ BookDetails: Removed from shelf")
                    }
                }
        } else {
            // Add to shelf
            print("💾 BookDetails: Adding to shelf")
            
            // Get EPUB URL for the book (either bundled or Firebase)
            let epubUrl = getEPUBUrl(for: book.id)
            print("📚 BookDetails: EPUB URL for book: \(epubUrl)")
            
            let shelfBook: [String: Any] = [
                "userId": userId,
                "bookId": book.id,
                "title": book.title,
                "author": book.author,
                "coverUrl": book.coverUrl,
                "epubUrl": epubUrl,  // NEW: Include EPUB URL
                "age": book.age,
                "genre": book.genre,
                "tags": book.tags,
                "addedAt": Timestamp(date: Date())
            ]
            
            print("📝 BookDetails: Saving document with data: \(shelfBook)")
            
            db.collection("userShelfBooks").addDocument(data: shelfBook) { error in
                if let error = error {
                    print("❌ BookDetails: Failed to add to shelf: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        errorMessage = "Failed to add to shelf: \(error.localizedDescription)"
                    }
                } else {
                    print("✅ BookDetails: Successfully added to shelf!")
                    DispatchQueue.main.async {
                        isFavorited = true
                    }
                    
                    // NOTE: We no longer automatically download books when favoriting
                    // Users must explicitly download books they want to read offline
                }
            }
        }
    }
    
    /// Get the EPUB URL for a book (cloud book storage URL)
    private func getEPUBUrl(for bookId: String) -> String {
        // For cloud books, use the storage URL from metadata if available
        if let metadata = cloudMetadata {
            return metadata.storageUrl
        }
        
        // Fallback: construct expected storage URL
        return "epubs/\(bookId).epub"
    }
}

// MARK: - Chapter Picker View
struct ChapterPickerView: View {
    let chapters: [Chapter]
    @Binding var selectedChapter: Chapter?
    @Environment(\.dismiss) var dismiss
    
    let primaryPink: Color
    let secondaryPink: Color
    let textPrimary: Color
    let textSecondary: Color
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(chapters.enumerated()), id: \.element.id) { index, chapter in
                    Button(action: {
                        selectedChapter = chapter
                        dismiss()
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Chapter \(index + 1)")
                                    .font(.system(size: 12))
                                    .foregroundColor(textSecondary)
                                
                                Text(chapter.title)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(textPrimary)
                            }
                            
                            Spacer()
                            
                            if selectedChapter?.id == chapter.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(secondaryPink)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("Select Chapter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Chapter Creator View
struct ChapterCreatorView: View {
    let bookText: String
    let bookId: String
    let bookTitle: String
    
    @Environment(\.dismiss) var dismiss
    @State private var detectedChapters: [ChapterDivision] = []
    @State private var isProcessing = true
    @State private var errorMessage: String?
    @State private var editingChapter: ChapterDivision?
    
    let primaryPink: Color
    let secondaryPink: Color
    let textPrimary: Color
    let textSecondary: Color
    let textTertiary: Color
    let bgTertiary: Color
    
    struct ChapterDivision: Identifiable {
        let id = UUID()
        var title: String
        var startIndex: String.Index
        var endIndex: String.Index
        var preview: String
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isProcessing {
                    VStack(spacing: 16) {
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(secondaryPink)
                        Text("Analyzing book structure...")
                            .font(.system(size: 16))
                            .foregroundColor(textSecondary)
                        Spacer()
                    }
                } else if detectedChapters.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "book.closed")
                            .font(.system(size: 48))
                            .foregroundColor(textTertiary)
                        Text("No Chapters Detected")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(textPrimary)
                        Text("This book doesn't have clear chapter divisions.")
                            .font(.system(size: 14))
                            .foregroundColor(textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        Spacer()
                    }
                } else {
                    List {
                        Section {
                            Text("Found \(detectedChapters.count) chapters")
                                .font(.system(size: 14))
                                .foregroundColor(textSecondary)
                        }
                        
                        ForEach(Array(detectedChapters.enumerated()), id: \.element.id) { index, chapter in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Chapter \(index + 1)")
                                            .font(.system(size: 12))
                                            .foregroundColor(textTertiary)
                                        Text(chapter.title)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(textPrimary)
                                    }
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        editingChapter = chapter
                                    }) {
                                        Image(systemName: "pencil")
                                            .font(.system(size: 14))
                                            .foregroundColor(secondaryPink)
                                    }
                                }
                                
                                Text(chapter.preview)
                                    .font(.system(size: 12))
                                    .foregroundColor(textSecondary)
                                    .lineLimit(2)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                
                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                        .padding()
                }
            }
            .navigationTitle("Create Chapters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChapters()
                    }
                    .disabled(detectedChapters.isEmpty || isProcessing)
                }
            }
            .alert("Edit Chapter Title", isPresented: .constant(editingChapter != nil)) {
                TextField("Chapter Title", text: .constant(editingChapter?.title ?? ""))
                Button("Cancel", role: .cancel) {
                    editingChapter = nil
                }
                Button("Save") {
                    // Update chapter title
                    if let editing = editingChapter,
                       let index = detectedChapters.firstIndex(where: { $0.id == editing.id }) {
                        detectedChapters[index].title = editing.title
                    }
                    editingChapter = nil
                }
            }
        }
        .onAppear {
            detectChapters()
        }
    }
    
    private func detectChapters() {
        Task {
            await MainActor.run {
                isProcessing = true
            }
            
            // Detect chapters using common patterns
            let patterns = [
                "(?:^|\\n)Chapter \\d+[:\\.]?\\s*(.+?)(?=\\n)",
                "(?:^|\\n)CHAPTER \\d+[:\\.]?\\s*(.+?)(?=\\n)",
                "(?:^|\\n)\\d+\\.\\s+(.+?)(?=\\n)",
            ]
            
            var divisions: [ChapterDivision] = []
            
            for pattern in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                    let nsString = bookText as NSString
                    let matches = regex.matches(in: bookText, range: NSRange(location: 0, length: nsString.length))
                    
                    if !matches.isEmpty {
                        // Found chapter markers
                        for (index, match) in matches.enumerated() {
                            let matchRange = match.range
                            let startIndex = bookText.index(bookText.startIndex, offsetBy: matchRange.location)
                            
                            // Get chapter title
                            var title = "Chapter \(index + 1)"
                            if match.numberOfRanges > 1 {
                                let titleRange = match.range(at: 1)
                                if titleRange.location != NSNotFound {
                                    title = nsString.substring(with: titleRange).trimmingCharacters(in: .whitespacesAndNewlines)
                                }
                            }
                            
                            // Determine end index
                            let endIndex: String.Index
                            if index < matches.count - 1 {
                                let nextMatch = matches[index + 1]
                                endIndex = bookText.index(bookText.startIndex, offsetBy: nextMatch.range.location)
                            } else {
                                endIndex = bookText.endIndex
                            }
                            
                            // Get preview
                            let contentStart = bookText.index(startIndex, offsetBy: min(100, bookText.distance(from: startIndex, to: endIndex)))
                            let preview = String(bookText[startIndex..<contentStart]).trimmingCharacters(in: .whitespacesAndNewlines)
                            
                            divisions.append(ChapterDivision(
                                title: title,
                                startIndex: startIndex,
                                endIndex: endIndex,
                                preview: preview
                            ))
                        }
                        break
                    }
                }
            }
            
            // If no patterns found, split by large paragraph breaks
            if divisions.isEmpty {
                let paragraphs = bookText.components(separatedBy: "\n\n\n")
                if paragraphs.count > 1 && paragraphs.count < 50 {
                    var currentIndex = bookText.startIndex
                    for (index, paragraph) in paragraphs.enumerated() {
                        let endIndex = bookText.index(currentIndex, offsetBy: paragraph.count, limitedBy: bookText.endIndex) ?? bookText.endIndex
                        let preview = String(paragraph.prefix(100)).trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        divisions.append(ChapterDivision(
                            title: "Chapter \(index + 1)",
                            startIndex: currentIndex,
                            endIndex: endIndex,
                            preview: preview
                        ))
                        
                        currentIndex = bookText.index(endIndex, offsetBy: 3, limitedBy: bookText.endIndex) ?? bookText.endIndex
                    }
                }
            }
            
            await MainActor.run {
                detectedChapters = divisions
                isProcessing = false
            }
        }
    }
    
    private func saveChapters() {
        // Convert divisions to Chapter objects
        var chapters: [Chapter] = []
        
        for (index, division) in detectedChapters.enumerated() {
            let content = String(bookText[division.startIndex..<division.endIndex])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            chapters.append(Chapter(
                id: UUID().uuidString,
                title: division.title,
                content: content,
                order: index
            ))
        }
        
        // Save to Firestore
        let db = Firestore.firestore()
        let bookRef = db.collection("books").document(bookId)
        
        // Convert chapters to dictionary format
        let chaptersData = chapters.map { chapter in
            return [
                "id": chapter.id,
                "title": chapter.title,
                "content": chapter.content
                // Removed "order"
            ] as [String: Any]
        }
        
        bookRef.updateData([
            "chapters": chaptersData,
            "textContent": FieldValue.delete() // Remove full text since we now have chapters
        ]) { error in
            if let error = error {
                errorMessage = "Failed to save: \(error.localizedDescription)"
            } else {
                dismiss()
            }
        }
    }
}

// MARK: - Text Reader View
struct TextReaderView: View {
    let book: Book
    let selectedChapter: Chapter?
    @Environment(\.dismiss) var dismiss
    
    let textPrimary: Color
    let textSecondary: Color
    let bgSecondary: Color
    
    @State private var fontSize: CGFloat = 18
    @State private var currentPage: Int = 0
    @State private var pages: [String] = []
    @State private var showControls: Bool = true
    @State private var pageTransitionDirection: PageTransitionDirection = .forward
    
    // Audio playback states - using new streaming manager
    @StateObject private var streamingManager = StreamingAudioManager()
    @State private var recordings: [VoiceRecording] = []
    @State private var selectedRecording: VoiceRecording?
    @State private var showVoicePicker: Bool = false
    
    private let secondaryPink = Color(hex: "F5B5A8")
    
    enum PageTransitionDirection {
        case forward, backward
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    if !pages.isEmpty {
                        TabView(selection: $currentPage) {
                            ForEach(pages.indices, id: \.self) { index in
                                ScrollView(.vertical) {
                                    VStack(alignment: .leading, spacing: 16) {
                                        
                                        // title only on first page
                                        if index == 0 {
                                            if let chapter = selectedChapter {
                                                Text(chapter.title)
                                                    .font(.system(size: 28, weight: .bold))
                                                    .foregroundColor(textPrimary)
                                                    .padding(.bottom, 8)
                                            } else {
                                                Text(book.title)
                                                    .font(.system(size: 28, weight: .bold))
                                                    .foregroundColor(textPrimary)
                                                    .padding(.bottom, 8)
                                            }
                                        }
                                        
                                        Text(pages[index])
                                            .font(.system(size: fontSize))
                                            .foregroundColor(textPrimary)
                                            .lineSpacing(8)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        
                                        // ensure extra breathing room for the last line
                                        Spacer(minLength: 0)
                                    }
                                    .padding(.horizontal, 32)
                                    .padding(.top, 80)
                                }
                                .contentMargins(.bottom, max(24, geo.safeAreaInsets.bottom + 8), for: .scrollContent)
                                .scrollIndicators(.hidden)
                                .background(Color(.systemBackground))
                                .tag(index)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                    } else {
                        VStack {
                            ProgressView().tint(textSecondary)
                            Text("Loading...")
                                .font(.system(size: 16))
                                .foregroundColor(textSecondary)
                                .padding(.top, 8)
                        }
                    }
                }
                
                // Top Controls Overlay (appears when showControls is true)
                VStack {
                    if showControls {
                        HStack {
                            // Close button
                            Button(action: { 
                                dismiss()
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(Color.white.opacity(0.9))
                                        .frame(width: 44, height: 44)
                                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                                    
                                    Image(systemName: "xmark")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(textPrimary)
                                }
                            }
                            .buttonStyle(.plain)
                            .zIndex(1000)
                            
                            Spacer()
                            
                            // Font size button
                            Menu {
                                Button(action: { 
                                    fontSize = 16
                                    regeneratePages()
                                }) {
                                    Label("Small", systemImage: fontSize == 16 ? "checkmark" : "")
                                }
                                Button(action: { 
                                    fontSize = 18
                                    regeneratePages()
                                }) {
                                    Label("Medium", systemImage: fontSize == 18 ? "checkmark" : "")
                                }
                                Button(action: { 
                                    fontSize = 20
                                    regeneratePages()
                                }) {
                                    Label("Large", systemImage: fontSize == 20 ? "checkmark" : "")
                                }
                                Button(action: { 
                                    fontSize = 24
                                    regeneratePages()
                                }) {
                                    Label("Extra Large", systemImage: fontSize == 24 ? "checkmark" : "")
                                }
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color.white.opacity(0.9))
                                        .frame(width: 44, height: 44)
                                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                                    
                                    Image(systemName: "textformat.size")
                                        .font(.system(size: 16))
                                        .foregroundColor(textPrimary)
                                }
                            }
                            .zIndex(1000)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(999)
                    }
                    
                    Spacer()
                    
                    // Bottom controls container
                    if showControls && !pages.isEmpty {
                        VStack(spacing: 8) {
                            // Error message display (only show errors, not progress)
                            if let errorMsg = streamingManager.errorMessage {
                                Text(errorMsg)
                                    .font(.system(size: 12))
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(Color.red.opacity(0.1))
                                    )
                                    .padding(.bottom, 4)
                            }
                            
                            ZStack {
                                // Centered Page indicator
                                HStack {
                                    Spacer()
                                    Text("\(currentPage + 1) / \(pages.count)")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(textSecondary)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(
                                            Capsule()
                                                .fill(Color.white.opacity(0.9))
                                                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                                        )
                                    Spacer()
                                }
                                
                                // Floating Play Button (bottom right)
                                HStack {
                                    Spacer()
                                    Button(action: handlePlayButtonTap) {
                                        ZStack {
                                            Circle()
                                                .fill(secondaryPink)
                                                .frame(width: 80, height: 80)
                                                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 4)
                                            
                                            if streamingManager.isGenerating && !streamingManager.isPlaying {
                                                ProgressView()
                                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                    .scaleEffect(1.5)
                                            } else {
                                                Image(systemName: streamingManager.isPlaying ? "pause.fill" : "play.fill")
                                                    .font(.system(size: 30))
                                                    .foregroundColor(.white)
                                                    .offset(x: streamingManager.isPlaying ? 0 : 2)
                                            }
                                        }
                                    }
                                    .disabled(streamingManager.isGenerating && !streamingManager.isPlaying)
                                    .padding(.trailing, 20)
                                }
                            }
                        }
                        .padding(.bottom, 40)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(999)
                    }
                }
                .zIndex(998)
                
                // Invisible tap zones for navigation (placed below controls in Z-order)
                if !showControls {
                    HStack(spacing: 0) {
                        // Left tap zone (previous page)
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if currentPage > 0 {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        currentPage -= 1
                                    }
                                }
                            }
                        
                        // Middle tap zone (toggle controls)
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showControls.toggle()
                                }
                            }
                        
                        // Right tap zone (next page)
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if currentPage < pages.count - 1 {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        currentPage += 1
                                    }
                                }
                            }
                    }
                    .ignoresSafeArea()
                    .zIndex(1)
                } else {
                    // When controls are visible, create a tap zone for the center area only
                    VStack {
                        Spacer()
                            .frame(height: 80) // Space for top controls
                        
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showControls.toggle()
                                }
                            }
                        
                        Spacer()
                            .frame(height: 120) // Space for bottom controls
                    }
                    .ignoresSafeArea()
                    .zIndex(1)
                }
            }
        }
        .statusBar(hidden: !showControls)
        .sheet(isPresented: $showVoicePicker) {
            VoicePickerSheet(
                recordings: recordings,
                selectedRecording: $selectedRecording,
                onSelect: { recording in
                    selectedRecording = recording
                    showVoicePicker = false
                    startPlayback()
                }
            )
        }
        .onAppear {
            generatePages()
            loadUserRecordings()
            // Hide controls after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showControls = false
                }
            }
        }
        .onDisappear {
            stopAudioPlayback()
        }
    }
    
    // MARK: - Audio Playback Functions
    
    private func loadUserRecordings() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        db.collection("voiceRecordings")
            .whereField("userId", isEqualTo: userId)
            .getDocuments { snapshot, error in
                guard let documents = snapshot?.documents else { return }
                
                let fetchedRecordings = documents.compactMap { doc -> VoiceRecording? in
                    let data = doc.data()
                    guard let name = data["name"] as? String,
                          let voiceId = data["voiceId"] as? String,
                          let userId = data["userId"] as? String,
                          let timestamp = data["createdAt"] as? Timestamp else {
                        return nil
                    }
                    
                    return VoiceRecording(
                        id: doc.documentID,
                        name: name,
                        voiceId: voiceId,
                        createdAt: timestamp.dateValue(),
                        userId: userId
                    )
                }
                
                DispatchQueue.main.async {
                    self.recordings = fetchedRecordings.sorted { $0.createdAt > $1.createdAt }
                    // Auto-select first recording if available
                    if self.selectedRecording == nil, let first = self.recordings.first {
                        self.selectedRecording = first
                    }
                }
            }
    }
    
    private func handlePlayButtonTap() {
        if streamingManager.isPlaying {
            // Pause playback
            streamingManager.pause()
        } else if streamingManager.isGenerating {
            // If generating but not playing, resume playback
            streamingManager.resume()
        } else {
            // Start new playback
            if selectedRecording == nil {
                // Show voice picker if no voice selected
                if !recordings.isEmpty {
                    showVoicePicker = true
                }
            } else {
                startPlayback()
            }
        }
    }
    
    private func startPlayback() {
        guard let recording = selectedRecording else { return }
        
        // Get text content
        let textContent = getTextContent()
        
        // Start streaming audio generation and playback
        Task { @MainActor in
            streamingManager.startStreaming(text: textContent, voiceId: recording.voiceId)
        }
    }
    
    private func stopAudioPlayback() {
        streamingManager.stop()
    }
    
    private func getTextContent() -> String {
        let rawContent: String
        if let chapter = selectedChapter {
            rawContent = chapter.content
        } else if !book.chapters.isEmpty {
            rawContent = book.chapters[0].content
        } else if let content = book.textContent {
            rawContent = content
        } else {
            return "No content available."
        }
        
        // Apply duplicate chapter title removal
        return removeDuplicateChapterTitle(from: rawContent)
    }
    
    /// Remove duplicate chapter title from the beginning of content
    /// Checks if the first lines match the chapter name and removes all duplicates
    private func removeDuplicateChapterTitle(from text: String) -> String {
        guard let chapter = selectedChapter else { return text }
        
        var trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let chapterTitle = chapter.title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Repeatedly remove duplicate chapter titles from the beginning until none are found
        var didRemove = true
        while didRemove {
            didRemove = false
            
            // Split by any combination of newlines to get lines
            let lines = trimmedText.components(separatedBy: .newlines)
            guard !lines.isEmpty else { return trimmedText }
            
            // Check first non-empty line
            for (index, line) in lines.enumerated() {
                let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Skip empty lines
                if trimmedLine.isEmpty {
                    continue
                }
                
                // Check if line matches chapter title (case-insensitive)
                if trimmedLine.lowercased() == chapterTitle.lowercased() {
                    // Remove this line
                    let remainingLines = lines.dropFirst(index + 1)
                    trimmedText = remainingLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                    didRemove = true
                    break
                }
                
                // Check common chapter heading patterns
                let chapterPatterns = [
                    "^CHAPTER\\s+\\d+\\s*$",
                    "^Chapter\\s+\\d+\\s*$",
                    "^CHAPTER\\s+[IVXLCDM]+\\s*$",
                    "^Chapter\\s+[IVXLCDM]+\\s*$",
                    "^[IVXLCDM]+\\.?\\s*$",  // Roman numerals with optional period
                    "^\\d+\\.?\\s*$"          // Numbers with optional period
                ]
                
                for pattern in chapterPatterns {
                    if let regex = try? NSRegularExpression(pattern: pattern, options: []),
                       regex.firstMatch(in: trimmedLine, range: NSRange(trimmedLine.startIndex..., in: trimmedLine)) != nil {
                        // Remove this line
                        let remainingLines = lines.dropFirst(index + 1)
                        trimmedText = remainingLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                        didRemove = true
                        break
                    }
                }
                
                if didRemove {
                    break
                }
                
                // If we found a non-empty line that doesn't match, stop searching
                break
            }
        }
        
        return trimmedText
    }
    
    private func generatePages() {
        let rawText = getTextContent()
        
        // Remove duplicate chapter title from content if it exists at the beginning
        let text = removeDuplicateChapterTitle(from: rawText)
        
        // Split text into paragraphs
        let paragraphs = text.components(separatedBy: "\n\n")
        
        // Approximate characters per page based on font size
        // Significantly reduced to prevent text from being covered at bottom
        let charsPerPage: Int
        switch fontSize {
        case 16:
            charsPerPage = 1000
        case 18:
            charsPerPage = 850
        case 20:
            charsPerPage = 700
        case 24:
            charsPerPage = 500
        default:
            charsPerPage = 850
        }
        
        var tempPages: [String] = []
        var currentPageText = ""
        var currentCharCount = 0
        
        for paragraph in paragraphs {
            var remainingParagraph = paragraph
            
            while !remainingParagraph.isEmpty {
                let availableSpace = charsPerPage - currentCharCount
                
                // If we have space and the paragraph fits, add it
                if remainingParagraph.count + 2 <= availableSpace {
                    if !currentPageText.isEmpty {
                        currentPageText += "\n\n"
                        currentCharCount += 2
                    }
                    currentPageText += remainingParagraph
                    currentCharCount += remainingParagraph.count
                    remainingParagraph = ""
                }
                // If current page is not empty but paragraph doesn't fit, start new page
                else if !currentPageText.isEmpty {
                    tempPages.append(currentPageText.trimmingCharacters(in: .whitespacesAndNewlines))
                    currentPageText = ""
                    currentCharCount = 0
                }
                // If current page is empty and paragraph is too long, split it
                else {
                    // Find a good break point (preferably at a sentence or word)
                    let breakPoint = min(charsPerPage, remainingParagraph.count)
                    var splitIndex = remainingParagraph.index(remainingParagraph.startIndex, offsetBy: breakPoint)
                    
                    // Try to break at a sentence end
                    if let sentenceEnd = remainingParagraph[..<splitIndex].lastIndex(where: { $0 == "." || $0 == "!" || $0 == "?" }) {
                        splitIndex = remainingParagraph.index(after: sentenceEnd)
                    }
                    // Otherwise break at a space
                    else if let spaceIndex = remainingParagraph[..<splitIndex].lastIndex(of: " ") {
                        splitIndex = spaceIndex
                    }
                    
                    let chunk = String(remainingParagraph[..<splitIndex])
                    currentPageText = chunk
                    currentCharCount = chunk.count
                    remainingParagraph = String(remainingParagraph[splitIndex...]).trimmingCharacters(in: .whitespaces)
                    
                    // If we've filled the page, save it
                    if currentCharCount >= Int(Double(charsPerPage) * 0.9) { // 90% threshold
                        tempPages.append(currentPageText.trimmingCharacters(in: .whitespacesAndNewlines))
                        currentPageText = ""
                        currentCharCount = 0
                    }
                }
            }
        }
        
        // Add the last page if there's remaining text
        if !currentPageText.isEmpty {
            tempPages.append(currentPageText.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        
        pages = tempPages
    }
    
    private func regeneratePages() {
        let savedPage = currentPage
        generatePages()
        // Try to maintain approximate position
        let pageRatio = Double(savedPage) / Double(max(pages.count, 1))
        currentPage = min(Int(pageRatio * Double(pages.count)), pages.count - 1)
    }
}

// MARK: - Voice Selector View
struct VoiceSelectorView: View {
    @Environment(\.dismiss) var dismiss
    @State private var recordings: [VoiceRecording] = []
    @State private var isLoading = true
    let onSelectVoice: (VoiceRecording) -> Void
    
    // Design tokens
    private let primaryPink = Color(hex: "F9DAD2")
    private let secondaryPink = Color(hex: "F5B5A8")
    private let textPrimary = Color(hex: "0F172A")
    private let textSecondary = Color(hex: "475569")
    private let textTertiary = Color(hex: "6B7280")
    private let borderColor = Color(hex: "E5E7EB")
    private let bgGray = Color(hex: "F9FAFB")
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading {
                    VStack {
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(secondaryPink)
                        Text("Loading voices...")
                            .font(.system(size: 16))
                            .foregroundColor(textSecondary)
                            .padding(.top, 16)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(bgGray)
                } else if recordings.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        
                        ZStack {
                            Circle()
                                .fill(primaryPink.opacity(0.3))
                                .frame(width: 96, height: 96)
                            
                            Image(systemName: "mic.slash")
                                .font(.system(size: 48))
                                .foregroundColor(secondaryPink)
                        }
                        
                        Text("No Recordings Yet")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(textPrimary)
                        
                        Text("Record your voice in the Record tab to create AI narrations")
                            .font(.system(size: 15))
                            .foregroundColor(textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(bgGray)
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(recordings) { recording in
                                Button(action: {
                                    onSelectVoice(recording)
                                }) {
                                    VoiceSelectionCard(recording: recording)
                                }
                            }
                        }
                        .padding(20)
                    }
                    .background(bgGray)
                }
            }
            .navigationTitle("Select Voice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadRecordings()
        }
    }
    
    private func loadRecordings() {
        guard let userId = Auth.auth().currentUser?.uid else {
            isLoading = false
            return
        }
        
        let db = Firestore.firestore()
        db.collection("voiceRecordings")
            .whereField("userId", isEqualTo: userId)
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                
                guard let documents = snapshot?.documents else { return }
                
                let fetchedRecordings = documents.compactMap { doc -> VoiceRecording? in
                    let data = doc.data()
                    
                    guard let name = data["name"] as? String,
                          let voiceId = data["voiceId"] as? String,
                          let userId = data["userId"] as? String,
                          let timestamp = data["createdAt"] as? Timestamp else {
                        return nil
                    }
                    
                    return VoiceRecording(
                        id: doc.documentID,
                        name: name,
                        voiceId: voiceId,
                        createdAt: timestamp.dateValue(),
                        userId: userId
                    )
                }
                
                DispatchQueue.main.async {
                    self.recordings = fetchedRecordings.sorted { $0.createdAt > $1.createdAt }
                }
            }
    }
}

// MARK: - Voice Selection Card
struct VoiceSelectionCard: View {
    let recording: VoiceRecording
    
    private let primaryPink = Color(hex: "F9DAD2")
    private let secondaryPink = Color(hex: "F5B5A8")
    private let textPrimary = Color(hex: "0F172A")
    private let textSecondary = Color(hex: "475569")
    private let textTertiary = Color(hex: "6B7280")
    private let borderColor = Color(hex: "E5E7EB")
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(primaryPink)
                    .frame(width: 56, height: 56)
                
                Image(systemName: "mic.fill")
                    .font(.system(size: 24))
                    .foregroundColor(secondaryPink)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(recording.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(textPrimary)
                
                Text(recording.formattedDate)
                    .font(.system(size: 13))
                    .foregroundColor(textSecondary)
            }
            
            Spacer()
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(textTertiary)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor, lineWidth: 1)
        )
    }
}

// MARK: - Audio Player View
struct AudioPlayerView: View {
    let book: Book
    let recording: VoiceRecording
    let selectedChapter: Chapter?
    
    @Environment(\.dismiss) var dismiss
    @StateObject private var streamingManager = StreamingAudioManager()
    @StateObject private var membershipManager = MembershipManager()
    @State private var errorMessage: String?
    @State private var timer: Timer?
    @State private var sessionListeningTime: TimeInterval = 0
    @State private var lastPlayTime: Date?
    @StateObject private var statsManager = UserStatsManager()
    @State private var showUsageLimitAlert = false
    
    // Design tokens
    private let primaryPink = Color(hex: "F9DAD2")
    private let secondaryPink = Color(hex: "F5B5A8")
    private let textPrimary = Color(hex: "0F172A")
    private let textSecondary = Color(hex: "475569")
    private let textTertiary = Color(hex: "6B7280")
    private let bgSecondary = Color(hex: "F9FAFB")
    
    var body: some View {
        ZStack {
            bgSecondary.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Navigation Bar
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(textPrimary)
                            .frame(width: 44, height: 44)
                    }
                    
                    Spacer()
                    
                    Text("Now Playing")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(textPrimary)
                    
                    Spacer()
                    
                    // Invisible placeholder
                    Color.clear
                        .frame(width: 44, height: 44)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .padding(.top, 20)
                .background(Color.white)
                
                Spacer()
                    .frame(height: 20)
                
                // Book Cover - using BookCoverImage to handle all URL types
                if let coverUrl = book.coverUrl, !coverUrl.isEmpty {
                    BookCoverImage(coverUrl: coverUrl)
                        .frame(width: 280, height: 420)
                        .cornerRadius(20)
                        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
                } else {
                    Rectangle()
                        .fill(Color(hex: "E5E7EB"))
                        .frame(width: 280, height: 420)
                        .cornerRadius(20)
                }
                
                Spacer()
                    .frame(height: 20)
                
                // Book Info
                VStack(spacing: 8) {
                    Text(book.title)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(textPrimary)
                        .multilineTextAlignment(.center)
                    
                    Text("by \(book.author)")
                        .font(.system(size: 16))
                        .foregroundColor(textSecondary)
                    
                    if let chapter = selectedChapter {
                        Text(chapter.title)
                            .font(.system(size: 14))
                            .foregroundColor(textTertiary)
                            .padding(.top, 4)
                    }
                    
                    Text("Voice: \(recording.name)")
                        .font(.system(size: 14))
                        .foregroundColor(secondaryPink)
                        .padding(.top, 2)
                }
                .padding(.horizontal, 32)
                
                Spacer()
                    .frame(height: 60)
                
                // Playback Controls Section
                VStack(spacing: 16) {
                    // ONLY show loading if we haven't started playing yet
                    if streamingManager.isGenerating && !streamingManager.isPlaying && streamingManager.currentChunkIndex == 0 {
                        // Initial loading state - waiting for first chunk
                        VStack(spacing: 12) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: secondaryPink))
                                .scaleEffect(1.2)
                            
                            Text("Generating audio with your voice...")
                                .font(.system(size: 14))
                                .foregroundColor(textSecondary)
                        }
                        .padding(.vertical, 20)
                    } else {
                        // Playback Controls
                        HStack(spacing: 48) {
                            // Rewind Button
                            Button(action: rewind) {
                                Image(systemName: "gobackward.15")
                                    .font(.system(size: 32))
                                    .foregroundColor(textPrimary)
                            }
                            
                            // Play/Pause Button
                            Button(action: togglePlayback) {
                                ZStack {
                                    Circle()
                                        .fill(secondaryPink)
                                        .frame(width: 72, height: 72)
                                    
                                    Image(systemName: streamingManager.isPlaying ? "pause.fill" : "play.fill")
                                        .font(.system(size: 28))
                                        .foregroundColor(.white)
                                        .offset(x: streamingManager.isPlaying ? 0 : 2)
                                }
                            }
                            // Only disable if we haven't started yet (no chunks played at all)
                            .disabled(streamingManager.currentChunkIndex == 0 && !streamingManager.isPlaying && !streamingManager.isGenerating)
                            
                            // Forward Button
                            Button(action: forward) {
                                Image(systemName: "goforward.15")
                                    .font(.system(size: 32))
                                    .foregroundColor(textPrimary)
                            }
                        }
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 60)
                
                if let error = errorMessage ?? streamingManager.errorMessage {
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 20)
                }
            }
        }
        .onAppear {
            // Set membership manager for usage tracking
            streamingManager.setMembershipManager(membershipManager)
            generateAndPlayAudio()
        }
        .onDisappear {
            print("🔴 Audio player view disappearing...")
            stopPlayback()
            saveListeningTime()
        }
        .alert("Usage Limit Reached", isPresented: $showUsageLimitAlert) {
            Button("OK") {
                dismiss()
            }
            Button("Upgrade to Premium") {
                // Navigate to membership view
                dismiss()
            }
        } message: {
            if let status = membershipManager.membershipStatus {
                if status.type == .free {
                    Text("You've used your 30 minutes of free audio for this month. Upgrade to Premium for unlimited listening, or wait until next month when your free time resets.")
                } else if status.type == .freeTrial {
                    Text("Your free trial of 30 minutes has expired. Upgrade to Premium for unlimited listening.")
                }
            } else {
                Text("You've reached your listening limit. Please upgrade to continue.")
            }
        }
    }
    
    private func generateAndPlayAudio() {
        print("🎵 generateAndPlayAudio() called with streaming")
        
        // Check membership status before playing
        Task { @MainActor in
            // Load membership status
            await membershipManager.loadMembershipStatus()
            
            // Check if user can use the feature
            guard membershipManager.canUseFeature() else {
                print("⚠️ User cannot use audio feature - limit reached")
                showUsageLimitAlert = true
                return
            }
            
            // Get text content
            let rawContent: String
            if let chapter = selectedChapter {
                rawContent = chapter.content
                print("📖 Using chapter content: \(chapter.title)")
                print("📏 Chapter content length: \(chapter.content.count) characters")
            } else if !book.chapters.isEmpty {
                rawContent = book.chapters[0].content
                print("📖 Using first chapter content")
                print("📏 Chapter content length: \(book.chapters[0].content.count) characters")
            } else if let content = book.textContent {
                rawContent = content
                print("📖 Using book text content")
            } else {
                errorMessage = "No text content available"
                return
            }
            
            // Remove duplicate chapter title from content
            let textContent = removeDuplicateChapterTitleInAudio(from: rawContent)
            
            print("✅ Final content length: \(textContent.count) characters")
            
            // Start streaming audio
            streamingManager.startStreaming(text: textContent, voiceId: recording.voiceId)
            lastPlayTime = Date()
            startTimer()
        }
    }
    
    /// Remove duplicate chapter title from the beginning of content for audio playback
    /// Checks if the first paragraph exactly matches the chapter name and removes it
    private func removeDuplicateChapterTitleInAudio(from text: String) -> String {
        guard let chapter = selectedChapter else { return text }
        
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let chapterTitle = chapter.title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Split by double newlines to get paragraphs
        let paragraphs = trimmedText.components(separatedBy: "\n\n")
        guard let firstParagraph = paragraphs.first else { return text }
        
        let firstParagraphTrimmed = firstParagraph.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check if first paragraph exactly matches the chapter title (case-insensitive)
        if firstParagraphTrimmed.lowercased() == chapterTitle.lowercased() {
            // Remove the first paragraph and rejoin the rest
            let remainingParagraphs = paragraphs.dropFirst()
            let result = remainingParagraphs.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
            print("🔧 Removed duplicate chapter title paragraph from audio content")
            return result
        }
        
        // Also check for common chapter heading patterns in the first line of first paragraph
        let lines = firstParagraph.components(separatedBy: .newlines)
        guard let firstLine = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return text
        }
        
        // Check if first line exactly matches chapter title (case-insensitive)
        if firstLine.lowercased() == chapterTitle.lowercased() {
            // Remove first line from first paragraph
            let remainingLines = lines.dropFirst()
            let modifiedFirstParagraph = remainingLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            
            // If there's remaining content in first paragraph, keep it
            if !modifiedFirstParagraph.isEmpty {
                var modifiedParagraphs = paragraphs
                modifiedParagraphs[0] = modifiedFirstParagraph
                let result = modifiedParagraphs.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
                print("🔧 Removed duplicate chapter title line from audio content")
                return result
            } else {
                // Otherwise remove entire first paragraph
                let remainingParagraphs = paragraphs.dropFirst()
                let result = remainingParagraphs.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
                print("🔧 Removed duplicate chapter title paragraph from audio content")
                return result
            }
        }
        
        // Check if first line looks like a chapter heading pattern
        let chapterPatterns = [
            "^CHAPTER\\s+\\d+",
            "^Chapter\\s+\\d+",
            "^CHAPTER\\s+[IVXLCDM]+",
            "^Chapter\\s+[IVXLCDM]+",
            "^\\d+\\.",
            "^[IVXLCDM]+\\."
        ]
        
        for pattern in chapterPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               regex.firstMatch(in: firstLine, range: NSRange(firstLine.startIndex..., in: firstLine)) != nil {
                // Remove the first line and return the rest
                let remainingLines = lines.dropFirst()
                let modifiedFirstParagraph = remainingLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                
                // If there's remaining content in first paragraph, keep it
                if !modifiedFirstParagraph.isEmpty {
                    var modifiedParagraphs = paragraphs
                    modifiedParagraphs[0] = modifiedFirstParagraph
                    let result = modifiedParagraphs.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
                    print("🔧 Removed chapter heading pattern from audio content")
                    return result
                } else {
                    // Otherwise remove entire first paragraph
                    let remainingParagraphs = paragraphs.dropFirst()
                    let result = remainingParagraphs.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
                    print("🔧 Removed chapter heading pattern paragraph from audio content")
                    return result
                }
            }
        }
        
        return text
    }
    
    private func togglePlayback() {
        if streamingManager.isPlaying {
            print("⏸️ Pausing playback")
            streamingManager.pause()
            stopTimer()
            updateSessionListeningTime()
            print("   Session listening time so far: \(Int(sessionListeningTime)) seconds")
        } else {
            print("▶️ Resuming playback")
            streamingManager.resume()
            startTimer()
            lastPlayTime = Date()
        }
    }
    
    private func stopPlayback() {
        if streamingManager.isPlaying {
            updateSessionListeningTime()
        }
        streamingManager.stop()
        stopTimer()
    }
    
    private func updateSessionListeningTime() {
        guard let lastPlay = lastPlayTime else {
            print("⚠️ No lastPlayTime set")
            return
        }
        let elapsed = Date().timeIntervalSince(lastPlay)
        sessionListeningTime += elapsed
        print("⏱️ Added \(Int(elapsed)) seconds. Total session time: \(Int(sessionListeningTime)) seconds")
        lastPlayTime = nil
    }
    
    private func saveListeningTime() {
        // Update session time if currently playing
        if streamingManager.isPlaying {
            updateSessionListeningTime()
        }
        
        // Save to Firestore if there's accumulated time
        guard sessionListeningTime > 0 else {
            print("⚠️ No listening time to save (sessionListeningTime: \(sessionListeningTime))")
            return
        }
        
        print("💾 Attempting to save \(Int(sessionListeningTime)) seconds of listening time...")
        
        // Create a detached task that won't be cancelled when view disappears
        Task.detached { [sessionListeningTime] in
            do {
                guard let userId = Auth.auth().currentUser?.uid else {
                    print("❌ No user logged in, cannot save listening time")
                    return
                }
                
                let db = Firestore.firestore()
                let userRef = db.collection("users").document(userId)
                let document = try await userRef.getDocument()
                
                if document.exists {
                    // Update existing listening time
                    try await userRef.updateData([
                        "totalListeningTime": FieldValue.increment(Int64(sessionListeningTime))
                    ])
                    print("✅ Successfully saved \(Int(sessionListeningTime)) seconds to Firestore")
                    print("   User ID: \(userId)")
                } else {
                    // Create user document with initial listening time
                    try await userRef.setData([
                        "totalListeningTime": sessionListeningTime,
                        "createdAt": FieldValue.serverTimestamp()
                    ])
                    print("✅ Created user document and saved \(Int(sessionListeningTime)) seconds")
                }
            } catch {
                print("❌ Error saving listening time: \(error.localizedDescription)")
            }
        }
    }
    
    private func rewind() {
        // TODO: Implement rewind for streaming audio (may need to track current audio position)
        print("⏪ Rewind not yet implemented for streaming audio")
    }
    
    private func forward() {
        // TODO: Implement forward for streaming audio (may need to track current audio position)
        print("⏩ Forward not yet implemented for streaming audio")
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            // Timer used for tracking session listening time
            // No need to update display time since we removed the time UI
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
}

// MARK: - Book Audio Player Delegate
class BookAudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    let onFinish: () -> Void
    
    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish()
    }
}

// MARK: - Voice Picker Sheet
struct VoicePickerSheet: View {
    let recordings: [VoiceRecording]
    @Binding var selectedRecording: VoiceRecording?
    let onSelect: (VoiceRecording) -> Void
    @Environment(\.dismiss) var dismiss
    
    private let primaryPink = Color(hex: "F9DAD2")
    private let secondaryPink = Color(hex: "F5B5A8")
    private let textPrimary = Color(hex: "0F172A")
    private let textSecondary = Color(hex: "475569")
    private let borderColor = Color(hex: "E5E7EB")
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if recordings.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        
                        Image(systemName: "mic.slash")
                            .font(.system(size: 48))
                            .foregroundColor(secondaryPink)
                        
                        Text("No Voice Recordings")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(textPrimary)
                        
                        Text("Please record your voice in the Record tab first")
                            .font(.system(size: 14))
                            .foregroundColor(textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        Spacer()
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(recordings) { recording in
                                Button(action: {
                                    onSelect(recording)
                                }) {
                                    HStack(spacing: 16) {
                                        ZStack {
                                            Circle()
                                                .fill(primaryPink)
                                                .frame(width: 56, height: 56)
                                            
                                            Image(systemName: "mic.fill")
                                                .font(.system(size: 24))
                                                .foregroundColor(secondaryPink)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(recording.name)
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(textPrimary)
                                            
                                            Text(recording.formattedDate)
                                                .font(.system(size: 13))
                                                .foregroundColor(textSecondary)
                                        }
                                        
                                        Spacer()
                                        
                                        if selectedRecording?.id == recording.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 24))
                                                .foregroundColor(secondaryPink)
                                        } else {
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 14))
                                                .foregroundColor(textSecondary)
                                        }
                                    }
                                    .padding(16)
                                    .background(Color.white)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(selectedRecording?.id == recording.id ? secondaryPink : borderColor, lineWidth: selectedRecording?.id == recording.id ? 2 : 1)
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(20)
                    }
                    .background(Color(hex: "F9FAFB"))
                }
            }
            .navigationTitle("Select Voice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Book Cover Image Component
struct BookCoverImage: View {
    let coverUrl: String
    
    private let bgTertiary = Color(hex: "F3F4F6")
    
    var body: some View {
        Group {
            // Trim whitespace and newlines for robust parsing
            let s = coverUrl.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Try to parse as URL first
            if let u = URL(string: s), let scheme = u.scheme {
                switch scheme.lowercased() {
                case "file":
                    // file:// URL
                    if let data = try? Data(contentsOf: u), let img = UIImage(data: data) {
                        Image(uiImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .cornerRadius(16)
                            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    } else {
                        let _ = print("⚠️ BookCoverImage: Failed to load file:// URL - \(coverUrl)")
                        placeholderCover
                    }
                    
                case "http", "https":
                    AsyncImage(url: u) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .cornerRadius(16)
                                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                        case .empty:
                            Rectangle()
                                .fill(bgTertiary)
                                .aspectRatio(2/3, contentMode: .fit)
                                .cornerRadius(16)
                                .overlay(ProgressView())
                        case .failure(let error):
                            let _ = print("⚠️ BookCoverImage: Failed to load remote URL - \(coverUrl), error: \(error)")
                            placeholderCover
                        @unknown default:
                            let _ = print("⚠️ BookCoverImage: Unknown AsyncImage phase for URL - \(coverUrl)")
                            placeholderCover
                        }
                    }
                    
                default:
                    let _ = print("⚠️ BookCoverImage: Unknown URL scheme - \(coverUrl)")
                    placeholderCover
                }
                
            } else if s.hasPrefix("/") {
                // Plain filesystem path like /var/.../cover.png
                if let img = UIImage(contentsOfFile: s) {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                } else {
                    let _ = print("⚠️ BookCoverImage: Failed to load filesystem path - \(coverUrl)")
                    placeholderCover
                }
                
            } else if let asset = UIImage(named: s) {
                // Asset bundle image (e.g., "BookCovers/alice-wonderland.png")
                Image(uiImage: asset)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
            } else if let bundlePath = Bundle.main.path(forResource: s, ofType: nil),
                      let image = UIImage(contentsOfFile: bundlePath) {
                // Try loading with Bundle.main.path (alternative for bundled resources)
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
            } else if let bundleResourcePath = Bundle.main.resourcePath {
                // Final fallback - try with full bundle resource path
                let fullPath = (bundleResourcePath as NSString).appendingPathComponent(s)
                if let image = UIImage(contentsOfFile: fullPath) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                } else {
                    let _ = print("⚠️ BookCoverImage: Could not load cover image as URL, file path, or asset - \(coverUrl)")
                    placeholderCover
                }
            } else {
                let _ = print("⚠️ BookCoverImage: Could not load cover image as URL, file path, or asset - \(coverUrl)")
                placeholderCover
            }
        }
    }
    
    private var placeholderCover: some View {
        Rectangle()
            .fill(bgTertiary)
            .aspectRatio(2/3, contentMode: .fit)
            .cornerRadius(16)
            .overlay(
                VStack(spacing: 8) {
                    Image(systemName: "book.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.gray.opacity(0.5))
                    Text("No Cover")
                        .font(.system(size: 14))
                        .foregroundColor(.gray.opacity(0.5))
                }
            )
    }
}


