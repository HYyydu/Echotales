import Foundation
import UIKit
import FirebaseStorage
import Combine

/// Service to manage cloud-based books with on-demand downloading
class CloudBookService: ObservableObject {
    static let shared = CloudBookService()
    
    @Published var downloadProgress: [String: Double] = [:] // bookId: progress (0.0-1.0)
    @Published var downloadedBooks: Set<String> = [] // Set of downloaded book IDs
    
    private let storage = Storage.storage()
    private var downloadTasks: [String: StorageDownloadTask] = [:]
    
    private init() {
        loadDownloadedBooksList()
    }
    
    // MARK: - Catalog Management
    
    /// Load cloud book catalog from bundled JSON
    func loadCloudCatalog() async -> CloudBookCatalog? {
        guard let url = Bundle.main.url(forResource: "cloud_books_catalog", withExtension: "json") else {
            print("❌ CloudBookService: cloud_books_catalog.json not found")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: url)
            let catalog = try JSONDecoder().decode(CloudBookCatalog.self, from: data)
            print("✅ CloudBookService: Loaded catalog with \(catalog.books.count) books")
            return catalog
        } catch {
            print("❌ CloudBookService: Failed to load catalog: \(error)")
            return nil
        }
    }
    
    /// Get books for a specific collection
    func getBooksForCollection(_ collection: BookCollection, from catalog: CloudBookCatalog) -> [CloudBookMetadata] {
        catalog.books.filter { collection.bookIds.contains($0.id) }
    }
    
    // MARK: - Download Management
    
    /// Check if a book is downloaded locally
    func isBookDownloaded(bookId: String) -> Bool {
        downloadedBooks.contains(bookId)
    }
    
    /// Mark a book as downloaded (called when saving from streaming to permanent)
    func markBookAsDownloaded(bookId: String) {
        downloadedBooks.insert(bookId)
        saveDownloadedBooksList()
    }
    
    /// Get local file URL for downloaded book
    func getLocalBookURL(bookId: String) -> URL? {
        let fileURL = getBooksDirectory().appendingPathComponent("\(bookId).epub")
        return FileManager.default.fileExists(atPath: fileURL.path) ? fileURL : nil
    }
    
    /// Download a book from Firebase Storage
    func downloadBook(metadata: CloudBookMetadata) async throws -> URL {
        print("📥 CloudBookService: Starting download for '\(metadata.title)'")
        
        // Check if already downloaded
        if let existingURL = getLocalBookURL(bookId: metadata.id) {
            print("✅ CloudBookService: Book already downloaded")
            return existingURL
        }
        
        let localURL = getBooksDirectory().appendingPathComponent("\(metadata.id).epub")
        
        // Create storage reference
        let storageRef: StorageReference
        if metadata.storageUrl.hasPrefix("gs://") || metadata.storageUrl.hasPrefix("https://") {
            storageRef = storage.reference(forURL: metadata.storageUrl)
        } else {
            storageRef = storage.reference().child(metadata.storageUrl)
        }
        
        // Start download with progress tracking
        return try await withCheckedThrowingContinuation { continuation in
            let task = storageRef.write(toFile: localURL) { [weak self] url, error in
                if let error = error {
                    print("❌ CloudBookService: Download failed: \(error)")
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let url = url else {
                    continuation.resume(throwing: NSError(domain: "CloudBookService", code: -1))
                    return
                }
                
                print("✅ CloudBookService: Downloaded '\(metadata.title)' to \(url.path)")
                
                // Update downloaded books list
                DispatchQueue.main.async {
                    self?.downloadedBooks.insert(metadata.id)
                    self?.saveDownloadedBooksList()
                    self?.downloadProgress.removeValue(forKey: metadata.id)
                    self?.downloadTasks.removeValue(forKey: metadata.id)
                }
                
                continuation.resume(returning: url)
            }
            
            // Track progress
            task.observe(.progress) { [weak self] snapshot in
                guard let progress = snapshot.progress else { return }
                let percentComplete = Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
                
                DispatchQueue.main.async {
                    self?.downloadProgress[metadata.id] = percentComplete
                }
            }
            
            downloadTasks[metadata.id] = task
        }
    }
    
    /// Cancel an ongoing download
    func cancelDownload(bookId: String) {
        downloadTasks[bookId]?.cancel()
        downloadTasks.removeValue(forKey: bookId)
        DispatchQueue.main.async {
            self.downloadProgress.removeValue(forKey: bookId)
        }
        print("🛑 CloudBookService: Cancelled download for \(bookId)")
    }
    
    /// Delete a downloaded book to free up space
    func deleteDownloadedBook(bookId: String) throws {
        let fileURL = getBooksDirectory().appendingPathComponent("\(bookId).epub")
        
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
            
            DispatchQueue.main.async {
                self.downloadedBooks.remove(bookId)
                self.saveDownloadedBooksList()
            }
            
            print("🗑️ CloudBookService: Deleted EPUB \(bookId)")
        }
        
        // Also delete cached cover image
        let coverPath = getCachedCoverPath(bookId: bookId)
        if FileManager.default.fileExists(atPath: coverPath) {
            try? FileManager.default.removeItem(atPath: coverPath)
            print("🗑️ CloudBookService: Deleted cached cover for \(bookId)")
        }
    }
    
    /// Get total size of downloaded books
    func getDownloadedBooksSize() -> Int64 {
        let directory = getBooksDirectory()
        
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        
        var totalSize: Int64 = 0
        for file in files {
            if let attributes = try? FileManager.default.attributesOfItem(atPath: file.path),
               let fileSize = attributes[.size] as? Int64 {
                totalSize += fileSize
            }
        }
        
        return totalSize
    }
    
    // MARK: - Book Content Loading
    
    /// Load book content (download if needed)
    func loadBook(metadata: CloudBookMetadata) async throws -> EPUBContent {
        // Download book if not already local
        let localURL: URL
        if let existingURL = getLocalBookURL(bookId: metadata.id) {
            localURL = existingURL
        } else {
            localURL = try await downloadBook(metadata: metadata)
        }
        
        // Parse EPUB (pass tags for AI detection)
        guard var epubContent = EPUBParser.parseEPUB(at: localURL, tags: metadata.tags) else {
            throw NSError(domain: "CloudBookService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to parse EPUB"])
        }
        
        // Copy cover from temporary directory to permanent cache
        if let tempCoverURLString = epubContent.coverImageURL,
           let tempCoverURL = URL(string: tempCoverURLString) ?? (tempCoverURLString.hasPrefix("/") ? URL(fileURLWithPath: tempCoverURLString) : nil) {
            
            print("📥 CloudBookService: Processing cover for '\(metadata.title)'")
            print("   - Temp cover URL: \(tempCoverURLString)")
            
            // Check if already in permanent cache (to avoid re-copying)
            let cachedCoverPath = getCachedCoverPath(bookId: metadata.id)
            if FileManager.default.fileExists(atPath: cachedCoverPath) {
                print("   ✅ Cover already in permanent cache: \(cachedCoverPath)")
                // Update EPUBContent with permanent path
                epubContent = EPUBContent(
                    title: epubContent.title,
                    author: epubContent.author,
                    chapters: epubContent.chapters,
                    coverImageURL: cachedCoverPath
                )
            } else if let permanentPath = copyToPermamentCache(from: tempCoverURL, bookId: metadata.id) {
                print("   ✅ Copied cover to permanent cache: \(permanentPath)")
                // Update EPUBContent with permanent path
                epubContent = EPUBContent(
                    title: epubContent.title,
                    author: epubContent.author,
                    chapters: epubContent.chapters,
                    coverImageURL: permanentPath
                )
            } else {
                print("   ⚠️ Failed to copy cover to permanent cache, using temp URL")
            }
        }
        
        return epubContent
    }
    
    // MARK: - Private Helpers
    
    private func getBooksDirectory() -> URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let booksDirectory = documentsDirectory.appendingPathComponent("DownloadedBooks", isDirectory: true)
        
        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: booksDirectory.path) {
            try? FileManager.default.createDirectory(at: booksDirectory, withIntermediateDirectories: true)
        }
        
        return booksDirectory
    }
    
    private func loadDownloadedBooksList() {
        let directory = getBooksDirectory()
        
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return
        }
        
        let bookIds = files
            .filter { $0.pathExtension == "epub" }
            .map { $0.deletingPathExtension().lastPathComponent }
        
        downloadedBooks = Set(bookIds)
        print("📚 CloudBookService: Found \(bookIds.count) downloaded books")
    }
    
    private func saveDownloadedBooksList() {
        // The list is automatically maintained by checking the file system
        // This method is here for future enhancements (e.g., metadata storage)
    }
    
    // MARK: - Cover Cache Management
    
    /// Get the path where a book's cover should be cached
    private func getCachedCoverPath(bookId: String) -> String {
        guard let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return ""
        }
        
        let coversDirectory = cachesDirectory.appendingPathComponent("BookCovers", isDirectory: true)
        let fileName = "\(bookId)-cover.png"
        return coversDirectory.appendingPathComponent(fileName).path
    }
    
    /// Copy cover from temporary location to permanent cache
    private func copyToPermamentCache(from sourceURL: URL, bookId: String) -> String? {
        print("   📁 CACHE DEBUG (Cloud): Copying cover for book: \(bookId)")
        print("   📁 CACHE DEBUG (Cloud): Source URL: \(sourceURL.absoluteString)")
        print("   📁 CACHE DEBUG (Cloud): Source path: \(sourceURL.path)")
        
        // Check if source file exists
        let sourcePath = sourceURL.path
        guard FileManager.default.fileExists(atPath: sourcePath) else {
            print("   ❌ CACHE DEBUG (Cloud): Source file does not exist at: \(sourcePath)")
            return nil
        }
        print("   ✅ CACHE DEBUG (Cloud): Source file exists")
        
        // Get source file size
        if let attributes = try? FileManager.default.attributesOfItem(atPath: sourcePath),
           let fileSize = attributes[.size] as? Int {
            print("   📁 CACHE DEBUG (Cloud): Source file size: \(fileSize) bytes")
        }
        
        guard let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            print("   ❌ CACHE DEBUG (Cloud): Cannot get caches directory")
            return nil
        }
        print("   📁 CACHE DEBUG (Cloud): Caches directory: \(cachesDirectory.path)")
        
        let coversDirectory = cachesDirectory.appendingPathComponent("BookCovers", isDirectory: true)
        print("   📁 CACHE DEBUG (Cloud): Target covers directory: \(coversDirectory.path)")
        
        // Create covers directory if it doesn't exist
        do {
            try FileManager.default.createDirectory(at: coversDirectory, withIntermediateDirectories: true)
            print("   ✅ CACHE DEBUG (Cloud): Covers directory created/verified")
        } catch {
            print("   ❌ CACHE DEBUG (Cloud): Failed to create covers directory: \(error)")
            return nil
        }
        
        let fileName = "\(bookId)-cover.png"
        let destinationURL = coversDirectory.appendingPathComponent(fileName)
        print("   📁 CACHE DEBUG (Cloud): Destination path: \(destinationURL.path)")
        
        // Remove existing file if present
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            print("   📁 CACHE DEBUG (Cloud): Removing existing cover at destination")
            do {
                try FileManager.default.removeItem(at: destinationURL)
                print("   ✅ CACHE DEBUG (Cloud): Existing file removed")
            } catch {
                print("   ⚠️ CACHE DEBUG (Cloud): Failed to remove existing file: \(error)")
            }
        }
        
        // Copy file
        do {
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            print("   ✅ CACHE DEBUG (Cloud): Cover copied successfully to: \(destinationURL.path)")
            
            // Verify the copy
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                print("   ✅ CACHE DEBUG (Cloud): Verified destination file exists")
                if let attributes = try? FileManager.default.attributesOfItem(atPath: destinationURL.path),
                   let fileSize = attributes[.size] as? Int {
                    print("   ✅ CACHE DEBUG (Cloud): Destination file size: \(fileSize) bytes")
                }
            }
            
            // Return the file PATH (not URL) for UIImage(contentsOfFile:)
            let returnPath = destinationURL.path
            print("   🎯 CACHE DEBUG (Cloud): Returning permanent path: \(returnPath)")
            return returnPath
        } catch {
            print("   ❌ CACHE DEBUG (Cloud): Failed to copy cover: \(error)")
            print("   ❌ CACHE DEBUG (Cloud): Error details: \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - Models

struct CloudBookCatalog: Codable {
    let collections: [BookCollection]
    let books: [CloudBookMetadata]
    let lastUpdated: String
    let version: Int
}

struct BookCollection: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let bookIds: [String]
    let coverImageUrl: String?
    let sortOrder: Int
}

struct CloudBookMetadata: Codable, Identifiable {
    let id: String
    let title: String
    let author: String
    let age: String
    let genre: String
    let tags: [String]
    let description: String
    
    // Cloud-specific fields
    let storageUrl: String  // Firebase Storage path: "epubs/book-id.epub"
    let coverImageUrl: String?  // Local bundled cover path (e.g., "BookCovers/book-id.png") or remote URL
    let fileSizeBytes: Int
    let isFeatured: Bool  // True if bundled in app as starter content
    
    var fileSizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: Int64(fileSizeBytes), countStyle: .file)
    }
    
    /// Get local bundled cover image if available
    var localCoverImage: UIImage? {
        guard let coverPath = coverImageUrl else {
            print("🔍 DEBUG: coverImageUrl is nil for book: \(id)")
            return nil
        }
        
        print("🔍 DEBUG: Attempting to load cover for '\(title)'")
        print("   📁 Cover path: \(coverPath)")
        
        // Check if it's a bundled resource path (not a URL)
        if !coverPath.hasPrefix("http") && !coverPath.hasPrefix("https") {
            // Try to load from bundle
            if let bundlePath = Bundle.main.path(forResource: coverPath, ofType: nil) {
                print("   ✅ Found cover at: \(bundlePath)")
                if let image = UIImage(contentsOfFile: bundlePath) {
                    print("   ✅ Successfully loaded image")
                    return image
                } else {
                    print("   ❌ Failed to create UIImage from file")
                    return nil
                }
            }
            
            // Try direct path in bundle
            if let bundlePath = Bundle.main.resourcePath {
                let fullPath = (bundlePath as NSString).appendingPathComponent(coverPath)
                print("   🔍 Trying direct path: \(fullPath)")
                
                if FileManager.default.fileExists(atPath: fullPath) {
                    print("   ✅ File exists at direct path")
                    if let image = UIImage(contentsOfFile: fullPath) {
                        print("   ✅ Successfully loaded image from direct path")
                        return image
                    } else {
                        print("   ❌ File exists but failed to create UIImage")
                    }
                } else {
                    print("   ❌ Cover URL doesn't exist at: \(fullPath)")
                    print("   📂 Bundle resource path: \(bundlePath)")
                    
                    // List what's actually in the bundle
                    if let contents = try? FileManager.default.contentsOfDirectory(atPath: bundlePath) {
                        let bookCoversExists = contents.contains("BookCovers")
                        print("   📂 BookCovers folder exists in bundle: \(bookCoversExists)")
                        
                        if bookCoversExists {
                            let bookCoversPath = (bundlePath as NSString).appendingPathComponent("BookCovers")
                            if let bookCovers = try? FileManager.default.contentsOfDirectory(atPath: bookCoversPath) {
                                print("   📂 BookCovers contains \(bookCovers.count) files")
                                print("   📂 First 5 files: \(bookCovers.prefix(5))")
                            }
                        }
                    }
                }
            }
        } else {
            print("   ℹ️  Skipping - appears to be a remote URL")
        }
        
        print("   ❌ Failed to load cover for '\(title)'")
        return nil
    }
}

