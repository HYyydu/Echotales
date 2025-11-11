#!/usr/bin/env python3
"""
Generate Cloud Books Catalog
============================

This script generates a cloud_books_catalog.json file from a directory of EPUB files.
It extracts metadata from EPUBs and creates a properly formatted catalog.

Usage:
    python3 generate_catalog.py --epubs-dir ./epubs --output cloud_books_catalog.json

Requirements:
    pip install ebooklib
"""

import argparse
import json
import os
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Optional

try:
    import ebooklib
    from ebooklib import epub
    EBOOKLIB_AVAILABLE = True
except ImportError:
    EBOOKLIB_AVAILABLE = False
    print("⚠️  Warning: ebooklib not installed. Install with: pip install ebooklib")
    print("   Continuing with basic metadata extraction...")


def get_file_size(filepath: Path) -> int:
    """Get file size in bytes"""
    return os.path.getsize(filepath)


def extract_epub_metadata(epub_path: Path) -> Dict[str, Optional[str]]:
    """
    Extract metadata from EPUB file.
    Returns dict with: title, author, language, description
    """
    metadata = {
        "title": None,
        "author": None,
        "language": None,
        "description": None,
    }
    
    if not EBOOKLIB_AVAILABLE:
        # Fallback: use filename
        metadata["title"] = epub_path.stem.replace("-", " ").replace("_", " ").title()
        return metadata
    
    try:
        book = epub.read_epub(str(epub_path))
        
        # Extract title
        title = book.get_metadata('DC', 'title')
        if title:
            metadata["title"] = title[0][0]
        
        # Extract author
        creator = book.get_metadata('DC', 'creator')
        if creator:
            metadata["author"] = creator[0][0]
        
        # Extract language
        language = book.get_metadata('DC', 'language')
        if language:
            metadata["language"] = language[0][0]
        
        # Extract description
        description = book.get_metadata('DC', 'description')
        if description:
            metadata["description"] = description[0][0]
            
    except Exception as e:
        print(f"⚠️  Could not extract metadata from {epub_path.name}: {e}")
        metadata["title"] = epub_path.stem.replace("-", " ").replace("_", " ").title()
    
    return metadata


def guess_genre(title: str, author: str, tags: List[str]) -> str:
    """Guess genre based on title, author, or tags"""
    title_lower = title.lower()
    author_lower = author.lower() if author else ""
    
    # Common patterns
    if any(word in title_lower for word in ["mystery", "detective", "murder", "crime"]):
        return "Mystery"
    if any(word in title_lower for word in ["fantasy", "wizard", "magic", "dragon"]):
        return "Fantasy"
    if any(word in title_lower for word in ["romance", "love", "heart"]):
        return "Romance"
    if any(word in title_lower for word in ["horror", "terror", "vampire", "zombie"]):
        return "Horror"
    if any(word in title_lower for word in ["science", "space", "robot", "future"]):
        return "Science Fiction"
    if "children" in " ".join(tags).lower() or "kid" in title_lower:
        return "Children's Literature"
    
    # Author-based
    if "dickens" in author_lower or "austen" in author_lower:
        return "Classic Literature"
    
    return "Fiction"


def guess_age_rating(title: str, genre: str, tags: List[str]) -> str:
    """Guess appropriate age rating"""
    title_lower = title.lower()
    genre_lower = genre.lower()
    tags_lower = " ".join(tags).lower()
    
    # Children indicators
    if any(word in title_lower for word in ["children", "kid", "little", "pooh", "curious george"]):
        return "Children"
    if "children" in tags_lower or "picture book" in tags_lower:
        return "Children"
    
    # Young adult indicators
    if any(word in title_lower for word in ["hardy boys", "nancy drew", "young"]):
        return "Young Adult"
    if "young adult" in tags_lower or "ya" in tags_lower:
        return "Young Adult"
    
    # Horror/mature content
    if genre_lower in ["horror", "gothic"]:
        return "Young Adult"
    
    return "Adult"


def generate_book_entry(epub_path: Path, firebase_path: str = "epubs", covers_dir: Optional[Path] = None) -> Dict:
    """Generate a book entry for the catalog"""
    
    # Extract metadata
    metadata = extract_epub_metadata(epub_path)
    
    # Generate ID from filename
    book_id = epub_path.stem.lower()
    
    # Get file size
    file_size = get_file_size(epub_path)
    
    # Generate tags based on metadata
    # Default tag for all cloud books is "Classic" (can be manually changed to "AI" if needed)
    tags = ["Classic"]
    
    # Guess genre and age
    title = metadata.get("title") or epub_path.stem.replace("-", " ").title()
    author = metadata.get("author") or "Unknown"
    genre = guess_genre(title, author, tags)
    age = guess_age_rating(title, genre, tags)
    
    # Check if local cover exists
    cover_image_url = None
    if covers_dir and covers_dir.exists():
        cover_file = covers_dir / f"{book_id}.png"
        if cover_file.exists():
            # Use relative path for bundled covers
            cover_image_url = f"BookCovers/{book_id}.png"
    
    # Build book entry
    book = {
        "id": book_id,
        "title": title,
        "author": author,
        "age": age,
        "genre": genre,
        "tags": tags,
        "description": metadata.get("description") or f"A {genre.lower()} book by {author}.",
        "storageUrl": f"{firebase_path}/{epub_path.name}",
        "coverImageUrl": cover_image_url,  # Local bundled cover path
        "fileSizeBytes": file_size,
        "isFeatured": False  # Mark featured books manually
    }
    
    return book


