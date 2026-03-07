#include "nds/nds_backend.h"
#include "nds/nds_libretro_abi.h"
#include "nds/nds_libretro_core_api.h"
#include "nds/nds_melonds_libretro_binding.h"
#include "nds/nds_touch_pointer_mapping.h"

#include <algorithm>
#include <cstdarg>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <map>
#include <string>
#include <sys/stat.h>
#include <sys/types.h>
#include <vector>

namespace xemu {
namespace nds {
namespace {

void frontendLogPrintf(int level, const char* fmt, ...) {
    (void)level;
    if (!fmt) {
        return;
    }
    va_list args;
    va_start(args, fmt);
    std::vfprintf(stderr, fmt, args);
    va_end(args);
}

static std::string extractDefaultCoreOptionValue(const char* definition) {
    if (!definition) {
        return std::string();
    }
    const char* semicolon = std::strchr(definition, ';');
    const char* valueStart = semicolon ? semicolon + 1 : definition;
    while (*valueStart == ' ') {
        ++valueStart;
    }
    const char* valueEnd = std::strchr(valueStart, '|');
    if (!valueEnd) {
        valueEnd = valueStart + std::strlen(valueStart);
    }
    while (valueEnd > valueStart && (*(valueEnd - 1) == ' ')) {
        --valueEnd;
    }
    return std::string(valueStart, valueEnd);
}

static std::string extractDefaultOptionValueV1(const retro_core_option_definition& definition) {
    if (definition.default_value && definition.default_value[0] != '\0') {
        return std::string(definition.default_value);
    }
    for (int i = 0; i < RETRO_NUM_CORE_OPTION_VALUES_MAX; ++i) {
        const retro_core_option_value& value = definition.values[i];
        if (!value.value) {
            break;
        }
        if (value.value[0] != '\0') {
            return std::string(value.value);
        }
    }
    return std::string();
}

static std::string extractDefaultOptionValueV2(const retro_core_option_v2_definition& definition) {
    if (definition.default_value && definition.default_value[0] != '\0') {
        return std::string(definition.default_value);
    }
    for (int i = 0; i < RETRO_NUM_CORE_OPTION_VALUES_MAX; ++i) {
        const retro_core_option_value& value = definition.values[i];
        if (!value.value) {
            break;
        }
        if (value.value[0] != '\0') {
            return std::string(value.value);
        }
    }
    return std::string();
}

class LibretroBackend final : public Backend {
public:
    LibretroBackend() {
        activeInstance_ = this;
        updateCompositedBufferForLayout(layout_);
        bindCoreCallbacks();
    }

    ~LibretroBackend() override {
        deinitializeCoreIfNeeded();
        if (activeInstance_ == this) {
            activeInstance_ = nullptr;
        }
    }

    xemu_error_t loadROM(const char* filename, const uint8_t* data, size_t size) override {
        if ((!data || size == 0) && !filename) {
            return XEMU_ERROR_INVALID_ARGUMENT;
        }

        lastLoadError_ = XEMU_OK;

        if (!initializeCoreIfNeeded()) {
            romLoaded_ = false;
            return XEMU_ERROR_UNSUPPORTED_FORMAT;
        }

        if (!api_.retro_load_game) {
            romLoaded_ = false;
            std::fprintf(stderr, "[xemu][nds] retro_load_game symbol not bound\n");
            return XEMU_ERROR_UNSUPPORTED_FORMAT;
        }

        retro_game_info game = {};
        game.path = filename;
        game.meta = nullptr;
        if (needFullpath_) {
            game.data = nullptr;
            game.size = 0;
        } else {
            game.data = data;
            game.size = size;
        }

        bool ok = api_.retro_load_game(&game);
        if (!ok && filename) {
            // Some cores are stricter than their reported flags; retry path-only.
            game.data = nullptr;
            game.size = 0;
            ok = api_.retro_load_game(&game);
        }
        romLoaded_ = ok;
        if (!ok) {
            std::fprintf(stderr,
                         "[xemu][nds] retro_load_game failed (path=%s, need_fullpath=%d, data=%s, size=%zu)\n",
                         filename ? filename : "<null>",
                         needFullpath_ ? 1 : 0,
                         (data && size > 0) ? "yes" : "no",
                         size);
        }
        return ok ? XEMU_OK : XEMU_ERROR_ROM_LOAD_FAILED;
    }

    xemu_error_t unloadROM() override {
        if (romLoaded_ && api_.retro_unload_game) {
            api_.retro_unload_game();
        }
        romLoaded_ = false;
        return XEMU_OK;
    }

    bool isROMLoaded() const override { return romLoaded_; }

