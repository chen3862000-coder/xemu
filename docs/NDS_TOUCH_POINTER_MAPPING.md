# NDS Touch Pointer Mapping

This document captures the touch-coordinate rule that fixed the March 2026
stacked-layout regression where visual touch points and in-game hit points
drifted apart.

## Problem Summary

The app sends DS-local stylus coordinates (`x: 0..255`, `y: 0..191`) through
the NDS libretro backend. melonDS DS, however, interprets libretro pointer
coordinates in **full frame space** (the composed output frame), then maps that
to the active touch screen.

If DS-local coordinates are forwarded directly to libretro pointer axes, touch
hits are offset (especially in stacked mode).

## Mapping Contract

When reporting `RETRO_DEVICE_POINTER_X/Y`, first convert DS-local stylus
coordinates to frame-space:

1. Determine current composed frame size (`frameWidth`, `frameHeight`).
2. If layout is side-by-side family (`frameWidth >= frameHeight * 2`):
   - add `frameWidth / 2` to `x` (bottom screen on right half).
3. Else if layout is top-bottom family (`frameHeight > frameWidth`):
   - add `frameHeight / 2` to `y` (bottom screen on lower half).
4. Clamp to `[0, frameWidth-1]` and `[0, frameHeight-1]`.
5. Normalize/clamp to libretro pointer range from those frame-space values.

Implementation: [`cores/src/nds/nds_touch_pointer_mapping.h`](/Users/spiderck/Development/xemu/cores/src/nds/nds_touch_pointer_mapping.h)

## Regression Tests

Unit tests that lock this behavior:

- [`cores/tests/nds/nds_touch_pointer_mapping_test.cpp`](/Users/spiderck/Development/xemu/cores/tests/nds/nds_touch_pointer_mapping_test.cpp)
  - stacked layout maps to lower half
  - side-by-side maps to right half
  - single-screen keeps local coordinates
  - out-of-range values clamp
  - invalid frame sizes use safe fallback

### Run Commands

Build and run the full C++ unit-test binary:

```bash
cd cores
cmake -S . -B build-tests -DBUILD_TESTS=ON -DBUILD_SHARED_LIBS=OFF -DBUILD_STATIC_LIBS=ON -DUSE_REAL_CORES=ON -DCMAKE_POLICY_VERSION_MINIMUM=3.5
cmake --build build-tests --target xemu_cores_test -j8
```

Run only the NDS touch mapping regression suite:

```bash
cd cores
./build-tests/tests/xemu_cores_test '--gtest_filter=NDSTouchPointerMappingTest.*'
```

## Notes for Future Layout Work

- Do not treat DS-local stylus coordinates as libretro pointer-frame
  coordinates.
- Any compositor/layout change that affects frame dimensions should be validated
  against the NDS touch mapping tests above.
