// Unit tests for the RFC 8785 serializer. Official JCS vectors live in
// canonjson_jcs_wbtest.mbt; these cover the mechanics piece by piece.

fn must_canonicalize(input : String) -> String raise {
  canonicalize(input) catch {
    error => fail("unexpected CanonError: \{error}")
  }
}

// ---------------------------------------------------------------------------
// Structure
// ---------------------------------------------------------------------------

test "canonicalize removes insignificant whitespace" {
  inspect(
    must_canonicalize("{ \"a\" : 1, \"b\" : true }"),
    content="{\"a\":1,\"b\":true}",
  )
}

test "canonicalize reordered object fields keeps same payload" {
  assert_true(same_canonical_payload("{\"b\":2,\"a\":1}", "{\"a\":1,\"b\":2}"))
}

test "canonicalize invalid json returns none" {
  debug_inspect(canonicalize_or_none("{"), content="None")
}

test "canonicalize invalid json raises parse failed" {
  let result = try? canonicalize("{")
  assert_true(result is Err(ParseFailed(_)))
}

test "canonicalize nested objects sorts keys recursively" {
  inspect(
    must_canonicalize("{\"z\":{\"b\":2,\"a\":1},\"a\":[{\"d\":4,\"c\":3}]}"),
    content="{\"a\":[{\"c\":3,\"d\":4}],\"z\":{\"a\":1,\"b\":2}}",
  )
}

test "canonicalize renders literals and empty containers" {
  inspect(
    must_canonicalize("[null, true, false, [], {}, \"\"]"),
    content="[null,true,false,[],{},\"\"]",
  )
}

// ---------------------------------------------------------------------------
// Key ordering: UTF-16 code units, NOT MoonBit's shortlex builtin
// ---------------------------------------------------------------------------

test "key order is lexicographic not shortlex" {
  // Builtin String::compare is shortlex and would order "b" before "aa".
  // RFC 8785 requires pure code-unit comparison: "aa" < "b" (0x61 < 0x62).
  inspect(
    must_canonicalize("{\"b\":1,\"aa\":2}"),
    content="{\"aa\":2,\"b\":1}",
  )
}

test "key order compares prefixes shorter first" {
  inspect(
    must_canonicalize("{\"ab\":2,\"a\":1}"),
    content="{\"a\":1,\"ab\":2}",
  )
}

test "key order places surrogate pairs by code unit value" {
  // U+10000 is stored as the surrogate pair d800/dc00. Code-unit order puts
  // it BEFORE U+FB33 and U+FF61 even though its code point is larger - the
  // exact case where UTF-16 order and code-point order disagree.
  inspect(
    must_canonicalize(
      "{\"\u{ff61}\":3,\"\u{10000}\":1,\"\u{fb33}\":2}",
    ),
    content="{\"\u{10000}\":1,\"\u{fb33}\":2,\"\u{ff61}\":3}",
  )
}

test "key order handles empty key first" {
  inspect(
    must_canonicalize("{\"a\":2,\"\":1}"),
    content="{\"\":1,\"a\":2}",
  )
}

// ---------------------------------------------------------------------------
// String escaping (RFC 8785 section 3.2.2.2)
// ---------------------------------------------------------------------------

test "escape uses two character forms for control shorthands" {
  // Input uses JSON escapes (raw control characters are invalid in JSON
  // strings); output must use the short two-character forms.
  inspect(
    must_canonicalize("[\"\\b\\f\\n\\r\\t\"]"),
    content="[\"\\b\\f\\n\\r\\t\"]",
  )
}

test "escape quotes and backslashes" {
  inspect(
    must_canonicalize("[\"a\\\"b\\\\c\"]"),
    content="[\"a\\\"b\\\\c\"]",
  )
}

test "escape remaining control characters as lowercase u00xx" {
  // \u0001 and \u001F have no shorthand; JCS mandates lowercase \u00xx.
  // Uppercase hex input must normalize to lowercase output.
  inspect(
    must_canonicalize("[\"\\u0001\\u001F\"]"),
    content="[\"\\u0001\\u001f\"]",
  )
}

test "forward slash is not escaped" {
  inspect(must_canonicalize("[\"a/b\"]"), content="[\"a/b\"]")
}

test "delete and non ascii characters pass through verbatim" {
  // U+007F is above the U+0020 escape threshold; JCS leaves it raw, along
  // with all non-ASCII text (here: euro sign, CJK, emoji surrogate pair).
  inspect(
    must_canonicalize("[\"\u{7f}\u{20ac}\u{4e2d}\u{1f600}\"]"),
    content="[\"\u{7f}\u{20ac}\u{4e2d}\u{1f600}\"]",
  )
}

// ---------------------------------------------------------------------------
// Numbers: ECMAScript serialization (RFC 8785 section 3.2.2.3, L2 policy)
// ---------------------------------------------------------------------------

test "numbers render safe integers verbatim" {
  inspect(
    must_canonicalize("[0,1,-1,42,9007199254740991,-9007199254740991]"),
    content="[0,1,-1,42,9007199254740991,-9007199254740991]",
  )
}

