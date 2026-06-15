include_guard(GLOBAL)

set(FFMPEG_OFFICIAL_SMOKE_TEST_TIMEOUT 180 CACHE STRING "Timeout in seconds for each official configure backend smoke test.")

function(_ffmpeg_official_add_tool_test _tests_var _name _executable _args _expect_regex)
    add_test(NAME "${_name}"
        COMMAND "${CMAKE_COMMAND}"
            "-DFFMPEG_OFFICIAL_SMOKE_MODE=tool"
            "-DFFMPEG_OFFICIAL_SMOKE_EXECUTABLE=${_executable}"
            "-DFFMPEG_OFFICIAL_SMOKE_ARGS=${_args}"
            "-DFFMPEG_OFFICIAL_SMOKE_EXPECT_REGEX=${_expect_regex}"
            "-DFFMPEG_OFFICIAL_SMOKE_TIMEOUT=${FFMPEG_OFFICIAL_SMOKE_TEST_TIMEOUT}"
            -P "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/FFmpegOfficialSmokeRun.cmake")
    set_tests_properties("${_name}" PROPERTIES
        LABELS "ffmpeg;official;smoke"
        TIMEOUT "${FFMPEG_OFFICIAL_SMOKE_TEST_TIMEOUT}")
    list(APPEND ${_tests_var} "${_name}")
    set(${_tests_var} "${${_tests_var}}" PARENT_SCOPE)
endfunction()

