import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct NameRecordingView: View {
    @Environment(\.dismiss) var dismiss
    let audioURL: URL
    let onSave: (String) -> Void
    let onCancel: () -> Void
    
    @State private var recordingName: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var isTextFieldFocused: Bool
    
    // Design Tokens
    private let primaryButton = Color(hex: "F5B5A8")
    private let backgroundGray = Color(hex: "F9FAFB")
    private let textPrimary = Color(hex: "0F172A")
    private let textSecondary = Color(hex: "475569")
    private let textTertiary = Color(hex: "334155")
    private let borderColor = Color(hex: "E5E7EB")
    
    var body: some View {
        VStack(spacing: 0) {
            // App Header
            HStack {
                Button(action: {
                    if !isSaving {
                        onCancel()
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(textPrimary)
                        .frame(width: 36, height: 36)
                }
                
                Spacer()
                
                Text("Name Your Recording")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(textPrimary)
                
                Spacer()
                
                // Spacer for balance
                Color.clear
                    .frame(width: 36, height: 36)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .padding(.top, 60)
            .background(Color.white)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(borderColor),
                alignment: .bottom
            )
            
            // Content Area
            ZStack {
                backgroundGray
                
                VStack(spacing: 0) {
                    Spacer()
                    
                    VStack(spacing: 0) {
                        // Icon
                        ZStack {
                            Circle()
                                .fill(Color(hex: "D4F4DD"))
                                .frame(width: 96, height: 96)
                            
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 48, weight: .semibold))
                                .foregroundColor(Color(hex: "16A34A"))
                        }
                        .padding(.bottom, 32)
                        
                        // Title
                        Text("Recording Complete!")
                            .font(.system(size: 30, weight: .regular))
                            .foregroundColor(textPrimary)
                            .padding(.bottom, 16)
                        
                        // Subtitle
                        Text("Give your recording a name")
                            .font(.system(size: 16))
                            .foregroundColor(textSecondary)
                            .padding(.bottom, 40)
                        
                        // Name Input Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Recording Name")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(textTertiary)
                            
                            TextField("e.g., My Voice, Reading Voice, etc.", text: $recordingName)
                                .font(.system(size: 16))
                                .foregroundColor(textPrimary)
                                .padding(16)
                                .background(Color.white)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(isTextFieldFocused ? primaryButton : borderColor, lineWidth: 2)
                                )
                                .focused($isTextFieldFocused)
                                .disabled(isSaving)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 32)
                        
                        // Error Message
                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 14))
                                .foregroundColor(.red)
                                .padding(.horizontal, 24)
                                .padding(.bottom, 16)
                        }
                        
                        // Save Button
                        Button(action: saveRecording) {
                            ZStack {
                                if isSaving {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("Save Recording")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(recordingName.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray : primaryButton)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                        }
                        .disabled(recordingName.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                        .padding(.horizontal, 24)
                        
                        // Cancel Button
                        Button(action: {
                            if !isSaving {
                                onCancel()
                            }
                        }) {
                            Text("Cancel")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(textSecondary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                        }
                        .disabled(isSaving)
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 25)
                    
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.white)
        .onAppear {
            // Auto-focus text field after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTextFieldFocused = true
            }
        }
    }
    
    private func saveRecording() {
        let trimmedName = recordingName.trimmingCharacters(in: .whitespaces)
        
        guard !trimmedName.isEmpty else {
            errorMessage = "Please enter a name for your recording"
            return
        }
        
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "You must be signed in to save recordings"
            return
        }
        
        isSaving = true
        errorMessage = nil
        
        Task {
            do {
                // Upload to ElevenLabs and get voice ID
                let voiceId = try await ElevenLabsService.shared.createVoiceClone(
                    audioURL: audioURL,
                    name: trimmedName
                )
                
                // Save to Firestore
                let db = Firestore.firestore()
                let recordingData: [String: Any] = [
                    "name": trimmedName,
                    "voiceId": voiceId,
                    "userId": userId,
                    "createdAt": FieldValue.serverTimestamp()
                ]
                
                try await db.collection("voiceRecordings").addDocument(data: recordingData)
                
                await MainActor.run {
                    onSave(voiceId)
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = "Failed to save recording: \(error.localizedDescription)"
                }
            }
        }
    }
}

#Preview {
    NameRecordingView(
        audioURL: URL(fileURLWithPath: "/tmp/recording.m4a"),
        onSave: { _ in },
        onCancel: { }
    )
}

