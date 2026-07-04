// Round-trip and unit tests for evidence pack creation.

///|
test "create_manifest produces valid canonical JSON" {
  let files : Map[String, Bytes] = {
    "hello.txt": b"hello world",
    "data.bin": b"\x00\x01\x02\x03",
  }
  let options : CreateOptions = {
    subject: { id: "test-subject", kind: "dataset" },
    algorithm: @digest.Sha256,
    version_id: "v1",
    version_parent: None,
  }
  let manifest_json = create_manifest(files, options)
  // Must parse as valid JSON.
  let _parsed = @json.parse(manifest_json)
  // Must be idempotent under canonicalization.
  let re_canon = @canonjson.canonicalize(manifest_json) catch { _ => "" }
  assert_eq(manifest_json, re_canon)
}

///|
test "create → verify round-trip succeeds" {
  let files : Map[String, Bytes] = {
    "a.txt": b"alpha",
    "b.txt": b"bravo",
    "c.txt": b"charlie",
  }
  let options : CreateOptions = {
    subject: { id: "roundtrip-test", kind: "archive" },
    algorithm: @digest.Sha256,
    version_id: "v1",
    version_parent: None,
  }
  let manifest_json = create_manifest(files, options)
  let report = @verify.verify_manifest(manifest_json, files)
  assert_true(report.ok)
  assert_eq(report.checked.files_total, 3)
  assert_eq(report.checked.files_passed, 3)
  assert_true(report.checked.merkle_checked)
  assert_eq(report.findings.length(), 0)
}

///|
test "create_manifest includes correct file count and sorted order" {
  let files : Map[String, Bytes] = {
    "z.txt": b"zulu",
    "a.txt": b"alpha",
    "m.txt": b"mike",
  }
  let options : CreateOptions = {
    subject: { id: "order-test", kind: "test" },
    algorithm: @digest.Sha256,
    version_id: "v1",
    version_parent: None,
  }
  let manifest_json = create_manifest(files, options)
  let parsed = @json.parse(manifest_json) catch { _ => return }
  let file_array = match parsed {
    Object(obj) =>
      match obj.get("files") {
        Some(Array(arr)) => arr
        _ => return
      }
    _ => return
  }
  assert_eq(file_array.length(), 3)
  // Files should be sorted by path.
  let first_path = match file_array[0] {
    Object(obj) =>
      match obj.get("path") {
        Some(String(s)) => s
        _ => ""
      }
    _ => ""
  }
  assert_eq(first_path, "a.txt")
}

///|
test "create_manifest with version parent" {
  let files : Map[String, Bytes] = { "f.txt": b"file" }
  let options : CreateOptions = {
    subject: { id: "chain-test", kind: "test" },
    algorithm: @digest.Sha256,
    version_id: "v2",
    version_parent: Some("v1"),
  }
  let manifest_json = create_manifest(files, options)
  let report = @verify.verify_manifest(manifest_json, files)
  assert_true(report.ok)
}

///|
test "create_manifest with empty files produces valid output" {
  let files : Map[String, Bytes] = {}
  let options : CreateOptions = {
    subject: { id: "empty-test", kind: "test" },
    algorithm: @digest.Sha256,
    version_id: "v1",
    version_parent: None,
  }
  let manifest_json = create_manifest(files, options)
  let _parsed = @json.parse(manifest_json)
  // Empty files is valid at create time; verify may have opinions.
}

///|
test "create → tamper → verify detects mismatch" {
  let files : Map[String, Bytes] = { "secret.txt": b"original content" }
  let options : CreateOptions = {
    subject: { id: "tamper-test", kind: "test" },
    algorithm: @digest.Sha256,
    version_id: "v1",
    version_parent: None,
  }
  let manifest_json = create_manifest(files, options)
  // Tamper with the file after creating the manifest.
  let tampered_files : Map[String, Bytes] = {
    "secret.txt": b"TAMPERED content",
  }
  let report = @verify.verify_manifest(manifest_json, tampered_files)
  assert_false(report.ok)
  assert_true(report.findings.length() > 0)
}

