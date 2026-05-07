if(NOT FFMPEG_SMOKE_FFMPEG)
    message(FATAL_ERROR "FFMPEG_SMOKE_FFMPEG is required")
endif()
if(NOT EXISTS "${FFMPEG_SMOKE_FFMPEG}")
    message(FATAL_ERROR "FFmpeg executable does not exist: ${FFMPEG_SMOKE_FFMPEG}")
endif()
if(NOT FFMPEG_SMOKE_MODE)
    message(FATAL_ERROR "FFMPEG_SMOKE_MODE is required")
endif()
if(NOT FFMPEG_SMOKE_TIMEOUT)
    set(FFMPEG_SMOKE_TIMEOUT 60)
endif()
if(NOT FFMPEG_SMOKE_WORK_DIR)
    set(FFMPEG_SMOKE_WORK_DIR "${CMAKE_CURRENT_BINARY_DIR}/ffmpeg-native/smoke")
endif()

file(MAKE_DIRECTORY "${FFMPEG_SMOKE_WORK_DIR}")

set(_ffmpeg_smoke_width 160)
set(_ffmpeg_smoke_height 160)
set(_ffmpeg_smoke_size "${_ffmpeg_smoke_width}x${_ffmpeg_smoke_height}")
set(_ffmpeg_smoke_rate 1)
math(EXPR _ffmpeg_smoke_luma_size "${_ffmpeg_smoke_width} * ${_ffmpeg_smoke_height}")
math(EXPR _ffmpeg_smoke_chroma_size "${_ffmpeg_smoke_luma_size} / 2")
set(_ffmpeg_smoke_frame "${FFMPEG_SMOKE_WORK_DIR}/smoke-${_ffmpeg_smoke_size}-nv12.yuv")
if(NOT EXISTS "${_ffmpeg_smoke_frame}")
    string(REPEAT "Y" "${_ffmpeg_smoke_luma_size}" _ffmpeg_smoke_luma)
    string(REPEAT "U" "${_ffmpeg_smoke_chroma_size}" _ffmpeg_smoke_chroma)
    file(WRITE "${_ffmpeg_smoke_frame}" "${_ffmpeg_smoke_luma}${_ffmpeg_smoke_chroma}")
endif()

function(_ffmpeg_smoke_is_hardware_unavailable _out _stderr)
    set(_ffmpeg_unavailable_patterns
        "Cannot load .*nvcuda"
        "Codec configuration not supported"
        "Codec not supported"
        "CUDA_ERROR_NO_DEVICE"
        "DLL amfrt64\\.dll failed to open"
        "Driver does not support requested features"
        "Error initializing a MFX session: unsupported"
        "No capable devices found"
        "No device available"
        "The current mfx implementation is not supported")

    foreach(_ffmpeg_pattern IN LISTS _ffmpeg_unavailable_patterns)
        if("${_stderr}" MATCHES "${_ffmpeg_pattern}")
            set(${_out} TRUE PARENT_SCOPE)
            return()
        endif()
    endforeach()

    set(${_out} FALSE PARENT_SCOPE)
endfunction()

function(_ffmpeg_smoke_run _step)
    execute_process(
        COMMAND ${ARGN}
        RESULT_VARIABLE _ffmpeg_result
        OUTPUT_VARIABLE _ffmpeg_stdout
        ERROR_VARIABLE _ffmpeg_stderr
        TIMEOUT "${FFMPEG_SMOKE_TIMEOUT}")
    if(NOT _ffmpeg_result STREQUAL "0")
        _ffmpeg_smoke_is_hardware_unavailable(_ffmpeg_hardware_unavailable "${_ffmpeg_stderr}")
        if(_ffmpeg_hardware_unavailable)
            message("FFMPEG_HW_SMOKE_SKIP: ${_step} runtime support is unavailable")
            message(STATUS "${_step} stdout:\n${_ffmpeg_stdout}")
            message(STATUS "${_step} stderr:\n${_ffmpeg_stderr}")
            message(FATAL_ERROR "FFMPEG_HW_SMOKE_SKIP: ${_step}")
        endif()
        message(STATUS "${_step} stdout:\n${_ffmpeg_stdout}")
        message(STATUS "${_step} stderr:\n${_ffmpeg_stderr}")
        message(FATAL_ERROR "${_step} failed with exit code ${_ffmpeg_result}")
    endif()