    xemu_error_t runFrame() override {
        if (!coreInitialized_ || !api_.retro_run) {
            return XEMU_ERROR_NOT_INITIALIZED;
        }

        // Don't clear audio buffer - let it accumulate naturally and return whatever is available
        receivedVideoFrameThisRun_ = false;
        api_.retro_run();

        // In the real integration, callbacks will populate top/bottom raw frames
        // and this method will composite them into video_. For now, preserve a
        // visible placeholder if no core video callback has run.
        if (!receivedVideoFrameThisRun_) {
            drawPlaceholderComposite();
        }
        receivedVideoFrameThisRun_ = false;
        return romLoaded_ ? XEMU_OK : XEMU_ERROR_NOT_INITIALIZED;
    }

    xemu_error_t reset() override {
        buttons_ = 0;
        touch_ = {0, 0, 0};
        inputPollCount_ = 0;
        if (coreInitialized_ && api_.retro_reset) {
            api_.retro_reset();
        }
        return XEMU_OK;
    }

    xemu_video_buffer_t getVideoBuffer() override {
        return videoBuffer_;
    }

    xemu_audio_buffer_t getAudioBuffer() override {
        audioBuffer_.data = audio_.empty() ? nullptr : audio_.data();
        audioBuffer_.sample_count = static_cast<int>(audio_.size());

        // Return all available audio and clear buffer for next frame
        // This provides the most responsive audio with no delay buildup
        if (!audio_.empty()) {
            std::vector<int16_t> samplesToReturn;
            samplesToReturn.swap(audio_);  // Efficiently swap buffers
            audioBuffer_.data = samplesToReturn.data();
            audioBuffer_.sample_count = static_cast<int>(samplesToReturn.size());
        }

        return audioBuffer_;
    }

    void setInput(uint32_t buttons) override { buttons_ = buttons; }

    void setTouch(xemu_nds_touch_state_t touch) override { touch_ = touch; }

    size_t getSaveStateSize() const override {
        if (!coreInitialized_ || !api_.retro_serialize_size) {
            return 0;
        }
        return api_.retro_serialize_size();
    }

    xemu_error_t saveState(xemu_save_state_t* state) override {
        if (!state || !state->data || state->size == 0) {
            return XEMU_ERROR_INVALID_ARGUMENT;
        }
        if (!coreInitialized_ || !api_.retro_serialize || !api_.retro_serialize_size) {
            return XEMU_ERROR_SAVE_STATE_FAILED;
        }

        const size_t needed = api_.retro_serialize_size();
        if (needed == 0 || state->size < needed) {
            return XEMU_ERROR_SAVE_STATE_FAILED;
        }
        return api_.retro_serialize(state->data, state->size) ? XEMU_OK : XEMU_ERROR_SAVE_STATE_FAILED;
    }

    xemu_error_t loadState(const xemu_save_state_t* state) override {
        if (!state || !state->data || state->size == 0) {
            return XEMU_ERROR_INVALID_ARGUMENT;
        }
        if (!coreInitialized_ || !api_.retro_unserialize) {
            return XEMU_ERROR_LOAD_STATE_FAILED;
        }
        return api_.retro_unserialize(state->data, state->size) ? XEMU_OK : XEMU_ERROR_LOAD_STATE_FAILED;
    }

    xemu_error_t setScreenLayout(xemu_nds_screen_layout_t layout) override {
        updateCompositedBufferForLayout(layout);
        return XEMU_OK;
    }

    xemu_nds_screen_layout_t getScreenLayout() const override { return layout_; }

private:
    bool initializeCoreIfNeeded() {
        if (coreInitialized_) {
            return true;
        }
        if (!api_.retro_init) {
            return false;
        }

        bindCoreCallbacks();
        api_.retro_init();
        coreInitialized_ = true;

        if (api_.retro_get_system_av_info) {
            retro_system_av_info av = {};
            api_.retro_get_system_av_info(&av);
            sampleRate_ = (av.timing.sample_rate > 1.0) ? static_cast<int>(av.timing.sample_rate) : 44100;
            if (av.geometry.base_width > 0 && av.geometry.base_height > 0) {
                coreBaseWidth_ = static_cast<int>(av.geometry.base_width);
                coreBaseHeight_ = static_cast<int>(av.geometry.base_height);
            }
        }
        if (api_.retro_get_system_info) {
            retro_system_info info = {};
            api_.retro_get_system_info(&info);
            needFullpath_ = info.need_fullpath;
            if (info.valid_extensions) {
                validExtensions_ = info.valid_extensions;
            } else {
                validExtensions_.clear();
            }
            std::fprintf(stderr,
                         "[xemu][nds] libretro core info: name=%s version=%s need_fullpath=%d ext=%s\n",
                         info.library_name ? info.library_name : "<null>",
                         info.library_version ? info.library_version : "<null>",
                         needFullpath_ ? 1 : 0,
                         validExtensions_.empty() ? "<none>" : validExtensions_.c_str());
        }
        audioBuffer_.sample_rate = sampleRate_;
        return true;
    }

    void deinitializeCoreIfNeeded() {
        if (!coreInitialized_) {
            return;
        }
        if (romLoaded_ && api_.retro_unload_game) {
            api_.retro_unload_game();
            romLoaded_ = false;
        }
        if (api_.retro_deinit) {
            api_.retro_deinit();
        }
        coreInitialized_ = false;
    }

