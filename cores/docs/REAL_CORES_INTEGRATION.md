# Real Gambatte/mGBA Integration Research

## Executive Summary

This document outlines the research and approach for integrating real Gambatte (GB/GBC) and mGBA (GBA) emulation cores into the Xemu iOS app, with dual-mode support (mocks for tests, real for runtime).

## Current Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Swift App (iOS)                        │
├─────────────────────────────────────────────────────────────┤
│  GBCore.swift  │  GBACore.swift  │  NESCore.swift       │
├─────────────────────────────────────────────────────────────┤
│              XemuCores Swift API (XemuCores.swift)         │
│              - dlopen/dlsym for dynamic loading            │
│              - Falls back to mock implementations           │
├─────────────────────────────────────────────────────────────┤
│                    C API Layer (xemu_cores.h)              │
│   xemu_gb_load_rom() │ xemu_gb_step() │ xemu_gba_*()     │
├─────────────────────────────────────────────────────────────┤
│           C++ Wrapper Layer (gb/gambatte_wrapper.cpp)        │
│           Currently: MOCK implementations                   │
├─────────────────────────────────────────────────────────────┤
│           Real Cores (third_party/) - NOT LINKED            │
│           - gambatte (libretro port)                        │
│           - mgba (full emulator)                            │
└─────────────────────────────────────────────────────────────┘
```

## Integration Options

### Option 1: Direct Core Integration (Recommended for Production)

**Approach**: Link directly against Gambatte/mGBA libraries

**Pros**:
- Full control over core behavior
- No intermediate libretro layer
- Best performance

**Cons**:
- Complex build system (Gambatte uses Makefiles)
- Requires platform-specific builds for each architecture
- More maintenance overhead

**Implementation**:
```bash
# Build Gambatte
cd cores/third_party/gambatte
make -j4

# Build mGBA  
cd cores/third_party/mgba
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j4
```

### Option 2: Libretro Adapter (Recommended for Cross-Platform)

**Approach**: Use libretro API which provides standardized interface

**Pros**:
- Consistent API across all cores
- Easier build system (many cores support libretro)
- Core can be swapped easily
- Already configured in project

**Cons**:
- Additional abstraction layer
- Slightly more overhead

**Implementation**:
```bash
# Build libretro cores
cd cores
./build-libretro.sh

# Output: libretro_gambatte.a, libretro_mgba.a
```

## Dual-Mode Architecture

### Build-Time Configuration

```cmake
# CMakeLists.txt
option(USE_REAL_CORES "Build with real emulation cores" OFF)

if(USE_REAL_CORES)
    add_definitions(-DXEMU_USE_REAL_CORES=1)
    target_link_libraries(xemu_cores PRIVATE 
        ${CMAKE_CURRENT_SOURCE_DIR}/third_party/gambatte/libgambatte/libgambatte.a
        ${CMAKE_CURRENT_SOURCE_DIR}/third_party/mgba/build/libmgba.a
    )
endif()
```

### Runtime Configuration

```swift
// XemuCores.swift
enum CoreMode {
    case real
    case mock
}

class XemuCores {
    static var gbCoreMode: CoreMode = .mock
    
    static func initialize() {
        #if DEBUG
        if ProcessInfo.processInfo.environment["USE_REAL_CORES"] == "true" {
            gbCoreMode = .real
        }
        #endif
        
        if gbCoreMode == .real {
            // Try to load real C library
            if loadRealCores() {
                print("[XemuCores] Using REAL Gambatte/mGBA cores")
            } else {
                print("[XemuCores] Real cores unavailable, using mocks")
                gbCoreMode = .mock
            }
        }
    }
}
```

### C++ Wrapper Dual-Mode

```cpp
// gambatte_wrapper.cpp
#ifdef XEMU_USE_REAL_CORES
#include <gambatte.h>
#endif

class GambatteCore {
private:
#ifdef XEMU_USE_REAL_CORES
    gambatte::GB* realCore = nullptr;
#endif
    
public:
    int loadROM(const uint8_t* data, size_t size) {
#ifdef XEMU_USE_REAL_CORES
        if (realCore) {
            return realCore->load(data, size);
        }
#endif
        // Mock implementation
        return mockLoadROM(data, size);
    }
    
    int runFrame(uint32_t* videoBuffer, int pitch, 
                int16_t* audioBuffer, size_t* samplesOut) {
#ifdef XEMU_USE_REAL_CORES
        if (realCore) {
            return realCore->runFor(videoBuffer, pitch, audioBuffer, *samplesOut);
        }
#endif
        // Mock implementation
        return mockRunFrame(videoBuffer, audioBuffer, samplesOut);
    }
};
```

## Gambatte API Reference

### Core Methods

```cpp
// Include
#include <gambatte.h>

// Initialize
gambatte::GB* gb = new gambatte::GB();

