# Echotales Backend Server

Backend API server for the Echotales iOS app. This server proxies requests to the ElevenLabs API, providing secure API key management, authentication, and rate limiting.

## 🚀 Features

- **Secure API Key Management**: API keys stored on server, never exposed to clients
- **Firebase Authentication**: Verifies user tokens from iOS app
- **Rate Limiting**: Prevents abuse and controls costs (50 requests/hour per user)
- **Usage Logging**: Track API usage per user
- **Voice Cloning**: Proxy endpoint for ElevenLabs voice cloning
- **Text-to-Speech**: Proxy endpoint for ElevenLabs TTS generation

## 📋 Prerequisites

- Node.js 18+ installed
- Firebase project set up
- ElevenLabs API account
- Firebase service account JSON file

## 🛠️ Setup Instructions

### 1. Install Dependencies

```bash
npm install
```

### 2. Configure Environment Variables

```bash
# Copy the template
cp .env.template .env

# Edit .env and add your credentials
nano .env
```

Required environment variables:

- `ELEVENLABS_API_KEY`: Your ElevenLabs API key
- `ELEVENLABS_BASE_URL`: ElevenLabs API base URL (default: https://api.elevenlabs.io/v1)
- `PORT`: Server port (default: 3000)

### 3. Get Firebase Service Account Key

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project (`echotales-d23cc`)
3. Go to **Project Settings** > **Service Accounts**
4. Click **Generate New Private Key**
5. Save the downloaded JSON file as `firebase-service-account.json` in this directory

### 4. Run the Server

**Development mode:**

```bash
npm run dev
```

**Production mode:**

```bash
npm start
```

The server will start on `http://localhost:3000` (or your configured PORT).

## 📡 API Endpoints

### Health Check

```
GET /health
```

Returns server status and configuration.

**Response:**

```json
{
  "status": "ok",
  "firebaseAuth": true,
  "timestamp": "2024-01-01T00:00:00.000Z"
}
```

### Create Voice Clone

```
POST /api/voice-clone
Content-Type: multipart/form-data
Authorization: Bearer <firebase-token>
```

**Parameters:**

- `audio` (file): Audio recording (m4a format)
- `name` (string): Name for the voice clone

**Response:**

```json
{
  "voiceId": "xyz123",
  "message": "Voice clone created successfully",
  "remaining": 49
}
```

### Text-to-Speech

```
POST /api/text-to-speech
Content-Type: application/json
Authorization: Bearer <firebase-token>
```

**Body:**

```json
{
  "voiceId": "xyz123",
  "text": "Text to convert to speech",
  "modelId": "eleven_monolingual_v1"
}
```

**Response:**

- Audio data (audio/mpeg format)
- Headers include `X-Rate-Limit-Remaining`

## 🔒 Security Features

### Authentication

All API endpoints (except `/health`) require Firebase authentication token in the `Authorization` header:

```
Authorization: Bearer <firebase-id-token>
```

### Rate Limiting

- 50 requests per hour per user (configurable)
- In-memory storage (consider Redis for production scaling)
- Returns 429 status when limit exceeded

### Error Handling

- API keys never exposed in error messages
- Detailed logging on server side
- Generic error messages to clients

## 🚀 Deployment Options

### Option 1: Google Cloud Run (Recommended)

Best for Firebase integration and auto-scaling.

```bash
# Install gcloud CLI
# https://cloud.google.com/sdk/docs/install

# Build and deploy
gcloud run deploy echotales-backend \
  --source . \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated
```

### Option 2: Heroku

```bash
# Install Heroku CLI
# https://devcenter.heroku.com/articles/heroku-cli

# Create app
heroku create echotales-backend

# Set environment variables
heroku config:set ELEVENLABS_API_KEY=your_key_here

# Deploy
git push heroku main
```

### Option 3: Railway

1. Go to [Railway.app](https://railway.app/)
2. Create new project from GitHub repo
3. Add environment variables in dashboard
4. Deploy automatically on push

### Option 4: AWS Lambda + API Gateway

For serverless deployment with AWS.

## 📊 Monitoring

### Usage Logs

View usage logs in the console output:

```
📊 Usage: 2024-01-01T00:00:00.000Z | User: abc123 | Action: voice-clone | Details: voice_xyz | Chars: N/A
```

### TODO: Persistent Logging

Uncomment the Firestore logging code in `logUsage()` function to save usage data to Firebase for analytics.

## 🔧 Configuration

### Adjust Rate Limits

Edit these constants in `server.js`:

```javascript
const RATE_LIMIT_WINDOW = 60 * 60 * 1000; // 1 hour in ms
const MAX_REQUESTS_PER_HOUR = 50; // requests per user
```

### File Upload Limits

Edit multer configuration:

```javascript
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 }, // 10MB
});
```

## 🧪 Testing

### Test Health Endpoint

```bash
curl http://localhost:3000/health
```

### Test with Firebase Token

```bash
# Get token from iOS app or Firebase
TOKEN="your_firebase_token"

curl -X POST http://localhost:3000/api/voice-clone \
  -H "Authorization: Bearer $TOKEN" \
  -F "audio=@recording.m4a" \
  -F "name=My Voice"
```

## 📝 TODO

- [ ] Add persistent rate limiting with Redis
- [ ] Implement usage tracking in Firestore
- [ ] Add webhook for usage alerts
- [ ] Implement subscription/payment logic
- [ ] Add response caching for cost optimization
- [ ] Set up monitoring and alerts (Sentry, etc.)
- [ ] Add API versioning
- [ ] Implement pagination for large responses

## 🐛 Troubleshooting

### "Firebase Admin initialization failed"

- Ensure `firebase-service-account.json` exists
- Verify the JSON file is valid
- Check file permissions

### "API authentication failed"

- Verify your ElevenLabs API key is correct
- Check if key has necessary permissions
- Ensure key hasn't been revoked

### Rate limit issues

- Check user's remaining requests
- Adjust rate limit constants if needed
- Consider implementing per-tier limits

## 📞 Support

For issues or questions:

1. Check the logs for error details
2. Review the SECURITY.md in the iOS app
3. Verify all environment variables are set correctly
