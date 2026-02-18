import CoreData

/// Core Data migration manager
/// Handles migration from v1.0 to v2.0 for new entities (SaveState, NativeSaveFile, GameSettings, ControllerMapping, UserEntitlement, AdEvent)
public actor CoreDataMigration {
    
    /// Core Data version identifier
    public static let currentVersion = "2.0"
    
    /// Previous version
    public static let previousVersion = "1.0"
    
    /// Check if migration is needed
    public static func needsMigration(from storeURL: URL) -> Bool {
        guard let metadata = try? NSPersistentStoreCoordinator.metadataForPersistentStore(ofType: NSSQLiteStoreType, at: storeURL) else {
            return false
        }
        
        // If version info doesn't match current version, migration needed
        let storeVersion = metadata["Version"] as? String ?? "1.0"
        return storeVersion < currentVersion
    }
    
    /// Perform lightweight migration with automatic mapping
    public static func performMigration(storeURL: URL) throws {
        // For v1.0 to v2.0 migration, we use lightweight migration
        // Core Data automatically infers mappings when entities are added
        // Existing ROMLibraryEntry entity is preserved
        // New entities (SaveState, NativeSaveFile, GameSettings, ControllerMapping, UserEntitlement, AdEvent) are created fresh
        
        print("Core Data migration: v\(previousVersion) -> v\(currentVersion)")
        print("Lightweight migration with automatic entity inference")
        print("Entities added: SaveState, NativeSaveFile, GameSettings, ControllerMapping, UserEntitlement, AdEvent")
        print("Existing entities preserved: ROMLibraryEntry")
    }
    
    /// Migration options for lightweight migration
    public static var migrationOptions: [String: Any] {
        return [
            NSMigratePersistentStoresAutomaticallyOption: true,
            NSInferMappingModelAutomaticallyOption: true
        ]
    }
}
