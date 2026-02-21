cmake_minimum_required(VERSION 3.16)
project(xemu_cores VERSION 0.1.0 LANGUAGES CXX C)

# C++ Standard
set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

# Options
option(BUILD_TESTS "Build unit tests" ON)
option(BUILD_SHARED_LIBS "Build shared libraries" ON)
option(BUILD_STATIC_LIBS "Build static libraries" ON)
option(BUILD_IOS "Build for iOS" OFF)
option(USE_REAL_CORES "Build with real Gambatte/mGBA cores" ON)

# Export compile commands for IDE support
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Include directories
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/include)
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/src)
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/third_party)

# Define XEMU_USE_REAL_CORES for real core support
if(USE_REAL_CORES)
    add_compile_definitions(XEMU_USE_REAL_CORES)
    add_compile_definitions(__LIBRETRO__)
    message(STATUS "Building with REAL emulator cores (Gambatte + mGBA)")
endif()

# Source files
set(XEMU_CORES_SOURCES
    src/api/gb_api.cpp
    src/api/gba_api.cpp
    src/api/error_codes.cpp
)

# GB/GBC sources
set(GB_SOURCES
    src/gb/gambatte_wrapper.cpp
    src/gb/gambatte_video.cpp
    src/gb/gambatte_audio.cpp
    src/gb/gambatte_input.cpp
    src/gb/gambatte_savestate.cpp
)

# GBA sources
set(GBA_SOURCES
    src/gba/mgba_wrapper.cpp
    src/gba/mgba_video.cpp
    src/gba/mgba_audio.cpp
    src/gba/mgba_input.cpp
    src/gba/mgba_savestate.cpp
)

# Gambatte (Game Boy) source files
set(GAMBATTE_SOURCES
    third_party/gambatte/libgambatte/src/gambatte.cpp
    third_party/gambatte/libgambatte/src/gambatte-memory.cpp
    third_party/gambatte/libgambatte/src/cpu.cpp
    third_party/gambatte/libgambatte/src/video.cpp
    third_party/gambatte/libgambatte/src/video_libretro.cpp
    third_party/gambatte/libgambatte/src/sound.cpp
    third_party/gambatte/libgambatte/src/interruptrequester.cpp
    third_party/gambatte/libgambatte/src/interrupter.cpp
    third_party/gambatte/libgambatte/src/bootloader.cpp
    third_party/gambatte/libgambatte/src/initstate.cpp
    third_party/gambatte/libgambatte/src/tima.cpp
    third_party/gambatte/libgambatte/src/statesaver.cpp
    third_party/gambatte/libgambatte/src/video/ppu.cpp
    third_party/gambatte/libgambatte/src/video/ly_counter.cpp
    third_party/gambatte/libgambatte/src/video/next_m0_time.cpp
    third_party/gambatte/libgambatte/src/video/lyc_irq.cpp
    third_party/gambatte/libgambatte/src/video/sprite_mapper.cpp
    third_party/gambatte/libgambatte/src/sound/length_counter.cpp
    third_party/gambatte/libgambatte/src/sound/channel1.cpp
    third_party/gambatte/libgambatte/src/sound/channel2.cpp
    third_party/gambatte/libgambatte/src/sound/channel3.cpp
    third_party/gambatte/libgambatte/src/sound/channel4.cpp
    third_party/gambatte/libgambatte/src/sound/duty_unit.cpp
    third_party/gambatte/libgambatte/src/sound/envelope_unit.cpp
    third_party/gambatte/libgambatte/src/mem/memptrs.cpp
    third_party/gambatte/libgambatte/src/mem/cartridge.cpp
    third_party/gambatte/libgambatte/src/mem/huc3.cpp
    third_party/gambatte/libgambatte/src/mem/rtc.cpp
)

# Gambatte include directories
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/src/gb/gambatte_compat)
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/third_party/gambatte/libgambatte/include)
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/third_party/gambatte/libgambatte/src)
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/third_party/gambatte/common)
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/third_party/gambatte/libgambatte/libretro)

# mGBA (GBA) - use subdirectory for complex build
if(USE_REAL_CORES)
    set(BUILD_LIB ${BUILD_STATIC_LIBS} CACHE BOOL "Build mGBA library" FORCE)
    set(BUILD_QT OFF CACHE BOOL "Disable Qt frontend" FORCE)
    set(BUILD_SDL OFF CACHE BOOL "Disable SDL frontend" FORCE)
    set(USE_DISCORD_RPC OFF CACHE BOOL "Disable Discord RPC" FORCE)
    set(USE_FFMPEG OFF CACHE BOOL "Disable FFmpeg" FORCE)
    set(USE_ZLIB OFF CACHE BOOL "Disable zlib" FORCE)
    set(USE_LIBZIP OFF CACHE BOOL "Disable libzip" FORCE)
    set(USE_LIBPNG OFF CACHE BOOL "Disable libpng" FORCE)
    set(USE_SQLITE3 OFF CACHE BOOL "Disable SQLite3" FORCE)
    set(USE_LZMA OFF CACHE BOOL "Disable LZMA" FORCE)
    set(ENABLE_SCRIPTING OFF CACHE BOOL "Disable scripting" FORCE)
    set(ENABLE_TESTS OFF CACHE BOOL "Disable tests" FORCE)
    add_subdirectory(third_party/mgba EXCLUDE_FROM_ALL)
