# App Store Readiness Checklist

Last Updated: November 8, 2025

## 🎉 COMPLETED

### ✅ Security Implementation

- [x] **API Keys Secured**
  - Removed hardcoded API keys from source code
  - Created `Config.plist` system (gitignored)
  - Implemented backend proxy server
  - Firebase authentication integrated
- [x] **Backend Server Created**
  - Node.js/Express server at `/echotales-backend/`
  - Firebase Admin SDK integrated
  - Rate limiting (50 requests/hour per user)
  - Secure API key storage on server
  - Health monitoring endpoint
- [x] **iOS App Updated**
  - Now calls backend instead of ElevenLabs directly
  - Firebase auth tokens included in all requests
  - Rate limit handling
  - Better error messages
  - Fallback mode for debugging

## ⚠️ CRITICAL: Must Do Before Submission

### 🔐 Security

- [ ] **Regenerate ElevenLabs API Key**

  - Old key was exposed in this conversation
  - Go to: https://elevenlabs.io/app/settings/api-keys
  - Delete old key: `sk_XXXXX...` (the exposed key)
  - Create new key
  - Update backend `.env` with new key
  - **DO NOT share the new key**

- [ ] **Check Git History**

  ```bash
  cd /Users/yuyan/TestCursorRecord/iOS/AIReadingApp
  git log -S "your_old_api_key" --oneline
  ```

  - If key found in git history, regenerating it is even more critical

- [ ] **Firebase Security Rules**
  - Review Firestore security rules
  - Ensure users can only access their own data
  - See `SECURITY.md` for examples

## 🚀 Deployment Requirements

### Backend Deployment

- [ ] Choose deployment platform:

  - ✅ **Google Cloud Run** (recommended, integrates with Firebase)
  - ⚬ Heroku
  - ⚬ Railway
  - ⚬ AWS Lambda + API Gateway

- [ ] Deploy backend to production
- [ ] Set environment variables on production server
- [ ] Upload Firebase service account to production server
- [ ] Test production backend health endpoint
- [ ] Note production URL for iOS app

### iOS App Configuration

- [ ] Update `Config.plist` with production backend URL
- [ ] Set `USE_BACKEND` to `true`
- [ ] Test app with production backend
- [ ] Remove any debug/test code
- [ ] Update app version numbers

## 📱 Technical Requirements

### Apple Developer Account

- [ ] Enroll in Apple Developer Program ($99/year)
  - https://developer.apple.com/programs/
- [ ] Complete account setup
- [ ] Accept agreements

### Xcode Project Setup

- [ ] Create/locate `.xcodeproj` or `.xcworkspace` file
- [ ] Configure bundle identifier (e.g., `com.yourcompany.echotales`)
- [ ] Set up code signing
  - Select development team
  - Configure signing certificates
  - Create provisioning profiles
- [ ] Set minimum iOS version (recommend iOS 15.0+)
- [ ] Configure capabilities:
  - Push Notifications (if needed)
  - Background Modes (if needed)
- [ ] Add `Config.plist` to Xcode project target
- [ ] Verify Firebase `GoogleService-Info.plist` is in target

### App Icons & Assets

- [ ] Create app icon in all required sizes:
  - iPhone: 180×180 (@3x), 120×120 (@2x)
  - iPad: 167×167 (@2x), 152×152 (@2x)
  - App Store: 1024×1024
- [ ] Create launch screen
- [ ] Test on various device sizes

### Testing

- [ ] Test on iOS Simulator
- [ ] Test on physical iPhone
- [ ] Test on physical iPad (if supporting iPad)
- [ ] Test with poor network conditions
- [ ] Test rate limiting behavior
- [ ] Test error scenarios
- [ ] Fix all crashes and critical bugs
- [ ] Remove debug logging statements

## 📄 Legal & Compliance

### Privacy Policy

