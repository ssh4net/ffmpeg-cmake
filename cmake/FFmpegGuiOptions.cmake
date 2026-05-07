include_guard(GLOBAL)

function(_ffmpeg_gui_cache_help _out _canonical _fallback)
    get_property(_ffmpeg_help CACHE "${_canonical}" PROPERTY HELPSTRING)
    if(NOT _ffmpeg_help)
        set(_ffmpeg_help "${_fallback}")
    endif()
    set(${_out} "${_ffmpeg_help}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_gui_cache_type _out _canonical _fallback)
    get_property(_ffmpeg_type CACHE "${_canonical}" PROPERTY TYPE)
    if(NOT _ffmpeg_type)
        set(_ffmpeg_type "${_fallback}")
    endif()
    set(${_out} "${_ffmpeg_type}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_gui_copy_strings _alias _canonical)
    get_property(_ffmpeg_strings CACHE "${_canonical}" PROPERTY STRINGS)
    if(_ffmpeg_strings)
        set_property(CACHE "${_alias}" PROPERTY STRINGS ${_ffmpeg_strings})
    endif()
endfunction()

function(_ffmpeg_gui_cache_alias _alias _canonical _type _default _help)
    if(NOT DEFINED ${_canonical})
        set(${_canonical} "${_default}" CACHE "${_type}" "${_help}")
    endif()

    _ffmpeg_gui_cache_type(_ffmpeg_type "${_canonical}" "${_type}")
    _ffmpeg_gui_cache_help(_ffmpeg_help "${_canonical}" "${_help}")

    if(NOT DEFINED ${_alias})
        set(${_alias} "${${_canonical}}" CACHE "${_ffmpeg_type}" "${_ffmpeg_help}")
    endif()

    set(_ffmpeg_last_alias_var "FFMPEG_GUI_LAST_${_alias}")
    set(_ffmpeg_last_canonical_var "FFMPEG_GUI_LAST_${_canonical}")

    set(_ffmpeg_alias_changed TRUE)
    if(DEFINED ${_ffmpeg_last_alias_var} AND "${${_alias}}" STREQUAL "${${_ffmpeg_last_alias_var}}")
        set(_ffmpeg_alias_changed FALSE)
    endif()

    set(_ffmpeg_canonical_changed FALSE)
    if(DEFINED ${_ffmpeg_last_canonical_var} AND NOT "${${_canonical}}" STREQUAL "${${_ffmpeg_last_canonical_var}}")
        set(_ffmpeg_canonical_changed TRUE)
    endif()

    if(_ffmpeg_alias_changed)
        set(${_canonical} "${${_alias}}" CACHE "${_ffmpeg_type}" "${_ffmpeg_help}" FORCE)
    elseif(_ffmpeg_canonical_changed)
        set(${_alias} "${${_canonical}}" CACHE "${_ffmpeg_type}" "${_ffmpeg_help}" FORCE)
    else()
        set(${_canonical} "${${_alias}}" CACHE "${_ffmpeg_type}" "${_ffmpeg_help}" FORCE)
    endif()

    _ffmpeg_gui_copy_strings("${_alias}" "${_canonical}")
    mark_as_advanced(FORCE "${_canonical}")

    set(${_ffmpeg_last_alias_var} "${${_alias}}" CACHE INTERNAL "Last synchronized value for ${_alias}" FORCE)
    set(${_ffmpeg_last_canonical_var} "${${_canonical}}" CACHE INTERNAL "Last synchronized value for ${_canonical}" FORCE)
endfunction()

function(_ffmpeg_gui_migrate_removed_alias _old_alias _canonical)
    if(DEFINED ${_old_alias})
        set(_ffmpeg_last_old_alias_var "FFMPEG_GUI_LAST_${_old_alias}")
        if(NOT DEFINED ${_ffmpeg_last_old_alias_var} OR NOT "${${_old_alias}}" STREQUAL "${${_ffmpeg_last_old_alias_var}}")
            get_property(_ffmpeg_type CACHE "${_canonical}" PROPERTY TYPE)
            if(NOT _ffmpeg_type)
                set(_ffmpeg_type STRING)
            endif()
            get_property(_ffmpeg_help CACHE "${_canonical}" PROPERTY HELPSTRING)
            if(NOT _ffmpeg_help)
                set(_ffmpeg_help "Migrated value for ${_canonical}.")
            endif()
            set(${_canonical} "${${_old_alias}}" CACHE "${_ffmpeg_type}" "${_ffmpeg_help}" FORCE)
        endif()
    endif()
    unset(${_old_alias} CACHE)
    unset(FFMPEG_GUI_LAST_${_old_alias} CACHE)
endfunction()

function(ffmpeg_sync_gui_options)
    _ffmpeg_gui_migrate_removed_alias(FFmpegCodecs_NATIVE_ENABLE_EXTERNAL_COMPONENTS FFMPEG_NATIVE_ENABLE_EXTERNAL_COMPONENTS)
    _ffmpeg_gui_migrate_removed_alias(FFmpegFilters_ENABLE_FILTERS FFMPEG_ENABLE_FILTERS)
    _ffmpeg_gui_migrate_removed_alias(FFmpegFilters_DISABLE_FILTERS FFMPEG_DISABLE_FILTERS)

    _ffmpeg_gui_cache_alias(FFmpegDeps_DISABLE_AUTODETECT FFMPEG_DISABLE_AUTODETECT BOOL OFF
        "Disable automatic discovery of optional system libraries.")
    _ffmpeg_gui_cache_alias(FFmpegDeps_NATIVE_AUTODETECT_EXTERNAL_LIBRARIES FFMPEG_NATIVE_AUTODETECT_EXTERNAL_LIBRARIES BOOL ON
        "Detect optional codec/filter/protocol libraries from CMAKE_PREFIX_PATH and pkg-config for the native backend.")
    _ffmpeg_gui_cache_alias(FFmpegDeps_NATIVE_ENABLE_EXTERNAL_COMPONENTS FFMPEG_NATIVE_ENABLE_EXTERNAL_COMPONENTS BOOL ON
        "Enable native codec/filter wrappers when their external libraries are available.")
    _ffmpeg_gui_cache_alias(FFmpegDeps_ENABLE_EXTERNAL_LIBRARIES FFMPEG_ENABLE_EXTERNAL_LIBRARIES STRING ""
        "Semicolon-separated external libraries to force on, for example zlib;openssl;libx264.")
    _ffmpeg_gui_cache_alias(FFmpegDeps_DISABLE_EXTERNAL_LIBRARIES FFMPEG_DISABLE_EXTERNAL_LIBRARIES STRING ""
        "Semicolon-separated external libraries to keep disabled even if found.")
    _ffmpeg_gui_cache_alias(FFmpegDeps_NATIVE_REQUIRE_EXTERNAL_DEPENDENCIES FFMPEG_NATIVE_REQUIRE_EXTERNAL_DEPENDENCIES BOOL ON
        "Stop configure when a requested native FFmpeg dependency cannot be found or imported.")
    _ffmpeg_gui_cache_alias(FFmpegDeps_NATIVE_INSTALL_RUNTIME_DEPENDENCIES FFMPEG_NATIVE_INSTALL_RUNTIME_DEPENDENCIES BOOL ON
        "Install runtime DLL/shared-library dependencies found through CMAKE_PREFIX_PATH.")
    _ffmpeg_gui_cache_alias(FFmpegDeps_NATIVE_AUDIT_DEPENDENCIES FFMPEG_NATIVE_AUDIT_DEPENDENCIES BOOL ON
        "Inspect native external dependency targets and write a static/import/CRT audit report.")
    _ffmpeg_gui_cache_alias(FFmpegDeps_NATIVE_WARN_ON_DEPENDENCY_AUDIT_ISSUES FFMPEG_NATIVE_WARN_ON_DEPENDENCY_AUDIT_ISSUES BOOL ON
        "Emit CMake warnings for native dependency audit issues.")
    _ffmpeg_gui_cache_alias(FFmpegDeps_NATIVE_REQUIRE_STATIC_EXTERNAL_DEPENDENCIES FFMPEG_NATIVE_REQUIRE_STATIC_EXTERNAL_DEPENDENCIES BOOL OFF
        "Fail configure if a native static FFmpeg build links to shared/import external dependency libraries.")
    _ffmpeg_gui_cache_alias(FFmpegDeps_NATIVE_REQUIRE_MATCHED_MSVC_RUNTIME FFMPEG_NATIVE_REQUIRE_MATCHED_MSVC_RUNTIME BOOL OFF
        "Fail configure if native static dependency archives advertise a CRT family that does not match CMAKE_MSVC_RUNTIME_LIBRARY.")
    _ffmpeg_gui_cache_alias(FFmpegDeps_NATIVE_DUMPBIN FFMPEG_NATIVE_DUMPBIN FILEPATH ""
        "Optional dumpbin executable used to inspect MSVC .lib dependencies for import libraries and CRT directives.")

    _ffmpeg_gui_cache_alias(FFmpegCodecs_ENABLE_ENCODERS FFMPEG_ENABLE_ENCODERS STRING ""
        "Semicolon-separated encoder names to force on, for example libx264;h264_nvenc.")
    _ffmpeg_gui_cache_alias(FFmpegCodecs_DISABLE_ENCODERS FFMPEG_DISABLE_ENCODERS STRING ""
        "Semicolon-separated encoder names to force off.")
    _ffmpeg_gui_cache_alias(FFmpegCodecs_ENABLE_DECODERS FFMPEG_ENABLE_DECODERS STRING ""
        "Semicolon-separated decoder names to force on, for example h264;hevc.")
    _ffmpeg_gui_cache_alias(FFmpegCodecs_DISABLE_DECODERS FFMPEG_DISABLE_DECODERS STRING ""
        "Semicolon-separated decoder names to force off.")
    _ffmpeg_gui_cache_alias(FFmpegCodecs_ENABLE_HWACCELS FFMPEG_ENABLE_HWACCELS STRING ""
        "Semicolon-separated hardware acceleration names to force on.")
    _ffmpeg_gui_cache_alias(FFmpegCodecs_DISABLE_HWACCELS FFMPEG_DISABLE_HWACCELS STRING ""
        "Semicolon-separated hardware acceleration names to force off.")

    _ffmpeg_gui_cache_alias(FFmpegCodecs_NATIVE_ENABLE_DEFAULT_COMPONENTS FFMPEG_NATIVE_ENABLE_DEFAULT_COMPONENTS BOOL ON
        "Enable the native backend's default media codec/container/filter component set.")
    _ffmpeg_gui_cache_alias(FFmpegCodecs_NATIVE_DEFAULT_COMPONENT_SET FFMPEG_NATIVE_DEFAULT_COMPONENT_SET STRING "COMMON"
        "Default native component set: COMMON enables typical playback/transcoding basics; ALL tries every built-in component; NONE enables only explicit lists.")
    set_property(CACHE FFmpegCodecs_NATIVE_DEFAULT_COMPONENT_SET PROPERTY STRINGS COMMON ALL NONE)
    _ffmpeg_gui_cache_alias(FFmpegCodecs_NATIVE_ENABLE_HARDWARE_COMPONENTS FFMPEG_NATIVE_ENABLE_HARDWARE_COMPONENTS BOOL ON
        "Enable native hardware codec components when platform headers and SDK libraries are available.")

    _ffmpeg_gui_cache_alias(FFmpegCodecs_NV_CODEC_HEADERS_DIR FFMPEG_NV_CODEC_HEADERS_DIR PATH "${PROJECT_SOURCE_DIR}/nv-codec-headers"
        "Path to nv-codec-headers checkout, install prefix, or include directory.")
    _ffmpeg_gui_cache_alias(FFmpegCodecs_NV_CODEC_HEADERS_GIT_CLONE FFMPEG_NV_CODEC_HEADERS_GIT_CLONE BOOL OFF
        "Clone nv-codec-headers into the configured in-tree path when missing.")
    _ffmpeg_gui_cache_alias(FFmpegCodecs_NV_CODEC_HEADERS_GIT_UPDATE FFMPEG_NV_CODEC_HEADERS_GIT_UPDATE BOOL OFF
        "Fetch and update the managed in-tree nv-codec-headers checkout during configure.")
    _ffmpeg_gui_cache_alias(FFmpegCodecs_NV_CODEC_HEADERS_GIT_REF FFMPEG_NV_CODEC_HEADERS_GIT_REF STRING ""
        "Optional nv-codec-headers branch, tag, or commit.")
    _ffmpeg_gui_cache_alias(FFmpegCodecs_NV_CODEC_HEADERS_GIT_DETACHED_HEAD FFMPEG_NV_CODEC_HEADERS_GIT_DETACHED_HEAD BOOL OFF
        "Check out the nv-codec-headers ref as a detached HEAD.")
    _ffmpeg_gui_cache_alias(FFmpegCodecs_NV_CODEC_HEADERS_VERSION FFMPEG_NV_CODEC_HEADERS_VERSION STRING ""
        "Version used when generating an ffnvcodec pkg-config file for headers from a source/include path.")

    _ffmpeg_gui_cache_alias(FFmpegCodecs_AMF_HEADERS_DIR FFMPEG_AMF_HEADERS_DIR PATH "${PROJECT_SOURCE_DIR}/amf"
        "Path to AMD AMF headers checkout, install prefix, or include directory.")
    _ffmpeg_gui_cache_alias(FFmpegCodecs_AMF_HEADERS_GIT_CLONE FFMPEG_AMF_HEADERS_GIT_CLONE BOOL OFF
        "Clone AMD AMF headers into the configured in-tree path when missing.")
    _ffmpeg_gui_cache_alias(FFmpegCodecs_AMF_HEADERS_GIT_UPDATE FFMPEG_AMF_HEADERS_GIT_UPDATE BOOL OFF
        "Fetch and update the managed in-tree AMD AMF headers checkout during configure.")
    _ffmpeg_gui_cache_alias(FFmpegCodecs_AMF_HEADERS_GIT_REF FFMPEG_AMF_HEADERS_GIT_REF STRING ""
        "Optional AMD AMF headers branch, tag, or commit.")
    _ffmpeg_gui_cache_alias(FFmpegCodecs_AMF_HEADERS_GIT_DETACHED_HEAD FFMPEG_AMF_HEADERS_GIT_DETACHED_HEAD BOOL OFF
        "Check out the AMD AMF headers ref as a detached HEAD.")

    _ffmpeg_gui_cache_alias(FFmpegCodecs_NATIVE_ENABLE_HARDWARE_SMOKE_TESTS FFMPEG_NATIVE_ENABLE_HARDWARE_SMOKE_TESTS BOOL OFF
        "Add opt-in CTest tests that execute tiny hardware encode/decode jobs.")
    _ffmpeg_gui_cache_alias(FFmpegCodecs_NATIVE_HARDWARE_SMOKE_TEST_TIMEOUT FFMPEG_NATIVE_HARDWARE_SMOKE_TEST_TIMEOUT STRING "60"
        "Timeout in seconds for each hardware execution smoke test.")

    _ffmpeg_gui_cache_alias(FFmpegCodecs_ENABLE_FILTERS FFMPEG_ENABLE_FILTERS STRING ""
        "Semicolon-separated filter names to force on, for example scale;aresample.")
    _ffmpeg_gui_cache_alias(FFmpegCodecs_DISABLE_FILTERS FFMPEG_DISABLE_FILTERS STRING ""
        "Semicolon-separated filter names to force off.")
endfunction()