    void bindCoreCallbacks() {
        // Set callback trampolines only when the libretro core API is actually bound.
        if (api_.retro_set_environment) {
            api_.retro_set_environment(&LibretroBackend::environmentCallbackTrampoline);
        }
        if (api_.retro_set_video_refresh) {
            api_.retro_set_video_refresh(&LibretroBackend::videoRefreshTrampoline);
        }
        if (api_.retro_set_audio_sample) {
            api_.retro_set_audio_sample(&LibretroBackend::audioSampleTrampoline);
        }
        if (api_.retro_set_audio_sample_batch) {
            api_.retro_set_audio_sample_batch(&LibretroBackend::audioSampleBatchTrampoline);
        }
        if (api_.retro_set_input_poll) {
            api_.retro_set_input_poll(&LibretroBackend::inputPollTrampoline);
        }
        if (api_.retro_set_input_state) {
            api_.retro_set_input_state(&LibretroBackend::inputStateTrampoline);
        }
    }

    static bool environmentCallbackTrampoline(unsigned cmd, void* data) {
        if (!activeInstance_) {
            return false;
        }
        return activeInstance_->onEnvironment(cmd, data);
    }

    static void videoRefreshTrampoline(const void* data, unsigned width, unsigned height, size_t pitch) {
        if (!activeInstance_) {
            return;
        }
        activeInstance_->onVideoRefresh(data, width, height, pitch);
    }

    static void audioSampleTrampoline(int16_t left, int16_t right) {
        if (!activeInstance_) {
            return;
        }
        activeInstance_->audio_.push_back(left);
        activeInstance_->audio_.push_back(right);
    }

    static size_t audioSampleBatchTrampoline(const int16_t* data, size_t frames) {
        if (!activeInstance_) {
            return 0;
        }
        return activeInstance_->onAudioSampleBatch(data, frames);
    }

    static void inputPollTrampoline() {
        if (!activeInstance_) {
            return;
        }
        activeInstance_->onInputPoll();
    }

    static int16_t inputStateTrampoline(unsigned port, unsigned device, unsigned index, unsigned id) {
        if (!activeInstance_) {
            return 0;
        }
        return activeInstance_->onInputState(port, device, index, id);
    }

    bool onEnvironment(unsigned cmd, void* data) {
        switch (cmd) {
        case RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY:
            if (!data) {
                return false;
            }
            ensureFrontendDirectories();
            *static_cast<const char**>(data) = systemDir_.c_str();
            return !systemDir_.empty();
        case RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY:
            if (!data) {
                return false;
            }
            ensureFrontendDirectories();
            *static_cast<const char**>(data) = saveDir_.c_str();
            return !saveDir_.empty();
        case RETRO_ENVIRONMENT_GET_CORE_OPTIONS_VERSION:
            if (!data) {
                return false;
            }
            *static_cast<unsigned*>(data) = 2;
            return true;
        case RETRO_ENVIRONMENT_SET_CORE_OPTIONS_V2:
            return setCoreOptionDefinitionsV2(data);
        case RETRO_ENVIRONMENT_SET_CORE_OPTIONS:
            return setCoreOptionDefinitionsV1(data);
        case RETRO_ENVIRONMENT_SET_CORE_OPTIONS_DISPLAY:
        case RETRO_ENVIRONMENT_SET_CORE_OPTIONS_UPDATE_DISPLAY_CALLBACK:
            return true;
        case RETRO_ENVIRONMENT_SET_VARIABLES:
            return setCoreOptionVariables(data);
        case RETRO_ENVIRONMENT_GET_VARIABLE:
            return getCoreOptionVariable(data);
        case RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE:
            if (!data) {
                return false;
            }
            *static_cast<bool*>(data) = false;
            return true;
        case RETRO_ENVIRONMENT_SET_PIXEL_FORMAT:
            if (!data) {
                return false;
            }
            pixelFormat_ = *static_cast<const retro_pixel_format*>(data);
            return true;
        case RETRO_ENVIRONMENT_SET_SYSTEM_AV_INFO:
            if (!data) {
                return false;
            }
            applySystemAVInfo(*static_cast<const retro_system_av_info*>(data));
            return true;
        case RETRO_ENVIRONMENT_SET_GEOMETRY:
            if (!data) {
                return false;
            }
            applyGeometry(*static_cast<const retro_game_geometry*>(data));
            return true;
        case RETRO_ENVIRONMENT_GET_LOG_INTERFACE:
            if (!data) {
                return false;
            }
            static_cast<retro_log_callback*>(data)->log = &frontendLogPrintf;
            return true;
        case RETRO_ENVIRONMENT_GET_MESSAGE_INTERFACE_VERSION:
            if (!data) {
                return false;
            }
            *static_cast<unsigned*>(data) = 1;
            return true;
        case RETRO_ENVIRONMENT_SET_MESSAGE:
        case RETRO_ENVIRONMENT_SET_MESSAGE_EXT:
            return true;
        case RETRO_ENVIRONMENT_GET_INPUT_BITMASKS:
            // Return false to keep the core on the simpler per-button input path.
            return false;
        case RETRO_ENVIRONMENT_GET_VFS_INTERFACE:
            return false;
        case RETRO_ENVIRONMENT_SET_HW_RENDER:
            return false;
        case RETRO_ENVIRONMENT_SET_SUPPORT_NO_GAME:
            return true;
        case RETRO_ENVIRONMENT_SET_SUPPORT_ACHIEVEMENTS:
            return true;
        default:
            // Unknown commands are expected until we integrate the real core.
            return false;
        }
    }

