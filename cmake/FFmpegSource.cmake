include_guard(GLOBAL)

set(FFMPEG_SOURCE_DIR "${PROJECT_SOURCE_DIR}/ffmpeg" CACHE PATH "Path to the FFmpeg source tree")
set(FFMPEG_SOURCE_GIT_REPOSITORY "https://git.ffmpeg.org/ffmpeg.git" CACHE STRING "Git repository used when cloning FFmpeg sources")
set(FFMPEG_SOURCE_GIT_REF "" CACHE STRING "Optional FFmpeg git branch, tag, or commit to check out after clone/update")

option(FFMPEG_SOURCE_GIT_CLONE "Clone FFmpeg into FFMPEG_SOURCE_DIR when the source tree is missing" OFF)
option(FFMPEG_SOURCE_GIT_UPDATE "Update the in-tree FFmpeg git checkout at configure time" OFF)
option(FFMPEG_SOURCE_GIT_DETACHED_HEAD "Check out FFMPEG_SOURCE_GIT_REF as a detached HEAD even when it names a branch or tag" OFF)

function(_ffmpeg_source_absolute _out _path)
    get_filename_component(_ffmpeg_path "${_path}" ABSOLUTE BASE_DIR "${PROJECT_SOURCE_DIR}")
    file(TO_CMAKE_PATH "${_ffmpeg_path}" _ffmpeg_path)
    string(REGEX REPLACE "/+$" "" _ffmpeg_path "${_ffmpeg_path}")
    set(${_out} "${_ffmpeg_path}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_source_is_in_project _out _path)
    _ffmpeg_source_absolute(_ffmpeg_path "${_path}")
    _ffmpeg_source_absolute(_ffmpeg_project "${PROJECT_SOURCE_DIR}")

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

function(_ffmpeg_source_require_in_project _operation)
    _ffmpeg_source_is_in_project(_ffmpeg_in_project "${FFMPEG_SOURCE_DIR}")
    if(NOT _ffmpeg_in_project)
        message(FATAL_ERROR "${_operation} is allowed only for FFmpeg sources inside the ffmpeg-cmake checkout: ${FFMPEG_SOURCE_DIR}")
    endif()

    _ffmpeg_source_absolute(_ffmpeg_project "${PROJECT_SOURCE_DIR}")
    if("${FFMPEG_SOURCE_DIR}" STREQUAL "${_ffmpeg_project}")
        message(FATAL_ERROR "${_operation} cannot use the ffmpeg-cmake repository root as FFMPEG_SOURCE_DIR")
    endif()
endfunction()

function(_ffmpeg_source_find_git)
    if(NOT GIT_EXECUTABLE)
        find_package(Git QUIET)
    endif()
    if(NOT GIT_EXECUTABLE)
        message(FATAL_ERROR "Git executable was not found. Install git or disable FFmpeg source git operations.")
    endif()
endfunction()

function(_ffmpeg_source_git _workdir)
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

function(_ffmpeg_source_git_ref_exists _out _workdir _ref)
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

function(_ffmpeg_source_checkout_ref _workdir _ref)
    if(_ref STREQUAL "")
        return()
    endif()

    _ffmpeg_source_git_ref_exists(_ffmpeg_has_remote_ref "${_workdir}" "${_ref}")
    if(_ffmpeg_has_remote_ref)
        set(_ffmpeg_checkout_ref "origin/${_ref}")
    else()
        set(_ffmpeg_checkout_ref "${_ref}")
    endif()

    if(FFMPEG_SOURCE_GIT_DETACHED_HEAD OR _ref MATCHES "^[0-9a-fA-F]{7,40}$")
        _ffmpeg_source_git("${_workdir}" checkout --detach "${_ffmpeg_checkout_ref}")
    elseif(_ffmpeg_has_remote_ref)
        _ffmpeg_source_git("${_workdir}" checkout -B "${_ref}" "${_ffmpeg_checkout_ref}")
    else()
        _ffmpeg_source_git("${_workdir}" checkout "${_ffmpeg_checkout_ref}")
    endif()
endfunction()

function(_ffmpeg_source_clone)
    _ffmpeg_source_require_in_project("Cloning FFmpeg")
    _ffmpeg_source_find_git()

    if(EXISTS "${FFMPEG_SOURCE_DIR}")
        file(GLOB _ffmpeg_entries
            LIST_DIRECTORIES TRUE
            "${FFMPEG_SOURCE_DIR}/*"
            "${FFMPEG_SOURCE_DIR}/.[!.]*")
        if(_ffmpeg_entries)
            message(FATAL_ERROR "Cannot clone FFmpeg into a non-empty directory that is not an FFmpeg source tree: ${FFMPEG_SOURCE_DIR}")
        endif()
    endif()

    get_filename_component(_ffmpeg_parent "${FFMPEG_SOURCE_DIR}" DIRECTORY)
    file(MAKE_DIRECTORY "${_ffmpeg_parent}")

    message(STATUS "Cloning FFmpeg from ${FFMPEG_SOURCE_GIT_REPOSITORY} into ${FFMPEG_SOURCE_DIR}")
    execute_process(
        COMMAND "${GIT_EXECUTABLE}" clone "${FFMPEG_SOURCE_GIT_REPOSITORY}" "${FFMPEG_SOURCE_DIR}"
        WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
        RESULT_VARIABLE _ffmpeg_result
        OUTPUT_VARIABLE _ffmpeg_output
        ERROR_VARIABLE _ffmpeg_error
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_STRIP_TRAILING_WHITESPACE)
    if(NOT _ffmpeg_result EQUAL 0)
        message(FATAL_ERROR "Failed to clone FFmpeg from ${FFMPEG_SOURCE_GIT_REPOSITORY}\n${_ffmpeg_error}\n${_ffmpeg_output}")
    endif()

    if(FFMPEG_SOURCE_GIT_REF)
        _ffmpeg_source_checkout_ref("${FFMPEG_SOURCE_DIR}" "${FFMPEG_SOURCE_GIT_REF}")
    endif()
endfunction()

function(_ffmpeg_source_update)
    _ffmpeg_source_require_in_project("Updating FFmpeg")
    _ffmpeg_source_find_git()

    if(NOT EXISTS "${FFMPEG_SOURCE_DIR}/.git")
        message(FATAL_ERROR "FFMPEG_SOURCE_GIT_UPDATE requires an in-tree git checkout: ${FFMPEG_SOURCE_DIR}")
    endif()

    execute_process(
        COMMAND "${GIT_EXECUTABLE}" status --porcelain
        WORKING_DIRECTORY "${FFMPEG_SOURCE_DIR}"
        RESULT_VARIABLE _ffmpeg_status_result
        OUTPUT_VARIABLE _ffmpeg_status
        ERROR_VARIABLE _ffmpeg_status_error
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_STRIP_TRAILING_WHITESPACE)
    if(NOT _ffmpeg_status_result EQUAL 0)
        message(FATAL_ERROR "Could not inspect FFmpeg git status: ${_ffmpeg_status_error}")
    endif()
    if(_ffmpeg_status)
        message(FATAL_ERROR "Refusing to update dirty FFmpeg checkout: ${FFMPEG_SOURCE_DIR}")
    endif()

    message(STATUS "Updating in-tree FFmpeg checkout at ${FFMPEG_SOURCE_DIR}")
    _ffmpeg_source_git("${FFMPEG_SOURCE_DIR}" fetch --tags origin)
    if(FFMPEG_SOURCE_GIT_REF)
        _ffmpeg_source_checkout_ref("${FFMPEG_SOURCE_DIR}" "${FFMPEG_SOURCE_GIT_REF}")
    else()
        _ffmpeg_source_git("${FFMPEG_SOURCE_DIR}" pull --ff-only)
    endif()
endfunction()

function(ffmpeg_prepare_source)
    _ffmpeg_source_absolute(_ffmpeg_source_dir "${FFMPEG_SOURCE_DIR}")
    set(FFMPEG_SOURCE_DIR "${_ffmpeg_source_dir}" CACHE PATH "Path to the FFmpeg source tree" FORCE)

    if(NOT EXISTS "${FFMPEG_SOURCE_DIR}/configure")
        if(FFMPEG_SOURCE_GIT_CLONE)
            _ffmpeg_source_clone()
        else()
            message(FATAL_ERROR "FFmpeg source tree was not found at ${FFMPEG_SOURCE_DIR}. Set FFMPEG_SOURCE_DIR or enable FFMPEG_SOURCE_GIT_CLONE.")
        endif()
    elseif(FFMPEG_SOURCE_GIT_UPDATE)
        _ffmpeg_source_update()
    endif()

    if(NOT EXISTS "${FFMPEG_SOURCE_DIR}/configure")
        message(FATAL_ERROR "FFMPEG_SOURCE_DIR does not contain FFmpeg configure: ${FFMPEG_SOURCE_DIR}")
    endif()
endfunction()
