include_guard(GLOBAL)

include(GNUInstallDirs)
include(CMakePackageConfigHelpers)
include(FFmpegNativeAutoconfig)
include(FFmpegNativeDependencies)

set(FFMPEG_NATIVE_COMPONENTS "avutil;swresample;swscale;avcodec;avformat;avfilter;avdevice" CACHE STRING "FFmpeg libraries to build with the native CMake backend.")
option(FFMPEG_NATIVE_ENABLE_ASM "Enable x86/x86_64 NASM assembly in the native CMake backend. Requires FFMPEG_X86ASM or nasm in PATH." OFF)
option(FFMPEG_NATIVE_ENABLE_X86_TX_ASM "Enable x86 floating-point transform assembly used by AAC/MDCT. Requires aligned allocation support; turn this OFF only as a toolchain fallback." ON)
option(FFMPEG_NATIVE_ENABLE_THREADS "Enable thread support in the native CMake backend." ON)
option(FFMPEG_NATIVE_BUILD_FFMPEG "Build the ffmpeg command line tool with the native CMake backend." ON)
option(FFMPEG_NATIVE_BUILD_FFPROBE "Build the ffprobe command line tool with the native CMake backend." ON)
option(FFMPEG_NATIVE_BUILD_FFPLAY "Build the ffplay command line tool with the native CMake backend. Requires SDL2 in CMAKE_PREFIX_PATH or pkg-config." OFF)
option(FFMPEG_NATIVE_BUILD_EXAMPLES "Build FFmpeg doc/examples as native CMake executable targets." OFF)
option(FFMPEG_NATIVE_INSTALL_RUNTIME_DEPENDENCIES "Install runtime DLL/shared-library dependencies found through CMAKE_PREFIX_PATH for native FFmpeg tools and shared libraries." ON)
option(FFMPEG_NATIVE_ENABLE_DEFAULT_COMPONENTS "Enable a default set of FFmpeg media components. Turn OFF for a minimal build controlled only by explicit FFMPEG_ENABLE_* lists." ON)
set(FFMPEG_NATIVE_DEFAULT_COMPONENT_SET "COMMON" CACHE STRING "Default native component set: COMMON enables normal local media playback/transcoding basics; ALL tries every FFmpeg built-in component and may require more dependency detection work; NONE keeps registries empty unless explicit FFMPEG_ENABLE_* lists are set.")
set_property(CACHE FFMPEG_NATIVE_DEFAULT_COMPONENT_SET PROPERTY STRINGS COMMON ALL NONE)

set(FFMPEG_NATIVE_EFFECTIVE_ENABLE_ASM "${FFMPEG_NATIVE_ENABLE_ASM}")
if(asm IN_LIST FFMPEG_DISABLE_FEATURES OR x86asm IN_LIST FFMPEG_DISABLE_FEATURES)
    set(FFMPEG_NATIVE_EFFECTIVE_ENABLE_ASM OFF)
endif()
set(FFMPEG_NATIVE_EFFECTIVE_ENABLE_X86_TX_ASM OFF)
if(FFMPEG_NATIVE_EFFECTIVE_ENABLE_ASM AND FFMPEG_NATIVE_ENABLE_X86_TX_ASM)
    set(FFMPEG_NATIVE_EFFECTIVE_ENABLE_X86_TX_ASM ON)
endif()

include("${CMAKE_CURRENT_LIST_DIR}/native/FFmpegNativeTargetSettings.cmake")

if(FFMPEG_NATIVE_EFFECTIVE_ENABLE_ASM)
    if(NOT FFMPEG_X86ASM)
        message(FATAL_ERROR "FFMPEG_NATIVE_ENABLE_ASM requires a NASM-compatible assembler. Set FFMPEG_X86ASM or make nasm available in PATH.")
    endif()
    _ffmpeg_native_nasm_object_format(_ffmpeg_nasm_format)
    if(NOT DEFINED CMAKE_ASM_NASM_OBJECT_FORMAT OR CMAKE_ASM_NASM_OBJECT_FORMAT STREQUAL "")
        set(CMAKE_ASM_NASM_OBJECT_FORMAT "${_ffmpeg_nasm_format}" CACHE STRING "Object file format passed to NASM for FFmpeg native assembly." FORCE)
    endif()
    set(CMAKE_ASM_NASM_COMPILER "${FFMPEG_X86ASM}" CACHE FILEPATH "NASM-compatible assembler executable used by CMake for FFmpeg native assembly." FORCE)
    enable_language(ASM_NASM)
endif()

include("${CMAKE_CURRENT_LIST_DIR}/native/FFmpegNativeGeneratedFiles.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/native/FFmpegNativeSources.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/native/FFmpegNativeTargets.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/native/FFmpegNativeCoverage.cmake")

