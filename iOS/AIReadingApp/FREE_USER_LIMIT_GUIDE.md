# Free User 30-Minute Monthly Limit Implementation Guide

## Overview

This guide explains how the 30-minute monthly limit for free users is implemented in the AI Reading App. Free users get 30 minutes of audio listening time per month, which automatically resets every month.

## Architecture

### 1. Membership System

The app has three membership types:

- **Free**: 30 minutes per month (recurring, resets monthly)
- **Free Trial**: 30 minutes one-time offer (for new users)
- **Premium**: Unlimited audio time (paid subscription)

### 2. Key Components

#### MembershipManager.swift

- Manages user membership status and usage tracking
- Handles monthly usage reset for free users
- Tracks time spent listening to audio
- Checks if user can use audio features

#### StreamingAudioManager.swift

- Handles audio playback
- Tracks playback time in real-time
- Reports usage to MembershipManager every 10 seconds
- Stops tracking when playback is paused or stopped

#### BookDetailsView.swift (AudioPlayerView)

- Checks membership status before starting playback
- Shows usage limit alert if limit is reached
- Blocks playback for users who exceeded their limit

#### MeView.swift

- Displays remaining time for free users
- Shows a usage banner with:
  - Minutes used vs. total minutes
  - Visual progress bar
  - Reset date
  - Upgrade to Premium button

## How It Works

### Monthly Reset Flow

```
1. User signs up → Gets free membership (30 min/month)
2. Membership document created in Firestore:
   - type: "free"
   - usedTimeInSeconds: 0
   - monthlyUsageResetDate: [1 month from now]
   - isActive: true

3. Every time user opens app:
   - Check if current date > monthlyUsageResetDate
   - If yes: Reset usedTimeInSeconds to 0
   - Update monthlyUsageResetDate to next month

4. Monthly cycle repeats automatically
```

### Usage Tracking Flow

```
1. User clicks Play on a book
   ↓
2. AudioPlayerView checks: membershipManager.canUseFeature()
   - If NO → Show "Usage Limit Reached" alert
   - If YES → Continue to step 3
   ↓
3. StreamingAudioManager starts playing audio
   ↓
4. Timer starts (tracks every 10 seconds)
   ↓
5. Every 10 seconds:
   - Calculate elapsed time since last check
   - Call membershipManager.trackUsageTime(seconds: elapsed)
   - Save to Firestore
   ↓
6. When user pauses/stops:
   - Save remaining time immediately
   - Stop timer
```

### Database Structure (Firestore)

```
users/{userId}/
  └── membership/
      └── status/
          ├── type: "free" | "free_trial" | "premium"
          ├── usedTimeInSeconds: number (e.g., 900 for 15 minutes)
          ├── monthlyUsageResetDate: timestamp
          ├── startDate: timestamp
          ├── endDate: timestamp (for premium/trial)
          └── isActive: boolean
```

## Key Features

### 1. Automatic Monthly Reset

```swift
// In MembershipManager.swift
func checkAndResetMonthlyUsage() async {
    guard var status = membershipStatus else { return }

    // Only reset for free users
    guard status.type == .free, status.needsMonthlyReset else {
        return
    }

    // Reset usage and update reset date
    status.usedTimeInSeconds = 0
    status.monthlyUsageResetDate = Calendar.current.date(
        byAdding: .month,
        value: 1,
        to: Date()
    )

    // Save to Firestore
    try await saveMembershipStatus(status: status, userId: userId)
}
```

### 2. Real-time Usage Tracking

```swift
// In StreamingAudioManager.swift
private func startUsageTracking() {
    playbackStartTime = Date()

    usageTrackingTimer = Timer.scheduledTimer(
        withTimeInterval: 10.0,
        repeats: true
    ) { [weak self] _ in
        Task { @MainActor [weak self] in
            await self?.trackCurrentPlaybackTime()
        }
    }
}

private func trackCurrentPlaybackTime() async {
    let elapsedTime = Date().timeIntervalSince(playbackStartTime)
    await membershipManager.trackUsageTime(seconds: elapsedTime)
    playbackStartTime = Date() // Reset for next interval
}
```

