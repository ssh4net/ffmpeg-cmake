# ffmpeg-cmake

This repository provides a CMake front end for building the bundled FFmpeg
source tree and for consuming installed FFmpeg builds through CMake targets.

The non-Windows backend drives FFmpeg's official `configure` script. The native
CMake backend is being built up separately for generators such as Visual Studio,
Ninja+MSVC, and Ninja+clang-cl where depending on MSYS2/MinGW shells is not
acceptable.

## Configure and Build Bundled FFmpeg

```sh
cmake -S . -B build/ffmpeg -DFFMPEG_BUILD_BACKEND=AUTO -DFFMPEG_INSTALL_PREFIX=build/install
cmake --build build/ffmpeg
```

Useful cache options:

- `FFMPEG_SOURCE_DIR` points at the FFmpeg source checkout. The default is
  `<ffmpeg-cmake>/ffmpeg`.
- `FFMPEG_SOURCE_GIT_CLONE=ON` clones FFmpeg into `FFMPEG_SOURCE_DIR` when the
  source tree is missing. Cloning is allowed only into this repository tree.
- `FFMPEG_SOURCE_GIT_REPOSITORY` and `FFMPEG_SOURCE_GIT_REF` select the remote
  and branch, tag, or commit to clone/check out. Commit hashes are checked out
  detached; use `FFMPEG_SOURCE_GIT_DETACHED_HEAD=ON` to detach branch or tag refs
  too.
- `FFMPEG_SOURCE_GIT_UPDATE=ON` updates an existing in-tree FFmpeg git checkout
  at configure time. It refuses external paths, non-git source trees, and dirty
  checkouts.
- `FFMPEG_NV_CODEC_HEADERS_DIR` points at `nv-codec-headers`. It may be an
  installed prefix, an include directory, or the default in-tree
  `<ffmpeg-cmake>/nv-codec-headers` checkout.
- `FFMPEG_NV_CODEC_HEADERS_GIT_CLONE=ON` clones `nv-codec-headers` into
  `FFMPEG_NV_CODEC_HEADERS_DIR` when those headers are missing. Clone/update is
  allowed only inside this repository tree.
- `FFMPEG_NV_CODEC_HEADERS_GIT_REPOSITORY`,
  `FFMPEG_NV_CODEC_HEADERS_GIT_REF`, and
  `FFMPEG_NV_CODEC_HEADERS_GIT_DETACHED_HEAD` select the NVIDIA codec header
  remote and branch, tag, or commit. Commit hashes are checked out detached.
- `FFMPEG_NV_CODEC_HEADERS_GIT_UPDATE=ON` updates an existing in-tree
  `nv-codec-headers` git checkout at configure time. It refuses dirty checkouts.
- `FFMPEG_AMF_HEADERS_DIR` points at AMD AMF headers. It may be an installed
  prefix, an include directory, or the default in-tree `<ffmpeg-cmake>/amf`
  checkout.
- `FFMPEG_AMF_HEADERS_GIT_CLONE=ON` clones AMD AMF headers into
  `FFMPEG_AMF_HEADERS_DIR` when those headers are missing. Clone/update is
  allowed only inside this repository tree.
- `FFMPEG_AMF_HEADERS_GIT_REPOSITORY`, `FFMPEG_AMF_HEADERS_GIT_REF`, and
  `FFMPEG_AMF_HEADERS_GIT_DETACHED_HEAD` select the AMD AMF header remote and
  branch, tag, or commit. Commit hashes are checked out detached.
- `FFMPEG_AMF_HEADERS_GIT_UPDATE=ON` updates an existing in-tree AMD AMF
  headers checkout at configure time. It refuses dirty checkouts.
- `FFMPEG_BUILD_STATIC` and `FFMPEG_BUILD_SHARED` control static/shared FFmpeg libraries.
- `CMAKE_PREFIX_PATH` is cached and is converted to `PKG_CONFIG_PATH` and `PATH`
  for FFmpeg `configure`, so dependencies installed in prefixes are found
  without manual environment setup.
- `CMAKE_POSITION_INDEPENDENT_CODE` is cached. Static native builds honor it;
  shared native builds force PIC as required.
