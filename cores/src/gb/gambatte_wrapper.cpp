#include "gambatte_wrapper.h"
#include <algorithm>
#include <cmath>
#include <cstring>
#include <cstdio>

#ifdef XEMU_USE_REAL_CORES
#include <gambatte.h>
#endif

namespace xemu {

constexpr size_t GambatteWrapper::SAVE_STATE_SIZE;

namespace {
constexpr unsigned RUN_SAMPLES_PER_CALL = 2064;
constexpr int16_t CC_KERNEL[32] = {
    0x0800, 0x07fb, 0x07eb, 0x07d3, 0x07b3, 0x0787, 0x0753, 0x0717,
    0x06d3, 0x068b, 0x063b, 0x05e2, 0x0586, 0x052a, 0x04c6, 0x0466,
    0x0402, 0x0399, 0x0339, 0x02d5, 0x0279, 0x021d, 0x01c4, 0x0174,
    0x012c, 0x00e8, 0x00ac, 0x0078, 0x004c, 0x002c, 0x0014, 0x0004
};
constexpr int16_t CC_KERNEL_R[32] = {
    0x0000, 0x0004, 0x0014, 0x002c, 0x004c, 0x0078, 0x00ac, 0x00e8,
    0x012c, 0x0174, 0x01c4, 0x021d, 0x0279, 0x02d5, 0x0339, 0x0399,
    0x0402, 0x0466, 0x04c6, 0x052a, 0x0586, 0x05e2, 0x063b, 0x068b,
    0x06d3, 0x0717, 0x0753, 0x0787, 0x07b3, 0x07d3, 0x07eb, 0x07fb
};

static inline uint8_t expand5To8(unsigned v) {
    return static_cast<uint8_t>((v << 3) | (v >> 2));
}

static inline uint8_t expand6To8(unsigned v) {
    return static_cast<uint8_t>((v << 2) | (v >> 4));
}
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

        // Apply different defaults for DMG vs CGB:
        // - CGB: keep bright direct rendering for current iOS look.
        // - DMG: keep color correction enabled so the gray ramp is preserved and
        //   doesn't collapse into harsh black/white output.
        applyDisplayDefaults();
        
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
        clearAudioPipeline();
        romLoaded_ = false;
        romData_.clear();
        std::memset(videoBuffer_.data(), 0, videoBuffer_.size());
        std::memset(audioBuffer_.data(), 0, audioBuffer_.size() * sizeof(int16_t));
    }

    bool isROMLoaded() const { return romLoaded_; }

