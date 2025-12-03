import Foundation
import FirebaseAuth

class ElevenLabsService {
    static let shared = ElevenLabsService()
    
    private let useBackend: Bool
    private let backendURL: String
    private let apiKey: String
    private let baseURL: String
    
    private init() {
        // Check if we should use backend or direct API
        self.useBackend = Config.shared.useBackend
        self.backendURL = Config.shared.backendURL
        
        // Load API key (only needed for direct API calls)
        self.apiKey = Config.shared.elevenLabsAPIKey
        self.baseURL = Config.shared.elevenLabsBaseURL
        
        if useBackend {
            print("✅ ElevenLabs service configured to use backend: \(backendURL)")
        } else {
            print("⚠️ ElevenLabs service using direct API calls (not recommended for production)")
            if apiKey.isEmpty {
                print("❌ WARNING: ElevenLabs API key is empty. Please configure Config.plist")
            }
        }
    }
    
    // MARK: - Public API
    
    // Create voice clone from audio file
    func createVoiceClone(audioURL: URL, name: String) async throws -> String {
        if useBackend {
            return try await createVoiceCloneViaBackend(audioURL: audioURL, name: name)
        } else {
            return try await createVoiceCloneDirect(audioURL: audioURL, name: name)
        }
    }
    
    // Generate speech from text using voice clone
    func textToSpeech(voiceId: String, text: String) async throws -> Data {
        if useBackend {
            return try await textToSpeechViaBackend(voiceId: voiceId, text: text)
        } else {
            return try await textToSpeechDirect(voiceId: voiceId, text: text)
        }
    }
    
    // MARK: - Backend Implementation
    
    private func createVoiceCloneViaBackend(audioURL: URL, name: String) async throws -> String {
        // Get Firebase auth token
        guard let user = Auth.auth().currentUser else {
            throw APIError.notAuthenticated
        }
        
        let token = try await user.getIDToken()
        
        // Prepare multipart request
        guard let url = URL(string: "\(backendURL)/api/voice-clone") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120 // 2 minutes timeout
        
        var body = Data()
        
        // Add name field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"name\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(name)\r\n".data(using: .utf8)!)
        
        // Add audio file
        let audioData = try Data(contentsOf: audioURL)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"recording.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        print("🎤 Creating voice clone via backend: \(name)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = parseBackendError(data: data, statusCode: httpResponse.statusCode)
            throw APIError.serverError(errorMessage)
        }
        
        // Parse backend response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let voiceId = json["voiceId"] as? String else {
            throw APIError.invalidResponse
        }
        
        print("✅ Voice clone created: \(voiceId)")
        return voiceId
    }
    
    private func textToSpeechViaBackend(voiceId: String, text: String) async throws -> Data {
        // Get Firebase auth token
        guard let user = Auth.auth().currentUser else {
            throw APIError.notAuthenticated
        }
        
        let token = try await user.getIDToken()
        
        guard let url = URL(string: "\(backendURL)/api/text-to-speech") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120 // 2 minutes timeout
        
        let requestBody: [String: Any] = [
            "voiceId": voiceId,
            "text": text,
            "modelId": "eleven_monolingual_v1"
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        print("🗣️ Generating speech via backend: \(text.prefix(50))...")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = parseBackendError(data: data, statusCode: httpResponse.statusCode)
            throw APIError.serverError(errorMessage)
        }
        
        print("✅ Speech generated: \(data.count) bytes")
        return data
    }
    
    // MARK: - Direct API Implementation (Legacy)
    
    private func createVoiceCloneDirect(audioURL: URL, name: String) async throws -> String {
        var request = URLRequest(url: URL(string: "\(baseURL)/voices/add")!)
        request.httpMethod = "POST"
        request.setValue("\(apiKey)", forHTTPHeaderField: "xi-api-key")
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add name field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"name\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(name)\r\n".data(using: .utf8)!)
        
        // Add audio file
        let audioData = try Data(contentsOf: audioURL)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"files\"; filename=\"recording.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = errorData["detail"] as? [String: Any],
               let message = detail["message"] as? String {
                throw APIError.serverError(message)
            }
            throw APIError.networkError
        }
        
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let voiceId = json["voice_id"] as? String {
            return voiceId
        }
        
        throw APIError.invalidResponse
    }
    
    private func textToSpeechDirect(voiceId: String, text: String) async throws -> Data {
        guard let url = URL(string: "\(baseURL)/text-to-speech/\(voiceId)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("\(apiKey)", forHTTPHeaderField: "xi-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "text": text,
            "model_id": "eleven_monolingual_v1",
            "voice_settings": [
                "stability": 0.5,
                "similarity_boost": 0.75
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = errorData["detail"] as? [String: Any],
               let message = detail["message"] as? String {
                throw APIError.serverError(message)
            }
            throw APIError.networkError
        }
        
        return data
    }
    
    // MARK: - Helper Methods
    
    private func parseBackendError(data: Data, statusCode: Int) -> String {
        // Try to parse error message from backend
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = json["error"] as? String {
            return error
        }
        
        // Fallback error messages
        switch statusCode {
        case 401:
            return "Authentication failed. Please sign in again."
        case 429:
            return "Rate limit exceeded. Please try again later."
        case 503:
            return "Backend service unavailable. Please try again later."
        default:
            return "Server error (code \(statusCode)). Please try again."
        }
    }
    
    // MARK: - Error Types
    
    enum APIError: LocalizedError {
        case networkError
        case invalidURL
        case invalidResponse
        case serverError(String)
        case notAuthenticated
        
        var errorDescription: String? {
            switch self {
            case .networkError:
                return "Network error. Please check your connection."
            case .invalidURL:
                return "Invalid URL."
            case .invalidResponse:
                return "Invalid response from server."
            case .serverError(let message):
                return message
            case .notAuthenticated:
                return "Please sign in to use this feature."
            }
        }
    }
}

