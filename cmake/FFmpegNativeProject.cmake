include_guard(GLOBAL)

include(GNUInstallDirs)
include(CMakePackageConfigHelpers)

set(FFMPEG_NATIVE_COMPONENTS "avutil;swresample" CACHE STRING "Native CMake FFmpeg components to build. Current backend supports avutil and swresample.")
option(FFMPEG_NATIVE_ENABLE_ASM "Enable native CMake assembly integration when implemented for this platform" OFF)
option(FFMPEG_NATIVE_ENABLE_THREADS "Enable FFmpeg threading support in the native CMake backend" OFF)

function(_ffmpeg_native_bool _out _value)
    if(${_value})
        set(${_out} 1 PARENT_SCOPE)
    else()
        set(${_out} 0 PARENT_SCOPE)
    endif()
endfunction()

function(_ffmpeg_native_collect_macros _out)
    set(_ffmpeg_scan_globs "${FFMPEG_SOURCE_DIR}/compat/*.[ch]")
    foreach(_ffmpeg_component IN LISTS FFMPEG_NATIVE_COMPONENTS)
        list(APPEND _ffmpeg_scan_globs "${FFMPEG_SOURCE_DIR}/lib${_ffmpeg_component}/*.[ch]")
    endforeach()
    list(REMOVE_DUPLICATES _ffmpeg_scan_globs)

    file(GLOB_RECURSE _ffmpeg_files CONFIGURE_DEPENDS ${_ffmpeg_scan_globs})

    set(_ffmpeg_macros)
    foreach(_ffmpeg_file IN LISTS _ffmpeg_files)
        file(READ "${_ffmpeg_file}" _ffmpeg_text)
        string(REGEX MATCHALL "(CONFIG|HAVE|ARCH)_[A-Z0-9_]+" _ffmpeg_file_macros "${_ffmpeg_text}")
        list(APPEND _ffmpeg_macros ${_ffmpeg_file_macros})
    endforeach()

    list(APPEND _ffmpeg_macros
        ARCH_AARCH64 ARCH_ARM ARCH_X86 ARCH_X86_32 ARCH_X86_64
        CONFIG_AVUTIL CONFIG_SWRESAMPLE CONFIG_STATIC CONFIG_SHARED
        HAVE_BIGENDIAN HAVE_FAST_UNALIGNED HAVE_THREADS HAVE_PTHREADS HAVE_W32THREADS)
    list(REMOVE_DUPLICATES _ffmpeg_macros)
    list(SORT _ffmpeg_macros)
    set(${_out} "${_ffmpeg_macros}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_collect_makefile_objects _out _library _variable)
    set(_ffmpeg_makefile "${FFMPEG_SOURCE_DIR}/lib${_library}/Makefile")
    file(STRINGS "${_ffmpeg_makefile}" _ffmpeg_makefile_lines)

    set(_ffmpeg_block)
    set(_ffmpeg_active FALSE)
    foreach(_ffmpeg_line IN LISTS _ffmpeg_makefile_lines)
        if(NOT _ffmpeg_active AND _ffmpeg_line MATCHES "^${_variable}[ \t]*=")
            set(_ffmpeg_active TRUE)
            string(REGEX REPLACE "^${_variable}[ \t]*=" "" _ffmpeg_line "${_ffmpeg_line}")
        elseif(NOT _ffmpeg_active)
            continue()
        endif()

        string(REGEX REPLACE "#.*$" "" _ffmpeg_line "${_ffmpeg_line}")
        string(REGEX REPLACE "[ \t]+$" "" _ffmpeg_line "${_ffmpeg_line}")
        if(_ffmpeg_line MATCHES "\\\\$")
            string(REGEX REPLACE "\\\\$" "" _ffmpeg_line "${_ffmpeg_line}")
            string(APPEND _ffmpeg_block " ${_ffmpeg_line}")
        else()
            string(APPEND _ffmpeg_block " ${_ffmpeg_line}")
            break()
        endif()
    endforeach()

    if(NOT _ffmpeg_active)
        message(FATAL_ERROR "Could not find ${_variable} in ${_ffmpeg_makefile}")
    endif()

    string(REGEX MATCHALL "[A-Za-z0-9_./+-]+\\.o" _ffmpeg_objects "${_ffmpeg_block}")

    set(_ffmpeg_sources)
    foreach(_ffmpeg_object IN LISTS _ffmpeg_objects)
        string(REGEX REPLACE "\\.o$" ".c" _ffmpeg_source "${_ffmpeg_object}")
        set(_ffmpeg_source_path "${FFMPEG_SOURCE_DIR}/lib${_library}/${_ffmpeg_source}")
        if(EXISTS "${_ffmpeg_source_path}")
            list(APPEND _ffmpeg_sources "${_ffmpeg_source_path}")
        else()
            message(VERBOSE "Skipping native source without C implementation: lib${_library}/${_ffmpeg_source}")
        endif()
    endforeach()

    list(REMOVE_DUPLICATES _ffmpeg_sources)
    set(${_out} "${_ffmpeg_sources}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_write_file_if_changed _path _content)
    if(EXISTS "${_path}")
        file(READ "${_path}" _ffmpeg_existing)
    else()
        set(_ffmpeg_existing)
    endif()
    if(NOT _ffmpeg_existing STREQUAL _content)
        file(WRITE "${_path}" "${_content}")
    endif()
endfunction()

function(_ffmpeg_native_write_config_headers)
    set(_ffmpeg_generated_dir "${CMAKE_CURRENT_BINARY_DIR}/ffmpeg-native")
    file(MAKE_DIRECTORY
        "${_ffmpeg_generated_dir}"
        "${_ffmpeg_generated_dir}/libavcodec"
        "${_ffmpeg_generated_dir}/libavdevice"
        "${_ffmpeg_generated_dir}/libavfilter"
        "${_ffmpeg_generated_dir}/libavformat"
        "${_ffmpeg_generated_dir}/libavutil")

    _ffmpeg_native_collect_macros(_ffmpeg_macros)

    set(_ffmpeg_enabled_macros CONFIG_STATIC CONFIG_AVUTIL)
    list(FIND FFMPEG_NATIVE_COMPONENTS swresample _ffmpeg_has_swresample)
    if(NOT _ffmpeg_has_swresample EQUAL -1)
        list(APPEND _ffmpeg_enabled_macros CONFIG_SWRESAMPLE)
    endif()

    if(CMAKE_SIZEOF_VOID_P EQUAL 8)
        if(CMAKE_SYSTEM_PROCESSOR MATCHES "^(x86_64|AMD64|amd64|x64)$")
            list(APPEND _ffmpeg_enabled_macros ARCH_X86 ARCH_X86_64 HAVE_FAST_UNALIGNED)
        elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "^(aarch64|ARM64|arm64)$")
            list(APPEND _ffmpeg_enabled_macros ARCH_AARCH64)
        endif()
    else()
        if(CMAKE_SYSTEM_PROCESSOR MATCHES "^(x86|i[3-6]86|X86)$")
            list(APPEND _ffmpeg_enabled_macros ARCH_X86 ARCH_X86_32 HAVE_FAST_UNALIGNED)
        elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "^(arm|ARM)")
            list(APPEND _ffmpeg_enabled_macros ARCH_ARM)
        endif()
    endif()

    if(FFMPEG_NATIVE_ENABLE_THREADS)
        list(APPEND _ffmpeg_enabled_macros HAVE_THREADS)
        if(WIN32)
            list(APPEND _ffmpeg_enabled_macros HAVE_W32THREADS)
        else()
            list(APPEND _ffmpeg_enabled_macros HAVE_PTHREADS)
        endif()
    endif()

    if(WIN32)
        list(APPEND _ffmpeg_enabled_macros
            HAVE_COMMANDLINETOARGVW
            HAVE_GETENV
            HAVE_GETMODULEHANDLE
            HAVE_GETPROCESSAFFINITYMASK
            HAVE_GETSTDHANDLE
            HAVE_GETSYSTEMTIMEASFILETIME
            HAVE_IO_H
            HAVE_LIBC_MSVCRT
            HAVE_MAPVIEWOFFILE
            HAVE_SETCONSOLETEXTATTRIBUTE
            HAVE_VIRTUALALLOC)
    else()
        list(APPEND _ffmpeg_enabled_macros
            HAVE_ACCESS
            HAVE_CLOCK_GETTIME
            HAVE_FCNTL
            HAVE_GETENV
            HAVE_GETTIMEOFDAY
            HAVE_ISATTY
            HAVE_LSTAT
            HAVE_MKSTEMP
            HAVE_MMAP
            HAVE_POSIX_MEMALIGN
            HAVE_SYSCONF
            HAVE_UNISTD_H)
    endif()

    set(_ffmpeg_config "/* Generated by ffmpeg-cmake native backend. */\n#ifndef FFMPEG_CONFIG_H\n#define FFMPEG_CONFIG_H\n")
    string(APPEND _ffmpeg_config "#define FFMPEG_CONFIGURATION \"ffmpeg-cmake native backend\"\n")
    string(APPEND _ffmpeg_config "#define FFMPEG_LICENSE \"LGPL version 2.1 or later\"\n")
    string(APPEND _ffmpeg_config "#define CONFIG_THIS_YEAR 2026\n")
    string(APPEND _ffmpeg_config "#define FFMPEG_DATADIR \"${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_DATADIR}/ffmpeg\"\n")
    string(APPEND _ffmpeg_config "#define AVCONV_DATADIR FFMPEG_DATADIR\n")
    string(APPEND _ffmpeg_config "#define CC_IDENT \"${CMAKE_C_COMPILER_ID} ${CMAKE_C_COMPILER_VERSION}\"\n")
    if(WIN32)
        string(APPEND _ffmpeg_config "#define OS_NAME win32\n")
        string(APPEND _ffmpeg_config "#define SLIBSUF \".dll\"\n")
    elseif(APPLE)
        string(APPEND _ffmpeg_config "#define OS_NAME darwin\n")
        string(APPEND _ffmpeg_config "#define SLIBSUF \".dylib\"\n")
    else()
        string(APPEND _ffmpeg_config "#define OS_NAME linux\n")
        string(APPEND _ffmpeg_config "#define SLIBSUF \".so\"\n")
    endif()
    string(APPEND _ffmpeg_config "#define EXTERN_PREFIX \"\"\n#define EXTERN_ASM\n#define BUILDSUF \"\"\n#define SWS_MAX_FILTER_SIZE 256\n")

    list(APPEND _ffmpeg_enabled_macros
        HAVE_ATANF
        HAVE_ATAN2F
        HAVE_CBRT
        HAVE_CBRTF
        HAVE_COPYSIGN
        HAVE_COSF
        HAVE_ERF
        HAVE_EXPF
        HAVE_EXP2
        HAVE_EXP2F
        HAVE_HYPOT
        HAVE_ISFINITE
        HAVE_ISINF
        HAVE_ISNAN
        HAVE_LDEXPF
        HAVE_LLRINT
        HAVE_LLRINTF
        HAVE_LOG2
        HAVE_LOG2F
        HAVE_LOG10F
        HAVE_LRINT
        HAVE_LRINTF
        HAVE_POWF
        HAVE_RINT
        HAVE_ROUND
        HAVE_ROUNDF
        HAVE_SINF
        HAVE_TRUNC
        HAVE_TRUNCF)

    foreach(_ffmpeg_macro IN LISTS _ffmpeg_macros)
        if(_ffmpeg_macro STREQUAL "HAVE_AV_CONFIG_H" OR
           _ffmpeg_macro STREQUAL "CONFIG_THIS_YEAR" OR
           _ffmpeg_macro STREQUAL "HAVE_6REGS" OR
           _ffmpeg_macro STREQUAL "HAVE_7REGS")
            continue()
        endif()
        list(FIND _ffmpeg_enabled_macros "${_ffmpeg_macro}" _ffmpeg_enabled_index)
        if(_ffmpeg_enabled_index EQUAL -1)
            string(APPEND _ffmpeg_config "#define ${_ffmpeg_macro} 0\n")
        else()
            string(APPEND _ffmpeg_config "#define ${_ffmpeg_macro} 1\n")
        endif()
    endforeach()
    string(APPEND _ffmpeg_config "#endif /* FFMPEG_CONFIG_H */\n")
    _ffmpeg_native_write_file_if_changed("${_ffmpeg_generated_dir}/config.h" "${_ffmpeg_config}")

    set(_ffmpeg_components "/* Generated by ffmpeg-cmake native backend. */\n#ifndef FFMPEG_CONFIG_COMPONENTS_H\n#define FFMPEG_CONFIG_COMPONENTS_H\n")
    foreach(_ffmpeg_macro IN LISTS _ffmpeg_macros)
        if(_ffmpeg_macro MATCHES "^CONFIG_")
            list(FIND _ffmpeg_enabled_macros "${_ffmpeg_macro}" _ffmpeg_enabled_index)
            if(_ffmpeg_enabled_index EQUAL -1)
                string(APPEND _ffmpeg_components "#define ${_ffmpeg_macro} 0\n")
            else()
                string(APPEND _ffmpeg_components "#define ${_ffmpeg_macro} 1\n")
            endif()
        endif()
    endforeach()
    string(APPEND _ffmpeg_components "#endif /* FFMPEG_CONFIG_COMPONENTS_H */\n")
    _ffmpeg_native_write_file_if_changed("${_ffmpeg_generated_dir}/config_components.h" "${_ffmpeg_components}")

    set(_ffmpeg_fast_unaligned 0)
    list(FIND _ffmpeg_enabled_macros HAVE_FAST_UNALIGNED _ffmpeg_fast_unaligned_index)
    if(NOT _ffmpeg_fast_unaligned_index EQUAL -1)
        set(_ffmpeg_fast_unaligned 1)
    endif()
    set(_ffmpeg_avconfig "/* Generated by ffmpeg-cmake native backend. */\n#ifndef AVUTIL_AVCONFIG_H\n#define AVUTIL_AVCONFIG_H\n#define AV_HAVE_BIGENDIAN 0\n#define AV_HAVE_FAST_UNALIGNED ${_ffmpeg_fast_unaligned}\n#endif /* AVUTIL_AVCONFIG_H */\n")
    _ffmpeg_native_write_file_if_changed("${_ffmpeg_generated_dir}/libavutil/avconfig.h" "${_ffmpeg_avconfig}")

    set(_ffmpeg_ffversion "/* Generated by ffmpeg-cmake native backend. */\n#ifndef AVUTIL_FFVERSION_H\n#define AVUTIL_FFVERSION_H\n#define FFMPEG_VERSION \"native-cmake\"\n#endif /* AVUTIL_FFVERSION_H */\n")
    _ffmpeg_native_write_file_if_changed("${_ffmpeg_generated_dir}/libavutil/ffversion.h" "${_ffmpeg_ffversion}")

    _ffmpeg_native_write_file_if_changed("${_ffmpeg_generated_dir}/libavcodec/codec_list.c" "static const FFCodec * const codec_list[] = { NULL };\n")
    _ffmpeg_native_write_file_if_changed("${_ffmpeg_generated_dir}/libavcodec/parser_list.c" "static const FFCodecParser * const parser_list[] = { NULL };\n")
    _ffmpeg_native_write_file_if_changed("${_ffmpeg_generated_dir}/libavcodec/bsf_list.c" "static const FFBitStreamFilter * const bitstream_filters[] = { NULL };\n")
    _ffmpeg_native_write_file_if_changed("${_ffmpeg_generated_dir}/libavformat/protocol_list.c" "static const URLProtocol * const url_protocols[] = { NULL };\n")
    _ffmpeg_native_write_file_if_changed("${_ffmpeg_generated_dir}/libavformat/muxer_list.c" "static const FFOutputFormat * const muxer_list[] = { NULL };\n")
    _ffmpeg_native_write_file_if_changed("${_ffmpeg_generated_dir}/libavformat/demuxer_list.c" "static const FFInputFormat * const demuxer_list[] = { NULL };\n")
    _ffmpeg_native_write_file_if_changed("${_ffmpeg_generated_dir}/libavfilter/filter_list.c" "static const AVFilter * const filter_list[] = { NULL };\n")
    _ffmpeg_native_write_file_if_changed("${_ffmpeg_generated_dir}/libavdevice/indev_list.c" "static const FFInputFormat * const indev_list[] = { NULL };\n")
    _ffmpeg_native_write_file_if_changed("${_ffmpeg_generated_dir}/libavdevice/outdev_list.c" "static const FFOutputFormat * const outdev_list[] = { NULL };\n")

    set(FFMPEG_NATIVE_GENERATED_DIR "${_ffmpeg_generated_dir}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_library_type _out)
    if(FFMPEG_BUILD_SHARED AND FFMPEG_BUILD_STATIC)
        if(MSVC OR WIN32)
            message(FATAL_ERROR "The native MSVC/Windows backend cannot build static and shared FFmpeg libraries in one configuration. Pick one of FFMPEG_BUILD_STATIC or FFMPEG_BUILD_SHARED.")
        endif()
    endif()
    if(FFMPEG_BUILD_SHARED)
        set(${_out} SHARED PARENT_SCOPE)
    else()
        set(${_out} STATIC PARENT_SCOPE)
    endif()
endfunction()

function(_ffmpeg_native_add_library _component)
    _ffmpeg_native_library_type(_ffmpeg_library_type)
    _ffmpeg_native_collect_makefile_objects(_ffmpeg_sources "${_component}" OBJS)

    add_library(${_component} ${_ffmpeg_library_type} ${_ffmpeg_sources})
    add_library(FFmpeg::${_component} ALIAS ${_component})
    target_include_directories(${_component}
        PUBLIC
            "$<BUILD_INTERFACE:${FFMPEG_SOURCE_DIR}>"
            "$<BUILD_INTERFACE:${FFMPEG_NATIVE_GENERATED_DIR}>"
            "$<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>")
    target_compile_definitions(${_component}
        PRIVATE
            HAVE_AV_CONFIG_H
            BUILDING_${_component})
    if(MSVC)
        target_compile_definitions(${_component} PRIVATE inline=__inline)
        target_compile_options(${_component} PRIVATE /utf-8 /wd4244 /wd4267 /wd4996)
    endif()
    set_target_properties(${_component} PROPERTIES
        OUTPUT_NAME "${_component}"
        POSITION_INDEPENDENT_CODE ${FFMPEG_BUILD_SHARED})

    install(TARGETS ${_component}
        EXPORT FFmpegNativeTargets
        ARCHIVE DESTINATION "${CMAKE_INSTALL_LIBDIR}"
        LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}"
        RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}")
