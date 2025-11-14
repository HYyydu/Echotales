import SwiftUI
import PhotosUI
import FirebaseFirestore
import FirebaseAuth

struct ShelfView: View {
    @State private var userBooks: [UserBook] = []
    @State private var shelfBooks: [ShelfBook] = []
    @State private var showImportSheet = false
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var isEditMode = false
    @State private var isLoadingShelfBooks = true
    
    // Design tokens
    private let primaryPink = Color(hex: "F9DAD2")
    private let secondaryPink = Color(hex: "F5B5A8")
    private let textPrimary = Color(hex: "0F172A")
    private let textSecondary = Color(hex: "475569")
    private let borderColor = Color(hex: "E5E7EB")
    private let bgGray = Color(hex: "F9FAFB")
    
    var body: some View {
        NavigationStack {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("My Bookshelf")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(textPrimary)
                
                Spacer()
                
                if !userBooks.isEmpty || !shelfBooks.isEmpty {
                    Button(action: {
                        isEditMode.toggle()
                    }) {
                        Text(isEditMode ? "Done" : "Select")
                            .font(.system(size: 16))
                            .foregroundColor(textSecondary)
                    }
                }
                
                // Import Button
                Button(action: {
                    showImportSheet = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Import")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(secondaryPink)
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20) // Clear status bar
            .padding(.bottom, 16)
            .background(Color.white)
            
            // Book Count or Empty State
            if userBooks.isEmpty && shelfBooks.isEmpty {
                // Empty State
                VStack(spacing: 24) {
                    Spacer()
                    
                    Image(systemName: "books.vertical")
                        .font(.system(size: 80))
                        .foregroundColor(primaryPink.opacity(0.5))
                    
                    VStack(spacing: 8) {
                        Text("No Books Yet")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(textPrimary)
                        
                        Text("Import your first book to get started")
                            .font(.system(size: 16))
                            .foregroundColor(textSecondary)
                    }
                    
                    Button(action: {
                        showImportSheet = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20))
                            Text("Import Book")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(secondaryPink)
                        .cornerRadius(12)
                    }
                    
                    Spacer()
                }
                .offset(y: -100)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(bgGray)
            } else {
                // Books Grid
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        let totalCount = userBooks.count + shelfBooks.count
                        Text("\(totalCount) \(totalCount == 1 ? "book" : "books") in your shelf")
                            .font(.system(size: 14))
                            .foregroundColor(textSecondary)
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 12, alignment: .top),
                            GridItem(.flexible(), spacing: 12, alignment: .top),
                            GridItem(.flexible(), spacing: 12, alignment: .top)
                        ], alignment: .leading, spacing: 12) {
                            // Shelf Books from Library
                            ForEach(shelfBooks) { book in
                                if isEditMode {
                                    ShelfBookCard(
                                        book: book,
                                        isEditMode: isEditMode,
                                        onDelete: {
                                            deleteShelfBook(book)
                                        }
                                    )
                                } else {
                                    NavigationLink(destination: ShelfBookDetailsWrapper(shelfBook: book)) {
                                        ShelfBookCard(
                                            book: book,
                                            isEditMode: isEditMode,
                                            onDelete: {
                                                deleteShelfBook(book)
                                            }
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            
                            // User Imported Books
                            ForEach(userBooks) { book in
                                if isEditMode {
                                    UserBookCard(
                                        book: book,
                                        isEditMode: isEditMode,
                                        onDelete: {
                                            deleteBook(book)
                                        }
                                    )
                                } else {
                                    NavigationLink(destination: UserBookReaderView(book: book)) {
                                        UserBookCard(
                                            book: book,
                                            isEditMode: isEditMode,
                                            onDelete: {
                                                deleteBook(book)
                                            }
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
                }
                .refreshable {
                    loadShelfBooks()
                }
                .background(bgGray)
            }
        }
        .sheet(isPresented: $showImportSheet) {
            ImportBookSheet(
                onImport: { title, author, coverImage, content, fileType in
                    addBook(title: title, author: author, coverImage: coverImage, content: content, fileType: fileType)
                }
            )
        }
        .onAppear {
            loadShelfBooks()
        }
        }
    }
    
    // Add book
    private func addBook(title: String, author: String, coverImage: UIImage?, content: String?, fileType: String?) {
        let newBook = UserBook(
            id: UUID().uuidString,
            title: title,
            author: author,
            coverImage: coverImage,
            addedDate: Date(),
            content: content,
            fileType: fileType
        )
        userBooks.append(newBook)
        showImportSheet = false
    }
    
    // Delete book
    private func deleteBook(_ book: UserBook) {
        userBooks.removeAll { $0.id == book.id }
    }
    
    // Load shelf books from Firebase
    private func loadShelfBooks() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("⚠️ ShelfView: No authenticated user found")
            isLoadingShelfBooks = false
            return
        }
        
        print("📚 ShelfView: Loading shelf books for user: \(userId)")
        
        let db = Firestore.firestore()
        
        // Note: Ordering requires a composite index in Firestore
        // To enable ordering, create a composite index: userId (Ascending) + addedAt (Descending)
        // See the error message in Xcode console for a direct link to create the index
        db.collection("userShelfBooks")
            .whereField("userId", isEqualTo: userId)
            // .order(by: "addedAt", descending: true)  // Uncomment after creating the composite index
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    isLoadingShelfBooks = false
                }
                
                if let error = error {
                    print("❌ ShelfView: Error loading books: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("⚠️ ShelfView: No documents found")
                    return
                }
                
                print("📖 ShelfView: Found \(documents.count) documents matching userId")
                
                let fetchedBooks = documents.compactMap { doc -> ShelfBook? in
                    let data = doc.data()
                    
                    guard let bookId = data["bookId"] as? String,
                          let title = data["title"] as? String,
                          let author = data["author"] as? String,
                          let timestamp = data["addedAt"] as? Timestamp else {
                        print("⚠️ ShelfView: Skipping document with invalid data: \(doc.documentID)")
                        print("   - bookId: \(data["bookId"] != nil)")
                        print("   - title: \(data["title"] != nil)")
                        print("   - addedAt: \(data["addedAt"] != nil)")
                        return nil
                    }
                    
                    // Get EPUB URL or generate it for bundled books (backwards compatibility)
                    var epubUrl = data["epubUrl"] as? String
                    var coverUrl = data["coverUrl"] as? String  // Optional: can be nil
                    
                    // Fix epubUrl if missing/invalid
                    let epubNeedsUpdate = epubUrl == nil || epubUrl!.isEmpty || epubUrl!.hasPrefix("bundle://")
                    if epubNeedsUpdate {
                        // Missing or invalid epubUrl - try to reconstruct from catalog
                        print("⚠️ ShelfView: Missing/invalid epubUrl for '\(title)', attempting to reconstruct")
                        
                        // Try to construct the proper storage URL
                        epubUrl = "epubs/\(bookId).epub"
                        print("   - Using storage path: \(epubUrl!)")
                        
                        // Update Firebase with corrected epubUrl
                        doc.reference.updateData(["epubUrl": epubUrl!]) { error in
                            if let error = error {
                                print("⚠️ ShelfView: Failed to update epubUrl in Firebase: \(error)")
                            } else {
                                print("✅ ShelfView: Updated epubUrl in Firebase for '\(title)'")
                            }
                        }
                    }
                    
                    // Fix coverUrl if missing, empty, or stale filesystem path
                    let needsCoverReconstruction: Bool
                    if let cover = coverUrl, !cover.isEmpty {
                        // Check if it's a stale filesystem path (starts with / but file doesn't exist)
                        if cover.hasPrefix("/") {
                            needsCoverReconstruction = !FileManager.default.fileExists(atPath: cover)
                            if needsCoverReconstruction {
                                print("⚠️ ShelfView: Stale coverUrl detected for '\(title)': \(cover)")
                            }
                        } else if cover.hasPrefix("book-placeholder") || cover.hasPrefix("bundle://") {
                            needsCoverReconstruction = true
                        } else {
                            needsCoverReconstruction = false
                        }
                    } else {
                        needsCoverReconstruction = true
                    }
                    
                    // Reconstruct cover URL if needed
                    if needsCoverReconstruction {
                        // Use bundled cover (matches catalog naming: bookId.png)
                        coverUrl = "BookCovers/\(bookId).png"
                        print("   - Reconstructing cover path: \(coverUrl!)")
                        
                        // Update Firebase with corrected coverUrl
                        doc.reference.updateData(["coverUrl": coverUrl!]) { error in
                            if let error = error {
                                print("⚠️ ShelfView: Failed to update coverUrl in Firebase: \(error)")
                            } else {
                                print("✅ ShelfView: Updated coverUrl in Firebase for '\(title)'")
                            }
                        }
                    }
                    
                    // Parse optional fields with defaults
                    let age = data["age"] as? String ?? "all"
                    let genre = data["genre"] as? String ?? "Adventure"
                    let tags = data["tags"] as? [String] ?? []
                    
                    print("✅ ShelfView: Loaded book: \(title)")
                    print("   - EPUB URL: \(epubUrl!)")
                    print("   - Cover URL: \(coverUrl ?? "nil")")
                    
                    return ShelfBook(
                        id: doc.documentID,
                        bookId: bookId,
                        title: title,
                        author: author,
                        epubUrl: epubUrl!,
                        coverUrl: coverUrl,  // Optional
                        age: age,
                        genre: genre,
                        tags: tags,
                        addedDate: timestamp.dateValue()
                    )
                }
                
                DispatchQueue.main.async {
                    print("📚 ShelfView: Setting \(fetchedBooks.count) books to display")
                    self.shelfBooks = fetchedBooks
                    
                    // Download shelf books to permanent storage if needed (background operation)
                    Task {
                        await self.ensureShelfBooksAreDownloaded(fetchedBooks)
                    }
                }
            }
    }
    
    /// Ensure shelf books are downloaded to permanent storage (background operation)
    private func ensureShelfBooksAreDownloaded(_ books: [ShelfBook]) async {
        print("📥 ShelfView: Checking if shelf books need to be downloaded permanently")
        
        // Load cloud catalog to get metadata
        guard let catalog = await CloudBookService.shared.loadCloudCatalog() else {
            print("⚠️ ShelfView: Could not load catalog for downloading")
            return
        }
        
        for book in books {
            // Skip if already downloaded
            if CloudBookService.shared.isBookDownloaded(bookId: book.bookId) {
                continue
            }
            
            // Skip bundled books (they don't need downloading)
            if book.epubUrl.hasPrefix("file://") || book.epubUrl.hasPrefix("bundle://") {
                continue
            }
            
            // Find metadata in catalog
            guard let metadata = catalog.books.first(where: { $0.id == book.bookId }) else {
                print("⚠️ ShelfView: Book '\(book.title)' not found in catalog")
                continue
            }
            
            print("📥 ShelfView: Downloading '\(book.title)' to permanent storage")
            
            // Check if in streaming cache - move to permanent
            if let streamingURL = StreamingEPUBService.shared.getStreamingBookURL(bookId: book.bookId) {
                do {
                    try await StreamingEPUBService.shared.saveForOffline(metadata: metadata)
                    print("✅ ShelfView: Moved '\(book.title)' from streaming to permanent storage")
                    continue
                } catch {
                    print("⚠️ ShelfView: Failed to move from streaming: \(error)")
                }
            }
            
            // Download to permanent storage
            do {
                _ = try await CloudBookService.shared.downloadBook(metadata: metadata)
                print("✅ ShelfView: Downloaded '\(book.title)' to permanent storage")
            } catch {
                print("⚠️ ShelfView: Failed to download '\(book.title)': \(error)")
            }
        }
    }
    
    // Delete shelf book from Firebase
    private func deleteShelfBook(_ book: ShelfBook) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        db.collection("userShelfBooks").document(book.id).delete { error in
            if error == nil {
                DispatchQueue.main.async {
                    shelfBooks.removeAll { $0.id == book.id }
                }
                
                // Delete permanently downloaded book to free up space
                Task {
                    if CloudBookService.shared.isBookDownloaded(bookId: book.bookId) {
                        do {
                            try CloudBookService.shared.deleteDownloadedBook(bookId: book.bookId)
                            print("✅ ShelfView: Deleted permanent download for '\(book.title)'")
                        } catch {
                            print("⚠️ ShelfView: Failed to delete permanent download: \(error)")
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Shelf Book Model (from Library)
struct ShelfBook: Identifiable {
    let id: String
    let bookId: String
    let title: String
    let author: String
    let epubUrl: String  // NEW: Firebase Storage URL for EPUB file
    let coverUrl: String? // Optional: Will be extracted from EPUB
    let age: String
    let genre: String
    let tags: [String]
    let addedDate: Date
    
    // Convert to Book for navigation
    func toBook(withCoverUrl dynamicCoverUrl: String?) -> Book {
        return Book(
            id: bookId,
            title: title,
            author: author,
            age: age,
            genre: genre,
            coverUrl: dynamicCoverUrl ?? coverUrl ?? "book-placeholder",
            tags: tags,
            textContent: nil,
            chapters: []
        )
    }
}

// MARK: - User Book Model (imported)
struct UserBook: Identifiable {
    let id: String
    let title: String
    let author: String
    let coverImage: UIImage?
    let addedDate: Date
    let content: String? // Document text content
    let fileType: String? // pdf, txt, doc, etc.
}

// MARK: - Shelf Book Card (from Library)
struct ShelfBookCard: View {
    let book: ShelfBook
    let isEditMode: Bool
    let onDelete: () -> Void
    
    // Design tokens (matching BookCard)
    private let tagText = Color(hex: "6B4C41")
    private let primaryPink = Color(hex: "F9DAD2")
    
    @State private var extractedCoverUrl: String? = nil
    @State private var isExtractingCover = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Cover Image with URL support
            GeometryReader { geometry in
                ZStack(alignment: .topTrailing) {
                    // Load actual cover image or show colored placeholder
                    if let coverUrl = extractedCoverUrl ?? book.coverUrl, !coverUrl.isEmpty {
                        // Try different loading strategies based on the URL type
                        if coverUrl.hasPrefix("/") {
                            // Filesystem path (e.g., cached EPUB cover)
                            // Check if file actually exists (could be stale path from old container)
                            if FileManager.default.fileExists(atPath: coverUrl),
                               let image = UIImage(contentsOfFile: coverUrl) {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: geometry.size.width, height: geometry.size.height)
                                    .clipped()
                            } else {
                                // File doesn't exist (stale path) - try bundled cover instead
                                if let bundlePath = Bundle.main.path(forResource: "BookCovers/\(book.bookId)", ofType: "png"),
                                   let image = UIImage(contentsOfFile: bundlePath) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: geometry.size.width, height: geometry.size.height)
                                        .clipped()
                                } else if let bundleResourcePath = Bundle.main.resourcePath {
                                    let fullPath = (bundleResourcePath as NSString).appendingPathComponent("BookCovers/\(book.bookId).png")
                                    if let image = UIImage(contentsOfFile: fullPath) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: geometry.size.width, height: geometry.size.height)
                                            .clipped()
                                    } else {
                                        Rectangle()
                                            .fill(Color(hex: getRandomColor()))
                                    }
                                } else {
                                    Rectangle()
                                        .fill(Color(hex: getRandomColor()))
                                }
                            }
                        } else if coverUrl.hasPrefix("http://") || coverUrl.hasPrefix("https://") || coverUrl.hasPrefix("gs://") {
                            // Remote URL - use AsyncImage
                            if let url = URL(string: coverUrl) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .empty:
                                        Rectangle()
                                            .fill(Color(hex: getRandomColor()))
                                            .overlay(
                                                ProgressView()
                                                    .tint(.white)
                                            )
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: geometry.size.width, height: geometry.size.height)
                                            .clipped()
                                    case .failure(_):
                                        Rectangle()
                                            .fill(Color(hex: getRandomColor()))
                                    @unknown default:
                                        Rectangle()
                                            .fill(Color(hex: getRandomColor()))
                                    }
                                }
                            } else {
                                Rectangle()
                                    .fill(Color(hex: getRandomColor()))
                            }
                        } else {
                            // Bundled resource path (e.g., "BookCovers/alice-wonderland.png")
                            if let bundlePath = Bundle.main.path(forResource: coverUrl, ofType: nil),
                               let image = UIImage(contentsOfFile: bundlePath) {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: geometry.size.width, height: geometry.size.height)
                                    .clipped()
                            } else if let bundleResourcePath = Bundle.main.resourcePath {
                                // Try direct path in bundle
                                let fullPath = (bundleResourcePath as NSString).appendingPathComponent(coverUrl)
                                if let image = UIImage(contentsOfFile: fullPath) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: geometry.size.width, height: geometry.size.height)
                                        .clipped()
                                } else {
                                    Rectangle()
                                        .fill(Color(hex: getRandomColor()))
                                }
                            } else {
                                Rectangle()
                                    .fill(Color(hex: getRandomColor()))
                            }
                        }
                    } else {
                        // No URL, show colored placeholder
                        Rectangle()
                            .fill(Color(hex: getRandomColor()))
                    }
                    
                    // Delete Button (Edit Mode only)
                    if isEditMode {
                        Button(action: onDelete) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.red)
                                .background(
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 24, height: 24)
                                )
                        }
                        .padding(8)
                    }
                }
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 3)
            }
            .aspectRatio(2/3, contentMode: .fit) // Fixed 2:3 aspect ratio
            
            // Title only (tag removed)
            VStack(alignment: .leading, spacing: 0) {
                // Title
                Text(book.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(hex: "0F172A"))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .task {
            // Skip extraction if we already have a cover URL or are currently extracting
            guard extractedCoverUrl == nil && !isExtractingCover else { return }
            
            // If book already has a valid coverUrl (bundled cover), don't extract from EPUB
            if let coverUrl = book.coverUrl, !coverUrl.isEmpty {
                // Check if it's a bundled cover path
                if !coverUrl.hasPrefix("http://") && !coverUrl.hasPrefix("https://") && !coverUrl.hasPrefix("/") {
                    print("📚 ShelfBookCard: Using bundled cover for '\(book.title)': \(coverUrl)")
                    // Don't need to extract - the cover will load directly from bundle
                    return
                }
                
                // If it's a filesystem path, check if it exists
                if coverUrl.hasPrefix("/") {
                    if FileManager.default.fileExists(atPath: coverUrl) {
                        print("📚 ShelfBookCard: Using cached cover for '\(book.title)': \(coverUrl)")
                        return
                    } else {
                        print("⚠️ ShelfBookCard: Stale cached cover path detected for '\(book.title)', will update")
                        // Continue to extraction to get fresh cover
                    }
                }
            }
            
            // Only extract from EPUB if we don't have a cover URL
            isExtractingCover = true
            print("📚 ShelfBookCard: No cover URL found, extracting from EPUB for '\(book.title)'")
            print("   - EPUB URL: \(book.epubUrl)")
            
            // Check if it's a bundled book (local file) or Firebase book
            if book.epubUrl.hasPrefix("file://") || book.epubUrl.hasPrefix("bundle://") {
                // Bundled book - try to extract cover from local EPUB
                print("📦 ShelfBookCard: Bundled EPUB detected, extracting cover")
                
                if let coverUrl = extractCoverFromBundledBook(bookId: book.bookId) {
                    print("✅ ShelfBookCard: Cover extracted from bundle: \(coverUrl)")
                    await MainActor.run {
                        extractedCoverUrl = coverUrl
                    }
                } else {
                    print("⚠️ ShelfBookCard: Failed to extract cover from bundled EPUB")
                }
            } else {
                // Firebase book - extract cover (will check permanent/temp storage first)
                print("☁️ ShelfBookCard: Cloud book detected, extracting cover")
                
                if let coverUrl = await FirebaseEPUBService.shared.extractCoverFromFirebaseEPUB(storageUrl: book.epubUrl, bookId: book.bookId) {
                    print("✅ ShelfBookCard: Cover extracted from cloud EPUB: \(coverUrl)")
                    await MainActor.run {
                        extractedCoverUrl = coverUrl
                    }
                } else {
                    print("⚠️ ShelfBookCard: Failed to extract cover from cloud EPUB")
                }
            }
            
            isExtractingCover = false
        }
    }
    
    /// Extract cover from a bundled EPUB file
    private func extractCoverFromBundledBook(bookId: String) -> String? {
        // Try to get the EPUB file from the bundle
        guard let epubURL = Bundle.main.url(forResource: bookId, withExtension: "epub") else {
            print("❌ ShelfBookCard: Bundled EPUB not found for bookId: \(bookId)")
            return nil
        }
        
        // Parse the EPUB and extract cover
        guard let epubContent = EPUBParser.parseEPUB(at: epubURL) else {
            print("❌ ShelfBookCard: Failed to parse bundled EPUB")
            return nil
        }
        
        return epubContent.coverImageURL
    }
    
    private func getRandomColor() -> String {
        let colors = ["8B5CF6", "EC4899", "10B981", "F59E0B", "3B82F6", "EF4444", "06B6D4", "84CC16", "6366F1"]
        return colors[abs(book.id.hashValue) % colors.count]
    }
}