- On Windows, `CMAKE_DEBUG_POSTFIX` defaults to `d`.
- On MSVC static builds, `CMAKE_MSVC_RUNTIME_LIBRARY` defaults to
  `$<$<CONFIG:Debug>:MultiThreadedDebug>$<$<CONFIG:Release>:MultiThreaded>`.
- `FFMPEG_NATIVE_REQUIRE_STATIC_EXTERNAL_DEPENDENCIES=ON` requires every
  external dependency to be a real static archive. Keep it `OFF` when a static
  FFmpeg build may use Windows import libraries and runtime DLLs.
- `FFMPEG_AS` sets FFmpeg `--as`; `FFMPEG_X86ASM` sets FFmpeg
  `--x86asmexe` for the NASM-compatible standalone x86 assembler. CMake probes
  `nasm`, but either path can be set manually.
- `FFMPEG_ENABLE_AVUTIL`, `FFMPEG_ENABLE_AVCODEC`, `FFMPEG_ENABLE_AVFORMAT`,
  and the other `FFMPEG_ENABLE_AV*` library switches are honored by both
  bundled build backends.
- `FFMPEG_CONFIGURE_OPTIONS` passes raw options directly to FFmpeg `configure`.
- `FFMPEG_ENABLE_EXTERNAL_LIBRARIES` maps entries like `libx264` or `openssl` to `--enable-libx264` / `--enable-openssl`.
- `FFMPEG_ENABLE_ENCODERS`, `FFMPEG_ENABLE_DECODERS`, `FFMPEG_ENABLE_FILTERS`, and matching `FFMPEG_DISABLE_*` variables map to FFmpeg's per-component options.

For options not modeled as cache variables, use `FFMPEG_CONFIGURE_OPTIONS`.
That is the escape hatch for full parity with `./configure --help`.

## Build Backends

`FFMPEG_BUILD_BACKEND` controls how bundled FFmpeg is built:

- `OFFICIAL_CONFIGURE` runs FFmpeg's upstream `configure` and make flow.
- `NATIVE_CMAKE` uses only CMake-generated build rules and does not call a POSIX shell or make.
- `AUTO` uses `NATIVE_CMAKE` on Windows and `OFFICIAL_CONFIGURE` elsewhere.

The native backend is the correct direction for Visual Studio, Ninja+MSVC, and
Ninja+clang-cl. It currently builds the native `avutil`, `swresample`,
`swscale`, core `avcodec`, core `avformat`, core `avfilter`, and core
`avdevice` libraries with CMake-generated FFmpeg config headers.

Native autoconfig parses upstream FFmpeg metadata from `configure` and the
component registry source files. It generates the full known `ARCH_*`,
`HAVE_*`, `CONFIG_*`, and `config_components.h` symbol surface, validates
license gates for GPL/version3/nonfree external libraries, resolves `select`
dependencies, and generates component registry lists for explicitly enabled
encoders, decoders, hwaccels, muxers, demuxers, protocols, filters, devices,
parsers, and bitstream filters.

Example native feature configuration:

```sh
cmake -S . -B build/native-gpl-nv -G Ninja \
  -DFFMPEG_BUILD_BACKEND=NATIVE_CMAKE \
  -DFFMPEG_NATIVE_COMPONENTS=avutil\;swresample\;swscale\;avcodec\;avformat\;avfilter\;avdevice \
  -DFFMPEG_ENABLE_GPL=ON \
  -DFFMPEG_ENABLE_EXTERNAL_LIBRARIES=libx264 \
  -DFFMPEG_ENABLE_FEATURES=ffnvcodec\;nvenc\;nvdec \
  -DFFMPEG_ENABLE_ENCODERS=libx264\;h264_nvenc \
  -DFFMPEG_ENABLE_HWACCELS=h264_nvdec
```

That emits the expected config symbols and builds the core libraries listed
above. Optional codec/container/protocol/filter/device implementations,
programs, and full native replacement coverage still need to be ported before
the native backend can replace the official backend for a full FFmpeg build.

