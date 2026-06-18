// Tests for incremental verification.

///|
test "incremental verify with all files cached skips rehashing" {
  let files : Map[String, Bytes] = {
    "a.txt": b"alpha",
    "b.txt": b"bravo",
  }
  let manifest_json = @create.create_manifest(
    files,
    {
      subject: { id: "inc-test", kind: "test" },
      algorithm: @digest.Sha256,
      version_id: "v1",
      version_parent: None,
    },
  )
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
  assert_true!(result.report.ok)
  assert_eq!(result.files_skipped, 2)
  assert_eq!(result.files_rehashed, 0)
}

///|
test "incremental verify rehashes changed files" {
  let files : Map[String, Bytes] = {
    "a.txt": b"alpha",
    "b.txt": b"bravo",
  }
  let manifest_json = @create.create_manifest(
    files,
    {
      subject: { id: "inc-test2", kind: "test" },
      algorithm: @digest.Sha256,
      version_id: "v1",
      version_parent: None,
    },
  )
  let previous : Map[String, String] = {
    "a.txt": @digest.Digest::of_bytes(@digest.Sha256, b"alpha").to_string(),
  }
  let result = verify_manifest_incremental(manifest_json, files, previous)
  assert_true!(result.report.ok)
  assert_eq!(result.files_skipped, 1)
  assert_eq!(result.files_rehashed, 1)
}

///|
test "incremental verify detects tampered file even with stale cache" {
  let original_files : Map[String, Bytes] = { "a.txt": b"original" }
  let manifest_json = @create.create_manifest(
    original_files,
    {
      subject: { id: "inc-tamper", kind: "test" },
      algorithm: @digest.Sha256,
      version_id: "v1",
      version_parent: None,
    },
  )
  let tampered_files : Map[String, Bytes] = { "a.txt": b"TAMPERED" }
  let stale_cache : Map[String, String] = {
    "a.txt": @digest.Digest::of_bytes(@digest.Sha256, b"TAMPERED").to_string(),
  }
  let result = verify_manifest_incremental(manifest_json, tampered_files, stale_cache)
  assert_false!(result.report.ok)
  assert_eq!(result.files_rehashed, 1)
}

///|
test "incremental verify with empty cache equals full verify" {
  let files : Map[String, Bytes] = { "x.txt": b"data" }
  let manifest_json = @create.create_manifest(
    files,
    {
      subject: { id: "inc-empty", kind: "test" },
      algorithm: @digest.Sha256,
      version_id: "v1",
      version_parent: None,
    },
  )
  let empty_cache : Map[String, String] = {}
  let result = verify_manifest_incremental(manifest_json, files, empty_cache)
  assert_true!(result.report.ok)
  assert_eq!(result.files_rehashed, 1)
  assert_eq!(result.files_skipped, 0)
}