endfunction()

set(_ffmpeg_common_args
    "${FFMPEG_SMOKE_FFMPEG}"
    -hide_banner
    -nostdin
    -loglevel warning
    -nostats)
set(_ffmpeg_raw_video_args
    -f rawvideo
    -pixel_format nv12
    -video_size "${_ffmpeg_smoke_size}"
    -framerate "${_ffmpeg_smoke_rate}"
    -i "${_ffmpeg_smoke_frame}")

if(FFMPEG_SMOKE_MODE STREQUAL "encoder")
    if(NOT FFMPEG_SMOKE_ENCODER)
        message(FATAL_ERROR "FFMPEG_SMOKE_ENCODER is required for encoder mode")
    endif()

    set(_ffmpeg_hw_args)
    set(_ffmpeg_filter_args)
    set(_ffmpeg_pixel_args -pix_fmt nv12)
    if(FFMPEG_SMOKE_HWDEVICE)
        list(APPEND _ffmpeg_hw_args -init_hw_device "${FFMPEG_SMOKE_HWDEVICE}")
        if(FFMPEG_SMOKE_FILTER_HWDEVICE)
            list(APPEND _ffmpeg_hw_args -filter_hw_device "${FFMPEG_SMOKE_FILTER_HWDEVICE}")
        endif()
        set(_ffmpeg_filter_args -vf format=nv12,hwupload)
        set(_ffmpeg_pixel_args)
    endif()

    _ffmpeg_smoke_run("hardware encode ${FFMPEG_SMOKE_ENCODER}"
        ${_ffmpeg_common_args}
        ${_ffmpeg_hw_args}
        ${_ffmpeg_raw_video_args}
        ${_ffmpeg_filter_args}
        -frames:v 2
        ${_ffmpeg_pixel_args}
        -c:v "${FFMPEG_SMOKE_ENCODER}"
        -f null
        -)
elseif(FFMPEG_SMOKE_MODE STREQUAL "decoder")
    if(NOT FFMPEG_SMOKE_ENCODER)
        message(FATAL_ERROR "FFMPEG_SMOKE_ENCODER is required for decoder mode")
    endif()
    if(NOT FFMPEG_SMOKE_DECODER)
        message(FATAL_ERROR "FFMPEG_SMOKE_DECODER is required for decoder mode")
    endif()
    if(NOT FFMPEG_SMOKE_CONTAINER)
        set(FFMPEG_SMOKE_CONTAINER mp4)
    endif()

    set(_ffmpeg_sample "${FFMPEG_SMOKE_WORK_DIR}/${FFMPEG_SMOKE_ENCODER}-${FFMPEG_SMOKE_DECODER}.${FFMPEG_SMOKE_CONTAINER}")
    file(REMOVE "${_ffmpeg_sample}")

    _ffmpeg_smoke_run("hardware decode fixture encode ${FFMPEG_SMOKE_ENCODER}"
        ${_ffmpeg_common_args}
        -y
        ${_ffmpeg_raw_video_args}
        -frames:v 2
        -pix_fmt nv12
        -c:v "${FFMPEG_SMOKE_ENCODER}"
        "${_ffmpeg_sample}")

    _ffmpeg_smoke_run("hardware decode ${FFMPEG_SMOKE_DECODER}"
        ${_ffmpeg_common_args}
        -c:v "${FFMPEG_SMOKE_DECODER}"
        -i "${_ffmpeg_sample}"
        -frames:v 2
        -c:v rawvideo
        -f null
        -)
else()
    message(FATAL_ERROR "Unknown FFMPEG_SMOKE_MODE='${FFMPEG_SMOKE_MODE}'")
endif()
