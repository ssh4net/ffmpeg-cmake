include_guard(GLOBAL)

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

function(_ffmpeg_native_append_enabled_summary_features _out)
    foreach(_ffmpeg_feature IN LISTS ARGN)
        if(_ffmpeg_feature IN_LIST FFMPEG_NATIVE_ENABLED_CONFIG_FEATURES)
            list(APPEND ${_out} "${_ffmpeg_feature}")
        endif()
    endforeach()
    set(${_out} "${${_out}}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_escape_c_string _out _value)
    string(REPLACE "\\" "\\\\" _ffmpeg_value "${_value}")
    string(REPLACE "\"" "\\\"" _ffmpeg_value "${_ffmpeg_value}")
    string(REPLACE "\n" "\\n" _ffmpeg_value "${_ffmpeg_value}")
    set(${_out} "${_ffmpeg_value}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_build_configuration_string _out)
    set(_ffmpeg_enabled_summary)
    _ffmpeg_native_append_enabled_summary_features(_ffmpeg_enabled_summary
        static
        shared
        pic
        gpl
        version3
        nonfree
        sdl2
        fontconfig
        libfontconfig
        iconv
        gnutls
        openssl
        lcms2
        libxml2
        zlib
        lzma
        bzlib
        ffnvcodec
        cuda
        cuvid
        nvdec
        nvenc
        d3d11va
        d3d12va
        d3d12va_encode
        dxva2
        amf
        libmfx
        libvpl
        qsv
        mediafoundation
        opencl
        vaapi
        vdpau
        videotoolbox
        vulkan
        libaom
        libass
        libdav1d
        libfdk_aac
        libfribidi
        libfreetype
        libharfbuzz
        libjxl
        libkvazaar
        libmp3lame
        libopenh264
        libopenjpeg
        libopenmpt
        libopus
        librav1e
        libspeex
        libsvtav1
        libtheora
        libtwolame
        libvorbis
        libvpx
        libwebp
        libx264
        libx265
        libxvid)

    foreach(_ffmpeg_feature IN LISTS FFMPEG_ENABLE_EXTERNAL_LIBRARIES FFMPEG_ENABLE_FEATURES)
        if(NOT _ffmpeg_feature STREQUAL "")
            list(APPEND _ffmpeg_enabled_summary "${_ffmpeg_feature}")
        endif()
    endforeach()

    list(REMOVE_DUPLICATES _ffmpeg_enabled_summary)

    set(_ffmpeg_configuration "ffmpeg-cmake native backend")
    if(_ffmpeg_enabled_summary)
        list(SORT _ffmpeg_enabled_summary)
        string(JOIN ", " _ffmpeg_enabled_text ${_ffmpeg_enabled_summary})
        string(APPEND _ffmpeg_configuration "; enable: ${_ffmpeg_enabled_text}")
    endif()

    set(${_out} "${_ffmpeg_configuration}" PARENT_SCOPE)
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
    list(FIND FFMPEG_NATIVE_COMPONENTS avfilter _ffmpeg_has_avfilter)
    if(NOT _ffmpeg_has_avfilter EQUAL -1)
        string(APPEND _ffmpeg_entries
            "    &ff_asrc_abuffer,\n"
            "    &ff_vsrc_buffer,\n"
            "    &ff_asink_abuffer,\n"
            "    &ff_vsink_buffer,\n")
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

    _ffmpeg_native_build_configuration_string(_ffmpeg_configuration)
    _ffmpeg_native_escape_c_string(_ffmpeg_configuration_c "${_ffmpeg_configuration}")

    set(_ffmpeg_config "/* Generated by ffmpeg-cmake native backend. */\n#ifndef FFMPEG_CONFIG_H\n#define FFMPEG_CONFIG_H\n")
    string(APPEND _ffmpeg_config "#define FFMPEG_CONFIGURATION \"${_ffmpeg_configuration_c}\"\n")
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

    if(FFMPEG_NATIVE_EFFECTIVE_ENABLE_ASM)
        set(_ffmpeg_config_asm "; Generated by ffmpeg-cmake native backend.\n")
        _ffmpeg_native_write_config_asm_macro_block(_ffmpeg_config_asm _ffmpeg_config_macros _ffmpeg_enabled_macros)
        _ffmpeg_native_write_file_if_changed("${_ffmpeg_generated_dir}/config.asm" "${_ffmpeg_config_asm}")
    endif()

    set(_ffmpeg_components "/* Generated by ffmpeg-cmake native backend. */\n#ifndef FFMPEG_CONFIG_COMPONENTS_H\n#define FFMPEG_CONFIG_COMPONENTS_H\n")
    _ffmpeg_native_write_config_macro_block(_ffmpeg_components _ffmpeg_component_macros _ffmpeg_enabled_component_macros)
    string(APPEND _ffmpeg_components "#endif /* FFMPEG_CONFIG_COMPONENTS_H */\n")
    _ffmpeg_native_write_file_if_changed("${_ffmpeg_generated_dir}/config_components.h" "${_ffmpeg_components}")

    if(FFMPEG_NATIVE_EFFECTIVE_ENABLE_ASM)
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
