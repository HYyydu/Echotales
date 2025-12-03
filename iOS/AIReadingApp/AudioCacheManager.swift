import Foundation
import AVFoundation

/// Manages local caching of voice sample audio files
class AudioCacheManager {
    static let shared = AudioCacheManager()
    
    // The sample text used for voice previews (must match the recording text)
    static let sampleText = """
Once upon a time, there lived a beautiful princess named Snow White. Her wicked stepmother became jealous of her beauty and ordered a huntsman to take her into the forest. Snow White wandered through the woods and found a cottage belonging to seven dwarfs.
"""
    
    private let cacheDirectory: URL
    
    private init() {
        // Create cache directory in Documents folder
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        cacheDirectory = documentsPath.appendingPathComponent("VoiceSamples", isDirectory: true)
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        print("📂 Audio cache directory: \(cacheDirectory.path)")
    }
    
    /// Get the cache file URL for a specific voice ID
    func cacheFileURL(for voiceId: String) -> URL {
        return cacheDirectory.appendingPathComponent("sample_\(voiceId).mp3")
    }
    
    /// Check if cached audio exists for a voice ID
    func hasCachedAudio(for voiceId: String) -> Bool {
        let fileURL = cacheFileURL(for: voiceId)
        let exists = FileManager.default.fileExists(atPath: fileURL.path)
        print("🔍 Cache check for \(voiceId): \(exists ? "✅ EXISTS" : "❌ NOT FOUND")")
        return exists
    }
    
    /// Save audio data to cache for a voice ID
    func cacheAudio(_ audioData: Data, for voiceId: String) throws {
        let fileURL = cacheFileURL(for: voiceId)
        try audioData.write(to: fileURL)
        print("💾 Cached audio for \(voiceId) (\(audioData.count) bytes) at: \(fileURL.path)")
    }
    
    /// Get cached audio data for a voice ID
    func getCachedAudio(for voiceId: String) -> Data? {
        let fileURL = cacheFileURL(for: voiceId)
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("❌ No cached audio found for \(voiceId)")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            print("✅ Retrieved cached audio for \(voiceId) (\(data.count) bytes)")
            return data
        } catch {
            print("❌ Error reading cached audio for \(voiceId): \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Delete cached audio for a voice ID
    func deleteCachedAudio(for voiceId: String) {
        let fileURL = cacheFileURL(for: voiceId)
        
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
                print("🗑️ Deleted cached audio for \(voiceId)")
            }
        } catch {
            print("❌ Error deleting cached audio for \(voiceId): \(error.localizedDescription)")
        }
    }
    
    /// Clear all cached audio files
    func clearAllCache() {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            for file in files {
                try FileManager.default.removeItem(at: file)
            }
            print("🗑️ Cleared all cached audio files (\(files.count) files)")
        } catch {
            print("❌ Error clearing cache: \(error.localizedDescription)")
        }
    }
    
    /// Get the total size of cached audio files
    func getCacheSize() -> Int64 {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey])
            
            let totalSize = files.reduce(Int64(0)) { total, file in
                let fileSize = (try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                return total + Int64(fileSize)
            }
            
            print("📊 Total cache size: \(formatBytes(totalSize)) (\(files.count) files)")
            return totalSize
        } catch {
            print("❌ Error calculating cache size: \(error.localizedDescription)")
            return 0
        }
    }
    
    /// Generate and cache audio sample for a voice ID
    /// Returns the cached file URL on success
    func generateAndCacheSample(for voiceId: String) async throws -> URL {
        print("🎤 Generating sample audio for voice: \(voiceId)")
        
        // Check if already cached
        if hasCachedAudio(for: voiceId) {
            print("✅ Audio already cached, returning existing file")
            return cacheFileURL(for: voiceId)
        }
        
        // Generate audio using ElevenLabs
        let audioData = try await ElevenLabsService.shared.textToSpeech(
            voiceId: voiceId,
            text: AudioCacheManager.sampleText
        )
        
        print("✅ Generated audio (\(audioData.count) bytes)")
        
        // Cache the audio
        try cacheAudio(audioData, for: voiceId)
        
        return cacheFileURL(for: voiceId)
    }
    
    // MARK: - Helper Methods
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

