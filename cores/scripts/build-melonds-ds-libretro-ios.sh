#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BASE_HELPER="$SCRIPT_DIR/build-melonds-ds-libretro-static.sh"

DEVICE_BUILD_DIR="${MELONDS_DS_IOS_DEVICE_BUILD_DIR:-$CORES_DIR/third_party/melonds-ds/build-xemu-ios-device}"
SIM_BUILD_DIR="${MELONDS_DS_IOS_SIM_BUILD_DIR:-$CORES_DIR/third_party/melonds-ds/build-xemu-ios-sim}"
DEPLOY_TARGET="${MELONDS_DS_IOS_DEPLOYMENT_TARGET:-14.0}"

if [ ! -f "$BASE_HELPER" ]; then
  echo "ERROR: base helper not found: $BASE_HELPER" >&2
  exit 1
fi

IOS_SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
SIM_SDK="$(xcrun --sdk iphonesimulator --show-sdk-path)"

echo "==> Building melonDS DS libretro for iOS device (arm64)"
MELONDS_DS_BUILD_DIR="$DEVICE_BUILD_DIR" \
MELONDS_DS_CMAKE_SYSTEM_NAME="iOS" \
MELONDS_DS_CMAKE_OSX_SYSROOT="$IOS_SDK" \
MELONDS_DS_CMAKE_OSX_ARCHITECTURES="arm64" \
MELONDS_DS_CMAKE_OSX_DEPLOYMENT_TARGET="$DEPLOY_TARGET" \
bash "$BASE_HELPER"

device_archive="$DEVICE_BUILD_DIR/src/libretro/libmelondsds_libretro_xemu_bundle.a"
if [ ! -f "$device_archive" ]; then
  device_archive="$(find "$DEVICE_BUILD_DIR" -type f \( -name 'libmelondsds_libretro.a' -o -name 'melondsds_libretro.a' \) | head -n 1)"
fi
if [ -z "$device_archive" ]; then
  echo "ERROR: device archive not found under $DEVICE_BUILD_DIR" >&2
  exit 1
fi

echo ""
echo "==> Building melonDS DS libretro for iOS simulator (arm64;x86_64)"
MELONDS_DS_BUILD_DIR="$SIM_BUILD_DIR" \
MELONDS_DS_CMAKE_SYSTEM_NAME="iOS" \
MELONDS_DS_CMAKE_OSX_SYSROOT="$SIM_SDK" \
MELONDS_DS_CMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
MELONDS_DS_CMAKE_OSX_DEPLOYMENT_TARGET="$DEPLOY_TARGET" \
bash "$BASE_HELPER"

sim_archive="$SIM_BUILD_DIR/src/libretro/libmelondsds_libretro_xemu_bundle.a"
if [ ! -f "$sim_archive" ]; then
  sim_archive="$(find "$SIM_BUILD_DIR" -type f \( -name 'libmelondsds_libretro.a' -o -name 'melondsds_libretro.a' \) | head -n 1)"
fi
if [ -z "$sim_archive" ]; then
  echo "ERROR: simulator archive not found under $SIM_BUILD_DIR" >&2
  exit 1
fi

echo ""
echo "Built iOS melonDS libretro archives:"
echo "  Device:    $device_archive"
echo "  Simulator: $sim_archive"
echo ""
echo "Use them with xemu cores build:"
echo "  cd $CORES_DIR"
echo "  ENABLE_NDS_LIBRETRO_BACKEND=ON \\"
echo "  ENABLE_NDS_MELONDS_LIBRETRO_SYMBOLS=ON \\"
echo "  NDS_MELONDS_LIBRETRO_STATIC_LIB_DEVICE=$device_archive \\"
echo "  NDS_MELONDS_LIBRETRO_STATIC_LIB_SIM=$sim_archive \\"
echo "  ./build-ios.sh"
