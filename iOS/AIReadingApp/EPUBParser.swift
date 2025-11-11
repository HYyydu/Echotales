import Foundation
import ZIPFoundation
import UIKit

/// Service to parse EPUB files and extract their content
class EPUBParser {
    
    // MARK: - Main Parsing Method
    
    /// Parse an EPUB file from the app bundle
    static func parseEPUB(fileName: String, tags: [String]? = nil) -> EPUBContent? {
        guard let epubURL = Bundle.main.url(forResource: fileName.replacingOccurrences(of: ".epub", with: ""), withExtension: "epub") else {
            print("❌ EPUB file not found: \(fileName)")
            return nil
        }
        
        return parseEPUB(at: epubURL, tags: tags)
    }
    
    /// Parse an EPUB file from a given URL
    static func parseEPUB(at url: URL, tags: [String]? = nil) -> EPUBContent? {
        print("🔍 DEBUG EPUBParser: Parsing EPUB at: \(url.lastPathComponent)")
        
        let archive: ZIPFoundation.Archive
        do {
            archive = try ZIPFoundation.Archive(url: url, accessMode: .read)
        } catch {
            print("❌ Failed to open EPUB archive: \(error)")
            return nil
        }
        
        print("   - Archive opened successfully")
        
        // Check if this is an AI-generated book (should use simple chapter names)
        let isAIBook = tags?.contains("AI") ?? false
        if isAIBook {
            print("   - ✨ AI-tagged book detected: will use simple chapter names (Chapter 1, Chapter 2, etc.)")
        }
        
        // Extract metadata and chapters
        var title: String?
        var author: String?
        var chapters: [EPUBChapter] = []
        var coverImageURL: String?
        
        // Find and parse the OPF file (contains metadata and manifest)
        var opfPath: String?
        if let (opfContent, path) = findContentOPFWithPath(in: archive) {
            print("   - OPF file found at: \(path)")
            opfPath = path
            let metadata = parseMetadata(from: opfContent)
            title = metadata.title
            author = metadata.author
            print("   - Title: \(title ?? "nil"), Author: \(author ?? "nil")")
            
            // Extract cover image and cache as PNG
            print("   - Attempting to extract cover image...")
            if let coverImage = extractCoverImage(from: opfContent, archive: archive, opfPath: path) {
                if let fileURL = try? cachePNG(coverImage) {
                    coverImageURL = fileURL.absoluteString
                    print("   - ✅ Cover image cached successfully")
                    print("   - 📍 Full URL: \(fileURL.absoluteString)")
                    print("   - 📁 Filename: \(fileURL.lastPathComponent)")
                    print("   - 🔗 This is what will be stored in coverUrl field")
                } else {
                    print("   - ⚠️ Failed to cache cover image")
                }
            } else {
                print("   - ⚠️ No cover image extracted")
            }
            
            // Extract chapters from OPF spine
            chapters = extractChapters(from: opfContent, archive: archive, useSimpleNames: isAIBook)
            print("   - Chapters extracted: \(chapters.count)")
        } else {
            print("   - ❌ OPF file not found")
        }
        
        return EPUBContent(
            title: title ?? "Unknown Title",
            author: author ?? "Unknown Author",
            chapters: chapters,
            coverImageURL: coverImageURL
        )
    }
    
    // MARK: - Helper Methods
    
    /// Cache a UIImage as PNG and return a file:// URL
    private static func cachePNG(_ img: UIImage) throws -> URL {
        let out = FileManager.default.temporaryDirectory
            .appendingPathComponent("cover-\(UUID().uuidString).png")
        guard let png = img.pngData() else {
            throw NSError(domain: "epub", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to PNG"])
        }
        try png.write(to: out)
        return out
    }
    
    /// Find the OPF file in the EPUB archive (returns content and path)
    private static func findContentOPFWithPath(in archive: ZIPFoundation.Archive) -> (content: String, path: String)? {
        // First, check container.xml to find OPF location
        if let containerEntry = archive["META-INF/container.xml"] {
            var containerData = Data()
            _ = try? archive.extract(containerEntry) { data in
                containerData.append(data)
            }
            
            if let containerXML = String(data: containerData, encoding: .utf8) {
                // Parse container.xml to find OPF path
                if let opfPath = extractOPFPath(from: containerXML) {
                    if let opfEntry = archive[opfPath] {
                        var opfData = Data()
                        _ = try? archive.extract(opfEntry) { data in
                            opfData.append(data)
                        }
                        if let content = String(data: opfData, encoding: .utf8) {
                            return (content, opfPath)
                        }
                    }
                }
            }
        }
        
        // Fallback: look for .opf files
        for entry in archive {
            if entry.path.hasSuffix(".opf") {
                var data = Data()
                _ = try? archive.extract(entry) { chunk in
                    data.append(chunk)
                }
                if let content = String(data: data, encoding: .utf8) {
                    return (content, entry.path)
                }
            }
        }
        
        return nil
    }
    
    /// Find the OPF file in the EPUB archive (backward compatibility)
    private static func findContentOPF(in archive: ZIPFoundation.Archive) -> String? {
        return findContentOPFWithPath(in: archive)?.content
    }
    
    /// Extract OPF file path from container.xml
    private static func extractOPFPath(from xml: String) -> String? {
        // Simple regex to find full-path attribute
        let pattern = "full-path=\"([^\"]+)\""
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: xml, range: NSRange(xml.startIndex..., in: xml)) {
            if let range = Range(match.range(at: 1), in: xml) {
                return String(xml[range])
            }
        }
        return nil
    }
    
