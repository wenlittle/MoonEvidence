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
  let tree_value = match
    @merkle.compute_tree(leaves, algorithm=manifest.algorithm) {
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
        Some(r) =>
          (
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
  match @merkle.compute_tree(leaves, algorithm=manifest.algorithm) {
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

// ---------------------------------------------------------------------------
// Create API: build an evidence pack manifest from raw files
// ---------------------------------------------------------------------------
//
// Request (JSON):
//   {
//     "files": { "<path>": "<hex bytes>" },     // required
//     "subject": { "id": "...", "kind": "..." }, // required
//     "algorithm": "sha256" | "sha512",          // optional, default sha256
//     "version_id": "v1",                        // required
//     "version_parent": "v0" | null              // optional
//   }
// Response (JSON):
//   { "ok": true, "manifest": "<canonical manifest JSON>" }
// or { "ok": false, "error": "..." }

///|
pub fn create_evidence_pack(request_json : String) -> String {
  let request = @json.parse(request_json) catch {
    _ => return error_response("request is not valid JSON")
  }
  guard request is Object(fields) else {
    return error_response("request must be a JSON object")
  }

  // files (required): { path: hex }
  let files : Map[String, Bytes] = {}
  match fields.get("files") {
    None | Some(Null) => return error_response("\"files\" is required")
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

  // subject (required)
  let subject_id = match fields.get("subject") {
    Some(Object(s)) =>
      match s.get("id") {
        Some(String(id)) => id
        _ => return error_response("\"subject.id\" must be a string")
      }
    _ => return error_response("\"subject\" must be an object with id")
  }
  let subject_kind = match fields.get("subject") {
    Some(Object(s)) =>
      // Accept "type" (consistent with manifest) or "kind" (backward compat).
      match s.get("type") {
        Some(String(t)) => t
        _ =>
          match s.get("kind") {
            Some(String(k)) => k
            _ => return error_response("\"subject.type\" must be a string")
          }
      }
    _ => return error_response("\"subject\" must be an object with type")
  }

  // algorithm (optional, default sha256)
  let algorithm = match fields.get("algorithm") {
    None | Some(Null) | Some(String("sha256")) => @digest.Sha256
    Some(String("sha512")) => @digest.Sha512
    Some(_) =>
      return error_response("\"algorithm\" must be \"sha256\" or \"sha512\"")
  }

  // version_id (required), version_parent (optional)
  guard fields.get("version_id") is Some(String(version_id)) else {
    return error_response("\"version_id\" must be a string")
  }
  let version_parent = match fields.get("version_parent") {
    None | Some(Null) => None
    Some(String(p)) => Some(p)
    Some(_) =>
      return error_response("\"version_parent\" must be a string or null")
  }

  let manifest = @create.create_manifest(files, {
    subject: { id: subject_id, kind: subject_kind },
    algorithm,
    version_id,
    version_parent,
  })

  Json::object({ "ok": Json::boolean(true), "manifest": Json::string(manifest) }).stringify()
}

// ---------------------------------------------------------------------------
// Prove API: generate and verify Merkle inclusion proofs
// ---------------------------------------------------------------------------
//
// generate_proof request:
//   { "manifest": "...", "files": { ... }, "index": <int> }
// generate_proof response:
//   { "ok": true, "proof": [ { "side": "left"|"right", "sibling": "<hex>" }, ... ],
//     "leaf_hash": "<hex>", "root": "<hex>" }

///|
pub fn generate_proof(request_json : String) -> String {
  let request = @json.parse(request_json) catch {
    _ => return error_response("request is not valid JSON")
  }
  guard request is Object(fields) else {
    return error_response("request must be a JSON object")
  }
  guard fields.get("manifest") is Some(String(manifest_text)) else {
    return error_response("\"manifest\" must be a string field")
  }

  // files (optional but needed for leaf payload reconstruction)
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

  // index (required)
  let index = match fields.get("index") {
    Some(Number(n, ..)) => n.to_int()
    _ => return error_response("\"index\" must be a number")
  }

  let manifest = @model.Manifest::parse(manifest_text) catch {
    e => return error_response("manifest parse failed: \{e}")
  }

  // Build leaf payloads (same as verify_manifest)
  let leaves : Array[Bytes] = []
  for entry in manifest.files {
    let leaf_json = canonical_file_entry_text(entry)
    leaves.push(@digest.string_to_utf8_bytes(leaf_json))
  }

  match @merkle.compute_proof(leaves, index, algorithm=manifest.algorithm) {
    None => error_response("index out of range or empty tree")
    Some(proof) => {
      let proof_json : Array[Json] = []
      for step in proof {
        proof_json.push(
          Json::object({
            "side": Json::string(step.side.to_string()),
            "sibling": Json::string(@digest.bytes_to_lower_hex(step.sibling)),
          }),
        )
      }
      let leaf_hash = @merkle.leaf_hash(
        leaves[index],
        algorithm=manifest.algorithm,
      )
      let root = match
        @merkle.compute_root(leaves, algorithm=manifest.algorithm) {
        Some(r) => @digest.bytes_to_lower_hex(r)
        None => ""
      }
      Json::object({
        "ok": Json::boolean(true),
        "proof": Json::array(proof_json),
        "leaf_hash": Json::string(@digest.bytes_to_lower_hex(leaf_hash)),
        "root": Json::string(root),
      }).stringify()
    }
  }
}

// verify_proof request:
//   { "leaf": "<hex payload>", "proof": [ { "side": "...", "sibling": "..." }, ... ],
//     "root": "<hex>" }
// verify_proof response:
//   { "ok": true, "valid": <bool> }

///|
pub fn verify_proof(request_json : String) -> String {
  let request = @json.parse(request_json) catch {
    _ => return error_response("request is not valid JSON")
  }
  guard request is Object(fields) else {
    return error_response("request must be a JSON object")
  }

  guard fields.get("leaf") is Some(String(leaf_hex)) else {
    return error_response("\"leaf\" must be a hex string")
  }
  guard @digest.hex_to_bytes(leaf_hex) is Some(leaf_bytes) else {
    return error_response("\"leaf\" is not valid hex")
  }

  let proof : Array[@merkle.ProofStep] = []
  match fields.get("proof") {
    None | Some(Null) => ()
    Some(Array(arr)) =>
      for item in arr {
        guard item is Object(p) &&
          p.get("side") is Some(String(side)) &&
          p.get("sibling") is Some(String(sib_hex)) else {
          return error_response("each proof step must have side and sibling")
        }
        guard @digest.hex_to_bytes(sib_hex) is Some(sib_bytes) else {
          return error_response("proof sibling is not valid hex")
        }
        let s = match side {
          "left" => @merkle.Left
          "right" => @merkle.Right
          _ => return error_response("side must be \"left\" or \"right\"")
        }
        proof.push({ sibling: sib_bytes, side: s })
      }
    Some(_) => return error_response("\"proof\" must be an array")
  }

  guard fields.get("root") is Some(String(root_hex)) else {
    return error_response("\"root\" must be a hex string")
  }
  guard @digest.hex_to_bytes(root_hex) is Some(root_bytes) else {
    return error_response("\"root\" is not valid hex")
  }

  // algorithm (optional, defaults to sha256): determines the hash used for
  // leaf_hash and node_hash during proof verification. Must match the
  // algorithm the proof was generated under.
  let algorithm = match fields.get("algorithm") {
    None | Some(Null) => @digest.Sha256
    Some(String(algo_str)) =>
      match @digest.normalize_algorithm(algo_str) {
        Some(a) => a
        None =>
          return error_response(
            "\"algorithm\" must be \"sha256\" or \"sha512\"",
          )
      }
    Some(_) => return error_response("\"algorithm\" must be a string")
  }

  let valid = @merkle.verify_inclusion(
    leaf_bytes,
    proof,
    root_bytes,
    algorithm~,
  )
  Json::object({ "ok": Json::boolean(true), "valid": Json::boolean(valid) }).stringify()
}

// ---------------------------------------------------------------------------
// Audit API: append-only hash-chained log operations
// ---------------------------------------------------------------------------
//
// audit_append request:
//   { "log": "<existing log JSON or null>", "actor": "...", "action": "...",
//     "subject_id": "...", "manifest_digest": "..." | null,
//     "timestamp": "..." | null }
// audit_append response:
//   { "ok": true, "log": "<updated log JSON>", "entry_hash": "..." }

///|
pub fn audit_append(request_json : String) -> String {
  let request = @json.parse(request_json) catch {
    _ => return error_response("request is not valid JSON")
  }
  guard request is Object(fields) else {
    return error_response("request must be a JSON object")
  }

  // Load existing log or start fresh
  let log = match fields.get("log") {
    None | Some(Null) | Some(String("")) => @audit.AuditLog::new()
    Some(String(log_json)) =>
      match @audit.AuditLog::from_json(log_json) {
        Some(rebuilt) => rebuilt
        None =>
          return error_response("\"log\" is not a valid audit log JSON array")
      }
    Some(_) => return error_response("\"log\" must be a string")
  }

  guard fields.get("actor") is Some(String(actor)) else {
    return error_response("\"actor\" must be a string")
  }
  guard fields.get("action") is Some(String(action)) else {
    return error_response("\"action\" must be a string")
  }
  guard fields.get("subject_id") is Some(String(subject_id_str)) else {
    return error_response("\"subject_id\" must be a string")
  }
  let manifest_digest = match fields.get("manifest_digest") {
    None | Some(Null) => None
    Some(String(d)) => Some(d)
    Some(_) =>
      return error_response("\"manifest_digest\" must be a string or null")
  }
  let timestamp = match fields.get("timestamp") {
    None | Some(Null) => "2026-07-04T00:00:00Z"
    Some(String(t)) => t
    Some(_) => return error_response("\"timestamp\" must be a string")
  }

  let audit_action = @audit.AuditAction::parse(action)
  log.append(timestamp, actor, audit_action, subject_id_str, manifest_digest?)

  let log_json = log.to_json()
  // Extract last entry hash: access entries field directly
  let last_hash = if log.length() == 0 {
    ""
  } else {
    log.entries[log.length() - 1].hash
  }

  Json::object({
    "ok": Json::boolean(true),
    "log": Json::string(log_json),
    "entry_hash": Json::string(last_hash),
  }).stringify()
}

// audit_verify request: { "log": "<log JSON>", "verify_signatures": <bool>, "public_key": "<hex>" }
// audit_verify response: { "ok": true, "chain_valid": <bool>, "signatures_valid": <bool>, "length": <int> }
//
// When verify_signatures is true, also validates Ed25519 signatures on all
// entries using the provided public_key. Entries without signatures are
// treated as valid (skipped). If any signed entry fails verification,
// signatures_valid is false.

///|
pub fn audit_verify(request_json : String) -> String {
  let request = @json.parse(request_json) catch {
    _ => return error_response("request is not valid JSON")
  }
  guard request is Object(fields) else {
    return error_response("request must be a JSON object")
  }
  // Reconstruct the log from JSON, then verify its hash chain integrity.
  let log = match fields.get("log") {
    Some(String(log_json)) =>
      match @audit.AuditLog::from_json(log_json) {
        Some(rebuilt) => rebuilt
        None =>
          return error_response("\"log\" is not a valid audit log JSON array")
      }
    _ => return error_response("\"log\" must be a string")
  }
  let chain_valid = log.verify_chain()
  // Optional: verify Ed25519 signatures on all entries that have them.
  let verify_sigs = match fields.get("verify_signatures") {
    Some(True) => true
    _ => false
  }
  let signatures_valid = if verify_sigs {
    match fields.get("public_key") {
      Some(String(pk_hex)) =>
        match @digest.hex_to_bytes(pk_hex) {
          Some(pk) => log.verify_signatures(pk)
          None => false
        }
      _ => false
    }
  } else {
    true
  }
  Json::object({
    "ok": Json::boolean(true),
    "chain_valid": Json::boolean(chain_valid),
    "signatures_valid": Json::boolean(signatures_valid),
    "length": Json::number(log.length().to_double()),
  }).stringify()
}

// audit_sign request: { "log": "<log JSON>", "secret_key": "<32-byte hex>" }
// audit_sign response: { "ok": true, "log": "<signed log JSON>" }
//
// Signs the last entry of the audit log with an Ed25519 private key.
// The signature is stored in the entry's "signature" field. If the log
// is empty, the call succeeds but no signature is added.

///|
pub fn audit_sign(request_json : String) -> String {
  let request = @json.parse(request_json) catch {
    _ => return error_response("request is not valid JSON")
  }
  guard request is Object(fields) else {
    return error_response("request must be a JSON object")
  }
  let log = match fields.get("log") {
    Some(String(log_json)) =>
      match @audit.AuditLog::from_json(log_json) {
        Some(rebuilt) => rebuilt
        None =>
          return error_response("\"log\" is not a valid audit log JSON array")
      }
    _ => return error_response("\"log\" must be a string")
  }
  guard fields.get("secret_key") is Some(String(sk_hex)) else {
    return error_response("\"secret_key\" must be a hex string")
  }
  guard @digest.hex_to_bytes(sk_hex) is Some(sk) else {
    return error_response("\"secret_key\" is not valid hex")
  }
  if sk.length() != 32 {
    return error_response("\"secret_key\" must be 32 bytes")
  }
  log.sign_last(sk)
  Json::object({
    "ok": Json::boolean(true),
    "log": Json::string(log.to_json()),
  }).stringify()
}

// ---------------------------------------------------------------------------
// Ed25519 Sign API: keypair generation, sign, verify
// ---------------------------------------------------------------------------
//
// ed25519_keypair request: { "seed": "<32-byte hex>" } (optional; if absent,
//   a deterministic seed is derived from a fixed constant — NOT for
//   production use, but sufficient for the demo workbench).
// ed25519_keypair response: { "ok": true, "public_key": "<hex>", "secret_key": "<hex>" }

///|
pub fn ed25519_keypair(request_json : String) -> String {
  let request = @json.parse(request_json) catch {
    _ => return error_response("request is not valid JSON")
  }
  guard request is Object(fields) else {
    return error_response("request must be a JSON object")
  }

  // Seed: 32 bytes. If not provided, use a fixed demo seed.
  let (seed, using_demo_seed) = match fields.get("seed") {
    None | Some(Null) =>
      // Demo seed — NOT secure, just for workbench visualization.
      (
        Bytes::from_array([
          1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
          21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32,
        ]),
        true,
      )
    Some(String(hex)) =>
      (
        match @digest.hex_to_bytes(hex) {
          Some(b) => b
          None => return error_response("\"seed\" is not valid hex")
        },
        false,
      )
    Some(_) => return error_response("\"seed\" must be a hex string")
  }
  if seed.length() != 32 {
    return error_response("\"seed\" must be exactly 32 bytes (64 hex chars)")
  }

  let sk = seed
  let pk = @crypto.ed25519_public_key(sk)
  let response = {
    "ok": Json::boolean(true),
    "public_key": Json::string(@digest.bytes_to_lower_hex(pk)),
    "secret_key": Json::string(@digest.bytes_to_lower_hex(sk)),
  }
  if using_demo_seed {
    response["warning"] = Json::string(
      "demo seed used — NOT for production. Provide a 32-byte \"seed\" for real keys.",
    )
  }
  Json::object(response).stringify()
}

// ed25519_sign request: { "secret_key": "<hex>", "message": "<hex>" }
// ed25519_sign response: { "ok": true, "signature": "<hex>" }

///|
pub fn ed25519_sign(request_json : String) -> String {
  let request = @json.parse(request_json) catch {
    _ => return error_response("request is not valid JSON")
  }
  guard request is Object(fields) else {
    return error_response("request must be a JSON object")
  }
  guard fields.get("secret_key") is Some(String(sk_hex)) else {
    return error_response("\"secret_key\" must be a hex string")
  }
  guard @digest.hex_to_bytes(sk_hex) is Some(sk) else {
    return error_response("\"secret_key\" is not valid hex")
  }
  if sk.length() != 32 {
    return error_response("\"secret_key\" must be 32 bytes")
  }
  guard fields.get("message") is Some(String(msg_hex)) else {
    return error_response("\"message\" must be a hex string")
  }
  guard @digest.hex_to_bytes(msg_hex) is Some(msg) else {
    return error_response("\"message\" is not valid hex")
  }
  let sig = @crypto.ed25519_sign(sk, msg)
  Json::object({
    "ok": Json::boolean(true),
    "signature": Json::string(@digest.bytes_to_lower_hex(sig)),
  }).stringify()
}

// ed25519_verify request: { "public_key": "<hex>", "message": "<hex>", "signature": "<hex>" }
// ed25519_verify response: { "ok": true, "valid": <bool> }

///|
pub fn ed25519_verify(request_json : String) -> String {
  let request = @json.parse(request_json) catch {
    _ => return error_response("request is not valid JSON")
  }
  guard request is Object(fields) else {
    return error_response("request must be a JSON object")
  }
  guard fields.get("public_key") is Some(String(pk_hex)) else {
    return error_response("\"public_key\" must be a hex string")
  }
  guard @digest.hex_to_bytes(pk_hex) is Some(pk) else {
    return error_response("\"public_key\" is not valid hex")
  }
  guard fields.get("message") is Some(String(msg_hex)) else {
    return error_response("\"message\" must be a hex string")
  }
  guard @digest.hex_to_bytes(msg_hex) is Some(msg) else {
    return error_response("\"message\" is not valid hex")
  }
  guard fields.get("signature") is Some(String(sig_hex)) else {
    return error_response("\"signature\" must be a hex string")
  }
  guard @digest.hex_to_bytes(sig_hex) is Some(sig) else {
    return error_response("\"signature\" is not valid hex")
  }
  let valid = @crypto.ed25519_verify(pk, msg, sig)
  Json::object({ "ok": Json::boolean(true), "valid": Json::boolean(valid) }).stringify()
}
