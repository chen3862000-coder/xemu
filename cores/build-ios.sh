#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Building Xemu Cores Library for iOS..."

ENABLE_NDS_LIBRETRO_BACKEND="${ENABLE_NDS_LIBRETRO_BACKEND:-ON}"
ENABLE_NDS_MELONDS_LIBRETRO_SYMBOLS="${ENABLE_NDS_MELONDS_LIBRETRO_SYMBOLS:-ON}"
NDS_MELONDS_LIBRETRO_STATIC_LIB="${NDS_MELONDS_LIBRETRO_STATIC_LIB:-}"
NDS_MELONDS_LIBRETRO_STATIC_LIB_DEVICE="${NDS_MELONDS_LIBRETRO_STATIC_LIB_DEVICE:-}"
NDS_MELONDS_LIBRETRO_STATIC_LIB_SIM="${NDS_MELONDS_LIBRETRO_STATIC_LIB_SIM:-}"

# Backward-compatible fallback: use one archive for both if explicitly provided.
if [ -n "$NDS_MELONDS_LIBRETRO_STATIC_LIB" ]; then
  [ -z "$NDS_MELONDS_LIBRETRO_STATIC_LIB_DEVICE" ] && NDS_MELONDS_LIBRETRO_STATIC_LIB_DEVICE="$NDS_MELONDS_LIBRETRO_STATIC_LIB"
  [ -z "$NDS_MELONDS_LIBRETRO_STATIC_LIB_SIM" ] && NDS_MELONDS_LIBRETRO_STATIC_LIB_SIM="$NDS_MELONDS_LIBRETRO_STATIC_LIB"
fi

# Auto-discover melonDS libretro archives for a safe default build.
if [ -z "$NDS_MELONDS_LIBRETRO_STATIC_LIB_DEVICE" ]; then
  AUTO_DEVICE_LIB="$SCRIPT_DIR/third_party/melonds-ds/build-xemu-ios-device/src/libretro/libmelondsds_libretro_xemu_bundle.a"
  [ -f "$AUTO_DEVICE_LIB" ] && NDS_MELONDS_LIBRETRO_STATIC_LIB_DEVICE="$AUTO_DEVICE_LIB"
fi
if [ -z "$NDS_MELONDS_LIBRETRO_STATIC_LIB_SIM" ]; then
  AUTO_SIM_LIB="$SCRIPT_DIR/third_party/melonds-ds/build-xemu-ios-sim/src/libretro/libmelondsds_libretro_xemu_bundle.a"
  [ -f "$AUTO_SIM_LIB" ] && NDS_MELONDS_LIBRETRO_STATIC_LIB_SIM="$AUTO_SIM_LIB"
fi

# If we cannot bind melonDS symbols, disable symbol mode explicitly to avoid
# a false "enabled" state that results in runtime NDS load failures.
if [ "$ENABLE_NDS_MELONDS_LIBRETRO_SYMBOLS" = "ON" ]; then
  if [ -z "$NDS_MELONDS_LIBRETRO_STATIC_LIB_DEVICE" ] || [ -z "$NDS_MELONDS_LIBRETRO_STATIC_LIB_SIM" ]; then
    echo "Warning: melonDS static archives were not found for both device/simulator."
    echo "         NDS symbol binding is being disabled for this build."
    ENABLE_NDS_MELONDS_LIBRETRO_SYMBOLS="OFF"
  fi
fi

echo "NDS libretro backend: $ENABLE_NDS_LIBRETRO_BACKEND"
echo "NDS melonDS symbol binding: $ENABLE_NDS_MELONDS_LIBRETRO_SYMBOLS"
if [ -n "$NDS_MELONDS_LIBRETRO_STATIC_LIB_DEVICE" ]; then
  echo "NDS melonDS static lib (device): $NDS_MELONDS_LIBRETRO_STATIC_LIB_DEVICE"
fi
if [ -n "$NDS_MELONDS_LIBRETRO_STATIC_LIB_SIM" ]; then
  echo "NDS melonDS static lib (sim):    $NDS_MELONDS_LIBRETRO_STATIC_LIB_SIM"
fi

verify_libretro_archive() {
  local archive="$1"
  if [ -x "./scripts/verify-libretro-core.sh" ]; then
    ./scripts/verify-libretro-core.sh "$archive"
  else
    echo "Warning: ./scripts/verify-libretro-core.sh is not executable; skipping libretro symbol preflight for $archive"
  fi
}

