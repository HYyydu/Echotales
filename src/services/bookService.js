import {
  collection,
  getDocs,
  addDoc,
  deleteDoc,
  doc,
  query,
  where,
} from "firebase/firestore";
import {
  ref,
  uploadBytes,
  getDownloadURL,
  deleteObject,
} from "firebase/storage";
import { db, storage } from "../config/firebase";

class BookService {
  constructor() {
    this.booksCollection = collection(db, "books");
  }

  // Fetch all books
  async getAllBooks() {
    try {
      const querySnapshot = await getDocs(this.booksCollection);
      return querySnapshot.docs.map((doc) => ({
        id: doc.id,
        ...doc.data(),
      }));
    } catch (error) {
      console.error("Error fetching books:", error);
      throw error;
    }
  }

  // Fetch books by age group
  async getBooksByAge(age) {
    try {
      const q = query(this.booksCollection, where("age", "==", age));
      const querySnapshot = await getDocs(q);
      return querySnapshot.docs.map((doc) => ({
        id: doc.id,
        ...doc.data(),
      }));
    } catch (error) {
      console.error("Error fetching books by age:", error);
      throw error;
    }
  }

  // Fetch books by genre
  async getBooksByGenre(genre) {
    try {
      const q = query(this.booksCollection, where("genre", "==", genre));
      const querySnapshot = await getDocs(q);
      return querySnapshot.docs.map((doc) => ({
        id: doc.id,
        ...doc.data(),
      }));
    } catch (error) {
      console.error("Error fetching books by genre:", error);
      throw error;
    }
  }

  // Upload book cover
  async uploadBookCover(file, bookId) {
    try {
      const storageRef = ref(storage, `book-covers/${bookId}.jpg`);
      await uploadBytes(storageRef, file);
      const downloadURL = await getDownloadURL(storageRef);
      return downloadURL;
    } catch (error) {
      console.error("Error uploading book cover:", error);
      throw error;
    }
  }

  // Add a new book
  async addBook(bookData, coverFile) {
    try {
      // First, add the book to get an ID
      const docRef = await addDoc(this.booksCollection, {
        ...bookData,
        coverUrl: "", // Temporary
      });

      // Upload cover with the book ID
      const coverUrl = await this.uploadBookCover(coverFile, docRef.id);

      // Update book with cover URL
      await updateDoc(doc(db, "books", docRef.id), {
        coverUrl,
      });

      return docRef.id;
    } catch (error) {
      console.error("Error adding book:", error);
      throw error;
    }
  }

  // Delete a book
  async deleteBook(bookId, coverUrl) {
    try {
      // Delete cover from storage
      if (coverUrl) {
        const coverRef = ref(storage, coverUrl);
        await deleteObject(coverRef);
      }

      // Delete book document
      await deleteDoc(doc(db, "books", bookId));
    } catch (error) {
      console.error("Error deleting book:", error);
      throw error;
    }
  }
}

export default new BookService();
