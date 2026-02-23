# NDS Support Plan: melonDS DS via libretro (First Working Path)

This document proposes a practical path to add Nintendo DS support to Xemu using
the `melonDS DS` libretro core as the first production-capable implementation path.

Goal: get a working NDS prototype integrated into the existing Xemu architecture
with minimal disruption to GB/GBA paths.

## Why This Path

Compared with a direct upstream `melonDS` embedding, libretro-based integration:
- reduces time-to-first-frame
- provides a stable, known core entry interface
- allows staged integration behind the existing `NDSCore` stub

Tradeoffs:
- extra adapter layer (libretro host bridge)
- licensing/compliance complexity (GPL)
- some DS-specific features exposed as core options, which require option mapping

## Current Xemu State (Relevant Integration Points)

- `Platform.NDS` exists: `ios/AppHost/Sources/Models/CommonTypes.swift`
- `EmulatorCoreFactory` already routes `.NDS` -> `NDSCore()`
- `NDSCore` is currently a stub:
  `ios/AppHost/Sources/Host/Emulation/NDSCore.swift`
- Native C bridge currently only exposes GB/GBA APIs:
  `ios/AppHost/Sources/XemuCoresLib/include/xemu_cores.h`

## Target Architecture (NDS Path)

```text
Swift UI / GamePlayView
  -> GamePlayViewModel
    -> NDSCore (Swift EmulatorCore implementation)
      -> XemuCores.swift / C shim
        -> xemu_cores.h NDS API
          -> xemu_nds_* C API implementation
            -> libretro host adapter
              -> melonDS DS core (libretro)
```

## Phase Plan

## Phase 0: Compliance + Dependency Locking (Required)

1. Choose exact upstreams
- `melonDS DS` libretro core repo URL + commit
- `libretro` headers/common code sources + commits

2. Record licensing
- Fill `THIRD_PARTY_NOTICES.md`
- Store upstream license files in vendored locations

3. Freeze versions
- Pin commit SHAs in a dependency manifest or README section

Deliverable:
- `docs/` note + `THIRD_PARTY_NOTICES.md` entries fully populated (no TODOs for NDS path)

## Phase 1: Native Core Adapter Skeleton (No Gameplay Yet)

Add a new native DS API to mirror GB/GBA patterns.

### 1.1 C API surface (`xemu_cores.h`)

Add DS-specific handles and functions:
- `xemu_nds_handle_t`
- create/destroy
- load/unload ROM
- run frame
- reset
- get video buffers (dual-screen aware)
- get audio buffer
- set buttons
- set touch input
- save/load state
- set/get core options (screen layout, screen gap, etc.)

### 1.2 DS-specific data types

NDS needs more than the GB/GBA API:
- dual-screen output metadata
- touch coordinates + touch down/up
- optional microphone input stub (future)

Proposed additions (C API):
- `xemu_nds_screen_layout_t` enum (`stacked`, `side_by_side`, `single_top`, `single_bottom`)
- `xemu_nds_touch_state_t` (`x`, `y`, `is_pressed`)
- either:
  - a single composited buffer, or
  - two separate buffers + metadata

Recommendation for first pass:
- return a **single composited RGBA buffer** from the native layer
- native layer composes top+bottom based on selected layout
- Swift renderer remains largely unchanged

Reason:
- simplest host integration with your existing `MetalRenderer` and `FrameBufferInfo`

### 1.3 Libretro host adapter skeleton

Create `cores/src/nds/` with:
- `melonds_libretro_wrapper.cpp/.h`
- `melonds_video.cpp`
- `melonds_audio.cpp`
- `melonds_input.cpp`
- `melonds_savestate.cpp`

Responsibilities:
- load libretro core
- provide libretro callbacks (video/audio/input/environment)
- map Xemu calls to retro API lifecycle
- cache latest video/audio buffers for Xemu polling

Deliverable:
- buildable DS adapter with fake frame/audio data or no-op path

## Phase 2: Minimal Playable NDS (Single Layout, Basic Controls)

### 2.1 NDSCore Swift implementation

Replace stub logic in `ios/AppHost/Sources/Host/Emulation/NDSCore.swift` with:
- native initialization
- ROM loading
- frame stepping
- `getFrameBufferInfo()` (preferred over `getFrameBuffer()`)
- audio retrieval
- save/load state
- reset

### 2.2 Input mapping (buttons)

Map Xemu inputs to NDS buttons:
- A/B/X/Y
- D-pad
- L/R
- Start/Select

Use existing `ControllerButton` enum where possible and extend mappings in:
- input bus / controller overlay
- touch controls view model

### 2.3 Touch/stylus support (minimal)

Required for many NDS games.

First-pass implementation:
- one-touch stylus point
- press / move / release
- map a dedicated “touch mode” UX in iOS overlay

