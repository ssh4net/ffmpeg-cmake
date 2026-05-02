include_guard(GLOBAL)

include(ExternalProject)
include(GNUInstallDirs)
include(CMakePackageConfigHelpers)
include(ProcessorCount)

function(_ffmpeg_collect_dependency_environment _out)
    if(WIN32)
        set(_ffmpeg_path_sep ";")
    else()
        set(_ffmpeg_path_sep ":")
    endif()

    set(_ffmpeg_pc_paths)
    set(_ffmpeg_bin_paths)

    if(FFMPEG_NV_CODEC_HEADERS_PKG_CONFIG_DIR)
        list(APPEND _ffmpeg_pc_paths "${FFMPEG_NV_CODEC_HEADERS_PKG_CONFIG_DIR}")
    endif()

    foreach(_ffmpeg_prefix IN LISTS CMAKE_PREFIX_PATH)
        if(_ffmpeg_prefix STREQUAL "")
            continue()
        endif()
        foreach(_ffmpeg_suffix IN ITEMS "${CMAKE_INSTALL_LIBDIR}/pkgconfig" lib/pkgconfig lib64/pkgconfig share/pkgconfig)
            if(IS_DIRECTORY "${_ffmpeg_prefix}/${_ffmpeg_suffix}")
                list(APPEND _ffmpeg_pc_paths "${_ffmpeg_prefix}/${_ffmpeg_suffix}")
            endif()
        endforeach()
        if(IS_DIRECTORY "${_ffmpeg_prefix}/bin")
            list(APPEND _ffmpeg_bin_paths "${_ffmpeg_prefix}/bin")
        endif()
    endforeach()

    list(REMOVE_DUPLICATES _ffmpeg_pc_paths)
    list(REMOVE_DUPLICATES _ffmpeg_bin_paths)

    set(_ffmpeg_env)
    if(_ffmpeg_pc_paths)
        string(JOIN "${_ffmpeg_path_sep}" _ffmpeg_pc_path ${_ffmpeg_pc_paths})
        if(DEFINED ENV{PKG_CONFIG_PATH} AND NOT "$ENV{PKG_CONFIG_PATH}" STREQUAL "")
            string(APPEND _ffmpeg_pc_path "${_ffmpeg_path_sep}$ENV{PKG_CONFIG_PATH}")
        endif()
        list(APPEND _ffmpeg_env "PKG_CONFIG_PATH=${_ffmpeg_pc_path}")
    endif()

    if(_ffmpeg_bin_paths)
        string(JOIN "${_ffmpeg_path_sep}" _ffmpeg_path ${_ffmpeg_bin_paths})
        if(DEFINED ENV{PATH} AND NOT "$ENV{PATH}" STREQUAL "")
            string(APPEND _ffmpeg_path "${_ffmpeg_path_sep}$ENV{PATH}")
        endif()
        list(APPEND _ffmpeg_env "PATH=${_ffmpeg_path}")
    endif()

    set(${_out} "${_ffmpeg_env}" PARENT_SCOPE)
endfunction()

