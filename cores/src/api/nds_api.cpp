#include "xemu_cores/xemu_cores.h"

#include "nds/nds_backend.h"

#include <new>

struct xemu_nds_s {
    xemu::nds::Backend* backend = nullptr;
};

extern "C" {

xemu_nds_handle_t xemu_nds_create(void) {
    try {
        auto* handle = new (std::nothrow) xemu_nds_s;
        if (!handle) {
            return nullptr;
        }
        auto backend = xemu::nds::createDefaultBackend();
        handle->backend = backend.release();
        if (!handle->backend) {
            delete handle;
            return nullptr;
        }
        return handle;
    } catch (...) {
        return nullptr;
    }
}

void xemu_nds_destroy(xemu_nds_handle_t handle) {
    if (handle && handle->backend) {
        delete handle->backend;
        handle->backend = nullptr;
    }
    delete handle;
}

xemu_error_t xemu_nds_load_rom(xemu_nds_handle_t handle, const char* filename,
                               const uint8_t* data, size_t size) {
    (void)filename;
    (void)data;
    (void)size;

    if (!handle) {
        return XEMU_ERROR_INVALID_ARGUMENT;
    }

    if (!handle->backend) {
        return XEMU_ERROR_NOT_INITIALIZED;
    }
    return handle->backend->loadROM(filename, data, size);
}

xemu_error_t xemu_nds_unload_rom(xemu_nds_handle_t handle) {
    if (!handle) {
        return XEMU_ERROR_INVALID_ARGUMENT;
    }
    if (!handle->backend) {
        return XEMU_ERROR_NOT_INITIALIZED;
    }
    return handle->backend->unloadROM();
}

int xemu_nds_is_rom_loaded(xemu_nds_handle_t handle) {
    if (!handle) {
        return 0;
    }
    if (!handle->backend) {
        return 0;
    }
    return handle->backend->isROMLoaded() ? 1 : 0;
}

xemu_error_t xemu_nds_run_frame(xemu_nds_handle_t handle) {
    if (!handle) {
        return XEMU_ERROR_INVALID_ARGUMENT;
    }

    if (!handle->backend) {
        return XEMU_ERROR_NOT_INITIALIZED;
    }
    return handle->backend->runFrame();
}

xemu_error_t xemu_nds_reset(xemu_nds_handle_t handle) {
    if (!handle) {
        return XEMU_ERROR_INVALID_ARGUMENT;
    }
    if (!handle->backend) {
        return XEMU_ERROR_NOT_INITIALIZED;
    }
    return handle->backend->reset();
}

xemu_video_buffer_t xemu_nds_get_video_buffer(xemu_nds_handle_t handle) {
    if (!handle) {
        return {nullptr, 0, 0, 0};
    }
    if (!handle->backend) {
        return {nullptr, 0, 0, 0};
    }
    return handle->backend->getVideoBuffer();
}

xemu_audio_buffer_t xemu_nds_get_audio_buffer(xemu_nds_handle_t handle) {
    if (!handle) {
        return {nullptr, 0, 0};
    }
    if (!handle->backend) {
        return {nullptr, 0, 0};
    }
    return handle->backend->getAudioBuffer();
}

void xemu_nds_set_input(xemu_nds_handle_t handle, uint32_t buttons) {
    if (!handle) {
        return;
    }
    if (!handle->backend) {
        return;
    }
    handle->backend->setInput(buttons);
}

void xemu_nds_set_touch(xemu_nds_handle_t handle, xemu_nds_touch_state_t touch) {
    if (!handle) {
        return;
    }
    if (!handle->backend) {
        return;
    }
    handle->backend->setTouch(touch);
}

size_t xemu_nds_get_save_state_size(xemu_nds_handle_t handle) {
    if (!handle) {
        return 0;
    }
    if (!handle->backend) {
        return 0;
    }
    return handle->backend->getSaveStateSize();
}

xemu_error_t xemu_nds_save_state(xemu_nds_handle_t handle, xemu_save_state_t* state) {
    (void)state;
    if (!handle) {
        return XEMU_ERROR_INVALID_ARGUMENT;
    }
    if (!handle->backend) {
        return XEMU_ERROR_NOT_INITIALIZED;
    }
    return handle->backend->saveState(state);
}

xemu_error_t xemu_nds_load_state(xemu_nds_handle_t handle, const xemu_save_state_t* state) {
    (void)state;
    if (!handle) {
        return XEMU_ERROR_INVALID_ARGUMENT;
    }
    if (!handle->backend) {
        return XEMU_ERROR_NOT_INITIALIZED;
    }
    return handle->backend->loadState(state);
}

xemu_error_t xemu_nds_set_screen_layout(xemu_nds_handle_t handle, xemu_nds_screen_layout_t layout) {
    if (!handle) {
        return XEMU_ERROR_INVALID_ARGUMENT;
    }

    if (!handle->backend) {
        return XEMU_ERROR_NOT_INITIALIZED;
    }
    return handle->backend->setScreenLayout(layout);
}

xemu_nds_screen_layout_t xemu_nds_get_screen_layout(xemu_nds_handle_t handle) {
    if (!handle) {
        return XEMU_NDS_SCREEN_LAYOUT_STACKED;
    }
    if (!handle->backend) {
        return XEMU_NDS_SCREEN_LAYOUT_STACKED;
    }
    return handle->backend->getScreenLayout();
}

} // extern "C"
