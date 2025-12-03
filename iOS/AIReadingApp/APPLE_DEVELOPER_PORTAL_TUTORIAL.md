# Apple Developer Portal: Register Bundle ID with Sign in with Apple

## Your Bundle Identifier
**`com.aiReadingApp`**

---

## 📱 Step-by-Step Tutorial

### Step 1: Access Apple Developer Portal

**Website:** **https://developer.apple.com/account/**

1. Open your web browser
2. Go to: **https://developer.apple.com/account/**
3. Click **"Sign In"** in the top right corner
4. Sign in with your Apple ID (the one you use for development)

---

### Step 2: Navigate to Identifiers

1. After signing in, you'll see the **"Certificates, Identifiers & Profiles"** page
2. In the **left sidebar**, click on **"Identifiers"**
   - It's under the "Identifiers" section
   - Icon looks like a blue app icon

![Screenshot showing Identifiers menu location]

---

### Step 3: Check if Your Bundle ID Already Exists

1. On the Identifiers page, you'll see a **search box** at the top
2. Type **`com.aiReadingApp`** in the search box
3. Look through the list to see if it already exists

**Two scenarios:**

#### Scenario A: Bundle ID Already Exists ✅
- If you see **`com.aiReadingApp`** in the list:
  - Click on it
  - **Go to Step 5 (Enable Sign in with Apple)**

#### Scenario B: Bundle ID Does NOT Exist ➕
- If it's not in the list:
  - **Continue to Step 4 (Create New Bundle ID)**

---

### Step 4: Create a New Bundle Identifier (if it doesn't exist)

1. Click the **blue "+" button** in the top left corner
   - Button says "Register an App ID" or just shows a "+" icon

2. **Select App ID Type:**
   - Select **"App IDs"**
   - Click **"Continue"**

3. **Select App ID Type (again):**
   - Select **"App"** (not "App Clip")
   - Click **"Continue"**

4. **Register an App ID - Fill in the form:**

   **Description:**
   ```
   AI Reading App
   ```
   (Or any descriptive name you want)

   **Bundle ID:**
   - Select **"Explicit"** (not Wildcard)
   - Enter: **`com.aiReadingApp`**
   - ⚠️ **IMPORTANT:** This must match exactly what's in your Xcode project

5. **Capabilities - Scroll down to find:**
   - ☑️ Check the box for **"Sign in with Apple"**
   - You can leave other capabilities unchecked for now
   - Common capabilities you might also want:
     - Push Notifications
     - iCloud
     - App Groups (if needed)

6. **Review:**
   - Click **"Continue"** at the bottom
   - Review your settings
   - Click **"Register"**

7. **Success!** 🎉
   - You should see a confirmation that your App ID was created
   - **Continue to Step 6 (Verify)**

---

### Step 5: Enable Sign in with Apple (for existing Bundle ID)

If your Bundle ID already existed:

1. Click on **`com.aiReadingApp`** in the identifiers list
2. Scroll down to the **"Capabilities"** section
3. Find **"Sign in with Apple"**
4. Check the box: ☑️ **"Sign in with Apple"**
5. Click **"Save"** at the top right
6. A confirmation dialog will appear - click **"Confirm"**
7. **Continue to Step 6 (Verify)**

---

### Step 6: Verify Sign in with Apple is Enabled

1. Go back to **Identifiers** (left sidebar)
2. Click on **`com.aiReadingApp`** in the list
3. Scroll down to **"Capabilities"**
4. Confirm you see:
   - ☑️ **Sign in with Apple** - **Enabled**

---

## 🔑 Important Notes

### About Apple Developer Account Types:

**Free Apple Developer Account (Personal Team):**
- ✅ Can use Sign in with Apple
- ✅ Can test on your own devices
- ❌ Cannot submit to App Store
- ❌ Limited to 3 devices per device type

**Paid Apple Developer Account ($99/year):**
- ✅ Full access to all capabilities
- ✅ Can submit to App Store
- ✅ No device limitations
- ✅ Better provisioning profile management

### Which Account Do You Have?

To check:
1. Go to: **https://developer.apple.com/account/**
2. Look at the top of the page:
   - **"Personal Team"** = Free account
   - **Your name or company name** = Paid account ($99/year)

---

## 🔍 Troubleshooting

### Issue: "You don't have permission to register an App ID"

**Solution:**
- You need at least a free Apple Developer account
- Go to **https://developer.apple.com/programs/**
- Click **"Enroll"** for a free account
- Or purchase the $99/year program

### Issue: "Bundle ID already in use"

**Solution:**
- Someone else (or another account) is using that Bundle ID
- Option 1: Use a different Bundle ID (e.g., `com.yourname.aiReadingApp`)
- Option 2: If it's your other account, release it from that account first

### Issue: "Sign in with Apple is not available"

**Solution:**
- Make sure you're signed in with the correct Apple ID
- Some older accounts might have restrictions
- Try signing out and back in

---

## ✅ After Completing This Tutorial

### Next Steps in Xcode:

1. **Open your project in Xcode**
2. **Select your project** in the Project Navigator (blue icon)
3. **Select the "AIReadingApp" target**
4. **Click "Signing & Capabilities" tab**
5. **Add the capability:**
   - Click **"+ Capability"** button (top left)
   - Search for and add **"Sign in with Apple"**
6. **Verify your Team:**
   - Make sure a **Team** is selected (should match your Apple Developer account)
   - Enable **"Automatically manage signing"** checkbox
7. **Clean and rebuild:**
   - Press `Shift + Command + Option + K` (Clean Build Folder)
   - Press `Command + R` (Build and Run)

### What Should Happen:

✅ Xcode will automatically download/create the correct provisioning profile  
✅ The "Sign in with Apple" capability will show in your entitlements  
✅ When you tap the "Sign in with Apple" button, the Apple Sign-In sheet will appear  
✅ No more Error 1000!

---

## 📚 Additional Resources

- **Apple Developer Portal:** https://developer.apple.com/account/
- **Sign in with Apple Documentation:** https://developer.apple.com/sign-in-with-apple/
- **Firebase Apple Sign-In Setup:** https://firebase.google.com/docs/auth/ios/apple
- **Xcode Capabilities Guide:** https://developer.apple.com/documentation/xcode/adding-capabilities-to-your-app

---

## 📞 Need Help?

If you encounter any issues:

1. Check that your Bundle ID in Xcode matches exactly: **`com.aiReadingApp`**
2. Make sure you're signed in with the correct Apple ID in Xcode (Xcode → Settings → Accounts)
3. Try downloading provisioning profiles manually:
   - Xcode → Settings → Accounts → Select your Apple ID → "Download Manual Profiles"
4. Clean build folder and restart Xcode

---

## ⏱️ How Long Does This Take?

- **Creating/updating Bundle ID:** 2-5 minutes
- **Xcode recognizing changes:** Immediate to 1 minute
- **Total time:** ~5-10 minutes

---

**Created for:** AI Reading App  
**Bundle ID:** com.aiReadingApp  
**Date:** December 3, 2025

