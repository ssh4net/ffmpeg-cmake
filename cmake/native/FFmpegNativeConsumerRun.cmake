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
set(_ffmpeg_install_configs)
set(_ffmpeg_build_configs)
if(DEFINED FFMPEG_CONSUMER_INSTALL_CONFIGS AND NOT "${FFMPEG_CONSUMER_INSTALL_CONFIGS}" STREQUAL "")
    set(_ffmpeg_install_configs ${FFMPEG_CONSUMER_INSTALL_CONFIGS})
elseif(_ffmpeg_config)
    set(_ffmpeg_install_configs "${_ffmpeg_config}")
endif()
if(DEFINED FFMPEG_CONSUMER_BUILD_CONFIGS AND NOT "${FFMPEG_CONSUMER_BUILD_CONFIGS}" STREQUAL "")
    set(_ffmpeg_build_configs ${FFMPEG_CONSUMER_BUILD_CONFIGS})
elseif(_ffmpeg_config)
    set(_ffmpeg_build_configs "${_ffmpeg_config}")
endif()
if(_ffmpeg_config)
    list(APPEND _ffmpeg_install_config_args --config "${_ffmpeg_config}")
endif()

file(REMOVE_RECURSE
    "${FFMPEG_CONSUMER_INSTALL_PREFIX}"
    "${FFMPEG_CONSUMER_BINARY_DIR}")
file(MAKE_DIRECTORY
    "${FFMPEG_CONSUMER_INSTALL_PREFIX}"
    "${FFMPEG_CONSUMER_BINARY_DIR}")

if(_ffmpeg_install_configs)
    foreach(_ffmpeg_install_config IN LISTS _ffmpeg_install_configs)
        _ffmpeg_consumer_run("install ${_ffmpeg_install_config}"
            "${CMAKE_COMMAND}"
            --install "${FFMPEG_CONSUMER_PROJECT_BINARY_DIR}"
            --prefix "${FFMPEG_CONSUMER_INSTALL_PREFIX}"
            --config "${_ffmpeg_install_config}")
    endforeach()
else()
    _ffmpeg_consumer_run("install"
        "${CMAKE_COMMAND}"
        --install "${FFMPEG_CONSUMER_PROJECT_BINARY_DIR}"
        --prefix "${FFMPEG_CONSUMER_INSTALL_PREFIX}"
        ${_ffmpeg_install_config_args})
endif()

set(_ffmpeg_consumer_prefix_path "${FFMPEG_CONSUMER_INSTALL_PREFIX}")
if(FFMPEG_CONSUMER_DEPENDENCY_PREFIX_PATH)
    list(APPEND _ffmpeg_consumer_prefix_path ${FFMPEG_CONSUMER_DEPENDENCY_PREFIX_PATH})
    list(REMOVE_DUPLICATES _ffmpeg_consumer_prefix_path)
endif()
list(JOIN _ffmpeg_consumer_prefix_path ";" _ffmpeg_consumer_prefix_path_text)
string(REPLACE ";" "\\;" _ffmpeg_consumer_prefix_path_text "${_ffmpeg_consumer_prefix_path_text}")

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
if(FFMPEG_CONSUMER_DEFAULT_STATIC_MSVC_RUNTIME AND
   FFMPEG_CONSUMER_USE_STATIC_LIBS AND
   NOT FFMPEG_CONSUMER_MSVC_RUNTIME_LIBRARY)
    set(FFMPEG_CONSUMER_MSVC_RUNTIME_LIBRARY "$<$<CONFIG:Debug>:MultiThreadedDebug>$<$<CONFIG:Release>:MultiThreaded>")
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

if(WIN32)
    set(_ffmpeg_runtime_env_name PATH)
    set(_ffmpeg_runtime_env_value "${FFMPEG_CONSUMER_INSTALL_PREFIX}/bin;$ENV{PATH}")
elseif(APPLE)
    set(_ffmpeg_runtime_env_name DYLD_LIBRARY_PATH)
    set(_ffmpeg_runtime_env_value "${FFMPEG_CONSUMER_INSTALL_PREFIX}/lib:$ENV{DYLD_LIBRARY_PATH}")
else()
    set(_ffmpeg_runtime_env_name LD_LIBRARY_PATH)
    set(_ffmpeg_runtime_env_value "${FFMPEG_CONSUMER_INSTALL_PREFIX}/lib:$ENV{LD_LIBRARY_PATH}")
endif()

set(_ffmpeg_saved_runtime_env "$ENV{${_ffmpeg_runtime_env_name}}")
set(ENV{${_ffmpeg_runtime_env_name}} "${_ffmpeg_runtime_env_value}")

if(_ffmpeg_build_configs)
    foreach(_ffmpeg_build_config IN LISTS _ffmpeg_build_configs)
        _ffmpeg_consumer_run("build ${_ffmpeg_build_config}"
            "${CMAKE_COMMAND}"
            --build "${FFMPEG_CONSUMER_BINARY_DIR}"
            --config "${_ffmpeg_build_config}"
            --parallel)

        _ffmpeg_consumer_run("ctest ${_ffmpeg_build_config}"
            "${FFMPEG_CONSUMER_CTEST_COMMAND}"
            --test-dir "${FFMPEG_CONSUMER_BINARY_DIR}"
            -C "${_ffmpeg_build_config}"
            --output-on-failure)
    endforeach()
else()
    _ffmpeg_consumer_run("build"
        "${CMAKE_COMMAND}"
        --build "${FFMPEG_CONSUMER_BINARY_DIR}"
        --parallel)

    _ffmpeg_consumer_run("ctest"
        "${FFMPEG_CONSUMER_CTEST_COMMAND}"
        --test-dir "${FFMPEG_CONSUMER_BINARY_DIR}"
        --output-on-failure)
endif()

set(ENV{${_ffmpeg_runtime_env_name}} "${_ffmpeg_saved_runtime_env}")
