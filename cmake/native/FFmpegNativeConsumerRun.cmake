function(_ffmpeg_consumer_run _step)
    execute_process(
        COMMAND ${ARGN}
        RESULT_VARIABLE _ffmpeg_result
        OUTPUT_VARIABLE _ffmpeg_stdout
        ERROR_VARIABLE _ffmpeg_stderr)
    if(NOT _ffmpeg_result EQUAL 0)
        message(STATUS "-- consumer ${_step} stdout:\n${_ffmpeg_stdout}")
        message(STATUS "-- consumer ${_step} stderr:\n${_ffmpeg_stderr}")
        message(FATAL_ERROR "consumer ${_step} failed with exit code ${_ffmpeg_result}")
    endif()
endfunction()

foreach(_ffmpeg_required_var IN ITEMS
        FFMPEG_CONSUMER_SOURCE_DIR
        FFMPEG_CONSUMER_PROJECT_BINARY_DIR
        FFMPEG_CONSUMER_INSTALL_PREFIX
        FFMPEG_CONSUMER_BINARY_DIR
        FFMPEG_CONSUMER_GENERATOR
        FFMPEG_CONSUMER_CTEST_COMMAND)
    if(NOT DEFINED ${_ffmpeg_required_var} OR "${${_ffmpeg_required_var}}" STREQUAL "")
        message(FATAL_ERROR "${_ffmpeg_required_var} is required")
    endif()
endforeach()

set(_ffmpeg_config "${FFMPEG_CONSUMER_CONFIG}")
if(_ffmpeg_config STREQUAL "$<CONFIG>")
    set(_ffmpeg_config)
endif()
if(NOT _ffmpeg_config AND FFMPEG_CONSUMER_MULTI_CONFIG)
    set(_ffmpeg_config Release)
endif()

set(_ffmpeg_install_config_args)
set(_ffmpeg_build_config_args)
set(_ffmpeg_ctest_config_args)
if(_ffmpeg_config)
    list(APPEND _ffmpeg_install_config_args --config "${_ffmpeg_config}")
    list(APPEND _ffmpeg_build_config_args --config "${_ffmpeg_config}")
    list(APPEND _ffmpeg_ctest_config_args -C "${_ffmpeg_config}")
endif()

file(REMOVE_RECURSE
    "${FFMPEG_CONSUMER_INSTALL_PREFIX}"
    "${FFMPEG_CONSUMER_BINARY_DIR}")
file(MAKE_DIRECTORY
    "${FFMPEG_CONSUMER_INSTALL_PREFIX}"
    "${FFMPEG_CONSUMER_BINARY_DIR}")

_ffmpeg_consumer_run("install"
    "${CMAKE_COMMAND}"
    --install "${FFMPEG_CONSUMER_PROJECT_BINARY_DIR}"
    --prefix "${FFMPEG_CONSUMER_INSTALL_PREFIX}"
    ${_ffmpeg_install_config_args})

set(_ffmpeg_consumer_prefix_path "${FFMPEG_CONSUMER_INSTALL_PREFIX}")
if(FFMPEG_CONSUMER_DEPENDENCY_PREFIX_PATH)
    list(APPEND _ffmpeg_consumer_prefix_path ${FFMPEG_CONSUMER_DEPENDENCY_PREFIX_PATH})
    list(REMOVE_DUPLICATES _ffmpeg_consumer_prefix_path)
endif()
list(JOIN _ffmpeg_consumer_prefix_path ";" _ffmpeg_consumer_prefix_path_text)

set(_ffmpeg_configure_args
    -S "${FFMPEG_CONSUMER_SOURCE_DIR}"
    -B "${FFMPEG_CONSUMER_BINARY_DIR}"
    -G "${FFMPEG_CONSUMER_GENERATOR}"
    "-DCMAKE_PREFIX_PATH=${_ffmpeg_consumer_prefix_path_text}"
    "-DFFmpeg_ROOT=${FFMPEG_CONSUMER_INSTALL_PREFIX}"
    "-DFFmpeg_USE_STATIC_LIBS=${FFMPEG_CONSUMER_USE_STATIC_LIBS}")

if(FFMPEG_CONSUMER_GENERATOR_PLATFORM)
    list(APPEND _ffmpeg_configure_args -A "${FFMPEG_CONSUMER_GENERATOR_PLATFORM}")
endif()
if(FFMPEG_CONSUMER_GENERATOR_TOOLSET)
    list(APPEND _ffmpeg_configure_args -T "${FFMPEG_CONSUMER_GENERATOR_TOOLSET}")
endif()
if(FFMPEG_CONSUMER_TOOLCHAIN_FILE)
    list(APPEND _ffmpeg_configure_args "-DCMAKE_TOOLCHAIN_FILE=${FFMPEG_CONSUMER_TOOLCHAIN_FILE}")
endif()
if(NOT FFMPEG_CONSUMER_MULTI_CONFIG AND FFMPEG_CONSUMER_BUILD_TYPE)
    list(APPEND _ffmpeg_configure_args "-DCMAKE_BUILD_TYPE=${FFMPEG_CONSUMER_BUILD_TYPE}")
endif()
if(FFMPEG_CONSUMER_MSVC_RUNTIME_LIBRARY)
    list(APPEND _ffmpeg_configure_args "-DCMAKE_MSVC_RUNTIME_LIBRARY=${FFMPEG_CONSUMER_MSVC_RUNTIME_LIBRARY}")
endif()
if(FFMPEG_CONSUMER_C_COMPILER)
    list(APPEND _ffmpeg_configure_args "-DCMAKE_C_COMPILER=${FFMPEG_CONSUMER_C_COMPILER}")
endif()

_ffmpeg_consumer_run("configure"
    "${CMAKE_COMMAND}"
    ${_ffmpeg_configure_args})

_ffmpeg_consumer_run("build"
    "${CMAKE_COMMAND}"
    --build "${FFMPEG_CONSUMER_BINARY_DIR}"
    ${_ffmpeg_build_config_args}
    --parallel)

if(WIN32)
    set(_ffmpeg_host_path "$ENV{PATH}")
    string(REPLACE ";" "\\;" _ffmpeg_host_path "${_ffmpeg_host_path}")
    set(_ffmpeg_path_var "PATH=${FFMPEG_CONSUMER_INSTALL_PREFIX}/bin\\;${_ffmpeg_host_path}")
elseif(APPLE)
    set(_ffmpeg_path_var "DYLD_LIBRARY_PATH=${FFMPEG_CONSUMER_INSTALL_PREFIX}/lib:$ENV{DYLD_LIBRARY_PATH}")
else()
    set(_ffmpeg_path_var "LD_LIBRARY_PATH=${FFMPEG_CONSUMER_INSTALL_PREFIX}/lib:$ENV{LD_LIBRARY_PATH}")
endif()

_ffmpeg_consumer_run("ctest"
    "${CMAKE_COMMAND}" -E env "${_ffmpeg_path_var}"
    "${FFMPEG_CONSUMER_CTEST_COMMAND}"
    --test-dir "${FFMPEG_CONSUMER_BINARY_DIR}"
    ${_ffmpeg_ctest_config_args}
    --output-on-failure)
