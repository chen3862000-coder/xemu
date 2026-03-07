import CryptoKit
import Foundation
import ImageIO
import os.log
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum CoverResolutionSource: String, Sendable {
    case customOverride
    case embedded
    case placeholder
}

struct CoverResolutionResult: Sendable {
    let data: Data
    let source: CoverResolutionSource
}

final class CoverArtService {
    static let shared = CoverArtService()

    private final class CachedCoverObject: NSObject {
        let data: NSData
        let sourceRaw: NSString

        init(data: Data, source: CoverResolutionSource) {
            self.data = data as NSData
            self.sourceRaw = source.rawValue as NSString
        }

        var source: CoverResolutionSource {
            CoverResolutionSource(rawValue: sourceRaw as String) ?? .embedded
        }
    }

    private struct CoverRequest: Sendable {
        let id: UUID
        let title: String
        let systemRaw: String
        let embeddedData: Data?
        let romSha1: String?
        let customCoverURLString: String?
    }

    private let cache = NSCache<NSString, CachedCoverObject>()
    private let fileManager = FileManager.default
    private let metadataMatcher: CoverMetadataMatching
    private let logger = Logger(subsystem: "com.xemu.app", category: "CoverArt")
    private let ioQueue = DispatchQueue(label: "com.xemu.cover-art.io", qos: .userInitiated)

    init(metadataMatcher: CoverMetadataMatching = SQLiteCoverMetadataMatcher.makeDefault()) {
        self.metadataMatcher = metadataMatcher
        cache.countLimit = 512
        cache.totalCostLimit = 96 * 1024 * 1024
    }

    func resolve(for entry: ROMLibraryEntry) -> CoverResolutionResult? {
        resolve(request: makeRequest(for: entry), targetPixelSize: 600)
    }

