# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Xemu is a native iOS retro emulator supporting multiple gaming consoles (GB/GBC, GBA, with NDS planned). The project uses a dual-mode architecture:

- **Real Mode**: Uses native C++ emulation cores (Gambatte for GB/GBC, mGBA for GBA) for production
- **Mock Mode**: Uses Swift mock implementations for development and testing (fast iteration)

The mode is controlled by the `USE_REAL_CORES` environment variable (`false` = mock, anything else = real).

## Common Commands

### Building the iOS App

```bash
# Generate Xcode project (run after project.yml changes)
cd ios/AppHost
xcodegen generate

# Build for iOS Simulator
xcodebuild -project Xemu.xcodeproj -scheme Xemu \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build

# Run tests
cd ios/AppHost
./test.sh test
```

### Building C++ Cores (Required After Core Changes)

**Critical**: When modifying files under `cores/src/` or `cores/third_party/`, you must rebuild the iOS core artifacts before changes take effect:

```bash
cd cores
./build-ios.sh
```

The iOS app links against `cores/XemuCores.xcframework`, so native source edits don't apply until this rebuild completes.

### Building for macOS (Testing Only)

```bash
cd ios/AppHost
swift build
swift test
```

Note: macOS builds use Swift Package Manager and mock cores by default (see `Package.swift`).

## Architecture

### Swift → C++ Integration Flow

```
Swift UI Layer (GamePlayView)
    ↓
EmulatorCore Protocol (GBCore, GBACore, NDSCore)
    ↓
XemuCores Swift API (GBCCoreWrapper, GBACoreWrapper)
    ↓
C API (xemu_gb_*, xemu_gba_*, xemu_nds_*)
    ↓
C++ Cores (Gambatte, mGBA, melonDS stub)
```

### Key Components

- **`ios/AppHost/Sources/Host/Emulation/EmulatorCore.swift`**: Core protocol all emulators must implement
- **`ios/AppHost/Sources/Host/Emulation/EmulatorCoreFactory.swift`**: Factory for creating cores
- **`ios/AppHost/Sources/XemuCores/XemuCores.swift`**: Swift wrappers around C API with dual-mode support
- **`cores/include/xemu_cores/xemu_cores.h`**: C API header for Swift interop
- **`cores/src/api/`**: C API implementations (`gb_api.cpp`, `gba_api.cpp`, `nds_api.cpp`)
- **`cores/src/{gb,gba,nds}/`**: Platform-specific wrappers around third-party cores

### Dual-Mode Implementation

The `XemuCores` class checks `USE_REAL_CORES` environment variable:
- When `USE_REAL_CORES=false`: Creates mock wrappers that don't call C functions
- Otherwise: Creates native wrappers that call C functions via `XemuCoresLib` module

The C++ cores are built into `cores/XemuCores.xcframework` which is linked statically into the iOS app.

### Build System

- **iOS App**: XcodeGen (`ios/AppHost/project.yml`) generates `Xemu.xcodeproj`
- **C++ Cores**: CMake (`cores/CMakeLists.txt`) builds static libraries and XCFramework
- **macOS Testing**: Swift Package Manager (`ios/AppHost/Package.swift`)

### Testing Strategy

Tests always use mock implementations via `USE_REAL_CORES=false` for fast, deterministic results. The `test.sh` script handles this automatically.

## Important Implementation Details

### Frame Buffer Access

Use `getFrameBufferInfo()` instead of `getFrameBuffer()` to ensure dimensions are atomically consistent with the returned data. This prevents race conditions where dimensions could change between calls.

### Audio Sample Rates

Different platforms have different native sample rates:
- GB/GBC: 65,536 Hz (via `GBCore.nativeAudioSampleRate`)
- GBA: 44,100 Hz
- NDS: 44,100 Hz

Use `getAudioSampleRate()` to get the core's reported rate for proper audio engine configuration.

### Input Mapping

Button mappings vary by platform. Each core handles its own input mapping in its `setInput()` method. Check individual core files for button-to-constant mappings.

### NDS Backend Status

The NDS backend is currently a scaffold/stub. The C API exists in `xemu_cores.h` with basic implementations that return placeholder data. Full NDS support via melonDS is planned but not yet implemented. The build system has placeholder configuration for libretro-based NDS integration.

## Development Workflow

1. **UI Changes**: Modify SwiftUI views in `ios/AppHost/Sources/Features/`, rebuild in Xcode
2. **Core Logic Changes**: Modify core wrappers in `ios/AppHost/Sources/Host/Emulation/`, rebuild in Xcode
3. **C++ Core Changes**: Modify files in `cores/src/` or `cores/third_party/`, run `./cores/build-ios.sh`
4. **Testing**: Run `cd ios/AppHost && ./test.sh test`

## Code Quality Guidelines

### Always Ensure Code Compiles

**Critical**: Before completing any task, ensure that your code changes compile successfully.

**Verification Command**:
```bash
# For macOS builds (fast compilation)
swift build

# For iOS builds (requires Xcode)
cd ios/AppHost
xcodebuild -project Xemu.xcodeproj -scheme Xemu \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build
```

**Common Compilation Issues to Avoid**:
- **Type visibility**: When using `private` types across struct boundaries, make them `internal` instead
- **Missing imports**: Ensure all required modules are imported (e.g., `ImageIO`, `UniformTypeIdentifiers` for GIF handling)
- **Enum conformance**: When using enums with `@AppStorage`, provide `init?(rawValue:)` initializers
- **Module-level types**: Move shared enums/types to module level if used by multiple structs in the same file

**Before Marking Tasks Complete**:
1. Run compilation verification
2. Check for any compiler warnings that could indicate issues
3. Verify that no build errors exist
4. If tests exist, ensure they pass

**If compilation fails**:
- Fix all compilation errors before marking a task as complete
- Address compiler warnings that indicate potential runtime issues
- Document any trade-offs or known limitations in comments

## Platform Support

Currently supported platforms:
- **Production**: GB, GBC (Gambatte), GBA (mGBA)
- **Development**: NDS (stub only, melonDS integration planned)
- **Planned**: NES, Genesis, PS1

## Build Configuration Notes

- Xcode project generation via XcodeGen is required after modifying `project.yml`
- C++ cores are built with C++14 standard
- iOS deployment target: iOS 17.0+
- The `project.yml` includes library search paths for the XCFramework in both device and simulator architectures
