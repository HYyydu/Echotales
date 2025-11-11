# AI Reading App (Echotales)

An iOS reading app that lets users record their voice, clone it using AI, and listen to books narrated in their own voice.

## 🎯 Features

- **Voice Recording & Cloning**: Record your voice and create AI-powered voice clones using ElevenLabs
- **Read Books**: Browse and read from a collection of classic literature
- **Listen Mode**: Have books read aloud in your cloned voice
- **Personal Library**: Build your book shelf with both bundled classics and imported books
- **Reading History**: Track your reading time and progress
- **User Authentication**: Sign in with Email, Google, or Apple

## 📱 App Structure

### Main Tabs

- **Read**: Browse and discover books with filtering by age group and genre
- **Shelf**: Your personal library with imported books and favorites
- **Record**: Create and manage your voice recordings
- **Me**: User profile, statistics, and settings

### Key Technologies

- SwiftUI for modern iOS UI
- Firebase (Authentication, Firestore, Storage)
- ElevenLabs API for voice cloning and TTS
- AVFoundation for audio recording and playback
- EPUBParser for reading EPUB format books

## 🚀 Getting Started

### Prerequisites

- Xcode 14.0 or later
- iOS 16.0+ deployment target
- Firebase account
- ElevenLabs API key

## 🏗️ Architecture

### Core Services

- `ElevenLabsService`: Voice cloning and text-to-speech API integration
- `StreamingAudioManager`: Handles streaming audio playback
- `BundledBooksService`: Manages pre-packaged classic books
- `FirebaseEPUBService`: Cloud storage for user books
- `UserStatsManager`: Tracks reading statistics

### Key Views

- `BookReaderView`: Main reading interface with book discovery
- `BookDetailsView`: Book details with audio playback
- `ShelfView`: Personal library management
- `VoiceRecorderView`: Voice recording and cloning
- `MeView`: User profile and settings

### Data Models

- `Book`: Book metadata and content structure
- `Chapter`: Individual book chapters
- `VoiceRecording`: User voice profiles
- `ReadingHistoryEntry`: Reading session tracking

## 📦 Bundled Books

All books are in the public domain.

## 🎨 Design System

## 🧪 Testing

- Test voice recording with 30-second sample script
- Verify Firebase authentication with all providers
- Check audio playback with streaming and downloaded audio
- Test EPUB parsing with bundled books

## 🚀 Future Enhancements

- [ ] Backend proxy for API key security
- [ ] Offline reading support
- [ ] Book annotations and highlights
- [ ] Social features (share quotes, recommendations)
- [ ] Multi-language support
- [ ] Premium subscription model
- [ ] Advanced reading statistics

## 📄 License

This project is for educational purposes. Bundled books are from Standard Ebooks and are in the public domain.

## 🙏 Acknowledgments

- [Standard Ebooks](https://standardebooks.org/) for high-quality public domain books
- [ElevenLabs](https://elevenlabs.io/) for voice cloning technology
- Firebase for backend services

## 📧 Support

For questions or issues, refer to the documentation files or check the app's Help & Support section.

---

**Version**: 1.0.0  
**Last Updated**: November 2025  
**Platform**: iOS 16.0+
