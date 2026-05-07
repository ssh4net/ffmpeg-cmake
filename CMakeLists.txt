cmake_minimum_required(VERSION 3.24)

cmake_policy(SET CMP0091 NEW)
if(POLICY CMP0207)
    cmake_policy(SET CMP0207 NEW)
endif()

project(ffmpeg-cmake VERSION 0.1.0 LANGUAGES C)

include(GNUInstallDirs)
include(CMakePackageConfigHelpers)

list(PREPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

option(FFMPEG_BUILD_FROM_SOURCE "Build FFmpeg from source and expose the resulting CMake targets." ON)
option(FFMPEG_FIND_INSTALLED "Import an existing FFmpeg installation from FFmpeg_ROOT or CMAKE_PREFIX_PATH." OFF)
option(FFMPEG_BUILD_SMOKE_TEST "Build a small link test executable against FFmpeg::FFmpeg." OFF)
option(FFMPEG_ALLOW_SHELL_BACKEND_ON_WINDOWS "Allow FFmpeg's POSIX shell configure backend on Windows. Keep OFF for native MSVC/clang-cl builds." OFF)

set(FFMPEG_BUILD_BACKEND "AUTO" CACHE STRING "Backend used to build FFmpeg from source. AUTO chooses native CMake on Windows and official configure elsewhere.")
set_property(CACHE FFMPEG_BUILD_BACKEND PROPERTY STRINGS AUTO OFFICIAL_CONFIGURE NATIVE_CMAKE)

set(FFMPEG_IMPORT_COMPONENTS
    avutil swresample swscale avcodec avformat avfilter avdevice
    CACHE STRING "FFmpeg libraries to import or build and expose as FFmpeg::<component> targets.")
set(FFmpeg_ROOT "" CACHE PATH "Optional installed FFmpeg prefix. Used when importing an existing FFmpeg package.")
option(FFmpeg_USE_STATIC_LIBS "Import installed FFmpeg using static link flags, including private dependency libraries." OFF)

include(FFmpegProjectDefaults)
include(FFmpegPkgConfigTargets)
include(FFmpegReport)
include(FFmpegSource)
include(FFmpegNvCodecHeaders)
include(FFmpegAmfHeaders)
include(FFmpegOptions)
include(FFmpegGuiOptions)

ffmpeg_enable_ide_folders()
ffmpeg_cache_common_cmake_options()
ffmpeg_sync_gui_options()
ffmpeg_apply_msvc_runtime_default()
ffmpeg_resolve_assembler_tools()

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

    ffmpeg_prepare_source()
    ffmpeg_prepare_nvcodec_headers()
    ffmpeg_prepare_amf_headers()

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

ffmpeg_print_report()
