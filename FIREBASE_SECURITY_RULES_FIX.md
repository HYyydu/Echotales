# Fix Firebase Security Rules for Reading History

## 🔴 Your Error: "Query failed" & "Cannot write to Firebase"

This means your Firestore security rules are blocking read/write access to the `readingHistory` collection.

## ✅ Quick Fix (3 Steps)

### Step 1: Open Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Click **Firestore Database** in the left menu
4. Click the **Rules** tab at the top

### Step 2: Add These Rules

Replace your current rules with these (or add to them):

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Books collection (keep existing rules if any)
    match /books/{document} {
      allow read: if true;  // Everyone can read books
      allow write: if request.auth != null;  // Only authenticated users can write
    }

    // Reading History - NEW RULES TO ADD
    match /readingHistory/{document} {
      // Allow users to read their own history
      allow read: if request.auth != null &&
                     resource.data.userId == request.auth.uid;

      // Allow users to write their own history
      allow create: if request.auth != null &&
                       request.resource.data.userId == request.auth.uid;

      // Allow users to delete their own history
      allow delete: if request.auth != null &&
                       resource.data.userId == request.auth.uid;
    }

    // User stats and other collections (keep existing rules if any)
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }

    match /voiceRecordings/{document} {
      allow read, write: if request.auth != null &&
                            resource.data.userId == request.auth.uid;
    }

    match /userShelfBooks/{document} {
      allow read, write: if request.auth != null &&
                            resource.data.userId == request.auth.uid;
    }
  }
}
```

### Step 3: Publish the Rules

1. Click the **"Publish"** button (top right)
2. Wait a few seconds for the rules to deploy
3. Run diagnostics again in your app

---

## 🎯 Alternative: Temporary Test Rules (Development Only)

**⚠️ WARNING: Only use this for testing! NOT for production!**

If you just want to test quickly:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

This allows any authenticated user to read/write everything. Use only for testing!

---

## 🔐 What These Rules Do

The recommended rules ensure:

✅ **Privacy**: Users can only see their own reading history
✅ **Security**: Users can't modify other users' data  
✅ **Authentication**: Only logged-in users can access history
✅ **Data Integrity**: Users can't change their userId when writing

---

## 🧪 After Updating Rules

1. Wait 10-20 seconds for rules to deploy
2. Go back to your app
3. Tap **⋯ → Run Diagnostics** again
4. You should now see:
   - ✅ Reading History Data: Found X history entries
   - ✅ Write Test: Write permissions OK

---

## 🤔 Still Getting Errors?

### Check Firebase Authentication Status

First, expand the error cards in diagnostics (tap the ▼) to see full details.

**If you see "permission-denied" errors:**

- Make sure you're logged in (Firebase Auth)
- Check that the rules are published
- Wait a few seconds and try again

**If you see "unauthenticated" errors:**

- You need to log in first
- The app requires Firebase Authentication

### Quick Auth Check

Add this code temporarily to check if you're logged in:

```swift
// Add this somewhere in your app (like in ContentView.onAppear)
if let user = Auth.auth().currentUser {
    print("✅ Logged in as: \(user.uid)")
} else {
    print("❌ Not logged in - logging in anonymously...")
    Auth.auth().signInAnonymously { result, error in
        if let error = error {
            print("Error: \(error)")
        } else {
            print("✅ Logged in anonymously")
        }
    }
}
```

---

## 📱 Quick Test After Fixing

1. **Update Firebase Rules** (see above)
2. **Run diagnostics** - Should show ✅ for all checks
3. **Click any book** from Read tab
4. **Go to Reading History** - Should see the book!

---

## 🆘 Need More Help?

**Tap the ▼ chevron** on each error card in diagnostics to see detailed error messages. Share those if you need more help!
