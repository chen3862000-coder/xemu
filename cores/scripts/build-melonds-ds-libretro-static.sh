#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
THIRD_PARTY_DIR="${THIRD_PARTY_DIR:-$CORES_DIR/third_party}"
SOURCE_DIR="${MELONDS_DS_SOURCE_DIR:-$THIRD_PARTY_DIR/melonds-ds}"
BUILD_DIR="${MELONDS_DS_BUILD_DIR:-$SOURCE_DIR/build-xemu-static}"
BUILD_TYPE="${MELONDS_DS_BUILD_TYPE:-Release}"
MELONDS_DS_CMAKE_SYSTEM_NAME="${MELONDS_DS_CMAKE_SYSTEM_NAME:-}"
MELONDS_DS_CMAKE_OSX_SYSROOT="${MELONDS_DS_CMAKE_OSX_SYSROOT:-}"
MELONDS_DS_CMAKE_OSX_ARCHITECTURES="${MELONDS_DS_CMAKE_OSX_ARCHITECTURES:-}"
MELONDS_DS_CMAKE_OSX_DEPLOYMENT_TARGET="${MELONDS_DS_CMAKE_OSX_DEPLOYMENT_TARGET:-}"
MELONDS_FORK_DIR="${MELONDS_FORK_DIR:-$THIRD_PARTY_DIR/melonDS-jesseTG}"
MELONDS_UPSTREAM_FALLBACK_DIR="${MELONDS_UPSTREAM_FALLBACK_DIR:-$THIRD_PARTY_DIR/melonDS}"

if [ ! -d "$SOURCE_DIR" ]; then
  echo "ERROR: melonds-ds source directory not found: $SOURCE_DIR" >&2
  exit 1
fi

echo "Building melonDS DS libretro static archive"
echo "Source: $SOURCE_DIR"
echo "Build:  $BUILD_DIR"
if [ -n "$MELONDS_DS_CMAKE_OSX_SYSROOT" ] || [ -n "$MELONDS_DS_CMAKE_OSX_ARCHITECTURES" ]; then
  echo "Apple target: sysroot=${MELONDS_DS_CMAKE_OSX_SYSROOT:-<default>} arch=${MELONDS_DS_CMAKE_OSX_ARCHITECTURES:-<default>} deploy=${MELONDS_DS_CMAKE_OSX_DEPLOYMENT_TARGET:-<default>}"
fi

if ! command -v cmake >/dev/null 2>&1; then
  echo "ERROR: cmake is required" >&2
  exit 1
fi

declare -a cmake_args
cmake_args+=("-S" "$SOURCE_DIR")
cmake_args+=("-B" "$BUILD_DIR")
cmake_args+=("-DCMAKE_BUILD_TYPE=$BUILD_TYPE")
cmake_args+=("-DCMAKE_POLICY_VERSION_MINIMUM=3.5")
cmake_args+=("-DCMAKE_C_FLAGS=-fno-lto")
cmake_args+=("-DCMAKE_CXX_FLAGS=-fno-lto")
cmake_args+=("-DBUILD_TESTING=OFF")
cmake_args+=("-DBUILD_AS_SHARED_LIBRARY=OFF")
cmake_args+=("-DBUILD_AS_STATIC_LIBRARY=ON")
cmake_args+=("-DENABLE_OPENGL=OFF")
cmake_args+=("-DENABLE_JIT=OFF")
cmake_args+=("-DENABLE_LTO_RELEASE=OFF")
cmake_args+=("-DENABLE_LTO=OFF")
cmake_args+=("-DFETCHCONTENT_FULLY_DISCONNECTED=ON")
if [ -n "$MELONDS_DS_CMAKE_SYSTEM_NAME" ]; then
  cmake_args+=("-DCMAKE_SYSTEM_NAME=$MELONDS_DS_CMAKE_SYSTEM_NAME")
fi
if [ -n "$MELONDS_DS_CMAKE_OSX_SYSROOT" ]; then
  cmake_args+=("-DCMAKE_OSX_SYSROOT=$MELONDS_DS_CMAKE_OSX_SYSROOT")
