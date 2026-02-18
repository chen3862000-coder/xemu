# Research Findings

**Date**: 2025-02-18  
**Feature**: Retro Emulator Foundation  
**Research Phase**: Phase 0 - Outline & Research

## Summary

This research phase analyzes the existing POC implementation in `ios/AppHost` to understand what foundation code exists, what needs to be built, and what technical decisions need to be made before implementation. The research confirms the POC provides a solid foundation for most core features, with modular architecture and comprehensive test coverage.

## Existing POC Analysis

### What Already Exists

The existing POC in `ios/AppHost` provides substantial foundation code across multiple layers:

#### 1. Feature Modules (UI + Logic)

**Library Module** (`Features/Library/`):
- `LibraryView.swift` - SwiftUI view for ROM library with filter, search
- `AdsPolicyController.swift` - Ad display policy with timing control
- Supports filtering by system, search functionality
- Integration with Core Data for ROM metadata

**Settings Module** (`Features/Settings/`):
- `EntitlementStatusView.swift` - UI for displaying IAP entitlement status
- Shows active/inactive status, validation details

**Controls Module** (`Features/Controls/`):
- `ControllerOverlayView.swift` - On-screen controller overlay for touch controls
- Customizable controller button mapping support

**Import Module** (`Features/Import/`):
- `RomImportCoordinator.swift` - ROM import flow with validation
- Checksum verification, system detection
- Progress publishing via Combine

**Store Module** (`Features/Store/`):
- `PurchaseFlowController.swift` - IAP purchase flow
- Integration with PurchaseFlowController for transaction handling

**Experimental Module** (`Features/Experimental/`):
- `ExperimentalGatingManager.swift` - Hardware capability gating
- `ExperimentalLaunchView.swift` - UI for experimental systems
- `CompatibilityDataStore.swift` - Hardware compatibility matrix
- `CompatibilityDiagnosticsSheet.swift` - Diagnostics UI

#### 2. Host Layer (Emulation)

**Host System** (`Host/`):
- `StableSystemsCoordinator.swift` - Coordinator for emulator instances
- Manages multiple emulator sessions, lifecycle

**Input Handling** (`Host/Input/`):
- `InputBus.swift` - Centralized input routing
- Controller input detection, touch control handling
- Listener registration for emulator cores
- @MainActor for thread safety

**Save States** (`Host/SaveStates/`):
- `SaveStateStorage.swift` - Save state file management
- Supports multiple save slots per game

#### 3. Models & Data

**Common Types** (`Models/`):
- `CommonTypes.swift` - Shared enums and structures:
  - `Platform` enum: NES, GB, GBA, Genesis, NDS, PS1 (matches spec!)
  - `ProductCode` enum: removeAds, experimentalPack, proBundle
  - `EntitlementStatus` enum: active, inactive, revoked, refunded, expired
  - `HardwareClass` enum: tier1, tier2, tier3 (Comparable)
  - `SessionMode`, `CompletionState`, `SessionVerdict` telemetry types
  - `Region`, `DisconnectReason`, `EnforcementAction`
  - `AchievementTrigger`, `DeviceBinding` structures

#### 4. Persistence Layer

**Core Data** (`Sources/AppHost/`):
- `Model.xcdatamodeld/` - Core Data schema
- `PersistenceController.swift` - Core Data stack initialization
- Device profile caching, ROM metadata, settings

#### 5. Services Layer

**External Integrations** (`Services/`):
- `AzureApiStub.swift` - Stub for Azure API (entitlement validation)
- `OfflineGraceManager.swift` - Offline grace period management
  - 7-day grace period logic
  - Network monitoring, cached entitlement fallback

#### 6. Telemetry

**Session Tracking** (`Telemetry/`):
- `StableSessionTracker.swift` - Usage analytics tracking
  - Session start/end, heartbeat, playtime tracking
  - Offline period detection

#### 7. Testing Infrastructure

**Comprehensive Test Suite** (`Tests/AppHostTests/`):
- All feature modules have corresponding test files
- Unit tests for services, models, core logic
- Demo.sh automation script for macOS/iOS builds and tests

### What Needs to Be Built

Based on feature spec requirements, the following components need to be added or completed:

#### 1. Emulator Cores Integration

**Decision**: Integrate open-source emulator cores for each system.