    func resolveAsync(for entry: ROMLibraryEntry, targetPixelSize: Int = 320) async -> CoverResolutionResult? {
        let request = makeRequest(for: entry)
        return await withCheckedContinuation { continuation in
            ioQueue.async { [weak self] in
                guard let self else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: self.resolve(request: request, targetPixelSize: targetPixelSize))
            }
        }
    }

    func metadataMatch(for entry: ROMLibraryEntry) -> CoverMetadataMatch? {
        metadataMatcher.match(
            romSha1: entry.romSha1,
            normalizedTitle: normalizedTitle(for: entry.title),
            systemRaw: entry.system ?? ""
        )
    }

    func metadataMatch(romSha1: String?, title: String?, systemRaw: String?) -> CoverMetadataMatch? {
        metadataMatcher.match(
            romSha1: romSha1,
            normalizedTitle: normalizedTitle(for: title),
            systemRaw: systemRaw ?? ""
        )
    }

    func assignDeterministicPlaceholderIfNeeded(to entry: ROMLibraryEntry) {
        guard (entry.coverImageData ?? Data()).isEmpty else { return }
        guard !customCoverExists(for: entry.id) else { return }
        guard let placeholder = makePlaceholderData(title: entry.title ?? "Unknown", systemRaw: entry.system ?? "gbc") else {
            return
        }
        entry.coverImageData = placeholder
        putInCache(placeholder, key: cacheKey(for: entry.id), source: .placeholder)
    }

    @discardableResult
    func saveCustomCoverData(_ data: Data, for entryID: UUID) throws -> URL {
        let outputURL = customCoverURL(for: entryID)
        let encoded = try normalizeCoverDataForStorage(data)
        try ensureCoverDirectoryExists()
        try encoded.write(to: outputURL, options: [.atomic])
        cache.removeAllObjects()
        NotificationCenter.default.post(
            name: .coverArtDidChange,
            object: nil,
            userInfo: ["entryID": entryID]
        )
        return outputURL
    }

    func removeCustomCover(for entryID: UUID) {
        let url = customCoverURL(for: entryID)
        if fileManager.fileExists(atPath: url.path) {
            try? fileManager.removeItem(at: url)
        }
        cache.removeAllObjects()
        NotificationCenter.default.post(
            name: .coverArtDidChange,
            object: nil,
            userInfo: ["entryID": entryID]
        )
    }

    func customCoverExists(for entryID: UUID) -> Bool {
        fileManager.fileExists(atPath: customCoverURL(for: entryID).path)
    }

    func customCoverURL(for entryID: UUID) -> URL {
        coverDirectoryURL().appendingPathComponent("\(entryID.uuidString.lowercased()).jpg")
    }

    func normalizedTitle(for value: String?) -> String {
        var title = (value ?? "")
            .lowercased()
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")

        title = title.replacingOccurrences(
            of: #"\[[^\]]*\]|\([^)]*\)"#,
            with: " ",
            options: .regularExpression
        )
        title = title.replacingOccurrences(
            of: #"\b(usa|eur|jpn|rev\s*[a-z0-9]+|v\d+(\.\d+)?)\b"#,
            with: " ",
            options: .regularExpression
        )
        title = title.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func cacheKey(for entryID: UUID) -> String {
        entryID.uuidString.lowercased()
    }

    private func putInCache(_ data: Data, key: String, source: CoverResolutionSource) {
        cache.setObject(CachedCoverObject(data: data, source: source), forKey: key as NSString, cost: data.count)
    }

    private func makeRequest(for entry: ROMLibraryEntry) -> CoverRequest {
        CoverRequest(
            id: entry.id,
            title: entry.title ?? "Unknown",
            systemRaw: entry.system ?? "gbc",
            embeddedData: entry.coverImageData,
            romSha1: entry.romSha1,
            customCoverURLString: entry.customCoverURL
        )
    }

    private func resolve(request: CoverRequest, targetPixelSize: Int) -> CoverResolutionResult? {
        let key = cacheKey(for: request.id)
        if let cached = cache.object(forKey: key as NSString) {
            let result = CoverResolutionResult(data: cached.data as Data, source: cached.source)
            logResolution(for: request, source: result.source, cacheHit: true, placeholderReason: nil)
            return result
        }

        if let customData = loadCustomCover(for: request) {
            let prepared = downsampleDataIfNeeded(customData, maxPixelSize: targetPixelSize)
            putInCache(prepared, key: key, source: .customOverride)
            logResolution(for: request, source: .customOverride, cacheHit: false, placeholderReason: nil)
            return CoverResolutionResult(data: prepared, source: .customOverride)
        }

        if let embedded = request.embeddedData, !embedded.isEmpty {
            let prepared = downsampleDataIfNeeded(embedded, maxPixelSize: targetPixelSize)
            putInCache(prepared, key: key, source: .embedded)
            logResolution(for: request, source: .embedded, cacheHit: false, placeholderReason: nil)
            return CoverResolutionResult(data: prepared, source: .embedded)
        }

        let normalized = normalizedTitle(for: request.title)
        let metadataMatch = metadataMatcher.match(
            romSha1: request.romSha1,
            normalizedTitle: normalized,
            systemRaw: request.systemRaw
        )

        let placeholderTitle = metadataMatch?.canonicalTitle ?? request.title
        guard let placeholder = makePlaceholderData(title: placeholderTitle, systemRaw: request.systemRaw) else {
            return nil
        }

        let reason: String
        if request.romSha1?.isEmpty ?? true {
            reason = "missing_rom_sha1"
        } else if metadataMatch == nil {
            reason = "metadata_no_match"
        } else {
            reason = "metadata_matched_placeholder"
        }

        let prepared = downsampleDataIfNeeded(placeholder, maxPixelSize: targetPixelSize)
        putInCache(prepared, key: key, source: .placeholder)
        logResolution(for: request, source: .placeholder, cacheHit: false, placeholderReason: reason)
        return CoverResolutionResult(data: prepared, source: .placeholder)
    }

    private func logResolution(
        for request: CoverRequest,
        source: CoverResolutionSource,
        cacheHit: Bool,
        placeholderReason: String?
    ) {
        let reason = placeholderReason ?? "n/a"
        logger.debug(
            "cover.resolve id=\(request.id.uuidString, privacy: .private(mask: .hash)) source=\(source.rawValue, privacy: .public) cache=\(cacheHit ? "hit" : "miss", privacy: .public) placeholder_reason=\(reason, privacy: .public)"
        )
    }

    private func coverDirectoryURL() -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return base
            .appendingPathComponent("AppHost", isDirectory: true)
            .appendingPathComponent("Covers", isDirectory: true)
    }

    private func ensureCoverDirectoryExists() throws {
        var dir = coverDirectoryURL()
        if !fileManager.fileExists(atPath: dir.path) {
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try dir.setResourceValues(values)
        }
    }

    private func loadCustomCover(for request: CoverRequest) -> Data? {
        if let storedPath = request.customCoverURLString,
           !storedPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let url = URL(fileURLWithPath: storedPath)
            if let data = try? Data(contentsOf: url) {
                return data
            }
        }
        let fallback = customCoverURL(for: request.id)
        return try? Data(contentsOf: fallback)
    }

    private func downsampleDataIfNeeded(_ data: Data, maxPixelSize: Int) -> Data {
        guard maxPixelSize > 0 else { return data }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return data
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]

        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return data
        }

        let encoded = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            encoded,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            return data
        }
        let props: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: 0.82
        ]
        CGImageDestinationAddImage(destination, image, props as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            return data
        }
        return encoded as Data
    }

    private func normalizeCoverDataForStorage(_ data: Data) throws -> Data {
        let targetSize: CGFloat = 600

        #if canImport(UIKit)
        guard let image = UIImage(data: data) else {
            throw NSError(domain: "CoverArtService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to decode image data"])
        }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: targetSize, height: targetSize), format: format)
        let rendered = renderer.image { _ in
            UIColor.black.setFill()
            UIBezierPath(rect: CGRect(origin: .zero, size: CGSize(width: targetSize, height: targetSize))).fill()
            image.draw(in: Self.aspectFillRect(imageSize: image.size, target: CGSize(width: targetSize, height: targetSize)))
        }
        return rendered.jpegData(compressionQuality: 0.8) ?? data
        #elseif canImport(AppKit)
        guard let image = NSImage(data: data) else {
            throw NSError(domain: "CoverArtService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to decode image data"])
        }
        let size = NSSize(width: targetSize, height: targetSize)
        let canvas = NSImage(size: size)
        canvas.lockFocus()
        NSColor.black.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        image.draw(in: NSRect(origin: .zero, size: size), from: .zero, operation: .sourceOver, fraction: 1)
        canvas.unlockFocus()
        guard let tiff = canvas.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let jpeg = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
            return data
        }
        return jpeg
        #else
        return data
        #endif
    }

    private static func aspectFillRect(imageSize: CGSize, target: CGSize) -> CGRect {
        let scale = max(target.width / max(imageSize.width, 1), target.height / max(imageSize.height, 1))
        let width = imageSize.width * scale
        let height = imageSize.height * scale
        return CGRect(
            x: (target.width - width) * 0.5,
            y: (target.height - height) * 0.5,
            width: width,
            height: height
        )
    }

    private func makePlaceholderData(title: String, systemRaw: String) -> Data? {
        #if canImport(UIKit)
        let size = CGSize(width: 600, height: 600)
        let seed = placeholderSeed(title: title, systemRaw: systemRaw)
        
        // Console-based color palette (not rainbow - controlled tones)
        let consoleColors = consoleColorPalette(for: systemRaw)
        let gradientColors = consoleColors.gradientColors(seed: seed)
        
        // Get first letter for monogram
        let normalized = normalizedTitle(for: title)
        let firstLetter = normalized.isEmpty ? "?" : String(normalized.prefix(1)).uppercased()
        
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let cg = context.cgContext
            
            // Base gradient - subtle top-left highlight
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: gradientColors as CFArray, locations: [0, 1]) {
                cg.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: size.width, y: size.height), options: [])
            }
            
            // Subtle pattern overlay based on console
            drawPattern(cgContext: cg, size: size, console: systemRaw, seed: seed)
            
            // Inner border for depth
            let borderRect = CGRect(x: 1, y: 1, width: size.width - 2, height: size.height - 2)
            cg.setStrokeColor(UIColor.white.withAlphaComponent(0.12).cgColor)
            cg.setLineWidth(1)
            cg.stroke(borderRect)
            
            // Console badge (top-right)
            let consoleTag = systemTag(for: systemRaw)
            drawConsoleBadge(cgContext: cg, tag: consoleTag, size: size)
            
            // Large monogram letter (center)
            drawMonogram(cgContext: cg, letter: firstLetter, size: size, seed: seed)
        }
        return image.pngData()
        #else
        return nil
        #endif
    }
    
    #if canImport(UIKit)
    private struct ConsoleColors {
        let baseHue: CGFloat
        let saturation: CGFloat
        let brightness: CGFloat
        
        var baseColor: UIColor {
            UIColor(hue: baseHue, saturation: saturation, brightness: brightness, alpha: 1)
        }
        
        func gradientColors(seed: [UInt8]) -> [CGColor] {
            let darker = UIColor(hue: baseHue, saturation: saturation * 1.1, brightness: brightness * 0.85, alpha: 1)
            return [baseColor.cgColor, darker.cgColor]
        }
    }
    
    private func consoleColorPalette(for systemRaw: String) -> ConsoleColors {
        let normalized = systemRaw.lowercased()
        
        // GB/GBC: Soft mint/teal - retro handheld feel
        if normalized.contains("gbc") || normalized.contains("gb") {
            return ConsoleColors(baseHue: 0.42, saturation: 0.25, brightness: 0.90)
        }
        // GBA: Soft violet/indigo - iconic purple
        if normalized.contains("gba") {
            return ConsoleColors(baseHue: 0.75, saturation: 0.30, brightness: 0.78)
        }
        // NDS: Cool blue/slate - dual screen feel
        if normalized.contains("nds") {
            return ConsoleColors(baseHue: 0.58, saturation: 0.18, brightness: 0.85)
        }
        // Default: Soft indigo
        return ConsoleColors(baseHue: 0.70, saturation: 0.22, brightness: 0.82)
    }
    
    private func drawPattern(cgContext: CGContext, size: CGSize, console: String, seed: [UInt8]) {
        let normalized = console.lowercased()
        
        cgContext.setFillColor(UIColor.white.withAlphaComponent(0.03).cgColor)
        
        if normalized.contains("gbc") || normalized.contains("gb") {
            // Pixel grid pattern for retro
            let gridSize: CGFloat = 20
            var x: CGFloat = 0
            while x < size.width {
                var y: CGFloat = 0
                while y < size.height {
                    if Int(x / gridSize) % 2 == Int(y / gridSize) % 2 {
                        cgContext.fill(CGRect(x: x, y: y, width: gridSize, height: gridSize))
                    }
                    y += gridSize
                }
                x += gridSize
            }
        } else if normalized.contains("gba") {
            // Diagonal sweep for GBA
            let stripeWidth: CGFloat = 40
            var x: CGFloat = -size.height
            while x < size.width + size.height {
                cgContext.move(to: CGPoint(x: x, y: 0))
                cgContext.addLine(to: CGPoint(x: x + stripeWidth, y: 0))
                cgContext.addLine(to: CGPoint(x: x + stripeWidth + size.height, y: size.height))
                cgContext.addLine(to: CGPoint(x: x + size.height, y: size.height))
                cgContext.closePath()
                cgContext.fillPath()
                x += stripeWidth * 2
            }
        } else if normalized.contains("nds") {
            // Dual rectangle motif for NDS
            let rectWidth: CGFloat = 60
            let rectHeight: CGFloat = 40
            cgContext.setStrokeColor(UIColor.white.withAlphaComponent(0.06).cgColor)
            cgContext.setLineWidth(1)
            var x: CGFloat = 20
            while x < size.width - rectWidth {
                var y: CGFloat = 20
                while y < size.height - rectHeight {
                    cgContext.stroke(CGRect(x: x, y: y, width: rectWidth, height: rectHeight).insetBy(dx: 0.5, dy: 0.5))
                    y += rectHeight + 10
                }
                x += rectWidth + 10
            }
        }
    }
    
    private func drawConsoleBadge(cgContext: CGContext, tag: String, size: CGSize) {
        let badgeFont = UIFont.systemFont(ofSize: 20, weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: badgeFont,
            .foregroundColor: UIColor.white.withAlphaComponent(0.90)
        ]
        let textSize = (tag as NSString).size(withAttributes: attributes)
        let padding: CGFloat = 10
        let badgeWidth = textSize.width + padding * 2
        let badgeHeight = textSize.height + padding * 0.8
        let badgeRect = CGRect(x: size.width - badgeWidth - 16, y: 16, width: badgeWidth, height: badgeHeight)
        
        // Console-specific badge colors (less saturated than before)
        let badgeColor: UIColor
        switch tag.uppercased() {
        case "GBA":
            badgeColor = UIColor(red: 0.55, green: 0.30, blue: 0.75, alpha: 0.85)  // Muted purple
        case "GBC", "GB":
            badgeColor = UIColor(red: 0.20, green: 0.65, blue: 0.60, alpha: 0.85)  // Muted teal
        case "NDS":
            badgeColor = UIColor(red: 0.25, green: 0.45, blue: 0.70, alpha: 0.85)  // Muted blue
        default:
            badgeColor = UIColor.black.withAlphaComponent(0.35)
        }
        
        // Badge background with slight blur effect
        cgContext.setFillColor(badgeColor.cgColor)
        let badgePath = UIBezierPath(roundedRect: badgeRect, cornerRadius: 5)
        cgContext.addPath(badgePath.cgPath)
        cgContext.fillPath()
        
        // Badge text
        let textRect = CGRect(x: badgeRect.origin.x + padding, y: badgeRect.origin.y + padding * 0.4, width: textSize.width, height: textSize.height)
        (tag as NSString).draw(in: textRect, withAttributes: attributes)
    }
    
    private func drawMonogram(cgContext: CGContext, letter: String, size: CGSize, seed: [UInt8]) {
        let fontSize: CGFloat = 320
        let font = UIFont.systemFont(ofSize: fontSize, weight: .heavy)
        
        // Main letter - lighter than background for depth
        let letterAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white.withAlphaComponent(0.35)
        ]
        let letterSize = (letter as NSString).size(withAttributes: letterAttributes)
        let letterRect = CGRect(
            x: (size.width - letterSize.width) / 2,
            y: (size.height - letterSize.height) / 2,
            width: letterSize.width,
            height: letterSize.height
        )
        
        // Draw subtle shadow below
        let shadowAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.black.withAlphaComponent(0.20)
        ]
        let shadowOffset: CGFloat = 10
        let shadowRect = CGRect(
            x: letterRect.origin.x + shadowOffset,
            y: letterRect.origin.y + shadowOffset,
            width: letterSize.width,
            height: letterSize.height
        )
        (letter as NSString).draw(in: shadowRect, withAttributes: shadowAttributes)
        
        // Draw main letter
        (letter as NSString).draw(in: letterRect, withAttributes: letterAttributes)
        
        // Draw subtle highlight from top-left (inner shadow effect)
        let highlightAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white.withAlphaComponent(0.08)
        ]
        let highlightOffset: CGFloat = -4
        let highlightRect = CGRect(
            x: letterRect.origin.x + highlightOffset,
            y: letterRect.origin.y + highlightOffset,
            width: letterSize.width,
            height: letterSize.height
        )
        (letter as NSString).draw(in: highlightRect, withAttributes: highlightAttributes)
    }
    
    private func systemTag(for systemRaw: String) -> String {
        let normalized = systemRaw.lowercased()
        if normalized.contains("gba") { return "GBA" }
        if normalized.contains("gbc") { return "GBC" }
        if normalized.contains("nds") { return "NDS" }
        if normalized.contains("gb") { return "GB" }
        return "NES"
    }
    #endif

    private func placeholderSeed(title: String, systemRaw: String) -> [UInt8] {
        let key = "\(systemRaw.lowercased())|\(normalizedTitle(for: title))"
        return Array(SHA256.hash(data: Data(key.utf8)))
    }
}
