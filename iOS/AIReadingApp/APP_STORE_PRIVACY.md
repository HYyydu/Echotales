# App Store Connect Privacy Configuration Guide

This guide helps you fill out the **App Privacy** section in App Store Connect for Echotales.

## Overview

When submitting your app to the App Store, you must declare what data you collect in App Store Connect under **App Privacy**. This information appears on your App Store product page.

---

## Step-by-Step Configuration

### 1. Contact Information

#### **Email Address**

- **Collected:** ✅ Yes
- **Linked to User:** ✅ Yes
- **Used for Tracking:** ❌ No
- **Purposes:**
  - ✅ App Functionality
  - ✅ Account Management

#### **Name**

- **Collected:** ✅ Yes
- **Linked to User:** ✅ Yes
- **Used for Tracking:** ❌ No
- **Purposes:**
  - ✅ App Functionality
  - ✅ Account Management

---

### 2. User Content

#### **Audio Data**

- **Collected:** ✅ Yes
- **Linked to User:** ✅ Yes
- **Used for Tracking:** ❌ No
- **Purposes:**
  - ✅ App Functionality
- **Description:** "Audio recordings are collected when you choose to create a voice clone. These recordings are processed to generate a personalized narration voice."

#### **Other User Content**

- **Collected:** ✅ Yes
- **Linked to User:** ✅ Yes
- **Used for Tracking:** ❌ No
- **Purposes:**
  - ✅ App Functionality
- **Description:** "Documents (PDF, EPUB, TXT, Word) that you upload to the app are stored for your personal reading library."

---

### 3. Usage Data

#### **Product Interaction**

- **Collected:** ✅ Yes
- **Linked to User:** ✅ Yes
- **Used for Tracking:** ❌ No
- **Purposes:**
  - ✅ App Functionality
  - ✅ Analytics
- **Description:** "We track which books you view and read to provide reading history and personalized recommendations."

---

### 4. Identifiers

#### **User ID**

- **Collected:** ✅ Yes
- **Linked to User:** ✅ Yes
- **Used for Tracking:** ❌ No
- **Purposes:**
  - ✅ App Functionality
  - ✅ Account Management
- **Description:** "A unique identifier is created for your account to manage authentication and data synchronization."

---

## Data NOT Collected

Mark **NO** for the following categories:

- ❌ Health & Fitness
- ❌ Financial Info
- ❌ Location
- ❌ Sensitive Info
- ❌ Contacts
- ❌ Search History
- ❌ Browsing History
- ❌ Purchases
- ❌ Other Data Types (Photos, Videos, Gameplay Content, Customer Support, etc.)
- ❌ Diagnostics (unless you implement crash reporting)
- ❌ Device ID (not explicitly collected)

---

## Third-Party Partners

### Question: "Do you or your third-party partners collect data from this app?"

**Answer:** ✅ Yes

### Third-Party Partners Collecting Data:

1. **Firebase (Google)**

   - Authentication
   - Cloud storage
   - Database services

2. **Google Sign-In**

   - Authentication

3. **Apple Sign-In**

   - Authentication

4. **ElevenLabs**
   - Voice cloning and text-to-speech

---

## Privacy Policy URL

You must provide a URL to your privacy policy. Options:

1. **Host on your website:** `https://yourwebsite.com/privacy`
2. **GitHub Pages:** Host `PRIVACY_POLICY.md` on GitHub Pages
3. **Third-party service:** Use services like TermsFeed or iubenda

### If you don't have a website:

Convert the `PRIVACY_POLICY.md` to HTML and host it on:

- **GitHub Pages** (free)
- **Firebase Hosting** (free tier available)
- **Netlify** (free tier available)

---

## Additional Questions in App Store Connect

### "Does this app collect data to track users across apps and websites owned by other companies?"

**Answer:** ❌ No

**Explanation:** We do not use data for cross-app or cross-site tracking for advertising purposes.

---

### "Do you use data from this app for tracking purposes?"

**Answer:** ❌ No

**Explanation:** We collect data for app functionality and analytics within our app only, not for advertising or tracking.

---

### "Are you or your third-party partners using data from this app to serve ads?"

**Answer:** ❌ No

**Explanation:** We do not display ads or use data for advertising purposes.

---

## Important Notes

### 1. Keep Privacy Policy Updated

When you add new features that collect data, update:

- `PRIVACY_POLICY.md`
- App Store Connect privacy declarations
- `PrivacyInfo.xcprivacy`

### 2. Privacy Manifest

The `PrivacyInfo.xcprivacy` file must be included in your Xcode project. Make sure it's:

- Added to your target
- Submitted with your app bundle
- Kept in sync with App Store declarations

### 3. Third-Party SDK Updates

When updating Firebase, Google Sign-In, or other SDKs, check if they've changed their data collection practices and update your privacy declarations accordingly.

### 4. Testing Privacy Features

Before submission, test:

- Sign in with Apple/Google/Email
- Voice recording permissions
- Microphone permission dialogs
- Account deletion functionality

---

## Example Privacy Policy Locations

### Option 1: GitHub Pages (Free)

```
1. Create a new repository or use existing one
2. Enable GitHub Pages in repository settings
3. Upload PRIVACY_POLICY.md (or convert to HTML)
4. URL: https://[username].github.io/[repo]/privacy.html
```

### Option 2: Firebase Hosting (Free)

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize hosting
firebase init hosting

# Deploy
firebase deploy --only hosting
```

### Option 3: Create Simple HTML

```html
<!DOCTYPE html>
<html>
  <head>
    <title>Privacy Policy - Echotales</title>
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <style>
      body {
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto,
          sans-serif;
        line-height: 1.6;
        max-width: 800px;
        margin: 0 auto;
        padding: 20px;
      }
      h1 {
        color: #333;
      }
      h2 {
        color: #555;
        margin-top: 30px;
      }
      h3 {
        color: #777;
      }
    </style>
  </head>
  <body>
    <!-- Paste converted markdown content here -->
  </body>
</html>
```

---

## Review Checklist

Before submitting to App Store Connect:

- [ ] Privacy policy hosted and accessible
- [ ] All collected data types declared
- [ ] Purposes for each data type specified
- [ ] Third-party data collection acknowledged
- [ ] Tracking questions answered correctly
- [ ] `PrivacyInfo.xcprivacy` included in app bundle
- [ ] `Info.plist` includes usage descriptions (NSMicrophoneUsageDescription)
- [ ] Tested all privacy-sensitive features
- [ ] Privacy policy matches App Store declarations
- [ ] Contact information provided for privacy inquiries

---

## Need Help?

If you're unsure about any privacy declarations:

1. **Review Apple's Guidelines:** [App Store Review Guidelines - Privacy](https://developer.apple.com/app-store/review/guidelines/#privacy)
2. **Check Firebase Documentation:** [Firebase iOS Privacy](https://firebase.google.com/docs/ios/app-privacy-details)
3. **Consult Legal Counsel:** For complex privacy requirements or international compliance

---

**Remember:** Accurate privacy disclosures are required by Apple and protect both you and your users. When in doubt, err on the side of transparency and over-disclosure rather than under-disclosure.
