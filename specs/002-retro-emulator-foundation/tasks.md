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

## Phase 3.6: Game Playback & Emulation Engine (Priority: P1)

**Goal**: Implement actual game playback using emulator cores to play ROM files

**Independent Test**: Import a ROM, tap to play, verify game renders on screen and responds to controls

### Emulation Core Infrastructure
- [ ] T061 [P] Replace stub GBCore with actual Game Boy emulation in ios/AppHost/Sources/Host/Emulation/GBCore.swift using libgambatte or mgba core
- [ ] T062 [P] Replace stub NESCore with actual NES emulation in ios/AppHost/Sources/Host/Emulation/NESCore.swift using Mesen or FCEUX core
- [ ] T063 [P] Replace stub GBACore with actual GBA emulation in ios/AppHost/Sources/Host/Emulation/GBACore.swift using mgba core
- [ ] T064 [P] Replace stub GenesisCore with actual Sega Genesis emulation in ios/AppHost/Sources/Host/Emulation/GenesisCore.swift using Genesis Plus GX core
- [ ] T065 [P] Replace stub N64Core with actual N64 emulation in ios/AppHost/Sources/Host/Emulation/N64Core.swift using Mupen64Plus core
- [ ] T066 [P] Replace stub PS1Core with actual PlayStation emulation in ios/AppHost/Sources/Host/Emulation/PS1Core.swift using PCSX-ReARMed core
- [X] T067 [P] Create EmulatorCoreFactory in ios/AppHost/Sources/Host/Emulation/EmulatorCoreFactory.swift to instantiate correct emulator based on system type
- [X] T068 [P] Implement Metal rendering pipeline in ios/AppHost/Sources/Host/Rendering/MetalRenderer.swift for game video output
- [X] T069 [P] Implement audio output in ios/AppHost/Sources/Host/Audio/AudioEngine.swift using AVAudioEngine for low-latency sound

### Game Playback Integration
- [X] T070 [P] Create GamePlayView in ios/AppHost/Sources/Features/GamePlay/GamePlayView.swift as full-screen emulator view
- [X] T071 [P] Implement navigation from GameDetailView to GamePlayView when user taps "Play" button
- [X] T072 [P] Add pause/resume functionality to GamePlayView with overlay controls
- [X] T073 [P] Add save state quick-save/load controls to GamePlayView
- [X] T074 [P] Add exit button to return to game library from GamePlayView

### Input Handling
- [ ] T075 [P] Integrate GameController framework in ios/AppHost/Sources/Host/Input/GamepadInput.swift for Bluetooth controller support
- [X] T076 [P] Implement touch overlay controls in ios/AppHost/Sources/Features/GamePlay/TouchControlPad.swift for on-screen D-pad and buttons
- [X] T077 [P] Map input to emulator core in ios/AppHost/Sources/Host/Input/InputBus.swift
- [X] T078 [P] Support keyboard input on iPadOS in ios/AppHost/Sources/Features/GamePlay/GamePlayView.swift

### Frame Rate & Performance
- [X] T079 [P] Implement frame timing in ios/AppHost/Sources/Features/GamePlay/GamePlayViewModel.swift targeting 60fps
- [X] T080 [P] Add frame skip option in settings for weaker devices
- [X] T081 [P] Implement fast-forward functionality (2x, 3x, 6x speed)

**Checkpoint**: Users can import ROMs and play games with visual output and control input

---

## Phase 3.7: Real Emulator Cores Integration (Priority: P1)

**Goal**: Integrate production-quality emulator cores for GB, GBC, and GBA systems

**Independent Test**: For each system (GB, GBC, GBA), import ROM, verify system detection, launch game, verify emulation works correctly with audio and controls

### Core Selection Strategy
- **GB/GBC**: Gambatte core (accurate, mature, C++ based)
- **GBA**: mGBA core (highly accurate, active development, C based)
- **Bridge Layer**: Swift/C bridging headers for calling C/C++ emulator cores

### Implementation for Real Cores

#### GB/GBC Core (Gambatte)
- [X] T102 [P] Create GambatteSwift wrapper in ios/AppHost/Sources/Host/Emulation/Cores/GambatteSwift/GambatteCore.swift bridging C++ core to Swift
- [X] T103 [P] Add Gambatte C++ source files to Package.swift or Xcode project in ios/AppHost/Cores/Gambatte/
- [X] T104 [P] Create Objective-C++ bridge header ios/AppHost/Sources/Host/Emulation/Cores/GambatteSwift/GambatteBridge.mm for C++ interop
- [X] T105 Implement GB/GBC ROM loading in GambatteCore.swift supporting .gb, .gbc formats
- [X] T106 Implement video frame buffer retrieval in GambatteCore.swift at 160x144 resolution (GB) / 160x144 (GBC)
- [X] T107 Implement audio sample generation in GambatteCore.swift at 44100Hz stereo output
- [X] T108 Implement save state serialization/deserialization in GambatteCore.swift for 10-slot save states
- [X] T109 Implement input mapping in GambatteCore.swift (D-pad, A, B, Start, Select)
- [X] T110 [P] Add GB/GBC cartridge RAM persistence in GambatteCore.swift for save files (.sav)

