# Tasks: Retro Emulator Foundation

**Input**: Design documents from `/specs/002-retro-emulator-foundation/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: Tests are NOT explicitly requested in the feature specification. The spec focuses on acceptance criteria and performance outcomes, not test-driven development. Therefore, NO test tasks are included in this plan.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3, etc.)
- Include exact file paths in descriptions

## Path Conventions

- **iOS Mobile App**: `ios/AppHost/Sources/` and `ios/AppHost/Tests/`
- **Resources**: `ios/AppHost/Resources/`
- **Specs**: `specs/002-retro-emulator-foundation/`

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and verification of existing POC foundation

- [X] T001 Verify existing POC structure in ios/AppHost matches research.md findings
- [X] T002 [P] Run test.sh build-macos to confirm build system works
- [X] T003 [P] Run test.sh test-macos to confirm all 107 tests pass
- [X] T004 Check if figma/ directory exists and contains UI components
- [X] T005 Verify Package.swift includes all required Apple frameworks (SwiftUI, MetalKit, GameController, StoreKit 2, Core Data, AVFoundation) ✅ NOTE: Package.swift is SPM-only; frameworks configured in Xcode project

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T006 Create EmulatorCore protocol abstraction in ios/AppHost/Sources/Host/Emulation/EmulatorCore.swift with required methods: init(), loadROM(), start(), pause(), resume(), frame(), stop(), cleanup()
- [X] T007 Extend Core Data schema with new entities in ios/AppHost/Sources/AppHost/Model.xcdatamodeld: SaveState, NativeSaveFile, GameSettings, ControllerMapping, UserEntitlement, AdEvent
- [X] T008 [P] Create Core Data migration strategy in ios/AppHost/Sources/Persistence/MigrationManager.swift to handle schema changes from existing POC
- [X] T009 Create EntitlementCache service in ios/AppHost/Sources/AppHost/EntitlementCache.swift for caching entitlements locally
- [X] T010 Create DeviceProfileCache in ios/AppHost/Sources/AppHost/DeviceProfileCache.swift for device-specific data (already exists, verify)
- [X] T011 Setup Google AdMob SDK integration in ios/AppHost/Sources/Services/AdService.swift ✅ NOTE: GoogleMobileAds added to Package.swift; full implementation in Phase 7 (US5)
- [X] T012 [P] Update AzureApiStub to real Azure Functions client in ios/AppHost/Sources/Services/AzureApiService.swift with /validate-receipt endpoint ✅ Created AzureFunctionsClient.swift for production; AzureApiStub retained for development

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Import and Play ROM (Priority: P1) 🎯 MVP

**Goal**: Users can import ROM files and launch them to play games immediately

**Independent Test**: Import a ROM file, verify it appears in library, tap to launch, verify game loads and is playable with touch controls

### Implementation for User Story 1

- [X] T013 [P] Create RomValidator in ios/AppHost/Sources/Features/Import/RomValidator.swift for checksum verification (SHA-256) and system detection
- [X] T014 [P] Enhance RomImportCoordinator in ios/AppHost/Sources/Features/Import/RomImportCoordinator.swift to add valid ROM to Core Data with metadata
- [X] T015 [P] Implement duplicate ROM detection in ios/AppHost/Sources/Features/Import/RomImportCoordinator.swift using checksum uniqueness
- [X] T016 Update LibraryView in ios/AppHost/Sources/Features/Library/LibraryView.swift to display all ROM entries from Core Data with system filtering
- [X] T017 Add ROM metadata extraction in ios/AppHost/Sources/Features/Import/RomMetadataExtractor.swift to read game names from ROM headers
- [X] T018 Create Core Data ROMLibraryEntry entity in ios/AppHost/Sources/AppHost/Model.xcdatamodeld ✅ Exists in POC
- [X] T019 Implement ROM file storage in FileManager in ios/AppHost/Sources/Persistence/ROMStorage.swift with naming pattern {CHECKSUM}.{extension}
- [X] T020 Integrate first emulator core (NES via FCEUX) in ios/AppHost/Sources/Host/Emulation/NESCore.swift implementing EmulatorCore protocol
- [X] T021 Create MetalKit render view in ios/AppHost/Sources/Host/Rendering/MetalRenderView.swift for game display
- [X] T022 Implement StableSystemsCoordinator ROM launching in ios/AppHost/Sources/Host/StableSystemsCoordinator.swift to create emulator instance and load ROM
- [X] T023 Add game loop in ios/AppHost/Sources/Host/Emulation/EmulatorSession.swift to call frame() at 60 FPS
- [X] T024 Implement touch controls overlay in ios/AppHost/Sources/Features/Controls/TouchControlsView.swift for on-screen buttons
- [X] T025 Connect InputBus touch controls to emulator inputs in ios/AppHost/Sources/Host/Input/InputBus.swift
- [X] T026 Add error handling for ROM import failures in ios/AppHost/Sources/Features/Import/RomImportCoordinator.swift with user-friendly messages
- [X] T027 Implement library loading performance optimization in ios/AppHost/Sources/Features/Library/LibraryView.swift using NSFetchedResultsController for lazy loading

**Checkpoint**: At this point, User Story 1 should be fully functional and independently testable - users can import and play NES ROMs

---

## Phase 3.5: Figma UI Implementation (Priority: P1) 🎯

**Goal**: Convert Figma HTML/TypeScript mockups to SwiftUI views

**Independent Test**: Launch app, verify UI matches Figma designs, all navigation works, interactions respond correctly

### Implementation for UI

**Pages (convert from figma/src/app/pages/)**:

- [X] T028 [P] [US1] Convert Home screen in figma/src/app/pages/home.tsx to SwiftUI in ios/AppHost/Sources/Features/Home/HomeView.swift
- [X] T029 [P] [US1] Convert Game List screen in figma/src/app/pages/game-list.tsx to SwiftUI in ios/AppHost/Sources/Features/Library/GameListView.swift
- [X] T030 [P] [US1] Convert Game Detail screen in figma/src/app/pages/game-detail.tsx to SwiftUI in ios/AppHost/Sources/Features/GameDetail/GameDetailView.swift
- [X] T031 [P] [US1] Convert Settings screen in figma/src/app/pages/settings.tsx to SwiftUI in ios/AppHost/Sources/Features/Settings/SettingsView.swift

**Components (convert from figma/src/app/components/)**:

- [X] T043 [P] [US1] Convert EmulatorCard in figma/src/app/components/emulator-card.tsx to SwiftUI in ios/AppHost/Sources/Features/Home/HomeView.swift
- [X] T044 [P] [US1] Convert GameCard in figma/src/app/components/game-card.tsx to SwiftUI in ios/AppHost/Sources/Features/Library/GameListView.swift
- [X] T045 [P] [US1] Convert Header in figma/src/app/components/header.tsx to SwiftUI in ios/AppHost/Sources/Features/Components/Header.swift
- [X] T046 [P] [US1] Convert ImportRomsButton in figma/src/app/components/import-roms-button.tsx to SwiftUI in ios/AppHost/Sources/Features/Home/HomeView.swift
- [X] T047 [P] [US1] Convert RecentGames in figma/src/app/components/recent-games.tsx to SwiftUI in ios/AppHost/Sources/Features/Home/HomeView.swift
- [X] T048 [P] [US1] Convert SettingsHeader in figma/src/app/components/settings-header.tsx to SwiftUI in ios/AppHost/Sources/Features/Settings/SettingsHeader.swift
- [X] T049 [P] [US1] Convert SettingsItem in figma/src/app/components/settings-item.tsx to SwiftUI in ios/AppHost/Sources/Features/Settings/SettingsItem.swift
- [X] T050 [P] [US1] Convert iPhoneMockup in figma/src/app/components/iphone-mockup.tsx to SwiftUI preview in ios/AppHost/Sources/Features/Preview/iPhoneMockup.swift

**UI Components Library (convert from figma/src/app/components/ui/)**:

- [X] T051 [P] [US1] Create SwiftUI UI component library in ios/AppHost/Sources/UI/ based on figma/src/app/components/ui/
- [X] T052 [P] [US1] Convert button, card, badge, label components
- [X] T053 [P] [US1] Convert dialog, drawer, dropdown-menu components
- [X] T054 [P] [US1] Convert input, form, checkbox components
- [ ] T055 [P] [US1] Convert navigation-menu, menubar, pagination components
- [X] T056 [P] [US1] Convert alert, alert-dialog, collapsible components

**Integration**:

- [X] T057 [US1] Integrate HomeView as main entry point in ios/AppHost/Sources/AppHost/ContentView.swift
- [X] T058 [US1] Wire up navigation between screens using SwiftUI NavigationStack
- [X] T059 [US1] Connect UI to existing ROM library data in Core Data
- [X] T060 [US1] Connect UI to existing ROM import functionality

**Checkpoint**: UI should match Figma designs and be fully functional with existing backend

---

## Phase 4: User Story 2 - Save States (Priority: P2)

**Goal**: Users can create and load save states to resume gameplay from exact moments

**Independent Test**: Play a game, create save state, verify thumbnail is captured, load save state, verify exact state restoration

### Implementation for User Story 2

- [ ] T061 [P] Create SaveState Core Data entity in ios/AppHost/Sources/AppHost/Model.xcdatamodeld with slot number (1-10)
- [ ] T062 [P] Implement SaveStateStorage in ios/AppHost/Sources/Host/SaveStates/SaveStateStorage.swift for save state file management
- [ ] T063 [P] Create save state UI view in ios/AppHost/Sources/Features/SaveStates/SaveStatesView.swift to display save slots with thumbnails
- [ ] T064 [P] Implement save state capture in ios/AppHost/Sources/Host/SaveStates/SaveStateStorage.swift calling emulator core state serialization
- [ ] T065 [P] Implement save state loading in ios/AppHost/Sources/Host/SaveStates/SaveStateStorage.swift calling emulator core state deserialization
- [ ] T066 Capture screenshot thumbnail on save state creation in ios/AppHost/Sources/Host/SaveStates/SaveStateStorage.swift using MetalKit texture snapshot
- [ ] T067 Implement save state validation in ios/AppHost/Sources/Host/SaveStates/SaveStateStorage.swift to detect corrupt/incompatible files
- [ ] T068 Add save state deletion UI in ios/AppHost/Sources/Features/SaveStates/SaveStatesView.swift with confirmation dialog
- [ ] T069 Implement save state slot management (10 slots max) in ios/AppHost/Sources/Host/SaveStates/SaveStateStorage.swift with validation
- [ ] T070 Add save state file naming pattern in ios/AppHost/Sources/Host/SaveStates/SaveStateStorage.swift: {ROM_ID}_{SLOT_NUMBER}.state
- [ ] T071 Integrate save state menu into game UI in ios/AppHost/Sources/Features/Controls/ControllerOverlayView.swift with pause menu option

**Checkpoint**: At this point, User Story 2 should be fully functional - users can create and load save states

---

## Phase 5: User Story 3 - Controller Support (Priority: P2)

**Goal**: Users can connect external controllers, customize button mappings, and play with physical controls

**Independent Test**: Connect a GameController-compatible controller, verify detection, play game, verify inputs work, customize button mapping, verify mapping persists

### Implementation for User Story 3

- [ ] T039 [P] Create ControllerMapping Core Data entity in ios/AppHost/Sources/AppHost/Model.xcdatamodeld with system, controller_id, button_mappings
- [ ] T040 [P] Implement controller detection in ios/AppHost/Sources/Host/Input/InputBus.swift using GameController framework notifications
- [ ] T041 [P] Create default button mappings per system in ios/AppHost/Sources/Models/DefaultControllerMappings.swift for NES, GB, GBC, GBA, Genesis, NDS, PS1
- [ ] T042 [P] Create controller mapping editor UI in ios/AppHost/Sources/Features/Controls/ControllerMappingEditor.swift with visual button configuration
- [ ] T043 [P] Implement mapping persistence in ios/AppHost/Sources/Features/Controls/ControllerMappingEditor.swift to save to Core Data
- [ ] T044 Map controller inputs to emulator inputs in ios/AppHost/Sources/Host/Input/InputBus.swift using button_mappings dictionary
- [ ] T045 Add controller profile management in ios/AppHost/Sources/Features/Controls/ControllerOverlayView.swift for per-system, per-controller profiles
- [ ] T046 Implement input latency measurement in ios/AppHost/Sources/Telemetry/StableSessionTracker.swift for controller response time
- [ ] T047 Handle controller disconnect gracefully in ios/AppHost/Sources/Host/Input/InputBus.swift with touch control fallback
- [ ] T048 Add unsupported controller detection in ios/AppHost/Sources/Host/Input/InputBus.swift with user notification

**Checkpoint**: At this point, User Story 3 should be fully functional - users can connect and configure controllers

---

## Phase 6: User Story 4 - Per-Game Settings (Priority: P3)

**Goal**: Users can configure display, audio, and control settings for each specific game

**Independent Test**: Configure settings for two games differently, verify settings apply independently and persist across restarts

### Implementation for User Story 4

- [ ] T049 [P] Create GameSettings Core Data entity in ios/AppHost/Sources/AppHost/Model.xcdatamodeld with rom_id (unique), display_mode, video_filter, audio_volume
- [ ] T050 [P] Create settings UI view in ios/AppHost/Sources/Features/Settings/GameSettingsView.swift with sections for display, video, audio, controls
- [ ] T051 [P] Implement display mode settings in ios/AppHost/Sources/Features/Settings/GameSettingsView.swift (aspect ratio: original, fill; scaling: integer, smooth)
- [ ] T052 [P] Implement video filter settings in ios/AppHost/Sources/Features/Settings/GameSettingsView.swift (none, CRT, scanline)
- [ ] T053 [P] Implement audio settings in ios/AppHost/Sources/Features/Settings/GameSettingsView.swift (volume slider, mute toggle, audio rate)
- [ ] T054 [P] Implement touch control settings in ios/AppHost/Sources/Features/Settings/GameSettingsView.swift (opacity, layout: default, compact, expanded)
- [ ] T055 Add settings persistence to Core Data in ios/AppHost/Sources/Features/Settings/GameSettingsView.swift
- [ ] T056 Add reset to default settings option in ios/AppHost/Sources/Features/Settings/GameSettingsView.swift
- [ ] T057 Integrate settings menu into library view in ios/AppHost/Sources/Features/Library/LibraryView.swift via long-press/swipe gesture

**Checkpoint**: At this point, User Story 4 should be fully functional - users can configure per-game settings

---

## Phase 7: User Story 5 - Ad-Supported Free Tier (Priority: P3)

**Goal**: Free tier users see banner ads on library screen only, with frequency limited to 1 view per 15 minutes

**Independent Test**: Use app without IAP purchase, verify banner ads appear on library screen only, verify frequency limits work, verify ads never appear during gameplay

### Implementation for User Story 5

- [ ] T058 [P] Create AdEvent Core Data entity in ios/AppHost/Sources/AppHost/Model.xcdatamodeld with timestamp, placement, format, was_shown
- [ ] T059 [P] Implement AdService with Google AdMob SDK in ios/AppHost/Sources/Services/AdService.swift for banner ad loading
- [ ] T060 [P] Create banner ad view component in ios/AppHost/Sources/Features/Library/LibraryView.swift integrating AdService
- [ ] T061 [P] Implement ad placement tracking in ios/AppHost/Sources/Features/Library/AdsPolicyController.swift with library_load, library_scroll events
- [ ] T062 Implement 15-minute frequency limit in ios/AppHost/Sources/Features/Library/AdsPolicyController.swift with last_ad_shown timestamp tracking
- [ ] T063 [P] Implement ad load failure graceful handling in ios/AppHost/Sources/Services/AdService.swift with error logging
- [ ] T064 Add ad click tracking in ios/AppHost/Sources/Services/AdService.swift updating AdEvent.was_clicked
- [ ] T065 Configure AdMob ad unit IDs in ios/AppHost/Resources/AdConfiguration.plist for production and test environments
- [ ] T066 Add analytics for ad performance in ios/AppHost/Sources/Telemetry/StableSessionTracker.swift tracking AdEvent failures

**Checkpoint**: At this point, User Story 5 should be fully functional - ads display correctly on library screen only

---

## Phase 8: User Story 6 - Offline Grace Period (Priority: P3)

**Goal**: Users can continue using app for 7 days when offline, with clear countdown and reconnection prompt

**Independent Test**: Go offline, verify app continues to work for 7 days, verify countdown displays, verify reconnection reactivates app

### Implementation for User Story 6

- [ ] T067 [P] Create UserEntitlement Core Data entity in ios/AppHost/Sources/AppHost/Model.xcdatamodeld with device_id, entitlement_type, expiry_date, validation_timestamp
- [ ] T068 [P] Enhance OfflineGraceManager in ios/AppHost/Sources/Services/OfflineGraceManager.swift with 7-day grace period logic
- [ ] T069 [P] Implement network monitoring in ios/AppHost/Sources/Services/OfflineGraceManager.swift to detect online/offline status changes
- [ ] T070 [P] Implement entitlement caching for offline use in ios/AppHost/Sources/AppHost/EntitlementCache.swift with 24-48 hour validity period
- [ ] T071 Create grace period countdown UI in ios/AppHost/Sources/Features/Settings/EntitlementStatusView.swift showing days remaining
- [ ] T072 Implement server validation on reconnect in ios/AppHost/Sources/Services/AzureApiService.swift to refresh entitlement status
- [ ] T073 Add grace period expiry notification in ios/AppHost/Sources/Services/OfflineGraceManager.swift with user prompt
- [ ] T074 Handle expired grace period in ios/AppHost/Sources/Services/OfflineGraceManager.swift by blocking features with reconnection prompt
- [ ] T075 Integrate grace period status into EntitlementStatusView in ios/AppHost/Sources/Features/Settings/EntitlementStatusView.swift

**Checkpoint**: At this point, User Story 6 should be fully functional - offline grace period works correctly

---

## Phase 9: Remaining Emulator Cores Integration (Priority: P2)

**Goal**: Integrate remaining emulator cores for GB, GBC, GBA, Genesis, NDS, PS1

**Independent Test**: For each system, import ROM, verify system detection, launch game, verify emulation works correctly

### Implementation for Remaining Cores

- [ ] T076 [P] Integrate SameBoy core for GB/GBC in ios/AppHost/Sources/Host/Emulation/GBCore.swift implementing EmulatorCore protocol
- [ ] T077 [P] Integrate mGBA core for GBA in ios/AppHost/Sources/Host/Emulation/GBACore.swift implementing EmulatorCore protocol
- [ ] T078 [P] Integrate Genesis Plus GX core for Genesis in ios/AppHost/Sources/Host/Emulation/GenesisCore.swift implementing EmulatorCore protocol
- [ ] T079 [P] Integrate DeSmuME core for NDS in ios/AppHost/Sources/Host/Emulation/NDSCore.swift implementing EmulatorCore protocol
- [ ] T080 [P] Integrate PCSX Rearmed core for PS1 in ios/AppHost/Sources/Host/Emulation/PS1Core.swift implementing EmulatorCore protocol
- [ ] T081 [P] Create platform detection logic in ios/AppHost/Sources/Features/Import/RomValidator.swift to map ROM headers to correct core
- [ ] T082 [P] Add system-specific configuration for each core in ios/AppHost/Sources/Host/Emulation/EmulatorCore.swift (frame rates, audio sample rates)
- [ ] T083 Add performance profiling for each core in ios/AppHost/Sources/Telemetry/StableSessionTracker.swift tracking frame rate stability

**Checkpoint**: At this point, all 6 emulator cores are integrated and all systems are playable

---

## Phase 10: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories and final launch preparation

- [ ] T084 [P] Create IAP purchase flow for Remove Ads in ios/AppHost/Sources/Features/Store/PurchaseFlowController.swift using StoreKit 2
- [ ] T085 Implement server-side receipt validation API endpoint in Azure Functions (deploy /validate-receipt with Apple receipt verification)
- [ ] T086 [P] Add native save file (SRAM) management in ios/AppHost/Sources/Host/Saves/NativeSaveStorage.swift with backup strategy
- [ ] T087 [P] Implement video filter shaders in ios/AppHost/Sources/Host/Rendering/MetalRenderView.swift (CRT, scanline effects)
- [ ] T088 [P] Add storage usage UI in ios/AppHost/Sources/Features/Library/LibraryView.swift showing ROM and save state disk usage
- [ ] T089 Performance optimization: Profile and optimize frame rate for all emulator cores in ios/AppHost/Sources/Host/Emulation/EmulatorSession.swift targeting 60 FPS
- [ ] T090 [P] Memory optimization: Reduce Core Data memory footprint for thumbnail images in ios/AppHost/Sources/Persistence/PersistenceController.swift
- [ ] T091 [P] Battery efficiency optimization: Reduce power consumption during gameplay in ios/AppHost/Sources/Host/Emulation/EmulatorSession.swift
- [ ] T092 Add comprehensive error handling with user-friendly messages in ios/AppHost/Sources/AppHost/ErrorHandling.swift
- [ ] T093 [P] Implement app crash reporting and analytics in ios/AppHost/Sources/Telemetry/StableSessionTracker.swift
- [ ] T094 Update README.md in ios/AppHost/README.md with installation instructions, supported systems, and controller compatibility
- [ ] T095 Update QUICKSTART.md in ios/AppHost/QUICKSTART.md with build/run instructions and development workflow
- [ ] T096 [P] Update test.sh in ios/AppHost/test.sh to add iOS Simulator build target for full integration testing
- [ ] T097 Run all 107 tests to ensure no regressions in ios/AppHost/Tests/AppHostTests/
- [ ] T098 Finalize Figma-to-SwiftUI conversions for remaining UI components in ios/AppHost/Sources/Features/
- [ ] T099 [P] Accessibility improvements: Add VoiceOver labels to all key UI elements in ios/AppHost/Sources/Features/
- [ ] T100 [P] Security hardening: Implement App Store compliance and ROM legality disclaimer in ios/AppHost/Sources/AppHost/AppDelegate.swift
- [ ] T101 Prepare App Store submission assets (screenshots, description, privacy policy) in ios/AppHost/Resources/

**Checkpoint**: All features complete, tested, and ready for launch

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3-8)**: All depend on Foundational phase completion
  - **User Story 1 (P1) - MVP**: Can start after Foundational (Phase 2) - No dependencies on other stories
  - **User Story 2 (P2)**: Can start after Foundational (Phase 2) - Integrates with US1 but should be independently testable
  - **User Story 3 (P2)**: Can start after Foundational (Phase 2) - Integrates with US1 but should be independently testable
  - **User Story 4 (P3)**: Can start after Foundational (Phase 2) - Integrates with US1 but should be independently testable
  - **User Story 5 (P3)**: Can start after Foundational (Phase 2) - Integrates with US1 but should be independently testable
  - **User Story 6 (P3)**: Can start after Foundational (Phase 2) - Integrates with US5 but should be independently testable
  - **Remaining Cores (Phase 9)**: Can start after US1 complete - Depends on EmulatorCore protocol being tested
- **Polish (Phase 10)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1) - Import and Play ROM**: NO dependencies on other stories - Foundation for all other features
- **User Story 2 (P2) - Save States**: Integrates with US1 (needs ROM to be playable) - Can be developed in parallel after US1 core works
- **User Story 3 (P2) - Controller Support**: Integrates with US1 (needs game to be playable) - Can be developed in parallel after US1 core works
- **User Story 4 (P3) - Per-Game Settings**: Integrates with US1 (needs ROM in library) - Can be developed in parallel after US1 core works
- **User Story 5 (P3) - Ad-Supported Free Tier**: Integrates with US1 (library screen) - Can be developed in parallel after US1 core works
- **User Story 6 (P3) - Offline Grace Period**: Integrates with US5 (ads entitlement) - Can be developed in parallel after US5 core works

### Within Each User Story

- All tasks marked [P] can run in parallel (different files, no dependencies)
- Models should be created before services in the same story
- Services should be created before UI components in the same story
- Story complete before moving to next priority

### Parallel Opportunities

**Within Phase 1 (Setup)**:
- All tasks T002, T003, T004, T005 can run in parallel

**Within Phase 2 (Foundational)**:
- All tasks T008, T010, T011 can run in parallel
- T007 must complete before T008
- T006 must complete before any emulator core integration

**Within Phase 3 (User Story 1)**:
- Tasks T013, T014, T015, T017, T018, T019, T024 can run in parallel
- T016 depends on T018
- T020 must complete before T021, T022, T023
- T021, T022, T023 can run in parallel after T020
- T025 depends on T024
- T026, T027 can run in parallel with other tasks

**Within Phase 4 (User Story 2)**:
- Tasks T028, T029, T030, T037 can run in parallel
- T031, T032, T033 can run in parallel after T029
- T034, T035 can run in parallel after T032
- T036, T038 can run in parallel after T030

**Within Phase 5 (User Story 3)**:
- Tasks T039, T041, T046 can run in parallel
- T040 must complete before T044
- T042, T043 can run in parallel after T039
- T044 must complete before T047
- T047, T048 can run in parallel after T044

**Within Phase 6 (User Story 4)**:
- Tasks T049, T050, T057 can run in parallel
- T051, T052, T053, T054 can run in parallel after T050
- T055 must complete before T056
- T056 can run in parallel with T055

**Within Phase 7 (User Story 5)**:
- Tasks T058, T059, T065 can run in parallel
- T060, T061 can run in parallel after T059
- T062, T063, T064 can run in parallel after T061
- T066 can run in parallel with T060

**Within Phase 8 (User Story 6)**:
- Tasks T067, T068, T069, T070 can run in parallel
- T071, T073 can run in parallel after T068
- T072, T074 can run in parallel after T070
- T075 must complete after T071

**Within Phase 9 (Remaining Cores)**:
- Tasks T076, T077, T078, T079, T080 can run in parallel
- T081 depends on T076, T077, T078, T079, T080
- T082, T083 can run in parallel after T081

**Within Phase 10 (Polish)**:
- Tasks T084, T086, T087, T088, T092, T094, T095, T096, T098, T099, T100, T101 can run in parallel
- T085 can run in parallel after T084
- T089, T090, T091, T093 can run in parallel after T097
- T097 must complete before T097 verification

**Across User Stories**:
- After Foundational (Phase 2) completes, User Stories 1-6 can all be developed in parallel by different team members
- US2, US3, US4, US5 integrate with US1 but can be tested independently

---

## Parallel Example: User Story 1 (Import and Play ROM)

```bash
# Launch parallel model and validation tasks together:
Task: "T013 Create RomValidator in ios/AppHost/Sources/Features/Import/RomValidator.swift"
Task: "T014 Enhance RomImportCoordinator in ios/AppHost/Sources/Features/Import/RomImportCoordinator.swift"
Task: "T015 Implement duplicate ROM detection in ios/AppHost/Sources/Features/Import/RomImportCoordinator.swift"
Task: "T017 Add ROM metadata extraction in ios/AppHost/Sources/Features/Import/RomMetadataExtractor.swift"
Task: "T018 Create Core Data ROMLibraryEntry entity in ios/AppHost/Sources/AppHost/Model.xcdatamodeld"
Task: "T019 Implement ROM file storage in FileManager in ios/AppHost/Sources/Persistence/ROMStorage.swift"
Task: "T024 Implement touch controls overlay in ios/AppHost/Sources/Features/Controls/TouchControlsView.swift"

