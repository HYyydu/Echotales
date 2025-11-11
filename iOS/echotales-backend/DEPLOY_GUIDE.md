# 🚀 Google Cloud Run Deployment Guide

This guide will help you deploy your Echotales backend to Google Cloud Run in about 15 minutes.

## ✅ Pre-Deployment Checklist

Before deploying, make sure you have:

- [x] Google Cloud SDK installed (`gcloud` command available)
- [x] Firebase project created (`echotales-d23cc`)
- [x] `firebase-service-account.json` file in this directory
- [x] `.env` file with your ElevenLabs API key
- [x] Authenticated with Google Cloud (`gcloud auth login`)

## 📋 Step-by-Step Deployment

### Step 1: Authenticate with Google Cloud

Open a **new terminal** and run:

```bash
gcloud auth login
```

- A browser window will open
- Sign in with your Google account (same one used for Firebase)
- Grant the requested permissions
- Return to terminal when done

### Step 2: Set Your Project

```bash
cd /Users/yuyan/TestCursorRecord/iOS/echotales-backend
gcloud config set project echotales-d23cc
```

### Step 3: Verify Your Configuration

Check that everything is ready:

```bash
# Check authentication
gcloud auth list

# Check project
gcloud config get-value project

# Verify files exist
ls -la | grep -E "(firebase-service|\.env|Dockerfile)"
```

You should see:

- ✅ firebase-service-account.json
- ✅ .env
- ✅ Dockerfile

### Step 4: Deploy to Cloud Run

**Option A: Use the automated script (Recommended)**

```bash
./deploy.sh
```

This script will:

1. Set the correct Google Cloud project
2. Verify all files exist
3. Load environment variables
4. Enable required APIs
5. Deploy to Cloud Run
6. Show you your production URL

**Option B: Manual deployment**

```bash
# Enable required APIs
gcloud services enable run.googleapis.com
gcloud services enable cloudbuild.googleapis.com

# Read API key from .env
source .env

# Deploy
gcloud run deploy echotales-backend \
  --source . \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars="ELEVENLABS_API_KEY=$ELEVENLABS_API_KEY,ELEVENLABS_BASE_URL=https://api.elevenlabs.io/v1,PORT=8080,NODE_ENV=production" \
  --memory=512Mi \
  --cpu=1 \
  --timeout=300
```

### Step 5: Test Your Deployment

After deployment completes, you'll see a URL like:

```
https://echotales-backend-xxxxx-uc.a.run.app
```

Test it:

```bash
# Replace with your actual URL
curl https://echotales-backend-xxxxx-uc.a.run.app/health
```

You should see:

```json
{
  "status": "ok",
  "firebaseAuth": true,
  "timestamp": "2025-11-08T..."
}
```

### Step 6: Update Your iOS App

Update your iOS app's `Config.plist`:

```xml
<key>BACKEND_URL</key>
<string>https://echotales-backend-xxxxx-uc.a.run.app</string>
<key>USE_BACKEND</key>
<true/>
```

### Step 7: Test End-to-End

1. Open your iOS app in Xcode
2. Build and run on simulator
3. Try creating a voice clone
4. Try generating speech
5. Check Cloud Run logs for requests

---

## 🔍 Monitoring & Logs

### View Logs

```bash
# Stream live logs
gcloud run services logs tail echotales-backend --region=us-central1

# View logs in browser
gcloud run services describe echotales-backend --region=us-central1
# Click the "Logs" link
```

### Check Status

```bash
# Service status
gcloud run services describe echotales-backend --region=us-central1

# List all Cloud Run services
gcloud run services list
```

### View Metrics

Go to: https://console.cloud.google.com/run

- Click on your service
- View request count, latency, errors

---

## 🔧 Updating Your Deployment

When you make changes to your code:

```bash
# Method 1: Use the script again
./deploy.sh

# Method 2: Quick redeploy
gcloud run deploy echotales-backend --source . --region us-central1
```

---

## 💰 Pricing

Google Cloud Run pricing:

- **Free tier**: 2 million requests/month
- **After free tier**: $0.40 per million requests
- **Memory**: $0.0000025 per GB-second
- **CPU**: $0.00002400 per vCPU-second

**Estimated cost for your app:**

- 100-500 requests/day: **$0-2/month**
- 1,000-5,000 requests/day: **$5-15/month**

Much cheaper than running a server 24/7!

---

## 🔐 Security Configuration

### Environment Variables

Cloud Run securely stores your environment variables. To update them:

```bash
gcloud run services update echotales-backend \
  --region=us-central1 \
  --set-env-vars="ELEVENLABS_API_KEY=new_key_here"
```

### Authentication

Your endpoints are currently `--allow-unauthenticated` which is correct because:

- Your backend validates Firebase tokens
- iOS app sends Firebase auth token with each request
- This is secure because Firebase validates the tokens

---

## 🐛 Troubleshooting

### Error: "Permission denied"

```bash
# Make sure you're authenticated
gcloud auth login

# Make sure you have the right project
gcloud config set project echotales-d23cc
```

### Error: "API not enabled"

```bash
# Enable required APIs
gcloud services enable run.googleapis.com
gcloud services enable cloudbuild.googleapis.com
```

### Error: "firebase-service-account.json not found"

```bash
# Check file exists
ls -la firebase-service-account.json

# If missing, download again from Firebase Console
```

### Deployment is slow

Cloud Run builds and deploys a Docker container, which takes 3-5 minutes the first time. Subsequent deploys are faster (~2 minutes).

### Health endpoint returns error

```bash
# Check logs
gcloud run services logs tail echotales-backend --region=us-central1

# Common issues:
# - Firebase service account not uploaded
# - Environment variables not set
# - PORT not set correctly (should be 8080)
```

---

## 📱 iOS App Configuration

After deployment, update your iOS app:

### Development (Local Testing)

```xml
<key>BACKEND_URL</key>
<string>http://localhost:3000</string>
```

### Production (App Store)

```xml
<key>BACKEND_URL</key>
<string>https://echotales-backend-xxxxx-uc.a.run.app</string>
```

### Pro Tip: Use Different Configs

Create two Config.plist files:

- `Config.plist` (local development)
- `Config.production.plist` (App Store)

Switch between them in Xcode build settings.

---

## 🎉 Success Checklist

After deployment, verify:

- [ ] Health endpoint returns 200 OK
- [ ] Firebase authentication is enabled (firebaseAuth: true)
- [ ] iOS app can connect to production backend
- [ ] Voice cloning works
- [ ] Text-to-speech works
- [ ] Backend logs show requests
- [ ] No errors in Cloud Run logs

---

## 📞 Support

If you encounter issues:

1. Check Cloud Run logs: `gcloud run services logs tail`
2. Verify environment variables are set
3. Test health endpoint with curl
4. Check Firebase service account is valid
5. Review `server.js` for any errors

---

## 🔄 Rollback

If something goes wrong:

```bash
# List revisions
gcloud run revisions list --service=echotales-backend --region=us-central1

# Rollback to previous revision
gcloud run services update-traffic echotales-backend \
  --region=us-central1 \
  --to-revisions=REVISION_NAME=100
```

---

**You're all set! Your backend is production-ready on Google Cloud Run.** 🚀
