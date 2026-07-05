// Incremental verification: skips re-hashing files whose (path, digest) pair
// matches a trusted previous verification cache. The Merkle root is always
// recomputed from scratch, but the per-file content hashing is skipped when
// the cache is trusted.
//
// TRUST MODEL: The `previous` cache MUST come from a prior successful
// verification run on the same pack. If an attacker can tamper with the
// cache (e.g., by editing cache.json on disk), they can cause modified
// files to skip content hashing. The manifest digest check (E2004) still
// detects manifest tampering, and the Merkle root still catches structural
// changes, but per-file content integrity is only as trustworthy as the
// cache source. For adversarial environments, use full `verify_manifest`.

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
///
/// `expected_manifest_digest`, when given, is the externally recorded
/// canonical digest that the manifest must equal (E2004) — identical to
/// `verify_manifest`'s step 3. Without this the incremental path would be
/// a silently weakened verification (missing the manifest-tamper check).
pub fn verify_manifest_incremental(
  manifest_json : String,
  files : Map[String, Bytes],
  previous : Map[String, String],
  expected_manifest_digest~ : String?,
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

  // Step 2: canonicalize (E1004 on failure) — same as the main pipeline.
  let canonical_json : String? = try
    @canonjson.canonicalize(manifest_json)
  catch {
    error => {
      findings.push({
        code: "E1004",
        severity: Error,
        path: "manifest",
        message: "canonicalization failed: \{error}",
      })
      None
    }
  } noraise {
    value => Some(value)
  }

  // Step 3: manifest canonical digest vs externally recorded value (E2004).
  // This is the check that was previously missing — the old code computed
  // canonical_json then `ignore`d it, making the incremental path a silently
  // weakened verification. Now it mirrors verify_manifest step 3 exactly.
  if expected_manifest_digest is Some(expected) &&
    canonical_json is Some(canonical) {
    let actual = @digest.Digest::of_bytes(
      manifest.algorithm,
      @digest.string_to_utf8_bytes(canonical),
    ).to_string()
    if actual != expected {
      findings.push({
        code: "E2004",
        severity: Error,
        path: "manifest",
        message: "canonical digest mismatch, expected \{expected} got \{actual}",
      })
    }
  }

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
      match @merkle.compute_root(leaves, algorithm=manifest.algorithm) {
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
