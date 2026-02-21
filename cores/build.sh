#!/bin/bash
set -e

# Build script for macOS
# Creates universal binary (x86_64 + arm64) and framework

echo "Building Xemu Cores Library for macOS..."

# Create build directory
mkdir -p build
cd build

# Configure for macOS Universal Binary
cmake .. \
    -DCMAKE_OSX_ARCHITECTURES="x86_64;arm64" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET="11.0" \
    -DBUILD_TESTS=ON \
    -DBUILD_SHARED_LIBS=ON \
    -DBUILD_STATIC_LIBS=ON \
    -DCMAKE_BUILD_TYPE=Release

# Build
make -j$(sysctl -n hw.ncpu)

# Run tests
if [ -f "test/xemu_cores_test" ]; then
    echo "Running tests..."
    ctest --output-on-failure
fi

echo "Build complete!"
echo ""
echo "Output files:"
echo "  Shared library: build/libxemu_cores.dylib"
echo "  Static library: build/libxemu_cores.a"
echo "  Headers:        build/include/"
