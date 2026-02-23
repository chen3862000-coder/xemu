# libretro Headers (Vendor Drop-In)

Place vendored libretro headers here for NDS core integration.

Expected next-step files:

- `include/libretro.h`

Notes:

- The current NDS adapter uses a minimal local ABI shim in
  `/Users/spiderck/Development/xemu/cores/src/nds/nds_libretro_abi.h`.
- Once `libretro.h` is vendored, we can replace the local shim types with the
  official header to reduce drift.
