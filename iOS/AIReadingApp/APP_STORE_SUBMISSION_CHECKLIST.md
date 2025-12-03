# 📱 App Store Submission Checklist

**App Name:** Echotales  
**Last Updated:** December 3, 2025  
**Status:** 🟢 Ready for Submission (with minor items to complete)

---

## 🎉 Major Items COMPLETED ✅

### ✅ Security Architecture

- **Backend integration complete** - API keys secured on server
- **Firebase Authentication** - All API calls authenticated
- **Rate limiting** - 50 requests/hour per user
- **No sensitive data in app bundle**

### ✅ Technical Requirements

- **Code signing** configured
- **Bundle ID** set (`com.aiReadingApp`)
- **Info.plist** complete with all permissions
- **Privacy manifest** (`PrivacyInfo.xcprivacy`) included
- **Firestore rules** ready to deploy

### ✅ Documentation

- Privacy policy written (`PRIVACY_POLICY.md`)
- App privacy declarations documented (`APP_STORE_PRIVACY.md`)
- Security guide available (`SECURITY.md`)
- Backend integration complete (`BACKEND_INTEGRATION_COMPLETE.md`)

---

## 🔴 CRITICAL - Complete Before Submission

### 1. Host Privacy Policy URL 🔴

**Current Status:** ❌ Not hosted  
**Required by:** Apple App Store  
**Priority:** HIGH

**Action Required:**

1. Choose hosting option:

   - **GitHub Pages** (recommended, free)
   - **Firebase Hosting** (free)
   - **Your own domain**

2. Convert `PRIVACY_POLICY.md` to HTML
3. Upload and get public URL
4. Update contact email in privacy policy (line 152) - currently shows placeholder

**Quick Setup (GitHub Pages):**

```bash
# Create a new repo or use existing
# Enable GitHub Pages in Settings
# Upload privacy.html
# URL will be: https://yourusername.github.io/repo-name/privacy.html
```

### 2. Test on Physical Device 🔴

**Current Status:** ❓ Unknown  
**Priority:** HIGH

**Test Checklist:**

- [ ] App installs and launches
- [ ] Sign in with Email/Password
- [ ] Sign in with Google
- [ ] Sign in with Apple
- [ ] Record voice (microphone permission)
- [ ] Create voice clone (backend integration)
- [ ] Browse books
- [ ] Read book with TTS
- [ ] Download book for offline
- [ ] All features work offline

### 3. Verify Backend is Running 🟡

**Current Status:** ✅ Deployed  
**Backend URL:** `https://echotales-backend-377842214787.us-central1.run.app`

**Verify:**

```bash
curl https://echotales-backend-377842214787.us-central1.run.app/health
```

**Expected Response:**

```json
{
  "status": "ok",
  "firebaseAuth": true,
  "timestamp": "2025-12-03T..."
}
```

**If backend is down:**

1. Check Google Cloud Run dashboard
2. Verify environment variables are set
3. Check backend logs for errors

---

## 🟡 IMPORTANT - Strongly Recommended

### 4. Deploy Firestore Security Rules 🟡

**Current Status:** ⚠️ Rules file exists, needs deployment  
**File:** `firestore.rules`

**Deploy Now:**

```bash
firebase deploy --only firestore:rules
```

Or manually in Firebase Console:

1. Go to https://console.firebase.google.com
2. Select project → Firestore → Rules
3. Copy contents from `firestore.rules`
4. Click "Publish"

### 5. Create App Screenshots 🟡

**Required Sizes:**

- 6.7" iPhone (iPhone 15 Pro Max): 1290 x 2796
- 6.5" iPhone (iPhone 14 Plus): 1284 x 2778
- 5.5" iPhone (optional): 1242 x 2208

**Recommended Screenshots:**

1. Welcome/Sign-in screen
2. Book library/shelf view
3. Book details with voice selection
4. Reading view with audio controls
5. Voice recording/My Recordings
6. User profile/settings

**Tools:**

