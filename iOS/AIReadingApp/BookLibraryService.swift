import Foundation
import FirebaseCore
import FirebaseFirestore
import FirebaseStorage

class BookLibraryService {
    static let shared = BookLibraryService()
    
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    
    private init() {}
    
    // Fetch all books
    func fetchBooks() async throws -> [Book] {
        let snapshot = try await db.collection("books").getDocuments()
        
        return snapshot.documents.compactMap { document in
            let data = document.data()
            guard let title = data["title"] as? String,
                  let author = data["author"] as? String,
                  let age = data["age"] as? String,
                  let genre = data["genre"] as? String,
                  let coverUrl = data["coverUrl"] as? String else {
                return nil
            }
            
            let tags = data["tags"] as? [String] ?? []
            let textContent = data["textContent"] as? String
            let id = document.documentID
            
            return Book(
                id: id,
                title: title,
                author: author,
                age: age,
                genre: genre,
                coverUrl: coverUrl,
                tags: tags,
                textContent: textContent
            )
        }
    }
    
    // Fetch books by age
    func fetchBooksByAge(age: String) async throws -> [Book] {
        let snapshot = try await db.collection("books")
            .whereField("age", isEqualTo: age)
            .getDocuments()
        
        return snapshot.documents.compactMap { document in
            parseBookDocument(document)
        }
    }
    
    // Fetch books by genre
    func fetchBooksByGenre(genre: String) async throws -> [Book] {
        let snapshot = try await db.collection("books")
            .whereField("genre", isEqualTo: genre)
            .getDocuments()
        
        return snapshot.documents.compactMap { document in
            parseBookDocument(document)
        }
    }
    
    // Upload book cover
    func uploadBookCover(imageData: Data, bookId: String) async throws -> String {
        let storageRef = storage.reference().child("book-covers/\(bookId).jpg")
        
        _ = try await storageRef.putDataAsync(imageData)
        let downloadURL = try await storageRef.downloadURL()
        
        return downloadURL.absoluteString
    }
    
    // Add a new book
    func addBook(title: String, author: String, age: String, genre: String, tags: [String], coverData: Data, textContent: String?) async throws -> String {
        // Create book document (without cover first)
        var bookData: [String: Any] = [
            "title": title,
            "author": author,
            "age": age,
            "genre": genre,
            "tags": tags,
            "createdAt": FieldValue.serverTimestamp()
        ]
        if let textContent = textContent {
            bookData["textContent"] = textContent
        }
        
        let docRef = try await db.collection("books").addDocument(data: bookData)
        
        // Upload cover
        let coverUrl = try await uploadBookCover(imageData: coverData, bookId: docRef.documentID)
        
        // Update book with cover URL
        try await docRef.updateData(["coverUrl": coverUrl])
        
        return docRef.documentID
    }
    
    // Delete a book
    func deleteBook(bookId: String) async throws {
        // Get book data first to get cover URL
        let docRef = db.collection("books").document(bookId)
        let document = try await docRef.getDocument()
        
        if let coverUrl = document.data()?["coverUrl"] as? String {
            // Delete cover from storage
            let storageRef = storage.reference(forURL: coverUrl)
            try? await storageRef.delete()
        }
        
        // Delete book document
        try await docRef.delete()
    }
    
    // Helper method to parse book document
    private func parseBookDocument(_ document: DocumentSnapshot) -> Book? {
        let data = document.data() ?? [:]
        guard let title = data["title"] as? String,
              let author = data["author"] as? String,
              let age = data["age"] as? String,
              let genre = data["genre"] as? String,
              let coverUrl = data["coverUrl"] as? String else {
            return nil
        }
        
        let tags = data["tags"] as? [String] ?? []
        let textContent = data["textContent"] as? String
        let id = document.documentID
        
        return Book(
            id: id,
            title: title,
            author: author,
            age: age,
            genre: genre,
            coverUrl: coverUrl,
            tags: tags,
            textContent: textContent
        )
    }
}
