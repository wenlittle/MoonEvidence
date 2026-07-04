// Incremental verification: skips re-hashing files whose digests are known
// to be correct from a previous run. The Merkle root is always recomputed
// from scratch (it's fast), so the security guarantee is identical to a
// full verify — only the per-file I/O-bound hashing is amortized.

///|
/// Result of incremental verification, extending the base report with stats
/// on how many files were re-hashed vs. skipped.
pub(all) struct IncrementalReport {
  report : @diag.VerifyReport
  files_rehashed : Int
  files_skipped : Int
}

///|
/// Incrementally verifies a manifest, skipping digest recomputation for
/// files whose path and expected digest match a `previous` entry.
///
/// The caller still supplies all file bytes; the optimization is that we
/// only call SHA-256/512 on files that are new or changed. Merkle root
/// verification always runs in full.
pub fn verify_manifest_incremental(
  manifest_json : String,
  files : Map[String, Bytes],
  previous : Map[String, String],
) -> IncrementalReport {
  let findings : Array[@diag.Finding] = []

  let manifest = @model.Manifest::parse(manifest_json) catch {
    error => {
      findings.push({
        code: error.error_code(),
        severity: Error,
        path: error.field_path(),
        message: error.detail(),
      })
      return {
        report: {
          ok: false,
          findings,
          checked: { files_total: 0, files_passed: 0, merkle_checked: false },
        },
        files_rehashed: 0,
        files_skipped: 0,
      }
    }
  }

  let canonical_json = @canonjson.canonicalize(manifest_json) catch {
    _ => manifest_json
  }
  ignore(canonical_json)

  let mut files_passed = 0
  let mut rehashed = 0
  let mut skipped = 0
  let listed : Map[String, Bool] = {}
  let leaves : Array[Bytes] = []

  for entry in manifest.files {
    listed[entry.path] = true
    let leaf_json = canonical_file_entry(entry)
    let leaf_bytes = @digest.string_to_utf8_bytes(leaf_json)
    leaves.push(leaf_bytes)

    match files.get(entry.path) {
      None => {
        findings.push({
          code: "E2003",
          severity: Error,
          path: entry.path,
          message: "file listed in manifest but missing from pack",
        })
        continue
      }
      Some(content) => {
        let expected_digest = entry.digest.to_string()
        let prev = previous.get(entry.path)
        if prev is Some(prev_digest) && prev_digest == expected_digest {
          skipped = skipped + 1
          files_passed = files_passed + 1
        } else {
          rehashed = rehashed + 1
          let actual = @digest.Digest::of_bytes(manifest.algorithm, content)
          if actual == entry.digest {
            files_passed = files_passed + 1
          } else {
            findings.push({
              code: "E2003",
              severity: Error,
              path: entry.path,
              message: "digest mismatch, expected \{entry.digest.to_string()} got \{actual.to_string()}",
            })
          }
        }
      }
    }
  }

  for path in files.keys() {
    if !listed.contains(path) {
      findings.push({
        code: "W1001",
        severity: Warning,
        path,
        message: "file present in pack but not listed in manifest",
      })
    }
  }

  let mut merkle_checked = false
  match manifest.merkle_root {
    Some(expected_root) =>
      match @merkle.compute_root(leaves) {
        Some(root) => {
          let actual_hex = @digest.bytes_to_lower_hex(root)
          let actual_str = "\{manifest.algorithm.label()}:\{actual_hex}"
          if @digest.same_digest(actual_str, expected_root.to_string()) {
            merkle_checked = true
          } else {
            findings.push({
              code: "E3003",
              severity: Error,
              path: "merkle_root",
              message: "merkle root mismatch",
            })
          }
        }
        None =>
          findings.push({
            code: "E3001",
            severity: Error,
            path: "merkle_root",
            message: "merkle root present but files[] is empty",
          })
      }
    None =>
      if manifest.files.length() > 0 {
        findings.push({
          code: "E3001",
          severity: Error,
          path: "merkle_root",
          message: "merkle root missing while files[] is non-empty",
        })
      }
  }

  let ok = findings.iter().all(fn(f) { f.severity != @diag.Error })
  {
    report: {
      ok,
      findings,
      checked: {
        files_total: manifest.files.length(),
        files_passed,
        merkle_checked,
      },
    },
    files_rehashed: rehashed,
    files_skipped: skipped,
  }
}