    void runFrame() {
        if (!romLoaded_) return;

#ifdef XEMU_USE_REAL_CORES
        int runResult = -1;

        do {
            unsigned samplesProduced = RUN_SAMPLES_PER_CALL;
            runResult = gambatte_->runFor(videoFramePixels_.data(),
                                          VIDEO_WIDTH,
                                          audioWorkBuffer_.data(),
                                          audioWorkBuffer_.size(),
                                          samplesProduced);

            const unsigned copyStereoFrames = samplesProduced;

            if (copyStereoFrames > 0) {
                const int16_t* chunk = reinterpret_cast<const int16_t*>(audioWorkBuffer_.data());
                pushCCResampledAudio(chunk, copyStereoFrames);
            }

        } while (runResult == -1);
        
        for (int i = 0; i < VIDEO_WIDTH * VIDEO_HEIGHT; ++i) {
            uint8_t* out = &videoBuffer_[i * 4];
#if defined(VIDEO_RGB565)
            const uint16_t pixel = videoFramePixels_[i];
            const unsigned r5 = (pixel >> 11) & 0x1F;
            const unsigned g6 = (pixel >> 5) & 0x3F;
            const unsigned b5 = pixel & 0x1F;
            out[0] = expand5To8(r5);
            out[1] = expand6To8(g6);
            out[2] = expand5To8(b5);
            out[3] = 0xFF;
#elif defined(VIDEO_ABGR1555)
            const uint16_t pixel = videoFramePixels_[i];
            const unsigned a1 = (pixel >> 15) & 0x01;
            const unsigned b5 = (pixel >> 10) & 0x1F;
            const unsigned g5 = (pixel >> 5) & 0x1F;
            const unsigned r5 = pixel & 0x1F;
            out[0] = expand5To8(r5);
            out[1] = expand5To8(g5);
            out[2] = expand5To8(b5);
            out[3] = a1 ? 0xFF : 0xFF;
#else
            const uint32_t pixel = videoFramePixels_[i];
            out[0] = (pixel >> 16) & 0xFF;
            out[1] = (pixel >> 8) & 0xFF;
            out[2] = pixel & 0xFF;
            out[3] = 0xFF;
#endif
        }

        const size_t outputSamples = std::min(audioBuffer_.size(), ccResampledAudioInterleaved_.size());
        if (outputSamples == 0) {
            audioSamples_ = 0;
            return;
        }

        std::memcpy(audioBuffer_.data(), ccResampledAudioInterleaved_.data(), outputSamples * sizeof(int16_t));
        ccResampledAudioInterleaved_.erase(
            ccResampledAudioInterleaved_.begin(),
            ccResampledAudioInterleaved_.begin() + static_cast<std::ptrdiff_t>(outputSamples)
        );

        audioSamples_ = static_cast<int>(outputSamples);
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
        clearAudioPipeline();
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
    void applyDisplayDefaults() {
        if (!gambatte_) return;
        if (gambatte_->isCgb()) {
            // Keep the brighter CGB path that looks good in the iOS app.
            gambatte_->setDarkFilterLevel(0);
            gambatte_->setColorCorrection(false);
        } else {
            // GB (DMG): keep a stable 4-step grayscale ramp and disable Gambatte's
            // color correction path (which can compress/shift the gray tones on
            // our iOS output path). Savestates can restore older palette values,
            // so reapply these defaults after ROM load and state load.
            gambatte_->setDarkFilterLevel(0);
            gambatte_->setColorCorrection(false);
            static const unsigned long dmgDefaultGray[4] = {
                0xFFFFFF,
                0xAAAAAA,
                0x555555,
                0x000000
            };
            for (unsigned pal = 0; pal < 3; ++pal) {
                for (unsigned c = 0; c < 4; ++c) {
                    gambatte_->setDmgPaletteColor(pal, c, dmgDefaultGray[c]);
                }
            }
        }
    }

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
        if (!romLoaded_ || !buffer) return false;
#ifdef XEMU_USE_REAL_CORES
        if (!gambatte_) return false;
        const size_t needed = gambatte_->stateSize();
        if (needed == 0 || size < needed) return false;
        gambatte_->saveState(buffer);
        return true;
#else
        return false;
#endif
    }

