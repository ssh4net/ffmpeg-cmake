# ffmpeg-cmake

This repository provides a CMake front end for building the bundled FFmpeg
source tree and for consuming installed FFmpeg builds through CMake targets.

The build does not reimplement FFmpeg's configuration logic. CMake drives
FFmpeg's official `configure` script, which keeps feature coverage aligned with
upstream FFmpeg. CMake is responsible for presets, dependency prefix plumbing,
install layout, and imported targets.

## Configure and Build Bundled FFmpeg

```sh
cmake --preset build-ubc-release-static
cmake --build --preset build-ubc-release-static
```

Useful cache options:

- `FFMPEG_BUILD_STATIC` and `FFMPEG_BUILD_SHARED` control static/shared FFmpeg libraries.
- `FFMPEG_CONFIGURE_OPTIONS` passes raw options directly to FFmpeg `configure`.
- `FFMPEG_ENABLE_EXTERNAL_LIBRARIES` maps entries like `libx264` or `openssl` to `--enable-libx264` / `--enable-openssl`.
- `FFMPEG_ENABLE_ENCODERS`, `FFMPEG_ENABLE_DECODERS`, `FFMPEG_ENABLE_FILTERS`, and matching `FFMPEG_DISABLE_*` variables map to FFmpeg's per-component options.
- `CMAKE_PREFIX_PATH` is converted to `PKG_CONFIG_PATH` and `PATH` for FFmpeg `configure`, so dependencies installed in prefixes are found without manual environment setup.

For options not modeled as cache variables, use `FFMPEG_CONFIGURE_OPTIONS`.
That is the escape hatch for full parity with `./configure --help`.

## Consume an Installed FFmpeg

```cmake
list(PREPEND CMAKE_MODULE_PATH "/path/to/ffmpeg-cmake/cmake")
set(FFmpeg_USE_STATIC_LIBS ON)
find_package(FFmpeg REQUIRED COMPONENTS avformat avcodec avutil)
target_link_libraries(app PRIVATE FFmpeg::FFmpeg)
```

`FindFFmpeg.cmake` and the generated `FFmpegConfig.cmake` create these targets:

- `FFmpeg::avutil`
- `FFmpeg::swresample`
- `FFmpeg::swscale`
- `FFmpeg::avcodec`
- `FFmpeg::avformat`
- `FFmpeg::avfilter`
- `FFmpeg::avdevice`
- `FFmpeg::FFmpeg`

Targets are generated from FFmpeg's pkg-config files. When
`FFmpeg_USE_STATIC_LIBS=ON`, pkg-config is called with `--static`, so private
third-party dependencies and linker flags are carried into the CMake targets.
Libraries found in pkg-config `-L` directories are resolved to static archive
paths when possible, avoiding accidental shared-library selection in mixed
static/shared prefixes.

## Verify the Existing WSL Prefix

The installed `/mnt/f/UBc/Release` and `/mnt/f/UBc/Debug` prefixes can be checked
with the smoke target:

```sh
cmake --preset find-ubc-release
cmake --build --preset find-ubc-release
ctest --preset find-ubc-release
```
