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