///|
/// Proves that `create_manifest` sorts file paths by UTF-16 code-unit order
/// (RFC 8785 section 3.2.3), NOT MoonBit's default shortlex (length-first).
///
/// Under shortlex, `"b"` (length 1) would sort before `"aa"` (length 2).
/// Under code-unit order, `"aa"` < `"b"` because `'a' (0x61) < 'b' (0x62)`.
/// A cross-tool implementation (Node `Array.sort()`, Python `sorted()`) uses
/// code-unit order, so the Merkle root would diverge if MoonBit used
/// shortlex. This test pins the code-unit-order contract.
test "create_manifest sorts paths by code-point order, not shortlex" {
  // Paths chosen so shortlex and code-point order disagree:
  //   shortlex:     "b" < "aa"  (length 1 before length 2)
  //   code-point:   "aa" < "b"  ('a' < 'b')
  let files : Map[String, Bytes] = {
    "b": b"bravo",
    "aa": b"alpha-alpha",
  }
  let options : CreateOptions = {
    subject: { id: "sort-order-test", kind: "test" },
    algorithm: @digest.Sha256,
    version_id: "v1",
    version_parent: None,
  }
  let manifest_json = create_manifest(files, options)
  let parsed = @json.parse(manifest_json) catch { _ => return }
  let file_array = match parsed {
    Object(obj) =>
      match obj.get("files") {
        Some(Array(arr)) => arr
        _ => return
      }
    _ => return
  }
  assert_eq(file_array.length(), 2)
  // First entry must be "aa", not "b" — code-point order, not shortlex.
  let first_path = match file_array[0] {
    Object(obj) =>
      match obj.get("path") {
        Some(String(s)) => s
        _ => ""
      }
    _ => ""
  }
  let second_path = match file_array[1] {
    Object(obj) =>
      match obj.get("path") {
        Some(String(s)) => s
        _ => ""
      }
    _ => ""
  }
  assert_eq(first_path, "aa")
  assert_eq(second_path, "b")
}

///|
/// Cross-checks that the code-point-order sort produces a Merkle root
/// identical to an independent Node implementation. The leaf payloads are
/// the canonical file-entry JSON objects; the root is RFC 6962 with domain
/// separation. This test uses a fixed expected root computed by
/// `tools/cross-verify.mjs` for the same file set, so any sort-order
/// regression (reverting to shortlex) changes the root and fails here.
test "create_manifest merkle root matches code-point-order expectation" {
  // Two files whose order differs between shortlex and code-point sort.
  // Independent Node computation (cross-verify.mjs algorithm) with
  // code-point order yields this exact root:
  //   sha256:96c3cb01779e37d47be046f625820ae7b215c06046768b27869949c3973f1730
  // Under shortlex ("b" before "aa") the root would be:
  //   sha256:315ab5f67f8327d4d7e1c36bd4080f8b3784cdd91cbf21f2a7f6694408ecdfc3
  let files : Map[String, Bytes] = {
    "b": b"bravo",
    "aa": b"alpha-alpha",
  }
  let options : CreateOptions = {
    subject: { id: "root-order-test", kind: "test" },
    algorithm: @digest.Sha256,
    version_id: "v1",
    version_parent: None,
  }
  let manifest_json = create_manifest(files, options)
  let parsed = @json.parse(manifest_json) catch { _ => return }
  let root = match parsed {
    Object(obj) =>
      match obj.get("merkle_root") {
        Some(String(s)) => s
        _ => ""
      }
    _ => ""
  }
  // Must match the code-point-order root, not the shortlex root.
  assert_eq(
    root,
    "sha256:96c3cb01779e37d47be046f625820ae7b215c06046768b27869949c3973f1730",
  )
}
