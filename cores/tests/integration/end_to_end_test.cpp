#include <gtest/gtest.h>
#include "xemu_cores/xemu_cores.h"

class EndToEndTest : public ::testing::Test {
protected:
    void SetUp() override {
        // Setup for end-to-end tests
    }
    
    void TearDown() override {
        // Cleanup
    }
};

// Full workflow test
TEST_F(EndToEndTest, GB_FullWorkflow) {
    // Create core
    xemu_gb_handle_t gb = xemu_gb_create();
    ASSERT_NE(gb, nullptr);
    
    // Check initial state
    EXPECT_EQ(xemu_gb_is_rom_loaded(gb), 0);
    
    // Get buffers
    xemu_video_buffer_t video = xemu_gb_get_video_buffer(gb);
    EXPECT_NE(video.data, nullptr);
    EXPECT_EQ(video.width, 160);
    EXPECT_EQ(video.height, 144);
    
    xemu_audio_buffer_t audio = xemu_gb_get_audio_buffer(gb);
    EXPECT_NE(audio.data, nullptr);
    EXPECT_EQ(audio.sample_rate, 44100);
    
    // Set input
    xemu_gb_set_input(gb, XEMU_BUTTON_A | XEMU_BUTTON_B);
    
    // Reset
    EXPECT_EQ(xemu_gb_reset(gb), XEMU_OK);
    
    // Cleanup
    xemu_gb_destroy(gb);
}

TEST_F(EndToEndTest, GBA_FullWorkflow) {
    // Create core
    xemu_gba_handle_t gba = xemu_gba_create();
    ASSERT_NE(gba, nullptr);
    
    // Check initial state
    EXPECT_EQ(xemu_gba_is_rom_loaded(gba), 0);
    
    // Get buffers
    xemu_video_buffer_t video = xemu_gba_get_video_buffer(gba);
    EXPECT_NE(video.data, nullptr);
    EXPECT_EQ(video.width, 240);
    EXPECT_EQ(video.height, 160);
    
    xemu_audio_buffer_t audio = xemu_gba_get_audio_buffer(gba);
    EXPECT_NE(audio.data, nullptr);
    EXPECT_EQ(audio.sample_rate, 44100);
    
    // Set input with L/R buttons (GBA-specific)
    xemu_gba_set_input(gba, XEMU_BUTTON_A | XEMU_BUTTON_B | XEMU_BUTTON_L | XEMU_BUTTON_R);
    
    // Reset
    EXPECT_EQ(xemu_gba_reset(gba), XEMU_OK);
    
    // Cleanup
    xemu_gba_destroy(gba);
}

TEST_F(EndToEndTest, MultipleInstances) {
    // Create multiple instances
    xemu_gb_handle_t gb1 = xemu_gb_create();
    xemu_gb_handle_t gb2 = xemu_gb_create();
    xemu_gba_handle_t gba1 = xemu_gba_create();
    
    ASSERT_NE(gb1, nullptr);
    ASSERT_NE(gb2, nullptr);
    ASSERT_NE(gba1, nullptr);
    
    // All should be independent
    EXPECT_EQ(xemu_gb_is_rom_loaded(gb1), 0);
    EXPECT_EQ(xemu_gb_is_rom_loaded(gb2), 0);
    EXPECT_EQ(xemu_gba_is_rom_loaded(gba1), 0);
    
    // Cleanup
    xemu_gb_destroy(gb1);
    xemu_gb_destroy(gb2);
    xemu_gba_destroy(gba1);
}
