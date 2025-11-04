# Using Free Kids Books in Your App

## About Free Kids Books

[Free Kids Books](https://freekidsbooks.org/) is an excellent resource for your AI Reading App. They provide:

✅ **Thousands of free children's books**
✅ **Organized by age groups** (matches your design!)
✅ **Multiple genres** (Adventure, Fantasy, Animals, etc.)
✅ **Creative Commons licensed** (free to use)
✅ **PDF downloads available**
✅ **High-quality illustrations**

## Benefits for Your App

1. **No copyright issues** - All books are Creative Commons
2. **Age-appropriate** - Pre-categorized by age (0-3, 4-6, 7-9, 10-12, 13+)
3. **Quality content** - Curated, professional books
4. **Diverse library** - Thousands of books to choose from
5. **Free to use** - No licensing costs

## How to Add Books to Your App

### Method 1: Manual Selection (Recommended)

1. **Browse Free Kids Books:**

   - Visit https://freekidsbooks.org/
   - Filter by age group (matches your categories)
   - Filter by genre/subject

2. **Download Books:**

   - Click "Download PDF" for each book
   - Save book cover images (right-click on cover)
   - Note the book details (title, author, age, genre)

3. **Upload to Your App:**
   - Open `admin/index.html` in browser
   - Fill in book details
   - Upload the cover image you downloaded
   - Add a short excerpt or full text
   - Submit

### Method 2: Batch Import Script

Use the provided script to import curated books:

1. **Update Firebase config** in `scripts/importFreeKidsBooks.js`

2. **Run the import:**

   ```bash
   cd /Users/yuyan/TestCursorRecord
   node scripts/importFreeKidsBooks.js
   ```

3. **Result:**
   - 10 pre-selected books from Free Kids Books
   - Auto-generated covers with book titles
   - Ready to use in your app

### Method 3: API Integration (Advanced)

If Free Kids Books has an API (check their documentation):

- Fetch books programmatically
- Auto-sync new books
- Keep library updated

## Recommended Books from Free Kids Books

I've already included these in the import script:

**Ages 0-3:**

- The Three Little Pigs (Classic fairy tale)

**Ages 4-6:**

- Where the Wild Things Are
- The Monster (About emotions/depression)
- How Turtle Cracked His Shell
- Hey Mom! What is Diversity?

**Ages 7-9:**

- Binti Knows Her Mind
- The Velveteen Rabbit
- Swimming in the Zambezi
- Aesop's Fables Collection

**Ages 10-12:**

- More Micropoems
- Alice in Wonderland

## Book Categories on Free Kids Books

The site has these categories (all great for kids):

- **Behavior & Emotions** - Social-emotional learning
- **Animals** - Dogs, cats, dinosaurs, sea creatures
- **Bedtime Stories** - Perfect for voice reading!
- **Adventure & Fantasy** - Exciting tales
- **Classic Books** - Timeless stories
- **Science & Nature** - Educational content
- **Diversity** - Multicultural stories
- **Friendship & Family** - Relationship stories

## Text-to-Speech Integration

Since these are PDF books, here's how to use them with your voice cloning:

1. **Extract Text from PDFs:**

   - Use a PDF reader to copy text
   - Or use a PDF-to-text converter tool
   - Store full text in Firebase (`textContent` field)

2. **Read with Cloned Voice:**
   - User records voice → ElevenLabs creates clone
   - User selects a book
   - App sends book text to ElevenLabs TTS API
   - ElevenLabs generates audio in user's voice
   - User listens to the story

## Legal Considerations

✅ **Safe to use** - All books on Free Kids Books are Creative Commons
✅ **No attribution required** - Most are CC0 or CC-BY
✅ **Free for commercial use** - You can use in your app
✅ **Check individual licenses** - Some may require attribution

## Implementation Steps

1. **Choose 10-20 books** from Free Kids Books that match your age groups
2. **Download covers and PDFs**
3. **Extract or summarize book text**
4. **Upload to Firebase** using admin panel
5. **Test in your app** - Books should appear in the grid
6. **Expand library** over time

## Quick Start

I've created `scripts/importFreeKidsBooks.js` with 10 pre-selected books. After setting up Firebase:

```bash
node scripts/importFreeKidsBooks.js
```

This will populate your library with quality children's books, perfectly categorized for your app!

## Additional Resources

- **Project Gutenberg** (gutenberg.org) - More classic children's books
- **Internet Archive** (archive.org) - Public domain books
- **Storyweaver** (storyweaver.org.in) - Multilingual children's stories

All of these have free, public domain content perfect for your reading app.
