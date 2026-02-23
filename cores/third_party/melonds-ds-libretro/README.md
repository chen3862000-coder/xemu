# melonDS DS libretro (Vendor Drop-In)

Place the vendored `melonDS DS` libretro core source or prebuilt static library
artifacts here.

Current integration status:

- `/Users/spiderck/Development/xemu/cores/src/nds/nds_backend_libretro.cpp` contains
  the host adapter + callback plumbing.
- `/Users/spiderck/Development/xemu/cores/src/nds/nds_melonds_libretro_binding.cpp`
  contains the `retro_*` symbol binding seam.
- `CMake` and `/Users/spiderck/Development/xemu/cores/build-ios.sh` now support
  enabling symbol binding and merging a prebuilt archive.

Recommended drop-in paths (future):

- Source checkout: `cores/third_party/melonds-ds-libretro/src/...`
- Prebuilt static archive (example): `cores/third_party/melonds-ds-libretro/lib/libmelonds_ds_libretro.a`

Build script env vars (already supported):

- `ENABLE_NDS_LIBRETRO_BACKEND=ON`
- `ENABLE_NDS_MELONDS_LIBRETRO_SYMBOLS=ON`
- `NDS_MELONDS_LIBRETRO_STATIC_LIB=/absolute/path/to/libmelonds_ds_libretro.a`
