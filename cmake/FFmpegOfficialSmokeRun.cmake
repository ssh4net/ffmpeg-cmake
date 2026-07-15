function(_ffmpeg_official_smoke_run _step)
    execute_process(
        COMMAND ${ARGN}
        RESULT_VARIABLE _ffmpeg_result
        OUTPUT_VARIABLE _ffmpeg_stdout
        ERROR_VARIABLE _ffmpeg_stderr
        TIMEOUT "${FFMPEG_OFFICIAL_SMOKE_TIMEOUT}")
    if(NOT _ffmpeg_result EQUAL 0)
        message(STATUS "-- official smoke ${_step} stdout:\n${_ffmpeg_stdout}")
        message(STATUS "-- official smoke ${_step} stderr:\n${_ffmpeg_stderr}")
        message(FATAL_ERROR "official smoke ${_step} failed with exit code ${_ffmpeg_result}")
    endif()
    set(FFMPEG_OFFICIAL_SMOKE_LAST_STDOUT "${_ffmpeg_stdout}" PARENT_SCOPE)
    set(FFMPEG_OFFICIAL_SMOKE_LAST_STDERR "${_ffmpeg_stderr}" PARENT_SCOPE)
endfunction()

if(NOT FFMPEG_OFFICIAL_SMOKE_MODE)
    message(FATAL_ERROR "FFMPEG_OFFICIAL_SMOKE_MODE is required")
endif()
if(NOT FFMPEG_OFFICIAL_SMOKE_TIMEOUT)
    set(FFMPEG_OFFICIAL_SMOKE_TIMEOUT 120)
endif()

if(FFMPEG_OFFICIAL_SMOKE_MODE STREQUAL "tool")
    if(NOT FFMPEG_OFFICIAL_SMOKE_EXECUTABLE)
        message(FATAL_ERROR "FFMPEG_OFFICIAL_SMOKE_EXECUTABLE is required")
    endif()
    if(NOT EXISTS "${FFMPEG_OFFICIAL_SMOKE_EXECUTABLE}")
        message(FATAL_ERROR
            "Expected installed FFmpeg tool is missing: ${FFMPEG_OFFICIAL_SMOKE_EXECUTABLE}\n"
            "Build/install the source build first, for example: cmake --build <build-dir> --target ffmpeg_cmake_package")
    endif()

    separate_arguments(_ffmpeg_args NATIVE_COMMAND "${FFMPEG_OFFICIAL_SMOKE_ARGS}")
    _ffmpeg_official_smoke_run("tool"
        "${FFMPEG_OFFICIAL_SMOKE_EXECUTABLE}"
        ${_ffmpeg_args})

    if(FFMPEG_OFFICIAL_SMOKE_EXPECT_REGEX)
        set(_ffmpeg_output "${FFMPEG_OFFICIAL_SMOKE_LAST_STDOUT}\n${FFMPEG_OFFICIAL_SMOKE_LAST_STDERR}")
        if(NOT _ffmpeg_output MATCHES "${FFMPEG_OFFICIAL_SMOKE_EXPECT_REGEX}")
            message(STATUS "-- official smoke tool stdout:\n${FFMPEG_OFFICIAL_SMOKE_LAST_STDOUT}")
            message(STATUS "-- official smoke tool stderr:\n${FFMPEG_OFFICIAL_SMOKE_LAST_STDERR}")
            message(FATAL_ERROR "official smoke output did not match expected regex: ${FFMPEG_OFFICIAL_SMOKE_EXPECT_REGEX}")
        endif()
    endif()
