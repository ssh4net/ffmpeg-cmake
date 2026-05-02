include_guard(GLOBAL)

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

function(_ffmpeg_native_component_option_name _out _name _suffix)
    if(_name MATCHES "_${_suffix}$")
        set(${_out} "${_name}" PARENT_SCOPE)
    else()
        set(${_out} "${_name}_${_suffix}" PARENT_SCOPE)
    endif()
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
        aiff_muxer
        adts_muxer
        apng_decoder
        apng_demuxer
        av1_decoder
        av1_demuxer
        av1_frame_merge_bsf
        av1_frame_split_bsf
        av1_parser
        avi_demuxer
        avi_muxer
        bmp_decoder
        data_demuxer
        data_muxer
        eac3_decoder
        eac3_core_bsf
        file_protocol
        flac_decoder
        flac_demuxer
        flac_parser
        flac_muxer
        flv_demuxer
        flv_muxer
        gif_decoder
        gif_demuxer
        gif_muxer
        h264_decoder
        h264_demuxer
        h264_muxer
        h264_mp4toannexb_bsf
        h264_parser
        hevc_decoder
        hevc_demuxer
        hevc_muxer
        hevc_mp4toannexb_bsf
        hevc_parser
        image2_demuxer
        image2_muxer
        matroska_demuxer
        matroska_muxer
        mjpeg_decoder
        mjpeg_demuxer
        mov_demuxer
        mov_muxer
        mp3_demuxer
        mp3_decoder
        mp3float_decoder
        mp3_muxer
        mp4_muxer
        mpeg4_decoder
        mpeg4video_parser
        mpegts_demuxer
        mpegts_muxer
        mpegvideo_demuxer
        mpegvideo_parser
        mpeg1video_decoder
        mpeg2video_decoder
        mpeg2video_parser
        null_muxer
        null_filter
        anull_filter
        aformat_filter
        format_filter
        scale_filter
        aresample_filter
        opus_decoder
        opus_parser
        ogg_demuxer
        ogg_muxer
        opus_muxer
        pcm_s16be_decoder
        pcm_s16be_muxer
        pcm_s16le_decoder
        pcm_s16le_muxer
        pcm_s24be_decoder
        pcm_s24be_muxer
        pcm_s24le_decoder
        pcm_s24le_muxer
        pcm_s32be_decoder
        pcm_s32be_muxer
        pcm_s32le_decoder
        pcm_s32le_muxer
        pcm_u8_decoder
        pcm_u8_muxer
        pipe_protocol
        png_decoder
        rawvideo_decoder
        rawvideo_muxer
        subfile_protocol
        vc1_decoder
        vc1_parser
        vorbis_decoder
        vorbis_parser
        wav_demuxer
        wav_muxer
        webm_dash_manifest_demuxer
        webm_muxer
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

function(_ffmpeg_native_hardware_backend_feature _out _backend)
    if(_backend STREQUAL "d3d11va2")
        set(${_out} "d3d11va" PARENT_SCOPE)
    elseif(_backend STREQUAL "mf")
        set(${_out} "mediafoundation" PARENT_SCOPE)
    elseif(_backend STREQUAL "v4l2m2m")
        set(${_out} "v4l2_m2m" PARENT_SCOPE)
    else()
        set(${_out} "${_backend}" PARENT_SCOPE)
    endif()
endfunction()

