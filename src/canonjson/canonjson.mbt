// RFC 8785 (JSON Canonicalization Scheme) serializer.
//
// Scope: full JCS string escaping (section 3.2.2.2) and UTF-16 code unit key
// ordering (section 3.2.3). Number serialization implements the L1 "safe
// subset" policy: integers within +/-(2^53 - 1) render exactly; every other
// number raises `UnsupportedNumber` instead of guessing a representation.
// The full ECMAScript shortest-round-trip formatting (L2) is a planned
// hardening step tracked in the master plan.

// ---------------------------------------------------------------------------
// Errors
// ---------------------------------------------------------------------------

/// Failure modes of canonicalization. Carried text is diagnostic context
/// (parser detail or the offending number) for explain-style reporting.
pub(all) suberror CanonError {
  /// Input is not valid JSON. Payload is the upstream parser diagnostic.
  ParseFailed(String)
  /// Number cannot be rendered under the L1 safe-subset policy. Payload is
  /// the rejected value's text form.
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
/// keys sorted by UTF-16 code units, JCS string escaping, and L1 safe-subset
/// numbers. The output is the byte-stable payload evidence digests are
/// computed over.
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
// Number serialization (L1 safe subset)
// ---------------------------------------------------------------------------

/// Largest integer a Double represents exactly (2^53 - 1, IEEE 754 binary64).
const SAFE_INTEGER_LIMIT : Double = 9007199254740991

/// L1 policy: render integers in the exact range as plain decimal text
/// (`-0` collapses to `0` via the Int64 conversion); raise on everything
/// else rather than risk a digest that disagrees with RFC 8785.
fn render_number(
  number : Double,
  repr : String?,
  out : StringBuilder,
) -> Unit raise CanonError {
  // The parser keeps the source text only for values that overflowed to
  // infinity (e.g. 1e999); those are never representable.
  if repr is Some(source) {
    raise CanonError::UnsupportedNumber(source)
  }
  if number != number {
    raise CanonError::UnsupportedNumber("NaN")
  }
  if number == @double.infinity || number == @double.neg_infinity {
    raise CanonError::UnsupportedNumber("Infinity")
  }
  if @double.trunc(number) == number && number.abs() <= SAFE_INTEGER_LIMIT {
    out.write_string(number.to_int64().to_string())
  } else {
    raise CanonError::UnsupportedNumber(number.to_string())
  }
}
