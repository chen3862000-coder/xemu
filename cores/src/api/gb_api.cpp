#include "xemu_cores/xemu_cores.h"
#include "../src/gb/gambatte_wrapper.h"
#include <new>
#include <vector>
#include <cstring>

// Opaque handle implementation
struct xemu_gb_s {
    xemu::GambatteWrapper wrapper;
    xemu_video_buffer_t videoBuffer;
    xemu_audio_buffer_t audioBuffer;
    std::vector<uint8_t> videoBufferCopy;  // Persistent copy for safe Swift access
};

extern "C" {

xemu_gb_handle_t xemu_gb_create(void) {
    try {
        auto* handle = new (std::nothrow) xemu_gb_s;
        if (!handle) {
            return nullptr;
        }
        
        // Initialize persistent video copy storage.
        handle->videoBuffer.width = handle->wrapper.getVideoWidth();
        handle->videoBuffer.height = handle->wrapper.getVideoHeight();
        handle->videoBuffer.pitch = handle->wrapper.getVideoWidth() * 4;
        size_t videoSize = handle->videoBuffer.width * handle->videoBuffer.height * 4;
        handle->videoBufferCopy.resize(videoSize);
        std::copy(handle->wrapper.getVideoBuffer(),
                  handle->wrapper.getVideoBuffer() + videoSize,
                  handle->videoBufferCopy.data());
        handle->videoBuffer.data = handle->videoBufferCopy.data();
        
        handle->audioBuffer.data = const_cast<int16_t*>(handle->wrapper.getAudioBuffer());
        handle->audioBuffer.sample_count = handle->wrapper.getAudioSampleCount();
        handle->audioBuffer.sample_rate = xemu::GambatteWrapper::AUDIO_SAMPLE_RATE;
        
        return handle;
    } catch (...) {
        return nullptr;
    }
}

void xemu_gb_destroy(xemu_gb_handle_t handle) {
    if (handle) {
        delete handle;
    }
}

xemu_error_t xemu_gb_load_rom(xemu_gb_handle_t handle, const char* filename, 
                               const uint8_t* data, size_t size) {
    if (!handle) {
        return XEMU_ERROR_INVALID_ARGUMENT;
    }
    
    if (!data || size == 0) {
        return XEMU_ERROR_INVALID_ARGUMENT;
    }
    
    bool success = handle->wrapper.loadROM(filename, data, size);
    return success ? XEMU_OK : XEMU_ERROR_ROM_LOAD_FAILED;
}

xemu_error_t xemu_gb_unload_rom(xemu_gb_handle_t handle) {
    if (!handle) {
        return XEMU_ERROR_INVALID_ARGUMENT;
    }
    
    handle->wrapper.unloadROM();
    return XEMU_OK;
}

int xemu_gb_is_rom_loaded(xemu_gb_handle_t handle) {
    if (!handle) {
        return 0;
    }
    
    return handle->wrapper.isROMLoaded() ? 1 : 0;
}

xemu_error_t xemu_gb_run_frame(xemu_gb_handle_t handle) {
    if (!handle) {
        return XEMU_ERROR_INVALID_ARGUMENT;
    }
    
    if (!handle->wrapper.isROMLoaded()) {
        return XEMU_ERROR_NOT_INITIALIZED;
    }
    
    handle->wrapper.runFrame();
    return XEMU_OK;
}

xemu_error_t xemu_gb_reset(xemu_gb_handle_t handle) {
    if (!handle) {
        return XEMU_ERROR_INVALID_ARGUMENT;
    }
    
    handle->wrapper.reset();
    return XEMU_OK;
}

xemu_video_buffer_t xemu_gb_get_video_buffer(xemu_gb_handle_t handle) {
    if (!handle) {
        return {nullptr, 0, 0, 0};
    }
    
    // Copy video buffer to persistent storage for safe Swift access
    // This prevents issues when the core reuses its internal buffer
    const uint8_t* src = handle->wrapper.getVideoBuffer();
    int width = handle->wrapper.getVideoWidth();
    int height = handle->wrapper.getVideoHeight();
    int pitch = width * 4;
    int size = height * pitch;
    
    handle->videoBufferCopy.resize(size);
    std::memcpy(handle->videoBufferCopy.data(), src, size);
    
    handle->videoBuffer.data = handle->videoBufferCopy.data();
    handle->videoBuffer.width = width;
    handle->videoBuffer.height = height;
    handle->videoBuffer.pitch = pitch;
    
    return handle->videoBuffer;
}

xemu_audio_buffer_t xemu_gb_get_audio_buffer(xemu_gb_handle_t handle) {
    if (!handle) {
        return {nullptr, 0, 0};
    }
    
    // Update sample count
    handle->audioBuffer.sample_count = handle->wrapper.getAudioSampleCount();
    return handle->audioBuffer;
}

void xemu_gb_set_input(xemu_gb_handle_t handle, uint32_t buttons) {
    if (!handle) {
        return;
    }
    
    handle->wrapper.setInput(buttons);
}

size_t xemu_gb_get_save_state_size(xemu_gb_handle_t handle) {
    if (!handle) {
        return 0;
    }
    
    return handle->wrapper.getSaveStateSize();
}

xemu_error_t xemu_gb_save_state(xemu_gb_handle_t handle, xemu_save_state_t* state) {
    if (!handle || !state) {
        return XEMU_ERROR_INVALID_ARGUMENT;
    }
    
    if (!state->data || state->size == 0) {
        return XEMU_ERROR_INVALID_ARGUMENT;
    }
    
    bool success = handle->wrapper.saveState(state->data, state->size);
    return success ? XEMU_OK : XEMU_ERROR_SAVE_STATE_FAILED;
}

xemu_error_t xemu_gb_load_state(xemu_gb_handle_t handle, const xemu_save_state_t* state) {
    if (!handle || !state) {
        return XEMU_ERROR_INVALID_ARGUMENT;
    }
    
    if (!state->data || state->size == 0) {
        return XEMU_ERROR_INVALID_ARGUMENT;
    }
    
    bool success = handle->wrapper.loadState(state->data, state->size);
    return success ? XEMU_OK : XEMU_ERROR_LOAD_STATE_FAILED;
}

size_t xemu_gb_get_battery_save_size(xemu_gb_handle_t handle) {
    if (!handle || !handle->wrapper.isROMLoaded()) {
        return 0;
    }
    return handle->wrapper.getBatterySaveSize();
}

xemu_error_t xemu_gb_save_battery(xemu_gb_handle_t handle, xemu_save_state_t* battery) {
    if (!handle || !battery || !battery->data || battery->size == 0) {
        return XEMU_ERROR_INVALID_ARGUMENT;
    }
    if (!handle->wrapper.isROMLoaded()) {
        return XEMU_ERROR_NOT_INITIALIZED;
    }

    const bool success = handle->wrapper.saveBattery(battery->data, battery->size);
    return success ? XEMU_OK : XEMU_ERROR_SAVE_STATE_FAILED;
}

xemu_error_t xemu_gb_load_battery(xemu_gb_handle_t handle, const xemu_save_state_t* battery) {
    if (!handle || !battery || !battery->data || battery->size == 0) {
        return XEMU_ERROR_INVALID_ARGUMENT;
    }
    if (!handle->wrapper.isROMLoaded()) {
        return XEMU_ERROR_NOT_INITIALIZED;
    }

    const bool success = handle->wrapper.loadBattery(battery->data, battery->size);
    return success ? XEMU_OK : XEMU_ERROR_LOAD_STATE_FAILED;
}

int xemu_gb_is_cgb_mode(xemu_gb_handle_t handle) {
    if (!handle) {
        return 0;
    }
    
    return handle->wrapper.isCGBMode() ? 1 : 0;
}

xemu_error_t xemu_gb_read_memory8(xemu_gb_handle_t handle, uint16_t address, uint8_t* value) {
    if (!handle || !value) {
        return XEMU_ERROR_INVALID_ARGUMENT;
    }

    return handle->wrapper.readMemory8(address, *value) ? XEMU_OK : XEMU_ERROR_UNKNOWN;
}

} // extern "C"