    /// Parse metadata from OPF content
    private static func parseMetadata(from opf: String) -> (title: String?, author: String?) {
        var title: String?
        var author: String?
        
        // Extract title
        if let titleMatch = opf.range(of: "<dc:title[^>]*>([^<]+)</dc:title>", options: .regularExpression) {
            let titleText = String(opf[titleMatch])
            title = extractTextBetweenTags(from: titleText)
        }
        
        // Extract author
        if let authorMatch = opf.range(of: "<dc:creator[^>]*>([^<]+)</dc:creator>", options: .regularExpression) {
            let authorText = String(opf[authorMatch])
            author = extractTextBetweenTags(from: authorText)
        }
        
        return (title, author)
    }
    
    /// Extract cover image from EPUB using comprehensive EPUB2/EPUB3 methods
    private static func extractCoverImage(from opf: String, archive: ZIPFoundation.Archive, opfPath: String) -> UIImage? {
        // Get the base path (directory containing the OPF file)
        let basePath = (opfPath as NSString).deletingLastPathComponent
        
        print("   🔍 COVER DEBUG: Starting cover extraction")
        print("   🔍 COVER DEBUG: OPF path: \(opfPath)")
        print("   🔍 COVER DEBUG: Base path: \(basePath)")
        
        // Parse manifest and metadata once
        let manifest = parseManifest(from: opf)
        let metadata = parseMetadataDict(from: opf)
        let spineHrefs = parseSpineHrefs(from: opf, manifest: manifest)
        
        print("   🔍 COVER DEBUG: Parsed manifest items: \(manifest.count)")
        print("   🔍 COVER DEBUG: Parsed spine items: \(spineHrefs.count)")
        
        // Method 1: EPUB3 - Look for <item properties="cover-image">
        print("   🔍 COVER DEBUG: Method 1 - EPUB3 properties='cover-image'...")
        if let coverItem = manifest.first(where: { ($0.properties ?? "").contains("cover-image") }) {
            print("   🔍 COVER DEBUG: Found cover-image item: id=\(coverItem.id), href=\(coverItem.href)")
            print("   🔍 COVER DEBUG: Manifest hrefs are relative to OPF: \(opfPath)")
            // Manifest hrefs are relative to the OPF file
            if let image = extractImageFromArchive(href: coverItem.href, xhtmlPath: opfPath, basePath: basePath, archive: archive) {
                print("   ✅ COVER DEBUG: Extracted cover using EPUB3 properties (size: \(image.size))")
                return image
            }
            print("   ❌ COVER DEBUG: Failed to extract image for cover-image item")
        } else {
            print("   ⚠️ COVER DEBUG: No cover-image property found")
        }
        
        // Method 2: EPUB2 - Look for <meta name="cover" content="id">
        print("   🔍 COVER DEBUG: Method 2 - EPUB2 metadata name='cover'...")
        if let coverId = metadata["cover"] {
            print("   🔍 COVER DEBUG: Found cover metadata with id: \(coverId)")
            if let coverItem = manifest.first(where: { $0.id == coverId }) {
                print("   🔍 COVER DEBUG: Found manifest item: href=\(coverItem.href)")
                print("   🔍 COVER DEBUG: Manifest hrefs are relative to OPF: \(opfPath)")
                // Manifest hrefs are relative to the OPF file
                if let image = extractImageFromArchive(href: coverItem.href, xhtmlPath: opfPath, basePath: basePath, archive: archive) {
                    print("   ✅ COVER DEBUG: Extracted cover using EPUB2 metadata (size: \(image.size))")
                    return image
                }
                print("   ❌ COVER DEBUG: Failed to extract image for metadata cover")
            } else {
                print("   ❌ COVER DEBUG: No manifest item found with id: \(coverId)")
            }
        } else {
            print("   ⚠️ COVER DEBUG: No cover metadata found")
        }
        
        // Method 3: EPUB2 guide - Look for <guide><reference type="cover">
        print("   🔍 COVER DEBUG: Method 3 - EPUB2 guide reference...")
        if let guideCoverHref = parseGuideCoverHref(from: opf) {
            print("   🔍 COVER DEBUG: Found guide cover href: \(guideCoverHref)")
            print("   🔍 COVER DEBUG: Guide hrefs are relative to OPF: \(opfPath)")
            // Guide hrefs are relative to the OPF file
            if let image = extractImageFromArchive(href: guideCoverHref, xhtmlPath: opfPath, basePath: basePath, archive: archive) {
                print("   ✅ COVER DEBUG: Extracted cover using guide reference (size: \(image.size))")
                return image
            }
            print("   ❌ COVER DEBUG: Failed to extract image for guide reference")
        } else {
            print("   ⚠️ COVER DEBUG: No guide cover reference found")
        }
        
        // Method 4: Parse first <img> in first spine document
        print("   🔍 COVER DEBUG: Method 4 - First image in first spine document...")
        for (index, href) in spineHrefs.prefix(3).enumerated() {
            print("   🔍 COVER DEBUG: Checking spine document \(index + 1): \(href)")
            // Spine hrefs are relative to the OPF file, so construct full path
            let spineDocPath = basePath.isEmpty ? href : "\(basePath)/\(href)"
            print("   🔍 COVER DEBUG: Full spine doc path: \(spineDocPath)")
            if let firstImgHref = firstImageHref(inXHTML: href, basePath: basePath, archive: archive) {
                print("   🔍 COVER DEBUG: Found first image href in spine: \(firstImgHref)")
                print("   🔍 COVER DEBUG: Will resolve relative to spine doc: \(spineDocPath)")
                // Pass the actual spine document path for proper resolution
                if let image = extractImageFromArchive(href: firstImgHref, xhtmlPath: spineDocPath, basePath: basePath, archive: archive) {
                    print("   ✅ COVER DEBUG: Extracted cover from first spine image (size: \(image.size))")
                    return image
                }
                print("   ❌ COVER DEBUG: Failed to extract image from spine document")
            } else {
                print("   ⚠️ COVER DEBUG: No image found in spine document \(index + 1)")
            }
        }
        print("   ⚠️ COVER DEBUG: No images found in first spine documents")
        
        // Method 5: Look for any image with "cover" or "title" in the name
        print("   🔍 COVER DEBUG: Method 5 - Searching for cover/title images by filename...")
        var foundCoverFiles: [String] = []
        for entry in archive {
            let lowercasePath = entry.path.lowercased()
            if (lowercasePath.contains("cover") || lowercasePath.contains("title")) &&
               (lowercasePath.hasSuffix(".jpg") || lowercasePath.hasSuffix(".jpeg") || 
                lowercasePath.hasSuffix(".png") || lowercasePath.hasSuffix(".gif")) {
                foundCoverFiles.append(entry.path)
            }
        }
        print("   🔍 COVER DEBUG: Found \(foundCoverFiles.count) potential cover files: \(foundCoverFiles)")
        
        for path in foundCoverFiles {
            if let entry = archive[path] {
                var imageData = Data()
                _ = try? archive.extract(entry) { data in
                    imageData.append(data)
                }
                print("   🔍 COVER DEBUG: Trying to load: \(path) (size: \(imageData.count) bytes)")
                if let image = UIImage(data: imageData) {
                    print("   ✅ COVER DEBUG: Extracted cover by filename: \(path) (size: \(image.size))")
                    return image
                }
            }
        }
        
        // Method 6: Get first image in the archive (sorted alphabetically)
        print("   🔍 COVER DEBUG: Method 6 - Looking for first image in archive...")
        var allImages: [(path: String, entry: ZIPFoundation.Entry)] = []
        for entry in archive {
            let path = entry.path.lowercased()
            if (path.hasSuffix(".jpg") || path.hasSuffix(".jpeg") || 
                path.hasSuffix(".png") || path.hasSuffix(".gif")) &&
               !path.contains("thumbnail") && // Skip thumbnails
               !path.contains("icon") { // Skip icons
                allImages.append((entry.path, entry))
            }
        }
        
        // Sort images alphabetically (first image is often the cover)
        allImages.sort { $0.path < $1.path }
        print("   🔍 COVER DEBUG: Found \(allImages.count) total images in EPUB")
        if !allImages.isEmpty {
            print("   🔍 COVER DEBUG: First 5 images: \(allImages.prefix(5).map { $0.path })")
        }
        
        for (path, entry) in allImages {
            var imageData = Data()
            _ = try? archive.extract(entry) { data in
                imageData.append(data)
            }
            if let image = UIImage(data: imageData) {
                print("   ✅ COVER DEBUG: Using first image as cover: \(path) (size: \(image.size))")
                return image
            }
        }
        
        print("   ❌ COVER DEBUG: No cover image found in EPUB after trying all methods")
        return nil
    }
    
