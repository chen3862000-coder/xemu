#ifndef MGBA_WRAPPER_H
#define MGBA_WRAPPER_H

#include <cstdint>
#include <cstddef>
#include <memory>
#include <vector>

namespace xemu {

// Forward declarations for mGBA types
struct mCore;

/**
 * Wrapper class for mGBA GBA emulator core
 */
class mGBAWrapper {
public:
    mGBAWrapper();
    ~mGBAWrapper();

    // Disable copy, enable move
    mGBAWrapper(const mGBAWrapper&) = delete;
    mGBAWrapper& operator=(const mGBAWrapper&) = delete;
    mGBAWrapper(mGBAWrapper&&) noexcept;
    mGBAWrapper& operator=(mGBAWrapper&&) noexcept;

    // ROM loading
    bool loadROM(const char* filename, const uint8_t* data, size_t size);
    void unloadROM();
    bool isROMLoaded() const;

    // Execution
    void runFrame();
    void reset();

    // Video (240x160, RGBA8888)
    static constexpr int VIDEO_WIDTH = 240;
    static constexpr int VIDEO_HEIGHT = 160;
    static constexpr int VIDEO_BUFFER_SIZE = VIDEO_WIDTH * VIDEO_HEIGHT * 4;
    
    const uint8_t* getVideoBuffer() const;
    int getVideoWidth() const { return VIDEO_WIDTH; }
    int getVideoHeight() const { return VIDEO_HEIGHT; }

    // Audio (44100Hz stereo)
    static constexpr int AUDIO_SAMPLE_RATE = 44100;
    static constexpr int AUDIO_SAMPLES_PER_FRAME = 735; // ~59.73 FPS
    
    const int16_t* getAudioBuffer() const;
    int getAudioSampleCount() const;

    // Input (includes L/R buttons for GBA)
    void setInput(uint32_t buttons);

    // Save states
    static constexpr size_t SAVE_STATE_SIZE = 512 * 1024; // 512KB
    
    bool saveState(uint8_t* buffer, size_t size);
    bool loadState(const uint8_t* buffer, size_t size);
    size_t getSaveStateSize() const;

    // System info
    const char* getROMTitle() const;

private:
    class Impl;
    std::unique_ptr<Impl> impl_;
    
    // Buffers
    std::vector<uint8_t> videoBuffer_;
    std::vector<int16_t> audioBuffer_;
    
    void initBuffers();
};

} // namespace xemu

#endif // MGBA_WRAPPER_H
