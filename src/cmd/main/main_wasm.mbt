// Wasm-only: stderr bridge fallback. The wasm / wasm-gc backends have no
// standard-error stream, so warnings fall back to `println` (stdout) to ensure
// the message is at least visible. The CLI is not run on wasm in practice
// (it runs via node on `js` or natively on `native`); this implementation
// only needs to compile and behave sensibly.
//
// Compiled for the `wasm` / `wasm-gc` targets only (see moon.pkg `targets`).

///|
/// Writes `s` followed by a newline to standard output (wasm has no stderr).
fn warn_stderr(s : String) -> Unit {
  println(s)
}