// MARK: - User Book Card (imported)
struct UserBookCard: View {
    let book: UserBook
    let isEditMode: Bool
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topTrailing) {
                // Cover Image
                if let coverImage = book.coverImage {
                    Image(uiImage: coverImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 240)
                        .clipped()
                        .cornerRadius(12)
                } else {
                    // Placeholder
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(
                            colors: [Color(hex: "8B5CF6"), Color(hex: "EC4899")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(height: 240)
                        .overlay(
                            Image(systemName: "book.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.white.opacity(0.7))
                        )
                }
                
                // Delete Button (Edit Mode)
                if isEditMode {
                    Button(action: onDelete) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.red)
                            .background(
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 24, height: 24)
                            )
                    }
                    .padding(8)
                }
            }
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            
            // Book Info
            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "0F172A"))
                    .lineLimit(2)
                
                Text(book.author)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "6B7280"))
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - Import Book Sheet
struct ImportBookSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedDocumentURL: URL?
    @State private var showDocumentPicker = false
    @State private var isProcessing = false
    @State private var processedDocument: DocumentProcessor.ProcessedDocument?
    @State private var bookTitle = ""
    @State private var bookAuthor = ""
    @State private var coverImage: UIImage?
    @State private var errorMessage: String?
    @State private var showManualEntry = false
    
    let onImport: (String, String, UIImage?, String?, String?) -> Void
    
    // Design tokens
    private let primaryPink = Color(hex: "F9DAD2")
    private let secondaryPink = Color(hex: "F5B5A8")
    private let textPrimary = Color(hex: "0F172A")
    private let textSecondary = Color(hex: "475569")
    private let textTertiary = Color(hex: "6B7280")
    private let bgGray = Color(hex: "F9FAFB")
    
    var body: some View {
        NavigationView {
            ZStack {
                bgGray.ignoresSafeArea()
                
                if let processed = processedDocument {
                    // Document Preview & Edit View
                    documentPreviewView(processed)
                } else {
                    // Document Selection View
                    documentSelectionView
                }
                
                // Processing Overlay
                if isProcessing {
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)
                            
                            Text("Processing document...")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .padding(32)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(hex: "0F172A"))
                        )
                    }
                }
            }
            .navigationTitle(processedDocument == nil ? "Import Document" : "Review & Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(processedDocument == nil ? "Cancel" : "Back") {
                        if processedDocument != nil {
                            processedDocument = nil
                            errorMessage = nil
                        } else {
                            dismiss()
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPicker(selectedDocument: $selectedDocumentURL)
        }
        .onChange(of: selectedDocumentURL) { newURL in
            if let url = newURL {
                processDocument(url: url)
            }
        }
    }
    
    // MARK: - Document Selection View
    private var documentSelectionView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Icon
            ZStack {
                Circle()
                    .fill(primaryPink.opacity(0.3))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 56))
                    .foregroundColor(secondaryPink)
            }
            
            // Title & Description
            VStack(spacing: 12) {
                Text("Import Your Book")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(textPrimary)
                
                Text("Select a document from your device or iCloud Drive")
                    .font(.system(size: 16))
                    .foregroundColor(textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            // Supported Formats
            VStack(spacing: 12) {
                Text("Supported Formats")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(textTertiary)
                    .textCase(.uppercase)
                    .tracking(1)
                
                HStack(spacing: 12) {
                    FormatBadge(format: "PDF", icon: "doc.fill")
                    FormatBadge(format: "TXT", icon: "doc.text")
                    FormatBadge(format: "RTF", icon: "doc.richtext")
                    FormatBadge(format: "DOC", icon: "doc")
                }
            }
            
            Spacer()
            
            // Error Message
            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 14))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.red.opacity(0.1))
                    )
                    .padding(.horizontal, 24)
            }
            
            // Action Button
            Button(action: {
                showDocumentPicker = true
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 20))
                    Text("Choose Document")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(secondaryPink)
                .cornerRadius(12)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
    
    // MARK: - Document Preview View
    private func documentPreviewView(_ document: DocumentProcessor.ProcessedDocument) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Cover Preview
                if let cover = coverImage {
                    Image(uiImage: cover)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 160, height: 240)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(
                            colors: [primaryPink, secondaryPink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 160, height: 240)
                        .overlay(
                            Image(systemName: "book.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.white.opacity(0.7))
                        )
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                }
                
                // Document Info Badge
                HStack(spacing: 8) {
                    Image(systemName: "doc.fill")
                        .font(.system(size: 12))
                        .foregroundColor(secondaryPink)
                    
                    Text(document.fileType.uppercased())
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(secondaryPink)
                    
                    Text("•")
                        .foregroundColor(textTertiary)
                    
                    Text("\(document.content.split(separator: " ").count) words")
                        .font(.system(size: 12))
                        .foregroundColor(textTertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(primaryPink.opacity(0.3))
                .cornerRadius(20)
                
                // Form Fields
                VStack(spacing: 20) {
                    // Title Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Title")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(textSecondary)
                        
                        TextField("Book title", text: $bookTitle)
                            .textFieldStyle(RoundedTextFieldStyle())
                    }
                    
                    // Author Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Author")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(textSecondary)
                        
                        TextField("Author name", text: $bookAuthor)
                            .textFieldStyle(RoundedTextFieldStyle())
                    }
                }
                .padding(.horizontal, 24)
                
                // Content Preview
                VStack(alignment: .leading, spacing: 12) {
                    Text("Content Preview")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(textSecondary)
                    
                    Text(String(document.content.prefix(300)) + "...")
                        .font(.system(size: 14))
                        .foregroundColor(textTertiary)
                        .lineLimit(6)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 24)
                
                // Import Button
                Button(action: {
                    if !bookTitle.isEmpty && !bookAuthor.isEmpty {
                        onImport(bookTitle, bookAuthor, coverImage, document.content, document.fileType)
                        dismiss()
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                        Text("Add to My Shelf")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(bookTitle.isEmpty || bookAuthor.isEmpty ? Color.gray : secondaryPink)
                    .cornerRadius(12)
                }
                .disabled(bookTitle.isEmpty || bookAuthor.isEmpty)
                .padding(.horizontal, 24)
                .padding(.top, 8)
            }
            .padding(.vertical, 24)
        }
    }
    
    // MARK: - Process Document
    private func processDocument(url: URL) {
        isProcessing = true
        errorMessage = nil
        
        // Get user's name from Auth
        let userName = Auth.auth().currentUser?.displayName ?? "Me"
        
        DispatchQueue.global(qos: .userInitiated).async {
            if let processed = DocumentProcessor.processDocument(url: url, userDisplayName: userName) {
                DispatchQueue.main.async {
                    self.processedDocument = processed
                    self.bookTitle = processed.title
                    self.bookAuthor = userName
                    self.coverImage = processed.coverImage ?? DocumentProcessor.generateDefaultCover(title: processed.title)
                    self.isProcessing = false
                }
            } else {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to process document. Please make sure it's a valid PDF, TXT, RTF, or DOC file."
                    self.isProcessing = false
                }
            }
        }
    }
}

