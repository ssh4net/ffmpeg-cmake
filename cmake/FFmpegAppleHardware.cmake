include_guard(GLOBAL)

set(FFMPEG_APPLE_VIDEOTOOLBOX "AUTO" CACHE STRING "Apple VideoToolbox hardware acceleration: AUTO enables it when SDK/framework probes pass, ON requires it, OFF disables it.")
set_property(CACHE FFMPEG_APPLE_VIDEOTOOLBOX PROPERTY STRINGS AUTO ON OFF)

function(_ffmpeg_apple_set_probe_result _available _encoder_available _configure_option _status _details)
    set(FFMPEG_APPLE_VIDEOTOOLBOX_AVAILABLE "${_available}" CACHE INTERNAL "Whether Apple VideoToolbox decode/framework support passed the CMake probe." FORCE)
    set(FFMPEG_APPLE_VIDEOTOOLBOX_ENCODER_AVAILABLE "${_encoder_available}" CACHE INTERNAL "Whether Apple VideoToolbox encoder support passed the CMake probe." FORCE)
    set(FFMPEG_APPLE_VIDEOTOOLBOX_CONFIGURE_OPTION "${_configure_option}" CACHE INTERNAL "FFmpeg configure option selected for VideoToolbox." FORCE)
    set(FFMPEG_APPLE_VIDEOTOOLBOX_STATUS "${_status}" CACHE INTERNAL "Human-readable Apple VideoToolbox probe status." FORCE)
    set(FFMPEG_APPLE_VIDEOTOOLBOX_DETAILS "${_details}" CACHE INTERNAL "Human-readable Apple VideoToolbox probe details." FORCE)
endfunction()

