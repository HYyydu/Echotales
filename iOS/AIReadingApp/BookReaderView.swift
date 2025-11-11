import SwiftUI
import FirebaseFirestore

// MARK: - BookReaderView (Enhanced with Cloud Books + Downloads)
struct BookReaderView: View {
    let voiceId: String?
    
    @State private var cloudBooks: [CloudBookMetadata] = [] // All books (now from cloud catalog)
    @State private var filteredCloudBooks: [CloudBookMetadata] = [] // Filtered cloud books to display
    @State private var displayedBooks: [CloudBookMetadata] = [] // Random 6 books when no filters
    @State private var selectedGenre: String = "All"
    @State private var selectedTag: String = "All" // All, Classic, AI
    @State private var searchQuery: String = ""
    @State private var showFilterSheet: Bool = false
    @State private var loading: Bool = true
    
    @StateObject private var cloudService = CloudBookService.shared
    
    // Design tokens
    private let primaryPink = Color(hex: "F9DAD2")
    private let secondaryPink = Color(hex: "F5B5A8")
    private let textPrimary = Color(hex: "0F172A")
    private let textSecondary = Color(hex: "475569")
    private let textTertiary = Color(hex: "6B7280")
    private let textQuaternary = Color(hex: "9CA3AF")
    private let borderLight = Color(hex: "E5E7EB")
    private let borderMedium = Color(hex: "D1D5DB")
    private let bgSecondary = Color(hex: "F9FAFB")
    private let bgTertiary = Color(hex: "F3F4F6")
    private let tagText = Color(hex: "6B4C41")
    
