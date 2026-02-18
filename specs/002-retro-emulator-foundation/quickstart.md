# Quick Start Guide

**Feature**: Retro Emulator Foundation  
**Date**: 2025-02-18

## Overview

This guide helps developers set up their environment, build the project, and start development on the retro emulator foundation feature.

## Prerequisites

### Hardware Requirements

- **Mac**: macOS 14+ (Sonoma or later) with Apple Silicon (M1/M2/M3 recommended)
- **RAM**: Minimum 16GB, 32GB recommended for iOS Simulator + emulator cores
- **Storage**: 50GB free disk space for SDKs, dependencies, and build artifacts

### Software Requirements

- **Xcode**: Version 16.0 or later (required for Swift 5.10 and iOS 17 SDK)
- **Xcode Command Line Tools**: Latest version (for Swift Package Manager)
- **Swift**: Swift 5.10 (bundled with Xcode 16)
- **Git**: Latest version for version control
- **iOS Simulator**: iOS 17+ simulator runtime (from Xcode)

### Required Accounts

- **Apple Developer Account**: For StoreKit 2 testing and App Store deployment
- **Google AdMob Account**: For ad unit configuration and analytics (optional - can use test mode during development)

---

## Project Setup

### 1. Clone Repository

```bash
git clone <repository-url>
cd xemu
git checkout 002-retro-emulator-foundation
```

### 2. Install Dependencies

The project uses Swift Package Manager (SPM) for most dependencies. Some dependencies may be provided via CocoaPods or static libraries.

**Swift Package Dependencies** (handled by SPM):
- SwiftUI (Apple framework, no install needed)
- Combine (Apple framework, no install needed)
- MetalKit (Apple framework, no install needed)
- GameController (Apple framework, no install needed)
- StoreKit 2 (Apple framework, no install needed)
- Core Data (Apple framework, no install needed)

**Manual Dependencies** (check Package.swift during Phase2 implementation):
- Google Mobile Ads SDK (SPM package or CocoaPods)
- Emulator cores (to be added as SPM packages or static libraries)

**Install Command** (if using CocoaPods for Ad SDK):
```bash
cd ios/AppHost
pod install
```

### 3. Open Project in Xcode

```bash
cd ios/AppHost
open AppHost.xcodeproj
# OR if workspace exists:
open AppHost.xcworkspace
```

### 4. Verify Build Configuration

**Target**: AppHost  
**Platform**: iOS 17.0+  
**Deployment Target**: iOS 17.0

In Xcode:
1. Select `AppHost` scheme
2. Choose iOS Simulator target (e.g., iPhone 15 Pro)
3. Verify deployment target is iOS 17.0

---

## Build and Run

### Using Demo Script (Recommended)

The `test.sh` script provides automated build, test, and run commands:

```bash
cd ios/AppHost

# Build for macOS (fastest for unit tests)
./test.sh build-macos

# Run all tests on macOS
./test.sh test-macos

# Run tests with coverage report
./test.sh test-coverage

# Build for iOS Simulator
./test.sh build

# Run on iOS Simulator
./test.sh demo

# List available simulators
./test.sh list-sims

# Use specific simulator
./test.sh demo --simulator "iPhone 15 Pro"

# Clean build artifacts
./test.sh clean
```

### Using Xcode Directly

**Build**:
- Press `Cmd + B` to build project
- Select scheme `AppHost` and destination `iOS Simulator`

**Run**:
- Press `Cmd + R` to build and run
- Choose simulator from scheme selector
- App will launch in iOS Simulator

**Run Tests**:
- Press `Cmd + U` to run all tests
- Use Test Navigator to run specific tests

---

## Development Workflow

### 1. Code Structure

The project follows modular architecture in `ios/AppHost/Sources/`:

```
Sources/
├── AppHost/              # Main app entry point
├── Features/              # Feature modules (Library, Controls, Settings, etc.)
├── Host/                  # Emulation host system
├── Models/                 # Shared data models
├── Persistence/             # Core Data stack
├── Services/              # External service integrations (ads, entitlements)
└── Telemetry/              # Usage analytics
```

### 2. Running Tests

**Unit Tests**:
```bash
cd ios/AppHost
swift test
```

**All Tests** (including integration):
```bash
./test.sh test-macos
# OR for iOS:
./test.sh test
```

**Specific Test**:
```bash
swift test --filter <TestName>
# Example:
swift test --filter LibraryViewModelTests
```

### 3. Adding New Features

When creating a new feature module:

1. Create directory under `Features/<FeatureName>/`
2. Add Swift files for View, ViewModel, and logic
3. Add test file under `Tests/AppHostTests/<FeatureName>Tests.swift`
4. Register module in Package.swift if needed
5. Follow existing patterns (e.g., Library module structure)

### 4. Core Data Changes

When modifying data model:

1. Open `Sources/AppHost/Model.xcdatamodeld` in Xcode
2. Add or modify entity in the model editor
3. Generate new NSManagedObject subclasses
4. Write migration script in `PersistenceController.swift`
5. Test migration on app launch

### 5. Emulator Core Integration

When integrating a new emulator core:

1. Add core dependency to Package.swift
2. Create wrapper in `Host/Emulation/<System>Core.swift`
3. Implement `EmulatorCore` protocol
4. Register core with `StableSystemsCoordinator`
5. Add tests for core wrapper in `Tests/AppHostTests/<System>CoreTests.swift`

---

## Testing Strategy

### Unit Tests