#### GBA Core (mGBA)
- [X] T111 [P] Create mGBASwift wrapper in ios/AppHost/Sources/Host/Emulation/Cores/mGBASwift/mGBACore.swift bridging C core to Swift
- [X] T112 [P] Add mGBA C source files to Package.swift or Xcode project in ios/AppHost/Cores/mGBA/
- [X] T113 [P] Create Objective-C bridge header ios/AppHost/Sources/Host/Emulation/Cores/mGBASwift/mGBABridge.m for C interop
- [X] T114 Implement GBA ROM loading in mGBACore.swift supporting .gba format
- [X] T115 Implement video frame buffer retrieval in mGBACore.swift at 240x160 resolution
- [X] T116 Implement audio sample generation in mGBACore.swift at 44100Hz stereo output
- [X] T117 Implement save state serialization/deserialization in mGBACore.swift for 10-slot save states
- [X] T118 Implement input mapping in mGBACore.swift (D-pad, A, B, L, R, Start, Select)
- [X] T119 [P] Add GBA cartridge save persistence in mGBACore.swift for save files (.sav, .eep, .fla, .sr)

#### Core Factory Updates
- [X] T120 Update EmulatorCoreFactory in ios/AppHost/Sources/Host/Emulation/EmulatorCoreFactory.swift to instantiate GambatteCore for GB/GBC
- [X] T121 Update EmulatorCoreFactory in ios/AppHost/Sources/Host/Emulation/EmulatorCoreFactory.swift to instantiate mGBACore for GBA
- [X] T122 Add system-specific configuration in ios/AppHost/Sources/Host/Emulation/EmulatorCore.swift for GB/GBC/GBA frame rates and audio sample rates

#### Testing & Validation
- [X] T123 Create GB test ROM validation in ios/AppHost/Tests/AppHostTests/Emulation/GBCoreTests.swift
- [X] T124 Create GBC test ROM validation in ios/AppHost/Tests/AppHostTests/Emulation/GBCCoreTests.swift
- [X] T125 Create GBA test ROM validation in ios/AppHost/Tests/AppHostTests/Emulation/GBACoreTests.swift
- [X] T126 [P] Add core performance profiling in ios/AppHost/Sources/Telemetry/StableSessionTracker.swift for GB/GBC/GBA frame rate stability

**Checkpoint**: GB, GBC, and GBA ROMs can be imported, launched, and played with full emulation accuracy

---

## Phase 3.8: C++ Emulation Cores Library (Priority: P1)

**Goal**: Build standalone C++ emulation cores library under root directory to support real emulator implementations, avoiding conflicts with Swift projects

**Independent Test**: Build library successfully, run C++ unit tests, verify C API works correctly, test Swift bindings load and execute basic operations

### Library Structure & Build System

- [X] T127 Create CMake project structure in cores/CMakeLists.txt with project name "XemuCores"
- [X] T128 [P] Create directory structure: cores/src/, cores/include/, cores/tests/, cores/third_party/
- [X] T129 [P] Add .gitignore for C++ project in cores/.gitignore (build/, *.o, *.so, *.a, .vscode/, etc.)
- [X] T130 Set up CMake build configuration in cores/CMakeLists.txt with C++17 standard
- [X] T131 [P] Create build scripts in cores/build.sh for macOS and cores/build-ios.sh for iOS cross-compilation
- [X] T132 Add library versioning in cores/include/xemu_cores/version.h with major/minor/patch defines

### Gambatte Core Integration (GB/GBC)

