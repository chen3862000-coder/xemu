#pragma once

#include "nds/nds_libretro_abi.h"

namespace xemu {
namespace nds {

// Function pointer table for a libretro core. In the next phase this will be
// populated from a vendored core (direct symbols or dynamic binding shim).
struct LibretroCoreAPI {
    void (*retro_set_environment)(retro_environment_t) = nullptr;
    void (*retro_set_video_refresh)(retro_video_refresh_t) = nullptr;
    void (*retro_set_audio_sample)(retro_audio_sample_t) = nullptr;
    void (*retro_set_audio_sample_batch)(retro_audio_sample_batch_t) = nullptr;
    void (*retro_set_input_poll)(retro_input_poll_t) = nullptr;
    void (*retro_set_input_state)(retro_input_state_t) = nullptr;

    void (*retro_init)(void) = nullptr;
    void (*retro_deinit)(void) = nullptr;
    unsigned (*retro_api_version)(void) = nullptr;
    void (*retro_get_system_info)(retro_system_info*) = nullptr;
    void (*retro_get_system_av_info)(retro_system_av_info*) = nullptr;
    void (*retro_reset)(void) = nullptr;
    void (*retro_run)(void) = nullptr;

    bool (*retro_load_game)(const retro_game_info*) = nullptr;
    void (*retro_unload_game)(void) = nullptr;
    size_t (*retro_serialize_size)(void) = nullptr;
    bool (*retro_serialize)(void* data, size_t size) = nullptr;
    bool (*retro_unserialize)(const void* data, size_t size) = nullptr;
};

LibretroCoreAPI createUnboundLibretroCoreAPI();

} // namespace nds
} // namespace xemu
