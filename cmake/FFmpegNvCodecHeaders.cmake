include_guard(GLOBAL)

set(FFMPEG_NV_CODEC_HEADERS_DIR "${PROJECT_SOURCE_DIR}/nv-codec-headers" CACHE PATH "Path to nv-codec-headers checkout, install prefix, or include directory. Leave as the in-tree path for managed clone/update.")
set(FFMPEG_NV_CODEC_HEADERS_GIT_REPOSITORY "https://git.videolan.org/git/ffmpeg/nv-codec-headers.git" CACHE STRING "Git URL used when cloning nv-codec-headers into this checkout.")
set(FFMPEG_NV_CODEC_HEADERS_GIT_REF "" CACHE STRING "Optional nv-codec-headers branch, tag, or commit to check out after clone or update.")
set(FFMPEG_NV_CODEC_HEADERS_VERSION "" CACHE STRING "Version written to the generated ffnvcodec pkg-config file when nv-codec-headers is used from a source/include path.")

option(FFMPEG_NV_CODEC_HEADERS_GIT_CLONE "Clone nv-codec-headers into FFMPEG_NV_CODEC_HEADERS_DIR when the headers are missing." OFF)
option(FFMPEG_NV_CODEC_HEADERS_GIT_UPDATE "Fetch and update the managed in-tree nv-codec-headers checkout during configure. Refuses dirty trees." OFF)
option(FFMPEG_NV_CODEC_HEADERS_GIT_DETACHED_HEAD "Check out FFMPEG_NV_CODEC_HEADERS_GIT_REF as a detached HEAD, useful for exact commits or reproducible builds." OFF)

