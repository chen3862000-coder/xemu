#include <gtest/gtest.h>
#include "xemu_cores/version.h"

TEST(VersionTest, GetVersionString) {
    const char* version = xemu_cores_get_version_string();
    EXPECT_NE(version, nullptr);
    EXPECT_STREQ(version, "0.1.0");
}

TEST(VersionTest, GetVersionNumbers) {
    int major, minor, patch;
    xemu_cores_get_version(&major, &minor, &patch);
    
    EXPECT_EQ(major, 0);
    EXPECT_EQ(minor, 1);
    EXPECT_EQ(patch, 0);
}

TEST(VersionTest, GetApiVersion) {
    int api_version = xemu_cores_get_api_version();
    EXPECT_EQ(api_version, 1);
}