Recommendation:
- Add a “Touch Cursor” interaction mode in gameplay UI:
  - drag on lower-screen interaction region
  - tap to stylus press

Deliverable:
- basic NDS ROM loads and runs
- audio/video present
- physical buttons work
- simple stylus touch works for menu navigation

## Phase 3: DS-Specific UX and Performance Controls

### 3.1 Dual-screen layouts

Add runtime layout options:
- stacked vertical (default portrait)
- side-by-side (landscape)
- single top focus
- single bottom focus

Store selection in user settings / per-game preferences.

### 3.2 Screen scaling and touch transform

Touch coordinates must map correctly from displayed/composited layout to native
DS touch screen coordinates (typically bottom screen only).

Implement:
- layout transform matrix
- letterboxing/pillarboxing compensation
- orientation-aware coordinate mapping

### 3.3 Core options bridge

Expose selected libretro core options through Xemu settings (only the safe subset):
- screen layout (if handled by core, otherwise by Xemu compositor)
- internal settings required for compatibility
- avoid exposing too many unstable debug options initially

### 3.4 Performance profiling

Benchmark on target device classes:
- iPhone tier 1 / 2 / 3 (as defined by your app)
- measure FPS stability, audio underruns, thermal impact

Deliverable:
- usable NDS gameplay experience on target hardware classes

## Phase 4: Save State + Compatibility Hardening

1. Save state support
- quick save/load parity with GB/GBA paths
- integrate with existing `SaveStatesView` and storage
- validate state compatibility across app versions/core updates (document policy)

2. ROM handling
- `.nds` file import detection
- metadata extraction stub/fallback (title, icon if feasible later)
- checksum generation and persistence

3. Compatibility testing
- boot test set
- input/touch regression tests
- audio/video smoke tests
- save/load smoke tests

Deliverable:
- NDS feature reaches “experimental but usable” tier

## Proposed File/Module Changes

## iOS / Swift

- `ios/AppHost/Sources/Host/Emulation/NDSCore.swift` (replace stub)
- `ios/AppHost/Sources/Host/Emulation/EmulatorCoreFactory.swift` (behavioral support only, already routes)
- `ios/AppHost/Sources/Host/Rendering/...` (if dual-buffer compositor is host-side)
- `ios/AppHost/Sources/Features/GamePlay/...` (touch/stylus UX + layout controls)
- `ios/AppHost/Sources/Models/...` (NDS layout/touch settings models)

## Native C/C++

- `ios/AppHost/Sources/XemuCoresLib/include/xemu_cores.h` (NDS API additions)
- `cores/src/api/nds_api.cpp` (new C bridge entry points)
- `cores/src/nds/*` (libretro host + melonDS wrapper)
- `cores/CMakeLists.txt` and iOS build scripts (link new sources/core)

## API Design Recommendations (Important)

1. Prefer `getFrameBufferInfo()` path in `EmulatorCore`
- NDS layouts may change dimensions dynamically
- width/height/pitch must stay attached to pixel data

2. Keep DS composition native-side initially
- one RGBA output to Swift reduces renderer churn
- move to dual-buffer host rendering later only if needed

3. Separate touch API from button bitmask
- DS stylus is not a normal button and needs coordinates
- avoid overloading `setInput(_ inputType:value:)` with hidden coordinate semantics

Recommended Swift-side extension (future):
- add optional `setTouch(x:y:isPressed:)` capability protocol for DS-like systems

## Risks and Mitigations

1. GPL / App Store compliance risk
- Mitigation: complete legal checklist and counsel review before shipping

2. Performance risk on older iPhones
- Mitigation: start with conservative defaults and profile early

3. Touch UX complexity
- Mitigation: ship minimal stylus mode first; improve gestures later

4. Libretro integration complexity
- Mitigation: isolate adapter inside `cores/src/nds/` and keep Xemu C API stable

## Definition of Done (First NDS Experimental Release)

- [ ] `.nds` ROM imports successfully
- [ ] Selected NDS game boots and renders
- [ ] Audio plays without constant underruns
- [ ] Buttons (A/B/X/Y, D-pad, L/R, Start/Select) work
- [ ] Stylus touch works in at least menu/game basic interactions
- [ ] Save/load state basic flow works
- [ ] Layout switch (at least 2 modes) works
- [ ] Crash-free 10-minute smoke session on target devices
- [ ] `THIRD_PARTY_NOTICES.md` and source availability prepared

## Immediate Next Tasks (Suggested)

1. Vendor and pin `melonDS DS` libretro core + libretro headers (exact commits)
2. Add `xemu_nds_*` C API declarations to `xemu_cores.h`
3. Implement `cores/src/api/nds_api.cpp` stub returning `XEMU_ERROR_UNSUPPORTED_FORMAT` / no-op
4. Replace `NDSCore` stub with bridge calls and error plumbing
5. Add gameplay UI task list for dual-screen touch layout

