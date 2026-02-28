#include "mgba_core_bridge.h"

uintptr_t xemu_mgba_core_init_ptr(struct mCore* core) {
    return core && core->init ? (uintptr_t) core->init : 0;
}

bool xemu_mgba_core_init(struct mCore* core) {
    return core && core->init && core->init(core);
}

void xemu_mgba_core_deinit(struct mCore* core) {
    if (core && core->deinit) {
        core->deinit(core);
    }
}

void xemu_mgba_core_set_video_buffer(struct mCore* core, mColor* buffer, size_t stride) {
    if (core && core->setVideoBuffer) {
        core->setVideoBuffer(core, buffer, stride);
    }
}

void xemu_mgba_core_set_audio_buffer_size(struct mCore* core, size_t samples) {
    if (core && core->setAudioBufferSize) {
        core->setAudioBufferSize(core, samples);
    }
}

unsigned xemu_mgba_core_audio_sample_rate(struct mCore* core) {
    if (core && core->audioSampleRate) {
        return core->audioSampleRate(core);
    }
    return 0;
}

bool xemu_mgba_core_preload_vf(struct mCore* core, struct VFile* vf) {
    if (!core || !vf) {
        return false;
    }
    return mCorePreloadVF(core, vf);
}

void xemu_mgba_core_set_keys(struct mCore* core, uint32_t keys) {
    if (core && core->setKeys) {
        core->setKeys(core, keys);
    }
}

void xemu_mgba_core_reset(struct mCore* core) {
    if (core && core->reset) {
        core->reset(core);
    }
}

void xemu_mgba_core_run_frame(struct mCore* core) {
    if (core && core->runFrame) {
        core->runFrame(core);
    }
}

bool xemu_mgba_core_get_pixels(struct mCore* core, const void** buffer, size_t* stride) {
    if (core && core->getPixels) {
        core->getPixels(core, buffer, stride);
        return true;
    }
    return false;
}

struct mAudioBuffer* xemu_mgba_core_get_audio_buffer(struct mCore* core) {
    if (core && core->getAudioBuffer) {
        return core->getAudioBuffer(core);
    }
    return 0;
}

void xemu_mgba_core_unload_rom(struct mCore* core) {
    if (core && core->unloadROM) {
        core->unloadROM(core);
    }
}

size_t xemu_mgba_core_state_size(struct mCore* core) {
    if (core && core->stateSize) {
        return core->stateSize(core);
    }
    return 0;
}

bool xemu_mgba_core_save_state(struct mCore* core, void* state) {
    return core && state && core->saveState && core->saveState(core, state);
}

bool xemu_mgba_core_load_state(struct mCore* core, const void* state) {
    return core && state && core->loadState && core->loadState(core, state);
}

size_t xemu_mgba_core_savedata_clone(struct mCore* core, void** out_savedata) {
    if (!out_savedata) {
        return 0;
    }
    *out_savedata = 0;
    if (core && core->savedataClone) {
        return core->savedataClone(core, out_savedata);
    }
    return 0;
}

bool xemu_mgba_core_savedata_restore(struct mCore* core, const void* savedata, size_t size, bool writeback) {
    return core && savedata && size > 0 && core->savedataRestore &&
           core->savedataRestore(core, savedata, size, writeback);
}
