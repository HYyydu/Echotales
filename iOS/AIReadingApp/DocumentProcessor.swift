import Foundation
import UIKit
import PDFKit
import UniformTypeIdentifiers
import Vision
import ZIPFoundation

// MARK: - Document Processor
/// Utility class to extract text and generate covers from various document types
class DocumentProcessor {
    
    // MARK: - Error Types
    enum ProcessingError: Error {
        case securityAccessFailed
        case fileNotReadable
        case fileEmpty
        case unsupportedFileType(String)
        case pdfLoadFailed
        case pdfNoText
        case pdfPasswordProtected
        case textExtractionFailed(String)
        
        var localizedDescription: String {
            switch self {
            case .securityAccessFailed:
                return "Cannot access the file. Please try selecting it again."
            case .fileNotReadable:
                return "The file cannot be read. It may be corrupted."
            case .fileEmpty:
                return "The file is empty or corrupted (0 bytes)."
            case .unsupportedFileType(let type):
                return "File type '\(type)' is not supported. Please use PDF, TXT, EPUB, or DOC files."
            case .pdfLoadFailed:
                return "Cannot open PDF. The file may be corrupted or password-protected."
            case .pdfNoText:
                return "This PDF contains no readable text. It may be a scanned document (image-only PDF)."
            case .pdfPasswordProtected:
                return "This PDF is password-protected and cannot be imported."
            case .textExtractionFailed(let reason):
                return "Failed to extract text: \(reason)"
            }
        }
    }
    
    // MARK: - Document Result
    struct ProcessedDocument {
        let title: String
        let content: String
        let coverImage: UIImage?
        let fileType: String
        let formattedContent: AttributedContent?  // NEW: Formatted content for better TTS
        let partialExtraction: Bool  // NEW: Indicates if extraction was partial due to errors
        let extractionWarnings: [String]  // NEW: List of warnings during extraction
    }
    
    // MARK: - Attributed Content for TTS
    /// Represents content with formatting hints for better text-to-speech
    struct AttributedContent {
        let plainText: String
        let formattingHints: [FormattingHint]
    }
    
    struct FormattingHint {
        let range: NSRange
        let type: FormattingType
    }
    
    enum FormattingType: Equatable {
        case bold
        case italic
        case heading(level: Int)  // H1, H2, H3, etc.
        case emphasis
        case quote
        
        var ssmlTag: String {
            switch self {
            case .bold, .emphasis:
                return "emphasis"
            case .italic:
                return "emphasis level='moderate'"
            case .heading(let level):
                return level <= 2 ? "emphasis level='strong'" : "emphasis"
            case .quote:
                return "prosody rate='slow'"
            }
        }
    }
    
    // MARK: - Process Document
    static func processDocument(url: URL, userDisplayName: String?) -> ProcessedDocument? {
        print("═══════════════════════════════════════════════════════════")
        print("📄 DocumentProcessor: Starting document processing")
        print("   File: \(url.lastPathComponent)")
        print("   Path: \(url.path)")
        
        // Check if file is in app's sandbox (tmp, Documents, Library, etc.)
        let isInAppSandbox = url.path.contains("/Containers/Data/Application/") && 
                             (url.path.contains("/tmp/") || 
                              url.path.contains("/Documents/") || 
                              url.path.contains("/Library/"))
        
        print("   📍 Location: \(isInAppSandbox ? "App Sandbox (no security scope needed)" : "External (requires security scope)")")
        
        // Start accessing security-scoped resource (only for files outside app sandbox)
        let needsSecurityScope = !isInAppSandbox
        var securityScopeStarted = false
        
        if needsSecurityScope {
            print("   🔐 Attempting to start security-scoped resource access...")
            securityScopeStarted = url.startAccessingSecurityScopedResource()
            
            if !securityScopeStarted {
                print("   ❌ Failed to access security-scoped resource")
                print("   Error: \(ProcessingError.securityAccessFailed.localizedDescription)")
                print("═══════════════════════════════════════════════════════════")
                return nil
            }
            print("   ✅ Security-scoped access granted")
        } else {
            print("   ℹ️ File is in app sandbox, skipping security-scoped access")
        }
        
        defer {
            if securityScopeStarted {
                url.stopAccessingSecurityScopedResource()
                print("🔓 DocumentProcessor: Released security-scoped resource")
            }
        }
        
        // Validate file is readable
        guard FileManager.default.isReadableFile(atPath: url.path) else {
            print("❌ DocumentProcessor: File is not readable")
            print("   Error: \(ProcessingError.fileNotReadable.localizedDescription)")
            print("═══════════════════════════════════════════════════════════")
            return nil
        }
        print("✅ File is readable")
        
        // Check file size
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            print("📊 File size: \(fileSize) bytes (\(Double(fileSize) / 1024.0) KB)")
            
            guard fileSize > 0 else {
                print("❌ DocumentProcessor: File is empty (0 bytes)")
                print("   Error: \(ProcessingError.fileEmpty.localizedDescription)")
                print("═══════════════════════════════════════════════════════════")
                return nil
            }
        } catch {
            print("⚠️ DocumentProcessor: Could not read file attributes: \(error.localizedDescription)")
        }
        
