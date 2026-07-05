// JS-only: stderr bridge. MoonBit core exposes `println` (stdout) only; this
// file provides `warn_stderr` via `console.error` so the CLI (run via node) can
// route warnings to standard error, leaving stdout free for machine-readable
// JSON / explain reports.
//
// Compiled for the `js` target only (see moon.pkg `targets`).

///|
/// Writes `s` followed by a newline to standard error (`console.error`).
extern "js" fn warn_stderr(s : String) -> Unit =
  #| (s) => console.error(s)