def create_collections(books: List[Dict]) -> List[Dict]:
    """Create collections based on genres and age groups"""
    
    # Group by genre
    genres = {}
    for book in books:
        genre = book["genre"]
        if genre not in genres:
            genres[genre] = []
        genres[genre].append(book["id"])
    
    # Group by age
    ages = {}
    for book in books:
        age = book["age"]
        if age not in ages:
            ages[age] = []
        ages[age].append(book["id"])
    
    collections = []
    sort_order = 0
    
    # Create "All Books" collection
    collections.append({
        "id": "all",
        "name": "All Books",
        "description": "Complete library collection",
        "sortOrder": sort_order,
        "coverImageUrl": None,
        "bookIds": [b["id"] for b in books]
    })
    sort_order += 1
    
    # Create age-based collections
    age_order = ["Children", "Young Adult", "Adult"]
    for age in age_order:
        if age in ages and ages[age]:
            collections.append({
                "id": age.lower().replace(" ", "-"),
                "name": f"{age} Books",
                "description": f"Books suitable for {age.lower()} readers",
                "sortOrder": sort_order,
                "coverImageUrl": None,
                "bookIds": ages[age]
            })
            sort_order += 1
    
    # Create genre-based collections
    for genre, book_ids in sorted(genres.items()):
        if len(book_ids) >= 2:  # Only create collection if at least 2 books
            collections.append({
                "id": genre.lower().replace(" ", "-").replace("'", ""),
                "name": genre,
                "description": f"{genre} books from our collection",
                "sortOrder": sort_order,
                "coverImageUrl": None,
                "bookIds": book_ids
            })
            sort_order += 1
    
    return collections


def generate_catalog(epubs_dir: Path, firebase_path: str = "epubs", covers_dir: Optional[Path] = None) -> Dict:
    """Generate complete catalog from EPUB directory"""
    
    print(f"📚 Scanning directory: {epubs_dir}")
    
    # Check for local covers
    if covers_dir and covers_dir.exists():
        cover_count = len(list(covers_dir.glob("*.png")))
        print(f"🖼️  Found {cover_count} local cover images in {covers_dir}")
    
    # Find all EPUB files
    epub_files = list(epubs_dir.glob("*.epub"))
    
    if not epub_files:
        print(f"❌ No EPUB files found in {epubs_dir}")
        return None
    
    print(f"📖 Found {len(epub_files)} EPUB files")
    print()
    
    # Generate book entries
    books = []
    for epub_file in sorted(epub_files):
        print(f"Processing: {epub_file.name}...")
        book = generate_book_entry(epub_file, firebase_path, covers_dir)
        books.append(book)
        print(f"  ✓ {book['title']} by {book['author']}")
        print(f"    Genre: {book['genre']}, Age: {book['age']}, Size: {book['fileSizeBytes']:,} bytes")
        if book['coverImageUrl']:
            print(f"    Cover: {book['coverImageUrl']}")
    
    print()
    print("📦 Generating collections...")
    
    # Create collections
    collections = create_collections(books)
    
    for collection in collections:
        print(f"  ✓ {collection['name']} ({len(collection['bookIds'])} books)")
    
    # Build catalog
    catalog = {
        "version": 1,
        "lastUpdated": datetime.now().strftime("%Y-%m-%d"),
        "collections": collections,
        "books": books
    }
    
    return catalog


def main():
    parser = argparse.ArgumentParser(
        description="Generate cloud books catalog from EPUB files"
    )
    parser.add_argument(
        "--epubs-dir",
        type=Path,
        default=Path("./Bundle Books"),
        help="Directory containing EPUB files (default: ./Bundle Books)"
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("./cloud_books_catalog.json"),
        help="Output catalog file (default: ./cloud_books_catalog.json)"
    )
    parser.add_argument(
        "--firebase-path",
        type=str,
        default="epubs",
        help="Firebase Storage path for EPUBs (default: epubs)"
    )
    parser.add_argument(
        "--covers-dir",
        type=Path,
        default=Path("./BookCovers"),
        help="Directory containing extracted cover images (default: ./BookCovers)"
    )
    parser.add_argument(
        "--pretty",
        action="store_true",
        help="Format JSON with indentation"
    )
    
    args = parser.parse_args()
    
    # Validate input directory
    if not args.epubs_dir.exists():
        print(f"❌ Error: Directory not found: {args.epubs_dir}")
        return 1
    
    # Generate catalog
    catalog = generate_catalog(args.epubs_dir, args.firebase_path, args.covers_dir)
    
    if not catalog:
        return 1
    
    # Save to file
    print()
    print(f"💾 Saving catalog to: {args.output}")
    
    with open(args.output, 'w', encoding='utf-8') as f:
        if args.pretty:
            json.dump(catalog, f, indent=2, ensure_ascii=False)
        else:
            json.dump(catalog, f, ensure_ascii=False)
    
    print()
    print("✅ Catalog generated successfully!")
    print()
    print(f"📊 Summary:")
    print(f"   Total books: {len(catalog['books'])}")
    print(f"   Collections: {len(catalog['collections'])}")
    print(f"   Output file: {args.output}")
    print(f"   File size: {os.path.getsize(args.output):,} bytes")
    print()
    print("🚀 Next steps:")
    print("   1. Review the generated catalog")
    print("   2. Update book metadata as needed (genres, ages, descriptions)")
    print("   3. Mark featured books (set isFeatured: true)")
    print("   4. Upload EPUBs to Firebase Storage")
    print("   5. Add catalog to your Xcode project")
    print()
    
    return 0


if __name__ == "__main__":
    exit(main())

