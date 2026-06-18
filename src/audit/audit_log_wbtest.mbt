// Tests for audit log hash chain.

///|
test "empty audit log verifies" {
  let log = AuditLog::new()
  assert_true!(log.verify_chain())
}

///|
test "single entry audit log" {
  let log = AuditLog::new()
  log.append("2026-06-18T19:00:00Z", "alice", Created, "dataset-v1")
  assert_eq!(log.length(), 1)
  assert_true!(log.verify_chain())
}

///|
test "multi-entry audit chain links correctly" {
  let log = AuditLog::new()
  log.append("2026-06-18T19:00:00Z", "alice", Created, "dataset-v1")
  log.append("2026-06-18T20:00:00Z", "bob", Verified, "dataset-v1")
  log.append("2026-06-18T21:00:00Z", "alice", Sealed, "dataset-v1")
  assert_eq!(log.length(), 3)
  assert_true!(log.verify_chain())
}

///|
test "entry hash is deterministic" {
  let entry : AuditEntry = {
    timestamp: "2026-06-18T19:00:00Z",
    actor: "alice",
    action: Created,
    subject_id: "test",
    manifest_digest: None,
    prev_hash: None,
    signature: None,
  }
  let h1 = entry.compute_hash()
  let h2 = entry.compute_hash()
  assert_eq!(h1, h2)
  assert_true!(h1.has_prefix("sha256:"))
  assert_eq!(h1.length(), 71)
}

///|
test "tampered chain detected" {
  let log = AuditLog::new()
  log.append("2026-06-18T19:00:00Z", "alice", Created, "test")
  log.append("2026-06-18T20:00:00Z", "bob", Verified, "test")
  assert_true!(log.verify_chain())
  let tampered_entry : AuditEntry = {
    timestamp: "2026-06-18T19:00:00Z",
    actor: "TAMPERED",
    action: Created,
    subject_id: "test",
    manifest_digest: None,
    prev_hash: None,
    signature: None,
  }
  log.entries[0] = tampered_entry
  assert_false!(log.verify_chain())
}

///|
test "audit log serializes to JSON" {
  let log = AuditLog::new()
  log.append("2026-06-18T19:00:00Z", "alice", Created, "test")
  let json_str = log.to_json()
  assert_true!(json_str.length() > 10)
  let _ = @json.parse(json_str)
}

///|
test "custom action type" {
  let log = AuditLog::new()
  log.append("2026-06-18T19:00:00Z", "system", Custom("migrated"), "test")
  assert_true!(log.verify_chain())
  assert_eq!(log.entries[0].action.to_string(), "migrated")
}
