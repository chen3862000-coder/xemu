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
        case duplicateROM

        var errorDescription: String? {
            switch self {
            case .fileAccessFailed:
                return "Failed to access selected ROM file"
            case .invalidROMFormat:
                return "Invalid or unsupported ROM format"
            case .duplicateROM:
                return "This ROM is already in your library"
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
    private let romsDirectory: URL

    init(persistence: PersistenceController, romsDirectory: URL) {
        self.persistence = persistence
        self.romsDirectory = romsDirectory
    }

    #if os(iOS)
    func presentFilePicker(on viewController: UIViewController, completion: @escaping @Sendable (URL?) -> Void) {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.data, .archive])
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

        let validation = try RomValidator.validate(at: url)
        importProgress = 0.3

        let metadata = RomMetadataExtractor.extract(from: fileData, system: validation.system)
        importProgress = 0.4

        let context = persistence.container.viewContext
        let fetchRequest: NSFetchRequest<ROMLibraryEntry> = ROMLibraryEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "checksum == %@", validation.checksum)
        fetchRequest.fetchLimit = 1

        let existingEntries = try context.fetch(fetchRequest)
        guard existingEntries.isEmpty else {
            throw ImportError.duplicateROM
        }

        importProgress = 0.5

        let entry = ROMLibraryEntry(context: context)
        // TODO: Core Data property access - requires Xcode build to generate NSManagedObject subclasses
        // entry.checksum = validation.checksum
        // entry.filename = url.lastPathComponent
        // entry.title = metadata.title
        // entry.platformRaw = validation.system.rawValue
        // entry.fileSize = Int64(fileData.count)
        // entry.importedAt = Date()
        // entry.lastPlayedAt = nil
        // entry.saveStateCount = 0
        // entry.artworkUri = nil
        // entry.eligibleForLeaderboard = false

        let romDestination = romsDirectory.appendingPathComponent("\(validation.checksum).\(url.pathExtension)")
        try FileManager.default.copyItem(at: url, to: romDestination)

        importProgress = 0.8

        try context.save()
        importProgress = 1.0
        importedEntries.append(entry)
        return entry
    }

    func batchImport(urls: [URL]) async throws {
        totalItems = urls.count
        completedItems = 0
        importProgressValue = ImportProgress(total: totalItems, completed: completedItems)

        var results: [Result<ROMLibraryEntry, Error>] = []

        for url in urls {
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
            case .success: return nil
            case .failure(let error): return error
            }
        }
        if let firstError = failures.first {
            throw firstError
        }
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
