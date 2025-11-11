import Foundation
import FirebaseStorage
import Combine

/// Service to handle streaming (temporary) book access from Firebase Storage
/// Books are downloaded to temp storage and can be "saved" for permanent offline access
class StreamingEPUBService: ObservableObject {
    static let shared = StreamingEPUBService()
    
    @Published var streamingProgress: [String: Double] = [:] // bookId: progress (0.0-1.0)
    
    private let storage = Storage.storage()
    private var downloadTasks: [String: StorageDownloadTask] = [:]
    
    private init() {
        cleanOldStreamingBooks()
    }
    
    // MARK: - Streaming Book Management
    
    /// Get temporary directory for streaming books
    private func getStreamingDirectory() -> URL {
        let tempDirectory = FileManager.default.temporaryDirectory
        let streamingDirectory = tempDirectory.appendingPathComponent("StreamingBooks", isDirectory: true)
        
        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: streamingDirectory.path) {
            try? FileManager.default.createDirectory(at: streamingDirectory, withIntermediateDirectories: true)
        }
        
        return streamingDirectory
    }
    
    /// Check if book is in streaming cache (temp storage)
    func isBookInStreamingCache(bookId: String) -> Bool {
        let fileURL = getStreamingDirectory().appendingPathComponent("\(bookId).epub")
        return FileManager.default.fileExists(atPath: fileURL.path)
    }
    
    /// Get streaming book URL if available
    func getStreamingBookURL(bookId: String) -> URL? {
        let fileURL = getStreamingDirectory().appendingPathComponent("\(bookId).epub")
        return FileManager.default.fileExists(atPath: fileURL.path) ? fileURL : nil
    }
    
    /// Stream a book (download to temporary storage for immediate reading)
    func streamBook(metadata: CloudBookMetadata) async throws -> URL {
        print("📺 StreamingEPUBService: Starting stream for '\(metadata.title)'")
        
        // Check if already in streaming cache
        if let existingURL = getStreamingBookURL(bookId: metadata.id) {
            print("✅ StreamingEPUBService: Book already in streaming cache")
            return existingURL
        }
        
        // Check if already downloaded permanently (use that instead)
        if CloudBookService.shared.isBookDownloaded(bookId: metadata.id),
           let permanentURL = CloudBookService.shared.getLocalBookURL(bookId: metadata.id) {
            print("✅ StreamingEPUBService: Book is permanently downloaded, using that")
            return permanentURL
        }
        
        let localURL = getStreamingDirectory().appendingPathComponent("\(metadata.id).epub")
        
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
                    print("❌ StreamingEPUBService: Stream failed: \(error)")
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let url = url else {
                    continuation.resume(throwing: NSError(domain: "StreamingEPUBService", code: -1))
                    return
                }
                
                print("✅ StreamingEPUBService: Streamed '\(metadata.title)' to temp storage")
                
                // Save metadata for cleanup tracking
                self?.saveStreamingMetadata(bookId: metadata.id)
                
                // Clear progress
                DispatchQueue.main.async {
                    self?.streamingProgress.removeValue(forKey: metadata.id)
                    self?.downloadTasks.removeValue(forKey: metadata.id)
                }
                
                continuation.resume(returning: url)
            }
            
            // Track progress
            task.observe(.progress) { [weak self] snapshot in
                guard let progress = snapshot.progress else { return }
                let percentComplete = Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
                
                DispatchQueue.main.async {
                    self?.streamingProgress[metadata.id] = percentComplete
                }
            }
            
            downloadTasks[metadata.id] = task
        }
    }
    
    /// Cancel an ongoing stream
    func cancelStream(bookId: String) {
        downloadTasks[bookId]?.cancel()
        downloadTasks.removeValue(forKey: bookId)
        DispatchQueue.main.async {
            self.streamingProgress.removeValue(forKey: bookId)
        }
        print("🛑 StreamingEPUBService: Cancelled stream for \(bookId)")
    }
    
    /// Load book content from streaming cache or permanent storage
    func loadBookForStreaming(metadata: CloudBookMetadata) async throws -> EPUBContent {
        print("📚 StreamingEPUBService: Loading book '\(metadata.title)'")
        
        // Try permanent download first
        if CloudBookService.shared.isBookDownloaded(bookId: metadata.id),
           let permanentURL = CloudBookService.shared.getLocalBookURL(bookId: metadata.id) {
            print("   - Using permanent download")
            return try await loadFromURL(permanentURL, metadata: metadata)
        }
        
        // Stream to temporary storage
        print("   - Streaming to temp storage")
        let streamURL = try await streamBook(metadata: metadata)
        return try await loadFromURL(streamURL, metadata: metadata)
    }
    
    /// Load EPUB content from URL
    private func loadFromURL(_ url: URL, metadata: CloudBookMetadata) async throws -> EPUBContent {
        // Parse EPUB (pass tags for AI detection)
        guard var epubContent = EPUBParser.parseEPUB(at: url, tags: metadata.tags) else {
            throw NSError(domain: "StreamingEPUBService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to parse EPUB"])
        }
        
        // Copy cover from temporary directory to permanent cache
        if let tempCoverURLString = epubContent.coverImageURL,
           let tempCoverURL = URL(string: tempCoverURLString) ?? (tempCoverURLString.hasPrefix("/") ? URL(fileURLWithPath: tempCoverURLString) : nil) {
            
            print("   - Processing cover for '\(metadata.title)'")
            
            // Check if already in permanent cache
            let cachedCoverPath = getCachedCoverPath(bookId: metadata.id)
            if FileManager.default.fileExists(atPath: cachedCoverPath) {
                print("   ✅ Cover already cached: \(cachedCoverPath)")
                epubContent = EPUBContent(
                    title: epubContent.title,
                    author: epubContent.author,
                    chapters: epubContent.chapters,
                    coverImageURL: cachedCoverPath
                )
            } else if let permanentPath = copyToPermamentCache(from: tempCoverURL, bookId: metadata.id) {
                print("   ✅ Copied cover to cache: \(permanentPath)")
                epubContent = EPUBContent(
                    title: epubContent.title,
                    author: epubContent.author,
                    chapters: epubContent.chapters,
                    coverImageURL: permanentPath
                )
            }
        }
        
        return epubContent
    }
    
    /// Save book to permanent offline storage (convert streaming → downloaded)
    func saveForOffline(metadata: CloudBookMetadata) async throws {
        print("💾 StreamingEPUBService: Saving '\(metadata.title)' for offline use")
        
        // Check if already in permanent storage
        if CloudBookService.shared.isBookDownloaded(bookId: metadata.id) {
            print("   ✅ Already saved for offline")
            return
        }
        
        // Get streaming URL (or download if not cached)
        let streamingURL: URL
        if let cachedURL = getStreamingBookURL(bookId: metadata.id) {
            streamingURL = cachedURL
        } else {
            streamingURL = try await streamBook(metadata: metadata)
        }
        
        // Copy to permanent storage
        let permanentURL = CloudBookService.shared.getLocalBookURL(bookId: metadata.id) ?? 
            FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                .appendingPathComponent("DownloadedBooks", isDirectory: true)
                .appendingPathComponent("\(metadata.id).epub")
        
        // Ensure downloads directory exists
        let downloadsDir = permanentURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: downloadsDir.path) {
            try FileManager.default.createDirectory(at: downloadsDir, withIntermediateDirectories: true)
        }
        
        // Copy file
        try FileManager.default.copyItem(at: streamingURL, to: permanentURL)
        
        // Update CloudBookService
        await MainActor.run {
            CloudBookService.shared.markBookAsDownloaded(bookId: metadata.id)
        }
        
        print("✅ StreamingEPUBService: Book saved to permanent storage")
    }
    
    /// Check if book is available (either streaming or downloaded)
    func isBookAvailable(bookId: String) -> Bool {
        return isBookInStreamingCache(bookId: bookId) || 
               CloudBookService.shared.isBookDownloaded(bookId: bookId)
    }
    
    // MARK: - Cleanup
    
    /// Clean old streaming books (older than 7 days)
    private func cleanOldStreamingBooks() {
        let streamingDir = getStreamingDirectory()
        
        guard let files = try? FileManager.default.contentsOfDirectory(at: streamingDir, includingPropertiesForKeys: [.creationDateKey]) else {
            return
        }
        
        let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        
        for fileURL in files {
            if let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
               let creationDate = attributes[.creationDate] as? Date,
               creationDate < sevenDaysAgo {
                try? FileManager.default.removeItem(at: fileURL)
                print("🗑️ StreamingEPUBService: Cleaned old streaming book: \(fileURL.lastPathComponent)")
            }
        }
    }
    
    /// Delete streaming cache for a specific book
    func deleteStreamingCache(bookId: String) {
        let fileURL = getStreamingDirectory().appendingPathComponent("\(bookId).epub")
        
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try? FileManager.default.removeItem(at: fileURL)
            print("🗑️ StreamingEPUBService: Deleted streaming cache for \(bookId)")
        }
        
        removeStreamingMetadata(bookId: bookId)
    }
    
    /// Get total size of streaming cache
    func getStreamingCacheSize() -> Int64 {
        let directory = getStreamingDirectory()
        
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
    
    // MARK: - Metadata Tracking
    
    private func saveStreamingMetadata(bookId: String) {
        let metadata = ["timestamp": Date().timeIntervalSince1970]
        UserDefaults.standard.set(metadata, forKey: "streaming_\(bookId)")
    }
    
    private func removeStreamingMetadata(bookId: String) {
        UserDefaults.standard.removeObject(forKey: "streaming_\(bookId)")
    }
    
    // MARK: - Cover Cache (same as CloudBookService)
    
    private func getCachedCoverPath(bookId: String) -> String {
        guard let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return ""
        }
        
        let coversDirectory = cachesDirectory.appendingPathComponent("BookCovers", isDirectory: true)
        let fileName = "\(bookId)-cover.png"
        return coversDirectory.appendingPathComponent(fileName).path
    }
    
    private func copyToPermamentCache(from sourceURL: URL, bookId: String) -> String? {
        let sourcePath = sourceURL.path
        guard FileManager.default.fileExists(atPath: sourcePath) else {
            return nil
        }
        
        guard let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let coversDirectory = cachesDirectory.appendingPathComponent("BookCovers", isDirectory: true)
        
        do {
            try FileManager.default.createDirectory(at: coversDirectory, withIntermediateDirectories: true)
        } catch {
            return nil
        }
        
        let fileName = "\(bookId)-cover.png"
        let destinationURL = coversDirectory.appendingPathComponent(fileName)
        
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try? FileManager.default.removeItem(at: destinationURL)
        }
        
        do {
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            return destinationURL.path
        } catch {
            return nil
        }
    }
}