    // MARK: - Enhanced OPF Parsing Helpers
    
    /// Parse manifest items from OPF (case-insensitive)
    private static func parseManifest(from opf: String) -> [(id: String, href: String, mediaType: String, properties: String?)] {
        var items: [(id: String, href: String, mediaType: String, properties: String?)] = []
        
        // Pattern to match <item> tags - (?is) for case-insensitive
        let pattern = #"(?is)<item\b[^>]+>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return items
        }
        
        let matches = regex.matches(in: opf, range: NSRange(opf.startIndex..., in: opf))
        
        for match in matches {
            if let range = Range(match.range, in: opf) {
                let itemTag = String(opf[range])
                
                // Extract attributes
                let id = extractAttribute("id", from: itemTag)
                let href = extractAttribute("href", from: itemTag)
                let mediaType = extractAttribute("media-type", from: itemTag)
                let properties = extractAttribute("properties", from: itemTag)
                
                if let id = id, let href = href, let mediaType = mediaType {
                    items.append((id: id, href: href, mediaType: mediaType, properties: properties))
                }
            }
        }
        
        return items
    }
    
    /// Parse metadata dictionary from OPF (case-insensitive, handles both quote styles)
    private static func parseMetadataDict(from opf: String) -> [String: String] {
        var dict: [String: String] = [:]
        
        // Pattern to match <meta name="..." content="..."> - (?is) for case-insensitive
        let pattern = #"(?is)<meta\b[^>]*\bname\s*=\s*(['"])(.*?)\1[^>]*\bcontent\s*=\s*(['"])(.*?)\3[^>]*>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return dict
        }
        
        let matches = regex.matches(in: opf, range: NSRange(opf.startIndex..., in: opf))
        
        for match in matches {
            if let nameRange = Range(match.range(at: 2), in: opf),
               let contentRange = Range(match.range(at: 4), in: opf) {
                let name = String(opf[nameRange])
                let content = String(opf[contentRange])
                dict[name] = content
            }
        }
        
        return dict
    }
    
    /// Parse spine hrefs from OPF (case-insensitive, handles both quote styles)
    private static func parseSpineHrefs(from opf: String, manifest: [(id: String, href: String, mediaType: String, properties: String?)]) -> [String] {
        var hrefs: [String] = []
        
        // Pattern to match <itemref idref="..."> - (?is) for case-insensitive
        let pattern = #"(?is)<itemref\b[^>]*\bidref\s*=\s*(['"])(.*?)\1[^>]*>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return hrefs
        }
        
        let matches = regex.matches(in: opf, range: NSRange(opf.startIndex..., in: opf))
        
        for match in matches {
            if let idrefRange = Range(match.range(at: 2), in: opf) {
                let idref = String(opf[idrefRange])
                
                // Find corresponding href in manifest
                if let item = manifest.first(where: { $0.id == idref }) {
                    hrefs.append(item.href)
                }
            }
        }
        
        return hrefs
    }
    
    /// Parse guide cover href from OPF (case-insensitive, supports cover and cover-image)
    private static func parseGuideCoverHref(from opf: String) -> String? {
        // <reference ... type="cover" ... href="..."> OR type="cover-image"
        // (?is) makes it case-insensitive and . matches newlines
        let pattern = #"(?is)<reference\b[^>]*\btype\s*=\s*(['"])(?:cover|cover-image)\1[^>]*\bhref\s*=\s*(['"])(.*?)\2[^>]*>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: opf, range: NSRange(opf.startIndex..., in: opf)),
              let hrefRange = Range(match.range(at: 3), in: opf) else {
            return nil
        }
        
        return String(opf[hrefRange])
    }
    
    /// Find first image href in XHTML document (with robust parsing)
    private static func firstImageHref(inXHTML href: String, basePath: String, archive: ZIPFoundation.Archive) -> String? {
        // Try to find and read the XHTML file
        let possiblePaths = [
            href,
            "\(basePath)/\(href)",
            "OEBPS/\(href)",
            "OPS/\(href)"
        ]
        
        var htmlData: Data?
        for path in possiblePaths {
            if let entry = archive[normalizeArchivePath(path)] ?? archive[path] {
                var data = Data()
                _ = try? archive.extract(entry) { chunk in
                    data.append(chunk)
                }
                htmlData = data
                break
            }
        }
        
        guard let data = htmlData else {
            return nil
        }
        
        // Try multiple encodings (UTF-8, UTF-16, ISO Latin 1)
        var html: String?
        for encoding in [String.Encoding.utf8, .utf16, .isoLatin1, .ascii] {
            if let decoded = String(data: data, encoding: encoding) {
                html = decoded
                break
            }
        }
        
        guard let htmlContent = html else {
            return nil
        }
        
        // Check for <base href="..."> tag to resolve relative URLs
        // (?is) makes it case-insensitive and . matches newlines
        var baseHref: String?
        let basePattern = #"(?is)<base\b[^>]*\bhref\s*=\s*(['"])(.*?)\1[^>]*>"#
        if let baseRegex = try? NSRegularExpression(pattern: basePattern, options: []),
           let baseMatch = baseRegex.firstMatch(in: htmlContent, range: NSRange(htmlContent.startIndex..., in: htmlContent)),
           let baseRange = Range(baseMatch.range(at: 2), in: htmlContent) {
            baseHref = String(htmlContent[baseRange])
        }
        
        // Try to find first valid image...
        let imagePatterns = [
            #"(?is)<img\b[^>]*\bsrc\s*=\s*"(.*?)"[^>]*>"#,
            #"(?is)<img\b[^>]*\bsrc\s*=\s*'(.*?)'[^>]*>"#,
            #"(?is)<image\b[^>]*\bxlink:href\s*=\s*"(.*?)"[^>]*>"#,
            #"(?is)<image\b[^>]*\bxlink:href\s*=\s*'(.*?)'[^>]*>"#,
            #"(?is)<image\b[^>]*\bhref\s*=\s*"(.*?)"[^>]*>"#,
            #"(?is)<image\b[^>]*\bhref\s*=\s*'(.*?)'[^>]*>"#,
            #"(?is)<svg:image\b[^>]*\bxlink:href\s*=\s*"(.*?)"[^>]*>"#,
            #"(?is)<svg:image\b[^>]*\bxlink:href\s*=\s*'(.*?)'[^>]*>"#,
            #"(?is)<svg:image\b[^>]*\bhref\s*=\s*"(.*?)"[^>]*>"#,
            #"(?is)<svg:image\b[^>]*\bhref\s*=\s*'(.*?)'[^>]*>"#
        ]
        
        for pattern in imagePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let matches = regex.matches(in: htmlContent, range: NSRange(htmlContent.startIndex..., in: htmlContent))
                
                for match in matches {
                    if let srcRange = Range(match.range(at: 1), in: htmlContent) {
                        let src = String(htmlContent[srcRange])
                        
                        // Skip data URLs
                        if src.lowercased().hasPrefix("data:") {
                            print("   🔍 IMAGE DEBUG: Skipping data URL")
                            continue
                        }
                        
                        print("   🔍 IMAGE DEBUG: Found image in XHTML")
                        print("      - XHTML path: \(href)")
                        print("      - Raw src: \(src)")
                        print("      - Base href: \(baseHref ?? "none")")
                        
                        // Resolve relative path
                        let resolvedPath = resolveRelativePath(src, relativeTo: href, basePath: basePath, baseHref: baseHref)
                        print("      - Resolved path: \(resolvedPath)")
                        return resolvedPath
                    }
                }
            }
        }
        
        return nil
    }
    
    /// Resolve `imagePath` against the XHTML location and optional <base href>, return a zip entry path (no leading slash)
    private static func resolveRelativePath(_ imagePath: String, relativeTo xhtmlPath: String, basePath: String, baseHref: String?) -> String {
        print("      🔧 PATH RESOLUTION:")
        print("         - imagePath: \(imagePath)")
        print("         - xhtmlPath: \(xhtmlPath)")
        print("         - baseHref: \(baseHref ?? "none")")
        
        // docDir is the folder that contains the XHTML file
        let docDir = (xhtmlPath as NSString).deletingLastPathComponent
        print("         - docDir: \(docDir)")
        
        // If there is a <base href> inside the XHTML, resolve it relative to the docDir
        let baseDir = baseHref ?? ""
        let effectiveBase = baseDir.isEmpty ? docDir : (docDir + "/" + baseDir)
        print("         - effectiveBase: \(effectiveBase)")
        
        // Handle different types of paths
        var resolvedPath: String
        if imagePath.hasPrefix("/") {
            // Absolute path from root
            resolvedPath = String(imagePath.dropFirst())
        } else if imagePath.hasPrefix("../") || imagePath.hasPrefix("./") {
            // Explicit relative path - use URL resolution
            let baseURL = URL(fileURLWithPath: "/" + effectiveBase)
            let resolved = URL(string: imagePath, relativeTo: baseURL)?.standardized ?? baseURL
            resolvedPath = resolved.path
            while resolvedPath.hasPrefix("/") { resolvedPath.removeFirst() }
        } else {
            // Implicit relative path (like "images/cover.jpg")
            // Simply append to the effective base directory
            resolvedPath = effectiveBase.isEmpty ? imagePath : (effectiveBase + "/" + imagePath)
        }
        
        print("         - resolved path: \(resolvedPath)")
        
        // Normalize the path (resolve ./ and ../)
        let normalized = normalizeArchivePath(resolvedPath)
        print("         - normalized: \(normalized)")
        
        return normalized
    }
    
    /// Normalize archive path (convert backslashes, collapse slashes, resolve ./ and ..)
    private static func normalizeArchivePath(_ path: String) -> String {
        // Convert backslashes, collapse slashes, resolve ./ and ..
        let replaced = path.replacingOccurrences(of: "\\", with: "/")
        var parts: [String] = []
        for p in replaced.split(separator: "/", omittingEmptySubsequences: true) {
            if p == "." { continue }
            if p == ".." { _ = parts.popLast(); continue }
            parts.append(String(p))
        }
        return parts.joined(separator: "/")
    }
    
    /// Extract an attribute value from an XML tag (handles both single and double quotes, case-insensitive)
    private static func extractAttribute(_ name: String, from tag: String) -> String? {
        let pattern = "(?is)\\b\(name)\\s*=\\s*(['\"])(.*?)\\1"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
           let match = regex.firstMatch(in: tag, range: NSRange(tag.startIndex..., in: tag)),
           let range = Range(match.range(at: 2), in: tag) {
            return String(tag[range])
        }
        
        return nil
    }
    
    /// Extract image from archive given href and actual XHTML path (using URL-based resolution)
    private static func extractImageFromArchive(href: String, xhtmlPath: String, basePath: String, archive: ZIPFoundation.Archive) -> UIImage? {
        print("   🔍 ZIP KEY DEBUG: Extracting image from archive")
        print("      - Original href: \(href)")
        print("      - XHTML path: \(xhtmlPath)")
        print("      - Base path: \(basePath)")
        
        // Resolve relative to the actual XHTML file path
        let resolved = normalizeArchivePath(resolveRelativePath(href, relativeTo: xhtmlPath, basePath: basePath, baseHref: nil))
        print("      - Resolved & normalized: \(resolved)")
        
        // 1) Try exact match
        print("      - Trying exact match: \(resolved)")
        if let entry = archive[resolved], let img = extractImageFromEntry(entry, archive: archive) {
            print("      ✅ Found with exact match!")
            return img
        }
        print("      ❌ Exact match failed")
        
        // 2) Try common fallbacks
        let fallbacks = ["OEBPS/\(resolved)", "OPS/\(resolved)", "images/\(resolved)"].map(normalizeArchivePath)
        print("      - Trying fallbacks: \(fallbacks)")
        for guess in fallbacks {
            print("      - Trying: \(guess)")
            if let entry = archive[guess], let img = extractImageFromEntry(entry, archive: archive) {
                print("      ✅ Found with fallback: \(guess)")
                return img
            }
        }
        print("      ❌ All fallbacks failed")
        
        // 3) Case-insensitive fallback
        print("      - Trying case-insensitive search...")
        if let img = findImageCaseInsensitive(path: resolved, archive: archive) {
            print("      ✅ Found with case-insensitive match!")
            return img
        }
        
        print("      ❌ Image not found in archive")
        return nil
    }
    
    /// Extract image from archive entry
    private static func extractImageFromEntry(_ entry: ZIPFoundation.Entry, archive: ZIPFoundation.Archive) -> UIImage? {
        var imageData = Data()
        do {
            try archive.extract(entry) { data in
                imageData.append(data)
            }
        } catch {
            return nil
        }
        
        // Skip if data is too small to be a real image
        guard imageData.count > 100 else {
            return nil
        }
        
        return UIImage(data: imageData)
    }
    
    /// Find image in archive with case-insensitive path matching
    private static func findImageCaseInsensitive(path: String, archive: ZIPFoundation.Archive) -> UIImage? {
        let lowercasePath = path.lowercased()
        
        for entry in archive {
            if entry.path.lowercased() == lowercasePath {
                return extractImageFromEntry(entry, archive: archive)
            }
        }
        
        return nil
    }
    
    /// Extract chapters from OPF and archive
    private static func extractChapters(from opf: String, archive: ZIPFoundation.Archive, useSimpleNames: Bool = false) -> [EPUBChapter] {
        var chapters: [EPUBChapter] = []
        
        // Find spine items (reading order)
        let spinePattern = "<itemref[^>]*idref=\"([^\"]+)\"[^>]*>"
        if let spineRegex = try? NSRegularExpression(pattern: spinePattern) {
            let matches = spineRegex.matches(in: opf, range: NSRange(opf.startIndex..., in: opf))
            
            for (index, match) in matches.enumerated() {
                if let range = Range(match.range(at: 1), in: opf) {
                    let itemId = String(opf[range])
                    
                    // Find the corresponding manifest item
                    if let href = findManifestHref(for: itemId, in: opf) {
                        // Extract chapter content
                        if let content = extractHTMLContent(for: href, from: archive) {
                            // For AI books, use simple chapter names
                            let extractedTitle: String
                            if useSimpleNames {
                                extractedTitle = "Chapter \(index + 1)"
                            } else {
                                // Try to extract a meaningful title from the content
                                extractedTitle = extractChapterTitleFromContent(content) ?? "Chapter \(index + 1)"
                            }
                            
                            let chapter = EPUBChapter(
                                id: UUID().uuidString,
                                title: extractedTitle,
                                content: content,
                                order: index
                            )
                            chapters.append(chapter)
                        }
                    }
                }
            }
        }
        
        // If no spine items found, try to get all HTML files
        if chapters.isEmpty {
            chapters = extractAllHTMLChapters(from: archive, useSimpleNames: useSimpleNames)
        }
        
        return chapters
    }
    
    /// Find manifest href for a given item ID
    private static func findManifestHref(for itemId: String, in opf: String) -> String? {
        let pattern = "<item[^>]*id=\"\(itemId)\"[^>]*href=\"([^\"]+)\"[^>]*>"
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: opf, range: NSRange(opf.startIndex..., in: opf)) {
            if let range = Range(match.range(at: 1), in: opf) {
                return String(opf[range])
            }
        }
        return nil
    }
    
    /// Extract HTML content for a given href (with robust encoding detection)
    private static func extractHTMLContent(for href: String, from archive: ZIPFoundation.Archive) -> String? {
        // Decode URL-encoded characters
        let decodedHref = href.removingPercentEncoding ?? href
        
        // Try different path combinations
        let possiblePaths = [
            decodedHref,
            "OEBPS/\(decodedHref)",
            "OPS/\(decodedHref)",
            "content/\(decodedHref)",
            href,
            "OEBPS/\(href)",
            "OPS/\(href)"
        ]
        
        for path in possiblePaths {
            let normalizedPath = normalizeArchivePath(path)
            
            // Try normalized path
            if let entry = archive[normalizedPath] {
                if let content = extractTextFromEntry(entry, archive: archive) {
                    return cleanHTMLContent(content)
                }
            }
            
            // Try original path
            if normalizedPath != path, let entry = archive[path] {
                if let content = extractTextFromEntry(entry, archive: archive) {
                    return cleanHTMLContent(content)
                }
            }
            
            // Try case-insensitive match
            if let content = findTextCaseInsensitive(path: normalizedPath, archive: archive) {
                return cleanHTMLContent(content)
            }
        }
        
        return nil
    }
    
    /// Extract text from archive entry with multiple encoding support
    private static func extractTextFromEntry(_ entry: ZIPFoundation.Entry, archive: ZIPFoundation.Archive) -> String? {
        var data = Data()
        do {
            try archive.extract(entry) { chunk in
                data.append(chunk)
            }
        } catch {
            return nil
        }
        
        // Try multiple encodings
        for encoding in [String.Encoding.utf8, .utf16, .isoLatin1, .ascii] {
            if let text = String(data: data, encoding: encoding) {
                return text
            }
        }
        
        return nil
    }
    
    /// Find text file in archive with case-insensitive path matching
    private static func findTextCaseInsensitive(path: String, archive: ZIPFoundation.Archive) -> String? {
        let lowercasePath = path.lowercased()
        
        for entry in archive {
            if entry.path.lowercased() == lowercasePath {
                return extractTextFromEntry(entry, archive: archive)
            }
        }
        
        return nil
    }
    
    /// Extract all HTML files as chapters (fallback method)
    private static func extractAllHTMLChapters(from archive: ZIPFoundation.Archive, useSimpleNames: Bool = false) -> [EPUBChapter] {
        var chapters: [EPUBChapter] = []
        var index = 0
        
        for entry in archive {
            if entry.path.hasSuffix(".html") || entry.path.hasSuffix(".xhtml") {
                var data = Data()
                _ = try? archive.extract(entry) { chunk in
                    data.append(chunk)
                }
                
                if let htmlString = String(data: data, encoding: .utf8) {
                    let content = cleanHTMLContent(htmlString)
                    if !content.isEmpty {
                        // For AI books, use simple chapter names
                        let title: String
                        if useSimpleNames {
                            title = "Chapter \(index + 1)"
                        } else {
                            // Try multiple methods to extract a meaningful title
                            title = extractTitleFromHTML(htmlString) 
                                ?? extractChapterTitleFromContent(content) 
                                ?? "Chapter \(index + 1)"
                        }
                        
                        let chapter = EPUBChapter(
                            id: UUID().uuidString,
                            title: title,
                            content: content,
                            order: index
                        )
                        chapters.append(chapter)
                        index += 1
                    }
                }
            }
        }
        
        return chapters.sorted { $0.order < $1.order }
    }
    
    /// Clean HTML content (remove tags, keep text)
    private static func cleanHTMLContent(_ html: String) -> String {
        var content = html
        
        // Remove HTML tags but keep line breaks
        content = content.replacingOccurrences(of: "<br[^>]*>", with: "\n", options: .regularExpression)
        content = content.replacingOccurrences(of: "<p[^>]*>", with: "\n", options: .regularExpression)
        content = content.replacingOccurrences(of: "</p>", with: "\n", options: .regularExpression)
        content = content.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        
        // Decode HTML entities
        content = content.replacingOccurrences(of: "&nbsp;", with: " ")
        content = content.replacingOccurrences(of: "&amp;", with: "&")
        content = content.replacingOccurrences(of: "&lt;", with: "<")
        content = content.replacingOccurrences(of: "&gt;", with: ">")
        content = content.replacingOccurrences(of: "&quot;", with: "\"")
        
        // Clean up whitespace
        content = content.replacingOccurrences(of: "\n\n\n+", with: "\n\n", options: .regularExpression)
        content = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return content
    }
    
    /// Extract chapter title from content (looks for common chapter heading patterns)
    private static func extractChapterTitleFromContent(_ content: String) -> String? {
        // Get the first few lines of content to look for chapter headings
        let lines = content.components(separatedBy: .newlines).prefix(10)
        let searchText = lines.joined(separator: "\n")
        
        // Pattern 1: "CHAPTER 1: THE TITLE" or "CHAPTER 1 - THE TITLE" or just "CHAPTER 1"
        let chapterPatterns = [
            "CHAPTER\\s+(\\d+|[IVXLCDM]+)\\s*:?\\s*([^\n]*)",  // CHAPTER 1: Title or CHAPTER I: Title
            "Chapter\\s+(\\d+|[IVXLCDM]+)\\s*:?\\s*([^\n]*)",  // Chapter 1: Title
            "EPILOGUE\\s*:?\\s*([^\n]*)",                       // EPILOGUE: Title
            "Epilogue\\s*:?\\s*([^\n]*)",                       // Epilogue: Title
            "PROLOGUE\\s*:?\\s*([^\n]*)",                       // PROLOGUE: Title
            "Prologue\\s*:?\\s*([^\n]*)"                        // Prologue: Title
        ]
        
        for pattern in chapterPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: searchText, range: NSRange(searchText.startIndex..., in: searchText)) {
                
                // Extract the full match
                if let matchRange = Range(match.range, in: searchText) {
                    var title = String(searchText[matchRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // Clean up the title (remove extra whitespace)
                    title = title.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                    
                    // If title is not empty and has meaningful content, return it
                    if !title.isEmpty {
                        return title
                    }
                }
            }
        }
        
        return nil
    }
    
    /// Extract title from HTML content
    private static func extractTitleFromHTML(_ html: String) -> String? {
        if let titleRange = html.range(of: "<title[^>]*>([^<]+)</title>", options: .regularExpression) {
            let titleText = String(html[titleRange])
            return extractTextBetweenTags(from: titleText)
        }
        
        if let h1Range = html.range(of: "<h1[^>]*>([^<]+)</h1>", options: .regularExpression) {
            let h1Text = String(html[h1Range])
            return extractTextBetweenTags(from: h1Text)
        }
        
        // Try to extract chapter title from cleaned content
        let cleanedContent = cleanHTMLContent(html)
        return extractChapterTitleFromContent(cleanedContent)
    }
    
    /// Extract text between XML/HTML tags
    private static func extractTextBetweenTags(from text: String) -> String? {
        if let startRange = text.range(of: ">"),
           let endRange = text.range(of: "</", options: .backwards) {
            return String(text[startRange.upperBound..<endRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }
}

// MARK: - Data Models

struct EPUBContent {
    let title: String
    let author: String
    let chapters: [EPUBChapter]
    let coverImageURL: String? // file:// URL to cached PNG or HTTPS URL for uploaded cover
}

struct EPUBChapter {
    let id: String
    let title: String
    let content: String
    let order: Int
}