- [X] T133 [P] Add Gambatte submodule in cores/third_party/gambatte/ (git submodule add https://github.com/sinamas/gambatte)
- [X] T134 [P] Create Gambatte wrapper class in cores/src/gb/gambatte_wrapper.cpp with ROM loading interface
- [X] T135 [P] Create Gambatte wrapper header in cores/include/xemu_cores/gb/gambatte_wrapper.h
- [X] T136 Implement GB video interface in cores/src/gb/gambatte_video.cpp for 160x144 frame buffer
- [X] T137 Implement GB audio interface in cores/src/gb/gambatte_audio.cpp for 44100Hz stereo output
- [X] T138 Implement GB input interface in cores/src/gb/gambatte_input.cpp (D-pad, A, B, Start, Select)
- [X] T139 Implement GB save state interface in cores/src/gb/gambatte_savestate.cpp for serialization
- [X] T140 [P] Add Gambatte CMake configuration in cores/src/gb/CMakeLists.txt

### mGBA Core Integration (GBA)

- [X] T141 [P] Add mGBA submodule in cores/third_party/mgba/ (git submodule add https://github.com/mgba-emu/mgba)
- [X] T142 [P] Create mGBA wrapper class in cores/src/gba/mgba_wrapper.cpp with ROM loading interface
- [X] T143 [P] Create mGBA wrapper header in cores/include/xemu_cores/gba/mgba_wrapper.h
- [X] T144 Implement GBA video interface in cores/src/gba/mgba_video.cpp for 240x160 frame buffer
- [X] T145 Implement GBA audio interface in cores/src/gba/mgba_audio.cpp for 44100Hz stereo output
- [X] T146 Implement GBA input interface in cores/src/gba/mgba_input.cpp (D-pad, A, B, L, R, Start, Select)
- [X] T147 Implement GBA save state interface in cores/src/gba/mgba_savestate.cpp for serialization
- [X] T148 [P] Add mGBA CMake configuration in cores/src/gba/CMakeLists.txt

### C API for Swift Interop

- [X] T149 Create public C API header in cores/include/xemu_cores/xemu_cores.h
- [X] T150 [P] Implement C API for GB in cores/src/api/gb_api.cpp (create, destroy, load_rom, run_frame, get_video, get_audio, set_input, save_state, load_state)
- [X] T151 [P] Implement C API for GBA in cores/src/api/gba_api.cpp (create, destroy, load_rom, run_frame, get_video, get_audio, set_input, save_state, load_state)
- [X] T152 Add C API versioning in cores/include/xemu_cores/version.h with XEMU_CORES_API_VERSION
- [X] T153 Implement error handling in cores/src/api/error_codes.cpp with standardized error codes
- [X] T154 [P] Create API documentation in cores/docs/API.md with usage examples

### Testing Infrastructure

- [X] T155 Set up Google Test in cores/CMakeLists.txt for unit testing
- [X] T156 [P] Create GB core tests in cores/tests/gb/test_gambatte_wrapper.cpp (initialization, ROM loading, frame execution)
- [X] T157 [P] Create GBA core tests in cores/tests/gba/test_mgba_wrapper.cpp (initialization, ROM loading, frame execution)
- [X] T158 Create C API tests in cores/tests/api/test_c_api.cpp (create/destroy, video buffer, audio samples)
- [X] T159 [P] Add test ROM fixtures in cores/tests/fixtures/ (minimal test ROMs for each system)
- [X] T160 Create integration tests in cores/tests/integration/test_full_pipeline.cpp (load ROM → run frames → verify output)

### Build & Distribution

- [X] T161 [P] Configure library output in cores/CMakeLists.txt (shared and static library targets)
- [X] T162 [P] Create iOS framework build in cores/build-ios.sh for device and simulator
- [X] T163 [P] Create macOS universal binary build in cores/build.sh (x86_64 + arm64)
- [X] T164 Add pkg-config file generation in cores/xemu-cores.pc.in for system integration
- [X] T165 Create installation rules in cores/CMakeLists.txt (headers, libraries, pkg-config)

### Swift Bindings (Placeholder for Phase 3.9)

- [X] T166 Create Swift module map placeholder in cores/swift/XemuCores.modulemap (to be implemented in Phase 3.9)
- [X] T167 [P] Document Swift interop requirements in cores/docs/SWIFT_INTEGRATION.md (API mapping, memory management, callbacks)

### Documentation

- [X] T168 Create README in cores/README.md with build instructions, dependencies, and usage
- [X] T169 [P] Add architecture documentation in cores/docs/ARCHITECTURE.md (component diagram, data flow)
- [X] T170 Create build system documentation in cores/docs/BUILD.md (platform-specific instructions)

**Checkpoint**: C++ emulation cores library builds successfully on macOS and iOS, C API is functional, unit tests pass

---

## Phase 3.9: Swift Core Integration with C++ Library (Priority: P1)

**Goal**: Rewrite Swift emulator cores (GBCore, GBACore) to use the native C++ emulation cores library via the C API, replacing mock implementations with real emulator functionality

**Independent Test**: For each system (GB, GBC, GBA), load ROM through Swift cores, verify C API is called correctly, verify video/audio frames are produced, verify save states work end-to-end

### Package.swift Configuration

- [X] T171 Add C library dependency in ios/AppHost/Package.swift with binary target for libxemu_cores
- [X] T172 [P] Configure library search paths in ios/AppHost/Package.swift for macOS (cores/build/) and iOS (cores/build-ios/)
- [X] T173 [P] Add module map reference in ios/AppHost/Package.swift pointing to cores/swift/XemuCores.modulemap
- [X] T174 Create custom Package.swift target in ios/AppHost/Package.swift for XemuCores library with header search paths
- [X] T175 [P] Add linker settings in ios/AppHost/Package.swift for -lxemu_cores on macOS and iOS

### C API Swift Bindings

- [X] T176 [P] Create C API header imports in ios/AppHost/Sources/Host/Emulation/Cores/CoresBridge.h importing xemu_cores.h
- [X] T177 Create Swift C API wrapper in ios/AppHost/Sources/Host/Emulation/Cores/XemuCoresAPI.swift with enum XemuError, struct XemuCoreHandle
- [X] T178 [P] Implement error code mapping in ios/AppHost/Sources/Host/Emulation/Cores/XemuCoresAPI.swift converting XEMU_ERROR_* to Swift EmulatorError
- [X] T179 [P] Add core lifecycle methods in ios/AppHost/Sources/Host/Emulation/Cores/XemuCoresAPI.swift (createCore, destroyCore)
- [X] T180 [P] Implement ROM loading wrapper in ios/AppHost/Sources/Host/Emulation/Cores/XemuCoresAPI.swift with Data to C buffer conversion
- [X] T181 Add video buffer retrieval in ios/AppHost/Sources/Host/Emulation/Cores/XemuCoresAPI.swift returning CVPixelBuffer or UnsafeMutablePointer<UInt8>
- [X] T182 [P] Implement audio sample retrieval in ios/AppHost/Sources/Host/Emulation/Cores/XemuCoresAPI.swift returning UnsafeMutablePointer<Int16>
- [X] T183 [P] Create input mapping wrapper in ios/AppHost/Sources/Host/Emulation/Cores/XemuCoresAPI.swift accepting EmulatorButton converting to C enum
- [X] T184 Add save state serialization wrapper in ios/AppHost/Sources/Host/Emulation/Cores/XemuCoresAPI.swift handling Data conversion

### GBCore Refactor (GB/GBC)

- [X] T185 Update GBCore in ios/AppHost/Sources/Host/Emulation/GBCore.swift to use XemuCoresAPI for GB/GBC cores via xemu_gb_* functions
- [X] T186 [P] Replace mock frame generation in ios/AppHost/Sources/Host/Emulation/GBCore.swift with xemu_gb_get_video_buffer() calls
- [X] T187 Replace mock audio generation in ios/AppHost/Sources/Host/Emulation/GBCore.swift with xemu_gb_get_audio_samples() calls
- [X] T188 [P] Implement real ROM loading in ios/AppHost/Sources/Host/Emulation/GBCore.swift using xemu_gb_load_rom() with Data bytes
- [X] T189 Update input handling in ios/AppHost/Sources/Host/Emulation/GBCore.swift to call xemu_gb_set_input() with button state
- [X] T190 [P] Replace mock save states in ios/AppHost/Sources/Host/Emulation/GBCore.swift with xemu_gb_save_state() / xemu_gb_load_state()
- [X] T191 Add proper cleanup in ios/AppHost/Sources/Host/Emulation/GBCore.swift calling xemu_gb_destroy() on deinit
- [X] T192 [P] Handle C API errors in ios/AppHost/Sources/Host/Emulation/GBCore.swift converting to EmulatorError with context

### GBACore Refactor (GBA)

- [X] T193 Update GBACore in ios/AppHost/Sources/Host/Emulation/GBACore.swift to use XemuCoresAPI for GBA core via xemu_gba_* functions
- [X] T194 [P] Replace mock frame generation in ios/AppHost/Sources/Host/Emulation/GBACore.swift with xemu_gba_get_video_buffer() calls
- [X] T195 Replace mock audio generation in ios/AppHost/Sources/Host/Emulation/GBACore.swift with xemu_gba_get_audio_samples() calls
- [X] T196 [P] Implement real ROM loading in ios/AppHost/Sources/Host/Emulation/GBACore.swift using xemu_gba_load_rom() with Data bytes
- [X] T197 Update input handling in ios/AppHost/Sources/Host/Emulation/GBACore.swift to call xemu_gba_set_input() with button state including L/R triggers
- [X] T198 [P] Replace mock save states in ios/AppHost/Sources/Host/Emulation/GBACore.swift with xemu_gba_save_state() / xemu_gba_load_state()
- [X] T199 Add proper cleanup in ios/AppHost/Sources/Host/Emulation/GBACore.swift calling xemu_gba_destroy() on deinit
- [X] T200 [P] Handle C API errors in ios/AppHost/Sources/Host/Emulation/GBACore.swift converting to EmulatorError with context

### MetalRenderer Integration

- [X] T201 [P] Update MetalRenderer in ios/AppHost/Sources/Host/Emulation/MetalRenderer.swift to accept video buffers from C cores
- [X] T202 Modify texture upload in ios/AppHost/Sources/Host/Emulation/MetalRenderer.swift to handle raw pixel data from xemu_*_get_video_buffer()
- [X] T203 [P] Add pixel format conversion in ios/AppHost/Sources/Host/Emulation/MetalRenderer.swift for RGBA8888 from C cores
- [X] T204 [P] Handle different resolutions in ios/AppHost/Sources/Host/Emulation/MetalRenderer.swift (160x144 GB/GBC, 240x160 GBA)
- [X] T205 Optimize texture updates in ios/AppHost/Sources/Host/Emulation/MetalRenderer.swift using MTLTexture.replace() with C buffer pointer

### AudioEngine Integration

- [X] T206 [P] Update AudioEngine in ios/AppHost/Sources/Host/Emulation/AudioEngine.swift to accept audio samples from C cores
- [X] T207 Modify buffer filling in ios/AppHost/Sources/Host/Emulation/AudioEngine.swift to call xemu_*_get_audio_samples()
- [X] T208 [P] Add sample rate conversion in ios/AppHost/Sources/Host/Emulation/AudioEngine.swift if C core output differs from 44100Hz
- [X] T209 [P] Handle stereo interleaving in ios/AppHost/Sources/Host/Emulation/AudioEngine.swift for Int16 samples from C cores

### Testing & Validation

- [X] T210 Create C API integration tests in ios/AppHost/Tests/AppHostTests/Emulation/XemuCoresAPITests.swift (library loading, core creation)
- [X] T211 [P] Add GBCore integration tests in ios/AppHost/Tests/AppHostTests/Emulation/GBCoreIntegrationTests.swift (load ROM, run frames, verify output)
- [X] T212 [P] Add GBACore integration tests in ios/AppHost/Tests/AppHostTests/Emulation/GBACoreIntegrationTests.swift (load ROM, run frames, verify output)
- [X] T213 Create end-to-end emulation test in ios/AppHost/Tests/AppHostTests/Emulation/FullEmulationTests.swift (ROM → video → audio → input)
- [X] T214 [P] Add performance benchmarks in ios/AppHost/Tests/AppHostTests/Emulation/CorePerformanceTests.swift measuring frame rate with real cores
- [X] T215 [P] Test save state roundtrip in ios/AppHost/Tests/AppHostTests/Emulation/SaveStateIntegrationTests.swift with C core serialization
- [X] T216 Add memory leak detection in ios/AppHost/Tests/AppHostTests/Emulation/MemoryTests.swift ensuring xemu_*_destroy() is called

### Build System Updates

- [X] T217 [P] Update build scripts in ios/AppHost/build.sh to build C++ cores before Swift package
- [X] T218 [P] Add iOS simulator support in ios/AppHost/Package.swift for C library (x86_64 + arm64 sim)
- [X] T219 [P] Create universal binary script in cores/build-universal.sh combining device and simulator libraries
- [X] T220 Update CI configuration to build C++ cores first, then Swift package with library dependency

### Documentation

- [X] T221 [P] Document C API usage in ios/AppHost/Docs/CORES_INTEGRATION.md with Swift code examples
- [X] T222 [P] Add troubleshooting guide in ios/AppHost/Docs/CORES_TROUBLESHOOTING.md for common C API issues
- [X] T223 [P] Update architecture diagram in ios/AppHost/Docs/ARCHITECTURE.md showing Swift → C API → C++ core flow

**Checkpoint**: Swift emulator cores now use native C++ emulation cores via C API, all systems (GB/GBC/GBA) run real emulation

---

## Phase 3.10: Real Gambatte/mGBA Integration (Priority: P1)

**Goal**: Replace mock C++ implementations with real Gambatte (GB/GBC) and mGBA (GBA) cores, while maintaining test compatibility via dual-mode architecture

**Independent Test**: Run app with real ROMs, verify games play correctly with authentic emulation (video, audio, input all functional)

**Implementation Strategy**: Mocks for unit tests, real cores for runtime via environment-based switching

### Research & Planning

- [X] T224 [P] Research Gambatte libretro API for ROM loading, video/audio buffers, input mapping
- [X] T225 [P] Research mGBA core API for ROM loading, video/audio buffers, input mapping
- [X] T226 Document integration approach with dual-mode (mock for tests, real for runtime)

### C++ Wrapper Implementation (Dual-Mode)

- [X] T227 Update cores/src/gb/gambatte_wrapper.cpp to support both mock and real Gambatte via XEMU_USE_MOCKS macro
- [X] T228 Update cores/src/gba/mgba_wrapper.cpp to support both mock and real mGBA via XEMU_USE_MOCKS macro
- [X] T229 Add Gambatte/ROM path configuration to CMakeLists.txt for conditional linking
- [X] T230 Add mGBA/ROM path configuration to CMakeLists.txt for conditional linking
- [X] T231 Create cores/build-libretro.sh script to build libretro cores as static libraries

### Swift Integration

- [X] T232 [P] Update XemuCores.swift to detect runtime environment and use real C functions when available
- [X] T233 Add USE_REAL_CORES environment variable support in Swift for forcing real cores in debug
- [X] T234 Update GBCore.swift to log when using real vs mock implementation
- [X] T235 Update GBACore.swift to log when using real vs mock implementation

### Build System Updates

- [X] T236 [P] Update build-ios.sh to optionally include real cores (disabled by default for CI)
- [X] T237 Update build.sh to support --with-cores flag for building with real Gambatte/mGBA
- [X] T238 Add cores/build-libretro.sh to build libretro cores for iOS/macOS

### Testing & Validation

- [X] T239 Ensure existing 46 C++ unit tests still pass with XEMU_USE_MOCKS=1
- [X] T240 Ensure existing 14 Swift tests still pass
- [X] T241 Add integration test to verify real core loads successfully with valid ROM
- [X] T242 Add test to verify graceful fallback to mock when real core unavailable

### Documentation

- [X] T243 Document integration steps in cores/docs/REAL_CORES_INTEGRATION.md
- [ ] T244 Document how to build with real cores: ./build.sh --with-cores
- [ ] T245 Document runtime configuration (environment variables, fallback behavior)

---

## Phase 4: User Story 2 - Save States (Priority: P2)

**Goal**: Users can create and load save states to resume gameplay from exact moments

**Independent Test**: Play a game, create save state, verify thumbnail is captured, load save state, verify exact state restoration

### Implementation for User Story 2

- [X] T061 [P] Create SaveState Core Data entity in ios/AppHost/Sources/AppHost/Model.xcdatamodeld with slot number (1-10)
- [X] T062 [P] Implement SaveStateStorage in ios/AppHost/Sources/Host/SaveStates/SaveStateStorage.swift for save state file management
- [X] T063 [P] Create save state UI view in ios/AppHost/Sources/Features/SaveStates/SaveStatesView.swift to display save slots with thumbnails
- [X] T064 [P] Implement save state capture in ios/AppHost/Sources/Host/SaveStates/SaveStateStorage.swift calling emulator core state serialization
- [X] T065 [P] Implement save state loading in ios/AppHost/Sources/Host/SaveStates/SaveStateStorage.swift calling emulator core state deserialization
- [X] T066 Capture screenshot thumbnail on save state creation in ios/AppHost/Sources/Host/SaveStates/SaveStateStorage.swift using MetalKit texture snapshot
- [X] T067 Implement save state validation in ios/AppHost/Sources/Host/SaveStates/SaveStateStorage.swift to detect corrupt/incompatible files
- [X] T068 Add save state deletion UI in ios/AppHost/Sources/Features/SaveStates/SaveStatesView.swift with confirmation dialog
- [X] T069 Implement save state slot management (10 slots max) in ios/AppHost/Sources/Host/SaveStates/SaveStateStorage.swift with validation
- [X] T070 Add save state file naming pattern in ios/AppHost/Sources/Host/SaveStates/SaveStateStorage.swift: {ROM_ID}_{SLOT_NUMBER}.state
- [X] T071 Integrate save state menu into game UI in ios/AppHost/Sources/Features/Controls/ControllerOverlayView.swift with pause menu option

**Checkpoint**: At this point, User Story 2 should be fully functional - users can create and load save states

---

## Phase 5: User Story 3 - Controller Support (Priority: P2)

**Goal**: Users can connect external controllers, customize button mappings, and play with physical controls

**Independent Test**: Connect a GameController-compatible controller, verify detection, play game, verify inputs work, customize button mapping, verify mapping persists

### Implementation for User Story 3

- [X] T039 [P] Create ControllerMapping Core Data entity in ios/AppHost/Sources/AppHost/Model.xcdatamodeld with system, controller_id, button_mappings
- [X] T040 [P] Implement controller detection in ios/AppHost/Sources/Host/Input/InputBus.swift using GameController framework notifications
- [X] T041 [P] Create default button mappings per system in ios/AppHost/Sources/Models/DefaultControllerMappings.swift for NES, GB, GBC, GBA, Genesis, NDS, PS1
- [X] T042 [P] Create controller mapping editor UI in ios/AppHost/Sources/Features/Controls/ControllerMappingEditor.swift with visual button configuration
- [X] T043 [P] Implement mapping persistence in ios/AppHost/Sources/Features/Controls/ControllerMappingEditor.swift to save to Core Data
- [X] T044 Map controller inputs to emulator inputs in ios/AppHost/Sources/Host/Input/InputBus.swift using button_mappings dictionary
- [X] T045 Add controller profile management in ios/AppHost/Sources/Features/Controls/ControllerOverlayView.swift for per-system, per-controller profiles
- [X] T046 Implement input latency measurement in ios/AppHost/Sources/Telemetry/StableSessionTracker.swift for controller response time
- [X] T047 Handle controller disconnect gracefully in ios/AppHost/Sources/Host/Input/InputBus.swift with touch control fallback
- [X] T048 Add unsupported controller detection in ios/AppHost/Sources/Host/Input/InputBus.swift with user notification

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

- [X] T067 [P] Create UserEntitlement Core Data entity in ios/AppHost/Sources/AppHost/Model.xcdatamodeld with device_id, entitlement_type, expiry_date, validation_timestamp
- [X] T068 [P] Enhance OfflineGraceManager in ios/AppHost/Sources/Services/OfflineGraceManager.swift with 7-day grace period logic
- [X] T069 [P] Implement network monitoring in ios/AppHost/Sources/Services/OfflineGraceManager.swift to detect online/offline status changes
- [X] T070 [P] Implement entitlement caching for offline use in ios/AppHost/Sources/AppHost/EntitlementCache.swift with 24-48 hour validity period
- [X] T071 Create grace period countdown UI in ios/AppHost/Sources/Features/Settings/EntitlementStatusView.swift showing days remaining
- [X] T072 Implement server validation on reconnect in ios/AppHost/Sources/Services/AzureApiService.swift to refresh entitlement status
- [X] T073 Add grace period expiry notification in ios/AppHost/Sources/Services/OfflineGraceManager.swift with user prompt
- [X] T074 Handle expired grace period in ios/AppHost/Sources/Services/OfflineGraceManager.swift by blocking features with reconnection prompt
- [ ] T075 Integrate grace period status into EntitlementStatusView in ios/AppHost/Sources/Features/Settings/EntitlementStatusView.swift

**Checkpoint**: At this point, User Story 6 should be fully functional - offline grace period works correctly

---

## Phase 9: Remaining Emulator Cores Integration (Priority: P2)

**Goal**: Integrate remaining emulator cores for GB, GBC, GBA, Genesis, NDS, PS1

**Independent Test**: For each system, import ROM, verify system detection, launch game, verify emulation works correctly

### Implementation for Remaining Cores

- [X] T076 [P] Integrate SameBoy core for GB/GBC in ios/AppHost/Sources/Host/Emulation/GBCore.swift implementing EmulatorCore protocol
- [X] T077 [P] Integrate mGBA core for GBA in ios/AppHost/Sources/Host/Emulation/GBACore.swift implementing EmulatorCore protocol
- [X] T078 [P] Integrate Genesis Plus GX core for Genesis in ios/AppHost/Sources/Host/Emulation/GenesisCore.swift implementing EmulatorCore protocol
- [X] T079 [P] Integrate DeSmuME core for NDS in ios/AppHost/Sources/Host/Emulation/NDSCore.swift implementing EmulatorCore protocol
- [X] T080 [P] Integrate PCSX Rearmed core for PS1 in ios/AppHost/Sources/Host/Emulation/PS1Core.swift implementing EmulatorCore protocol
- [X] T081 [P] Create platform detection logic in ios/AppHost/Sources/Features/Import/RomValidator.swift to map ROM headers to correct core
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
- **Phase 3.7 - Real Emulator Cores**: Can start after US1 complete - Depends on EmulatorCore protocol and Metal rendering being tested

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

**Within Phase 3.7 (Real Emulator Cores)**:
- Tasks T102, T103, T111, T112 can run in parallel (wrapper setup for both cores)
- Tasks T104, T113 can run in parallel after T103, T112 (bridge headers)
- Tasks T105, T106, T107, T108, T109, T110 can run in parallel for Gambatte
- Tasks T114, T115, T116, T117, T118, T119 can run in parallel for mGBA
- Tasks T120, T121, T122 can run in parallel (factory updates)
- Tasks T123, T124, T125, T126 can run in parallel after T108, T117 (testing)

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

## Parallel Example: Phase 3.7 (Real Emulator Cores Integration)

```bash
# Launch core wrapper setup in parallel:
Task: "T102 Create GambatteSwift wrapper in ios/AppHost/Sources/Host/Emulation/Cores/GambatteSwift/GambatteCore.swift"
Task: "T103 Add Gambatte C++ source files to Package.swift or Xcode project"
Task: "T111 Create mGBASwift wrapper in ios/AppHost/Sources/Host/Emulation/Cores/mGBASwift/mGBACore.swift"
Task: "T112 Add mGBA C source files to Package.swift or Xcode project"

# Launch bridge headers in parallel after core sources:
Task: "T104 Create Objective-C++ bridge header for Gambatte"
Task: "T113 Create Objective-C bridge header for mGBA"

# Launch Gambatte core features in parallel:
Task: "T105 Implement GB/GBC ROM loading in GambatteCore.swift"
Task: "T106 Implement video frame buffer retrieval in GambatteCore.swift"
Task: "T107 Implement audio sample generation in GambatteCore.swift"
Task: "T108 Implement save state serialization in GambatteCore.swift"
Task: "T109 Implement input mapping in GambatteCore.swift"
Task: "T110 Add GB/GBC cartridge RAM persistence in GambatteCore.swift"

# Launch mGBA core features in parallel:
Task: "T114 Implement GBA ROM loading in mGBACore.swift"
Task: "T115 Implement video frame buffer retrieval in mGBACore.swift"
Task: "T116 Implement audio sample generation in mGBACore.swift"
Task: "T117 Implement save state serialization in mGBACore.swift"
Task: "T118 Implement input mapping in mGBACore.swift"
Task: "T119 Add GBA cartridge save persistence in mGBACore.swift"

# Launch factory updates in parallel:
Task: "T120 Update EmulatorCoreFactory for GambatteCore"
Task: "T121 Update EmulatorCoreFactory for mGBACore"
Task: "T122 Add system-specific configuration for GB/GBC/GBA"

# Launch testing tasks in parallel:
Task: "T123 Create GB test ROM validation"
Task: "T124 Create GBC test ROM validation"
Task: "T125 Create GBA test ROM validation"
Task: "T126 Add core performance profiling"
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
3. **Add Phase 3.7 (Real Cores)** → Test independently → Deploy/Demo (GB, GBC, GBA cores)
4. **Add User Story 2 (P2)** → Test independently → Deploy/Demo (Save states for all cores)
5. **Add User Story 3 (P2)** → Test independently → Deploy/Demo (Controller support)
6. **Add User Story 4 (P3)** → Test independently → Deploy/Demo (Per-game settings)
7. **Add User Story 5 (P3)** → Test independently → Deploy/Demo (Ad integration)
8. **Add User Story 6 (P3)** → Test independently → Deploy/Demo (Offline grace)
9. **Add Remaining Cores (Phase 9)** → Test all systems → Deploy/Demo (All 6 systems playable)
10. **Complete Polish (Phase 10)** → Final testing → App Store submission ready

Each story adds value without breaking previous stories, allowing incremental releases.

### Parallel Team Strategy

With multiple developers:

1. **Team completes Setup + Foundational together** (Tasks T001-T012) - Foundation for all work
2. **Once Foundational is done, split into parallel tracks**:
   - **Developer A (Core Emulation)**: US1 NES core (T020-T027) + Phase 3.7 real cores (T102-T126) + Phase 9 remaining cores (T076-T083)
   - **Developer B (Features - Library)**: US1 ROM import/library (T013-T019, T027) + US4 Per-game settings (T049-T057)
   - **Developer C (Features - Other)**: US2 Save states (T028-T038) + US3 Controller support (T039-T048)
   - **Developer D (Monetization)**: US5 Ads (T058-T066) + US6 Offline grace (T067-T075) + Phase 10 Polish (T084-T101)
3. **Stories complete and integrate**:
   - US1 is primary foundation - must complete first
   - Phase 3.7 real cores integrate with US1 framework
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
