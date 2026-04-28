cmake_minimum_required(VERSION 3.24)

set_property(GLOBAL PROPERTY USE_FOLDERS ON)
set_property(GLOBAL PROPERTY PREDEFINED_TARGETS_FOLDER "CMake/Targets")

if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
    project(ffmpeg-smoke LANGUAGES C)
    set(FFmpeg_USE_STATIC_LIBS ON CACHE BOOL "Use pkg-config --static for FFmpeg")
    find_package(FFmpeg REQUIRED COMPONENTS avformat avcodec avutil)
    enable_testing()
endif()

add_executable(ffmpeg_smoke smoke.c)
set_target_properties(ffmpeg_smoke PROPERTIES FOLDER "FFmpeg/Tests")
target_link_libraries(ffmpeg_smoke PRIVATE FFmpeg::FFmpeg)
add_test(NAME ffmpeg_smoke COMMAND ffmpeg_smoke)