if [ "$ENABLE_NDS_MELONDS_LIBRETRO_SYMBOLS" = "ON" ] && [ -n "$NDS_MELONDS_LIBRETRO_STATIC_LIB_DEVICE" ]; then
  verify_libretro_archive "$NDS_MELONDS_LIBRETRO_STATIC_LIB_DEVICE"
fi
if [ "$ENABLE_NDS_MELONDS_LIBRETRO_SYMBOLS" = "ON" ] && [ -n "$NDS_MELONDS_LIBRETRO_STATIC_LIB_SIM" ] && [ "$NDS_MELONDS_LIBRETRO_STATIC_LIB_SIM" != "$NDS_MELONDS_LIBRETRO_STATIC_LIB_DEVICE" ]; then
  verify_libretro_archive "$NDS_MELONDS_LIBRETRO_STATIC_LIB_SIM"
fi

# Detect SDKs
IOS_SDK=$(xcrun --sdk iphoneos --show-sdk-path)
SIM_SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)

echo "iOS SDK: $IOS_SDK"
echo "Simulator SDK: $SIM_SDK"

# Build for iOS Device (arm64)
echo ""
echo "Building for iOS Device (arm64)..."
rm -rf build-ios-device
mkdir -p build-ios-device
cd build-ios-device
cmake .. \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_SYSROOT=$IOS_SDK \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
    -DBUILD_TESTS=OFF \
    -DBUILD_SHARED_LIBS=OFF \
    -DBUILD_STATIC_LIBS=ON \
    -DCMAKE_C_FLAGS=-fno-lto \
    -DCMAKE_CXX_FLAGS=-fno-lto \
    -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=OFF \
    -DCMAKE_XCODE_ATTRIBUTE_ENABLE_BITCODE=NO \
    -DENABLE_NDS_LIBRETRO_BACKEND=$ENABLE_NDS_LIBRETRO_BACKEND \
    -DENABLE_NDS_MELONDS_LIBRETRO_SYMBOLS=$ENABLE_NDS_MELONDS_LIBRETRO_SYMBOLS \
    -DNDS_MELONDS_LIBRETRO_STATIC_LIB="$NDS_MELONDS_LIBRETRO_STATIC_LIB_DEVICE" \
    -DCMAKE_BUILD_TYPE=Release
cmake --build . --target xemu_cores_static -j$(sysctl -n hw.ncpu)
cd ..

# Build for iOS Simulator (arm64 + x86_64)
echo ""
echo "Building for iOS Simulator (arm64 + x86_64)..."
rm -rf build-ios-sim
mkdir -p build-ios-sim
cd build-ios-sim
cmake .. \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
    -DCMAKE_OSX_SYSROOT=$SIM_SDK \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
    -DBUILD_TESTS=OFF \
    -DBUILD_SHARED_LIBS=OFF \
    -DBUILD_STATIC_LIBS=ON \
    -DCMAKE_C_FLAGS=-fno-lto \
    -DCMAKE_CXX_FLAGS=-fno-lto \
    -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=OFF \
    -DCMAKE_XCODE_ATTRIBUTE_ENABLE_BITCODE=NO \
    -DENABLE_NDS_LIBRETRO_BACKEND=$ENABLE_NDS_LIBRETRO_BACKEND \
    -DENABLE_NDS_MELONDS_LIBRETRO_SYMBOLS=$ENABLE_NDS_MELONDS_LIBRETRO_SYMBOLS \
    -DNDS_MELONDS_LIBRETRO_STATIC_LIB="$NDS_MELONDS_LIBRETRO_STATIC_LIB_SIM" \
    -DCMAKE_BUILD_TYPE=Release
cmake --build . --target xemu_cores_static -j$(sysctl -n hw.ncpu)
cd ..

# Create XCFramework
echo ""
echo "Creating merged static libraries..."
DEVICE_LIBS=(
    build-ios-device/libxemu_cores.a
    build-ios-device/third_party/mgba/libmgba.a
)
SIM_LIBS=(
    build-ios-sim/libxemu_cores.a
    build-ios-sim/third_party/mgba/libmgba.a
)

