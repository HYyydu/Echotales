import Foundation
import AVFoundation

/// Manages streaming audio playback by generating and playing audio chunks progressively
/// 
/// **User Experience**: From the user's perspective, they click play and audio starts within 2-3 seconds.
/// The streaming/chunking process happens transparently in the background.
/// Users see: Loading → Playing (no technical details exposed)
@MainActor
class StreamingAudioManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published var isGenerating: Bool = false
    @Published var isPlaying: Bool = false
    @Published var currentChunkIndex: Int = 0
    @Published var totalChunks: Int = 0
    @Published var progress: Double = 0.0
    @Published var errorMessage: String?
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    
    // MARK: - Private Properties
    private var audioQueue: [Data] = []
    private var currentPlayer: AVAudioPlayer?
    private var generationTask: Task<Void, Never>?
    private var textChunks: [String] = []
    private var isFinishedGenerating: Bool = false
    private var isStopped: Bool = false
    private var isRequestInProgress: Bool = false  // Track if API request is currently running
    private var isPaused: Bool = false  // Track if user manually paused
    private var voiceIdForGeneration: String = ""  // Store voice ID for resuming generation
    
    // Audio session
    private let audioSession = AVAudioSession.sharedInstance()
    
    // Configuration
    private let maxConcurrentRequests = 3
    private let prefetchBuffer = 2 // Keep 2 chunks ahead in queue
    private let minimumBufferBeforePlay = 2 // Require 2 chunks ready before starting playback
    
    // MARK: - Public Methods
    
    /// Start streaming audio generation and playback
    func startStreaming(text: String, voiceId: String) {
        // Stop any existing playback/generation first
        stop()
        
        // Reset all state for fresh start
        resetState()
        
        print("🎵 Starting streaming audio for text length: \(text.count)")
        
        // Split text into paragraphs
        textChunks = splitIntoParagraphs(text)
        totalChunks = textChunks.count
        voiceIdForGeneration = voiceId
        
        guard !textChunks.isEmpty else {
            errorMessage = "No content to play"
            return
        }
        
        print("📝 Split into \(textChunks.count) paragraph chunks")
        print("🎯 Starting continuous generation (will stop only if user pauses)")
        
        isGenerating = true
        isStopped = false
        isPaused = false
        
        // Start generation task - generate ALL chunks continuously
        generationTask = Task {
            await generateAndPlayChunks(voiceId: voiceId)
        }
    }
    
    /// Pause playback
    func pause() {
        currentPlayer?.pause()
        isPlaying = false
        isPaused = true
        
        // Cancel ongoing generation to save API costs
        print("⏸️ Paused playback - stopping generation to save API costs")
        generationTask?.cancel()
        generationTask = nil
        isGenerating = false
    }
    
    /// Resume playback
    func resume() {
        isPaused = false
        
        // For resume, we need at least 2 chunks (current + next) or 3 if starting fresh
        let requiredBuffer = (currentChunkIndex == 0) ? 3 : minimumBufferBeforePlay
        let needsBuffering = audioQueue.count < requiredBuffer && !isFinishedGenerating
        
        // Resume generation if not finished
        if !isFinishedGenerating && !isGenerating {
            let nextChunkToGenerate = currentChunkIndex + audioQueue.count
            if nextChunkToGenerate < textChunks.count {
                if needsBuffering {
                    let chunksNeeded = requiredBuffer - audioQueue.count
                    print("🔄 Resuming generation from chunk \(nextChunkToGenerate + 1) (need \(chunksNeeded) chunk(s) for buffer, then continue)")
                } else {
                    print("🔄 Resuming generation from chunk \(nextChunkToGenerate + 1) (continuous generation)")
                }
                isGenerating = true
                generationTask = Task {
                    // Always generate all remaining chunks, but playback will wait for buffer
                    await generateAndPlayChunks(voiceId: voiceIdForGeneration, startFromChunk: nextChunkToGenerate)
                }
            }
        }
        
        // If we need buffering and no player is active, wait for chunks
        if needsBuffering && currentPlayer == nil {
            print("⏸️ Waiting for \(requiredBuffer) chunks to be ready before resuming...")
            return
        }
        
        guard let player = currentPlayer else {
            // If no current player but we have enough queued audio, play next
            if audioQueue.count >= requiredBuffer || isFinishedGenerating {
                playNextChunk()
            }
            return
        }
        
        // Ensure audio session is active before resuming
        do {
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
        } catch {
            print("❌ Failed to activate audio session: \(error.localizedDescription)")
            errorMessage = "Failed to resume audio"
            return
        }
        
        player.play()
        isPlaying = true
        print("▶️ Resumed playback")
    }
    
    /// Stop all generation and playback
    func stop() {
        print("⏹️ FORCE STOPPING streaming audio")
        
        // CRITICAL: Set stopped flag FIRST - this blocks all new work
        isStopped = true
        
        // Immediately update UI state so user sees instant feedback
        isPlaying = false
        isGenerating = false
        
        // Cancel the background generation task immediately
        // This sets Task.isCancelled = true
        generationTask?.cancel()
        generationTask = nil
        
        // Stop audio playback immediately
        currentPlayer?.stop()
        currentPlayer = nil
        
        // Clear audio queue - no more chunks will play
        audioQueue.removeAll()
        
        // Reset time tracking
        currentTime = 0
        duration = 0
        
        // Log if there's a request in progress (it will complete but be discarded)
        if isRequestInProgress {
            print("⚠️ Network request in progress, will discard result when complete")
        }
        
        print("✅ STOP EXECUTED - Loop will exit at next checkpoint (max 3s if request in flight)")
    }
    
    /// Update current time from the audio player
    func updateTime() {
        guard let player = currentPlayer else {
            currentTime = 0
            duration = 0
            return
        }
        
        currentTime = player.currentTime
        duration = player.duration
    }
    
    // MARK: - Private Methods
    
    private func resetState() {
        audioQueue.removeAll()
        textChunks.removeAll()
        currentChunkIndex = 0
        totalChunks = 0
        progress = 0.0
        errorMessage = nil
        isFinishedGenerating = false
        isStopped = false  // Reset stopped flag for new playback
        isRequestInProgress = false  // Reset request tracking
        isPaused = false
        voiceIdForGeneration = ""
        currentTime = 0
        duration = 0
    }
    
    private func generateAndPlayChunks(voiceId: String, maxChunks: Int? = nil, startFromChunk: Int = 0) async {
        var failedChunks = 0
        
        let chunksToGenerate = maxChunks ?? (textChunks.count - startFromChunk)
        let endIndex = min(startFromChunk + chunksToGenerate, textChunks.count)
        
        print("📊 Generating chunks \(startFromChunk + 1) to \(endIndex) (total: \(textChunks.count))")
        
        for index in startFromChunk..<endIndex {
            let chunk = textChunks[index]
            // Check if stopped BEFORE starting any work
            if isStopped {
                print("🛑 Generation stopped by user (before chunk \(index + 1))")
                await MainActor.run {
                    isGenerating = false
                }
                return
            }
            
            // Check if task is cancelled (user paused)
            if Task.isCancelled {
                print("⏸️ Generation cancelled by user pause (at chunk \(index + 1))")
                await MainActor.run {
                    isGenerating = false
                }
                return
            }
            
            do {
                // CRITICAL CHECK: Don't start ANY new work if stopped
                guard !isStopped && !Task.isCancelled else {
                    print("🛑 BLOCKED: Stop detected before chunk \(index + 1)")
                    await MainActor.run {
                        isGenerating = false
                    }
                    return
                }
                
                print("🎤 Generating chunk \(index + 1)/\(textChunks.count) (\(chunk.count) chars)")
                
                // Mark that a request is starting
                await MainActor.run {
                    isRequestInProgress = true
                }
                
                // Triple-check stop status right before API call
                guard !isStopped && !Task.isCancelled else {
                    print("🛑 BLOCKED: Stop detected right before API call for chunk \(index + 1)")
                    await MainActor.run {
                        isGenerating = false
                        isRequestInProgress = false
                    }
                    return
                }
                
                // Generate audio for this chunk
                // NOTE: This await cannot be cancelled mid-flight (URLSession limitation)
                // It will run to completion (~2-3s) but result will be discarded if stopped
                let audioData = try await ElevenLabsService.shared.textToSpeech(
                    voiceId: voiceId,
                    text: chunk
                )
                
                // Mark that request completed
                await MainActor.run {
                    isRequestInProgress = false
                }
                
                // CRITICAL CHECK: Verify we're still running after API call
                guard !isStopped && !Task.isCancelled else {
                    print("🛑 DISCARDED: Chunk \(index + 1) generated but stop was called, discarding \(audioData.count) bytes")
                    await MainActor.run {
                        isGenerating = false
                    }
                    return
                }
                
                print("✅ Generated chunk \(index + 1): \(audioData.count) bytes")
                
                await MainActor.run {
                    // Add to queue
                    audioQueue.append(audioData)
                    
                    // Update progress based on currentChunkIndex + queue size
                    let totalGenerated = currentChunkIndex + audioQueue.count
                    progress = Double(totalGenerated) / Double(totalChunks)
                    
                    print("📦 Generated chunk \(index + 1), Queue now has \(audioQueue.count) chunk(s), currentChunkIndex=\(currentChunkIndex), isPlaying=\(isPlaying)")
                    
                    // Check if we should start/resume playing
                    // For initial playback (currentChunkIndex == 0), need 3 chunks so after playing chunk 1, we have 2 left
                    // For resume after buffering (currentChunkIndex > 0), need 2 chunks
                    let requiredBuffer = (currentChunkIndex == 0) ? 3 : minimumBufferBeforePlay
                    
                    if !isPlaying && audioQueue.count >= requiredBuffer && currentChunkIndex == 0 {
                        print("🎵 Initial buffer ready (\(audioQueue.count) chunks in queue, need \(requiredBuffer)), attempting to start playback...")
                        playNextChunk()
                    } else if !isPlaying && audioQueue.count >= minimumBufferBeforePlay && currentChunkIndex > 0 {
                        // Resume after buffering pause
                        print("🎵 Buffer refilled (\(audioQueue.count) chunks in queue), attempting to resume playback...")
                        playNextChunk()
                    } else {
                        print("⏳ Not starting playback yet: isPlaying=\(isPlaying), queueCount=\(audioQueue.count), currentChunkIndex=\(currentChunkIndex), need \(requiredBuffer) chunks")
                    }
                }
                
                // Small delay to avoid rate limiting (only if not the last chunk we're generating)
                if index < endIndex - 1 {
                    // CRITICAL: Check stop before sleeping
                    guard !isStopped && !Task.isCancelled else {
                        print("🛑 BLOCKED: Stop detected before sleep")
                        await MainActor.run {
                            isGenerating = false
                        }
                        return
                    }
                    
                    // Use Task.sleep with cancellation check
                    do {
                        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    } catch {
                        // Sleep was cancelled, stop generation IMMEDIATELY
                        print("🛑 CANCELLED: Sleep interrupted, stopping generation loop")
                        await MainActor.run {
                            isGenerating = false
                        }
                        return
                    }
                    
                    // Check again after sleep
                    guard !isStopped && !Task.isCancelled else {
                        print("🛑 BLOCKED: Stop detected after sleep")
                        await MainActor.run {
                            isGenerating = false
                        }
                        return
                    }
                }
                
            } catch {
                print("❌ Failed to generate chunk \(index + 1): \(error.localizedDescription)")
                failedChunks += 1
                
                // If we fail too many chunks, show error
                if failedChunks > 3 {
                    await MainActor.run {
                        errorMessage = "Failed to generate audio: \(error.localizedDescription)"
                        isGenerating = false
                    }
                    return
                }
                
                // Otherwise, continue with next chunk
                continue
            }
        }
        
        await MainActor.run {
            // Check if we've generated all chunks
            if endIndex >= textChunks.count {
                isFinishedGenerating = true
                print("✅ Finished generating ALL chunks (generated up to chunk \(endIndex))")
            } else {
                print("⏸️ Generated chunks up to \(endIndex). Will resume generation when needed.")
            }
            isGenerating = false
        }
    }
    
    private func playNextChunk() {
        print("🔍 playNextChunk called: queue=\(audioQueue.count), currentChunkIndex=\(currentChunkIndex), isPlaying=\(isPlaying), isFinished=\(isFinishedGenerating)")
        
        // Check buffer requirement:
        // - Need at least 2 chunks to play (ensures next chunk is ready)
        // - UNLESS generation is finished (then play remaining chunks)
        let hasMinimumBuffer = audioQueue.count >= 2 || isFinishedGenerating
        
        print("   Buffer check: hasMinimumBuffer=\(hasMinimumBuffer), queueCount=\(audioQueue.count), minimumRequired=\(minimumBufferBeforePlay)")
        
        if !hasMinimumBuffer {
            print("❌ BLOCKED: Waiting for buffer: only \(audioQueue.count) chunk(s) in queue, need at least 2")
            
            // CRITICAL: Set isPlaying to false so buffer refill can trigger playback
            isPlaying = false
            print("   ⏸️ Set isPlaying=false to wait for buffer refill")
            
            // Resume generation if not currently generating
            if !isGenerating && !isPaused && !isStopped {
                let nextChunkToGenerate = currentChunkIndex + audioQueue.count
                if nextChunkToGenerate < textChunks.count {
                    print("🔄 Buffering: resuming generation from chunk \(nextChunkToGenerate + 1)")
                    isGenerating = true
                    generationTask = Task {
                        await generateAndPlayChunks(voiceId: voiceIdForGeneration, startFromChunk: nextChunkToGenerate)
                    }
                }
            }
            return
        }
        
        guard !audioQueue.isEmpty else {
            print("⚠️ No chunks in queue to play")
            
            // If generation is finished and queue is empty, we're done
            if isFinishedGenerating {
                print("✅ Playback complete")
                isPlaying = false
                currentChunkIndex = 0
            }
            return
        }
        
        // Log buffer status BEFORE removing chunk
        print("✅ Buffer check passed. About to play chunk \(currentChunkIndex + 1)")
        if isFinishedGenerating && audioQueue.count < 2 {
            print("   📢 Playing remaining chunk (generation complete, \(audioQueue.count) left in queue)")
        } else {
            print("   ▶️ Playing with good buffer: \(audioQueue.count) chunk(s) in queue before removal")
        }
        
        let audioData = audioQueue.removeFirst()
        print("   🎬 Removed chunk from queue, queue now has \(audioQueue.count) chunk(s) remaining")
        
        currentChunkIndex += 1
        
        do {
            // Configure audio session
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
            
            // Save to temp file
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("streaming_chunk_\(currentChunkIndex)_\(UUID().uuidString).m4a")
            try audioData.write(to: tempURL)
            
            // Create player
            let player = try AVAudioPlayer(contentsOf: tempURL)
            player.delegate = self
            player.prepareToPlay()
            player.play()
            
            currentPlayer = player
            isPlaying = true
            
            // Initialize time values for this chunk
            currentTime = player.currentTime
            duration = player.duration
            
            print("🎵 NOW PLAYING chunk \(currentChunkIndex)/\(totalChunks) (duration: \(duration)s, \(audioQueue.count) chunk(s) remaining in buffer)")
            
        } catch {
            print("❌ Failed to play chunk: \(error.localizedDescription)")
            errorMessage = "Failed to play audio"
            
            // Try next chunk if available
            if !audioQueue.isEmpty {
                playNextChunk()
            }
        }
    }
    
    private func splitIntoParagraphs(_ text: String) -> [String] {
        // Split by double newlines (paragraphs)
        let paragraphs = text.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        // Further split if any paragraph is too long (over 3000 chars)
        var chunks: [String] = []
        
        for paragraph in paragraphs {
            if paragraph.count <= 3000 {
                chunks.append(paragraph)
            } else {
                // Split long paragraph by sentences
                let sentences = splitIntoSentences(paragraph)
                var currentChunk = ""
                
                for sentence in sentences {
                    if currentChunk.count + sentence.count > 3000 {
                        if !currentChunk.isEmpty {
                            chunks.append(currentChunk.trimmingCharacters(in: .whitespacesAndNewlines))
                            currentChunk = ""
                        }
                        
                        // If single sentence is too long, force split
                        if sentence.count > 3000 {
                            let forceSplit = forceSplitText(sentence, maxLength: 3000)
                            chunks.append(contentsOf: forceSplit)
                        } else {
                            currentChunk = sentence
                        }
                    } else {
                        currentChunk += (currentChunk.isEmpty ? "" : " ") + sentence
                    }
                }
                
                if !currentChunk.isEmpty {
                    chunks.append(currentChunk.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            }
        }
        
        print("📊 Split text into \(chunks.count) chunks")
        for (index, chunk) in chunks.enumerated() {
            print("   Chunk \(index + 1): \(chunk.count) chars")
        }
        
        return chunks
    }
    
    private func splitIntoSentences(_ text: String) -> [String] {
        let sentenceEndings = CharacterSet(charactersIn: ".!?")
        var sentences: [String] = []
        var currentSentence = ""
        
        for char in text {
            currentSentence.append(char)
            if let scalar = char.unicodeScalars.first, sentenceEndings.contains(scalar) {
                sentences.append(currentSentence.trimmingCharacters(in: .whitespaces))
                currentSentence = ""
            }
        }
        
        if !currentSentence.isEmpty {
            sentences.append(currentSentence.trimmingCharacters(in: .whitespaces))
        }
        
        return sentences.filter { !$0.isEmpty }
    }
    
    private func forceSplitText(_ text: String, maxLength: Int) -> [String] {
        var chunks: [String] = []
        var startIndex = text.startIndex
        
        while startIndex < text.endIndex {
            let endIndex = text.index(startIndex, offsetBy: maxLength, limitedBy: text.endIndex) ?? text.endIndex
            chunks.append(String(text[startIndex..<endIndex]))
            startIndex = endIndex
        }
        
        return chunks
    }
}

// MARK: - AVAudioPlayerDelegate

extension StreamingAudioManager: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            print("✅ Chunk \(currentChunkIndex) finished playing successfully: \(flag)")
            print("   Queue state: \(audioQueue.count) chunk(s) in queue, isFinishedGenerating=\(isFinishedGenerating)")
            
            // Clean up temp file
            try? FileManager.default.removeItem(at: player.url!)
            
            // Play next chunk if available
            if !audioQueue.isEmpty || !isFinishedGenerating {
                print("   ⏭️ Preparing to play next chunk...")
                // Small delay before next chunk for smooth transition
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                playNextChunk()
            } else {
                // All done
                print("🎉 All chunks played successfully")
                isPlaying = false
                currentChunkIndex = 0
                progress = 1.0
            }
        }
    }
    
    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            print("❌ Audio player decode error: \(error?.localizedDescription ?? "unknown")")
            
            // Try next chunk
            if !audioQueue.isEmpty {
                playNextChunk()
            } else {
                errorMessage = "Audio playback error"
                isPlaying = false
            }
        }
    }
}

