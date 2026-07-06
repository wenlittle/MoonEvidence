// Tests for incremental verification.

///|
test "incremental verify with all files cached skips rehashing" {
  let files : Map[String, Bytes] = { "a.txt": b"alpha", "b.txt": b"bravo" }
  let manifest_json = @create.create_manifest(files, {
    subject: { id: "inc-test", kind: "test" },
    algorithm: @digest.Sha256,
    version_id: "v1",
    version_parent: None,
  })
  let previous : Map[String, String] = {}
  for entry_path in files.keys() {
    match files.get(entry_path) {
      Some(content) => {
        let digest = @digest.Digest::of_bytes(@digest.Sha256, content)
        previous[entry_path] = digest.to_string()
      }
      None => ()
    }
  }
  let result = verify_manifest_incremental(
    manifest_json,
    files,
    previous,
    expected_manifest_digest=None,
  )
  assert_true(result.report.ok)
  assert_eq(result.files_skipped, 2)
  assert_eq(result.files_rehashed, 0)
}

///|
test "incremental verify rehashes changed files" {
  let files : Map[String, Bytes] = { "a.txt": b"alpha", "b.txt": b"bravo" }
  let manifest_json = @create.create_manifest(files, {
    subject: { id: "inc-test2", kind: "test" },
    algorithm: @digest.Sha256,
    version_id: "v1",
    version_parent: None,
  })
  let previous : Map[String, String] = {
    "a.txt": @digest.Digest::of_bytes(@digest.Sha256, b"alpha").to_string(),
  }
  let result = verify_manifest_incremental(
    manifest_json,
    files,
    previous,
    expected_manifest_digest=None,
  )
  assert_true(result.report.ok)
  assert_eq(result.files_skipped, 1)
  assert_eq(result.files_rehashed, 1)
}

///|
test "incremental verify detects tampered file even with stale cache" {
  let original_files : Map[String, Bytes] = { "a.txt": b"original" }
  let manifest_json = @create.create_manifest(original_files, {
    subject: { id: "inc-tamper", kind: "test" },
    algorithm: @digest.Sha256,
    version_id: "v1",
    version_parent: None,
  })
  let tampered_files : Map[String, Bytes] = { "a.txt": b"TAMPERED" }
  let stale_cache : Map[String, String] = {
    "a.txt": @digest.Digest::of_bytes(@digest.Sha256, b"TAMPERED").to_string(),
  }
  let result = verify_manifest_incremental(
    manifest_json,
    tampered_files,
    stale_cache,
    expected_manifest_digest=None,
  )
  assert_false(result.report.ok)
  assert_eq(result.files_rehashed, 1)
}

///|
test "incremental verify with empty cache equals full verify" {
  let files : Map[String, Bytes] = { "x.txt": b"data" }
  let manifest_json = @create.create_manifest(files, {
    subject: { id: "inc-empty", kind: "test" },
    algorithm: @digest.Sha256,
    version_id: "v1",
    version_parent: None,
  })
  let empty_cache : Map[String, String] = {}
  let result = verify_manifest_incremental(
    manifest_json,
    files,
    empty_cache,
    expected_manifest_digest=None,
  )
  assert_true(result.report.ok)
  assert_eq(result.files_rehashed, 1)
  assert_eq(result.files_skipped, 0)
}

///|
/// Helper: collects finding codes from an incremental report.
fn incremental_error_codes(report : @diag.VerifyReport) -> Array[String] {
  report.findings.map(fn(f) { f.code })
}

///|
test "incremental verify reports e2003 when manifest file is missing from pack" {
  // Manifest lists a.txt and b.txt; the pack only provides b.txt. The missing
  // file must surface as E2003 (same code as the main pipeline), NOT E2001
  // (which is reserved for "unsupported algorithm").
  let files : Map[String, Bytes] = { "a.txt": b"alpha", "b.txt": b"bravo" }
  let manifest_json = @create.create_manifest(files, {
    subject: { id: "inc-missing-file", kind: "test" },
    algorithm: @digest.Sha256,
    version_id: "v1",
    version_parent: None,
  })
  let incomplete : Map[String, Bytes] = { "b.txt": b"bravo" }
  let previous : Map[String, String] = {}
  let result = verify_manifest_incremental(
    manifest_json,
    incomplete,
    previous,
    expected_manifest_digest=None,
  )
  assert_false(result.report.ok)
  @debug.assert_eq(incremental_error_codes(result.report), ["E2003"])
}

