#include <gtest/gtest.h>
#include "gb/gambatte_wrapper.h"
#include "xemu_cores/xemu_cores.h"

using namespace xemu;

class GambatteWrapperTest : public ::testing::Test {
protected:
    void SetUp() override {
        gb = std::make_unique<GambatteWrapper>();
    }
    
    void TearDown() override {
        gb.reset();
    }
    
    std::unique_ptr<GambatteWrapper> gb;
};

TEST_F(GambatteWrapperTest, CreateAndDestroy) {
    EXPECT_NE(gb, nullptr);
    EXPECT_FALSE(gb->isROMLoaded());
}

TEST_F(GambatteWrapperTest, VideoBufferDimensions) {
    EXPECT_EQ(gb->getVideoWidth(), 160);
    EXPECT_EQ(gb->getVideoHeight(), 144);
    EXPECT_NE(gb->getVideoBuffer(), nullptr);
}

TEST_F(GambatteWrapperTest, AudioBufferConfiguration) {
    EXPECT_EQ(gb->getAudioSampleCount(), GambatteWrapper::AUDIO_SAMPLES_PER_FRAME * 2);
    EXPECT_NE(gb->getAudioBuffer(), nullptr);
}

TEST_F(GambatteWrapperTest, LoadROMInvalidData) {
    EXPECT_FALSE(gb->loadROM("test.gb", nullptr, 0));
    EXPECT_FALSE(gb->isROMLoaded());
}

TEST_F(GambatteWrapperTest, LoadROMSmallBuffer) {
    uint8_t smallData[0x50] = {0};
    EXPECT_FALSE(gb->loadROM("test.gb", smallData, sizeof(smallData)));
}

TEST_F(GambatteWrapperTest, SaveStateSize) {
    EXPECT_EQ(gb->getSaveStateSize(), GambatteWrapper::SAVE_STATE_SIZE);
}

TEST_F(GambatteWrapperTest, SaveStateWithoutROM) {
    std::vector<uint8_t> buffer(gb->getSaveStateSize());
    EXPECT_FALSE(gb->saveState(buffer.data(), buffer.size()));
}

TEST_F(GambatteWrapperTest, LoadStateWithoutROM) {
    std::vector<uint8_t> buffer(gb->getSaveStateSize());
    EXPECT_FALSE(gb->loadState(buffer.data(), buffer.size()));
}

TEST_F(GambatteWrapperTest, InputHandling) {
    uint32_t buttons = XEMU_BUTTON_A | XEMU_BUTTON_B | XEMU_BUTTON_START | XEMU_BUTTON_SELECT;
    gb->setInput(buttons);
    gb->runFrame();
}

TEST_F(GambatteWrapperTest, ResetWithoutROM) {
    // Should not crash
    gb->reset();
}

TEST_F(GambatteWrapperTest, UnloadROM) {
    // Should not crash even without loaded ROM
    gb->unloadROM();
    EXPECT_FALSE(gb->isROMLoaded());
}

TEST_F(GambatteWrapperTest, CGBModeDetection) {
    // Initially not in CGB mode
    EXPECT_FALSE(gb->isCGBMode());
}