# Launch NES emulator core and rendering together:
Task: "T020 Integrate first emulator core (NES via FCEUX) in ios/AppHost/Sources/Host/Emulation/NESCore.swift"
Task: "T021 Create MetalKit render view in ios/AppHost/Sources/Host/Rendering/MetalRenderView.swift"

# Launch integration tasks after core is ready:
Task: "T022 Implement StableSystemsCoordinator ROM launching in ios/AppHost/Sources/Host/StableSystemsCoordinator.swift"
Task: "T023 Add game loop in ios/AppHost/Sources/Host/Emulation/EmulatorSession.swift"
Task: "T025 Connect InputBus touch controls to emulator inputs in ios/AppHost/Sources/Host/Input/InputBus.swift"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. **Complete Phase 1: Setup** - Verify existing POC foundation (Tasks T001-T005)
2. **Complete Phase 2: Foundational** - Build core infrastructure that blocks all stories (Tasks T006-T012)
3. **Complete Phase 3: User Story 1** - Import and Play ROM functionality for NES system (Tasks T013-T027)
4. **STOP and VALIDATE**: Test User Story 1 independently - Import ROM, launch game, verify playable
5. **Demo MVP**: Deploy/demonstrate NES ROM import and playback with touch controls

**MVP Deliverables**:
- ROM import with validation and metadata extraction
- Library display with filtering
- NES emulation core integrated
- Game launching and gameplay loop
- Touch controls for gameplay
- Save states (10 slots) for NES games
- Basic error handling

