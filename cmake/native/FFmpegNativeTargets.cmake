include_guard(GLOBAL)

function(_ffmpeg_native_resolve_components _out)
    set(_ffmpeg_components)
    foreach(_ffmpeg_component IN LISTS FFMPEG_NATIVE_COMPONENTS)
        string(TOUPPER "${_ffmpeg_component}" _ffmpeg_component_uc)
        if(DEFINED FFMPEG_ENABLE_${_ffmpeg_component_uc} AND NOT FFMPEG_ENABLE_${_ffmpeg_component_uc})
            continue()
        endif()
        list(APPEND _ffmpeg_components "${_ffmpeg_component}")
    endforeach()
    list(REMOVE_DUPLICATES _ffmpeg_components)
    set(${_out} "${_ffmpeg_components}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_program_require_components _tool)
    if(_tool STREQUAL "ffprobe")
        set(_ffmpeg_required avutil avcodec avformat)
    elseif(_tool STREQUAL "ffmpeg")
        set(_ffmpeg_required avutil avcodec avformat avfilter)
    elseif(_tool STREQUAL "ffplay")
        set(_ffmpeg_required avutil avcodec avformat avfilter swscale swresample)
    else()
        message(FATAL_ERROR "Unknown native FFmpeg program '${_tool}'")
    endif()

    foreach(_ffmpeg_required_component IN LISTS _ffmpeg_required)
        if(NOT TARGET "${_ffmpeg_required_component}")
            message(FATAL_ERROR "Native program '${_tool}' requires ${_ffmpeg_required_component} in FFMPEG_NATIVE_COMPONENTS")
        endif()
    endforeach()
endfunction()

function(_ffmpeg_native_link_program_libraries _target)
    set(_ffmpeg_program_libs)
    foreach(_ffmpeg_component IN ITEMS avdevice avfilter avformat avcodec swresample swscale avutil)
        if(TARGET ${_ffmpeg_component})
            list(APPEND _ffmpeg_program_libs "FFmpeg::${_ffmpeg_component}")
        endif()
    endforeach()

    if(FFMPEG_BUILD_STATIC AND NOT WIN32 AND _ffmpeg_program_libs)
        string(REPLACE ";" "," _ffmpeg_program_group "${_ffmpeg_program_libs}")
        target_link_libraries(${_target} PRIVATE "$<LINK_GROUP:RESCAN,${_ffmpeg_program_group}>")
    else()
        target_link_libraries(${_target} PRIVATE ${_ffmpeg_program_libs})
    endif()
endfunction()

function(_ffmpeg_native_runtime_dependency_dirs _out)
    set(_ffmpeg_dirs)
    foreach(_ffmpeg_prefix IN LISTS CMAKE_PREFIX_PATH)
        if(_ffmpeg_prefix STREQUAL "")
            continue()
        endif()
        foreach(_ffmpeg_suffix IN ITEMS bin lib lib64)
            if(IS_DIRECTORY "${_ffmpeg_prefix}/${_ffmpeg_suffix}")
                list(APPEND _ffmpeg_dirs "${_ffmpeg_prefix}/${_ffmpeg_suffix}")
            endif()
        endforeach()
    endforeach()
    list(REMOVE_DUPLICATES _ffmpeg_dirs)
    set(${_out} "${_ffmpeg_dirs}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_runtime_dependency_args _out)
    if(NOT FFMPEG_NATIVE_INSTALL_RUNTIME_DEPENDENCIES)
        set(${_out} "" PARENT_SCOPE)
        return()
    endif()

    _ffmpeg_native_runtime_dependency_dirs(_ffmpeg_runtime_dirs)
    set(_ffmpeg_args
        RUNTIME_DEPENDENCIES
            PRE_EXCLUDE_REGEXES
                "api-ms-.*"
                "ext-ms-.*")
    if(WIN32)
        list(APPEND _ffmpeg_args
            POST_EXCLUDE_REGEXES
            ".*[/\\\\][Ww]indows[/\\\\][Ss]ystem32[/\\\\].*"
            ".*[/\\\\][Ww]indows[/\\\\][Ss]ysWOW64[/\\\\].*"
            ".*[/\\\\][Ww]indows[/\\\\][Ww]inSxS[/\\\\].*")
    elseif(APPLE)
        list(APPEND _ffmpeg_args
            POST_EXCLUDE_REGEXES
            "^/System/Library/.*"
            "^/usr/lib/.*")
    else()
        list(APPEND _ffmpeg_args
            POST_EXCLUDE_REGEXES
            "^/lib/.*"
            "^/lib64/.*"
            "^/usr/lib/.*"
            "^/usr/lib64/.*")
    endif()
    if(_ffmpeg_runtime_dirs)
        list(APPEND _ffmpeg_args DIRECTORIES ${_ffmpeg_runtime_dirs})
    endif()
    set(${_out} "${_ffmpeg_args}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_add_program _tool)
    list(FIND FFMPEG_NATIVE_ENABLED_CONFIG_FEATURES "${_tool}" _ffmpeg_program_enabled)
    if(_ffmpeg_program_enabled EQUAL -1)
        return()
    endif()
    if(_tool STREQUAL "ffmpeg" AND NOT FFMPEG_NATIVE_ENABLE_THREADS)
        message(FATAL_ERROR "Native program 'ffmpeg' requires FFMPEG_NATIVE_ENABLE_THREADS=ON")
    endif()
    if(_tool STREQUAL "ffplay" AND NOT TARGET FFmpegExternal::sdl2)
        message(FATAL_ERROR "Native program 'ffplay' requires SDL2. Provide sdl2 via CMAKE_PREFIX_PATH/pkg-config or disable FFMPEG_NATIVE_BUILD_FFPLAY.")
    endif()

    _ffmpeg_native_program_require_components("${_tool}")
    _ffmpeg_native_collect_fftool_sources(_ffmpeg_sources "${_tool}")
    add_executable(${_tool} ${_ffmpeg_sources})
    ffmpeg_set_target_folder(${_tool} "FFmpeg/Tools")
    target_include_directories(${_tool}
        PRIVATE
            "${FFMPEG_NATIVE_GENERATED_DIR}"
            "${FFMPEG_SOURCE_DIR}")
    _ffmpeg_native_apply_compile_settings(${_tool})
    _ffmpeg_native_link_program_libraries(${_tool})

    if(_tool STREQUAL "ffplay" AND TARGET FFmpegExternal::sdl2)
        target_link_libraries(${_tool} PRIVATE FFmpegExternal::sdl2)
    endif()

    _ffmpeg_native_runtime_dependency_args(_ffmpeg_runtime_dependency_args)
    install(TARGETS ${_tool}
        ${_ffmpeg_runtime_dependency_args}
        RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}")
    list(APPEND FFMPEG_NATIVE_PROGRAMS "${_tool}")
    set(FFMPEG_NATIVE_PROGRAMS "${FFMPEG_NATIVE_PROGRAMS}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_add_example _example)
    set(_ffmpeg_source "${FFMPEG_SOURCE_DIR}/doc/examples/${_example}.c")
    if(NOT EXISTS "${_ffmpeg_source}")
        message(VERBOSE "Skipping native FFmpeg example without source: ${_example}")
        return()
    endif()
    if(WIN32)
        file(READ "${_ffmpeg_source}" _ffmpeg_example_source)
        if(_ffmpeg_example_source MATCHES "#[ \t]*include[ \t]*<unistd\\.h>")
            message(VERBOSE "Skipping native FFmpeg example with POSIX-only headers on Windows: ${_example}")
            return()
        endif()
    endif()

    set(_ffmpeg_target "ffmpeg_example_${_example}")
    add_executable(${_ffmpeg_target} EXCLUDE_FROM_ALL "${_ffmpeg_source}")
    ffmpeg_set_target_folder(${_ffmpeg_target} "FFmpeg/Examples")
    target_include_directories(${_ffmpeg_target}
        PRIVATE
            "${FFMPEG_NATIVE_GENERATED_DIR}"
            "${FFMPEG_SOURCE_DIR}")
    _ffmpeg_native_apply_compile_settings(${_ffmpeg_target})
    _ffmpeg_native_link_program_libraries(${_ffmpeg_target})
    set_target_properties(${_ffmpeg_target} PROPERTIES
        OUTPUT_NAME "${_example}"
        RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/doc/examples")

    list(APPEND FFMPEG_NATIVE_EXAMPLE_TARGETS "${_ffmpeg_target}")
    list(APPEND FFMPEG_NATIVE_EXAMPLES "${_example}")
    set(FFMPEG_NATIVE_EXAMPLE_TARGETS "${FFMPEG_NATIVE_EXAMPLE_TARGETS}" PARENT_SCOPE)
    set(FFMPEG_NATIVE_EXAMPLES "${FFMPEG_NATIVE_EXAMPLES}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_add_examples)
    _ffmpeg_native_collect_enabled_examples(_ffmpeg_examples)
    set(FFMPEG_NATIVE_EXAMPLES)
    set(FFMPEG_NATIVE_EXAMPLE_TARGETS)
    foreach(_ffmpeg_example IN LISTS _ffmpeg_examples)
        _ffmpeg_native_add_example("${_ffmpeg_example}")
    endforeach()

    if(FFMPEG_NATIVE_EXAMPLE_TARGETS)
        add_custom_target(ffmpeg_native_examples ALL DEPENDS ${FFMPEG_NATIVE_EXAMPLE_TARGETS})
        ffmpeg_set_target_folder(ffmpeg_native_examples "FFmpeg/Examples")
    endif()

    set(FFMPEG_NATIVE_EXAMPLES "${FFMPEG_NATIVE_EXAMPLES}" PARENT_SCOPE)
    set(FFMPEG_NATIVE_EXAMPLE_TARGETS "${FFMPEG_NATIVE_EXAMPLE_TARGETS}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_install_examples)
    set(_ffmpeg_examples_dir "${FFMPEG_SOURCE_DIR}/doc/examples")
    if(NOT IS_DIRECTORY "${_ffmpeg_examples_dir}")
        return()
    endif()

    file(GLOB _ffmpeg_example_sources
        CONFIGURE_DEPENDS
        "${_ffmpeg_examples_dir}/*.c")
    if(_ffmpeg_example_sources)
        install(FILES ${_ffmpeg_example_sources}
            DESTINATION "${CMAKE_INSTALL_DATADIR}/ffmpeg/examples")
    endif()
    if(EXISTS "${_ffmpeg_examples_dir}/README")
        install(FILES "${_ffmpeg_examples_dir}/README"
            DESTINATION "${CMAKE_INSTALL_DATADIR}/ffmpeg/examples")
    endif()
    if(EXISTS "${_ffmpeg_examples_dir}/Makefile.example")
        install(FILES "${_ffmpeg_examples_dir}/Makefile.example"
            DESTINATION "${CMAKE_INSTALL_DATADIR}/ffmpeg/examples"
            RENAME Makefile)
    elseif(EXISTS "${_ffmpeg_examples_dir}/Makefile")
        install(FILES "${_ffmpeg_examples_dir}/Makefile"
            DESTINATION "${CMAKE_INSTALL_DATADIR}/ffmpeg/examples")
    endif()
endfunction()

function(_ffmpeg_native_library_type _out)
    if(FFMPEG_BUILD_SHARED AND FFMPEG_BUILD_STATIC)
        if(MSVC OR WIN32)
            message(FATAL_ERROR "The native MSVC/Windows backend cannot build static and shared FFmpeg libraries in one configuration. Pick one of FFMPEG_BUILD_STATIC or FFMPEG_BUILD_SHARED.")
        endif()
    endif()
    if(FFMPEG_BUILD_SHARED)
        set(${_out} SHARED PARENT_SCOPE)
    else()
        set(${_out} STATIC PARENT_SCOPE)
    endif()
endfunction()

function(_ffmpeg_native_add_library _component)
    _ffmpeg_native_library_type(_ffmpeg_library_type)
    _ffmpeg_native_collect_makefile_objects(_ffmpeg_sources "${_component}")

    add_library(${_component} ${_ffmpeg_library_type} ${_ffmpeg_sources})
    ffmpeg_set_target_folder(${_component} "FFmpeg/Libraries")
    add_library(FFmpeg::${_component} ALIAS ${_component})
    set(_ffmpeg_private_include_dirs)
    if(_component STREQUAL "avcodec")
        list(APPEND _ffmpeg_private_include_dirs
            "${FFMPEG_NATIVE_GENERATED_DIR}/lib${_component}"
            "${FFMPEG_SOURCE_DIR}/lib${_component}")
    endif()
    target_include_directories(${_component}
        PUBLIC
            "$<BUILD_INTERFACE:${FFMPEG_NATIVE_GENERATED_DIR}>"
            "$<BUILD_INTERFACE:${FFMPEG_SOURCE_DIR}>"
            "$<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>")
    if(_ffmpeg_private_include_dirs)
        target_include_directories(${_component}
        PRIVATE
            ${_ffmpeg_private_include_dirs})
    endif()
    _ffmpeg_native_apply_compile_settings(${_component} HAVE_AV_CONFIG_H)
    _ffmpeg_native_target_c_definitions(${_component} BUILDING_${_component})
    if(UNIX AND NOT APPLE)
        target_link_libraries(${_component} PUBLIC m)
    endif()
    set(_ffmpeg_position_independent_code "${CMAKE_POSITION_INDEPENDENT_CODE}")
    if(FFMPEG_BUILD_SHARED)
        set(_ffmpeg_position_independent_code ON)
    endif()
    set_target_properties(${_component} PROPERTIES
        OUTPUT_NAME "${_component}"
        POSITION_INDEPENDENT_CODE "${_ffmpeg_position_independent_code}")

    set(_ffmpeg_runtime_dependency_args)
    if(NOT _ffmpeg_library_type STREQUAL "STATIC")
        _ffmpeg_native_runtime_dependency_args(_ffmpeg_runtime_dependency_args)
    endif()
    install(TARGETS ${_component}
        EXPORT FFmpegNativeTargets
        ${_ffmpeg_runtime_dependency_args}
        ARCHIVE DESTINATION "${CMAKE_INSTALL_LIBDIR}"
        LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}"
        RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}")
endfunction()

function(_ffmpeg_native_install_headers)
    foreach(_ffmpeg_component IN LISTS FFMPEG_NATIVE_COMPONENTS)
        install(DIRECTORY "${FFMPEG_SOURCE_DIR}/lib${_ffmpeg_component}/"
            DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/lib${_ffmpeg_component}"
            FILES_MATCHING PATTERN "*.h")
        if(IS_DIRECTORY "${FFMPEG_NATIVE_GENERATED_DIR}/lib${_ffmpeg_component}")
            install(DIRECTORY "${FFMPEG_NATIVE_GENERATED_DIR}/lib${_ffmpeg_component}/"
                DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/lib${_ffmpeg_component}"
                FILES_MATCHING PATTERN "*.h")
        endif()
    endforeach()
endfunction()