endfunction()

function(_ffmpeg_native_install_headers)
    foreach(_ffmpeg_component IN LISTS FFMPEG_NATIVE_COMPONENTS)
        install(DIRECTORY "${FFMPEG_SOURCE_DIR}/lib${_ffmpeg_component}/"
            DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/lib${_ffmpeg_component}"
            FILES_MATCHING PATTERN "*.h")
        if(IS_DIRECTORY "${FFMPEG_NATIVE_GENERATED_DIR}/lib${_ffmpeg_component}")
            install(DIRECTORY "${FFMPEG_NATIVE_GENERATED_DIR}/lib${_ffmpeg_component}/"
                DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/lib${_ffmpeg_component}"
                FILES_MATCHING PATTERN "*.h")
        endif()
    endforeach()
endfunction()

function(ffmpeg_add_native_project)
    if(NOT EXISTS "${FFMPEG_SOURCE_DIR}/libavutil/Makefile")
        message(FATAL_ERROR "FFMPEG_SOURCE_DIR does not look like an FFmpeg source tree: ${FFMPEG_SOURCE_DIR}")
    endif()
    if(FFMPEG_NATIVE_ENABLE_ASM)
        message(FATAL_ERROR "FFMPEG_NATIVE_ENABLE_ASM is not implemented yet. Keep it OFF for native MSVC/clang-cl builds.")
    endif()

    foreach(_ffmpeg_component IN LISTS FFMPEG_NATIVE_COMPONENTS)
        if(NOT _ffmpeg_component IN_LIST FFMPEG_IMPORT_COMPONENTS)
            message(FATAL_ERROR "Unknown native FFmpeg component '${_ffmpeg_component}'")
        endif()
        if(NOT _ffmpeg_component STREQUAL "avutil" AND NOT _ffmpeg_component STREQUAL "swresample")
            message(FATAL_ERROR "The native CMake backend currently supports avutil and swresample only. '${_ffmpeg_component}' still requires the OFFICIAL_CONFIGURE backend.")
        endif()
    endforeach()

    list(FIND FFMPEG_NATIVE_COMPONENTS avutil _ffmpeg_has_avutil)
    if(_ffmpeg_has_avutil EQUAL -1)
        message(FATAL_ERROR "The native backend currently requires avutil in FFMPEG_NATIVE_COMPONENTS")
    endif()

    _ffmpeg_native_write_config_headers()
    _ffmpeg_native_add_library(avutil)

    list(FIND FFMPEG_NATIVE_COMPONENTS swresample _ffmpeg_has_swresample)
    if(NOT _ffmpeg_has_swresample EQUAL -1)
        _ffmpeg_native_add_library(swresample)
        target_link_libraries(swresample PUBLIC FFmpeg::avutil)
    endif()

    if(TARGET swresample)
        add_library(FFmpeg_native_aggregate INTERFACE)
        target_link_libraries(FFmpeg_native_aggregate INTERFACE FFmpeg::swresample FFmpeg::avutil)
    else()
        add_library(FFmpeg_native_aggregate INTERFACE)
        target_link_libraries(FFmpeg_native_aggregate INTERFACE FFmpeg::avutil)
    endif()
    add_library(FFmpeg::FFmpeg ALIAS FFmpeg_native_aggregate)

    install(EXPORT FFmpegNativeTargets
        NAMESPACE FFmpeg::
        DESTINATION "${CMAKE_INSTALL_LIBDIR}/cmake/FFmpeg")
    _ffmpeg_native_install_headers()
endfunction()
