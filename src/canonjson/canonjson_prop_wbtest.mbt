// Property tests for canonicalization: randomized documents and rendering
// variants beyond the fixed vectors in canonjson_wbtest.mbt.
//
// Two properties:
//
// 1. Variant convergence - the defining property of a canonical form: any
//    two textual spellings of the same abstract JSON value (shuffled key
//    order, random whitespace, alternative string escapes, equivalent
//    number spellings) canonicalize to identical bytes.
// 2. Idempotence - canonical output is a fixed point of `canonicalize`.
//
// Generators are hand-rolled (splitmix64, fixed seed) so failures replay
// deterministically on every backend; the round number is part of every
// failure message.
//
// Teeth check (mutation-tested by hand before landing): removing the key
// sort fails variant convergence; emitting control characters raw fails the
// fixed-point property (output stops parsing). Number-formatting mutations
// (e.g. passing the parser's source text through) are caught by the fixed
// Appendix B / lossy-integer vectors in canonjson_wbtest.mbt rather than by
// these properties, since equivalent number spellings rarely survive both
// the parser's lossless capture and the variant generator in the same round.

// ---------------------------------------------------------------------------
// Deterministic PRNG (splitmix64)
// ---------------------------------------------------------------------------

priv struct PropRng {
  mut state : UInt64
}

fn PropRng::make(seed : UInt64) -> PropRng {
  { state: seed }
}

fn PropRng::next(self : PropRng) -> UInt64 {
  self.state = self.state + 0x9E3779B97F4A7C15UL
  let mut z = self.state
  z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9UL
  z = (z ^ (z >> 27)) * 0x94D049BB133111EBUL
  z ^ (z >> 31)
}

fn PropRng::below(self : PropRng, bound : Int) -> Int {
  (self.next() % bound.to_uint64()).to_int()
}

fn PropRng::chance(self : PropRng, percent : Int) -> Bool {
  self.below(100) < percent
}

// ---------------------------------------------------------------------------
// Abstract JSON values
// ---------------------------------------------------------------------------

priv enum PropValue {
  PNull
  PBool(Bool)
  PNumber(Double)
  PString(String)
  PArray(Array[PropValue])
  PObject(Array[(String, PropValue)])
}

/// Finite random double mixing the interesting regimes: small integers,
/// decimal-looking values, full random bit patterns (filtered to finite),
/// and ECMAScript notation-threshold magnitudes.
fn random_number(rng : PropRng) -> Double {
  let sign : Double = if rng.chance(30) { -1.0 } else { 1.0 }
  match rng.below(5) {
    0 => sign * rng.below(1000).to_double()
    1 => sign * rng.below(1_000_000).to_double() / 1000.0
    2 =>
      // Around the fixed/exponent notation switch points (1e-7 .. 1e22).
      sign *
      rng.below(100).to_double() *
      [1.0e-8, 1.0e-7, 1.0e-6, 1.0e18, 1.0e20, 1.0e21, 1.0e22][rng.below(7)]
    3 => {
      // Random finite bit pattern: any representable double can appear.
      let bits = rng.next()
      let value = bits.reinterpret_as_double()
      if value != value ||
        value == @double.infinity ||
        value == @double.neg_infinity {
        sign * 0.5
      } else {
        value
      }
    }
    _ => sign * (rng.next() % 9007199254740993UL).to_double()
  }
}

/// Random string mixing printable ASCII, characters JCS must escape,
/// non-ASCII BMP text, and surrogate pairs.
fn random_string(rng : PropRng) -> String {
  let out = StringBuilder::new()
  let length = rng.below(12)
  for _ in 0..<length {
    match rng.below(8) {
      0 => out.write_char(['"', '\\', '/'][rng.below(3)])
      1 =>
        // Control characters: short-escape set and \u00xx territory.
        out.write_char(
          [
            (0x08).unsafe_to_char(),
            (0x0c).unsafe_to_char(),
            (0x0a).unsafe_to_char(),
            (0x0d).unsafe_to_char(),
            (0x09).unsafe_to_char(),
            (0x00).unsafe_to_char(),
            (0x1f).unsafe_to_char(),
          ][rng.below(7)],
        )
      2 => out.write_char(['\u{e9}', '\u{20ac}', '\u{4e2d}', '\u{7f}'][rng.below(4)])
      3 => {
        // Supplementary plane (surrogate pair in UTF-16).
        let scalars = ["\u{1F600}", "\u{10000}", "\u{1D11E}"]
        out.write_string(scalars[rng.below(3)])
      }
      _ =>
        // Printable ASCII.
        out.write_char((0x20 + rng.below(0x5f)).unsafe_to_char())
    }
  }
  out.to_string()
}

