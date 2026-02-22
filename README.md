# Xemu - Multi-System Emulator for iOS

A native iOS emulator supporting multiple classic gaming consoles with a modern SwiftUI interface, powered by native C++ emulation cores.

## Supported Platforms

- **Game Boy / Game Boy Color (GB/GBC)** - Via Gambatte core
- **Game Boy Advance (GBA)** - Via mGBA core
- **Nintendo Entertainment System (NES)** - (Coming soon)
- **Sega Genesis / Mega Drive** - (Coming soon)
- **Nintendo DS (NDS)** - (Coming soon)
- **PlayStation 1 (PS1)** - (Coming soon)

## Features

### Core Emulation
- Native C++ emulation cores (Gambatte, mGBA)
- High-performance emulation with 60 FPS target
- Low-latency input handling (<16ms)
- Accurate audio reproduction
- Save state support with multiple slots
- Fast-forward mode (2x, 3x, 6x speeds)
- Frame skip option for weaker devices

### Dual-Mode Architecture
- **Mock Mode**: For development and testing (fast iteration)
- **Real Mode**: Production with native C++ cores
- Controlled via `USE_REAL_CORES` environment variable

### User Interface
- Modern SwiftUI-based interface
- Game library with cover art support
- ROM import via Files app
- Full-screen gameplay view
- Touch overlay controls (D-pad + buttons)
- Bluetooth controller support (MFi/PS4/Xbox)
- iPadOS keyboard support
- Pause/Resume functionality
- Quick save/load shortcuts

### Settings
- Frame skip toggle for performance
- Audio volume control
- Controller mapping

## Project Structure

```
xemu/
├── ios/AppHost/                    # iOS Swift application
│   ├── Sources/
│   │   ├── AppHost/               # App entry point, AppDelegate, ContentView
│   │   ├── Features/              # SwiftUI views/screens
│   │   │   ├── GamePlay/         # Emulator playback UI
│   │   │   ├── GameDetail/       # Game info view
│   │   │   ├── Library/          # ROM library grid
│   │   │   ├── Settings/         # App settings
│   │   │   ├── Import/           # ROM import flow
│   │   │   └── Home/             # Main navigation
│   │   ├── Host/                 # Core emulation layer
│   │   │   ├── Emulation/        # Emulator cores (GBCore, GBACore, etc.)
│   │   │   │   ├── GBCore.swift          # GB/GBC core
│   │   │   │   ├── GBACore.swift         # GBA core
│   │   │   │   ├── EmulatorCore.swift    # Core protocol
│   │   │   │   └── EmulatorCoreFactory.swift  # Core factory
│   │   │   ├── Input/            # Input handling
│   │   │   ├── Rendering/        # Metal rendering pipeline
│   │   │   │   └── MetalRenderer.swift
│   │   │   ├── Audio/            # AVAudioEngine audio
│   │   │   │   └── AudioEngine.swift
│   │   │   └── SaveStates/       # Save state storage
│   │   ├── XemuCores/            # Swift ↔ C++ bridge
│   │   │   ├── XemuCores.swift   # Swift API to C cores
│   │   │   └── include/          # C header imports
│   │   ├── Models/               # Data models
│   │   ├── Persistence/           # Core Data storage
│   │   ├── Services/             # App services
│   │   └── UI/                   # Reusable UI components
│   ├── lib/                       # Pre-built C++ libraries
│   ├── Tests/                     # Unit tests
│   ├── Package.swift              # Swift Package manifest
│   ├── project.yml                # XcodeGen configuration
│   └── test.sh                    # Test automation script
│
├── cores/                         # C++ emulation cores library
│   ├── src/
│   │   ├── gb/                   # Gambatte wrapper (GB/GBC)
│   │   │   ├── gambatte_wrapper.cpp/.h
│   │   │   ├── gambatte_video.cpp
│   │   │   ├── gambatte_audio.cpp
│   │   │   ├── gambatte_input.cpp
│   │   │   └── gambatte_savestate.cpp
│   │   ├── gba/                  # mGBA wrapper (GBA)
│   │   │   ├── mgba_wrapper.cpp/.h
│   │   │   ├── mgba_video.cpp
│   │   │   ├── mgba_audio.cpp
│   │   │   ├── mgba_input.cpp
│   │   │   └── mgba_savestate.cpp
│   │   └── api/                  # C API for Swift interop
│   │       ├── gb_api.cpp
│   │       └── gba_api.cpp
│   ├── include/                   # Public headers
│   │   └── xemu_cores/
│   │       ├── xemu_cores.h       # Main C API
│   │       ├── version.h
│   │       ├── gb/gambatte_wrapper.h
│   │       └── gba/mgba_wrapper.h
│   ├── tests/                     # C++ unit tests (Google Test)
│   ├── third_party/               # External cores
│   │   ├── gambatte/             # Gambatte libretro port
│   │   └── mgba/                 # mGBA emulator
│   ├── docs/                      # Documentation
│   │   └── REAL_CORES_INTEGRATION.md
│   ├── CMakeLists.txt            # CMake build config
│   ├── build.sh                   # macOS build script
│   └── build-ios.sh               # iOS build script
│
├── specs/                         # Feature specifications
│   └── 002-retro-emulator-foundation/
│       ├── tasks.md               # Implementation tasks
│       ├── plan.md               # Technical plan
│       ├── spec.md               # User stories
│       └── checklists/            # Feature checklists
│
└── README.md                     # This file
```

