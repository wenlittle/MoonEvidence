// MoonBit strings are UTF-16, but every digest in an evidence pack is defined
// over UTF-8 bytes (the wire format of canonical JSON). This file owns the
// explicit UTF-16 -> UTF-8 transcoding step so the rest of the library never
// hashes platform-dependent string representations by accident.

/// Encodes `input` (UTF-16) into UTF-8 bytes.
///
/// Well-formed surrogate pairs become 4-byte sequences. An unpaired
/// surrogate cannot be represented in UTF-8, so it is replaced with
/// U+FFFD - the same behavior as the WHATWG TextEncoder used by the
/// JavaScript reference implementation, keeping cross-implementation
/// digests identical even on malformed input.
pub fn string_to_utf8_bytes(input : String) -> Bytes {
  let output : Array[Byte] = []
  let mut index = 0
  while index < input.length() {
    let unit = input[index].to_int()
    let mut code_point = unit
    if unit >= 0xd800 && unit <= 0xdbff {
      // High surrogate: valid only when a low surrogate follows.
      if index + 1 < input.length() {
        let next = input[index + 1].to_int()
        if next >= 0xdc00 && next <= 0xdfff {
          code_point = 0x10000 + ((unit - 0xd800) << 10) + (next - 0xdc00)
          index = index + 1
        } else {
          code_point = 0xfffd
        }
      } else {
        code_point = 0xfffd
      }
    } else if unit >= 0xdc00 && unit <= 0xdfff {
      // Low surrogate without a preceding high surrogate.
      code_point = 0xfffd
    }
    write_code_point(output, code_point)
    index = index + 1
  }
  Bytes::from_array(output)
}

/// Appends the UTF-8 encoding of one Unicode scalar value (RFC 3629):
/// 1 byte up to U+007F, 2 up to U+07FF, 3 up to U+FFFF, otherwise 4.
fn write_code_point(output : Array[Byte], code_point : Int) -> Unit {
  if code_point < 0x80 {
    output.push(code_point.to_byte())
  } else if code_point < 0x800 {
    output.push((0xc0 | (code_point >> 6)).to_byte())
    output.push((0x80 | (code_point & 0x3f)).to_byte())
  } else if code_point < 0x10000 {
    output.push((0xe0 | (code_point >> 12)).to_byte())
    output.push((0x80 | ((code_point >> 6) & 0x3f)).to_byte())
    output.push((0x80 | (code_point & 0x3f)).to_byte())
  } else {
    output.push((0xf0 | (code_point >> 18)).to_byte())
    output.push((0x80 | ((code_point >> 12) & 0x3f)).to_byte())
    output.push((0x80 | ((code_point >> 6) & 0x3f)).to_byte())
    output.push((0x80 | (code_point & 0x3f)).to_byte())
  }
}
