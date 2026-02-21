#include "mgba_wrapper.h"
#include <cstring>

namespace xemu {

// Placeholder implementation - will integrate actual mGBA core
class mGBAWrapper::Impl {
public:
    bool romLoaded = false;
    uint32_t inputState = 0;
    char romTitle[13] = {0};
};

mGBAWrapper::mGBAWrapper() 
    : impl_(std::make_unique<Impl>()) {
    initBuffers();
}

mGBAWrapper::~mGBAWrapper() = default;

mGBAWrapper::mGBAWrapper(mGBAWrapper&&) noexcept = default;
mGBAWrapper& mGBAWrapper::operator=(mGBAWrapper&&) noexcept = default;

void mGBAWrapper::initBuffers() {
    videoBuffer_.resize(VIDEO_BUFFER_SIZE);
    audioBuffer_.resize(AUDIO_SAMPLES_PER_FRAME * 2); // Stereo
    
    // Clear to black
    std::memset(videoBuffer_.data(), 0, videoBuffer_.size());
}

bool mGBAWrapper::loadROM(const char* filename, const uint8_t* data, size_t size) {
    // Placeholder - will integrate actual mGBA loading
    if (!data || size == 0) {
        return false;
    }
    
    // Check for valid GBA header
    if (size < 0xC0) {
        return false;
    }
    
    // Extract ROM title (game code starts at 0xAC)
    std::memcpy(impl_->romTitle, data + 0xA0, 12);
    impl_->romTitle[12] = '\0';
    
    impl_->romLoaded = true;
    return true;
}

void mGBAWrapper::unloadROM() {
    impl_->romLoaded = false;
    impl_->romTitle[0] = '\0';
}

bool mGBAWrapper::isROMLoaded() const {
    return impl_->romLoaded;
}

void mGBAWrapper::runFrame() {
    if (!impl_->romLoaded) return;
    
    // Placeholder - will integrate actual frame execution
    // For now, just fill audio buffer with silence
    std::memset(audioBuffer_.data(), 0, audioBuffer_.size() * sizeof(int16_t));
}

void mGBAWrapper::reset() {
    if (!impl_->romLoaded) return;
    // Placeholder - will integrate actual reset
}

const uint8_t* mGBAWrapper::getVideoBuffer() const {
    return videoBuffer_.data();
}

const int16_t* mGBAWrapper::getAudioBuffer() const {
    return audioBuffer_.data();
}

int mGBAWrapper::getAudioSampleCount() const {
    return static_cast<int>(audioBuffer_.size());
}

void mGBAWrapper::setInput(uint32_t buttons) {
    impl_->inputState = buttons;
}

bool mGBAWrapper::saveState(uint8_t* buffer, size_t size) {
    if (!impl_->romLoaded || size < SAVE_STATE_SIZE) {
        return false;
    }
    // Placeholder - will integrate actual save state serialization
    std::memset(buffer, 0, size);
    return true;
}

bool mGBAWrapper::loadState(const uint8_t* buffer, size_t size) {
    if (!impl_->romLoaded || size < SAVE_STATE_SIZE) {
        return false;
    }
    // Placeholder - will integrate actual load state deserialization
    return true;
}

size_t mGBAWrapper::getSaveStateSize() const {
    return SAVE_STATE_SIZE;
}

const char* mGBAWrapper::getROMTitle() const {
    return impl_->romTitle;
}

} // namespace xemu
