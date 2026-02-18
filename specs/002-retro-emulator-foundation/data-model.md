# Data Model

**Feature**: Retro Emulator Foundation  
**Phase**: 1 - Design & Contracts  
**Date**: 2025-02-18

## Overview

This data model defines entities, relationships, and validation rules for the retro emulator application. The model extends the existing Core Data schema in the POC with entities required by the feature specification. All entities leverage Core Data for persistence with SwiftUI for UI integration.

## Core Data Entities

### 1. ROMLibraryEntry

**Description**: Represents a ROM file imported into the user's library.

**Fields**:
- `id`: UUID (primary key)
- `file_path`: String - Location of ROM file on device storage
- `checksum`: String - SHA-256 or CRC32 hash for file validation
- `system`: String - Identified system (NES, GB, GBC, GBA, Genesis, NDS, PS1) - maps to `Platform` enum
- `game_name`: String? - Extracted or user-provided name
- `display_name`: String? - User-customizable display name
- `file_size`: Int64 - Size in bytes
- `import_timestamp`: Date - When ROM was added to library
- `playtime`: Int64 - Total time played (in seconds)
- `last_played`: Date? - Most recent play session timestamp
- `thumbnail`: Data? - Screenshot or box art image data
- `platform`: String - Platform enum value (from CommonTypes.Platform)
- `tier`: String - Stability tier (stable/experimental) - from CommonTypes.Tier
- `is_favorite`: Bool - User favorited flag

**Validation Rules**:
- `checksum` must be unique across all entries (enforce duplicate detection)
- `system` must be one of supported platforms (NES, GB, GBC, GBA, Genesis, NDS, PS1)
- `file_path` must point to existing file in user-accessible storage
- `file_size` must be > 0

**Relationships**:
- One-to-Many: `ROMLibraryEntry` has many `SaveState` entries
- One-to-One: `ROMLibraryEntry` has one `GameSettings` entry
- One-to-Many: `ROMLibraryEntry` has many `NativeSaveFile` entries

**Indexes**:
- Unique index on `checksum`
- Index on `system` for filtering
- Index on `playtime` for sorting

---

### 2. SaveState

**Description**: A complete snapshot of emulator state at a specific moment in gameplay.

**Fields**:
- `id`: UUID (primary key)
- `rom_id`: UUID - Foreign key to `ROMLibraryEntry`
- `name`: String - User-provided or auto-generated name (e.g., "Boss Fight - Level 3")
- `timestamp`: Date - When save state was created
- `screenshot_thumbnail`: Data - Image preview of save state (PNG/JPEG compressed)
- `file_size`: Int64 - Size in bytes
- `is_valid`: Bool - Indicates if save state loads successfully
- `slot_number`: Int16 - Slot number (1-10 per game, per spec minimum)

**Validation Rules**:
- `slot_number` must be between 1 and 10
- `name` must not be empty
- `screenshot_thumbnail` must not be empty (required for UI preview)
- `file_size` must be < 5MB (per spec requirement)

**Relationships**:
- Many-to-One: Many `SaveState` entries belong to one `ROMLibraryEntry`

**Indexes**:
- Index on `rom_id`
- Index on `timestamp` for sorting
- Index on `slot_number`

---

### 3. NativeSaveFile

**Description**: Represents an in-game save file (SRAM, battery-backed RAM) from a game.

**Fields**:
- `id`: UUID (primary key)
- `rom_id`: UUID - Foreign key to `ROMLibraryEntry`
- `file_path`: String - Location of save file in device storage
- `file_size`: Int64 - Size in bytes
- `last_modified`: Date - Last time save file was modified
- `backup_count`: Int16 - Number of backup versions available

**Validation Rules**:
- `file_path` must point to existing file
- `file_size` must be > 0
- `last_modified` must be <= current date

**Relationships**:
- Many-to-One: Many `NativeSaveFile` entries belong to one `ROMLibraryEntry`

**Indexes**:
- Index on `rom_id`

---

### 4. GameSettings

**Description**: User-configurable settings for a specific game.

**Fields**:
- `id`: UUID (primary key)
- `rom_id`: UUID - Foreign key to `ROMLibraryEntry` (unique)
- `display_mode`: String? - Aspect ratio, scaling settings ("aspectOriginal", "aspectFill", "scaleInteger")
- `video_filter`: String? - CRT, scanline, or null ("none")
- `touch_controls_layout`: String? - Virtual button layout ("default", "compact", "expanded")
- `touch_controls_opacity`: Double? - Button transparency (0.0-1.0)
- `audio_volume`: Int16 - Volume level (0-100)
- `audio_muted`: Bool - Mute state
- `frame_skip`: Int16? - Frame skipping (0-2)
- `audio_rate`: Int16? - Audio sample rate

