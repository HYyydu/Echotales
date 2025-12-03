# Audio Cache Implementation

## Overview

This document explains the audio caching system implemented to optimize voice recording playback and reduce ElevenLabs API costs.

## Problem Statement

Previously, every time a user wanted to preview their voice recording, the app would:

1. Call the ElevenLabs API to generate the audio sample
2. Wait 2-3 seconds for generation
3. Incur API costs for every playback
4. Require internet connection every time

This resulted in:

- ❌ High API costs (charged per playback)
- ❌ Slow user experience (wait for generation)
- ❌ No offline support
- ❌ Poor UX with "Generating audio..." state

## Solution: Local Audio Caching

The new implementation caches the generated audio samples locally on the device.

### Key Benefits

1. **💰 Cost Savings** - Only one API call per voice recording (when created)
2. **⚡ Instant Playback** - No wait time for cached samples
3. **📶 Offline Support** - Preview recordings without internet
4. **🎯 Better UX** - No loading states after initial cache

### Architecture

```
┌─────────────────────────────────────────────────────┐
│                AudioCacheManager                    │
│  - Singleton for managing cached audio samples      │
│  - Stores files in Documents/VoiceSamples/          │
│  - Filename format: sample_{voiceId}.mp3            │
└─────────────────────────────────────────────────────┘
                        ▲
                        │
        ┌───────────────┼───────────────┐
        │               │               │
┌───────▼──────┐  ┌────▼─────┐  ┌──────▼──────┐
│NameRecording │  │ VoiceRec │  │MyRecordings │
│    View      │  │orderView │  │    View     │
│              │  │          │  │             │
│ Generates &  │  │ Uses     │  │ Uses cache  │
│ caches on    │  │ cache    │  │ first       │
│ save         │  │          │  │             │
└──────────────┘  └──────────┘  └─────────────┘
```

## Implementation Details

### 1. AudioCacheManager (`AudioCacheManager.swift`)

A singleton service that manages all audio caching operations:

**Key Methods:**

- `hasCachedAudio(for voiceId:)` - Check if audio is cached
- `cacheFileURL(for voiceId:)` - Get the file URL for a voice ID
- `getCachedAudio(for voiceId:)` - Retrieve cached audio data
- `cacheAudio(_:for:)` - Save audio data to cache
- `deleteCachedAudio(for voiceId:)` - Remove cached audio
- `generateAndCacheSample(for voiceId:)` - Generate and cache in one operation
- `clearAllCache()` - Clear all cached files
- `getCacheSize()` - Get total cache size

**Storage Location:**

```
Documents/VoiceSamples/sample_{voiceId}.mp3
```

**Sample Text:**
The cache manager uses a consistent sample text (Snow White story excerpt) that matches what users see during recording. This ensures consistency across the app.

### 2. NameRecordingView Updates

When a user saves a new voice recording:

```swift
// Step 1: Upload to ElevenLabs
let voiceId = try await ElevenLabsService.shared.createVoiceClone(...)

// Step 2: Generate and cache sample (NEW!)
_ = try await AudioCacheManager.shared.generateAndCacheSample(for: voiceId)

// Step 3: Save to Firestore
try await db.collection("voiceRecordings").addDocument(...)
```

This ensures the audio is cached immediately after creation, so subsequent playbacks are instant.

### 3. VoiceRecorderView Updates

When playing the finished recording:

```swift
// Check cache first
if AudioCacheManager.shared.hasCachedAudio(for: voiceId) {
    audioURL = AudioCacheManager.shared.cacheFileURL(for: voiceId)
} else {
    // Fallback: generate and cache
    audioURL = try await AudioCacheManager.shared.generateAndCacheSample(for: voiceId)
}

// Play from URL (no API call if cached!)
let player = try AVAudioPlayer(contentsOf: audioURL)
```

### 4. MyRecordingsView Updates

When playing a recording from the list:

```swift
// Try cached audio first (instant!)
if AudioCacheManager.shared.hasCachedAudio(for: recording.voiceId) {
    audioURL = AudioCacheManager.shared.cacheFileURL(for: recording.voiceId)
    isGeneratingAudio = false  // No loading state!
} else {
    // Fallback: generate and cache
    audioURL = try await AudioCacheManager.shared.generateAndCacheSample(for: recording.voiceId)
}
```

**Cleanup on Delete:**
When a recording is deleted, the cached audio is also removed:

```swift
AudioCacheManager.shared.deleteCachedAudio(for: recording.voiceId)
```

## Performance Metrics

### Before Caching

- First playback: ~2-3 seconds (API call)
- Subsequent playbacks: ~2-3 seconds (API call each time)
- API cost per playback: ~$0.002 - $0.01 (depending on plan)
- Offline support: ❌ No

### After Caching

- First playback: ~2-3 seconds (one-time API call + cache)
- Subsequent playbacks: **~0.1 seconds** (instant!)
- API cost per playback: ~$0.002 - $0.01 (only once)
- Offline support: ✅ Yes (after first cache)

### Cost Savings Example

If a user previews their voice 10 times:

- **Before:** 10 API calls = 10x cost
- **After:** 1 API call = 1x cost
- **Savings:** 90% cost reduction

## Storage Considerations

### File Sizes

- Average MP3 sample: ~150-250 KB
- 10 recordings: ~2-3 MB
- 50 recordings: ~10-15 MB

### Cache Management

The app currently does **not** implement automatic cache eviction. Cached files persist until:

1. Recording is manually deleted
2. App is uninstalled
3. User manually clears cache (if implemented in settings)

**Future Enhancement:** Consider implementing LRU (Least Recently Used) cache eviction if storage becomes a concern.

## Testing Checklist

- [x] New recording generates and caches sample audio
- [x] First playback uses cached audio (instant)
- [x] Subsequent playbacks use cached audio (no API calls)
- [x] Deleting recording removes cached audio
- [x] Handles missing cache gracefully (generates and caches)
- [x] Works offline after initial cache
- [x] No linting errors

## Monitoring & Debugging

All cache operations include detailed logging with emojis for easy debugging:

```
📂 Audio cache directory: /path/to/Documents/VoiceSamples
🔍 Cache check for voice_123: ✅ EXISTS
💾 Cached audio for voice_123 (234567 bytes)
✅ Using cached audio - instant playback!
🗑️ Deleted cached audio for voice_123
```

## Future Enhancements

1. **Cache Size Display** - Show total cache size in app settings
2. **Manual Cache Clear** - Allow users to clear cache from settings
3. **LRU Eviction** - Automatically remove oldest cached files when storage limit reached
4. **Preload Strategy** - Preload cached audio in background for even faster playback
5. **Cloud Sync** - Optionally sync cached audio via iCloud for cross-device support

## Related Files

- `AudioCacheManager.swift` - Core caching logic
- `NameRecordingView.swift` - Initial cache generation
- `VoiceRecorderView.swift` - Uses cache after recording
- `MyRecordingsView.swift` - Main playback with cache
- `ElevenLabsService.swift` - API integration

## Notes

- **Sample Text Consistency:** The sample text in `AudioCacheManager.sampleText` must match the text shown to users during recording in `VoiceRecorderView` and `MyRecordingsView`.
- **Thread Safety:** All file operations are performed on background threads, with UI updates on MainActor.
- **Error Handling:** If cached file is corrupted, the app automatically regenerates and re-caches.
