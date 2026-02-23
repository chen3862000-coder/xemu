#!/bin/bash
set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 /absolute/path/to/libretro_core.a" >&2
  exit 2
fi

LIB_PATH="$1"

if [ ! -f "$LIB_PATH" ]; then
  echo "ERROR: archive not found: $LIB_PATH" >&2
  exit 1
fi

if ! command -v nm >/dev/null 2>&1; then
  echo "ERROR: nm is required" >&2
  exit 1
fi

echo "Verifying libretro archive: $LIB_PATH"

required_symbols=(
  "_retro_init"
  "_retro_deinit"
  "_retro_api_version"
  "_retro_get_system_info"
  "_retro_get_system_av_info"
  "_retro_set_environment"
  "_retro_set_video_refresh"
  "_retro_set_audio_sample"
  "_retro_set_audio_sample_batch"
  "_retro_set_input_poll"
  "_retro_set_input_state"
  "_retro_load_game"
  "_retro_unload_game"
  "_retro_run"
)

missing=0
symbol_dump="$(nm -gU "$LIB_PATH" 2>/dev/null || true)"

if [ -z "$symbol_dump" ]; then
  # Fallback for archives where -gU is unsupported/no output in this environment.
  symbol_dump="$(nm "$LIB_PATH" 2>/dev/null || true)"
fi

for sym in "${required_symbols[@]}"; do
  if ! grep -Fq -- "$sym" <<< "$symbol_dump"; then
    echo "Missing symbol: $sym" >&2
    missing=1
  fi
done

if [ "$missing" -ne 0 ]; then
  echo "ERROR: archive does not look like a libretro core (or symbols are stripped)." >&2
  exit 1
fi

if command -v lipo >/dev/null 2>&1; then
  archs="$(lipo -info "$LIB_PATH" 2>/dev/null || true)"
  if [ -n "$archs" ]; then
    echo "$archs"
  fi
fi

echo "OK: libretro core symbols detected."
