# Xemu Cores Library

A standalone C++ emulation cores library for Game Boy (GB), Game Boy Color (GBC), and Game Boy Advance (GBA) emulation.

## Overview

This library provides:
- **Gambatte** integration for GB/GBC emulation
- **mGBA** integration for GBA emulation
- C API for Swift/Objective-C interop
- Cross-platform support (macOS, iOS)

## Project Structure

```
cores/
├── include/xemu_cores/    # Public headers
│   ├── xemu_cores.h       # Main C API header
│   ├── version.h          # Version information
│   └── gb/                # GB/GBC specific headers
│   └── gba/               # GBA specific headers
├── src/                   # Implementation
│   ├── gb/                # Gambatte wrapper
│   ├── gba/               # mGBA wrapper
│   └── api/               # C API implementation
├── tests/                 # Unit and integration tests
│   ├── gb/                # GB core tests
│   ├── gba/               # GBA core tests
│   ├── api/               # C API tests
│   └── integration/       # End-to-end tests
├── third_party/           # Git submodules
│   ├── gambatte/          # GB/GBC core
│   └── mgba/              # GBA core
└── docs/                  # Documentation

```

## Building

### macOS

```bash
cd cores
./build.sh
```

This creates:
- `build/libxemu_cores.dylib` (shared library)
- `build/libxemu_cores.a` (static library)
- `build/xemu_cores.framework` (iOS/macOS framework)

### iOS

```bash
cd cores
./build-ios.sh
```

This creates a universal iOS framework supporting both device and simulator.

## Dependencies

- CMake 3.16+
- C++17 compatible compiler
- Gambatte (git submodule)
- mGBA (git submodule)
- Google Test (for testing)

## API Usage

See [docs/API.md](docs/API.md) for detailed API documentation.

Quick example:

```c
#include <xemu_cores/xemu_cores.h>

// Create GB core
xemu_gb_handle_t gb = xemu_gb_create();

// Load ROM
xemu_error_t err = xemu_gb_load_rom(gb, "game.gb", rom_data, rom_size);

// Run frame
xemu_gb_run_frame(gb);

// Get video buffer
const uint8_t* video = xemu_gb_get_video_buffer(gb);

// Cleanup
xemu_gb_destroy(gb);
```

## Swift Integration

See [docs/SWIFT_INTEGRATION.md](docs/SWIFT_INTEGRATION.md) for Swift binding details.

## License

This library is part of the Xemu project. The emulation cores (Gambatte, mGBA) have their own licenses.

## Architecture

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for internal architecture details.