    void onVideoRefresh(const void* data, unsigned width, unsigned height, size_t pitch) {
        receivedVideoFrameThisRun_ = true;
        if (!data || width == 0 || height == 0 || pitch == 0) {
            drawPlaceholderComposite();
            return;
        }

        // Phase 2 seam: store the most recent libretro output frame in a scratch
        // buffer, then map/composite into the public NDS composited framebuffer.
        coreFrameWidth_ = static_cast<int>(width);
        coreFrameHeight_ = static_cast<int>(height);
        coreFramePitch_ = static_cast<int>(pitch);
        if (coreFrameWidth_ != lastLoggedCoreFrameWidth_ || coreFrameHeight_ != lastLoggedCoreFrameHeight_) {
            std::fprintf(stderr,
                         "[xemu][nds] video frame from core: %dx%d pitch=%d layout=%d pixel_fmt=%d\n",
                         coreFrameWidth_,
                         coreFrameHeight_,
                         coreFramePitch_,
                         static_cast<int>(layout_),
                         static_cast<int>(pixelFormat_));
            lastLoggedCoreFrameWidth_ = coreFrameWidth_;
            lastLoggedCoreFrameHeight_ = coreFrameHeight_;
        }
        const size_t byteCount = pitch * static_cast<size_t>(height);
        coreFrameScratch_.assign(static_cast<const uint8_t*>(data),
                                 static_cast<const uint8_t*>(data) + byteCount);

        blitCoreFrameIntoCompositedBuffer();
    }

    size_t onAudioSampleBatch(const int16_t* data, size_t frames) {
        if (!data || frames == 0) {
            return 0;
        }
        const size_t sampleCount = frames * 2; // stereo interleaved
        audio_.insert(audio_.end(), data, data + sampleCount);
        return frames;
    }

    void onInputPoll() { ++inputPollCount_; }

    xemu::nds::PointerFrameCoordinates mapTouchToLibretroPointerCoords() const {
        const int frameW = coreFrameWidth_ > 0 ? coreFrameWidth_ : (coreBaseWidth_ > 0 ? coreBaseWidth_ : 256);
        const int frameH = coreFrameHeight_ > 0 ? coreFrameHeight_ : (coreBaseHeight_ > 0 ? coreBaseHeight_ : 384);

        return xemu::nds::mapTouchToPointerFrame(
            static_cast<int>(touch_.x),
            static_cast<int>(touch_.y),
            frameW,
            frameH
        );
    }

    int16_t onInputState(unsigned port, unsigned device, unsigned index, unsigned id) const {
        (void)index;
        if (port != 0) {
            return 0;
        }

        if (device == RETRO_DEVICE_JOYPAD) {
            if (id == RETRO_DEVICE_ID_JOYPAD_MASK) {
                return static_cast<int16_t>(buildLibretroJoypadMask() & 0xFFFF);
            }
            return mapJoypadInput(id) ? 1 : 0;
        }

        if (device == RETRO_DEVICE_POINTER) {
            const xemu::nds::PointerFrameCoordinates pointer = mapTouchToLibretroPointerCoords();
            switch (id) {
            case RETRO_DEVICE_ID_POINTER_X:
                return static_cast<int16_t>(mapPointerAxisToLibretro(pointer.x, pointer.maxX));
            case RETRO_DEVICE_ID_POINTER_Y:
                return static_cast<int16_t>(mapPointerAxisToLibretro(pointer.y, pointer.maxY));
            case RETRO_DEVICE_ID_POINTER_PRESSED:
                return touch_.is_pressed ? 1 : 0;
            default:
                return 0;
            }
        }

        return 0;
    }

