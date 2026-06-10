pub(all) enum HashAlgorithm {
  Sha256
} derive(Eq)

pub(all) struct Digest {
  algorithm : HashAlgorithm
  hex : String
} derive(Eq)

/// Renders the algorithm as its canonical lowercase label (e.g. `sha256`),
/// matching the prefix used in digest text form.
pub impl Show for HashAlgorithm with output(self, logger) {
  logger.write_string(self.label())
}

/// Renders the digest in evidence-pack text form `algorithm:hex`, so test
/// failures and diagnostics print the same string users see in manifests.
pub impl Show for Digest with output(self, logger) {
  logger.write_string(self.to_string())
}

pub fn HashAlgorithm::label(self : HashAlgorithm) -> String {
  match self {
    Sha256 => "sha256"
  }
}

pub fn normalize_algorithm(name : String) -> HashAlgorithm? {
  let folded = name[:].to_lower().to_owned()
  if folded == "sha256" || folded == "sha-256" {
    Some(Sha256)
  } else {
    None
  }
}

pub fn is_supported_algorithm(name : String) -> Bool {
  normalize_algorithm(name) is Some(_)
}

pub fn is_hex(input : String) -> Bool {
  input.length() > 0 && input.iter().all(c => c.is_ascii_hexdigit())
}

pub fn normalize_hex(input : String) -> String? {
  if is_hex(input) {
    Some(input[:].to_lower().to_owned())
  } else {
    None
  }
}

pub fn parse_digest(input : String) -> Digest? {
  let parts = input.split(":").collect()
  guard parts.length() == 2 else { return None }
  guard normalize_algorithm(parts[0].to_owned()) is Some(algorithm) else {
    return None
  }
  guard normalize_hex(parts[1].to_owned()) is Some(hex) else {
    return None
  }
  Some({ algorithm, hex })
}

/// Computes the digest of `data` under `algorithm` and returns it as a
/// tagged `Digest` value - the factory bridging raw bytes to the
/// `algorithm:hex` text form used across evidence packs.
pub fn Digest::of_bytes(algorithm : HashAlgorithm, data : Bytes) -> Digest {
  match algorithm {
    Sha256 => { algorithm: Sha256, hex: sha256_hex(data) }
  }
}

pub fn Digest::to_string(self : Digest) -> String {
  "\{self.algorithm.label()}:\{self.hex}"
}

pub fn same_digest(left : String, right : String) -> Bool {
  match (parse_digest(left), parse_digest(right)) {
    (Some(a), Some(b)) => a == b
    _ => false
  }
}
