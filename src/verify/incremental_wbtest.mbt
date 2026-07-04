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
  let result = verify_manifest_incremental(manifest_json, files, previous)
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
  let result = verify_manifest_incremental(manifest_json, files, previous)
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
    manifest_json, tampered_files, stale_cache,
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
  let result = verify_manifest_incremental(manifest_json, files, empty_cache)
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
  let result = verify_manifest_incremental(manifest_json, incomplete, previous)
  assert_false(result.report.ok)
  @debug.assert_eq(incremental_error_codes(result.report), ["E2003"])
}

///|
test "incremental verify reports e3003 when merkle_root is tampered" {
  // Both files are present and correct, so file digests pass. The recorded
  // merkle_root is swapped for a well-formed but wrong digest: the recomputed
  // root no longer matches, which must surface as E3003 (same code as the
  // main pipeline), NOT E3002 (which is reserved for "proof format invalid").
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
  let result = verify_manifest_incremental(tampered_json, files, previous)
  assert_false(result.report.ok)
  @debug.assert_eq(incremental_error_codes(result.report), ["E3003"])
}
