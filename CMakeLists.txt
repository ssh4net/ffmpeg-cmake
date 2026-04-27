cmake_minimum_required(VERSION 3.24)

project(ffmpeg-cmake VERSION 0.1.0 LANGUAGES C)

include(GNUInstallDirs)
include(CMakePackageConfigHelpers)

list(PREPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

option(FFMPEG_BUILD_FROM_SOURCE "Build the bundled FFmpeg source tree with FFmpeg's official configure script" ON)
option(FFMPEG_FIND_INSTALLED "Import an already installed FFmpeg with pkg-config" OFF)
option(FFMPEG_BUILD_SMOKE_TEST "Build a small executable that links to FFmpeg::FFmpeg" OFF)
option(FFMPEG_ALLOW_SHELL_BACKEND_ON_WINDOWS "Allow the POSIX-shell official configure backend on Windows" OFF)

set(FFMPEG_BUILD_BACKEND "AUTO" CACHE STRING "Bundled FFmpeg build backend: AUTO, OFFICIAL_CONFIGURE, or NATIVE_CMAKE")
set_property(CACHE FFMPEG_BUILD_BACKEND PROPERTY STRINGS AUTO OFFICIAL_CONFIGURE NATIVE_CMAKE)

set(FFMPEG_IMPORT_COMPONENTS
    avutil swresample swscale avcodec avformat avfilter avdevice
    CACHE STRING "FFmpeg library components to import or expose as CMake targets")
set(FFmpeg_ROOT "" CACHE PATH "Optional FFmpeg installation root used by FindFFmpeg/pkg-config")
option(FFmpeg_USE_STATIC_LIBS "Use pkg-config --static when importing FFmpeg targets" OFF)

include(FFmpegPkgConfigTargets)

if(FFMPEG_FIND_INSTALLED)
    set(_ffmpeg_import_required)
    if(FFMPEG_BUILD_SMOKE_TEST)
        list(APPEND _ffmpeg_import_required REQUIRED)
    endif()

    set(_ffmpeg_import_static)
    if(FFmpeg_USE_STATIC_LIBS)
        list(APPEND _ffmpeg_import_static STATIC)
    endif()

    ffmpeg_pkg_config_import_targets(
        GLOBAL
        ${_ffmpeg_import_required}
        ${_ffmpeg_import_static}
        NAMESPACE FFmpeg::
        ROOT "${FFmpeg_ROOT}"
        COMPONENTS ${FFMPEG_IMPORT_COMPONENTS})
endif()

if(FFMPEG_BUILD_FROM_SOURCE)
    string(TOUPPER "${FFMPEG_BUILD_BACKEND}" FFMPEG_BUILD_BACKEND)
    if(FFMPEG_BUILD_BACKEND STREQUAL "AUTO")
        if(WIN32)
            set(FFMPEG_EFFECTIVE_BUILD_BACKEND NATIVE_CMAKE)
        else()
            set(FFMPEG_EFFECTIVE_BUILD_BACKEND OFFICIAL_CONFIGURE)
        endif()
    else()
        set(FFMPEG_EFFECTIVE_BUILD_BACKEND "${FFMPEG_BUILD_BACKEND}")
    endif()
    set(FFMPEG_EFFECTIVE_BUILD_BACKEND "${FFMPEG_EFFECTIVE_BUILD_BACKEND}" CACHE INTERNAL "Resolved bundled FFmpeg build backend")

    include(FFmpegOptions)
    if(FFMPEG_EFFECTIVE_BUILD_BACKEND STREQUAL "OFFICIAL_CONFIGURE")
        if(WIN32 AND NOT FFMPEG_ALLOW_SHELL_BACKEND_ON_WINDOWS)
            message(FATAL_ERROR "The OFFICIAL_CONFIGURE backend requires FFmpeg's POSIX configure/make flow. Use -DFFMPEG_BUILD_BACKEND=NATIVE_CMAKE for native Windows generators, or set FFMPEG_ALLOW_SHELL_BACKEND_ON_WINDOWS=ON explicitly.")
        endif()
        include(FFmpegExternalProject)
        ffmpeg_add_external_project()
    elseif(FFMPEG_EFFECTIVE_BUILD_BACKEND STREQUAL "NATIVE_CMAKE")
        include(FFmpegNativeProject)
        ffmpeg_add_native_project()
    else()
        message(FATAL_ERROR "Unknown FFMPEG_BUILD_BACKEND='${FFMPEG_BUILD_BACKEND}'. Expected AUTO, OFFICIAL_CONFIGURE, or NATIVE_CMAKE.")
    endif()
endif()

set(_ffmpeg_package_dir "${CMAKE_CURRENT_BINARY_DIR}/cmake/package")
configure_package_config_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/cmake/FFmpegConfig.cmake.in"
    "${_ffmpeg_package_dir}/FFmpegConfig.cmake"
    INSTALL_DESTINATION "${CMAKE_INSTALL_LIBDIR}/cmake/FFmpeg")
write_basic_package_version_file(
    "${_ffmpeg_package_dir}/FFmpegConfigVersion.cmake"
    VERSION "${PROJECT_VERSION}"
    COMPATIBILITY SameMajorVersion)

install(FILES
    "${_ffmpeg_package_dir}/FFmpegConfig.cmake"
    "${_ffmpeg_package_dir}/FFmpegConfigVersion.cmake"
    "${CMAKE_CURRENT_SOURCE_DIR}/cmake/FFmpegPkgConfigTargets.cmake"
    DESTINATION "${CMAKE_INSTALL_LIBDIR}/cmake/FFmpeg")
install(FILES
    "${CMAKE_CURRENT_SOURCE_DIR}/cmake/FindFFmpeg.cmake"
    DESTINATION "${CMAKE_INSTALL_LIBDIR}/cmake/FFmpeg")

if(FFMPEG_BUILD_SMOKE_TEST)
    if(NOT TARGET FFmpeg::FFmpeg)
        message(FATAL_ERROR "FFMPEG_BUILD_SMOKE_TEST requires imported FFmpeg targets. Enable FFMPEG_FIND_INSTALLED or call find_package(FFmpeg) before adding the smoke target.")
    endif()
    enable_testing()
    add_subdirectory(examples/smoke)
endif()