- [ ] Create privacy policy (required by App Store)
- [ ] Must be publicly accessible URL
- [ ] Include:
  - What data you collect (voice recordings, usage data)
  - How you use the data (ElevenLabs API, Firebase)
  - Third-party services (ElevenLabs, Firebase, Google)
  - User rights (data deletion, access)
  - Contact information
- [ ] Can use templates from:
  - https://www.iubenda.com/
  - https://www.termsfeed.com/
  - https://www.freeprivacypolicy.com/

### Terms of Service

- [ ] Create terms of service
- [ ] Include acceptable use policy
- [ ] Liability disclaimers
- [ ] Service availability statements

### Privacy Manifest

- [ ] Create `PrivacyInfo.xcprivacy` file
- [ ] Declare all data collection
- [ ] List required reasons for API usage
- [ ] Declare tracking domains (if any)

### Permissions

- [x] Microphone permission description (✅ already in `Info.plist`)
- [ ] Review permission text for clarity
- [ ] Ensure permission timing makes sense to users

## 📝 App Store Connect

### Create App Record

- [ ] Log in to App Store Connect
  - https://appstoreconnect.apple.com/
- [ ] Create new app
- [ ] Choose bundle identifier
- [ ] Select primary language
- [ ] Choose app name (must be unique)
- [ ] Select category (e.g., Books, Education, Productivity)
- [ ] Select content rights

### App Information

- [ ] **App Name**: "Echotales" (or your chosen name)
- [ ] **Subtitle**: Short description (30 chars max)
- [ ] **Description**: Full description of features
- [ ] **Keywords**: Comma-separated, max 100 chars
  - Example: "audiobook,reading,voice,AI,text-to-speech,books"
- [ ] **Support URL**: Your support website or email
- [ ] **Marketing URL** (optional): Your app website
- [ ] **Privacy Policy URL**: **REQUIRED**

### Screenshots

Required for each device size you support:

**iPhone (required):**

- [ ] 6.7" display (iPhone 14 Pro Max): 1290×2796
- [ ] 6.5" display (iPhone 11 Pro Max): 1242×2688
- [ ] 5.5" display (iPhone 8 Plus): 1242×2208 (if supporting iOS 14)

**iPad (if supporting iPad):**

- [ ] 12.9" display (iPad Pro): 2048×2732
- [ ] 11" display (iPad Pro): 1668×2388

Tips for screenshots:

- Show key features
- Use clean, readable designs
- Add captions explaining features
- Show the app in action
- Use real content (not lorem ipsum)

### App Preview Videos (Optional but Recommended)

- [ ] Create 15-30 second app preview videos
- [ ] Show core functionality
- [ ] Same sizes as screenshots
- [ ] No external logos or brands

### Pricing & Availability

- [ ] Select pricing tier (Free or Paid)
- [ ] Choose available countries/regions
- [ ] Set availability date (manual or automatic)

### Age Rating

- [ ] Complete age rating questionnaire
- [ ] Be honest about content
- [ ] Consider user-generated content implications

### Review Information

- [ ] Provide demo account (if app requires login)
- [ ] Add reviewer notes explaining:
  - Backend server is required
  - How to test features
  - Any special setup needed
- [ ] Contact information for review team

## 🧪 Pre-Submission Testing

### Build & Archive

- [ ] Clean build folder (Cmd+Shift+K)
- [ ] Archive app (Product → Archive)
- [ ] Verify no errors or warnings
- [ ] Upload to App Store Connect
- [ ] Wait for processing to complete

### TestFlight

- [ ] Add internal testers
- [ ] Test the uploaded build
- [ ] Verify all features work
- [ ] Check for crashes
- [ ] Optional: Add external testers for beta testing

## 📋 Submission Checklist

### Final Review

- [ ] All features working
- [ ] No crashes or critical bugs
- [ ] Backend server deployed and stable
- [ ] Privacy policy live and accessible
- [ ] Terms of service complete
- [ ] All App Store Connect fields filled
- [ ] Screenshots uploaded
- [ ] Age rating complete
- [ ] Pricing set
- [ ] Review information provided

### Submit for Review

