#ifndef GAMBATTE_WRAPPER_H
#define GAMBATTE_WRAPPER_H

#include <cstdint>
#include <cstddef>
#include <memory>
#include <vector>

namespace xemu {

class GambatteWrapper {
public:
    GambatteWrapper();
    ~GambatteWrapper();

    GambatteWrapper(const GambatteWrapper&) = delete;
    GambatteWrapper& operator=(const GambatteWrapper&) = delete;
    GambatteWrapper(GambatteWrapper&&) noexcept;
    GambatteWrapper& operator=(GambatteWrapper&&) noexcept;

    bool loadROM(const char* filename, const uint8_t* data, size_t size);
    void unloadROM();
    bool isROMLoaded() const;

    void runFrame();
    void reset();

    static constexpr int VIDEO_WIDTH = 160;
    static constexpr int VIDEO_HEIGHT = 144;
    static constexpr int VIDEO_BUFFER_SIZE = VIDEO_WIDTH * VIDEO_HEIGHT * 4;
    
    const uint8_t* getVideoBuffer() const;
    int getVideoWidth() const { return VIDEO_WIDTH; }
    int getVideoHeight() const { return VIDEO_HEIGHT; }

    static constexpr int AUDIO_SAMPLE_RATE = 65536;
    static constexpr int AUDIO_SAMPLES_PER_FRAME = 1098;
    
    const int16_t* getAudioBuffer() const;
    int getAudioSampleCount() const;

    void setInput(uint32_t buttons);

    static constexpr size_t SAVE_STATE_SIZE = 128 * 1024;
    
    bool saveState(uint8_t* buffer, size_t size);
    bool loadState(const uint8_t* buffer, size_t size);
    size_t getSaveStateSize() const;
    bool saveBattery(uint8_t* buffer, size_t size);
    bool loadBattery(const uint8_t* buffer, size_t size);
    size_t getBatterySaveSize() const;
    bool readMemory8(uint16_t address, uint8_t& value) const;

    bool isCGBMode() const;
    const char* getROMTitle() const;

private:
    class Impl;
    std::unique_ptr<Impl> impl_;
};

} // namespace xemu

#endif // GAMBATTE_WRAPPER_H
