// Official JCS vectors, mirrored from `tests/fixtures/jcs/` (single source
// listed there for the step-7 CLI black-box reuse). Sources: RFC 8785
// section 3.2.3 sorting example and the cyberphone/json-canonicalization
// testdata set, including the number-formatting vectors that require the
// ECMAScript shortest-form algorithm (L2). The RFC 8785 Appendix B number
// table lives in `canonjson_wbtest.mbt` as bit-pattern tests.

fn jcs_canonicalize(input : String) -> String raise {
  canonicalize(input) catch {
    error => fail("unexpected CanonError: \{error}")
  }
}

/// Asserts the vector canonicalizes to `expected` and that the output is a
/// fixed point: canonicalize(canonicalize(x)) == canonicalize(x).
fn assert_jcs_vector(input : String, expected : String) -> Unit raise {
  let canonical = jcs_canonicalize(input)
  assert_eq(canonical, expected)
  assert_eq(jcs_canonicalize(canonical), canonical)
}

test "jcs vector rfc8785 sorting example" {
  // RFC 8785 section 3.2.3: keys sort by UTF-16 code units, so the emoji
  // surrogate pair (d83d/de00) lands before U+FB33 despite its larger code
  // point. U+0080 stays raw (>= 0x20); \r uses the short escape form.
  assert_jcs_vector(
    "{\"\\u20ac\":\"Euro Sign\",\"\\r\":\"Carriage Return\",\"\\ufb33\":\"Hebrew Letter Dalet With Dagesh\",\"1\":\"One\",\"\\ud83d\\ude00\":\"Emoji: Grinning Face\",\"\\u0080\":\"Control\",\"\\u00f6\":\"Latin Small Letter O With Diaeresis\"}",
    "{\"\\r\":\"Carriage Return\",\"1\":\"One\",\"\u{80}\":\"Control\",\"\u{f6}\":\"Latin Small Letter O With Diaeresis\",\"\u{20ac}\":\"Euro Sign\",\"\u{1f600}\":\"Emoji: Grinning Face\",\"\u{fb33}\":\"Hebrew Letter Dalet With Dagesh\"}",
  )
}

test "jcs vector french locale must be ignored" {
  // cyberphone french.json: code-unit order (e < é < ê), not French collation.
  assert_jcs_vector(
    "{\"peach\":\"This sorting order\",\"p\u{e9}ch\u{e9}\":\"is wrong according to French\",\"p\u{ea}che\":\"but canonicalization MUST\",\"sin\":\"ignore locale\"}",
    "{\"peach\":\"This sorting order\",\"p\u{e9}ch\u{e9}\":\"is wrong according to French\",\"p\u{ea}che\":\"but canonicalization MUST\",\"sin\":\"ignore locale\"}",
  )
}

test "jcs vector structures" {
  // cyberphone structures.json: empty key first, "10"/"111" sort as strings
  // not numbers, uppercase before lowercase, 56.0 collapses to 56.
  assert_jcs_vector(
    "{\"1\":{\"f\":{\"f\":\"hi\",\"F\":5},\"\\n\":56.0},\"10\":{},\"\":\"empty\",\"a\":{},\"111\":[{\"e\":\"yes\",\"E\":\"no\"}],\"A\":{}}",
    "{\"\":\"empty\",\"1\":{\"\\n\":56,\"f\":{\"F\":5,\"f\":\"hi\"}},\"10\":{},\"111\":[{\"E\":\"no\",\"e\":\"yes\"}],\"A\":{},\"a\":{}}",
  )
}

test "jcs vector arrays" {
  // cyberphone arrays.json: array order is preserved, nested object sorted.
  assert_jcs_vector(
    "[56, {\"d\": true, \"10\": null, \"1\": [ ]}]",
    "[56,{\"1\":[],\"10\":null,\"d\":true}]",
  )
}

test "jcs vector values full mixed sample" {
  // cyberphone values.json == the RFC 8785 section 3.2.2 worked example:
  // every number requires ES shortest-form rendering (333333333.33333329
  // rounds, 1E30 -> 1e+30, 4.50 -> 4.5, 2e-3 -> 0.002, 1e-27 stays
  // exponential), the string mixes \uXXXX escapes that must collapse to
  // raw text or short escapes, and keys re-sort (literals < numbers <
  // string). Expected output is the RFC section 3.2.3 result.
  assert_jcs_vector(
    "{\"numbers\": [333333333.33333329, 1E30, 4.50, 2e-3, 0.000000000000000000000000001], \"string\": \"\\u20ac$\\u000F\\u000aA'\\u0042\\u0022\\u005c\\\\\\\"\\/\", \"literals\": [null, true, false]}",
    "{\"literals\":[null,true,false],\"numbers\":[333333333.3333333,1e+30,4.5,0.002,1e-27],\"string\":\"\u{20ac}$\\u000f\\nA'B\\\"\\\\\\\\\\\"/\"}",
  )
}

test "canonicalize is idempotent on a mixed document" {
  // Belt-and-braces fixed-point check beyond the official vectors: escapes,
  // surrogate pairs, nested containers, and integer-valued numbers together.
  let input = "{\"z\":[3, 1e2, {\"\\u0001\":\"low\",\"\u{1f600}\":\"emoji\"}],\"a\\\\b\":\"back\\\\slash\",\"nl\":\"line\\nbreak\"}"
  let once = jcs_canonicalize(input)
  let twice = jcs_canonicalize(once)
  assert_eq(once, twice)
}
