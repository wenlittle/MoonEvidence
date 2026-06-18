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
  let re_canon = try { @canonjson.canonicalize(manifest_json) } catch { _ => "" }
  assert_eq!(manifest_json, re_canon)
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
  assert_true!(report.ok)
  assert_eq!(report.checked.files_total, 3)
  assert_eq!(report.checked.files_passed, 3)
  assert_true!(report.checked.merkle_checked)
  assert_eq!(report.findings.length(), 0)
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
  assert_eq!(file_array.length(), 3)
  // Files should be sorted by path.
  let first_path = match file_array[0] {
    Object(obj) =>
      match obj.get("path") {
        Some(String(s)) => s
        _ => ""
      }
    _ => ""
  }
  assert_eq!(first_path, "a.txt")
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
  assert_true!(report.ok)
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
  let files : Map[String, Bytes] = {
    "secret.txt": b"original content",
  }
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
  assert_false!(report.ok)
  assert_true!(report.findings.length() > 0)
}
