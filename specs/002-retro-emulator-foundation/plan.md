# Implementation Plan: Retro Emulator Foundation

**Branch**: `002-retro-emulator-foundation` | **Date**: 2025-02-18 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/002-retro-emulator-foundation/spec.md`

**Note**: This template is filled in by `/speckit.plan` command. See `.specify/templates/commands/plan.md` for execution workflow.

## Summary

Build a commercially viable retro gaming emulator application for iOS that supports six classic gaming systems (NES, GB, GBC, GBA, Genesis, NDS, PS1). The implementation will leverage existing POC code in `ios/AppHost` directory and extend it with missing emulator cores, complete UI from Figma designs, and integrate monetization (ads + IAP). The architecture uses SwiftUI for UI, MetalKit for rendering, GameController for input, and modular feature-based code organization.

## Technical Context

**Language/Version**: Swift 5.10 (Xcode 16)
**Primary Dependencies**:
- Apple Frameworks: SwiftUI, MetalKit, GameController, StoreKit 2, Core Data, AVFoundation, GoogleWebRTC, URLSession, FileManager
- Emulator Cores: Third-party open-source libraries for NES, GB, GBC, GBA, Genesis, NDS, PS1 (to be integrated)
- Ad Network SDK: Google AdMob or Unity Ads (NEEDS CLARIFICATION)
- Server Infrastructure: Azure API or equivalent for entitlement validation

**Storage**:
- Core Data for ROM metadata, settings, entitlement cache, telemetry
- FileManager for ROM files, save states, native game saves (SRAM)
- Keychain for device entitlement keys

**Testing**: XCTest (AppHostTests) - Comprehensive unit tests with Swift Package Manager, test.sh automation script

**Target Platform**: iOS 17+ (minimum iPhone 12 hardware)

**Project Type**: Mobile application with modular feature architecture

**Performance Goals**:
- 60 FPS consistent frame rate during gameplay
- < 16ms controller input latency
- < 3 second app launch time
- < 2 second game load time
- < 2 second save state creation
- < 10 second ad load time

**Constraints**:
- iOS-only platform (no Android/web initially)
- No user account system (device-based only)
- Single entitlement type ("Remove Ads" IAP)
- Conservative ad strategy (banner only, max 1 view per 15 minutes)
- Offline grace period of at least 7 days
- ROM storage in user-accessible sandbox (no cloud sync)

**Scale/Scope**:
- 6 emulator cores to integrate
- 100+ UI components/screens
- Support for 90%+ GameController-compatible controllers
- 80%+ ROM compatibility across all systems

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

**Initial Evaluation (Pre-Research)**: Not configured - constitution.md file is template with no values filled in. Cannot evaluate gates. Skipped validation.

**Re-evaluation (Post-Design)**: No design violations found. The implementation plan:
- Reuses existing modular architecture from POC
- Follows Swift/iOS best practices (SPM, SwiftUI, Combine)
- Maintains test coverage requirements (XCTest)
- Uses Apple-supported frameworks (MetalKit, GameController, StoreKit 2)
- Keeps scope bounded (iOS-only, no account system)

**Recommendation**: Configure project constitution before future planning sessions to enable gate enforcement.

**Status**: ✅ PASSED (design review)

## Project Structure

### Documentation (this feature)

```text
specs/002-retro-emulator-foundation/
├── spec.md              # Feature specification (existing)
├── plan.md              # This file (implementation plan)
├── research.md          # Phase 0 output (research findings)
├── data-model.md        # Phase 1 output (data entities)
├── quickstart.md        # Phase 1 output (developer setup)
├── contracts/           # Phase 1 output (API contracts)
│   └── api-spec.yaml   # Server API specification
└── checklists/
    └── requirements.md   # Quality checklist (existing)
```

### Source Code (repository root)

Based on existing POC in `ios/AppHost`, we will extend and enhance the modular Swift Package Manager structure:

```text
ios/AppHost/
├── Sources/
│   ├── AppHost/                 # Main app entry point, AppDelegate
│   ├── Features/                 # Feature modules (UI + logic)
│   │   ├── Library/             # ROM library, import, management
│   │   ├── Controls/             # Controller overlay, button mapping
│   │   ├── Settings/             # Per-game settings, configuration
│   │   ├── Import/              # ROM import flow
│   │   ├── Store/               # IAP purchase flow
│   │   └── Experimental/         # Experimental features, diagnostics
│   ├── Host/                     # Emulation host system
│   │   ├── Input/                # Input routing, controller handling
│   │   └── SaveStates/          # Save state management
│   ├── Models/                    # Data models, CommonTypes
│   ├── Persistence/               # Core Data stack, migrations
│   ├── Services/                  # External service integrations
│   │   └── OfflineGraceManager/   # Entitlement validation, offline grace
│   └── Telemetry/               # Usage analytics, session tracking
├── Tests/
│   └── AppHostTests/            # XCTest suite
├── Resources/                   # Assets, Figma components
├── Package.swift                 # Swift Package Manager manifest
├── test.sh                      # Build/test automation script
└── README.md                    # Module documentation
```

**Structure Decision**: Mobile application (iOS-only) with modular feature architecture. Existing POC provides foundation for most features (library, import, controls, save states, telemetry). We will:
1. Extend existing Features modules with complete UI from Figma designs
2. Integrate emulator cores for all 6 systems (NES, GB, GBC, GBA, Genesis, NDS, PS1)
3. Enhance Host/ layer with proper emulator abstraction
4. Complete monetization (ads + IAP) implementation
5. Add missing UI screens and polish

**Key architectural principles from POC**:
- Feature-based modularization (Library, Controls, Settings, Import, Store, Experimental)
- SwiftUI for UI with Combine for reactivity
- Core Data for persistence with clear models
- Coordinator pattern for feature flows
- Dependency injection through Services layer
- Comprehensive test coverage

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

**No constitution violations** - constitution file is unconfigured, cannot evaluate violations.
