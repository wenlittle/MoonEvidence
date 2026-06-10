// Pipeline tests over a golden pack whose digests and Merkle root were
// computed by the independent Node reference (tools/gen-pack-fixture.mjs),
// so a green "valid pack" run is itself an end-to-end cross-check.

let golden_manifest : String =
  #|{
  #|  "schema": "moon-evidence/v0",
  #|  "subject": { "id": "golden-pack", "type": "dataset" },
  #|  "hash_algorithm": "sha256",
  #|  "files": [
  #|    {
  #|      "path": "files/a.txt",
  #|      "size": 12,
  #|      "digest": "sha256:a948904f2f0f479b8f8197694b30184b0d2ed1c1cd2a1ec0fb85d299a192a447"
  #|    },
  #|    {
  #|      "path": "files/b.bin",
  #|      "size": 0,
  #|      "digest": "sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
  #|    }
  #|  ],
  #|  "merkle_root": "sha256:07a4f4bf0c83169b056f07acbf3483a5e418e58e09e942a3f06421f9cca316a5",
  #|  "version": { "id": "v1", "parent": null }
  #|}

/// Node-computed canonical digest of golden_manifest (E2004 positive case).
const GOLDEN_MANIFEST_DIGEST : String = "sha256:16bbf1e91de3acfb8bd9091233926b454045c6d96c24327baec20272af583f1e"

fn golden_files() -> Map[String, Bytes] {
  {
    "files/a.txt": @digest.string_to_utf8_bytes("hello world\n"),
    "files/b.bin": b"",
  }
}

fn error_codes(report : @diag.VerifyReport) -> Array[String] {
  report.findings.map(fn(item) { item.code })
}

// ---------------------------------------------------------------------------
// Valid pack
// ---------------------------------------------------------------------------

test "valid pack verifies with zero findings" {
  let report = verify_manifest(golden_manifest, golden_files())
  assert_true(report.ok)
  assert_eq(report.findings.length(), 0)
  assert_eq(report.checked.files_total, 2)
  assert_eq(report.checked.files_passed, 2)
  assert_true(report.checked.merkle_checked)
}

test "valid pack passes recorded manifest digest check" {
  let report = verify_manifest(
    golden_manifest,
    golden_files(),
    expected_manifest_digest=GOLDEN_MANIFEST_DIGEST,
  )
  assert_true(report.ok)
  assert_eq(report.findings.length(), 0)
}

// ---------------------------------------------------------------------------
// E1xxx: model and canonicalization failures surface as findings
// ---------------------------------------------------------------------------

test "unparsable manifest reports e1001 and stops" {
  let report = verify_manifest("{ not json", golden_files())
  assert_false(report.ok)
  @debug.assert_eq(error_codes(report), ["E1001"])
  assert_eq(report.checked.files_total, 0)
}

test "model validation failure carries field path into the finding" {
  let report = verify_manifest(
    golden_manifest.replace(old="\"size\": 12", new="\"size\": -1"),
    golden_files(),
  )
  assert_false(report.ok)
  @debug.assert_eq(error_codes(report), ["E1002"])
  assert_eq(report.findings[0].path, "files[0].size")
}

test "unsupported number in ignored field reports e1004" {
  // The model ignores unknown fields, but canonicalization must still cover
  // the whole document - a non-integer number is rejected under L1 (E1004).
  let report = verify_manifest(
    golden_manifest.replace(
      old="\"hash_algorithm\": \"sha256\",",
      new="\"hash_algorithm\": \"sha256\", \"annotation\": 12.34,",
    ),
    golden_files(),
  )
  assert_false(report.ok)
  assert_true(error_codes(report).contains("E1004"))
}

// ---------------------------------------------------------------------------
// E2xxx: digest findings
// ---------------------------------------------------------------------------

test "missing file content reports e2003" {
  let files = golden_files()
  files.remove("files/a.txt")
  let report = verify_manifest(golden_manifest, files)
  assert_false(report.ok)
  @debug.assert_eq(error_codes(report), ["E2003"])
  assert_eq(report.findings[0].path, "files/a.txt")
  assert_eq(report.checked.files_passed, 1)
}

test "tampered file content reports e2003 with expected and got" {
  let files = golden_files()
  files["files/a.txt"] = @digest.string_to_utf8_bytes("hello world!")
  let report = verify_manifest(golden_manifest, files)
  assert_false(report.ok)
  @debug.assert_eq(error_codes(report), ["E2003"])
  assert_true(report.findings[0].message.contains("expected sha256:a948904f"))
  assert_true(report.findings[0].message.contains("got sha256:"))
}

