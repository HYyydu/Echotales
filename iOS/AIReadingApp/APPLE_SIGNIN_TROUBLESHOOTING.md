# Apple Sign-In Error 1000: Troubleshooting Guide

## Error Description

**Error Message:** `Apple sign-in failed: Sign in failed: The operation couldn't be completed. (com.apple.AuthenticationServices.Authorization Error error 1000.)`

**Error Code:** `ASAuthorizationErrorUnknown` (error 1000)

This is a generic authorization error that can have multiple root causes.

---

## Potential Causes & Solutions

### 1. **Sign in with Apple Capability Not Enabled in Xcode** ⚠️ MOST COMMON

**Problem:** The "Sign in with Apple" capability is not enabled in your Xcode project's Signing & Capabilities tab.

**Solution:**

1. Open your project in Xcode
2. Select your project in the Project Navigator (blue icon at top)
3. Select the **"AIReadingApp"** target
4. Click the **"Signing & Capabilities"** tab
5. Click the **"+ Capability"** button (top left)
6. Search for and add **"Sign in with Apple"**
7. Make sure it appears in the capabilities list
8. Clean and rebuild your project (`Shift + Command + Option + K`, then `Command + R`)

---

### 2. **Entitlements File Not Linked to Target**

**Problem:** You have `AIReadingAppRelease.entitlements` file, but it might not be properly linked to your app target.

**Solution:**

1. In Xcode, select your project in the Project Navigator
2. Select the **"AIReadingApp"** target
3. Go to **"Build Settings"** tab
4. Search for **"Code Signing Entitlements"**
5. Make sure it shows: `AIReadingApp/AIReadingAppRelease.entitlements`
   - If it's empty or different, click on it and set the path correctly
6. Also check in **"Signing & Capabilities"** tab:
   - The entitlements file should be listed under "App Sandbox" or similar section
   - If not, Xcode should automatically detect it when the capability is enabled

---

### 3. **Bundle Identifier Not Registered in Apple Developer Portal**

**Problem:** Your app's bundle identifier (e.g., `com.aiReadingApp`) is not registered in your Apple Developer account, or Sign in with Apple is not enabled for that identifier.

**Solution:**

