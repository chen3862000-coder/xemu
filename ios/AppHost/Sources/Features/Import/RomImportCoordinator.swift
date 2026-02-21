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
            print("[DEBUG] importROM: Step 1 - Reading file at: \(url.path)")
            print("[DEBUG] importROM: file exists? \(FileManager.default.fileExists(atPath: url.path))")
            let fileData = try Data(contentsOf: url)
            print("[DEBUG] importROM: Step 1 complete - read \(fileData.count) bytes")
            importProgress = 0.2
            
            print("[DEBUG] importROM: Step 2 - Validating ROM")
            let validation = try RomValidator.validate(at: url)
            print("[DEBUG] importROM: Step 2 complete - system: \(validation.system), checksum: \(validation.checksum.prefix(16))...")
            importProgress = 0.3
            
            print("[DEBUG] importROM: Step 3 - Extracting metadata")
            let metadata = RomMetadataExtractor.extract(from: fileData, system: validation.system)
            print("[DEBUG] importROM: Step 3 complete - title: \(metadata.title)")
            importProgress = 0.4
            
            print("[DEBUG] importROM: Step 4 - Checking for duplicates")
            let context = persistence.container.viewContext
            let fetchRequest: NSFetchRequest<ROMLibraryEntry> = ROMLibraryEntry.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "checksum == %@", validation.checksum)
            fetchRequest.fetchLimit = 1
            
            let existingEntries = try context.fetch(fetchRequest)
            if let existingEntry = existingEntries.first {
                print("[DEBUG] importROM: Step 4 - duplicate ROM found, returning existing entry: \(existingEntry.title ?? "Unknown")")
                importProgress = 1.0
                importedEntries.append(existingEntry)
                return existingEntry
            }
            print("[DEBUG] importROM: Step 4 complete - no duplicates")
            importProgress = 0.5
            
            print("[DEBUG] importROM: Step 5 - Creating Core Data entry")
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
            print("[DEBUG] importROM: Step 5 complete - entry created with ID: \(entry.id.uuidString)")
            
            print("[DEBUG] importROM: Step 6 - Copying ROM to storage")
            // Create ROMs directory if it doesn't exist
            if !FileManager.default.fileExists(atPath: romsDirectory.path) {
                print("[DEBUG] importROM: Creating ROMs directory at: \(romsDirectory.path)")
                try FileManager.default.createDirectory(at: romsDirectory, withIntermediateDirectories: true)
                print("[DEBUG] importROM: ROMs directory created")
            }
            let romDestination = romsDirectory.appendingPathComponent("\(validation.checksum).\(url.pathExtension)")
            print("[DEBUG] importROM: destination: \(romDestination.path)")
            try FileManager.default.copyItem(at: url, to: romDestination)
            print("[DEBUG] importROM: Step 6 complete - ROM copied")
            importProgress = 0.8
            
            print("[DEBUG] importROM: Step 7 - Saving Core Data context")
            try context.save()
            print("[DEBUG] importROM: Step 7 complete - context saved")
            importProgress = 1.0
            
            importedEntries.append(entry)
            print("[DEBUG] importROM: SUCCESS - ROM imported successfully")
            return entry
        } catch {
            print("[DEBUG] importROM: FAILED at step with error: \(error)")
            print("[DEBUG] importROM: Error localized description: \(error.localizedDescription)")
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
                    print("[DEBUG] Copied and verified: \(url.lastPathComponent) -> \(tempURL.path)")
                    tempURLs.append(tempURL)
                } else {
                    print("[ERROR] File copy succeeded but file doesn't exist: \(tempURL.path)")
                }
            } catch {
                print("[DEBUG] Failed to copy file \(url.lastPathComponent): \(error)")
            }
        }
        
        completion(tempURLs)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        completion([])
    }
}
#endif