test "wrong recorded manifest digest reports e2004" {
  let report = verify_manifest(
    golden_manifest,
    golden_files(),
    expected_manifest_digest="sha256:0000000000000000000000000000000000000000000000000000000000000000",
  )
  assert_false(report.ok)
  @debug.assert_eq(error_codes(report), ["E2004"])
}

test "all file problems are reported in one run" {
  // Exhaustive, not fail-fast: tamper one file AND drop the other. Content
  // tampering does NOT disturb the Merkle root - the tree attests manifest
  // entries, and those are unchanged here.
  let files : Map[String, Bytes] = {
    "files/a.txt": @digest.string_to_utf8_bytes("tampered"),
  }
  let report = verify_manifest(golden_manifest, files)
  assert_false(report.ok)
  @debug.assert_eq(error_codes(report), ["E2003", "E2003"])
  assert_true(report.checked.merkle_checked)
}

test "tampered manifest digest entry trips both e2003 and e3003" {
  // Editing a digest INSIDE the manifest changes the canonical file entry,
  // so the recomputed Merkle root drifts from the recorded one: the file
  // check (against the new digest) and the root check both fail.
  let report = verify_manifest(
    golden_manifest.replace(
      old="sha256:a948904f2f0f479b8f8197694b30184b0d2ed1c1cd2a1ec0fb85d299a192a447",
      new="sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    ),
    golden_files(),
  )
  assert_false(report.ok)
  @debug.assert_eq(error_codes(report), ["E2003", "E3003"])
}

// ---------------------------------------------------------------------------
// W1001: unlisted file is a warning, not a failure
// ---------------------------------------------------------------------------

test "unlisted file reports w1001 but pack stays ok" {
  let files = golden_files()
  files["files/extra.bin"] = b"\x01\x02"
  let report = verify_manifest(golden_manifest, files)
  assert_true(report.ok)
  @debug.assert_eq(error_codes(report), ["W1001"])
  assert_eq(report.warning_count(), 1)
  assert_eq(report.error_count(), 0)
}

// ---------------------------------------------------------------------------
// E3xxx: Merkle findings
// ---------------------------------------------------------------------------

test "missing merkle root with files reports e3001" {
  let report = verify_manifest(
    golden_manifest.replace(
      old="\"merkle_root\": \"sha256:07a4f4bf0c83169b056f07acbf3483a5e418e58e09e942a3f06421f9cca316a5\",",
      new="",
    ),
    golden_files(),
  )
  assert_false(report.ok)
  @debug.assert_eq(error_codes(report), ["E3001"])
  assert_false(report.checked.merkle_checked)
}

test "merkle root over empty files reports e3001" {
  let input =
    #|{
    #|  "schema": "moon-evidence/v0",
    #|  "subject": { "id": "p", "type": "dataset" },
    #|  "hash_algorithm": "sha256",
    #|  "files": [],
    #|  "merkle_root": "sha256:07a4f4bf0c83169b056f07acbf3483a5e418e58e09e942a3f06421f9cca316a5",
    #|  "version": { "id": "v1" }
    #|}
  let report = verify_manifest(input, {})
  assert_false(report.ok)
  @debug.assert_eq(error_codes(report), ["E3001"])
}

test "empty pack without merkle root is ok" {
  let input =
    #|{
    #|  "schema": "moon-evidence/v0",
    #|  "subject": { "id": "p", "type": "dataset" },
    #|  "hash_algorithm": "sha256",
    #|  "files": [],
    #|  "version": { "id": "v1" }
    #|}
  let report = verify_manifest(input, {})
  assert_true(report.ok)
  assert_eq(report.findings.length(), 0)
}

test "tampered merkle root reports e3003" {
  let report = verify_manifest(
    golden_manifest.replace(
      old="sha256:07a4f4bf0c83169b056f07acbf3483a5e418e58e09e942a3f06421f9cca316a5",
      new="sha256:07a4f4bf0c83169b056f07acbf3483a5e418e58e09e942a3f06421f9cca316a6",
    ),
    golden_files(),
  )
  assert_false(report.ok)
  @debug.assert_eq(error_codes(report), ["E3003"])
  assert_true(report.findings[0].message.contains("expected sha256:07a4f4bf"))
}