///|
test "incremental verify reports e3003 when merkle_root is tampered" {
  // Both files are present and correct, so file digests pass. The recorded
  // merkle_root is swapped for a well-formed but wrong digest: the recomputed
  // root no longer matches, which must surface as E3003 (same code as the
  // main pipeline), NOT E3002 (reserved for proof format invalid — not
  // currently emitted by any code path; documented as reserved).
  let files : Map[String, Bytes] = { "a.txt": b"alpha", "b.txt": b"bravo" }
  let manifest_json = @create.create_manifest(files, {
    subject: { id: "inc-tamper-root", kind: "test" },
    algorithm: @digest.Sha256,
    version_id: "v1",
    version_parent: None,
  })
  let manifest = @model.Manifest::parse(manifest_json) catch {
    error => fail("manifest should parse: \{error}")
  }
  let original_root = match manifest.merkle_root {
    Some(d) => d.to_string()
    None => fail("expected merkle_root to be present")
  }
  // Swap for a well-formed canonical digest that is guaranteed different.
  let tampered_root = "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  let tampered_json = manifest_json.replace(
    old=original_root,
    new=tampered_root,
  )
  let previous : Map[String, String] = {}
  let result = verify_manifest_incremental(
    tampered_json,
    files,
    previous,
    expected_manifest_digest=None,
  )
  assert_false(result.report.ok)
  @debug.assert_eq(incremental_error_codes(result.report), ["E3003"])
}

///|
test "incremental verify reports e2004 when manifest digest mismatches" {
  // The manifest is correct and all files match. But the externally recorded
  // manifest digest is wrong — the incremental path must surface E2004,
  // matching the main pipeline's step 3.
  let files : Map[String, Bytes] = { "a.txt": b"alpha" }
  let manifest_json = @create.create_manifest(files, {
    subject: { id: "inc-e2004", kind: "test" },
    algorithm: @digest.Sha256,
    version_id: "v1",
    version_parent: None,
  })
  let wrong_digest = "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  let previous : Map[String, String] = {}
  let result = verify_manifest_incremental(
    manifest_json,
    files,
    previous,
    expected_manifest_digest=Some(wrong_digest),
  )
  assert_false(result.report.ok)
  assert_true(incremental_error_codes(result.report).contains("E2004"))
}

///|
test "incremental verify reports e1004 for unsupported ignored number" {
  // The model ignores unknown fields, but canonicalization covers the whole
  // manifest. A JSON number that overflows IEEE 754 has no RFC 8785 canonical
  // form, so the incremental path must surface E1004 just like full verify.
  let manifest_json = golden_manifest.replace(
    old="\"hash_algorithm\": \"sha256\",",
    new="\"hash_algorithm\": \"sha256\", \"annotation\": 1e999,",
  )
  let previous = golden_cache_from_manifest()
  let result = verify_manifest_incremental(
    manifest_json,
    golden_files(),
    previous,
    expected_manifest_digest=None,
  )
  assert_false(result.report.ok)
  assert_true(incremental_error_codes(result.report).contains("E1004"))
}

///|
test "incremental verify reports w1001 for unlisted file but remains ok" {
  let files = golden_files()
  files["files/extra.bin"] = b"\x01\x02"
  let previous = golden_cache_from_manifest()
  let result = verify_manifest_incremental(
    golden_manifest,
    files,
    previous,
    expected_manifest_digest=None,
  )
  assert_true(result.report.ok)
  @debug.assert_eq(incremental_error_codes(result.report), ["W1001"])
  assert_eq(result.report.warning_count(), 1)
  assert_eq(result.report.error_count(), 0)
  assert_eq(result.files_skipped, 2)
  assert_eq(result.files_rehashed, 0)
}

///|
test "incremental verify reports e3001 when merkle_root is missing" {
  let manifest_json = golden_manifest.replace(
    old="\"merkle_root\": \"sha256:07a4f4bf0c83169b056f07acbf3483a5e418e58e09e942a3f06421f9cca316a5\",",
    new="",
  )
  let previous = golden_cache_from_manifest()
  let result = verify_manifest_incremental(
    manifest_json,
    golden_files(),
    previous,
    expected_manifest_digest=None,
  )
  assert_false(result.report.ok)
  @debug.assert_eq(incremental_error_codes(result.report), ["E3001"])
  assert_false(result.report.checked.merkle_checked)
}

