#include <gtest/gtest.h>
#include "xemu_cores/xemu_cores.h"

TEST(ErrorCodesTest, GetErrorString) {
    EXPECT_STREQ(xemu_error_string(XEMU_OK), "Success");
    EXPECT_STREQ(xemu_error_string(XEMU_ERROR_INVALID_ARGUMENT), "Invalid argument");
    EXPECT_STREQ(xemu_error_string(XEMU_ERROR_OUT_OF_MEMORY), "Out of memory");
    EXPECT_STREQ(xemu_error_string(XEMU_ERROR_ROM_LOAD_FAILED), "Failed to load ROM");
    EXPECT_STREQ(xemu_error_string(XEMU_ERROR_UNSUPPORTED_FORMAT), "Unsupported ROM format");
    EXPECT_STREQ(xemu_error_string(XEMU_ERROR_NOT_INITIALIZED), "Core not initialized");
    EXPECT_STREQ(xemu_error_string(XEMU_ERROR_ALREADY_RUNNING), "Core already running");
    EXPECT_STREQ(xemu_error_string(XEMU_ERROR_SAVE_STATE_FAILED), "Failed to save state");
    EXPECT_STREQ(xemu_error_string(XEMU_ERROR_LOAD_STATE_FAILED), "Failed to load state");
    EXPECT_STREQ(xemu_error_string(XEMU_ERROR_BUFFER_TOO_SMALL), "Buffer too small");
    EXPECT_STREQ(xemu_error_string(XEMU_ERROR_UNKNOWN), "Unknown error");
}
