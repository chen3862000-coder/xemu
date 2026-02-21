#include "gambatte_wrapper.h"
#include <algorithm>
#include <cstring>
#include <cstdio>

#ifdef XEMU_USE_REAL_CORES
#include <gambatte.h>
#endif

namespace xemu {

namespace {
constexpr unsigned RUN_SAMPLES_PER_CALL = 2064;
}

class GambatteWrapper::Impl {
public:
    Impl() : romLoaded_(false), audioSamples_(0) {
        videoBuffer_.resize(VIDEO_BUFFER_SIZE);
        audioBuffer_.resize(AUDIO_SAMPLES_PER_FRAME * 2);
        audioWorkBuffer_.resize(RUN_SAMPLES_PER_CALL + 2064);
        std::memset(videoBuffer_.data(), 0, videoBuffer_.size());
        std::memset(audioBuffer_.data(), 0, audioBuffer_.size() * sizeof(int16_t));

#ifdef XEMU_USE_REAL_CORES
        gambatte_ = std::make_unique<gambatte::GB>();
        inputGetter_ = std::make_unique<InputGetter>();
        gambatte_->setInputGetter(inputGetter_.get());
        printf("[GambatteWrapper] Initialized in REAL mode\n");
#else
        printf("[GambatteWrapper] Initialized in MOCK mode\n");
#endif
    }

    ~Impl() = default;

    bool loadROM(const char* filename, const uint8_t* data, size_t size) {
        if (!data || size == 0) {
            printf("[GambatteWrapper] ERROR: Invalid ROM data\n");
            return false;
        }

#ifdef XEMU_USE_REAL_CORES
        romData_.assign(data, data + size);
        
        unsigned flags = 0;
        if (gambatte_->load(romData_.data(), static_cast<unsigned>(romData_.size()), flags) != 0) {
            printf("[GambatteWrapper] ERROR: Failed to load ROM\n");
            return false;
        }
        
        romLoaded_ = true;
        printf("[GambatteWrapper] ROM loaded successfully (%zu bytes), CGB mode: %s\n", 
               size, gambatte_->isCgb() ? "yes" : "no");
        return true;
#else
        romLoaded_ = true;
        printf("[GambatteWrapper] MOCK: ROM loaded (%zu bytes)\n", size);
        return true;
#endif
    }

    void unloadROM() {
#ifdef XEMU_USE_REAL_CORES
        gambatte_ = std::make_unique<gambatte::GB>();
        if (gambatte_ && inputGetter_) {
            gambatte_->setInputGetter(inputGetter_.get());
        }
#endif
        romLoaded_ = false;
        romData_.clear();
        std::memset(videoBuffer_.data(), 0, videoBuffer_.size());
        std::memset(audioBuffer_.data(), 0, audioBuffer_.size() * sizeof(int16_t));
    }

    bool isROMLoaded() const { return romLoaded_; }

    void runFrame() {
        if (!romLoaded_) return;

#ifdef XEMU_USE_REAL_CORES
        unsigned totalStereoFrames = 0;
        int runResult = -1;

        do {
            unsigned samplesProduced = RUN_SAMPLES_PER_CALL;
            runResult = gambatte_->runFor(videoFramePixels_.data(),
                                          VIDEO_WIDTH,
                                          audioWorkBuffer_.data(),
                                          audioWorkBuffer_.size(),
                                          samplesProduced);

            const unsigned maxStereoFrames = static_cast<unsigned>(audioBuffer_.size() / 2);
            const unsigned remaining = (totalStereoFrames < maxStereoFrames)
                ? (maxStereoFrames - totalStereoFrames)
                : 0;
            const unsigned copyStereoFrames = std::min(samplesProduced, remaining);

            for (unsigned i = 0; i < copyStereoFrames; ++i) {
                const uint32_t sample = audioWorkBuffer_[i];
                const unsigned dst = (totalStereoFrames + i) * 2;
                audioBuffer_[dst] = static_cast<int16_t>(sample & 0xFFFF);
                audioBuffer_[dst + 1] = static_cast<int16_t>((sample >> 16) & 0xFFFF);
            }

            totalStereoFrames += copyStereoFrames;
        } while (runResult == -1);
        
        for (int i = 0; i < VIDEO_WIDTH * VIDEO_HEIGHT; ++i) {
            uint32_t pixel = videoFramePixels_[i];
            uint8_t* out = &videoBuffer_[i * 4];
            out[0] = (pixel >> 16) & 0xFF;
            out[1] = (pixel >> 8) & 0xFF;
            out[2] = pixel & 0xFF;
            out[3] = 0xFF;
        }

        audioSamples_ = static_cast<int>(totalStereoFrames * 2);
#else
        for (int i = 0; i < VIDEO_WIDTH * VIDEO_HEIGHT; ++i) {
            uint8_t pattern = static_cast<uint8_t>((i + frameCount_) & 0xFF);
            videoBuffer_[i * 4 + 0] = pattern;
            videoBuffer_[i * 4 + 1] = pattern;
            videoBuffer_[i * 4 + 2] = pattern;
            videoBuffer_[i * 4 + 3] = 0xFF;
        }
        frameCount_++;
        audioSamples_ = AUDIO_SAMPLES_PER_FRAME * 2;
#endif
    }