    bool mapJoypadInput(unsigned id) const {
        switch (id) {
        case RETRO_DEVICE_ID_JOYPAD_A:
            return (buttons_ & static_cast<uint32_t>(XEMU_BUTTON_A)) != 0;
        case RETRO_DEVICE_ID_JOYPAD_B:
            return (buttons_ & static_cast<uint32_t>(XEMU_BUTTON_B)) != 0;
        case RETRO_DEVICE_ID_JOYPAD_SELECT:
            return (buttons_ & static_cast<uint32_t>(XEMU_BUTTON_SELECT)) != 0;
        case RETRO_DEVICE_ID_JOYPAD_START:
            return (buttons_ & static_cast<uint32_t>(XEMU_BUTTON_START)) != 0;
        case RETRO_DEVICE_ID_JOYPAD_UP:
            return (buttons_ & static_cast<uint32_t>(XEMU_BUTTON_UP)) != 0;
        case RETRO_DEVICE_ID_JOYPAD_DOWN:
            return (buttons_ & static_cast<uint32_t>(XEMU_BUTTON_DOWN)) != 0;
        case RETRO_DEVICE_ID_JOYPAD_LEFT:
            return (buttons_ & static_cast<uint32_t>(XEMU_BUTTON_LEFT)) != 0;
        case RETRO_DEVICE_ID_JOYPAD_RIGHT:
            return (buttons_ & static_cast<uint32_t>(XEMU_BUTTON_RIGHT)) != 0;
        case RETRO_DEVICE_ID_JOYPAD_L:
            return (buttons_ & static_cast<uint32_t>(XEMU_BUTTON_L)) != 0;
        case RETRO_DEVICE_ID_JOYPAD_R:
            return (buttons_ & static_cast<uint32_t>(XEMU_BUTTON_R)) != 0;
        case RETRO_DEVICE_ID_JOYPAD_X:
            return (buttons_ & static_cast<uint32_t>(XEMU_BUTTON_X)) != 0;
        case RETRO_DEVICE_ID_JOYPAD_Y:
            return (buttons_ & static_cast<uint32_t>(XEMU_BUTTON_Y)) != 0;
        default:
            return false;
        }
    }

    uint32_t buildLibretroJoypadMask() const {
        uint32_t mask = 0;
        const unsigned ids[] = {
            RETRO_DEVICE_ID_JOYPAD_B, RETRO_DEVICE_ID_JOYPAD_Y, RETRO_DEVICE_ID_JOYPAD_SELECT,
            RETRO_DEVICE_ID_JOYPAD_START, RETRO_DEVICE_ID_JOYPAD_UP, RETRO_DEVICE_ID_JOYPAD_DOWN,
            RETRO_DEVICE_ID_JOYPAD_LEFT, RETRO_DEVICE_ID_JOYPAD_RIGHT, RETRO_DEVICE_ID_JOYPAD_A,
            RETRO_DEVICE_ID_JOYPAD_X, RETRO_DEVICE_ID_JOYPAD_L, RETRO_DEVICE_ID_JOYPAD_R
        };
        for (unsigned id : ids) {
            if (mapJoypadInput(id)) {
                mask |= (1u << id);
            }
        }
        return mask;
    }

    static int mapPointerAxisToLibretro(int32_t value, int32_t maxValue) {
        const int clamped = std::max(0, std::min(static_cast<int>(maxValue), static_cast<int>(value)));
        const int range = std::max(1, static_cast<int>(maxValue));
        return (clamped * 0xFFFF / range) - 0x8000;
    }