    private let genres = ["All", "Adventure", "Fantasy", "Fairy Tales", "Animals", "Science", "Mystery", "Friendship", "Family", "Romance", "Gothic"]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Main Content
                if loading {
                    // Loading State
                    VStack {
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(secondaryPink)
                        Text("Loading books...")
                            .font(.system(size: 16))
                            .foregroundColor(textSecondary)
                            .padding(.top, 16)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            // Header Section
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Discover Books")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(textPrimary)
                                    .padding(.top, 20)
                                
                                // Search Bar + Filter Button
                                HStack(spacing: 8) {
                                    // Search Bar
                                    HStack(spacing: 8) {
                                        Image(systemName: "magnifyingglass")
                                            .font(.system(size: 16))
                                            .foregroundColor(textQuaternary)
                                        
                                        TextField("Search books...", text: $searchQuery)
                                            .font(.system(size: 14))
                                            .foregroundColor(textPrimary)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(bgTertiary)
                                    .cornerRadius(12)
                                    
                                    // Filter Button
                                    Button(action: { showFilterSheet = true }) {
                                        Image(systemName: "slider.horizontal.3")
                                            .font(.system(size: 20))
                                            .foregroundColor(hasActiveFilters ? textPrimary : textQuaternary)
                                            .frame(width: 44, height: 44)
                                            .background(hasActiveFilters ? primaryPink : Color.white)
                                            .cornerRadius(12)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(hasActiveFilters ? secondaryPink : borderLight, lineWidth: 2)
                                            )
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            
                            // Active Filters
                            if hasActiveFilters {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        if selectedTag != "All" {
                                            FilterBadge(text: selectedTag) {
                                                selectedTag = "All"
                                            }
                                        }
                                        if selectedGenre != "All" {
                                            FilterBadge(text: selectedGenre) {
                                                selectedGenre = "All"
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                                .padding(.vertical, 8)
                            }
                            
                            // Results Count
                            HStack {
                                Text("\(filteredCloudBooks.count) \(filteredCloudBooks.count == 1 ? "book" : "books") found")
                                    .font(.system(size: 14))
                                    .foregroundColor(textSecondary)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            
                            // Books Grid or Empty State
                            if filteredCloudBooks.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "books.vertical")
                                        .font(.system(size: 48))
                                        .foregroundColor(textQuaternary)
                                        .padding(.top, 60)
                                    Text("No books found")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(textSecondary)
                                    Text("Try adjusting your filters or search")
                                        .font(.system(size: 14))
                                        .foregroundColor(textTertiary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                            } else {
                                VStack(spacing: 16) {
                                    LazyVGrid(columns: [
                                        GridItem(.flexible(), spacing: 12, alignment: .top),
                                        GridItem(.flexible(), spacing: 12, alignment: .top),
                                        GridItem(.flexible(), spacing: 12, alignment: .top)
                                    ], alignment: .leading, spacing: 12) {
                                        ForEach(filteredCloudBooks) { cloudBook in
                                            NavigationLink(destination: CloudBookDetailsLoader(
                                                cloudBook: cloudBook,
                                                voiceId: voiceId
                                            )) {
                                                CloudBookCard(
                                                    book: cloudBook,
                                                    cloudService: cloudService,
                                                    streamingService: StreamingEPUBService.shared,
                                                    tagText: tagText,
                                                    primaryPink: primaryPink
                                                )
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                    }
                                    
                                    // "Change Batch" button - only show when no filters/search active
                                    if !hasActiveFilters && searchQuery.isEmpty && cloudBooks.count > 6 {
                                        Button(action: {
                                            selectRandomBooks()
                                        }) {
                                            HStack(spacing: 8) {
                                                Image(systemName: "arrow.2.squarepath")
                                                    .font(.system(size: 16, weight: .medium))
                                                Text("Change Batch")
                                                    .font(.system(size: 16, weight: .semibold))
                                            }
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 14)
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
                                        .padding(.top, 8)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.bottom, 24)
                            }
                        }
                    }
                    .background(Color.white)
                }
            }
            .onAppear {
                loadBooks()
            }
            .onChange(of: selectedGenre) { oldValue, newValue in filterBooks() }
            .onChange(of: selectedTag) { oldValue, newValue in filterBooks() }
            .onChange(of: searchQuery) { oldValue, newValue in filterBooks() }
            .sheet(isPresented: $showFilterSheet) {
                FilterSheet(
                    selectedGenre: $selectedGenre,
                    selectedTag: $selectedTag,
                    genres: genres,
                    primaryPink: primaryPink,
                    secondaryPink: secondaryPink,
                    borderLight: borderLight,
                    textPrimary: textPrimary
                )
            }
        }
    }
    
    private var hasActiveFilters: Bool {
        selectedGenre != "All" || selectedTag != "All"
    }
    
    private func loadBooks() {
        // Load only cloud books from catalog
        Task {
            // Load cloud books from catalog
            if let catalog = await cloudService.loadCloudCatalog() {
                await MainActor.run {
                    self.cloudBooks = catalog.books
                    print("✅ Loaded \(catalog.books.count) cloud books from catalog")
                    
                    // Initially select random books
                    if !self.cloudBooks.isEmpty {
                        let shuffled = self.cloudBooks.shuffled()
                        self.displayedBooks = Array(shuffled.prefix(6))
                    }
                    
                    self.loading = false
                    self.filterBooks()
                    
                    print("📚 Total books available: \(self.cloudBooks.count)")
                }
            } else {
                await MainActor.run {
                    self.loading = false
                }
            }
        }
    }
    
    private func filterBooks() {
        // If no filters or search are active, show random 6 books
        if !hasActiveFilters && searchQuery.isEmpty {
            filteredCloudBooks = displayedBooks
            return
        }
        
        // Apply filters to cloud books
        filteredCloudBooks = cloudBooks.filter { book in
            let matchesGenre = selectedGenre == "All" || book.genre == selectedGenre
            let matchesTag = selectedTag == "All" || book.tags.contains(selectedTag)
            let matchesSearch = searchQuery.isEmpty ||
                book.title.lowercased().contains(searchQuery.lowercased()) ||
                book.author.lowercased().contains(searchQuery.lowercased())
            return matchesGenre && matchesTag && matchesSearch
        }
    }
    
    private func selectRandomBooks() {
        // Randomly select 6 books from all available books
        let shuffled = cloudBooks.shuffled()
        displayedBooks = Array(shuffled.prefix(6))
        filterBooks()
    }
}

// MARK: - Source Chip (All / AI / Classics)
struct SourceChip: View {
    let text: String
    let isSelected: Bool
    let action: () -> Void
    
    private let primaryPink = Color(hex: "F9DAD2")
    private let secondaryPink = Color(hex: "F5B5A8")
    private let textPrimary = Color(hex: "0F172A")
    private let textSecondary = Color(hex: "475569")
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? textPrimary : textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? primaryPink : Color.white)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? secondaryPink : Color(hex: "E5E7EB"), lineWidth: 2)
                )
        }
    }
}