    void reset() {
        if (!romLoaded_) return;
#ifdef XEMU_USE_REAL_CORES
        if (gambatte_) {
            gambatte_->reset();
        }
#endif
    }

    const uint8_t* getVideoBuffer() const { return videoBuffer_.data(); }
    
    const int16_t* getAudioBuffer() const { return audioBuffer_.data(); }
    
    int getAudioSampleCount() const { return audioSamples_; }

    void setInput(uint32_t buttons) {
#ifdef XEMU_USE_REAL_CORES
        if (inputGetter_) {
            inputGetter_->setButtons(buttons);
        }
#endif
    }

#ifdef XEMU_USE_REAL_CORES
    class InputGetter : public gambatte::InputGetter {
    public:
        unsigned operator()() override { return buttons_; }
        void setButtons(unsigned buttons) { buttons_ = buttons; }
    private:
        unsigned buttons_ = 0;
    };
    std::unique_ptr<InputGetter> inputGetter_;
#endif

    bool saveState(uint8_t* buffer, size_t size) {
        if (!romLoaded_ || !buffer || size < SAVE_STATE_SIZE) return false;
#ifdef XEMU_USE_REAL_CORES
        gambatte_->saveState(buffer);
        return true;
#else
        return false;
#endif
    }

    bool loadState(const uint8_t* buffer, size_t size) {
        if (!romLoaded_ || !buffer || size == 0) return false;
#ifdef XEMU_USE_REAL_CORES
        gambatte_->loadState(buffer);
        return true;
#else
        return false;
#endif
    }

    size_t getSaveStateSize() const {
#ifdef XEMU_USE_REAL_CORES
        return gambatte_ ? gambatte_->stateSize() : 0;
#else
        return 0;
#endif
    }

    bool isCGBMode() const {
#ifdef XEMU_USE_REAL_CORES
        return gambatte_ ? gambatte_->isCgb() : false;
#else
        return false;
#endif
    }

    const char* getROMTitle() const {
#ifdef XEMU_USE_REAL_CORES
        static char title[17] = {0};
        return title;
#else
        return "MOCK ROM";
#endif
    }

private:
#ifdef XEMU_USE_REAL_CORES
    std::unique_ptr<gambatte::GB> gambatte_;
#endif
    std::vector<uint8_t> romData_;
    std::vector<uint8_t> videoBuffer_;
    std::vector<int16_t> audioBuffer_;
    std::array<gambatte::video_pixel_t, VIDEO_WIDTH * VIDEO_HEIGHT> videoFramePixels_{};
    std::vector<gambatte::uint_least32_t> audioWorkBuffer_;
    bool romLoaded_;
    int audioSamples_;
    int frameCount_ = 0;
};

GambatteWrapper::GambatteWrapper() : impl_(std::make_unique<Impl>()) {}
GambatteWrapper::~GambatteWrapper() = default;
GambatteWrapper::GambatteWrapper(GambatteWrapper&&) noexcept = default;
GambatteWrapper& GambatteWrapper::operator=(GambatteWrapper&&) noexcept = default;

bool GambatteWrapper::loadROM(const char* filename, const uint8_t* data, size_t size) {
    return impl_->loadROM(filename, data, size);
}

void GambatteWrapper::unloadROM() { impl_->unloadROM(); }
bool GambatteWrapper::isROMLoaded() const { return impl_->isROMLoaded(); }
void GambatteWrapper::runFrame() { impl_->runFrame(); }
void GambatteWrapper::reset() { impl_->reset(); }
const uint8_t* GambatteWrapper::getVideoBuffer() const { return impl_->getVideoBuffer(); }
const int16_t* GambatteWrapper::getAudioBuffer() const { return impl_->getAudioBuffer(); }
int GambatteWrapper::getAudioSampleCount() const { return impl_->getAudioSampleCount(); }
void GambatteWrapper::setInput(uint32_t buttons) { impl_->setInput(buttons); }
bool GambatteWrapper::saveState(uint8_t* buffer, size_t size) { return impl_->saveState(buffer, size); }
bool GambatteWrapper::loadState(const uint8_t* buffer, size_t size) { return impl_->loadState(buffer, size); }
size_t GambatteWrapper::getSaveStateSize() const { return impl_->getSaveStateSize(); }
bool GambatteWrapper::isCGBMode() const { return impl_->isCGBMode(); }
const char* GambatteWrapper::getROMTitle() const { return impl_->getROMTitle(); }

} // namespace xemu
