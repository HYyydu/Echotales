# Setup Instructions for Echotales

## 🔐 API Key Configuration

This app requires an ElevenLabs API key to function. The API key is stored in a secure configuration file that is **not** committed to version control.

### First-Time Setup

1. **Copy the template file:**

   ```bash
   cp Config.plist.template Config.plist
   ```

2. **Add your API keys to `Config.plist`:**

   - Replace `YOUR_ELEVENLABS_API_KEY_HERE` with your actual ElevenLabs API key
   - Get your API key from: https://elevenlabs.io/app/settings/api-keys

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
    <key>ELEVENLABS_API_KEY</key>
    <string>your_actual_api_key_here</string>
    <key>ELEVENLABS_BASE_URL</key>
    <string>https://api.elevenlabs.io/v1</string>
    <key>DEBUG_MODE</key>
    <false/>
</dict>
</plist>
```

### Important Security Notes

⚠️ **NEVER commit `Config.plist` to git**
⚠️ **NEVER share your API key publicly**
⚠️ **NEVER screenshot or share Config.plist contents**

## 🏗️ Building the App

1. Ensure you have Xcode installed (version 14.0 or later recommended)
2. Open the project in Xcode
3. Add `Config.plist` to your Xcode project (but ensure it's not added to git)
4. Select your development team in Signing & Capabilities
5. Build and run on simulator or device

## 🚀 Production Deployment

**IMPORTANT:** The current implementation stores the API key in the app bundle, which is not fully secure for production. For a production app, you should:

1. **Set up a backend server** to proxy API calls
2. **Remove the API key** from the app entirely
3. **Authenticate users** with your backend
4. **Rate limit** API calls on your backend

See `SECURITY.md` for more details on implementing a secure backend.

## 📝 Additional Configuration

### Firebase Setup

The app uses Firebase for authentication and data storage. Ensure you have:

- `GoogleService-Info.plist` properly configured
- Firebase project created at https://console.firebase.google.com
- Authentication enabled (Anonymous auth is used by default)
- Firestore database created

## 🆘 Troubleshooting

### "Config.plist not found" error

- Make sure you created `Config.plist` from the template
- Verify it's added to your Xcode project target
- Check that it's in the same directory as other source files

### "ELEVENLABS_API_KEY not found" error

- Open `Config.plist` and verify the API key is present
- Make sure the key name is exactly `ELEVENLABS_API_KEY`
- Ensure the value is not empty

### Build errors

- Clean build folder (Cmd+Shift+K)
- Delete DerivedData
- Restart Xcode
