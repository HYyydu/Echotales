# 📚 Catalog Files Setup Guide

## Overview

Your app uses **two different catalog systems** for managing books:

### 1. **Bundled Books** (Offline/Local Books)
- **File**: `bundled_books_catalog.json` (root directory)
- **Purpose**: Metadata for EPUB files bundled with the app
- **Books Source**: EPUB files in `Bundle Books/` directory
- **Service**: `BundledBooksService.swift`
- **Category Filter**: Shows as "Classics" in the app

### 2. **Cloud Books** (Downloadable Books)
- **File**: `cloud_books_catalog.json` (root directory)
- **Purpose**: Metadata for books stored in Firebase Storage
- **Books Source**: Firebase Storage
- **Service**: `CloudBookService.swift`
- **View**: `CloudLibraryView.swift`

---

## File Structure

```
AIReadingApp/
├── bundled_books_catalog.json ✅ (for offline books)
├── cloud_books_catalog.json ✅ (for cloud books)
└── Bundle Books/
    ├── alice-wonderland.epub
    ├── frankenstein.epub
    ├── sherlock-holmes.epub
    └── ... (all EPUB files)
```

---

## Why You See "0 Books Found"

The most common issue is that **the catalog file isn't included in Xcode's build**.

### ✅ How to Fix in Xcode:

1. **Open your project in Xcode**
2. **Click on your project name** in the Project Navigator (left sidebar)
3. **Select your app target** (e.g., "AIReadingApp")
4. **Go to "Build Phases" tab**
5. **Expand "Copy Bundle Resources"**
6. **Check if `bundled_books_catalog.json` is listed**
   - ✅ If YES → The catalog is included
   - ❌ If NO → Click the **"+"** button and add it

7. **Also verify all EPUB files are listed** (alice-wonderland.epub, frankenstein.epub, etc.)

### Alternative Quick Check:

In Xcode's Project Navigator:
- Find `bundled_books_catalog.json`
- Click on it
- Look at the **"Target Membership"** section in the File Inspector (right sidebar)
- Make sure your app target is **checked ✓**

---

## Category Buttons in the App

The "Read" tab shows three category buttons:

| Button | What It Shows |
|--------|---------------|
| **All** | All books (bundled + Firebase) |
| **AI** | Books with "AI" tag (like "The Little Star") |
| **Classics** | Books from `bundled_books_catalog.json` |

---

## Debugging Tips

### Check Console Logs

When you run the app, look for these log messages:

**✅ Success:**
```
✅ Loaded 13 bundled books
📚 Total books available: 13 (Firebase: 0, Bundled: 13)
```

**❌ Problem:**
```
❌ CATALOG DEBUG: bundled_books_catalog.json not found in bundle
```

If you see the error, the catalog file isn't in the app bundle.

### Manual Test

Add this to `BookReaderView.swift` in the `loadBooks()` function:

```swift
private func loadBooks() {
    Task {
        // Test if catalog exists
        if let url = Bundle.main.url(forResource: "bundled_books_catalog", withExtension: "json") {
            print("✅ Catalog found at: \(url)")
        } else {
            print("❌ Catalog NOT found in bundle!")
        }
        
        // ... rest of function
    }
}
```

---

## Which Catalog to Edit?

### For Offline Books (Bundled with App):
**Edit**: `bundled_books_catalog.json` (root directory)

Example: Add a new book
```json
{
  "id": "new-book-id",
  "title": "New Book Title",
  "author": "Author Name",
  "age": "Children",
  "genre": "Fantasy",
  "tags": ["Classic", "Fantasy"],
  "epubFileName": "new-book.epub",
  "coverImageName": "new-book-cover",
  "description": "Book description"
}
```

### For Cloud Books (Firebase Storage):
**Edit**: `cloud_books_catalog.json` (root directory)

Example: Add a new cloud book
```json
{
  "id": "new-cloud-book",
  "title": "Cloud Book Title",
  "author": "Author Name",
  "age": "Adult",
  "genre": "Romance",
  "tags": ["Romance", "Modern"],
  "description": "Book description",
  "storageUrl": "epubs/new-cloud-book.epub",
  "coverImageUrl": "https://your-cdn.com/covers/new-book.jpg",
  "fileSizeBytes": 512000,
  "isFeatured": false
}
```

---

## Quick Troubleshooting Checklist

- [ ] `bundled_books_catalog.json` is in the root directory
- [ ] File is added to Xcode project
- [ ] Target Membership is checked for your app
- [ ] File appears in "Copy Bundle Resources" build phase
- [ ] All EPUB files are also in "Copy Bundle Resources"
- [ ] Firebase is configured (for cloud books)
- [ ] App has been cleaned and rebuilt (Product → Clean Build Folder)

---

## Summary

**Use These Files:**
1. ✅ `bundled_books_catalog.json` (root) → For offline books
2. ✅ `cloud_books_catalog.json` (root) → For cloud books

**Don't Use:**
- ❌ Any duplicate `bundled_books_catalog.json` in subdirectories

The key is making sure Xcode includes the catalog in your app bundle!