elseif(FFMPEG_OFFICIAL_SMOKE_MODE STREQUAL "consumer")
    foreach(_ffmpeg_required_var IN ITEMS
            FFMPEG_OFFICIAL_SMOKE_SOURCE_DIR
            FFMPEG_OFFICIAL_SMOKE_BINARY_DIR
            FFMPEG_OFFICIAL_SMOKE_INSTALL_PREFIX
            FFMPEG_OFFICIAL_SMOKE_PKGCONFIG_DIR
            FFMPEG_OFFICIAL_SMOKE_LIBRARY_DIR
            FFMPEG_OFFICIAL_SMOKE_GENERATOR
            FFMPEG_OFFICIAL_SMOKE_CTEST_COMMAND)
        if(NOT DEFINED ${_ffmpeg_required_var} OR "${${_ffmpeg_required_var}}" STREQUAL "")
            message(FATAL_ERROR "${_ffmpeg_required_var} is required")
        endif()
    endforeach()

    foreach(_ffmpeg_pc_component IN ITEMS libavutil libswresample libswscale libavcodec libavformat libavfilter libavdevice)
        set(_ffmpeg_pc "${FFMPEG_OFFICIAL_SMOKE_PKGCONFIG_DIR}/${_ffmpeg_pc_component}.pc")
        if(NOT EXISTS "${_ffmpeg_pc}")
            message(FATAL_ERROR
                "Expected installed FFmpeg pkg-config file is missing: ${_ffmpeg_pc}\n"
                "Build/install the source build first, for example: cmake --build <build-dir> --target ffmpeg_cmake_package")
        endif()
    endforeach()

    file(REMOVE_RECURSE "${FFMPEG_OFFICIAL_SMOKE_BINARY_DIR}")
    file(MAKE_DIRECTORY "${FFMPEG_OFFICIAL_SMOKE_BINARY_DIR}")

    set(_ffmpeg_prefix_path "${FFMPEG_OFFICIAL_SMOKE_INSTALL_PREFIX}")
    if(FFMPEG_OFFICIAL_SMOKE_DEPENDENCY_PREFIX_PATH)
        list(APPEND _ffmpeg_prefix_path ${FFMPEG_OFFICIAL_SMOKE_DEPENDENCY_PREFIX_PATH})
        list(REMOVE_DUPLICATES _ffmpeg_prefix_path)
    endif()
    list(JOIN _ffmpeg_prefix_path ";" _ffmpeg_prefix_path_text)
    set(_ffmpeg_initial_cache
        "${FFMPEG_OFFICIAL_SMOKE_BINARY_DIR}/ffmpeg-consumer-prefix.cmake")
    file(WRITE "${_ffmpeg_initial_cache}"
        "set(CMAKE_PREFIX_PATH [==[${_ffmpeg_prefix_path_text}]==] CACHE STRING \"Consumer dependency prefixes\" FORCE)\n")

    set(_ffmpeg_configure_args
        -S "${FFMPEG_OFFICIAL_SMOKE_SOURCE_DIR}"
        -B "${FFMPEG_OFFICIAL_SMOKE_BINARY_DIR}"
        -G "${FFMPEG_OFFICIAL_SMOKE_GENERATOR}"
        -C "${_ffmpeg_initial_cache}"
        "-DFFmpeg_ROOT=${FFMPEG_OFFICIAL_SMOKE_INSTALL_PREFIX}"
        "-DFFmpeg_USE_STATIC_LIBS=${FFMPEG_OFFICIAL_SMOKE_USE_STATIC_LIBS}")

    if(FFMPEG_OFFICIAL_SMOKE_GENERATOR_PLATFORM)
        list(APPEND _ffmpeg_configure_args -A "${FFMPEG_OFFICIAL_SMOKE_GENERATOR_PLATFORM}")
    endif()
    if(FFMPEG_OFFICIAL_SMOKE_GENERATOR_TOOLSET)
        list(APPEND _ffmpeg_configure_args -T "${FFMPEG_OFFICIAL_SMOKE_GENERATOR_TOOLSET}")
    endif()
    if(FFMPEG_OFFICIAL_SMOKE_TOOLCHAIN_FILE)
        list(APPEND _ffmpeg_configure_args "-DCMAKE_TOOLCHAIN_FILE=${FFMPEG_OFFICIAL_SMOKE_TOOLCHAIN_FILE}")
    endif()
    if(FFMPEG_OFFICIAL_SMOKE_C_COMPILER)
        list(APPEND _ffmpeg_configure_args "-DCMAKE_C_COMPILER=${FFMPEG_OFFICIAL_SMOKE_C_COMPILER}")
    endif()
    if(NOT FFMPEG_OFFICIAL_SMOKE_MULTI_CONFIG AND FFMPEG_OFFICIAL_SMOKE_BUILD_TYPE)
        list(APPEND _ffmpeg_configure_args "-DCMAKE_BUILD_TYPE=${FFMPEG_OFFICIAL_SMOKE_BUILD_TYPE}")
    endif()

    _ffmpeg_official_smoke_run("consumer configure"
        "${CMAKE_COMMAND}"
        ${_ffmpeg_configure_args})

    set(_ffmpeg_build_args --build "${FFMPEG_OFFICIAL_SMOKE_BINARY_DIR}" --parallel)
    if(FFMPEG_OFFICIAL_SMOKE_MULTI_CONFIG AND FFMPEG_OFFICIAL_SMOKE_CONFIG)
        list(APPEND _ffmpeg_build_args --config "${FFMPEG_OFFICIAL_SMOKE_CONFIG}")
    endif()
    _ffmpeg_official_smoke_run("consumer build"
        "${CMAKE_COMMAND}"
        ${_ffmpeg_build_args})

    if(APPLE)
        set(_ffmpeg_runtime_env_name DYLD_LIBRARY_PATH)
        set(_ffmpeg_runtime_env_value "${FFMPEG_OFFICIAL_SMOKE_LIBRARY_DIR}:$ENV{DYLD_LIBRARY_PATH}")
    elseif(WIN32)
        set(_ffmpeg_runtime_env_name PATH)
        set(_ffmpeg_runtime_env_value "${FFMPEG_OFFICIAL_SMOKE_INSTALL_PREFIX}/bin;$ENV{PATH}")
    else()
        set(_ffmpeg_runtime_env_name LD_LIBRARY_PATH)
        set(_ffmpeg_runtime_env_value "${FFMPEG_OFFICIAL_SMOKE_LIBRARY_DIR}:$ENV{LD_LIBRARY_PATH}")
    endif()

    set(_ffmpeg_saved_runtime_env "$ENV{${_ffmpeg_runtime_env_name}}")
    set(ENV{${_ffmpeg_runtime_env_name}} "${_ffmpeg_runtime_env_value}")

    set(_ffmpeg_ctest_args
        --test-dir "${FFMPEG_OFFICIAL_SMOKE_BINARY_DIR}"
        --output-on-failure)
    if(FFMPEG_OFFICIAL_SMOKE_MULTI_CONFIG AND FFMPEG_OFFICIAL_SMOKE_CONFIG)
        list(APPEND _ffmpeg_ctest_args -C "${FFMPEG_OFFICIAL_SMOKE_CONFIG}")
    endif()
    _ffmpeg_official_smoke_run("consumer ctest"
        "${FFMPEG_OFFICIAL_SMOKE_CTEST_COMMAND}"
        ${_ffmpeg_ctest_args})

    set(ENV{${_ffmpeg_runtime_env_name}} "${_ffmpeg_saved_runtime_env}")
else()
    message(FATAL_ERROR "Unknown FFMPEG_OFFICIAL_SMOKE_MODE='${FFMPEG_OFFICIAL_SMOKE_MODE}'")
endif()
