# Firestore Setup Guide

## 🔥 Deploying Firestore Security Rules

The `firestore.rules` file contains security rules that control access to your Firestore database. These rules **must be deployed** to Firebase Console for your app to work properly.

### Error Symptoms

If you see errors like:
- ❌ "Error loading membership status: Missing or insufficient permissions"
- ⚠️ "User document doesn't exist yet"
- Any Firestore permission denied errors

This means your security rules are not properly configured.

### Option 1: Deploy via Firebase Console (Recommended)

1. **Open Firebase Console**
   - Go to https://console.firebase.google.com
   - Select your project

2. **Navigate to Firestore Rules**
   - Click "Firestore Database" in the left sidebar
   - Click the "Rules" tab at the top

3. **Copy and Paste Rules**
   - Open the `firestore.rules` file in this project
   - Copy the entire contents
   - Paste into the Firebase Console rules editor
   - Click "Publish" button

### Option 2: Deploy via Firebase CLI

If you have Firebase CLI installed:

```bash
# Install Firebase CLI if you haven't
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize Firebase in your project (if not already done)
firebase init firestore

# Deploy the rules
firebase deploy --only firestore:rules
```

### What the Rules Do

The security rules ensure:

✅ Users can only read/write their own data in `/users/{userId}`
✅ Users can access their own membership subcollection
✅ Users can only manage their own voice recordings
✅ Users can only access their own shelf books
✅ All authenticated users can read books from the library
✅ Users can only access their own reading history
❌ All other access is denied by default

### Security Best Practices

1. **Never use test mode rules in production**
   ```javascript
   // ❌ DON'T USE THIS IN PRODUCTION
   allow read, write: if true;
   ```

2. **Always validate user ownership**
   ```javascript
   // ✅ DO THIS
   allow read, write: if request.auth != null && request.auth.uid == userId;
   ```

3. **Validate data structure** (optional but recommended)
   ```javascript
   allow create: if request.resource.data.keys().hasAll(['email', 'displayName', 'createdAt']);
   ```

### Verify Rules Are Working

After deploying, test your app:

1. Sign in with a test account
2. Check the console logs - you should NOT see permission errors
3. Try accessing user stats, membership, and shelf books
4. All operations should work without errors

### Troubleshooting

**Problem:** Still getting permission errors after deploying rules

**Solutions:**
- Wait 1-2 minutes for rules to propagate
- Hard refresh the app or restart
- Check Firebase Console → Firestore → Rules tab to confirm rules are published
- Check the "Rules playground" in Firebase Console to test specific operations
- Verify your app is using the correct Firebase project (check `GoogleService-Info.plist`)

**Problem:** Rules syntax error

**Solution:**
- Use the Firebase Console rules editor - it validates syntax automatically
- Common issues:
  - Missing semicolons
  - Incorrect match path syntax
  - Unbalanced curly braces

## 📊 Firestore Collections Structure

Your app uses these collections:

```
/users/{userId}
├── email: string
├── displayName: string
├── createdAt: timestamp
├── memberSince: string
├── totalListeningTime: number (optional)
├── hasUsedFreeTrial: boolean (optional)
└── /membership/{document}
    └── /status
        ├── type: string ("free" | "free_trial" | "premium")
        ├── startDate: timestamp
        ├── endDate: timestamp
        ├── usedTimeInSeconds: number
        └── isActive: boolean

/voiceRecordings/{recordingId}
├── name: string
├── voiceId: string
├── userId: string
└── createdAt: timestamp

/userShelfBooks/{shelfBookId}
├── userId: string
├── bookId: string
└── addedAt: timestamp

/books/{bookId}
├── title: string
├── author: string
├── ... (library book data)

/readingHistory/{historyId}
├── userId: string
├── bookId: string
└── ... (reading history data)
```

## 🔐 Additional Security Measures

1. **Enable App Check** (recommended for production)
   - Prevents abuse from unauthorized apps
   - https://firebase.google.com/docs/app-check

2. **Set up billing alerts**
   - Prevent unexpected costs from abuse
   - Firebase Console → Project Settings → Usage and billing

3. **Monitor usage**
   - Check Firestore usage dashboard regularly
   - Set up Cloud Functions to detect unusual patterns

4. **Rate limiting**
   - Consider implementing rate limiting in your app
   - Use Cloud Functions with Firebase Extensions

## 📝 Need Help?

- Firebase Documentation: https://firebase.google.com/docs/firestore/security/get-started
- Firebase Rules Playground: Test rules before deploying
- Firebase Support: https://firebase.google.com/support


