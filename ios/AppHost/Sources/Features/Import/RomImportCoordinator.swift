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

@MainActor
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
    private var filePickerDelegate: FilePickerDelegate?
    
    func presentFilePicker(on viewController: UIViewController, completion: @escaping @Sendable ([URL]) -> Void) {
        let delegate = FilePickerDelegate { urls in
            completion(urls)
        }
        filePickerDelegate = delegate
        
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [
            UTType(filenameExtension: "gb")!,
            UTType(filenameExtension: "gbc")!,
            UTType(filenameExtension: "gba")!,
            UTType(filenameExtension: "nes")!,
            UTType(filenameExtension: "gen")!,
            UTType(filenameExtension: "md")!,
            UTType(filenameExtension: "bin")!,
            UTType(filenameExtension: "smc")!,
            UTType(filenameExtension: "sfc")!,
            UTType.item
        ])
        documentPicker.allowsMultipleSelection = true
        documentPicker.delegate = delegate
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
        
        do {
            // URL is now a temp file that doesn't need security scope
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
            if let existingEntry = existingEntries.first {
                importProgress = 1.0
                importedEntries.append(existingEntry)
                return existingEntry
            }
            importProgress = 0.5
            
            let entry = ROMLibraryEntry(context: context)
            entry.id = UUID()
            entry.checksum = validation.checksum
            entry.title = metadata.title.isEmpty ? url.deletingPathExtension().lastPathComponent : metadata.title
            entry.system = validation.system.rawValue
            entry.fileName = url.lastPathComponent
            entry.fileSize = Int64(fileData.count)
            entry.dateAdded = Date()
            entry.lastPlayedAt = nil
            entry.playtimeTotal = 0
            entry.isFavorite = false
            
            // Create ROMs directory if it doesn't exist
            if !FileManager.default.fileExists(atPath: romsDirectory.path) {
                try FileManager.default.createDirectory(at: romsDirectory, withIntermediateDirectories: true)
            }
            let romDestination = romsDirectory.appendingPathComponent("\(validation.checksum).\(url.pathExtension)")
            try FileManager.default.copyItem(at: url, to: romDestination)
            importProgress = 0.8
            
            try context.save()
            importProgress = 1.0
            
            importedEntries.append(entry)
            return entry
        } catch {
            throw error
        }
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
    private let completion: ([URL]) -> Void

    init(completion: @escaping ([URL]) -> Void) {
        self.completion = completion
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        // Copy files to temp directory while security scope is active
        let tempDir = FileManager.default.temporaryDirectory
        var tempURLs: [URL] = []
        
        for url in urls {
            let didStartAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if didStartAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            do {
                let tempURL = tempDir.appendingPathComponent(UUID().uuidString + "_" + url.lastPathComponent)
                try FileManager.default.copyItem(at: url, to: tempURL)
                
                // Verify file exists
                if FileManager.default.fileExists(atPath: tempURL.path) {
                    tempURLs.append(tempURL)
                } else {
                    print("[ERROR] File copy succeeded but file doesn't exist: \(tempURL.path)")
                }
            } catch {
                print("Failed to copy file \(url.lastPathComponent): \(error)")
            }
        }
        
        completion(tempURLs)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        completion([])
    }
}
#endif
