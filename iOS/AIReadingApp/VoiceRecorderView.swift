import SwiftUI
import AVFoundation

struct VoiceRecorderView: View {
    @StateObject private var recorder = AudioRecorderManager()
    @State private var isRecording = false
    @State private var isFinished = false
    @State private var showNamingView = false
    @State private var isPlaying = false
    @State private var recordingTime: TimeInterval = 0
    @State private var audioLevels: [CGFloat] = Array(repeating: 4, count: 40)
    @State private var voiceId: String?
    @State private var errorMessage: String?
    @State private var recordingTimer: Timer?
    @State private var waveformTimer: Timer?
    @State private var recordedAudioURL: URL?
    @State private var storyAudioPlayer: AVAudioPlayer?
    @State private var isGeneratingAudio = false
    @State private var audioPlayerDelegate: AudioPlayerDelegate?
    
    let onVoiceRecorded: (String) -> Void
    
    // Design Tokens - Figma Specification
    private let primaryButton = Color(hex: "F5B5A8")  // Primary interactive buttons
    private let successGreen = Color(hex: "D4F4DD")    // Success background
    private let successGreenIcon = Color(hex: "16A34A") // Checkmark color (green-600)
    private let backgroundGray = Color(hex: "F9FAFB")   // Content area bg (gray-50)
    private let textPrimary = Color(hex: "0F172A")      // Headings (slate-900)
    private let textSecondary = Color(hex: "475569")    // Body text (slate-600)
    private let textTertiary = Color(hex: "334155")     // Labels (slate-700)
    private let borderColor = Color(hex: "E5E7EB")      // Borders (gray-200)
    private let progressBarBg = Color(hex: "E5E7EB")    // Progress bar background
    private let recordingRed = Color(hex: "EF4444")     // Recording dot (red-500)
    
    private let RECORDING_DURATION: TimeInterval = 30.0
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // App Header (positioned 60px down to clear notch/Dynamic Island)
                AppHeaderView(
                    title: "Voice Recorder",
                    onBack: {
                        if isRecording {
                            stopRecording()
                        } else if isFinished {
                            resetToInitial()
                        }
                    }
                )
                .padding(.top, 60)
                    
                    // Content Area
                    ZStack {
                        backgroundGray
                        
                        if isFinished {
                            FinishedStateView(
                                primaryPink: primaryButton,
                                successGreen: successGreen,
                                successGreenIcon: successGreenIcon,
                                textPrimary: textPrimary,
                                textSecondary: textSecondary,
                                borderColor: borderColor,
                                isPlaying: $isPlaying,
                                isGeneratingAudio: isGeneratingAudio,
                                onPlay: togglePlayback
                            )
                        } else if isRecording {
                            RecordingStateView(
                                recordingTime: recordingTime,
                                audioLevels: audioLevels,
                                progress: recordingTime / RECORDING_DURATION,
                                textPrimary: textPrimary,
                                textSecondary: textSecondary,
                                primaryPink: primaryButton,
                                secondaryPink: primaryButton,
                                recordingRed: recordingRed,
                                borderColor: progressBarBg
                            )
                        } else {
                            InitialStateView(
                                primaryPink: primaryButton,
                                textPrimary: textPrimary,
                                textSecondary: textSecondary,
                                onStartRecording: startRecording
                            )
                        }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color.white)
            .onAppear {
                setupAudioLevels()
            }
            
