import CryptoKit
import Foundation
#if os(iOS)
import UIKit
#endif
import UniformTypeIdentifiers
import CoreData

struct ImportProgress {
    let total: Int
    let completed: Int

    var completedCount: Int {
        completed
    }
}

final class RomImportCoordinator: ObservableObject {
    enum ImportError: LocalizedError {
        case fileAccessFailed
        case invalidROMFormat
        case hashComputationFailed
        case duplicateROM
        case metadataFetchFailed

        var errorDescription: String? {
            switch self {
            case .fileAccessFailed:
                return "Failed to access the selected ROM file"
            case .invalidROMFormat:
                return "Invalid or unsupported ROM format"
            case .hashComputationFailed:
                return "Failed to compute ROM hash"
            case .duplicateROM:
                return "This ROM is already in your library"
            case .metadataFetchFailed:
                return "Failed to fetch ROM metadata"
            }
        }
    }

    @Published var isImporting = false
    @Published var importProgress: Double = 0
    @Published var importedEntries: [ROMLibraryEntry] = []
    @Published var importProgressValue: ImportProgress = ImportProgress(total: 0, completed: 0)

    private var totalItems: Int = 0
    private var completedItems: Int = 0

    private let persistence: PersistenceController
    private let compatibility: [AzureApiStub.CompatibilityEntry]
    let romsDirectory: URL

    init(persistence: PersistenceController, compatibility: [AzureApiStub.CompatibilityEntry] = [], romsDirectory: URL) {
        self.persistence = persistence
        self.compatibility = compatibility
        self.romsDirectory = romsDirectory
    }

