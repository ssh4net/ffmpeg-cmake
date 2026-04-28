include_guard(GLOBAL)

include(GNUInstallDirs)
include(CMakePackageConfigHelpers)
include(FFmpegNativeAutoconfig)
include(FFmpegNativeDependencies)

set(FFMPEG_NATIVE_COMPONENTS "avutil;swresample;swscale;avcodec;avformat;avfilter;avdevice" CACHE STRING "Native CMake FFmpeg library components to build.")
option(FFMPEG_NATIVE_ENABLE_ASM "Enable native CMake x86 NASM assembly integration when supported for this platform" OFF)
option(FFMPEG_NATIVE_ENABLE_THREADS "Enable FFmpeg threading support in the native CMake backend" ON)
option(FFMPEG_NATIVE_BUILD_FFMPEG "Build the native CMake ffmpeg command line program when FFMPEG_BUILD_PROGRAMS is enabled" ON)
option(FFMPEG_NATIVE_BUILD_FFPROBE "Build the native CMake ffprobe command line program when FFMPEG_BUILD_PROGRAMS is enabled" ON)
option(FFMPEG_NATIVE_BUILD_FFPLAY "Build the native CMake ffplay command line program when FFMPEG_BUILD_PROGRAMS is enabled" OFF)
option(FFMPEG_NATIVE_BUILD_EXAMPLES "Build FFmpeg doc/examples with the native CMake backend" OFF)

function(_ffmpeg_native_bool _out _value)
    if(${_value})
        set(${_out} 1 PARENT_SCOPE)
    else()
        set(${_out} 0 PARENT_SCOPE)
    endif()
endfunction()

function(_ffmpeg_native_extern_prefix _out)
    if(APPLE OR (WIN32 AND CMAKE_SIZEOF_VOID_P EQUAL 4))
        set(${_out} "_" PARENT_SCOPE)
    else()
        set(${_out} "" PARENT_SCOPE)
    endif()
endfunction()

function(_ffmpeg_native_nasm_object_format _out)
    if(WIN32)
        if(CMAKE_SIZEOF_VOID_P EQUAL 8)
            set(_ffmpeg_format win64)
        else()
            set(_ffmpeg_format win32)
        endif()
    elseif(APPLE)
        if(CMAKE_SIZEOF_VOID_P EQUAL 8)
            set(_ffmpeg_format macho64)
        else()
            set(_ffmpeg_format macho)
        endif()
    else()
        if(CMAKE_SIZEOF_VOID_P EQUAL 8)
            set(_ffmpeg_format elf64)
        else()
            set(_ffmpeg_format elf)
        endif()
    endif()
    set(${_out} "${_ffmpeg_format}" PARENT_SCOPE)
endfunction()

if(FFMPEG_NATIVE_ENABLE_ASM)
    if(NOT FFMPEG_X86ASM)
        message(FATAL_ERROR "FFMPEG_NATIVE_ENABLE_ASM requires a NASM-compatible assembler. Set FFMPEG_X86ASM or make nasm available in PATH.")
    endif()
    _ffmpeg_native_nasm_object_format(_ffmpeg_nasm_format)
    if(NOT DEFINED CMAKE_ASM_NASM_OBJECT_FORMAT OR CMAKE_ASM_NASM_OBJECT_FORMAT STREQUAL "")
        set(CMAKE_ASM_NASM_OBJECT_FORMAT "${_ffmpeg_nasm_format}" CACHE STRING "NASM object format for FFmpeg native assembly" FORCE)
    endif()
    set(CMAKE_ASM_NASM_COMPILER "${FFMPEG_X86ASM}" CACHE FILEPATH "NASM-compatible assembler for FFmpeg native assembly" FORCE)
    enable_language(ASM_NASM)
endif()

function(_ffmpeg_native_setup_asm_language)
    if(NOT FFMPEG_NATIVE_ENABLE_ASM)
        return()
    endif()

    list(FIND FFMPEG_NATIVE_ENABLED_ARCH_FEATURES x86 _ffmpeg_has_x86)
    if(_ffmpeg_has_x86 EQUAL -1)
        message(FATAL_ERROR "FFMPEG_NATIVE_ENABLE_ASM currently supports x86/x86_64 NASM only.")
    endif()
    if(NOT FFMPEG_X86ASM)
        message(FATAL_ERROR "FFMPEG_NATIVE_ENABLE_ASM requires a NASM-compatible assembler. Set FFMPEG_X86ASM or make nasm available in PATH.")
    endif()
endfunction()

function(_ffmpeg_native_apply_compile_settings _target)
    cmake_parse_arguments(_ffmpeg_settings "HAVE_AV_CONFIG_H" "" "" ${ARGN})
    if(_ffmpeg_settings_HAVE_AV_CONFIG_H)
        target_compile_definitions(${_target} PRIVATE HAVE_AV_CONFIG_H)
    endif()
    if(MSVC)
        target_compile_definitions(${_target} PRIVATE inline=__inline)
        target_compile_options(${_target} PRIVATE /utf-8 /wd4244 /wd4267 /wd4996)
    endif()
    if(FFMPEG_NATIVE_ENABLE_ASM)
        set(_ffmpeg_asm_include_dirs
            "${FFMPEG_NATIVE_GENERATED_DIR}"
            "${FFMPEG_SOURCE_DIR}"
            "${FFMPEG_SOURCE_DIR}/libavutil/x86"
            "${FFMPEG_SOURCE_DIR}/libavcodec/x86"
            "${FFMPEG_SOURCE_DIR}/libavfilter/x86"
            "${FFMPEG_SOURCE_DIR}/libswresample/x86"
            "${FFMPEG_SOURCE_DIR}/libswscale/x86")
        foreach(_ffmpeg_asm_include_dir IN LISTS _ffmpeg_asm_include_dirs)
            target_compile_options(${_target} PRIVATE "$<$<COMPILE_LANGUAGE:ASM_NASM>:-I${_ffmpeg_asm_include_dir}/>")
        endforeach()
        target_compile_options(${_target} PRIVATE "$<$<COMPILE_LANGUAGE:ASM_NASM>:-P${FFMPEG_NATIVE_GENERATED_DIR}/config.asm>")
        if(FFMPEG_BUILD_SHARED OR CMAKE_POSITION_INDEPENDENT_CODE)
            target_compile_options(${_target} PRIVATE "$<$<COMPILE_LANGUAGE:ASM_NASM>:-DPIC>")
        endif()
        _ffmpeg_native_extern_prefix(_ffmpeg_extern_prefix)
        if(_ffmpeg_extern_prefix)
            target_compile_options(${_target} PRIVATE "$<$<COMPILE_LANGUAGE:ASM_NASM>:-DPREFIX>")
        endif()
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