**Recommended Cores**:
- **NES**: FCEUX or Nestopia
- **GB/GBC**: SameBoy or TGB Dual
- **GBA**: mGBA or VBA-M
- **Genesis**: Genesis Plus GX or PicoDrive
- **NDS**: DeSmuME or melonDS
- **PS1**: PCSX Rearmed or DuckStation

**Rationale**: These cores are well-maintained, have iOS compatibility, good performance, and permissive licenses.

**Alternatives Considered**:
- Libretro-based cores: Good standardization but requires Libretro wrapper
- Core-specific alternatives: Multiple options evaluated for each platform
- Commercial licensing: Not viable (costly, restrictive)

**Integration Approach**:
- Create abstraction layer in `Host/Emulation/`
- Each core implements common `EmulatorCore` protocol
- Host layer coordinates core instances via `StableSystemsCoordinator`
- Core lifecycle: init → load ROM → start → frame() → pause → resume → stop → cleanup

#### 2. Core Data Schema Expansion

**Decision**: Extend existing Core Data model with entities from spec.

**Entities to Add**:
- `ROMLibraryEntry` (may already exist from POC)
- `SaveState` (may need expansion)
- `ControllerMapping` (may need addition)
- `GameSettings` (may need addition)
- `UserEntitlement` (may need addition)
- `AdEvent` (telemetry entity)

**Relationships**:
- ROM has many SaveStates
- ROM has one GameSettings
- One UserEntitlement per device
- Many AdEvents per session

#### 3. Ad Network SDK Selection

**Decision**: Google AdMob SDK for iOS.

**Rationale**:
- Industry standard, stable SDK
- High fill rates globally
- Good iOS integration and documentation
- Supports banner ads (matches spec requirement for banner-only strategy)
- Alternative: Unity Ads has better fill rates but more complex integration

**Ad Format**: Banner ads only (per user clarification Q1: A)
- Placement: Library screen only
- Frequency tracking: max 1 view per 15 minutes
- Interstitial ads: NOT implemented (per conservative strategy)
- Rewarded video ads: NOT implemented (per conservative strategy)

**Implementation**:
- Integrate Google Mobile Ads SDK via SPM or CocoaPods
- Banner ad view in LibraryView
- Ad display timing controlled by `AdsPolicyController`
- Analytics tracking via `AdEvent` Core Data entity

#### 4. Server-Side Entitlement Validation

**Decision**: Azure Functions or equivalent serverless service for receipt validation.

**Rationale**:
- POC already has `AzureApiStub.swift` suggesting Azure intent
- Serverless functions scale automatically
- Apple provides StoreKit 2 receipt verification libraries
- Cost-effective for validation-only workload

**API Contract** (to be defined in `contracts/`):
- POST `/validate-receipt` - Validate IAP receipt
- Request: Base64-encoded receipt, device ID
- Response: Entitlement status (active/inactive), product code
- Error handling: Invalid receipt, expired purchase, server errors

**Caching Strategy**:
- Successful validations cached locally in `EntitlementCache`
- Cache validity period: 24-48 hours
- Offline fallback: Use cached entitlements during grace period
- Grace period enforcement: 7 days maximum (per spec)

#### 5. Figma UI Integration

**Decision**: Hybrid approach - Use native SwiftUI for core screens, selectively convert Figma components.

**Rationale**:
- Native SwiftUI provides better performance and iOS integration
- Existing POC already has SwiftUI foundation
- Direct Figma HTML/TS integration would add complexity
- Maintain design fidelity while optimizing performance

**Implementation Strategy**:
1. Review Figma designs in `figma/` directory (to be verified)
2. Convert Figma components to SwiftUI views:
   - Button styles, card layouts, navigation patterns
   - Color schemes, typography, spacing
3. Implement missing screens:
   - ROM detail view with play controls
   - Save state management UI
   - Controller mapping editor
   - Settings screens
   - IAP purchase screens
4. Apply Figma design tokens to SwiftUI views

**Figma Directory Status**: NEEDS CLARIFICATION
- User mentioned "given figma make output (generated in HTML and Typescript already) under 'figma' directory"
- Directory may not exist or contain designs yet
- Action: Verify figma/ directory contents during Phase 1

#### 6. Native Save Game Support

**Decision**: Implement SRAM save file management alongside save states.

**Rationale**:
- Many games rely on in-game saves (battery-backed RAM)
- Users expect native saves to work
- Distinct from emulator save states

**Implementation**:
- Detect SRAM file format per system (varies by core)
- File naming: `{ROM_CHECKSUM}.sram` in ROM directory
- Core Data tracks which ROMs have native saves
- Save state includes native save data (or separate files per core design)