## Architecture

### Swift → C++ Integration Flow

```
┌─────────────────────────────────────────────────────────────┐
│                      iOS App (Swift)                        │
├─────────────────────────────────────────────────────────────┤
│  GamePlayView                                              │
│       │                                                    │
│       ▼                                                    │
│  GBCore / GBACore  ──►  XemuCores.swift  ──►  dlopen()   │
│  (EmulatorCore)         (Swift API)            │          │
│                                                 ▼          │
│                                    ┌──────────────────┐    │
│                                    │  libxemu_cores   │    │
│                                    │     (C API)      │    │
│                                    └──────────────────┘    │
│                                                 │          │
│                                                 ▼          │
│                                    ┌──────────────────┐    │
│                                    │   C++ Cores      │    │
│                                    │  (Gambatte/mGBA) │    │
│                                    └──────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

### Emulator Core Protocol

Each platform implements the `EmulatorCore` protocol:

```swift
public protocol EmulatorCore {
    var platform: Platform { get }
    func initialize() -> Bool
    func loadROM(romPath: String) -> Bool
    func start()
    func pause()
    func resume()
    func frame() -> Bool
    func stop()
    func cleanup()
    func getFrameBuffer() -> Data?
    func getAudioSamples() -> Data?
    func saveState() -> Data?
    func loadState(_ state: Data) -> Bool
    func setInput(_ inputType: Int, value: Float)
    func reset()
}
```

### Rendering Pipeline

- Metal-based GPU rendering
- Texture scaling and filtering
- 60 FPS frame timing
- RGB32 video buffer format

### Audio Engine

- AVAudioEngine for low-latency output
- Platform-aware sample rates (GB/GBC use native-friendly high-rate stream)
- Stereo output support

## Recent Stability Updates

- Removed temporary debugging traces from Swift UI/input paths and C bridge glue.
- Hardened GB/GBC runtime paths (frame loop, ROM lifecycle, and input state routing).
- Tuned platform-specific video profiles so GB stays natural while GBC remains brighter.

### Native Core Build Note

When changing files under `cores/src/` or `cores/third_party/`, rebuild the iOS core artifacts before launching the app:

```bash
cd cores
./build-ios.sh
```

The iOS app links `cores/XemuCores.xcframework`, so native source edits do not take effect until this rebuild step is completed.

## Requirements

- Xcode 16+
- iOS 17.0+ / macOS 14.0+
- Swift 5.10+
- CMake (for building C++ cores)

## Quick Start

### Prerequisites

- Xcode 16+ installed
- XcodeGen installed: `brew install xcodegen`

### Build iOS App

1. **Generate Xcode Project:**
```bash
cd ios/AppHost
xcodegen generate
```

2. **Build for iOS Simulator:**
```bash
xcodebuild -project Xemu.xcodeproj -scheme Xemu \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build
```

3. **Run on iOS Simulator:**
```bash
# Find simulator ID
xcrun simctl list devices available | grep "iPhone 17"

# Boot and open simulator
SIMULATOR_ID="<DEVICE_ID>"
xcrun simctl boot $SIMULATOR_ID
open -a Simulator

# Install app
xcrun simctl install $SIMULATOR_ID \
  ~/Library/Developer/Xcode/DerivedData/Xemu-*/Build/Products/Debug-iphonesimulator/Xemu.app

# Launch app
xcrun simctl launch $SIMULATOR_ID com.xemu.Xemu
```

### Build C++ Cores (Optional)

1. **For macOS:**
```bash
cd cores
./build.sh
```

2. **For iOS:**
```bash
cd cores
./build-ios.sh
```

The library will be built at `cores/build/local/lib/libxemu_cores.a`

### Testing

**Run Swift Unit Tests:**
```bash
cd ios/AppHost
swift test
```

**Or use the test script:**
```bash
cd ios/AppHost
./test.sh test
```

## Environment Variables

### USE_REAL_CORES

Controls whether to use real C++ cores or mock implementations.

| Value | Mode | Description |
|-------|------|-------------|
| `true` | Real | Uses Gambatte/mGBA C++ cores |
| `false` | Mock | Uses Swift mock implementations |
| (not set) | Real* | Default: real in release, mock in debug* |

*Note: In DEBUG builds, defaults to REAL cores. Use `USE_REAL_CORES=false` for mocks.

**Setting in Xcode:**
1. Product → Scheme → Edit Scheme (⌘<)
2. Select Run → Environment Variables
3. Add `USE_REAL_CORES` = `true` or `false`

## Development

### Running Tests with Mocks

Tests always use mock implementations to ensure fast, deterministic results:

```bash
cd ios/AppHost
./test.sh test
```

### Adding New Emulator Cores

1. Add C++ core to `cores/third_party/`
2. Implement wrapper in `cores/src/{gb,gba,nes}/`
3. Add C API functions in `cores/src/api/`
4. Create Swift wrapper in `ios/AppHost/Sources/XemuCores/`
5. Implement Swift core class in `ios/AppHost/Sources/Host/Emulation/`
6. Register in `EmulatorCoreFactory`

## License

Proprietary - All rights reserved.
