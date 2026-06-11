///|
/// Hash algorithms an evidence pack may declare. Only SHA-256 today; the
/// enum keeps call sites total so adding an algorithm is a compile-guided
/// change.
pub(all) enum HashAlgorithm {
  Sha256
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
  }
}

///|
/// Maps a user-supplied algorithm name to the enum, accepting the common
/// `sha256` / `SHA-256` spellings case-insensitively; `None` when unknown.
pub fn normalize_algorithm(name : String) -> HashAlgorithm? {
  let folded = name[:].to_lower().to_owned()
  if folded == "sha256" || folded == "sha-256" {
    Some(Sha256)
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
