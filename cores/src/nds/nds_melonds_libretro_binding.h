#pragma once

#include "nds/nds_libretro_core_api.h"

namespace xemu {
namespace nds {

// Returns a libretro API table backed by melonDS DS libretro symbols when they
// are available; otherwise returns an unbound table.
LibretroCoreAPI createMelonDSLibretroCoreAPI();

} // namespace nds
} // namespace xemu
