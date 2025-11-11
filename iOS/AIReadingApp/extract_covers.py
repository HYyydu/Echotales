#!/usr/bin/env python3
"""
Extract Book Covers from EPUBs
===============================

This script extracts cover images from all EPUB files and saves them
as PNG files that can be bundled in your iOS app for offline display.

Usage:
    python3 extract_covers.py --epubs-dir "./Bundle Books" --output-dir "./BookCovers"

Requirements:
    pip install ebooklib Pillow
"""

import argparse
import os
import shutil
from pathlib import Path
from PIL import Image
import io

try:
    import ebooklib
    from ebooklib import epub
    EBOOKLIB_AVAILABLE = True
except ImportError:
    EBOOKLIB_AVAILABLE = False
    print("❌ Error: ebooklib not installed")
    print("   Install with: pip install ebooklib Pillow")
    exit(1)


def extract_cover_from_epub(epub_path: Path) -> bytes:
    """
    Extract cover image from EPUB file.
    Returns image data as bytes, or None if not found.
    """
    try:
        book = epub.read_epub(str(epub_path))
        
        # Method 1: Try to get cover image directly
        cover_image = None
        for item in book.get_items():
            if item.get_type() == ebooklib.ITEM_COVER:
                cover_image = item.get_content()
                break
        
        if cover_image:
            return cover_image
        
        # Method 2: Look for cover in metadata
        cover_meta = book.get_metadata('OPF', 'cover')
        if cover_meta:
            cover_id = cover_meta[0][1].get('content', '')
            for item in book.get_items():
                if item.get_id() == cover_id:
                    cover_image = item.get_content()
                    break
        
        if cover_image:
            return cover_image
        
        # Method 3: Look for common cover filenames
        cover_names = ['cover.jpg', 'cover.jpeg', 'cover.png', 'cover.gif',
                      'Cover.jpg', 'Cover.png', 'COVER.JPG', 'COVER.PNG']
        
        for item in book.get_items():
            if item.get_type() == ebooklib.ITEM_IMAGE:
                # Check if filename contains 'cover'
                if any(name in item.get_name() for name in cover_names):
                    cover_image = item.get_content()
                    break
                # Check if 'cover' is in the path
                if 'cover' in item.get_name().lower():
                    cover_image = item.get_content()
                    break
        
        if cover_image:
            return cover_image
        
        # Method 4: Use first image if nothing else found
        for item in book.get_items():
            if item.get_type() == ebooklib.ITEM_IMAGE:
                cover_image = item.get_content()
                break
        
        return cover_image
        
    except Exception as e:
        print(f"   ⚠️  Error extracting cover: {e}")
        return None


def resize_and_optimize_cover(image_data: bytes, max_width: int = 300, max_height: int = 450) -> bytes:
    """
    Resize and optimize cover image for mobile display.
    Maintains aspect ratio while fitting within max dimensions.
    """
    try:
        # Open image
        img = Image.open(io.BytesIO(image_data))
        
        # Convert to RGB if necessary (for PNG with transparency)
        if img.mode in ('RGBA', 'LA', 'P'):
            background = Image.new('RGB', img.size, (255, 255, 255))
            if img.mode == 'P':
                img = img.convert('RGBA')
            background.paste(img, mask=img.split()[-1] if img.mode == 'RGBA' else None)
            img = background
        
        # Calculate new size maintaining aspect ratio
        img.thumbnail((max_width, max_height), Image.Resampling.LANCZOS)
        
        # Save as PNG
        output = io.BytesIO()
        img.save(output, format='PNG', optimize=True)
        return output.getvalue()
        
    except Exception as e:
        print(f"   ⚠️  Error resizing image: {e}")
        return image_data


def create_placeholder_cover(book_id: str, title: str, author: str, width: int = 300, height: int = 450) -> bytes:
    """
    Create a placeholder cover image with gradient and text.
    """
    try:
        from PIL import ImageDraw, ImageFont
        
        # Create gradient background
        img = Image.new('RGB', (width, height))
        draw = ImageDraw.Draw(img)
        
        # Choose color based on book_id hash
        colors = [
            [(139, 92, 246), (124, 58, 237)],  # Purple
            [(236, 72, 153), (219, 39, 119)],  # Pink
            [(16, 185, 129), (5, 150, 105)],   # Green
            [(245, 158, 11), (217, 119, 6)],   # Orange
            [(59, 130, 246), (37, 99, 235)],   # Blue
            [(239, 68, 68), (220, 38, 38)],    # Red
        ]
        
        color_pair = colors[abs(hash(book_id)) % len(colors)]
        
        # Draw gradient
        for y in range(height):
            ratio = y / height
            r = int(color_pair[0][0] + (color_pair[1][0] - color_pair[0][0]) * ratio)
            g = int(color_pair[0][1] + (color_pair[1][1] - color_pair[0][1]) * ratio)
            b = int(color_pair[0][2] + (color_pair[1][2] - color_pair[0][2]) * ratio)
            draw.line([(0, y), (width, y)], fill=(r, g, b))
        
        # Add book icon and text
        # Try to load a system font
        try:
            title_font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 24)
            author_font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 16)
        except:
            title_font = ImageFont.load_default()
            author_font = ImageFont.load_default()
        
        # Draw title (centered, with word wrap)
        title_lines = []
        words = title.split()
        current_line = ""
        for word in words:
            test_line = current_line + " " + word if current_line else word
            bbox = draw.textbbox((0, 0), test_line, font=title_font)
            if bbox[2] - bbox[0] <= width - 40:
                current_line = test_line
            else:
                if current_line:
                    title_lines.append(current_line)
                current_line = word
        if current_line:
            title_lines.append(current_line)
        
        # Limit to 3 lines
        title_lines = title_lines[:3]
        
        # Draw title
        y_offset = height // 2 - (len(title_lines) * 30) // 2
        for line in title_lines:
            bbox = draw.textbbox((0, 0), line, font=title_font)
            text_width = bbox[2] - bbox[0]
            x = (width - text_width) // 2
            draw.text((x, y_offset), line, fill=(255, 255, 255), font=title_font)
            y_offset += 35
        
        # Draw author
        if author and author != "Unknown":
            bbox = draw.textbbox((0, 0), author, font=author_font)
            text_width = bbox[2] - bbox[0]
            x = (width - text_width) // 2
            draw.text((x, y_offset + 20), author, fill=(255, 255, 255, 200), font=author_font)
        
        # Save as PNG
        output = io.BytesIO()
        img.save(output, format='PNG', optimize=True)
        return output.getvalue()
        
    except Exception as e:
        print(f"   ⚠️  Error creating placeholder: {e}")
        # Return a simple colored rectangle as fallback
        img = Image.new('RGB', (width, height), (100, 100, 150))
        output = io.BytesIO()
        img.save(output, format='PNG')
        return output.getvalue()


