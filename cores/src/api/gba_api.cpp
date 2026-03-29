#include "xemu_cores/xemu_cores.h"
#include "../src/gba/mgba_wrapper.h"
#include <cstdio>
#include <new>

// Opaque handle implementation
struct xemu_gba_s {
    xemu::mGBAWrapper wrapper;
    xemu_video_buffer_t videoBuffer;
    xemu_audio_buffer_t audioBuffer;
};

extern "C" {

xemu_gba_handle_t xemu_gba_create(void) {
    try {
        auto* handle = new (std::nothrow) xemu_gba_s;
        if (!handle) {
            return nullptr;
        }

        // Initialize buffer structures with validation
        handle->videoBuffer.width = handle->wrapper.getVideoWidth();
        handle->videoBuffer.height = handle->wrapper.getVideoHeight();
        handle->videoBuffer.pitch = handle->wrapper.getVideoWidth() * 4;

        // Validate dimensions
        if (handle->videoBuffer.width <= 0 || handle->videoBuffer.height <= 0) {
            delete handle;
            return nullptr;
        }

        // Check for potential overflow in size calculation
        if (handle->videoBuffer.width > 16384 || handle->videoBuffer.height > 16384) {
            delete handle;
            return nullptr;
        }

        // Store pointer to internal video buffer - marked const in wrapper
        // We need to provide mutable pointer for Swift compatibility, but wrapper
        // doesn't actually modify through this path
        handle->videoBuffer.data = const_cast<uint8_t*>(handle->wrapper.getVideoBuffer());

        // Initialize audio buffer with validation
        handle->audioBuffer.data = const_cast<int16_t*>(handle->wrapper.getAudioBuffer());
        handle->audioBuffer.sample_count = handle->wrapper.getAudioSampleCount();
        int sampleRate = handle->wrapper.getAudioSampleRate();
        if (sampleRate <= 0 || sampleRate > 192000) {
            sampleRate = 44100; // Fallback to safe default
        }
        handle->audioBuffer.sample_rate = sampleRate;

        return handle;
    } catch (...) {
        return nullptr;
    }
}

void xemu_gba_destroy(xemu_gba_handle_t handle) {
    delete handle;
}

xemu_error_t xemu_gba_load_rom(xemu_gba_handle_t handle, const char* filename,
                                const uint8_t* data, size_t size) {
    if (!handle) {
        return XEMU_ERROR_INVALID_ARGUMENT;
    }
    
    if (!data || size == 0) {
        return XEMU_ERROR_INVALID_ARGUMENT;
    }
    
    bool success = handle->wrapper.loadROM(filename, data, size);
    if (!success) {
        std::fprintf(stderr,
                     "[xemu_gba_load_rom] failed filename=%s size=%zu\n",
                     filename ? filename : "<null>",
                     size);
    }
    return success ? XEMU_OK : XEMU_ERROR_ROM_LOAD_FAILED;
}

xemu_error_t xemu_gba_unload_rom(xemu_gba_handle_t handle) {
    if (!handle) {
        return XEMU_ERROR_INVALID_ARGUMENT;
    }
    
    handle->wrapper.unloadROM();
    return XEMU_OK;
}

int xemu_gba_is_rom_loaded(xemu_gba_handle_t handle) {
    if (!handle) {
        return 0;
    }
    
    return handle->wrapper.isROMLoaded() ? 1 : 0;
}

xemu_error_t xemu_gba_run_frame(xemu_gba_handle_t handle) {
    if (!handle) {
        return XEMU_ERROR_INVALID_ARGUMENT;
    }
    
    if (!handle->wrapper.isROMLoaded()) {
        return XEMU_ERROR_NOT_INITIALIZED;
    }
    
    handle->wrapper.runFrame();
    return XEMU_OK;
}

xemu_error_t xemu_gba_reset(xemu_gba_handle_t handle) {
    if (!handle) {
        return XEMU_ERROR_INVALID_ARGUMENT;
    }
    
    handle->wrapper.reset();
    return XEMU_OK;
}

xemu_video_buffer_t xemu_gba_get_video_buffer(xemu_gba_handle_t handle) {
    if (!handle) {
        return {nullptr, 0, 0, 0};
    }
    
    return handle->videoBuffer;
}

xemu_audio_buffer_t xemu_gba_get_audio_buffer(xemu_gba_handle_t handle) {
    if (!handle) {
        return {nullptr, 0, 0};
    }
    
    // Update dynamic audio metadata
    handle->audioBuffer.sample_count = handle->wrapper.getAudioSampleCount();
    handle->audioBuffer.sample_rate = handle->wrapper.getAudioSampleRate();
    return handle->audioBuffer;
}

void xemu_gba_set_input(xemu_gba_handle_t handle, uint32_t buttons) {
    if (!handle) {
        return;
    }
    
    handle->wrapper.setInput(buttons);
}

size_t xemu_gba_get_save_state_size(xemu_gba_handle_t handle) {
    if (!handle) {
        return 0;
    }
    
    return handle->wrapper.getSaveStateSize();
}

xemu_error_t xemu_gba_save_state(xemu_gba_handle_t handle, xemu_save_state_t* state) {
    if (!handle || !state) {
        return XEMU_ERROR_INVALID_ARGUMENT;
    }
    
    if (!state->data || state->size == 0) {
        return XEMU_ERROR_INVALID_ARGUMENT;
    }
    
    bool success = handle->wrapper.saveState(state->data, state->size);
    return success ? XEMU_OK : XEMU_ERROR_SAVE_STATE_FAILED;
}

xemu_error_t xemu_gba_load_state(xemu_gba_handle_t handle, const xemu_save_state_t* state) {
    if (!handle || !state) {
        return XEMU_ERROR_INVALID_ARGUMENT;
    }
    
    if (!state->data || state->size == 0) {
        return XEMU_ERROR_INVALID_ARGUMENT;
    }
    
    bool success = handle->wrapper.loadState(state->data, state->size);
    return success ? XEMU_OK : XEMU_ERROR_LOAD_STATE_FAILED;
}

size_t xemu_gba_get_battery_save_size(xemu_gba_handle_t handle) {
    if (!handle || !handle->wrapper.isROMLoaded()) {
        return 0;
    }
    return handle->wrapper.getBatterySaveSize();
}

xemu_error_t xemu_gba_save_battery(xemu_gba_handle_t handle, xemu_save_state_t* battery) {
    if (!handle || !battery || !battery->data || battery->size == 0) {
        return XEMU_ERROR_INVALID_ARGUMENT;
    }
    if (!handle->wrapper.isROMLoaded()) {
        return XEMU_ERROR_NOT_INITIALIZED;
    }

    const bool success = handle->wrapper.saveBattery(battery->data, battery->size);
    return success ? XEMU_OK : XEMU_ERROR_SAVE_STATE_FAILED;
}

xemu_error_t xemu_gba_load_battery(xemu_gba_handle_t handle, const xemu_save_state_t* battery) {
    if (!handle || !battery || !battery->data || battery->size == 0) {
        return XEMU_ERROR_INVALID_ARGUMENT;
    }
    if (!handle->wrapper.isROMLoaded()) {
        return XEMU_ERROR_NOT_INITIALIZED;
    }

    const bool success = handle->wrapper.loadBattery(battery->data, battery->size);
    return success ? XEMU_OK : XEMU_ERROR_LOAD_STATE_FAILED;
}

xemu_error_t xemu_gba_read_memory8(xemu_gba_handle_t handle, uint32_t address, uint8_t* value) {
    if (!handle || !value) {
        return XEMU_ERROR_INVALID_ARGUMENT;
    }
    if (!handle->wrapper.isROMLoaded()) {
        return XEMU_ERROR_NOT_INITIALIZED;
    }
    return handle->wrapper.readMemory8(address, *value) ? XEMU_OK : XEMU_ERROR_UNKNOWN;
}

xemu_error_t xemu_gba_read_memory16(xemu_gba_handle_t handle, uint32_t address, uint16_t* value) {
    if (!handle || !value) {
        return XEMU_ERROR_INVALID_ARGUMENT;
    }
    if (!handle->wrapper.isROMLoaded()) {
        return XEMU_ERROR_NOT_INITIALIZED;
    }
    return handle->wrapper.readMemory16(address, *value) ? XEMU_OK : XEMU_ERROR_UNKNOWN;
}

xemu_error_t xemu_gba_read_memory32(xemu_gba_handle_t handle, uint32_t address, uint32_t* value) {
    if (!handle || !value) {
        return XEMU_ERROR_INVALID_ARGUMENT;
    }
    if (!handle->wrapper.isROMLoaded()) {
        return XEMU_ERROR_NOT_INITIALIZED;
    }
    return handle->wrapper.readMemory32(address, *value) ? XEMU_OK : XEMU_ERROR_UNKNOWN;
}

} // extern "C"
