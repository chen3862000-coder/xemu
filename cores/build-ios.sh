#!/bin/bash
set -e

echo "Building Xemu Cores Library for iOS..."

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
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_SYSROOT=$IOS_SDK \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
    -DBUILD_TESTS=OFF \
    -DCMAKE_BUILD_TYPE=Release
make -j$(sysctl -n hw.ncpu)
cd ..

# Build for iOS Simulator (arm64 + x86_64)
echo ""
echo "Building for iOS Simulator (arm64 + x86_64)..."
rm -rf build-ios-sim
mkdir -p build-ios-sim
cd build-ios-sim
cmake .. \
    -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
    -DCMAKE_OSX_SYSROOT=$SIM_SDK \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
    -DBUILD_TESTS=OFF \
    -DCMAKE_BUILD_TYPE=Release
make -j$(sysctl -n hw.ncpu)
cd ..

# Create XCFramework
echo ""
echo "Creating XCFramework..."
rm -rf XemuCores.xcframework
xcodebuild -create-xcframework \
    -library build-ios-device/libxemu_cores.a \
    -library build-ios-sim/libxemu_cores.a \
    -output XemuCores.xcframework

echo ""
echo "Build complete: XemuCores.xcframework"
