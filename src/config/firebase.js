import { initializeApp } from "firebase/app";
import { getFirestore } from "firebase/firestore";
import { getStorage } from "firebase/storage";

// Your web app's Firebase configuration
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

// Initialize Firebase services
export const db = getFirestore(app);
export const storage = getStorage(app);
export default app;