fn random_value(rng : PropRng, depth : Int) -> PropValue {
  let pick = if depth <= 0 { rng.below(4) } else { rng.below(6) }
  match pick {
    0 => PNull
    1 => PBool(rng.chance(50))
    2 => PNumber(random_number(rng))
    3 => PString(random_string(rng))
    4 => {
      let items : Array[PropValue] = []
      for _ in 0..<rng.below(5) {
        items.push(random_value(rng, depth - 1))
      }
      PArray(items)
    }
    _ => {
      let fields : Array[(String, PropValue)] = []
      let used : Array[String] = []
      for index in 0..<rng.below(5) {
        // Suffix with the index so keys stay unique even when the random
        // part collides (duplicate keys are not a JCS document).
        let key = "\{random_string(rng)}#\{index}"
        if used.contains(key) {
          continue
        }
        used.push(key)
        fields.push((key, random_value(rng, depth - 1)))
      }
      PObject(fields)
    }
  }
}

// ---------------------------------------------------------------------------
// Variant rendering: many spellings of the same value
// ---------------------------------------------------------------------------

let upper_hex_digits : FixedArray[Char] = [
  '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F',
]

fn write_unicode_escape(rng : PropRng, unit : Int, out : StringBuilder) -> Unit {
  // JSON allows either hex case inside \uXXXX; flip per escape.
  let digits = if rng.chance(50) { lower_hex_digits } else { upper_hex_digits }
  out.write_string("\\u")
  out.write_char(digits[(unit >> 12) & 0xf])
  out.write_char(digits[(unit >> 8) & 0xf])
  out.write_char(digits[(unit >> 4) & 0xf])
  out.write_char(digits[unit & 0xf])
}

/// Renders `text` as a JSON string literal, randomly choosing among the
/// legal spellings of every code unit (raw, short escape, \uXXXX).
fn render_string_variant(rng : PropRng, text : String, out : StringBuilder) -> Unit {
  out.write_char('"')
  let mut index = 0
  while index < text.length() {
    let unit = text[index].to_int()
    // Surrogate pairs: one escape decision covers both halves. JSON has no
    // portable "one half escaped, one half raw" spelling of a pair.
    if unit >= 0xd800 && unit <= 0xdbff && index + 1 < text.length() {
      let low = text[index + 1].to_int()
      if low >= 0xdc00 && low <= 0xdfff {
        if rng.chance(40) {
          write_unicode_escape(rng, unit, out)
          write_unicode_escape(rng, low, out)
        } else {
          out.write_view(text[index:index + 2])
        }
        index = index + 2
        continue
      }
    }
    let short : String? = match unit {
      0x22 => Some("\\\"")
      0x5c => Some("\\\\")
      0x08 => Some("\\b")
      0x0c => Some("\\f")
      0x0a => Some("\\n")
      0x0d => Some("\\r")
      0x09 => Some("\\t")
      0x2f => Some("\\/")
      _ => None
    }
    if short is Some(sequence) && rng.chance(50) {
      out.write_string(sequence)
    } else if unit < 0x20 || unit == 0x22 || unit == 0x5c {
      // No raw spelling exists for controls, the quote, or the backslash;
      // when the short escape was not picked, \uXXXX is the only fallback.
      write_unicode_escape(rng, unit, out)
    } else if rng.chance(25) {
      // Any non-surrogate code unit may also be \u-escaped.
      write_unicode_escape(rng, unit, out)
    } else {
      out.write_char(unit.unsafe_to_char())
    }
    index = index + 1
  }
  out.write_char('"')
}