function(ffmpeg_add_native_project)
    if(NOT EXISTS "${FFMPEG_SOURCE_DIR}/libavutil/Makefile")
        message(FATAL_ERROR "FFMPEG_SOURCE_DIR does not look like an FFmpeg source tree: ${FFMPEG_SOURCE_DIR}")
    endif()

    _ffmpeg_native_resolve_components(_ffmpeg_effective_components)
    set(FFMPEG_NATIVE_COMPONENTS "${_ffmpeg_effective_components}")

    foreach(_ffmpeg_component IN LISTS FFMPEG_NATIVE_COMPONENTS)
        if(NOT _ffmpeg_component IN_LIST FFMPEG_IMPORT_COMPONENTS)
            message(FATAL_ERROR "Unknown native FFmpeg component '${_ffmpeg_component}'")
        endif()
        if(NOT _ffmpeg_component STREQUAL "avutil" AND
           NOT _ffmpeg_component STREQUAL "swresample" AND
           NOT _ffmpeg_component STREQUAL "swscale" AND
           NOT _ffmpeg_component STREQUAL "avcodec" AND
           NOT _ffmpeg_component STREQUAL "avformat" AND
           NOT _ffmpeg_component STREQUAL "avfilter" AND
           NOT _ffmpeg_component STREQUAL "avdevice")
            message(FATAL_ERROR "The native CMake backend currently supports FFmpeg libraries only. '${_ffmpeg_component}' still requires the OFFICIAL_CONFIGURE backend.")
        endif()
    endforeach()

    list(FIND FFMPEG_NATIVE_COMPONENTS avutil _ffmpeg_has_avutil)
    if(_ffmpeg_has_avutil EQUAL -1)
        message(FATAL_ERROR "The native backend currently requires avutil in FFMPEG_NATIVE_COMPONENTS")
    endif()

    _ffmpeg_native_write_config_headers()
    _ffmpeg_native_setup_asm_language()
    _ffmpeg_native_add_library(avutil)

    list(FIND FFMPEG_NATIVE_COMPONENTS swresample _ffmpeg_has_swresample)
    if(NOT _ffmpeg_has_swresample EQUAL -1)
        _ffmpeg_native_add_library(swresample)
        target_link_libraries(swresample PUBLIC FFmpeg::avutil)
    endif()

    list(FIND FFMPEG_NATIVE_COMPONENTS swscale _ffmpeg_has_swscale)
    if(NOT _ffmpeg_has_swscale EQUAL -1)
        _ffmpeg_native_add_library(swscale)
        target_link_libraries(swscale PUBLIC FFmpeg::avutil)
    endif()

    list(FIND FFMPEG_NATIVE_COMPONENTS avcodec _ffmpeg_has_avcodec)
    if(NOT _ffmpeg_has_avcodec EQUAL -1)
        _ffmpeg_native_add_library(avcodec)
        target_link_libraries(avcodec PUBLIC FFmpeg::avutil)
    endif()

    list(FIND FFMPEG_NATIVE_COMPONENTS avformat _ffmpeg_has_avformat)
    if(NOT _ffmpeg_has_avformat EQUAL -1)
        if(_ffmpeg_has_avcodec EQUAL -1)
            message(FATAL_ERROR "The native avformat target requires avcodec in FFMPEG_NATIVE_COMPONENTS")
        endif()
        _ffmpeg_native_add_library(avformat)
        target_link_libraries(avformat PUBLIC FFmpeg::avcodec FFmpeg::avutil)
    endif()

    list(FIND FFMPEG_NATIVE_COMPONENTS avfilter _ffmpeg_has_avfilter)
    if(NOT _ffmpeg_has_avfilter EQUAL -1)
        _ffmpeg_native_add_library(avfilter)
        target_link_libraries(avfilter PUBLIC FFmpeg::avutil)
        foreach(_ffmpeg_filter_dep IN ITEMS avformat avcodec swresample swscale)
            if(TARGET ${_ffmpeg_filter_dep})
                target_link_libraries(avfilter PUBLIC FFmpeg::${_ffmpeg_filter_dep})
            endif()
        endforeach()
    endif()

    list(FIND FFMPEG_NATIVE_COMPONENTS avdevice _ffmpeg_has_avdevice)
    if(NOT _ffmpeg_has_avdevice EQUAL -1)
        if(_ffmpeg_has_avformat EQUAL -1 OR _ffmpeg_has_avcodec EQUAL -1)
            message(FATAL_ERROR "The native avdevice target requires avformat and avcodec in FFMPEG_NATIVE_COMPONENTS")
        endif()
        _ffmpeg_native_add_library(avdevice)
        target_link_libraries(avdevice PUBLIC FFmpeg::avformat FFmpeg::avcodec FFmpeg::avutil)
        if(TARGET avfilter)
            target_link_libraries(avdevice PUBLIC FFmpeg::avfilter)
        endif()
    endif()

    ffmpeg_native_import_dependencies(_ffmpeg_native_dependency_file _ffmpeg_native_dependency_targets)
    if(_ffmpeg_native_dependency_targets)
        foreach(_ffmpeg_component IN ITEMS avutil swresample swscale avcodec avformat avfilter avdevice)
            if(TARGET ${_ffmpeg_component})
                target_link_libraries(${_ffmpeg_component} PUBLIC ${_ffmpeg_native_dependency_targets})
            endif()
        endforeach()
    endif()

    set(FFMPEG_NATIVE_PROGRAMS)
    if(FFMPEG_BUILD_PROGRAMS)
        foreach(_ffmpeg_program IN ITEMS ffmpeg ffprobe ffplay)
            _ffmpeg_native_add_program("${_ffmpeg_program}")
        endforeach()
        list(REMOVE_DUPLICATES FFMPEG_NATIVE_PROGRAMS)
        list(SORT FFMPEG_NATIVE_PROGRAMS)
    endif()

    set(FFMPEG_NATIVE_EXAMPLES)
    set(FFMPEG_NATIVE_EXAMPLE_TARGETS)
    if(FFMPEG_NATIVE_BUILD_EXAMPLES)
        _ffmpeg_native_add_examples()
        _ffmpeg_native_install_examples()
        list(REMOVE_DUPLICATES FFMPEG_NATIVE_EXAMPLES)
        list(SORT FFMPEG_NATIVE_EXAMPLES)
        list(REMOVE_DUPLICATES FFMPEG_NATIVE_EXAMPLE_TARGETS)
        list(SORT FFMPEG_NATIVE_EXAMPLE_TARGETS)
    endif()

    add_library(FFmpeg_native_aggregate INTERFACE)
    ffmpeg_set_target_folder(FFmpeg_native_aggregate "FFmpeg/Libraries")
    set(_ffmpeg_native_aggregate_libs)
    foreach(_ffmpeg_component IN ITEMS avdevice avfilter avformat avcodec swresample swscale avutil)
        if(TARGET ${_ffmpeg_component})
            list(APPEND _ffmpeg_native_aggregate_libs "FFmpeg::${_ffmpeg_component}")
        endif()
    endforeach()
    target_link_libraries(FFmpeg_native_aggregate INTERFACE ${_ffmpeg_native_aggregate_libs})
    add_library(FFmpeg::FFmpeg ALIAS FFmpeg_native_aggregate)

    install(EXPORT FFmpegNativeTargets
        NAMESPACE FFmpeg::
        DESTINATION "${CMAKE_INSTALL_LIBDIR}/cmake/FFmpeg")
    install(FILES "${_ffmpeg_native_dependency_file}"
        DESTINATION "${CMAKE_INSTALL_LIBDIR}/cmake/FFmpeg")
    _ffmpeg_native_install_headers()
    ffmpeg_native_write_coverage_report(_ffmpeg_native_coverage_file)

    foreach(_ffmpeg_report_var IN ITEMS
            FFMPEG_NATIVE_ALL_CONFIG_FEATURES
            FFMPEG_NATIVE_ALL_COMPONENT_FEATURES
            FFMPEG_NATIVE_ALL_HAVE_FEATURES
            FFMPEG_NATIVE_ALL_ARCH_FEATURES
            FFMPEG_NATIVE_ENABLED_CONFIG_FEATURES
            FFMPEG_NATIVE_ENABLED_COMPONENT_FEATURES
            FFMPEG_NATIVE_ENABLED_HAVE_FEATURES
            FFMPEG_NATIVE_ENABLED_ARCH_FEATURES
            FFMPEG_NATIVE_FOUND_EXTERNAL_DEPENDENCIES
            FFMPEG_NATIVE_MISSING_EXTERNAL_DEPENDENCIES
            FFMPEG_NATIVE_DEPENDENCY_TARGETS
            FFMPEG_NATIVE_LICENSE
            FFMPEG_NATIVE_COMPONENTS
            FFMPEG_NATIVE_PROGRAMS
            FFMPEG_NATIVE_EXAMPLES
            FFMPEG_NATIVE_EXAMPLE_TARGETS
            FFMPEG_NATIVE_COVERAGE_FILE
            FFMPEG_NATIVE_COVERAGE_SUMMARY
            FFMPEG_NATIVE_HARDWARE_ENABLED_FEATURES
            FFMPEG_NATIVE_HARDWARE_DISABLED_FEATURES)
        set(${_ffmpeg_report_var} "${${_ffmpeg_report_var}}" PARENT_SCOPE)
    endforeach()
endfunction()
