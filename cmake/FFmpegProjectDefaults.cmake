include_guard(GLOBAL)

function(_ffmpeg_cache_default _name _type _value _help)
    if(NOT DEFINED ${_name})
        set(${_name} "${_value}" CACHE ${_type} "${_help}")
    else()
        set(${_name} "${${_name}}" CACHE ${_type} "${_help}")
    endif()
    set_property(CACHE ${_name} PROPERTY HELPSTRING "${_help}")
endfunction()

function(ffmpeg_enable_ide_folders)
    set_property(GLOBAL PROPERTY USE_FOLDERS ON)
    set_property(GLOBAL PROPERTY PREDEFINED_TARGETS_FOLDER "CMake/Targets")
endfunction()

function(ffmpeg_set_target_folder _target _folder)
    if(TARGET "${_target}")
        set_target_properties("${_target}" PROPERTIES FOLDER "${_folder}")
    endif()
endfunction()

function(ffmpeg_cache_common_cmake_options)
    _ffmpeg_cache_default(CMAKE_PREFIX_PATH STRING ""
        "Semicolon-separated install prefixes searched for FFmpeg and third-party dependencies.")
    _ffmpeg_cache_default(CMAKE_POSITION_INDEPENDENT_CODE BOOL OFF
        "Build position-independent code. Enable this for shared-library consumers that link static FFmpeg libraries.")
    _ffmpeg_cache_default(CMAKE_C_STANDARD STRING 11
        "C language standard used for FFmpeg sources. FFmpeg needs at least C11.")
    _ffmpeg_cache_default(CMAKE_C_STANDARD_REQUIRED BOOL ON
        "Require the selected C standard instead of silently falling back to an older compiler mode.")
    _ffmpeg_cache_default(CMAKE_C_EXTENSIONS BOOL ON
        "Allow compiler C extensions where they are the platform default. MSVC still uses C11 mode.")
    _ffmpeg_cache_default(CMAKE_CXX_STANDARD STRING 17
        "C++ language standard used by helper code or future C++ targets in this project.")
    _ffmpeg_cache_default(CMAKE_CXX_STANDARD_REQUIRED BOOL ON
        "Require the selected C++ standard instead of silently falling back to an older compiler mode.")
    _ffmpeg_cache_default(CMAKE_CXX_EXTENSIONS BOOL OFF
        "Use standard C++17 mode for C++ targets instead of compiler-specific extension mode.")

    if(WIN32)
        _ffmpeg_cache_default(CMAKE_DEBUG_POSTFIX STRING "d"
            "Suffix appended to Debug library and executable names on Windows.")
    endif()
endfunction()

function(ffmpeg_apply_msvc_runtime_default)
    if(NOT MSVC)
        return()
    endif()

    if(DEFINED CMAKE_MSVC_RUNTIME_LIBRARY)
        set(CMAKE_MSVC_RUNTIME_LIBRARY "${CMAKE_MSVC_RUNTIME_LIBRARY}" CACHE STRING "MSVC runtime selection for generated targets, for example MultiThreaded or MultiThreadedDLL.")
        set_property(CACHE CMAKE_MSVC_RUNTIME_LIBRARY PROPERTY HELPSTRING "MSVC runtime selection for generated targets, for example MultiThreaded or MultiThreadedDLL.")
        return()
    endif()

    set(_ffmpeg_static_runtime FALSE)
    if(FFMPEG_BUILD_FROM_SOURCE AND FFMPEG_BUILD_STATIC AND NOT FFMPEG_BUILD_SHARED)
        set(_ffmpeg_static_runtime TRUE)
    endif()
    if(FFMPEG_FIND_INSTALLED AND FFmpeg_USE_STATIC_LIBS)
        set(_ffmpeg_static_runtime TRUE)
    endif()

    if(_ffmpeg_static_runtime)
        set(_ffmpeg_msvc_runtime "$<$<CONFIG:Debug>:MultiThreadedDebug>$<$<CONFIG:Release>:MultiThreaded>")
    else()
        set(_ffmpeg_msvc_runtime "MultiThreaded$<$<CONFIG:Debug>:Debug>DLL")
    endif()

    set(CMAKE_MSVC_RUNTIME_LIBRARY "${_ffmpeg_msvc_runtime}" CACHE STRING "MSVC runtime selection for generated targets, for example MultiThreaded or MultiThreadedDLL.")
    set_property(CACHE CMAKE_MSVC_RUNTIME_LIBRARY PROPERTY HELPSTRING "MSVC runtime selection for generated targets, for example MultiThreaded or MultiThreadedDLL.")
endfunction()
