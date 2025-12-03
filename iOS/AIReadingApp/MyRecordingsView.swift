import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import AVFoundation

// MARK: - Voice Recording Model
struct VoiceRecording: Identifiable, Codable {
    let id: String
    let name: String
    let voiceId: String
    let createdAt: Date
    let userId: String
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
}

// MARK: - My Recordings View
struct MyRecordingsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var recordings: [VoiceRecording] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var playingVoiceId: String?
    @State private var isGeneratingAudio = false
    @State private var audioPlayer: AVAudioPlayer?
    @State private var audioPlayerDelegate: AudioPlayerDelegate?
    @State private var showDiagnostics = false
    @State private var recordingToDelete: VoiceRecording?
    @State private var showDeleteConfirmation = false
    
    // Design tokens
    private let primaryPink = Color(hex: "F9DAD2")
    private let secondaryPink = Color(hex: "F5B5A8")
    private let textPrimary = Color(hex: "0F172A")
    private let textSecondary = Color(hex: "475569")
    private let textTertiary = Color(hex: "6B7280")
    private let borderColor = Color(hex: "E5E7EB")
    private let bgGray = Color(hex: "F9FAFB")
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom Navigation Bar
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(textPrimary)
                }
                
                Spacer()
                
                Text("My Recordings")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(textPrimary)
                
                Spacer()
                
                // Invisible placeholder for symmetry
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.clear)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .padding(.top, 22)
            .background(Color.white)
            
            // Divider
            Rectangle()
                .fill(borderColor)
                .frame(height: 1)
            
            // Content
            if isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(secondaryPink)
                    Text("Loading recordings...")
                        .font(.system(size: 16))
                        .foregroundColor(textSecondary)
                        .padding(.top, 16)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(bgGray)
            } else if recordings.isEmpty {
                // Empty State
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
                    
                    Text("Your voice recordings will appear here after you record them in the Record tab")
                        .font(.system(size: 15))
                        .foregroundColor(textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(bgGray)
            } else {
                // Recordings List
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(recordings) { recording in
                            RecordingCard(
                                recording: recording,
                                isPlaying: playingVoiceId == recording.voiceId,
                                isGenerating: isGeneratingAudio && playingVoiceId == recording.voiceId,
                                onTap: {
                                    togglePlayback(for: recording)
                                },
                                onDelete: {
                                    recordingToDelete = recording
                                    showDeleteConfirmation = true
                                }
                            )
                        }
                    }
                    .padding(20)
                }
                .background(bgGray)
            }
        }
        .navigationBarHidden(true)
        .background(Color.white)
        .onAppear {
            loadRecordings()
        }
        .alert("Error", isPresented: .constant(errorMessage != nil), presenting: errorMessage) { _ in
            Button("OK") {
                errorMessage = nil
            }
        } message: { message in
            Text(message)
        }
        .confirmationDialog(
            "Delete Recording",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible,
            presenting: recordingToDelete
        ) { recording in
            Button("Yes, Delete", role: .destructive) {
                deleteRecording(recording)
            }
            Button("No, Keep It", role: .cancel) {
                recordingToDelete = nil
            }
        } message: { recording in
            Text("Are you sure you want to delete \"\(recording.name)\"? This action cannot be undone.")
        }
    }
    
    private func loadRecordings() {
        print("🔍 Loading recordings...")
        
        guard let userId = Auth.auth().currentUser?.uid else {
            print("⚠️ No user logged in - cannot load recordings")
            print("   - Auth.auth().currentUser is nil")
            isLoading = false
            return
        }
        
        print("📱 Current user ID: \(userId)")
        
        let db = Firestore.firestore()
        print("🔍 Querying Firestore collection 'voiceRecordings'...")
        print("   - Filtering by userId: \(userId)")
        
        db.collection("voiceRecordings")
            .whereField("userId", isEqualTo: userId)
            // Note: Ordering removed temporarily - recordings will show in random order
            // To enable ordering, create the Firestore index from the error message link
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                
                if let error = error {
                    print("❌ Error loading recordings: \(error.localizedDescription)")
                    print("   - Error details: \(error)")
                    DispatchQueue.main.async {
                        self.errorMessage = "Failed to load recordings: \(error.localizedDescription)"
                    }
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("📝 No documents in snapshot")
                    return
                }
                
                print("📦 Found \(documents.count) document(s) in Firestore")
                
                let fetchedRecordings = documents.compactMap { doc -> VoiceRecording? in
                    let data = doc.data()
                    print("   📄 Document ID: \(doc.documentID)")
                    print("      - Data: \(data)")
                    
                    guard let name = data["name"] as? String,
                          let voiceId = data["voiceId"] as? String,
                          let userId = data["userId"] as? String,
                          let timestamp = data["createdAt"] as? Timestamp else {
                        print("      ⚠️ Failed to decode recording: \(doc.documentID)")
                        print("         - name: \(data["name"] ?? "nil")")
                        print("         - voiceId: \(data["voiceId"] ?? "nil")")
                        print("         - userId: \(data["userId"] ?? "nil")")
                        print("         - createdAt: \(data["createdAt"] ?? "nil")")
                        return nil
                    }
                    
                    print("      ✅ Successfully decoded: \(name)")
                    
                    return VoiceRecording(
                        id: doc.documentID,
                        name: name,
                        voiceId: voiceId,
                        createdAt: timestamp.dateValue(),
                        userId: userId
                    )
                }
                
                print("✅ Successfully loaded \(fetchedRecordings.count) recording(s)")
                DispatchQueue.main.async {
                    // Sort recordings by date (newest first) on the client side
                    self.recordings = fetchedRecordings.sorted { $0.createdAt > $1.createdAt }
                }
            }
    }
    
    private func deleteRecording(_ recording: VoiceRecording) {
        print("🗑️ Deleting recording: \(recording.name) (ID: \(recording.id))")
        
        // Stop playback if this recording is currently playing
        if playingVoiceId == recording.voiceId {
            stopPlayback()
        }
        
        let db = Firestore.firestore()
        
        db.collection("voiceRecordings").document(recording.id).delete { error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Error deleting recording: \(error.localizedDescription)")
                    self.errorMessage = "Failed to delete recording: \(error.localizedDescription)"
                } else {
                    print("✅ Recording deleted successfully")
                    
                    // Delete cached audio file as well
                    AudioCacheManager.shared.deleteCachedAudio(for: recording.voiceId)
                    
                    // Remove from local array
                    self.recordings.removeAll { $0.id == recording.id }
                }
                
                // Clear the recording to delete
                self.recordingToDelete = nil
            }
        }
    }
    
    private func togglePlayback(for recording: VoiceRecording) {
        if playingVoiceId == recording.voiceId {
            // Stop current playback
            stopPlayback()
        } else {
            // Start new playback
            playStoryWithVoice(recording)
        }
    }
    
    private func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        audioPlayerDelegate = nil
        playingVoiceId = nil
    }
    
    private func playStoryWithVoice(_ recording: VoiceRecording) {
        print("🎵 Starting playback with voice: \(recording.name) (ID: \(recording.voiceId))")
        
        // Stop any current playback
        stopPlayback()
        
        playingVoiceId = recording.voiceId
        isGeneratingAudio = true
        
        Task {
            do {
                // Try to use cached audio first (much faster and no API cost!)
                let audioURL: URL
                if AudioCacheManager.shared.hasCachedAudio(for: recording.voiceId) {
                    print("✅ Using cached audio - instant playback!")
                    audioURL = AudioCacheManager.shared.cacheFileURL(for: recording.voiceId)
                    
                    // Set generating to false immediately since we're using cache
                    await MainActor.run {
                        isGeneratingAudio = false
                    }
                } else {
                    print("⚠️ No cache found, generating new audio (this will use ElevenLabs API)...")
                    
                    // Check if user is authenticated before making API call
                    guard Auth.auth().currentUser != nil else {
                        print("❌ User is not authenticated!")
                        throw NSError(domain: "Authentication", code: 401, userInfo: [
                            NSLocalizedDescriptionKey: "You must be signed in to play voice recordings. Please sign out and sign in again."
                        ])
                    }
                    
                    // Generate and cache if not already cached
                    audioURL = try await AudioCacheManager.shared.generateAndCacheSample(for: recording.voiceId)
                    
                    await MainActor.run {
                        isGeneratingAudio = false
                    }
                }
                
                await MainActor.run {
                    do {
                        print("🔊 Configuring audio session for playback...")
                        // Configure audio session for playback
                        let audioSession = AVAudioSession.sharedInstance()
                        try audioSession.setCategory(.playback, mode: .default)
                        try audioSession.setActive(true)
                        print("✅ Audio session configured")
                        
                        // Create and play audio
                        print("🎵 Creating audio player...")
                        let player = try AVAudioPlayer(contentsOf: audioURL)
                        player.prepareToPlay()
                        
                        // Create delegate and store it to prevent deallocation
                        let delegate = AudioPlayerDelegate(onFinish: {
                            Task { @MainActor in
                                print("✅ Audio playback finished")
                                self.playingVoiceId = nil
                            }
                        })
                        
                        player.delegate = delegate
                        audioPlayerDelegate = delegate
                        audioPlayer = player
                        
                        print("▶️ Starting playback...")
                        let success = player.play()
                        print(success ? "✅ Playback started successfully" : "❌ Failed to start playback")
                    } catch {
                        print("❌ Failed to play audio: \(error.localizedDescription)")
                        errorMessage = "Failed to play audio: \(error.localizedDescription)"
                        playingVoiceId = nil
                    }
                }
            } catch {
                print("❌ Failed to load audio: \(error.localizedDescription)")
                print("❌ Full error details: \(error)")
                
                await MainActor.run {
                    var displayError = "Failed to load audio: \(error.localizedDescription)"
                    
                    // More user-friendly error messages
                    if (error as NSError).domain == "Authentication" {
                        displayError = error.localizedDescription
                    } else if (error as NSError).localizedDescription.contains("authentication") ||
                       (error as NSError).localizedDescription.contains("unauthorized") {
                        displayError = "Authentication error. Please sign out and sign in again."
                    } else if (error as NSError).localizedDescription.contains("network") {
                        displayError = "Network error. Please check your internet connection."
                    }
                    
                    errorMessage = displayError
                    isGeneratingAudio = false
                    playingVoiceId = nil
                }
            }
        }
    }
}