### Incremental Delivery

1. **Complete Setup + Foundational** → Foundation ready for all user stories
2. **Add User Story 1 (P1)** → Test independently → Deploy/Demo (MVP - NES only)
3. **Add User Story 2 (P2)** → Test independently → Deploy/Demo (Save states for all cores)
4. **Add User Story 3 (P2)** → Test independently → Deploy/Demo (Controller support)
5. **Add User Story 4 (P3)** → Test independently → Deploy/Demo (Per-game settings)
6. **Add User Story 5 (P3)** → Test independently → Deploy/Demo (Ad integration)
7. **Add User Story 6 (P3)** → Test independently → Deploy/Demo (Offline grace)
8. **Add Remaining Cores (Phase 9)** → Test all systems → Deploy/Demo (All 6 systems playable)
9. **Complete Polish (Phase 10)** → Final testing → App Store submission ready

Each story adds value without breaking previous stories, allowing incremental releases.

### Parallel Team Strategy

With multiple developers:

1. **Team completes Setup + Foundational together** (Tasks T001-T012) - Foundation for all work
2. **Once Foundational is done, split into parallel tracks**:
   - **Developer A (Core Emulation)**: US1 NES core (T020-T027) + Phase 9 remaining cores (T076-T083)
   - **Developer B (Features - Library)**: US1 ROM import/library (T013-T019, T027) + US4 Per-game settings (T049-T057)
   - **Developer C (Features - Other)**: US2 Save states (T028-T038) + US3 Controller support (T039-T048)
   - **Developer D (Monetization)**: US5 Ads (T058-T066) + US6 Offline grace (T067-T075) + US4 Polish (T084-T101)
