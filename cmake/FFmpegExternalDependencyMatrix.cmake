include_guard(GLOBAL)

include(FFmpegPkgConfigTargets)

option(FFMPEG_EXTERNAL_DEPENDENCY_MATRIX "Generate a full FFmpeg external dependency status matrix during configure." ON)
set(FFMPEG_EXTERNAL_DEPENDENCY_MATRIX_FILE "${PROJECT_BINARY_DIR}/ffmpeg-external-dependency-matrix.md"
    CACHE FILEPATH "Markdown report written by the FFmpeg external dependency matrix probe.")

function(_ffmpeg_dep_matrix_var_suffix _out _name)
    string(TOUPPER "${_name}" _ffmpeg_suffix)
    string(REGEX REPLACE "[^A-Z0-9_]" "_" _ffmpeg_suffix "${_ffmpeg_suffix}")
    set(${_out} "${_ffmpeg_suffix}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_dep_matrix_configure_var _out _content _name)
    string(REGEX MATCH "(^|\n)${_name}=\"\n([^\"]*)\n\"" _ffmpeg_match "${_content}")
    if(NOT _ffmpeg_match)
        set(${_out} "" PARENT_SCOPE)
        return()
    endif()

    set(_ffmpeg_body "${CMAKE_MATCH_2}")
    string(REGEX REPLACE "[\r\n\t ]+" ";" _ffmpeg_items "${_ffmpeg_body}")
    set(_ffmpeg_result)
    foreach(_ffmpeg_item IN LISTS _ffmpeg_items)
        string(STRIP "${_ffmpeg_item}" _ffmpeg_item)
        if(NOT _ffmpeg_item STREQUAL "")
            list(APPEND _ffmpeg_result "${_ffmpeg_item}")
        endif()
    endforeach()
    set(${_out} "${_ffmpeg_result}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_dep_matrix_expand_list _out _raw_var)
    set(_ffmpeg_result)
    foreach(_ffmpeg_item IN LISTS ${_raw_var})
        if(_ffmpeg_item MATCHES "^\\$([A-Za-z0-9_]+)$")
            set(_ffmpeg_ref "${CMAKE_MATCH_1}")
            if(DEFINED ${_ffmpeg_ref})
                list(APPEND _ffmpeg_result ${${_ffmpeg_ref}})
            endif()
        else()
            list(APPEND _ffmpeg_result "${_ffmpeg_item}")
        endif()
    endforeach()
    list(REMOVE_DUPLICATES _ffmpeg_result)
    list(SORT _ffmpeg_result)
    set(${_out} "${_ffmpeg_result}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_dep_matrix_parse_lists _out_all _out_explicit _out_auto _out_hw_explicit _out_hw_auto)
    file(READ "${FFMPEG_SOURCE_DIR}/configure" _ffmpeg_configure)

    foreach(_ffmpeg_var IN ITEMS
            EXTERNAL_AUTODETECT_LIBRARY_LIST
            EXTERNAL_LIBRARY_GPL_LIST
            EXTERNAL_LIBRARY_NONFREE_LIST
            EXTERNAL_LIBRARY_VERSION3_LIST
            EXTERNAL_LIBRARY_GPLV3_LIST
            EXTERNAL_LIBRARY_LIST
            HWACCEL_LIBRARY_NONFREE_LIST
            HWACCEL_LIBRARY_LIST
            HWACCEL_AUTODETECT_LIBRARY_LIST)
        _ffmpeg_dep_matrix_configure_var(${_ffmpeg_var} "${_ffmpeg_configure}" "${_ffmpeg_var}")
    endforeach()

    _ffmpeg_dep_matrix_expand_list(_ffmpeg_explicit EXTERNAL_LIBRARY_LIST)
    _ffmpeg_dep_matrix_expand_list(_ffmpeg_auto EXTERNAL_AUTODETECT_LIBRARY_LIST)
    _ffmpeg_dep_matrix_expand_list(_ffmpeg_hw_explicit HWACCEL_LIBRARY_LIST)
    _ffmpeg_dep_matrix_expand_list(_ffmpeg_hw_auto HWACCEL_AUTODETECT_LIBRARY_LIST)

    set(_ffmpeg_all ${_ffmpeg_explicit} ${_ffmpeg_auto} ${_ffmpeg_hw_explicit} ${_ffmpeg_hw_auto})
    list(REMOVE_DUPLICATES _ffmpeg_all)
    list(SORT _ffmpeg_all)

    foreach(_ffmpeg_var IN ITEMS
            EXTERNAL_LIBRARY_GPL_LIST
            EXTERNAL_LIBRARY_NONFREE_LIST
            EXTERNAL_LIBRARY_VERSION3_LIST
            EXTERNAL_LIBRARY_GPLV3_LIST
            HWACCEL_LIBRARY_NONFREE_LIST)
        set(${_ffmpeg_var} "${${_ffmpeg_var}}" PARENT_SCOPE)
    endforeach()

    set(${_out_all} "${_ffmpeg_all}" PARENT_SCOPE)
    set(${_out_explicit} "${_ffmpeg_explicit}" PARENT_SCOPE)
    set(${_out_auto} "${_ffmpeg_auto}" PARENT_SCOPE)
    set(${_out_hw_explicit} "${_ffmpeg_hw_explicit}" PARENT_SCOPE)
    set(${_out_hw_auto} "${_ffmpeg_hw_auto}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_dep_matrix_split_words _out _text)
    set(_ffmpeg_text "${_text}")
    set(_ffmpeg_words)
    foreach(_ffmpeg_unused RANGE 0 96)
        string(STRIP "${_ffmpeg_text}" _ffmpeg_text)
        if(_ffmpeg_text STREQUAL "")
            break()
        elseif(_ffmpeg_text MATCHES "^\"([^\"]*)\"[ \t]*(.*)$")
            list(APPEND _ffmpeg_words "${CMAKE_MATCH_1}")
            set(_ffmpeg_text "${CMAKE_MATCH_2}")
        elseif(_ffmpeg_text MATCHES "^'([^']*)'[ \t]*(.*)$")
            list(APPEND _ffmpeg_words "${CMAKE_MATCH_1}")
            set(_ffmpeg_text "${CMAKE_MATCH_2}")
        elseif(_ffmpeg_text MATCHES "^([^ \t;&|{}()]+)[ \t]*(.*)$")
            list(APPEND _ffmpeg_words "${CMAKE_MATCH_1}")
            set(_ffmpeg_text "${CMAKE_MATCH_2}")
        else()
            break()
        endif()
    endforeach()

    set(${_out} "${_ffmpeg_words}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_dep_matrix_add_use _feature _category _component)
    if(_feature STREQUAL "" OR _category STREQUAL "")
        return()
    endif()
    _ffmpeg_dep_matrix_var_suffix(_ffmpeg_suffix "${_feature}")

    set(_ffmpeg_use_var "FFMPEG_DEP_MATRIX_USES_${_ffmpeg_suffix}")
    list(APPEND ${_ffmpeg_use_var} "${_category}")
    list(REMOVE_DUPLICATES ${_ffmpeg_use_var})
    list(SORT ${_ffmpeg_use_var})
    set(${_ffmpeg_use_var} "${${_ffmpeg_use_var}}" PARENT_SCOPE)

    if(NOT _component STREQUAL "")
        set(_ffmpeg_component_var "FFMPEG_DEP_MATRIX_USED_BY_${_ffmpeg_suffix}")
        list(APPEND ${_ffmpeg_component_var} "${_component}")
        list(REMOVE_DUPLICATES ${_ffmpeg_component_var})
        list(SORT ${_ffmpeg_component_var})
        set(${_ffmpeg_component_var} "${${_ffmpeg_component_var}}" PARENT_SCOPE)
    endif()
endfunction()

function(_ffmpeg_dep_matrix_collect_component_uses _deps)
    file(STRINGS "${FFMPEG_SOURCE_DIR}/configure" _ffmpeg_lines)
    foreach(_ffmpeg_line IN LISTS _ffmpeg_lines)
        if(NOT _ffmpeg_line MATCHES "^([A-Za-z0-9_]+)_(encoder|decoder|hwaccel|filter|protocol|demuxer|muxer|indev|outdev)_deps(_any)?=\"([^\"]*)\"")
            continue()
        endif()

        set(_ffmpeg_name "${CMAKE_MATCH_1}")
        set(_ffmpeg_kind "${CMAKE_MATCH_2}")
        set(_ffmpeg_dep_text "${CMAKE_MATCH_4}")
        set(_ffmpeg_component "${_ffmpeg_name}_${_ffmpeg_kind}")
        if(_ffmpeg_kind STREQUAL "encoder" OR _ffmpeg_kind STREQUAL "decoder")
            set(_ffmpeg_category "Codecs")
        elseif(_ffmpeg_kind STREQUAL "hwaccel")
            set(_ffmpeg_category "Hardware")
        elseif(_ffmpeg_kind STREQUAL "filter")
            set(_ffmpeg_category "Filters")
        else()
            set(_ffmpeg_category "Formats/Devices/Protocols")
        endif()

        string(REGEX REPLACE "[ \t]+" ";" _ffmpeg_dep_words "${_ffmpeg_dep_text}")
        foreach(_ffmpeg_dep IN LISTS _ffmpeg_dep_words)
            if(_ffmpeg_dep IN_LIST _deps)
                _ffmpeg_dep_matrix_add_use("${_ffmpeg_dep}" "${_ffmpeg_category}" "${_ffmpeg_component}")
            endif()
        endforeach()
    endforeach()

    foreach(_ffmpeg_dep IN LISTS _deps)
        _ffmpeg_dep_matrix_var_suffix(_ffmpeg_suffix "${_ffmpeg_dep}")
        set(FFMPEG_DEP_MATRIX_USES_${_ffmpeg_suffix} "${FFMPEG_DEP_MATRIX_USES_${_ffmpeg_suffix}}" PARENT_SCOPE)
        set(FFMPEG_DEP_MATRIX_USED_BY_${_ffmpeg_suffix} "${FFMPEG_DEP_MATRIX_USED_BY_${_ffmpeg_suffix}}" PARENT_SCOPE)
    endforeach()
endfunction()

function(_ffmpeg_dep_matrix_add_pkg_rule _feature _pkg)
    if(_feature STREQUAL "" OR _pkg STREQUAL "")
        return()
    endif()
    if(_pkg MATCHES "^([A-Za-z0-9_.+-]+)")
        set(_pkg "${CMAKE_MATCH_1}")
    endif()
    if(_feature MATCHES "[^A-Za-z0-9_]" OR _feature MATCHES "^\\$" OR _pkg MATCHES "\\$")
        return()
    endif()

    _ffmpeg_dep_matrix_var_suffix(_ffmpeg_suffix "${_feature}")
    set(_ffmpeg_var "FFMPEG_DEP_MATRIX_PKGS_${_ffmpeg_suffix}")
    list(APPEND ${_ffmpeg_var} "${_pkg}")
    list(REMOVE_DUPLICATES ${_ffmpeg_var})
    set(${_ffmpeg_var} "${${_ffmpeg_var}}" PARENT_SCOPE)

    set(FFMPEG_DEP_MATRIX_PKG_FEATURES "${FFMPEG_DEP_MATRIX_PKG_FEATURES};${_feature}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_dep_matrix_collect_pkg_rules)
    file(STRINGS "${FFMPEG_SOURCE_DIR}/configure" _ffmpeg_lines)
    set(FFMPEG_DEP_MATRIX_PKG_FEATURES)
    foreach(_ffmpeg_line IN LISTS _ffmpeg_lines)
        set(_ffmpeg_rest "${_ffmpeg_line}")
        foreach(_ffmpeg_unused RANGE 0 8)
            if(_ffmpeg_rest MATCHES "((require|check|test)_pkg_config(_[A-Za-z0-9_]+)?)[ \t]+(.+)$")
                set(_ffmpeg_after "${CMAKE_MATCH_4}")
                _ffmpeg_dep_matrix_split_words(_ffmpeg_words "${_ffmpeg_after}")
                list(LENGTH _ffmpeg_words _ffmpeg_word_count)
                if(_ffmpeg_word_count GREATER 1)
                    list(GET _ffmpeg_words 0 _ffmpeg_feature)
                    list(GET _ffmpeg_words 1 _ffmpeg_pkg)
                    _ffmpeg_dep_matrix_add_pkg_rule("${_ffmpeg_feature}" "${_ffmpeg_pkg}")
                endif()
                set(_ffmpeg_rest "${_ffmpeg_after}")
            else()
                break()
            endif()
        endforeach()
    endforeach()

    set(_ffmpeg_alias_features
        alsa
        cairo
        chromaprint
        ffnvcodec
        frei0r
        gcrypt
        gmp
        gnutls
        lcms2
        libaom
        libaribb24
        libaribcaption
        libass
        libbluray
        libbs2b
        libcaca
        libcdio
        libcodec2
        libdav1d
        libdavs2
        libdc1394
        libdrm
        libdvdnav
        libdvdread
        libfdk_aac
        libfontconfig
        libfreetype
        libfribidi
        libgme
        libgsm
        libharfbuzz
        libilbc
        libjack
        libjxl
        libjxl_threads
        libkvazaar
        liblc3
        liblcevc_dec
        libmfx
        libmodplug
        libmp3lame
        libmpeghdec
        libmysofa
        liboapv
        libopencv
        libopencolorio
        libopenh264
        libopenjpeg
        libopenmpt
        libopencore_amrnb
        libopencore_amrwb
        libopus
        libplacebo
        libpulse
        libqrencode
        libquirc
        librabbitmq
        librav1e
        librsvg
        librtmp
        librubberband
        libshine
        libsnappy
        libsoxr
        libspeex
        libsrt
        libssh
        libsvtav1
        libsvtjpegxs
        libtesseract
        libtheora
        libtls
        libtwolame
        libuavs3d
        libv4l2
        libvidstab
        libvmaf
        libvo_amrwbenc
        libvorbis
        libvorbisenc
        libvpl
        libvpx
        libvvenc
        libwebp
        libwebp_anim_encoder
        libxcb
        libxcb_shm
        libxcb_shape
        libxcb_xfixes
        libxml2
        libx264
        libx265
        libxavs2
        libxevd
        libxevdb
        libxeve
        libxeveb
        libxvid
        libzimg
        libzmq
        libzvbi
        lv2
        mbedtls
        openal
        opencl
        openssl
        pocketsphinx
        rkmpp
        sdl2
        sndio
        vaapi
        vdpau
        vulkan
        xlib
        zlib)
    set(_ffmpeg_alias_pkgs
        alsa
        cairo
        libchromaprint
        ffnvcodec
        frei0r
        gcrypt
        gmp
        gnutls
        lcms2
        aom
        aribb24
        libaribcaption
        libass
        libbluray
        libbs2b
        caca
        libcdio_paranoia
        codec2
        dav1d
        davs2
        libdc1394-2
        libdrm
        dvdnav
        dvdread
        fdk-aac
        fontconfig
        freetype2
        fribidi
        libgme
        gsm
        harfbuzz
        libilbc
        jack
        libjxl
        libjxl_threads
        kvazaar
        lc3
        lcevc_dec
        libmfx
        libmodplug
        libmp3lame
        mpeghdec
        libmysofa
        oapv
        opencv4
        OpenColorIO
        openh264
        libopenjp2
        libopenmpt
        opencore-amrnb
        opencore-amrwb
        opus
        libplacebo
        libpulse
        libqrencode
        libquirc
        librabbitmq
        rav1e
        librsvg-2.0
        librtmp
        rubberband
        shine
        snappy
        soxr
        speex
        srt
        libssh
        SvtAv1Enc
        SvtJpegxs
        tesseract
        theora
        libtls
        twolame
        uavs3d
        libv4l2
        vidstab
        libvmaf
        vo-amrwbenc
        vorbis
        vorbisenc
        vpl
        vpx
        libvvenc
        libwebp
        libwebpmux
        xcb
        xcb-shm
        xcb-shape
        xcb-xfixes
        libxml-2.0
        x264
        x265
        xavs2
        xevd
        xevdb
        xeve
        xeveb
        xvidcore
        zimg
        libzmq
        zvbi-0.2
        lilv-0
        mbedtls
        openal
        OpenCL
        openssl
        pocketsphinx
        rockchip_mpp
        sdl2
        sndio
        libva
        vdpau
        vulkan
        x11
        zlib)
    foreach(_ffmpeg_feature _ffmpeg_pkg IN ZIP_LISTS _ffmpeg_alias_features _ffmpeg_alias_pkgs)
        _ffmpeg_dep_matrix_add_pkg_rule("${_ffmpeg_feature}" "${_ffmpeg_pkg}")
    endforeach()

    list(REMOVE_DUPLICATES FFMPEG_DEP_MATRIX_PKG_FEATURES)
    foreach(_ffmpeg_feature IN LISTS FFMPEG_DEP_MATRIX_PKG_FEATURES)
        _ffmpeg_dep_matrix_var_suffix(_ffmpeg_suffix "${_ffmpeg_feature}")
        set(FFMPEG_DEP_MATRIX_PKGS_${_ffmpeg_suffix} "${FFMPEG_DEP_MATRIX_PKGS_${_ffmpeg_suffix}}" PARENT_SCOPE)
    endforeach()
    set(FFMPEG_DEP_MATRIX_PKG_FEATURES "${FFMPEG_DEP_MATRIX_PKG_FEATURES}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_dep_matrix_find_prefix_header _out _header)
    set(_ffmpeg_dirs)
    if(FFMPEG_NV_CODEC_HEADERS_INCLUDE_DIR AND IS_DIRECTORY "${FFMPEG_NV_CODEC_HEADERS_INCLUDE_DIR}")
        list(APPEND _ffmpeg_dirs "${FFMPEG_NV_CODEC_HEADERS_INCLUDE_DIR}")
    endif()
    if(FFMPEG_AMF_HEADERS_INCLUDE_DIR AND IS_DIRECTORY "${FFMPEG_AMF_HEADERS_INCLUDE_DIR}")
        list(APPEND _ffmpeg_dirs "${FFMPEG_AMF_HEADERS_INCLUDE_DIR}")
    endif()
    foreach(_ffmpeg_prefix IN LISTS CMAKE_PREFIX_PATH)
        foreach(_ffmpeg_suffix IN ITEMS include include/mfx include/vpl include/libdrm include/openjpeg-2.5 include/openjpeg-2.4)
            if(IS_DIRECTORY "${_ffmpeg_prefix}/${_ffmpeg_suffix}")
                list(APPEND _ffmpeg_dirs "${_ffmpeg_prefix}/${_ffmpeg_suffix}")
            endif()
        endforeach()
    endforeach()
    foreach(_ffmpeg_dir IN LISTS _ffmpeg_dirs)
        if(EXISTS "${_ffmpeg_dir}/${_header}")
            set(${_out} "${_ffmpeg_dir}" PARENT_SCOPE)
            return()
        endif()
    endforeach()
    set(${_out} "" PARENT_SCOPE)
endfunction()

function(_ffmpeg_dep_matrix_probe_framework _out_found _out_detail _name _framework)
    if(NOT APPLE)
        set(${_out_found} FALSE PARENT_SCOPE)
        set(${_out_detail} "not an Apple platform" PARENT_SCOPE)
        return()
    endif()

    string(TOUPPER "${_name}" _ffmpeg_suffix)
    string(REGEX REPLACE "[^A-Z0-9_]" "_" _ffmpeg_suffix "${_ffmpeg_suffix}")
    find_library(FFMPEG_DEP_MATRIX_FRAMEWORK_${_ffmpeg_suffix} NAMES "${_framework}" NO_CACHE)
    if(FFMPEG_DEP_MATRIX_FRAMEWORK_${_ffmpeg_suffix})
        set(${_out_found} TRUE PARENT_SCOPE)
        set(${_out_detail} "Apple framework: ${_framework}" PARENT_SCOPE)
    else()
        set(${_out_found} FALSE PARENT_SCOPE)
        set(${_out_detail} "Apple framework not found: ${_framework}" PARENT_SCOPE)
    endif()
endfunction()

function(_ffmpeg_dep_matrix_probe_special _out_known _out_found _out_detail _feature)
    set(_ffmpeg_known TRUE)
    set(_ffmpeg_found FALSE)
    set(_ffmpeg_detail)

    if(_feature STREQUAL "ffnvcodec" OR _feature STREQUAL "nvenc" OR _feature STREQUAL "nvdec" OR _feature STREQUAL "cuvid")
        if(FFMPEG_NV_CODEC_HEADERS_FOUND)
            set(_ffmpeg_found TRUE)
            set(_ffmpeg_detail "nv-codec-headers: ${FFMPEG_NV_CODEC_HEADERS_INCLUDE_DIR}")
        else()
            set(_ffmpeg_detail "nv-codec-headers not found")
        endif()
    elseif(_feature STREQUAL "amf")
        if(FFMPEG_AMF_HEADERS_FOUND AND FFMPEG_AMF_HEADERS_USABLE)
            set(_ffmpeg_found TRUE)
            set(_ffmpeg_detail "AMD AMF headers: ${FFMPEG_AMF_HEADERS_INCLUDE_DIR}")
        elseif(FFMPEG_AMF_HEADERS_FOUND)
            set(_ffmpeg_detail "AMD AMF headers found but too old: ${FFMPEG_AMF_HEADERS_VERSION}")
        else()
            set(_ffmpeg_detail "AMD AMF headers not found")
        endif()
    elseif(_feature STREQUAL "videotoolbox")
        if(APPLE AND FFMPEG_APPLE_VIDEOTOOLBOX_AVAILABLE)
            set(_ffmpeg_found TRUE)
            set(_ffmpeg_detail "Apple VideoToolbox SDK probe passed")
        elseif(APPLE)
            set(_ffmpeg_detail "Apple VideoToolbox SDK probe failed")
        else()
            set(_ffmpeg_detail "not an Apple platform")
        endif()
    elseif(_feature STREQUAL "audiotoolbox")
        _ffmpeg_dep_matrix_probe_framework(_ffmpeg_found _ffmpeg_detail "${_feature}" AudioToolbox)
    elseif(_feature STREQUAL "avfoundation")
        _ffmpeg_dep_matrix_probe_framework(_ffmpeg_found _ffmpeg_detail "${_feature}" AVFoundation)
    elseif(_feature STREQUAL "appkit")
        _ffmpeg_dep_matrix_probe_framework(_ffmpeg_found _ffmpeg_detail "${_feature}" AppKit)
    elseif(_feature STREQUAL "coreimage")
        _ffmpeg_dep_matrix_probe_framework(_ffmpeg_found _ffmpeg_detail "${_feature}" CoreImage)
    elseif(_feature STREQUAL "metal")
        _ffmpeg_dep_matrix_probe_framework(_ffmpeg_found _ffmpeg_detail "${_feature}" Metal)
    elseif(_feature STREQUAL "securetransport")
        _ffmpeg_dep_matrix_probe_framework(_ffmpeg_found _ffmpeg_detail "${_feature}" Security)
    elseif(_feature STREQUAL "d3d11va" OR _feature STREQUAL "d3d12va" OR _feature STREQUAL "dxva2" OR _feature STREQUAL "mediafoundation" OR _feature STREQUAL "schannel")
        if(WIN32)
            set(_ffmpeg_found TRUE)
            set(_ffmpeg_detail "Windows SDK/platform API")
        else()
            set(_ffmpeg_detail "not a Windows platform")
        endif()
    elseif(_feature STREQUAL "cuda" OR _feature STREQUAL "cuda_sdk")
        find_path(FFMPEG_DEP_MATRIX_CUDA_INCLUDE_DIR NAMES cuda.h HINTS ENV CUDA_PATH PATH_SUFFIXES include NO_CACHE)
        if(FFMPEG_DEP_MATRIX_CUDA_INCLUDE_DIR)
            set(_ffmpeg_found TRUE)
            set(_ffmpeg_detail "CUDA headers: ${FFMPEG_DEP_MATRIX_CUDA_INCLUDE_DIR}")
        else()
            set(_ffmpeg_detail "CUDA headers not found")
        endif()
    elseif(_feature STREQUAL "cuda_nvcc")
        find_program(FFMPEG_DEP_MATRIX_NVCC NAMES nvcc HINTS ENV CUDA_PATH PATH_SUFFIXES bin NO_CACHE)
        if(FFMPEG_DEP_MATRIX_NVCC)
            set(_ffmpeg_found TRUE)
            set(_ffmpeg_detail "nvcc: ${FFMPEG_DEP_MATRIX_NVCC}")
        else()
            set(_ffmpeg_detail "nvcc not found")
        endif()
    elseif(_feature STREQUAL "cuda_llvm")
        find_path(FFMPEG_DEP_MATRIX_CUDA_INCLUDE_DIR NAMES cuda.h HINTS ENV CUDA_PATH PATH_SUFFIXES include NO_CACHE)
        if(FFMPEG_DEP_MATRIX_CUDA_INCLUDE_DIR AND CMAKE_C_COMPILER_ID MATCHES "Clang")
            set(_ffmpeg_found TRUE)
            set(_ffmpeg_detail "Clang CUDA path with cuda.h")
        elseif(FFMPEG_DEP_MATRIX_CUDA_INCLUDE_DIR)
            set(_ffmpeg_detail "cuda.h found, but C compiler is not Clang")
        else()
            set(_ffmpeg_detail "CUDA headers not found")
        endif()
    elseif(_feature STREQUAL "v4l2_m2m")
        if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
            find_path(FFMPEG_DEP_MATRIX_V4L2_INCLUDE_DIR NAMES linux/videodev2.h NO_CACHE)
            if(FFMPEG_DEP_MATRIX_V4L2_INCLUDE_DIR)
                set(_ffmpeg_found TRUE)
                set(_ffmpeg_detail "Linux V4L2 headers: ${FFMPEG_DEP_MATRIX_V4L2_INCLUDE_DIR}")
            else()
                set(_ffmpeg_detail "Linux V4L2 headers not found")
            endif()
        else()
            set(_ffmpeg_detail "not a Linux platform")
        endif()
    elseif(_feature STREQUAL "vulkan")
        find_package(Vulkan QUIET)
        if(Vulkan_FOUND OR TARGET Vulkan::Vulkan)
            set(_ffmpeg_found TRUE)
            if(Vulkan_VERSION)
                set(_ffmpeg_detail "CMake package: Vulkan ${Vulkan_VERSION}")
            else()
                set(_ffmpeg_detail "CMake package: Vulkan")
            endif()
        else()
            set(_ffmpeg_known FALSE)
        endif()
    elseif(_feature STREQUAL "sdl2")
        find_package(SDL2 CONFIG QUIET)
        if(SDL2_FOUND OR TARGET SDL2::SDL2 OR TARGET SDL2::SDL2-static)
            set(_ffmpeg_found TRUE)
            set(_ffmpeg_detail "SDL2 CMake package")
        else()
            set(_ffmpeg_known FALSE)
        endif()
    elseif(_feature STREQUAL "zlib")
        find_package(ZLIB QUIET)
        if(ZLIB_FOUND)
            set(_ffmpeg_found TRUE)
            set(_ffmpeg_detail "CMake package: ZLIB")
        else()
            set(_ffmpeg_known FALSE)
        endif()
    elseif(_feature STREQUAL "bzlib")
        find_package(BZip2 QUIET)
        if(BZip2_FOUND)
            set(_ffmpeg_found TRUE)
            set(_ffmpeg_detail "CMake package: BZip2")
        else()
            set(_ffmpeg_known FALSE)
        endif()
    elseif(_feature STREQUAL "lzma")
        find_package(LibLZMA QUIET)
        if(LibLZMA_FOUND)
            set(_ffmpeg_found TRUE)
            set(_ffmpeg_detail "CMake package: LibLZMA")
        else()
            set(_ffmpeg_known FALSE)
        endif()
    elseif(_feature STREQUAL "iconv")
        find_package(Iconv QUIET)
        if(Iconv_FOUND)
            set(_ffmpeg_found TRUE)
            set(_ffmpeg_detail "CMake package: Iconv")
        else()
            set(_ffmpeg_known FALSE)
        endif()
    elseif(_feature STREQUAL "libmfx")
        _ffmpeg_dep_matrix_find_prefix_header(_ffmpeg_mfx_header "mfxvideo.h")
        if(_ffmpeg_mfx_header)
            set(_ffmpeg_found TRUE)
            set(_ffmpeg_detail "MediaSDK/libmfx header: ${_ffmpeg_mfx_header}")
        else()
            set(_ffmpeg_known FALSE)
        endif()
    elseif(_feature STREQUAL "libvpl")
        _ffmpeg_dep_matrix_find_prefix_header(_ffmpeg_vpl_header "mfxdispatcher.h")
        if(_ffmpeg_vpl_header)
            set(_ffmpeg_found TRUE)
            set(_ffmpeg_detail "oneVPL header: ${_ffmpeg_vpl_header}")
        else()
            set(_ffmpeg_known FALSE)
        endif()
    else()
        set(_ffmpeg_known FALSE)
    endif()

    set(${_out_known} "${_ffmpeg_known}" PARENT_SCOPE)
    set(${_out_found} "${_ffmpeg_found}" PARENT_SCOPE)
    set(${_out_detail} "${_ffmpeg_detail}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_dep_matrix_probe_pkg_config _out_known _out_found _out_detail _feature)
    _ffmpeg_dep_matrix_var_suffix(_ffmpeg_suffix "${_feature}")
    set(_ffmpeg_pkgs "${FFMPEG_DEP_MATRIX_PKGS_${_ffmpeg_suffix}}")
    if(NOT _ffmpeg_pkgs)
        set(${_out_known} FALSE PARENT_SCOPE)
        set(${_out_found} FALSE PARENT_SCOPE)
        set(${_out_detail} "no CMake/pkg-config probe rule yet" PARENT_SCOPE)
        return()
    endif()

    _ffmpeg_pkg_config_path(_ffmpeg_pc_path "")
    _ffmpeg_pkg_config_command(_ffmpeg_pkg_config "${_ffmpeg_pc_path}")
    if(NOT _ffmpeg_pkg_config)
        string(REPLACE ";" ", " _ffmpeg_pkg_text "${_ffmpeg_pkgs}")
        set(${_out_known} TRUE PARENT_SCOPE)
        set(${_out_found} FALSE PARENT_SCOPE)
        set(${_out_detail} "pkg-config not found; modules: ${_ffmpeg_pkg_text}" PARENT_SCOPE)
        return()
    endif()

    foreach(_ffmpeg_pkg IN LISTS _ffmpeg_pkgs)
        _ffmpeg_pkg_config_output(_ffmpeg_unused _ffmpeg_result "${_ffmpeg_pc_path}" --exists "${_ffmpeg_pkg}")
        if(_ffmpeg_result EQUAL 0)
            set(${_out_known} TRUE PARENT_SCOPE)
            set(${_out_found} TRUE PARENT_SCOPE)
            set(${_out_detail} "pkg-config: ${_ffmpeg_pkg}" PARENT_SCOPE)
            return()
        endif()
    endforeach()

    string(REPLACE ";" ", " _ffmpeg_pkg_text "${_ffmpeg_pkgs}")
    set(${_out_known} TRUE PARENT_SCOPE)
    set(${_out_found} FALSE PARENT_SCOPE)
    set(${_out_detail} "pkg-config modules not found: ${_ffmpeg_pkg_text}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_dep_matrix_probe _out_known _out_found _out_detail _feature)
    if(_feature IN_LIST FFMPEG_NATIVE_FOUND_EXTERNAL_DEPENDENCIES)
        set(${_out_known} TRUE PARENT_SCOPE)
        set(${_out_found} TRUE PARENT_SCOPE)
        set(${_out_detail} "native backend dependency target found" PARENT_SCOPE)
        return()
    endif()
    if(_feature IN_LIST FFMPEG_NATIVE_MISSING_EXTERNAL_DEPENDENCIES)
        set(${_out_known} TRUE PARENT_SCOPE)
        set(${_out_found} FALSE PARENT_SCOPE)
        set(${_out_detail} "native backend dependency target missing" PARENT_SCOPE)
        return()
    endif()

    _ffmpeg_dep_matrix_probe_special(_ffmpeg_known _ffmpeg_found _ffmpeg_detail "${_feature}")
    if(_ffmpeg_known)
        set(${_out_known} TRUE PARENT_SCOPE)
        set(${_out_found} "${_ffmpeg_found}" PARENT_SCOPE)
        set(${_out_detail} "${_ffmpeg_detail}" PARENT_SCOPE)
        return()
    endif()

    _ffmpeg_dep_matrix_probe_pkg_config(_ffmpeg_known _ffmpeg_found _ffmpeg_detail "${_feature}")
    set(${_out_known} "${_ffmpeg_known}" PARENT_SCOPE)
    set(${_out_found} "${_ffmpeg_found}" PARENT_SCOPE)
    set(${_out_detail} "${_ffmpeg_detail}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_dep_matrix_raw_option_state _out_enabled _out_disabled _feature)
    set(_ffmpeg_enabled FALSE)
    set(_ffmpeg_disabled FALSE)
    set(_ffmpeg_raw_options)
    if(FFMPEG_CONFIGURE_OPTIONS)
        separate_arguments(_ffmpeg_raw_options NATIVE_COMMAND "${FFMPEG_CONFIGURE_OPTIONS}")
    endif()
    foreach(_ffmpeg_option IN LISTS _ffmpeg_raw_options)
        if(_ffmpeg_option STREQUAL "--enable-${_feature}" OR _ffmpeg_option MATCHES "^--enable-${_feature}=")
            set(_ffmpeg_enabled TRUE)
        elseif(_ffmpeg_option STREQUAL "--disable-${_feature}" OR _ffmpeg_option MATCHES "^--disable-${_feature}=")
            set(_ffmpeg_disabled TRUE)
        endif()
    endforeach()
    set(${_out_enabled} "${_ffmpeg_enabled}" PARENT_SCOPE)
    set(${_out_disabled} "${_ffmpeg_disabled}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_dep_matrix_license_state _out_ok _out_label _out_detail _feature)
    set(_ffmpeg_ok TRUE)
    set(_ffmpeg_label "LGPL-compatible")
    set(_ffmpeg_detail)

    if(_feature IN_LIST EXTERNAL_LIBRARY_NONFREE_LIST OR _feature IN_LIST HWACCEL_LIBRARY_NONFREE_LIST)
        set(_ffmpeg_label "Nonfree")
        if(NOT FFMPEG_ENABLE_NONFREE)
            set(_ffmpeg_ok FALSE)
            set(_ffmpeg_detail "requires FFMPEG_ENABLE_NONFREE")
        endif()
    elseif(_feature IN_LIST EXTERNAL_LIBRARY_GPLV3_LIST)
        set(_ffmpeg_label "GPLv3")
        if(NOT FFMPEG_ENABLE_GPL OR NOT FFMPEG_ENABLE_VERSION3)
            set(_ffmpeg_ok FALSE)
            set(_ffmpeg_detail "requires FFMPEG_ENABLE_GPL and FFMPEG_ENABLE_VERSION3")
        endif()
    elseif(_feature IN_LIST EXTERNAL_LIBRARY_GPL_LIST)
        set(_ffmpeg_label "GPL")
        if(NOT FFMPEG_ENABLE_GPL)
            set(_ffmpeg_ok FALSE)
            set(_ffmpeg_detail "requires FFMPEG_ENABLE_GPL")
        endif()
    elseif(_feature IN_LIST EXTERNAL_LIBRARY_VERSION3_LIST)
        set(_ffmpeg_label "Version3")
        if(NOT FFMPEG_ENABLE_VERSION3)
            set(_ffmpeg_ok FALSE)
            set(_ffmpeg_detail "requires FFMPEG_ENABLE_VERSION3")
        endif()
    endif()

    set(${_out_ok} "${_ffmpeg_ok}" PARENT_SCOPE)
    set(${_out_label} "${_ffmpeg_label}" PARENT_SCOPE)
    set(${_out_detail} "${_ffmpeg_detail}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_dep_matrix_markdown_escape _out _text)
    set(_ffmpeg_text "${_text}")
    string(REPLACE "\\" "\\\\" _ffmpeg_text "${_ffmpeg_text}")
    string(REPLACE "|" "\\|" _ffmpeg_text "${_ffmpeg_text}")
    string(REPLACE "\n" " " _ffmpeg_text "${_ffmpeg_text}")
    set(${_out} "${_ffmpeg_text}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_dep_matrix_short_list _out _values _limit)
    set(_ffmpeg_items ${${_values}})
    list(LENGTH _ffmpeg_items _ffmpeg_count)
    if(_ffmpeg_count EQUAL 0)
        set(${_out} "none" PARENT_SCOPE)
        return()
    endif()

    set(_ffmpeg_result)
    set(_ffmpeg_index 0)
    foreach(_ffmpeg_item IN LISTS _ffmpeg_items)
        if(_ffmpeg_index GREATER_EQUAL _limit)
            break()
        endif()
        list(APPEND _ffmpeg_result "${_ffmpeg_item}")
        math(EXPR _ffmpeg_index "${_ffmpeg_index} + 1")
    endforeach()
    if(_ffmpeg_count GREATER _limit)
        math(EXPR _ffmpeg_remaining "${_ffmpeg_count} - ${_limit}")
        list(APPEND _ffmpeg_result "+${_ffmpeg_remaining} more")
    endif()
    string(REPLACE ";" ", " _ffmpeg_text "${_ffmpeg_result}")
    set(${_out} "${_ffmpeg_text}" PARENT_SCOPE)
endfunction()

function(ffmpeg_generate_external_dependency_matrix)
    if(NOT FFMPEG_EXTERNAL_DEPENDENCY_MATRIX)
        set(FFMPEG_EXTERNAL_DEPENDENCY_MATRIX_SUMMARY "disabled" CACHE INTERNAL "Summary of FFmpeg external dependency matrix results" FORCE)
        return()
    endif()
    if(NOT FFMPEG_BUILD_FROM_SOURCE)
        set(FFMPEG_EXTERNAL_DEPENDENCY_MATRIX_SUMMARY "source-build=off" CACHE INTERNAL "Summary of FFmpeg external dependency matrix results" FORCE)
        return()
    endif()
    if(NOT EXISTS "${FFMPEG_SOURCE_DIR}/configure")
        set(FFMPEG_EXTERNAL_DEPENDENCY_MATRIX_SUMMARY "missing-configure" CACHE INTERNAL "Summary of FFmpeg external dependency matrix results" FORCE)
        return()
    endif()

    _ffmpeg_dep_matrix_parse_lists(
        _ffmpeg_all_deps
        _ffmpeg_explicit_deps
        _ffmpeg_autodetect_deps
        _ffmpeg_hw_explicit_deps
        _ffmpeg_hw_autodetect_deps)
    _ffmpeg_dep_matrix_collect_component_uses("${_ffmpeg_all_deps}")
    _ffmpeg_dep_matrix_collect_pkg_rules()

    set(_ffmpeg_rows)
    set(_ffmpeg_found)
    set(_ffmpeg_not_found)
    set(_ffmpeg_off)
    set(_ffmpeg_disabled)
    set(_ffmpeg_unknown)
    set(_ffmpeg_requested_missing)
    set(_ffmpeg_requested_off)
    set(_ffmpeg_requested_disabled)
    set(_ffmpeg_requested_unknown)
    set(_ffmpeg_codec_deps)
    set(_ffmpeg_hardware_deps)
    set(_ffmpeg_filter_deps)

    set(_ffmpeg_autodetect_enabled TRUE)
    if(FFMPEG_DISABLE_AUTODETECT)
        set(_ffmpeg_autodetect_enabled FALSE)
    endif()

    foreach(_ffmpeg_dep IN LISTS _ffmpeg_all_deps)
        _ffmpeg_dep_matrix_var_suffix(_ffmpeg_suffix "${_ffmpeg_dep}")
        set(_ffmpeg_uses "${FFMPEG_DEP_MATRIX_USES_${_ffmpeg_suffix}}")
        set(_ffmpeg_used_by "${FFMPEG_DEP_MATRIX_USED_BY_${_ffmpeg_suffix}}")

        if(_ffmpeg_dep IN_LIST _ffmpeg_hw_explicit_deps)
            set(_ffmpeg_kind "Hardware opt-in")
            _ffmpeg_dep_matrix_add_use("${_ffmpeg_dep}" "Hardware" "")
            set(_ffmpeg_uses "${FFMPEG_DEP_MATRIX_USES_${_ffmpeg_suffix}}")
        elseif(_ffmpeg_dep IN_LIST _ffmpeg_hw_autodetect_deps)
            set(_ffmpeg_kind "Hardware autodetect")
            _ffmpeg_dep_matrix_add_use("${_ffmpeg_dep}" "Hardware" "")
            set(_ffmpeg_uses "${FFMPEG_DEP_MATRIX_USES_${_ffmpeg_suffix}}")
        elseif(_ffmpeg_dep IN_LIST _ffmpeg_autodetect_deps)
            set(_ffmpeg_kind "Autodetect")
        else()
            set(_ffmpeg_kind "External opt-in")
        endif()

        if(NOT _ffmpeg_uses)
            set(_ffmpeg_uses "Other")
        endif()
        if("Codecs" IN_LIST _ffmpeg_uses)
            list(APPEND _ffmpeg_codec_deps "${_ffmpeg_dep}")
        endif()
        if("Hardware" IN_LIST _ffmpeg_uses)
            list(APPEND _ffmpeg_hardware_deps "${_ffmpeg_dep}")
        endif()
        if("Filters" IN_LIST _ffmpeg_uses)
            list(APPEND _ffmpeg_filter_deps "${_ffmpeg_dep}")
        endif()

        _ffmpeg_dep_matrix_raw_option_state(_ffmpeg_raw_enabled _ffmpeg_raw_disabled "${_ffmpeg_dep}")
        set(_ffmpeg_requested FALSE)
        if(_ffmpeg_dep IN_LIST FFMPEG_ENABLE_EXTERNAL_LIBRARIES OR
           _ffmpeg_dep IN_LIST FFMPEG_ENABLE_FEATURES OR
           _ffmpeg_raw_enabled)
            set(_ffmpeg_requested TRUE)
        endif()
        set(_ffmpeg_explicitly_disabled FALSE)
        if(_ffmpeg_dep IN_LIST FFMPEG_DISABLE_EXTERNAL_LIBRARIES OR
           _ffmpeg_dep IN_LIST FFMPEG_DISABLE_FEATURES OR
           _ffmpeg_raw_disabled)
            set(_ffmpeg_explicitly_disabled TRUE)
        endif()

        _ffmpeg_dep_matrix_license_state(_ffmpeg_license_ok _ffmpeg_license _ffmpeg_license_detail "${_ffmpeg_dep}")

        set(_ffmpeg_status)
        set(_ffmpeg_request_state)
        set(_ffmpeg_detail)
        if(_ffmpeg_explicitly_disabled)
            set(_ffmpeg_status "DISABLED")
            set(_ffmpeg_request_state "disabled")
            set(_ffmpeg_detail "disabled by CMake/user option")
        elseif(NOT _ffmpeg_license_ok)
            set(_ffmpeg_status "OFF")
            if(_ffmpeg_requested)
                set(_ffmpeg_request_state "requested but license-off")
            else()
                set(_ffmpeg_request_state "license-off")
            endif()
            set(_ffmpeg_detail "${_ffmpeg_license_detail}")
        elseif(NOT _ffmpeg_requested AND _ffmpeg_dep IN_LIST _ffmpeg_explicit_deps)
            set(_ffmpeg_status "OFF")
            set(_ffmpeg_request_state "default off")
            set(_ffmpeg_detail "explicit --enable-${_ffmpeg_dep} is required")
        elseif(NOT _ffmpeg_requested AND _ffmpeg_dep IN_LIST _ffmpeg_hw_explicit_deps)
            set(_ffmpeg_status "OFF")
            set(_ffmpeg_request_state "default off")
            set(_ffmpeg_detail "explicit --enable-${_ffmpeg_dep} is required")
        elseif(NOT _ffmpeg_requested AND NOT _ffmpeg_autodetect_enabled)
            set(_ffmpeg_status "OFF")
            set(_ffmpeg_request_state "autodetect disabled")
            set(_ffmpeg_detail "FFMPEG_DISABLE_AUTODETECT is ON")
        else()
            if(_ffmpeg_requested)
                set(_ffmpeg_request_state "requested")
            else()
                set(_ffmpeg_request_state "autodetect")
            endif()

            _ffmpeg_dep_matrix_probe(_ffmpeg_probe_known _ffmpeg_probe_found _ffmpeg_probe_detail "${_ffmpeg_dep}")
            set(_ffmpeg_detail "${_ffmpeg_probe_detail}")
            if(_ffmpeg_probe_found)
                set(_ffmpeg_status "FOUND")
            elseif(NOT _ffmpeg_requested AND _ffmpeg_probe_known AND _ffmpeg_probe_detail MATCHES "^not (a|an) [A-Za-z]+ platform")
                set(_ffmpeg_status "OFF")
                set(_ffmpeg_request_state "platform off")
            elseif(_ffmpeg_probe_known)
                set(_ffmpeg_status "NOT FOUND")
            else()
                set(_ffmpeg_status "UNKNOWN")
            endif()
        endif()

        if(_ffmpeg_status STREQUAL "FOUND")
            list(APPEND _ffmpeg_found "${_ffmpeg_dep}")
        elseif(_ffmpeg_status STREQUAL "NOT FOUND")
            list(APPEND _ffmpeg_not_found "${_ffmpeg_dep}")
            if(_ffmpeg_requested)
                list(APPEND _ffmpeg_requested_missing "${_ffmpeg_dep}")
            endif()
        elseif(_ffmpeg_status STREQUAL "OFF")
            list(APPEND _ffmpeg_off "${_ffmpeg_dep}")
            if(_ffmpeg_requested)
                list(APPEND _ffmpeg_requested_off "${_ffmpeg_dep}")
            endif()
        elseif(_ffmpeg_status STREQUAL "DISABLED")
            list(APPEND _ffmpeg_disabled "${_ffmpeg_dep}")
            if(_ffmpeg_requested)
                list(APPEND _ffmpeg_requested_disabled "${_ffmpeg_dep}")
            endif()
        else()
            list(APPEND _ffmpeg_unknown "${_ffmpeg_dep}")
            if(_ffmpeg_requested)
                list(APPEND _ffmpeg_requested_unknown "${_ffmpeg_dep}")
            endif()
        endif()

        _ffmpeg_dep_matrix_short_list(_ffmpeg_used_by_text _ffmpeg_used_by 12)
        string(REPLACE ";" ", " _ffmpeg_uses_text "${_ffmpeg_uses}")
        _ffmpeg_dep_matrix_markdown_escape(_ffmpeg_kind_md "${_ffmpeg_kind}")
        _ffmpeg_dep_matrix_markdown_escape(_ffmpeg_uses_md "${_ffmpeg_uses_text}")
        _ffmpeg_dep_matrix_markdown_escape(_ffmpeg_license_md "${_ffmpeg_license}")
        _ffmpeg_dep_matrix_markdown_escape(_ffmpeg_status_md "${_ffmpeg_status}")
        _ffmpeg_dep_matrix_markdown_escape(_ffmpeg_request_md "${_ffmpeg_request_state}")
        _ffmpeg_dep_matrix_markdown_escape(_ffmpeg_detail_md "${_ffmpeg_detail}")
        _ffmpeg_dep_matrix_markdown_escape(_ffmpeg_used_by_md "${_ffmpeg_used_by_text}")
        set(_ffmpeg_row "| `${_ffmpeg_dep}` | ${_ffmpeg_kind_md} | ${_ffmpeg_uses_md} | ")
        string(APPEND _ffmpeg_row "${_ffmpeg_license_md} | ${_ffmpeg_status_md} | ")
        string(APPEND _ffmpeg_row "${_ffmpeg_request_md} | ${_ffmpeg_detail_md} | ${_ffmpeg_used_by_md} |")
        list(APPEND _ffmpeg_rows "${_ffmpeg_row}")
    endforeach()

    foreach(_ffmpeg_list IN ITEMS
            _ffmpeg_found
            _ffmpeg_not_found
            _ffmpeg_off
            _ffmpeg_disabled
            _ffmpeg_unknown
            _ffmpeg_requested_missing
            _ffmpeg_requested_off
            _ffmpeg_requested_disabled
            _ffmpeg_requested_unknown
            _ffmpeg_codec_deps
            _ffmpeg_hardware_deps
            _ffmpeg_filter_deps)
        list(REMOVE_DUPLICATES ${_ffmpeg_list})
        list(SORT ${_ffmpeg_list})
    endforeach()

    list(LENGTH _ffmpeg_all_deps _ffmpeg_total_count)
    list(LENGTH _ffmpeg_explicit_deps _ffmpeg_explicit_count)
    list(LENGTH _ffmpeg_autodetect_deps _ffmpeg_autodetect_count)
    list(LENGTH _ffmpeg_hw_explicit_deps _ffmpeg_hw_explicit_count)
    list(LENGTH _ffmpeg_hw_autodetect_deps _ffmpeg_hw_autodetect_count)
    list(LENGTH _ffmpeg_found _ffmpeg_found_count)
    list(LENGTH _ffmpeg_not_found _ffmpeg_not_found_count)
    list(LENGTH _ffmpeg_off _ffmpeg_off_count)
    list(LENGTH _ffmpeg_disabled _ffmpeg_disabled_count)
    list(LENGTH _ffmpeg_unknown _ffmpeg_unknown_count)
    list(LENGTH _ffmpeg_codec_deps _ffmpeg_codec_count)
    list(LENGTH _ffmpeg_hardware_deps _ffmpeg_hardware_count)
    list(LENGTH _ffmpeg_filter_deps _ffmpeg_filter_count)

    set(_ffmpeg_summary
        "total=${_ffmpeg_total_count}"
        "found=${_ffmpeg_found_count}"
        "not-found=${_ffmpeg_not_found_count}"
        "off=${_ffmpeg_off_count}"
        "disabled=${_ffmpeg_disabled_count}"
        "unknown=${_ffmpeg_unknown_count}"
        "codec-related=${_ffmpeg_codec_count}"
        "hardware-related=${_ffmpeg_hardware_count}"
        "filter-related=${_ffmpeg_filter_count}")

    set(_ffmpeg_content "# FFmpeg External Dependency Matrix\n\n")
    string(APPEND _ffmpeg_content "Generated by ffmpeg-cmake from `${FFMPEG_SOURCE_DIR}/configure`.\n\n")
    string(APPEND _ffmpeg_content "## Summary\n\n")
    string(APPEND _ffmpeg_content "| Metric | Count |\n")
    string(APPEND _ffmpeg_content "| --- | ---: |\n")
    string(APPEND _ffmpeg_content "| Unique external and hardware dependency names | ${_ffmpeg_total_count} |\n")
    string(APPEND _ffmpeg_content "| Explicit external libraries | ${_ffmpeg_explicit_count} |\n")
    string(APPEND _ffmpeg_content "| Autodetected external libraries | ${_ffmpeg_autodetect_count} |\n")
    string(APPEND _ffmpeg_content "| Explicit hardware libraries | ${_ffmpeg_hw_explicit_count} |\n")
    string(APPEND _ffmpeg_content "| Autodetected hardware backends | ${_ffmpeg_hw_autodetect_count} |\n")
    string(APPEND _ffmpeg_content "| Found | ${_ffmpeg_found_count} |\n")
    string(APPEND _ffmpeg_content "| Not found | ${_ffmpeg_not_found_count} |\n")
    string(APPEND _ffmpeg_content "| Off | ${_ffmpeg_off_count} |\n")
    string(APPEND _ffmpeg_content "| Disabled | ${_ffmpeg_disabled_count} |\n")
    string(APPEND _ffmpeg_content "| Unknown probe | ${_ffmpeg_unknown_count} |\n")
    string(APPEND _ffmpeg_content "| Codec-related dependencies | ${_ffmpeg_codec_count} |\n")
    string(APPEND _ffmpeg_content "| Hardware-related dependencies | ${_ffmpeg_hardware_count} |\n")
    string(APPEND _ffmpeg_content "| Filter-related dependencies | ${_ffmpeg_filter_count} |\n\n")

    string(APPEND _ffmpeg_content "## Requested Issues\n\n")
    if(_ffmpeg_requested_missing OR _ffmpeg_requested_off OR _ffmpeg_requested_disabled OR _ffmpeg_requested_unknown)
        if(_ffmpeg_requested_missing)
            string(REPLACE ";" ", " _ffmpeg_requested_missing_text "${_ffmpeg_requested_missing}")
            string(APPEND _ffmpeg_content "- Requested but not found: ${_ffmpeg_requested_missing_text}\n")
        else()
            string(APPEND _ffmpeg_content "- Requested but not found: none\n")
        endif()
        if(_ffmpeg_requested_off)
            string(REPLACE ";" ", " _ffmpeg_requested_off_text "${_ffmpeg_requested_off}")
            string(APPEND _ffmpeg_content "- Requested but off: ${_ffmpeg_requested_off_text}\n")
        else()
            string(APPEND _ffmpeg_content "- Requested but off: none\n")
        endif()
        if(_ffmpeg_requested_disabled)
            string(REPLACE ";" ", " _ffmpeg_requested_disabled_text "${_ffmpeg_requested_disabled}")
            string(APPEND _ffmpeg_content "- Requested but disabled: ${_ffmpeg_requested_disabled_text}\n")
        else()
            string(APPEND _ffmpeg_content "- Requested but disabled: none\n")
        endif()
        if(_ffmpeg_requested_unknown)
            string(REPLACE ";" ", " _ffmpeg_requested_unknown_text "${_ffmpeg_requested_unknown}")
            string(APPEND _ffmpeg_content "- Requested with unknown probe coverage: ${_ffmpeg_requested_unknown_text}\n")
        else()
            string(APPEND _ffmpeg_content "- Requested with unknown probe coverage: none\n")
        endif()
    else()
        string(APPEND _ffmpeg_content "- none\n")
    endif()

    string(APPEND _ffmpeg_content "\n## Matrix\n\n")
    string(APPEND _ffmpeg_content "| Dependency | Kind | Use | License | Status | Request | Probe/detail | Used by |\n")
    string(APPEND _ffmpeg_content "| --- | --- | --- | --- | --- | --- | --- | --- |\n")
    foreach(_ffmpeg_row IN LISTS _ffmpeg_rows)
        string(APPEND _ffmpeg_content "${_ffmpeg_row}\n")
    endforeach()

    get_filename_component(_ffmpeg_matrix_dir "${FFMPEG_EXTERNAL_DEPENDENCY_MATRIX_FILE}" DIRECTORY)
    file(MAKE_DIRECTORY "${_ffmpeg_matrix_dir}")
    file(WRITE "${FFMPEG_EXTERNAL_DEPENDENCY_MATRIX_FILE}" "${_ffmpeg_content}")

    set(FFMPEG_EXTERNAL_DEPENDENCY_MATRIX_SUMMARY "${_ffmpeg_summary}" CACHE INTERNAL "Summary of FFmpeg external dependency matrix results" FORCE)
    set(FFMPEG_EXTERNAL_DEPENDENCY_MATRIX_FOUND "${_ffmpeg_found}" CACHE INTERNAL "External dependencies found by the matrix probe" FORCE)
    set(FFMPEG_EXTERNAL_DEPENDENCY_MATRIX_NOT_FOUND "${_ffmpeg_not_found}" CACHE INTERNAL "External dependencies not found by the matrix probe" FORCE)
    set(FFMPEG_EXTERNAL_DEPENDENCY_MATRIX_OFF "${_ffmpeg_off}" CACHE INTERNAL "External dependencies off by default or license/autodetect setting" FORCE)
    set(FFMPEG_EXTERNAL_DEPENDENCY_MATRIX_DISABLED "${_ffmpeg_disabled}" CACHE INTERNAL "External dependencies disabled by user options" FORCE)
    set(FFMPEG_EXTERNAL_DEPENDENCY_MATRIX_UNKNOWN "${_ffmpeg_unknown}" CACHE INTERNAL "External dependencies without a matrix probe rule" FORCE)
    set(FFMPEG_EXTERNAL_DEPENDENCY_MATRIX_REQUESTED_MISSING "${_ffmpeg_requested_missing}" CACHE INTERNAL "Requested external dependencies not found by the matrix probe" FORCE)
    set(FFMPEG_EXTERNAL_DEPENDENCY_MATRIX_REQUESTED_OFF "${_ffmpeg_requested_off}" CACHE INTERNAL "Requested external dependencies blocked by off/license/autodetect state" FORCE)
    set(FFMPEG_EXTERNAL_DEPENDENCY_MATRIX_REQUESTED_DISABLED "${_ffmpeg_requested_disabled}" CACHE INTERNAL "Requested external dependencies also disabled by user options" FORCE)
    set(FFMPEG_EXTERNAL_DEPENDENCY_MATRIX_REQUESTED_UNKNOWN "${_ffmpeg_requested_unknown}" CACHE INTERNAL "Requested external dependencies without a matrix probe rule" FORCE)
    set(FFMPEG_EXTERNAL_DEPENDENCY_MATRIX_CODEC_DEPENDENCIES "${_ffmpeg_codec_deps}" CACHE INTERNAL "Codec-related external dependency names" FORCE)
    set(FFMPEG_EXTERNAL_DEPENDENCY_MATRIX_HARDWARE_DEPENDENCIES "${_ffmpeg_hardware_deps}" CACHE INTERNAL "Hardware-related external dependency names" FORCE)
    set(FFMPEG_EXTERNAL_DEPENDENCY_MATRIX_FILTER_DEPENDENCIES "${_ffmpeg_filter_deps}" CACHE INTERNAL "Filter-related external dependency names" FORCE)
endfunction()
