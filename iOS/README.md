# Echotales - iOS Version

A native iOS app that allows users to record their voice and listen to stories read in their own cloned voice using ElevenLabs API.

## Features

1. **Voice Recording**: Record audio samples to create a voice clone using AVAudioRecorder
2. **Story Reading**: Read books/stories using the cloned voice via ElevenLabs API

## Requirements

- iOS 17.0 or later
- Xcode 15.0 or later
- Swift 5.0 or later
- ElevenLabs API key (already configured)

## Setup Instructions

1. **Open the Project in Xcode**

   - Navigate to the `iOS` folder
   - Double-click on `AIReadingApp.xcodeproj` to open it in Xcode

2. **Configure Signing**

   - Select the project in the navigator
   - Go to "Signing & Capabilities"
   - Select your development team
   - Xcode will automatically manage your provisioning profile

3. **Build and Run**
   - Select a simulator or connected device
   - Press `Cmd + R` or click the Play button
   - The app will build and launch

## Project Structure

```
AIReadingApp/
├── App.swift                    # Main app entry point
├── ContentView.swift            # Main view with header and layout
├── VoiceRecorderView.swift      # Voice recording UI and logic
├── BookReaderView.swift         # Story reading UI and logic
├── AudioRecorderManager.swift   # AVAudioRecorder wrapper
├── ElevenLabsService.swift      # ElevenLabs API integration
├── Info.plist                   # App configuration and permissions
└── Assets.xcassets/            # App icons and assets
```

## API Configuration

The ElevenLabs API key is configured in `ElevenLabsService.swift`:

```swift
private let apiKey = "sk_551194fe1fc5de99b6aac494024b05147a82c0b958625315"
```

To change the API key, edit the `apiKey` property in `ElevenLabsService.swift`.

## Permissions

The app requires microphone permission to record voice. This is configured in `Info.plist`:

- `NSMicrophoneUsageDescription`: "We need access to your microphone to record your voice for voice cloning."

## How to Use

1. **Record Your Voice**

   - Tap "Start Recording"
   - Speak for at least 30 seconds (recommended)
   - Tap "Stop Recording"
   - Wait for voice cloning to complete
   - You'll see a voice ID when successful

2. **Read a Story**
   - After recording, the "Read Story" section will be enabled
   - Tap "🎧 Read Story in My Voice"
   - The app will generate audio using your cloned voice
   - The story will play automatically

## Architecture

- **SwiftUI**: Modern declarative UI framework
- **AVFoundation**: Audio recording and playback
- **URLSession**: Network requests to ElevenLabs API
- **Async/Await**: Modern concurrency for API calls

## Troubleshooting

### Build Errors

- Make sure you're using Xcode 15.0 or later
- Clean build folder: `Product > Clean Build Folder` (Shift + Cmd + K)
- Restart Xcode if issues persist

### Microphone Permission

- If microphone permission is denied, go to Settings > Privacy & Security > Microphone
- Enable microphone access for the app

### API Errors

- Check your internet connection
- Verify the API key is correct in `ElevenLabsService.swift`
- Check ElevenLabs account status and quotas

## Notes

- The app saves recordings temporarily in the app's document directory
- Generated audio is saved temporarily and cleaned up after playback
- Voice clones are stored on ElevenLabs servers, not locally

## License

MIT
