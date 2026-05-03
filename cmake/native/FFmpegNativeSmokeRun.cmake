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

function(_ffmpeg_smoke_run _step)
    execute_process(
        COMMAND ${ARGN}
        RESULT_VARIABLE _ffmpeg_result
        OUTPUT_VARIABLE _ffmpeg_stdout
        ERROR_VARIABLE _ffmpeg_stderr
        TIMEOUT "${FFMPEG_SMOKE_TIMEOUT}")
    if(NOT _ffmpeg_result STREQUAL "0")
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

if(FFMPEG_SMOKE_MODE STREQUAL "encoder")
    if(NOT FFMPEG_SMOKE_ENCODER)
        message(FATAL_ERROR "FFMPEG_SMOKE_ENCODER is required for encoder mode")
    endif()

    _ffmpeg_smoke_run("hardware encode ${FFMPEG_SMOKE_ENCODER}"
        ${_ffmpeg_common_args}
        -f lavfi
        -i testsrc2=size=128x72:rate=1
        -frames:v 2
        -pix_fmt yuv420p
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
        -f lavfi
        -i testsrc2=size=128x72:rate=1
        -frames:v 2
        -pix_fmt yuv420p
        -c:v "${FFMPEG_SMOKE_ENCODER}"
        "${_ffmpeg_sample}")

    _ffmpeg_smoke_run("hardware decode ${FFMPEG_SMOKE_DECODER}"
        ${_ffmpeg_common_args}
        -c:v "${FFMPEG_SMOKE_DECODER}"
        -i "${_ffmpeg_sample}"
        -frames:v 2
        -f null
        -)
else()
    message(FATAL_ERROR "Unknown FFMPEG_SMOKE_MODE='${FFMPEG_SMOKE_MODE}'")
endif()