    void blitCoreFrameIntoCompositedBuffer() {
        if (video_.empty()) {
            return;
        }
        if (coreFrameScratch_.empty() || coreFrameWidth_ <= 0 || coreFrameHeight_ <= 0 || coreFramePitch_ <= 0) {
            drawPlaceholderComposite();
            return;
        }

        drawPlaceholderComposite();
        const int srcW = coreFrameWidth_;
        const int srcH = coreFrameHeight_;

        auto blitRowSegment = [&](int srcY, int srcX, int dstY, int dstX, int copyWidth) {
            if (copyWidth <= 0) {
                return;
            }
            if (srcY < 0 || srcY >= srcH || dstY < 0 || dstY >= height_) {
                return;
            }

            const int bytesPerPixel = (pixelFormat_ == RETRO_PIXEL_FORMAT_XRGB8888) ? 4 : 2;
            const uint8_t* srcRow = coreFrameScratch_.data() + (static_cast<size_t>(srcY) * coreFramePitch_);
            srcRow += static_cast<size_t>(srcX) * bytesPerPixel;

            std::vector<uint8_t> converted(static_cast<size_t>(copyWidth) * 4u);
            convertLibretroRowToRGBA8888(srcRow, converted.data(), copyWidth);

            uint8_t* dstRow = video_.data() + (static_cast<size_t>(dstY) * pitch_);
            dstRow += static_cast<size_t>(dstX) * 4u;
            std::memcpy(dstRow, converted.data(), static_cast<size_t>(copyWidth) * 4u);
        };

        // Common melonds/libretro output: stacked 256x384 (top over bottom).
        if (srcW == 256 && srcH == 384) {
            if (layout_ == XEMU_NDS_SCREEN_LAYOUT_SIDE_BY_SIDE && width_ >= 512 && height_ >= 192) {
                for (int y = 0; y < 192; ++y) {
                    blitRowSegment(y, 0, y, 0, 256);       // top screen -> left half
                    blitRowSegment(y + 192, 0, y, 256, 256); // bottom screen -> right half
                }
                videoBuffer_.data = video_.data();
                return;
            }
            if (layout_ == XEMU_NDS_SCREEN_LAYOUT_STACKED && width_ >= 256 && height_ >= 384) {
                for (int y = 0; y < 384; ++y) {
                    blitRowSegment(y, 0, y, 0, 256);
                }
                videoBuffer_.data = video_.data();
                return;
            }
            if (layout_ == XEMU_NDS_SCREEN_LAYOUT_TOP_ONLY && width_ >= 256 && height_ >= 192) {
                for (int y = 0; y < 192; ++y) {
                    blitRowSegment(y, 0, y, 0, 256);
                }
                videoBuffer_.data = video_.data();
                return;
            }
            if (layout_ == XEMU_NDS_SCREEN_LAYOUT_BOTTOM_ONLY && width_ >= 256 && height_ >= 192) {
                for (int y = 0; y < 192; ++y) {
                    blitRowSegment(y + 192, 0, y, 0, 256);
                }
                videoBuffer_.data = video_.data();
                return;
            }
        }

        // If the core already outputs side-by-side 512x192, remap as needed.
        if (srcW == 512 && srcH == 192) {
            if (layout_ == XEMU_NDS_SCREEN_LAYOUT_SIDE_BY_SIDE && width_ >= 512 && height_ >= 192) {
                for (int y = 0; y < 192; ++y) {
                    blitRowSegment(y, 0, y, 0, 512);
                }
                videoBuffer_.data = video_.data();
                return;
            }
            if (layout_ == XEMU_NDS_SCREEN_LAYOUT_STACKED && width_ >= 256 && height_ >= 384) {
                for (int y = 0; y < 192; ++y) {
                    blitRowSegment(y, 0, y, 0, 256);      // left half -> top
                    blitRowSegment(y, 256, y + 192, 0, 256); // right half -> bottom
                }
                videoBuffer_.data = video_.data();
                return;
            }
            if (layout_ == XEMU_NDS_SCREEN_LAYOUT_TOP_ONLY && width_ >= 256 && height_ >= 192) {
                for (int y = 0; y < 192; ++y) {
                    blitRowSegment(y, 0, y, 0, 256);
                }
                videoBuffer_.data = video_.data();
                return;
            }
            if (layout_ == XEMU_NDS_SCREEN_LAYOUT_BOTTOM_ONLY && width_ >= 256 && height_ >= 192) {
                for (int y = 0; y < 192; ++y) {
                    blitRowSegment(y, 256, y, 0, 256);
                }
                videoBuffer_.data = video_.data();
                return;
            }
        }

        if (srcW != lastFallbackLoggedCoreFrameWidth_ || srcH != lastFallbackLoggedCoreFrameHeight_) {
            std::fprintf(stderr,
                         "[xemu][nds] compositor fallback for unhandled core frame shape %dx%d (layout=%d)\n",
                         srcW,
                         srcH,
                         static_cast<int>(layout_));
            lastFallbackLoggedCoreFrameWidth_ = srcW;
            lastFallbackLoggedCoreFrameHeight_ = srcH;
        }

        // Fallback: top-left blit for unknown core output shapes.
        const int copyWidth = std::min(width_, srcW);
        const int copyHeight = std::min(height_, srcH);
        for (int y = 0; y < copyHeight; ++y) {
            blitRowSegment(y, 0, y, 0, copyWidth);
        }
        videoBuffer_.data = video_.data();
    }

    void convertLibretroRowToRGBA8888(const uint8_t* srcRow, uint8_t* dstRow, int pixelCount) const {
        if (!srcRow || !dstRow || pixelCount <= 0) {
            return;
        }

        switch (pixelFormat_) {
        case RETRO_PIXEL_FORMAT_XRGB8888:
            // libretro XRGB8888 stores pixels as 0x00RRGGBB. On little-endian
            // platforms bytes arrive as B, G, R, X and must be reordered.
            for (int x = 0; x < pixelCount; ++x) {
                const uint8_t* s = srcRow + (x * 4);
                uint8_t* d = dstRow + (x * 4);
                d[0] = s[2];
                d[1] = s[1];
                d[2] = s[0];
                d[3] = 255;
            }
            break;
        case RETRO_PIXEL_FORMAT_RGB565:
            for (int x = 0; x < pixelCount; ++x) {
                const uint16_t px = static_cast<uint16_t>(srcRow[x * 2]) |
                                    (static_cast<uint16_t>(srcRow[x * 2 + 1]) << 8);
                uint8_t* d = dstRow + (x * 4);
                const uint8_t r5 = static_cast<uint8_t>((px >> 11) & 0x1F);
                const uint8_t g6 = static_cast<uint8_t>((px >> 5) & 0x3F);
                const uint8_t b5 = static_cast<uint8_t>(px & 0x1F);
                d[0] = static_cast<uint8_t>((r5 << 3) | (r5 >> 2));
                d[1] = static_cast<uint8_t>((g6 << 2) | (g6 >> 4));
                d[2] = static_cast<uint8_t>((b5 << 3) | (b5 >> 2));
                d[3] = 255;
            }
            break;
        case RETRO_PIXEL_FORMAT_0RGB1555:
            for (int x = 0; x < pixelCount; ++x) {
                const uint16_t px = static_cast<uint16_t>(srcRow[x * 2]) |
                                    (static_cast<uint16_t>(srcRow[x * 2 + 1]) << 8);
                uint8_t* d = dstRow + (x * 4);
                const uint8_t r5 = static_cast<uint8_t>((px >> 10) & 0x1F);
                const uint8_t g5 = static_cast<uint8_t>((px >> 5) & 0x1F);
                const uint8_t b5 = static_cast<uint8_t>(px & 0x1F);
                d[0] = static_cast<uint8_t>((r5 << 3) | (r5 >> 2));
                d[1] = static_cast<uint8_t>((g5 << 3) | (g5 >> 2));
                d[2] = static_cast<uint8_t>((b5 << 3) | (b5 >> 2));
                d[3] = 255;
            }
            break;
        default:
            break;
        }
    }