function(ffmpeg_official_add_smoke_tests)
    set(FFMPEG_OFFICIAL_SMOKE_TESTS)
    if(NOT FFMPEG_BUILD_SMOKE_TEST)
        set(FFMPEG_OFFICIAL_SMOKE_TESTS "${FFMPEG_OFFICIAL_SMOKE_TESTS}" PARENT_SCOPE)
        return()
    endif()

    enable_testing()

    set(_ffmpeg_dependency_prefix_path "${CMAKE_PREFIX_PATH}")
    string(REPLACE ";" "\\;" _ffmpeg_dependency_prefix_path "${_ffmpeg_dependency_prefix_path}")
    if(CMAKE_CONFIGURATION_TYPES)
        set(_ffmpeg_multi_config ON)
        set(_ffmpeg_config "$<CONFIG>")
    else()
        set(_ffmpeg_multi_config OFF)
        set(_ffmpeg_config)
    endif()

    set(_ffmpeg_consumer_name "ffmpeg-official.consumer.installed")
    add_test(NAME "${_ffmpeg_consumer_name}"
        COMMAND "${CMAKE_COMMAND}"
            "-DFFMPEG_OFFICIAL_SMOKE_MODE=consumer"
            "-DFFMPEG_OFFICIAL_SMOKE_SOURCE_DIR=${PROJECT_SOURCE_DIR}/examples/consumer-smoke"
            "-DFFMPEG_OFFICIAL_SMOKE_BINARY_DIR=${CMAKE_CURRENT_BINARY_DIR}/ffmpeg-official/consumer/build"
            "-DFFMPEG_OFFICIAL_SMOKE_INSTALL_PREFIX=${FFMPEG_INSTALL_PREFIX}"
            "-DFFMPEG_OFFICIAL_SMOKE_PKGCONFIG_DIR=${FFMPEG_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBDIR}/pkgconfig"
            "-DFFMPEG_OFFICIAL_SMOKE_LIBRARY_DIR=${FFMPEG_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBDIR}"
            "-DFFMPEG_OFFICIAL_SMOKE_DEPENDENCY_PREFIX_PATH=${_ffmpeg_dependency_prefix_path}"
            "-DFFMPEG_OFFICIAL_SMOKE_GENERATOR=${CMAKE_GENERATOR}"
            "-DFFMPEG_OFFICIAL_SMOKE_GENERATOR_PLATFORM=${CMAKE_GENERATOR_PLATFORM}"
            "-DFFMPEG_OFFICIAL_SMOKE_GENERATOR_TOOLSET=${CMAKE_GENERATOR_TOOLSET}"
            "-DFFMPEG_OFFICIAL_SMOKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}"
            "-DFFMPEG_OFFICIAL_SMOKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}"
            "-DFFMPEG_OFFICIAL_SMOKE_CONFIG=${_ffmpeg_config}"
            "-DFFMPEG_OFFICIAL_SMOKE_MULTI_CONFIG=${_ffmpeg_multi_config}"
            "-DFFMPEG_OFFICIAL_SMOKE_USE_STATIC_LIBS=${FFMPEG_BUILD_STATIC}"
            "-DFFMPEG_OFFICIAL_SMOKE_C_COMPILER=${CMAKE_C_COMPILER}"
            "-DFFMPEG_OFFICIAL_SMOKE_CTEST_COMMAND=${CMAKE_CTEST_COMMAND}"
            "-DFFMPEG_OFFICIAL_SMOKE_TIMEOUT=${FFMPEG_OFFICIAL_SMOKE_TEST_TIMEOUT}"
            -P "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/FFmpegOfficialSmokeRun.cmake")
    set_tests_properties("${_ffmpeg_consumer_name}" PROPERTIES
        LABELS "ffmpeg;official;smoke;consumer-smoke"
        TIMEOUT "${FFMPEG_OFFICIAL_SMOKE_TEST_TIMEOUT}")
    list(APPEND FFMPEG_OFFICIAL_SMOKE_TESTS "${_ffmpeg_consumer_name}")

    if(FFMPEG_BUILD_PROGRAMS)
        set(_ffmpeg_bin_dir "${FFMPEG_INSTALL_PREFIX}/bin")
        _ffmpeg_official_add_tool_test(FFMPEG_OFFICIAL_SMOKE_TESTS
            ffmpeg-official.ffmpeg.version
            "${_ffmpeg_bin_dir}/ffmpeg"
            "-hide_banner -version"
            "ffmpeg version")
        _ffmpeg_official_add_tool_test(FFMPEG_OFFICIAL_SMOKE_TESTS
            ffmpeg-official.ffmpeg.hwaccels
            "${_ffmpeg_bin_dir}/ffmpeg"
            "-hide_banner -hwaccels"
            "Hardware acceleration methods")
        _ffmpeg_official_add_tool_test(FFMPEG_OFFICIAL_SMOKE_TESTS
            ffmpeg-official.ffmpeg.encoders
            "${_ffmpeg_bin_dir}/ffmpeg"
            "-hide_banner -encoders"
            "Encoders")
        _ffmpeg_official_add_tool_test(FFMPEG_OFFICIAL_SMOKE_TESTS
            ffmpeg-official.ffprobe.version
            "${_ffmpeg_bin_dir}/ffprobe"
            "-hide_banner -version"
            "ffprobe version")

        if(APPLE AND FFMPEG_APPLE_VIDEOTOOLBOX_AVAILABLE)
            _ffmpeg_official_add_tool_test(FFMPEG_OFFICIAL_SMOKE_TESTS
                ffmpeg-official.ffmpeg.hwaccels.videotoolbox
                "${_ffmpeg_bin_dir}/ffmpeg"
                "-hide_banner -hwaccels"
                "(^|[\r\n])videotoolbox([\r\n]|$)")
            _ffmpeg_official_add_tool_test(FFMPEG_OFFICIAL_SMOKE_TESTS
                ffmpeg-official.ffmpeg.encoders.videotoolbox
                "${_ffmpeg_bin_dir}/ffmpeg"
                "-hide_banner -encoders"
                "(h264|hevc|prores)_videotoolbox")
        endif()
    endif()

    list(REMOVE_DUPLICATES FFMPEG_OFFICIAL_SMOKE_TESTS)
    list(SORT FFMPEG_OFFICIAL_SMOKE_TESTS)
    set(FFMPEG_OFFICIAL_SMOKE_TESTS "${FFMPEG_OFFICIAL_SMOKE_TESTS}" PARENT_SCOPE)
endfunction()
