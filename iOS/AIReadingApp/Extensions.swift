import SwiftUI
import Foundation

// MARK: - Book Model
struct Book: Identifiable {
    let id: String
    let title: String
    let author: String
    let age: String?
    let genre: String?
    let coverUrl: String?
    let tags: [String]?
    let textContent: String?
    let chapters: [Chapter]
    let coverImageURL: String?
    
    init(id: String, title: String, author: String, age: String? = nil, genre: String? = nil, 
         coverUrl: String? = nil, tags: [String]? = nil, textContent: String? = nil, 
         chapters: [Chapter] = [], coverImageURL: String? = nil) {
        self.id = id
        self.title = title
        self.author = author
        self.age = age
        self.genre = genre
        self.coverUrl = coverUrl
        self.tags = tags
        self.textContent = textContent
        self.chapters = chapters
        self.coverImageURL = coverImageURL
    }
    
    // Convenience initializer from EPUBContent
    init(from epubContent: EPUBContent, id: String, age: String? = nil, genre: String? = nil, 
         coverUrl: String? = nil, tags: [String]? = nil) {
        self.id = id
        self.title = epubContent.title
        self.author = epubContent.author
        self.age = age
        self.genre = genre
        self.coverUrl = coverUrl ?? epubContent.coverImageURL
        self.tags = tags
        self.textContent = nil
        self.chapters = epubContent.chapters
        self.coverImageURL = epubContent.coverImageURL
    }
}

// MARK: - Chapter Type Alias
typealias Chapter = EPUBChapter

// MARK: - Color Extension for Hex Colors
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

