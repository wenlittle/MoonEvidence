// Tests for audit log hash chain.

///|
test "empty audit log verifies" {
  let log = AuditLog::new()
  assert_true(log.verify_chain())
}

///|
test "single entry audit log" {
  let log = AuditLog::new()
  log.append("2026-06-18T19:00:00Z", "alice", Created, "dataset-v1")
  assert_eq(log.length(), 1)
  assert_true(log.verify_chain())
}

///|
test "multi-entry audit chain links correctly" {
  let log = AuditLog::new()
  log.append("2026-06-18T19:00:00Z", "alice", Created, "dataset-v1")
  log.append("2026-06-18T20:00:00Z", "bob", Verified, "dataset-v1")
  log.append("2026-06-18T21:00:00Z", "alice", Sealed, "dataset-v1")
  assert_eq(log.length(), 3)
  assert_true(log.verify_chain())
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
    hash: "",
    signature: None,
  }
  let h1 = entry.compute_hash()
  let h2 = entry.compute_hash()
  assert_eq(h1, h2)
  assert_true(h1.has_prefix("sha256:"))
  assert_eq(h1.length(), 71)
}

///|
test "tampered chain detected" {
  let log = AuditLog::new()
  log.append("2026-06-18T19:00:00Z", "alice", Created, "test")
  log.append("2026-06-18T20:00:00Z", "bob", Verified, "test")
  assert_true(log.verify_chain())
  let tampered_entry : AuditEntry = {
    timestamp: "2026-06-18T19:00:00Z",
    actor: "TAMPERED",
    action: Created,
    subject_id: "test",
    manifest_digest: None,
    prev_hash: None,
    hash: "",
    signature: None,
  }
  log.entries[0] = tampered_entry
  assert_false(log.verify_chain())
}

///|
test "tampered hash field is detected by verify_chain" {
  // Even when the prev_hash chain links correctly and the entry content is
  // unchanged, a tampered `hash` field must cause verify_chain to fail.
  let log = AuditLog::new()
  log.append("2026-06-18T19:00:00Z", "alice", Created, "test")
  assert_true(log.verify_chain())
  let entry = log.entries[0]
  // Flip the stored hash to a well-formed but wrong digest while keeping
  // every other field (including prev_hash) intact.
  let tampered_entry : AuditEntry = {
    ..entry,
    hash: "sha256:0000000000000000000000000000000000000000000000000000000000000000",
  }
  log.entries[0] = tampered_entry
  assert_false(log.verify_chain())
}

///|
test "audit log serializes to JSON" {
  let log = AuditLog::new()
  log.append("2026-06-18T19:00:00Z", "alice", Created, "test")
  let json_str = log.to_json()
  assert_true(json_str.length() > 10)
  let _ = @json.parse(json_str)
}

///|
test "custom action type" {
  let log = AuditLog::new()
  log.append("2026-06-18T19:00:00Z", "system", Custom("migrated"), "test")
  assert_true(log.verify_chain())
  assert_eq(log.entries[0].action.to_string(), "migrated")
}

///|
test "audit action parse recognizes builtins and preserves custom action" {
  assert_true(AuditAction::parse("created") == Created)
  assert_true(AuditAction::parse("verified") == Verified)
  assert_true(AuditAction::parse("sealed") == Sealed)
  assert_true(AuditAction::parse("signed") == Signed)
  assert_true(AuditAction::parse("shared") == Shared)
  assert_true(AuditAction::parse("migrated") == Custom("migrated"))
}

///|
fn test_sk() -> Bytes {
  let b : Array[Byte] = [
    b'\x9d', b'\x61', b'\xb1', b'\x9d', b'\xef', b'\xfd', b'\x5a', b'\x60', b'\xba',
    b'\x84', b'\x4a', b'\xf4', b'\x92', b'\xec', b'\x2c', b'\xc4', b'\x44', b'\x49',
    b'\xc5', b'\x69', b'\x7b', b'\x32', b'\x69', b'\x19', b'\x70', b'\x3b', b'\xac',
    b'\x03', b'\x1c', b'\xae', b'\x7f', b'\x60',
  ]
  Bytes::from_array(b)
}

