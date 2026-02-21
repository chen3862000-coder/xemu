# Gameplay Stability Tasks

Last updated: 2026-02-21

## Scope
- GB/GBC in-game screen glitching
- Virtual pad input not responding reliably
- Intermittent crash when opening/quitting gameplay

## Root Causes Identified
- Input bridge sent non-stateful button masks, clearing held inputs on release.
- GB/GBA host input mapping did not match wrapper button index contract.
- Renderer uploaded frame data and presented mismatched textures in ping-pong flow.
- Gameplay teardown allowed draw-loop/lifecycle overlap during exit transitions.

## Implementation Plan (Requested Order)
- [x] 1) Fix wrapper input state handling in `ios/AppHost/Sources/XemuCores/XemuCores.swift`
- [x] 2) Fix GB/GBA core input mapping and `InputBus` guarding
- [x] 3) Fix Metal renderer ping-pong upload/present order
- [x] 4) Harden teardown lifecycle for gameplay exit/open transitions
- [x] 5) Run tests and capture current result/blockers

## Notes
- Third-party core implementation source is not present in-repo; only bridge/API contracts are directly patchable here.
- `./test.sh test` completed but reports simulator-only test execution and skipped local test run.
- `swift test` currently fails at link stage in this environment due missing native `xemu_gb_*`/`xemu_gba_*` symbols.

## Follow-up Pass (2026-02-21)
- [x] Cancel delayed gameplay startup task on view dismiss to avoid late start/teardown overlap.
- [x] Make gameplay exit path synchronous on main actor (remove async Task stop wrappers in view).
- [x] Add native-call locking in GB/GBA wrappers to prevent concurrent handle access during frame/input/cleanup.
- [x] Replace D-pad with drag-based directional control area (supports hold/slide/diagonal transitions).
- [x] Prevent potential double ROM teardown by avoiding unload in `stop()` and relying on `cleanup()` shutdown.
- [x] Copy video/audio buffers while native lock is held (do not expose raw pointer lifetimes to caller).
- [x] Route virtual pad touch input directly to active core mapping path (bypass async InputBus hop for touch controls).
- [x] Marshal frame tick work onto `MainActor` before stepping emulator session.
- [x] Simplify renderer to a single frame texture to remove ping-pong presentation mismatch risk.
- [x] Replace drag-area D-pad with explicit directional touch buttons for simulator click reliability.
- [x] Remove per-frame async task scheduling from tick path to reduce frame jitter and ordering issues.
- [x] Fix GB C API invalid free (`videoBuffer.data` reassigned to vector memory then `delete[]` in destroy).
- [x] Rebuild `cores/XemuCores.xcframework` after native C++ fixes using `cores/build-ios.sh`.
- [x] Raise D-pad gesture priority and enlarge directional hit targets for simulator touch reliability.
- [x] Add 50ms delayed release for touch inputs to ensure tap events survive frame-boundary sampling.
- [x] Increased minimum touch press to 200ms for simulator frame pacing.
- [x] Added native GB input bitmask tracing in `xemu_gb_set_input` for end-to-end input verification.
- [x] Disabled audio playback path on simulator to avoid HALC overload and improve input/frame responsiveness.
- [x] Updated Gambatte frame stepping to loop `runFor()` until frame completion (`!= -1`) using upstream libretro-style sample cadence.

## Remaining Risk
- Native core internals are still opaque in this repository; if malloc checksum crashes persist after wrapper serialization, root cause is likely inside linked third-party core implementation.
