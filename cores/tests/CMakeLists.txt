# Tests CMakeLists.txt

# Find Google Test
find_package(GTest QUIET)

if(NOT GTest_FOUND)
    # Download and build Google Test
    include(FetchContent)
    FetchContent_Declare(
        googletest
        GIT_REPOSITORY https://github.com/google/googletest.git
        GIT_TAG release-1.12.1
    )
    FetchContent_MakeAvailable(googletest)
endif()

# Test sources
set(TEST_SOURCES
    main.cpp
    gb/gambatte_wrapper_test.cpp
    gba/mgba_wrapper_test.cpp
    api/c_api_test.cpp
    api/test_error_codes.cpp
    api/test_version.cpp
)

# Create test executable
add_executable(xemu_cores_test ${TEST_SOURCES})

# Link against library and gtest
target_link_libraries(xemu_cores_test
    xemu_cores_static
    GTest::gtest
    GTest::gtest_main
)

# Add test
add_test(NAME xemu_cores_unit_tests COMMAND xemu_cores_test)

# Copy test fixtures
file(COPY ${CMAKE_CURRENT_SOURCE_DIR}/fixtures 
     DESTINATION ${CMAKE_CURRENT_BINARY_DIR})
