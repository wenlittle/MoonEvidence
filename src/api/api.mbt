// Browser/JS adapter: a single string-in / string-out entry point so no
// MoonBit type ever crosses the JS boundary. Mirrors the CLI's merge
// semantics (manifest pipeline + optional version chain) without any IO -
// callers inject file bytes as hex.
//
// Request (JSON):
//   {
//     "manifest": "<manifest.json text>",          // required
//     "files": { "<pack path>": "<hex bytes>" },   // optional
//     "version_chain": "<version_chain.json text>" // optional
//   }
// Response (JSON):
//   { "ok": Bool, "explain": String, "report": <canonical report object> }
// or, when the request itself is malformed:
//   { "ok": false, "error": String }

///|
/// Verifies an evidence pack delivered as a JSON request string and returns
/// a JSON response string. Exported to JS (see moon.pkg).
pub fn verify_evidence(request_json : String) -> String {
  let request = @json.parse(request_json) catch {
    _ => return error_response("request is not valid JSON")
  }
  guard request is Object(fields) else {
    return error_response("request must be a JSON object")
  }

  // manifest (required)
  guard fields.get("manifest") is Some(String(manifest_text)) else {
    return error_response("\"manifest\" must be a string field")
  }

  // files (optional): { path: hex }
  let files : Map[String, Bytes] = {}
  match fields.get("files") {
    None | Some(Null) => ()
    Some(Object(entries)) =>
      for path, value in entries {
        guard value is String(hex) else {
          return error_response("files[\"\{path}\"] must be a hex string")
        }
        guard @digest.hex_to_bytes(hex) is Some(content) else {
          return error_response("files[\"\{path}\"] is not valid hex")
        }
        files[path] = content
      }
    Some(_) => return error_response("\"files\" must be an object")
  }

  // Pure manifest pipeline.
  let report = @verify.verify_manifest(manifest_text, files)

  // Optional version chain, merged exactly like the CLI does.
  let chain_findings : Array[@diag.Finding] = match
    fields.get("version_chain") {
    None | Some(Null) => []
    Some(String(chain_text)) =>
      @verify.verify_chain_text(chain_text, path="version_chain")
    Some(_) => return error_response("\"version_chain\" must be a string")
  }
  let merged_findings = report.findings + chain_findings
  let merged : @diag.VerifyReport = {
    ok: !merged_findings.iter().any(f => f.severity is Error),
    findings: merged_findings,
    checked: report.checked,
  }

  // Response envelope. The report is embedded as a JSON object (parsed back
  // from its canonical rendering, which cannot fail for our own output).
  let report_value = @json.parse(@diag.to_json(merged)) catch {
    _ => Json::null()
  }
  Json::object({
    "ok": Json::boolean(merged.ok),
    "explain": Json::string(@diag.explain(merged)),
    "report": report_value,
  }).stringify()
}

///|
fn error_response(message : String) -> String {
  Json::object({ "ok": Json::boolean(false), "error": Json::string(message) }).stringify()
}

