// Manifest verification pipeline, orchestrating the spec's verification
// semantics over the pure packages: parse -> canonicalize -> manifest digest
// -> file digests -> unlisted files -> Merkle root. Version chain linearity
// lives in chain.mbt; combining both is the adapter's job.
//
// Pure-core rule: no IO here. File contents arrive as a caller-provided
// `Map[String, Bytes]` keyed by manifest path; the CLI adapter reads disk.

///|
fn finding(
  code : String,
  severity : @diag.Severity,
  path : String,
  message : String,
) -> @diag.Finding {
  { code, severity, path, message }
}

///|
/// Verifies one manifest against caller-provided file bytes.
///
/// `expected_manifest_digest`, when given, is the externally recorded value
/// (e.g. from a notarization transaction) that the manifest's canonical
/// digest must equal (E2004). It must be in canonical
/// `<algo>:<lowercase-hex>` form.
///
/// The report is exhaustive, not fail-fast: every file problem is listed in
/// one run so users fix packs in one pass.
pub fn verify_manifest(
  manifest_json : String,
  files : Map[String, Bytes],
  expected_manifest_digest? : String,
) -> @diag.VerifyReport {
  let findings : Array[@diag.Finding] = []

  // Step 1: parse + validate the manifest model.
  let manifest = @model.Manifest::parse(manifest_json) catch {
    error => {
      findings.push(
        finding(error.error_code(), Error, error.field_path(), error.detail()),
      )
      return {
        ok: false,
        findings,
        checked: { files_total: 0, files_passed: 0, merkle_checked: false },
      }
    }
  }

  // Step 2: canonicalize the manifest document (E1004 on failure).
  let canonical_manifest : String? = try
    @canonjson.canonicalize(manifest_json)
  catch {
    error => {
      findings.push(
        finding("E1004", Error, "manifest", "canonicalization failed: \{error}"),
      )
      None
    }
  } noraise {
    value => Some(value)
  }

  // Step 3: manifest canonical digest versus externally recorded value.
  if expected_manifest_digest is Some(expected) &&
    canonical_manifest is Some(canonical) {
    let actual = @digest.Digest::of_bytes(
      manifest.algorithm,
      @digest.string_to_utf8_bytes(canonical),
    ).to_string()
    if actual != expected {
      findings.push(
        finding(
          "E2004",
          Error,
          "manifest",
          "canonical digest mismatch, expected \{expected} got \{actual}",
        ),
      )
    }
  }

  // Step 4: per-file digests (E2003), exhaustive across all entries; the
  // same pass records listed paths for the unlisted-file check below.
  let mut files_passed = 0
  let listed : Map[String, Bool] = {}
  for entry in manifest.files {
    listed[entry.path] = true
    match files.get(entry.path) {
      None =>
        findings.push(
          finding(
            "E2003",
            Error,
            entry.path,
            "file content not provided by caller",
          ),
        )
      Some(content) => {
        let actual = @digest.Digest::of_bytes(manifest.algorithm, content)
        if actual == entry.digest {
          files_passed = files_passed + 1
        } else {
          findings.push(
            finding(
              "E2003",
              Error,
              entry.path,
              "digest mismatch, expected \{entry.digest.to_string()} got \{actual.to_string()}",
            ),
          )
        }
      }
    }
  }

  // Step 5: files provided but not listed in the manifest (W1001).
  for path, _ in files {
    if listed.get(path) is None {
      findings.push(
        finding(
          "W1001",
          Warning,
          path,
          "file present in pack but not listed in manifest",
        ),
      )
    }
  }

  // Step 6: Merkle root over canonical file entries (E3001 / E3003).
  let mut merkle_checked = false
  match manifest.merkle_root {
    None =>
      if manifest.files.length() > 0 {
        findings.push(
          finding(
            "E3001",
            Error,
            "merkle_root",
            "merkle root missing while files[] is non-empty",
          ),
        )
      }
    Some(recorded) => {
      let leaves = manifest.files.map(entry => {
        @digest.string_to_utf8_bytes(canonical_file_entry(entry))
      })
      match @merkle.compute_root(leaves, algorithm=manifest.algorithm) {
        None =>
          // merkle_root present but files[] empty: nothing it could attest.
          findings.push(
            finding(
              "E3001",
              Error,
              "merkle_root",
              "merkle root present but files[] is empty",
            ),
          )
        Some(root) => {
          merkle_checked = true
          let actual = @digest.bytes_to_lower_hex(root)
          if actual != recorded.hex {
            findings.push(
              finding(
                "E3003",
                Error,
                "merkle_root",
                "merkle root mismatch, expected \{recorded.to_string()} got \{manifest.algorithm.label()}:\{actual}",
              ),
            )
          }
        }
      }
    }
  }

  // Step 7: aggregate.
  {
    ok: !findings.iter().any(item => item.severity is Error),
    findings,
    checked: {
      files_total: manifest.files.length(),
      files_passed,
      merkle_checked,
    },
  }
}

///|
/// Canonical JSON of one `files[]` entry - the Merkle leaf payload defined
/// by the spec (`canonical_file_entry_bytes`). Built from the validated
/// model: digest strings are canonical by parse rule, so this re-rendering
/// is byte-identical to canonicalizing the original manifest entry.
fn canonical_file_entry(entry : @model.FileEntry) -> String {
  let document = Json::object({
    "path": Json::string(entry.path),
    "size": Json::number(entry.size.to_double()),
    "digest": Json::string(entry.digest.to_string()),
  })
  @canonjson.canonicalize(document.stringify()) catch {
    // Sizes are validated integers and strings always canonicalize;
    // unreachable, kept total to avoid a raising signature.
    _ => document.stringify()
  }
}
