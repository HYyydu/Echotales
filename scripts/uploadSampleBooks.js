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

// Sample books data
const sampleBooks = [
  {
    title: "Wobbly",
    author: "Frances Hodgson Burnett",
    age: "7-9",
    genre: "Adventure",
    tags: ["Bestseller"],
    textContent: "Once upon a time, there was a young girl named Mary...",
  },
  {
    title: "Where the Wild Things Are",
    author: "Maurice Sendak",
    age: "4-6",
    genre: "Fantasy",
    tags: ["Classic"],
    textContent: "The night Max wore his wolf suit and made mischief...",
  },
  {
    title: "Charlotte's Web",
    author: "E.B. White",
    age: "7-9",
    genre: "Animals",
    tags: ["Award Winner"],
    textContent: "Where's Papa going with that ax?",
  },
  {
    title: "The Little Prince",
    author: "Antoine de Saint-Exupéry",
    age: "10-12",
    genre: "Fantasy",
    tags: ["Classic"],
    textContent: "Once when I was six years old I saw a magnificent picture...",
  },
  {
    title: "Goodnight Moon",
    author: "Margaret Wise Brown",
    age: "0-3",
    genre: "Bedtime",
    tags: ["Bedtime"],
    textContent: "In the great green room, there was a telephone...",
  },
  {
    title: "Harry Potter and the Sorcerer's Stone",
    author: "J.K. Rowling",
    age: "10-12",
    genre: "Fantasy",
    tags: ["Trending"],
    textContent: "Mr. and Mrs. Dursley, of number four, Privet Drive...",
  },
  {
    title: "Matilda",
    author: "Roald Dahl",
    age: "7-9",
    genre: "Adventure",
    tags: ["Bestseller"],
    textContent: "It's a funny thing about mothers and fathers...",
  },
  {
    title: "The Cat in the Hat",
    author: "Dr. Seuss",
    age: "4-6",
    genre: "Animals",
    tags: ["Classic"],
    textContent: "The sun did not shine. It was too wet to play...",
  },
  {
    title: "Green Eggs and Ham",
    author: "Dr. Seuss",
    age: "4-6",
    genre: "Animals",
    tags: ["Classic"],
    textContent: "I am Sam. Sam I am. That Sam-I-am! That Sam-I-am!",
  },
];

// Generate placeholder book cover SVG
function generatePlaceholderCover(title, color) {
  return `<svg width="400" height="600" xmlns="http://www.w3.org/2000/svg">
    <rect width="400" height="600" fill="${color}"/>
    <text x="200" y="300" font-family="Arial, sans-serif" font-size="32" font-weight="bold" 
          fill="white" text-anchor="middle" dominant-baseline="middle">
      ${title.substring(0, 20)}
    </text>
  </svg>`;
}

// Upload books
async function uploadSampleBooks() {
  const colors = [
    "#8B5CF6",
    "#EC4899",
    "#10B981",
    "#F59E0B",
    "#3B82F6",
    "#EF4444",
    "#06B6D4",
    "#84CC16",
    "#6366F1",
  ];

  console.log("Starting to upload sample books...\n");

  for (let i = 0; i < sampleBooks.length; i++) {
    const book = sampleBooks[i];
    const color = colors[i % colors.length];

    try {
      console.log(`Uploading: ${book.title}...`);

      // Create book document first
      const docRef = await addDoc(collection(db, "books"), {
        ...book,
        coverUrl: "",
        createdAt: new Date(),
      });

      // Generate and upload placeholder cover
      const coverSVG = generatePlaceholderCover(book.title, color);
      const storageRef = ref(storage, `book-covers/${docRef.id}.svg`);
      await uploadString(storageRef, coverSVG, "raw", {
        contentType: "image/svg+xml",
      });
      const coverUrl = await getDownloadURL(storageRef);

      // Update book with cover URL
      await updateDoc(doc(db, "books", docRef.id), { coverUrl });

      console.log(`✅ Uploaded: ${book.title}`);
    } catch (error) {
      console.error(`❌ Error uploading ${book.title}:`, error);
    }
  }

  console.log("\n✅ All sample books uploaded!");
}

// Run the upload
uploadSampleBooks().catch(console.error);
