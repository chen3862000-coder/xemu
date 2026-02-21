#ifndef XEMU_CORES_VERSION_H
#define XEMU_CORES_VERSION_H

#ifdef __cplusplus
extern "C" {
#endif

/* Library version information */
#define XEMU_CORES_VERSION_MAJOR 0
#define XEMU_CORES_VERSION_MINOR 1
#define XEMU_CORES_VERSION_PATCH 0
#define XEMU_CORES_VERSION_STRING "0.1.0"

/* API version - increment when C API changes */
#define XEMU_CORES_API_VERSION 1

/* Get version string */
const char* xemu_cores_get_version_string(void);

/* Get version numbers */
void xemu_cores_get_version(int* major, int* minor, int* patch);

/* Get API version */
int xemu_cores_get_api_version(void);

#ifdef __cplusplus
}
#endif

#endif /* XEMU_CORES_VERSION_H */
