// UTF-8 boundary code points are written as \u{...} escapes so the source
// file stays ASCII-clean. Golden digests were generated with an independent
// reference (.NET System.Text.Encoding.UTF8 + SHA256, 2026-06-11), so the
// MoonBit implementation is cross-checked rather than self-validated.

///|
test "utf8 of ascii is identity" {
  assert_eq(string_to_utf8_bytes("abc"), b"abc")
}

///|
test "utf8 of empty string is empty" {
  assert_eq(string_to_utf8_bytes(""), b"")
}

///|
test "utf8 two byte sequences cover the encoding boundaries" {
  // U+0080 is the smallest 2-byte code point, U+07FF the largest.
  assert_eq(string_to_utf8_bytes("\u{df}"), b"\xc3\x9f")
  assert_eq(string_to_utf8_bytes("\u{80}"), b"\xc2\x80")
  assert_eq(string_to_utf8_bytes("\u{7ff}"), b"\xdf\xbf")
}

///|
test "utf8 three byte sequences cover the encoding boundaries" {
  // U+0800 is the smallest 3-byte code point, U+FFFF the largest.
  assert_eq(string_to_utf8_bytes("\u{800}"), b"\xe0\xa0\x80")
  assert_eq(string_to_utf8_bytes("\u{4e2d}"), b"\xe4\xb8\xad")
  assert_eq(string_to_utf8_bytes("\u{20ac}"), b"\xe2\x82\xac")
  assert_eq(string_to_utf8_bytes("\u{ffff}"), b"\xef\xbf\xbf")
}

///|
test "utf8 four byte sequences decode utf16 surrogate pairs" {
  // U+10000 is the smallest supplementary code point, U+10FFFF the largest;
  // both are stored as surrogate pairs in MoonBit's UTF-16 strings.
  assert_eq(string_to_utf8_bytes("\u{10000}"), b"\xf0\x90\x80\x80")
  assert_eq(string_to_utf8_bytes("\u{1f600}"), b"\xf0\x9f\x98\x80")
  assert_eq(string_to_utf8_bytes("\u{10ffff}"), b"\xf4\x8f\xbf\xbf")
}

///|
test "utf8 of chinese text matches dotnet reference bytes" {
  assert_eq(
    string_to_utf8_bytes("\u{4e2d}\u{6587}"),
    b"\xe4\xb8\xad\xe6\x96\x87",
  )
}

///|
test "sha256 over utf8 chinese text matches dotnet reference digest" {
  inspect(
    sha256_hex(string_to_utf8_bytes("\u{4e2d}\u{6587}")),
    content="72726d8818f693066ceb69afa364218b692e62ea92b385782363780f47529c21",
  )
}

///|
test "sha256 over mixed ascii cjk emoji matches dotnet reference digest" {
  inspect(
    sha256_hex(string_to_utf8_bytes("Hello, \u{4e16}\u{754c}! \u{1f600}")),
    content="3ff31641de75ec0e234643751632026cbcb3193e85946e7ae23dd3c6e6467231",
  )
}
