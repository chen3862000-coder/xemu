#include "nds/nds_backend.h"

#include <algorithm>
#include <vector>

namespace xemu {
namespace nds {
namespace {

class StubBackend final : public Backend {
public:
    xemu_error_t loadROM(const char* filename, const uint8_t* data, size_t size) override {
        (void)filename;
        (void)data;
        (void)size;

        romLoaded_ = false;
        return XEMU_ERROR_UNSUPPORTED_FORMAT;
    }

    xemu_error_t unloadROM() override {
        romLoaded_ = false;
        return XEMU_OK;
    }

    bool isROMLoaded() const override { return romLoaded_; }

    xemu_error_t runFrame() override {
        drawPlaceholderFrame();
        if (!romLoaded_) {
            return XEMU_ERROR_NOT_INITIALIZED;
        }
        return XEMU_OK;
    }

    xemu_error_t reset() override {
        touch_ = {0, 0, 0};
        buttons_ = 0;
        return XEMU_OK;
    }

    xemu_video_buffer_t getVideoBuffer() override { return videoBuffer_; }

    xemu_audio_buffer_t getAudioBuffer() override {
        audioBuffer_.data = audio_.data();
        audioBuffer_.sample_count = static_cast<int>(audio_.size());
        audioBuffer_.sample_rate = 44100;
        return audioBuffer_;
    }

    void setInput(uint32_t buttons) override { buttons_ = buttons; }

    void setTouch(xemu_nds_touch_state_t touch) override { touch_ = touch; }

    size_t getSaveStateSize() const override { return 0; }

    xemu_error_t saveState(xemu_save_state_t* state) override {
        (void)state;
        return XEMU_ERROR_SAVE_STATE_FAILED;
    }

    xemu_error_t loadState(const xemu_save_state_t* state) override {
        (void)state;
        return XEMU_ERROR_LOAD_STATE_FAILED;
    }

    xemu_error_t setScreenLayout(xemu_nds_screen_layout_t layout) override {
        resizeVideoForLayout(layout);
        return XEMU_OK;
    }

    xemu_nds_screen_layout_t getScreenLayout() const override { return layout_; }

    StubBackend() { resizeVideoForLayout(layout_); }

private:
    void resizeVideoForLayout(xemu_nds_screen_layout_t newLayout) {
        layout_ = newLayout;
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
            width_ = 256;
            height_ = 384;
            layout_ = XEMU_NDS_SCREEN_LAYOUT_STACKED;
            break;
        }

        pitch_ = width_ * 4;
        video_.assign(static_cast<size_t>(pitch_ * height_), 0);
        videoBuffer_.data = video_.data();
        videoBuffer_.width = width_;
        videoBuffer_.height = height_;
        videoBuffer_.pitch = pitch_;
    }

    void drawPlaceholderFrame() {
        if (video_.empty()) {
            return;
        }

        for (int y = 0; y < height_; ++y) {
            uint8_t* row = video_.data() + (y * pitch_);
            for (int x = 0; x < width_; ++x) {
                const size_t i = static_cast<size_t>(x * 4);
                const uint8_t r = static_cast<uint8_t>(30 + (x * 40 / std::max(1, width_)));
                const uint8_t g = static_cast<uint8_t>(12 + (y * 25 / std::max(1, height_)));
                const uint8_t b = static_cast<uint8_t>(
                    55 + ((x + y) * 45 / std::max(1, width_ + height_)));
                row[i + 0] = r;
                row[i + 1] = g;
                row[i + 2] = b;
                row[i + 3] = 255;
            }
        }

        if (layout_ == XEMU_NDS_SCREEN_LAYOUT_STACKED) {
            const int separatorY = 192;
            if (separatorY >= 0 && separatorY < height_) {
                uint8_t* row = video_.data() + (separatorY * pitch_);
                for (int x = 0; x < width_; ++x) {
                    const size_t i = static_cast<size_t>(x * 4);
                    row[i + 0] = 120;
                    row[i + 1] = 80;
                    row[i + 2] = 180;
                    row[i + 3] = 255;
                }
            }
        }
    }

    bool romLoaded_ = false;
    xemu_nds_screen_layout_t layout_ = XEMU_NDS_SCREEN_LAYOUT_STACKED;
    xemu_nds_touch_state_t touch_ = {0, 0, 0};
    uint32_t buttons_ = 0;

    int width_ = 256;
    int height_ = 384;
    int pitch_ = 256 * 4;
    std::vector<uint8_t> video_;
    std::vector<int16_t> audio_;
    xemu_video_buffer_t videoBuffer_ = {nullptr, 0, 0, 0};
    xemu_audio_buffer_t audioBuffer_ = {nullptr, 0, 44100};
};

} // namespace

std::unique_ptr<Backend> createStubBackend() {
    return std::unique_ptr<Backend>(new StubBackend());
}

} // namespace nds
} // namespace xemu
