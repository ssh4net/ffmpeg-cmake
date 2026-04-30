include_guard(GLOBAL)

include(CheckSymbolExists)

function(_ffmpeg_native_detect_base_have)
    set(_ffmpeg_enabled_have
        atanf
        atan2f
        cbrt
        cbrtf
        copysign
        cosf
        erf
        expf
        exp2
        exp2f
        hypot
        isfinite
        isinf
        isnan
        ldexpf
        llrint
        llrintf
        log2
        log2f
        log10f
        lrint
        lrintf
        powf
        rint
        round
        roundf
        sinf
        trunc
        truncf
        getenv)

    if(CMAKE_C_BYTE_ORDER STREQUAL "BIG_ENDIAN")
        list(APPEND _ffmpeg_enabled_have bigendian)
    endif()

    if(CMAKE_SIZEOF_VOID_P EQUAL 8)
        list(APPEND _ffmpeg_enabled_have fast_64bit)
    endif()

    if(CMAKE_SYSTEM_PROCESSOR MATCHES "^(x86_64|AMD64|amd64|x64|x86|i[3-6]86|X86)$")
        list(APPEND _ffmpeg_enabled_have fast_unaligned)
    endif()

    if(FFMPEG_NATIVE_ENABLE_THREADS)
        list(APPEND _ffmpeg_enabled_have threads)
        if(WIN32)
            list(APPEND _ffmpeg_enabled_have w32threads)
        else()
            list(APPEND _ffmpeg_enabled_have pthreads)
        endif()
    endif()

    if(FFMPEG_NATIVE_ENABLE_ASM AND CMAKE_SYSTEM_PROCESSOR MATCHES "^(x86_64|AMD64|amd64|x64|x86|i[3-6]86|X86)$")
        _ffmpeg_native_expand_configure_list(_ffmpeg_x86_ext ARCH_EXT_LIST_X86)
        _ffmpeg_native_expand_configure_list(_ffmpeg_x86_simd_ext ARCH_EXT_LIST_X86_SIMD)
        list(APPEND _ffmpeg_enabled_have x86asm ${_ffmpeg_x86_ext})
        foreach(_ffmpeg_x86_feature IN LISTS _ffmpeg_x86_simd_ext)
            list(APPEND _ffmpeg_enabled_have "${_ffmpeg_x86_feature}_external")
        endforeach()
    endif()

    if(WIN32)
        check_symbol_exists(_aligned_malloc "malloc.h" FFMPEG_NATIVE_HAVE_ALIGNED_MALLOC)
        if(FFMPEG_NATIVE_HAVE_ALIGNED_MALLOC)
            list(APPEND _ffmpeg_enabled_have
                aligned_malloc
                malloc_h)
        endif()
        list(APPEND _ffmpeg_enabled_have
            CommandLineToArgvW
            GetModuleHandle
            GetProcessAffinityMask
            GetStdHandle
            GetSystemTimeAsFileTime
            MapViewOfFile
            MemoryBarrier
            SetConsoleTextAttribute
            VirtualAlloc
            dos_paths
            io_h
            libc_msvcrt
            windows_h
            winsock2_h)
    elseif(APPLE)
        list(APPEND _ffmpeg_enabled_have
            access
            clock_gettime
            dirent_h
            fcntl
            fork
            gettimeofday
            isatty
            lstat
            mach_absolute_time
            mmap
            posix_memalign
            sys_time_h
            sys_un_h
            unistd_h)
    else()
        list(APPEND _ffmpeg_enabled_have
            access
            clock_gettime
            dirent_h
            fcntl
            fork
            gettimeofday
            isatty
            lstat
            mkstemp
            mmap
            posix_memalign
            sysconf
            sys_time_h
            sys_un_h
            unistd_h)
    endif()

    list(REMOVE_DUPLICATES _ffmpeg_enabled_have)
    set(_ffmpeg_enabled_have "${_ffmpeg_enabled_have}" PARENT_SCOPE)
endfunction()

function(_ffmpeg_native_detect_arch)
    set(_ffmpeg_enabled_arch)
    if(CMAKE_SYSTEM_PROCESSOR MATCHES "^(x86_64|AMD64|amd64|x64)$")
        list(APPEND _ffmpeg_enabled_arch x86 x86_64)
    elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "^(x86|i[3-6]86|X86)$")
        list(APPEND _ffmpeg_enabled_arch x86 x86_32)
    elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "^(aarch64|ARM64|arm64)$")
        list(APPEND _ffmpeg_enabled_arch aarch64)
    elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "^(arm|ARM)")
        list(APPEND _ffmpeg_enabled_arch arm)
    elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "^(riscv64|riscv)$")
        list(APPEND _ffmpeg_enabled_arch riscv)
    elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "^(ppc64|powerpc64)$")
        list(APPEND _ffmpeg_enabled_arch ppc ppc64)
    elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "^(ppc|powerpc)$")
        list(APPEND _ffmpeg_enabled_arch ppc)
    endif()
    set(_ffmpeg_enabled_arch "${_ffmpeg_enabled_arch}" PARENT_SCOPE)
endfunction()