// MARK: - Enhanced Book Card (shows badge for classics)
struct EnhancedBookCard: View {
    let book: Book
    let isBundled: Bool
    let tagText: Color
    let primaryPink: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Cover Image
            GeometryReader { geometry in
                ZStack(alignment: .topTrailing) {
                    // Cover image logic
                    if !book.coverUrl.isEmpty {
                        if isBundled {
                            // Try loading from file path first (cached EPUB covers)
                            if let image = UIImage(contentsOfFile: book.coverUrl) {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: geometry.size.width, height: geometry.size.height)
                                    .clipped()
                            } else if let image = UIImage(named: book.coverUrl) {
                                // Fallback to Assets bundle
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: geometry.size.width, height: geometry.size.height)
                                    .clipped()
                            } else {
                                // Placeholder if no cover found
                                Rectangle()
                                    .fill(Color(hex: getRandomColor()))
                                    .overlay(
                                        VStack(spacing: 8) {
                                            Image(systemName: "book.fill")
                                                .font(.system(size: 32))
                                                .foregroundColor(.white.opacity(0.8))
                                            Text("CLASSIC")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(.white.opacity(0.6))
                                        }
                                    )
                            }
                        } else if let url = URL(string: book.coverUrl) {
                            // Firebase book URL
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty:
                                    Rectangle()
                                        .fill(Color(hex: getRandomColor()))
                                        .overlay(ProgressView().tint(.white))
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: geometry.size.width, height: geometry.size.height)
                                        .clipped()
                                case .failure(_):
                                    Rectangle().fill(Color(hex: getRandomColor()))
                                @unknown default:
                                    Rectangle().fill(Color(hex: getRandomColor()))
                                }
                            }
                        } else {
                            Rectangle().fill(Color(hex: getRandomColor()))
                        }
                    } else {
                        Rectangle().fill(Color(hex: getRandomColor()))
                    }
                }
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 3)
            }
            .aspectRatio(2/3, contentMode: .fit)
            
            // Title and Tag
            VStack(alignment: .leading, spacing: 0) {
                Text(book.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(hex: "0F172A"))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 6)
                
                if !book.tags.isEmpty {
                    Text(book.tags.first ?? "")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(tagText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(primaryPink)
                        .cornerRadius(8)
                }
            }
        }
    }
    
    private func getRandomColor() -> String {
        let colors = ["8B5CF6", "EC4899", "10B981", "F59E0B", "3B82F6", "EF4444", "06B6D4", "84CC16", "6366F1"]
        return colors[abs(book.id.hashValue) % colors.count]
    }
}

// MARK: - Book Card (kept for compatibility)
struct BookCard: View {
    let book: Book
    let tagText: Color
    let primaryPink: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Cover Image with URL support
            GeometryReader { geometry in
                ZStack(alignment: .topTrailing) {
                    // Load actual cover image or show colored placeholder
                    if !book.coverUrl.isEmpty, let url = URL(string: book.coverUrl) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                // Loading state
                                Rectangle()
                                    .fill(Color(hex: getRandomColor()))
                                    .overlay(
                                        ProgressView()
                                            .tint(.white)
                                    )
                            case .success(let image):
                                // Successfully loaded image
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: geometry.size.width, height: geometry.size.height)
                                    .clipped()
                            case .failure(_):
                                // Failed to load, show placeholder
                                Rectangle()
                                    .fill(Color(hex: getRandomColor()))
                            @unknown default:
                                Rectangle()
                                    .fill(Color(hex: getRandomColor()))
                            }
                        }
                    } else {
                        // No URL, show colored placeholder
                        Rectangle()
                            .fill(Color(hex: getRandomColor()))
                    }
                }
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 3)
            }
            .aspectRatio(2/3, contentMode: .fit) // Fixed 2:3 aspect ratio
            
            // Title and Tag grouped together
            VStack(alignment: .leading, spacing: 0) {
                // Title
                Text(book.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(hex: "0F172A"))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 6)
                
                // Tag
                if !book.tags.isEmpty {
                    Text(book.tags.first ?? "")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(tagText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(primaryPink)
                        .cornerRadius(8)
                }
            }
        }
    }
    
    private func getRandomColor() -> String {
        let colors = ["8B5CF6", "EC4899", "10B981", "F59E0B", "3B82F6", "EF4444", "06B6D4", "84CC16", "6366F1"]
        return colors[abs(book.id.hashValue) % colors.count]
    }
}

