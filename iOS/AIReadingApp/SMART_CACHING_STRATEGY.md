# Smart Caching Strategy - Shelf vs Read Tab

## Overview

This document describes the intelligent caching strategy that differentiates between temporary (Read tab) and permanent (Shelf tab) book storage, eliminating redundant downloads while ensuring shelf books persist.

---

## The Problem

Previously, books were downloaded to temporary directories that iOS would clean up, causing:
- ❌ Missing EPUB files when extracting covers for shelf books
- ❌ "No such file or directory" errors
- ❌ Cover images failing to display on shelf
- ❌ Redundant downloads when switching between Read and Shelf tabs

---

## The Solution

### Two-Tier Storage System

#### **Tier 1: Temporary Storage (Read Tab)**
- **Location**: `/tmp/StreamingBooks/`
- **Purpose**: Stream books for immediate reading without commitment
- **Lifecycle**: Can be cleaned up by iOS when space is needed
- **Use Case**: Browsing books in Read tab before deciding to keep them

#### **Tier 2: Permanent Storage (Shelf Tab)**
- **Location**: `~/Documents/DownloadedBooks/`
- **Purpose**: Keep favorited books permanently available offline
- **Lifecycle**: Persists until user explicitly removes from shelf
- **Use Case**: Books added to "My Bookshelf" via heart/favorite button

---

## Implementation Details

### 1. Smart Cover Extraction (`FirebaseEPUBService.swift`)

The `extractCoverFromFirebaseEPUB()` function now follows a 3-step priority:

```swift
1. Check permanent storage (Documents)
   ↓ Not found?
2. Check streaming cache (Temp)
   ↓ Not found?
3. Download to temp for one-time extraction
```

**Benefits**:
- ✅ No "file not found" errors for shelf books
- ✅ Reuses existing downloads (no redundant downloads)
- ✅ Falls back gracefully for temporary books

### 2. Automatic Download on Favorite (`BookDetailsView.swift`)

When user taps the heart button to add a book to shelf:

```swift
1. Save book metadata to Firebase (userShelfBooks collection)
   ↓
2. Check if book is in streaming cache
   ↓ Yes?
3. Move from temp → permanent storage (no re-download!)
   ↓ No?
4. Download directly to permanent storage
```

**Benefits**:
- ✅ Instant permanence when favoriting
- ✅ Reuses streaming downloads (smart move operation)
- ✅ No extra bandwidth usage

### 3. Background Download for Existing Shelf Books (`ShelfView.swift`)

When shelf loads (app launch or pull-to-refresh):

```swift
1. Load shelf books from Firebase
   ↓
2. For each book:
   - Already permanently downloaded? → Skip
   - Is bundled resource? → Skip
   - In streaming cache? → Move to permanent
   - Otherwise → Download to permanent
```