- **Location**: `Tests/AppHostTests/`
- **Framework**: XCTest
- **Coverage**: Aim for >80% coverage on feature modules

Run unit tests:
```bash
cd ios/AppHost
swift test
```

### Integration Tests

- **Emulator Cores**: Test each core wrapper independently
- **Core Data**: Test entity relationships and migrations
- **API Integration**: Test Azure API stub with mock responses

### UI Tests

- **Critical Flows**: ROM import, game launch, save state creation
- **Controller Support**: Test with connected physical controller
- **IAP Flow**: Test with sandbox receipt validation

### Performance Tests

- **Frame Rate**: Verify 60 FPS during gameplay
- **Input Latency**: Measure < 16ms controller response
- **App Launch**: Verify < 3 second startup time

---

## Debugging

### Logging

The project uses `StableSessionTracker` for telemetry and analytics. For debugging:

1. Check Xcode console for assertion failures
2. Use breakpoints in critical flows (import, validation, IAP)
3. Enable "Debug" scheme for verbose logging

### Common Issues

**Build Errors**:
- **SPM dependency not found**: Run `swift package resolve`
- **CocoaPods issue**: Run `pod install --repo-update`
- **iOS SDK not available**: Verify Xcode iOS 17 SDK is installed

**Runtime Errors**:
- **Core Data migration failure**: Clear app data and reinstall
- **Ad SDK initialization**: Check AdMob account configuration
- **Controller not detected**: Verify Bluetooth is enabled in Simulator

---

## API Integration (Entitlement Validation)

### Local Development (Stub Mode)

During development, the app uses `AzureApiStub.swift` for mock responses:

- **Test receipts**: Always return valid entitlement
- **Network failures**: Simulate timeout, rate limiting
- **Error scenarios**: Test invalid receipt, expired purchase

### Production Deployment

When deploying to production:

1. Update `AzureApiStub.swift` to use real `URLSession` calls
2. Configure production API base URL: `https://api.xemu.app/v1`
3. Add device ID generation/Keychain storage
4. Test with real StoreKit sandbox receipts

### Testing the API

Use `/test-receipt` endpoint for development validation:

```bash
curl -X POST https://dev-api.xemu.app/v1/test-receipt \
  -H "Content-Type: application/json" \
  -d '{"test_mode": true, "receipt_data": "base64-receipt", "device_id": "test-device", "product_code": "REMOVE_ADS"}'
```

---

## Deployment

### Building for Release

1. Select `Release` configuration in Xcode
2. Set deployment target to iOS 17.0
3. Enable optimization settings (fast build, dead code stripping)
4. Archive project: `Product > Archive`
5. Validate archive for App Store submission
6. Export IPA for distribution or upload archive directly

### App Store Submission

**Required Assets**:
- App icons (1024x1024, all sizes)
- Screenshots (iPhone and iPad, various sizes)
- App preview videos (optional but recommended)
- Privacy manifest file
- Marketing description, keywords, screenshots

**StoreKit Configuration**:
- Configure "Remove Ads" IAP product in App Store Connect
- Set pricing (e.g., $2.99 or $4.99)
- Enable receipt validation in backend

---

## Code Review

### Pull Request Guidelines

Before submitting code:

1. All tests pass (`swift test` succeeds)
2. Code follows existing patterns (feature modules, SwiftUI views)
3. New entities added to Core Data model
4. Migrations tested (app launches without crash)
5. Documentation updated (README, QUICKSTART.md)

### Review Checklist

- [ ] Tests added for new features
- [ ] Core Data model updated with migration
- [ ] API contracts validated (for entitlement endpoints)
- [ ] Performance tested (60 FPS, < 16ms latency)
- [ ] Ad SDK integrated with test mode
- [ ] UI matches Figma designs
- [ ] Code follows project architecture (Features, Models, Services, Telemetry)

---

## Troubleshooting

### Build Issues

**"Command PhaseScriptExecutionFailed"**:
- Clean build folder: `./test.sh clean`
- Reset SPM packages: `rm -rf .build && swift package resolve`
- Restart Xcode

**"Cannot find module"**:
- Verify Package.swift dependencies are correctly listed
- Run `swift package update`
- Check for iOS version mismatch (requires iOS 17 SDK)

### Runtime Issues

**"Core Data can't open model"**:
- Delete app from Simulator
- Rebuild and reinstall
- Check .xcdatamodeld file format

**"Ads not showing"**:
- Verify AdMob app ID configuration
- Check test mode is disabled (only in dev)
- Review ad placement timing (AdsPolicyController)

**"Emulator crashes on load"**:
- Verify ROM file is valid (checksum)
- Check core initialization parameters
- Review error logs from core wrapper
- Test with different ROM files

---

## Next Steps

After completing setup:

1. Review existing POC code in `ios/AppHost/`
2. Read `research.md` for technical decisions
3. Review `data-model.md` for entity definitions
4. Review `contracts/api-spec.yaml` for server API
5. Start with Phase2: Implementation Planning (`/speckit.tasks` command)

---

## Resources

- **Specification**: `specs/002-retro-emulator-foundation/spec.md`
- **Research**: `specs/002-retro-emulator-foundation/research.md`
- **Data Model**: `specs/002-retro-emulator-foundation/data-model.md`
- **API Contracts**: `specs/002-retro-emulator-foundation/contracts/api-spec.yaml`
- **Project README**: `ios/AppHost/README.md`
- **Testing Guide**: `ios/AppHost/TESTING.md`
- **Existing POC**: `ios/AppHost/` source code