# Optional: merge a prebuilt melonDS libretro archive if the caller provides one.
# If you pass a universal/fat archive, the same path can usually be used for both.
if [ -n "$NDS_MELONDS_LIBRETRO_STATIC_LIB_DEVICE" ]; then
  if [ -f "$NDS_MELONDS_LIBRETRO_STATIC_LIB_DEVICE" ]; then
    DEVICE_LIBS+=("$NDS_MELONDS_LIBRETRO_STATIC_LIB_DEVICE")
  else
    echo "Warning: NDS_MELONDS_LIBRETRO_STATIC_LIB_DEVICE not found, skipping merge: $NDS_MELONDS_LIBRETRO_STATIC_LIB_DEVICE"
  fi
fi
if [ -n "$NDS_MELONDS_LIBRETRO_STATIC_LIB_SIM" ]; then
  if [ -f "$NDS_MELONDS_LIBRETRO_STATIC_LIB_SIM" ]; then
    SIM_LIBS+=("$NDS_MELONDS_LIBRETRO_STATIC_LIB_SIM")
  else
    echo "Warning: NDS_MELONDS_LIBRETRO_STATIC_LIB_SIM not found, skipping merge: $NDS_MELONDS_LIBRETRO_STATIC_LIB_SIM"
  fi
fi

strip_dummy_bitcode_members() {
  local archive="$1"
  [ -f "$archive" ] || return 0
  if ! command -v xcrun >/dev/null 2>&1; then
    return 0
  fi
  if ! command -v lipo >/dev/null 2>&1; then
    xcrun ar -d "$archive" foo.c.o foo.cpp.o >/dev/null 2>&1 || true
    return 0
  fi

  local lipo_info
  lipo_info="$(lipo -info "$archive" 2>/dev/null || true)"
  if [[ "$lipo_info" == *"are:"* ]]; then
    local arch_list="${lipo_info##*are: }"
    local tmpdir
    tmpdir="$(mktemp -d)"
    local thin_outputs=()
    local arch
    for arch in $arch_list; do
      local thin="$tmpdir/${arch}.a"
      lipo "$archive" -thin "$arch" -output "$thin" >/dev/null 2>&1 || continue
      xcrun ar -d "$thin" foo.c.o foo.cpp.o >/dev/null 2>&1 || true
      thin_outputs+=("$thin")
    done
    if [ "${#thin_outputs[@]}" -gt 0 ]; then
      lipo -create "${thin_outputs[@]}" -output "$archive" >/dev/null 2>&1 || true
      ranlib "$archive" >/dev/null 2>&1 || true
    fi
    rm -rf "$tmpdir"
  else
    xcrun ar -d "$archive" foo.c.o foo.cpp.o >/dev/null 2>&1 || true
  fi
}

libtool -static -o build-ios-device/libxemu_cores_combined.a "${DEVICE_LIBS[@]}"
strip_dummy_bitcode_members "build-ios-device/libxemu_cores_combined.a"
mv build-ios-device/libxemu_cores_combined.a build-ios-device/libxemu_cores.a

libtool -static -o build-ios-sim/libxemu_cores_combined.a "${SIM_LIBS[@]}"
strip_dummy_bitcode_members "build-ios-sim/libxemu_cores_combined.a"
mv build-ios-sim/libxemu_cores_combined.a build-ios-sim/libxemu_cores.a

