import Foundation
import UIKit
import PDFKit
import UniformTypeIdentifiers

// MARK: - Document Processor
/// Utility class to extract text and generate covers from various document types
class DocumentProcessor {
    
    // MARK: - Document Result
    struct ProcessedDocument {
        let title: String
        let content: String
        let coverImage: UIImage?
        let fileType: String
    }
    
    // MARK: - Process Document
    static func processDocument(url: URL, userDisplayName: String?) -> ProcessedDocument? {
        // Start accessing security-scoped resource
        guard url.startAccessingSecurityScopedResource() else {
            print("❌ DocumentProcessor: Failed to access security-scoped resource")
            return nil
        }
        
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        // Get file extension
        let fileExtension = url.pathExtension.lowercased()
        let fileName = url.deletingPathExtension().lastPathComponent
        
        print("📄 DocumentProcessor: Processing \(fileExtension.uppercased()) file: \(fileName)")
        
        var content: String?
        var coverImage: UIImage?
        
        switch fileExtension {
        case "pdf":
            let result = processPDF(url: url)
            content = result.text
            coverImage = result.coverImage
            
        case "txt":
            content = processTextFile(url: url)
            
        case "rtf", "rtfd":
            content = processRTF(url: url)
            
        case "doc", "docx":
            content = processWordDocument(url: url)
            
        default:
            print("⚠️ DocumentProcessor: Unsupported file type: \(fileExtension)")
            return nil
        }
        
        guard let finalContent = content, !finalContent.isEmpty else {
            print("❌ DocumentProcessor: Failed to extract content from document")
            return nil
        }
        
        print("✅ DocumentProcessor: Successfully extracted \(finalContent.count) characters")
        
        return ProcessedDocument(
            title: fileName,
            content: finalContent,
            coverImage: coverImage,
            fileType: fileExtension
        )
    }
    
    // MARK: - PDF Processing
    private static func processPDF(url: URL) -> (text: String?, coverImage: UIImage?) {
        guard let document = PDFDocument(url: url) else {
            print("❌ DocumentProcessor: Failed to load PDF document")
            return (nil, nil)
        }
        
        print("📖 DocumentProcessor: PDF has \(document.pageCount) pages")
        
        // Extract text from all pages
        var fullText = ""
        for pageIndex in 0..<document.pageCount {
            if let page = document.page(at: pageIndex) {
                if let pageText = page.string {
                    fullText += pageText + "\n\n"
                }
            }
        }
        
        // Generate cover image from first page
        var coverImage: UIImage?
        if let firstPage = document.page(at: 0) {
            let pageRect = firstPage.bounds(for: .mediaBox)
            let renderer = UIGraphicsImageRenderer(size: pageRect.size)
            
            coverImage = renderer.image { context in
                UIColor.white.set()
                context.fill(pageRect)
                
                context.cgContext.translateBy(x: 0, y: pageRect.size.height)
                context.cgContext.scaleBy(x: 1.0, y: -1.0)
                
                firstPage.draw(with: .mediaBox, to: context.cgContext)
            }
            
            print("✅ DocumentProcessor: Generated cover image from PDF first page")
        }
        
        let trimmedText = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmedText.isEmpty ? nil : trimmedText, coverImage)
    }
    
    // MARK: - Text File Processing
    private static func processTextFile(url: URL) -> String? {
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            print("✅ DocumentProcessor: Successfully read text file")
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            print("❌ DocumentProcessor: Failed to read text file: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - RTF Processing
    private static func processRTF(url: URL) -> String? {
        do {
            let attributedString = try NSAttributedString(
                url: url,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
            )
            let text = attributedString.string.trimmingCharacters(in: .whitespacesAndNewlines)
            print("✅ DocumentProcessor: Successfully extracted text from RTF")
            return text
        } catch {
            print("❌ DocumentProcessor: Failed to process RTF: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Word Document Processing
    private static func processWordDocument(url: URL) -> String? {
        // Try to read as RTF first (works for some DOC files)
        if let rtfContent = processRTF(url: url) {
            return rtfContent
        }
        
        // For DOCX, try with default options (no specific document type)
        do {
            let attributedString = try NSAttributedString(
                url: url,
                options: [:],
                documentAttributes: nil
            )
            let text = String(attributedString.string).trimmingCharacters(in: .whitespacesAndNewlines)
            print("✅ DocumentProcessor: Successfully extracted text from Word document")
            return text
        } catch {
            print("⚠️ DocumentProcessor: Failed to process Word document: \(error.localizedDescription)")
            
            // Last resort: try reading as plain text
            if let plainText = processTextFile(url: url) {
                return plainText
            }
            
            return nil
        }
    }
    
    // MARK: - Generate Default Cover
    static func generateDefaultCover(title: String, color: UIColor = UIColor(red: 0.96, green: 0.71, blue: 0.66, alpha: 1.0)) -> UIImage {
        let size = CGSize(width: 300, height: 450)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { context in
            // Background gradient
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    color.cgColor,
                    color.withAlphaComponent(0.7).cgColor
                ] as CFArray,
                locations: [0.0, 1.0]
            )
            
            context.cgContext.drawLinearGradient(
                gradient!,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )
            
            // Book icon
            let iconSize: CGFloat = 80
            let iconRect = CGRect(
                x: (size.width - iconSize) / 2,
                y: size.height * 0.35,
                width: iconSize,
                height: iconSize
            )
            
            if let bookIcon = UIImage(systemName: "book.fill")?.withConfiguration(
                UIImage.SymbolConfiguration(pointSize: iconSize, weight: .regular)
            ) {
                bookIcon.withTintColor(.white.withAlphaComponent(0.7), renderingMode: .alwaysOriginal)
                    .draw(in: iconRect)
            }
            
            // Title text
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            paragraphStyle.lineBreakMode = .byWordWrapping
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24, weight: .bold),
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraphStyle
            ]
            
            let titleText = String(title.prefix(50)) // Limit length and convert to String
            let textRect = CGRect(x: 20, y: size.height * 0.6, width: size.width - 40, height: 100)
            titleText.draw(in: textRect, withAttributes: attributes)
        }
        
        return image
    }
}