- Xcode Simulator (Cmd+S to screenshot)
- [Screenshots.pro](https://screenshots.pro) (add device frames)
- Figma/Sketch (design marketing screenshots)

### 6. Create App Icon (1024x1024) 🟡

**Current Status:** ✅ icon3.png exists in Assets  
**Verify:** No transparency, PNG format, exactly 1024x1024

### 7. Test All Authentication Methods 🟡

- [ ] Email/Password sign up
- [ ] Email/Password sign in
- [ ] Google Sign-In
- [ ] Apple Sign-In
- [ ] Password reset flow
- [ ] Sign out

### 8. Prepare Demo Account for App Review 🟡

Create a test account with:

- Pre-loaded books
- Existing voice recording
- Reading history
- Full access to all features

**Add to App Review Notes:**

```
Demo Account:
Email: demo@echotales.app
Password: [SecurePassword123]

Instructions:
1. Sign in with demo account
2. Browse "Shelf" tab to see pre-loaded books
3. Tap any book to see details
4. Tap "Read" to start audio narration
5. Visit "My Recordings" to see voice clones
6. All features are fully functional
```

---

## 🟢 RECOMMENDED - Best Practices

### 9. App Store Metadata 🟢

Prepare text for App Store Connect:

**App Name:** Echotales

**Subtitle (30 chars):**
"AI-Powered Audio Books"

**Description (4000 chars max):**
[Write compelling description highlighting:

- Voice cloning feature
- Personal AI narrator
- Book library
- Offline reading
- Family-friendly content]

**Keywords:**
audiobooks, voice clone, AI, reading, books, narrator, TTS, text to speech, ebook, reading app

**Category:**

- Primary: Books
- Secondary: Entertainment or Education

**Age Rating:**

- 4+ (if all content is appropriate)
- or 9+ if some content is more mature

### 10. What's New Text 🟢

**Version 1.0:**

```
Welcome to Echotales!

🎙️ Create your own AI voice clone
📚 Enjoy thousands of classic books
🗣️ Listen with your personalized narrator
📖 Read offline anywhere
👨‍👩‍👧‍👦 Family-friendly content

Experience the future of audiobooks with Echotales!
```

### 11. Support URL 🟢

Provide a support contact:

- Email: support@echotales.app (or your actual email)
- Or: Link to help page
- Or: Link to GitHub issues

### 12. Marketing URL (Optional) 🟢

- Your website
- Landing page
- Or leave blank

### 13. App Review Information 🟢

**Contact Information:**

- First Name: [Your name]
- Last Name: [Your name]
- Phone: [Your phone]
- Email: [Your email]

**Notes:**

```
Voice Recording Feature:
- Requires microphone permission
- Minimum 30 seconds of audio needed
- Used only for creating personalized voice
- Can be deleted anytime in settings

Book Content:
- All books are public domain classics
- Content is family-friendly
- Users cannot upload their own content

Backend Integration:
- App uses secure backend server
- All API calls are authenticated
- Rate limited to prevent abuse
```

---

## 📋 Pre-Submission Final Checklist

### Code & Build

- [x] Backend integration complete
- [x] API keys removed from app
- [x] Firebase Authentication configured
- [ ] Test on physical device
- [ ] No critical bugs or crashes
- [x] App builds in Release mode
- [ ] Archive created successfully

### Privacy & Security

- [x] Privacy policy written
- [ ] Privacy policy hosted (URL needed!)
- [x] PrivacyInfo.xcprivacy included
- [x] Data collection documented
- [x] Microphone permission explained
- [x] Rate limiting enabled
- [ ] Firestore rules deployed

### App Store Connect

- [ ] App created in App Store Connect
- [ ] Screenshots uploaded (6.7" required)
- [ ] App icon uploaded (1024x1024)
- [ ] Description written
- [ ] Keywords added
- [ ] Privacy policy URL added
- [ ] App privacy declarations filled
- [ ] Demo account created
- [ ] App review notes written
- [ ] Support contact provided

### Testing

- [ ] Sign in/Sign up works
- [ ] Voice recording works
- [ ] Voice clone creation works
- [ ] Book reading works
- [ ] TTS generation works
- [ ] Offline mode works
- [ ] All permissions work
- [ ] No memory leaks
- [ ] Handles poor network gracefully

---

## 🚀 Submission Steps

Once all above is complete:

### Step 1: Create Archive

1. In Xcode, select "Any iOS Device"
2. Product → Archive
3. Wait for build to complete

### Step 2: Upload to App Store Connect

1. In Organizer, select your archive
2. Click "Distribute App"
3. Choose "App Store Connect"
4. Select "Upload"
5. Choose signing options (automatic)
6. Click "Upload"
7. Wait for processing (15-60 mins)

### Step 3: Fill App Store Connect

1. Go to https://appstoreconnect.apple.com
2. Create new app
3. Fill all metadata
4. Upload screenshots
5. Add privacy policy URL
6. Configure app privacy
7. Select uploaded build
8. Submit for review

### Step 4: Wait for Review

- Typical review time: 24-48 hours
- Check email for updates
- Respond quickly to any questions
- Most apps approved on first try!

---

## 📊 Common Rejection Reasons to Avoid

| Issue                          | Solution                                      |
| ------------------------------ | --------------------------------------------- |
| Missing privacy policy URL     | ✅ Host privacy policy online                 |
| Incorrect privacy declarations | ✅ Follow `APP_STORE_PRIVACY.md`              |
| Demo account doesn't work      | ✅ Test demo account before submitting        |
| App crashes on launch          | ✅ Test thoroughly on device                  |
| Permissions not explained      | ✅ NSMicrophoneUsageDescription in Info.plist |
| Broken features                | ✅ Test all features work                     |

---

## 🎯 Priority Order

**Do these TODAY:**

1. ⏰ Host privacy policy (1-2 hours)
2. ⏰ Test on physical device (1 hour)
3. ⏰ Deploy Firestore rules (5 minutes)

**Do these THIS WEEK:** 4. Create screenshots (2-3 hours) 5. Write app description (1 hour) 6. Create demo account (30 minutes) 7. Archive and upload (1 hour)

---

## 📞 Need Help?

**Existing Documentation:**

- `BACKEND_INTEGRATION_COMPLETE.md` - Backend setup
- `APP_STORE_PRIVACY.md` - Privacy declarations
- `SIGNING_SETUP_GUIDE.md` - Code signing help
- `SECURITY.md` - Security best practices

**External Resources:**

- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [App Store Connect Help](https://developer.apple.com/help/app-store-connect/)
- [Firebase iOS Setup](https://firebase.google.com/docs/ios/setup)

---

**🎉 You're 90% ready! Just need privacy policy URL and screenshots to submit!**