**Validation Rules**:
- `rom_id` must be unique (one settings per game)
- `audio_volume` must be between 0 and 100
- `touch_controls_opacity` must be between 0.0 and 1.0

**Relationships**:
- One-to-One: One `GameSettings` belongs to one `ROMLibraryEntry`

**Indexes**:
- Unique index on `rom_id`

---

### 5. ControllerMapping

**Description**: Configuration of which controller button corresponds to which emulator input.

**Fields**:
- `id`: UUID (primary key)
- `system`: String - System this mapping applies to (NES, GB, etc.)
- `controller_id`: String - Identifier for specific controller profile (e.g., "XboxElite2", "DualSense")
- `button_mappings`: Data - JSON-encoded dictionary mapping controller buttons to emulator inputs
- `is_default`: Bool - Indicates if this is default mapping
- `created_at`: Date - When mapping was created
- `modified_at`: Date? - Last time mapping was modified

**Validation Rules**:
- `system` must be one of supported platforms
- `button_mappings` must not be empty
- `is_default` must be true for at most one mapping per system/controller pair

**Relationships**:
- Many-to-One: Many mappings per system (system field groups them)
- Many-to-One: Many mappings per controller type (controller_id field groups them)

**Indexes**:
- Index on `system`
- Index on `controller_id`
- Unique index on (`system`, `controller_id`, `is_default`)

---

### 6. UserEntitlement

**Description**: Represents user's access rights and purchases.

**Fields**:
- `id`: UUID (primary key)
- `device_id`: String - Device identifier (from Keychain or unique ID)
- `entitlement_type`: String - Type of entitlement ("REMOVE_ADS", "EXPERIMENTAL_PACK", "PRO_BUNDLE") - maps to `ProductCode` enum
- `purchase_date`: Date - When entitlement was acquired
- `expiry_date`: Date? - When entitlement expires (null for lifetime)
- `is_active`: Bool - Current status
- `server_validated`: Bool - If server verification completed
- `validation_timestamp`: Date? - Last server validation timestamp
- `product_code`: String - Product code from App Store ("REMOVE_ADS")

**Validation Rules**:
- `entitlement_type` must be one of valid product codes
- `device_id` must be unique
- `is_active` must be false if `expiry_date` < current date (and not null)

**Relationships**:
- One-to-Many: One device can have multiple entitlements (future expansion, currently single)

**Indexes**:
- Unique index on `device_id`
- Index on `entitlement_type`
- Index on `is_active`

---

### 7. AdEvent

**Description**: Record of ad display and interaction for analytics.

**Fields**:
- `id`: UUID (primary key)
- `user_id`: String - Device identifier (from UserEntitlement.device_id)
- `ad_placement`: String - Where ad was shown ("library_load", "library_scroll", "game_exit") - per spec only library placement
- `ad_format`: String - Type of ad ("banner", "interstitial", "rewarded") - per spec only "banner"
- `timestamp`: Date - When ad was displayed
- `was_shown`: Bool - Indicates if ad actually displayed
- `was_clicked`: Bool - Indicates if user tapped ad
- `load_failed`: Bool - Indicates if ad failed to load
- `failure_reason`: String? - Description of why ad failed (if applicable)

**Validation Rules**:
- `ad_placement` must be one of valid placements (currently only "library_load" per spec)
- `ad_format` must be "banner" per spec requirement
- `timestamp` must be <= current date
- `was_shown` and `was_clicked` cannot both be true (mutually exclusive states)

**Relationships**:
- Many-to-One: Many events per user (user_id links to UserEntitlement)

**Indexes**:
- Index on `user_id`
- Index on `timestamp` for analytics queries

---

## State Transitions

### ROMLibraryEntry State Machine

```
[Import] → [Validated] → [In Library] → [Active] ↔ [Paused]
                  ↓
               [Invalid] → [Error]
                  ↓
               [Duplicate] → [User Decision] → [Replace/Keep Both]
```

**States**:
- **Import**: ROM file is being imported and validated
- **Validated**: Checksum verification passed, system detected
- **In Library**: ROM is available in library but not yet played
- **Active**: ROM is currently being emulated
- **Paused**: Emulation is paused (user can resume)
- **Invalid**: ROM failed validation (corrupted, unsupported system)
- **Error**: ROM import failed due to file access or other error

### SaveState Lifecycle

