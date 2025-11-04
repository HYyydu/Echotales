import { initializeApp } from "firebase/app";
import { getFirestore, collection, getDocs } from "firebase/firestore";

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

// Check books
async function checkBooks() {
  try {
    console.log("📚 Checking books in Firebase...\n");
    
    const booksSnapshot = await getDocs(collection(db, "books"));
    
    if (booksSnapshot.empty) {
      console.log("❌ No books found in the database.");
      console.log("\nThe upload might have failed. Check the browser console for errors.");
      return;
    }
    
    console.log(`✅ Found ${booksSnapshot.size} book(s) in the database!\n`);
    console.log("=" .repeat(60));
    
    booksSnapshot.forEach((doc, index) => {
      const book = doc.data();
      console.log(`\n📖 Book #${index + 1}:`);
      console.log(`   ID: ${doc.id}`);
      console.log(`   Title: ${book.title}`);
      console.log(`   Author: ${book.author}`);
      console.log(`   Age: ${book.age}`);
      console.log(`   Genre: ${book.genre}`);
      console.log(`   Tags: ${book.tags?.join(", ") || "None"}`);
      console.log(`   Cover: ${book.coverUrl ? "✓ Uploaded" : "✗ Missing"}`);
      console.log(`   Content Length: ${book.textContent?.length || 0} characters`);
      console.log(`   Created: ${book.createdAt?.toDate?.()?.toLocaleString() || "Unknown"}`);
    });
    
    console.log("\n" + "=".repeat(60));
    console.log("\n✅ All books loaded successfully!");
    
  } catch (error) {
    console.error("❌ Error checking books:", error.message);
    console.error("\nPossible issues:");
    console.error("1. Firestore is not enabled in Firebase Console");
    console.error("2. Network connection issue");
    console.error("3. Firebase configuration is incorrect");
  }
  
  process.exit(0);
}

// Run the check
checkBooks();