// Load ROM
int result = gb->load(romData, romSize, gambatte::GB::FORCE_CGB);

// Run frame
size_t samples = gb->runFor(videoBuffer, 160,  // pitch in pixels
                            audioBuffer, 35112); // max samples

// Input
struct InputGetter : gambatte::InputGetter {
    virtual unsigned operator()() {
        return buttons;  // Bitmask: A=1, B=2, SELECT=4, START=8, 
                        // RIGHT=0x10, LEFT=0x20, UP=0x40, DOWN=0x80
    }
};
gb->setInputGetter(&inputGetter);

// Save state
size_t stateSize = gb->stateSize();
std::vector<char> state(stateSize);
gb->saveState(state.data());
gb->loadState(state.data());

// Properties
bool isCgb = gb->isCgb();
bool isLoaded = gb->isLoaded();
```

### Video Format
- Resolution: 160x144 (GB), 240x144 (GBC in mode 3)
- Format: RGB32 (0xRRGGBB)
- Pitch: 160 pixels

### Audio Format
- Samples per frame: 35112 (GB), 140544 (GBC)
- Format: 16-bit stereo PCM
- Sample rate: 44100 Hz

## mGBA API Reference

### Core Methods

```cpp
// Include
#include <mgba/core.h>

// Initialize
struct mCore* core = mCoreFind("gb");  // or "gba", "gbc"

// Load ROM
mCoreLoadROM(core, "rom.gb");

// Run frame
mCoreRunFrame(core);

// Video
uint32_t* buffer;
int w, h;
mCoreGetVideoBuffer(core, &buffer, &w, &h);

// Audio
int16_t* samples;
mCoreGetAudioBuffer(core, &samples);

// Input
mCoreSetInputPollCallback(core, inputPoll, userdata);
mCoreSetInput(core, mCORE_INPUT_A, pressed);

// Save state
void* state = malloc(mCoreGetStateSize(core));
mCoreSaveState(core, state, 0);
mCoreLoadState(core, state, 0);
free(state);
```

### Video Format
- Resolution: 240x160 (GBA), 160x144 (GB/GBC)
- Format: RGB32

### Audio Format
- Samples: 2048 per frame (GBA)
- Format: 16-bit stereo

## Build Scripts

### build-libretro.sh

```bash
#!/bin/bash
set -e

# Build libretro Gambatte
cd third_party/gambatte
make -j4 libretro.a

# Build libretro mGBA  
cd ../../mgba
make -j4 libretro

# Copy to lib/
mkdir -p ../../lib
cp third_party/gambatte/libretro.a ../../lib/libretro_gambatte.a
cp third_party/mgba/libretro_mgba.a ../../lib/libretro_mgba.a
```

### build.sh with cores

```bash
#!/bin/bash
WITH_CORES=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --with-cores)
            WITH_CORES=true
            shift
            ;;
        *)
            shift
            ;;
    esac
done

mkdir -p build
cd build

if [ "$WITH_CORES" = true ]; then
    cmake .. -DUSE_REAL_CORES=ON
else
    cmake .. -DUSE_REAL_CORES=OFF
fi

make -j4
```

## Testing Strategy

### Unit Tests (Always Use Mocks)
- Compile with `XEMU_USE_MOCKS=1`
- 46 C++ tests pass
- 14 Swift tests pass

### Integration Tests
```swift
// Test real core loading
func testRealCoreLoads() {
    guard let rom = loadTestROM() else { return }
    
    let result = XemuCores.loadROM(rom, system: .gbc)
    XCTAssertEqual(result, XemuError.success)
    
    // Verify real core used
    XCTAssertTrue(XemuCores.isUsingRealCores)
}
```

### Runtime Behavior

| Environment | Core Mode | Behavior |
|-------------|-----------|----------|
| CI/Tests | Mock | Uses mock implementations |
| Debug (SIMULATOR) | Configurable | Uses USE_REAL_CORES env var |
| Debug (DEVICE) | Real | Uses real if available |
| Release | Real | Uses real cores |

## Recommended Implementation Order

1. **T224-T226**: Research and document APIs (done above)
2. **T227-T230**: Update C++ wrappers with dual-mode #ifdef
3. **T231**: Create build-libretro.sh
4. **T232-T235**: Update Swift integration with env detection
5. **T236-T238**: Update build scripts
6. **T239-T242**: Test both modes
7. **T243-T245**: Document final integration

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Core crashes | Graceful fallback to mock |
| Memory leaks | Instruments testing in debug |
| Performance | Profile with real cores vs mocks |
| Build complexity | Libretro provides abstraction |

## Conclusion

The recommended approach is **Option 2 (Libretro)** with dual-mode support:
- Simpler build system
- Standardized API
- Easy to swap cores
- Tests use mocks, production uses real
- Already have submodules ready
