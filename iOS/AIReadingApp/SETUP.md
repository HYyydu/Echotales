# Setup Instructions for Echotales

## 🔐 Backend Configuration

This app uses a secure backend server for all ElevenLabs API calls. The API key is stored on the server, **not in the iOS app**.

### ✅ Backend Already Set Up

Your backend is deployed and running at:

```
https://echotales-backend-377842214787.us-central1.run.app
```

### First-Time Setup

1. **Copy the template file:**

   ```bash
   cp Config.plist.template Config.plist
   ```

2. **Verify `Config.plist` settings:**

   - `USE_BACKEND` should be `true`
   - `BACKEND_URL` should point to your deployed backend
   - `ELEVENLABS_API_KEY` should be empty (not needed!)

3. **Verify `Config.plist` is in `.gitignore`:**
   - This file should **NEVER** be committed to git
   - The `.gitignore` is already configured to exclude it

### Configuration File Structure

The `Config.plist` file should contain:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>BACKEND_URL</key>
    <string>https://echotales-backend-377842214787.us-central1.run.app</string>
    <key>USE_BACKEND</key>
    <true/>
    <key>ELEVENLABS_API_KEY</key>
    <string></string>
    <key>ELEVENLABS_BASE_URL</key>
    <string>https://api.elevenlabs.io/v1</string>
    <key>DEBUG_MODE</key>
    <false/>
</dict>
</plist>
```

### Important Security Notes

✅ **API key is on the server** - much more secure!
✅ **Rate limiting** - 50 requests per hour per user
✅ **Authentication required** - Firebase tokens verified
⚠️ **NEVER commit `Config.plist` to git**

## 🏗️ Building the App

1. Ensure you have Xcode installed (version 14.0 or later recommended)
2. Open the project in Xcode
3. Add `Config.plist` to your Xcode project (but ensure it's not added to git)
4. Select your development team in Signing & Capabilities
5. Build and run on simulator or device

## 🚀 Production Deployment

✅ **Backend integration complete!** Your app now:

1. ✅ **Uses backend server** for all ElevenLabs API calls
2. ✅ **No API key in app** - stored securely on server
3. ✅ **Authenticates users** with Firebase tokens
4. ✅ **Rate limits enabled** - 50 requests/hour per user

See `BACKEND_INTEGRATION_COMPLETE.md` for full details on the secure architecture.

## 📝 Additional Configuration

### Firebase Setup

The app uses Firebase for authentication and data storage. Ensure you have:

- `GoogleService-Info.plist` properly configured
- Firebase project created at https://console.firebase.google.com
- Authentication enabled (Email/Password, Google, and Apple Sign-In)
- Firestore database created
- **Firestore security rules deployed** (see `FIRESTORE_SETUP.md`)

⚠️ **IMPORTANT:** You must deploy Firestore security rules or the app will show permission errors!

**Quick Start:**

1. See `FIRESTORE_SETUP.md` for complete Firestore configuration
2. Deploy the `firestore.rules` file to Firebase Console
3. Restart your app after deploying rules

If you see errors like "Missing or insufficient permissions", see `FIRESTORE_PERMISSION_FIX.md`

## 🆘 Troubleshooting

### "Config.plist not found" error

- Make sure you created `Config.plist` from the template
- Verify it's added to your Xcode project target
- Check that it's in the same directory as other source files

### "Backend service unavailable" error

- Check that backend is running: Visit health endpoint in browser
- Verify `BACKEND_URL` in `Config.plist` is correct
- Ensure `USE_BACKEND` is set to `true`
- Check your internet connection

### Build errors

- Clean build folder (Cmd+Shift+K)
- Delete DerivedData
- Restart Xcode
