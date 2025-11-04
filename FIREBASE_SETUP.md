# Firebase Setup Guide

This guide will help you set up Firebase for your AI Reading App.

## Prerequisites

- Google account
- Your app already created (web and iOS)

---

## Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Click "Add project" or "Create a project"
3. Enter project name: `ai-reading-app` (or your choice)
4. Disable Google Analytics (optional for prototype)
5. Click "Create project"

---

## Step 2: Enable Firebase Services

### Firestore Database

1. In Firebase Console, go to **Build** → **Firestore Database**
2. Click "Create database"
3. Select **Start in test mode** (for development)
4. Choose a location (us-central1 or closest to you)
5. Click "Enable"

### Firebase Storage

1. Go to **Build** → **Storage**
2. Click "Get started"
3. Select **Start in test mode**
4. Click "Done"

---

## Step 3: Configure Web App

1. In Firebase Console, click the **web icon** (</>) to add a web app
2. Enter app nickname: `AI Reading Web App`
3. Click "Register app"
4. **Copy the Firebase configuration** object
5. Update `src/config/firebase.js`:

```javascript
const firebaseConfig = {
  apiKey: "AIza...", // Your actual values
  authDomain: "your-app.firebaseapp.com",
  projectId: "your-project-id",
  storageBucket: "your-app.appspot.com",
  messagingSenderId: "123456789",
  appId: "1:123456789:web:abc123",
};
```

---

## Step 4: Configure iOS App

1. In Firebase Console, click the **iOS icon** to add an iOS app
2. Enter iOS bundle ID: `com.aiReadingApp`
3. Enter app nickname: `AI Reading iOS App`
4. Click "Register app"
5. **Download GoogleService-Info.plist**
6. Replace the file at:
   ```
   iOS/AIReadingApp/GoogleService-Info.plist
   ```

### Install Firebase SDK for iOS

1. Open Terminal
2. Navigate to the iOS folder:

   ```bash
   cd /Users/yuyan/TestCursorRecord/iOS
   ```

3. Install CocoaPods (if not already installed):

   ```bash
   sudo gem install cocoapods
   ```

4. Install Firebase pods:

   ```bash
   pod install
   ```

5. **From now on, open `AIReadingApp.xcworkspace`** (not `.xcodeproj`)

### Update App.swift

Add Firebase initialization to `iOS/AIReadingApp/App.swift`:

```swift
import SwiftUI
import FirebaseCore

@main
struct AIReadingApp: App {
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

---

## Step 5: Update Firebase Rules (Security)

### Firestore Rules

In Firebase Console → Firestore → Rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Books collection - read by anyone, write by admin only
    match /books/{bookId} {
      allow read: if true;
      allow write: if false; // Change to admin auth later
    }

    // User voices - read/write by authenticated users only
    match /users/{userId}/voices/{voiceId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

### Storage Rules

In Firebase Console → Storage → Rules:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Book covers - readable by anyone
    match /book-covers/{bookId} {
      allow read: if true;
      allow write: if false; // Admin only
    }

    // User voice recordings - user-specific
    match /user-voices/{userId}/{allPaths=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

---

## Step 6: Install Dependencies

### Web App

```bash
cd /Users/yuyan/TestCursorRecord
npm install
```

### iOS App

```bash
cd /Users/yuyan/TestCursorRecord/iOS
pod install
```

**Important:** After running `pod install`, always open `AIReadingApp.xcworkspace` instead of `AIReadingApp.xcodeproj`

---

## Step 7: Upload Sample Books

### Using the Admin Panel

1. Open the admin panel:
   ```bash
   cd /Users/yuyan/TestCursorRecord
   open admin/index.html
   ```
2. Update Firebase config in the HTML file
3. Upload books through the web interface

### Using the Script

1. Update Firebase config in `scripts/uploadSampleBooks.js`
2. Run:
   ```bash
   node scripts/uploadSampleBooks.js
   ```

---

## Step 8: Test the App

### Web App

```bash
npm run dev
```

Visit http://localhost:3000

### iOS App

1. Open `AIReadingApp.xcworkspace` in Xcode (not .xcodeproj)
2. Select a simulator
3. Press Cmd + R to run

---

## Verification Checklist

- [ ] Firebase project created
- [ ] Firestore Database enabled
- [ ] Storage enabled
- [ ] Web app Firebase config updated in `src/config/firebase.js`
- [ ] iOS GoogleService-Info.plist downloaded and added
- [ ] CocoaPods installed (`pod install` completed)
- [ ] Opening `.xcworkspace` file (not `.xcodeproj`)
- [ ] Firebase initialized in App.swift
- [ ] Sample books uploaded to Firestore
- [ ] App can fetch and display books

---

## Common Issues

### iOS: "No such module 'Firebase'"

- Make sure you ran `pod install`
- Open the `.xcworkspace` file, NOT `.xcodeproj`
- Clean build folder (Shift + Cmd + K)

### Web: Firebase not initializing

- Check that config values are correct
- Make sure Firebase is imported before use
- Check browser console for errors

### Storage: Permission denied

- Update Storage rules to allow read access
- For development, use test mode rules

---

## Next Steps

After Firebase is set up:

1. Books will load dynamically from Firestore
2. You can upload new books through the admin panel
3. Book covers will be stored in Firebase Storage
4. Both web and iOS apps will share the same data

## Cost Estimate

Firebase free tier includes:

- **Firestore:** 50,000 reads/day, 20,000 writes/day
- **Storage:** 5GB storage, 1GB/day downloads
- **Perfect for prototypes and testing**

For production, costs scale with usage.