fi
if [ -n "$MELONDS_DS_CMAKE_OSX_ARCHITECTURES" ]; then
  cmake_args+=("-DCMAKE_OSX_ARCHITECTURES=$MELONDS_DS_CMAKE_OSX_ARCHITECTURES")
fi
if [ -n "$MELONDS_DS_CMAKE_OSX_DEPLOYMENT_TARGET" ]; then
  cmake_args+=("-DCMAKE_OSX_DEPLOYMENT_TARGET=$MELONDS_DS_CMAKE_OSX_DEPLOYMENT_TARGET")
fi
cmake_args+=("-DCMAKE_INTERPROCEDURAL_OPTIMIZATION=OFF")
cmake_args+=("-DCMAKE_XCODE_ATTRIBUTE_ENABLE_BITCODE=NO")

# Map local vendored checkouts to FetchContent overrides (names follow
# FETCHCONTENT_SOURCE_DIR_<MAKE_C_IDENTIFIER(UPPER(name))>).
declare -a missing_required
add_override_if_exists() {
  local var_name="$1"
  local path="$2"
  local required="${3:-no}"
  if [ -d "$path" ]; then
    cmake_args+=("-D${var_name}=$path")
    echo "Using local dependency: ${var_name} -> $path"
  elif [ "$required" = "yes" ]; then
    missing_required+=("$var_name::$path")
  fi
}

melonds_dep_dir=""
if [ -d "$MELONDS_FORK_DIR" ]; then
  melonds_dep_dir="$MELONDS_FORK_DIR"
  echo "Using local dependency: FETCHCONTENT_SOURCE_DIR_MELONDS -> $MELONDS_FORK_DIR (preferred JesseTG fork)"
elif [ -d "$MELONDS_UPSTREAM_FALLBACK_DIR/.git" ]; then
  remote_url="$(git -C "$MELONDS_UPSTREAM_FALLBACK_DIR" remote get-url origin 2>/dev/null || true)"
  if [[ "$remote_url" == *"melonDS-emu/melonDS"* ]]; then
    echo "ERROR: $MELONDS_UPSTREAM_FALLBACK_DIR is the upstream melonDS repo ($remote_url)." >&2
    echo "melonds-ds expects JesseTG/melonDS (pinned in its FetchDependencies.cmake)." >&2
    echo "Run: bash \"$CORES_DIR/scripts/fetch-melonds-ds-deps.sh\" to clone $THIRD_PARTY_DIR/melonDS-jesseTG, then rerun." >&2
    exit 1
  fi
  melonds_dep_dir="$MELONDS_UPSTREAM_FALLBACK_DIR"
fi
add_override_if_exists "FETCHCONTENT_SOURCE_DIR_MELONDS" "${melonds_dep_dir:-$THIRD_PARTY_DIR/melonDS}" yes
add_override_if_exists "FETCHCONTENT_SOURCE_DIR_LIBRETRO_COMMON" "$THIRD_PARTY_DIR/libretro-common" yes
add_override_if_exists "FETCHCONTENT_SOURCE_DIR_EMBED_BINARIES" "$THIRD_PARTY_DIR/embed-binaries" yes
add_override_if_exists "FETCHCONTENT_SOURCE_DIR_GLM" "$THIRD_PARTY_DIR/glm" yes
add_override_if_exists "FETCHCONTENT_SOURCE_DIR_LIBSLIRP" "$THIRD_PARTY_DIR/libslirp-mirror" yes
add_override_if_exists "FETCHCONTENT_SOURCE_DIR_PNTR" "$THIRD_PARTY_DIR/pntr" yes
add_override_if_exists "FETCHCONTENT_SOURCE_DIR_FMT" "$THIRD_PARTY_DIR/fmt" yes
add_override_if_exists "FETCHCONTENT_SOURCE_DIR_YAMC" "$THIRD_PARTY_DIR/yamc" yes
add_override_if_exists "FETCHCONTENT_SOURCE_DIR_SPAN_LITE" "$THIRD_PARTY_DIR/span-lite" yes
add_override_if_exists "FETCHCONTENT_SOURCE_DIR_DATE" "$THIRD_PARTY_DIR/date" yes
add_override_if_exists "FETCHCONTENT_SOURCE_DIR_ZLIB" "$THIRD_PARTY_DIR/zlib" yes
add_override_if_exists "FETCHCONTENT_SOURCE_DIR_TRACY" "$THIRD_PARTY_DIR/tracy" no

