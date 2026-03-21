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

void xemu_mgba_core_set_video_buffer(struct mCore* core, color_t* buffer, size_t stride) {
    if (core && core->setVideoBuffer) {
        core->setVideoBuffer(core, buffer, stride);
    }
}

void xemu_mgba_core_set_audio_buffer_size(struct mCore* core, size_t samples) {
    if (core && core->setAudioBufferSize) {
        core->setAudioBufferSize(core, samples);
    }
}

void xemu_mgba_core_set_audio_sample_rate(struct mCore* core, unsigned sample_rate) {
    if (!core || !core->getAudioChannel || !core->frequency || sample_rate == 0) {
        return;
    }

    blip_t* left = core->getAudioChannel(core, 0);
    blip_t* right = core->getAudioChannel(core, 1);
    if (!left || !right) {
        return;
    }
    const int32_t freq = core->frequency(core);
    if (freq <= 0) {
        return;
    }
    blip_set_rates(left, (double)freq, (double)sample_rate);
    blip_set_rates(right, (double)freq, (double)sample_rate);
}

int xemu_mgba_core_audio_samples_avail(struct mCore* core) {
    if (!core || !core->getAudioChannel) {
        return 0;
    }
    const blip_t* left = core->getAudioChannel(core, 0);
    if (!left) {
        return 0;
    }
    return blip_samples_avail(left);
}

int xemu_mgba_core_audio_read_interleaved(struct mCore* core, int16_t* out, int frames) {
    if (!core || !core->getAudioChannel || !out || frames <= 0) {
        return 0;
    }
    blip_t* left = core->getAudioChannel(core, 0);
    blip_t* right = core->getAudioChannel(core, 1);
    if (!left || !right) {
        return 0;
    }

    const int producedLeft = blip_read_samples(left, out, frames, 1);
    const int producedRight = blip_read_samples(right, out + 1, frames, 1);
    if (producedLeft <= 0 || producedRight <= 0) {
        return 0;
    }
    return producedLeft < producedRight ? producedLeft : producedRight;
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

bool xemu_mgba_core_read8(struct mCore* core, uint32_t address, uint8_t* out_value) {
    if (!core || !out_value || !core->rawRead8) {
        return false;
    }
    *out_value = (uint8_t) core->rawRead8(core, address, -1);
    return true;
}

bool xemu_mgba_core_read16(struct mCore* core, uint32_t address, uint16_t* out_value) {
    if (!core || !out_value || !core->rawRead16) {
        return false;
    }
    *out_value = (uint16_t) core->rawRead16(core, address, -1);
    return true;
}

bool xemu_mgba_core_read32(struct mCore* core, uint32_t address, uint32_t* out_value) {
    if (!core || !out_value || !core->rawRead32) {
        return false;
    }
    *out_value = core->rawRead32(core, address, -1);
    return true;
}