// MARK: - Format Badge
struct FormatBadge: View {
    let format: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(Color(hex: "F5B5A8"))
            
            Text(format)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color(hex: "6B7280"))
        }
        .frame(width: 65, height: 65)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
        )
    }
}

// MARK: - Custom TextField Style
struct RoundedTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(12)
            .background(Color(hex: "F9FAFB"))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
            )
    }
}

// MARK: - Image Picker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - User Book Reader View
struct UserBookReaderView: View {
    let book: UserBook
    @Environment(\.dismiss) var dismiss
    @State private var fontSize: CGFloat = 18
    @State private var currentPage: Int = 0
    @State private var pages: [String] = []
    @State private var showControls: Bool = true
    
    // Design tokens
    private let textPrimary = Color(hex: "0F172A")
    private let textSecondary = Color(hex: "475569")
    private let bgSecondary = Color(hex: "F9FAFB")
    
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
                                            Text(book.title)
                                                .font(.system(size: 28, weight: .bold))
                                                .foregroundColor(textPrimary)
                                                .padding(.bottom, 4)
                                            
                                            Text("by \(book.author)")
                                                .font(.system(size: 16))
                                                .foregroundColor(textSecondary)
                                                .padding(.bottom, 8)
                                            
                                            Divider().padding(.bottom, 8)
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
                                    .padding(.top, 60)
                                }
                                .contentMargins(.bottom, max(24, geo.safeAreaInsets.bottom + 8), for: .scrollContent)
                                .scrollIndicators(.hidden)
                                .background(Color(.systemBackground))
                                .tag(index)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                    } else if let content = book.content, !content.isEmpty {
                        // Loading state
                        VStack {
                            ProgressView()
                                .tint(textSecondary)
                            Text("Loading...")
                                .font(.system(size: 16))
                                .foregroundColor(textSecondary)
                                .padding(.top, 8)
                        }
                    } else {
                        // No content state
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 48))
                                .foregroundColor(textSecondary.opacity(0.5))
                            
                            Text("No content available")
                                .font(.system(size: 16))
                                .foregroundColor(textSecondary)
                        }
                    }
                }
                
                // Top Controls Overlay
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
                    
                    // Bottom page indicator
                    if showControls && !pages.isEmpty {
                        HStack(spacing: 8) {
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
                        }
                        .padding(.bottom, 40)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(999)
                    }
                }
                .zIndex(998)
                
                // Invisible tap zones for navigation
                if !pages.isEmpty {
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
        }
        .navigationBarHidden(true)
        .statusBar(hidden: !showControls)
        .onAppear {
            generatePages()
            // Hide controls after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showControls = false
                }
            }
        }
    }
    
    private func generatePages() {
        guard let text = book.content, !text.isEmpty else {
            pages = []
            return
        }
        
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

// MARK: - Shelf Book Details Wrapper
// This wrapper fetches the full book data (including chapters) before showing BookDetailsView
struct ShelfBookDetailsWrapper: View {
    let shelfBook: ShelfBook
    
    @State private var fullBook: Book?
    @State private var cloudMetadata: CloudBookMetadata?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    // Design tokens
    private let bgSecondary = Color(hex: "F9FAFB")
    private let textSecondary = Color(hex: "475569")
    
    var body: some View {
        Group {
            if isLoading {
                // Loading state
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading book details...")
                        .font(.system(size: 16))
                        .foregroundColor(textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(bgSecondary)
            } else if let fullBook = fullBook {
                // Show full book details
                BookDetailsView(book: fullBook, voiceId: nil, cloudMetadata: cloudMetadata)
            } else {
                // Error state
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.red)
                    Text(errorMessage ?? "Failed to load book")
                        .font(.system(size: 16))
                        .foregroundColor(textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(bgSecondary)
            }
        }
        .onAppear {
            loadFullBook()
        }
    }
    
    private func loadFullBook() {
        Task {
            do {
                print("📖 ShelfBookDetailsWrapper: Extracting cover from EPUB for: \(shelfBook.title)")
                print("   - EPUB URL: \(shelfBook.epubUrl)")
                
                // Extract cover based on book type (bundled vs Firebase)
                let extractedCoverUrl: String?
                
                if shelfBook.epubUrl.hasPrefix("file://") || shelfBook.epubUrl.hasPrefix("bundle://") {
                    // Bundled book - extract cover directly from local EPUB
                    print("📦 ShelfBookDetailsWrapper: Bundled book detected")
                    extractedCoverUrl = extractCoverFromBundledBook(bookId: shelfBook.bookId)
                } else {
                    // Firebase book - use FirebaseEPUBService (will check permanent/temp storage)
                    print("☁️ ShelfBookDetailsWrapper: Firebase book detected")
                    extractedCoverUrl = await FirebaseEPUBService.shared.extractCoverFromFirebaseEPUB(storageUrl: shelfBook.epubUrl, bookId: shelfBook.bookId)
                }
                
                if let coverUrl = extractedCoverUrl {
                    print("✅ ShelfBookDetailsWrapper: Cover extracted: \(coverUrl)")
                } else {
                    print("⚠️ ShelfBookDetailsWrapper: Failed to extract cover")
                }
                
                print("📖 ShelfBookDetailsWrapper: Fetching full book data for bookId: \(shelfBook.bookId)")
                
                // Load book from cloud catalog (all books are now cloud books)
                print("☁️ ShelfBookDetailsWrapper: Loading cloud book from catalog")
                let cloudService = CloudBookService.shared
                
                // Load cloud catalog
                guard let catalog = await cloudService.loadCloudCatalog() else {
                    await MainActor.run {
                        errorMessage = "Failed to load book catalog"
                        isLoading = false
                    }
                    return
                }
                
                // Find the book in catalog
                guard let cloudBook = catalog.books.first(where: { $0.id == shelfBook.bookId }) else {
                    await MainActor.run {
                        errorMessage = "Book not found in catalog"
                        isLoading = false
                    }
                    return
                }
                
                // Stream the book (don't force download)
                let streamingService = StreamingEPUBService.shared
                let epubContent: EPUBContent
                do {
                    epubContent = try await streamingService.loadBookForStreaming(metadata: cloudBook)
                } catch {
                    await MainActor.run {
                        errorMessage = "Failed to load book: \(error.localizedDescription)"
                        isLoading = false
                    }
                    return
                }
                
                // Convert to Book model
                // Priority: Use cached cover from EPUBContent > extracted cover > catalog cover
                let finalCoverUrl = epubContent.coverImageURL ?? extractedCoverUrl ?? cloudBook.coverImageUrl ?? ""
                print("   - Using cover URL: \(finalCoverUrl)")
                
                let book = Book(
                    id: cloudBook.id,
                    title: cloudBook.title,
                    author: cloudBook.author,
                    age: cloudBook.age,
                    genre: cloudBook.genre,
                    coverUrl: finalCoverUrl,
                    tags: cloudBook.tags,
                    textContent: nil,
                    chapters: epubContent.chapters,
                    coverImageURL: finalCoverUrl
                )
                
                await MainActor.run {
                    self.fullBook = book
                    self.cloudMetadata = cloudBook // Store cloud metadata for downloads
                    self.isLoading = false
                    print("✅ ShelfBookDetailsWrapper: Successfully loaded book with \(book.chapters.count) chapters")
                    print("   - Final Cover URL: \(finalCoverUrl)")
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Error loading book: \(error.localizedDescription)"
                    self.isLoading = false
                    print("❌ ShelfBookDetailsWrapper: Error loading book: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Extract cover from a bundled EPUB file
    private func extractCoverFromBundledBook(bookId: String) -> String? {
        // Try to get the EPUB file from the bundle
        guard let epubURL = Bundle.main.url(forResource: bookId, withExtension: "epub") else {
            print("❌ ShelfBookDetailsWrapper: Bundled EPUB not found for bookId: \(bookId)")
            return nil
        }
        
        // Parse the EPUB and extract cover
        guard let epubContent = EPUBParser.parseEPUB(at: epubURL) else {
            print("❌ ShelfBookDetailsWrapper: Failed to parse bundled EPUB")
            return nil
        }
        
        return epubContent.coverImageURL
    }
}

#Preview {
    ShelfView()
}

