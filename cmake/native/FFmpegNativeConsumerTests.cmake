option(FFMPEG_NATIVE_ENABLE_CONSUMER_TESTS "Add CTest tests that install native FFmpeg and build a separate CMake consumer against the installed package." ON)
set(FFMPEG_NATIVE_CONSUMER_TEST_TIMEOUT 180 CACHE STRING "Timeout in seconds for each native installed-package consumer test.")

if(FFMPEG_NATIVE_ENABLE_CONSUMER_TESTS)
    enable_testing()
endif()

function(ffmpeg_native_add_consumer_tests)
    if(NOT FFMPEG_NATIVE_ENABLE_CONSUMER_TESTS)
        set(FFMPEG_NATIVE_SMOKE_TESTS "${FFMPEG_NATIVE_SMOKE_TESTS}" PARENT_SCOPE)
        return()
    endif()

    set(_ffmpeg_multi_config OFF)
    get_property(_ffmpeg_consumer_build_type CACHE CMAKE_BUILD_TYPE PROPERTY VALUE)
    set(_ffmpeg_consumer_config "${_ffmpeg_consumer_build_type}")
    if(CMAKE_CONFIGURATION_TYPES)
        set(_ffmpeg_multi_config ON)
        set(_ffmpeg_consumer_build_type)
        set(_ffmpeg_consumer_config "$<CONFIG>")
    endif()

    if(FFMPEG_BUILD_SHARED)
        set(_ffmpeg_consumer_linkage shared)
    else()
        set(_ffmpeg_consumer_linkage static)
    endif()
    set(_ffmpeg_consumer_name "ffmpeg-native.consumer.installed.${_ffmpeg_consumer_linkage}")
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
            "-DFFMPEG_CONSUMER_BUILD_TYPE=${_ffmpeg_consumer_build_type}"
            "-DFFMPEG_CONSUMER_CONFIG=${_ffmpeg_consumer_config}"
            "-DFFMPEG_CONSUMER_MULTI_CONFIG=${_ffmpeg_multi_config}"
            "-DFFMPEG_CONSUMER_USE_STATIC_LIBS=${FFMPEG_BUILD_STATIC}"
            "-DFFMPEG_CONSUMER_MSVC_RUNTIME_LIBRARY=${CMAKE_MSVC_RUNTIME_LIBRARY}"
            "-DFFMPEG_CONSUMER_C_COMPILER=${CMAKE_C_COMPILER}"
            "-DFFMPEG_CONSUMER_CTEST_COMMAND=${CMAKE_CTEST_COMMAND}"
            -P "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/FFmpegNativeConsumerRun.cmake")
    set_tests_properties("${_ffmpeg_consumer_name}" PROPERTIES
        LABELS "ffmpeg;native;smoke;consumer-smoke;consumer-${_ffmpeg_consumer_linkage}"
        TIMEOUT "${FFMPEG_NATIVE_CONSUMER_TEST_TIMEOUT}")

    list(APPEND FFMPEG_NATIVE_SMOKE_TESTS "${_ffmpeg_consumer_name}")

    if(_ffmpeg_multi_config)
        list(FIND CMAKE_CONFIGURATION_TYPES Debug _ffmpeg_has_debug_config)
        list(FIND CMAKE_CONFIGURATION_TYPES Release _ffmpeg_has_release_config)
        if(NOT _ffmpeg_has_debug_config EQUAL -1 AND NOT _ffmpeg_has_release_config EQUAL -1)
            set(_ffmpeg_consumer_same_prefix_name "ffmpeg-native.consumer.installed.same-prefix.${_ffmpeg_consumer_linkage}")
            set(_ffmpeg_consumer_same_prefix_install_prefix "${CMAKE_CURRENT_BINARY_DIR}/ffmpeg-native/consumer/same-prefix/install")
            set(_ffmpeg_consumer_same_prefix_binary_dir "${CMAKE_CURRENT_BINARY_DIR}/ffmpeg-native/consumer/same-prefix/build")
            set(_ffmpeg_consumer_same_prefix_msvc_runtime "${CMAKE_MSVC_RUNTIME_LIBRARY}")
            set(_ffmpeg_consumer_same_prefix_default_static_runtime OFF)
            if(_ffmpeg_consumer_same_prefix_msvc_runtime MATCHES "\\$<")
                set(_ffmpeg_consumer_same_prefix_msvc_runtime)
                set(_ffmpeg_consumer_same_prefix_default_static_runtime ON)
            endif()
            add_test(NAME "${_ffmpeg_consumer_same_prefix_name}"
                COMMAND "${CMAKE_COMMAND}"
                    "-DFFMPEG_CONSUMER_SOURCE_DIR=${PROJECT_SOURCE_DIR}/examples/consumer-smoke"
                    "-DFFMPEG_CONSUMER_PROJECT_BINARY_DIR=${CMAKE_CURRENT_BINARY_DIR}"
                    "-DFFMPEG_CONSUMER_INSTALL_PREFIX=${_ffmpeg_consumer_same_prefix_install_prefix}"
                    "-DFFMPEG_CONSUMER_BINARY_DIR=${_ffmpeg_consumer_same_prefix_binary_dir}"
                    "-DFFMPEG_CONSUMER_DEPENDENCY_PREFIX_PATH=${_ffmpeg_consumer_dependency_prefix_path}"
                    "-DFFMPEG_CONSUMER_GENERATOR=${CMAKE_GENERATOR}"
                    "-DFFMPEG_CONSUMER_GENERATOR_PLATFORM=${CMAKE_GENERATOR_PLATFORM}"
                    "-DFFMPEG_CONSUMER_GENERATOR_TOOLSET=${CMAKE_GENERATOR_TOOLSET}"
                    "-DFFMPEG_CONSUMER_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}"
                    "-DFFMPEG_CONSUMER_CONFIG=Release"
                    "-DFFMPEG_CONSUMER_INSTALL_CONFIGS=Release\\;Debug"
                    "-DFFMPEG_CONSUMER_BUILD_CONFIGS=Release\\;Debug"
                    "-DFFMPEG_CONSUMER_MULTI_CONFIG=${_ffmpeg_multi_config}"
                    "-DFFMPEG_CONSUMER_USE_STATIC_LIBS=${FFMPEG_BUILD_STATIC}"
                    "-DFFMPEG_CONSUMER_MSVC_RUNTIME_LIBRARY=${_ffmpeg_consumer_same_prefix_msvc_runtime}"
                    "-DFFMPEG_CONSUMER_DEFAULT_STATIC_MSVC_RUNTIME=${_ffmpeg_consumer_same_prefix_default_static_runtime}"
                    "-DFFMPEG_CONSUMER_C_COMPILER=${CMAKE_C_COMPILER}"
                    "-DFFMPEG_CONSUMER_CTEST_COMMAND=${CMAKE_CTEST_COMMAND}"
                    -P "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/FFmpegNativeConsumerRun.cmake")
            math(EXPR _ffmpeg_same_prefix_timeout "${FFMPEG_NATIVE_CONSUMER_TEST_TIMEOUT} * 2")
            set_tests_properties("${_ffmpeg_consumer_same_prefix_name}" PROPERTIES
                LABELS "ffmpeg;native;smoke;consumer-smoke;consumer-${_ffmpeg_consumer_linkage};consumer-same-prefix"
                TIMEOUT "${_ffmpeg_same_prefix_timeout}")
            list(APPEND FFMPEG_NATIVE_SMOKE_TESTS "${_ffmpeg_consumer_same_prefix_name}")
        endif()
    endif()

    list(REMOVE_DUPLICATES FFMPEG_NATIVE_SMOKE_TESTS)
    list(SORT FFMPEG_NATIVE_SMOKE_TESTS)
    set(FFMPEG_NATIVE_SMOKE_TESTS "${FFMPEG_NATIVE_SMOKE_TESTS}" PARENT_SCOPE)
endfunction()