def extract_all_covers(epubs_dir: Path, output_dir: Path, create_placeholders: bool = True):
    """
    Extract covers from all EPUB files and save to output directory.
    """
    print(f"📚 Scanning EPUBs in: {epubs_dir}")
    print(f"💾 Output directory: {output_dir}")
    print()
    
    # Create output directory if it doesn't exist
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # Find all EPUB files
    epub_files = list(epubs_dir.glob("*.epub"))
    
    if not epub_files:
        print(f"❌ No EPUB files found in {epubs_dir}")
        return
    
    print(f"📖 Found {len(epub_files)} EPUB files")
    print()
    
    # Process each EPUB
    extracted_count = 0
    placeholder_count = 0
    
    for epub_file in sorted(epub_files):
        # Generate book ID from filename
        book_id = epub_file.stem.lower()
        output_file = output_dir / f"{book_id}.png"
        
        print(f"Processing: {epub_file.name}")
        
        # Skip if already exists
        if output_file.exists():
            print(f"  ⏭️  Cover already exists, skipping")
            continue
        
        # Extract cover
        cover_data = extract_cover_from_epub(epub_file)
        
        if cover_data:
            # Resize and optimize
            optimized_cover = resize_and_optimize_cover(cover_data)
            
            # Save to file
            with open(output_file, 'wb') as f:
                f.write(optimized_cover)
            
            # Get file size
            file_size = os.path.getsize(output_file)
            print(f"  ✅ Extracted cover ({file_size:,} bytes)")
            extracted_count += 1
            
        elif create_placeholders:
            # Create placeholder cover
            try:
                import ebooklib
                from ebooklib import epub
                book = epub.read_epub(str(epub_file))
                
                # Get title and author
                title_meta = book.get_metadata('DC', 'title')
                title = title_meta[0][0] if title_meta else epub_file.stem.replace("-", " ").title()
                
                author_meta = book.get_metadata('DC', 'creator')
                author = author_meta[0][0] if author_meta else "Unknown"
                
                placeholder_data = create_placeholder_cover(book_id, title, author)
                
                with open(output_file, 'wb') as f:
                    f.write(placeholder_data)
                
                file_size = os.path.getsize(output_file)
                print(f"  🎨 Created placeholder cover ({file_size:,} bytes)")
                placeholder_count += 1
                
            except Exception as e:
                print(f"  ❌ Failed to create placeholder: {e}")
        else:
            print(f"  ⚠️  No cover found")
    
    print()
    print("=" * 60)
    print(f"✅ Processing complete!")
    print()
    print(f"📊 Summary:")
    print(f"   Total EPUBs processed: {len(epub_files)}")
    print(f"   Covers extracted: {extracted_count}")
    print(f"   Placeholders created: {placeholder_count}")
    print(f"   Output directory: {output_dir}")
    print()
    print("🚀 Next steps:")
    print("   1. Review the generated covers")
    print("   2. Add the BookCovers folder to your Xcode project")
    print("   3. Check 'Copy items if needed' and add to target")
    print("   4. Update CloudBookMetadata to use local cover paths")
    print()


def main():
    parser = argparse.ArgumentParser(
        description="Extract cover images from EPUB files for iOS app bundling"
    )
    parser.add_argument(
        "--epubs-dir",
        type=Path,
        default=Path("./Bundle Books"),
        help="Directory containing EPUB files (default: ./Bundle Books)"
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("./BookCovers"),
        help="Output directory for cover images (default: ./BookCovers)"
    )
    parser.add_argument(
        "--no-placeholders",
        action="store_true",
        help="Don't create placeholder covers for books without covers"
    )
    
    args = parser.parse_args()
    
    # Validate input directory
    if not args.epubs_dir.exists():
        print(f"❌ Error: Directory not found: {args.epubs_dir}")
        return 1
    
    # Extract covers
    extract_all_covers(args.epubs_dir, args.output_dir, create_placeholders=not args.no_placeholders)
    
    return 0


if __name__ == "__main__":
    exit(main())

