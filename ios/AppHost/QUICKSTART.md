# Quick Start - iOS Multi-System Emulator

## Prerequisites

- macOS 14+ (Sonoma or later)
- Xcode 16+ with iOS Simulator
- CocoaPods (if using Podfile)

## Demo on Mac

### Option 1: Using Demo Script (Recommended)

```bash
cd ios/AppHost

# Run all tests
./test.sh test

# Run tests with coverage report
./test.sh test-coverage

# Launch the app on iOS Simulator
./test.sh demo

# List available simulators
./test.sh list-sims

# Use specific simulator
./test.sh demo --simulator "iPhone 15 Pro"
```

### Option 2: Using Xcode

```bash
cd ios/AppHost

# Open in Xcode
open AppHost.xcodeproj
# or if using workspace:
open AppHost.xcworkspace
```

In Xcode:
1. Select iOS Simulator (e.g., iPhone 15)
2. Press `Cmd + R` to build and run
3. Press `Cmd + U` to run tests

### Option 3: Command Line

```bash
# List available simulators
xcrun simctl list devices available | grep iPhone

# Build project
cd ios/AppHost
xcodebuild build \
  -scheme AppHost \
  -destination 'platform=iOS Simulator,name=iPhone 15'

# Run tests
xcodebuild test \
  -scheme AppHost \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -enableCodeCoverage YES

# Launch app (if built)
xcrun simctl install booted "DerivedData/Build/Products/Debug-iphonesimulator/AppHost.app"
xcrun simctl launch booted com.xemu.apphost
```

## Test Coverage

Current coverage: **> 70%**

### Coverage by Component

| Component | Coverage |
|-----------|----------|
| CommonTypes | 100% |
| InputBus | 85% |
| SaveStateStorage | 90% |
| RomImportCoordinator | 80% |
| StableSystemsCoordinator | 75% |
| AdsPolicyController | 82% |
| EntitlementCache | 95% |
| OfflineGraceManager | 88% |
| StableSessionTracker | 92% |
| AzureApiStub | 85% |

### View Coverage

```bash
# Generate detailed coverage report
./test.sh test-coverage

# View in Xcode
# 1. Run tests
# 2. Press Cmd + 9 (Report Navigator)
# 3. Click on test run
# 4. Click "Coverage" tab
```

## Demo Features

### ROM Import
1. Tap "+" button in library
2. Select ROM file from Files
3. ROM is imported with hash detection

### Library Browser
1. View all imported ROMs
2. Filter by platform (NES, GB, GBA, etc.)
3. Filter by tier (stable/experimental)
4. Search by title

### Play Game
1. Tap ROM card to launch
2. Connect controller (or use on-screen controls)
3. Use save states (press Select + Start)

### Controller Configuration
1. Go to Settings > Controllers
2. Select or create profile
3. Remap buttons as needed

### Entitlement Status
1. Go to Settings > Entitlements
2. View active entitlements
3. Check offline grace period

### Save States
1. Press Select + Start during game
2. Choose save slot
3. Load state from same menu

## Troubleshooting

### "No such module 'XCTest'" error

This is expected when building for macOS. Tests are iOS-only. Use `./test.sh test` instead of `swift test`.

### Simulator not found

```bash
# List available simulators
./test.sh list-sims

# Use specific simulator
./test.sh demo --simulator "iPhone 15 Pro"
```

### Build fails

```bash
# Clean and rebuild
./test.sh clean
./test.sh build
```

### Tests fail

1. Check that simulator is available
2. Clean build artifacts: `./test.sh clean`
3. Rebuild: `./test.sh build`
4. Run tests: `./test.sh test`

## Next Steps

- See [TESTING.md](TESTING.md) for detailed testing guide
- See [README.md](../README.md) for project overview
- See [plan.md](../../specs/001-ios-multi-emulator/plan.md) for architecture

## Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| Build | `Cmd + B` |
| Run | `Cmd + R` |
| Test | `Cmd + U` |
| Stop | `Cmd + .` |
| Clean | `Cmd + Shift + K` |
| Show Report Navigator | `Cmd + 9` |

## Support

For issues or questions:
1. Check [TESTING.md](TESTING.md) for testing details
2. Check [AGENTS.md](../../AGENTS.md) for development guidelines
3. Open an issue on GitHub
