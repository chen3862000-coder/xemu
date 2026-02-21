# GBA Core Sources
set(GBA_SOURCES
    ${CMAKE_CURRENT_SOURCE_DIR}/mgba_wrapper.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/mgba_video.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/mgba_audio.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/mgba_input.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/mgba_savestate.cpp
    PARENT_SCOPE
)

# For now, create a library target when mGBA is available
# add_library(gba_core STATIC ${GBA_SOURCES})
# target_link_libraries(gba_core mgba)
