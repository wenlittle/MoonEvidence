// RFC 8785 (JSON Canonicalization Scheme) serializer.
//
// Scope: full JCS string escaping (section 3.2.2.2), UTF-16 code unit key
// ordering (section 3.2.3), and ECMAScript number serialization (section
// 3.2.2.3, the L2 policy): finite values render through the ES-compliant
// shortest-round-trip algorithm, pinned by the RFC 8785 Appendix B vector
// suite. NaN, Infinity, and literals that overflow IEEE 754 double range
// raise `UnsupportedNumber`, as the RFC mandates an error for them.

// ---------------------------------------------------------------------------
// Errors
// ---------------------------------------------------------------------------

/// Failure modes of canonicalization. Carried text is diagnostic context
/// (parser detail or the offending number) for explain-style reporting.
pub(all) suberror CanonError {
  /// Input is not valid JSON. Payload is the upstream parser diagnostic.
  ParseFailed(String)
  /// Number has no RFC 8785 representation: NaN, Infinity, or a literal
  /// whose magnitude overflows IEEE 754 double range. Payload is the
  /// rejected value's text form.
  UnsupportedNumber(String)
} derive(Eq)

/// Renders the error as `kind: detail`, keeping diagnostics single-line.
pub impl Show for CanonError with output(self, logger) {
  match self {
    ParseFailed(detail) => {
      logger.write_string("ParseFailed: ")
      logger.write_string(detail)
    }
    UnsupportedNumber(text) => {
      logger.write_string("UnsupportedNumber: ")
      logger.write_string(text)
    }
  }
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Canonicalizes a JSON document per RFC 8785: minimal whitespace, object
/// keys sorted by UTF-16 code units, JCS string escaping, and ECMAScript
/// shortest-form numbers. The output is the byte-stable payload evidence
/// digests are computed over.
pub fn canonicalize(input : String) -> String raise CanonError {
  let value = @json.parse(input) catch {
    error => raise CanonError::ParseFailed(error.to_json().stringify())
  }
  let out = StringBuilder::new(size_hint=input.length())
  render(value, out)
  out.to_string()
}

/// Returns `None` instead of raising when the input cannot be canonicalized.
pub fn canonicalize_or_none(input : String) -> String? {
  try {
    Some(canonicalize(input))
  } catch {
    (_ : CanonError) => None
  }
}

/// Checks whether two JSON payloads have the same canonical representation.
pub fn same_canonical_payload(left : String, right : String) -> Bool {
  match (canonicalize_or_none(left), canonicalize_or_none(right)) {
    (Some(a), Some(b)) => a == b
    _ => false
  }
}

// ---------------------------------------------------------------------------
// Rendering
// ---------------------------------------------------------------------------

fn render(value : Json, out : StringBuilder) -> Unit raise CanonError {
  match value {
    Null => out.write_string("null")
    True => out.write_string("true")
    False => out.write_string("false")
    Number(number, repr~) => render_number(number, repr, out)
    String(text) => render_string(text, out)
    Array(items) => {
      out.write_char('[')
      for index in 0..<items.length() {
        if index > 0 {
          out.write_char(',')
        }
        render(items[index], out)
      }
      out.write_char(']')
    }
    Object(fields) => {
      let entries = fields.iter().to_array()
      entries.sort_by(fn(left, right) {
        let (left_key, _) = left
        let (right_key, _) = right
        compare_code_units(left_key, right_key)
      })
      out.write_char('{')
      for index in 0..<entries.length() {
        if index > 0 {
          out.write_char(',')
        }
        let (key, field_value) = entries[index]
        render_string(key, out)
        out.write_char(':')
        render(field_value, out)
      }
      out.write_char('}')
    }
  }
}

// ---------------------------------------------------------------------------
// Key ordering (RFC 8785 section 3.2.3)
// ---------------------------------------------------------------------------

/// Pure lexicographic comparison of UTF-16 code units.
///
/// Deliberately NOT the builtin `String::compare`: MoonBit's builtin is
/// shortlex (length first), which would order `"b" < "aa"` and violate
/// RFC 8785. Surrogate halves are compared as raw code units, exactly as
/// the spec requires.
fn compare_code_units(left : String, right : String) -> Int {
  let left_length = left.length()
  let right_length = right.length()
  let shared = if left_length < right_length { left_length } else { right_length }
  for index in 0..<shared {
    let order = left[index].compare(right[index])
    if order != 0 {
      return order
    }
  }
  left_length.compare(right_length)
}

// ---------------------------------------------------------------------------
// String escaping (RFC 8785 section 3.2.2.2)
// ---------------------------------------------------------------------------

let lower_hex_digits : FixedArray[Char] = [
  '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f',
]

/// Serializes one string literal with the exact JCS escape set: `\"`, `\\`,
/// the two-character forms `\b \f \n \r \t`, and `\u00xx` (lowercase hex)
/// for the remaining control characters below U+0020. Every other code unit
/// is emitted verbatim - notably `/`, U+007F, and non-ASCII text.
fn render_string(text : String, out : StringBuilder) -> Unit {
  out.write_char('"')
  let length = text.length()
  let mut plain_start = 0
  for index in 0..<length {
    let unit = text[index].to_int()
    let escape : String? = match unit {
      0x22 => Some("\\\"")
      0x5c => Some("\\\\")
      0x08 => Some("\\b")
      0x0c => Some("\\f")
      0x0a => Some("\\n")
      0x0d => Some("\\r")
      0x09 => Some("\\t")
      _ => None
    }
    if escape is Some(sequence) {
      out.write_view(text[plain_start:index])
      out.write_string(sequence)
      plain_start = index + 1
    } else if unit < 0x20 {
      out.write_view(text[plain_start:index])
      out.write_string("\\u00")
      out.write_char(lower_hex_digits[(unit >> 4) & 0x0f])
      out.write_char(lower_hex_digits[unit & 0x0f])
      plain_start = index + 1
    }
  }
  out.write_view(text[plain_start:length])
  out.write_char('"')
}

// ---------------------------------------------------------------------------
// Number serialization (RFC 8785 section 3.2.2.3, ECMAScript algorithm)
// ---------------------------------------------------------------------------

fn render_number(
  number : Double,
  repr : String?,
  out : StringBuilder,
) -> Unit raise CanonError {
  out.write_string(format_number(number, repr))
}

/// Serializes one JSON number exactly as ECMAScript `Number::toString`
/// would, which is what RFC 8785 requires (section 3.2.2.3 defers to
/// ECMA-262 section 7.1.12.1 including the "Note 2" shortest-form rule).
///
/// MoonBit's builtin `Double::to_string` is a Ryu port explicitly adjusted
/// to the ECMAScript algorithm (js backend calls `Number.prototype.toString`
/// directly), so finite doubles delegate to it; the RFC 8785 Appendix B
/// vector suite in `canonjson_wbtest.mbt` pins this assumption against
/// every published edge case.
fn format_number(number : Double, repr : String?) -> String raise CanonError {
  let resolved : Double = match repr {
    // The parser refuses to silently round literals it cannot capture
    // losslessly (integers beyond 2^53, extreme magnitudes) and hands the
    // source text through. Resolve it to the nearest IEEE 754 double the
    // way an ECMAScript engine would; true overflow stays out of range and
    // is rejected below, exactly like the RFC's Infinity rule.
    Some(source) =>
      @string.parse_double(source) catch {
        _ => raise CanonError::UnsupportedNumber(source)
      }
    None => number
  }
  if resolved != resolved {
    raise CanonError::UnsupportedNumber("NaN")
  }
  if resolved == @double.infinity || resolved == @double.neg_infinity {
    raise CanonError::UnsupportedNumber(
      match repr {
        Some(source) => source
        None => "Infinity"
      },
    )
  }
  resolved.to_string()
}
