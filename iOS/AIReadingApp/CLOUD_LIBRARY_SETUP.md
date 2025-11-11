# Cloud Library Setup Guide

## 📚 Overview

This guide explains how to manage a large book catalog (100+ books) without bloating your iOS app size. The solution uses **cloud storage with on-demand downloads**.

### Benefits

✅ **Small App Size**: Only metadata (~50KB for 100 books) in app bundle  
✅ **Scalable**: Support unlimited books without app size impact  
✅ **On-Demand Downloads**: Users download only what they want to read  
✅ **Offline Access**: Downloaded books work offline  
✅ **User Control**: Users can delete books to manage storage  
✅ **Collections/Batches**: Organize books into browsable categories

---

## 🏗️ Architecture

### Three-Tier System

1. **App Bundle** (Lightweight)

   - `cloud_books_catalog.json` - Metadata for all books (~50KB)
   - 3-5 "featured" starter books (optional, for offline demo)
   - Cover images can be URLs or bundled assets

2. **Firebase Storage** (Cloud)

   - All EPUB files hosted in Firebase Storage
   - Path structure: `epubs/book-id.epub`
   - Download on-demand with progress tracking

3. **Local Storage** (Device)
   - Downloaded books cached in Documents directory
   - Path: `~/Documents/DownloadedBooks/`
   - User can manage/delete to free space

---

## 📦 File Structure

```
AIReadingApp/
├── CloudBookService.swift         # Main service for cloud books
├── CloudLibraryView.swift         # UI for browsing/downloading
├── cloud_books_catalog.json       # Metadata catalog (lightweight)
└── Bundle Books/                  # Optional: Featured starter books
    ├── the-little-star.epub
    └── alice-wonderland.epub
```

---

## 🚀 Setup Instructions

### Step 1: Upload EPUBs to Firebase Storage

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login to Firebase
firebase login

# Upload books to Firebase Storage
# Option A: Using Firebase Console
# 1. Go to Firebase Console > Storage
# 2. Create folder: epubs/
# 3. Upload all EPUB files

# Option B: Using gsutil
gsutil -m cp *.epub gs://your-project-id.appspot.com/epubs/

# Option C: Script (recommended for 100+ books)
# See upload_books_script.sh below
```

#### Upload Script (`upload_books_script.sh`)

```bash
#!/bin/bash

# Configuration
PROJECT_ID="your-project-id"
BUCKET="gs://${PROJECT_ID}.appspot.com"
EPUBS_DIR="./your-epubs-folder"

echo "📤 Uploading EPUBs to Firebase Storage..."

