cmake_minimum_required(VERSION 3.24)

project(ffmpeg-native-smoke LANGUAGES C)

find_package(FFmpeg REQUIRED COMPONENTS avutil swresample swscale avcodec avformat avfilter avdevice)

enable_testing()

add_executable(ffmpeg_native_smoke native_smoke.c)
target_link_libraries(ffmpeg_native_smoke PRIVATE FFmpeg::FFmpeg)
add_test(NAME ffmpeg_native_smoke COMMAND ffmpeg_native_smoke)