1. Go to [Apple Developer Portal](https://developer.apple.com/account/)
2. Sign in with your Apple ID
3. Navigate to **"Certificates, Identifiers & Profiles"**
4. Click **"Identifiers"** in the left sidebar
5. Search for your bundle identifier (e.g., `com.aiReadingApp`)
6. If it doesn't exist:
   - Click the **"+"** button
   - Select **"App IDs"**
   - Enter your bundle identifier
   - Enable **"Sign in with Apple"** capability
   - Click **"Continue"** and **"Register"**
7. If it exists:
   - Click on it to edit
   - Make sure **"Sign in with Apple"** is checked/enabled
   - Click **"Save"**

**Note:** If you're using a free Apple ID (Personal Team), you can still enable Sign in with Apple, but you need to register the bundle identifier first.

---

### 4. **Team Not Selected or Incorrect Team**

**Problem:** Your Xcode project doesn't have a team selected, or the wrong team is selected.

**Solution:**

1. In Xcode, select your project → **"AIReadingApp"** target → **"Signing & Capabilities"** tab
2. Under **"Signing"**, make sure:
   - **"Team"** is selected (should show your name or "Personal Team")
   - **"Automatically manage signing"** is checked
3. If no team appears:
   - Go to **Xcode → Settings → Accounts**
   - Add your Apple ID if not already added
   - Return to Signing & Capabilities and select your team

---

### 5. **Running on Simulator Without Proper Signing**

**Problem:** Apple Sign-In requires proper code signing, even for Simulator builds in some cases.

**Solution:**

1. Make sure your project is properly signed (see Solution #4)
2. Try building for a **physical device** instead of Simulator:
   - Connect your iPhone/iPad
   - Select it as the build destination
   - Build and run
3. If you must use Simulator:
   - Ensure automatic signing is enabled
   - Make sure a team is selected
   - Clean build folder and rebuild

---

### 6. **Provisioning Profile Issues**

**Problem:** The provisioning profile doesn't include the Sign in with Apple capability.

**Solution:**

1. In Xcode, go to **Xcode → Settings → Accounts**
2. Select your Apple ID
3. Click **"Download Manual Profiles"** button
4. Wait for it to complete
5. Go back to your project → **Signing & Capabilities**
6. Uncheck **"Automatically manage signing"**
7. Wait 5 seconds
8. Check **"Automatically manage signing"** again
9. Select your team
10. Wait for Xcode to regenerate the provisioning profile

---

### 7. **Bundle Identifier Mismatch**

**Problem:** The bundle identifier in your project doesn't match what's registered in Apple Developer Portal.

**Solution:**

1. Check your bundle identifier:
   - In Xcode: Project → Target → General → **"Bundle Identifier"**
   - Should be something like: `com.aiReadingApp`
2. Verify it matches in Apple Developer Portal:
   - Go to [developer.apple.com](https://developer.apple.com/account/)
   - Certificates, Identifiers & Profiles → Identifiers
   - Find your app identifier
3. If they don't match:
   - Either change the bundle ID in Xcode to match the registered one
   - Or register a new identifier in the portal with the Xcode bundle ID

---

### 8. **Missing Configuration in Info.plist**

**Problem:** While not always required, some Apple Sign-In configurations might be missing.

**Current Status:** ✅ Your `Info.plist` looks fine - no special Apple Sign-In entries are required there.

---

### 9. **Code Implementation Issues**

**Problem:** The code might have issues with nonce handling or credential creation.

**Current Status:** ✅ Your code in `SignInView.swift` and `AuthenticationManager.swift` looks correct:

- Nonce generation is implemented properly
- SHA256 hashing is correct
- Credential creation follows Firebase documentation

**However, one potential issue:**

- Make sure the nonce is generated **before** the button is tapped
- In your code, `prepareNewAppleSignInNonce()` is called in `onRequest`, which is correct ✅

---

### 10. **Firebase Configuration Issues**

**Problem:** Firebase might not be properly configured for Apple Sign-In.

**Solution:**

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Go to **Authentication → Sign-in method**
4. Make sure **"Apple"** is enabled
5. Verify the **Service ID** and **OAuth configuration** are set up correctly
6. If you haven't set up Apple Sign-In in Firebase:
   - Click on "Apple" provider
   - Follow the setup instructions
   - You'll need to create a Service ID in Apple Developer Portal

---

### 11. **Switching Between Teams/Accounts** ⚠️ IMPORTANT

**Problem:** You've switched from a Personal Team (free account) to a paid Apple Developer account, or vice versa. This can cause signing and capability issues.

**What Happens When You Switch Teams:**

1. **Provisioning profiles become invalid** - They're tied to the old team
2. **Bundle identifier registration** - May need to be re-registered under the new team
3. **Capabilities need to be re-enabled** - Sign in with Apple must be enabled for the new team
4. **Entitlements may need updating** - The entitlements file is still valid, but the team association changes

**Solution - Step by Step:**

1. **Switch Team in Xcode:**

   - Project → Target → Signing & Capabilities
   - Select your new team from the "Team" dropdown (the paid Developer account)
   - Make sure "Automatically manage signing" is checked
   - Wait for Xcode to process (may take 30-60 seconds)

2. **Register Bundle ID Under New Team:**

   - Go to [Apple Developer Portal](https://developer.apple.com/account/)
   - Sign in with your **paid Developer account** (not the free one)
   - Navigate to **Certificates, Identifiers & Profiles → Identifiers**
   - Check if your bundle identifier exists:
     - **If it exists:** Click on it → Make sure "Sign in with Apple" is enabled → Save
     - **If it doesn't exist:** Create a new App ID with your bundle identifier and enable "Sign in with Apple"

3. **Re-enable Sign in with Apple Capability:**

   - In Xcode → Signing & Capabilities
   - If "Sign in with Apple" capability is missing, click "+ Capability" and add it
   - If it's already there, remove it and re-add it to refresh the association

4. **Refresh Provisioning Profiles:**

   - Xcode → Settings → Accounts
   - Select your **paid Developer account**
   - Click "Download Manual Profiles"
   - Wait for completion

5. **Clean and Rebuild:**
   - `Shift + Command + Option + K` (Clean Build Folder)
   - Close and reopen Xcode
   - `Command + R` (Build and Run)

**Benefits of Using a Paid Developer Account:**

✅ **Better for Sign in with Apple:**

- More reliable provisioning profile generation
- Better support for capabilities
- Can create Service IDs for Firebase integration (if needed)

✅ **No Device Limitations:**

- Personal Teams have device registration limits
- Paid accounts have more flexibility

✅ **App Store Distribution:**

- Required for App Store submission
- Better for production apps

**Potential Issues After Switching:**

⚠️ **Bundle ID Conflicts:**

- If your bundle ID was registered under the old team, you may need to:
  - Use a different bundle ID, OR
  - Transfer/register it under the new team (if the old team releases it)

⚠️ **Provisioning Profile Errors:**

- Xcode should automatically regenerate profiles
- If errors persist, manually refresh (see Solution #6)

⚠️ **Capability Not Available:**

- Make sure your paid Developer account has the capability enabled
- Some capabilities require specific account types

**Important Notes:**

- **Your code doesn't need to change** - The implementation stays the same
- **Entitlements file stays the same** - No changes needed to `AIReadingAppRelease.entitlements`
- **Firebase configuration** - May need to update Service ID if you're using Firebase Apple Sign-In
- **Test thoroughly** - After switching, test Sign in with Apple on both Simulator and physical device

---

## Quick Diagnostic Checklist

Use this checklist to systematically diagnose the issue:

- [ ] **Sign in with Apple capability is added** in Xcode (Signing & Capabilities tab)
- [ ] **Entitlements file is linked** (Build Settings → Code Signing Entitlements)
- [ ] **Team is selected** in Signing & Capabilities
- [ ] **Automatically manage signing is enabled**
- [ ] **Bundle identifier is registered** in Apple Developer Portal
- [ ] **Sign in with Apple is enabled** for the bundle identifier in Apple Developer Portal
- [ ] **Firebase has Apple Sign-In enabled** in Authentication settings
- [ ] **Provisioning profiles are up to date** (Download Manual Profiles)
- [ ] **Project builds without errors** (no red warnings in Signing & Capabilities)

---

## Step-by-Step Fix (Recommended Order)

1. **Enable Capability in Xcode** (Most Important)

   - Project → Target → Signing & Capabilities
   - Add "Sign in with Apple" capability

2. **Verify Team and Signing**

   - Select your team
   - Enable automatic signing

3. **Register Bundle ID in Developer Portal**

   - Go to developer.apple.com
   - Register your bundle identifier
   - Enable Sign in with Apple

4. **Refresh Provisioning Profiles**

   - Xcode → Settings → Accounts
   - Download Manual Profiles

5. **Clean and Rebuild**

   - `Shift + Command + Option + K` (Clean Build Folder)
   - `Command + R` (Build and Run)

6. **Test on Physical Device** (if possible)
   - Simulator sometimes has issues with Sign in with Apple

---

## Testing Apple Sign-In

After fixing the configuration:

1. **Build and run** your app
2. **Tap "Sign in with Apple"** button
3. **You should see** the Apple Sign-In sheet appear
4. **Sign in** with your Apple ID
5. **Check Firebase Console** → Authentication → Users
   - You should see a new user with Apple provider

---

## Common Error Messages Reference

| Error Code | Meaning               | Solution                                                   |
| ---------- | --------------------- | ---------------------------------------------------------- |
| 1000       | Unknown/Generic error | Usually capability not enabled or bundle ID not registered |
| 1001       | Canceled              | User canceled - this is normal, not an error               |
| 1002       | Invalid response      | Check Firebase configuration                               |
| 1003       | Not handled           | Implementation issue - check code                          |

---

## Additional Resources

- [Apple Sign-In Documentation](https://developer.apple.com/sign-in-with-apple/)
- [Firebase Apple Sign-In Setup](https://firebase.google.com/docs/auth/ios/apple)
- [Xcode Capabilities Guide](https://developer.apple.com/documentation/xcode/adding-capabilities-to-your-app)

---

## Still Having Issues?

If none of the above solutions work:

1. **Check Xcode Console** for more detailed error messages
2. **Check Firebase Console** → Authentication → Sign-in method → Apple (for configuration errors)
3. **Verify your Apple Developer account** has proper permissions
4. **Try creating a new test project** with Apple Sign-In to isolate the issue
5. **Check if you're using the correct entitlements file** for your build configuration (Debug vs Release)

---

**Last Updated:** Based on your current project structure and code implementation.