function(_ffmpeg_nvcodec_absolute _out _path)
    get_filename_component(_ffmpeg_path "${_path}" ABSOLUTE BASE_DIR "${PROJECT_SOURCE_DIR}")
    file(TO_CMAKE_PATH "${_ffmpeg_path}" _ffmpeg_path)
    string(REGEX REPLACE "/+$" "" _ffmpeg_path "${_ffmpeg_path}")
    set(${_out} "${_ffmpeg_path}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_nvcodec_is_in_project _out _path)
    _ffmpeg_nvcodec_absolute(_ffmpeg_path "${_path}")
    _ffmpeg_nvcodec_absolute(_ffmpeg_project "${PROJECT_SOURCE_DIR}")

    string(LENGTH "${_ffmpeg_path}" _ffmpeg_path_len)
    string(LENGTH "${_ffmpeg_project}" _ffmpeg_project_len)
    if(_ffmpeg_path_len LESS _ffmpeg_project_len)
        set(${_out} FALSE PARENT_SCOPE)
        return()
    endif()

    string(SUBSTRING "${_ffmpeg_path}" 0 "${_ffmpeg_project_len}" _ffmpeg_prefix)
    if(NOT _ffmpeg_prefix STREQUAL _ffmpeg_project)
        set(${_out} FALSE PARENT_SCOPE)
        return()
    endif()

    if(_ffmpeg_path_len EQUAL _ffmpeg_project_len)
        set(${_out} TRUE PARENT_SCOPE)
        return()
    endif()

    string(SUBSTRING "${_ffmpeg_path}" "${_ffmpeg_project_len}" 1 _ffmpeg_next)
    if(_ffmpeg_next STREQUAL "/")
        set(${_out} TRUE PARENT_SCOPE)
    else()
        set(${_out} FALSE PARENT_SCOPE)
    endif()
endfunction()

function(_ffmpeg_nvcodec_require_in_project _operation)
    _ffmpeg_nvcodec_is_in_project(_ffmpeg_in_project "${FFMPEG_NV_CODEC_HEADERS_DIR}")
    if(NOT _ffmpeg_in_project)
        message(FATAL_ERROR "${_operation} is allowed only for nv-codec-headers inside the ffmpeg-cmake checkout: ${FFMPEG_NV_CODEC_HEADERS_DIR}")
    endif()

    _ffmpeg_nvcodec_absolute(_ffmpeg_project "${PROJECT_SOURCE_DIR}")
    if("${FFMPEG_NV_CODEC_HEADERS_DIR}" STREQUAL "${_ffmpeg_project}")
        message(FATAL_ERROR "${_operation} cannot use the ffmpeg-cmake repository root as FFMPEG_NV_CODEC_HEADERS_DIR")
    endif()
endfunction()

function(_ffmpeg_nvcodec_find_git)
    if(NOT GIT_EXECUTABLE)
        find_package(Git QUIET)
    endif()
    if(NOT GIT_EXECUTABLE)
        message(FATAL_ERROR "Git executable was not found. Install git or disable nv-codec-headers git operations.")
    endif()
endfunction()

function(_ffmpeg_nvcodec_git _workdir)
    execute_process(
        COMMAND "${GIT_EXECUTABLE}" ${ARGN}
        WORKING_DIRECTORY "${_workdir}"
        RESULT_VARIABLE _ffmpeg_result
        OUTPUT_VARIABLE _ffmpeg_output
        ERROR_VARIABLE _ffmpeg_error
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_STRIP_TRAILING_WHITESPACE)
    if(NOT _ffmpeg_result EQUAL 0)
        string(JOIN " " _ffmpeg_git_args ${ARGN})
        message(FATAL_ERROR "Git command failed in ${_workdir}: git ${_ffmpeg_git_args}\n${_ffmpeg_error}\n${_ffmpeg_output}")
    endif()
endfunction()

function(_ffmpeg_nvcodec_git_ref_exists _out _workdir _ref)
    execute_process(
        COMMAND "${GIT_EXECUTABLE}" rev-parse --verify --quiet "refs/remotes/origin/${_ref}"
        WORKING_DIRECTORY "${_workdir}"
        RESULT_VARIABLE _ffmpeg_result
        OUTPUT_QUIET
        ERROR_QUIET)
    if(_ffmpeg_result EQUAL 0)
        set(${_out} TRUE PARENT_SCOPE)
    else()
        set(${_out} FALSE PARENT_SCOPE)
    endif()
endfunction()

function(_ffmpeg_nvcodec_checkout_ref _workdir _ref)
    if(_ref STREQUAL "")
        return()
    endif()

    _ffmpeg_nvcodec_git_ref_exists(_ffmpeg_has_remote_ref "${_workdir}" "${_ref}")
    if(_ffmpeg_has_remote_ref)
        set(_ffmpeg_checkout_ref "origin/${_ref}")
    else()
        set(_ffmpeg_checkout_ref "${_ref}")
    endif()

    if(FFMPEG_NV_CODEC_HEADERS_GIT_DETACHED_HEAD OR _ref MATCHES "^[0-9a-fA-F]{7,40}$")
        _ffmpeg_nvcodec_git("${_workdir}" checkout --detach "${_ffmpeg_checkout_ref}")
    elseif(_ffmpeg_has_remote_ref)
        _ffmpeg_nvcodec_git("${_workdir}" checkout -B "${_ref}" "${_ffmpeg_checkout_ref}")
    else()
        _ffmpeg_nvcodec_git("${_workdir}" checkout "${_ffmpeg_checkout_ref}")
    endif()
endfunction()

function(_ffmpeg_nvcodec_header_dir_from_root _out _root)
    set(_ffmpeg_candidates
        "${_root}/include"
        "${_root}")
    foreach(_ffmpeg_candidate IN LISTS _ffmpeg_candidates)
        if(EXISTS "${_ffmpeg_candidate}/ffnvcodec/nvEncodeAPI.h" AND
           EXISTS "${_ffmpeg_candidate}/ffnvcodec/dynlink_cuda.h" AND
           EXISTS "${_ffmpeg_candidate}/ffnvcodec/dynlink_cuviddec.h" AND
           EXISTS "${_ffmpeg_candidate}/ffnvcodec/dynlink_nvcuvid.h")
            set(${_out} "${_ffmpeg_candidate}" PARENT_SCOPE)
            return()
        endif()
    endforeach()
    set(${_out} "" PARENT_SCOPE)
endfunction()

function(_ffmpeg_nvcodec_prefix_include_dirs _out)
    set(_ffmpeg_dirs)
    foreach(_ffmpeg_prefix IN LISTS CMAKE_PREFIX_PATH)
        if(_ffmpeg_prefix STREQUAL "")
            continue()
        endif()
        foreach(_ffmpeg_suffix IN ITEMS include)
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

function(_ffmpeg_nvcodec_find_system_header_dir _out)
    _ffmpeg_nvcodec_prefix_include_dirs(_ffmpeg_include_dirs)
    foreach(_ffmpeg_include_dir IN LISTS _ffmpeg_include_dirs)
        _ffmpeg_nvcodec_header_dir_from_root(_ffmpeg_header_dir "${_ffmpeg_include_dir}")
        if(_ffmpeg_header_dir)
            set(${_out} "${_ffmpeg_header_dir}" PARENT_SCOPE)
            return()
        endif()
    endforeach()
    set(${_out} "" PARENT_SCOPE)
endfunction()

function(_ffmpeg_nvcodec_clone)
    _ffmpeg_nvcodec_require_in_project("Cloning nv-codec-headers")
    _ffmpeg_nvcodec_find_git()

    if(EXISTS "${FFMPEG_NV_CODEC_HEADERS_DIR}")
        file(GLOB _ffmpeg_entries
            LIST_DIRECTORIES TRUE
            "${FFMPEG_NV_CODEC_HEADERS_DIR}/*"
            "${FFMPEG_NV_CODEC_HEADERS_DIR}/.[!.]*")
        if(_ffmpeg_entries)
            message(FATAL_ERROR "Cannot clone nv-codec-headers into a non-empty directory that does not contain nv-codec-headers: ${FFMPEG_NV_CODEC_HEADERS_DIR}")
        endif()
    endif()

    get_filename_component(_ffmpeg_parent "${FFMPEG_NV_CODEC_HEADERS_DIR}" DIRECTORY)
    file(MAKE_DIRECTORY "${_ffmpeg_parent}")

    message(STATUS "Cloning nv-codec-headers from ${FFMPEG_NV_CODEC_HEADERS_GIT_REPOSITORY} into ${FFMPEG_NV_CODEC_HEADERS_DIR}")
    execute_process(
        COMMAND "${GIT_EXECUTABLE}" clone "${FFMPEG_NV_CODEC_HEADERS_GIT_REPOSITORY}" "${FFMPEG_NV_CODEC_HEADERS_DIR}"
        WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
        RESULT_VARIABLE _ffmpeg_result
        OUTPUT_VARIABLE _ffmpeg_output
        ERROR_VARIABLE _ffmpeg_error
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_STRIP_TRAILING_WHITESPACE)
    if(NOT _ffmpeg_result EQUAL 0)
        message(FATAL_ERROR "Failed to clone nv-codec-headers from ${FFMPEG_NV_CODEC_HEADERS_GIT_REPOSITORY}\n${_ffmpeg_error}\n${_ffmpeg_output}")
    endif()

    if(FFMPEG_NV_CODEC_HEADERS_GIT_REF)
        _ffmpeg_nvcodec_checkout_ref("${FFMPEG_NV_CODEC_HEADERS_DIR}" "${FFMPEG_NV_CODEC_HEADERS_GIT_REF}")
    endif()
endfunction()

function(_ffmpeg_nvcodec_update)
    _ffmpeg_nvcodec_require_in_project("Updating nv-codec-headers")
    _ffmpeg_nvcodec_find_git()

    if(NOT EXISTS "${FFMPEG_NV_CODEC_HEADERS_DIR}/.git")
        message(FATAL_ERROR "FFMPEG_NV_CODEC_HEADERS_GIT_UPDATE requires an in-tree git checkout: ${FFMPEG_NV_CODEC_HEADERS_DIR}")
    endif()

    execute_process(
        COMMAND "${GIT_EXECUTABLE}" status --porcelain
        WORKING_DIRECTORY "${FFMPEG_NV_CODEC_HEADERS_DIR}"
        RESULT_VARIABLE _ffmpeg_status_result
        OUTPUT_VARIABLE _ffmpeg_status
        ERROR_VARIABLE _ffmpeg_status_error
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_STRIP_TRAILING_WHITESPACE)
    if(NOT _ffmpeg_status_result EQUAL 0)
        message(FATAL_ERROR "Could not inspect nv-codec-headers git status: ${_ffmpeg_status_error}")
    endif()
    if(_ffmpeg_status)
        message(FATAL_ERROR "Refusing to update dirty nv-codec-headers checkout: ${FFMPEG_NV_CODEC_HEADERS_DIR}")
    endif()

    message(STATUS "Updating in-tree nv-codec-headers checkout at ${FFMPEG_NV_CODEC_HEADERS_DIR}")
    _ffmpeg_nvcodec_git("${FFMPEG_NV_CODEC_HEADERS_DIR}" fetch --tags origin)
    if(FFMPEG_NV_CODEC_HEADERS_GIT_REF)
        _ffmpeg_nvcodec_checkout_ref("${FFMPEG_NV_CODEC_HEADERS_DIR}" "${FFMPEG_NV_CODEC_HEADERS_GIT_REF}")
    else()
        _ffmpeg_nvcodec_git("${FFMPEG_NV_CODEC_HEADERS_DIR}" pull --ff-only)
    endif()
endfunction()

function(_ffmpeg_nvcodec_parse_version _out)
    if(NOT FFMPEG_NV_CODEC_HEADERS_VERSION STREQUAL "")
        set(${_out} "${FFMPEG_NV_CODEC_HEADERS_VERSION}" PARENT_SCOPE)
        return()
    endif()

    set(_ffmpeg_version)
    if(FFMPEG_NV_CODEC_HEADERS_DIR AND EXISTS "${FFMPEG_NV_CODEC_HEADERS_DIR}/Makefile")
        file(STRINGS "${FFMPEG_NV_CODEC_HEADERS_DIR}/Makefile" _ffmpeg_makefile_lines REGEX "^[ \t]*VERSION[ \t]*=")
        foreach(_ffmpeg_line IN LISTS _ffmpeg_makefile_lines)
            if(_ffmpeg_line MATCHES "^[ \t]*VERSION[ \t]*=[ \t]*([^ \t#]+)")
                set(_ffmpeg_version "${CMAKE_MATCH_1}")
                break()
            endif()
        endforeach()
    endif()

    if(NOT _ffmpeg_version AND FFMPEG_NV_CODEC_HEADERS_DIR)
        foreach(_ffmpeg_pc IN ITEMS
                "${FFMPEG_NV_CODEC_HEADERS_DIR}/lib/pkgconfig/ffnvcodec.pc"
                "${FFMPEG_NV_CODEC_HEADERS_DIR}/lib64/pkgconfig/ffnvcodec.pc"
                "${FFMPEG_NV_CODEC_HEADERS_DIR}/share/pkgconfig/ffnvcodec.pc")
            if(EXISTS "${_ffmpeg_pc}")
                file(STRINGS "${_ffmpeg_pc}" _ffmpeg_pc_lines REGEX "^[ \t]*Version[ \t]*:")
                foreach(_ffmpeg_line IN LISTS _ffmpeg_pc_lines)
                    if(_ffmpeg_line MATCHES "^[ \t]*Version[ \t]*:[ \t]*(.+)")
                        set(_ffmpeg_version "${CMAKE_MATCH_1}")
                        break()
                    endif()
                endforeach()
            endif()
            if(_ffmpeg_version)
                break()
            endif()
        endforeach()
    endif()

    if(NOT _ffmpeg_version)
        set(_ffmpeg_version "13.0.19.0")
    endif()

    set(FFMPEG_NV_CODEC_HEADERS_VERSION "${_ffmpeg_version}" CACHE STRING "Version written to the generated ffnvcodec pkg-config file when nv-codec-headers is used from a source/include path." FORCE)
    set(${_out} "${_ffmpeg_version}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_nvcodec_generate_pkg_config _include_dir _version)
    set(_ffmpeg_pc_dir "${PROJECT_BINARY_DIR}/nv-codec-headers/pkgconfig")
    file(MAKE_DIRECTORY "${_ffmpeg_pc_dir}")
    file(TO_CMAKE_PATH "${_include_dir}" _ffmpeg_include_dir)
    set(_ffmpeg_pc "${_ffmpeg_pc_dir}/ffnvcodec.pc")
    file(WRITE "${_ffmpeg_pc}"
"prefix=${_ffmpeg_include_dir}/..
includedir=${_ffmpeg_include_dir}

Name: ffnvcodec
Description: FFmpeg NVIDIA codec API headers
Version: ${_version}
Cflags: -I\${includedir}
")
    set(FFMPEG_NV_CODEC_HEADERS_PKG_CONFIG_DIR "${_ffmpeg_pc_dir}" CACHE INTERNAL "Generated ffnvcodec pkg-config directory" FORCE)
endfunction()

function(ffmpeg_prepare_nvcodec_headers)
    set(FFMPEG_NV_CODEC_HEADERS_FOUND FALSE CACHE INTERNAL "Whether nv-codec-headers were found by ffmpeg-cmake" FORCE)
    set(FFMPEG_NV_CODEC_HEADERS_INCLUDE_DIR "" CACHE INTERNAL "Include directory containing the ffnvcodec headers" FORCE)
    set(FFMPEG_NV_CODEC_HEADERS_PKG_CONFIG_DIR "" CACHE INTERNAL "pkg-config directory for ffnvcodec" FORCE)
    set(FFMPEG_NV_CODEC_HEADERS_ORIGIN "not found" CACHE INTERNAL "How nv-codec-headers were found" FORCE)

    if(FFMPEG_NV_CODEC_HEADERS_DIR)
        _ffmpeg_nvcodec_absolute(_ffmpeg_nvcodec_dir "${FFMPEG_NV_CODEC_HEADERS_DIR}")
        set(FFMPEG_NV_CODEC_HEADERS_DIR "${_ffmpeg_nvcodec_dir}" CACHE PATH "Path to nv-codec-headers checkout, install prefix, or include directory. Leave as the in-tree path for managed clone/update." FORCE)

        _ffmpeg_nvcodec_header_dir_from_root(_ffmpeg_header_dir "${FFMPEG_NV_CODEC_HEADERS_DIR}")
        if(NOT _ffmpeg_header_dir AND FFMPEG_NV_CODEC_HEADERS_GIT_CLONE)
            _ffmpeg_nvcodec_clone()
            _ffmpeg_nvcodec_header_dir_from_root(_ffmpeg_header_dir "${FFMPEG_NV_CODEC_HEADERS_DIR}")
            if(NOT _ffmpeg_header_dir)
                message(FATAL_ERROR "Cloned repository does not contain nv-codec-headers: ${FFMPEG_NV_CODEC_HEADERS_DIR}")
            endif()
        elseif(_ffmpeg_header_dir AND FFMPEG_NV_CODEC_HEADERS_GIT_UPDATE)
            _ffmpeg_nvcodec_update()
            _ffmpeg_nvcodec_header_dir_from_root(_ffmpeg_header_dir "${FFMPEG_NV_CODEC_HEADERS_DIR}")
            if(NOT _ffmpeg_header_dir)
                message(FATAL_ERROR "Updated repository no longer contains nv-codec-headers: ${FFMPEG_NV_CODEC_HEADERS_DIR}")
            endif()
        elseif(NOT _ffmpeg_header_dir AND FFMPEG_NV_CODEC_HEADERS_GIT_UPDATE)
            message(FATAL_ERROR "FFMPEG_NV_CODEC_HEADERS_GIT_UPDATE was requested, but nv-codec-headers were not found at ${FFMPEG_NV_CODEC_HEADERS_DIR}")
        endif()

        if(_ffmpeg_header_dir)
            set(FFMPEG_NV_CODEC_HEADERS_FOUND TRUE CACHE INTERNAL "Whether nv-codec-headers were found by ffmpeg-cmake" FORCE)
            set(FFMPEG_NV_CODEC_HEADERS_INCLUDE_DIR "${_ffmpeg_header_dir}" CACHE INTERNAL "Include directory containing the ffnvcodec headers" FORCE)
            set(FFMPEG_NV_CODEC_HEADERS_ORIGIN "configured path" CACHE INTERNAL "How nv-codec-headers were found" FORCE)
        endif()
    endif()

    if(NOT FFMPEG_NV_CODEC_HEADERS_FOUND)
        _ffmpeg_nvcodec_find_system_header_dir(_ffmpeg_header_dir)
        if(_ffmpeg_header_dir)
            set(FFMPEG_NV_CODEC_HEADERS_FOUND TRUE CACHE INTERNAL "Whether nv-codec-headers were found by ffmpeg-cmake" FORCE)
            set(FFMPEG_NV_CODEC_HEADERS_INCLUDE_DIR "${_ffmpeg_header_dir}" CACHE INTERNAL "Include directory containing the ffnvcodec headers" FORCE)
            set(FFMPEG_NV_CODEC_HEADERS_ORIGIN "prefix/include path" CACHE INTERNAL "How nv-codec-headers were found" FORCE)
        endif()
    endif()

    if(FFMPEG_NV_CODEC_HEADERS_FOUND)
        _ffmpeg_nvcodec_parse_version(_ffmpeg_version)
        _ffmpeg_nvcodec_generate_pkg_config("${FFMPEG_NV_CODEC_HEADERS_INCLUDE_DIR}" "${_ffmpeg_version}")
    endif()
endfunction()
