import CryptoKit
import Foundation
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

protocol CoverMetadataMatching: Sendable {
    func defaultCoverKey(for checksum: String, normalizedTitle: String, systemRaw: String) -> String?
}

struct NullCoverMetadataMatcher: CoverMetadataMatching {
    func defaultCoverKey(for checksum: String, normalizedTitle: String, systemRaw: String) -> String? {
        nil
    }
}

final class CoverArtService {
    static let shared = CoverArtService()

    private let cache = NSCache<NSString, NSData>()
    private let fileManager = FileManager.default
    private let metadataMatcher: CoverMetadataMatching

    init(metadataMatcher: CoverMetadataMatching = NullCoverMetadataMatcher()) {
        self.metadataMatcher = metadataMatcher
        cache.countLimit = 512
        cache.totalCostLimit = 96 * 1024 * 1024
    }

    func resolve(for entry: ROMLibraryEntry) -> CoverResolutionResult? {
        let cacheKey = cacheKey(for: entry)
        if let cached = cache.object(forKey: cacheKey as NSString) as Data? {
            return CoverResolutionResult(data: cached, source: .embedded)
        }

        if let customData = loadCustomCover(for: entry.id) {
            putInCache(customData, key: cacheKey)
            return CoverResolutionResult(data: customData, source: .customOverride)
        }

        if let embedded = entry.coverImageData, !embedded.isEmpty {
            putInCache(embedded, key: cacheKey)
            return CoverResolutionResult(data: embedded, source: .embedded)
        }

        let normalizedTitle = normalizedTitle(for: entry.title)
        _ = metadataMatcher.defaultCoverKey(
            for: entry.checksum ?? "",
            normalizedTitle: normalizedTitle,
            systemRaw: entry.system ?? ""
        )

        guard let placeholder = makePlaceholderData(title: entry.title ?? "Unknown", systemRaw: entry.system ?? "gbc") else {
            return nil
        }
        putInCache(placeholder, key: cacheKey)
        return CoverResolutionResult(data: placeholder, source: .placeholder)
    }

    func assignDeterministicPlaceholderIfNeeded(to entry: ROMLibraryEntry) {
        guard (entry.coverImageData ?? Data()).isEmpty else { return }
        guard let placeholder = makePlaceholderData(title: entry.title ?? "Unknown", systemRaw: entry.system ?? "gbc") else {
            return
        }
        entry.coverImageData = placeholder
        putInCache(placeholder, key: cacheKey(for: entry))
    }

    @discardableResult
    func saveCustomCoverData(_ data: Data, for entryID: UUID) throws -> URL {
        let outputURL = customCoverURL(for: entryID)
        let encoded = try normalizeCoverDataForStorage(data)
        try ensureCoverDirectoryExists()
        try encoded.write(to: outputURL, options: [.atomic])
        cache.removeObject(forKey: entryID.uuidString as NSString)
        return outputURL
    }

    func removeCustomCover(for entryID: UUID) {
        let url = customCoverURL(for: entryID)
        if fileManager.fileExists(atPath: url.path) {
            try? fileManager.removeItem(at: url)
        }
        cache.removeObject(forKey: entryID.uuidString as NSString)
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

    private func cacheKey(for entry: ROMLibraryEntry) -> String {
        entry.id.uuidString
    }

    private func putInCache(_ data: Data, key: String) {
        cache.setObject(data as NSData, forKey: key as NSString, cost: data.count)
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

    private func loadCustomCover(for entryID: UUID) -> Data? {
        let url = customCoverURL(for: entryID)
        return try? Data(contentsOf: url)
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
        let size = CGSize(width: 600, height: 900)  // 2:3 aspect ratio like real covers
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
