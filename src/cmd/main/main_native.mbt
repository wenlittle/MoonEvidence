// Native-only: stderr bridge. MoonBit core exposes `println` (stdout) only;
// this file provides `warn_stderr` via a C FFI stub (`native_stub.c`) so the
// CLI can route warnings to standard error, leaving stdout free for
// machine-readable JSON / explain reports.
//
// Compiled for the `native` / `llvm` targets only (see moon.pkg `targets`).

///|
#borrow(s)
extern "C" fn eprintln_stderr_ffi(s : Bytes, len : Int) -> Unit = "moon_evidence_eprintln_stderr"

///|
/// Writes `s` (as UTF-8) followed by a newline to standard error.
fn warn_stderr(s : String) -> Unit {
  let bytes = @digest.string_to_utf8_bytes(s)
  eprintln_stderr_ffi(bytes, bytes.length())
}
