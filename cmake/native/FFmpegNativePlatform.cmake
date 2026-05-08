include_guard(GLOBAL)

include(CheckCSourceCompiles)
include(CheckIncludeFile)
include(CheckSymbolExists)
include(FFmpegPkgConfigTargets)

function(_ffmpeg_native_prefix_include_dirs _out)
    set(_ffmpeg_dirs)
    if(FFMPEG_NV_CODEC_HEADERS_INCLUDE_DIR AND IS_DIRECTORY "${FFMPEG_NV_CODEC_HEADERS_INCLUDE_DIR}")
        list(APPEND _ffmpeg_dirs "${FFMPEG_NV_CODEC_HEADERS_INCLUDE_DIR}")
    endif()
    if(FFMPEG_AMF_HEADERS_INCLUDE_DIR AND IS_DIRECTORY "${FFMPEG_AMF_HEADERS_INCLUDE_DIR}")
        list(APPEND _ffmpeg_dirs "${FFMPEG_AMF_HEADERS_INCLUDE_DIR}")
    endif()
    foreach(_ffmpeg_prefix IN LISTS CMAKE_PREFIX_PATH)
        if(_ffmpeg_prefix STREQUAL "")
            continue()
        endif()
        foreach(_ffmpeg_suffix IN ITEMS
                include
                include/vpl
                include/mfx
                include/fribidi
                include/harfbuzz
                include/freetype2
                include/openjpeg-2.5
                include/openjpeg-2.4)
            if(IS_DIRECTORY "${_ffmpeg_prefix}/${_ffmpeg_suffix}")
                list(APPEND _ffmpeg_dirs "${_ffmpeg_prefix}/${_ffmpeg_suffix}")
            endif()
        endforeach()
    endforeach()
    foreach(_ffmpeg_dir IN LISTS CMAKE_INCLUDE_PATH)
        if(IS_DIRECTORY "${_ffmpeg_dir}")
            list(APPEND _ffmpeg_dirs "${_ffmpeg_dir}")
        endif()
    endforeach()
    list(REMOVE_DUPLICATES _ffmpeg_dirs)
    set(${_out} "${_ffmpeg_dirs}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_prefix_library_dirs _out)
    set(_ffmpeg_dirs)
    foreach(_ffmpeg_prefix IN LISTS CMAKE_PREFIX_PATH)
        if(_ffmpeg_prefix STREQUAL "")
            continue()
        endif()
        foreach(_ffmpeg_suffix IN ITEMS lib lib64 bin)
            if(IS_DIRECTORY "${_ffmpeg_prefix}/${_ffmpeg_suffix}")
                list(APPEND _ffmpeg_dirs "${_ffmpeg_prefix}/${_ffmpeg_suffix}")
            endif()
        endforeach()
    endforeach()
    list(REMOVE_DUPLICATES _ffmpeg_dirs)
    set(${_out} "${_ffmpeg_dirs}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_check_c_source _out _feature _source)
    string(MAKE_C_IDENTIFIER "FFMPEG_NATIVE_CHECK_${_feature}" _ffmpeg_check_var)
    set(_ffmpeg_check_stamp_var "${_ffmpeg_check_var}_STAMP")
    set(_ffmpeg_saved_required_includes "${CMAKE_REQUIRED_INCLUDES}")
    _ffmpeg_native_prefix_include_dirs(_ffmpeg_required_includes)
    if(_ffmpeg_required_includes)
        list(APPEND CMAKE_REQUIRED_INCLUDES ${_ffmpeg_required_includes})
    endif()
    string(SHA1 _ffmpeg_check_stamp "${_source}|${CMAKE_REQUIRED_INCLUDES}|${CMAKE_C_COMPILER}|${CMAKE_C_FLAGS}|${CMAKE_MSVC_RUNTIME_LIBRARY}|${CMAKE_SYSTEM_NAME}|${CMAKE_SYSTEM_PROCESSOR}")
    if(NOT DEFINED ${_ffmpeg_check_stamp_var} OR NOT "${${_ffmpeg_check_stamp_var}}" STREQUAL "${_ffmpeg_check_stamp}")
        unset(${_ffmpeg_check_var} CACHE)
    endif()
    check_c_source_compiles("${_source}" "${_ffmpeg_check_var}")
    set(${_ffmpeg_check_stamp_var} "${_ffmpeg_check_stamp}" CACHE INTERNAL "Input stamp for ${_ffmpeg_check_var}")
    set(CMAKE_REQUIRED_INCLUDES "${_ffmpeg_saved_required_includes}")
    set(${_out} "${${_ffmpeg_check_var}}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_check_c_source_links _out _feature _source)
    string(MAKE_C_IDENTIFIER "FFMPEG_NATIVE_LINK_${_feature}" _ffmpeg_check_var)
    set(_ffmpeg_check_stamp_var "${_ffmpeg_check_var}_STAMP")
    set(_ffmpeg_saved_required_includes "${CMAKE_REQUIRED_INCLUDES}")
    set(_ffmpeg_saved_required_libraries "${CMAKE_REQUIRED_LIBRARIES}")
    _ffmpeg_native_prefix_include_dirs(_ffmpeg_required_includes)
    if(_ffmpeg_required_includes)
        list(APPEND CMAKE_REQUIRED_INCLUDES ${_ffmpeg_required_includes})
    endif()
    set(CMAKE_REQUIRED_LIBRARIES ${ARGN})
    string(SHA1 _ffmpeg_check_stamp "${_source}|${CMAKE_REQUIRED_INCLUDES}|${CMAKE_REQUIRED_LIBRARIES}|${CMAKE_C_COMPILER}|${CMAKE_C_FLAGS}|${CMAKE_EXE_LINKER_FLAGS}|${CMAKE_MSVC_RUNTIME_LIBRARY}|${CMAKE_SYSTEM_NAME}|${CMAKE_SYSTEM_PROCESSOR}")
    if(NOT DEFINED ${_ffmpeg_check_stamp_var} OR NOT "${${_ffmpeg_check_stamp_var}}" STREQUAL "${_ffmpeg_check_stamp}")
        unset(${_ffmpeg_check_var} CACHE)
    endif()
    check_c_source_compiles("${_source}" "${_ffmpeg_check_var}")
    set(${_ffmpeg_check_stamp_var} "${_ffmpeg_check_stamp}" CACHE INTERNAL "Input stamp for ${_ffmpeg_check_var}")
    set(CMAKE_REQUIRED_INCLUDES "${_ffmpeg_saved_required_includes}")
    set(CMAKE_REQUIRED_LIBRARIES "${_ffmpeg_saved_required_libraries}")
    set(${_out} "${${_ffmpeg_check_var}}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_header_available _out _header)
    _ffmpeg_native_prefix_include_dirs(_ffmpeg_include_dirs)
    foreach(_ffmpeg_include_dir IN LISTS _ffmpeg_include_dirs)
        if(EXISTS "${_ffmpeg_include_dir}/${_header}")
            set(${_out} TRUE PARENT_SCOPE)
            return()
        endif()
    endforeach()

    string(MAKE_C_IDENTIFIER "FFMPEG_NATIVE_HAVE_HEADER_${_header}" _ffmpeg_header_var)
    set(_ffmpeg_saved_required_includes "${CMAKE_REQUIRED_INCLUDES}")
    if(_ffmpeg_include_dirs)
        list(APPEND CMAKE_REQUIRED_INCLUDES ${_ffmpeg_include_dirs})
    endif()
    check_include_file("${_header}" "${_ffmpeg_header_var}")
    set(CMAKE_REQUIRED_INCLUDES "${_ffmpeg_saved_required_includes}")
    set(${_out} "${${_ffmpeg_header_var}}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_append_have_if_compiles _feature _source)
    _ffmpeg_native_check_c_source(_ffmpeg_compiles "${_feature}" "${_source}")
    if(_ffmpeg_compiles)
        list(APPEND _ffmpeg_enabled_have "${_feature}")
        set(_ffmpeg_enabled_have "${_ffmpeg_enabled_have}" PARENT_SCOPE)
    endif()
endfunction()

function(_ffmpeg_native_append_config_if_compiles _feature _source)
    _ffmpeg_native_check_c_source(_ffmpeg_compiles "${_feature}" "${_source}")
    if(_ffmpeg_compiles)
        list(APPEND FFMPEG_NATIVE_DETECTED_CONFIG_FEATURES "${_feature}")
        set(FFMPEG_NATIVE_DETECTED_CONFIG_FEATURES "${FFMPEG_NATIVE_DETECTED_CONFIG_FEATURES}" PARENT_SCOPE)
    endif()
endfunction()

function(_ffmpeg_native_pkg_config_available _out _pkg)
    _ffmpeg_pkg_config_path(_ffmpeg_pc_path "")
    _ffmpeg_pkg_config_output(_ffmpeg_unused _ffmpeg_result "${_ffmpeg_pc_path}" --exists "${_pkg}")
    if(_ffmpeg_result EQUAL 0)
        set(${_out} TRUE PARENT_SCOPE)
    else()
        set(${_out} FALSE PARENT_SCOPE)
    endif()
endfunction()

function(_ffmpeg_native_append_config_if_pkg _feature _pkg)
    _ffmpeg_native_pkg_config_available(_ffmpeg_pkg_found "${_pkg}")
    if(_ffmpeg_pkg_found)
        list(APPEND FFMPEG_NATIVE_DETECTED_CONFIG_FEATURES "${_feature}")
        set(FFMPEG_NATIVE_DETECTED_CONFIG_FEATURES "${FFMPEG_NATIVE_DETECTED_CONFIG_FEATURES}" PARENT_SCOPE)
    endif()
endfunction()

function(_ffmpeg_native_cmake_target_available _out _package)
    if(_package STREQUAL "Freetype")
        find_package(PNG CONFIG QUIET)
    endif()
    find_package("${_package}" CONFIG QUIET)
    foreach(_ffmpeg_target IN LISTS ARGN)
        if(TARGET "${_ffmpeg_target}")
            set(${_out} TRUE PARENT_SCOPE)
            return()
        endif()
    endforeach()
    set(${_out} FALSE PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_append_config_if_cmake_target _feature _package)
    _ffmpeg_native_cmake_target_available(_ffmpeg_cmake_found "${_package}" ${ARGN})
    if(_ffmpeg_cmake_found)
        list(APPEND FFMPEG_NATIVE_DETECTED_CONFIG_FEATURES "${_feature}")
    endif()
    set(FFMPEG_NATIVE_DETECTED_CONFIG_FEATURES "${FFMPEG_NATIVE_DETECTED_CONFIG_FEATURES}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_header_and_library_available _out _header)
    _ffmpeg_native_header_available(_ffmpeg_header_found "${_header}")
    if(NOT _ffmpeg_header_found)
        set(${_out} FALSE PARENT_SCOPE)
        return()
    endif()

    _ffmpeg_native_prefix_library_dirs(_ffmpeg_library_dirs)
    find_library(_ffmpeg_library_found NAMES ${ARGN} HINTS ${_ffmpeg_library_dirs} NO_CACHE)
    if(_ffmpeg_library_found)
        set(${_out} TRUE PARENT_SCOPE)
    else()
        set(${_out} FALSE PARENT_SCOPE)
    endif()
endfunction()

function(_ffmpeg_native_append_config_if_header_and_library _feature _header)
    _ffmpeg_native_header_and_library_available(_ffmpeg_library_found "${_header}" ${ARGN})
    if(_ffmpeg_library_found)
        list(APPEND FFMPEG_NATIVE_DETECTED_CONFIG_FEATURES "${_feature}")
    endif()
    set(FFMPEG_NATIVE_DETECTED_CONFIG_FEATURES "${FFMPEG_NATIVE_DETECTED_CONFIG_FEATURES}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_qsv_libvpl_available _out)
    find_package(VPL CONFIG QUIET)
    if(TARGET VPL::dispatcher)
        set(_ffmpeg_vpl_link_item VPL::dispatcher)
    else()
        _ffmpeg_native_prefix_library_dirs(_ffmpeg_library_dirs)
        find_library(_ffmpeg_vpl_library NAMES vpl libvpl HINTS ${_ffmpeg_library_dirs} NO_CACHE)
        if(NOT _ffmpeg_vpl_library)
            set(${_out} FALSE PARENT_SCOPE)
            return()
        endif()
        set(_ffmpeg_vpl_link_item "${_ffmpeg_vpl_library}")
    endif()

    _ffmpeg_native_check_c_source_links(_ffmpeg_links libvpl
        "#include <mfxvideo.h>\n#include <mfxdispatcher.h>\nint main(void) { mfxLoader loader = MFXLoad(); if (loader) MFXUnload(loader); return 0; }\n"
        "${_ffmpeg_vpl_link_item}")
    set(${_out} "${_ffmpeg_links}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_qsv_libmfx_available _out)
    _ffmpeg_native_prefix_library_dirs(_ffmpeg_library_dirs)
    find_library(_ffmpeg_mfx_library NAMES mfx libmfx HINTS ${_ffmpeg_library_dirs} NO_CACHE)
    if(NOT _ffmpeg_mfx_library)
        set(${_out} FALSE PARENT_SCOPE)
        return()
    endif()

    _ffmpeg_native_check_c_source_links(_ffmpeg_links libmfx
        "#include <mfxvideo.h>\nint main(void) { mfxSession session = 0; mfxVersion version = { 0 }; MFXInit(MFX_IMPL_AUTO_ANY, &version, &session); if (session) MFXClose(session); return 0; }\n"
        "${_ffmpeg_mfx_library}")
    set(${_out} "${_ffmpeg_links}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_msvc_static_runtime_selected _out)
    if(NOT MSVC)
        set(${_out} FALSE PARENT_SCOPE)
        return()
    endif()

    string(TOUPPER "${CMAKE_MSVC_RUNTIME_LIBRARY}" _ffmpeg_runtime)
    if(_ffmpeg_runtime MATCHES "MULTITHREADED" AND NOT _ffmpeg_runtime MATCHES "DLL")
        set(${_out} TRUE PARENT_SCOPE)
    else()
        set(${_out} FALSE PARENT_SCOPE)
    endif()
endfunction()

function(_ffmpeg_native_qsv_libvpl_failure_note _out)
    _ffmpeg_native_msvc_static_runtime_selected(_ffmpeg_static_runtime)
    if(_ffmpeg_static_runtime)
        set(${_out} "oneVPL was found but failed the link probe with the current static MSVC runtime profile. Rebuild oneVPL for /MT and /MTd, or use a /MD and /MDd FFmpeg CMake profile." PARENT_SCOPE)
    else()
        set(${_out} "oneVPL was found but failed the link probe." PARENT_SCOPE)
    endif()
endfunction()

function(_ffmpeg_native_detect_qsv_backends)
    set(FFMPEG_NATIVE_QSV_BACKEND "none")
    set(FFMPEG_NATIVE_QSV_BACKEND_NOTE)
    if(NOT FFMPEG_NATIVE_AUTODETECT_EXTERNAL_LIBRARIES)
        set(FFMPEG_NATIVE_QSV_BACKEND "${FFMPEG_NATIVE_QSV_BACKEND}" PARENT_SCOPE)
        set(FFMPEG_NATIVE_QSV_BACKEND_NOTE "${FFMPEG_NATIVE_QSV_BACKEND_NOTE}" PARENT_SCOPE)
        set(FFMPEG_NATIVE_DETECTED_CONFIG_FEATURES "${FFMPEG_NATIVE_DETECTED_CONFIG_FEATURES}" PARENT_SCOPE)
        return()
    endif()

    set(_ffmpeg_vpl_candidate FALSE)
    _ffmpeg_native_pkg_config_available(_ffmpeg_has_libvpl "vpl")
    if(_ffmpeg_has_libvpl)
        set(_ffmpeg_vpl_candidate TRUE)
        _ffmpeg_native_qsv_libvpl_available(_ffmpeg_has_libvpl)
    endif()
    if(_ffmpeg_has_libvpl)
        # FFmpeg's configure models QSV as depending on "libmfx" even when
        # the imported package is oneVPL; keep both feature names so native
        # dependency pruning follows the same component graph.
        list(APPEND FFMPEG_NATIVE_DETECTED_CONFIG_FEATURES libvpl libmfx qsv qsvdec qsvenc qsvvpp)
        list(APPEND _ffmpeg_enabled_have struct_mfxConfigInterface)
        set(FFMPEG_NATIVE_QSV_BACKEND "oneVPL")
    else()
        _ffmpeg_native_cmake_target_available(_ffmpeg_has_libvpl_cmake VPL VPL::dispatcher)
        if(NOT _ffmpeg_has_libvpl_cmake)
            _ffmpeg_native_header_and_library_available(_ffmpeg_has_libvpl_cmake "vpl/mfxvideo.h" vpl libvpl)
        endif()
        if(_ffmpeg_has_libvpl_cmake)
            set(_ffmpeg_vpl_candidate TRUE)
            _ffmpeg_native_qsv_libvpl_available(_ffmpeg_has_libvpl_cmake)
        endif()
        if(_ffmpeg_has_libvpl_cmake)
            list(APPEND FFMPEG_NATIVE_DETECTED_CONFIG_FEATURES libvpl libmfx qsv qsvdec qsvenc qsvvpp)
            list(APPEND _ffmpeg_enabled_have struct_mfxConfigInterface)
            set(FFMPEG_NATIVE_QSV_BACKEND "oneVPL")
            set(_ffmpeg_enabled_have "${_ffmpeg_enabled_have}" PARENT_SCOPE)
            set(FFMPEG_NATIVE_QSV_BACKEND "${FFMPEG_NATIVE_QSV_BACKEND}" PARENT_SCOPE)
            set(FFMPEG_NATIVE_QSV_BACKEND_NOTE "${FFMPEG_NATIVE_QSV_BACKEND_NOTE}" PARENT_SCOPE)
            set(FFMPEG_NATIVE_DETECTED_CONFIG_FEATURES "${FFMPEG_NATIVE_DETECTED_CONFIG_FEATURES}" PARENT_SCOPE)
            return()
        endif()

        _ffmpeg_native_pkg_config_available(_ffmpeg_has_libmfx "libmfx")
        if(NOT _ffmpeg_has_libmfx)
            _ffmpeg_native_header_and_library_available(_ffmpeg_has_libmfx "mfx/mfxvideo.h" mfx libmfx)
        endif()
        if(_ffmpeg_has_libmfx)
            _ffmpeg_native_qsv_libmfx_available(_ffmpeg_has_libmfx)
        endif()
        if(_ffmpeg_has_libmfx)
            list(APPEND FFMPEG_NATIVE_DETECTED_CONFIG_FEATURES libmfx qsv qsvdec qsvenc qsvvpp)
            set(FFMPEG_NATIVE_QSV_BACKEND "MediaSDK/libmfx")
            if(_ffmpeg_vpl_candidate)
                _ffmpeg_native_qsv_libvpl_failure_note(_ffmpeg_vpl_note)
                set(FFMPEG_NATIVE_QSV_BACKEND_NOTE "${_ffmpeg_vpl_note} Falling back to MediaSDK/libmfx.")
            endif()
        elseif(_ffmpeg_vpl_candidate)
            _ffmpeg_native_qsv_libvpl_failure_note(FFMPEG_NATIVE_QSV_BACKEND_NOTE)
        endif()
    endif()

    set(_ffmpeg_enabled_have "${_ffmpeg_enabled_have}" PARENT_SCOPE)
    set(FFMPEG_NATIVE_QSV_BACKEND "${FFMPEG_NATIVE_QSV_BACKEND}" PARENT_SCOPE)
    set(FFMPEG_NATIVE_QSV_BACKEND_NOTE "${FFMPEG_NATIVE_QSV_BACKEND_NOTE}" PARENT_SCOPE)
    set(FFMPEG_NATIVE_DETECTED_CONFIG_FEATURES "${FFMPEG_NATIVE_DETECTED_CONFIG_FEATURES}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_detect_external_libraries)
    if(NOT FFMPEG_NATIVE_AUTODETECT_EXTERNAL_LIBRARIES)
        set(FFMPEG_NATIVE_DETECTED_CONFIG_FEATURES "${FFMPEG_NATIVE_DETECTED_CONFIG_FEATURES}" PARENT_SCOPE)
        return()
    endif()

    set(_ffmpeg_external_features
        zlib
        lcms2
        libaom
        libass
        libbluray
        libdav1d
        libfontconfig
        libfreetype
        libfribidi
        libharfbuzz
        libjxl
        libjxl_threads
        libkvazaar
        libopenh264
        libopenjpeg
        libopenmpt
        libopus
        librav1e
        openssl
        libmysofa
        libshine
        libsnappy
        libsoxr
        libspeex
        libsvtav1
        libvorbis
        libwebp
        libxml2
        libzimg)
    set(_ffmpeg_external_pkgs
        zlib
        lcms2
        aom
        libass
        libbluray
        dav1d
        fontconfig
        freetype2
        fribidi
        harfbuzz
        libjxl
        libjxl_threads
        kvazaar
        openh264
        libopenjp2
        libopenmpt
        opus
        rav1e
        openssl
        libmysofa
        shine
        snappy
        soxr
        speex
        SvtAv1Enc
        vorbis
        libwebp
        libxml-2.0
        zimg)
    foreach(_ffmpeg_feature _ffmpeg_pkg IN ZIP_LISTS _ffmpeg_external_features _ffmpeg_external_pkgs)
        _ffmpeg_native_append_config_if_pkg("${_ffmpeg_feature}" "${_ffmpeg_pkg}")
    endforeach()

    _ffmpeg_native_append_config_if_cmake_target(zlib ZLIB ZLIB::ZLIB)
    _ffmpeg_native_append_config_if_cmake_target(bzlib BZip2 BZip2::BZip2)
    _ffmpeg_native_append_config_if_cmake_target(lzma LibLZMA LibLZMA::LibLZMA)
    _ffmpeg_native_append_config_if_cmake_target(iconv Iconv Iconv::Iconv)
    _ffmpeg_native_append_config_if_cmake_target(lcms2 lcms2 lcms2::lcms2)
    _ffmpeg_native_append_config_if_cmake_target(libxml2 LibXml2 LibXml2::LibXml2)
    _ffmpeg_native_append_config_if_cmake_target(libaom AOM AOM::aom)
    _ffmpeg_native_append_config_if_cmake_target(libfreetype Freetype Freetype::Freetype freetype)
    _ffmpeg_native_append_config_if_cmake_target(libharfbuzz harfbuzz harfbuzz::harfbuzz HarfBuzz::HarfBuzz)
    _ffmpeg_native_append_config_if_cmake_target(libopenjpeg OpenJPEG openjp2)
    _ffmpeg_native_append_config_if_cmake_target(libopus Opus Opus::opus)
    _ffmpeg_native_append_config_if_cmake_target(openssl OpenSSL OpenSSL::SSL OpenSSL::Crypto)
    _ffmpeg_native_append_config_if_cmake_target(libvpx unofficial-libvpx unofficial::libvpx::libvpx)

    _ffmpeg_native_append_config_if_header_and_library(lcms2 "lcms2.h" lcms2 liblcms2)
    _ffmpeg_native_append_config_if_header_and_library(libass "ass/ass.h" ass libass)
    _ffmpeg_native_append_config_if_header_and_library(libbluray "libbluray/bluray.h" bluray libbluray)
    _ffmpeg_native_append_config_if_header_and_library(libdav1d "dav1d/dav1d.h" dav1d libdav1d)
    _ffmpeg_native_append_config_if_header_and_library(libfontconfig "fontconfig/fontconfig.h" fontconfig libfontconfig)
    _ffmpeg_native_append_config_if_header_and_library(libfribidi "fribidi.h" fribidi libfribidi)
    _ffmpeg_native_append_config_if_header_and_library(libjxl "jxl/decode.h" jxl libjxl)
    _ffmpeg_native_append_config_if_header_and_library(libjxl_threads "jxl/thread_parallel_runner.h" jxl_threads libjxl_threads)
    _ffmpeg_native_append_config_if_header_and_library(libkvazaar "kvazaar.h" kvazaar libkvazaar)
    _ffmpeg_native_append_config_if_header_and_library(libmp3lame "lame/lame.h" mp3lame libmp3lame)
    _ffmpeg_native_append_config_if_header_and_library(libopenh264 "wels/codec_api.h" openh264 libopenh264)
    _ffmpeg_native_append_config_if_header_and_library(libopenmpt "libopenmpt/libopenmpt.h" openmpt libopenmpt)
    _ffmpeg_native_append_config_if_header_and_library(libmysofa "mysofa.h" mysofa libmysofa)
    _ffmpeg_native_append_config_if_header_and_library(librav1e "rav1e.h" rav1e librav1e)
    _ffmpeg_native_append_config_if_header_and_library(libshine "shine/layer3.h" shine libshine)
    _ffmpeg_native_append_config_if_header_and_library(libsnappy "snappy-c.h" snappy libsnappy)
    _ffmpeg_native_append_config_if_header_and_library(libsoxr "soxr.h" soxr libsoxr)
    _ffmpeg_native_append_config_if_header_and_library(libspeex "speex/speex.h" speex libspeex)
    _ffmpeg_native_append_config_if_header_and_library(libsvtav1 "EbSvtAv1Enc.h" SvtAv1Enc SvtAv1EncStatic libSvtAv1Enc libSvtAv1EncStatic)
    _ffmpeg_native_append_config_if_header_and_library(libwebp "webp/encode.h" webp libwebp)
    _ffmpeg_native_append_config_if_header_and_library(libtwolame "twolame.h" twolame libtwolame)
    _ffmpeg_native_append_config_if_header_and_library(libtheora "theora/theoraenc.h" theoraenc libtheoraenc)
    _ffmpeg_native_append_config_if_header_and_library(libvorbis "vorbis/codec.h" vorbis libvorbis)
    _ffmpeg_native_append_config_if_header_and_library(libvorbisenc "vorbis/vorbisenc.h" vorbisenc libvorbisenc)
    _ffmpeg_native_append_config_if_header_and_library(libzimg "zimg.h" zimg libzimg)
    _ffmpeg_native_append_config_if_header_and_library(openssl "openssl/ssl.h" ssl libssl)

    if(FFMPEG_ENABLE_GPL)
        set(_ffmpeg_gpl_external_features libvidstab libx264 libx265)
        set(_ffmpeg_gpl_external_pkgs vidstab x264 x265)
        foreach(_ffmpeg_feature _ffmpeg_pkg IN ZIP_LISTS _ffmpeg_gpl_external_features _ffmpeg_gpl_external_pkgs)
            _ffmpeg_native_append_config_if_pkg("${_ffmpeg_feature}" "${_ffmpeg_pkg}")
        endforeach()
        _ffmpeg_native_append_config_if_header_and_library(libvidstab "vid.stab/libvidstab.h" vidstab libvidstab)
        _ffmpeg_native_append_config_if_header_and_library(libx264 "x264.h" x264 libx264)
        _ffmpeg_native_append_config_if_header_and_library(libx265 "x265.h" x265-static x265 libx265)
        _ffmpeg_native_append_config_if_header_and_library(libxvid "xvid.h" xvidcore libxvidcore xvid libxvid)
    endif()

    if(FFMPEG_ENABLE_VERSION3)
        set(_ffmpeg_version3_external_features
            libopencore_amrnb
            libopencore_amrwb
            libvo_amrwbenc)
        set(_ffmpeg_version3_external_pkgs
            opencore-amrnb
            opencore-amrwb
            vo-amrwbenc)
        foreach(_ffmpeg_feature _ffmpeg_pkg IN ZIP_LISTS _ffmpeg_version3_external_features _ffmpeg_version3_external_pkgs)
            _ffmpeg_native_append_config_if_pkg("${_ffmpeg_feature}" "${_ffmpeg_pkg}")
        endforeach()
        _ffmpeg_native_append_config_if_header_and_library(libopencore_amrnb "opencore-amrnb/interf_dec.h" opencore-amrnb libopencore-amrnb)
        _ffmpeg_native_append_config_if_header_and_library(libopencore_amrwb "opencore-amrwb/dec_if.h" opencore-amrwb libopencore-amrwb)
        _ffmpeg_native_append_config_if_header_and_library(libvo_amrwbenc "vo-amrwbenc/enc_if.h" vo-amrwbenc libvo-amrwbenc)
    endif()

    if(FFMPEG_ENABLE_NONFREE)
        _ffmpeg_native_append_config_if_pkg(libfdk_aac fdk-aac)
        _ffmpeg_native_append_config_if_header_and_library(libfdk_aac "fdk-aac/aacenc_lib.h" fdk-aac fdk_aac libfdk-aac libfdk_aac)
    endif()

    if(libharfbuzz IN_LIST FFMPEG_NATIVE_DETECTED_CONFIG_FEATURES)
        _ffmpeg_native_header_available(_ffmpeg_has_hb_ft "hb-ft.h")
        if(NOT _ffmpeg_has_hb_ft)
            list(REMOVE_ITEM FFMPEG_NATIVE_DETECTED_CONFIG_FEATURES libharfbuzz)
        endif()
    endif()

    set(FFMPEG_NATIVE_DETECTED_CONFIG_FEATURES "${FFMPEG_NATIVE_DETECTED_CONFIG_FEATURES}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_detect_windows_hw_have)
    list(APPEND _ffmpeg_enabled_have LoadLibrary ole32 user32)

    _ffmpeg_native_append_have_if_compiles(dxva_h
        "#include <windows.h>\n#include <dxva.h>\nint main(void) { return 0; }\n")
    _ffmpeg_native_append_have_if_compiles(dxva2api_h
        "#include <d3d9.h>\n#include <dxva2api.h>\nint main(void) { return 0; }\n")
    _ffmpeg_native_append_have_if_compiles(DXVA2_ConfigPictureDecode
        "#include <d3d9.h>\n#include <dxva2api.h>\nint main(void) { DXVA2_ConfigPictureDecode v; (void)v; return 0; }\n")
    _ffmpeg_native_append_have_if_compiles(DXVA_PicParams_AV1
        "#include <windows.h>\n#include <dxva.h>\nint main(void) { DXVA_PicParams_AV1 v; (void)v; return 0; }\n")
    _ffmpeg_native_append_have_if_compiles(DXVA_PicParams_HEVC
        "#include <windows.h>\n#include <dxva.h>\nint main(void) { DXVA_PicParams_HEVC v; (void)v; return 0; }\n")
    _ffmpeg_native_append_have_if_compiles(DXVA_PicParams_VP9
        "#include <windows.h>\n#include <dxva.h>\nint main(void) { DXVA_PicParams_VP9 v; (void)v; return 0; }\n")
    _ffmpeg_native_append_have_if_compiles(ID3D11VideoDecoder
        "#include <windows.h>\n#include <d3d11.h>\nint main(void) { ID3D11VideoDecoder *v = 0; return v != 0; }\n")
    _ffmpeg_native_append_have_if_compiles(ID3D11VideoContext
        "#include <windows.h>\n#include <d3d11.h>\nint main(void) { ID3D11VideoContext *v = 0; return v != 0; }\n")
    _ffmpeg_native_append_have_if_compiles(ID3D12Device
        "#include <windows.h>\n#include <d3d12.h>\nint main(void) { ID3D12Device *v = 0; return v != 0; }\n")
    _ffmpeg_native_append_have_if_compiles(ID3D12VideoDecoder
        "#include <windows.h>\n#include <d3d12.h>\n#include <d3d12video.h>\nint main(void) { ID3D12VideoDecoder *v = 0; return v != 0; }\n")
    _ffmpeg_native_append_have_if_compiles(ID3D12VideoEncoder
        "#include <windows.h>\n#include <d3d12.h>\n#include <d3d12video.h>\nint main(void) { ID3D12VideoEncoder *v = 0; return v != 0; }\n")
    _ffmpeg_native_append_have_if_compiles(ID3D12VideoProcessor
        "#include <windows.h>\n#include <d3d12.h>\n#include <d3d12video.h>\nint main(void) { ID3D12VideoProcessor *v = 0; return v != 0; }\n")
    _ffmpeg_native_append_have_if_compiles(ID3D12VideoMotionEstimator
        "#include <windows.h>\n#include <d3d12.h>\n#include <d3d12video.h>\nint main(void) { ID3D12VideoMotionEstimator *v = 0; return v != 0; }\n")

    if(dxva_h IN_LIST _ffmpeg_enabled_have AND
       ID3D11VideoDecoder IN_LIST _ffmpeg_enabled_have AND
       ID3D11VideoContext IN_LIST _ffmpeg_enabled_have)
        list(APPEND FFMPEG_NATIVE_DETECTED_CONFIG_FEATURES d3d11va)
    endif()
    if(dxva_h IN_LIST _ffmpeg_enabled_have AND
       ID3D12Device IN_LIST _ffmpeg_enabled_have AND
       ID3D12VideoDecoder IN_LIST _ffmpeg_enabled_have)
        list(APPEND FFMPEG_NATIVE_DETECTED_CONFIG_FEATURES d3d12va)
    endif()
    if(dxva2api_h IN_LIST _ffmpeg_enabled_have AND
       DXVA2_ConfigPictureDecode IN_LIST _ffmpeg_enabled_have)
        list(APPEND FFMPEG_NATIVE_DETECTED_CONFIG_FEATURES dxva2)
    endif()

    _ffmpeg_native_append_config_if_compiles(d3d12_encoder_feature
        "#include <windows.h>\n#include <d3d12.h>\n#include <d3d12video.h>\nint main(void) { D3D12_FEATURE_VIDEO f = D3D12_FEATURE_VIDEO_ENCODER_CODEC; D3D12_FEATURE_DATA_VIDEO_ENCODER_RESOURCE_REQUIREMENTS r; (void)f; (void)r; return 0; }\n")
    _ffmpeg_native_append_config_if_compiles(d3d12va_av1_headers
        "#include <windows.h>\n#include <d3d12.h>\n#include <d3d12video.h>\nint main(void) { D3D12_VIDEO_ENCODER_CODEC c = D3D12_VIDEO_ENCODER_CODEC_AV1; (void)c; return 0; }\n")
    _ffmpeg_native_append_config_if_compiles(d3d12_intra_refresh
        "#include <windows.h>\n#include <d3d12.h>\n#include <d3d12video.h>\nint main(void) { D3D12_FEATURE_DATA_VIDEO_ENCODER_INTRA_REFRESH_MODE v = { 0 }; (void)v; return 0; }\n")
    _ffmpeg_native_append_config_if_compiles(d3d12va_me_precision_eighth_pixel
        "#include <windows.h>\n#include <d3d12.h>\n#include <d3d12video.h>\nint main(void) { D3D12_VIDEO_ENCODER_MOTION_ESTIMATION_PRECISION_MODE v = D3D12_VIDEO_ENCODER_MOTION_ESTIMATION_PRECISION_MODE_EIGHTH_PIXEL; (void)v; return 0; }\n")
    _ffmpeg_native_append_config_if_compiles(d3d12_motion_estimator
        "#include <windows.h>\n#include <d3d12.h>\n#include <d3d12video.h>\nint main(void) { D3D12_FEATURE_DATA_VIDEO_MOTION_ESTIMATOR v = { 0 }; (void)v; return 0; }\n")
    _ffmpeg_native_append_config_if_compiles(d3d12_video_process_reference_info
        "#include <windows.h>\n#include <d3d12.h>\n#include <d3d12video.h>\nint main(void) { D3D12_FEATURE_DATA_VIDEO_PROCESS_REFERENCE_INFO v = { 0 }; (void)v; return 0; }\n")

    set(_ffmpeg_enabled_have "${_ffmpeg_enabled_have}" PARENT_SCOPE)
    set(FFMPEG_NATIVE_DETECTED_CONFIG_FEATURES "${FFMPEG_NATIVE_DETECTED_CONFIG_FEATURES}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_detect_windows_indevs)
    set(FFMPEG_NATIVE_WINDOWS_DSHOW_INDEV_AVAILABLE FALSE)
    set(FFMPEG_NATIVE_WINDOWS_GDIGRAB_INDEV_AVAILABLE FALSE)
    set(FFMPEG_NATIVE_WINDOWS_VFWCAP_INDEV_AVAILABLE FALSE)

    if(NOT WIN32)
        set(FFMPEG_NATIVE_WINDOWS_DSHOW_INDEV_AVAILABLE "${FFMPEG_NATIVE_WINDOWS_DSHOW_INDEV_AVAILABLE}" PARENT_SCOPE)
        set(FFMPEG_NATIVE_WINDOWS_GDIGRAB_INDEV_AVAILABLE "${FFMPEG_NATIVE_WINDOWS_GDIGRAB_INDEV_AVAILABLE}" PARENT_SCOPE)
        set(FFMPEG_NATIVE_WINDOWS_VFWCAP_INDEV_AVAILABLE "${FFMPEG_NATIVE_WINDOWS_VFWCAP_INDEV_AVAILABLE}" PARENT_SCOPE)
        return()
    endif()

    _ffmpeg_native_check_c_source_links(_ffmpeg_has_dshow dshow_indev
        "#include <windows.h>\n#include <dshow.h>\nint main(void) { IBaseFilter *filter = 0; const GUID *id = &IID_IBaseFilter; (void)filter; return id == 0; }\n"
        strmiids ole32 oleaut32 uuid shlwapi psapi)
    if(_ffmpeg_has_dshow)
        list(APPEND _ffmpeg_enabled_have IBaseFilter)
        set(FFMPEG_NATIVE_WINDOWS_DSHOW_INDEV_AVAILABLE TRUE)
    endif()

    _ffmpeg_native_check_c_source_links(_ffmpeg_has_gdigrab gdigrab_indev
        "#include <windows.h>\nint main(void) { BITMAPINFO bmi = { 0 }; void *bits = 0; HBITMAP bmp = CreateDIBSection(0, &bmi, DIB_RGB_COLORS, &bits, 0, 0); if (bmp) DeleteObject(bmp); return 0; }\n"
        gdi32 user32)
    if(_ffmpeg_has_gdigrab)
        list(APPEND _ffmpeg_enabled_have CreateDIBSection)
        set(FFMPEG_NATIVE_WINDOWS_GDIGRAB_INDEV_AVAILABLE TRUE)
    endif()

    _ffmpeg_native_check_c_source_links(_ffmpeg_has_vfwcap vfwcap_indev
        "#include <windows.h>\n#include <vfw.h>\n#if WM_CAP_DRIVER_CONNECT <= WM_USER\n#error vfw capture macros are unavailable\n#endif\nint main(void) { HWND window = capCreateCaptureWindowA(\"ffmpeg-cmake\", 0, 0, 0, 1, 1, 0, 0); if (window) DestroyWindow(window); return 0; }\n"
        vfw32 user32)
    if(_ffmpeg_has_vfwcap)
        list(APPEND FFMPEG_NATIVE_DETECTED_CONFIG_FEATURES vfw32 vfwcap_defines)
        set(FFMPEG_NATIVE_WINDOWS_VFWCAP_INDEV_AVAILABLE TRUE)
    endif()

    set(_ffmpeg_enabled_have "${_ffmpeg_enabled_have}" PARENT_SCOPE)
    set(FFMPEG_NATIVE_WINDOWS_DSHOW_INDEV_AVAILABLE "${FFMPEG_NATIVE_WINDOWS_DSHOW_INDEV_AVAILABLE}" PARENT_SCOPE)
    set(FFMPEG_NATIVE_WINDOWS_GDIGRAB_INDEV_AVAILABLE "${FFMPEG_NATIVE_WINDOWS_GDIGRAB_INDEV_AVAILABLE}" PARENT_SCOPE)
    set(FFMPEG_NATIVE_WINDOWS_VFWCAP_INDEV_AVAILABLE "${FFMPEG_NATIVE_WINDOWS_VFWCAP_INDEV_AVAILABLE}" PARENT_SCOPE)
    set(FFMPEG_NATIVE_DETECTED_CONFIG_FEATURES "${FFMPEG_NATIVE_DETECTED_CONFIG_FEATURES}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_detect_acceleration_headers)
    _ffmpeg_native_check_c_source(_ffmpeg_has_ffnvcodec ffnvcodec
        "#include <ffnvcodec/nvEncodeAPI.h>\n#include <ffnvcodec/dynlink_cuda.h>\n#include <ffnvcodec/dynlink_cuviddec.h>\n#include <ffnvcodec/dynlink_nvcuvid.h>\nint main(void) { return 0; }\n")
    if(_ffmpeg_has_ffnvcodec)
        list(APPEND FFMPEG_NATIVE_DETECTED_CONFIG_FEATURES ffnvcodec cuda cuvid nvdec nvenc)
        _ffmpeg_native_append_have_if_compiles(NV_ENC_PIC_PARAMS_AV1
            "#include <ffnvcodec/nvEncodeAPI.h>\nint main(void) { NV_ENC_PIC_PARAMS_AV1 v; (void)v; return 0; }\n")
        _ffmpeg_native_append_have_if_compiles(CUVIDAV1PICPARAMS
            "#include <ffnvcodec/dynlink_cuda.h>\n#include <ffnvcodec/dynlink_cuviddec.h>\nint main(void) { CUVIDAV1PICPARAMS v; (void)v; return 0; }\n")
    endif()

    _ffmpeg_native_check_c_source(_ffmpeg_has_amf amf
        "#include <AMF/core/Version.h>\n#if (AMF_VERSION_MAJOR << 48 | AMF_VERSION_MINOR << 32 | AMF_VERSION_RELEASE << 16 | AMF_VERSION_BUILD_NUM) < 0x1000500000000\n#error AMF SDK is too old for this FFmpeg checkout\n#endif\nint main(void) { return 0; }\n")
    if(_ffmpeg_has_amf)
        list(APPEND FFMPEG_NATIVE_DETECTED_CONFIG_FEATURES amf)
    endif()

    _ffmpeg_native_append_have_if_compiles(MFX_CODEC_VP9
        "#include <mfxdefs.h>\n#include <mfxstructures.h>\nint main(void) { int v = MFX_CODEC_VP9; return v == 0; }\n")
    _ffmpeg_native_detect_qsv_backends()

    _ffmpeg_native_check_c_source(_ffmpeg_has_vaapi vaapi
        "#include <va/va.h>\nint main(void) { VADisplay d = 0; (void)d; return 0; }\n")
    if(_ffmpeg_has_vaapi)
        list(APPEND FFMPEG_NATIVE_DETECTED_CONFIG_FEATURES vaapi)
        _ffmpeg_native_append_have_if_compiles(VAPictureParameterBufferHEVC
            "#include <va/va.h>\n#include <va/va_dec_hevc.h>\nint main(void) { VAPictureParameterBufferHEVC v; (void)v; return 0; }\n")
        _ffmpeg_native_append_have_if_compiles(VAPictureParameterBufferVVC
            "#include <va/va.h>\n#include <va/va_dec_vvc.h>\nint main(void) { VAPictureParameterBufferVVC v; (void)v; return 0; }\n")
        _ffmpeg_native_append_have_if_compiles(VADecPictureParameterBufferVP9_bit_depth
            "#include <va/va.h>\nint main(void) { VADecPictureParameterBufferVP9 v; (void)v.bit_depth; return 0; }\n")
        _ffmpeg_native_append_have_if_compiles(VADecPictureParameterBufferAV1_bit_depth_idx
            "#include <va/va.h>\nint main(void) { VADecPictureParameterBufferAV1 v; (void)v.bit_depth_idx; return 0; }\n")
        _ffmpeg_native_append_have_if_compiles(VAProcFilterParameterBufferHDRToneMapping
            "#include <va/va.h>\n#include <va/va_vpp.h>\nint main(void) { VAProcFilterParameterBufferHDRToneMapping v; (void)v; return 0; }\n")
        _ffmpeg_native_append_have_if_compiles(VAProcPipelineCaps_rotation_flags
            "#include <va/va.h>\n#include <va/va_vpp.h>\nint main(void) { VAProcPipelineCaps v; (void)v.rotation_flags; return 0; }\n")
        _ffmpeg_native_append_have_if_compiles(VAProcPipelineCaps_blend_flags
            "#include <va/va.h>\n#include <va/va_vpp.h>\nint main(void) { VAProcPipelineCaps v; (void)v.blend_flags; return 0; }\n")
        _ffmpeg_native_append_have_if_compiles(VAEncPictureParameterBufferHEVC
            "#include <va/va.h>\n#include <va/va_enc_hevc.h>\nint main(void) { VAEncPictureParameterBufferHEVC v; (void)v; return 0; }\n")
        _ffmpeg_native_append_have_if_compiles(VAEncPictureParameterBufferJPEG
            "#include <va/va.h>\n#include <va/va_enc_jpeg.h>\nint main(void) { VAEncPictureParameterBufferJPEG v; (void)v; return 0; }\n")
        _ffmpeg_native_append_have_if_compiles(VAEncPictureParameterBufferVP8
            "#include <va/va.h>\n#include <va/va_enc_vp8.h>\nint main(void) { VAEncPictureParameterBufferVP8 v; (void)v; return 0; }\n")
        _ffmpeg_native_append_have_if_compiles(VAEncPictureParameterBufferVP9
            "#include <va/va.h>\n#include <va/va_enc_vp9.h>\nint main(void) { VAEncPictureParameterBufferVP9 v; (void)v; return 0; }\n")
        _ffmpeg_native_append_have_if_compiles(VAEncPictureParameterBufferAV1
            "#include <va/va.h>\n#include <va/va_enc_av1.h>\nint main(void) { VAEncPictureParameterBufferAV1 v; (void)v; return 0; }\n")
    endif()

    _ffmpeg_native_check_c_source(_ffmpeg_has_vulkan vulkan
        "#include <vulkan/vulkan.h>\nint main(void) { VkInstance v = 0; (void)v; return 0; }\n")
    if(_ffmpeg_has_vulkan)
        list(APPEND FFMPEG_NATIVE_DETECTED_CONFIG_FEATURES vulkan)
        _ffmpeg_native_append_config_if_compiles(vulkan_1_4
            "#include <vulkan/vulkan.h>\nint main(void) {\n#if !defined(VK_VERSION_1_4) && !(defined(VK_VERSION_1_3) && VK_HEADER_VERSION >= 277)\n#error Vulkan headers are too old\n#endif\nreturn 0;\n}\n")
    endif()

    set(_ffmpeg_enabled_have "${_ffmpeg_enabled_have}" PARENT_SCOPE)
    set(FFMPEG_NATIVE_QSV_BACKEND "${FFMPEG_NATIVE_QSV_BACKEND}" PARENT_SCOPE)
    set(FFMPEG_NATIVE_QSV_BACKEND_NOTE "${FFMPEG_NATIVE_QSV_BACKEND_NOTE}" PARENT_SCOPE)
    set(FFMPEG_NATIVE_DETECTED_CONFIG_FEATURES "${FFMPEG_NATIVE_DETECTED_CONFIG_FEATURES}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_detect_base_have)
    set(FFMPEG_NATIVE_DETECTED_CONFIG_FEATURES)
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

    if(NOT WIN32)
        list(APPEND _ffmpeg_enabled_have libdl)
    endif()

    if(FFMPEG_NATIVE_ENABLE_ASM AND CMAKE_SYSTEM_PROCESSOR MATCHES "^(x86_64|AMD64|amd64|x64|x86|i[3-6]86|X86)$")
        _ffmpeg_native_expand_configure_list(_ffmpeg_x86_ext ARCH_EXT_LIST_X86)
        _ffmpeg_native_expand_configure_list(_ffmpeg_x86_simd_ext ARCH_EXT_LIST_X86_SIMD)
        list(APPEND _ffmpeg_enabled_have x86asm ${_ffmpeg_x86_ext})
        foreach(_ffmpeg_x86_feature IN LISTS _ffmpeg_x86_simd_ext)
            list(APPEND _ffmpeg_enabled_have "${_ffmpeg_x86_feature}_external")
        endforeach()
    endif()

    if(WIN32)
        check_symbol_exists(_aligned_malloc "malloc.h" FFMPEG_NATIVE_HAVE_ALIGNED_MALLOC)
        if(FFMPEG_NATIVE_HAVE_ALIGNED_MALLOC)
            list(APPEND _ffmpeg_enabled_have
                aligned_malloc
                malloc_h)
        endif()
        list(APPEND _ffmpeg_enabled_have
            CommandLineToArgvW
            GetModuleHandle
            GetProcessAffinityMask
            GetStdHandle
            GetSystemTimeAsFileTime
            MapViewOfFile
            MemoryBarrier
            SetConsoleTextAttribute
            VirtualAlloc
            closesocket
            dos_paths
            getaddrinfo
            io_h
            libc_msvcrt
            windows_h
            winsock2_h
            socklen_t
            struct_addrinfo
            struct_group_source_req
            struct_ip_mreq_source
            struct_ipv6_mreq
            struct_pollfd
            struct_sockaddr_in6
            struct_sockaddr_storage)
        list(APPEND FFMPEG_NATIVE_DETECTED_CONFIG_FEATURES network)
        _ffmpeg_native_detect_windows_hw_have()
        _ffmpeg_native_detect_windows_indevs()
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
        _ffmpeg_native_append_config_if_compiles(network
            "#include <sys/types.h>\n#include <sys/socket.h>\n#include <netdb.h>\nint main(void) { struct addrinfo *res = 0; return getaddrinfo(\"localhost\", \"80\", 0, &res); }\n")
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
        _ffmpeg_native_append_config_if_compiles(network
            "#include <sys/types.h>\n#include <sys/socket.h>\n#include <netdb.h>\nint main(void) { struct addrinfo *res = 0; return getaddrinfo(\"localhost\", \"80\", 0, &res); }\n")
    endif()

    _ffmpeg_native_append_have_if_compiles(const_nan
        "#include <math.h>\nstruct ffmpeg_cmake_const_nan_probe { double d; };\nstatic const struct ffmpeg_cmake_const_nan_probe probe[] = { { NAN } };\nint main(void) { return probe[0].d == 0.0; }\n")

    if(NOT FFMPEG_DISABLE_AUTODETECT)
        _ffmpeg_native_detect_acceleration_headers()
        _ffmpeg_native_detect_external_libraries()
    endif()

    list(REMOVE_DUPLICATES _ffmpeg_enabled_have)
    list(REMOVE_DUPLICATES FFMPEG_NATIVE_DETECTED_CONFIG_FEATURES)
    set(_ffmpeg_enabled_have "${_ffmpeg_enabled_have}" PARENT_SCOPE)
    set(FFMPEG_NATIVE_QSV_BACKEND "${FFMPEG_NATIVE_QSV_BACKEND}" PARENT_SCOPE)
    set(FFMPEG_NATIVE_QSV_BACKEND_NOTE "${FFMPEG_NATIVE_QSV_BACKEND_NOTE}" PARENT_SCOPE)
    set(FFMPEG_NATIVE_WINDOWS_DSHOW_INDEV_AVAILABLE "${FFMPEG_NATIVE_WINDOWS_DSHOW_INDEV_AVAILABLE}" PARENT_SCOPE)
    set(FFMPEG_NATIVE_WINDOWS_GDIGRAB_INDEV_AVAILABLE "${FFMPEG_NATIVE_WINDOWS_GDIGRAB_INDEV_AVAILABLE}" PARENT_SCOPE)
    set(FFMPEG_NATIVE_WINDOWS_VFWCAP_INDEV_AVAILABLE "${FFMPEG_NATIVE_WINDOWS_VFWCAP_INDEV_AVAILABLE}" PARENT_SCOPE)
    set(FFMPEG_NATIVE_DETECTED_CONFIG_FEATURES "${FFMPEG_NATIVE_DETECTED_CONFIG_FEATURES}" PARENT_SCOPE)
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