test "numbers collapse integer valued forms to plain decimal" {
  // 5.0, 1e2, and 1E+2 all denote the same integer; RFC 8785 renders the
  // shortest form. -0 must collapse to 0 (section 3.2.2.3).
  inspect(
    must_canonicalize("[5.0,1e2,1E+2,-0,-0.0]"),
    content="[5,100,100,0,0]",
  )
}

test "numbers render fractions in shortest round trip form" {
  // Trailing zeros vanish; the shortest digit string that round-trips to
  // the same double wins (ES "Note 2" rule).
  inspect(
    must_canonicalize("[12.34,4.50,0.1,2e-3,333333333.33333329]"),
    content="[12.34,4.5,0.1,0.002,333333333.3333333]",
  )
}

test "numbers switch to exponent notation at ecmascript thresholds" {
  // Fixed notation covers 1e-6 up to (not including) 1e21; outside that
  // window ES emits exponent form with an explicit sign on the exponent.
  inspect(
    must_canonicalize("[1e21,1e30,0.000001,1e-7,0.000000000000000000000000001]"),
    content="[1e+21,1e+30,0.000001,1e-7,1e-27]",
  )
}

test "numbers round lossy integers like an ecmascript engine" {
  // The MoonBit parser refuses to silently round integer literals beyond
  // 2^53 and hands the source text through; canonicalization must resolve
  // them to the nearest double. 2^53+1 ties to even (2^53); 2^63-1 is the
  // documented cyberphone values case; the third row is ~2^68 from the
  // RFC 8785 Appendix B table via the parser path.
  inspect(
    must_canonicalize(
      "[9007199254740993,9223372036854775807,295147905179352825856]",
    ),
    content="[9007199254740992,9223372036854776000,295147905179352830000]",
  )
}

test "numbers reject overflow to infinity" {
  // Values beyond IEEE 754 double range resolve to Infinity, which JCS
  // must reject (RFC 8785 section 3.2.2.3 note). The parser keeps the
  // source text for both the exponent and long-literal overflow paths.
  let exponent_overflow = try? canonicalize("[1e999]")
  assert_true(exponent_overflow is Err(UnsupportedNumber("1e999")))
  let digits_overflow = try? canonicalize("[-1e309]")
  assert_true(digits_overflow is Err(UnsupportedNumber("-1e309")))
}

test "format_number rejects nan and infinity bit patterns" {
  // JSON cannot spell NaN/Infinity, but the formatter is also the boundary
  // for report rendering; pin the RFC-mandated error on the raw values.
  let nan = try? format_number(
    0x7FFFFFFFFFFFFFFFUL.reinterpret_as_double(),
    None,
  )
  assert_true(nan is Err(UnsupportedNumber("NaN")))
  let infinity = try? format_number(
    0x7FF0000000000000UL.reinterpret_as_double(),
    None,
  )
  assert_true(infinity is Err(UnsupportedNumber("Infinity")))
}

test "jcs number vectors from rfc 8785 appendix b" {
  // Table 1 of RFC 8785 Appendix B: IEEE 754 bit pattern -> required JSON
  // text (also mirrored in tests/fixtures/jcs/numbers-appendix-b.txt).
  // This pins the assumption that MoonBit's Double::to_string implements
  // the ECMAScript shortest-form algorithm on every backend.
  let vectors : Array[(UInt64, String)] = [
    (0x0000000000000000UL, "0"), // zero
    (0x8000000000000000UL, "0"), // minus zero loses its sign
    (0x0000000000000001UL, "5e-324"), // min pos subnormal
    (0x8000000000000001UL, "-5e-324"), // min neg subnormal
    (0x7FEFFFFFFFFFFFFFUL, "1.7976931348623157e+308"), // max pos
    (0xFFEFFFFFFFFFFFFFUL, "-1.7976931348623157e+308"), // max neg
    (0x4340000000000000UL, "9007199254740992"), // 2^53
    (0xC340000000000000UL, "-9007199254740992"), // -2^53
    (0x4430000000000000UL, "295147905179352830000"), // ~2^68
    (0x44B52D02C7E14AF5UL, "9.999999999999997e+22"),
    (0x44B52D02C7E14AF6UL, "1e+23"),
    (0x44B52D02C7E14AF7UL, "1.0000000000000001e+23"),
    (0x444B1AE4D6E2EF4EUL, "999999999999999700000"),
    (0x444B1AE4D6E2EF4FUL, "999999999999999900000"),
    (0x444B1AE4D6E2EF50UL, "1e+21"),
    (0x3EB0C6F7A0B5ED8CUL, "9.999999999999997e-7"),
    (0x3EB0C6F7A0B5ED8DUL, "0.000001"),
    (0x41B3DE4355555553UL, "333333333.3333332"),
    (0x41B3DE4355555554UL, "333333333.33333325"),
    (0x41B3DE4355555555UL, "333333333.3333333"),
    (0x41B3DE4355555556UL, "333333333.3333334"),
    (0x41B3DE4355555557UL, "333333333.33333343"),
    (0xBECBF647612F3696UL, "-0.0000033333333333333333"),
    (0x43143FF3C1CB0959UL, "1424953923781206.2"), // round to even
  ]
  for vector in vectors {
    let (bits, expected) = vector
    let rendered = format_number(bits.reinterpret_as_double(), None) catch {
      error => fail("vector \{expected}: unexpected \{error}")
    }
    assert_eq(rendered, expected)
  }
}
