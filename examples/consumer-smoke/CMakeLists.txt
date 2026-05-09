cmake_minimum_required(VERSION 3.24)

set_property(GLOBAL PROPERTY USE_FOLDERS ON)
set_property(GLOBAL PROPERTY PREDEFINED_TARGETS_FOLDER "CMake/Targets")

project(ffmpeg-consumer-smoke LANGUAGES C)

option(FFmpeg_USE_STATIC_LIBS "Prefer static FFmpeg link flags when importing through pkg-config." OFF)

find_package(FFmpeg REQUIRED COMPONENTS avutil swresample swscale avcodec avformat avfilter avdevice)

enable_testing()

function(ffmpeg_consumer_add _name _target _define)
    if(NOT TARGET "${_target}")
        message(FATAL_ERROR "Expected imported target '${_target}' was not created by find_package(FFmpeg)")
    endif()

    add_executable("${_name}" consumer_smoke.c)
    target_compile_definitions("${_name}" PRIVATE "${_define}")
    target_link_libraries("${_name}" PRIVATE "${_target}")
    set_target_properties("${_name}" PROPERTIES FOLDER "FFmpeg/Tests")
    add_test(NAME "${_name}" COMMAND "${_name}")
endfunction()

ffmpeg_consumer_add(ffmpeg_consumer_aggregate FFmpeg::FFmpeg FFMPEG_CONSUMER_AGGREGATE)
ffmpeg_consumer_add(ffmpeg_consumer_avutil FFmpeg::avutil FFMPEG_CONSUMER_AVUTIL)
ffmpeg_consumer_add(ffmpeg_consumer_swresample FFmpeg::swresample FFMPEG_CONSUMER_SWRESAMPLE)
ffmpeg_consumer_add(ffmpeg_consumer_swscale FFmpeg::swscale FFMPEG_CONSUMER_SWSCALE)
ffmpeg_consumer_add(ffmpeg_consumer_avcodec FFmpeg::avcodec FFMPEG_CONSUMER_AVCODEC)
ffmpeg_consumer_add(ffmpeg_consumer_avformat FFmpeg::avformat FFMPEG_CONSUMER_AVFORMAT)
ffmpeg_consumer_add(ffmpeg_consumer_avfilter FFmpeg::avfilter FFMPEG_CONSUMER_AVFILTER)
ffmpeg_consumer_add(ffmpeg_consumer_avdevice FFmpeg::avdevice FFMPEG_CONSUMER_AVDEVICE)