# Upload all EPUBs
gsutil -m cp "${EPUBS_DIR}"/*.epub "${BUCKET}/epubs/"

echo "✅ Upload complete!"
echo "Files uploaded to: ${BUCKET}/epubs/"
```

### Step 2: Generate Catalog JSON

Create a script to generate `cloud_books_catalog.json` from your EPUB files:

```python
#!/usr/bin/env python3
"""
generate_catalog.py - Generate cloud books catalog
"""

import json
import os
from pathlib import Path

def get_file_size(filepath):
    """Get file size in bytes"""
    return os.path.getsize(filepath)

def generate_catalog(epubs_dir, output_file):
    """Generate catalog JSON from EPUB directory"""

    books = []

    for epub_file in Path(epubs_dir).glob("*.epub"):
        book_id = epub_file.stem  # filename without extension
        file_size = get_file_size(epub_file)

        # You'll need to extract metadata from EPUB or maintain a CSV
        # This is a simplified example
        book = {
            "id": book_id,
            "title": book_id.replace("-", " ").title(),
            "author": "Unknown",  # Extract from EPUB metadata
            "age": "Adult",
            "genre": "Fiction",
            "tags": [],
            "description": "",
            "storageUrl": f"epubs/{epub_file.name}",
            "coverImageUrl": None,  # Or upload covers separately
            "fileSizeBytes": file_size,
            "isFeatured": False
        }
        books.append(book)

    catalog = {
        "version": 1,
        "lastUpdated": "2025-11-10",
        "collections": [
            {
                "id": "all",
                "name": "All Books",
                "description": "Complete library",
                "sortOrder": 0,
                "coverImageUrl": None,
                "bookIds": [b["id"] for b in books]
            }
        ],
        "books": books
    }

    with open(output_file, 'w') as f:
        json.dump(catalog, f, indent=2)

    print(f"✅ Generated catalog with {len(books)} books")
    print(f"📄 Saved to: {output_file}")

if __name__ == "__main__":
    generate_catalog("./epubs", "cloud_books_catalog.json")
```

### Step 3: Add Catalog to Xcode

1. Drag `cloud_books_catalog.json` into Xcode project
2. Ensure "Target Membership" is checked
3. Verify it appears in "Copy Bundle Resources"

### Step 4: Configure Firebase Storage Rules

```javascript
// storage.rules
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Public read access to EPUBs
    match /epubs/{bookFile} {
      allow read: if true;  // Or add authentication
      allow write: if false; // Only admins can upload
    }

    // Public read access to covers
    match /covers/{coverFile} {
      allow read: if true;
      allow write: if false;
    }
  }
}
```

### Step 5: Add CloudLibraryView to Your App

```swift
// ContentView.swift or your main navigation
import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            ShelfView()
                .tabItem {
                    Label("My Shelf", systemImage: "books.vertical")
                }

            CloudLibraryView()  // ← Add this
                .tabItem {
                    Label("Cloud Library", systemImage: "cloud")
                }

            MeView()
                .tabItem {
                    Label("Me", systemImage: "person")
                }
        }
    }
}
```

---

## 📊 Organizing Books into Collections

### Creating Collections

Collections help users browse books in organized groups (like "changing batches"):

```json
{
  "collections": [
    {
      "id": "starter-pack",
      "name": "Starter Pack",
      "description": "Perfect books to begin with",
      "sortOrder": 0,
      "bookIds": ["book1", "book2", "book3"]
    },
    {
      "id": "classics",
      "name": "Classic Literature",
      "description": "Timeless masterpieces",
      "sortOrder": 1,
      "bookIds": ["pride-prejudice", "frankenstein"]
    },
    {
      "id": "mystery",
      "name": "Mystery & Thriller",
      "description": "Page-turners and whodunits",
      "sortOrder": 2,
      "bookIds": ["sherlock", "hardy-boys"]
    }
  ]
}
```

### Collection Strategies

**Option 1: Genre-Based**

- Classic Literature
- Mystery & Thriller
- Fantasy & Sci-Fi
- Children's Books

**Option 2: Reading Level**

- Ages 5-8
- Ages 9-12
- Young Adult
- Adult

**Option 3: Curated Sets**

- Starter Pack (5 books)
- Book Club Picks
- Summer Reading List
- Award Winners

**Option 4: Time-Based Batches**

- January Selection
- February Selection
- etc.

---

## 💾 Storage Management

### App Size Impact

| Component                   | Size           | Count | Total       |
| --------------------------- | -------------- | ----- | ----------- |
| Catalog JSON                | 500 bytes/book | 100   | ~50 KB      |
| Cover thumbnails (optional) | 10 KB/cover    | 100   | ~1 MB       |
| Featured books (optional)   | 300 KB/book    | 5     | ~1.5 MB     |
| **Total App Bundle**        |                |       | **~2.5 MB** |

Compare to bundling all books: **~30-50 MB** ❌

### User Device Storage

- Books stored in: `Documents/DownloadedBooks/`
- User can manage via "Storage Manager" UI
- Average book: 200-500 KB
- 20 downloaded books: ~10 MB

---

## 🔄 Update Strategy

### Adding New Books

1. **Upload EPUB** to Firebase Storage
2. **Update catalog JSON**:
   ```json
   {
     "id": "new-book-id",
     "title": "New Book Title",
     ...
     "storageUrl": "epubs/new-book.epub"
   }
   ```
3. **Release app update** with new catalog
4. Or: **Fetch catalog from server** (see Remote Catalog below)

### Remote Catalog (Advanced)

Instead of bundling catalog in app, fetch from server:

```swift
class CloudBookService {
    func fetchRemoteCatalog() async throws -> CloudBookCatalog {
        let url = URL(string: "https://your-api.com/books/catalog.json")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(CloudBookCatalog.self, from: data)
    }
}
```

Benefits:

- ✅ Add books without app updates
- ✅ A/B test different collections
- ✅ Personalized recommendations
- ⚠️ Requires internet to browse (cache for offline)

---

## 🎨 Cover Images

### Option 1: Bundle Covers (Recommended for Small Catalogs)

- Store covers in Assets.xcassets
- Size: ~10 KB each
- 100 covers = ~1 MB

```swift
Image("book-cover-\(book.id)")
    .resizable()
```

### Option 2: Remote Covers (Recommended for Large Catalogs)

- Upload covers to Firebase Storage or CDN
- Use `AsyncImage` in SwiftUI

```swift
AsyncImage(url: URL(string: book.coverImageUrl))
```

### Option 3: Extract from EPUB

- EPUBs contain cover images
- Extract and cache on first download
- Already implemented in `EPUBParser`

---

## 📱 User Experience Flow

### First Launch

1. App loads with catalog (instant)
2. Shows "Featured" collection (3-5 bundled books)
3. User can read featured books immediately

### Browsing Library

1. User opens "Cloud Library" tab
2. Sees collections: "Classics", "Mystery", etc.
3. Scrolls horizontally through books
4. Each book shows: cover, title, author, file size, download status

### Downloading

1. User taps "Download" button
2. Progress bar shows download (with cancel option)
3. After download completes, button changes to "Read"
4. Book available offline

### Reading

1. User taps "Read"
2. Book opens in reader (your existing BookReaderView)
3. No internet required

### Storage Management

1. User opens "Storage Manager"
2. Sees list of downloaded books
3. Swipe to delete books
4. Frees up device storage

---

## 🔧 Advanced Features

### 1. Smart Preloading

Download books users are likely to read:

```swift
class CloudBookService {
    func preloadRecommendedBooks(_ bookIds: [String]) async {
        for bookId in bookIds {
            // Download in background, low priority
            Task(priority: .background) {
                try? await downloadBook(bookId)
            }
        }
    }
}
```

### 2. Auto-Delete Old Books

```swift
func deleteOldBooks(keepRecent: Int = 5) {
    let sortedBooks = downloadedBooks.sorted { $0.lastReadDate > $1.lastReadDate }
    let toDelete = sortedBooks.dropFirst(keepRecent)

    for book in toDelete {
        try? deleteDownloadedBook(bookId: book.id)
    }
}
```

### 3. Offline Mode

```swift
var isOfflineMode: Bool {
    // Check network reachability
    // Show only downloaded books when offline
}
```

### 4. Search Across All Books

```swift
func searchBooks(query: String) -> [CloudBookMetadata] {
    catalog.books.filter {
        $0.title.localizedCaseInsensitiveContains(query) ||
        $0.author.localizedCaseInsensitiveContains(query)
    }
}
```

---

## 📈 Scaling to 1000+ Books

For very large catalogs:

1. **Paginated Catalog**: Load collections in chunks
2. **Search-First UI**: Don't show all books, require search
3. **Lazy Loading**: Load book details on demand
4. **CDN**: Use CloudFront/Cloudflare for faster downloads
5. **Compression**: Compress EPUBs (they're already ZIP files)

---

## ⚡ Performance Tips

### Catalog Loading

- ✅ Cache parsed catalog in memory
- ✅ Use Codable for fast JSON parsing
- ✅ Load asynchronously

### Downloads

- ✅ Use background URLSession for downloads
- ✅ Resume downloads if interrupted
- ✅ Limit concurrent downloads (max 3)

### Storage

- ✅ Store books in Documents (backed up to iCloud)
- ✅ Or use Application Support (not backed up)
- ✅ Implement storage limits

---

## 🐛 Troubleshooting

### Books Won't Download

Check Firebase Storage rules:

```bash
firebase deploy --only storage
```

### Catalog Not Loading

Verify file is in bundle:

```bash
# In Xcode, Build Phases > Copy Bundle Resources
# Ensure cloud_books_catalog.json is listed
```

### Storage URL Not Found

Format should be:

- ✅ `epubs/book.epub` (relative path)
- ✅ `gs://project.appspot.com/epubs/book.epub` (full GS URL)
- ✅ `https://storage.googleapis.com/...` (download URL)

---

## 💡 Recommendations Summary

### For Your Use Case (100 Books)

I recommend:

1. **Catalog in App** (50 KB)

   - Bundle `cloud_books_catalog.json`
   - Include all metadata
   - Update with app releases

2. **All EPUBs in Cloud**

   - Upload to Firebase Storage
   - ~20-50 MB total
   - Download on-demand

3. **3-5 Featured Books Bundled** (Optional)

   - Small starter set (1-2 MB)
   - Available offline immediately
   - Good for demo/first impression

4. **Organize into 5-10 Collections**

   - By genre, age, or theme
   - Users "change batch" by switching collections
   - Each collection: 10-20 books

5. **Smart Storage Management**
   - Auto-delete after 30 days
   - Keep recently read books
   - Show storage used in UI

### Expected Results

- 📱 App size: **~10 MB** (vs. 50 MB with all books)
- 📥 User downloads: **~5-10 MB** (10-20 books)
- 🚀 First launch: **Instant** (no parsing 100 EPUBs)
- 📚 Browsing: **Smooth** (metadata only, no downloads)
- 💾 Scalability: **Unlimited** books

---

## 📞 Questions?

Common questions:

**Q: Do users need internet to browse?**  
A: Yes, to download books. But catalog loads offline (bundled).

**Q: Can I add books without app updates?**  
A: Use remote catalog (fetch from server) instead of bundled JSON.

**Q: What about book security/DRM?**  
A: Public domain books don't need DRM. For protected content, use Firebase Auth + Storage Rules.

**Q: How to handle very large EPUBs (10+ MB)?**  
A: Show clear file size, allow background downloads, implement resume support.

---

## 🎯 Next Steps

1. ✅ Upload your EPUBs to Firebase Storage
2. ✅ Generate `cloud_books_catalog.json`
3. ✅ Add catalog to Xcode project
4. ✅ Test `CloudLibraryView` in your app
5. ✅ Organize books into collections
6. ✅ Deploy and monitor download analytics

Good luck with your library app! 🚀📚
