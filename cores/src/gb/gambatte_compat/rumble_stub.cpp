#include <cstdint>

// libgambatte's cartridge.cpp references this symbol when rumble-capable mappers
// are present. We do not currently expose rumble hardware on iOS, so keep it no-op.
void cartridge_set_rumble(unsigned active) {
    (void)active;
}