### 3. Usage Check Before Playback

```swift
// In BookDetailsView.swift (AudioPlayerView)
private func generateAndPlayAudio() {
    Task { @MainActor in
        await membershipManager.loadMembershipStatus()

        guard membershipManager.canUseFeature() else {
            showUsageLimitAlert = true
            return
        }

        // Start playback...
    }
}
```

### 4. UI Display

```swift
// In MeView.swift
// Shows usage banner for free users
FreeUsageBanner(
    usedMinutes: status.usedMinutes,
    totalMinutes: 30,
    remainingMinutes: status.remainingFreeMinutes,
    resetDate: status.monthlyUsageResetDate,
    isTrial: status.type == .freeTrial,
    onUpgrade: { showMembership = true }
)
```

## User Experience

### For Free Users:

1. **First time**: Get 30 minutes of free audio per month
2. **Using audio**: See real-time progress bar showing usage
3. **Reaching limit**: Get alert when all 30 minutes are used
4. **Monthly reset**: Automatically get 30 new minutes next month
5. **Upgrade option**: Can upgrade to Premium anytime for unlimited access

### Visual Indicators:

- **Green progress bar**: 15+ minutes remaining
- **Orange progress bar**: 5-15 minutes remaining
- **Red progress bar**: Less than 5 minutes remaining

## Testing

### Test Cases:

1. **New User Signup**

   - Create account → Should get free membership with 30 min
   - Check Firestore: `type: "free"`, `usedTimeInSeconds: 0`

2. **Audio Playback Tracking**

   - Play audio for 5 minutes
   - Check Firestore: `usedTimeInSeconds` should be ~300

3. **Monthly Reset**

   - Manually set `monthlyUsageResetDate` to yesterday
   - Open app → Should reset to 0 and set new reset date

4. **Limit Reached**

   - Set `usedTimeInSeconds` to 1800 (30 minutes)
   - Try to play audio → Should show limit alert

5. **Premium User**
   - Upgrade to premium
   - Play audio for hours → No limits

## Firestore Security Rules

```javascript
// In firestore.rules
match /users/{userId}/membership/{document=**} {
  allow read: if isOwner(userId);
  allow write: if isOwner(userId);
}

function isOwner(userId) {
  return request.auth != null && request.auth.uid == userId;
}
```

## Troubleshooting

### Issue: Usage not tracking

**Solution**: Check if `membershipManager` is set on `streamingManager`:

```swift
streamingManager.setMembershipManager(membershipManager)
```

### Issue: Monthly reset not happening

**Solution**: Ensure `checkAndResetMonthlyUsage()` is called:

- In `MembershipManager.init()`
- In `loadMembershipStatus()`
- When app opens

### Issue: Timer not stopping

**Solution**: Verify `stopUsageTracking()` is called:

- In `pause()`
- In `stop()`
- In `onDisappear` of AudioPlayerView

## Future Enhancements

1. **Usage Analytics**

   - Track most listened books
   - Average daily usage
   - Peak usage times

2. **Smart Notifications**

   - Alert when 5 minutes remain
   - Notify when monthly usage resets

3. **Family Plans**

   - Shared monthly minutes
   - Multiple user accounts

4. **Rollover Minutes**
   - Unused minutes carry to next month
   - Max 60 minutes accumulation

## Summary

The 30-minute monthly limit system provides:

- ✅ Recurring monthly free usage (not one-time)
- ✅ Automatic reset every month
- ✅ Real-time usage tracking
- ✅ Clear visual indicators
- ✅ Seamless upgrade path to Premium
- ✅ Fair and transparent limit enforcement

Free users get genuine value while being encouraged to upgrade for unlimited access.
