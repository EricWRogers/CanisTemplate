include_guard(GLOBAL)

set(_canis_emscripten_toolchain "")

if(DEFINED ENV{EMSDK} AND EXISTS "$ENV{EMSDK}/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake")
    set(_canis_emscripten_toolchain "$ENV{EMSDK}/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake")
elseif(DEFINED ENV{EMSCRIPTEN} AND EXISTS "$ENV{EMSCRIPTEN}/cmake/Modules/Platform/Emscripten.cmake")
    set(_canis_emscripten_toolchain "$ENV{EMSCRIPTEN}/cmake/Modules/Platform/Emscripten.cmake")
elseif(EXISTS "/usr/share/emscripten/cmake/Modules/Platform/Emscripten.cmake")
    set(_canis_emscripten_toolchain "/usr/share/emscripten/cmake/Modules/Platform/Emscripten.cmake")
endif()

if(_canis_emscripten_toolchain STREQUAL "")
    message(FATAL_ERROR
        "Could not locate the Emscripten CMake toolchain. "
        "Set EMSDK/EMSCRIPTEN or install the toolchain under /usr/share/emscripten.")
endif()

include("${_canis_emscripten_toolchain}")
