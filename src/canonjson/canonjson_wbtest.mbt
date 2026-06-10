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
// Number policy L1: exact integers only
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

test "numbers reject fractions under l1 policy" {
  let result = try? canonicalize("[12.34]")
  assert_true(result is Err(UnsupportedNumber(_)))
}

test "numbers reject small exponents that are not integers" {
  let result = try? canonicalize("[2e-3]")
  assert_true(result is Err(UnsupportedNumber(_)))
}

test "numbers reject integers beyond double precision" {
  // 2^53 + 1 cannot be represented exactly; emitting any digits would risk
  // a digest mismatch with a correct JCS implementation.
  let result = try? canonicalize("[9007199254740993]")
  assert_true(result is Err(UnsupportedNumber(_)))
}

test "numbers reject large magnitude exponents" {
  let result = try? canonicalize("[1e30]")
  assert_true(result is Err(UnsupportedNumber(_)))
}

test "numbers reject overflow to infinity" {
  // The parser keeps the source text for values beyond double range.
  let result = try? canonicalize("[1e999]")
  assert_true(result is Err(UnsupportedNumber(_)))
}
