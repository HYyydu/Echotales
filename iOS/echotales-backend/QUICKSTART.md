# 🚀 Quick Start Guide

This guide will get your backend server running in **5 minutes**.

## ✅ Step 1: Prerequisites (COMPLETED)

- ✅ Node.js installed
- ✅ Project created
- ✅ Dependencies installed
- ✅ Basic configuration set up

## 🔐 Step 2: Get Firebase Service Account Key (REQUIRED)

You need a Firebase service account key for authentication to work.

### How to get it:

1. Go to: https://console.firebase.google.com/
2. Select your project: **echotales-d23cc**
3. Click the gear icon ⚙️ → **Project Settings**
4. Click **Service Accounts** tab
5. Click **Generate New Private Key** button
6. Download the JSON file
7. Rename it to `firebase-service-account.json`
8. Move it to this directory: `/Users/yuyan/TestCursorRecord/iOS/echotales-backend/`

**Important:** This file is already in `.gitignore` and will NOT be committed to git.

## 🧪 Step 3: Test the Server (Optional - works without Firebase)

The server can run without Firebase (with limited functionality) for testing:

```bash
cd /Users/yuyan/TestCursorRecord/iOS/echotales-backend
npm start
```

You should see:
```
🚀 Echotales backend server running on port 3000
📍 Health check: http://localhost:3000/health
🔐 Firebase Auth: Disabled
```

Test the health endpoint:
```bash
curl http://localhost:3000/health
```

Press `Ctrl+C` to stop the server.

## 🎯 Step 4: Start Development Server

Once you have the Firebase service account key:

```bash
cd /Users/yuyan/TestCursorRecord/iOS/echotales-backend
npm run dev
```

The server will:
- ✅ Start on port 3000
- ✅ Auto-reload on code changes
- ✅ Enable Firebase authentication
- ✅ Be ready for iOS app connections

## 📱 Step 5: Update iOS App to Use Backend

Next, you'll need to update your iOS app to call the backend instead of ElevenLabs directly.

**We'll do this in the next step!**

## 🔧 Troubleshooting

### "Cannot find module 'express'"
```bash
npm install
```

### Server won't start
Check if port 3000 is already in use:
```bash
lsof -ti:3000
```

Kill the process:
```bash
kill -9 $(lsof -ti:3000)
```

Or change the port in `.env`:
```
PORT=3001
```

### Firebase errors
- Make sure `firebase-service-account.json` exists in this directory
- Verify the file is valid JSON
- Check file permissions (should be readable)

## 📊 What's Next?

1. ✅ Get Firebase service account key
2. ✅ Start the server
3. 🔜 Update iOS app to use backend (we'll do this together)
4. 🔜 Test end-to-end
5. 🔜 Deploy to production (Google Cloud Run, Heroku, etc.)

## 🆘 Need Help?

If something doesn't work, check:
1. Node.js version: `node --version` (should be 18+)
2. Server logs in the terminal
3. `.env` file has correct values
4. All dependencies installed: `npm install`

Ready to continue? Let me know when you have the Firebase service account key!

