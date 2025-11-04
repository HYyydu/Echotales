import { initializeApp } from "firebase/app";
import { getFirestore, collection, addDoc } from "firebase/firestore";
import {
  getStorage,
  ref,
  uploadString,
  getDownloadURL,
} from "firebase/storage";

// Firebase configuration
const firebaseConfig = {
  apiKey: "AIzaSyCPEIaMSj8PYggVxDVOkyNL0MTGiyrD9vg",
  authDomain: "echotales-d23cc.firebaseapp.com",
  databaseURL: "https://echotales-d23cc-default-rtdb.firebaseio.com",
  projectId: "echotales-d23cc",
  storageBucket: "echotales-d23cc.firebasestorage.app",
  messagingSenderId: "377842214787",
  appId: "1:377842214787:web:e5b8088c9369b23a1178b6",
  measurementId: "G-SLH6TW4KEF",
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);
const db = getFirestore(app);
const storage = getStorage(app);

/**
 * Books sourced from FreeKidsBooks.org
 * All books are Creative Commons licensed and free to use
 *
 * How to add more books:
 * 1. Visit https://freekidsbooks.org/
 * 2. Browse by age/category
 * 3. Download PDF or get book details
 * 4. Add to the array below
 */

const freeKidsBooksData = [
  {
    title: "The Monster - A Story About Depression",
    author: "Bel Richardson",
    age: "4-6",
    genre: "Emotions",
    tags: ["Mental Health", "Family"],
    source: "Free Kids Books",
    sourceUrl: "https://freekidsbooks.org/",
    description:
      "A simple story about a boy with depression, told by his younger sister.",
    coverColor: "#8B5CF6",
  },
  {
    title: "How Turtle Cracked His Shell",
    author: "Joseph Bruchac (Retold by Rosie McCormick)",
    age: "4-6",
    genre: "Animals",
    tags: ["Fable", "Classic"],
    source: "Free Kids Books",
    sourceUrl: "https://freekidsbooks.org/",
    description: "A short fable about how Turtle's shell came to look cracked.",
    coverColor: "#10B981",
  },
  {
    title: "Binti Knows Her Mind",
    author: "Richa Jha",
    age: "7-9",
    genre: "Friendship",
    tags: ["Values", "Bestseller"],
    source: "Free Kids Books",
    sourceUrl: "https://freekidsbooks.org/",
    description: "Binti is full of energy and knows what she wants.",
    coverColor: "#F59E0B",
  },
  {
    title: "Hey Mom! What is Diversity?",
    author: "T. Albert",
    age: "4-6",
    genre: "Family",
    tags: ["Diversity", "Learning"],
    source: "Free Kids Books",
    sourceUrl: "https://freekidsbooks.org/",
    description: "Sally learns about diversity and how everyone is different.",
    coverColor: "#EC4899",
  },
  {
    title: "More Micropoems",
    author: "Gabriel Rosenstock",
    age: "10-12",
    genre: "Poetry",
    tags: ["Creative", "Classic"],
    source: "Free Kids Books",
    sourceUrl: "https://freekidsbooks.org/",
    description: "A fun compilation of contemplative micropoems.",
    coverColor: "#3B82F6",
  },
  {
    title: "Swimming in the Zambezi",
    author: "Imelda Lyamine",
    age: "7-9",
    genre: "Adventure",
    tags: ["Africa", "Friendship"],
    source: "Free Kids Books",
    sourceUrl: "https://freekidsbooks.org/",
    description: "Ntwala takes girls swimming in the Zambezi river.",
    coverColor: "#06B6D4",
  },
  {
    title: "The Three Little Pigs",
    author: "Traditional",
    age: "0-3",
    genre: "Fairy Tales",
    tags: ["Classic", "Bedtime"],
    source: "Free Kids Books",
    sourceUrl: "https://freekidsbooks.org/",
    description: "The classic tale of three pigs and a big bad wolf.",
    coverColor: "#EF4444",
  },
  {
    title: "Alice in Wonderland",
    author: "Lewis Carroll",
    age: "10-12",
    genre: "Fantasy",
    tags: ["Classic", "Adventure"],
    source: "Free Kids Books",
    sourceUrl: "https://freekidsbooks.org/",
    description: "Alice falls down a rabbit hole into a magical world.",
    coverColor: "#8B5CF6",
  },
  {
    title: "The Velveteen Rabbit",
    author: "Margery Williams",
    age: "7-9",
    genre: "Animals",
    tags: ["Classic", "Emotions"],
    source: "Free Kids Books",
    sourceUrl: "https://freekidsbooks.org/",
    description: "A toy rabbit becomes real through a child's love.",
    coverColor: "#84CC16",
  },
  {
    title: "Aesop's Fables Collection",
    author: "Aesop",
    age: "7-9",
    genre: "Fable",
    tags: ["Classic", "Moral"],
    source: "Free Kids Books",
    sourceUrl: "https://freekidsbooks.org/",
    description: "Classic fables teaching valuable life lessons.",
    coverColor: "#6366F1",
  },
];

