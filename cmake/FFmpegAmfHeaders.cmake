include_guard(GLOBAL)

set(FFMPEG_AMF_HEADERS_DIR "${PROJECT_SOURCE_DIR}/amf" CACHE PATH "Path to AMD AMF headers checkout, install prefix, or include directory. Leave as the in-tree path for managed clone/update.")
set(FFMPEG_AMF_HEADERS_GIT_REPOSITORY "https://github.com/GPUOpen-LibrariesAndSDKs/AMF.git" CACHE STRING "Git URL used when cloning AMD AMF headers into this checkout.")
set(FFMPEG_AMF_HEADERS_GIT_REF "" CACHE STRING "Optional AMD AMF headers branch, tag, or commit to check out after clone or update.")

option(FFMPEG_AMF_HEADERS_GIT_CLONE "Clone AMD AMF headers into FFMPEG_AMF_HEADERS_DIR when the headers are missing." OFF)
option(FFMPEG_AMF_HEADERS_GIT_UPDATE "Fetch and update the managed in-tree AMD AMF headers checkout during configure. Refuses dirty trees." OFF)
option(FFMPEG_AMF_HEADERS_GIT_DETACHED_HEAD "Check out FFMPEG_AMF_HEADERS_GIT_REF as a detached HEAD, useful for exact commits or reproducible builds." OFF)