    void drawPlaceholderComposite() {
        for (int y = 0; y < height_; ++y) {
            uint8_t* row = video_.data() + (static_cast<size_t>(y) * pitch_);
            for (int x = 0; x < width_; ++x) {
                const size_t i = static_cast<size_t>(x * 4);
                row[i + 0] = static_cast<uint8_t>(24 + (x * 30 / std::max(1, width_)));
                row[i + 1] = static_cast<uint8_t>(10 + (y * 20 / std::max(1, height_)));
                row[i + 2] = static_cast<uint8_t>(42 + ((x + y) * 35 / std::max(1, width_ + height_)));
                row[i + 3] = 255;
            }
        }

        if (layout_ == XEMU_NDS_SCREEN_LAYOUT_STACKED && height_ > 192) {
            uint8_t* sep = video_.data() + (static_cast<size_t>(192) * pitch_);
            for (int x = 0; x < width_; ++x) {
                const size_t i = static_cast<size_t>(x * 4);
                sep[i + 0] = 100;
                sep[i + 1] = 70;
                sep[i + 2] = 170;
                sep[i + 3] = 255;
            }
        }
    }

    void updateCompositedBufferForLayout(xemu_nds_screen_layout_t layout) {
        layout_ = layout;
        switch (layout_) {
        case XEMU_NDS_SCREEN_LAYOUT_STACKED:
            width_ = 256;
            height_ = 384;
            break;
        case XEMU_NDS_SCREEN_LAYOUT_SIDE_BY_SIDE:
            width_ = 512;
            height_ = 192;
            break;
        case XEMU_NDS_SCREEN_LAYOUT_TOP_ONLY:
        case XEMU_NDS_SCREEN_LAYOUT_BOTTOM_ONLY:
            width_ = 256;
            height_ = 192;
            break;
        default:
            layout_ = XEMU_NDS_SCREEN_LAYOUT_STACKED;
            width_ = 256;
            height_ = 384;
            break;
        }

        pitch_ = width_ * 4;
        video_.assign(static_cast<size_t>(pitch_ * height_), 0);
        videoBuffer_.data = video_.empty() ? nullptr : video_.data();
        videoBuffer_.width = width_;
        videoBuffer_.height = height_;
        videoBuffer_.pitch = pitch_;
        drawPlaceholderComposite();
    }

    void applySystemAVInfo(const retro_system_av_info& av) {
        if (av.timing.sample_rate > 1.0) {
            sampleRate_ = static_cast<int>(av.timing.sample_rate);
            audioBuffer_.sample_rate = sampleRate_;
        }
        retro_game_geometry geometry = {
            av.geometry.base_width,
            av.geometry.base_height,
            av.geometry.max_width,
            av.geometry.max_height,
            av.geometry.aspect_ratio,
        };
        applyGeometry(geometry);
    }

    void applyGeometry(const retro_game_geometry& geometry) {
        if (geometry.base_width > 0) {
            coreBaseWidth_ = static_cast<int>(geometry.base_width);
        }
        if (geometry.base_height > 0) {
            coreBaseHeight_ = static_cast<int>(geometry.base_height);
        }
    }

    bool setCoreOptionVariables(void* data) {
        if (!data) {
            return false;
        }
        const retro_variable* vars = static_cast<const retro_variable*>(data);
        if (!vars) {
            return false;
        }
        coreOptions_.clear();
        for (const retro_variable* v = vars; v && v->key; ++v) {
            coreOptions_[v->key] = extractDefaultCoreOptionValue(v->value);
        }
        applyCoreOptionOverrides();
        coreOptionsDirty_ = false;
        return true;
    }