// MARK: - Filter Badge
struct FilterBadge: View {
    let text: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "6B4C41"))
            
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(hex: "6B4C41"))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(hex: "F9DAD2"))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "F5B5A8"), lineWidth: 2)
        )
    }
}

// MARK: - Filter Sheet
struct FilterSheet: View {
    @Binding var selectedGenre: String
    @Binding var selectedTag: String
    @Environment(\.dismiss) var dismiss
    
    let genres: [String]
    let primaryPink: Color
    let secondaryPink: Color
    let borderLight: Color
    let textPrimary: Color
    
    private let tags = ["All", "Classic", "AI"]
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 24) {
                // Book Type Section (Classic / AI)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Book Type")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(textPrimary)
                    
                    HStack(spacing: 8) {
                        ForEach(tags, id: \.self) { tag in
                            FilterChip(
                                text: tag,
                                isSelected: selectedTag == tag,
                                primaryPink: primaryPink,
                                secondaryPink: secondaryPink,
                                borderLight: borderLight
                            ) {
                                selectedTag = tag
                            }
                        }
                    }
                }
                
                // Genre Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Genre")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(textPrimary)
                    
                    FlexibleView(
                        data: genres,
                        spacing: 8,
                        alignment: .leading
                    ) { genre in
                        FilterChip(
                            text: genre,
                            isSelected: selectedGenre == genre,
                            primaryPink: primaryPink,
                            secondaryPink: secondaryPink,
                            borderLight: borderLight
                        ) {
                            selectedGenre = genre
                        }
                    }
                }
                
                Spacer()
                
                // Reset Button
                Button(action: {
                    selectedGenre = "All"
                    selectedTag = "All"
                }) {
                    Text("Reset Filters")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(borderLight, lineWidth: 2)
                        )
                }
            }
            .padding(24)
            .navigationTitle("Filter Books")
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

// MARK: - Filter Chip
struct FilterChip: View {
    let text: String
    let isSelected: Bool
    let primaryPink: Color
    let secondaryPink: Color
    let borderLight: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "0F172A"))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? primaryPink : Color.white)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? secondaryPink : borderLight, lineWidth: 2)
                )
        }
    }
}

// MARK: - Flexible View (for wrapping chips)
struct FlexibleView<Data: Collection, Content: View>: View where Data.Element: Hashable {
    let data: Data
    let spacing: CGFloat
    let alignment: HorizontalAlignment
    let content: (Data.Element) -> Content
    
    @State private var availableWidth: CGFloat = 0
    
    var body: some View {
        ZStack(alignment: Alignment(horizontal: alignment, vertical: .center)) {
            Color.clear
                .frame(height: 1)
                .readSize { size in
                    availableWidth = size.width
                }
            
            FlexibleViewContent(
                availableWidth: availableWidth,
                data: data,
                spacing: spacing,
                alignment: alignment,
                content: content
            )
        }
    }
}

struct FlexibleViewContent<Data: Collection, Content: View>: View where Data.Element: Hashable {
    let availableWidth: CGFloat
    let data: Data
    let spacing: CGFloat
    let alignment: HorizontalAlignment
    let content: (Data.Element) -> Content
    
    var body: some View {
        VStack(alignment: alignment, spacing: spacing) {
            ForEach(computeRows(), id: \.self) { rowElements in
                HStack(spacing: spacing) {
                    ForEach(rowElements, id: \.self) { element in
                        content(element)
                    }
                }
            }
        }
    }
    
    func computeRows() -> [[Data.Element]] {
        var rows: [[Data.Element]] = [[]]
        var currentRow = 0
        var remainingWidth = availableWidth
        
        for element in data {
            let elementWidth = element.hashValue % 100 + 60 // Approximate width
            
            if remainingWidth - CGFloat(elementWidth) >= 0 {
                rows[currentRow].append(element)
            } else {
                currentRow += 1
                rows.append([element])
                remainingWidth = availableWidth
            }
            
            remainingWidth -= CGFloat(elementWidth + Int(spacing))
        }
        
        return rows
    }
}

