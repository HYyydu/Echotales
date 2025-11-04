import SwiftUI
import FirebaseFirestore

// MARK: - Book Model
struct Book: Identifiable, Codable {
    let id: String
    let title: String
    let author: String
    let age: String
    let genre: String
    let coverUrl: String
    let tags: [String]
    let textContent: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case author
        case age
        case genre
        case coverUrl
        case tags
        case textContent
    }
}

// MARK: - AgeGroup Model
struct AgeGroup: Hashable {
    let key: String
    let label: String
}

// MARK: - BookReaderView
struct BookReaderView: View {
    let voiceId: String?
    
    @State private var books: [Book] = []
    @State private var filteredBooks: [Book] = []
    @State private var selectedAge: String = "all"
    @State private var selectedGenre: String = "All"
    @State private var searchQuery: String = ""
    @State private var showFilterSheet: Bool = false
    @State private var loading: Bool = true
    
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
    
    private let ageGroups: [AgeGroup] = [
        AgeGroup(key: "all", label: "All Ages"),
        AgeGroup(key: "0-3", label: "0-3 years"),
        AgeGroup(key: "4-6", label: "4-6 years"),
        AgeGroup(key: "7-9", label: "7-9 years"),
        AgeGroup(key: "10-12", label: "10-12 years"),
        AgeGroup(key: "13+", label: "13+ years")
    ]
    
