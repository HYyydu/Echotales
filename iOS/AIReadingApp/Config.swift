import Foundation

/// Configuration manager for API keys and sensitive data
/// This reads from Config.plist which should be gitignored
class Config {
    static let shared = Config()
    
    private var configDict: [String: Any]?
    
    private init() {
        // Try to load Config.plist
        if let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path) as? [String: Any] {
            configDict = dict
            print("✅ Config.plist loaded successfully")
        } else {
            print("⚠️ Config.plist not found. Please create it from Config.plist.template")
            configDict = nil
        }
    }
    
    /// Backend Server URL (where our secure API proxy runs)
    var backendURL: String {
        return configDict?["BACKEND_URL"] as? String ?? "http://localhost:3000"
    }
    
    /// Use backend server instead of direct API calls
    var useBackend: Bool {
        return configDict?["USE_BACKEND"] as? Bool ?? true
    }
    
    /// ElevenLabs API Key (deprecated - now handled by backend)
    /// Only used if USE_BACKEND is false
    var elevenLabsAPIKey: String {
        guard let key = configDict?["ELEVENLABS_API_KEY"] as? String, !key.isEmpty else {
            if useBackend {
                return "" // Not needed when using backend
            }
            fatalError("❌ ELEVENLABS_API_KEY not found in Config.plist. Please add it.")
        }
        return key
    }
    
    /// ElevenLabs Base URL (deprecated - now handled by backend)
    /// Only used if USE_BACKEND is false
    var elevenLabsBaseURL: String {
        return configDict?["ELEVENLABS_BASE_URL"] as? String ?? "https://api.elevenlabs.io/v1"
    }
    
    /// Optional: Add other configuration values here
    var isDebugMode: Bool {
        return configDict?["DEBUG_MODE"] as? Bool ?? false
    }
}