// MARK: - View Extension for Size Reading
extension View {
    func readSize(onChange: @escaping (CGSize) -> Void) -> some View {
        background(
            GeometryReader { geometryProxy in
                Color.clear
                    .preference(key: SizePreferenceKey.self, value: geometryProxy.size)
            }
        )
        .onPreferenceChange(SizePreferenceKey.self, perform: onChange)
    }
}

struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {}
}

// MARK: - Cloud Book Card (Unified Design)
struct CloudBookCard: View {
    let book: CloudBookMetadata
    @ObservedObject var cloudService: CloudBookService
    @ObservedObject var streamingService: StreamingEPUBService
    let tagText: Color
    let primaryPink: Color
    
    var isDownloaded: Bool {
        cloudService.isBookDownloaded(bookId: book.id)
    }
    
    var isStreaming: Bool {
        streamingService.isBookInStreamingCache(bookId: book.id)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Cover Image
            GeometryReader { geometry in
                ZStack(alignment: .topTrailing) {
                    // Cover image logic
                    if let coverImage = book.localCoverImage {
                        Image(uiImage: coverImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                    } else {
                        // Placeholder
                        Rectangle()
                            .fill(Color(hex: getRandomColor()))
                            .overlay(
                                VStack(spacing: 8) {
                                    Image(systemName: "book.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(.white.opacity(0.8))
                                    Text("CLOUD")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                            )
                    }
                }
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 3)
            }
            .aspectRatio(2/3, contentMode: .fit)
            
            // Title and Tag
            VStack(alignment: .leading, spacing: 0) {
                Text(book.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(hex: "0F172A"))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 6)
                
                // Show tag
                if !book.tags.isEmpty {
                    Text(book.tags.first ?? "")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(tagText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(primaryPink)
                        .cornerRadius(8)
                }
            }
        }
    }
    
    private func getRandomColor() -> String {
        let colors = ["8B5CF6", "EC4899", "10B981", "F59E0B", "3B82F6", "EF4444", "06B6D4", "84CC16", "6366F1"]
        return colors[abs(book.id.hashValue) % colors.count]
    }
}

// MARK: - Cloud Book Details Loader (Handles Streaming)
struct CloudBookDetailsLoader: View {
    let cloudBook: CloudBookMetadata
    let voiceId: String?
    
    @StateObject private var streamingService = StreamingEPUBService.shared
    @State private var epubContent: EPUBContent?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(Color(hex: "F5B5A8"))
                    
