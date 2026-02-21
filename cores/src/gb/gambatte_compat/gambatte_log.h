#ifndef _GAMBATTE_LOG_H
#define _GAMBATTE_LOG_H

#include <cstdio>
#include <cstdarg>

#ifdef __cplusplus
extern "C" {
#endif

enum retro_log_level {
    RETRO_LOG_DEBUG = 0,
    RETRO_LOG_INFO,
    RETRO_LOG_WARN,
    RETRO_LOG_ERROR
};

typedef void (*retro_log_printf_t)(enum retro_log_level level, const char *fmt, ...);

static inline void gambatte_log_set_cb(retro_log_printf_t) {}

static inline void gambatte_log(enum retro_log_level, const char *format, ...) {
    va_list args;
    va_start(args, format);
    vfprintf(stderr, format, args);
    va_end(args);
}

#ifdef __cplusplus
}
#endif

#endif