Enabled external features that upstream FFmpeg checks through
`check_pkg_config` or `require_pkg_config` are imported as
`FFmpegExternal::<feature>` targets and linked into the native libraries. Static
native builds call pkg-config with `--static`; when pkg-config exposes library
directories, `-lfoo` entries are resolved to static archive paths where
possible. For common native dependencies, the backend falls back to CMake
package targets such as `ZLIB::ZLIB`, `BZip2::BZip2`, `OpenSSL::SSL`,
`LibXml2::LibXml2`, `Vulkan::Vulkan`, and `OpenCL::OpenCL`. Static Unix builds
temporarily prefer static library suffixes for those fallback packages, both at
build time and in the generated install package. The generated install package
also exports these dependency targets, including special handling for CMake
`Threads::Threads`.

Native dependency import is intentionally strict by default:
`FFMPEG_NATIVE_REQUIRE_EXTERNAL_DEPENDENCIES=ON` fails configuration when an
enabled external feature cannot be imported. Non-pkg-config upstream checks
such as custom `require` / `check_lib` probes are still being mapped.

On Windows, the official backend is blocked by default because it requires
FFmpeg's POSIX shell build flow. Override it only when intentionally using
MSYS2/Git Bash/etc.:

```sh
cmake -S . -B build/win-native -G Ninja -DFFMPEG_BUILD_BACKEND=NATIVE_CMAKE
cmake --build build/win-native
```

## Windows Native Matrix

`CMakePresets.json` includes native Windows presets for Visual Studio, Ninja
with MSVC, and Ninja with clang-cl. The Ninja presets expect native MSVC/LLVM
tools in `PATH`, for example from a Developer Command Prompt or equivalent
environment. They do not require MSYS2, MinGW, or a POSIX shell.

Set `FFMPEG_DEPENDENCY_PREFIX_WINDOWS` when optional dependencies for static
builds live in a separate prefix. Shared presets are dependency-light by default
to avoid mixing `/MD` FFmpeg DLLs with `/MT` third-party archives; provide
`FFMPEG_DEPENDENCY_PREFIX_WINDOWS_SHARED` and set
`FFMPEG_NATIVE_AUTODETECT_EXTERNAL_LIBRARIES=ON` only for dependencies built
with a compatible MSVC runtime.

```bat
cmake --preset native-windows-vs2022-msvc-x64-static
cmake --build --preset native-windows-vs2022-msvc-x64-static-release
ctest --preset native-windows-vs2022-msvc-x64-static-release-consumer

cmake --preset native-windows-vs2022-msvc-x64-shared
cmake --build --preset native-windows-vs2022-msvc-x64-shared-release
ctest --preset native-windows-vs2022-msvc-x64-shared-release-consumer
```

The preset matrix also includes Release and Debug static-runtime checks for
Ninja+MSVC and Ninja+clang-cl:

```bat
cmake --preset native-windows-ninja-msvc-x64-static-release
cmake --build --preset native-windows-ninja-msvc-x64-static-release
ctest --preset native-windows-ninja-msvc-x64-static-release-consumer

cmake --preset native-windows-ninja-clangcl-x64-static-debug
cmake --build --preset native-windows-ninja-clangcl-x64-static-debug
ctest --preset native-windows-ninja-clangcl-x64-static-debug-consumer
```

Plain `Ninja` is a single-configuration generator. Use one
`CMAKE_BUILD_TYPE`, such as `Release` or `Debug`, per build tree. To build
Debug and Release from one Ninja build tree, use the `Ninja Multi-Config`
generator and set `CMAKE_CONFIGURATION_TYPES=Debug;Release`.

Consumer test presets install the just-built FFmpeg package into a private test
prefix, configure a separate CMake project, link against `FFmpeg::FFmpeg` and
each component target, then run the resulting executables with the installed
runtime directory on the platform library path.

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

## Verify an Installed Prefix

An installed FFmpeg prefix can be checked with the smoke target:

```sh
cmake -S . -B build/find-installed \
  -DFFMPEG_BUILD_FROM_SOURCE=OFF \
  -DFFMPEG_FIND_INSTALLED=ON \
  -DFFMPEG_BUILD_SMOKE_TEST=ON \
  -DFFmpeg_ROOT=/path/to/ffmpeg-prefix
cmake --build build/find-installed
ctest --test-dir build/find-installed --output-on-failure
```
