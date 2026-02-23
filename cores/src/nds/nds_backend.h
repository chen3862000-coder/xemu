#pragma once

#include "xemu_cores/xemu_cores.h"

#include <cstddef>
#include <cstdint>
#include <memory>

namespace xemu {
namespace nds {

class Backend {
public:
    virtual ~Backend() = default;

    virtual xemu_error_t loadROM(const char* filename, const uint8_t* data, size_t size) = 0;
    virtual xemu_error_t unloadROM() = 0;
    virtual bool isROMLoaded() const = 0;

    virtual xemu_error_t runFrame() = 0;
    virtual xemu_error_t reset() = 0;

    virtual xemu_video_buffer_t getVideoBuffer() = 0;
    virtual xemu_audio_buffer_t getAudioBuffer() = 0;

    virtual void setInput(uint32_t buttons) = 0;
    virtual void setTouch(xemu_nds_touch_state_t touch) = 0;

    virtual size_t getSaveStateSize() const = 0;
    virtual xemu_error_t saveState(xemu_save_state_t* state) = 0;
    virtual xemu_error_t loadState(const xemu_save_state_t* state) = 0;

    virtual xemu_error_t setScreenLayout(xemu_nds_screen_layout_t layout) = 0;
    virtual xemu_nds_screen_layout_t getScreenLayout() const = 0;
};

// Phase 1: placeholder renderer/input sink used before libretro/melonDS is wired.
std::unique_ptr<Backend> createStubBackend();
std::unique_ptr<Backend> createLibretroBackend();
std::unique_ptr<Backend> createDefaultBackend();

} // namespace nds
} // namespace xemu
