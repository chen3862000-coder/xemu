#include <gtest/gtest.h>
#include "xemu_cores/xemu_cores.h"
#include <cstring>

class CAPI_Test : public ::testing::Test {
protected:
    void SetUp() override {
        gb = xemu_gb_create();
        gba = xemu_gba_create();
    }
    
    void TearDown() override {
        xemu_gb_destroy(gb);
        xemu_gba_destroy(gba);
    }
    
    xemu_gb_handle_t gb = nullptr;
    xemu_gba_handle_t gba = nullptr;
};

// Version tests
TEST(CAPI_VersionTest, GetVersionString) {
    const char* version = xemu_cores_get_version_string();
    EXPECT_NE(version, nullptr);
    EXPECT_STREQ(version, "0.1.0");
}

TEST(CAPI_VersionTest, GetVersionNumbers) {
    int major, minor, patch;
    xemu_cores_get_version(&major, &minor, &patch);
    EXPECT_EQ(major, 0);
    EXPECT_EQ(minor, 1);
    EXPECT_EQ(patch, 0);
}

TEST(CAPI_VersionTest, GetAPIVersion) {
    EXPECT_EQ(xemu_cores_get_api_version(), 1);
}

// Error string tests
TEST(CAPI_ErrorTest, ErrorStrings) {
    EXPECT_STREQ(xemu_error_string(XEMU_OK), "Success");
    EXPECT_STREQ(xemu_error_string(XEMU_ERROR_INVALID_ARGUMENT), "Invalid argument");
    EXPECT_STREQ(xemu_error_string(XEMU_ERROR_OUT_OF_MEMORY), "Out of memory");
    EXPECT_STREQ(xemu_error_string(XEMU_ERROR_ROM_LOAD_FAILED), "Failed to load ROM");
    EXPECT_STREQ(xemu_error_string(XEMU_ERROR_UNKNOWN), "Unknown error");
}

// GB API tests
TEST_F(CAPI_Test, GB_CreateDestroy) {
    EXPECT_NE(gb, nullptr);
}

TEST_F(CAPI_Test, GB_NotLoadedInitially) {
    EXPECT_EQ(xemu_gb_is_rom_loaded(gb), 0);
}

TEST_F(CAPI_Test, GB_LoadInvalidROM) {
    xemu_error_t err = xemu_gb_load_rom(gb, "test.gb", nullptr, 0);
    EXPECT_EQ(err, XEMU_ERROR_INVALID_ARGUMENT);
}

TEST_F(CAPI_Test, GB_GetVideoBuffer) {
    xemu_video_buffer_t video = xemu_gb_get_video_buffer(gb);
    EXPECT_NE(video.data, nullptr);
    EXPECT_EQ(video.width, 160);
    EXPECT_EQ(video.height, 144);
}

TEST_F(CAPI_Test, GB_GetAudioBuffer) {
    xemu_audio_buffer_t audio = xemu_gb_get_audio_buffer(gb);
    EXPECT_NE(audio.data, nullptr);
    EXPECT_EQ(audio.sample_rate, 44100);
}

TEST_F(CAPI_Test, GB_SaveStateSize) {
    size_t size = xemu_gb_get_save_state_size(gb);
    EXPECT_EQ(size, 128 * 1024); // 128KB
}

TEST_F(CAPI_Test, GB_SaveStateWithoutROM) {
    std::vector<uint8_t> buffer(xemu_gb_get_save_state_size(gb));
    xemu_save_state_t state = {buffer.data(), buffer.size()};
    xemu_error_t err = xemu_gb_save_state(gb, &state);
    EXPECT_EQ(err, XEMU_ERROR_SAVE_STATE_FAILED);
}

TEST_F(CAPI_Test, GB_RunFrameWithoutROM) {
    xemu_error_t err = xemu_gb_run_frame(gb);
    EXPECT_EQ(err, XEMU_ERROR_NOT_INITIALIZED);
}

// GBA API tests
TEST_F(CAPI_Test, GBA_CreateDestroy) {
    EXPECT_NE(gba, nullptr);
}

TEST_F(CAPI_Test, GBA_NotLoadedInitially) {
    EXPECT_EQ(xemu_gba_is_rom_loaded(gba), 0);
}

TEST_F(CAPI_Test, GBA_LoadInvalidROM) {
    xemu_error_t err = xemu_gba_load_rom(gba, "test.gba", nullptr, 0);
    EXPECT_EQ(err, XEMU_ERROR_INVALID_ARGUMENT);
}

TEST_F(CAPI_Test, GBA_GetVideoBuffer) {
    xemu_video_buffer_t video = xemu_gba_get_video_buffer(gba);
    EXPECT_NE(video.data, nullptr);
    EXPECT_EQ(video.width, 240);
    EXPECT_EQ(video.height, 160);
}

TEST_F(CAPI_Test, GBA_GetAudioBuffer) {
    xemu_audio_buffer_t audio = xemu_gba_get_audio_buffer(gba);
    EXPECT_NE(audio.data, nullptr);
    EXPECT_EQ(audio.sample_rate, 44100);
}

TEST_F(CAPI_Test, GBA_SaveStateSize) {
    size_t size = xemu_gba_get_save_state_size(gba);
    EXPECT_EQ(size, 512 * 1024); // 512KB
}

TEST_F(CAPI_Test, GBA_ExtendedButtons) {
    // Test L/R buttons (GBA-specific)
    uint32_t buttons = XEMU_BUTTON_A | XEMU_BUTTON_B | XEMU_BUTTON_L | XEMU_BUTTON_R;
    xemu_gba_set_input(gba, buttons);
    // Should not crash
    xemu_gba_run_frame(gba);
}
