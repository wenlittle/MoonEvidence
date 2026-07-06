// Native timing helpers for the Ed25519 dudect-style sampler.
//
// The MoonBit harness calls into the project's own crypto implementation; this
// stub only supplies a monotonic high-resolution timer and prints the native
// toolchain/timer environment used for the run.

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include "moonbit.h"

#if defined(_WIN32)
#include <windows.h>
#else
#include <time.h>
#endif

MOONBIT_FFI_EXPORT int64_t moon_evidence_timing_now_ticks(void) {
#if defined(_WIN32)
  LARGE_INTEGER counter;
  QueryPerformanceCounter(&counter);
  return (int64_t)counter.QuadPart;
#else
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return (int64_t)ts.tv_sec * 1000000000LL + (int64_t)ts.tv_nsec;
#endif
}

MOONBIT_FFI_EXPORT int64_t moon_evidence_timing_ticks_per_second(void) {
#if defined(_WIN32)
  LARGE_INTEGER freq;
  QueryPerformanceFrequency(&freq);
  return (int64_t)freq.QuadPart;
#else
  return 1000000000LL;
#endif
}

MOONBIT_FFI_EXPORT void moon_evidence_timing_print_native_env(void) {
#if defined(_WIN32)
  printf("native_os: Windows\n");
#else
  printf("native_os: POSIX\n");
#endif

#if defined(_MSC_VER)
  printf("native_compiler: MSVC %d\n", _MSC_VER);
#elif defined(__clang__)
  printf("native_compiler: Clang %d.%d.%d\n", __clang_major__, __clang_minor__,
         __clang_patchlevel__);
#elif defined(__GNUC__)
  printf("native_compiler: GCC %d.%d.%d\n", __GNUC__, __GNUC_MINOR__,
         __GNUC_PATCHLEVEL__);
#else
  printf("native_compiler: unknown\n");
#endif

#if defined(_M_X64) || defined(__x86_64__)
  printf("native_arch: x86_64\n");
#elif defined(_M_ARM64) || defined(__aarch64__)
  printf("native_arch: arm64\n");
#else
  printf("native_arch: unknown\n");
#endif

  printf("timer_ticks_per_second: %lld\n",
         (long long)moon_evidence_timing_ticks_per_second());

  const char *cpu = getenv("PROCESSOR_IDENTIFIER");
  if (cpu != NULL && cpu[0] != '\0') {
    printf("processor_identifier: %s\n", cpu);
  }
  fflush(stdout);
}

#ifdef __cplusplus
}
#endif