    #if os(iOS)
    func presentFilePicker(on viewController: UIViewController, completion: @escaping (URL?) -> Void) {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.data, UTType("public.composite-content"), UTType("org.nes.rom"), UTType("org.gameboy.rom"), UTType("org.gba.rom"), UTType("org.sega.rom")], in: .import)
        documentPicker.delegate = FilePickerDelegate(completion: completion)
        documentPicker.allowsMultipleSelection = true
        viewController.present(documentPicker, animated: true)
    }
    #endif

    func importROM(from url: URL) async throws -> ROMLibraryEntry {
        isImporting = true
        importProgress = 0

        defer {
            isImporting = false
            importProgress = 0
        }

        let fileData = try Data(contentsOf: url)
        importProgress = 0.2

        let hash = try await computeHash(for: fileData)
        importProgress = 0.4

        let context = persistence.container.viewContext
        let fetchRequest: NSFetchRequest<ROMLibraryEntry> = ROMLibraryEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "romHash == %@", hash)
        fetchRequest.fetchLimit = 1

        let existingEntries = try context.fetch(fetchRequest)
        guard existingEntries.isEmpty else {
            throw ImportError.duplicateROM
        }

        importProgress = 0.5

        let platform = try detectPlatform(from: fileData, fileName: url.lastPathComponent)
        importProgress = 0.6

        let compatibilityEntry = compatibility.first { $0.romHash == hash }
        let tier = Tier(rawValue: compatibilityEntry?.tier.lowercased() ?? "unknown") ?? .unknown

        let entry = ROMLibraryEntry(context: context)
        entry.entryId = UUID()
        entry.userId = UUID()
        entry.romHash = hash
        entry.title = deriveTitle(from: url.lastPathComponent, platform: platform)
        entry.platform = platform.rawValue
        entry.tier = tier.rawValue
        entry.artworkUri = nil
        entry.playtimeTotal = 0
        entry.completionState = CompletionState.notStarted.rawValue
        entry.perGameSettings = nil
        entry.lastPlayedAt = nil
        entry.eligibleForLeaderboard = tier == .stable

        let romDestination = romsDirectory.appendingPathComponent("\(hash).rom")
        try FileManager.default.copyItem(at: url, to: romDestination)

        importProgress = 0.8

        try context.save()
        importProgress = 1.0
        importedEntries.append(entry)
        return entry
    }

    func importROM(from url: URL) throws -> ROMLibraryEntry {
        isImporting = true
        importProgress = 0

        defer {
            isImporting = false
            importProgress = 0
        }

        let fileData = try Data(contentsOf: url)
        importProgress = 0.2

        let hash = try computeSHA256Hash(for: fileData)
        importProgress = 0.4

        let context = persistence.container.viewContext
        let fetchRequest: NSFetchRequest<ROMLibraryEntry> = ROMLibraryEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "romHash == %@", hash)
        fetchRequest.fetchLimit = 1

        let existingEntries = try context.fetch(fetchRequest)
        guard existingEntries.isEmpty else {
            throw ImportError.duplicateROM
        }

        importProgress = 0.5

        let platform = detectPlatform(from: url.lastPathComponent)
        importProgress = 0.6

        let compatibilityEntry = compatibility.first { $0.romHash == hash }
        let tier = Tier(rawValue: compatibilityEntry?.tier.lowercased() ?? "unknown") ?? .unknown

        let entry = ROMLibraryEntry(context: context)
        entry.entryId = UUID()
        entry.userId = UUID()
        entry.romHash = hash
        entry.title = deriveTitle(from: url.lastPathComponent)
        entry.platform = platform?.rawValue ?? "unknown"
        entry.tier = tier.rawValue
        entry.artworkUri = nil
        entry.playtimeTotal = 0
        entry.completionState = CompletionState.notStarted.rawValue
        entry.perGameSettings = nil
        entry.lastPlayedAt = nil
        entry.eligibleForLeaderboard = tier == .stable

        let romDestination = romsDirectory.appendingPathComponent("\(hash).rom")
        try FileManager.default.copyItem(at: url, to: romDestination)

        importProgress = 0.8

        try context.save()
        importProgress = 1.0

        return entry
    }

    func batchImport(urls: [URL]) async throws {
        totalItems = urls.count
        completedItems = 0
        importProgressValue = ImportProgress(total: totalItems, completed: completedItems)

        var results: [Result<ROMLibraryEntry, Error>] = []

        for (index, url) in urls.enumerated() {
            do {
                let entry = try await importROM(from: url)
                results.append(.success(entry))
            } catch {
                results.append(.failure(error))
            }
            completedItems += 1
            importProgressValue = ImportProgress(total: totalItems, completed: completedItems)
        }

        let failures = results.compactMap { result -> Error? in
            switch result {
            case .success:
                return nil
            case .failure(let error):
                return error
            }
        }
        if let firstError = failures.first {
            throw firstError
        }
    }

    private func computeHash(for data: Data) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let digest = SHA256.hash(data: data)
                let hash = digest.compactMap { String(format: "%02x", $0) }.joined()
                continuation.resume(returning: hash)
            }
        }
    }

    func computeSHA256Hash(for data: Data) throws -> String {
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func detectPlatform(from data: Data, fileName: String) throws -> Platform {
        let signature = data.prefix(16)

        if signature.starts(with: [0x4E, 0x45, 0x53, 0x1A]) {
            return .NES
        } else if signature.starts(with: [0xC3, 0x00, 0x00, 0x00, 0x00]) {
            return .GBA
        } else if signature.starts(with: [0xCE, 0xED, 0x66, 0x66, 0xCC, 0x0D, 0x00, 0x0B]) {
            return .GB
        } else if signature.starts(with: [0x53, 0x45, 0x47, 0x41]) {
            return .GENESIS
        } else if signature.starts(with: [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]) {
            return .NDS
        }

        let lowercased = fileName.lowercased()
        if lowercased.hasSuffix(".nes") { return .NES }
        if lowercased.hasSuffix(".gba") { return .GBA }
        if lowercased.hasSuffix(".gb") || lowercased.hasSuffix(".gbc") { return .GB }
        if lowercased.hasSuffix(".md") || lowercased.hasSuffix(".gen") { return .GENESIS }
        if lowercased.hasSuffix(".nds") { return .NDS }

        return .NES
    }

    func detectPlatform(from fileName: String) -> Platform? {
        let lowercased = fileName.lowercased()
        if lowercased.hasSuffix(".nes") { return .NES }
        if lowercased.hasSuffix(".gba") { return .GBA }
        if lowercased.hasSuffix(".gb") || lowercased.hasSuffix(".gbc") { return .GB }
        if lowercased.hasSuffix(".gen") { return .GENESIS }
        if lowercased.hasSuffix(".nds") { return .NDS }
        if lowercased.hasSuffix(".iso") { return .PS1 }
        if lowercased.hasSuffix(".3ds") { return ._3DS }
        return nil
    }

    private func deriveTitle(from fileName: String, platform: Platform) -> String {
        var title = (fileName as NSString).deletingPathExtension
        title = title.replacingOccurrences(of: "_", with: " ")
        title = title.replacingOccurrences(of: ".", with: " ")
        return title.trimmingCharacters(in: .whitespaces)
    }

    func deriveTitle(from fileName: String) -> String {
        var title = (fileName as NSString).deletingPathExtension
        title = title.replacingOccurrences(of: "_", with: " ")
        title = title.replacingOccurrences(of: ".", with: " ")
        return title.trimmingCharacters(in: .whitespaces)
    }
}

#if os(iOS)
private final class FilePickerDelegate: NSObject, UIDocumentPickerDelegate {
    private let completion: (URL?) -> Void

    init(completion: @escaping (URL?) -> Void) {
        self.completion = completion
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else {
            completion(nil)
            return
        }

        if url.startAccessingSecurityScopedResource() {
            defer { url.stopAccessingSecurityScopedResource() }
            completion(url)
        } else {
            completion(url)
        }
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        completion(nil)
    }
}
#endif



