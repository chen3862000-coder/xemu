#include <gtest/gtest.h>
#include "gba/mgba_wrapper.h"
#include "xemu_cores/xemu_cores.h"

using namespace xemu;

class MGBAWrapperTest : public ::testing::Test {
protected:
    void SetUp() override {
        gba = std::make_unique<mGBAWrapper>();
    }
    
    void TearDown() override {
        gba.reset();
    }
    
    std::unique_ptr<mGBAWrapper> gba;
};

TEST_F(MGBAWrapperTest, CreateAndDestroy) {
    EXPECT_NE(gba, nullptr);
    EXPECT_FALSE(gba->isROMLoaded());
}

TEST_F(MGBAWrapperTest, VideoBufferDimensions) {
    EXPECT_EQ(gba->getVideoWidth(), 240);
    EXPECT_EQ(gba->getVideoHeight(), 160);
    EXPECT_NE(gba->getVideoBuffer(), nullptr);
}

TEST_F(MGBAWrapperTest, AudioBufferConfiguration) {
    EXPECT_EQ(gba->getAudioSampleCount(), mGBAWrapper::AUDIO_SAMPLES_PER_FRAME * 2);
    EXPECT_NE(gba->getAudioBuffer(), nullptr);
}

TEST_F(MGBAWrapperTest, LoadROMInvalidData) {
    EXPECT_FALSE(gba->loadROM("test.gba", nullptr, 0));
    EXPECT_FALSE(gba->isROMLoaded());
}

TEST_F(MGBAWrapperTest, LoadROMSmallBuffer) {
    uint8_t smallData[0x50] = {0};
    EXPECT_FALSE(gba->loadROM("test.gba", smallData, sizeof(smallData)));
}

TEST_F(MGBAWrapperTest, SaveStateSize) {
    EXPECT_EQ(gba->getSaveStateSize(), mGBAWrapper::SAVE_STATE_SIZE);
}

TEST_F(MGBAWrapperTest, SaveStateWithoutROM) {
    std::vector<uint8_t> buffer(gba->getSaveStateSize());
    EXPECT_FALSE(gba->saveState(buffer.data(), buffer.size()));
}

TEST_F(MGBAWrapperTest, LoadStateWithoutROM) {
    std::vector<uint8_t> buffer(gba->getSaveStateSize());
    EXPECT_FALSE(gba->loadState(buffer.data(), buffer.size()));
}

TEST_F(MGBAWrapperTest, InputHandling) {
    // Test GBA-specific buttons (L/R)
    uint32_t gbaButtons = XEMU_BUTTON_A | XEMU_BUTTON_B | XEMU_BUTTON_L | XEMU_BUTTON_R;
    gba->setInput(gbaButtons);
    gba->runFrame();
}

TEST_F(MGBAWrapperTest, ResetWithoutROM) {
    // Should not crash
    gba->reset();
}

TEST_F(MGBAWrapperTest, UnloadROM) {
    // Should not crash even without loaded ROM
    gba->unloadROM();
    EXPECT_FALSE(gba->isROMLoaded());
}