3. **Stories complete and integrate**:
   - US1 is primary foundation - must complete first
   - US2, US3, US4, US5, US6 integrate with US1 library and gameplay
   - Regular integration points to test cross-story functionality
4. **Final Polish Team**: All developers contribute to Phase 10 tasks in parallel

---

## Notes

- [P] tasks = different files, no dependencies on incomplete tasks within same phase
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable (except where explicitly integrating)
- Existing POC in ios/AppHost provides ~60-70% foundation code - tasks focus on completing missing pieces
- **Tests are NOT included** - Spec does not explicitly request TDD; existing test suite covers foundation
- **Verify existing POC** - Many entities/services may already exist, verify and extend rather than recreate
- **Emulator core integration is the largest effort** - Requires C/C++ bridging, Metal rendering, input mapping
- **Figma integration** - If figma/ directory does not exist or is empty, focus on native SwiftUI with design tokens from spec
- **Ad strategy** - Banner ads ONLY on library screen, max 1 view per 15 minutes (per user Q1:A)
- **Entitlements** - Single "Remove Ads" IAP only, no user accounts (per user Q2:A)
- **Offline grace** - 7 days maximum, device-based (per spec REQ-22)
- **Stop at checkpoints** - Validate User Story 1 independently before proceeding to ensure MVP is solid
- **Commit after each task or logical group** - Maintain granular commits for easy rollback
- **Performance targets** - 60 FPS, <16ms input latency, <3s app launch, <2s game load