**Benefits**:
- ✅ Ensures all shelf books are permanently cached
- ✅ Handles existing shelf entries from before this update
- ✅ Non-blocking background operation (doesn't freeze UI)

### 4. Automatic Cleanup on Remove from Shelf (`ShelfView.swift`)

When user removes a book from shelf:

```swift
1. Delete from Firebase (userShelfBooks collection)
   ↓
2. Remove from UI
   ↓
3. Delete permanent download (frees up space)
   ↓
4. Delete cached cover image
```

**Benefits**:
- ✅ Frees up storage space automatically
- ✅ Clean slate if user re-adds book later
- ✅ Maintains tidy storage footprint

---

## User Experience Flow

### Scenario 1: Read → Favorite
```
1. User browses "Read" tab → Book streams to temp storage
2. User loves the book → Taps heart button
3. Book moves from temp → permanent (no re-download!)
4. Book appears on "Shelf" tab with cover
5. Temp download cleaned up by iOS (space freed)
```

### Scenario 2: Direct Favorite from Read Tab
```
1. User sees book in "Read" tab → Taps heart
2. Book downloads to permanent storage
3. Book appears on "Shelf" tab immediately
4. Cover extracted from permanent EPUB
```

### Scenario 3: Existing Shelf Books (App Restart)
```
1. App launches → Shelf loads from Firebase
2. Check Alice in Wonderland:
   - Not in permanent storage
   - Found in streaming cache!
   - Move to permanent (background, no user action)
3. Cover extracted from permanent EPUB
4. Shelf displays correctly
```

### Scenario 4: Remove from Shelf
```
1. User enters "Select" mode on Shelf
2. Taps X to remove "Alice in Wonderland"
3. Book removed from Firebase
4. Permanent download deleted (space freed)
5. User can still stream it again from Read tab
```

---

## Technical Benefits

### No Redundant Downloads
- Streaming downloads are reused when favoriting
- Cover extraction checks all locations before downloading
- Multiple components share the same permanent storage

### Optimal Storage Usage
- Read tab: Minimal storage (temp, can be cleaned)
- Shelf tab: Controlled storage (only favorited books)
- Automatic cleanup when unfavoriting

### Resilient Error Handling
- Graceful fallback if temp files are cleaned up
- Background downloads don't block UI
- Failed downloads logged but don't crash

### Performance Optimization
- Cover extraction is instant for permanent books
- No re-parsing EPUBs that are already parsed
- Streaming cache checked before network requests

---

## Files Modified

### 1. `FirebaseEPUBService.swift`
- Added bookId parameter to `extractCoverFromFirebaseEPUB()`
- Added 3-tier check: permanent → streaming → download
- Added `extractBookIdFromStorageUrl()` helper

### 2. `BookDetailsView.swift`
- Added `downloadShelfBookPermanently()` function
- Automatic download when favoriting cloud books
- Smart move from streaming to permanent storage

### 3. `ShelfView.swift`
- Updated cover loading to handle bundled resources properly
- Added `ensureShelfBooksAreDownloaded()` background task
- Updated delete to clean up permanent downloads
- Fixed epubUrl reconstruction for missing URLs

---

## Storage Locations Summary

| Storage Type | Location | Persists? | Used By | Cleanup |
|--------------|----------|-----------|---------|---------|
| **Streaming Cache** | `/tmp/StreamingBooks/` | ❌ No (iOS cleans) | Read tab | Automatic by iOS |
| **Permanent Downloads** | `~/Documents/DownloadedBooks/` | ✅ Yes | Shelf tab | On unfavorite |
| **Extracted Covers** | `~/Library/Caches/BookCovers/` | ✅ Yes | Both tabs | On unfavorite |
| **Bundled Resources** | App Bundle | ✅ Yes | Both tabs | Never (built-in) |

---

## Testing Checklist

- [ ] Add book to shelf → Check permanent storage has EPUB
- [ ] Stream book, then favorite → Verify no re-download (check logs)
- [ ] Restart app → Shelf books still show covers
- [ ] Remove from shelf → Verify permanent download deleted
- [ ] Shelf book cover loads instantly (no download spinner)
- [ ] Read tab book can still stream after unfavoriting
- [ ] Background download doesn't freeze UI on shelf load

---

## Future Enhancements

### Storage Management UI
- Show storage usage per book on shelf
- Bulk delete permanent downloads
- Choose which shelf books to keep offline

### Smart Pre-caching
- Pre-download next chapter while reading
- Pre-cache covers for all shelf books on WiFi
- Predictive downloads based on reading patterns

### Sync Across Devices
- iCloud sync of shelf (already done via Firebase)
- Optionally sync permanent downloads via iCloud Drive
- Smart downloads: only on device with most storage

---

## Migration Notes

**For existing users with shelf books:**

The app will automatically handle migration on next shelf load:
1. Existing shelf entries are loaded from Firebase
2. `ensureShelfBooksAreDownloaded()` runs in background
3. Books are downloaded to permanent storage
4. Covers are extracted and cached
5. User sees properly rendered shelf (may take a moment for downloads)

**No user action required!** The migration is automatic and transparent.

