include_guard(GLOBAL)

option(FFMPEG_NATIVE_ENABLE_SMOKE_TESTS "Add query-only CTest smoke tests for native FFmpeg tools and hardware registrations." ON)
set(FFMPEG_NATIVE_SMOKE_TEST_TIMEOUT 30 CACHE STRING "Timeout in seconds for each native FFmpeg smoke test.")
option(FFMPEG_NATIVE_ENABLE_HARDWARE_SMOKE_TESTS "Add opt-in CTest tests that execute tiny hardware encode/decode jobs. These require matching GPU drivers at test time." OFF)
set(FFMPEG_NATIVE_HARDWARE_SMOKE_TEST_TIMEOUT 60 CACHE STRING "Timeout in seconds for each native FFmpeg hardware execution smoke test.")

if(FFMPEG_NATIVE_ENABLE_SMOKE_TESTS OR FFMPEG_NATIVE_ENABLE_HARDWARE_SMOKE_TESTS)
    enable_testing()
endif()

function(_ffmpeg_native_smoke_environment_modifications _out _target)
    set(_ffmpeg_env
        "PATH=path_list_prepend:$<TARGET_FILE_DIR:${_target}>")

    foreach(_ffmpeg_prefix IN LISTS CMAKE_PREFIX_PATH FFMPEG_INSTALL_PREFIX CMAKE_INSTALL_PREFIX)
        if(_ffmpeg_prefix STREQUAL "")
            continue()
        endif()
        foreach(_ffmpeg_suffix IN ITEMS bin lib)
            if(IS_DIRECTORY "${_ffmpeg_prefix}/${_ffmpeg_suffix}")
                file(TO_CMAKE_PATH "${_ffmpeg_prefix}/${_ffmpeg_suffix}" _ffmpeg_runtime_dir)
                list(APPEND _ffmpeg_env "PATH=path_list_prepend:${_ffmpeg_runtime_dir}")
            endif()
        endforeach()
    endforeach()

    set(${_out} "${_ffmpeg_env}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_add_smoke_test _tests_var _name _target)
    if(NOT TARGET "${_target}")
        set(${_tests_var} "${${_tests_var}}" PARENT_SCOPE)
        return()
    endif()

    add_test(NAME "${_name}" COMMAND "$<TARGET_FILE:${_target}>" ${ARGN})
    _ffmpeg_native_smoke_environment_modifications(_ffmpeg_env "${_target}")
    set_tests_properties("${_name}" PROPERTIES
        LABELS "ffmpeg;native;smoke"
        ENVIRONMENT_MODIFICATION "${_ffmpeg_env}"
        TIMEOUT "${FFMPEG_NATIVE_SMOKE_TEST_TIMEOUT}")
    list(APPEND ${_tests_var} "${_name}")
    set(${_tests_var} "${${_tests_var}}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_add_component_help_test _tests_var _component _kind _target _ffmpeg_name)
    if(NOT "${_component}" IN_LIST FFMPEG_NATIVE_ENABLED_COMPONENT_FEATURES)
        set(${_tests_var} "${${_tests_var}}" PARENT_SCOPE)
        return()
    endif()

    _ffmpeg_native_add_smoke_test(${_tests_var}
        "ffmpeg-native.help.${_kind}.${_ffmpeg_name}"
        "${_target}"
        -hide_banner -h "${_kind}=${_ffmpeg_name}")
    set(${_tests_var} "${${_tests_var}}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_set_smoke_test_runtime _name _target _labels _timeout)
    _ffmpeg_native_smoke_environment_modifications(_ffmpeg_env "${_target}")
    math(EXPR _ffmpeg_ctest_timeout "${_timeout} + 10")
    set_tests_properties("${_name}" PROPERTIES
        LABELS "${_labels}"
        ENVIRONMENT_MODIFICATION "${_ffmpeg_env}"
        TIMEOUT "${_ffmpeg_ctest_timeout}")
    if(_labels MATCHES "(^|;)hardware-smoke(;|$)")
        set_tests_properties("${_name}" PROPERTIES
            SKIP_REGULAR_EXPRESSION "FFMPEG_HW_SMOKE_SKIP")
    endif()
endfunction()

function(_ffmpeg_native_component_enabled _out _component)
    if("${_component}" IN_LIST FFMPEG_NATIVE_ENABLED_COMPONENT_FEATURES)
        set(${_out} TRUE PARENT_SCOPE)
    else()
        set(${_out} FALSE PARENT_SCOPE)
    endif()
endfunction()

function(_ffmpeg_native_add_hardware_encoder_test _tests_var _component _encoder)
    set(_ffmpeg_hwdevice)
    set(_ffmpeg_filter_hwdevice)
    if(ARGC GREATER 3)
        set(_ffmpeg_hwdevice "${ARGV3}")
    endif()
    if(ARGC GREATER 4)
        set(_ffmpeg_filter_hwdevice "${ARGV4}")
    endif()

    if(NOT TARGET ffmpeg)
        set(${_tests_var} "${${_tests_var}}" PARENT_SCOPE)
        return()
    endif()
    _ffmpeg_native_component_enabled(_ffmpeg_component_enabled "${_component}")
    if(NOT _ffmpeg_component_enabled)
        set(${_tests_var} "${${_tests_var}}" PARENT_SCOPE)
        return()
    endif()

    set(_ffmpeg_hwdevice_args)
    if(_ffmpeg_hwdevice)
        list(APPEND _ffmpeg_hwdevice_args "-DFFMPEG_SMOKE_HWDEVICE=${_ffmpeg_hwdevice}")
    endif()
    if(_ffmpeg_filter_hwdevice)
        list(APPEND _ffmpeg_hwdevice_args "-DFFMPEG_SMOKE_FILTER_HWDEVICE=${_ffmpeg_filter_hwdevice}")
    endif()

    set(_ffmpeg_name "ffmpeg-native.hw.encode.${_encoder}")
    add_test(NAME "${_ffmpeg_name}"
        COMMAND "${CMAKE_COMMAND}"
            "-DFFMPEG_SMOKE_MODE=encoder"
            "-DFFMPEG_SMOKE_FFMPEG=$<TARGET_FILE:ffmpeg>"
            "-DFFMPEG_SMOKE_ENCODER=${_encoder}"
            "-DFFMPEG_SMOKE_TIMEOUT=${FFMPEG_NATIVE_HARDWARE_SMOKE_TEST_TIMEOUT}"
            "-DFFMPEG_SMOKE_WORK_DIR=${CMAKE_CURRENT_BINARY_DIR}/ffmpeg-native/smoke"
            ${_ffmpeg_hwdevice_args}
            -P "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/FFmpegNativeSmokeRun.cmake")
    _ffmpeg_native_set_smoke_test_runtime("${_ffmpeg_name}" ffmpeg "ffmpeg;native;hardware-smoke" "${FFMPEG_NATIVE_HARDWARE_SMOKE_TEST_TIMEOUT}")
    list(APPEND ${_tests_var} "${_ffmpeg_name}")
    set(${_tests_var} "${${_tests_var}}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_add_hardware_decoder_test _tests_var _decoder_component _decoder _generator_component _generator _container)
    if(NOT TARGET ffmpeg)
        set(${_tests_var} "${${_tests_var}}" PARENT_SCOPE)
        return()
    endif()
    _ffmpeg_native_component_enabled(_ffmpeg_decoder_enabled "${_decoder_component}")
    _ffmpeg_native_component_enabled(_ffmpeg_generator_enabled "${_generator_component}")
    if(NOT _ffmpeg_decoder_enabled OR NOT _ffmpeg_generator_enabled)
        set(${_tests_var} "${${_tests_var}}" PARENT_SCOPE)
        return()
    endif()

    set(_ffmpeg_name "ffmpeg-native.hw.decode.${_decoder}")
    add_test(NAME "${_ffmpeg_name}"
        COMMAND "${CMAKE_COMMAND}"
            "-DFFMPEG_SMOKE_MODE=decoder"
            "-DFFMPEG_SMOKE_FFMPEG=$<TARGET_FILE:ffmpeg>"
            "-DFFMPEG_SMOKE_DECODER=${_decoder}"
            "-DFFMPEG_SMOKE_ENCODER=${_generator}"
            "-DFFMPEG_SMOKE_CONTAINER=${_container}"
            "-DFFMPEG_SMOKE_TIMEOUT=${FFMPEG_NATIVE_HARDWARE_SMOKE_TEST_TIMEOUT}"
            "-DFFMPEG_SMOKE_WORK_DIR=${CMAKE_CURRENT_BINARY_DIR}/ffmpeg-native/smoke"
            -P "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/FFmpegNativeSmokeRun.cmake")
    _ffmpeg_native_set_smoke_test_runtime("${_ffmpeg_name}" ffmpeg "ffmpeg;native;hardware-smoke" "${FFMPEG_NATIVE_HARDWARE_SMOKE_TEST_TIMEOUT}")
    list(APPEND ${_tests_var} "${_ffmpeg_name}")
    set(${_tests_var} "${${_tests_var}}" PARENT_SCOPE)
endfunction()

function(ffmpeg_native_add_hardware_smoke_tests)
    set(FFMPEG_NATIVE_HARDWARE_SMOKE_TESTS)
    if(NOT FFMPEG_NATIVE_ENABLE_HARDWARE_SMOKE_TESTS)
        set(FFMPEG_NATIVE_HARDWARE_SMOKE_TESTS "${FFMPEG_NATIVE_HARDWARE_SMOKE_TESTS}" PARENT_SCOPE)
        return()
    endif()

    foreach(_ffmpeg_pair IN ITEMS
            av1_nvenc_encoder:av1_nvenc
            h264_nvenc_encoder:h264_nvenc
            hevc_nvenc_encoder:hevc_nvenc
            av1_amf_encoder:av1_amf
            h264_amf_encoder:h264_amf
            hevc_amf_encoder:hevc_amf
            h264_qsv_encoder:h264_qsv
            hevc_qsv_encoder:hevc_qsv
            vp9_qsv_encoder:vp9_qsv)
        string(REPLACE ":" ";" _ffmpeg_parts "${_ffmpeg_pair}")
        list(GET _ffmpeg_parts 0 _ffmpeg_component)
        list(GET _ffmpeg_parts 1 _ffmpeg_encoder)
        _ffmpeg_native_add_hardware_encoder_test(FFMPEG_NATIVE_HARDWARE_SMOKE_TESTS
            "${_ffmpeg_component}" "${_ffmpeg_encoder}")
    endforeach()

    _ffmpeg_native_add_hardware_encoder_test(FFMPEG_NATIVE_HARDWARE_SMOKE_TESTS
        av1_d3d12va_encoder av1_d3d12va d3d12va=d3d12 d3d12)
    _ffmpeg_native_add_hardware_encoder_test(FFMPEG_NATIVE_HARDWARE_SMOKE_TESTS
        h264_d3d12va_encoder h264_d3d12va d3d12va=d3d12 d3d12)
    _ffmpeg_native_add_hardware_encoder_test(FFMPEG_NATIVE_HARDWARE_SMOKE_TESTS
        hevc_d3d12va_encoder hevc_d3d12va d3d12va=d3d12 d3d12)

    _ffmpeg_native_add_hardware_decoder_test(FFMPEG_NATIVE_HARDWARE_SMOKE_TESTS
        h264_cuvid_decoder h264_cuvid h264_nvenc_encoder h264_nvenc mp4)
    _ffmpeg_native_add_hardware_decoder_test(FFMPEG_NATIVE_HARDWARE_SMOKE_TESTS
        hevc_cuvid_decoder hevc_cuvid hevc_nvenc_encoder hevc_nvenc mp4)
    _ffmpeg_native_add_hardware_decoder_test(FFMPEG_NATIVE_HARDWARE_SMOKE_TESTS
        h264_qsv_decoder h264_qsv h264_qsv_encoder h264_qsv mp4)
    _ffmpeg_native_add_hardware_decoder_test(FFMPEG_NATIVE_HARDWARE_SMOKE_TESTS
        hevc_qsv_decoder hevc_qsv hevc_qsv_encoder hevc_qsv mp4)

    list(REMOVE_DUPLICATES FFMPEG_NATIVE_HARDWARE_SMOKE_TESTS)
    list(SORT FFMPEG_NATIVE_HARDWARE_SMOKE_TESTS)
    set(FFMPEG_NATIVE_HARDWARE_SMOKE_TESTS "${FFMPEG_NATIVE_HARDWARE_SMOKE_TESTS}" PARENT_SCOPE)
endfunction()

function(ffmpeg_native_add_smoke_tests)
    set(FFMPEG_NATIVE_SMOKE_TESTS)
    if(NOT FFMPEG_NATIVE_ENABLE_SMOKE_TESTS)
        set(FFMPEG_NATIVE_SMOKE_TESTS "${FFMPEG_NATIVE_SMOKE_TESTS}" PARENT_SCOPE)
        return()
    endif()

    _ffmpeg_native_add_smoke_test(FFMPEG_NATIVE_SMOKE_TESTS
        ffmpeg-native.ffmpeg.version ffmpeg
        -hide_banner -version)
    _ffmpeg_native_add_smoke_test(FFMPEG_NATIVE_SMOKE_TESTS
        ffmpeg-native.ffmpeg.protocols ffmpeg
        -hide_banner -protocols)
    _ffmpeg_native_add_smoke_test(FFMPEG_NATIVE_SMOKE_TESTS
        ffmpeg-native.ffmpeg.hwaccels ffmpeg
        -hide_banner -hwaccels)
    _ffmpeg_native_add_smoke_test(FFMPEG_NATIVE_SMOKE_TESTS
        ffmpeg-native.ffmpeg.encoders ffmpeg
        -hide_banner -encoders)
    _ffmpeg_native_add_smoke_test(FFMPEG_NATIVE_SMOKE_TESTS
        ffmpeg-native.ffprobe.version ffprobe
        -hide_banner -version)

    foreach(_ffmpeg_pair IN ITEMS
            av1_nvenc_encoder:encoder:av1_nvenc
            h264_nvenc_encoder:encoder:h264_nvenc
            hevc_nvenc_encoder:encoder:hevc_nvenc
            av1_amf_encoder:encoder:av1_amf
            h264_amf_encoder:encoder:h264_amf
            hevc_amf_encoder:encoder:hevc_amf
            av1_d3d12va_encoder:encoder:av1_d3d12va
            h264_d3d12va_encoder:encoder:h264_d3d12va
            hevc_d3d12va_encoder:encoder:hevc_d3d12va
            h264_qsv_encoder:encoder:h264_qsv
            hevc_qsv_encoder:encoder:hevc_qsv
            vp9_qsv_encoder:encoder:vp9_qsv
            av1_cuvid_decoder:decoder:av1_cuvid
            h264_cuvid_decoder:decoder:h264_cuvid
            hevc_cuvid_decoder:decoder:hevc_cuvid
            h264_qsv_decoder:decoder:h264_qsv
            hevc_qsv_decoder:decoder:hevc_qsv
            av1_qsv_decoder:decoder:av1_qsv)
        string(REPLACE ":" ";" _ffmpeg_parts "${_ffmpeg_pair}")
        list(GET _ffmpeg_parts 0 _ffmpeg_component)
        list(GET _ffmpeg_parts 1 _ffmpeg_kind)
        list(GET _ffmpeg_parts 2 _ffmpeg_name)
        _ffmpeg_native_add_component_help_test(FFMPEG_NATIVE_SMOKE_TESTS
            "${_ffmpeg_component}" "${_ffmpeg_kind}" ffmpeg "${_ffmpeg_name}")
    endforeach()

    list(REMOVE_DUPLICATES FFMPEG_NATIVE_SMOKE_TESTS)
    list(SORT FFMPEG_NATIVE_SMOKE_TESTS)
    set(FFMPEG_NATIVE_SMOKE_TESTS "${FFMPEG_NATIVE_SMOKE_TESTS}" PARENT_SCOPE)
endfunction()
