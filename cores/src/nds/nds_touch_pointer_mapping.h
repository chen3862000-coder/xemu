#ifndef XEMU_NDS_TOUCH_POINTER_MAPPING_H
#define XEMU_NDS_TOUCH_POINTER_MAPPING_H

namespace xemu {
namespace nds {

struct PointerFrameCoordinates {
    int x;
    int y;
    int maxX;
    int maxY;
};

inline int clampInt(int value, int minValue, int maxValue) {
    return value < minValue ? minValue : (value > maxValue ? maxValue : value);
}

// Convert DS-local stylus coordinates (0..255, 0..191) to libretro pointer
// frame-space coordinates for the current composited output frame.
inline PointerFrameCoordinates mapTouchToPointerFrame(
    int touchX,
    int touchY,
    int frameWidth,
    int frameHeight
) {
    const int safeFrameWidth = frameWidth > 0 ? frameWidth : 256;
    const int safeFrameHeight = frameHeight > 0 ? frameHeight : 384;

    PointerFrameCoordinates coords{
        touchX,
        touchY,
        safeFrameWidth > 1 ? safeFrameWidth - 1 : 1,
        safeFrameHeight > 1 ? safeFrameHeight - 1 : 1
    };

    // Side-by-side family: bottom screen in the right half.
    if (safeFrameWidth >= (safeFrameHeight * 2)) {
        coords.x += safeFrameWidth / 2;
    // Top-bottom family: bottom screen in the lower half.
    } else if (safeFrameHeight > safeFrameWidth) {
        coords.y += safeFrameHeight / 2;
    }

    coords.x = clampInt(coords.x, 0, coords.maxX);
    coords.y = clampInt(coords.y, 0, coords.maxY);
    return coords;
}

} // namespace nds
} // namespace xemu

#endif // XEMU_NDS_TOUCH_POINTER_MAPPING_H