    private let genres = ["All", "Adventure", "Fantasy", "Fairy Tales", "Animals", "Science", "Mystery", "Friendship", "Family"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Main Content (status bar removed, shifted up)
            ScrollView {
                VStack(spacing: 0) {
                    // Header Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Discover Books")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(textPrimary)
                            .padding(.top, 60) // Increased padding to clear Dynamic Island
                        
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
                                if selectedAge != "all" {
                                    FilterBadge(text: ageGroups.first(where: { $0.key == selectedAge })?.label ?? selectedAge) {
                                        selectedAge = "all"
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
                    Text("\(filteredBooks.count) \(filteredBooks.count == 1 ? "book" : "books") found")
                        .font(.system(size: 14))
                        .foregroundColor(textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    
                    // Books Grid
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12, alignment: .top),
                        GridItem(.flexible(), spacing: 12, alignment: .top),
                        GridItem(.flexible(), spacing: 12, alignment: .top)
                    ], alignment: .leading, spacing: 12) {
                        ForEach(filteredBooks) { book in
                            BookCard(book: book, tagText: tagText, primaryPink: primaryPink)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
            .background(Color.white)
        }
        .onAppear {
            loadBooks()
        }
        .onChange(of: selectedAge) { _ in filterBooks() }
        .onChange(of: selectedGenre) { _ in filterBooks() }
        .onChange(of: searchQuery) { _ in filterBooks() }
        .sheet(isPresented: $showFilterSheet) {
            FilterSheet(
                selectedAge: $selectedAge,
                selectedGenre: $selectedGenre,
                ageGroups: ageGroups,
                genres: genres,
                primaryPink: primaryPink,
                secondaryPink: secondaryPink,
                borderLight: borderLight,
                textPrimary: textPrimary
            )
        }
    }
    
    private var hasActiveFilters: Bool {
        selectedAge != "all" || selectedGenre != "All"
    }
    
    private func loadBooks() {
        // Start with sample data immediately
        setSampleBooks()
        loading = false
        
        // Try to fetch from Firebase in background
        let db = Firestore.firestore()
        db.collection("books").getDocuments { snapshot, error in
            if let error = error {
                print("❌ Firebase error: \(error.localizedDescription)")
                return
            }
            
            guard let snapshot = snapshot, !snapshot.documents.isEmpty else {
                print("📚 No books in Firebase, using sample data")
                return
            }
            
            let fetchedBooks = snapshot.documents.compactMap { doc -> Book? in
                let data = doc.data()
                
                // Manually decode because Firebase ID is separate from document data
                guard let title = data["title"] as? String,
                      let author = data["author"] as? String,
                      let age = data["age"] as? String,
                      let genre = data["genre"] as? String,
                      let coverUrl = data["coverUrl"] as? String,
                      let tags = data["tags"] as? [String] else {
                    print("⚠️ Failed to decode book: \(doc.documentID)")
                    return nil
                }
                
                let textContent = data["textContent"] as? String
                
                print("📚 Loaded book: \(title) - Cover URL: \(coverUrl)")
                
                return Book(
                    id: doc.documentID, // Use Firebase document ID
                    title: title,
                    author: author,
                    age: age,
                    genre: genre,
                    coverUrl: coverUrl,
                    tags: tags,
                    textContent: textContent
                )
            }
            
            if !fetchedBooks.isEmpty {
                print("✅ Loaded \(fetchedBooks.count) books from Firebase")
                DispatchQueue.main.async {
                    self.books = fetchedBooks
                    self.filterBooks()
                }
            }
        }
    }
    
    private func setSampleBooks() {
        books = [
            Book(id: "1", title: "The Secret Garden", author: "Frances Hodgson Burnett", age: "7-9", genre: "Adventure", coverUrl: "", tags: ["Bestseller"], textContent: nil),
            Book(id: "2", title: "Where the Wild Things Are", author: "Maurice Sendak", age: "4-6", genre: "Fantasy", coverUrl: "", tags: ["Classic"], textContent: nil),
            Book(id: "3", title: "Charlotte's Web", author: "E.B. White", age: "7-9", genre: "Animals", coverUrl: "", tags: ["Award Winner"], textContent: nil),
            Book(id: "4", title: "The Little Prince", author: "Antoine de Saint-Exupéry", age: "10-12", genre: "Fantasy", coverUrl: "", tags: ["Classic"], textContent: nil),
            Book(id: "5", title: "Goodnight Moon", author: "Margaret Wise Brown", age: "0-3", genre: "Fairy Tales", coverUrl: "", tags: ["Bedtime"], textContent: nil),
            Book(id: "6", title: "Harry Potter", author: "J.K. Rowling", age: "10-12", genre: "Fantasy", coverUrl: "", tags: ["Trending"], textContent: nil),
            Book(id: "7", title: "Matilda", author: "Roald Dahl", age: "7-9", genre: "Fantasy", coverUrl: "", tags: ["Popular"], textContent: nil),
            Book(id: "8", title: "The Very Hungry Caterpillar", author: "Eric Carle", age: "0-3", genre: "Animals", coverUrl: "", tags: ["Classic"], textContent: nil),
            Book(id: "9", title: "Green Eggs and Ham", author: "Dr. Seuss", age: "4-6", genre: "Friendship", coverUrl: "", tags: ["Popular"], textContent: nil)
        ]
        filterBooks()
    }
    
    private func filterBooks() {
        filteredBooks = books.filter { book in
            let matchesAge = selectedAge == "all" || book.age == selectedAge
            let matchesGenre = selectedGenre == "All" || book.genre == selectedGenre
            let matchesSearch = searchQuery.isEmpty ||
                book.title.lowercased().contains(searchQuery.lowercased()) ||
                book.author.lowercased().contains(searchQuery.lowercased())
            return matchesAge && matchesGenre && matchesSearch
        }
    }
}

// MARK: - Book Card
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
                    
                    // Age Badge (on top of cover)
                    Text(book.age)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(tagText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(primaryPink)
                        .cornerRadius(12)
                        .padding(6)
                }
                .cornerRadius(8)
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
            }
            .aspectRatio(2/3, contentMode: .fit) // Fixed 2:3 aspect ratio
            
            // Title (Fixed height for consistent alignment)
            Text(book.title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(hex: "0F172A"))
                .lineLimit(2)
                .frame(minHeight: 32, alignment: .topLeading)
                .fixedSize(horizontal: false, vertical: true)
            
            // Author (Fixed height)
            Text(book.author)
                .font(.system(size: 10))
                .foregroundColor(Color(hex: "6B7280"))
                .lineLimit(1)
                .frame(height: 14, alignment: .leading)
            
            // Tags (Fixed height to prevent misalignment)
            Group {
                if !book.tags.isEmpty {
                    Text(book.tags.first ?? "")
                        .font(.system(size: 10))
                        .foregroundColor(tagText)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(primaryPink)
                        .cornerRadius(4)
                } else {
                    // Empty spacer to maintain consistent height
                    Color.clear.frame(height: 18)
                }
            }
            .frame(height: 18, alignment: .leading)
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
    @Binding var selectedAge: String
    @Binding var selectedGenre: String
    @Environment(\.dismiss) var dismiss
    
    let ageGroups: [AgeGroup]
    let genres: [String]
    let primaryPink: Color
    let secondaryPink: Color
    let borderLight: Color
    let textPrimary: Color
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 24) {
                // Age Group Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Age Group")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(textPrimary)
                    
                    FlexibleView(
                        data: ageGroups,
                        spacing: 8,
                        alignment: .leading
                    ) { item in
                        FilterChip(
                            text: item.label,
                            isSelected: selectedAge == item.key,
                            primaryPink: primaryPink,
                            secondaryPink: secondaryPink,
                            borderLight: borderLight
                        ) {
                            selectedAge = item.key
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
                    selectedAge = "all"
                    selectedGenre = "All"
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