    bool setCoreOptionDefinitionsV1(void* data) {
        if (!data) {
            return false;
        }
        const retro_core_option_definition* definitions =
            static_cast<const retro_core_option_definition*>(data);
        if (!definitions) {
            return false;
        }
        coreOptions_.clear();
        for (const retro_core_option_definition* definition = definitions;
             definition && definition->key;
             ++definition) {
            coreOptions_[definition->key] = extractDefaultOptionValueV1(*definition);
        }
        applyCoreOptionOverrides();
        coreOptionsDirty_ = false;
        return true;
    }

    bool setCoreOptionDefinitionsV2(void* data) {
        if (!data) {
            return false;
        }
        const retro_core_options_v2* options = static_cast<const retro_core_options_v2*>(data);
        if (!options || !options->definitions) {
            return false;
        }
        coreOptions_.clear();
        for (const retro_core_option_v2_definition* definition = options->definitions;
             definition && definition->key;
             ++definition) {
            coreOptions_[definition->key] = extractDefaultOptionValueV2(*definition);
        }
        applyCoreOptionOverrides();
        // Frontend default: avoid requiring external DS BIOS/firmware dumps.
        // melonDS DS publishes "Native" first for this option, but "Built-In"
        // yields a working out-of-the-box ROM load path in app environments.
        coreOptionsDirty_ = false;
        return true;
    }

    void applyCoreOptionOverrides() {
        coreOptions_["melonds_sysfile_mode"] = "builtin";
    }

    bool getCoreOptionVariable(void* data) {
        if (!data) {
            return false;
        }
        retro_variable* var = static_cast<retro_variable*>(data);
        if (!var || !var->key) {
            return false;
        }
        auto it = coreOptions_.find(var->key);
        if (it == coreOptions_.end()) {
            var->value = nullptr;
            return false;
        }
        var->value = it->second.c_str();
        return true;
    }

    void ensureFrontendDirectories() {
        if (!systemDir_.empty() && !saveDir_.empty()) {
            return;
        }
        const char* tmp = std::getenv("TMPDIR");
        std::string root = (tmp && *tmp) ? std::string(tmp) : std::string("/tmp");
        if (!root.empty() && root[root.size() - 1] == '/') {
            root.pop_back();
        }
        frontendRootDir_ = root + "/xemu-nds-libretro";
        systemDir_ = frontendRootDir_ + "/system";
        saveDir_ = frontendRootDir_ + "/save";

        mkdir(frontendRootDir_.c_str(), 0755);
        mkdir(systemDir_.c_str(), 0755);
        mkdir(saveDir_.c_str(), 0755);
    }

    static LibretroBackend* activeInstance_;

    LibretroCoreAPI api_ = createMelonDSLibretroCoreAPI();
    bool coreInitialized_ = false;
    bool romLoaded_ = false;
    bool needFullpath_ = false;
    uint32_t buttons_ = 0;
    xemu_nds_touch_state_t touch_ = {0, 0, 0};
    xemu_nds_screen_layout_t layout_ = XEMU_NDS_SCREEN_LAYOUT_STACKED;
    retro_pixel_format pixelFormat_ = RETRO_PIXEL_FORMAT_XRGB8888;
    xemu_error_t lastLoadError_ = XEMU_OK;
    bool receivedVideoFrameThisRun_ = false;
    uint64_t inputPollCount_ = 0;
    bool coreOptionsDirty_ = false;

    int width_ = 256;
    int height_ = 384;
    int pitch_ = 256 * 4;
    int sampleRate_ = 44100;
    int coreBaseWidth_ = 256;
    int coreBaseHeight_ = 384;
    int coreFrameWidth_ = 0;
    int coreFrameHeight_ = 0;
    int coreFramePitch_ = 0;
    int lastLoggedCoreFrameWidth_ = 0;
    int lastLoggedCoreFrameHeight_ = 0;
    int lastFallbackLoggedCoreFrameWidth_ = 0;
    int lastFallbackLoggedCoreFrameHeight_ = 0;
    std::vector<uint8_t> video_;
    std::vector<uint8_t> coreFrameScratch_;
    std::vector<int16_t> audio_;
    std::map<std::string, std::string> coreOptions_;
    std::string frontendRootDir_;
    std::string systemDir_;
    std::string saveDir_;
    std::string validExtensions_;
    xemu_video_buffer_t videoBuffer_ = {nullptr, 0, 0, 0};
    xemu_audio_buffer_t audioBuffer_ = {nullptr, 0, 44100};
};

LibretroBackend* LibretroBackend::activeInstance_ = nullptr;

} // namespace

std::unique_ptr<Backend> createLibretroBackend() {
#if defined(XEMU_ENABLE_NDS_LIBRETRO_BACKEND)
    std::unique_ptr<Backend> backend(new LibretroBackend());
    return backend;
#else
    return nullptr;
#endif
}

} // namespace nds
} // namespace xemu