endif()

# All sources
set(ALL_SOURCES ${XEMU_CORES_SOURCES} ${GB_SOURCES} ${GBA_SOURCES})
if(USE_REAL_CORES)
    list(APPEND ALL_SOURCES ${GAMBATTE_SOURCES})
endif()

# Shared library
if(BUILD_SHARED_LIBS)
    add_library(xemu_cores_shared SHARED ${ALL_SOURCES})
    set_target_properties(xemu_cores_shared PROPERTIES
        OUTPUT_NAME xemu_cores
        VERSION ${PROJECT_VERSION}
        SOVERSION ${PROJECT_VERSION_MAJOR}
        PUBLIC_HEADER "include/xemu_cores/xemu_cores.h;include/xemu_cores/version.h"
    )
    target_include_directories(xemu_cores_shared PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
        $<INSTALL_INTERFACE:include>
    )
    if(USE_REAL_CORES)
        target_link_libraries(xemu_cores_shared PRIVATE mgba)
        target_include_directories(xemu_cores_shared PRIVATE
            ${CMAKE_CURRENT_SOURCE_DIR}/third_party/mgba/include
            ${CMAKE_CURRENT_SOURCE_DIR}/third_party/mgba/src
        )
    endif()
endif()

# Static library
if(BUILD_STATIC_LIBS)
    add_library(xemu_cores_static STATIC ${ALL_SOURCES})
    set_target_properties(xemu_cores_static PROPERTIES
        OUTPUT_NAME xemu_cores
        PUBLIC_HEADER "include/xemu_cores/xemu_cores.h;include/xemu_cores/version.h"
    )
    target_include_directories(xemu_cores_static PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
        $<INSTALL_INTERFACE:include>
    )
    if(USE_REAL_CORES)
        target_link_libraries(xemu_cores_static PRIVATE mgba)
        target_include_directories(xemu_cores_static PRIVATE
            ${CMAKE_CURRENT_SOURCE_DIR}/third_party/mgba/include
            ${CMAKE_CURRENT_SOURCE_DIR}/third_party/mgba/src
        )
    endif()
endif()

# iOS Framework
if(BUILD_IOS)
    set(CMAKE_OSX_SYSROOT iphoneos)
    set(CMAKE_OSX_ARCHITECTURES "arm64")
    set(CMAKE_OSX_DEPLOYMENT_TARGET "14.0")
    
    add_library(xemu_cores_framework SHARED ${ALL_SOURCES})
    set_target_properties(xemu_cores_framework PROPERTIES
        FRAMEWORK TRUE
        FRAMEWORK_VERSION A
        MACOSX_FRAMEWORK_IDENTIFIER com.xemu.cores
        MACOSX_FRAMEWORK_INFO_PLIST ${CMAKE_CURRENT_SOURCE_DIR}/Info.plist
        PUBLIC_HEADER "include/xemu_cores/xemu_cores.h;include/xemu_cores/version.h"
        OUTPUT_NAME XemuCores
    )
    target_include_directories(xemu_cores_framework PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
        $<INSTALL_INTERFACE:include>
    )
endif()

# Add subdirectories
add_subdirectory(src/gb)
add_subdirectory(src/gba)

# Testing
if(BUILD_TESTS)
    enable_testing()
    add_subdirectory(tests)
endif()

# Installation
include(GNUInstallDirs)

if(BUILD_SHARED_LIBS)
    install(TARGETS xemu_cores_shared
        LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
        ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
        RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
        PUBLIC_HEADER DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/xemu_cores
    )
endif()

if(BUILD_STATIC_LIBS)
    install(TARGETS xemu_cores_static
        ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
        PUBLIC_HEADER DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/xemu_cores
    )
endif()

# pkg-config file
configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/xemu-cores.pc.in
    ${CMAKE_CURRENT_BINARY_DIR}/xemu-cores.pc
    @ONLY
)

install(FILES ${CMAKE_CURRENT_BINARY_DIR}/xemu-cores.pc
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/pkgconfig
)

# Print configuration summary
message(STATUS "")
message(STATUS "Xemu Cores Library Configuration:")
message(STATUS "  Version: ${PROJECT_VERSION}")
message(STATUS "  Build tests: ${BUILD_TESTS}")
message(STATUS "  Build shared libs: ${BUILD_SHARED_LIBS}")
message(STATUS "  Build static libs: ${BUILD_STATIC_LIBS}")
message(STATUS "  Build for iOS: ${BUILD_IOS}")
message(STATUS "  Install prefix: ${CMAKE_INSTALL_PREFIX}")
message(STATUS "")
