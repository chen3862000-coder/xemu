#include "nds/nds_melonds_libretro_binding.h"

namespace xemu {
namespace nds {

#if defined(XEMU_ENABLE_NDS_MELONDS_LIBRETRO_SYMBOLS)
extern "C" {
void retro_set_environment(retro_environment_t);
void retro_set_video_refresh(retro_video_refresh_t);
void retro_set_audio_sample(retro_audio_sample_t);
void retro_set_audio_sample_batch(retro_audio_sample_batch_t);
void retro_set_input_poll(retro_input_poll_t);
void retro_set_input_state(retro_input_state_t);

void retro_init(void);
void retro_deinit(void);
unsigned retro_api_version(void);
void retro_get_system_info(retro_system_info*);
void retro_get_system_av_info(retro_system_av_info*);
void retro_reset(void);
void retro_run(void);

bool retro_load_game(const retro_game_info*);
void retro_unload_game(void);
size_t retro_serialize_size(void);
bool retro_serialize(void* data, size_t size);
bool retro_unserialize(const void* data, size_t size);
} // extern "C"
#endif

LibretroCoreAPI createMelonDSLibretroCoreAPI() {
#if defined(XEMU_ENABLE_NDS_MELONDS_LIBRETRO_SYMBOLS)
    LibretroCoreAPI api;
    api.retro_set_environment = &retro_set_environment;
    api.retro_set_video_refresh = &retro_set_video_refresh;
    api.retro_set_audio_sample = &retro_set_audio_sample;
    api.retro_set_audio_sample_batch = &retro_set_audio_sample_batch;
    api.retro_set_input_poll = &retro_set_input_poll;
    api.retro_set_input_state = &retro_set_input_state;

    api.retro_init = &retro_init;
    api.retro_deinit = &retro_deinit;
    api.retro_api_version = &retro_api_version;
    api.retro_get_system_info = &retro_get_system_info;
    api.retro_get_system_av_info = &retro_get_system_av_info;
    api.retro_reset = &retro_reset;
    api.retro_run = &retro_run;

    api.retro_load_game = &retro_load_game;
    api.retro_unload_game = &retro_unload_game;
    api.retro_serialize_size = &retro_serialize_size;
    api.retro_serialize = &retro_serialize;
    api.retro_unserialize = &retro_unserialize;
    return api;
#else
    return createUnboundLibretroCoreAPI();
#endif
}

} // namespace nds
} // namespace xemu
