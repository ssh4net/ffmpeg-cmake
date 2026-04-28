include_guard(GLOBAL)

function(_ffmpeg_native_read_quoted_assignment _out _name)
    set(_ffmpeg_configure "${FFMPEG_SOURCE_DIR}/configure")
    if(NOT EXISTS "${_ffmpeg_configure}")
        message(FATAL_ERROR "Could not find FFmpeg configure script: ${_ffmpeg_configure}")
    endif()

    file(STRINGS "${_ffmpeg_configure}" _ffmpeg_lines)
    set(_ffmpeg_collecting FALSE)
    set(_ffmpeg_value)
    foreach(_ffmpeg_line IN LISTS _ffmpeg_lines)
        if(NOT _ffmpeg_collecting)
            if(_ffmpeg_line MATCHES "^${_name}=\"(.*)$")
                set(_ffmpeg_collecting TRUE)
                set(_ffmpeg_line "${CMAKE_MATCH_1}")
            else()
                continue()
            endif()
        endif()

        if(_ffmpeg_line MATCHES "^(.*)\"[ \t]*$")
            string(APPEND _ffmpeg_value "\n${CMAKE_MATCH_1}")
            break()
        endif()
        string(APPEND _ffmpeg_value "\n${_ffmpeg_line}")
    endforeach()

    set(${_out} "${_ffmpeg_value}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_normalize_words _out _text)
    string(REGEX REPLACE "#[^\n\r]*" " " _ffmpeg_text "${_text}")
    string(REGEX REPLACE "[\r\n\t ]+" ";" _ffmpeg_words "${_ffmpeg_text}")

    set(_ffmpeg_result)
    foreach(_ffmpeg_word IN LISTS _ffmpeg_words)
        if(_ffmpeg_word STREQUAL "" OR _ffmpeg_word MATCHES "^\\$\\(" OR _ffmpeg_word MATCHES "^\\$")
            continue()
        endif()
        list(APPEND _ffmpeg_result "${_ffmpeg_word}")
    endforeach()
    list(REMOVE_DUPLICATES _ffmpeg_result)
    set(${_out} "${_ffmpeg_result}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_expand_configure_list _out _name)
    _ffmpeg_native_read_quoted_assignment(_ffmpeg_raw "${_name}")
    set(_ffmpeg_text "${_ffmpeg_raw}")

    foreach(_ffmpeg_unused RANGE 0 24)
        set(_ffmpeg_changed FALSE)

        while(_ffmpeg_text MATCHES "\\$\\(add_suffix[ \t]+([^ \t\\)]+)[ \t]+\\$([A-Za-z0-9_]+)\\)")
            set(_ffmpeg_expression "${CMAKE_MATCH_0}")
            set(_ffmpeg_suffix "${CMAKE_MATCH_1}")
            set(_ffmpeg_ref "${CMAKE_MATCH_2}")
            _ffmpeg_native_expand_configure_list(_ffmpeg_ref_items "${_ffmpeg_ref}")
            set(_ffmpeg_expanded)
            foreach(_ffmpeg_item IN LISTS _ffmpeg_ref_items)
                string(APPEND _ffmpeg_expanded " ${_ffmpeg_item}${_ffmpeg_suffix}")
            endforeach()
            string(REPLACE "${_ffmpeg_expression}" "${_ffmpeg_expanded}" _ffmpeg_text "${_ffmpeg_text}")
            set(_ffmpeg_changed TRUE)
        endwhile()

        string(REGEX MATCHALL "\\$[A-Za-z0-9_]+" _ffmpeg_refs "${_ffmpeg_text}")
        if(_ffmpeg_refs)
            foreach(_ffmpeg_ref_token IN LISTS _ffmpeg_refs)
                string(SUBSTRING "${_ffmpeg_ref_token}" 1 -1 _ffmpeg_ref)
                if(_ffmpeg_ref STREQUAL "${_name}")
                    continue()
                endif()
                _ffmpeg_native_expand_configure_list(_ffmpeg_ref_items "${_ffmpeg_ref}")
                list(JOIN _ffmpeg_ref_items " " _ffmpeg_ref_text)
                string(REPLACE "${_ffmpeg_ref_token}" "${_ffmpeg_ref_text}" _ffmpeg_text "${_ffmpeg_text}")
                set(_ffmpeg_changed TRUE)
            endforeach()
        endif()

        if(NOT _ffmpeg_changed)
            break()
        endif()
    endforeach()

    _ffmpeg_native_normalize_words(_ffmpeg_result "${_ffmpeg_text}")
    set(${_out} "${_ffmpeg_result}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_collect_extern_components _out _file _regex _suffix)
    if(NOT EXISTS "${_file}")
        set(${_out} "" PARENT_SCOPE)
        return()
    endif()

    file(STRINGS "${_file}" _ffmpeg_lines)
    set(_ffmpeg_components)
    foreach(_ffmpeg_line IN LISTS _ffmpeg_lines)
        if(_ffmpeg_line MATCHES "${_regex}")
            list(APPEND _ffmpeg_components "${CMAKE_MATCH_1}_${_suffix}")
        endif()
    endforeach()
    list(REMOVE_DUPLICATES _ffmpeg_components)
    list(SORT _ffmpeg_components)
    set(${_out} "${_ffmpeg_components}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_collect_filter_components _out)
    set(_ffmpeg_file "${FFMPEG_SOURCE_DIR}/libavfilter/allfilters.c")
    if(NOT EXISTS "${_ffmpeg_file}")
        set(${_out} "" PARENT_SCOPE)
        return()
    endif()

    file(STRINGS "${_ffmpeg_file}" _ffmpeg_lines)
    set(_ffmpeg_components)
    foreach(_ffmpeg_line IN LISTS _ffmpeg_lines)
        if(_ffmpeg_line MATCHES "^extern const FFFilter ff_[a-z0-9]+_([A-Za-z0-9_]+);")
            list(APPEND _ffmpeg_components "${CMAKE_MATCH_1}_filter")
        endif()
    endforeach()
    list(REMOVE_DUPLICATES _ffmpeg_components)
    list(SORT _ffmpeg_components)
    set(${_out} "${_ffmpeg_components}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_collect_component_lists)
    _ffmpeg_native_collect_extern_components(_ffmpeg_encoders
        "${FFMPEG_SOURCE_DIR}/libavcodec/allcodecs.c"
        "^extern const FFCodec ff_([A-Za-z0-9_]+)_encoder;"
        encoder)
    _ffmpeg_native_collect_extern_components(_ffmpeg_decoders
        "${FFMPEG_SOURCE_DIR}/libavcodec/allcodecs.c"
        "^extern const FFCodec ff_([A-Za-z0-9_]+)_decoder;"
        decoder)
    _ffmpeg_native_collect_extern_components(_ffmpeg_parsers
        "${FFMPEG_SOURCE_DIR}/libavcodec/parsers.c"
        "^extern const FFCodecParser ff_([A-Za-z0-9_]+)_parser;"
        parser)
    _ffmpeg_native_collect_extern_components(_ffmpeg_bsfs
        "${FFMPEG_SOURCE_DIR}/libavcodec/bitstream_filters.c"
        "^extern const FFBitStreamFilter ff_([A-Za-z0-9_]+)_bsf;"
        bsf)
    _ffmpeg_native_collect_extern_components(_ffmpeg_hwaccels
        "${FFMPEG_SOURCE_DIR}/libavcodec/hwaccels.h"
        "^extern const struct FFHWAccel ff_([A-Za-z0-9_]+)_hwaccel;"
        hwaccel)
    _ffmpeg_native_collect_extern_components(_ffmpeg_muxers
        "${FFMPEG_SOURCE_DIR}/libavformat/allformats.c"
        "^extern const FFOutputFormat ff_([A-Za-z0-9_]+)_muxer;"
        muxer)
    _ffmpeg_native_collect_extern_components(_ffmpeg_demuxers
        "${FFMPEG_SOURCE_DIR}/libavformat/allformats.c"
        "^extern const FFInputFormat[ \t]+ff_([A-Za-z0-9_]+)_demuxer;"
        demuxer)
    _ffmpeg_native_collect_extern_components(_ffmpeg_protocols
        "${FFMPEG_SOURCE_DIR}/libavformat/protocols.c"
        "^extern const URLProtocol ff_([A-Za-z0-9_]+)_protocol;"
        protocol)
    _ffmpeg_native_collect_extern_components(_ffmpeg_indevs
        "${FFMPEG_SOURCE_DIR}/libavdevice/alldevices.c"
        "^extern const FFInputFormat[ \t]+ff_([A-Za-z0-9_]+)_demuxer;"
        indev)
    _ffmpeg_native_collect_extern_components(_ffmpeg_outdevs
        "${FFMPEG_SOURCE_DIR}/libavdevice/alldevices.c"
        "^extern const FFOutputFormat ff_([A-Za-z0-9_]+)_muxer;"
        outdev)
    _ffmpeg_native_collect_filter_components(_ffmpeg_filters)

    set(FFMPEG_NATIVE_ENCODER_LIST "${_ffmpeg_encoders}" PARENT_SCOPE)
    set(FFMPEG_NATIVE_DECODER_LIST "${_ffmpeg_decoders}" PARENT_SCOPE)
    set(FFMPEG_NATIVE_PARSER_LIST "${_ffmpeg_parsers}" PARENT_SCOPE)
    set(FFMPEG_NATIVE_BSF_LIST "${_ffmpeg_bsfs}" PARENT_SCOPE)
    set(FFMPEG_NATIVE_HWACCEL_LIST "${_ffmpeg_hwaccels}" PARENT_SCOPE)
    set(FFMPEG_NATIVE_MUXER_LIST "${_ffmpeg_muxers}" PARENT_SCOPE)
    set(FFMPEG_NATIVE_DEMUXER_LIST "${_ffmpeg_demuxers}" PARENT_SCOPE)
    set(FFMPEG_NATIVE_PROTOCOL_LIST "${_ffmpeg_protocols}" PARENT_SCOPE)
    set(FFMPEG_NATIVE_INDEV_LIST "${_ffmpeg_indevs}" PARENT_SCOPE)
    set(FFMPEG_NATIVE_OUTDEV_LIST "${_ffmpeg_outdevs}" PARENT_SCOPE)
    set(FFMPEG_NATIVE_FILTER_LIST "${_ffmpeg_filters}" PARENT_SCOPE)

    set(_ffmpeg_all
        ${_ffmpeg_encoders}
        ${_ffmpeg_decoders}
        ${_ffmpeg_parsers}
        ${_ffmpeg_bsfs}
        ${_ffmpeg_hwaccels}
        ${_ffmpeg_muxers}
        ${_ffmpeg_demuxers}
        ${_ffmpeg_protocols}
        ${_ffmpeg_indevs}
        ${_ffmpeg_outdevs}
        ${_ffmpeg_filters})
    list(REMOVE_DUPLICATES _ffmpeg_all)
    list(SORT _ffmpeg_all)
    set(FFMPEG_NATIVE_ALL_COMPONENTS "${_ffmpeg_all}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_load_dependency_rules)
    file(STRINGS "${FFMPEG_SOURCE_DIR}/configure" _ffmpeg_lines)

    set(_ffmpeg_collecting FALSE)
    set(_ffmpeg_name)
    set(_ffmpeg_kind)
    set(_ffmpeg_value)
    set(_ffmpeg_rule_features)
    foreach(_ffmpeg_line IN LISTS _ffmpeg_lines)
        if(NOT _ffmpeg_collecting)
            if(_ffmpeg_line MATCHES "^([A-Za-z0-9_]+)_(deps|select|suggest|if|if_any|conflict)=\"(.*)$")
                set(_ffmpeg_collecting TRUE)
                set(_ffmpeg_name "${CMAKE_MATCH_1}")
                set(_ffmpeg_kind "${CMAKE_MATCH_2}")
                set(_ffmpeg_line "${CMAKE_MATCH_3}")
                set(_ffmpeg_value)
            else()
                continue()
            endif()
        endif()

        if(_ffmpeg_line MATCHES "^(.*)\"[ \t]*$")
            string(APPEND _ffmpeg_value " ${CMAKE_MATCH_1}")
            _ffmpeg_native_normalize_words(_ffmpeg_items "${_ffmpeg_value}")
            set("FFMPEG_NATIVE_RULE_${_ffmpeg_name}_${_ffmpeg_kind}" "${_ffmpeg_items}" PARENT_SCOPE)
            list(APPEND _ffmpeg_rule_features "${_ffmpeg_name}")
            set(_ffmpeg_collecting FALSE)
        else()
            string(APPEND _ffmpeg_value " ${_ffmpeg_line}")
        endif()
    endforeach()
    list(REMOVE_DUPLICATES _ffmpeg_rule_features)
    set(FFMPEG_NATIVE_RULE_FEATURES "${_ffmpeg_rule_features}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_to_macro_suffix _out _name)
    string(TOUPPER "${_name}" _ffmpeg_macro)
    string(REGEX REPLACE "[^A-Z0-9]" "_" _ffmpeg_macro "${_ffmpeg_macro}")
    set(${_out} "${_ffmpeg_macro}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_component_option_name _out _name _suffix)
    if(_name MATCHES "_${_suffix}$")
        set(${_out} "${_name}" PARENT_SCOPE)
    else()
        set(${_out} "${_name}_${_suffix}" PARENT_SCOPE)
    endif()
endfunction()

function(_ffmpeg_native_append_user_list _enabled_var _explicit_var _list_var)
    foreach(_ffmpeg_name IN LISTS ${_list_var})
        if(NOT _ffmpeg_name STREQUAL "")
            list(APPEND ${_enabled_var} "${_ffmpeg_name}")
            list(APPEND ${_explicit_var} "${_ffmpeg_name}")
        endif()
    endforeach()
    set(${_enabled_var} "${${_enabled_var}}" PARENT_SCOPE)
    set(${_explicit_var} "${${_explicit_var}}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_append_user_components _enabled_var _explicit_var _option_var _suffix)
    foreach(_ffmpeg_name IN LISTS ${_option_var})
        if(NOT _ffmpeg_name STREQUAL "")
            _ffmpeg_native_component_option_name(_ffmpeg_feature "${_ffmpeg_name}" "${_suffix}")
            list(APPEND ${_enabled_var} "${_ffmpeg_feature}")
            list(APPEND ${_explicit_var} "${_ffmpeg_feature}")
        endif()
    endforeach()
    set(${_enabled_var} "${${_enabled_var}}" PARENT_SCOPE)
    set(${_explicit_var} "${${_explicit_var}}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_append_default_components _enabled_var)
    string(TOUPPER "${FFMPEG_NATIVE_DEFAULT_COMPONENT_SET}" _ffmpeg_default_set)
    if(_ffmpeg_default_set STREQUAL "NONE")
        set(${_enabled_var} "${${_enabled_var}}" PARENT_SCOPE)
        return()
    elseif(_ffmpeg_default_set STREQUAL "ALL")
        foreach(_ffmpeg_list_var IN ITEMS
                FFMPEG_NATIVE_ENCODER_LIST
                FFMPEG_NATIVE_DECODER_LIST
                FFMPEG_NATIVE_PARSER_LIST
                FFMPEG_NATIVE_BSF_LIST
                FFMPEG_NATIVE_HWACCEL_LIST
                FFMPEG_NATIVE_MUXER_LIST
                FFMPEG_NATIVE_DEMUXER_LIST
                FFMPEG_NATIVE_PROTOCOL_LIST
                FFMPEG_NATIVE_INDEV_LIST
                FFMPEG_NATIVE_OUTDEV_LIST
                FFMPEG_NATIVE_FILTER_LIST)
            list(APPEND ${_enabled_var} ${${_ffmpeg_list_var}})
        endforeach()
        set(${_enabled_var} "${${_enabled_var}}" PARENT_SCOPE)
        return()
    elseif(NOT _ffmpeg_default_set STREQUAL "COMMON")
        message(FATAL_ERROR "Unknown FFMPEG_NATIVE_DEFAULT_COMPONENT_SET='${FFMPEG_NATIVE_DEFAULT_COMPONENT_SET}'. Expected COMMON, ALL, or NONE.")
    endif()

    set(_ffmpeg_common_components
        aac_decoder
        aac_parser
        aac_adtstoasc_bsf
        ac3_decoder
        ac3_parser
        aiff_demuxer
        apng_decoder
        apng_demuxer
        av1_decoder
        av1_demuxer
        av1_frame_merge_bsf
        av1_frame_split_bsf
        av1_parser
        avi_demuxer
        bmp_decoder
        data_demuxer
        eac3_decoder
        eac3_core_bsf
        file_protocol
        flac_decoder
        flac_demuxer
        flac_parser
        flv_demuxer
        gif_decoder
        gif_demuxer
        h264_decoder
        h264_demuxer
        h264_mp4toannexb_bsf
        h264_parser
        hevc_decoder
        hevc_demuxer
        hevc_mp4toannexb_bsf
        hevc_parser
        image2_demuxer
        matroska_demuxer
        mjpeg_decoder
        mjpeg_demuxer
        mov_demuxer
        mp3_demuxer
        mp3_decoder
        mp3float_decoder
        mpeg4_decoder
        mpeg4video_parser
        mpegts_demuxer
        mpegvideo_demuxer
        mpegvideo_parser
        mpeg1video_decoder
        mpeg2video_decoder
        mpeg2video_parser
        null_filter
        anull_filter
        aformat_filter
        format_filter
        scale_filter
        aresample_filter
        opus_decoder
        opus_parser
        ogg_demuxer
        pcm_s16be_decoder
        pcm_s16le_decoder
        pcm_s24be_decoder
        pcm_s24le_decoder
        pcm_s32be_decoder
        pcm_s32le_decoder
        pcm_u8_decoder
        pipe_protocol
        png_decoder
        rawvideo_decoder
        subfile_protocol
        vc1_decoder
        vc1_parser
        vorbis_decoder
        vorbis_parser
        wav_demuxer
        webm_dash_manifest_demuxer
        vp8_decoder
        vp8_parser
        vp9_decoder
        vp9_parser
        vp9_superframe_split_bsf)

    foreach(_ffmpeg_component IN LISTS _ffmpeg_common_components)
        if(_ffmpeg_component IN_LIST _ffmpeg_all_components)
            list(APPEND ${_enabled_var} "${_ffmpeg_component}")
        endif()
    endforeach()
    set(${_enabled_var} "${${_enabled_var}}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_append_disabled_components _disabled_var _option_var _suffix)
    foreach(_ffmpeg_name IN LISTS ${_option_var})
        if(NOT _ffmpeg_name STREQUAL "")
            _ffmpeg_native_component_option_name(_ffmpeg_feature "${_ffmpeg_name}" "${_suffix}")
            list(APPEND ${_disabled_var} "${_ffmpeg_feature}")
        endif()
    endforeach()
    set(${_disabled_var} "${${_disabled_var}}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_collect_example_config_features _out)
    _ffmpeg_native_expand_configure_list(_ffmpeg_examples EXAMPLE_LIST)

    set(_ffmpeg_makefile "${FFMPEG_SOURCE_DIR}/doc/examples/Makefile")
    if(EXISTS "${_ffmpeg_makefile}")
        file(STRINGS "${_ffmpeg_makefile}" _ffmpeg_lines)
        foreach(_ffmpeg_line IN LISTS _ffmpeg_lines)
            if(_ffmpeg_line MATCHES "^EXAMPLES-\\$\\(CONFIG_([A-Z0-9_]+)\\)")
                string(TOLOWER "${CMAKE_MATCH_1}" _ffmpeg_makefile_feature)
                list(APPEND _ffmpeg_examples "${_ffmpeg_makefile_feature}")
            endif()
        endforeach()
    endif()

    list(REMOVE_DUPLICATES _ffmpeg_examples)
    list(SORT _ffmpeg_examples)
    set(${_out} "${_ffmpeg_examples}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_remove_disabled _enabled_var _disabled)
    foreach(_ffmpeg_disabled IN LISTS _disabled)
        list(REMOVE_ITEM ${_enabled_var} "${_ffmpeg_disabled}")
    endforeach()
    set(${_enabled_var} "${${_enabled_var}}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_dependency_rule_feature _out _feature)
    set(_ffmpeg_rule_feature "${_feature}")
    if(NOT DEFINED FFMPEG_NATIVE_RULE_${_ffmpeg_rule_feature}_deps AND _feature MATCHES "^(.*)_example$")
        set(_ffmpeg_base_feature "${CMAKE_MATCH_1}")
        if(DEFINED FFMPEG_NATIVE_RULE_${_ffmpeg_base_feature}_deps)
            set(_ffmpeg_rule_feature "${_ffmpeg_base_feature}")
        endif()
    endif()
    set(${_out} "${_ffmpeg_rule_feature}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_feature_is_enabled _out _feature)
    if(_feature IN_LIST _ffmpeg_enabled_config OR
       _feature IN_LIST _ffmpeg_enabled_components OR
       _feature IN_LIST _ffmpeg_enabled_have OR
       _feature IN_LIST _ffmpeg_enabled_arch)
        set(${_out} TRUE PARENT_SCOPE)
    else()
        set(${_out} FALSE PARENT_SCOPE)
    endif()
endfunction()

function(_ffmpeg_native_enable_known_feature _changed_var _feature)
    if(_feature IN_LIST _ffmpeg_all_components)
        list(FIND _ffmpeg_enabled_components "${_feature}" _ffmpeg_index)
        if(_ffmpeg_index EQUAL -1)
            list(APPEND _ffmpeg_enabled_components "${_feature}")
            set(${_changed_var} TRUE PARENT_SCOPE)
        endif()
    elseif(_feature IN_LIST _ffmpeg_all_config)
        list(FIND _ffmpeg_enabled_config "${_feature}" _ffmpeg_index)
        if(_ffmpeg_index EQUAL -1)
            list(APPEND _ffmpeg_enabled_config "${_feature}")
            set(${_changed_var} TRUE PARENT_SCOPE)
        endif()
    elseif(_feature IN_LIST _ffmpeg_all_have)
        list(FIND _ffmpeg_enabled_have "${_feature}" _ffmpeg_index)
        if(_ffmpeg_index EQUAL -1)
            list(APPEND _ffmpeg_enabled_have "${_feature}")
            set(${_changed_var} TRUE PARENT_SCOPE)
        endif()
    elseif(_feature IN_LIST _ffmpeg_all_arch)
        list(FIND _ffmpeg_enabled_arch "${_feature}" _ffmpeg_index)
        if(_ffmpeg_index EQUAL -1)
            list(APPEND _ffmpeg_enabled_arch "${_feature}")
            set(${_changed_var} TRUE PARENT_SCOPE)
        endif()
    endif()

    set(_ffmpeg_enabled_config "${_ffmpeg_enabled_config}" PARENT_SCOPE)
    set(_ffmpeg_enabled_components "${_ffmpeg_enabled_components}" PARENT_SCOPE)
    set(_ffmpeg_enabled_have "${_ffmpeg_enabled_have}" PARENT_SCOPE)
    set(_ffmpeg_enabled_arch "${_ffmpeg_enabled_arch}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_resolve_dependency_rules)
    foreach(_ffmpeg_unused RANGE 0 200)
        set(_ffmpeg_changed FALSE)

        foreach(_ffmpeg_feature IN LISTS _ffmpeg_enabled_config _ffmpeg_enabled_components)
            foreach(_ffmpeg_selected IN LISTS FFMPEG_NATIVE_RULE_${_ffmpeg_feature}_select)
                _ffmpeg_native_enable_known_feature(_ffmpeg_changed "${_ffmpeg_selected}")
            endforeach()
        endforeach()

        foreach(_ffmpeg_feature IN LISTS FFMPEG_NATIVE_RULE_FEATURES)
            if(DEFINED FFMPEG_NATIVE_RULE_${_ffmpeg_feature}_if_any)
                set(_ffmpeg_has_any FALSE)
                foreach(_ffmpeg_dep IN LISTS FFMPEG_NATIVE_RULE_${_ffmpeg_feature}_if_any)
                    _ffmpeg_native_feature_is_enabled(_ffmpeg_dep_enabled "${_ffmpeg_dep}")
                    if(_ffmpeg_dep_enabled)
                        set(_ffmpeg_has_any TRUE)
                        break()
                    endif()
                endforeach()
                if(_ffmpeg_has_any)
                    _ffmpeg_native_enable_known_feature(_ffmpeg_changed "${_ffmpeg_feature}")
                endif()
            endif()

            if(DEFINED FFMPEG_NATIVE_RULE_${_ffmpeg_feature}_if)
                set(_ffmpeg_has_all TRUE)
                foreach(_ffmpeg_dep IN LISTS FFMPEG_NATIVE_RULE_${_ffmpeg_feature}_if)
                    _ffmpeg_native_feature_is_enabled(_ffmpeg_dep_enabled "${_ffmpeg_dep}")
                    if(NOT _ffmpeg_dep_enabled)
                        set(_ffmpeg_has_all FALSE)
                        break()
                    endif()
                endforeach()
                if(_ffmpeg_has_all)
                    _ffmpeg_native_enable_known_feature(_ffmpeg_changed "${_ffmpeg_feature}")
                endif()
            endif()
        endforeach()

        if(NOT _ffmpeg_changed)
            break()
        endif()
    endforeach()

    foreach(_ffmpeg_unused RANGE 0 200)
        set(_ffmpeg_changed FALSE)

        foreach(_ffmpeg_feature IN LISTS _ffmpeg_enabled_config)
            _ffmpeg_native_dependency_rule_feature(_ffmpeg_rule_feature "${_ffmpeg_feature}")
            set(_ffmpeg_missing_deps)
            foreach(_ffmpeg_rule_kind IN ITEMS deps select)
                foreach(_ffmpeg_dep IN LISTS FFMPEG_NATIVE_RULE_${_ffmpeg_rule_feature}_${_ffmpeg_rule_kind})
                    if(_ffmpeg_dep IN_LIST _ffmpeg_all_config OR
                       _ffmpeg_dep IN_LIST _ffmpeg_all_components OR
                       _ffmpeg_dep IN_LIST _ffmpeg_all_have OR
                       _ffmpeg_dep IN_LIST _ffmpeg_all_arch)
                        _ffmpeg_native_feature_is_enabled(_ffmpeg_dep_enabled "${_ffmpeg_dep}")
                        if(NOT _ffmpeg_dep_enabled)
                            list(APPEND _ffmpeg_missing_deps "${_ffmpeg_dep}")
                        endif()
                    endif()
                endforeach()
            endforeach()
            if(_ffmpeg_missing_deps AND NOT _ffmpeg_feature IN_LIST _ffmpeg_explicit_config)
                list(REMOVE_ITEM _ffmpeg_enabled_config "${_ffmpeg_feature}")
                set(_ffmpeg_changed TRUE)
            endif()
        endforeach()

        foreach(_ffmpeg_feature IN LISTS _ffmpeg_enabled_components)
            _ffmpeg_native_dependency_rule_feature(_ffmpeg_rule_feature "${_ffmpeg_feature}")
            set(_ffmpeg_missing_deps)
            foreach(_ffmpeg_rule_kind IN ITEMS deps select)
                foreach(_ffmpeg_dep IN LISTS FFMPEG_NATIVE_RULE_${_ffmpeg_rule_feature}_${_ffmpeg_rule_kind})
                    if(_ffmpeg_dep IN_LIST _ffmpeg_all_config OR
                       _ffmpeg_dep IN_LIST _ffmpeg_all_components OR
                       _ffmpeg_dep IN_LIST _ffmpeg_all_have OR
                       _ffmpeg_dep IN_LIST _ffmpeg_all_arch)
                        _ffmpeg_native_feature_is_enabled(_ffmpeg_dep_enabled "${_ffmpeg_dep}")
                        if(NOT _ffmpeg_dep_enabled)
                            list(APPEND _ffmpeg_missing_deps "${_ffmpeg_dep}")
                        endif()
                    endif()
                endforeach()
            endforeach()
            if(_ffmpeg_missing_deps AND NOT _ffmpeg_feature IN_LIST _ffmpeg_explicit_components)
                list(REMOVE_ITEM _ffmpeg_enabled_components "${_ffmpeg_feature}")
                set(_ffmpeg_changed TRUE)
            endif()
        endforeach()

        if(NOT _ffmpeg_changed)
            break()
        endif()
    endforeach()

    foreach(_ffmpeg_feature IN LISTS _ffmpeg_enabled_config _ffmpeg_enabled_components)
        foreach(_ffmpeg_conflict IN LISTS FFMPEG_NATIVE_RULE_${_ffmpeg_feature}_conflict)
            _ffmpeg_native_feature_is_enabled(_ffmpeg_conflict_enabled "${_ffmpeg_conflict}")
            if(_ffmpeg_conflict_enabled)
                message(FATAL_ERROR "Native FFmpeg feature '${_ffmpeg_feature}' conflicts with enabled feature '${_ffmpeg_conflict}'")
            endif()
        endforeach()
    endforeach()

    foreach(_ffmpeg_feature IN LISTS _ffmpeg_explicit_config _ffmpeg_explicit_components)
        _ffmpeg_native_dependency_rule_feature(_ffmpeg_rule_feature "${_ffmpeg_feature}")
        foreach(_ffmpeg_rule_kind IN ITEMS deps select)
            foreach(_ffmpeg_dep IN LISTS FFMPEG_NATIVE_RULE_${_ffmpeg_rule_feature}_${_ffmpeg_rule_kind})
                if(_ffmpeg_dep IN_LIST _ffmpeg_all_config OR
                   _ffmpeg_dep IN_LIST _ffmpeg_all_components OR
                   _ffmpeg_dep IN_LIST _ffmpeg_all_have OR
                   _ffmpeg_dep IN_LIST _ffmpeg_all_arch)
                    _ffmpeg_native_feature_is_enabled(_ffmpeg_dep_enabled "${_ffmpeg_dep}")
                    if(NOT _ffmpeg_dep_enabled)
                        message(FATAL_ERROR "Native FFmpeg feature '${_ffmpeg_feature}' requires '${_ffmpeg_dep}'. Enable it explicitly or provide a detector for it.")
                    endif()
                endif()
            endforeach()
        endforeach()
    endforeach()

    set(_ffmpeg_enabled_config "${_ffmpeg_enabled_config}" PARENT_SCOPE)
    set(_ffmpeg_enabled_components "${_ffmpeg_enabled_components}" PARENT_SCOPE)
    set(_ffmpeg_enabled_have "${_ffmpeg_enabled_have}" PARENT_SCOPE)
    set(_ffmpeg_enabled_arch "${_ffmpeg_enabled_arch}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_detect_base_have)
    set(_ffmpeg_enabled_have
        atanf
        atan2f
        cbrt
        cbrtf
        copysign
        cosf
        erf
        expf
        exp2
        exp2f
        hypot
        isfinite
        isinf
        isnan
        ldexpf
        llrint
        llrintf
        log2
        log2f
        log10f
        lrint
        lrintf
        powf
        rint
        round
        roundf
        sinf
        trunc
        truncf
        getenv)

    if(CMAKE_C_BYTE_ORDER STREQUAL "BIG_ENDIAN")
        list(APPEND _ffmpeg_enabled_have bigendian)
    endif()

    if(CMAKE_SIZEOF_VOID_P EQUAL 8)
        list(APPEND _ffmpeg_enabled_have fast_64bit)
    endif()

    if(CMAKE_SYSTEM_PROCESSOR MATCHES "^(x86_64|AMD64|amd64|x64|x86|i[3-6]86|X86)$")
        list(APPEND _ffmpeg_enabled_have fast_unaligned)
    endif()

    if(FFMPEG_NATIVE_ENABLE_THREADS)
        list(APPEND _ffmpeg_enabled_have threads)
        if(WIN32)
            list(APPEND _ffmpeg_enabled_have w32threads)
        else()
            list(APPEND _ffmpeg_enabled_have pthreads)
        endif()
    endif()

    if(FFMPEG_NATIVE_ENABLE_ASM AND CMAKE_SYSTEM_PROCESSOR MATCHES "^(x86_64|AMD64|amd64|x64|x86|i[3-6]86|X86)$")
        _ffmpeg_native_expand_configure_list(_ffmpeg_x86_ext ARCH_EXT_LIST_X86)
        list(APPEND _ffmpeg_enabled_have x86asm ${_ffmpeg_x86_ext})
        foreach(_ffmpeg_x86_feature IN LISTS _ffmpeg_x86_ext)
            list(APPEND _ffmpeg_enabled_have "${_ffmpeg_x86_feature}_external")
        endforeach()
    endif()

    if(WIN32)
        list(APPEND _ffmpeg_enabled_have
            CommandLineToArgvW
            GetModuleHandle
            GetProcessAffinityMask
            GetStdHandle
            GetSystemTimeAsFileTime
            MapViewOfFile
            SetConsoleTextAttribute
            VirtualAlloc
            io_h
            libc_msvcrt
            windows_h
            winsock2_h)
    elseif(APPLE)
        list(APPEND _ffmpeg_enabled_have
            access
            clock_gettime
            dirent_h
            fcntl
            fork
            gettimeofday
            isatty
            lstat
            mach_absolute_time
            mmap
            posix_memalign
            sys_time_h
            sys_un_h
            unistd_h)
    else()
        list(APPEND _ffmpeg_enabled_have
            access
            clock_gettime
            dirent_h
            fcntl
            fork
            gettimeofday
            isatty
            lstat
            mkstemp
            mmap
            posix_memalign
            sysconf
            sys_time_h
            sys_un_h
            unistd_h)
    endif()

    list(REMOVE_DUPLICATES _ffmpeg_enabled_have)
    set(_ffmpeg_enabled_have "${_ffmpeg_enabled_have}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_detect_arch)
    set(_ffmpeg_enabled_arch)
    if(CMAKE_SYSTEM_PROCESSOR MATCHES "^(x86_64|AMD64|amd64|x64)$")
        list(APPEND _ffmpeg_enabled_arch x86 x86_64)
    elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "^(x86|i[3-6]86|X86)$")
        list(APPEND _ffmpeg_enabled_arch x86 x86_32)
    elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "^(aarch64|ARM64|arm64)$")
        list(APPEND _ffmpeg_enabled_arch aarch64)
    elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "^(arm|ARM)")
        list(APPEND _ffmpeg_enabled_arch arm)
    elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "^(riscv64|riscv)$")
        list(APPEND _ffmpeg_enabled_arch riscv)
    elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "^(ppc64|powerpc64)$")
        list(APPEND _ffmpeg_enabled_arch ppc ppc64)
    elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "^(ppc|powerpc)$")
        list(APPEND _ffmpeg_enabled_arch ppc)
    endif()
    set(_ffmpeg_enabled_arch "${_ffmpeg_enabled_arch}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_validate_license_gates)
    foreach(_ffmpeg_lib IN LISTS FFMPEG_ENABLE_EXTERNAL_LIBRARIES FFMPEG_ENABLE_FEATURES _ffmpeg_enabled_config)
        if(_ffmpeg_lib IN_LIST _ffmpeg_external_gpl AND NOT FFMPEG_ENABLE_GPL)
            message(FATAL_ERROR "Native FFmpeg feature '${_ffmpeg_lib}' is GPL. Enable FFMPEG_ENABLE_GPL=ON.")
        endif()
        if(_ffmpeg_lib IN_LIST _ffmpeg_external_nonfree AND NOT FFMPEG_ENABLE_NONFREE)
            message(FATAL_ERROR "Native FFmpeg feature '${_ffmpeg_lib}' is nonfree. Enable FFMPEG_ENABLE_NONFREE=ON.")
        endif()
        if(_ffmpeg_lib IN_LIST _ffmpeg_external_version3 AND NOT FFMPEG_ENABLE_VERSION3)
            message(FATAL_ERROR "Native FFmpeg feature '${_ffmpeg_lib}' requires version3. Enable FFMPEG_ENABLE_VERSION3=ON.")
        endif()
        if(_ffmpeg_lib IN_LIST _ffmpeg_external_gplv3 AND (NOT FFMPEG_ENABLE_GPL OR NOT FFMPEG_ENABLE_VERSION3))
            message(FATAL_ERROR "Native FFmpeg feature '${_ffmpeg_lib}' is GPLv3. Enable FFMPEG_ENABLE_GPL=ON and FFMPEG_ENABLE_VERSION3=ON.")
        endif()
    endforeach()
endfunction()

function(ffmpeg_native_autoconfig)
    _ffmpeg_native_expand_configure_list(_ffmpeg_config CONFIG_LIST)
    _ffmpeg_native_expand_configure_list(_ffmpeg_config_extra CONFIG_EXTRA)
    _ffmpeg_native_expand_configure_list(_ffmpeg_have HAVE_LIST)
    _ffmpeg_native_expand_configure_list(_ffmpeg_arch ARCH_LIST)
    _ffmpeg_native_expand_configure_list(_ffmpeg_external_gpl EXTERNAL_LIBRARY_GPL_LIST)
    _ffmpeg_native_expand_configure_list(_ffmpeg_external_nonfree EXTERNAL_LIBRARY_NONFREE_LIST)
    _ffmpeg_native_expand_configure_list(_ffmpeg_external_version3 EXTERNAL_LIBRARY_VERSION3_LIST)
    _ffmpeg_native_expand_configure_list(_ffmpeg_external_gplv3 EXTERNAL_LIBRARY_GPLV3_LIST)
    _ffmpeg_native_expand_configure_list(_ffmpeg_hwaccel_nonfree HWACCEL_LIBRARY_NONFREE_LIST)
    list(APPEND _ffmpeg_external_nonfree ${_ffmpeg_hwaccel_nonfree})
    list(REMOVE_DUPLICATES _ffmpeg_external_nonfree)
    _ffmpeg_native_collect_component_lists()
    _ffmpeg_native_load_dependency_rules()
    _ffmpeg_native_detect_base_have()
    _ffmpeg_native_detect_arch()

    set(_ffmpeg_all_config ${_ffmpeg_config} ${_ffmpeg_config_extra})
    set(_ffmpeg_all_have ${_ffmpeg_have})
    set(_ffmpeg_all_arch ${_ffmpeg_arch})
    set(_ffmpeg_all_components ${FFMPEG_NATIVE_ALL_COMPONENTS})
    list(REMOVE_DUPLICATES _ffmpeg_all_config)
    list(REMOVE_DUPLICATES _ffmpeg_all_have)
    list(REMOVE_DUPLICATES _ffmpeg_all_arch)

    set(_ffmpeg_enabled_config)
    set(_ffmpeg_explicit_config)
    set(_ffmpeg_enabled_components)
    set(_ffmpeg_explicit_components)

    if(NOT FFMPEG_DISABLE_AUTODETECT)
        list(APPEND _ffmpeg_enabled_config autodetect)
    endif()
    if(FFMPEG_BUILD_STATIC)
        list(APPEND _ffmpeg_enabled_config static)
    endif()
    if(FFMPEG_BUILD_SHARED)
        list(APPEND _ffmpeg_enabled_config shared)
    endif()
    if(FFMPEG_BUILD_SHARED OR CMAKE_POSITION_INDEPENDENT_CODE)
        list(APPEND _ffmpeg_enabled_config pic)
    endif()
    if(FFMPEG_ENABLE_GPL)
        list(APPEND _ffmpeg_enabled_config gpl)
    endif()
    if(FFMPEG_ENABLE_VERSION3)
        list(APPEND _ffmpeg_enabled_config version3)
    endif()
    if(FFMPEG_ENABLE_NONFREE)
        list(APPEND _ffmpeg_enabled_config nonfree)
    endif()
    if(FFMPEG_NATIVE_ENABLE_THREADS)
        list(APPEND _ffmpeg_enabled_config threads)
    endif()
    if(WIN32)
        list(APPEND _ffmpeg_enabled_config atomics_win32)
    else()
        list(APPEND _ffmpeg_enabled_config stdatomic)
    endif()
    if(FFMPEG_BUILD_PROGRAMS)
        if(FFMPEG_NATIVE_BUILD_FFMPEG)
            list(APPEND _ffmpeg_enabled_config ffmpeg)
            list(APPEND _ffmpeg_explicit_config ffmpeg)
        endif()
        if(FFMPEG_NATIVE_BUILD_FFPROBE)
            list(APPEND _ffmpeg_enabled_config ffprobe)
            list(APPEND _ffmpeg_explicit_config ffprobe)
        endif()
        if(FFMPEG_NATIVE_BUILD_FFPLAY)
            list(APPEND _ffmpeg_enabled_config ffplay sdl2)
            list(APPEND _ffmpeg_explicit_config ffplay sdl2)
        endif()
    endif()

    if(FFMPEG_NATIVE_BUILD_EXAMPLES)
        _ffmpeg_native_collect_example_config_features(_ffmpeg_examples)
        list(APPEND _ffmpeg_enabled_config ${_ffmpeg_examples})
    endif()

    foreach(_ffmpeg_component IN LISTS FFMPEG_NATIVE_COMPONENTS)
        list(APPEND _ffmpeg_enabled_config "${_ffmpeg_component}")
    endforeach()

    if(FFMPEG_NATIVE_ENABLE_DEFAULT_COMPONENTS)
        _ffmpeg_native_append_default_components(_ffmpeg_enabled_components)
    endif()

    _ffmpeg_native_append_user_list(_ffmpeg_enabled_config _ffmpeg_explicit_config FFMPEG_ENABLE_FEATURES)
    _ffmpeg_native_append_user_list(_ffmpeg_enabled_config _ffmpeg_explicit_config FFMPEG_ENABLE_EXTERNAL_LIBRARIES)

    _ffmpeg_native_append_user_components(_ffmpeg_enabled_components _ffmpeg_explicit_components FFMPEG_ENABLE_ENCODERS encoder)
    _ffmpeg_native_append_user_components(_ffmpeg_enabled_components _ffmpeg_explicit_components FFMPEG_ENABLE_DECODERS decoder)
    _ffmpeg_native_append_user_components(_ffmpeg_enabled_components _ffmpeg_explicit_components FFMPEG_ENABLE_HWACCELS hwaccel)
    _ffmpeg_native_append_user_components(_ffmpeg_enabled_components _ffmpeg_explicit_components FFMPEG_ENABLE_MUXERS muxer)
    _ffmpeg_native_append_user_components(_ffmpeg_enabled_components _ffmpeg_explicit_components FFMPEG_ENABLE_DEMUXERS demuxer)
    _ffmpeg_native_append_user_components(_ffmpeg_enabled_components _ffmpeg_explicit_components FFMPEG_ENABLE_PARSERS parser)
    _ffmpeg_native_append_user_components(_ffmpeg_enabled_components _ffmpeg_explicit_components FFMPEG_ENABLE_BSFS bsf)
    _ffmpeg_native_append_user_components(_ffmpeg_enabled_components _ffmpeg_explicit_components FFMPEG_ENABLE_PROTOCOLS protocol)
    _ffmpeg_native_append_user_components(_ffmpeg_enabled_components _ffmpeg_explicit_components FFMPEG_ENABLE_INDEVS indev)
    _ffmpeg_native_append_user_components(_ffmpeg_enabled_components _ffmpeg_explicit_components FFMPEG_ENABLE_OUTDEVS outdev)
    _ffmpeg_native_append_user_components(_ffmpeg_enabled_components _ffmpeg_explicit_components FFMPEG_ENABLE_FILTERS filter)

    set(_ffmpeg_disabled_config ${FFMPEG_DISABLE_FEATURES} ${FFMPEG_DISABLE_EXTERNAL_LIBRARIES})
    set(_ffmpeg_disabled_components)
    _ffmpeg_native_append_disabled_components(_ffmpeg_disabled_components FFMPEG_DISABLE_ENCODERS encoder)
    _ffmpeg_native_append_disabled_components(_ffmpeg_disabled_components FFMPEG_DISABLE_DECODERS decoder)
    _ffmpeg_native_append_disabled_components(_ffmpeg_disabled_components FFMPEG_DISABLE_HWACCELS hwaccel)
    _ffmpeg_native_append_disabled_components(_ffmpeg_disabled_components FFMPEG_DISABLE_MUXERS muxer)
    _ffmpeg_native_append_disabled_components(_ffmpeg_disabled_components FFMPEG_DISABLE_DEMUXERS demuxer)
    _ffmpeg_native_append_disabled_components(_ffmpeg_disabled_components FFMPEG_DISABLE_PARSERS parser)
    _ffmpeg_native_append_disabled_components(_ffmpeg_disabled_components FFMPEG_DISABLE_BSFS bsf)
    _ffmpeg_native_append_disabled_components(_ffmpeg_disabled_components FFMPEG_DISABLE_PROTOCOLS protocol)
    _ffmpeg_native_append_disabled_components(_ffmpeg_disabled_components FFMPEG_DISABLE_INDEVS indev)
    _ffmpeg_native_append_disabled_components(_ffmpeg_disabled_components FFMPEG_DISABLE_OUTDEVS outdev)
    _ffmpeg_native_append_disabled_components(_ffmpeg_disabled_components FFMPEG_DISABLE_FILTERS filter)

    _ffmpeg_native_remove_disabled(_ffmpeg_enabled_config "${_ffmpeg_disabled_config}")
    _ffmpeg_native_remove_disabled(_ffmpeg_enabled_components "${_ffmpeg_disabled_components}")
    _ffmpeg_native_resolve_dependency_rules()
    _ffmpeg_native_remove_disabled(_ffmpeg_enabled_config "${_ffmpeg_disabled_config}")
    _ffmpeg_native_remove_disabled(_ffmpeg_enabled_components "${_ffmpeg_disabled_components}")
    _ffmpeg_native_validate_license_gates()

    list(REMOVE_DUPLICATES _ffmpeg_enabled_config)
    list(REMOVE_DUPLICATES _ffmpeg_enabled_components)
    list(REMOVE_DUPLICATES _ffmpeg_enabled_have)
    list(REMOVE_DUPLICATES _ffmpeg_enabled_arch)
    list(SORT _ffmpeg_all_config)
    list(SORT _ffmpeg_all_components)
    list(SORT _ffmpeg_all_have)
    list(SORT _ffmpeg_all_arch)
    list(SORT _ffmpeg_enabled_config)
    list(SORT _ffmpeg_enabled_components)
    list(SORT _ffmpeg_enabled_have)
    list(SORT _ffmpeg_enabled_arch)

    set(_ffmpeg_license "LGPL version 2.1 or later")
    if(FFMPEG_ENABLE_NONFREE)
        set(_ffmpeg_license "nonfree and unredistributable")
    elseif(FFMPEG_ENABLE_GPL AND FFMPEG_ENABLE_VERSION3)
        set(_ffmpeg_license "GPL version 3 or later")
    elseif(FFMPEG_ENABLE_GPL)
        set(_ffmpeg_license "GPL version 2 or later")
    elseif(FFMPEG_ENABLE_VERSION3)
        set(_ffmpeg_license "LGPL version 3 or later")
    endif()

    set(FFMPEG_NATIVE_ALL_CONFIG_FEATURES "${_ffmpeg_all_config}" PARENT_SCOPE)
    set(FFMPEG_NATIVE_ALL_COMPONENT_FEATURES "${_ffmpeg_all_components}" PARENT_SCOPE)
    set(FFMPEG_NATIVE_ALL_HAVE_FEATURES "${_ffmpeg_all_have}" PARENT_SCOPE)
    set(FFMPEG_NATIVE_ALL_ARCH_FEATURES "${_ffmpeg_all_arch}" PARENT_SCOPE)
    set(FFMPEG_NATIVE_ENABLED_CONFIG_FEATURES "${_ffmpeg_enabled_config}" PARENT_SCOPE)
    set(FFMPEG_NATIVE_ENABLED_COMPONENT_FEATURES "${_ffmpeg_enabled_components}" PARENT_SCOPE)
    set(FFMPEG_NATIVE_ENABLED_HAVE_FEATURES "${_ffmpeg_enabled_have}" PARENT_SCOPE)
    set(FFMPEG_NATIVE_ENABLED_ARCH_FEATURES "${_ffmpeg_enabled_arch}" PARENT_SCOPE)
    set(FFMPEG_NATIVE_LICENSE "${_ffmpeg_license}" PARENT_SCOPE)
endfunction()