            // Naming View Overlay
            if showNamingView, let audioURL = recordedAudioURL {
                NameRecordingView(
                    audioURL: audioURL,
                    onSave: { voiceId in
                        self.voiceId = voiceId
                        onVoiceRecorded(voiceId)
                        showNamingView = false
                        isFinished = true
                    },
                    onCancel: {
                        showNamingView = false
                        resetToInitial()
                    }
                )
                .transition(.move(edge: .bottom))
                .zIndex(1)
            }
        }
    }
    
    // MARK: - Initial State (Figma Spec)
    struct InitialStateView: View {
        let primaryPink: Color
        let textPrimary: Color
        let textSecondary: Color
        let onStartRecording: () -> Void
        
        var body: some View {
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 0) {
                    // Heading: text-4xl (36px), mb-6 (24px)
                    Text("Ready to Record")
                        .font(.system(size: 36, weight: .regular))
                        .foregroundColor(textPrimary)
                        .padding(.bottom, 24)
                    
                    // Description: Default size (16px), mb-16 (64px), max-w-xs
                    Text("Tap the microphone button below to start recording your voice for 30 seconds")
                        .font(.system(size: 16))
                        .foregroundColor(textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .frame(maxWidth: 280)
                        .padding(.bottom, 64)
                    
                    // Microphone Button: 128×128px, icon 64×64px, shadow-xl
                    Button(action: onStartRecording) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.white)
                            .frame(width: 128, height: 128)
                            .background(primaryPink)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 10)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 25)  // Shift content down by 25px
                
                Spacer()
            }
        }
    }
    
    // MARK: - Recording State (Figma Spec)
    struct RecordingStateView: View {
        let recordingTime: TimeInterval
        let audioLevels: [CGFloat]
        let progress: Double
        let textPrimary: Color
        let textSecondary: Color
        let primaryPink: Color
        let secondaryPink: Color
        let recordingRed: Color
        let borderColor: Color
        
        @State private var isTextExpanded = false
        
        // Snow White text (about 30s of reading)
        let readAloudText = """
Once upon a time, there lived a beautiful princess named Snow White. Her wicked stepmother became jealous of her beauty and ordered a huntsman to take her into the forest. Snow White wandered through the woods and found a cottage belonging to seven dwarfs.
"""
        
        var body: some View {
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 0) {
                    // Read Aloud Card
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text("Read aloud:")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(textPrimary)
                            
                            Spacer()
                            
                            Button(action: {
                                withAnimation {
                                    isTextExpanded.toggle()
                                }
                            }) {
                                Image(systemName: isTextExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                                    .font(.system(size: 16))
                                    .foregroundColor(textSecondary)
                            }
                        }
                        .padding(.bottom, 12)
                        
                        Text(readAloudText)
                            .font(.system(size: 15))
                            .foregroundColor(textSecondary)
                            .lineSpacing(4)
                            .lineLimit(isTextExpanded ? nil : 3)
                            .padding(.bottom, 12)
                        
                        if !isTextExpanded {
                            Text("Tap to expand")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "9CA3AF"))
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(hex: "F3F4F6"))
                    .cornerRadius(12)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                    .onTapGesture {
                        withAnimation {
                            isTextExpanded.toggle()
                        }
                    }
                    
                    // Recording Indicator
                    HStack(spacing: 8) {
                        Circle()
                            .fill(recordingRed)
                            .frame(width: 16, height: 16)
                            .opacity(1.0)
                            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: true)
                        
                        Text("Recording")
                            .font(.system(size: 16))
                            .foregroundColor(textSecondary)
                    }
                    .padding(.bottom, 32)
                    
                    // Waveform: h-32 (128px), 40 bars, 4px width
                    WaveformView(audioLevels: audioLevels, primaryPink: primaryPink)
                        .frame(height: 128)
                        .padding(.horizontal, 24)
                    
                    // Progress Indicator: mt-10 (40px)
                    VStack(spacing: 12) {
                        HStack {
                            Text("Progress")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "334155"))
                            Spacer()
                            Text("\(Int(progress * 100))%")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "334155"))
                        }
                        
                        // Progress bar: h-3 (12px), rounded-full
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 9999)
                                    .fill(Color(hex: "E5E7EB"))
                                    .frame(height: 12)
                                
                                RoundedRectangle(cornerRadius: 9999)
                                    .fill(primaryPink)
                                    .frame(width: geometry.size.width * min(progress, 1.0), height: 12)
                                    .animation(.linear(duration: 1.0), value: progress)
                            }
                        }
                        .frame(height: 12)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 40)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 25)  // Shift content down by 25px
                
                Spacer()
            }
        }
    }
    
    // MARK: - Finished State (Figma Spec)
    struct FinishedStateView: View {
        let primaryPink: Color
        let successGreen: Color
        let successGreenIcon: Color
        let textPrimary: Color
        let textSecondary: Color
        let borderColor: Color
        @Binding var isPlaying: Bool
        let isGeneratingAudio: Bool
        let onPlay: () -> Void
        
        var body: some View {
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 0) {
                    // Success Icon: 96×96px (w-24 h-24), checkmark 48×48px (w-12 h-12), mb-8 (32px)
                    ZStack {
                        Circle()
                            .fill(successGreen)
                            .frame(width: 96, height: 96)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 48, weight: .semibold))
                            .foregroundColor(successGreenIcon)
                    }
                    .padding(.bottom, 32)
                    
                    // Finished Text: text-3xl (30px), tracking-wide, mb-4 (16px)
                    Text("FINISHED!")
                        .font(.system(size: 30, weight: .regular))
                        .tracking(2)
                        .foregroundColor(textPrimary)
                        .padding(.bottom, 16)
                    
                    // Subtitle: Default (16px), mb-16 (64px)
                    Text("Now you can play your AI voice")
                        .font(.system(size: 16))
                        .foregroundColor(textSecondary)
                        .padding(.bottom, 64)
                    
                    // Play/Pause Button: 128×128px, icon 56×56px (h-14 w-14), shadow-xl
                    Button(action: onPlay) {
                        ZStack {
                            if isGeneratingAudio {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.5)
                            } else {
                                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 56))
                                    .foregroundColor(.white)
                                    .offset(x: isPlaying ? 0 : 8)  // ml-2 for visual centering of play icon
                            }
                        }
                        .frame(width: 128, height: 128)
                        .background(primaryPink)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 10)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(isGeneratingAudio)
                    
                    // Info Card: mt-12 (48px), p-4 (16px), rounded-xl, border, shadow-sm
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Your voice has been trained successfully. You can now use this AI voice to read any book in the app.")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "6B7280"))  // text-gray-600
                            .lineSpacing(4)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(borderColor, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                    .padding(.horizontal, 24)
                    .padding(.top, 48)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 25)  // Shift content down by 25px
                
                Spacer()
            }
        }
    }
    
    // MARK: - Waveform View
    struct WaveformView: View {
        let audioLevels: [CGFloat]
        let primaryPink: Color
        
        var body: some View {
            HStack(spacing: 4) {
                ForEach(0..<audioLevels.count, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(primaryPink)
                        .frame(width: 4, height: max(audioLevels[index], 4))
                        .animation(.easeInOut(duration: 0.1), value: audioLevels[index])
                }
            }
        }
    }
    
    // MARK: - Actions
    private func startRecording() {
        isRecording = true
        isFinished = false
        recordingTime = 0
        
        Task {
            do {
                _ = try await recorder.startRecording()
                startTimers()
            } catch {
                errorMessage = error.localizedDescription
                isRecording = false
            }
        }
    }
    
    private func stopRecording() {
        recorder.stopRecording()
        recordingTimer?.invalidate()
        waveformTimer?.invalidate()
        isRecording = false
        recordingTime = 0
        audioLevels = Array(repeating: 4, count: 40)
    }
    
    private func startTimers() {
        // Timer for recording duration
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [self] _ in
            recordingTime += 0.1
            
            if recordingTime >= RECORDING_DURATION {
                finishRecording()
            }
        }
        
        // Timer for waveform animation
        waveformTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [self] _ in
            updateAudioLevels()
        }
    }
    
    private func updateAudioLevels() {
        // Simulate audio levels (in real app, get from audio recorder)
        for i in 0..<audioLevels.count {
            audioLevels[i] = CGFloat.random(in: 4...120)
        }
    }
    
    private func finishRecording() {
        recordingTimer?.invalidate()
        waveformTimer?.invalidate()
        
        if let url = recorder.stopRecording() {
            recordedAudioURL = url
            // Show naming view
            isRecording = false
            showNamingView = true
        } else {
            isRecording = false
        }
    }
    
    private func resetToInitial() {
        isFinished = false
        isRecording = false
        showNamingView = false
        recordingTime = 0
        audioLevels = Array(repeating: 4, count: 40)
        recordedAudioURL = nil
        voiceId = nil
    }
    
    private func togglePlayback() {
        if isPlaying {
            // Stop playback
            storyAudioPlayer?.stop()
            storyAudioPlayer = nil
            audioPlayerDelegate = nil
            isPlaying = false
        } else {
            // Start playback
            playStoryWithClonedVoice()
        }
    }
    
    private func playStoryWithClonedVoice() {
        guard let voiceId = voiceId else { return }
        
        isGeneratingAudio = true
        
        // Snow White story text
        let storyText = """
Once upon a time, in a faraway kingdom, there lived a beautiful princess named Snow White. Her skin was as white as snow, her lips as red as roses, and her hair as black as ebony.

One day, her wicked stepmother, the Queen, became jealous of Snow White's beauty. The Queen ordered a huntsman to take Snow White into the forest. But the huntsman couldn't bring himself to harm the innocent princess, so he let her go free.

Snow White wandered through the forest until she found a small cottage. Inside, she discovered seven little beds, seven little chairs, and seven little everything. The cottage belonged to seven dwarfs who worked in a nearby mine.

When the dwarfs returned home, they found Snow White sleeping in their beds. They welcomed her and asked her to stay with them. Snow White was happy to have found a new home.

But the Queen discovered that Snow White was still alive. She disguised herself as an old peddler woman and visited the cottage with a poisoned apple. When Snow White took a bite, she fell into a deep sleep.

The dwarfs were heartbroken. They placed Snow White in a glass coffin and kept watch over her. One day, a handsome prince came by and saw the beautiful princess. He fell in love with her and kissed her. Snow White awoke, and the spell was broken.

The prince and Snow White were married, and they lived happily ever after. The wicked Queen was never seen again, and peace returned to the kingdom.
"""
        
        Task {
            do {
                // Generate speech using ElevenLabs with cloned voice
                let audioData = try await ElevenLabsService.shared.textToSpeech(
                    voiceId: voiceId,
                    text: storyText
                )
                
                // Save to temporary file
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("snow_white_\(voiceId).mp3")
                try audioData.write(to: tempURL)
                
                await MainActor.run {
                    do {
                        // Create and play audio
                        let player = try AVAudioPlayer(contentsOf: tempURL)
                        
                        // Create delegate and store it to prevent deallocation
                        let delegate = AudioPlayerDelegate(onFinish: {
                            Task { @MainActor in
                                isPlaying = false
                            }
                        })
                        
                        player.delegate = delegate
                        audioPlayerDelegate = delegate
                        storyAudioPlayer = player
                        player.play()
                        isPlaying = true
                        isGeneratingAudio = false
                    } catch {
                        errorMessage = "Failed to play audio: \(error.localizedDescription)"
                        isGeneratingAudio = false
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to generate speech: \(error.localizedDescription)"
                    isGeneratingAudio = false
                }
            }
        }
    }
    
    private func setupAudioLevels() {
        audioLevels = Array(repeating: 4, count: 40)
    }
    
    static func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Supporting Views
struct AppHeaderView: View {
    let title: String
    let onBack: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(hex: "0F172A"))
                    .frame(width: 36, height: 36)
            }
            
            Spacer()
            
            Text(title)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(Color(hex: "0F172A"))
            
            Spacer()
            
            // Spacer for balance
            Color.clear
                .frame(width: 36, height: 36)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color.white)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(hex: "E5E7EB")),
            alignment: .bottom
        )
    }
}

// MARK: - Button Style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Audio Player Delegate
class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    let onFinish: () -> Void
    
    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish()
    }
}

#Preview {
    VoiceRecorderView(onVoiceRecorded: { _ in })
}
