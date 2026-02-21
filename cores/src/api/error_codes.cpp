#include "xemu_cores/xemu_cores.h"
#include <cstring>

const char* xemu_error_string(xemu_error_t error) {
    switch (error) {
        case XEMU_OK: return "Success";
        case XEMU_ERROR_INVALID_ARGUMENT: return "Invalid argument";
        case XEMU_ERROR_OUT_OF_MEMORY: return "Out of memory";
        case XEMU_ERROR_ROM_LOAD_FAILED: return "Failed to load ROM";
        case XEMU_ERROR_UNSUPPORTED_FORMAT: return "Unsupported ROM format";
        case XEMU_ERROR_NOT_INITIALIZED: return "Core not initialized";
        case XEMU_ERROR_ALREADY_RUNNING: return "Core already running";
        case XEMU_ERROR_SAVE_STATE_FAILED: return "Failed to save state";
        case XEMU_ERROR_LOAD_STATE_FAILED: return "Failed to load state";
        case XEMU_ERROR_BUFFER_TOO_SMALL: return "Buffer too small";
        case XEMU_ERROR_UNKNOWN: return "Unknown error";
        default: return "Invalid error code";
    }
}

extern "C" {

const char* xemu_cores_get_version_string(void) {
    return XEMU_CORES_VERSION_STRING;
}

void xemu_cores_get_version(int* major, int* minor, int* patch) {
    if (major) *major = XEMU_CORES_VERSION_MAJOR;
    if (minor) *minor = XEMU_CORES_VERSION_MINOR;
    if (patch) *patch = XEMU_CORES_VERSION_PATCH;
}

int xemu_cores_get_api_version(void) {
    return XEMU_CORES_API_VERSION;
}

} // extern "C"
