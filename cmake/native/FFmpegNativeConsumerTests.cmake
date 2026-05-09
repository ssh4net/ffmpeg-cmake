option(FFMPEG_NATIVE_ENABLE_CONSUMER_TESTS "Add CTest tests that install native FFmpeg and build a separate CMake consumer against the installed package." ON)
set(FFMPEG_NATIVE_CONSUMER_TEST_TIMEOUT 180 CACHE STRING "Timeout in seconds for each native installed-package consumer test.")

function(ffmpeg_native_add_consumer_tests)
    if(NOT FFMPEG_NATIVE_ENABLE_CONSUMER_TESTS)
        set(FFMPEG_NATIVE_SMOKE_TESTS "${FFMPEG_NATIVE_SMOKE_TESTS}" PARENT_SCOPE)
        return()
    endif()

    set(_ffmpeg_multi_config OFF)
    if(CMAKE_CONFIGURATION_TYPES)
        set(_ffmpeg_multi_config ON)
    endif()

    set(_ffmpeg_consumer_name ffmpeg-native.consumer.installed)
    set(_ffmpeg_consumer_install_prefix "${CMAKE_CURRENT_BINARY_DIR}/ffmpeg-native/consumer/install/$<CONFIG>")
    set(_ffmpeg_consumer_binary_dir "${CMAKE_CURRENT_BINARY_DIR}/ffmpeg-native/consumer/build/$<CONFIG>")
    if(NOT CMAKE_CONFIGURATION_TYPES)
        set(_ffmpeg_consumer_install_prefix "${CMAKE_CURRENT_BINARY_DIR}/ffmpeg-native/consumer/install")
        set(_ffmpeg_consumer_binary_dir "${CMAKE_CURRENT_BINARY_DIR}/ffmpeg-native/consumer/build")
    endif()
    set(_ffmpeg_consumer_dependency_prefix_path "${CMAKE_PREFIX_PATH}")
    string(REPLACE ";" "\\;" _ffmpeg_consumer_dependency_prefix_path "${_ffmpeg_consumer_dependency_prefix_path}")

    add_test(NAME "${_ffmpeg_consumer_name}"
        COMMAND "${CMAKE_COMMAND}"
            "-DFFMPEG_CONSUMER_SOURCE_DIR=${PROJECT_SOURCE_DIR}/examples/consumer-smoke"
            "-DFFMPEG_CONSUMER_PROJECT_BINARY_DIR=${CMAKE_CURRENT_BINARY_DIR}"
            "-DFFMPEG_CONSUMER_INSTALL_PREFIX=${_ffmpeg_consumer_install_prefix}"
            "-DFFMPEG_CONSUMER_BINARY_DIR=${_ffmpeg_consumer_binary_dir}"
            "-DFFMPEG_CONSUMER_DEPENDENCY_PREFIX_PATH=${_ffmpeg_consumer_dependency_prefix_path}"
            "-DFFMPEG_CONSUMER_GENERATOR=${CMAKE_GENERATOR}"
            "-DFFMPEG_CONSUMER_GENERATOR_PLATFORM=${CMAKE_GENERATOR_PLATFORM}"
            "-DFFMPEG_CONSUMER_GENERATOR_TOOLSET=${CMAKE_GENERATOR_TOOLSET}"
            "-DFFMPEG_CONSUMER_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}"
            "-DFFMPEG_CONSUMER_BUILD_TYPE=${CMAKE_BUILD_TYPE}"
            "-DFFMPEG_CONSUMER_CONFIG=$<CONFIG>"
            "-DFFMPEG_CONSUMER_MULTI_CONFIG=${_ffmpeg_multi_config}"
            "-DFFMPEG_CONSUMER_USE_STATIC_LIBS=${FFMPEG_BUILD_STATIC}"
            "-DFFMPEG_CONSUMER_MSVC_RUNTIME_LIBRARY=${CMAKE_MSVC_RUNTIME_LIBRARY}"
            "-DFFMPEG_CONSUMER_C_COMPILER=${CMAKE_C_COMPILER}"
            "-DFFMPEG_CONSUMER_CTEST_COMMAND=${CMAKE_CTEST_COMMAND}"
            -P "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/FFmpegNativeConsumerRun.cmake")
    set_tests_properties("${_ffmpeg_consumer_name}" PROPERTIES
        LABELS "ffmpeg;native;smoke;consumer-smoke"
        TIMEOUT "${FFMPEG_NATIVE_CONSUMER_TEST_TIMEOUT}")

    list(APPEND FFMPEG_NATIVE_SMOKE_TESTS "${_ffmpeg_consumer_name}")
    list(REMOVE_DUPLICATES FFMPEG_NATIVE_SMOKE_TESTS)
    list(SORT FFMPEG_NATIVE_SMOKE_TESTS)
    set(FFMPEG_NATIVE_SMOKE_TESTS "${FFMPEG_NATIVE_SMOKE_TESTS}" PARENT_SCOPE)
endfunction()
