#ifndef XEMU_MGBA_CORE_BRIDGE_H
#define XEMU_MGBA_CORE_BRIDGE_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include <mgba/core/core.h>
#include <mgba/core/blip_buf.h>
#include <mgba-util/vfs.h>

#ifdef __cplusplus
extern "C" {
#endif

uintptr_t xemu_mgba_core_init_ptr(struct mCore* core);
bool xemu_mgba_core_init(struct mCore* core);
void xemu_mgba_core_deinit(struct mCore* core);
void xemu_mgba_core_set_video_buffer(struct mCore* core, color_t* buffer, size_t stride);
void xemu_mgba_core_set_audio_buffer_size(struct mCore* core, size_t samples);
void xemu_mgba_core_set_audio_sample_rate(struct mCore* core, unsigned sample_rate);
int xemu_mgba_core_audio_samples_avail(struct mCore* core);
int xemu_mgba_core_audio_read_interleaved(struct mCore* core, int16_t* out, int frames);
bool xemu_mgba_core_preload_vf(struct mCore* core, struct VFile* vf);
void xemu_mgba_core_set_keys(struct mCore* core, uint32_t keys);
void xemu_mgba_core_reset(struct mCore* core);
void xemu_mgba_core_run_frame(struct mCore* core);
bool xemu_mgba_core_get_pixels(struct mCore* core, const void** buffer, size_t* stride);
void xemu_mgba_core_unload_rom(struct mCore* core);
size_t xemu_mgba_core_state_size(struct mCore* core);
bool xemu_mgba_core_save_state(struct mCore* core, void* state);
bool xemu_mgba_core_load_state(struct mCore* core, const void* state);
size_t xemu_mgba_core_savedata_clone(struct mCore* core, void** out_savedata);
bool xemu_mgba_core_savedata_restore(struct mCore* core, const void* savedata, size_t size, bool writeback);

#ifdef __cplusplus
}
#endif

#endif
