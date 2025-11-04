import Foundation
import AVFoundation

class AudioRecorderManager: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0
    
    private var audioRecorder: AVAudioRecorder?
    private var recordingTimer: Timer?
    private var audioSession: AVAudioSession = AVAudioSession.sharedInstance()
    
    func requestMicrophonePermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            audioSession.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    func startRecording() async throws -> URL {
        // Request permission
        let hasPermission = await requestMicrophonePermission()
        guard hasPermission else {
            throw RecordingError.microphonePermissionDenied
        }
        
        // Configure audio session
        try audioSession.setCategory(.playAndRecord, mode: .default)
        try audioSession.setActive(true)
        
        // Get documents directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = documentsPath.appendingPathComponent("recording.m4a")
        
        // Audio settings
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 2,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        // Create recorder
        audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
        audioRecorder?.delegate = self
        audioRecorder?.record()
        
        isRecording = true
        recordingTime = 0
        
        // Start timer
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.recordingTime += 0.1
        }
        
        return audioFilename
    }
    
    func stopRecording() -> URL? {
        guard let recorder = audioRecorder else { return nil }
        
        let url = recorder.url
        recorder.stop()
        audioRecorder = nil
        
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        isRecording = false
        
        try? audioSession.setActive(false)
        
        return url
    }
    
    enum RecordingError: LocalizedError {
        case microphonePermissionDenied
        case recordingFailed
        
        var errorDescription: String? {
            switch self {
            case .microphonePermissionDenied:
                return "Microphone access denied. Please allow microphone permissions in Settings."
            case .recordingFailed:
                return "Failed to start recording. Please try again."
            }
        }
    }
}