///|
test "incremental verify reports e3001 when merkle_root attests empty files" {
  let manifest_json =
    #|{
    #|  "schema": "moon-evidence/v0",
    #|  "subject": { "id": "empty-with-root", "type": "dataset" },
    #|  "hash_algorithm": "sha256",
    #|  "files": [],
    #|  "merkle_root": "sha256:07a4f4bf0c83169b056f07acbf3483a5e418e58e09e942a3f06421f9cca316a5",
    #|  "version": { "id": "v1", "parent": null }
    #|}
  let result = verify_manifest_incremental(
    manifest_json,
    {},
    {},
    expected_manifest_digest=None,
  )
  assert_false(result.report.ok)
  @debug.assert_eq(incremental_error_codes(result.report), ["E3001"])
  assert_eq(result.report.checked.files_total, 0)
}

///|
test "incremental verify passes when manifest digest matches" {
  // Same setup, but the expected digest is the real canonical digest.
  let files : Map[String, Bytes] = { "a.txt": b"alpha" }
  let manifest_json = @create.create_manifest(files, {
    subject: { id: "inc-e2004-ok", kind: "test" },
    algorithm: @digest.Sha256,
    version_id: "v1",
    version_parent: None,
  })
  let canonical = @canonjson.canonicalize(manifest_json) catch {
    _ => fail("canonicalize failed")
  }
  let real_digest = @digest.Digest::of_bytes(
    @digest.Sha256,
    @digest.string_to_utf8_bytes(canonical),
  ).to_string()
  let previous : Map[String, String] = {}
  let result = verify_manifest_incremental(
    manifest_json,
    files,
    previous,
    expected_manifest_digest=Some(real_digest),
  )
  assert_true(result.report.ok)
  assert_eq(incremental_error_codes(result.report).length(), 0)
}

// ===========================================================================
// Independent-oracle tests (Q1/Q2/Q3) — use golden_manifest from
// verify_wbtest.mbt, which was generated by the independent Node reference
// (tools/gen-pack-fixture.mjs). These tests do NOT call @create.create_manifest,
// breaking the create→verify self-referential cycle that weakens the 9 tests
// above. If a shared primitive (SHA-256, canonjson, Merkle) has a bug, the
// golden manifest's hardcoded digests will NOT match our recomputed values,
// and these tests will catch it — whereas the create-based tests above would
// pass because both sides use the same buggy primitive.
// ===========================================================================

///|
/// Helper: extract per-file digests from the golden manifest to build a cache.
/// The digests come from the manifest (Node-computed), NOT from our own
/// @digest.sha256 — this is what makes the cache an independent oracle.
fn golden_cache_from_manifest() -> Map[String, String] raise {
  let manifest = @model.Manifest::parse(golden_manifest) catch {
    error => fail("golden_manifest should parse: \{error}")
  }
  let cache : Map[String, String] = {}
  for entry in manifest.files {
    cache[entry.path] = entry.digest.to_string()
  }
  cache
}

///|
/// Q1 independent positive oracle: golden manifest + golden files + correct
/// cache (digests from manifest, not from our SHA-256) → all files skipped,
/// verification passes. This proves the incremental path agrees with the
/// independent Node reference on valid input.
test "incremental golden: all files cached, verify passes (independent oracle)" {
  let previous = golden_cache_from_manifest()
  let result = verify_manifest_incremental(
    golden_manifest,
    golden_files(),
    previous,
    expected_manifest_digest=None,
  )
  assert_true(result.report.ok)
  assert_eq(result.files_skipped, 2)
  assert_eq(result.files_rehashed, 0)
  assert_eq(result.report.checked.files_passed, 2)
}

///|
/// Q1 independent positive oracle: golden manifest + golden files + empty
/// cache → all files rehashed, verification still passes. This proves the
/// incremental rehash path agrees with the independent Node reference —
/// our SHA-256 digests match the golden manifest's hardcoded values.
test "incremental golden: empty cache, all rehashed, verify passes (independent oracle)" {
  let empty_cache : Map[String, String] = {}
  let result = verify_manifest_incremental(
    golden_manifest,
    golden_files(),
    empty_cache,
    expected_manifest_digest=None,
  )
  assert_true(result.report.ok)
  assert_eq(result.files_rehashed, 2)
  assert_eq(result.files_skipped, 0)
  assert_eq(result.report.checked.files_passed, 2)
  assert_true(result.report.checked.merkle_checked)
}

