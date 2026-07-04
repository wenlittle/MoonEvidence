///|
/// Hash algorithms an evidence pack may declare. Only SHA-256 today; the
/// enum keeps call sites total so adding an algorithm is a compile-guided
/// change.
pub(all) enum HashAlgorithm {
  Sha256
  Sha512
} derive(Eq, @debug.Debug)

///|
/// A parsed digest value: the algorithm tag plus the lowercase hex of the
/// raw hash bytes - the two halves of the canonical `algorithm:hex` form.
pub(all) struct Digest {
  algorithm : HashAlgorithm
  hex : String
} derive(Eq, @debug.Debug)

///|
/// Renders the algorithm as its canonical lowercase label (e.g. `sha256`),
/// matching the prefix used in digest text form.
pub impl Show for HashAlgorithm with fn output(self, logger) {
  logger.write_string(self.label())
}

///|
/// Renders the digest in evidence-pack text form `algorithm:hex`, so test
/// failures and diagnostics print the same string users see in manifests.
pub impl Show for Digest with fn output(self, logger) {
  logger.write_string(self.to_string())
}

///|
/// Canonical lowercase label of the algorithm (`sha256`), the spelling
/// manifests use both standalone and as the digest text-form prefix.
pub fn HashAlgorithm::label(self : HashAlgorithm) -> String {
  match self {
    Sha256 => "sha256"
    Sha512 => "sha512"
  }
}

///|
/// Maps a user-supplied algorithm name to the enum, accepting the common
/// `sha256` / `SHA-256` spellings case-insensitively; `None` when unknown.
pub fn normalize_algorithm(name : String) -> HashAlgorithm? {
  let folded = name[:].to_lower().to_owned()
  if folded == "sha256" || folded == "sha-256" {
    Some(Sha256)
  } else if folded == "sha512" || folded == "sha-512" {
    Some(Sha512)
  } else {
    None
  }
}

///|
/// Whether `name` resolves to a supported algorithm (E2001 gate).
pub fn is_supported_algorithm(name : String) -> Bool {
  normalize_algorithm(name) is Some(_)
}

///|
/// Whether `input` is non-empty and pure ASCII hex (either case).
pub fn is_hex(input : String) -> Bool {
  input.length() > 0 && input.iter().all(c => c.is_ascii_hexdigit())
}

///|
/// Maps a single hex digit byte value (ASCII code) to its 0..15 numeric
/// value; `None` for non-hex characters. Case-insensitive.
fn hex_nibble(byte : Int) -> Int? {
  if byte >= 0x30 && byte <= 0x39 {
    Some(byte - 0x30)
  } else if byte >= 0x61 && byte <= 0x66 {
    Some(byte - 0x61 + 10)
  } else if byte >= 0x41 && byte <= 0x46 {
    Some(byte - 0x41 + 10)
  } else {
    None
  }
}

///|
/// Decodes a hex string into bytes, returning `None` when the length is odd
/// or any character is not a hex digit (case-insensitive). This is the
/// single canonical hex decoder for the codebase: every caller that used to
/// silently map invalid characters to 0 (audit) or -1 (merkle tests) now
/// goes through here, so a tampered hex signature surfaces as a
/// verification failure instead of silent byte corruption.
pub fn hex_to_bytes(hex : String) -> Bytes? {
  if hex.length() % 2 != 0 {
    return None
  }
  let out : Array[Byte] = []
  for index in 0..<(hex.length() / 2) {
    let high = hex_nibble(hex[index * 2].to_int())
    let low = hex_nibble(hex[index * 2 + 1].to_int())
    guard high is Some(hi) && low is Some(lo) else { return None }
    out.push(((hi << 4) | lo).to_byte())
  }
  Some(Bytes::from_array(out))
}

///|
/// Lowercases a hex string after validating it with `is_hex`; `None` when
/// the input is empty or contains a non-hex character.
pub fn normalize_hex(input : String) -> String? {
  if is_hex(input) {
    Some(input[:].to_lower().to_owned())
  } else {
    None
  }
}

///|
/// Parses the canonical `algorithm:hex` text form into a `Digest`,
/// normalizing case on both halves; `None` on any shape violation (E2002
/// territory for callers that need an error).
pub fn parse_digest(input : String) -> Digest? {
  let parts = input.split(":").collect()
  guard parts.length() == 2 else { return None }
  guard normalize_algorithm(parts[0].to_owned()) is Some(algorithm) else {
    return None
  }
  guard normalize_hex(parts[1].to_owned()) is Some(hex) else { return None }
  Some({ algorithm, hex })
}

///|
/// Computes the digest of `data` under `algorithm` and returns it as a
/// tagged `Digest` value - the factory bridging raw bytes to the
/// `algorithm:hex` text form used across evidence packs.
pub fn Digest::of_bytes(algorithm : HashAlgorithm, data : Bytes) -> Digest {
  match algorithm {
    Sha256 => { algorithm: Sha256, hex: sha256_hex(data) }
    Sha512 => { algorithm: Sha512, hex: sha512_hex(data) }
  }
}

///|
/// Renders the canonical `algorithm:hex` text form (lowercase throughout).
pub fn Digest::to_string(self : Digest) -> String {
  "\{self.algorithm.label()}:\{self.hex}"
}

///|
/// Compares two digest strings semantically: both must parse, then the
/// normalized values are compared - so case differences never matter and
/// malformed input never equals anything.
pub fn same_digest(left : String, right : String) -> Bool {
  match (parse_digest(left), parse_digest(right)) {
    (Some(a), Some(b)) => a == b
    _ => false
  }
}