                    Text("Opening book...")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "475569"))
                    
                    if let progress = streamingService.streamingProgress[cloudBook.id] {
                        Text("\(Int(progress * 100))% loaded")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "6B7280"))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white)
            } else if let error = errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.red)
                    
                    Text("Failed to open book")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Color(hex: "0F172A"))
                    
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "6B7280"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white)
            } else if let content = epubContent {
                BookDetailsView(
                    book: Book(
                        id: cloudBook.id,
                        title: cloudBook.title,
                        author: cloudBook.author,
                        age: cloudBook.age,
                        genre: cloudBook.genre,
                        coverUrl: cloudBook.coverImageUrl ?? "",
                        tags: cloudBook.tags,
                        textContent: nil,
                        chapters: content.chapters.map { epubChapter in
                            Chapter(
                                id: epubChapter.id,
                                title: epubChapter.title,
                                content: epubChapter.content
                            )
                        }
                    ),
                    voiceId: voiceId,
                    cloudMetadata: cloudBook
                )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadBook()
        }
    }
    
    private func loadBook() {
        Task {
            do {
                let content = try await streamingService.loadBookForStreaming(metadata: cloudBook)
                await MainActor.run {
                    self.epubContent = content
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Old Cloud Book Card (Keep for backward compatibility, but not used)
struct CloudBookCardCompact: View {
    let book: CloudBookMetadata
    @ObservedObject var cloudService: CloudBookService
    let voiceId: String?
    let primaryPink: Color
    let secondaryPink: Color
    
    @StateObject private var streamingService = StreamingEPUBService.shared
    @State private var isLoading = false
    @State private var showingReader = false
    @State private var epubContent: EPUBContent?
    @State private var errorMessage: String?
    
    var isDownloaded: Bool {
        cloudService.isBookDownloaded(bookId: book.id)
    }
    
    var isStreaming: Bool {
        streamingService.isBookInStreamingCache(bookId: book.id)
    }
    
    var loadingProgress: Double? {
        streamingService.streamingProgress[book.id]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Cover Image with Download Progress Overlay
            GeometryReader { geometry in
                ZStack(alignment: .center) {
                    // Cover image
                    if let coverImage = book.localCoverImage {
                        Image(uiImage: coverImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                    } else {
                        // Placeholder
                        Rectangle()
                            .fill(LinearGradient(
                                colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .overlay {
                                Image(systemName: "book.fill")
                                    .font(.largeTitle)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                    }
                    
                    // Loading Progress Overlay
                    if let progress = loadingProgress {
                        ZStack {
                            // Dimmed background
                            Color.black.opacity(0.5)
                            
                            // Circular progress ring
                            CircularProgressView(progress: progress, lineWidth: 4)
                                .frame(width: 60, height: 60)
                        }
                    }
                    
                    // Status badges
                    if loadingProgress == nil {
                        VStack {
                            HStack {
                                Spacer()
                                if isDownloaded {
                                    // Downloaded badge (green checkmark)
                                    Image(systemName: "arrow.down.circle.fill")
                                        .foregroundColor(.green)
                                        .background(Circle().fill(Color.white).frame(width: 20, height: 20))
                                        .padding(6)
                                } else if isStreaming {
                                    // Streaming badge (cloud icon)
                                    Image(systemName: "cloud.fill")
                                        .foregroundColor(.blue)
                                        .background(Circle().fill(Color.white).frame(width: 20, height: 20))
                                        .padding(6)
                                }
                            }
                            Spacer()
                        }
                    }
                }
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 3)
            }
            .aspectRatio(2/3, contentMode: .fit)
            
            // Title and status
            VStack(alignment: .leading, spacing: 2) {
                Text(book.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(hex: "0F172A"))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Show status indicator
                if isDownloaded {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                        Text("Downloaded")
                            .font(.system(size: 11))
                            .foregroundColor(.green)
                    }
                } else if isStreaming && loadingProgress == nil {
                    HStack(spacing: 4) {
                        Image(systemName: "cloud.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.blue)
                        Text("In Cache")
                            .font(.system(size: 11))
                            .foregroundColor(.blue)
                    }
                } else if loadingProgress == nil {
                    Text(book.fileSizeFormatted)
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "6B7280"))
                }
            }
        }
        .onTapGesture {
            // Always open immediately (stream if needed)
            Task {
                await openBook()
            }
        }
        .fullScreenCover(isPresented: $showingReader) {
            if let content = epubContent {
                BookDetailsView(
                    book: Book(
                        id: book.id,
                        title: book.title,
                        author: book.author,
                        age: book.age,
                        genre: book.genre,
                        coverUrl: book.coverImageUrl ?? "",
                        tags: book.tags,
                        textContent: nil,
                        chapters: content.chapters.map { epubChapter in
                            Chapter(
                                id: epubChapter.id,
                                title: epubChapter.title,
                                content: epubChapter.content
                            )
                        }
                    ),
                    voiceId: voiceId,
                    cloudMetadata: book // Pass cloud metadata for "Save for Offline" feature
                )
            }
        }
        .alert("Download Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
    }
    
    private func openBook() async {
        isLoading = true
        do {
            // Use streaming service - downloads to temp if needed, uses permanent if available
            epubContent = try await streamingService.loadBookForStreaming(metadata: book)
            isLoading = false
            showingReader = true
        } catch {
            errorMessage = "Failed to open book: \(error.localizedDescription)"
            isLoading = false
        }
    }
}

// MARK: - Circular Progress View
struct CircularProgressView: View {
    let progress: Double
    let lineWidth: CGFloat
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: lineWidth)
            
            // Progress circle
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    Color.white,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear, value: progress)
            
            // Progress text
            Text("\(Int(progress * 100))%")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
        }
    }
}