// MARK: - Recording Card
struct RecordingCard: View {
    let recording: VoiceRecording
    let isPlaying: Bool
    let isGenerating: Bool
    let onTap: () -> Void
    let onDelete: () -> Void
    
    private let primaryPink = Color(hex: "F9DAD2")
    private let secondaryPink = Color(hex: "F5B5A8")
    private let textPrimary = Color(hex: "0F172A")
    private let textSecondary = Color(hex: "475569")
    private let textTertiary = Color(hex: "6B7280")
    private let borderColor = Color(hex: "E5E7EB")
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(primaryPink)
                        .frame(width: 56, height: 56)
                    
                    if isGenerating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: secondaryPink))
                    } else if isPlaying {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 24))
                            .foregroundColor(secondaryPink)
                    } else {
                        Image(systemName: "play.fill")
                            .font(.system(size: 24))
                            .foregroundColor(secondaryPink)
                    }
                }
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(recording.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(textPrimary)
                    
                    if isPlaying {
                        Text("Playing sample...")
                            .font(.system(size: 13))
                            .foregroundColor(secondaryPink)
                    } else if isGenerating {
                        Text("Generating audio...")
                            .font(.system(size: 13))
                            .foregroundColor(secondaryPink)
                    } else {
                        Text(recording.formattedDate)
                            .font(.system(size: 13))
                            .foregroundColor(textSecondary)
                    }
                    
                    Text("Voice ID: \(recording.voiceId)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(textTertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                
                Spacer()
                
                // Delete Button
                Button(action: {
                    onDelete()
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: "EF4444"))
                        .frame(width: 44, height: 44)
                        .background(Color(hex: "FEE2E2"))
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Status Icon
                if isPlaying || isGenerating {
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 24))
                        .foregroundColor(secondaryPink)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color(hex: "10B981"))
                }
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isPlaying ? secondaryPink : borderColor, lineWidth: isPlaying ? 2 : 1)
            )
            .shadow(color: .black.opacity(isPlaying ? 0.08 : 0.04), radius: isPlaying ? 12 : 8, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    MyRecordingsView()
}

