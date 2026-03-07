#include "mgba_wrapper.h"
#include "mgba_core_bridge.h"

#include <algorithm>
#include <array>
#include <cctype>
#include <cstdlib>
#include <cstdio>
#include <cstring>
#include <limits>

#include <mgba/flags.h>
#include <mgba/gba/core.h>
#include <mgba/core/interface.h>
#include <mgba/internal/gba/input.h>
#include <mgba-util/vfs.h>

namespace xemu {

constexpr size_t mGBAWrapper::SAVE_STATE_SIZE;

namespace {
constexpr bool MGBA_LOAD_DEBUG = false;
}

class mGBAWrapper::Impl {
public:
    mCore* core = nullptr;
    bool romLoaded = false;
    uint32_t inputState = 0;
    int audioSampleCount = 0;
    int audioSampleRate = mGBAWrapper::AUDIO_SAMPLE_RATE;
    std::array<char, 13> romTitle{};
    std::vector<uint8_t> romData;
    std::vector<color_t> nativeVideo;
};

mGBAWrapper::mGBAWrapper() : impl_(std::make_unique<Impl>()) {
    initBuffers();
}

mGBAWrapper::~mGBAWrapper() {
    unloadROM();
}

mGBAWrapper::mGBAWrapper(mGBAWrapper&& other) noexcept
    : impl_(std::move(other.impl_)),
      videoBuffer_(std::move(other.videoBuffer_)),
      audioBuffer_(std::move(other.audioBuffer_)) {
}

mGBAWrapper& mGBAWrapper::operator=(mGBAWrapper&& other) noexcept {
    if (this != &other) {
        unloadROM();
        impl_ = std::move(other.impl_);
        videoBuffer_ = std::move(other.videoBuffer_);
        audioBuffer_ = std::move(other.audioBuffer_);
    }
    return *this;
}

void mGBAWrapper::initBuffers() {
    videoBuffer_.resize(VIDEO_BUFFER_SIZE, 0);
    audioBuffer_.resize(AUDIO_SAMPLES_PER_FRAME * 2, 0);
}

bool mGBAWrapper::loadROM(const char* filename, const uint8_t* data, size_t size) {
    if (!data || size == 0) {
        if (MGBA_LOAD_DEBUG) {
            std::fprintf(stderr, "[mGBAWrapper] loadROM invalid input (size=%zu)\n", size);
        }
        return false;
    }

    unloadROM();

    impl_->core = GBACoreCreate();
    if (!impl_->core) {
        impl_->core = mCoreCreate(mPLATFORM_GBA);
    }

    const bool hasCore = impl_->core != nullptr;
    const uintptr_t initPtr = hasCore ? xemu_mgba_core_init_ptr(impl_->core) : 0;
    const bool initOk = hasCore && xemu_mgba_core_init(impl_->core);

    if (MGBA_LOAD_DEBUG) {
        std::fprintf(stderr,
                     "[mGBAWrapper] core=%p initFn=%p initOk=%d\n",
                     static_cast<void*>(impl_->core),
                     reinterpret_cast<void*>(initPtr),
                     initOk ? 1 : 0);
    }

    if (!initOk) {
        xemu_mgba_core_deinit(impl_->core);
        impl_->core = nullptr;
        return false;
    }

    mCoreInitConfig(impl_->core, nullptr);

    unsigned width = VIDEO_WIDTH;
    unsigned height = VIDEO_HEIGHT;
    if (impl_->core->desiredVideoDimensions) {
        impl_->core->desiredVideoDimensions(impl_->core, &width, &height);
    }
    if (width == 0 || height == 0) {
        width = VIDEO_WIDTH;
        height = VIDEO_HEIGHT;
    }

    impl_->nativeVideo.assign(width * height, 0);
    xemu_mgba_core_set_video_buffer(impl_->core, impl_->nativeVideo.data(), width);

    xemu_mgba_core_set_audio_buffer_size(impl_->core, AUDIO_SAMPLES_PER_FRAME);
    impl_->audioSampleRate = AUDIO_SAMPLE_RATE;
    xemu_mgba_core_set_audio_sample_rate(impl_->core, static_cast<unsigned>(impl_->audioSampleRate));

    (void)filename;
    impl_->romData.assign(data, data + size);

    if (MGBA_LOAD_DEBUG) {
        std::fprintf(stderr,
                     "[mGBAWrapper] loading ROM bytes=%zu sampleRate=%d audioBufFrames=%d\n",
                     impl_->romData.size(),
                     impl_->audioSampleRate,
                     AUDIO_SAMPLES_PER_FRAME);
    }

    VFile* romFile = VFileFromMemory(impl_->romData.data(), impl_->romData.size());

    if (!romFile) {
        if (MGBA_LOAD_DEBUG) {
            std::fprintf(stderr, "[mGBAWrapper] VFileFromMemory failed\n");
        }
        unloadROM();
        return false;
    }

    const bool loaded = xemu_mgba_core_preload_vf(impl_->core, romFile);

    if (!loaded) {
        if (MGBA_LOAD_DEBUG) {
            std::fprintf(stderr, "[mGBAWrapper] mCorePreloadVF failed\n");
        }
        unloadROM();
        return false;
    }

    xemu_mgba_core_set_keys(impl_->core, 0);
    xemu_mgba_core_reset(impl_->core);

    impl_->romLoaded = true;
    impl_->inputState = 0;
    impl_->audioSampleCount = 0;
    std::fill(audioBuffer_.begin(), audioBuffer_.end(), 0);

    std::fill(impl_->romTitle.begin(), impl_->romTitle.end(), '\0');
    if (size > 0xAC) {
        const size_t titleLength = std::min<size_t>(12, size - 0xA0);
        for (size_t i = 0; i < titleLength; ++i) {
            const char c = static_cast<char>(data[0xA0 + i]);
            if (std::isprint(static_cast<unsigned char>(c)) != 0) {
                impl_->romTitle[i] = c;
            }
        }
    }

    if (MGBA_LOAD_DEBUG) {
        std::fprintf(stderr, "[mGBAWrapper] ROM loaded successfully title='%s'\n", impl_->romTitle.data());
    }

    return true;
}

void mGBAWrapper::unloadROM() {
    if (impl_->core) {
        if (impl_->romLoaded) {
            xemu_mgba_core_unload_rom(impl_->core);
        }
        xemu_mgba_core_deinit(impl_->core);
        impl_->core = nullptr;
    }

    impl_->romLoaded = false;
    impl_->inputState = 0;
    impl_->audioSampleCount = 0;
    impl_->audioSampleRate = AUDIO_SAMPLE_RATE;
    impl_->romData.clear();
    impl_->nativeVideo.clear();
    std::fill(impl_->romTitle.begin(), impl_->romTitle.end(), '\0');
    std::fill(videoBuffer_.begin(), videoBuffer_.end(), 0);
    std::fill(audioBuffer_.begin(), audioBuffer_.end(), 0);
}

bool mGBAWrapper::isROMLoaded() const {
    return impl_->romLoaded;
}

void mGBAWrapper::runFrame() {
    if (!impl_->romLoaded || !impl_->core) {
        return;
    }

    xemu_mgba_core_run_frame(impl_->core);

    const void* pixelData = nullptr;
    size_t stride = VIDEO_WIDTH;
    xemu_mgba_core_get_pixels(impl_->core, &pixelData, &stride);

    const unsigned width = VIDEO_WIDTH;
    const unsigned height = VIDEO_HEIGHT;

    if (pixelData && stride >= width) {
#ifdef COLOR_16_BIT
        const uint16_t* src = static_cast<const uint16_t*>(pixelData);
        for (unsigned y = 0; y < height; ++y) {
            for (unsigned x = 0; x < width; ++x) {
                const uint16_t px = src[y * stride + x];
#ifdef COLOR_5_6_5
                const uint8_t r = static_cast<uint8_t>(((px >> 11) & 0x1F) * 255 / 31);
                const uint8_t g = static_cast<uint8_t>(((px >> 5) & 0x3F) * 255 / 63);
                const uint8_t b = static_cast<uint8_t>((px & 0x1F) * 255 / 31);
#else
                const uint8_t r = static_cast<uint8_t>((px & 0x1F) * 255 / 31);
                const uint8_t g = static_cast<uint8_t>(((px >> 5) & 0x1F) * 255 / 31);
                const uint8_t b = static_cast<uint8_t>(((px >> 10) & 0x1F) * 255 / 31);
#endif
                const size_t idx = static_cast<size_t>(y * width + x) * 4;
                videoBuffer_[idx + 0] = r;
                videoBuffer_[idx + 1] = g;
                videoBuffer_[idx + 2] = b;
                videoBuffer_[idx + 3] = 0xFF;
            }
        }
#else
        const uint32_t* src = static_cast<const uint32_t*>(pixelData);
        for (unsigned y = 0; y < height; ++y) {
            for (unsigned x = 0; x < width; ++x) {
                const uint32_t px = src[y * stride + x];
                const uint8_t r = static_cast<uint8_t>(px & 0xFF);
                const uint8_t g = static_cast<uint8_t>((px >> 8) & 0xFF);
                const uint8_t b = static_cast<uint8_t>((px >> 16) & 0xFF);
                const size_t idx = static_cast<size_t>(y * width + x) * 4;
                videoBuffer_[idx + 0] = r;
                videoBuffer_[idx + 1] = g;
                videoBuffer_[idx + 2] = b;
                videoBuffer_[idx + 3] = 0xFF;
            }
        }
#endif
    }

    impl_->audioSampleCount = 0;
    const int availableFrames = xemu_mgba_core_audio_samples_avail(impl_->core);
    int readFrames = 0;

    if (availableFrames > 0) {
        const int maxFrames = static_cast<int>(audioBuffer_.size() / 2); // stereo interleaved
        int framesToRead = std::min(availableFrames, maxFrames);

        if (availableFrames > maxFrames) {
            int framesToDrop = availableFrames - maxFrames;
            std::array<int16_t, 1024> discardBuffer{}; // 512 stereo frames
            while (framesToDrop > 0) {
                const int chunkFrames = std::min(framesToDrop, static_cast<int>(discardBuffer.size() / 2));
                const int dropped = xemu_mgba_core_audio_read_interleaved(impl_->core, discardBuffer.data(), chunkFrames);
                if (dropped <= 0) {
                    break;
                }
                framesToDrop -= dropped;
            }
            framesToRead = maxFrames;
        }

        if (framesToRead > 0) {
            readFrames = xemu_mgba_core_audio_read_interleaved(impl_->core, audioBuffer_.data(), framesToRead);
            if (readFrames > 0) {
                const int sampleCount = readFrames * 2;
                impl_->audioSampleCount = sampleCount;
            }
        }
    }
}

void mGBAWrapper::reset() {
    xemu_mgba_core_reset(impl_->core);
}

const uint8_t* mGBAWrapper::getVideoBuffer() const {
    return videoBuffer_.data();
}

const int16_t* mGBAWrapper::getAudioBuffer() const {
    return audioBuffer_.data();
}

int mGBAWrapper::getAudioSampleCount() const {
    return impl_->audioSampleCount;
}

int mGBAWrapper::getAudioSampleRate() const {
    return impl_->audioSampleRate;
}

void mGBAWrapper::setInput(uint32_t buttons) {
    impl_->inputState = buttons;
    if (impl_->core && impl_->romLoaded) {
        xemu_mgba_core_set_keys(impl_->core, impl_->inputState);
    }
}

bool mGBAWrapper::saveState(uint8_t* buffer, size_t size) {
    if (!impl_->core || !impl_->romLoaded || !buffer) {
        return false;
    }

    const size_t needed = xemu_mgba_core_state_size(impl_->core);
    if (needed == 0 || size < needed) {
        return false;
    }

    return xemu_mgba_core_save_state(impl_->core, buffer);
}

bool mGBAWrapper::loadState(const uint8_t* buffer, size_t size) {
    if (!impl_->core || !impl_->romLoaded || !buffer) {
        return false;
    }

    const size_t needed = xemu_mgba_core_state_size(impl_->core);
    if (needed == 0 || size < needed) {
        return false;
    }

    return xemu_mgba_core_load_state(impl_->core, buffer);
}

size_t mGBAWrapper::getSaveStateSize() const {
    if (impl_->core) {
        const size_t size = xemu_mgba_core_state_size(impl_->core);
        if (size > 0) {
            return size;
        }
    }
    return SAVE_STATE_SIZE;
}

const char* mGBAWrapper::getROMTitle() const {
    return impl_->romTitle.data();
}

bool mGBAWrapper::saveBattery(uint8_t* buffer, size_t size) {
    if (!impl_->core || !impl_->romLoaded || !buffer) {
        return false;
    }

    void* savedata = nullptr;
    const size_t savedataSize = xemu_mgba_core_savedata_clone(impl_->core, &savedata);
    if (savedataSize == 0 || !savedata || size < savedataSize) {
        if (savedata) {
            std::free(savedata);
        }
        return false;
    }

    std::memcpy(buffer, savedata, savedataSize);
    std::free(savedata);
    return true;
}

bool mGBAWrapper::loadBattery(const uint8_t* buffer, size_t size) {
    if (!impl_->core || !impl_->romLoaded || !buffer || size == 0) {
        return false;
    }

    return xemu_mgba_core_savedata_restore(impl_->core, buffer, size, true);
}

size_t mGBAWrapper::getBatterySaveSize() const {
    if (!impl_->core || !impl_->romLoaded) {
        return 0;
    }

    void* savedata = nullptr;
    const size_t savedataSize = xemu_mgba_core_savedata_clone(impl_->core, &savedata);
    if (savedata) {
        std::free(savedata);
    }
    return savedataSize;
}

} // namespace xemu
