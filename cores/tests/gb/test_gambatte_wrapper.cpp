#include <gtest/gtest.h>
#include "gb/gambatte_wrapper.h"

using namespace xemu;

TEST(GambatteWrapperTest, CreateDestroy) {
    auto wrapper = std::make_unique<GambatteWrapper>();
    EXPECT_FALSE(wrapper->isROMLoaded());
}

TEST(GambatteWrapperTest, VideoBufferFormat) {
    GambatteWrapper wrapper;
    
    EXPECT_EQ(wrapper.getVideoWidth(), 160);
    EXPECT_EQ(wrapper.getVideoHeight(), 144);
    EXPECT_NE(wrapper.getVideoBuffer(), nullptr);
}

TEST(GambatteWrapperTest, AudioBufferFormat) {
    GambatteWrapper wrapper;
    
    EXPECT_EQ(wrapper.getAudioSampleCount(), 735); // ~59.73 FPS
}

TEST(GambatteWrapperTest, LoadROMWithoutData) {
    GambatteWrapper wrapper;
    
    // Should fail without data
    EXPECT_FALSE(wrapper->loadROM("test.gb", nullptr, 0));
}

TEST(GambatteWrapperTest, InputState) {
    GambatteWrapper wrapper;
    
    // Set all buttons
    wrapper.setInput(XEMU_BUTTON_A | XEMU_BUTTON_B | XEMU_BUTTON_START | XEMU_BUTTON_SELECT |
                     XEMU_BUTTON_UP | XEMU_BUTTON_DOWN | XEMU_BUTTON_LEFT | XEMU_BUTTON_RIGHT);
    
    // No crash expected
    EXPECT_TRUE(true);
}
