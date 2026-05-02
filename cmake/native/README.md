# Native FFmpeg CMake Modules

These files are internal implementation modules for the native CMake backend.
The public entry points remain:

- `cmake/FFmpegNativeAutoconfig.cmake`
- `cmake/FFmpegNativeProject.cmake`

Module ownership:

- `FFmpegNativeConfigureParser.cmake`: reads and expands FFmpeg `configure` lists and dependency rules.
- `FFmpegNativeComponents.cmake`: discovers codecs, formats, filters, protocols, devices, examples, and default component sets.
- `FFmpegNativeFeatureGraph.cmake`: resolves feature dependencies, conditions, explicit feature validation, and license gates.
- `FFmpegNativePlatform.cmake`: probes platform, compiler, architecture, and `HAVE_*` capabilities.
- `FFmpegNativeTargetSettings.cmake`: shared target compile definitions, compiler options, NASM object format, and ASM validation.
- `FFmpegNativeGeneratedFiles.cmake`: writes generated `config.h`, `config.asm`, registries, package files, and generated support sources.
- `FFmpegNativeSources.cmake`: expands FFmpeg Makefile objects into CMake source lists, including arch-specific sources.
- `FFmpegNativeTargets.cmake`: creates libraries, programs, examples, install rules, and target links.
- `FFmpegNativeCoverage.cmake`: writes the generated native coverage table and hardware feature summary.

Keep new code near the data it owns. The wrapper files should stay as orchestration only.
