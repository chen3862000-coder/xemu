# Xemu Cores Architecture

## Overview

The Xemu Cores library provides a clean abstraction layer over existing emulation cores (Gambatte for GB/GBC, mGBA for GBA) with a unified C API for cross-language integration.

## Architecture Layers

```
┌─────────────────────────────────────────┐
│           Swift / Objective-C           │
│           (iOS/macOS Apps)              │
├─────────────────────────────────────────┤
│            C API Layer                  │
│     (xemu_cores.h / xemu_cores.cpp)     │
├─────────────────────────────────────────┤
│         Wrapper Classes                 │
│   (GambatteWrapper / mGBAWrapper)       │
├─────────────────────────────────────────┤
│         Emulation Cores                 │
│    (Gambatte / mGBA libraries)          │
└─────────────────────────────────────────┘
```

## Components

### 1. C API Layer (`src/api/`)

**Purpose**: Provide a stable, language-agnostic interface

**Files**:
- `gb_api.cpp` - GB/GBC C API implementation
- `gba_api.cpp` - GBA C API implementation
- `error_codes.cpp` - Error code definitions and string conversion

**Design**:
- Opaque handles hide C++ implementation details
- Plain C structs for data exchange
- Explicit memory management (create/destroy pairs)
- Error codes for all operations

### 2. Wrapper Classes (`src/gb/`, `src/gba/`)

**Purpose**: Adapt emulation cores to common interface

**GB/GBC** (`GambatteWrapper`):
- Wraps Gambatte C++ API
- Manages video/audio buffers
- Handles input state
- Implements save state serialization

**GBA** (`mGBAWrapper`):
- Wraps mGBA C API
- Similar interface to GambatteWrapper
- Handles GBA-specific features (L/R buttons)

**Design**:
- RAII pattern for resource management
- PIMPL idiom for ABI stability
- Buffer ownership remains with wrapper
- Non-copyable, movable

### 3. Emulation Cores (`third_party/`)

**Gambatte**:
- GB/GBC emulator
- C++ interface
- Accurate cycle timing
- Save state support

**mGBA**:
- GBA emulator
- C interface
- High compatibility
- BIOS support

## Data Flow

### Video Frame Rendering

```
Emulation Core
      ↓
Wrapper (buffers video to internal RGBA buffer)
      ↓
C API (returns pointer to buffer)
      ↓
Swift/ObjC (renders to Metal/OpenGL texture)
```

### Audio Generation

```
Emulation Core
      ↓
Wrapper (collects samples into ring buffer)
      ↓
C API (returns sample array)
      ↓
Swift/ObjC (feeds to AVAudioEngine)
```

### Input Handling

```
User Input (touch screen / controller)
      ↓
Swift/ObjC (converts to button bitmask)
      ↓
C API (xemu_gb_set_input / xemu_gba_set_input)
      ↓
Wrapper (updates internal input state)
      ↓
Emulation Core (reads input each frame)
```

## Buffer Management

### Video Buffers

- **GB/GBC**: 160x144 RGBA8888 = 92,160 bytes
- **GBA**: 240x160 RGBA8888 = 153,600 bytes
- **Lifetime**: Buffer owned by wrapper, pointer valid until next frame
- **Thread Safety**: Buffer updated only during `run_frame()`

### Audio Buffers

- **Sample Rate**: 44,100 Hz (configurable)
- **Frame Duration**: ~16.74ms at 59.73 FPS
- **Samples per Frame**: ~735 stereo frames (1,470 samples)
- **Format**: 16-bit signed, interleaved stereo (L, R, L, R...)
- **Ring Buffer**: Wrappers may use ring buffer for smooth audio

### Save State Buffers

- **GB/GBC**: ~128KB
- **GBA**: ~512KB
- **Format**: Opaque binary blob (core-specific)
- **Validation**: CRC/checksum on load (recommended)

## Build System

### CMake Structure

```
cores/
├── CMakeLists.txt          # Root configuration
├── src/gb/CMakeLists.txt   # GB core sources
├── src/gba/CMakeLists.txt  # GBA core sources
└── tests/CMakeLists.txt    # Test configuration
```

### Targets

- `xemu_cores_shared` - Shared library (.dylib/.so)
- `xemu_cores_static` - Static library (.a)
- `xemu_cores_framework` - iOS/macOS framework
- `xemu_cores_test` - Unit tests

### Platform Support

**macOS**:
- Universal binary (x86_64 + arm64)
- Minimum version: macOS 11.0
- Build: `./build.sh`

**iOS**:
- Device (arm64) + Simulator (arm64, x86_64)
- Minimum version: iOS 14.0
- Build: `./build-ios.sh`

## Testing Strategy

### Unit Tests

- Wrapper class tests (mock cores)
- API layer tests (validate C interface)
- Error handling tests

### Integration Tests

- End-to-end with real ROMs
- Save state round-trip
- Performance benchmarks

### Test Fixtures

Located in `tests/fixtures/`:
- Small test ROMs (homebrew)
- Expected frame dumps
- Save state files

## Performance Considerations

### Memory

- Zero-copy video buffer access
- Pre-allocated audio buffers
- Minimal allocations during emulation

### CPU

- Frame-based execution (not cycle-accurate)
- Configurable frame skip for performance
- Optional threading (run core on background thread)

### Battery (Mobile)

- Suspend emulation when backgrounded
- Reduce audio quality for power saving
- Optional vsync off for max performance

## Future Enhancements

1. **Additional Cores**:
   - Snes9x (SNES)
   - Genesis Plus GX (Genesis/Mega Drive)
   - PCSX ReARMed (PS1)

2. **Features**:
   - Shader support (video filters)
   - Netplay support
   - Achievements system

3. **Optimizations**:
   - JIT compilation for hot paths
   - Metal compute shaders for rendering
   - Background loading/saving

## Security

- ROM data is read-only
- No network access
- Sandboxed file system access
- Save states validated before loading

## License

- Xemu Cores: MIT License
- Gambatte: GPL v2
- mGBA: MPL 2.0

Applications using this library must comply with emulation core licenses.
