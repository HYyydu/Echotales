# 📚 Echotales - AI Reading App

An iOS and web application that uses AI voice cloning to read children's books in a personalized voice.

## ✨ Features

### 🎙️ Voice Recorder
- Record your voice for 30 seconds
- Upload to ElevenLabs for AI voice cloning
- Three states: Initial, Recording, and Finished
- Real-time audio level visualization

### 📖 Book Library
- Browse children's books by age group and genre
- Search books by title or author
- Filter by age (0-3, 4-6, 7-9, 10-12, 13+)
- Filter by genre (Adventure, Fantasy, Animals, etc.)
- Firebase-powered book storage

### 👨‍💼 Admin Panel
- Web-based book management
- Upload book covers and content
- Edit and delete books
- Real-time Firebase sync

## 🛠️ Tech Stack

- **iOS:** SwiftUI, Firebase iOS SDK, AVFoundation
- **Web:** React, Vite, Firebase Web SDK
- **Backend:** Firebase (Firestore + Storage)
- **AI:** ElevenLabs Voice API

## 🚀 Getting Started

### Prerequisites

- Xcode 15+ (for iOS)
- Node.js 16+ (for web)
- Firebase account
- ElevenLabs API key

### Installation

#### Web App

```bash
# Install dependencies
npm install

# Start development server
npm run dev

# Open browser to http://localhost:3000
```

#### iOS App

1. Open `iOS/AIReadingApp.xcodeproj` in Xcode
2. Update `GoogleService-Info.plist` with your Firebase config
3. Add your ElevenLabs API key to `ElevenLabsService.swift`
4. Build and run on simulator or device

### Firebase Setup

1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Enable Firestore Database (start in test mode)
3. Enable Storage (start in test mode)
4. Download config files:
   - Web: Update `src/config/firebase.js`
   - iOS: Add `GoogleService-Info.plist`

See `FIREBASE_SETUP.md` for detailed instructions.

## 📱 App Structure

```
TestCursorRecord/
├── iOS/                      # iOS SwiftUI app
│   └── AIReadingApp/
│       ├── ContentView.swift          # Main tab navigation
│       ├── VoiceRecorderView.swift    # Voice recording UI
│       ├── BookReaderView.swift       # Book library UI
│       ├── ElevenLabsService.swift    # API integration
│       └── AudioRecorderManager.swift # Audio recording
├── src/                      # React web app
│   ├── components/
│   │   ├── VoiceRecorder.jsx
│   │   └── BookReader.jsx
│   └── config/
│       └── firebase.js
├── admin/                    # Admin panel
│   └── index.html
└── scripts/                  # Utility scripts
    ├── uploadSampleBooks.js
    └── importFreeKidsBooks.js
```

## 🎨 Design System

- **Primary Pink:** #F9DAD2
- **Secondary Pink:** #F5B5A8
- **Text Primary:** #0F172A (Slate 900)
- **Text Secondary:** #475569 (Slate 600)
- **Background:** #FFFFFF (White)

## 📝 Usage

### Adding Books

1. Open the admin panel: `http://localhost:3000/admin/index.html`
2. Fill in book details (title, author, age, genre, tags)
3. Upload a cover image
4. Add book content/story text
5. Click "Upload Book"

Books will appear in both the web and iOS apps!

### Recording Voice

1. Open the iOS app
2. Tap the "Record" tab
3. Tap the microphone button
4. Record for 30 seconds
5. Voice is uploaded to ElevenLabs
6. Use the cloned voice to read stories!

## 🔐 Security Notes

⚠️ **Important:** This project is configured for development. For production:

1. Update Firebase security rules
2. Use environment variables for API keys
3. Enable authentication
4. Add proper error handling

## 📄 License

MIT License - feel free to use this project for learning or personal use.

## 🙏 Credits

- Built with SwiftUI, React, and Firebase
- Voice cloning powered by [ElevenLabs](https://elevenlabs.io/)
- Book content from [Free Kids Books](https://freekidsbooks.org/)

## 🐛 Known Issues

- Cover images may take time to load on first view
- Voice recording requires microphone permissions
- Firebase must be configured before books will sync

## 📧 Contact

For questions or issues, please open a GitHub issue.

---

Made with ❤️ for children's literacy
