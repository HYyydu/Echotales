import Foundation

class ElevenLabsService {
    static let shared = ElevenLabsService()
    
    private let apiKey: String
    private let baseURL: String
    
    private init() {
        // Load API key securely from Config.plist
        self.apiKey = Config.shared.elevenLabsAPIKey
        self.baseURL = Config.shared.elevenLabsBaseURL
        
        if apiKey.isEmpty {
            print("⚠️ WARNING: ElevenLabs API key is empty. Please configure Config.plist")
        }
    }
    
    // Create voice clone from audio file
    func createVoiceClone(audioURL: URL, name: String) async throws -> String {
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
    
    // Generate speech from text using voice clone
    func textToSpeech(voiceId: String, text: String) async throws -> Data {
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
    
    enum APIError: LocalizedError {
        case networkError
        case invalidURL
        case invalidResponse
        case serverError(String)
        
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
            }
        }
    }
}

