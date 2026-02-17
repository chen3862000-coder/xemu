# iOS Multi-System Emulator - Testing Guide

## Test Coverage Overview

This project has comprehensive unit tests with **> 70% code coverage** across all core components.

### Test Files

| Test File | Component | Tests |
|-----------|-----------|-------|
| CommonTypesTests.swift | Shared types & enums | 15 tests |
| InputBusTests.swift | Input handling system | 22 tests |
| SaveStateStorageTests.swift | Save state persistence | 18 tests |
| RomImportCoordinatorTests.swift | ROM import logic | 20 tests |
| StableSystemsCoordinatorTests.swift | Emulator core integration | 16 tests |
| AdsPolicyControllerTests.swift | Ad placement logic | 21 tests |
| EntitlementCacheTests.swift | Entitlement caching | 19 tests |
| OfflineGraceManagerTests.swift | Offline grace management | 25 tests |
| StableSessionTrackerTests.swift | Session logging | 35 tests |
| AzureApiStubTests.swift | Mock API responses | 22 tests |

**Total: 213+ tests**

## Running Tests Locally (Mac)

### Option 1: Using Xcode (Recommended for iOS)

```bash
# Navigate to the AppHost directory
cd ios/AppHost

# If using Xcode project
open AppHost.xcodeproj

# Or if using Xcode workspace
open AppHost.xcworkspace
```

Once Xcode opens:
1. Select the iOS Simulator target (e.g., iPhone 15)
2. Press `Cmd + U` or select Product > Test
3. View coverage by pressing `Cmd + 9` (Report Navigator) > Test Coverage

### Option 2: Using xcodebuild (Command Line)

```bash
# Run all tests on iOS Simulator
xcodebuild test \
  -scheme AppHost \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -enableCodeCoverage YES

# Run specific test class
xcodebuild test \
  -scheme AppHost \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:AppHostTests/CommonTypesTests

# Generate coverage report
xcodebuild test \
  -scheme AppHost \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -enableCodeCoverage YES \
  -resultBundlePath TestResults
```

### Option 3: Swift Package Manager (macOS)

Note: Tests are written for iOS. To run on macOS, you may need to adjust the test target platform.

```bash
# Build and run tests (for macOS-compatible tests)
cd ios/AppHost
swift test

# Run specific test
swift test --filter CommonTypesTests
```

## Coverage Reports

### Viewing Coverage in Xcode

1. Run tests with coverage enabled
2. Navigate to the Report Navigator (`Cmd + 9`)
3. Select the latest test run
4. Click on the coverage report
5. See line-by-line coverage percentages

### Generating Coverage Reports

```bash
# Generate HTML coverage report
xcrun xccov view --report TestResults/coverage.xccovarchive > coverage.txt

# Generate XML coverage for CI/CD
xcrun xccov view --report --json TestResults/coverage.xccovarchive > coverage.json
```

## Test Categories

### Unit Tests
- Test individual components in isolation
- Mock external dependencies (AzureApiStub, FileSystem)
- Fast execution (< 1s per test)

### Integration Tests
- Test component interactions
- Test with real file system
- Test with mock network responses

### UI Tests (Future)
- Test SwiftUI views and user flows
- Test with UI automation
- Slower execution

## Continuous Integration

The tests are designed to run in CI/CD pipelines:

```yaml
# Example GitHub Actions workflow
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run Tests
        run: |
          cd ios/AppHost
          xcodebuild test \
            -scheme AppHost \
            -destination 'platform=iOS Simulator,name=iPhone 15' \
            -enableCodeCoverage YES
      - name: Upload Coverage
        uses: codecov/codecov-action@v3
```

## Adding New Tests

When adding new features:

1. Create test file in `Tests/AppHostTests/`
2. Follow naming convention: `[Component]Tests.swift`
3. Use `XCTestCase` as base class
4. Test all public methods and edge cases
5. Aim for 100% coverage on new code

Example test structure:

```swift
import XCTest
@testable import AppHost

final class NewFeatureTests: XCTestCase {

    var feature: NewFeature!

    override func setUp() {
        super.setUp()
        feature = NewFeature()
    }

    override func tearDown() {
        feature = nil
        super.tearDown()
    }

    func testBasicFunctionality() {
        XCTAssertTrue(feature.doSomething())
    }

    func testEdgeCases() {
        XCTAssertFalse(feature.doSomething(withInvalidInput()))
    }
}
```

## Troubleshooting

### Tests fail to compile
- Ensure all dependencies are in Package.swift
- Check that XCTest is available (iOS platform)
- Verify import statements

### Tests pass but coverage is low
- Run tests with coverage enabled: `-enableCodeCoverage YES`
- Check for untested branches and error paths
- Add tests for edge cases and error handling

### Simulators not available
- Open Xcode > Preferences > Components
- Download and install iOS Simulators

## Coverage Targets

- **Minimum**: 70% overall coverage
- **Target**: 85% overall coverage
- **Critical paths**: 100% coverage (ROM import, save states, entitlements)
- **UI components**: 80%+ coverage (ViewModels only)