        // Get file extension
        let fileExtension = url.pathExtension.lowercased()
        let fileName = url.deletingPathExtension().lastPathComponent
        
        print("📝 File type: \(fileExtension.uppercased())")
        print("📑 File name: \(fileName)")
        print("───────────────────────────────────────────────────────────")
        
        var content: String?
        var coverImage: UIImage?
        var processingError: ProcessingError?
        
        switch fileExtension {
        case "pdf":
            print("🔄 Processing as PDF...")
            let result = processPDF(url: url)
            content = result.text
            coverImage = result.coverImage
            processingError = result.error
            
        case "txt":
            print("🔄 Processing as TXT...")
            let result = processTextFile(url: url)
            content = result.text
            processingError = result.error
            
        case "epub":
            print("🔄 Processing as EPUB...")
            let result = processEPUB(url: url)
            content = result.text
            coverImage = result.coverImage
            processingError = result.error
            
        case "doc", "docx":
            print("🔄 Processing as Word document...")
            let result = processWordDocument(url: url)
            content = result.text
            processingError = result.error
            
        default:
            print("❌ DocumentProcessor: Unsupported file type: \(fileExtension)")
            processingError = .unsupportedFileType(fileExtension)
        }
        
        // Check for processing errors
        if let error = processingError {
            print("❌ Processing failed with error:")
            print("   \(error.localizedDescription)")
            print("═══════════════════════════════════════════════════════════")
            return nil
        }
        
        // Check if we have any content
        let hasContent = content != nil && !(content?.isEmpty ?? true)
        
        if !hasContent {
            print("❌ DocumentProcessor: Failed to extract content from document")
            print("   Content is nil or empty after processing")
            print("═══════════════════════════════════════════════════════════")
            return nil
        }
        
        let finalContent = content!
        print("✅ Successfully extracted \(finalContent.count) characters")
        print("📄 Preview (first 100 chars): \(String(finalContent.prefix(100)))...")
        
        // Add formatting information if available (for TTS enhancement)
        var formattedContent: AttributedContent?
        var warnings: [String] = []
        
        // Extract formatting hints based on file type
        switch fileExtension {
        case "epub":
            // EPUB preserves rich formatting
            formattedContent = extractFormattingFromEPUB(content: finalContent)
            print("   🎨 Formatting hints extracted: \(formattedContent?.formattingHints.count ?? 0)")
        case "doc", "docx":
            // Word documents have rich formatting
            formattedContent = extractFormattingFromAttributedString(content: finalContent)
            print("   🎨 Formatting hints extracted: \(formattedContent?.formattingHints.count ?? 0)")
        default:
            // Plain text - detect markdown-style formatting
            formattedContent = extractFormattingFromPlainText(content: finalContent)
            print("   🎨 Basic formatting hints detected: \(formattedContent?.formattingHints.count ?? 0)")
        }
        
        // Add warnings if any errors occurred
        if let error = processingError {
            warnings.append(error.localizedDescription)
        }
        
        print("═══════════════════════════════════════════════════════════")
        
