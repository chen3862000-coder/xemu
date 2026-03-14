#include <gtest/gtest.h>

#include "nds/nds_touch_pointer_mapping.h"

using xemu::nds::PointerFrameCoordinates;
using xemu::nds::mapTouchToPointerFrame;

TEST(NDSTouchPointerMappingTest, StackedLayoutMapsToBottomHalf) {
    const PointerFrameCoordinates mapped = mapTouchToPointerFrame(
        128,
        96,
        256,
        384
    );
    EXPECT_EQ(mapped.x, 128);
    EXPECT_EQ(mapped.y, 288);
    EXPECT_EQ(mapped.maxX, 255);
    EXPECT_EQ(mapped.maxY, 383);
}

TEST(NDSTouchPointerMappingTest, SideBySideLayoutMapsToRightHalf) {
    const PointerFrameCoordinates mapped = mapTouchToPointerFrame(
        40,
        100,
        512,
        192
    );
    EXPECT_EQ(mapped.x, 296);
    EXPECT_EQ(mapped.y, 100);
    EXPECT_EQ(mapped.maxX, 511);
    EXPECT_EQ(mapped.maxY, 191);
}

TEST(NDSTouchPointerMappingTest, SingleScreenLayoutKeepsLocalCoordinates) {
    const PointerFrameCoordinates mapped = mapTouchToPointerFrame(
        40,
        100,
        256,
        192
    );
    EXPECT_EQ(mapped.x, 40);
    EXPECT_EQ(mapped.y, 100);
    EXPECT_EQ(mapped.maxX, 255);
    EXPECT_EQ(mapped.maxY, 191);
}

TEST(NDSTouchPointerMappingTest, OutOfBoundsTouchCoordinatesAreClamped) {
    const PointerFrameCoordinates mapped = mapTouchToPointerFrame(
        800,
        900,
        256,
        384
    );
    EXPECT_EQ(mapped.x, 255);
    EXPECT_EQ(mapped.y, 383);
    EXPECT_EQ(mapped.maxX, 255);
    EXPECT_EQ(mapped.maxY, 383);
}

TEST(NDSTouchPointerMappingTest, InvalidFrameDimensionsUseSafeFallback) {
    const PointerFrameCoordinates mapped = mapTouchToPointerFrame(
        10,
        20,
        0,
        0
    );
    EXPECT_EQ(mapped.x, 10);
    EXPECT_EQ(mapped.y, 212);
    EXPECT_EQ(mapped.maxX, 255);
    EXPECT_EQ(mapped.maxY, 383);
}
