# GB/GBC Core Sources
set(GB_SOURCES
    ${CMAKE_CURRENT_SOURCE_DIR}/gambatte_wrapper.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/gambatte_video.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/gambatte_audio.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/gambatte_input.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/gambatte_savestate.cpp
    PARENT_SCOPE
)

# For now, create a library target when Gambatte is available
# add_library(gb_core STATIC ${GB_SOURCES})
# target_link_libraries(gb_core gambatte_libretro)