/// Renders a number through its canonical text, then applies value-preserving
/// spelling tweaks: trailing fraction zeros, explicit `e0` exponents,
/// exponent case/sign/zero-padding variations.
fn render_number_variant(rng : PropRng, value : Double, out : StringBuilder) -> Unit {
  let canonical = value.to_string()
  let has_exponent = canonical.contains("e")
  let has_fraction = canonical.contains(".")
  if has_exponent {
    let text = if rng.chance(50) {
      canonical.replace(old="e", new="E")
    } else {
      canonical
    }
    // `1e+30` may drop the plus or zero-pad the exponent; both parse back
    // to the same double because the decimal value is unchanged.
    let text = if rng.chance(40) {
      text.replace(old="+", new="")
    } else {
      text
    }
    out.write_string(text)
    return
  }
  out.write_string(canonical)
  if has_fraction {
    if rng.chance(40) {
      for _ in 0..<(1 + rng.below(3)) {
        out.write_char('0') // 12.34 -> 12.340 (same decimal value)
      }
    }
  } else if rng.chance(40) {
    out.write_string(".0") // 42 -> 42.0
  }
  if rng.chance(30) {
    out.write_string(if rng.chance(50) { "e0" } else { "E0" })
  }
}

fn write_whitespace(rng : PropRng, out : StringBuilder) -> Unit {
  for _ in 0..<rng.below(3) {
    out.write_char([' ', '\t', '\n', '\r'][rng.below(4)])
  }
}

/// Renders one randomly spelled JSON text for `value`: shuffled object key
/// order, random inter-token whitespace, random string/number spellings.
fn render_variant(rng : PropRng, value : PropValue, out : StringBuilder) -> Unit {
  match value {
    PNull => out.write_string("null")
    PBool(true) => out.write_string("true")
    PBool(false) => out.write_string("false")
    PNumber(number) => render_number_variant(rng, number, out)
    PString(text) => render_string_variant(rng, text, out)
    PArray(items) => {
      out.write_char('[')
      for index in 0..<items.length() {
        if index > 0 {
          out.write_char(',')
        }
        write_whitespace(rng, out)
        render_variant(rng, items[index], out)
        write_whitespace(rng, out)
      }
      out.write_char(']')
    }
    PObject(fields) => {
      // Shuffle the emission order (Fisher-Yates on a copy of the indexes);
      // canonicalization must converge to the sorted order regardless.
      let order : Array[Int] = []
      for index in 0..<fields.length() {
        order.push(index)
      }
      for index = order.length() - 1; index > 0; index = index - 1 {
        let swap = rng.below(index + 1)
        let kept = order[index]
        order[index] = order[swap]
        order[swap] = kept
      }
      out.write_char('{')
      for position in 0..<order.length() {
        if position > 0 {
          out.write_char(',')
        }
        write_whitespace(rng, out)
        let (key, field_value) = fields[order[position]]
        render_string_variant(rng, key, out)
        write_whitespace(rng, out)
        out.write_char(':')
        write_whitespace(rng, out)
        render_variant(rng, field_value, out)
        write_whitespace(rng, out)
      }
      out.write_char('}')
    }
  }
}

fn render_variant_text(rng : PropRng, value : PropValue) -> String {
  let out = StringBuilder::new()
  render_variant(rng, value, out)
  out.to_string()
}

// ---------------------------------------------------------------------------
// Properties
// ---------------------------------------------------------------------------

test "property: every spelling of a value canonicalizes to the same bytes" {
  let rng = PropRng::make(0x6a63732d70726f70UL) // "jcs-prop"
  for round in 0..<150 {
    let value = random_value(rng, 3)
    let first = render_variant_text(rng, value)
    let second = render_variant_text(rng, value)
    let canonical_first = canonicalize(first) catch {
      error => fail("round \{round}: variant 1 rejected: \{error}\n\{first}")
    }
    let canonical_second = canonicalize(second) catch {
      error => fail("round \{round}: variant 2 rejected: \{error}\n\{second}")
    }
    if canonical_first != canonical_second {
      fail(
        "round \{round}: variants diverged\n in 1: \{first}\n in 2: \{second}\nout 1: \{canonical_first}\nout 2: \{canonical_second}",
      )
    }
  }
}

test "property: canonical output is a fixed point of canonicalize" {
  let rng = PropRng::make(0x6a63732d70726f71UL)
  for round in 0..<150 {
    let value = random_value(rng, 3)
    let text = render_variant_text(rng, value)
    let once = canonicalize(text) catch {
      error => fail("round \{round}: input rejected: \{error}\n\{text}")
    }
    let twice = canonicalize(once) catch {
      error => fail("round \{round}: canonical output rejected: \{error}\n\{once}")
    }
    if once != twice {
      fail(
        "round \{round}: not a fixed point\nonce : \{once}\ntwice: \{twice}",
      )
    }
  }
}
