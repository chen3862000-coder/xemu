#ifndef XEMU_CORES_H
#define XEMU_CORES_H

#include <stdint.h>
#include <stddef.h>
#include "version.h"

#ifdef __cplusplus
extern "C" {
#endif

/* Error codes */
typedef enum {
    XEMU_OK = 0,
    XEMU_ERROR_INVALID_ARGUMENT = -1,
    XEMU_ERROR_OUT_OF_MEMORY = -2,
    XEMU_ERROR_ROM_LOAD_FAILED = -3,
    XEMU_ERROR_UNSUPPORTED_FORMAT = -4,
    XEMU_ERROR_NOT_INITIALIZED = -5,
    XEMU_ERROR_ALREADY_RUNNING = -6,
    XEMU_ERROR_SAVE_STATE_FAILED = -7,
    XEMU_ERROR_LOAD_STATE_FAILED = -8,
    XEMU_ERROR_BUFFER_TOO_SMALL = -9,
    XEMU_ERROR_UNKNOWN = -100
} xemu_error_t;

/* Get error string for error code */
const char* xemu_error_string(xemu_error_t error);

/* Input buttons (bitmask) */
#define XEMU_BUTTON_A      0x01
#define XEMU_BUTTON_B      0x02
#define XEMU_BUTTON_SELECT 0x04
#define XEMU_BUTTON_START  0x08
#define XEMU_BUTTON_RIGHT  0x10
#define XEMU_BUTTON_LEFT   0x20
#define XEMU_BUTTON_UP     0x40
#define XEMU_BUTTON_DOWN   0x80

/* GBA extended buttons */
#define XEMU_BUTTON_L      0x100
#define XEMU_BUTTON_R      0x200

/* NDS extended buttons */
#define XEMU_BUTTON_X      0x400
#define XEMU_BUTTON_Y      0x800

/* Video buffer info */
typedef struct {
    uint8_t* data;          /* RGBA8888 format */
    int width;
    int height;
    int pitch;              /* Bytes per row */
} xemu_video_buffer_t;

/* Audio buffer info */
typedef struct {
    int16_t* data;          /* Stereo interleaved: L,R,L,R... */
    int sample_count;       /* Total samples (frames * channels) */
    int sample_rate;        /* Hz (typically 44100) */
} xemu_audio_buffer_t;

/* Save state buffer */
typedef struct {
    uint8_t* data;
    size_t size;
} xemu_save_state_t;

/* ============================================================================
 * Game Boy / Game Boy Color API
 * ============================================================================ */

typedef struct xemu_gb_s* xemu_gb_handle_t;

/* Create/destroy */
xemu_gb_handle_t xemu_gb_create(void);
void xemu_gb_destroy(xemu_gb_handle_t handle);

/* ROM loading */
xemu_error_t xemu_gb_load_rom(xemu_gb_handle_t handle, const char* filename, 
                               const uint8_t* data, size_t size);
xemu_error_t xemu_gb_unload_rom(xemu_gb_handle_t handle);
int xemu_gb_is_rom_loaded(xemu_gb_handle_t handle);

/* Execution */
xemu_error_t xemu_gb_run_frame(xemu_gb_handle_t handle);
xemu_error_t xemu_gb_reset(xemu_gb_handle_t handle);

/* Video (160x144, RGBA8888) */
xemu_video_buffer_t xemu_gb_get_video_buffer(xemu_gb_handle_t handle);

/* Audio (44100Hz stereo) */
xemu_audio_buffer_t xemu_gb_get_audio_buffer(xemu_gb_handle_t handle);

/* Input */
void xemu_gb_set_input(xemu_gb_handle_t handle, uint32_t buttons);

/* Save states */
size_t xemu_gb_get_save_state_size(xemu_gb_handle_t handle);
xemu_error_t xemu_gb_save_state(xemu_gb_handle_t handle, xemu_save_state_t* state);
xemu_error_t xemu_gb_load_state(xemu_gb_handle_t handle, const xemu_save_state_t* state);

/* System type detection */
int xemu_gb_is_cgb_mode(xemu_gb_handle_t handle);

/* ============================================================================
 * Game Boy Advance API
 * ============================================================================ */

typedef struct xemu_gba_s* xemu_gba_handle_t;

/* Create/destroy */
xemu_gba_handle_t xemu_gba_create(void);
void xemu_gba_destroy(xemu_gba_handle_t handle);

/* ROM loading */
xemu_error_t xemu_gba_load_rom(xemu_gba_handle_t handle, const char* filename,
                                const uint8_t* data, size_t size);
xemu_error_t xemu_gba_unload_rom(xemu_gba_handle_t handle);
int xemu_gba_is_rom_loaded(xemu_gba_handle_t handle);

/* Execution */
xemu_error_t xemu_gba_run_frame(xemu_gba_handle_t handle);
xemu_error_t xemu_gba_reset(xemu_gba_handle_t handle);

/* Video (240x160, RGBA8888) */
xemu_video_buffer_t xemu_gba_get_video_buffer(xemu_gba_handle_t handle);

/* Audio (44100Hz stereo) */
xemu_audio_buffer_t xemu_gba_get_audio_buffer(xemu_gba_handle_t handle);

/* Input (includes L/R buttons) */
void xemu_gba_set_input(xemu_gba_handle_t handle, uint32_t buttons);

/* Save states */
size_t xemu_gba_get_save_state_size(xemu_gba_handle_t handle);
xemu_error_t xemu_gba_save_state(xemu_gba_handle_t handle, xemu_save_state_t* state);
xemu_error_t xemu_gba_load_state(xemu_gba_handle_t handle, const xemu_save_state_t* state);

/* ============================================================================
 * Nintendo DS API (skeleton)
 * ============================================================================
 *
 * Initial implementation is a stub scaffold to establish a stable ABI for the
 * future melonDS/libretro integration. ROM loading/execution may return
 * XEMU_ERROR_UNSUPPORTED_FORMAT until the core backend is wired.
 * ============================================================================ */

typedef struct xemu_nds_s* xemu_nds_handle_t;

typedef enum {
    XEMU_NDS_SCREEN_LAYOUT_STACKED = 0,
    XEMU_NDS_SCREEN_LAYOUT_SIDE_BY_SIDE = 1,
    XEMU_NDS_SCREEN_LAYOUT_TOP_ONLY = 2,
    XEMU_NDS_SCREEN_LAYOUT_BOTTOM_ONLY = 3
} xemu_nds_screen_layout_t;

typedef struct {
    int x;              /* DS touchscreen X (0..255) */
    int y;              /* DS touchscreen Y (0..191) */
    int is_pressed;     /* 0 or 1 */
} xemu_nds_touch_state_t;

/* Create/destroy */
xemu_nds_handle_t xemu_nds_create(void);
void xemu_nds_destroy(xemu_nds_handle_t handle);

/* ROM loading */
xemu_error_t xemu_nds_load_rom(xemu_nds_handle_t handle, const char* filename,
                               const uint8_t* data, size_t size);
xemu_error_t xemu_nds_unload_rom(xemu_nds_handle_t handle);
int xemu_nds_is_rom_loaded(xemu_nds_handle_t handle);

/* Execution */
xemu_error_t xemu_nds_run_frame(xemu_nds_handle_t handle);
xemu_error_t xemu_nds_reset(xemu_nds_handle_t handle);

/* Video (composited dual-screen output, RGBA8888) */
xemu_video_buffer_t xemu_nds_get_video_buffer(xemu_nds_handle_t handle);

/* Audio (44100Hz stereo target; may be empty in stub) */
xemu_audio_buffer_t xemu_nds_get_audio_buffer(xemu_nds_handle_t handle);

/* Input */
void xemu_nds_set_input(xemu_nds_handle_t handle, uint32_t buttons);
void xemu_nds_set_touch(xemu_nds_handle_t handle, xemu_nds_touch_state_t touch);

/* Save states */
size_t xemu_nds_get_save_state_size(xemu_nds_handle_t handle);
xemu_error_t xemu_nds_save_state(xemu_nds_handle_t handle, xemu_save_state_t* state);
xemu_error_t xemu_nds_load_state(xemu_nds_handle_t handle, const xemu_save_state_t* state);

/* DS-specific options */
xemu_error_t xemu_nds_set_screen_layout(xemu_nds_handle_t handle, xemu_nds_screen_layout_t layout);
xemu_nds_screen_layout_t xemu_nds_get_screen_layout(xemu_nds_handle_t handle);

#ifdef __cplusplus
}
#endif

#endif /* XEMU_CORES_H */