function(ffmpeg_add_external_project)
    if(NOT EXISTS "${FFMPEG_SOURCE_DIR}/configure")
        message(FATAL_ERROR "FFMPEG_SOURCE_DIR does not contain FFmpeg configure: ${FFMPEG_SOURCE_DIR}")
    endif()

    if(NOT FFMPEG_MAKE_PROGRAM)
        find_program(_ffmpeg_make_program NAMES gmake make nmake)
        if(NOT _ffmpeg_make_program)
            message(FATAL_ERROR "Could not find make/gmake/nmake for the FFmpeg external build")
        endif()
        set(FFMPEG_MAKE_PROGRAM "${_ffmpeg_make_program}" CACHE FILEPATH "Make/nmake executable used by the official configure backend." FORCE)
    endif()
    ProcessorCount(_ffmpeg_processor_count)
    if(_ffmpeg_processor_count EQUAL 0)
        set(_ffmpeg_processor_count "")
    endif()
    set(FFMPEG_MAKE_JOBS "${_ffmpeg_processor_count}" CACHE STRING "Parallel job count for the official configure backend build step.")

    if(NOT FFMPEG_CONFIGURE_SHELL)
        find_program(_ffmpeg_shell NAMES bash sh)
        if(_ffmpeg_shell)
            set(FFMPEG_CONFIGURE_SHELL "${_ffmpeg_shell}" CACHE FILEPATH "Shell executable used only by the official configure backend. Not needed for native Windows builds." FORCE)
        endif()
    endif()

    ffmpeg_compose_configure_options(_ffmpeg_configure_args)
    _ffmpeg_collect_dependency_environment(_ffmpeg_env)
    set(FFMPEG_OFFICIAL_CONFIGURE_OPTIONS "${_ffmpeg_configure_args}" PARENT_SCOPE)
    set(FFMPEG_OFFICIAL_ENVIRONMENT "${_ffmpeg_env}" PARENT_SCOPE)

    if(FFMPEG_CONFIGURE_SHELL)
        set(_ffmpeg_configure_command "${FFMPEG_CONFIGURE_SHELL}" "${FFMPEG_SOURCE_DIR}/configure")
    else()
        set(_ffmpeg_configure_command "${FFMPEG_SOURCE_DIR}/configure")
    endif()

    set(_ffmpeg_make_args)
    if(FFMPEG_MAKE_JOBS)
        list(APPEND _ffmpeg_make_args "-j${FFMPEG_MAKE_JOBS}")
    endif()

    set(_ffmpeg_env_command)
    if(_ffmpeg_env)
        set(_ffmpeg_env_command "${CMAKE_COMMAND}" -E env ${_ffmpeg_env})
    endif()

    ExternalProject_Add(ffmpeg_external
        SOURCE_DIR "${FFMPEG_SOURCE_DIR}"
        BINARY_DIR "${FFMPEG_BINARY_DIR}"
        PREFIX "${CMAKE_CURRENT_BINARY_DIR}/ffmpeg-external"
        CONFIGURE_COMMAND ${_ffmpeg_env_command} ${_ffmpeg_configure_command} ${_ffmpeg_configure_args}
        BUILD_COMMAND ${_ffmpeg_env_command} "${FFMPEG_MAKE_PROGRAM}" ${_ffmpeg_make_args}
        INSTALL_COMMAND ${_ffmpeg_env_command} "${FFMPEG_MAKE_PROGRAM}" install
        BUILD_IN_SOURCE OFF
        STEP_TARGETS configure build install
        USES_TERMINAL_CONFIGURE TRUE
        USES_TERMINAL_BUILD TRUE
        USES_TERMINAL_INSTALL TRUE)

    add_custom_target(ffmpeg DEPENDS ffmpeg_external)
    foreach(_ffmpeg_external_target IN ITEMS
            ffmpeg
            ffmpeg_external
            ffmpeg_external-configure
            ffmpeg_external-build
            ffmpeg_external-install)
        ffmpeg_set_target_folder("${_ffmpeg_external_target}" "FFmpeg/External")
    endforeach()

    set(_ffmpeg_package_dir "${CMAKE_CURRENT_BINARY_DIR}/ffmpeg-package")
    configure_package_config_file(
        "${PROJECT_SOURCE_DIR}/cmake/FFmpegConfig.cmake.in"
        "${_ffmpeg_package_dir}/FFmpegConfig.cmake"
        INSTALL_DESTINATION "${CMAKE_INSTALL_LIBDIR}/cmake/FFmpeg")
    write_basic_package_version_file(
        "${_ffmpeg_package_dir}/FFmpegConfigVersion.cmake"
        VERSION "${PROJECT_VERSION}"
        COMPATIBILITY SameMajorVersion)

    set(_ffmpeg_package_install_dir "${FFMPEG_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBDIR}/cmake/FFmpeg")
    add_custom_target(ffmpeg_cmake_package ALL
        COMMAND "${CMAKE_COMMAND}" -E make_directory "${_ffmpeg_package_install_dir}"
        COMMAND "${CMAKE_COMMAND}" -E copy_if_different
                "${_ffmpeg_package_dir}/FFmpegConfig.cmake"
                "${_ffmpeg_package_dir}/FFmpegConfigVersion.cmake"
                "${PROJECT_SOURCE_DIR}/cmake/FFmpegPkgConfigTargets.cmake"
                "${_ffmpeg_package_install_dir}"
        DEPENDS ffmpeg_external
        COMMENT "Installing FFmpeg CMake package files")
    ffmpeg_set_target_folder(ffmpeg_cmake_package "FFmpeg/Package")
endfunction()