function(_ffmpeg_native_make_condition_enabled _out _condition)
    string(STRIP "${_condition}" _ffmpeg_condition)
    set(_ffmpeg_negated FALSE)
    if(_ffmpeg_condition MATCHES "^!([A-Za-z0-9_]+)$")
        set(_ffmpeg_negated TRUE)
        set(_ffmpeg_condition "${CMAKE_MATCH_1}")
    endif()

    list(FIND FFMPEG_NATIVE_ENABLED_OBJECT_MACROS "${_ffmpeg_condition}" _ffmpeg_condition_index)
    if(_ffmpeg_condition_index EQUAL -1)
        set(_ffmpeg_enabled FALSE)
    else()
        set(_ffmpeg_enabled TRUE)
    endif()

    if(_ffmpeg_negated)
        if(_ffmpeg_enabled)
            set(_ffmpeg_enabled FALSE)
        else()
            set(_ffmpeg_enabled TRUE)
        endif()
    endif()

    set(${_out} "${_ffmpeg_enabled}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_expand_make_conditionals _out _text)
    set(_ffmpeg_text "${_text}")
    foreach(_ffmpeg_unused RANGE 0 64)
        if(_ffmpeg_text MATCHES "\\$\\(if[ \t]+\\$\\((!?[A-Za-z0-9_]+)\\),[ \t]*([^\\)]*)\\)")
            set(_ffmpeg_expr "${CMAKE_MATCH_0}")
            set(_ffmpeg_condition "${CMAKE_MATCH_1}")
            set(_ffmpeg_true_value "${CMAKE_MATCH_2}")
            _ffmpeg_native_make_condition_enabled(_ffmpeg_condition_enabled "${_ffmpeg_condition}")
            if(_ffmpeg_condition_enabled)
                string(REPLACE "${_ffmpeg_expr}" "${_ffmpeg_true_value}" _ffmpeg_text "${_ffmpeg_text}")
            else()
                string(REPLACE "${_ffmpeg_expr}" "" _ffmpeg_text "${_ffmpeg_text}")
            endif()
        else()
            break()
        endif()
    endforeach()
    set(${_out} "${_ffmpeg_text}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_append_makefile_objects _objects_var _makefile _variable)
    file(STRINGS "${_makefile}" _ffmpeg_makefile_lines)

    set(_ffmpeg_active FALSE)
    set(_ffmpeg_include_block FALSE)
    set(_ffmpeg_rhs)
    foreach(_ffmpeg_line IN LISTS _ffmpeg_makefile_lines)
        string(REGEX REPLACE "#.*$" "" _ffmpeg_line "${_ffmpeg_line}")
        string(REGEX REPLACE "[ \t]+$" "" _ffmpeg_line "${_ffmpeg_line}")

        if(NOT _ffmpeg_active)
            if(_ffmpeg_line MATCHES "^${_variable}[ \t]*(\\+?=)[ \t]*(.*)$")
                set(_ffmpeg_active TRUE)
                set(_ffmpeg_include_block TRUE)
                set(_ffmpeg_line "${CMAKE_MATCH_2}")
            elseif(_ffmpeg_line MATCHES "^${_variable}-\\$\\((!?[A-Za-z0-9_]+)\\)[ \t]*\\+?=[ \t]*(.*)$")
                set(_ffmpeg_active TRUE)
                set(_ffmpeg_condition "${CMAKE_MATCH_1}")
                _ffmpeg_native_make_condition_enabled(_ffmpeg_include_block "${_ffmpeg_condition}")
                set(_ffmpeg_line "${CMAKE_MATCH_2}")
            else()
                continue()
            endif()
        endif()

        set(_ffmpeg_continues FALSE)
        if(_ffmpeg_line MATCHES "\\\\$")
            set(_ffmpeg_continues TRUE)
            string(REGEX REPLACE "\\\\$" "" _ffmpeg_line "${_ffmpeg_line}")
        endif()

        if(_ffmpeg_include_block)
            string(APPEND _ffmpeg_rhs " ${_ffmpeg_line}")
        endif()

        if(_ffmpeg_continues)
            continue()
        endif()

        if(_ffmpeg_include_block)
            _ffmpeg_native_expand_make_conditionals(_ffmpeg_rhs "${_ffmpeg_rhs}")
            string(REGEX MATCHALL "[A-Za-z0-9_./+-]+\\.o" _ffmpeg_statement_objects "${_ffmpeg_rhs}")
            list(APPEND ${_objects_var} ${_ffmpeg_statement_objects})
        endif()

        set(_ffmpeg_active FALSE)
        set(_ffmpeg_include_block FALSE)
        set(_ffmpeg_rhs)
    endforeach()

    if(_ffmpeg_active AND _ffmpeg_include_block)
        _ffmpeg_native_expand_make_conditionals(_ffmpeg_rhs "${_ffmpeg_rhs}")
        string(REGEX MATCHALL "[A-Za-z0-9_./+-]+\\.o" _ffmpeg_statement_objects "${_ffmpeg_rhs}")
        list(APPEND ${_objects_var} ${_ffmpeg_statement_objects})
    endif()

    set(${_objects_var} "${${_objects_var}}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_objects_to_sources _out _base_dir)
    set(_ffmpeg_sources)
    foreach(_ffmpeg_object IN LISTS ARGN)
        if(_ffmpeg_object MATCHES "\\.spv\\.o$")
            message(VERBOSE "Skipping generated SPIR-V object in native source collector: ${_ffmpeg_object}")
            continue()
        endif()

        string(REGEX REPLACE "\\.o$" "" _ffmpeg_stem "${_ffmpeg_object}")
        set(_ffmpeg_c_source "${_base_dir}/${_ffmpeg_stem}.c")
        set(_ffmpeg_asm_source "${_base_dir}/${_ffmpeg_stem}.asm")

        if(EXISTS "${_ffmpeg_c_source}")
            list(APPEND _ffmpeg_sources "${_ffmpeg_c_source}")
        elseif(FFMPEG_NATIVE_ENABLE_ASM AND EXISTS "${_ffmpeg_asm_source}")
            set_source_files_properties("${_ffmpeg_asm_source}" PROPERTIES LANGUAGE ASM_NASM)
            list(APPEND _ffmpeg_sources "${_ffmpeg_asm_source}")
        elseif(EXISTS "${_ffmpeg_asm_source}")
            message(VERBOSE "Skipping native assembly source because FFMPEG_NATIVE_ENABLE_ASM is OFF: ${_ffmpeg_asm_source}")
        else()
            message(VERBOSE "Skipping native source without C/ASM implementation: ${_base_dir}/${_ffmpeg_stem}")
        endif()
    endforeach()

    list(REMOVE_DUPLICATES _ffmpeg_sources)
    set(${_out} "${_ffmpeg_sources}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_append_makefile_includes _makefiles_var _makefile _library)
    file(STRINGS "${_makefile}" _ffmpeg_makefile_lines)
    foreach(_ffmpeg_line IN LISTS _ffmpeg_makefile_lines)
        string(REGEX REPLACE "#.*$" "" _ffmpeg_line "${_ffmpeg_line}")
        string(REGEX REPLACE "[ \t]+$" "" _ffmpeg_line "${_ffmpeg_line}")
        if(_ffmpeg_line MATCHES "^-?include[ \t]+\\$\\(SRC_PATH\\)/lib${_library}/([^ \t]+)$")
            set(_ffmpeg_include "${FFMPEG_SOURCE_DIR}/lib${_library}/${CMAKE_MATCH_1}")
            if(EXISTS "${_ffmpeg_include}")
                list(APPEND ${_makefiles_var} "${_ffmpeg_include}")
            endif()
        else()
            continue()
        endif()
    endforeach()

    set(${_makefiles_var} "${${_makefiles_var}}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_append_arch_makefiles _makefiles_var _library)
    set(_ffmpeg_arch_dirs)
    foreach(_ffmpeg_arch IN LISTS FFMPEG_NATIVE_ENABLED_ARCH_FEATURES)
        list(APPEND _ffmpeg_arch_dirs "${_ffmpeg_arch}")
    endforeach()
    if(x86 IN_LIST FFMPEG_NATIVE_ENABLED_ARCH_FEATURES OR
       x86_32 IN_LIST FFMPEG_NATIVE_ENABLED_ARCH_FEATURES OR
       x86_64 IN_LIST FFMPEG_NATIVE_ENABLED_ARCH_FEATURES)
        list(APPEND _ffmpeg_arch_dirs x86)
    endif()
    list(REMOVE_DUPLICATES _ffmpeg_arch_dirs)

    foreach(_ffmpeg_arch_dir IN LISTS _ffmpeg_arch_dirs)
        set(_ffmpeg_arch_makefile "${FFMPEG_SOURCE_DIR}/lib${_library}/${_ffmpeg_arch_dir}/Makefile")
        if(EXISTS "${_ffmpeg_arch_makefile}")
            list(APPEND ${_makefiles_var} "${_ffmpeg_arch_makefile}")
        endif()
    endforeach()

    set(${_makefiles_var} "${${_makefiles_var}}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_collect_makefile_objects _out _library)
    set(_ffmpeg_makefile "${FFMPEG_SOURCE_DIR}/lib${_library}/Makefile")
    set(_ffmpeg_makefiles "${_ffmpeg_makefile}")
    _ffmpeg_native_append_makefile_includes(_ffmpeg_makefiles "${_ffmpeg_makefile}" "${_library}")
    _ffmpeg_native_append_arch_makefiles(_ffmpeg_makefiles "${_library}")
    set(_ffmpeg_objects)

    foreach(_ffmpeg_current_makefile IN LISTS _ffmpeg_makefiles)
        _ffmpeg_native_append_makefile_objects(_ffmpeg_objects "${_ffmpeg_current_makefile}" OBJS)
        if(FFMPEG_NATIVE_ENABLE_ASM)
            _ffmpeg_native_append_makefile_objects(_ffmpeg_objects "${_ffmpeg_current_makefile}" X86ASM-OBJS)
        endif()
        if(FFMPEG_BUILD_STATIC)
            _ffmpeg_native_append_makefile_objects(_ffmpeg_objects "${_ffmpeg_current_makefile}" STLIBOBJS)
        endif()
        if(FFMPEG_BUILD_SHARED)
            _ffmpeg_native_append_makefile_objects(_ffmpeg_objects "${_ffmpeg_current_makefile}" SHLIBOBJS)
        endif()
    endforeach()

    _ffmpeg_native_objects_to_sources(_ffmpeg_sources "${FFMPEG_SOURCE_DIR}/lib${_library}" ${_ffmpeg_objects})
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

function(_ffmpeg_native_append_feature_macros _out _prefix _features)
    foreach(_ffmpeg_feature IN LISTS ${_features})
        _ffmpeg_native_to_macro_suffix(_ffmpeg_suffix "${_ffmpeg_feature}")
        list(APPEND ${_out} "${_prefix}${_ffmpeg_suffix}")
    endforeach()
    set(${_out} "${${_out}}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_write_config_macro_block _out _all_macros _enabled_macros)
    foreach(_ffmpeg_macro IN LISTS ${_all_macros})
        if(_ffmpeg_macro STREQUAL "HAVE_AV_CONFIG_H" OR
           _ffmpeg_macro STREQUAL "CONFIG_THIS_YEAR" OR
           _ffmpeg_macro STREQUAL "HAVE_6REGS" OR
           _ffmpeg_macro STREQUAL "HAVE_7REGS")
            continue()
        endif()
        list(FIND ${_enabled_macros} "${_ffmpeg_macro}" _ffmpeg_enabled_index)
        if(_ffmpeg_enabled_index EQUAL -1)
            string(APPEND ${_out} "#define ${_ffmpeg_macro} 0\n")
        else()
            string(APPEND ${_out} "#define ${_ffmpeg_macro} 1\n")
        endif()
    endforeach()
    set(${_out} "${${_out}}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_write_config_asm_macro_block _out _all_macros _enabled_macros)
    foreach(_ffmpeg_macro IN LISTS ${_all_macros})
        if(_ffmpeg_macro STREQUAL "HAVE_AV_CONFIG_H" OR
           _ffmpeg_macro STREQUAL "CONFIG_THIS_YEAR")
            continue()
        endif()
        list(FIND ${_enabled_macros} "${_ffmpeg_macro}" _ffmpeg_enabled_index)
        if(_ffmpeg_enabled_index EQUAL -1)
            string(APPEND ${_out} "%define ${_ffmpeg_macro} 0\n")
        else()
            string(APPEND ${_out} "%define ${_ffmpeg_macro} 1\n")
        endif()
    endforeach()
    set(${_out} "${${_out}}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_write_registry_from_externs _path _type _array _file _regex _suffix)
    set(_ffmpeg_entries)
    if(EXISTS "${_file}")
        file(STRINGS "${_file}" _ffmpeg_lines)
        foreach(_ffmpeg_line IN LISTS _ffmpeg_lines)
            if(_ffmpeg_line MATCHES "${_regex}")
                set(_ffmpeg_symbol "${CMAKE_MATCH_1}_${_suffix}")
                set(_ffmpeg_feature "${CMAKE_MATCH_1}_${_suffix}")
                if(_ffmpeg_feature IN_LIST FFMPEG_NATIVE_ENABLED_COMPONENT_FEATURES)
                    string(APPEND _ffmpeg_entries "    &ff_${_ffmpeg_symbol},\n")
                endif()
            endif()
        endforeach()
    endif()

    set(_ffmpeg_content "static const ${_type} * const ${_array}[] = {\n${_ffmpeg_entries}    NULL\n};\n")
    _ffmpeg_native_write_file_if_changed("${_path}" "${_ffmpeg_content}")
endfunction()

function(_ffmpeg_native_append_registry_entries_from_externs _out _file _regex _suffix)
    foreach(_ffmpeg_line IN LISTS _ffmpeg_registry_lines)
        if(_ffmpeg_line MATCHES "${_regex}")
            set(_ffmpeg_symbol "${CMAKE_MATCH_1}_${_suffix}")
            set(_ffmpeg_feature "${CMAKE_MATCH_1}_${_suffix}")
            if(_ffmpeg_feature IN_LIST FFMPEG_NATIVE_ENABLED_COMPONENT_FEATURES)
                string(APPEND ${_out} "    &ff_${_ffmpeg_symbol},\n")
            endif()
        endif()
    endforeach()
    set(${_out} "${${_out}}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_write_codec_registry _path)
    set(_ffmpeg_entries)
    set(_ffmpeg_file "${FFMPEG_SOURCE_DIR}/libavcodec/allcodecs.c")
    if(EXISTS "${_ffmpeg_file}")
        file(STRINGS "${_ffmpeg_file}" _ffmpeg_registry_lines)
        _ffmpeg_native_append_registry_entries_from_externs(_ffmpeg_entries "${_ffmpeg_file}" "^extern const FFCodec ff_([A-Za-z0-9_]+)_encoder;" encoder)
        _ffmpeg_native_append_registry_entries_from_externs(_ffmpeg_entries "${_ffmpeg_file}" "^extern const FFCodec ff_([A-Za-z0-9_]+)_decoder;" decoder)
    endif()

    set(_ffmpeg_content "static const FFCodec * const codec_list[] = {\n${_ffmpeg_entries}    NULL\n};\n")
    _ffmpeg_native_write_file_if_changed("${_path}" "${_ffmpeg_content}")
endfunction()

function(_ffmpeg_native_write_filter_registry _path)
    set(_ffmpeg_entries)
    set(_ffmpeg_file "${FFMPEG_SOURCE_DIR}/libavfilter/allfilters.c")
    if(EXISTS "${_ffmpeg_file}")
        file(STRINGS "${_ffmpeg_file}" _ffmpeg_lines)
        foreach(_ffmpeg_line IN LISTS _ffmpeg_lines)
            if(_ffmpeg_line MATCHES "^extern const FFFilter ff_([a-z0-9]+_([A-Za-z0-9_]+));")
                set(_ffmpeg_symbol "${CMAKE_MATCH_1}")
                set(_ffmpeg_feature "${CMAKE_MATCH_2}_filter")
                if(_ffmpeg_feature IN_LIST FFMPEG_NATIVE_ENABLED_COMPONENT_FEATURES)
                    string(APPEND _ffmpeg_entries "    &ff_${_ffmpeg_symbol},\n")
                endif()
            endif()
        endforeach()
    endif()

    set(_ffmpeg_content "static const FFFilter * const filter_list[] = {\n${_ffmpeg_entries}    NULL\n};\n")
    _ffmpeg_native_write_file_if_changed("${_path}" "${_ffmpeg_content}")
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

    ffmpeg_native_autoconfig()
    _ffmpeg_native_collect_macros(_ffmpeg_macros)

    set(_ffmpeg_config_macros)
    _ffmpeg_native_append_feature_macros(_ffmpeg_config_macros ARCH_ FFMPEG_NATIVE_ALL_ARCH_FEATURES)
    _ffmpeg_native_append_feature_macros(_ffmpeg_config_macros HAVE_ FFMPEG_NATIVE_ALL_HAVE_FEATURES)
    _ffmpeg_native_append_feature_macros(_ffmpeg_config_macros CONFIG_ FFMPEG_NATIVE_ALL_CONFIG_FEATURES)
    list(APPEND _ffmpeg_config_macros ${_ffmpeg_macros})
    list(REMOVE_DUPLICATES _ffmpeg_config_macros)
    list(SORT _ffmpeg_config_macros)

    set(_ffmpeg_enabled_macros)
    _ffmpeg_native_append_feature_macros(_ffmpeg_enabled_macros ARCH_ FFMPEG_NATIVE_ENABLED_ARCH_FEATURES)
    _ffmpeg_native_append_feature_macros(_ffmpeg_enabled_macros HAVE_ FFMPEG_NATIVE_ENABLED_HAVE_FEATURES)
    _ffmpeg_native_append_feature_macros(_ffmpeg_enabled_macros CONFIG_ FFMPEG_NATIVE_ENABLED_CONFIG_FEATURES)
    list(REMOVE_DUPLICATES _ffmpeg_enabled_macros)

    set(_ffmpeg_component_macros)
    _ffmpeg_native_append_feature_macros(_ffmpeg_component_macros CONFIG_ FFMPEG_NATIVE_ALL_COMPONENT_FEATURES)
    list(REMOVE_DUPLICATES _ffmpeg_component_macros)
    list(SORT _ffmpeg_component_macros)

    set(_ffmpeg_enabled_component_macros)
    _ffmpeg_native_append_feature_macros(_ffmpeg_enabled_component_macros CONFIG_ FFMPEG_NATIVE_ENABLED_COMPONENT_FEATURES)
    list(REMOVE_DUPLICATES _ffmpeg_enabled_component_macros)

    foreach(_ffmpeg_component_macro IN LISTS _ffmpeg_component_macros)
        list(REMOVE_ITEM _ffmpeg_config_macros "${_ffmpeg_component_macro}")
    endforeach()

    set(_ffmpeg_config "/* Generated by ffmpeg-cmake native backend. */\n#ifndef FFMPEG_CONFIG_H\n#define FFMPEG_CONFIG_H\n")
    string(APPEND _ffmpeg_config "#define FFMPEG_CONFIGURATION \"ffmpeg-cmake native backend\"\n")
    string(APPEND _ffmpeg_config "#define FFMPEG_LICENSE \"${FFMPEG_NATIVE_LICENSE}\"\n")
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
    _ffmpeg_native_extern_prefix(_ffmpeg_extern_prefix)
    string(APPEND _ffmpeg_config "#define EXTERN_PREFIX \"${_ffmpeg_extern_prefix}\"\n")
    string(APPEND _ffmpeg_config "#define EXTERN_ASM ${_ffmpeg_extern_prefix}\n#define BUILDSUF \"\"\n#define SWS_MAX_FILTER_SIZE 256\n")

    _ffmpeg_native_write_config_macro_block(_ffmpeg_config _ffmpeg_config_macros _ffmpeg_enabled_macros)
    string(APPEND _ffmpeg_config "#endif /* FFMPEG_CONFIG_H */\n")
    _ffmpeg_native_write_file_if_changed("${_ffmpeg_generated_dir}/config.h" "${_ffmpeg_config}")

    if(FFMPEG_NATIVE_ENABLE_ASM)
        set(_ffmpeg_config_asm "; Generated by ffmpeg-cmake native backend.\n")
        _ffmpeg_native_write_config_asm_macro_block(_ffmpeg_config_asm _ffmpeg_config_macros _ffmpeg_enabled_macros)
        _ffmpeg_native_write_file_if_changed("${_ffmpeg_generated_dir}/config.asm" "${_ffmpeg_config_asm}")
    endif()

    set(_ffmpeg_components "/* Generated by ffmpeg-cmake native backend. */\n#ifndef FFMPEG_CONFIG_COMPONENTS_H\n#define FFMPEG_CONFIG_COMPONENTS_H\n")
    _ffmpeg_native_write_config_macro_block(_ffmpeg_components _ffmpeg_component_macros _ffmpeg_enabled_component_macros)
    string(APPEND _ffmpeg_components "#endif /* FFMPEG_CONFIG_COMPONENTS_H */\n")
    _ffmpeg_native_write_file_if_changed("${_ffmpeg_generated_dir}/config_components.h" "${_ffmpeg_components}")

    if(FFMPEG_NATIVE_ENABLE_ASM)
        set(_ffmpeg_components_asm "; Generated by ffmpeg-cmake native backend.\n")
        _ffmpeg_native_write_config_asm_macro_block(_ffmpeg_components_asm _ffmpeg_component_macros _ffmpeg_enabled_component_macros)
        _ffmpeg_native_write_file_if_changed("${_ffmpeg_generated_dir}/config_components.asm" "${_ffmpeg_components_asm}")
    endif()

    set(_ffmpeg_fast_unaligned 0)
    list(FIND FFMPEG_NATIVE_ENABLED_HAVE_FEATURES fast_unaligned _ffmpeg_fast_unaligned_index)
    if(NOT _ffmpeg_fast_unaligned_index EQUAL -1)
        set(_ffmpeg_fast_unaligned 1)
    endif()
    set(_ffmpeg_bigendian 0)
    list(FIND FFMPEG_NATIVE_ENABLED_HAVE_FEATURES bigendian _ffmpeg_bigendian_index)
    if(NOT _ffmpeg_bigendian_index EQUAL -1)
        set(_ffmpeg_bigendian 1)
    endif()
    set(_ffmpeg_avconfig "/* Generated by ffmpeg-cmake native backend. */\n#ifndef AVUTIL_AVCONFIG_H\n#define AVUTIL_AVCONFIG_H\n#define AV_HAVE_BIGENDIAN ${_ffmpeg_bigendian}\n#define AV_HAVE_FAST_UNALIGNED ${_ffmpeg_fast_unaligned}\n#endif /* AVUTIL_AVCONFIG_H */\n")
    _ffmpeg_native_write_file_if_changed("${_ffmpeg_generated_dir}/libavutil/avconfig.h" "${_ffmpeg_avconfig}")

    set(_ffmpeg_ffversion "/* Generated by ffmpeg-cmake native backend. */\n#ifndef AVUTIL_FFVERSION_H\n#define AVUTIL_FFVERSION_H\n#define FFMPEG_VERSION \"native-cmake\"\n#endif /* AVUTIL_FFVERSION_H */\n")
    _ffmpeg_native_write_file_if_changed("${_ffmpeg_generated_dir}/libavutil/ffversion.h" "${_ffmpeg_ffversion}")

    _ffmpeg_native_write_codec_registry("${_ffmpeg_generated_dir}/libavcodec/codec_list.c")
    _ffmpeg_native_write_registry_from_externs("${_ffmpeg_generated_dir}/libavcodec/parser_list.c" FFCodecParser parser_list
        "${FFMPEG_SOURCE_DIR}/libavcodec/parsers.c" "^extern const FFCodecParser ff_([A-Za-z0-9_]+)_parser;" parser)
    _ffmpeg_native_write_registry_from_externs("${_ffmpeg_generated_dir}/libavcodec/bsf_list.c" FFBitStreamFilter bitstream_filters
        "${FFMPEG_SOURCE_DIR}/libavcodec/bitstream_filters.c" "^extern const FFBitStreamFilter ff_([A-Za-z0-9_]+)_bsf;" bsf)
    _ffmpeg_native_write_registry_from_externs("${_ffmpeg_generated_dir}/libavformat/protocol_list.c" URLProtocol url_protocols
        "${FFMPEG_SOURCE_DIR}/libavformat/protocols.c" "^extern const URLProtocol ff_([A-Za-z0-9_]+)_protocol;" protocol)
    _ffmpeg_native_write_registry_from_externs("${_ffmpeg_generated_dir}/libavformat/muxer_list.c" FFOutputFormat muxer_list
        "${FFMPEG_SOURCE_DIR}/libavformat/allformats.c" "^extern const FFOutputFormat ff_([A-Za-z0-9_]+)_muxer;" muxer)
    _ffmpeg_native_write_registry_from_externs("${_ffmpeg_generated_dir}/libavformat/demuxer_list.c" FFInputFormat demuxer_list
        "${FFMPEG_SOURCE_DIR}/libavformat/allformats.c" "^extern const FFInputFormat[ \t]+ff_([A-Za-z0-9_]+)_demuxer;" demuxer)
    _ffmpeg_native_write_filter_registry("${_ffmpeg_generated_dir}/libavfilter/filter_list.c")
    _ffmpeg_native_write_registry_from_externs("${_ffmpeg_generated_dir}/libavdevice/indev_list.c" FFInputFormat indev_list
        "${FFMPEG_SOURCE_DIR}/libavdevice/alldevices.c" "^extern const FFInputFormat[ \t]+ff_([A-Za-z0-9_]+)_demuxer;" indev)
    _ffmpeg_native_write_registry_from_externs("${_ffmpeg_generated_dir}/libavdevice/outdev_list.c" FFOutputFormat outdev_list
        "${FFMPEG_SOURCE_DIR}/libavdevice/alldevices.c" "^extern const FFOutputFormat ff_([A-Za-z0-9_]+)_muxer;" outdev)

    set(_ffmpeg_enabled_object_macros ${_ffmpeg_enabled_macros} ${_ffmpeg_enabled_component_macros})
    list(REMOVE_DUPLICATES _ffmpeg_enabled_object_macros)
    set(FFMPEG_NATIVE_ENABLED_OBJECT_MACROS "${_ffmpeg_enabled_object_macros}" PARENT_SCOPE)
    set(FFMPEG_NATIVE_ALL_CONFIG_FEATURES "${FFMPEG_NATIVE_ALL_CONFIG_FEATURES}" PARENT_SCOPE)
    set(FFMPEG_NATIVE_ALL_COMPONENT_FEATURES "${FFMPEG_NATIVE_ALL_COMPONENT_FEATURES}" PARENT_SCOPE)
    set(FFMPEG_NATIVE_ALL_HAVE_FEATURES "${FFMPEG_NATIVE_ALL_HAVE_FEATURES}" PARENT_SCOPE)
    set(FFMPEG_NATIVE_ALL_ARCH_FEATURES "${FFMPEG_NATIVE_ALL_ARCH_FEATURES}" PARENT_SCOPE)
    set(FFMPEG_NATIVE_ENABLED_CONFIG_FEATURES "${FFMPEG_NATIVE_ENABLED_CONFIG_FEATURES}" PARENT_SCOPE)
    set(FFMPEG_NATIVE_ENABLED_COMPONENT_FEATURES "${FFMPEG_NATIVE_ENABLED_COMPONENT_FEATURES}" PARENT_SCOPE)
    set(FFMPEG_NATIVE_ENABLED_HAVE_FEATURES "${FFMPEG_NATIVE_ENABLED_HAVE_FEATURES}" PARENT_SCOPE)
    set(FFMPEG_NATIVE_ENABLED_ARCH_FEATURES "${FFMPEG_NATIVE_ENABLED_ARCH_FEATURES}" PARENT_SCOPE)
    set(FFMPEG_NATIVE_LICENSE "${FFMPEG_NATIVE_LICENSE}" PARENT_SCOPE)
    set(FFMPEG_NATIVE_GENERATED_DIR "${_ffmpeg_generated_dir}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_resolve_components _out)
    set(_ffmpeg_components)
    foreach(_ffmpeg_component IN LISTS FFMPEG_NATIVE_COMPONENTS)
        string(TOUPPER "${_ffmpeg_component}" _ffmpeg_component_uc)
        if(DEFINED FFMPEG_ENABLE_${_ffmpeg_component_uc} AND NOT FFMPEG_ENABLE_${_ffmpeg_component_uc})
            continue()
        endif()
        list(APPEND _ffmpeg_components "${_ffmpeg_component}")
    endforeach()
    list(REMOVE_DUPLICATES _ffmpeg_components)
    set(${_out} "${_ffmpeg_components}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_write_binary_c _path _source _symbol)
    file(READ "${_source}" _ffmpeg_hex HEX)
    string(LENGTH "${_ffmpeg_hex}" _ffmpeg_hex_len)
    math(EXPR _ffmpeg_len "${_ffmpeg_hex_len} / 2")
    string(REGEX MATCHALL ".." _ffmpeg_bytes "${_ffmpeg_hex}")

    set(_ffmpeg_content "/* Generated by ffmpeg-cmake native backend. */\n#include <stddef.h>\n\n")
    string(APPEND _ffmpeg_content "const unsigned char ff_${_symbol}_data[] = {\n")
    set(_ffmpeg_col 0)
    foreach(_ffmpeg_byte IN LISTS _ffmpeg_bytes)
        if(_ffmpeg_col EQUAL 0)
            string(APPEND _ffmpeg_content "    ")
        endif()
        string(APPEND _ffmpeg_content "0x${_ffmpeg_byte}, ")
        math(EXPR _ffmpeg_col "${_ffmpeg_col} + 1")
        if(_ffmpeg_col EQUAL 12)
            string(APPEND _ffmpeg_content "\n")
            set(_ffmpeg_col 0)
        endif()
    endforeach()
    if(NOT _ffmpeg_col EQUAL 0)
        string(APPEND _ffmpeg_content "\n")
    endif()
    string(APPEND _ffmpeg_content "    0x00\n};\n")
    string(APPEND _ffmpeg_content "const unsigned int ff_${_symbol}_len = ${_ffmpeg_len};\n")
    _ffmpeg_native_write_file_if_changed("${_path}" "${_ffmpeg_content}")
endfunction()

function(_ffmpeg_native_generate_ffmpeg_resources _out)
    set(_ffmpeg_resource_dir "${FFMPEG_NATIVE_GENERATED_DIR}/fftools/resources")
    file(MAKE_DIRECTORY "${_ffmpeg_resource_dir}")

    set(_ffmpeg_graph_html_c "${_ffmpeg_resource_dir}/graph.html.c")
    set(_ffmpeg_graph_css_c "${_ffmpeg_resource_dir}/graph.css.c")
    _ffmpeg_native_write_binary_c("${_ffmpeg_graph_html_c}" "${FFMPEG_SOURCE_DIR}/fftools/resources/graph.html" graph_html)
    _ffmpeg_native_write_binary_c("${_ffmpeg_graph_css_c}" "${FFMPEG_SOURCE_DIR}/fftools/resources/graph.css" graph_css)

    set(${_out} "${_ffmpeg_graph_html_c};${_ffmpeg_graph_css_c}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_collect_fftool_sources _out _tool)
    set(_ffmpeg_makefile "${FFMPEG_SOURCE_DIR}/fftools/Makefile")
    set(_ffmpeg_objects
        "fftools/cmdutils.o"
        "fftools/opt_common.o"
        "fftools/${_tool}.o")
    _ffmpeg_native_append_makefile_objects(_ffmpeg_objects "${_ffmpeg_makefile}" "OBJS-${_tool}")

    if(_tool STREQUAL "ffmpeg")
        _ffmpeg_native_append_makefile_objects(_ffmpeg_objects "${FFMPEG_SOURCE_DIR}/fftools/resources/Makefile" "OBJS-resman")
    endif()

    _ffmpeg_native_objects_to_sources(_ffmpeg_sources "${FFMPEG_SOURCE_DIR}" ${_ffmpeg_objects})

    if(_tool STREQUAL "ffmpeg")
        _ffmpeg_native_generate_ffmpeg_resources(_ffmpeg_resource_sources)
        list(APPEND _ffmpeg_sources ${_ffmpeg_resource_sources})
    endif()

    list(REMOVE_DUPLICATES _ffmpeg_sources)
    set(${_out} "${_ffmpeg_sources}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_program_require_components _tool)
    if(_tool STREQUAL "ffprobe")
        set(_ffmpeg_required avutil avcodec avformat)
    elseif(_tool STREQUAL "ffmpeg")
        set(_ffmpeg_required avutil avcodec avformat avfilter)
    elseif(_tool STREQUAL "ffplay")
        set(_ffmpeg_required avutil avcodec avformat avfilter swscale swresample)
    else()
        message(FATAL_ERROR "Unknown native FFmpeg program '${_tool}'")
    endif()

    foreach(_ffmpeg_required_component IN LISTS _ffmpeg_required)
        if(NOT TARGET "${_ffmpeg_required_component}")
            message(FATAL_ERROR "Native program '${_tool}' requires ${_ffmpeg_required_component} in FFMPEG_NATIVE_COMPONENTS")
        endif()
    endforeach()
endfunction()

function(_ffmpeg_native_link_program_libraries _target)
    set(_ffmpeg_program_libs)
    foreach(_ffmpeg_component IN ITEMS avdevice avfilter avformat avcodec swresample swscale avutil)
        if(TARGET ${_ffmpeg_component})
            list(APPEND _ffmpeg_program_libs "FFmpeg::${_ffmpeg_component}")
        endif()
    endforeach()

    if(FFMPEG_BUILD_STATIC AND NOT WIN32 AND _ffmpeg_program_libs)
        string(REPLACE ";" "," _ffmpeg_program_group "${_ffmpeg_program_libs}")
        target_link_libraries(${_target} PRIVATE "$<LINK_GROUP:RESCAN,${_ffmpeg_program_group}>")
    else()
        target_link_libraries(${_target} PRIVATE ${_ffmpeg_program_libs})
    endif()
endfunction()

function(_ffmpeg_native_add_program _tool)
    list(FIND FFMPEG_NATIVE_ENABLED_CONFIG_FEATURES "${_tool}" _ffmpeg_program_enabled)
    if(_ffmpeg_program_enabled EQUAL -1)
        return()
    endif()
    if(_tool STREQUAL "ffmpeg" AND NOT FFMPEG_NATIVE_ENABLE_THREADS)
        message(FATAL_ERROR "Native program 'ffmpeg' requires FFMPEG_NATIVE_ENABLE_THREADS=ON")
    endif()
    if(_tool STREQUAL "ffplay" AND NOT TARGET FFmpegExternal::sdl2)
        message(FATAL_ERROR "Native program 'ffplay' requires SDL2. Provide sdl2 via CMAKE_PREFIX_PATH/pkg-config or disable FFMPEG_NATIVE_BUILD_FFPLAY.")
    endif()

    _ffmpeg_native_program_require_components("${_tool}")
    _ffmpeg_native_collect_fftool_sources(_ffmpeg_sources "${_tool}")
    add_executable(${_tool} ${_ffmpeg_sources})
    ffmpeg_set_target_folder(${_tool} "FFmpeg/Tools")
    target_include_directories(${_tool}
        PRIVATE
            "${FFMPEG_SOURCE_DIR}"
            "${FFMPEG_NATIVE_GENERATED_DIR}")
    _ffmpeg_native_apply_compile_settings(${_tool})
    _ffmpeg_native_link_program_libraries(${_tool})

    if(_tool STREQUAL "ffplay" AND TARGET FFmpegExternal::sdl2)
        target_link_libraries(${_tool} PRIVATE FFmpegExternal::sdl2)
    endif()

    install(TARGETS ${_tool}
        RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}")
    list(APPEND FFMPEG_NATIVE_PROGRAMS "${_tool}")
    set(FFMPEG_NATIVE_PROGRAMS "${FFMPEG_NATIVE_PROGRAMS}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_collect_enabled_examples _out)
    set(_ffmpeg_makefile "${FFMPEG_SOURCE_DIR}/doc/examples/Makefile")
    if(NOT EXISTS "${_ffmpeg_makefile}")
        set(${_out} "" PARENT_SCOPE)
        return()
    endif()

    file(STRINGS "${_ffmpeg_makefile}" _ffmpeg_lines)
    set(_ffmpeg_examples)
    foreach(_ffmpeg_line IN LISTS _ffmpeg_lines)
        string(REGEX REPLACE "#.*$" "" _ffmpeg_line "${_ffmpeg_line}")
        string(REGEX REPLACE "[ \t]+$" "" _ffmpeg_line "${_ffmpeg_line}")
        if(_ffmpeg_line MATCHES "^EXAMPLES-\\$\\((!?[A-Za-z0-9_]+)\\)[ \t]*\\+?=[ \t]*(.*)$")
            set(_ffmpeg_condition "${CMAKE_MATCH_1}")
            set(_ffmpeg_items "${CMAKE_MATCH_2}")
            _ffmpeg_native_make_condition_enabled(_ffmpeg_enabled "${_ffmpeg_condition}")
            if(_ffmpeg_enabled)
                _ffmpeg_native_normalize_words(_ffmpeg_example_names "${_ffmpeg_items}")
                list(APPEND _ffmpeg_examples ${_ffmpeg_example_names})
            endif()
        endif()
    endforeach()

    list(REMOVE_DUPLICATES _ffmpeg_examples)
    list(SORT _ffmpeg_examples)
    set(${_out} "${_ffmpeg_examples}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_add_example _example)
    set(_ffmpeg_source "${FFMPEG_SOURCE_DIR}/doc/examples/${_example}.c")
    if(NOT EXISTS "${_ffmpeg_source}")
        message(VERBOSE "Skipping native FFmpeg example without source: ${_example}")
        return()
    endif()

    set(_ffmpeg_target "ffmpeg_example_${_example}")
    add_executable(${_ffmpeg_target} EXCLUDE_FROM_ALL "${_ffmpeg_source}")
    ffmpeg_set_target_folder(${_ffmpeg_target} "FFmpeg/Examples")
    target_include_directories(${_ffmpeg_target}
        PRIVATE
            "${FFMPEG_SOURCE_DIR}"
            "${FFMPEG_NATIVE_GENERATED_DIR}")
    _ffmpeg_native_apply_compile_settings(${_ffmpeg_target})
    _ffmpeg_native_link_program_libraries(${_ffmpeg_target})
    set_target_properties(${_ffmpeg_target} PROPERTIES
        OUTPUT_NAME "${_example}"
        RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/doc/examples")

    list(APPEND FFMPEG_NATIVE_EXAMPLE_TARGETS "${_ffmpeg_target}")
    list(APPEND FFMPEG_NATIVE_EXAMPLES "${_example}")
    set(FFMPEG_NATIVE_EXAMPLE_TARGETS "${FFMPEG_NATIVE_EXAMPLE_TARGETS}" PARENT_SCOPE)
    set(FFMPEG_NATIVE_EXAMPLES "${FFMPEG_NATIVE_EXAMPLES}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_add_examples)
    _ffmpeg_native_collect_enabled_examples(_ffmpeg_examples)
    set(FFMPEG_NATIVE_EXAMPLES)
    set(FFMPEG_NATIVE_EXAMPLE_TARGETS)
    foreach(_ffmpeg_example IN LISTS _ffmpeg_examples)
        _ffmpeg_native_add_example("${_ffmpeg_example}")
    endforeach()

    if(FFMPEG_NATIVE_EXAMPLE_TARGETS)
        add_custom_target(ffmpeg_native_examples ALL DEPENDS ${FFMPEG_NATIVE_EXAMPLE_TARGETS})
        ffmpeg_set_target_folder(ffmpeg_native_examples "FFmpeg/Examples")
    endif()

    set(FFMPEG_NATIVE_EXAMPLES "${FFMPEG_NATIVE_EXAMPLES}" PARENT_SCOPE)
    set(FFMPEG_NATIVE_EXAMPLE_TARGETS "${FFMPEG_NATIVE_EXAMPLE_TARGETS}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_install_examples)
    set(_ffmpeg_examples_dir "${FFMPEG_SOURCE_DIR}/doc/examples")
    if(NOT IS_DIRECTORY "${_ffmpeg_examples_dir}")
        return()
    endif()

    file(GLOB _ffmpeg_example_sources
        CONFIGURE_DEPENDS
        "${_ffmpeg_examples_dir}/*.c")
    if(_ffmpeg_example_sources)
        install(FILES ${_ffmpeg_example_sources}
            DESTINATION "${CMAKE_INSTALL_DATADIR}/ffmpeg/examples")
    endif()
    if(EXISTS "${_ffmpeg_examples_dir}/README")
        install(FILES "${_ffmpeg_examples_dir}/README"
            DESTINATION "${CMAKE_INSTALL_DATADIR}/ffmpeg/examples")
    endif()
    if(EXISTS "${_ffmpeg_examples_dir}/Makefile.example")
        install(FILES "${_ffmpeg_examples_dir}/Makefile.example"
            DESTINATION "${CMAKE_INSTALL_DATADIR}/ffmpeg/examples"
            RENAME Makefile)
    elseif(EXISTS "${_ffmpeg_examples_dir}/Makefile")
        install(FILES "${_ffmpeg_examples_dir}/Makefile"
            DESTINATION "${CMAKE_INSTALL_DATADIR}/ffmpeg/examples")
    endif()
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
    _ffmpeg_native_collect_makefile_objects(_ffmpeg_sources "${_component}")

    add_library(${_component} ${_ffmpeg_library_type} ${_ffmpeg_sources})
    ffmpeg_set_target_folder(${_component} "FFmpeg/Libraries")
    add_library(FFmpeg::${_component} ALIAS ${_component})
    target_include_directories(${_component}
        PUBLIC
            "$<BUILD_INTERFACE:${FFMPEG_SOURCE_DIR}>"
            "$<BUILD_INTERFACE:${FFMPEG_NATIVE_GENERATED_DIR}>"
            "$<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>")
    _ffmpeg_native_apply_compile_settings(${_component} HAVE_AV_CONFIG_H)
    target_compile_definitions(${_component} PRIVATE BUILDING_${_component})
    if(UNIX AND NOT APPLE)
        target_link_libraries(${_component} PUBLIC m)
    endif()
    set(_ffmpeg_position_independent_code "${CMAKE_POSITION_INDEPENDENT_CODE}")
    if(FFMPEG_BUILD_SHARED)
        set(_ffmpeg_position_independent_code ON)
    endif()
    set_target_properties(${_component} PROPERTIES
        OUTPUT_NAME "${_component}"
        POSITION_INDEPENDENT_CODE "${_ffmpeg_position_independent_code}")

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
            FFMPEG_NATIVE_EXAMPLE_TARGETS)
        set(${_ffmpeg_report_var} "${${_ffmpeg_report_var}}" PARENT_SCOPE)
    endforeach()
endfunction()