///|
test "sign_last on empty log is a no-op" {
  let sk = test_sk()
  let log = AuditLog::new()
  log.sign_last(sk)
  assert_eq(log.length(), 0)
  assert_true(log.verify_chain())
}

///|
test "sign and verify audit entry" {
  let sk = test_sk()
  let pk = @crypto.ed25519_public_key(sk)
  let log = AuditLog::new()
  log.append("2026-06-18T19:00:00Z", "alice", Created, "dataset-v1")
  log.sign_last(sk)
  assert_true(log.entries[0].signature is Some(_))
  assert_true(log.verify_signatures(pk))
  assert_true(log.verify_chain())
}

///|
test "unsigned audit entries are skipped by signature verification" {
  let sk = test_sk()
  let pk = @crypto.ed25519_public_key(sk)
  let log = AuditLog::new()
  log.append("2026-06-18T19:00:00Z", "alice", Created, "dataset-v1")
  assert_true(log.verify_signatures(pk))
}

///|
test "signed log rejects wrong public key" {
  let sk = test_sk()
  let log = AuditLog::new()
  log.append("2026-06-18T19:00:00Z", "alice", Created, "test")
  log.sign_last(sk)
  let wrong_pk = Bytes::make(32, b'\x42')
  assert_false(log.verify_signatures(wrong_pk))
}

///|
test "odd-length signature hex is rejected" {
  let sk = test_sk()
  let pk = @crypto.ed25519_public_key(sk)
  let log = AuditLog::new()
  log.append("2026-06-18T19:00:00Z", "alice", Created, "test")
  log.sign_last(sk)
  let entry = log.entries[0]
  let tampered_entry : AuditEntry = { ..entry, signature: Some("abc") }
  log.entries[0] = tampered_entry
  assert_false(log.verify_signatures(pk))
}

///|
test "tampered signature hex is rejected instead of silently decoding" {
  // A signature whose hex string is corrupted (non-hex character injected)
  // must cause verify_signatures to return false, rather than silently
  // decoding the bad characters to 0x00 bytes and proceeding.
  let sk = test_sk()
  let pk = @crypto.ed25519_public_key(sk)
  let log = AuditLog::new()
  log.append("2026-06-18T19:00:00Z", "alice", Created, "test")
  log.sign_last(sk)
  // Inject two non-hex characters at the front, preserving even length so
  // the decoder reaches the per-character validation rather than the odd
  // length early return.
  let entry = log.entries[0]
  let good_sig = match entry.signature {
    Some(s) => s
    None => fail("expected a signature")
  }
  let tampered_sig = "zz" + good_sig
  let tampered_entry : AuditEntry = {
    timestamp: entry.timestamp,
    actor: entry.actor,
    action: entry.action,
    subject_id: entry.subject_id,
    manifest_digest: entry.manifest_digest,
    prev_hash: entry.prev_hash,
    hash: entry.hash,
    signature: Some(tampered_sig),
  }
  log.entries[0] = tampered_entry
  assert_false(log.verify_signatures(pk))
}

///|
test "multi-entry signed log" {
  let sk = test_sk()
  let pk = @crypto.ed25519_public_key(sk)
  let log = AuditLog::new()
  log.append("2026-06-18T19:00:00Z", "alice", Created, "dataset-v1")
  log.sign_last(sk)
  log.append("2026-06-18T20:00:00Z", "bob", Verified, "dataset-v1")
  log.sign_last(sk)
  assert_eq(log.length(), 2)
  assert_true(log.verify_chain())
  assert_true(log.verify_signatures(pk))
}

