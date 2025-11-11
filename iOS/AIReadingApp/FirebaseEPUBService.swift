import Foundation
import FirebaseStorage
import UIKit

/// Service to download and parse EPUBs from Firebase Storage
class FirebaseEPUBService {
    static let shared = FirebaseEPUBService()
    
    private init() {}
    
    // Cache for downloaded EPUBs to avoid re-downloading
    private var downloadedEPUBs: [String: URL] = [:]
    
    /// Download EPUB from Firebase Storage URL and extract cover
    /// Checks permanent storage first, then temp storage, then downloads if needed
    func extractCoverFromFirebaseEPUB(storageUrl: String, bookId: String? = nil) async -> String? {
        print("📚 FirebaseEPUBService: Extracting cover from: \(storageUrl)")
        
        // Try to get bookId from storageUrl if not provided
        let extractedBookId = bookId ?? extractBookIdFromStorageUrl(storageUrl)
        
        // Check if book is permanently downloaded first (for shelf books)
        if let bookId = extractedBookId,
           CloudBookService.shared.isBookDownloaded(bookId: bookId),
           let permanentURL = CloudBookService.shared.getLocalBookURL(bookId: bookId) {
            print("✅ FirebaseEPUBService: Using permanently downloaded EPUB: \(permanentURL.path)")
            
            // Parse EPUB and extract cover
            if let epubContent = EPUBParser.parseEPUB(at: permanentURL) {
                print("✅ FirebaseEPUBService: Cover extracted from permanent EPUB")
                print("   - Cover URL: \(epubContent.coverImageURL ?? "none")")
                return epubContent.coverImageURL
            }
        }
        
        // Check streaming cache next (for Read tab books)
        if let bookId = extractedBookId,
           let streamingURL = StreamingEPUBService.shared.getStreamingBookURL(bookId: bookId) {
            print("✅ FirebaseEPUBService: Using streaming cache EPUB: \(streamingURL.path)")
            
            // Parse EPUB and extract cover
            if let epubContent = EPUBParser.parseEPUB(at: streamingURL) {
                print("✅ FirebaseEPUBService: Cover extracted from streaming cache")
                print("   - Cover URL: \(epubContent.coverImageURL ?? "none")")
                return epubContent.coverImageURL
            }
        }
        
        // Download EPUB file to temp if not found in either location
        print("📥 FirebaseEPUBService: No local copy found, downloading to temp")
        guard let localEPUBUrl = await downloadEPUB(from: storageUrl) else {
            print("❌ FirebaseEPUBService: Failed to download EPUB")
            return nil
        }
        
        print("✅ FirebaseEPUBService: EPUB downloaded to: \(localEPUBUrl.path)")
        
        // Parse EPUB and extract cover
        guard let epubContent = EPUBParser.parseEPUB(at: localEPUBUrl) else {
            print("❌ FirebaseEPUBService: Failed to parse EPUB")
            return nil
        }
        
        print("✅ FirebaseEPUBService: EPUB parsed successfully")
        print("   - Title: \(epubContent.title)")
        print("   - Cover URL: \(epubContent.coverImageURL ?? "none")")
        
        return epubContent.coverImageURL
    }
    
    /// Extract bookId from storage URL (e.g., "epubs/alice-wonderland.epub" -> "alice-wonderland")
    private func extractBookIdFromStorageUrl(_ storageUrl: String) -> String? {
        // Handle different URL formats
        let path = storageUrl
            .replacingOccurrences(of: "gs://", with: "")
            .replacingOccurrences(of: "https://", with: "")
            .components(separatedBy: "/").last ?? ""
        
        // Remove .epub extension
        let bookId = path.replacingOccurrences(of: ".epub", with: "")
        return bookId.isEmpty ? nil : bookId
    }
    
    /// Download EPUB from Firebase Storage to local cache
    private func downloadEPUB(from storageUrl: String) async -> URL? {
        // Check if already downloaded
        if let cached = downloadedEPUBs[storageUrl] {
            if FileManager.default.fileExists(atPath: cached.path) {
                print("✅ FirebaseEPUBService: Using cached EPUB")
                return cached
            } else {
                // Cache entry exists but file is gone, remove from cache
                downloadedEPUBs.removeValue(forKey: storageUrl)
            }
        }
        
        // Create a unique local filename
        let filename = "\(UUID().uuidString).epub"
        let localURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        
        print("📥 FirebaseEPUBService: Downloading EPUB...")
        print("   - From: \(storageUrl)")
        print("   - To: \(localURL.path)")
        
        // Get Firebase Storage reference
        let storage = Storage.storage()
        let storageRef: StorageReference
        
        if storageUrl.hasPrefix("gs://") {
            // Full GS URL
            storageRef = storage.reference(forURL: storageUrl)
        } else if storageUrl.hasPrefix("https://") {
            // HTTPS download URL
            guard let url = URL(string: storageUrl),
                  let data = try? await URLSession.shared.data(from: url).0 else {
                print("❌ FirebaseEPUBService: Failed to download from HTTPS URL")
                return nil
            }
            
            do {
                try data.write(to: localURL)
                downloadedEPUBs[storageUrl] = localURL
                print("✅ FirebaseEPUBService: Downloaded \(data.count) bytes")
                return localURL
            } catch {
                print("❌ FirebaseEPUBService: Failed to write file: \(error)")
                return nil
            }
        } else {
            // Path string (e.g., "epubs/book-id.epub")
            storageRef = storage.reference().child(storageUrl)
        }
        
        // Download using Firebase Storage SDK
        do {
            _ = try await storageRef.write(toFile: localURL)
            downloadedEPUBs[storageUrl] = localURL
            
            let attributes = try? FileManager.default.attributesOfItem(atPath: localURL.path)
            let fileSize = attributes?[.size] as? Int ?? 0
            print("✅ FirebaseEPUBService: Downloaded \(fileSize) bytes")
            
            return localURL
        } catch {
            print("❌ FirebaseEPUBService: Download failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Clear cached EPUBs
    func clearCache() {
        for (_, url) in downloadedEPUBs {
            try? FileManager.default.removeItem(at: url)
        }
        downloadedEPUBs.removeAll()
        print("🗑️ FirebaseEPUBService: Cache cleared")
    }
}