```
[Create] → [Validating] → [Storing] → [Available] → [Loading] → [Loaded]
                             ↓                              ↓
                          [Invalid]                    [Corrupt]
```

**States**:
- **Create**: User requests save state creation
- **Validating**: Emulator state is being captured
- **Storing**: Save state is being written to storage
- **Available**: Save state is ready to be loaded
- **Loading**: Save state is being restored into emulator
- **Loaded**: Save state successfully restored
- **Invalid**: Save state validation failed (version mismatch, corrupted)
- **Corrupt**: Save state file is unreadable

### UserEntitlement Lifecycle

```
[Purchased] → [Validating] → [Server Confirmed] → [Active] ↔ [Offline Grace]
                  ↓                  ↓
               [Invalid]            [Expired] → [Revoked/Refunded]
```

**States**:
- **Purchased**: IAP purchase completed locally
- **Validating**: Server is verifying receipt
- **Server Confirmed**: Server confirmed purchase is valid
- **Active**: Entitlement is currently active (ads removed)
- **Offline Grace**: App is offline but using cached entitlement (< 7 days)
- **Invalid**: Receipt validation failed
- **Expired**: Entitlement period has passed
- **Revoked**: Entitlement was revoked by Apple or server

---

## Validation Rules Summary

| Entity | Validation Rule | Enforced By |
|---------|-----------------|---------------|
| ROMLibraryEntry | Checksum must be unique | Core Data unique index |
| ROMLibraryEntry | System must be supported | Entity model validation |
| SaveState | Slot number 1-10 | Entity model validation |
| SaveState | File size < 5MB | Entity model validation |
| GameSettings | Audio volume 0-100 | Entity model validation |
| ControllerMapping | System must be supported | Entity model validation |
| UserEntitlement | Device ID must be unique | Core Data unique index |
| UserEntitlement | Entitlement type must be valid | Entity model validation |
| AdEvent | Placement must be valid | Entity model validation |

---

## Persistence Strategy

### Core Data Configuration

**Model File**: `Sources/AppHost/Model.xcdatamodeld`  
**Stack Class**: `PersistenceController` (existing in POC)

**Context Management**:
- View-scoped contexts for SwiftUI views
- Background context for async operations
- Merging changes with proper NSManagedObjectContext

### File Storage Strategy

**ROM Files**:
- Location: User-accessible app sandbox (FileManager.documentsDirectory)
- Naming: `{CHECKSUM}.{extension}` - e.g., `abc123.nes`
- Access: Read-only during gameplay

**Save State Files**:
- Location: Application Support directory /SaveStates/
- Naming: `{ROM_ID}_{SLOT_NUMBER}.state`
- Thumbnail: `{ROM_ID}_{SLOT_NUMBER}.png` (separate file or embedded)

**Native Save Files**:
- Location: Application Support directory /Saves/
- Naming: `{CHECKSUM}.sram` (varies by system)
- Backup strategy: Keep last 3 backups per game

**Thumbnails/Cover Art**:
- Stored in Core Data as BLOB data (for fast library loading)
- Cached in FileManager for performance
- Regenerated on ROM import if missing

---

## Performance Considerations

### Indexing Strategy

- **ROM Library**: Index by system, playtime, checksum for fast filtering and sorting
- **Save States**: Index by ROM ID and slot for quick loading
- **Ad Events**: Index by timestamp for analytics queries (retain last 30 days)

### Lazy Loading

- **Library Grid**: Fetch ROM entries in batches (50 per page)
- **Save State Thumbnails**: Load lazily on scroll
- **Screenshot Previews**: Generate on-demand, cache in Core Data

### Memory Management

- **Image Data**: Store thumbnails compressed (PNG) to reduce Core Data memory footprint
- **Save State Metadata**: Keep in memory, stream file data on-demand
- **Large Collections**: Use NSFetchedResultsController for memory-efficient querying

---

## Migration Plan

### Version 1.0 (Initial Release)

- Create all entities above
- Set up Core Data schema
- Implement validation rules
- Set up indexes for performance

### Future Migrations

- **Cloud Sync**: Add sync_status field for future cloud save support
- **User Accounts**: Add user_id field for future account system
- **Achievements**: Add AchievementTrigger linking to UserEntitlement

---

## Summary

This data model provides complete persistence for:
- ROM library management (import, validation, metadata)
- Save states (10 slots per game, thumbnails)
- Native save files (SRAM management)
- Per-game settings (display, audio, controls)
- Controller mappings (per-system, per-controller)
- Entitlements (IAP tracking, server validation)
- Ad analytics (event tracking, frequency limiting)

All entities align with feature spec requirements and leverage existing POC architecture.