// ---------------------------------------------------------------------------
// Long-chain stress tests (step 7 hardening). The cases above only exercise
// chains of length <= 3, so a quadratic or off-by-one bug in verify_chain
// (e.g. a loop that stops one entry short, or a prev_hash comparison that
// silently coerces types) would slip through. These tests build 1000-entry
// linear chains and confirm verify_chain stays correct at scale, plus a
// fork case that the linear-only model must still reject.
// ---------------------------------------------------------------------------

///|
test "long chain: 1000 linear entries verify" {
  let log = AuditLog::new()
  for index in 0..<1000 {
    log.append("2026-06-18T19:00:00Z", "alice", Created, "dataset-\{index}")
  }
  assert_eq(log.length(), 1000)
  // Every prev_hash must chain to the previous computed hash; a single
  // off-by-one in the loop would break one link and flip the verdict.
  assert_true(log.verify_chain())
}

///|
test "long chain: broken prev_hash in the middle is detected" {
  let log = AuditLog::new()
  for index in 0..<1000 {
    log.append("2026-06-18T19:00:00Z", "alice", Created, "dataset-\{index}")
  }
  // Tamper entry 500 (middle of the chain): rewrite its prev_hash so it
  // no longer links to entry 499's computed hash. verify_chain must fail
  // at exactly this position, proving the walk reaches the middle.
  let entry = log.entries[500]
  let tampered : AuditEntry = {
    ..entry,
    prev_hash: Some(
      "sha256:0000000000000000000000000000000000000000000000000000000000000000",
    ),
  }
  log.entries[500] = tampered
  assert_false(log.verify_chain())
}

///|
test "long chain: forked entries are rejected" {
  // AuditLog is append-only and linear by construction; a forked chain
  // (two entries sharing the same prev_hash) must be detected as a break.
  // We build e0 -> e1, then append a third entry whose prev_hash points
  // back at e0 (the same prev e1 used) instead of e1's hash.
  let log = AuditLog::new()
  log.append("2026-06-18T19:00:00Z", "alice", Created, "dataset-v1")
  log.append("2026-06-18T20:00:00Z", "bob", Verified, "dataset-v1")
  let fork_prev = log.entries[0].hash
  let fork_entry : AuditEntry = {
    timestamp: "2026-06-18T21:00:00Z",
    actor: "carol",
    action: Sealed,
    subject_id: "dataset-v1",
    manifest_digest: None,
    prev_hash: Some(fork_prev),
    hash: "",
    signature: None,
  }
  let fork_hash = fork_entry.compute_hash()
  let fork_final : AuditEntry = { ..fork_entry, hash: fork_hash }
  log.entries.push(fork_final)
  // verify_chain walks in order: at the fork entry, its prev_hash (e0's
  // hash) no longer equals e1's freshly computed hash, so the chain breaks.
  assert_false(log.verify_chain())
}

// ---------------------------------------------------------------------------
// from_json round-trip tests. Before from_json existed, api.audit_append
// and api.audit_verify discarded the input log and built an empty one,
// making the JS API audit layer a no-op. These tests prove the round-trip
// (to_json → from_json) preserves chain integrity and entry data.
// ---------------------------------------------------------------------------

///|
test "from_json round-trip preserves chain integrity" {
  let log = AuditLog::new()
  log.append("2026-06-18T19:00:00Z", "alice", Created, "dataset-v1")
  log.append("2026-06-18T20:00:00Z", "bob", Verified, "dataset-v1")
  log.append("2026-06-18T21:00:00Z", "alice", Sealed, "dataset-v1")
  let json_str = log.to_json()
  let rebuilt = match AuditLog::from_json(json_str) {
    Some(r) => r
    None => fail("from_json returned None for valid log")
  }
  assert_eq(rebuilt.length(), 3)
  assert_true(rebuilt.verify_chain())
  // Entry data must match.
  assert_eq(rebuilt.entries[0].actor, "alice")
  assert_eq(rebuilt.entries[1].actor, "bob")
  assert_true(rebuilt.entries[2].action == Sealed)
}