// ---------------------------------------------------------------------------
// Visualization API: full Merkle tree materialization
// ---------------------------------------------------------------------------
//
// `compute_merkle_tree` is the visualization counterpart to `verify_evidence`:
// it accepts the same JSON envelope (manifest + optional hex files), parses
// the manifest, builds the canonical leaf payloads exactly like `verify_manifest`
// does, and returns the full Merkle tree plus metadata the front end needs to
// render it: per-level hash arrays (hex), leaf-path metadata so a Tamper-Lab
// view can highlight which ancestor nodes depend on which leaf, and the
// recorded-vs-actual root comparison so the renderer can colour the root
// red on tamper without re-running verification.
//
// Request (JSON): same envelope as `verify_evidence` (`manifest` required,
// `files` optional).
// Response (JSON) on success:
//   {
//     "ok": true,
//     "tree": {
//       "leaves": [ { "path": "<file path>", "size": <int>, "digest": "<digest>" }, ... ],
//       "levels": [ [ "<hex>", ... ], ... ],      // levels[0] = leaf hashes
//       "root":  { "recorded": "<digest>|null", "actual": "<digest>", "matches": <bool> },
//       "paths": [ { "level": <int>, "node_index": <int> }, ... ]
//     }
//   }
// On parse failure: `{ "ok": false, "error": "<reason>" }`.
///|
pub fn compute_merkle_tree(request_json : String) -> String {
  let request = @json.parse(request_json) catch {
    _ => return error_response("request is not valid JSON")
  }
  guard request is Object(fields) else {
    return error_response("request must be a JSON object")
  }
  guard fields.get("manifest") is Some(String(manifest_text)) else {
    return error_response("\"manifest\" must be a string field")
  }

  // files (optional): { path: hex }
  let files : Map[String, Bytes] = {}
  match fields.get("files") {
    None | Some(Null) => ()
    Some(Object(entries)) =>
      for path, value in entries {
        guard value is String(hex) else {
          return error_response("files[\"\{path}\"] must be a hex string")
        }
        guard @digest.hex_to_bytes(hex) is Some(content) else {
          return error_response("files[\"\{path}\"] is not valid hex")
        }
        files[path] = content
      }
    Some(_) => return error_response("\"files\" must be an object")
  }

  // Parse manifest; surface model errors as plain JSON for the renderer.
  let manifest = @model.Manifest::parse(manifest_text) catch {
    e => return error_response("manifest parse failed: \{e}")
  }

  // Build canonical leaf payloads exactly the way verify_manifest does.
  let leaves : Array[Bytes] = []
  let leaf_meta : Array[Json] = []
  for entry in manifest.files {
    let leaf_json_str = canonical_file_entry_text(entry)
    leaves.push(@digest.string_to_utf8_bytes(leaf_json_str))
    leaf_meta.push(
      Json::object({
        "path": Json::string(entry.path),
        "size": Json::number(entry.size.to_double()),
        "digest": Json::string(entry.digest.to_string()),
      }),
    )
  }

  // Materialize the tree (None for empty files[]).
  let tree_value = match @merkle.compute_tree(leaves) {
    None =>
      Json::object({
        "levels": Json::array([]),
        "leaf_count": Json::number(0.0),
        "height": Json::number(0.0),
        "root": Json::null(),
        "leaves_meta": Json::array([]),
      })
    Some(tree) => {
      // Hex-encode every level.
      let levels : Array[Json] = []
      for level in 0..<tree.height() {
        let nodes = tree.level(level)
        let hex_nodes : Array[Json] = []
        for node in nodes {
          hex_nodes.push(Json::string(@digest.bytes_to_lower_hex(node)))
        }
        levels.push(Json::array(hex_nodes))
      }
      // Recorded vs actual root.
      let actual_hex = match tree.root() {
        Some(r) => @digest.bytes_to_lower_hex(r)
        None => ""
      }
      let actual_str = "\{manifest.algorithm.label()}:\{actual_hex}"
      let (recorded_str, matches) = match manifest.merkle_root {
        None => (Json::null(), true)
        Some(r) => (
          Json::string(r.to_string()),
          @digest.same_digest(actual_str, r.to_string()),
        )
      }
      let root_obj = Json::object({
        "recorded": recorded_str,
        "actual": Json::string(actual_str),
        "matches": Json::boolean(matches),
      })
      Json::object({
        "levels": Json::array(levels),
        "leaf_count": Json::number(tree.leaf_count().to_double()),
        "height": Json::number(tree.height().to_double()),
        "root": root_obj,
        "leaves_meta": Json::array(leaf_meta),
      })
    }
  }

  // Optionally compute the spine for leaf 0 — used by Tamper Lab's
  // "default focus" but kept here as a demonstrative smoke check.
  let spine : Array[Json] = []
  match @merkle.compute_tree(leaves) {
    Some(tree) =>
      match tree.leaf_path(0) {
        Some(path) =>
          for step in path {
            spine.push(
              Json::object({
                "level": Json::number(step.level.to_double()),
                "node_index": Json::number(step.node_index.to_double()),
              }),
            )
          }
        None => ()
      }
    None => ()
  }

  Json::object({
    "ok": Json::boolean(true),
    "tree": tree_value,
    "example_path": Json::array(spine),
  }).stringify()
}

///|
/// Duplicate of `verify_manifest`'s canonical entry renderer, kept private
/// to this adapter so the visualization path stays independent of the
/// verification path (no shared mutable state).
fn canonical_file_entry_text(entry : @model.FileEntry) -> String {
  let document = Json::object({
    "path": Json::string(entry.path),
    "size": Json::number(entry.size.to_double()),
    "digest": Json::string(entry.digest.to_string()),
  })
  @canonjson.canonicalize(document.stringify()) catch {
    _ => document.stringify()
  }
}
