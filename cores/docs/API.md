# Xemu Cores Library - API Documentation

## Overview

The Xemu Cores library provides a C API for integrating Game Boy (GB), Game Boy Color (GBC), and Game Boy Advance (GBA) emulation into applications.

## Error Handling

All functions return `xemu_error_t` indicating success or failure:

- `XEMU_OK` (0) - Success
- `XEMU_ERROR_INVALID_ARGUMENT` - Invalid parameter
- `XEMU_ERROR_OUT_OF_MEMORY` - Memory allocation failed
- `XEMU_ERROR_ROM_LOAD_FAILED` - ROM loading failed
- `XEMU_ERROR_UNSUPPORTED_FORMAT` - ROM format not supported
- `XEMU_ERROR_NOT_INITIALIZED` - Core not initialized
- `XEMU_ERROR_ALREADY_RUNNING` - Core already running
- `XEMU_ERROR_SAVE_STATE_FAILED` - Save state failed
- `XEMU_ERROR_LOAD_STATE_FAILED` - Load state failed
- `XEMU_ERROR_BUFFER_TOO_SMALL` - Buffer too small
- `XEMU_ERROR_UNKNOWN` - Unknown error

Use `xemu_error_string()` to get human-readable error messages.

## Game Boy / Game Boy Color API

### Core Lifecycle

```c
// Create core instance
xemu_gb_handle_t gb = xemu_gb_create();
if (!gb) {
    // Handle error
}

// Destroy when done
xemu_gb_destroy(gb);
```

### ROM Loading

```c
// Load ROM from memory
xemu_error_t err = xemu_gb_load_rom(gb, "game.gb", rom_data, rom_size);
if (err != XEMU_OK) {
    printf("Error: %s\n", xemu_error_string(err));
}

// Check if ROM is loaded
if (xemu_gb_is_rom_loaded(gb)) {
    // ROM is ready
}

// Unload ROM
xemu_gb_unload_rom(gb);
```

### Execution

```c
// Run single frame (~16.74ms at 59.73 FPS)
xemu_error_t err = xemu_gb_run_frame(gb);

// Reset to initial state
xemu_gb_reset(gb);
```

### Video Output

```c
// Get video buffer (160x144, RGBA8888 format)
xemu_video_buffer_t video = xemu_gb_get_video_buffer(gb);

// Access pixel at (x, y)
int x = 10, y = 20;
uint8_t* pixel = video.data + (y * video.pitch) + (x * 4);
uint8_t r = pixel[0];
uint8_t g = pixel[1];
uint8_t b = pixel[2];
uint8_t a = pixel[3];
```

### Audio Output

```c
// Get audio buffer (44100Hz stereo, interleaved)
xemu_audio_buffer_t audio = xemu_gb_get_audio_buffer(gb);

// Process audio samples
for (int i = 0; i < audio.sample_count; i += 2) {
    int16_t left = audio.data[i];
    int16_t right = audio.data[i + 1];
    // Output to audio device...
}
```

### Input

```c
// Set button states (bitmask)
uint32_t buttons = XEMU_BUTTON_A | XEMU_BUTTON_RIGHT;
xemu_gb_set_input(gb, buttons);

// Clear all buttons
xemu_gb_set_input(gb, 0);
```

**Button Constants:**
- `XEMU_BUTTON_A`
- `XEMU_BUTTON_B`
- `XEMU_BUTTON_SELECT`
- `XEMU_BUTTON_START`
- `XEMU_BUTTON_RIGHT`
- `XEMU_BUTTON_LEFT`
- `XEMU_BUTTON_UP`
- `XEMU_BUTTON_DOWN`

### Save States

```c
// Get required buffer size
size_t state_size = xemu_gb_get_save_state_size(gb);

// Allocate buffer
uint8_t* state_buffer = malloc(state_size);
xemu_save_state_t state = {
    .data = state_buffer,
    .size = state_size
};

// Save state
xemu_error_t err = xemu_gb_save_state(gb, &state);

// Later: Load state
err = xemu_gb_load_state(gb, &state);

free(state_buffer);
```

### System Type Detection

```c
// Check if running in CGB (Color Game Boy) mode
if (xemu_gb_is_cgb_mode(gb)) {
    // GBC mode with full color palette
} else {
    // Classic GB mode
}
```

## Game Boy Advance API

The GBA API is nearly identical to the GB API, with these differences:

### Video
- Resolution: 240x160 (vs 160x144 for GB)
- Same RGBA8888 format

### Input
Additional buttons:
- `XEMU_BUTTON_L` - L shoulder button
- `XEMU_BUTTON_R` - R shoulder button

### Save States
- Larger buffer size (~512KB vs ~128KB for GB)

### Example

```c
xemu_gba_handle_t gba = xemu_gba_create();
xemu_gba_load_rom(gba, "game.gba", rom_data, rom_size);

// Run frame
xemu_gba_run_frame(gba);

// Get 240x160 video buffer
xemu_video_buffer_t video = xemu_gba_get_video_buffer(gba);

// Input with L/R buttons
uint32_t buttons = XEMU_BUTTON_A | XEMU_BUTTON_L;
xemu_gba_set_input(gba, buttons);

xemu_gba_destroy(gba);
```

## Version Information

```c
// Get version string (e.g., "0.1.0")
const char* version = xemu_cores_get_version_string();

// Get version numbers
int major, minor, patch;
xemu_cores_get_version(&major, &minor, &patch);

// Get API version (for compatibility checks)
int api_version = xemu_cores_get_api_version();
```

## Thread Safety

- **Not thread-safe**: Core instances should not be accessed from multiple threads simultaneously
- **Thread-safe**: Separate core instances can run on different threads
- **Best practice**: Run each core on its own thread, or use proper synchronization

## Memory Management

- All allocations are internal to the library
- Use the corresponding `destroy` function to free resources
- No memory leaks when used correctly

## Swift Integration

See [SWIFT_INTEGRATION.md](SWIFT_INTEGRATION.md) for Swift-specific documentation.