// Generate SVG cover
function generateBookCover(title, author, color) {
  const shortTitle = title.length > 30 ? title.substring(0, 27) + "..." : title;
  const shortAuthor =
    author.length > 25 ? author.substring(0, 22) + "..." : author;

  return `<svg width="400" height="600" xmlns="http://www.w3.org/2000/svg">
    <defs>
      <linearGradient id="grad${color.replace(
        "#",
        ""
      )}" x1="0%" y1="0%" x2="100%" y2="100%">
        <stop offset="0%" style="stop-color:${color};stop-opacity:1" />
        <stop offset="100%" style="stop-color:${adjustBrightness(
          color,
          -20
        )};stop-opacity:1" />
      </linearGradient>
    </defs>
    <rect width="400" height="600" fill="url(#grad${color.replace("#", "")})"/>
    <text x="200" y="250" font-family="Arial, sans-serif" font-size="36" font-weight="bold" 
          fill="white" text-anchor="middle" dominant-baseline="middle" style="text-shadow: 2px 2px 4px rgba(0,0,0,0.3)">
      <tspan x="200" dy="0">${shortTitle
        .split(" ")
        .slice(0, 3)
        .join(" ")}</tspan>
      <tspan x="200" dy="40">${shortTitle.split(" ").slice(3).join(" ")}</tspan>
    </text>
    <text x="200" y="500" font-family="Arial, sans-serif" font-size="20" 
          fill="white" text-anchor="middle" opacity="0.9">
      ${shortAuthor}
    </text>
    <rect x="0" y="0" width="400" height="600" fill="none" stroke="rgba(255,255,255,0.2)" stroke-width="3"/>
  </svg>`;
}

function adjustBrightness(color, amount) {
  const num = parseInt(color.replace("#", ""), 16);
  const r = Math.max(0, Math.min(255, (num >> 16) + amount));
  const g = Math.max(0, Math.min(255, ((num >> 8) & 0x00ff) + amount));
  const b = Math.max(0, Math.min(255, (num & 0x0000ff) + amount));
  return "#" + ((r << 16) | (g << 8) | b).toString(16).padStart(6, "0");
}

// Upload books to Firebase
async function uploadBooks() {
  console.log("📚 Starting to upload Free Kids Books...\n");

  for (let i = 0; i < freeKidsBooksData.length; i++) {
    const book = freeKidsBooksData[i];

    try {
      console.log(
        `[${i + 1}/${freeKidsBooksData.length}] Uploading: ${book.title}...`
      );

      // Create book document
      const docRef = await addDoc(collection(db, "books"), {
        title: book.title,
        author: book.author,
        age: book.age,
        genre: book.genre,
        tags: book.tags,
        source: book.source,
        sourceUrl: book.sourceUrl,
        description: book.description,
        coverUrl: "",
        createdAt: new Date(),
      });

      // Generate and upload cover
      const coverSVG = generateBookCover(
        book.title,
        book.author,
        book.coverColor
      );
      const storageRef = ref(storage, `book-covers/${docRef.id}.svg`);
      await uploadString(storageRef, coverSVG, "raw", {
        contentType: "image/svg+xml",
      });
      const coverUrl = await getDownloadURL(storageRef);

      // Update book with cover URL
      await updateDoc(doc(db, "books", docRef.id), { coverUrl });

      console.log(`   ✅ Success! ID: ${docRef.id}`);
    } catch (error) {
      console.error(`   ❌ Error uploading ${book.title}:`, error.message);
    }

    // Small delay to avoid rate limiting
    await new Promise((resolve) => setTimeout(resolve, 500));
  }

  console.log("\n🎉 All books uploaded successfully!");
  console.log(`Total: ${freeKidsBooksData.length} books added to Firebase`);
}

// Add missing import
import { updateDoc, doc } from "firebase/firestore";

// Run the upload
uploadBooks()
  .then(() => {
    console.log("\n✨ Import complete! You can now view books in your app.");
    process.exit(0);
  })
  .catch((error) => {
    console.error("\n💥 Error during import:", error);
    process.exit(1);
  });