- [ ] Click "Submit for Review" in App Store Connect
- [ ] Answer any additional questions
- [ ] Wait for Apple's review (typically 1-7 days)
- [ ] Monitor email for review updates

### After Submission

- [ ] Monitor App Store Connect for status updates
- [ ] Respond quickly to any review feedback
- [ ] If rejected, address issues and resubmit
- [ ] Once approved, celebrate! 🎉

## 🔧 Backend Production Setup

Before submitting, your backend MUST be deployed:

### Recommended: Google Cloud Run

```bash
cd /Users/yuyan/TestCursorRecord/iOS/echotales-backend

# Install Google Cloud CLI
brew install --cask google-cloud-sdk

# Login and set project
gcloud auth login
gcloud config set project echotales-d23cc

# Create Dockerfile (needed for Cloud Run)
cat > Dockerfile << 'EOF'
FROM node:18-slim
WORKDIR /app
COPY package*.json ./
RUN npm install --production
COPY . .
EXPOSE 3000
CMD ["npm", "start"]
EOF

# Deploy to Cloud Run
gcloud run deploy echotales-backend \
  --source . \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars="ELEVENLABS_API_KEY=your_new_api_key,ELEVENLABS_BASE_URL=https://api.elevenlabs.io/v1" \
  --set-secrets="FIREBASE_SERVICE_ACCOUNT=firebase-service-account:latest"

# Note the deployed URL and update iOS app Config.plist
```

### Alternative: Heroku

```bash
cd /Users/yuyan/TestCursorRecord/iOS/echotales-backend

# Install Heroku CLI
brew tap heroku/brew && brew install heroku

# Login and create app
heroku login
heroku create echotales-backend

# Set environment variables
heroku config:set ELEVENLABS_API_KEY=your_new_api_key
heroku config:set ELEVENLABS_BASE_URL=https://api.elevenlabs.io/v1

# Deploy
git init
git add .
git commit -m "Initial backend"
heroku git:remote -a echotales-backend
git push heroku main

# Note the app URL (https://echotales-backend.herokuapp.com)
```

## 📊 Estimated Timeline

| Task                         | Time Estimate |
| ---------------------------- | ------------- |
| Regenerate API key           | 5 minutes     |
| Deploy backend to production | 1-2 hours     |
| Update iOS config & test     | 30 minutes    |
| Create privacy policy        | 2-4 hours     |
| Create App Store assets      | 4-8 hours     |
| Fill App Store Connect info  | 1-2 hours     |
| Testing & bug fixes          | 4-8 hours     |
| Apple review process         | 1-7 days      |
| **TOTAL**                    | **2-3 weeks** |

## 🎯 Priority Order

1. **URGENT**: Regenerate API key (5 min)
2. **HIGH**: Deploy backend (2 hours)
3. **HIGH**: Test with production backend (30 min)
4. **MEDIUM**: Privacy policy (4 hours)
5. **MEDIUM**: App Store screenshots (6 hours)
6. **MEDIUM**: Complete App Store Connect (2 hours)
7. **LOW**: Optional polish & improvements
8. **SUBMIT**: Upload and submit for review

## 📞 Resources

- **Apple Developer**: https://developer.apple.com/
- **App Store Connect**: https://appstoreconnect.apple.com/
- **Firebase Console**: https://console.firebase.google.com/
- **ElevenLabs Dashboard**: https://elevenlabs.io/app/
- **App Review Guidelines**: https://developer.apple.com/app-store/review/guidelines/
- **Human Interface Guidelines**: https://developer.apple.com/design/human-interface-guidelines/

## 🆘 Need Help?

If you get stuck:

1. Check the documentation files in your project
2. Search Apple Developer Forums
3. Review App Store Connect help articles
4. Consider hiring iOS developer consultant for tricky parts

---

**Current Status**: ✅ Backend infrastructure complete, iOS app ready for backend
**Next Step**: Deploy backend to production, then work on App Store assets

Good luck with your submission! 🚀