        return ProcessedDocument(
            title: fileName,
            content: finalContent,
            coverImage: coverImage,
            fileType: fileExtension,
            formattedContent: formattedContent,
            partialExtraction: !warnings.isEmpty,
            extractionWarnings: warnings
        )
    }
    
    // MARK: - PDF Processing
    private static func processPDF(url: URL) -> (text: String?, coverImage: UIImage?, error: ProcessingError?) {
        print("   📖 Loading PDF document...")
        
        guard let document = PDFDocument(url: url) else {
            print("   ❌ Failed to load PDF document")
            print("   Possible reasons:")
            print("      - File is corrupted")
            print("      - File is password-protected")
            print("      - File is not a valid PDF")
            return (nil, nil, .pdfLoadFailed)
        }
        
        print("   ✅ PDF loaded successfully")
        print("   📄 Page count: \(document.pageCount)")
        
        // Check if PDF is encrypted/password-protected
        if document.isEncrypted {
            print("   ⚠️ PDF is encrypted (password-protected)")
            if !document.isLocked {
                print("   ℹ️ PDF is unlocked, attempting to extract text")
            } else {
                print("   ❌ PDF is locked and requires password")
                return (nil, nil, .pdfPasswordProtected)
            }
        }
        
        // Extract text from all pages with error tolerance and structure preservation
        var fullText = ""
        var pagesWithText = 0
        var totalCharacters = 0
        var failedPages: [Int] = []
        var corruptedPages: [Int] = []
        
        print("   🔄 Extracting text from \(document.pageCount) pages with structure preservation...")
        
        for pageIndex in 0..<document.pageCount {
            do {
                guard let page = document.page(at: pageIndex) else {
                    print("   ⚠️ Page \(pageIndex + 1): Could not load page (may be corrupted)")
                    failedPages.append(pageIndex + 1)
                    continue
                }
                
                // Try to extract text with structure preservation
                if let pageText = extractStructuredTextFromPage(page, pageNumber: pageIndex + 1) {
                    let charCount = pageText.count
                    if charCount > 0 {
                        pagesWithText += 1
                        totalCharacters += charCount
                        fullText += pageText + "\n\n"
                    } else {
                        // Empty page is OK, not an error
                        if pageIndex == 0 {
                            print("   ⚠️ Page 1 contains no text")
                        }
                    }
                    
                    // Log first page details
                    if pageIndex == 0 && charCount > 0 {
                        print("   📄 Page 1 text length: \(charCount) characters")
                        let preview = pageText.prefix(50).replacingOccurrences(of: "\n", with: " ")
                        print("   📝 Page 1 preview: \(preview)...")
                    }
                } else {
                    // Could load page but no text - might be image-only
                    if pageIndex < 3 {  // Only log for first few pages
                        print("   ⚠️ Page \(pageIndex + 1): No text extractable (may be image-only)")
                    }
                }
            } catch {
                print("   ❌ Page \(pageIndex + 1): Exception during extraction: \(error.localizedDescription)")
                corruptedPages.append(pageIndex + 1)
                // Continue with next page instead of failing completely
                continue
            }
        }
        
        print("   📊 Extraction summary:")
        print("      - Total pages: \(document.pageCount)")
        print("      - Pages with text: \(pagesWithText)")
        print("      - Failed pages: \(failedPages.count)")
        print("      - Corrupted pages: \(corruptedPages.count)")
        print("      - Total characters: \(totalCharacters)")
        
        // Analyze structure of extracted text
        let paragraphCount = fullText.components(separatedBy: "\n\n").filter { !$0.isEmpty }.count
        print("      - Paragraphs detected: \(paragraphCount)")
        print("      - Avg chars per paragraph: \(paragraphCount > 0 ? totalCharacters / paragraphCount : 0)")
        
        if !failedPages.isEmpty {
            print("   ⚠️ Failed pages: \(failedPages.prefix(10).map(String.init).joined(separator: ", "))")
        }
        if !corruptedPages.isEmpty {
            print("   ⚠️ Corrupted pages: \(corruptedPages.prefix(10).map(String.init).joined(separator: ", "))")
        }
        
        // Generate cover image from first page
        var coverImage: UIImage?
        print("   🖼️ Generating cover image from first page...")
        
        if let firstPage = document.page(at: 0) {
            let pageRect = firstPage.bounds(for: .mediaBox)
            print("      - Page dimensions: \(pageRect.size.width) x \(pageRect.size.height)")
            
            let renderer = UIGraphicsImageRenderer(size: pageRect.size)
            
            coverImage = renderer.image { context in
                UIColor.white.set()
                context.fill(pageRect)
                
                context.cgContext.translateBy(x: 0, y: pageRect.size.height)
                context.cgContext.scaleBy(x: 1.0, y: -1.0)
                
                firstPage.draw(with: .mediaBox, to: context.cgContext)
            }
            
            print("   ✅ Cover image generated successfully")
        } else {
            print("   ⚠️ Could not generate cover image (no first page)")
        }
        
        let trimmedText = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check if we have enough content
        let minCharacters = 50  // Minimum characters to consider successful
        
        if trimmedText.isEmpty || trimmedText.count < minCharacters {
            print("   ⚠️ Insufficient text extracted from PDF (\(trimmedText.count) chars)")
            print("   Attempting OCR for scanned PDF...")
            
            // Try OCR extraction with graceful fallback
            do {
                if let ocrText = performOCR(on: document) {
                    print("   ✅ OCR extraction successful")
                    // If we had partial text, combine it with OCR results
                    if !trimmedText.isEmpty {
                        print("   ℹ️ Combining partial text extraction with OCR results")
                        return (trimmedText + "\n\n" + ocrText, coverImage, nil)
                    }
                    return (ocrText, coverImage, nil)
                } else if !trimmedText.isEmpty {
                    // We have some text, even if not much
                    print("   ⚠️ OCR failed, but using partial text extraction (\(trimmedText.count) chars)")
                    return (trimmedText, coverImage, nil)
                } else {
                    print("   ❌ Both text extraction and OCR failed")
                    print("   This is likely a scanned PDF with poor image quality or no text")
                    return (nil, coverImage, .pdfNoText)
                }
            } catch {
                // OCR threw an exception - use partial text if available
                print("   ❌ OCR exception: \(error.localizedDescription)")
                if !trimmedText.isEmpty {
                    print("   ℹ️ Using partial text extraction despite OCR failure")
                    return (trimmedText, coverImage, nil)
                }
                return (nil, coverImage, .pdfNoText)
            }
        }
        
        // Successful text extraction
        print("   ✅ Text extraction successful")
        
        // Warn if many pages failed but we got some content
        if (failedPages.count + corruptedPages.count) > document.pageCount / 4 {
            print("   ⚠️ Warning: Many pages failed (\(failedPages.count + corruptedPages.count)/\(document.pageCount))")
            print("   ℹ️ Extraction is partial but usable")
        }
        
        return (trimmedText, coverImage, nil)
    }
    
    // MARK: - Structured Text Extraction from PDF Page
    /// Extract text from a PDF page while preserving structure (paragraphs, headers, bullets)
    private static func extractStructuredTextFromPage(_ page: PDFPage, pageNumber: Int) -> String? {
        guard let rawText = page.string else { return nil }
        
        // If text is very short, return as-is
        if rawText.count < 100 {
            return rawText
        }
        
        // Split into lines first
        var lines = rawText.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        
        // Build structured text with proper spacing
        var structuredText = ""
        var previousLineLength = 0
        var previousLineWasEmpty = false
        var consecutiveShortLines = 0
        
        for (index, line) in lines.enumerated() {
            // Skip completely empty lines but track them
            if line.isEmpty {
                if !previousLineWasEmpty && !structuredText.isEmpty {
                    structuredText += "\n"
                    previousLineWasEmpty = true
                }
                previousLineLength = 0
                consecutiveShortLines = 0
                continue
            }
            
            let isFirstLine = structuredText.isEmpty
            let lineLength = line.count
            
            // Detect various formatting patterns
            let startsWithBullet = line.hasPrefix("•") || line.hasPrefix("-") || line.hasPrefix("*") ||
                                   line.hasPrefix("○") || line.hasPrefix("▪") || line.hasPrefix("▫") ||
                                   line.range(of: "^[0-9]+[.):]\\s", options: .regularExpression) != nil
            
            let isLikelyHeader = (line == line.uppercased() && lineLength > 3 && lineLength < 50) ||
                                 (lineLength < 40 && !line.contains(".") && !line.contains(","))
            
            let isLikelyShortLine = lineLength < 60  // Short lines might be formatting artifacts
            let hasProperEnding = line.hasSuffix(".") || line.hasSuffix(":") || line.hasSuffix(";") ||
                                  line.hasSuffix(",") || line.hasSuffix(")")
            
            // Track consecutive short lines (might be a list or contact info)
            if isLikelyShortLine {
                consecutiveShortLines += 1
            } else {
                consecutiveShortLines = 0
            }
            
            // Add line to structured text with appropriate spacing
            if isFirstLine {
                // First line - just add it
                structuredText = line
            } else if startsWithBullet {
                // Bullet point - always start new line with double spacing for emphasis
                structuredText += "\n\n" + line
                previousLineWasEmpty = false
            } else if isLikelyHeader {
                // Header - add double spacing before and mark it
                structuredText += "\n\n" + line
                previousLineWasEmpty = false
            } else if previousLineWasEmpty || previousLineLength < 40 {
                // Previous line was empty or very short - start new paragraph
                structuredText += "\n\n" + line
                previousLineWasEmpty = false
            } else if consecutiveShortLines > 2 && isLikelyShortLine {
                // Multiple short lines (like contact info, skills list) - keep each on new line
                structuredText += "\n" + line
            } else if !hasProperEnding && lineLength > 60 {
                // Line continuation (no proper ending and reasonable length) - append with space
                structuredText += " " + line
            } else if hasProperEnding {
                // Proper sentence ending - might be end of paragraph
                if index < lines.count - 1 {
                    let nextLine = lines[index + 1]
                    // Check if next line looks like continuation or new paragraph
                    let nextLineIsEmpty = nextLine.isEmpty
                    let nextLineStartsWithCapital = nextLine.first?.isUppercase ?? false
                    let nextLineStartsWithBullet = nextLine.hasPrefix("•") || nextLine.hasPrefix("-")
                    
                    if nextLineIsEmpty || nextLineStartsWithBullet || 
                       (nextLineStartsWithCapital && nextLine.count < 60) {
                        // New paragraph coming
                        structuredText += " " + line
                    } else {
                        // Likely continuation
                        structuredText += " " + line
                    }
                } else {
                    // Last line
                    structuredText += " " + line
                }
            } else {
                // Default - append with space
                structuredText += " " + line
            }
            
            previousLineLength = lineLength
            previousLineWasEmpty = false
        }
        
        // Post-process: Clean up excessive spacing
        structuredText = structuredText.replacingOccurrences(of: "\n\n\n+", with: "\n\n", options: .regularExpression)
        structuredText = structuredText.replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
        
        // Log structure analysis for first page
        if pageNumber == 1 {
            let paragraphCount = structuredText.components(separatedBy: "\n\n").count
            let bulletCount = structuredText.components(separatedBy: .newlines)
                .filter { $0.hasPrefix("•") || $0.hasPrefix("-") || $0.hasPrefix("*") }.count
            print("   🏗️ Structure analysis: ~\(paragraphCount) paragraphs, ~\(bulletCount) bullets detected")
        }
        
        return structuredText
    }
    
    // MARK: - Text File Processing
    private static func processTextFile(url: URL) -> (text: String?, error: ProcessingError?) {
        print("   📝 Reading text file...")
        
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            
            print("   ✅ Successfully read text file")
            print("      - Character count: \(trimmed.count)")
            
            if trimmed.isEmpty {
                print("   ⚠️ Text file is empty after trimming whitespace")
                return (nil, .textExtractionFailed("File contains no readable content"))
            }
            
            return (trimmed, nil)
        } catch {
            print("   ❌ Failed to read text file")
            print("      Error: \(error.localizedDescription)")
            return (nil, .textExtractionFailed(error.localizedDescription))
        }
    }
    
    // MARK: - EPUB Processing
    private static func processEPUB(url: URL) -> (text: String?, coverImage: UIImage?, error: ProcessingError?) {
        print("   📚 Processing EPUB document...")
        
        guard let epubContent = EPUBParser.parseEPUB(at: url) else {
            print("   ❌ Failed to parse EPUB")
            return (nil, nil, .textExtractionFailed("Failed to parse EPUB file. The file may be corrupted or in an unsupported format."))
        }
        
        print("   ✅ Successfully parsed EPUB")
        print("      - Title: \(epubContent.title)")
        print("      - Author: \(epubContent.author)")
        print("      - Chapters: \(epubContent.chapters.count)")
        
        // Combine all chapter content with error handling
        var fullText = ""
        var successfulChapters = 0
        var failedChapters: [String] = []
        
        for (index, chapter) in epubContent.chapters.enumerated() {
            do {
                // Validate chapter content
                guard !chapter.content.isEmpty else {
                    print("   ⚠️ Chapter \(index + 1) '\(chapter.title)' is empty")
                    failedChapters.append(chapter.title)
                    continue
                }
                
                if index > 0 {
                    fullText += "\n\n"
                }
                
                // Add chapter title as heading
                fullText += "# \(chapter.title)\n\n"
                fullText += chapter.content
                successfulChapters += 1
                
            } catch {
                print("   ❌ Error processing chapter \(index + 1): \(error.localizedDescription)")
                failedChapters.append(chapter.title)
                continue
            }
        }
        
        print("   📊 Chapter extraction:")
        print("      - Successful: \(successfulChapters)")
        print("      - Failed: \(failedChapters.count)")
        
        if !failedChapters.isEmpty {
            print("   ⚠️ Failed chapters: \(failedChapters.prefix(5).joined(separator: ", "))")
        }
        
        let trimmedText = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Allow partial extraction if we got some content
        if trimmedText.isEmpty {
            print("   ❌ EPUB contains no readable text")
            return (nil, nil, .textExtractionFailed("EPUB contains no readable content"))
        }
        
        // Warn if many chapters failed
        if failedChapters.count > epubContent.chapters.count / 2 {
            print("   ⚠️ Warning: More than half of chapters failed to extract")
        }
        
        print("      - Total character count: \(trimmedText.count)")
        
        // Extract cover image if available with error handling
        var coverImage: UIImage?
        do {
            if let coverURLString = epubContent.coverImageURL,
               let coverURL = URL(string: coverURLString) {
                // Check if it's a file URL (cached image)
                if coverURL.isFileURL {
                    if FileManager.default.fileExists(atPath: coverURL.path) {
                        coverImage = UIImage(contentsOfFile: coverURL.path)
                        print("      - ✅ Extracted cover image from EPUB")
                    } else {
                        print("      - ⚠️ Cover image file not found: \(coverURL.path)")
                    }
                }
            }
        } catch {
            print("      - ⚠️ Failed to load cover image: \(error.localizedDescription)")
            // Continue without cover - not a critical error
        }
        
        return (trimmedText, coverImage, nil)
    }
    
    // MARK: - Word Document Processing
    private static func processWordDocument(url: URL) -> (text: String?, error: ProcessingError?) {
        print("   📄 Processing Word document...")
        
        // Try with default options (works for both DOC and DOCX)
        do {
            print("   🔄 Attempting Word document extraction...")
            let attributedString = try NSAttributedString(
                url: url,
                options: [:],
                documentAttributes: nil
            )
            let text = String(attributedString.string).trimmingCharacters(in: .whitespacesAndNewlines)
            
            print("   ✅ Successfully extracted text from Word document")
            print("      - Character count: \(text.count)")
            
            if text.isEmpty {
                print("   ⚠️ Word document is empty after extraction")
                return (nil, .textExtractionFailed("Document contains no readable content"))
            }
            
            return (text, nil)
        } catch {
            print("   ⚠️ Word document extraction failed: \(error.localizedDescription)")
            
            // Last resort: try reading as plain text
            print("   🔄 Last resort: Attempting plain text extraction...")
            let textResult = processTextFile(url: url)
            if let plainText = textResult.text {
                print("   ✅ Successfully extracted as plain text")
                return (plainText, nil)
            }
            
            print("   ❌ All extraction methods failed for Word document")
            return (nil, .textExtractionFailed("Unable to extract text from Word document. File may be corrupted or in an unsupported format."))
        }
    }
    
    // MARK: - OCR Processing
    /// Perform OCR on a PDF document using Vision framework
    private static func performOCR(on document: PDFDocument) -> String? {
        print("   🔍 Starting OCR extraction...")
        
        var allText = ""
        let totalPages = document.pageCount
        
        // Limit OCR to first 50 pages to avoid excessive processing time
        let pagesToProcess = min(totalPages, 50)
        print("   📄 Will process \(pagesToProcess) of \(totalPages) pages")
        
        for pageIndex in 0..<pagesToProcess {
            guard let page = document.page(at: pageIndex) else { continue }
            
            // Render page as image
            let pageRect = page.bounds(for: .mediaBox)
            let renderer = UIGraphicsImageRenderer(size: pageRect.size)
            
            let pageImage = renderer.image { context in
                UIColor.white.set()
                context.fill(pageRect)
                
                context.cgContext.translateBy(x: 0, y: pageRect.size.height)
                context.cgContext.scaleBy(x: 1.0, y: -1.0)
                
                page.draw(with: .mediaBox, to: context.cgContext)
            }
            
            // Perform OCR on the page image
            if let pageText = recognizeText(in: pageImage) {
                if !pageText.isEmpty {
                    allText += pageText + "\n\n"
                    print("   ✅ Page \(pageIndex + 1): Extracted \(pageText.count) characters")
                } else {
                    print("   ⚠️ Page \(pageIndex + 1): No text recognized")
                }
            } else {
                print("   ❌ Page \(pageIndex + 1): OCR failed")
            }
        }
        
        let trimmedText = allText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedText.isEmpty {
            print("   ❌ OCR extraction failed: No text recognized")
            return nil
        }
        
        print("   ✅ OCR extraction complete: \(trimmedText.count) total characters")
        return trimmedText
    }
    
    /// Recognize text in a UIImage using Vision framework
    private static func recognizeText(in image: UIImage) -> String? {
        guard let cgImage = image.cgImage else { return nil }
        
        var recognizedText = ""
        let semaphore = DispatchSemaphore(value: 0)
        
        let request = VNRecognizeTextRequest { request, error in
            defer { semaphore.signal() }
            
            guard error == nil else {
                print("      OCR Error: \(error!.localizedDescription)")
                return
            }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                return
            }
            
            // Combine all recognized text
            let textLines = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }
            
            recognizedText = textLines.joined(separator: "\n")
        }
        
        // Configure OCR request for best accuracy
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = true
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
        } catch {
            print("      Failed to perform OCR: \(error.localizedDescription)")
            return nil
        }
        
        // Wait for OCR to complete (with timeout)
        _ = semaphore.wait(timeout: .now() + 10)
        
        return recognizedText.isEmpty ? nil : recognizedText
    }
    
    // MARK: - Formatting Extraction Methods
    
    /// Extract formatting hints from EPUB content
    private static func extractFormattingFromEPUB(content: String) -> AttributedContent {
        var hints: [FormattingHint] = []
        let nsString = content as NSString
        
        // Detect headings (usually in all caps or preceded by "CHAPTER")
        let headingPatterns = [
            "(?m)^[A-Z][A-Z\\s]{10,}$",  // All caps lines (likely headings)
            "(?m)^CHAPTER\\s+[IVXLCDM0-9]+.*$",  // Chapter headings
            "(?m)^PROLOGUE.*$",
            "(?m)^EPILOGUE.*$"
        ]
        
        for pattern in headingPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let matches = regex.matches(in: content, range: NSRange(location: 0, length: nsString.length))
                for match in matches {
                    hints.append(FormattingHint(range: match.range, type: .heading(level: 1)))
                }
            }
        }
        
        // Detect emphasis through punctuation patterns
        // Words in ALL CAPS (likely emphasis)
        if let emphasisRegex = try? NSRegularExpression(pattern: "\\b[A-Z]{3,}\\b", options: []) {
            let matches = emphasisRegex.matches(in: content, range: NSRange(location: 0, length: nsString.length))
            for match in matches where match.range.length < 20 {  // Avoid matching long all-caps sections
                hints.append(FormattingHint(range: match.range, type: .emphasis))
            }
        }
        
        // Detect quoted text
        if let quoteRegex = try? NSRegularExpression(pattern: "\"[^\"]{10,200}\"", options: []) {
            let matches = quoteRegex.matches(in: content, range: NSRange(location: 0, length: nsString.length))
            for match in matches {
                hints.append(FormattingHint(range: match.range, type: .quote))
            }
        }
        
        print("   📝 EPUB formatting: Found \(hints.count) hints")
        return AttributedContent(plainText: content, formattingHints: hints)
    }
    
    /// Extract formatting from attributed string (Word documents)
    private static func extractFormattingFromAttributedString(content: String) -> AttributedContent {
        // For Word documents, we already have plain text
        // Try to detect markdown-like patterns and structure
        return extractFormattingFromPlainText(content: content)
    }
    
    /// Extract basic formatting from plain text using markdown-style patterns
    private static func extractFormattingFromPlainText(content: String) -> AttributedContent {
        var hints: [FormattingHint] = []
        let nsString = content as NSString
        
        // Detect markdown-style bold: **text** or __text__
        let boldPatterns = ["\\*\\*([^*]+)\\*\\*", "__([^_]+)__"]
        for pattern in boldPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let matches = regex.matches(in: content, range: NSRange(location: 0, length: nsString.length))
                for match in matches {
                    if match.numberOfRanges > 1 {
                        let innerRange = match.range(at: 1)  // Get the text inside markers
                        hints.append(FormattingHint(range: innerRange, type: .bold))
                    }
                }
            }
        }
        
        // Detect markdown-style italic: *text* or _text_
        let italicPatterns = ["\\*([^*]+)\\*", "_([^_]+)_"]
        for pattern in italicPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let matches = regex.matches(in: content, range: NSRange(location: 0, length: nsString.length))
                for match in matches {
                    if match.numberOfRanges > 1 {
                        let innerRange = match.range(at: 1)
                        // Make sure it's not already marked as bold
                        let isNotBold = !hints.contains { $0.range.intersection(innerRange) != nil && $0.type == .bold }
                        if isNotBold {
                            hints.append(FormattingHint(range: innerRange, type: .italic))
                        }
                    }
                }
            }
        }
        
        // Detect markdown-style headings: # Heading, ## Heading, etc.
        if let headingRegex = try? NSRegularExpression(pattern: "(?m)^(#{1,6})\\s+(.+)$", options: []) {
            let matches = headingRegex.matches(in: content, range: NSRange(location: 0, length: nsString.length))
            for match in matches {
                if match.numberOfRanges > 2 {
                    let hashCount = (nsString.substring(with: match.range(at: 1)) as NSString).length
                    let textRange = match.range(at: 2)
                    hints.append(FormattingHint(range: textRange, type: .heading(level: hashCount)))
                }
            }
        }
        
        // Detect all-caps words (likely emphasis)
        if let capsRegex = try? NSRegularExpression(pattern: "\\b[A-Z]{3,}\\b", options: []) {
            let matches = capsRegex.matches(in: content, range: NSRange(location: 0, length: nsString.length))
            for match in matches where match.range.length < 15 {
                hints.append(FormattingHint(range: match.range, type: .emphasis))
            }
        }
        
        // Detect quoted text
        if let quoteRegex = try? NSRegularExpression(pattern: "\"[^\"]{10,200}\"", options: []) {
            let matches = quoteRegex.matches(in: content, range: NSRange(location: 0, length: nsString.length))
            for match in matches {
                hints.append(FormattingHint(range: match.range, type: .quote))
            }
        }
        
        print("   📝 Plain text formatting: Found \(hints.count) hints")
        return AttributedContent(plainText: content, formattingHints: hints)
    }
    
    /// Convert formatting hints to TTS-friendly text with SSML-style markers
    static func applyFormattingForTTS(content: AttributedContent) -> String {
        var result = content.plainText
        let nsString = result as NSString
        
        // Sort hints by range location (reverse order for replacement)
        let sortedHints = content.formattingHints.sorted { $0.range.location > $1.range.location }
        
        for hint in sortedHints {
            guard hint.range.location >= 0 && hint.range.location + hint.range.length <= nsString.length else {
                continue
            }
            
            let text = nsString.substring(with: hint.range)
            var replacement = text
            
            // Apply emphasis markers based on type
            switch hint.type {
            case .bold, .emphasis:
                replacement = "**\(text)**"  // Double emphasis for TTS
            case .italic:
                replacement = "*\(text)*"  // Single emphasis
            case .heading(let level):
                if level <= 2 {
                    replacement = "**\(text.uppercased())**"  // Strong heading
                } else {
                    replacement = "**\(text)**"
                }
            case .quote:
                replacement = "...\(text)..."  // Pause markers for quotes
            }
            
            result = (result as NSString).replacingCharacters(in: hint.range, with: replacement)
        }
        
        return result
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

