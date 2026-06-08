pub(all) enum HashAlgorithm {
  Sha256
} derive(Eq)

pub(all) struct Digest {
  algorithm : HashAlgorithm
  hex : String
} derive(Eq)

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

pub fn Digest::to_string(self : Digest) -> String {
  "\{self.algorithm.label()}:\{self.hex}"
}

pub fn same_digest(left : String, right : String) -> Bool {
  match (parse_digest(left), parse_digest(right)) {
    (Some(a), Some(b)) => a == b
    _ => false
  }
}
