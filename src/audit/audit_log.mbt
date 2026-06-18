// Audit log: a hash-chained append-only record of actions performed on an
// evidence pack. Each entry records who did what and when, and chains to
// the previous entry via a SHA-256 hash, making insertions, deletions, and
// reordering detectable.

///|
pub(all) enum AuditAction {
  Created
  Verified
  Sealed
  Signed
  Shared
  Custom(String)
} derive(Eq, @debug.Debug)

///|
pub fn AuditAction::to_string(self : AuditAction) -> String {
  match self {
    Created => "created"
    Verified => "verified"
    Sealed => "sealed"
    Signed => "signed"
    Shared => "shared"
    Custom(s) => s
  }
}

///|
pub fn AuditAction::parse(s : String) -> AuditAction {
  match s {
    "created" => Created
    "verified" => Verified
    "sealed" => Sealed
    "signed" => Signed
    "shared" => Shared
    other => Custom(other)
  }
}

///|
/// One audit log entry in the hash chain.
pub(all) struct AuditEntry {
  timestamp : String
  actor : String
  action : AuditAction
  subject_id : String
  manifest_digest : String?
  prev_hash : String?
  signature : String?
} derive(Eq, @debug.Debug)

///|
/// Computes the canonical hash of an audit entry for chain linking.
pub fn AuditEntry::compute_hash(self : AuditEntry) -> String {
  let digest_json : Json = match self.manifest_digest {
    Some(d) => Json::string(d)
    None => Json::null()
  }
  let prev_json : Json = match self.prev_hash {
    Some(h) => Json::string(h)
    None => Json::null()
  }
  let entry_json = Json::object(
    {
      "timestamp": Json::string(self.timestamp),
      "actor": Json::string(self.actor),
      "action": Json::string(self.action.to_string()),
      "subject_id": Json::string(self.subject_id),
      "manifest_digest": digest_json,
      "prev_hash": prev_json,
    },
  )
  let canonical = try {
    @canonjson.canonicalize(entry_json.stringify())
  } catch {
    _ => entry_json.stringify()
  }
  let bytes = @digest.string_to_utf8_bytes(canonical)
  "sha256:\{@digest.sha256_hex(bytes)}"
}

///|
/// Serializes an audit entry to canonical JSON.
pub fn AuditEntry::to_json(self : AuditEntry) -> String {
  let digest_json : Json = match self.manifest_digest {
    Some(d) => Json::string(d)
    None => Json::null()
  }
  let prev_json : Json = match self.prev_hash {
    Some(h) => Json::string(h)
    None => Json::null()
  }
  let sig_json : Json = match self.signature {
    Some(s) => Json::string(s)
    None => Json::null()
  }
  let entry_json = Json::object(
    {
      "timestamp": Json::string(self.timestamp),
      "actor": Json::string(self.actor),
      "action": Json::string(self.action.to_string()),
      "subject_id": Json::string(self.subject_id),
      "manifest_digest": digest_json,
      "prev_hash": prev_json,
      "hash": Json::string(self.compute_hash()),
      "signature": sig_json,
    },
  )
  try {
    @canonjson.canonicalize(entry_json.stringify())
  } catch {
    _ => entry_json.stringify()
  }
}

///|
/// An append-only audit log backed by a hash chain.
pub struct AuditLog {
  entries : Array[AuditEntry]
  mut last_hash : String?
}

///|
pub fn AuditLog::new() -> AuditLog {
  { entries: [], last_hash: None }
}

///|
/// Appends a new entry, automatically chaining to the previous hash.
pub fn AuditLog::append(
  self : AuditLog,
  timestamp : String,
  actor : String,
  action : AuditAction,
  subject_id : String,
  manifest_digest? : String,
) -> Unit {
  let entry : AuditEntry = {
    timestamp,
    actor,
    action,
    subject_id,
    manifest_digest,
    prev_hash: self.last_hash,
    signature: None,
  }
  let hash = entry.compute_hash()
  self.entries.push(entry)
  self.last_hash = Some(hash)
}

///|
/// Verifies the hash chain integrity: each entry's prev_hash must match
/// the computed hash of the preceding entry.
pub fn AuditLog::verify_chain(self : AuditLog) -> Bool {
  let mut prev_hash : String? = None
  for entry in self.entries {
    if entry.prev_hash != prev_hash {
      return false
    }
    prev_hash = Some(entry.compute_hash())
  }
  true
}

///|
pub fn AuditLog::length(self : AuditLog) -> Int {
  self.entries.length()
}

///|
/// Signs the last entry in the log with Ed25519.
pub fn AuditLog::sign_last(self : AuditLog, sk : Bytes) -> Unit {
  if self.entries.length() == 0 {
    return
  }
  let idx = self.entries.length() - 1
  let entry = self.entries[idx]
  let hash_str = entry.compute_hash()
  let hash_bytes = @digest.string_to_utf8_bytes(hash_str)
  let sig = @crypto.ed25519_sign(sk, hash_bytes)
  let sig_hex = @digest.bytes_to_lower_hex(sig)
  let signed_entry : AuditEntry = {
    timestamp: entry.timestamp,
    actor: entry.actor,
    action: entry.action,
    subject_id: entry.subject_id,
    manifest_digest: entry.manifest_digest,
    prev_hash: entry.prev_hash,
    signature: Some(sig_hex),
  }
  self.entries[idx] = signed_entry
}

///|
/// Verifies all Ed25519 signatures in the log.
/// Entries without signatures are skipped (returns true for them).
pub fn AuditLog::verify_signatures(self : AuditLog, pk : Bytes) -> Bool {
  for entry in self.entries {
    match entry.signature {
      Some(sig_hex) => {
        let hash_str = entry.compute_hash()
        let hash_bytes = @digest.string_to_utf8_bytes(hash_str)
        let sig = hex_to_bytes(sig_hex)
        if @crypto.ed25519_verify(pk, hash_bytes, sig) == false {
          return false
        }
      }
      None => ()
    }
  }
  true
}

///|
fn hex_to_bytes(hex : String) -> Bytes {
  let chars = hex.to_array()
  let arr : Array[Byte] = []
  let mut i = 0
  while i + 1 < chars.length() {
    let hi = hex_char_val(chars[i])
    let lo = hex_char_val(chars[i + 1])
    let val = hi * 16 + lo
    arr.push((val.to_uint64() & 0xffUL).to_byte())
    i = i + 2
  }
  Bytes::from_array(arr)
}

///|
fn hex_char_val(c : Char) -> Int {
  if c >= '0' && c <= '9' {
    c.to_int() - '0'.to_int()
  } else if c >= 'a' && c <= 'f' {
    c.to_int() - 'a'.to_int() + 10
  } else if c >= 'A' && c <= 'F' {
    c.to_int() - 'A'.to_int() + 10
  } else {
    0
  }
}

///|
/// Serializes the entire log as a JSON array.
pub fn AuditLog::to_json(self : AuditLog) -> String {
  let entries_json : Array[Json] = []
  for entry in self.entries {
    let parsed = @json.parse(entry.to_json()) catch { _ => Json::null() }
    entries_json.push(parsed)
  }
  let doc = Json::array(entries_json)
  try {
    @canonjson.canonicalize(doc.stringify())
  } catch {
    _ => doc.stringify()
  }
}