function(_ffmpeg_apple_requested_videotoolbox _out)
    set(_ffmpeg_requested FALSE)
    if(FFMPEG_APPLE_VIDEOTOOLBOX STREQUAL "ON")
        set(_ffmpeg_requested TRUE)
    endif()
    if("videotoolbox" IN_LIST FFMPEG_ENABLE_FEATURES)
        set(_ffmpeg_requested TRUE)
    endif()
    if(FFMPEG_CONFIGURE_OPTIONS MATCHES "(^|[ \t;])--enable-videotoolbox($|[ \t;])")
        set(_ffmpeg_requested TRUE)
    endif()
    set(${_out} "${_ffmpeg_requested}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_apple_disabled_videotoolbox _out)
    set(_ffmpeg_disabled FALSE)
    if(FFMPEG_APPLE_VIDEOTOOLBOX STREQUAL "OFF")
        set(_ffmpeg_disabled TRUE)
    endif()
    if("videotoolbox" IN_LIST FFMPEG_DISABLE_FEATURES)
        set(_ffmpeg_disabled TRUE)
    endif()
    if(FFMPEG_CONFIGURE_OPTIONS MATCHES "(^|[ \t;])--disable-videotoolbox($|[ \t;])")
        set(_ffmpeg_disabled TRUE)
    endif()
    set(${_out} "${_ffmpeg_disabled}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_apple_raw_videotoolbox_option _out)
    if(FFMPEG_CONFIGURE_OPTIONS MATCHES "(^|[ \t;])--(enable|disable)-videotoolbox($|[ \t;])")
        set(${_out} TRUE PARENT_SCOPE)
    else()
        set(${_out} FALSE PARENT_SCOPE)
    endif()
endfunction()

function(ffmpeg_probe_apple_hardware)
    string(TOUPPER "${FFMPEG_APPLE_VIDEOTOOLBOX}" FFMPEG_APPLE_VIDEOTOOLBOX)
    set(FFMPEG_APPLE_VIDEOTOOLBOX "${FFMPEG_APPLE_VIDEOTOOLBOX}" CACHE STRING "Apple VideoToolbox hardware acceleration: AUTO enables it when SDK/framework probes pass, ON requires it, OFF disables it." FORCE)
    set_property(CACHE FFMPEG_APPLE_VIDEOTOOLBOX PROPERTY STRINGS AUTO ON OFF)

    set(_ffmpeg_valid_modes AUTO ON OFF)
    if(NOT FFMPEG_APPLE_VIDEOTOOLBOX IN_LIST _ffmpeg_valid_modes)
        message(FATAL_ERROR "FFMPEG_APPLE_VIDEOTOOLBOX must be AUTO, ON, or OFF")
    endif()

    if(NOT APPLE)
        if(FFMPEG_APPLE_VIDEOTOOLBOX STREQUAL "ON")
            message(FATAL_ERROR "FFMPEG_APPLE_VIDEOTOOLBOX=ON requires an Apple target platform.")
        endif()
        _ffmpeg_apple_set_probe_result(FALSE FALSE "" "not applicable" "VideoToolbox is only available on Apple platforms.")
        return()
    endif()

    _ffmpeg_apple_disabled_videotoolbox(_ffmpeg_disabled)
    if(_ffmpeg_disabled)
        _ffmpeg_apple_set_probe_result(FALSE FALSE "--disable-videotoolbox" "disabled" "Disabled by FFMPEG_APPLE_VIDEOTOOLBOX or FFMPEG_DISABLE_FEATURES.")
        return()
    endif()

    include(CheckCSourceCompiles)
    include(CMakePushCheckState)

    set(_ffmpeg_framework_names VideoToolbox CoreFoundation CoreMedia CoreVideo)
    set(_ffmpeg_frameworks)
    set(_ffmpeg_missing)
    foreach(_ffmpeg_framework_name IN LISTS _ffmpeg_framework_names)
        string(TOUPPER "${_ffmpeg_framework_name}" _ffmpeg_framework_var)
        find_library(_ffmpeg_framework_${_ffmpeg_framework_var} NAMES "${_ffmpeg_framework_name}" NO_CACHE)
        if(_ffmpeg_framework_${_ffmpeg_framework_var})
            list(APPEND _ffmpeg_frameworks "${_ffmpeg_framework_${_ffmpeg_framework_var}}")
        else()
            list(APPEND _ffmpeg_missing "${_ffmpeg_framework_name}.framework")
        endif()
    endforeach()

    set(_ffmpeg_details)
    if(_ffmpeg_missing)
        string(REPLACE ";" ", " _ffmpeg_missing_text "${_ffmpeg_missing}")
        list(APPEND _ffmpeg_details "Missing Apple frameworks: ${_ffmpeg_missing_text}")
    endif()

    set(_ffmpeg_videotoolbox_available FALSE)
    set(_ffmpeg_videotoolbox_encoder_available FALSE)
    if(NOT _ffmpeg_missing)
        unset(FFMPEG_APPLE_CHECK_VIDEOTOOLBOX_DECODE CACHE)
        unset(FFMPEG_APPLE_CHECK_VIDEOTOOLBOX_ENCODE CACHE)
        cmake_push_check_state(RESET)
        set(CMAKE_REQUIRED_QUIET TRUE)
        set(CMAKE_REQUIRED_LIBRARIES ${_ffmpeg_frameworks})
        check_c_source_compiles([=[
            #include <CoreFoundation/CoreFoundation.h>
            #include <CoreMedia/CoreMedia.h>
            #include <CoreVideo/CoreVideo.h>
            #include <VideoToolbox/VideoToolbox.h>
            int main(void)
            {
                VTDecodeInfoFlags flags = 0;
                return VTDecompressionSessionDecodeFrame(0, 0, 0, 0, &flags);
            }
        ]=] FFMPEG_APPLE_CHECK_VIDEOTOOLBOX_DECODE)

        check_c_source_compiles([=[
            #include <VideoToolbox/VTCompressionSession.h>
            int main(void)
            {
                return VTCompressionSessionPrepareToEncodeFrames(0);
            }
        ]=] FFMPEG_APPLE_CHECK_VIDEOTOOLBOX_ENCODE)
        cmake_pop_check_state()

        if(FFMPEG_APPLE_CHECK_VIDEOTOOLBOX_DECODE)
            set(_ffmpeg_videotoolbox_available TRUE)
        else()
            list(APPEND _ffmpeg_details "VideoToolbox decode/link probe failed: VTDecompressionSessionDecodeFrame was not usable. See CMakeFiles/CMakeError.log for compiler/linker output.")
        endif()

        if(FFMPEG_APPLE_CHECK_VIDEOTOOLBOX_ENCODE)
            set(_ffmpeg_videotoolbox_encoder_available TRUE)
        else()
            list(APPEND _ffmpeg_details "VideoToolbox encode/link probe failed: VTCompressionSessionPrepareToEncodeFrames was not usable. VideoToolbox decode may still be available.")
        endif()
    endif()

    _ffmpeg_apple_requested_videotoolbox(_ffmpeg_requested)
    if(_ffmpeg_videotoolbox_available)
        if(_ffmpeg_videotoolbox_encoder_available)
            list(APPEND _ffmpeg_details "VideoToolbox decode and encoder SDK probes passed.")
        else()
            list(APPEND _ffmpeg_details "VideoToolbox decode probe passed; encoder SDK probe did not pass.")
        endif()
        _ffmpeg_apple_set_probe_result(TRUE "${_ffmpeg_videotoolbox_encoder_available}" "--enable-videotoolbox" "available" "${_ffmpeg_details}")
    else()
        if(NOT _ffmpeg_details)
            list(APPEND _ffmpeg_details "VideoToolbox SDK probe failed for an unknown reason. See CMakeFiles/CMakeError.log.")
        endif()
        _ffmpeg_apple_set_probe_result(FALSE FALSE "--disable-videotoolbox" "not found" "${_ffmpeg_details}")
        if(_ffmpeg_requested)
            string(REPLACE ";" "\n  " _ffmpeg_detail_text "${_ffmpeg_details}")
            message(FATAL_ERROR "Apple VideoToolbox was requested but is not available:\n  ${_ffmpeg_detail_text}")
        endif()
    endif()
endfunction()

function(ffmpeg_apple_hardware_configure_options _out)
    set(_ffmpeg_args)
    if(NOT APPLE)
        set(${_out} "${_ffmpeg_args}" PARENT_SCOPE)
        return()
    endif()

    _ffmpeg_apple_raw_videotoolbox_option(_ffmpeg_raw_option)
    if(_ffmpeg_raw_option OR "videotoolbox" IN_LIST FFMPEG_ENABLE_FEATURES OR "videotoolbox" IN_LIST FFMPEG_DISABLE_FEATURES)
        set(FFMPEG_APPLE_VIDEOTOOLBOX_CONFIGURE_OPTION "managed by user feature/configure option" CACHE INTERNAL "FFmpeg configure option selected for VideoToolbox." FORCE)
        set(${_out} "${_ffmpeg_args}" PARENT_SCOPE)
        return()
    endif()

    if(FFMPEG_APPLE_VIDEOTOOLBOX_CONFIGURE_OPTION)
        list(APPEND _ffmpeg_args "${FFMPEG_APPLE_VIDEOTOOLBOX_CONFIGURE_OPTION}")
    endif()

    set(${_out} "${_ffmpeg_args}" PARENT_SCOPE)
endfunction()