///|
test "from_json round-trip with signatures" {
  let sk = test_sk()
  let pk = @crypto.ed25519_public_key(sk)
  let log = AuditLog::new()
  log.append("2026-06-18T19:00:00Z", "alice", Created, "dataset-v1")
  log.sign_last(sk)
  log.append("2026-06-18T20:00:00Z", "bob", Verified, "dataset-v1")
  log.sign_last(sk)
  let json_str = log.to_json()
  let rebuilt = match AuditLog::from_json(json_str) {
    Some(r) => r
    None => fail("from_json returned None for signed log")
  }
  assert_eq(rebuilt.length(), 2)
  assert_true(rebuilt.verify_chain())
  assert_true(rebuilt.verify_signatures(pk))
  // Signatures must survive the round-trip.
  assert_true(rebuilt.entries[0].signature is Some(_))
  assert_true(rebuilt.entries[1].signature is Some(_))
}

///|
test "from_json returns None for invalid input" {
  assert_true(AuditLog::from_json("not json") is None)
  assert_true(AuditLog::from_json("{}") is None) // object, not array
  assert_true(AuditLog::from_json("[42]") is None) // non-object element
  // Missing required fields (actor only, no timestamp/hash/etc.)
  assert_true(AuditLog::from_json("[{\"actor\":\"alice\"}]") is None)
}

///|
test "from_json rejects malformed hash field" {
  // Hash without "sha256:" prefix.
  let bad1 = "[{\"timestamp\":\"t\",\"actor\":\"a\",\"action\":\"created\",\"subject_id\":\"s\",\"hash\":\"abcd\"}]"
  assert_true(AuditLog::from_json(bad1) is None)
  // Hash with prefix but wrong length (not 71 chars).
  let bad2 = "[{\"timestamp\":\"t\",\"actor\":\"a\",\"action\":\"created\",\"subject_id\":\"s\",\"hash\":\"sha256:short\"}]"
  assert_true(AuditLog::from_json(bad2) is None)
}

///|
test "from_json rejects malformed prev_hash field" {
  // Build a valid 2-entry log, then corrupt the prev_hash of the second
  // entry before deserializing.
  let log = AuditLog::new()
  log.append("2026-06-18T19:00:00Z", "alice", Created, "dataset-v1")
  log.append("2026-06-18T20:00:00Z", "bob", Verified, "dataset-v1")
  let json_str = log.to_json()
  // Replace the second entry's prev_hash with a non-sha256 string.
  // The to_json output is canonical, so prev_hash appears as a value; we
  // just inject a bad-format string in its place.
  let tampered = json_str.replace(
    old= log.entries[1].prev_hash.unwrap(),
    new= "bad-hash-format",
  )
  assert_true(AuditLog::from_json(tampered) is None)
}

///|
test "from_json of empty log produces empty log" {
  let log = AuditLog::new()
  let json_str = log.to_json()
  let rebuilt = match AuditLog::from_json(json_str) {
    Some(r) => r
    None => fail("from_json returned None for empty log")
  }
  assert_eq(rebuilt.length(), 0)
  assert_true(rebuilt.verify_chain())
}

///|
test "from_json of tampered log fails verify_chain" {
  let log = AuditLog::new()
  log.append("2026-06-18T19:00:00Z", "alice", Created, "dataset-v1")
  log.append("2026-06-18T20:00:00Z", "bob", Verified, "dataset-v1")
  // Tamper: change actor in the serialized JSON before from_json.
  let json_str = log.to_json()
  let tampered_json = json_str.replace(old="alice", new="eve")
  let rebuilt = match AuditLog::from_json(tampered_json) {
    Some(r) => r
    None => fail("from_json returned None for tampered log")
  }
  // The hash field still reflects the original entry, but the actor changed,
  // so verify_chain must fail (compute_hash won't match stored hash).
  assert_false(rebuilt.verify_chain())
}