if [ "${#missing_required[@]}" -gt 0 ]; then
  echo "ERROR: missing required local dependency checkouts for offline build:" >&2
  for entry in "${missing_required[@]}"; do
    echo "  - ${entry%%::*} -> ${entry##*::}" >&2
  done
  echo "" >&2
  echo "Download those repos under $THIRD_PARTY_DIR (or override THIRD_PARTY_DIR / FETCHCONTENT paths) and rerun." >&2
  exit 1
fi

cmake "${cmake_args[@]}"
jobs="$(sysctl -n hw.ncpu 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)"
cmake --build "$BUILD_DIR" --config "$BUILD_TYPE" --target melondsds_libretro -j"$jobs"

archive_path="$(find "$BUILD_DIR" -type f \( -name 'libmelondsds_libretro.a' -o -name 'melondsds_libretro.a' \) | head -n 1)"
if [ -z "$archive_path" ]; then
  echo "ERROR: build completed but no static archive was found in $BUILD_DIR" >&2
  exit 1
fi

echo "Built archive: $archive_path"

# Bundle melonds-ds libretro with its dependent static libraries so downstream
# linkers (xemu/Xcode) do not need to know melonds-ds internal archive layout.
# This is especially important for iOS, where we pass a single archive into the
# xemu cores build and later merge it into an XCFramework.
bundle_output="${BUILD_DIR}/src/libretro/libmelondsds_libretro_xemu_bundle.a"
declare -a bundle_inputs
while IFS= read -r lib; do
  # Exclude previously-created bundles to avoid recursive growth.
  case "$lib" in
    *libmelondsds_libretro_xemu_bundle.a) continue ;;
  esac
  bundle_inputs+=("$lib")
done < <(find "$BUILD_DIR" -type f -name '*.a' | sort)

if [ "${#bundle_inputs[@]}" -gt 0 ] && command -v libtool >/dev/null 2>&1; then
  echo "Creating bundled archive for xemu integration..."
  mkdir -p "$(dirname "$bundle_output")"
  rm -f "$bundle_output"
  libtool -static -o "$bundle_output" "${bundle_inputs[@]}"
  # Some dependency archives include dummy placeholder objects (foo.c.o/foo.cpp.o)
  # built as LLVM bitcode wrappers. They have no symbols, but `xcodebuild
  # -create-xcframework` fails when these wrappers are present in a merged static
  # archive. It is safe to strip them.
  if command -v xcrun >/dev/null 2>&1; then
    xcrun ar -d "$bundle_output" foo.c.o foo.cpp.o >/dev/null 2>&1 || true
  fi
  archive_path="$bundle_output"
  echo "Built bundled archive: $archive_path"
else
  echo "Warning: could not create bundled archive (libtool missing or no inputs found); using raw melondsds archive"
fi

if [ -x "$CORES_DIR/scripts/verify-libretro-core.sh" ]; then
  "$CORES_DIR/scripts/verify-libretro-core.sh" "$archive_path"
fi

echo ""
echo "To build xemu cores with NDS libretro enabled:"
echo "  cd $CORES_DIR"
echo "  ENABLE_NDS_LIBRETRO_BACKEND=ON \\"
echo "  ENABLE_NDS_MELONDS_LIBRETRO_SYMBOLS=ON \\"
echo "  NDS_MELONDS_LIBRETRO_STATIC_LIB=$archive_path \\"
echo "  ./build-ios.sh"
