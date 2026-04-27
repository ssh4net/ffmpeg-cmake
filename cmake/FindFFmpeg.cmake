include(FindPackageHandleStandardArgs)
include("${CMAKE_CURRENT_LIST_DIR}/FFmpegPkgConfigTargets.cmake")

set(_FFmpeg_components ${FFmpeg_FIND_COMPONENTS})
if(NOT _FFmpeg_components)
    set(_FFmpeg_components avutil swresample swscale avcodec avformat avfilter avdevice)
endif()

set(_FFmpeg_required)
if(FFmpeg_FIND_REQUIRED)
    list(APPEND _FFmpeg_required REQUIRED)
endif()

set(_FFmpeg_static)
if(FFmpeg_USE_STATIC_LIBS OR FFMPEG_USE_STATIC_LIBS)
    list(APPEND _FFmpeg_static STATIC)
endif()

ffmpeg_pkg_config_import_targets(
    GLOBAL
    ${_FFmpeg_required}
    ${_FFmpeg_static}
    NAMESPACE FFmpeg::
    ROOT "${FFmpeg_ROOT}"
    COMPONENTS ${_FFmpeg_components})

find_package_handle_standard_args(FFmpeg
    REQUIRED_VARS FFmpeg_LIBRARIES FFmpeg_INCLUDE_DIRS
    VERSION_VAR FFmpeg_VERSION
    HANDLE_COMPONENTS
    REASON_FAILURE_MESSAGE "${FFmpeg_NOT_FOUND_MESSAGE}")

