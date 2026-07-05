// Native stub for stderr output. MoonBit core only exposes `println` (stdout);
// this stub provides a minimal `fprintf(stderr, ...)` bridge so the CLI can
// emit warnings to standard error, keeping stdout clean for machine-readable
// reports.

#ifdef __cplusplus
extern "C" {
#endif

#include <stdio.h>
#include "moonbit.h"

// Write `len` bytes from `s` to stderr, followed by a newline.
// `s` is a borrowed moonbit_bytes_t (uint8_t*); the caller retains ownership.
MOONBIT_FFI_EXPORT void moon_evidence_eprintln_stderr(moonbit_bytes_t s,
                                                       int len) {
  if (len > 0 && s != NULL) {
    fwrite(s, 1, (size_t)len, stderr);
  }
  fputc('\n', stderr);
  fflush(stderr);
}

#ifdef __cplusplus
}
#endif
