#include "nds/nds_backend.h"

namespace xemu {
namespace nds {

std::unique_ptr<Backend> createDefaultBackend() {
#if defined(XEMU_ENABLE_NDS_LIBRETRO_BACKEND)
    if (auto backend = createLibretroBackend()) {
        return backend;
    }
#endif
    return createStubBackend();
}

} // namespace nds
} // namespace xemu
