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
  hash : String
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
  let entry_json = Json::object({
    "timestamp": Json::string(self.timestamp),
    "actor": Json::string(self.actor),
    "action": Json::string(self.action.to_string()),
    "subject_id": Json::string(self.subject_id),
    "manifest_digest": digest_json,
    "prev_hash": prev_json,
  })
  let canonical = @canonjson.canonicalize(entry_json.stringify()) catch {
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
  let entry_json = Json::object({
    "timestamp": Json::string(self.timestamp),
    "actor": Json::string(self.actor),
    "action": Json::string(self.action.to_string()),
    "subject_id": Json::string(self.subject_id),
    "manifest_digest": digest_json,
    "prev_hash": prev_json,
    "hash": Json::string(self.hash),
    "signature": sig_json,
  })
  @canonjson.canonicalize(entry_json.stringify()) catch {
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
    hash: "",
    signature: None,
  }
  let hash = entry.compute_hash()
  let final_entry : AuditEntry = { ..entry, hash, }
  self.entries.push(final_entry)
  self.last_hash = Some(hash)
}

///|
/// Verifies the hash chain integrity: each entry's prev_hash must match
/// the computed hash of the preceding entry, and each entry's stored
/// `hash` field must match the freshly recomputed hash. Without the
/// latter check, a tampered `hash` field would go undetected as long as
/// the prev_hash links still line up.
pub fn AuditLog::verify_chain(self : AuditLog) -> Bool {
  let mut prev_hash : String? = None
  for entry in self.entries {
    if entry.prev_hash != prev_hash {
      return false
    }
    let computed = entry.compute_hash()
    if entry.hash != computed {
      return false
    }
    prev_hash = Some(computed)
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
  let signed_entry : AuditEntry = { ..entry, signature: Some(sig_hex) }
  self.entries[idx] = signed_entry
}

///|
/// Verifies all Ed25519 signatures in the log.
/// Entries without signatures are skipped (returns true for them).
/// A signature whose hex encoding is invalid (tampered or corrupted) causes
/// verification to fail rather than silently decoding to wrong bytes.
pub fn AuditLog::verify_signatures(self : AuditLog, pk : Bytes) -> Bool {
  for entry in self.entries {
    match entry.signature {
      Some(sig_hex) => {
        let hash_str = entry.compute_hash()
        let hash_bytes = @digest.string_to_utf8_bytes(hash_str)
        match @digest.hex_to_bytes(sig_hex) {
          Some(sig) =>
            if @crypto.ed25519_verify(pk, hash_bytes, sig) == false {
              return false
            }
          None => return false
        }
      }
      None => ()
    }
  }
  true
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
  @canonjson.canonicalize(doc.stringify()) catch {
    _ => doc.stringify()
  }
}

///|
/// Reconstructs an AuditLog from the JSON array produced by `to_json`.
/// Returns `None` on any parse or shape error. The reconstructed log has
/// the same entries, prev_hash links, and last_hash as the original, so
/// `verify_chain` and `verify_signatures` work on the rebuilt log.
///
/// This closes the round-trip gap: before this method, `api.audit_append`
/// and `api.audit_verify` discarded the input log and built an empty one,
/// making the JS API audit layer a no-op.
pub fn AuditLog::from_json(json_str : String) -> AuditLog? {
  let parsed = @json.parse(json_str) catch { _ => return None }
  guard parsed is Array(arr) else { return None }
  let log = AuditLog::new()
  for entry_json in arr {
    guard entry_json is Object(obj) else { return None }
    // Required string fields.
    guard obj.get("timestamp") is Some(String(timestamp)) else { return None }
    guard obj.get("actor") is Some(String(actor)) else { return None }
    guard obj.get("action") is Some(String(action_str)) else { return None }
    let action = AuditAction::parse(action_str)
    guard obj.get("subject_id") is Some(String(subject_id)) else { return None }
    guard obj.get("hash") is Some(String(hash)) else { return None }
    // Optional string fields: Some(string) → Some(value), null/missing → None.
    let manifest_digest : String? = match obj.get("manifest_digest") {
      Some(String(s)) => Some(s)
      _ => None
    }
    let prev_hash : String? = match obj.get("prev_hash") {
      Some(String(s)) => Some(s)
      _ => None
    }
    let signature : String? = match obj.get("signature") {
      Some(String(s)) => Some(s)
      _ => None
    }
    let entry : AuditEntry = {
      timestamp,
      actor,
      action,
      subject_id,
      manifest_digest,
      prev_hash,
      hash,
      signature,
    }
    log.entries.push(entry)
    log.last_hash = Some(hash)
  }
  Some(log)
}
