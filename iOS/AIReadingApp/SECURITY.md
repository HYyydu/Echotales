# Security Guide for Echotales

## ⚠️ Current Security Status

The current implementation uses a client-side configuration file for API keys. While this is better than hardcoding keys in source code, it's **NOT FULLY SECURE** for production apps.

### Current Protection Level: 🟡 Medium

✅ API key not in source code repository
✅ Protected from casual code inspection
❌ Still extractable from app bundle by determined users
❌ All users share the same API key
❌ No rate limiting per user
❌ API usage costs could spike if exploited

## 🔒 Production-Ready Security Solution

For App Store distribution, implement a backend proxy server:

### Architecture Overview

```
iOS App → Your Backend Server → ElevenLabs API
         (Authenticated)       (API Key Hidden)
```

### Implementation Steps

#### 1. Set Up Backend Server (Node.js Example)

```javascript
// server.js
const express = require('express');
const axios = require('axios');
require('dotenv').config();

const app = express();
app.use(express.json());

// Verify Firebase token middleware
const verifyFirebaseToken = async (req, res, next) => {
  const token = req.headers.authorization?.split('Bearer ')[1];
  if (!token) return res.status(401).json({ error: 'No token' });
  
  try {
    // Verify token with Firebase Admin SDK
    const decodedToken = await admin.auth().verifyIdToken(token);
    req.userId = decodedToken.uid;
    next();
  } catch (error) {
    res.status(401).json({ error: 'Invalid token' });
  }
};

// Proxy endpoint for voice cloning
app.post('/api/voice-clone', verifyFirebaseToken, async (req, res) => {
  try {
    // Rate limiting per user
    const userUsage = await checkUserUsage(req.userId);
    if (userUsage.exceeded) {
      return res.status(429).json({ error: 'Rate limit exceeded' });
    }
    
    // Call ElevenLabs API with server-side key
    const response = await axios.post(
      'https://api.elevenlabs.io/v1/voices/add',
      req.body,
      {
        headers: {
          'xi-api-key': process.env.ELEVENLABS_API_KEY
        }
      }
    );
    
    // Log usage for billing/monitoring
    await logUsage(req.userId, 'voice-clone');
    
    res.json(response.data);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.listen(3000);
```

#### 2. Update iOS App to Use Backend

```swift
class ElevenLabsService {
    private let backendURL = "https://your-backend.com/api"
    
    func createVoiceClone(audioURL: URL, name: String) async throws -> String {
        guard let url = URL(string: "\(backendURL)/voice-clone") else {
            throw APIError.invalidURL
        }
        
        // Get Firebase auth token
        guard let user = Auth.auth().currentUser else {
            throw APIError.notAuthenticated
        }
        
        let token = try await user.getIDToken()
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        // ... rest of implementation
    }
}
```

#### 3. Deploy Backend Server

Options for deployment:
- **Google Cloud Run** (integrates well with Firebase)
- **AWS Lambda** + API Gateway
- **Heroku**
- **Vercel** (for Next.js/Node.js)
- **Railway**

### Benefits of Backend Proxy

✅ API key never leaves your server
✅ Rate limiting per user
✅ Monitor and control costs
✅ Can implement subscription/payment logic
✅ Audit trail of API usage
✅ Can cache responses to save costs
✅ Easier to update API logic without app updates

## 🛡️ Additional Security Measures

### 1. Firebase Security Rules

⚠️ **IMPORTANT:** Your Firestore security rules have been created in `firestore.rules` and **must be deployed** to Firebase Console.

**See `FIRESTORE_SETUP.md` for complete deployment instructions.**

Quick deploy:
1. Open https://console.firebase.google.com
2. Go to Firestore Database → Rules
3. Copy contents from `firestore.rules` and paste
4. Click Publish

Or use Firebase CLI:
```bash
firebase deploy --only firestore:rules
```

The rules ensure:
- Users can only access their own data
- Proper authentication checks for all operations
- Membership and voice recording data is protected
- Books are read-only for authenticated users

### 2. API Key Restrictions

In ElevenLabs dashboard:
- Set usage quotas
- Monitor for unusual activity
- Set up billing alerts
- Consider IP restrictions (for backend server)

### 3. App Transport Security

Ensure all API calls use HTTPS.

### 4. Code Obfuscation

While not a security measure itself, obfuscation can slow down reverse engineering:
- Use ProGuard-equivalent for Swift (SwiftShield)
- Strip debug symbols in release builds

### 5. Certificate Pinning

For highly sensitive apps, implement SSL certificate pinning to prevent man-in-the-middle attacks.

## 📊 Monitoring & Alerts

Set up monitoring for:
- Unusual API usage spikes
- Failed authentication attempts
- Error rates
- Cost thresholds

## 🔄 Migration Path

1. **Phase 1 (Current):** Config file with .gitignore
2. **Phase 2:** Backend proxy for ElevenLabs calls
3. **Phase 3:** User authentication and rate limiting
4. **Phase 4:** Monetization/subscription system

## 📝 Compliance

If storing user voice data:
- ✅ Get explicit user consent
- ✅ Provide data deletion option
- ✅ Create privacy policy
- ✅ Comply with GDPR/CCPA
- ✅ Inform users about third-party processing (ElevenLabs)

## 🚨 If API Key is Compromised

1. **Immediately** regenerate the API key in ElevenLabs dashboard
2. Update Config.plist with new key
3. Review API usage logs for unauthorized activity
4. Contact ElevenLabs support if needed
5. Consider moving to backend proxy immediately

## 📞 Security Questions?

For security concerns, best practices:
1. Review ElevenLabs security documentation
2. Follow Apple's Security Guidelines
3. Consider hiring a security audit before major launch

