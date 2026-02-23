# NDS Vendoring Guide (melonDS + libretro)

This project's current NDS implementation path is:

- host app (`Swift`) -> `xemu_nds_*` C API
- native backend adapter -> **libretro** callback model
- target core -> **melonDS DS libretro core** (`retro_*` symbols)

## Important Distinction

There are two different codebases:

1. **Upstream `melonDS` emulator repo** (desktop/frontends)
2. **`melonDS DS` libretro core** (exports `retro_*` functions)

The upstream repo at:

- `/Users/spiderck/Development/xemu/cores/third_party/melonDS`

does **not** export libretro `retro_*` entrypoints and cannot be linked directly
into the current libretro-based NDS adapter without additional work.

## What the current code expects

When enabling symbol binding, the build expects a static archive that exports:

- `retro_init`
- `retro_deinit`
- `retro_api_version`
- `retro_get_system_info`
- `retro_get_system_av_info`
- `retro_set_environment`
- `retro_set_video_refresh`
- `retro_set_audio_sample`
- `retro_set_audio_sample_batch`
- `retro_set_input_poll`
- `retro_set_input_state`
- `retro_load_game`
- `retro_unload_game`
- `retro_run`

## Recommended vendor layout

- Official/headers:
  - `/Users/spiderck/Development/xemu/cores/third_party/libretro/include/libretro.h`
- melonDS libretro source or build outputs:
  - `/Users/spiderck/Development/xemu/cores/third_party/melonds-ds-libretro/`
  - example archive path:
    `/Users/spiderck/Development/xemu/cores/third_party/melonds-ds-libretro/lib/libmelonds_ds_libretro.a`

## Preflight validation

Validate the archive before wiring it into the build:

```bash
/Users/spiderck/Development/xemu/cores/scripts/verify-libretro-core.sh \
/absolute/path/to/libmelonds_ds_libretro.a
```

## Offline local build helper (for vendored repos)

If you have vendored the `melonds-ds` repo and all its dependencies under
`/Users/spiderck/Development/xemu/cores/third_party`, use:

```bash
/Users/spiderck/Development/xemu/cores/scripts/build-melonds-ds-libretro-static.sh
```

This helper:

- enables a local patch that builds `melondsds_libretro` as a static archive
- sets `FETCHCONTENT_SOURCE_DIR_*` overrides for local dependency checkouts
- forces `FETCHCONTENT_FULLY_DISCONNECTED=ON`
- validates the built archive exports `retro_*`

## Build xemu cores with NDS libretro backend enabled

```bash
cd /Users/spiderck/Development/xemu/cores
ENABLE_NDS_LIBRETRO_BACKEND=ON \
ENABLE_NDS_MELONDS_LIBRETRO_SYMBOLS=ON \
NDS_MELONDS_LIBRETRO_STATIC_LIB=/absolute/path/to/libmelonds_ds_libretro.a \
./build-ios.sh
```

## Current adapter readiness (already implemented)

- libretro callback trampolines (env/video/audio/input)
- touch/pointer mapping seam
- NDS screen layout API
- libretro pixel format conversion (`XRGB8888`, `RGB565`, `0RGB1555`)
- melonDS libretro symbol binding seam (`retro_*`)

## If you want to use upstream melonDS directly instead

That is a separate integration path (non-libretro) and requires:

- a new native backend implementation (direct melonDS API embedding)
- custom frame/audio/input plumbing
- different build/link strategy than the current `retro_*` binding seam