    bool loadState(const uint8_t* buffer, size_t size) {
        if (!romLoaded_ || !buffer) return false;
#ifdef XEMU_USE_REAL_CORES
        if (!gambatte_) return false;
        const size_t needed = gambatte_->stateSize();
        if (needed == 0 || size < needed) return false;
        gambatte_->loadState(buffer);
        applyDisplayDefaults();
        clearAudioPipeline();
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

    bool saveBattery(uint8_t* buffer, size_t size) {
        if (!romLoaded_ || !buffer) return false;
#ifdef XEMU_USE_REAL_CORES
        if (!gambatte_) return false;
        const unsigned needed = gambatte_->savedata_size();
        if (needed == 0 || size < needed) return false;
        const void* src = gambatte_->savedata_ptr();
        if (!src) return false;
        std::memcpy(buffer, src, needed);
        return true;
#else
        return false;
#endif
    }

    bool loadBattery(const uint8_t* buffer, size_t size) {
        if (!romLoaded_ || !buffer) return false;
#ifdef XEMU_USE_REAL_CORES
        if (!gambatte_) return false;
        const unsigned needed = gambatte_->savedata_size();
        if (needed == 0 || size < needed) return false;
        void* dst = gambatte_->savedata_ptr();
        if (!dst) return false;
        std::memcpy(dst, buffer, needed);
        return true;
#else
        return false;
#endif
    }

    size_t getBatterySaveSize() const {
#ifdef XEMU_USE_REAL_CORES
        return gambatte_ ? gambatte_->savedata_size() : 0;
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
    void pushCCResampledAudio(const int16_t* interleavedSamples, unsigned stereoFrames) {
        if (!interleavedSamples || stereoFrames == 0) {
            return;
        }

        // Mirrors Gambatte's libretro "Convoluted Cosine" resampler path.
        for (unsigned i = 0; i < stereoFrames; ++i) {
            const int16_t left = interleavedSamples[static_cast<size_t>(i) * 2];
            const int16_t right = interleavedSamples[(static_cast<size_t>(i) * 2) + 1];

            ccCurrentLeft_ += static_cast<int32_t>(left) * CC_KERNEL[ccAccumulatedSamples_];
            ccCurrentRight_ += static_cast<int32_t>(right) * CC_KERNEL[ccAccumulatedSamples_];
            ccNextLeft_ += static_cast<int32_t>(left) * CC_KERNEL_R[ccAccumulatedSamples_];
            ccNextRight_ += static_cast<int32_t>(right) * CC_KERNEL_R[ccAccumulatedSamples_];

            ++ccAccumulatedSamples_;
            if (ccAccumulatedSamples_ != 32) {
                continue;
            }

            const int16_t sampleLeft = static_cast<int16_t>(ccCurrentLeft_ >> 16);
            const int32_t tmpLeft = ccHighpassLeft_ + ((static_cast<int32_t>(sampleLeft) - ccPrevSampleLeft_) << 8);
            ccHighpassLeft_ = tmpLeft - (tmpLeft >> 8);
            ccPrevSampleLeft_ = sampleLeft;
            const int16_t outputLeft = static_cast<int16_t>((ccHighpassLeft_ + 128) >> 8);

            const int16_t sampleRight = static_cast<int16_t>(ccCurrentRight_ >> 16);
            const int32_t tmpRight = ccHighpassRight_ + ((static_cast<int32_t>(sampleRight) - ccPrevSampleRight_) << 8);
            ccHighpassRight_ = tmpRight - (tmpRight >> 8);
            ccPrevSampleRight_ = sampleRight;
            const int16_t outputRight = static_cast<int16_t>((ccHighpassRight_ + 128) >> 8);

            ccResampledAudioInterleaved_.push_back(outputLeft);
            ccResampledAudioInterleaved_.push_back(outputRight);

            ccAccumulatedSamples_ = 0;
            ccCurrentLeft_ = ccNextLeft_;
            ccCurrentRight_ = ccNextRight_;
            ccNextLeft_ = 0;
            ccNextRight_ = 0;
        }
    }

    void clearAudioPipeline() {
        std::fill(audioBuffer_.begin(), audioBuffer_.end(), 0);
        ccResampledAudioInterleaved_.clear();
        ccAccumulatedSamples_ = 0;
        ccPrevSampleLeft_ = 0;
        ccPrevSampleRight_ = 0;
        ccHighpassLeft_ = 0;
        ccHighpassRight_ = 0;
        ccCurrentLeft_ = 0;
        ccCurrentRight_ = 0;
        ccNextLeft_ = 0;
        ccNextRight_ = 0;
        audioSamples_ = 0;
    }

#ifdef XEMU_USE_REAL_CORES
    std::unique_ptr<gambatte::GB> gambatte_;
#endif
    std::vector<uint8_t> romData_;
    std::vector<uint8_t> videoBuffer_;
    std::vector<int16_t> audioBuffer_;
    std::vector<int16_t> ccResampledAudioInterleaved_;
    std::array<gambatte::video_pixel_t, VIDEO_WIDTH * VIDEO_HEIGHT> videoFramePixels_{};
    std::vector<gambatte::uint_least32_t> audioWorkBuffer_;
    unsigned ccAccumulatedSamples_ = 0;
    int32_t ccPrevSampleLeft_ = 0;
    int32_t ccPrevSampleRight_ = 0;
    int32_t ccHighpassLeft_ = 0;
    int32_t ccHighpassRight_ = 0;
    int32_t ccCurrentLeft_ = 0;
    int32_t ccCurrentRight_ = 0;
    int32_t ccNextLeft_ = 0;
    int32_t ccNextRight_ = 0;
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
bool GambatteWrapper::saveBattery(uint8_t* buffer, size_t size) { return impl_->saveBattery(buffer, size); }
bool GambatteWrapper::loadBattery(const uint8_t* buffer, size_t size) { return impl_->loadBattery(buffer, size); }
size_t GambatteWrapper::getBatterySaveSize() const { return impl_->getBatterySaveSize(); }
bool GambatteWrapper::isCGBMode() const { return impl_->isCGBMode(); }
const char* GambatteWrapper::getROMTitle() const { return impl_->getROMTitle(); }

} // namespace xemu