function(_ffmpeg_native_append_hardware_if_backend _enabled_var _config_var _component _backend)
    _ffmpeg_native_hardware_backend_feature(_ffmpeg_backend_feature "${_backend}")
    if(_ffmpeg_backend_feature IN_LIST ${_config_var})
        list(APPEND ${_enabled_var} "${_component}")
    endif()
    set(${_enabled_var} "${${_enabled_var}}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_append_hardware_components _enabled_var _config_var)
    if(NOT FFMPEG_NATIVE_ENABLE_HARDWARE_COMPONENTS)
        set(${_enabled_var} "${${_enabled_var}}" PARENT_SCOPE)
        return()
    endif()

    foreach(_ffmpeg_component IN LISTS FFMPEG_NATIVE_HWACCEL_LIST)
        if(_ffmpeg_component MATCHES "_(amf|cuda|d3d11va|d3d11va2|d3d12va|dxva2|nvdec|qsv|vaapi|vdpau|videotoolbox)_hwaccel$")
            _ffmpeg_native_append_hardware_if_backend(${_enabled_var} ${_config_var} "${_ffmpeg_component}" "${CMAKE_MATCH_1}")
        endif()
    endforeach()

    foreach(_ffmpeg_component IN LISTS FFMPEG_NATIVE_ENCODER_LIST FFMPEG_NATIVE_DECODER_LIST)
        if(_ffmpeg_component MATCHES "_(amf|cuvid|d3d12va|mediacodec|mf|nvenc|qsv|rkmpp|vaapi|v4l2m2m|videotoolbox)_(encoder|decoder)$")
            _ffmpeg_native_append_hardware_if_backend(${_enabled_var} ${_config_var} "${_ffmpeg_component}" "${CMAKE_MATCH_1}")
        endif()
    endforeach()

    foreach(_ffmpeg_component IN LISTS FFMPEG_NATIVE_FILTER_LIST)
        if(_ffmpeg_component MATCHES "(^amf_capture|_amf)_filter$")
            _ffmpeg_native_append_hardware_if_backend(${_enabled_var} ${_config_var} "${_ffmpeg_component}" amf)
        elseif(_ffmpeg_component MATCHES "_qsv_filter$")
            _ffmpeg_native_append_hardware_if_backend(${_enabled_var} ${_config_var} "${_ffmpeg_component}" qsv)
        elseif(_ffmpeg_component MATCHES "_d3d11_filter$")
            _ffmpeg_native_append_hardware_if_backend(${_enabled_var} ${_config_var} "${_ffmpeg_component}" d3d11va)
        elseif(_ffmpeg_component MATCHES "_d3d12_filter$")
            _ffmpeg_native_append_hardware_if_backend(${_enabled_var} ${_config_var} "${_ffmpeg_component}" d3d12va)
        endif()
    endforeach()

    list(REMOVE_DUPLICATES ${_enabled_var})
    set(${_enabled_var} "${${_enabled_var}}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_append_component_if_known _enabled_var _component)
    if("${_component}" IN_LIST FFMPEG_NATIVE_ALL_COMPONENTS)
        list(APPEND ${_enabled_var} "${_component}")
    endif()
    set(${_enabled_var} "${${_enabled_var}}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_append_external_if_feature _enabled_var _config_var _feature)
    if(NOT "${_feature}" IN_LIST ${_config_var})
        set(${_enabled_var} "${${_enabled_var}}" PARENT_SCOPE)
        return()
    endif()

    foreach(_ffmpeg_component IN LISTS ARGN)
        _ffmpeg_native_append_component_if_known(${_enabled_var} "${_ffmpeg_component}")
    endforeach()
    set(${_enabled_var} "${${_enabled_var}}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_append_external_components _enabled_var _config_var)
    if(NOT FFMPEG_NATIVE_ENABLE_EXTERNAL_COMPONENTS)
        set(${_enabled_var} "${${_enabled_var}}" PARENT_SCOPE)
        return()
    endif()

    _ffmpeg_native_append_external_if_feature(${_enabled_var} ${_config_var} libaom
        libaom_av1_decoder
        libaom_av1_encoder)
    _ffmpeg_native_append_external_if_feature(${_enabled_var} ${_config_var} libass
        ass_filter
        subtitles_filter)
    _ffmpeg_native_append_external_if_feature(${_enabled_var} ${_config_var} libdav1d
        libdav1d_decoder)
    _ffmpeg_native_append_external_if_feature(${_enabled_var} ${_config_var} libfreetype
        drawtext_filter)
    _ffmpeg_native_append_external_if_feature(${_enabled_var} ${_config_var} libharfbuzz
        drawtext_filter)
    _ffmpeg_native_append_external_if_feature(${_enabled_var} ${_config_var} lcms2
        iccdetect_filter
        iccgen_filter)
    if(libjxl IN_LIST ${_config_var} AND libjxl_threads IN_LIST ${_config_var})
        _ffmpeg_native_append_component_if_known(${_enabled_var} libjxl_anim_decoder)
        _ffmpeg_native_append_component_if_known(${_enabled_var} libjxl_anim_encoder)
        _ffmpeg_native_append_component_if_known(${_enabled_var} libjxl_decoder)
        _ffmpeg_native_append_component_if_known(${_enabled_var} libjxl_encoder)
    endif()
    _ffmpeg_native_append_external_if_feature(${_enabled_var} ${_config_var} libkvazaar
        libkvazaar_encoder)
    _ffmpeg_native_append_external_if_feature(${_enabled_var} ${_config_var} libopenh264
        libopenh264_decoder
        libopenh264_encoder)
    _ffmpeg_native_append_external_if_feature(${_enabled_var} ${_config_var} libopenjpeg
        libopenjpeg_encoder)
    _ffmpeg_native_append_external_if_feature(${_enabled_var} ${_config_var} libopenmpt
        libopenmpt_demuxer)
    _ffmpeg_native_append_external_if_feature(${_enabled_var} ${_config_var} libopus
        libopus_decoder
        libopus_encoder)
    _ffmpeg_native_append_external_if_feature(${_enabled_var} ${_config_var} libspeex
        libspeex_decoder
        libspeex_encoder)
    _ffmpeg_native_append_external_if_feature(${_enabled_var} ${_config_var} libtheora
        libtheora_encoder)
    _ffmpeg_native_append_external_if_feature(${_enabled_var} ${_config_var} libtwolame
        libtwolame_encoder)
    _ffmpeg_native_append_external_if_feature(${_enabled_var} ${_config_var} libvorbis
        libvorbis_decoder
        libvorbis_encoder)
    _ffmpeg_native_append_external_if_feature(${_enabled_var} ${_config_var} libvpx
        libvpx_vp8_decoder
        libvpx_vp8_encoder
        libvpx_vp9_decoder
        libvpx_vp9_encoder)
    _ffmpeg_native_append_external_if_feature(${_enabled_var} ${_config_var} libwebp
        libwebp_anim_encoder
        libwebp_encoder
        webp_muxer)
    _ffmpeg_native_append_external_if_feature(${_enabled_var} ${_config_var} libx264
        libx264_encoder
        libx264rgb_encoder)
    _ffmpeg_native_append_external_if_feature(${_enabled_var} ${_config_var} libx265
        libx265_encoder)
    _ffmpeg_native_append_external_if_feature(${_enabled_var} ${_config_var} libxvid
        libxvid_encoder)
    _ffmpeg_native_append_external_if_feature(${_enabled_var} ${_config_var} libzimg
        zscale_filter)

    list(REMOVE_DUPLICATES ${_enabled_var})
    set(${_enabled_var} "${${_enabled_var}}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_refresh_component_family_features _config_var _components_var)
    foreach(_ffmpeg_family IN ITEMS bsfs decoders encoders hwaccels parsers indevs outdevs filters demuxers muxers protocols)
        list(REMOVE_ITEM ${_config_var} "${_ffmpeg_family}")
    endforeach()

    set(_ffmpeg_has_bsfs FALSE)
    set(_ffmpeg_has_decoders FALSE)
    set(_ffmpeg_has_encoders FALSE)
    set(_ffmpeg_has_hwaccels FALSE)
    set(_ffmpeg_has_parsers FALSE)
    set(_ffmpeg_has_indevs FALSE)
    set(_ffmpeg_has_outdevs FALSE)
    set(_ffmpeg_has_filters FALSE)
    set(_ffmpeg_has_demuxers FALSE)
    set(_ffmpeg_has_muxers FALSE)
    set(_ffmpeg_has_protocols FALSE)

    foreach(_ffmpeg_component IN LISTS ${_components_var})
        if(_ffmpeg_component MATCHES "_bsf$")
            set(_ffmpeg_has_bsfs TRUE)
        elseif(_ffmpeg_component MATCHES "_decoder$")
            set(_ffmpeg_has_decoders TRUE)
        elseif(_ffmpeg_component MATCHES "_encoder$")
            set(_ffmpeg_has_encoders TRUE)
        elseif(_ffmpeg_component MATCHES "_hwaccel$")
            set(_ffmpeg_has_hwaccels TRUE)
        elseif(_ffmpeg_component MATCHES "_parser$")
            set(_ffmpeg_has_parsers TRUE)
        elseif(_ffmpeg_component MATCHES "_indev$")
            set(_ffmpeg_has_indevs TRUE)
        elseif(_ffmpeg_component MATCHES "_outdev$")
            set(_ffmpeg_has_outdevs TRUE)
        elseif(_ffmpeg_component MATCHES "_filter$")
            set(_ffmpeg_has_filters TRUE)
        elseif(_ffmpeg_component MATCHES "_demuxer$")
            set(_ffmpeg_has_demuxers TRUE)
        elseif(_ffmpeg_component MATCHES "_muxer$")
            set(_ffmpeg_has_muxers TRUE)
        elseif(_ffmpeg_component MATCHES "_protocol$")
            set(_ffmpeg_has_protocols TRUE)
        endif()
    endforeach()

    foreach(_ffmpeg_family IN ITEMS bsfs decoders encoders hwaccels parsers indevs outdevs filters demuxers muxers protocols)
        if(_ffmpeg_has_${_ffmpeg_family})
            list(APPEND ${_config_var} "${_ffmpeg_family}")
        endif()
    endforeach()

    list(REMOVE_DUPLICATES ${_config_var})
    set(${_config_var} "${${_config_var}}" PARENT_SCOPE)
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