function(_ffmpeg_amf_absolute _out _path)
    get_filename_component(_ffmpeg_path "${_path}" ABSOLUTE BASE_DIR "${PROJECT_SOURCE_DIR}")
    file(TO_CMAKE_PATH "${_ffmpeg_path}" _ffmpeg_path)
    string(REGEX REPLACE "/+$" "" _ffmpeg_path "${_ffmpeg_path}")
    set(${_out} "${_ffmpeg_path}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_amf_is_in_project _out _path)
    _ffmpeg_amf_absolute(_ffmpeg_path "${_path}")
    _ffmpeg_amf_absolute(_ffmpeg_project "${PROJECT_SOURCE_DIR}")

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

function(_ffmpeg_amf_require_in_project _operation)
    _ffmpeg_amf_is_in_project(_ffmpeg_in_project "${FFMPEG_AMF_HEADERS_DIR}")
    if(NOT _ffmpeg_in_project)
        message(FATAL_ERROR "${_operation} is allowed only for AMD AMF headers inside the ffmpeg-cmake checkout: ${FFMPEG_AMF_HEADERS_DIR}")
    endif()

    _ffmpeg_amf_absolute(_ffmpeg_project "${PROJECT_SOURCE_DIR}")
    if("${FFMPEG_AMF_HEADERS_DIR}" STREQUAL "${_ffmpeg_project}")
        message(FATAL_ERROR "${_operation} cannot use the ffmpeg-cmake repository root as FFMPEG_AMF_HEADERS_DIR")
    endif()
endfunction()

function(_ffmpeg_amf_find_git)
    if(NOT GIT_EXECUTABLE)
        find_package(Git QUIET)
    endif()
    if(NOT GIT_EXECUTABLE)
        message(FATAL_ERROR "Git executable was not found. Install git or disable AMD AMF headers git operations.")
    endif()
endfunction()

function(_ffmpeg_amf_git _workdir)
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

function(_ffmpeg_amf_git_ref_exists _out _workdir _ref)
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

function(_ffmpeg_amf_checkout_ref _workdir _ref)
    if(_ref STREQUAL "")
        return()
    endif()

    _ffmpeg_amf_git_ref_exists(_ffmpeg_has_remote_ref "${_workdir}" "${_ref}")
    if(_ffmpeg_has_remote_ref)
        set(_ffmpeg_checkout_ref "origin/${_ref}")
    else()
        set(_ffmpeg_checkout_ref "${_ref}")
    endif()

    if(FFMPEG_AMF_HEADERS_GIT_DETACHED_HEAD OR _ref MATCHES "^[0-9a-fA-F]{7,40}$")
        _ffmpeg_amf_git("${_workdir}" checkout --detach "${_ffmpeg_checkout_ref}")
    elseif(_ffmpeg_has_remote_ref)
        _ffmpeg_amf_git("${_workdir}" checkout -B "${_ref}" "${_ffmpeg_checkout_ref}")
    else()
        _ffmpeg_amf_git("${_workdir}" checkout "${_ffmpeg_checkout_ref}")
    endif()
endfunction()

function(_ffmpeg_amf_generate_layout_include_dir _out _source_include_dir)
    set(_ffmpeg_layout_root "${PROJECT_BINARY_DIR}/amf-headers/include")
    set(_ffmpeg_layout_amf_dir "${_ffmpeg_layout_root}/AMF")

    file(REMOVE_RECURSE "${_ffmpeg_layout_amf_dir}")
    file(MAKE_DIRECTORY "${_ffmpeg_layout_amf_dir}")
    file(COPY "${_source_include_dir}/" DESTINATION "${_ffmpeg_layout_amf_dir}")

    set(${_out} "${_ffmpeg_layout_root}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_amf_header_dir_from_root _out _root)
    set(_ffmpeg_candidates
        "${_root}/include"
        "${_root}/public/include"
        "${_root}/amf/public/include"
        "${_root}/AMF/public/include"
        "${_root}")
    foreach(_ffmpeg_candidate IN LISTS _ffmpeg_candidates)
        if(EXISTS "${_ffmpeg_candidate}/AMF/core/Version.h")
            set(${_out} "${_ffmpeg_candidate}" PARENT_SCOPE)
            return()
        endif()
    endforeach()

    set(_ffmpeg_raw_candidates
        "${_root}/include"
        "${_root}/public/include"
        "${_root}/amf/public/include"
        "${_root}/AMF/public/include"
        "${_root}")
    foreach(_ffmpeg_candidate IN LISTS _ffmpeg_raw_candidates)
        if(EXISTS "${_ffmpeg_candidate}/core/Version.h" AND
           EXISTS "${_ffmpeg_candidate}/core/Factory.h" AND
           EXISTS "${_ffmpeg_candidate}/components/Component.h")
            _ffmpeg_amf_generate_layout_include_dir(_ffmpeg_layout_dir "${_ffmpeg_candidate}")
            set(${_out} "${_ffmpeg_layout_dir}" PARENT_SCOPE)
            return()
        endif()
    endforeach()

    set(${_out} "" PARENT_SCOPE)
endfunction()

function(_ffmpeg_amf_prefix_include_dirs _out)
    set(_ffmpeg_dirs)
    foreach(_ffmpeg_prefix IN LISTS CMAKE_PREFIX_PATH)
        if(_ffmpeg_prefix STREQUAL "")
            continue()
        endif()
        foreach(_ffmpeg_suffix IN ITEMS include public/include amf/public/include AMF/public/include)
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

function(_ffmpeg_amf_find_system_header_dir _out)
    _ffmpeg_amf_prefix_include_dirs(_ffmpeg_include_dirs)
    foreach(_ffmpeg_include_dir IN LISTS _ffmpeg_include_dirs)
        _ffmpeg_amf_header_dir_from_root(_ffmpeg_header_dir "${_ffmpeg_include_dir}")
        if(_ffmpeg_header_dir)
            set(${_out} "${_ffmpeg_header_dir}" PARENT_SCOPE)
            return()
        endif()
    endforeach()
    set(${_out} "" PARENT_SCOPE)
endfunction()

function(_ffmpeg_amf_parse_version _include_dir)
    set(_ffmpeg_version)
    set(_ffmpeg_usable FALSE)
    set(_ffmpeg_header "${_include_dir}/AMF/core/Version.h")
    if(EXISTS "${_ffmpeg_header}")
        file(STRINGS "${_ffmpeg_header}" _ffmpeg_version_lines REGEX "^[ \t]*#[ \t]*define[ \t]+AMF_VERSION_(MAJOR|MINOR|RELEASE|BUILD_NUM)[ \t]+[0-9]+")
        foreach(_ffmpeg_line IN LISTS _ffmpeg_version_lines)
            if(_ffmpeg_line MATCHES "AMF_VERSION_MAJOR[ \t]+([0-9]+)")
                set(_ffmpeg_major "${CMAKE_MATCH_1}")
            elseif(_ffmpeg_line MATCHES "AMF_VERSION_MINOR[ \t]+([0-9]+)")
                set(_ffmpeg_minor "${CMAKE_MATCH_1}")
            elseif(_ffmpeg_line MATCHES "AMF_VERSION_RELEASE[ \t]+([0-9]+)")
                set(_ffmpeg_release "${CMAKE_MATCH_1}")
            elseif(_ffmpeg_line MATCHES "AMF_VERSION_BUILD_NUM[ \t]+([0-9]+)")
                set(_ffmpeg_build "${CMAKE_MATCH_1}")
            endif()
        endforeach()
        if(DEFINED _ffmpeg_major AND DEFINED _ffmpeg_minor AND DEFINED _ffmpeg_release AND DEFINED _ffmpeg_build)
            set(_ffmpeg_version "${_ffmpeg_major}.${_ffmpeg_minor}.${_ffmpeg_release}.${_ffmpeg_build}")
            if(_ffmpeg_major GREATER 1 OR (_ffmpeg_major EQUAL 1 AND _ffmpeg_minor GREATER_EQUAL 5))
                set(_ffmpeg_usable TRUE)
            endif()
        endif()
    endif()

    set(FFMPEG_AMF_HEADERS_VERSION "${_ffmpeg_version}" CACHE INTERNAL "Detected AMD AMF headers version" FORCE)
    set(FFMPEG_AMF_HEADERS_USABLE "${_ffmpeg_usable}" CACHE INTERNAL "Whether AMD AMF headers are new enough for this FFmpeg checkout" FORCE)
endfunction()

function(_ffmpeg_amf_clone)
    _ffmpeg_amf_require_in_project("Cloning AMD AMF headers")
    _ffmpeg_amf_find_git()

    if(EXISTS "${FFMPEG_AMF_HEADERS_DIR}")
        file(GLOB _ffmpeg_entries
            LIST_DIRECTORIES TRUE
            "${FFMPEG_AMF_HEADERS_DIR}/*"
            "${FFMPEG_AMF_HEADERS_DIR}/.[!.]*")
        if(_ffmpeg_entries)
            message(FATAL_ERROR "Cannot clone AMD AMF headers into a non-empty directory that does not contain AMF headers: ${FFMPEG_AMF_HEADERS_DIR}")
        endif()
    endif()

    get_filename_component(_ffmpeg_parent "${FFMPEG_AMF_HEADERS_DIR}" DIRECTORY)
    file(MAKE_DIRECTORY "${_ffmpeg_parent}")

    message(STATUS "Cloning AMD AMF headers from ${FFMPEG_AMF_HEADERS_GIT_REPOSITORY} into ${FFMPEG_AMF_HEADERS_DIR}")
    execute_process(
        COMMAND "${GIT_EXECUTABLE}" -c core.autocrlf=false clone --config core.autocrlf=false "${FFMPEG_AMF_HEADERS_GIT_REPOSITORY}" "${FFMPEG_AMF_HEADERS_DIR}"
        WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
        RESULT_VARIABLE _ffmpeg_result
        OUTPUT_VARIABLE _ffmpeg_output
        ERROR_VARIABLE _ffmpeg_error
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_STRIP_TRAILING_WHITESPACE)
    if(NOT _ffmpeg_result EQUAL 0)
        message(FATAL_ERROR "Failed to clone AMD AMF headers from ${FFMPEG_AMF_HEADERS_GIT_REPOSITORY}\n${_ffmpeg_error}\n${_ffmpeg_output}")
    endif()

    if(FFMPEG_AMF_HEADERS_GIT_REF)
        _ffmpeg_amf_checkout_ref("${FFMPEG_AMF_HEADERS_DIR}" "${FFMPEG_AMF_HEADERS_GIT_REF}")
    endif()
endfunction()

function(_ffmpeg_amf_update)
    _ffmpeg_amf_require_in_project("Updating AMD AMF headers")
    _ffmpeg_amf_find_git()

    if(NOT EXISTS "${FFMPEG_AMF_HEADERS_DIR}/.git")
        message(FATAL_ERROR "FFMPEG_AMF_HEADERS_GIT_UPDATE requires an in-tree git checkout: ${FFMPEG_AMF_HEADERS_DIR}")
    endif()

    execute_process(
        COMMAND "${GIT_EXECUTABLE}" status --porcelain
        WORKING_DIRECTORY "${FFMPEG_AMF_HEADERS_DIR}"
        RESULT_VARIABLE _ffmpeg_status_result
        OUTPUT_VARIABLE _ffmpeg_status
        ERROR_VARIABLE _ffmpeg_status_error
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_STRIP_TRAILING_WHITESPACE)
    if(NOT _ffmpeg_status_result EQUAL 0)
        message(FATAL_ERROR "Could not inspect AMD AMF headers git status: ${_ffmpeg_status_error}")
    endif()
    if(_ffmpeg_status)
        message(FATAL_ERROR "Refusing to update dirty AMD AMF headers checkout: ${FFMPEG_AMF_HEADERS_DIR}")
    endif()

    message(STATUS "Updating in-tree AMD AMF headers checkout at ${FFMPEG_AMF_HEADERS_DIR}")
    _ffmpeg_amf_git("${FFMPEG_AMF_HEADERS_DIR}" fetch --tags origin)
    if(FFMPEG_AMF_HEADERS_GIT_REF)
        _ffmpeg_amf_checkout_ref("${FFMPEG_AMF_HEADERS_DIR}" "${FFMPEG_AMF_HEADERS_GIT_REF}")
    else()
        _ffmpeg_amf_git("${FFMPEG_AMF_HEADERS_DIR}" pull --ff-only)
    endif()
endfunction()

function(ffmpeg_prepare_amf_headers)
    set(FFMPEG_AMF_HEADERS_FOUND FALSE CACHE INTERNAL "Whether AMD AMF headers were found by ffmpeg-cmake" FORCE)
    set(FFMPEG_AMF_HEADERS_INCLUDE_DIR "" CACHE INTERNAL "Include directory containing AMD AMF headers" FORCE)
    set(FFMPEG_AMF_HEADERS_ORIGIN "not found" CACHE INTERNAL "How AMD AMF headers were found" FORCE)
    set(FFMPEG_AMF_HEADERS_VERSION "" CACHE INTERNAL "Detected AMD AMF headers version" FORCE)
    set(FFMPEG_AMF_HEADERS_USABLE FALSE CACHE INTERNAL "Whether AMD AMF headers are new enough for this FFmpeg checkout" FORCE)

    if(FFMPEG_AMF_HEADERS_DIR)
        _ffmpeg_amf_absolute(_ffmpeg_amf_dir "${FFMPEG_AMF_HEADERS_DIR}")
        set(FFMPEG_AMF_HEADERS_DIR "${_ffmpeg_amf_dir}" CACHE PATH "Path to AMD AMF headers checkout, install prefix, or include directory. Leave as the in-tree path for managed clone/update." FORCE)

        _ffmpeg_amf_header_dir_from_root(_ffmpeg_header_dir "${FFMPEG_AMF_HEADERS_DIR}")
        if(NOT _ffmpeg_header_dir AND FFMPEG_AMF_HEADERS_GIT_CLONE)
            _ffmpeg_amf_clone()
            _ffmpeg_amf_header_dir_from_root(_ffmpeg_header_dir "${FFMPEG_AMF_HEADERS_DIR}")
            if(NOT _ffmpeg_header_dir)
                message(FATAL_ERROR "Cloned repository does not contain AMD AMF headers: ${FFMPEG_AMF_HEADERS_DIR}")
            endif()
        elseif(_ffmpeg_header_dir AND FFMPEG_AMF_HEADERS_GIT_UPDATE)
            _ffmpeg_amf_update()
            _ffmpeg_amf_header_dir_from_root(_ffmpeg_header_dir "${FFMPEG_AMF_HEADERS_DIR}")
            if(NOT _ffmpeg_header_dir)
                message(FATAL_ERROR "Updated repository no longer contains AMD AMF headers: ${FFMPEG_AMF_HEADERS_DIR}")
            endif()
        elseif(NOT _ffmpeg_header_dir AND FFMPEG_AMF_HEADERS_GIT_UPDATE)
            message(FATAL_ERROR "FFMPEG_AMF_HEADERS_GIT_UPDATE was requested, but AMD AMF headers were not found at ${FFMPEG_AMF_HEADERS_DIR}")
        endif()

        if(_ffmpeg_header_dir)
            set(FFMPEG_AMF_HEADERS_FOUND TRUE CACHE INTERNAL "Whether AMD AMF headers were found by ffmpeg-cmake" FORCE)
            set(FFMPEG_AMF_HEADERS_INCLUDE_DIR "${_ffmpeg_header_dir}" CACHE INTERNAL "Include directory containing AMD AMF headers" FORCE)
            set(FFMPEG_AMF_HEADERS_ORIGIN "configured path" CACHE INTERNAL "How AMD AMF headers were found" FORCE)
        endif()
    endif()

    if(NOT FFMPEG_AMF_HEADERS_FOUND)
        _ffmpeg_amf_find_system_header_dir(_ffmpeg_header_dir)
        if(_ffmpeg_header_dir)
            set(FFMPEG_AMF_HEADERS_FOUND TRUE CACHE INTERNAL "Whether AMD AMF headers were found by ffmpeg-cmake" FORCE)
            set(FFMPEG_AMF_HEADERS_INCLUDE_DIR "${_ffmpeg_header_dir}" CACHE INTERNAL "Include directory containing AMD AMF headers" FORCE)
            set(FFMPEG_AMF_HEADERS_ORIGIN "prefix/include path" CACHE INTERNAL "How AMD AMF headers were found" FORCE)
        endif()
    endif()

    if(FFMPEG_AMF_HEADERS_FOUND)
        _ffmpeg_amf_parse_version("${FFMPEG_AMF_HEADERS_INCLUDE_DIR}")
    endif()
endfunction()