///|
/// Q1 independent positive oracle: golden manifest + golden files + correct
/// manifest digest (Node-computed GOLDEN_MANIFEST_DIGEST) → E2004 passes.
/// This proves our canonicalization + SHA-256 of the manifest matches the
/// independent Node reference.
test "incremental golden: manifest digest matches Node-computed value (independent oracle)" {
  let previous = golden_cache_from_manifest()
  let result = verify_manifest_incremental(
    golden_manifest,
    golden_files(),
    previous,
    expected_manifest_digest=Some(GOLDEN_MANIFEST_DIGEST),
  )
  assert_true(result.report.ok)
  assert_eq(incremental_error_codes(result.report).length(), 0)
}

///|
/// Q2 independent negative oracle: golden manifest + golden files + WRONG
/// manifest digest → E2004. The digest is independently known (Node-computed);
/// supplying a different value must be detected.
test "incremental golden: wrong manifest digest rejected (independent oracle)" {
  let previous = golden_cache_from_manifest()
  let wrong_digest = "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  let result = verify_manifest_incremental(
    golden_manifest,
    golden_files(),
    previous,
    expected_manifest_digest=Some(wrong_digest),
  )
  assert_false(result.report.ok)
  assert_true(incremental_error_codes(result.report).contains("E2004"))
}

///|
/// Q3 attack encoding — trust model boundary documentation:
/// golden manifest + TAMPERED file content + cache matching manifest digests
/// → file is skipped (cache hit), verification PASSES despite tampered content.
///
/// This is NOT a bug — it is the documented trust model (incremental.mbt L6-12):
/// "If an attacker can tamper with the cache, they can cause modified files to
/// skip content hashing." This test proves the boundary exists and makes it
/// explicit. The Merkle root still passes because it is recomputed from the
/// manifest's leaf payloads (which use the manifest's digests, not the file
/// content), so structural tampering is still caught — only content tampering
/// is hidden by a malicious cache.
///
/// The cache digests come from the golden manifest (Node-computed), NOT from
/// our own SHA-256 of the tampered content — so this test does not create a
/// self-referential cycle.
test "incremental golden: trust model boundary — tampered file hidden by matching cache" {
  // Tamper a.txt content but keep the cache pointing at the manifest's digest.
  let tampered_files : Map[String, Bytes] = {
    "files/a.txt": @digest.string_to_utf8_bytes("TAMPERED CONTENT\n"),
    "files/b.bin": b"",
  }
  let previous = golden_cache_from_manifest()
  let result = verify_manifest_incremental(
    golden_manifest,
    tampered_files,
    previous,
    expected_manifest_digest=None,
  )
  // The cache matches the manifest's digests, so a.txt is skipped (not rehashed).
  // The tampered content is NOT detected because the hash is never recomputed.
  assert_true(result.report.ok)
  assert_eq(result.files_skipped, 2)
  assert_eq(result.files_rehashed, 0)
  // This is the trust model boundary: incremental verification with a
  // compromised cache cannot detect content tampering. Full verify_manifest
  // WOULD detect it (rehashes every file regardless of cache).
  let full_report = verify_manifest(golden_manifest, tampered_files)
  assert_false(full_report.ok)
}

///|
test "incremental verify without expected_manifest_digest skips e2004" {
  // When expected_manifest_digest is None, the incremental path should NOT
  // emit E2004 — backward compatible with callers who don't supply it.
  let files : Map[String, Bytes] = { "a.txt": b"alpha" }
  let manifest_json = @create.create_manifest(files, {
    subject: { id: "inc-no-e2004", kind: "test" },
    algorithm: @digest.Sha256,
    version_id: "v1",
    version_parent: None,
  })
  let previous : Map[String, String] = {}
  let result = verify_manifest_incremental(
    manifest_json,
    files,
    previous,
    expected_manifest_digest=None,
  )
  assert_true(result.report.ok)
  assert_eq(incremental_error_codes(result.report).length(), 0)
}
