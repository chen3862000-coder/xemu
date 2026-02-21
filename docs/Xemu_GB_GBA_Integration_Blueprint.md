# Xemu -- GB/GBC/GBA Integration Blueprint (Gambatte + mGBA)

This document summarizes the recommended architecture and best practices
for integrating Gambatte (GB/GBC) and mGBA (GBA) C++ cores into a
Swift-based iOS emulator application.

Focus areas: - Stable Swift ↔ C ↔ C++ boundaries - Proper threading and
frame pacing - Efficient Metal rendering - Low-latency audio via ring
buffer - Save state and SRAM management - Avoiding common integration
pitfalls

------------------------------------------------------------------------

# 1. Target Architecture

SwiftUI / Host Layer\
↓\
Swift Core Wrapper (GBCore.swift / GBACore.swift)\
↓\
XemuCores.swift (Typed Swift wrapper, no dlopen)\
↓\
xemu_cores.h (Stable C ABI)\
↓\
gb_api.cpp / gba_api.cpp (C shim)\
↓\
gambatte_wrapper.cpp / mgba_wrapper.cpp (C++ wrapper)\
↓\
Gambatte / mGBA core

Key Principle: The Swift layer should never directly depend on Gambatte
or mGBA. Only the stable C ABI should be visible.

------------------------------------------------------------------------

# 2. C ABI Design Principles

Use opaque handles and C-compatible types only.

Recommended function structure:

-   xemu_core_create()
-   xemu_core_destroy()
-   xemu_core_load_rom()
-   xemu_core_run_frame()
-   xemu_core_video_buffer()
-   xemu_core_audio_read_i16()
-   xemu_core_save_state()
-   xemu_core_load_state()
-   xemu_core_sram_read()
-   xemu_core_sram_write()

Rules: - Use extern "C" - Avoid C++ types in headers - No exceptions
across ABI boundary - Use pull-based APIs for audio

------------------------------------------------------------------------

# 3. Build Artifact Strategy

Do NOT use dlopen for local cores.

Instead:

-   Build XemuCores.xcframework
-   Include slices for:
    -   ios-arm64
    -   iossimulator-arm64
    -   optional iossimulator-x86_64
-   Import via Swift Package Manager binaryTarget
-   Use direct linking

This eliminates: - rpath issues - codesigning issues - dynamic loading
failures

------------------------------------------------------------------------

# 4. Frame Execution Model

Use Swift to drive frame execution.

Recommended flow:

-   CADisplayLink triggers per-frame tick
-   Emulator runs on a dedicated serial queue
-   run_frame() produces:
    -   Updated video buffer
    -   Audio samples appended to ring buffer

Keep emulator execution off the main thread.

------------------------------------------------------------------------

# 5. Video Pipeline

Standardize on a single format:

-   32-bit RGBA or BGRA
-   Metal texture format: .bgra8Unorm or .rgba8Unorm

Typical resolutions:

-   GB/GBC: 160×144
-   GBA: 240×160

Avoid per-frame allocations. Reuse buffers where possible.

------------------------------------------------------------------------

# 6. Audio Integration (Critical)

Do NOT return Data per frame.

Correct approach:

-   C++ core pushes samples into ring buffer
-   Swift AudioEngine pulls samples in render callback
-   Use signed 16-bit interleaved stereo (44.1kHz)

If insufficient samples available: - Fill with zeros - Avoid blocking
audio thread

------------------------------------------------------------------------

# 7. Input Handling

Define unified input enum in Swift:

-   up, down, left, right
-   A, B, Start, Select
-   L, R (GBA only)

Set input immediately on change. Do not delay until frame boundary.

------------------------------------------------------------------------

# 8. Save States vs SRAM

## SRAM (Battery Save)

-   Persist periodically
-   Persist on app background
-   Key by ROM hash

## Save States

-   User-triggered
-   Store blob + metadata
-   Use state_size API before saving

Keep SRAM and save states separate.

------------------------------------------------------------------------

# 9. ROM Handling

After import:

-   Copy ROM to app sandbox
-   Compute SHA hash
-   Use hash for:
    -   Save location
    -   Multiplayer compatibility
    -   Community features

Avoid long-term use of security-scoped URLs.

------------------------------------------------------------------------

# 10. Threading Model Summary

Main Thread: - UI - Metal presentation scheduling

Emulation Queue: - run_frame() - input updates

Audio Thread: - Pull samples from ring buffer

Never block audio thread.

------------------------------------------------------------------------

# 11. Common Integration Bugs

1.  Missing simulator slice in library
2.  Missing extern "C" (name mangling)
3.  Audio crackling from bad buffering
4.  Frame stutter from main-thread emulation
5.  Per-frame memory allocations
6.  Input latency from delayed updates

------------------------------------------------------------------------

# 12. Recommended Immediate Action Plan

1.  Replace dlopen with XCFramework direct linking
2.  Implement generic xemu_core\_\* API
3.  Update GBCore.swift to use handle-based engine
4.  Implement audio ring buffer
5.  Add SRAM auto-save on background
6.  Confirm simulator + device builds both succeed

------------------------------------------------------------------------

# 13. Strategic Outcome

With this structure:

-   GB/GBC and GBA share one ABI
-   Swift layer remains clean
-   Performance remains stable at 60 FPS
-   Audio remains low-latency
-   Future systems can reuse the same structure

This creates a scalable foundation for your multi-system emulator
platform.