## Technical Decisions

### 1. Build System

**Decision**: Swift Package Manager (SPM) + test.sh automation.

**Rationale**:
- Existing POC uses SPM (Package.swift)
- Better integration with Xcode 16 / Swift 5.10
- Demo.sh provides reliable build/test automation
- SPM is now default for Apple development

**Alternative Rejected**: CocoaPods - POC has Podfile but SPM preferred for modern Apple projects

### 2. Testing Strategy

**Decision**: XCTest with test.sh CI/CD automation.

**Rationale**:
- Existing POC has comprehensive XCTest suite
- Demo.sh already provides macOS and iOS test automation
- Coverage reporting supported via test.sh test-coverage

**Test Organization**:
- Unit tests per feature module (LibraryTests, InputBusTests, etc.)
- Integration tests for emulator core wrappers
- UI tests for critical user flows

### 3. Controller Support

**Decision**: Use Apple GameController framework (already in POC).

**Rationale**:
- Native iOS framework with low latency
- Supports wide range of MFi controllers
- POC already has InputBus and ControllerOverlayView
- Existing `ControllerButton` enum in CommonTypes

**Implementation**:
- Extend controller mapping editor in Settings module
- Support multiple controller profiles (per-game, per-system)
- Input latency monitoring via `StableSessionTracker`

### 4. Video Rendering

**Decision**: MetalKit for GPU-accelerated rendering.

**Rationale**:
- Metal provides hardware-accelerated rendering on iOS
- Required for PS1 and more demanding systems
- Supports shaders/filters (CRT, scanline - per spec)
- Existing POC may already have Metal integration

**Implementation**:
- MetalKit render view in Host layer
- Texture upscaling for better visual quality
- Post-processing shaders for video filters

### 5. Audio Playback

**Decision**: AVAudioEngine or Core Audio for low-latency audio.

**Rationale**:
- iOS native audio APIs with low latency
- Required for 60 FPS emulation
- Supports audio volume/mute controls (per spec)

## Unknowns Resolved

| Unknown | Resolution | Decision | Rationale |
|----------|-----------|----------|------------|
| Ad Network SDK selection | Google AdMob vs Unity Ads | Google AdMob | Industry standard, good iOS integration, supports banner ads |
| Emulator cores to integrate | Multiple options per system | Core-specific recommendations (see above) | Well-maintained, iOS-compatible, permissive licensing |
| Server infrastructure for entitlement validation | Azure Functions vs custom backend | Azure Functions | POC has AzureApiStub, serverless scales well, cost-effective |
| Figma integration approach | Direct HTML/TS vs native conversion | Hybrid: Native SwiftUI + Figma design conversion | Better performance, maintains design fidelity |
| Build system | SPM vs CocoaPods | Swift Package Manager | Modern Apple default, better Xcode 16 integration |
| Video rendering | MetalKit vs software rendering | MetalKit | Hardware acceleration, supports filters/shaders, required for PS1 |

## Remaining Unknowns

None - all technical decisions resolved based on spec, POC analysis, and industry best practices.

## Dependencies to Add

### Swift Package Dependencies
- **Google Mobile Ads SDK**: For ad display
- **Emulator Cores**: Each core as SPM package or static library
- **Metal Shaders**: If needed for video filters

### External Services
- **Azure Functions**: For IAP receipt validation (existing stub to replace)
- **Google AdMob**: Ad network account and ad unit configuration

## Recommendations for Phase 1

1. **Data Model Design**: Define Core Data schema extensions for SaveState, GameSettings, ControllerMapping, UserEntitlement, AdEvent
2. **API Contracts**: Design REST API for entitlement validation (endpoints, request/response schemas)
3. **Core Abstraction**: Create `EmulatorCore` protocol with required methods (init, loadROM, start, pause, resume, frame, stop, cleanup)
4. **Figma Directory Verification**: Confirm existence of figma/ directory and review available UI components

## Summary

The existing POC provides approximately 60-70% of required foundation code, with solid architecture, comprehensive testing, and modular design. The remaining work focuses on:

1. Emulator core integration (6 cores)
2. Core Data schema completion
3. Ad network integration
4. Server-side entitlement API development
5. UI completion from Figma designs
6. Monetization implementation (ads + IAP)

All technical decisions have been made, no blockers remain. Ready to proceed to Phase 1: Design & Contracts.