remove_bitcode_wrapper_members() {
  local archive="$1"
  python3 - "$archive" <<'PY'
import os, subprocess, sys, tempfile

archive = sys.argv[1]
if not os.path.exists(archive):
    sys.exit(0)

MAGIC = bytes.fromhex('dec0170b')

def list_members(path):
    try:
        out = subprocess.check_output(['xcrun', 'ar', '-t', path], text=True, stderr=subprocess.DEVNULL)
    except subprocess.CalledProcessError:
        return []
    return [m for m in out.splitlines() if m and m != '__.SYMDEF']

def bitcode_members(path):
    bad = []
    for m in list_members(path):
        try:
            data = subprocess.check_output(['xcrun', 'ar', '-p', path, m], stderr=subprocess.DEVNULL)
        except subprocess.CalledProcessError:
            continue
        if len(data) >= 4 and data[:4] == MAGIC:
            bad.append(m)
    return bad

def delete_members(path, names):
    if not names:
        return
    chunk = 50
    for i in range(0, len(names), chunk):
        batch = names[i:i + chunk]
        subprocess.run(['xcrun', 'ar', '-d', path, *batch], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
    subprocess.run(['ranlib', path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)

def lipo_arches(path):
    try:
        info = subprocess.check_output(['lipo', '-info', path], text=True, stderr=subprocess.STDOUT)
    except Exception:
        return []
    if 'are:' in info:
        return info.split('are:', 1)[1].strip().split()
    if 'architecture:' in info:
        return [info.split('architecture:', 1)[1].strip().split()[0]]
    return []

arches = lipo_arches(archive)
if len(arches) > 1:
    with tempfile.TemporaryDirectory() as d:
        thins = []
        for arch in arches:
            thin = os.path.join(d, f'{arch}.a')
            try:
                subprocess.check_call(['lipo', archive, '-thin', arch, '-output', thin], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            except subprocess.CalledProcessError:
                continue
            delete_members(thin, bitcode_members(thin))
            thins.append(thin)
        if thins:
            subprocess.run(['lipo', '-create', *thins, '-output', archive], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
            subprocess.run(['ranlib', archive], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
else:
    delete_members(archive, bitcode_members(archive))
PY
}

remove_bitcode_wrapper_members "$SCRIPT_DIR/build-ios-device/libxemu_cores.a"
remove_bitcode_wrapper_members "$SCRIPT_DIR/build-ios-sim/libxemu_cores.a"

scan_archive_for_bitcode_wrappers() {
  local archive="$1"
  local label="$2"
  python3 - "$archive" "$label" <<'PY'
import os, subprocess, sys, tempfile
archive, label = sys.argv[1], sys.argv[2]
if not os.path.exists(archive):
    print(f"[{label}] archive missing: {archive}")
    sys.exit(0)
def scan_one(path):
    members = subprocess.check_output(['xcrun', 'ar', '-t', path], text=True).splitlines()
    bad = []
    for m in members:
        if not m or m == '__.SYMDEF':
            continue
        try:
            data = subprocess.check_output(['xcrun', 'ar', '-p', path, m], stderr=subprocess.DEVNULL)
        except subprocess.CalledProcessError:
            continue
        if len(data) >= 4 and data[:4] == bytes.fromhex('dec0170b'):
            bad.append(m)
    return bad

def lipo_arches(path):
    try:
        info = subprocess.check_output(['lipo', '-info', path], text=True, stderr=subprocess.STDOUT)
    except Exception:
        return []
    if 'are:' in info:
        return info.split('are:', 1)[1].strip().split()
    if 'architecture:' in info:
        return [info.split('architecture:', 1)[1].strip().split()[0]]
    return []

arches = lipo_arches(archive)
if arches and len(arches) > 1:
    any_bad = False
    with tempfile.TemporaryDirectory() as d:
        for arch in arches:
            thin = os.path.join(d, f"{arch}.a")
            try:
                subprocess.check_call(['lipo', archive, '-thin', arch, '-output', thin], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                bad = scan_one(thin)
            except subprocess.CalledProcessError as e:
                print(f"[{label}:{arch}] failed to scan thin slice: {e}")
                continue
            if bad:
                any_bad = True
                print(f"[{label}:{arch}] LLVM bitcode wrapper members still present ({len(bad)}):")
                for name in bad[:50]:
                    print(f"  - {name}")
            else:
                print(f"[{label}:{arch}] no LLVM bitcode wrapper members detected")
    if not any_bad:
        print(f"[{label}] no LLVM bitcode wrapper members detected")
else:
    try:
        bad = scan_one(archive)
    except subprocess.CalledProcessError as e:
        print(f"[{label}] failed to list archive members: {e}")
        sys.exit(0)
    if bad:
        print(f"[{label}] LLVM bitcode wrapper members still present ({len(bad)}):")
        for name in bad[:50]:
            print(f"  - {name}")
    else:
        print(f"[{label}] no LLVM bitcode wrapper members detected")
PY
}

scan_archive_for_bitcode_wrappers "$SCRIPT_DIR/build-ios-device/libxemu_cores.a" "device"
scan_archive_for_bitcode_wrappers "$SCRIPT_DIR/build-ios-sim/libxemu_cores.a" "sim"

echo ""
echo "Creating XCFramework..."
rm -rf XemuCores.xcframework
xcodebuild -create-xcframework \
    -library build-ios-device/libxemu_cores.a \
    -library build-ios-sim/libxemu_cores.a \
    -output XemuCores.xcframework

echo ""
echo "Build complete: XemuCores.xcframework"
