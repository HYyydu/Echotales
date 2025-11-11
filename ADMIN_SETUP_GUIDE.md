# 🔧 Admin Panel Setup Guide

## Problem: Permission Denied When Uploading Books

Your admin panel needs **Firebase Authentication** to upload books. The security rules require authentication for write operations.

---

## ✅ Quick Fix Steps

### Step 1: Enable Firebase Authentication

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project (`echotales-d23cc`)
3. Click **Authentication** in the left menu
4. Click **Get Started** (if not already enabled)
5. Click **Sign-in method** tab
6. Enable **Email/Password** authentication
   - Click on "Email/Password"
   - Toggle **Enable**
   - Click **Save**

### Step 2: Create an Admin User

Still in Firebase Console:

1. Go to **Authentication → Users** tab
2. Click **Add user**
3. Enter an email (e.g., `admin@echotales.com`)
4. Enter a password (use a strong password!)
5. Click **Add user**

### Step 3: Update Firestore Rules

1. Go to **Firestore Database → Rules** tab
2. Copy the contents from `firestore.rules` file in your project
3. Or paste this:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Books collection - everyone can read, authenticated users can write
    match /books/{document} {
      allow read: if true;
      allow write: if request.auth != null;
    }

    // Reading History - users can only access their own history
    match /readingHistory/{document} {
      allow read: if request.auth != null && resource.data.userId == request.auth.uid;
      allow create: if request.auth != null && request.resource.data.userId == request.auth.uid;
      allow delete: if request.auth != null && resource.data.userId == request.auth.uid;
    }

    // Users collection - users can only access their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }

    // Voice recordings - users can only access their own recordings
    match /voiceRecordings/{document} {
      allow read, write: if request.auth != null && resource.data.userId == request.auth.uid;
    }

    // User shelf books - users can only access their own shelf
    match /userShelfBooks/{document} {
      allow read, write: if request.auth != null && resource.data.userId == request.auth.uid;
    }
  }
}
```

4. Click **Publish**

### Step 4: Update Storage Rules

1. Go to **Storage → Rules** tab
2. Copy the contents from `storage.rules` file in your project
3. Or paste this:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {

    // Book covers - authenticated users can upload, everyone can read
    match /book-covers/{bookId} {
      allow read: if true;
      allow write: if request.auth != null;
    }

    // Voice recordings - users can only access their own recordings
    match /voice-recordings/{userId}/{recordingId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }

    // Default deny all other paths
    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
```

4. Click **Publish**

### Step 5: Use the Admin Panel

1. Open `admin/index.html` in your browser
2. You'll see a login form
3. Enter the admin email and password you created
4. After login, you can upload books!

---

## 🎯 What Was Changed?

### admin/index.html

- ✅ Added Firebase Authentication imports
- ✅ Added login/logout UI
- ✅ Admin panels now require authentication
- ✅ Upload/delete operations only available when logged in

### firestore.rules

- ✅ Books: Anyone can read, authenticated users can write
- ✅ Reading history: Users can only access their own
- ✅ Other collections: User-specific access only

### storage.rules (NEW FILE)

- ✅ Book covers: Anyone can read, authenticated users can upload
- ✅ Voice recordings: User-specific access only

---

## 🔐 Security Features

Your admin panel now has:

✅ **Login Required** - Can't upload without authentication
✅ **Secure Rules** - Firestore and Storage rules prevent unauthorized access
✅ **User Privacy** - Each user can only access their own data
✅ **Public Books** - Everyone can read books (but not modify)

---

## 🆘 Troubleshooting

### "Login failed: auth/user-not-found"

- You haven't created an admin user in Firebase Console
- Go to Authentication → Users → Add user

### "Login failed: auth/wrong-password"

- Check your password
- Reset it in Firebase Console if needed

### Still getting "Permission denied"

1. Make sure you're logged in (check top of admin panel)
2. Wait 10-20 seconds after updating rules
3. Try refreshing the page
4. Check browser console (F12) for detailed errors

### "Firebase: Error (auth/configuration-not-found)"

- Email/Password authentication not enabled
- Go to Firebase Console → Authentication → Sign-in method
- Enable "Email/Password"

---

## 🚀 Next Steps

1. **Deploy the rules** to Firebase Console
2. **Create an admin user** in Firebase Authentication
3. **Test the login** with your admin credentials
4. **Upload a book** to verify everything works!

---

## ⚠️ Important Notes

### DO NOT use these temporary rules:

```javascript
// ❌ NEVER USE THIS IN PRODUCTION
allow read, write: if true;
```

This allows anyone to read/write everything without authentication!

### Production Checklist:

- ✅ Authentication enabled
- ✅ Admin user created with strong password
- ✅ Firestore rules deployed
- ✅ Storage rules deployed
- ✅ Test uploading a book
- ✅ Test iOS app still works

---

## 📱 iOS App Compatibility

The iOS app uses anonymous authentication by default, which works with these rules because:

- Books: Public read access (anonymous users can read)
- User data: Each user can only access their own data
- Reading history: Tied to user's anonymous UID

---

## 🔄 Alternative: Anonymous Admin Access (NOT RECOMMENDED)

If you want to skip login for development only:

1. Enable **Anonymous Authentication** in Firebase Console
2. Add this to admin/index.html after initializing Firebase:

```javascript
// Auto-login anonymously (DEVELOPMENT ONLY)
auth.signInAnonymously();
```

**⚠️ Warning:** Anyone with access to the admin panel URL can upload/delete books!

---

## 📞 Need Help?

Check browser console (F12) for detailed error messages when:

- Login fails
- Upload fails
- Rules are rejected

Error messages will tell you exactly what's wrong!
