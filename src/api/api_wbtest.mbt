// Whitebox tests for the JS string adapter: request envelope validation,
// hex decoding, pipeline pass-through, and version chain merging. The
// golden pack mirrors verify_wbtest, so digests stay cross-checked against
// the independent Node reference (tools/gen-pack-fixture.mjs).

// ---------------------------------------------------------------------------
// Golden data (same pack as verify_wbtest)
// ---------------------------------------------------------------------------

///|
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

///|
/// Hex encoding of "hello world\n" (files/a.txt). files/b.bin is empty.
const GOLDEN_A_HEX : String = "68656c6c6f20776f726c640a"

///|
let empty_manifest : String =
  #|{
  #|  "schema": "moon-evidence/v0",
  #|  "subject": { "id": "p", "type": "dataset" },
  #|  "hash_algorithm": "sha256",
  #|  "files": [],
  #|  "version": { "id": "v1" }
  #|}

// ---------------------------------------------------------------------------
// Request / response helpers
// ---------------------------------------------------------------------------

///|
/// Builds a request envelope; absent arguments leave the field out entirely.
/// `files` values are raw Json so tests can also inject non-string values.
fn make_request(
  manifest? : String,
  files? : Array[(String, Json)],
  version_chain? : String,
) -> String {
  let fields : Map[String, Json] = {}
  if manifest is Some(text) {
    fields["manifest"] = Json::string(text)
  }
  if files is Some(entries) {
    let file_fields : Map[String, Json] = {}
    for pair in entries {
      file_fields[pair.0] = pair.1
    }
    fields["files"] = Json::object(file_fields)
  }
  if version_chain is Some(text) {
    fields["version_chain"] = Json::string(text)
  }
  Json::object(fields).stringify()
}

///|
fn golden_request() -> String {
  make_request(manifest=golden_manifest, files=[
    ("files/a.txt", Json::string(GOLDEN_A_HEX)),
    ("files/b.bin", Json::string("")),
  ])
}

///|
fn response_fields(response : String) -> Map[String, Json] raise {
  guard @json.parse(response) is Object(fields) else {
    fail("response is not a JSON object: \{response}")
  }
  fields
}

///|
fn response_ok(response : String) -> Bool raise {
  match response_fields(response).get("ok") {
    Some(True) => true
    Some(False) => false
    _ => fail("response has no boolean \"ok\": \{response}")
  }
}

///|
fn response_error(response : String) -> String raise {
  guard response_fields(response).get("error") is Some(String(message)) else {
    fail("response has no \"error\" field: \{response}")
  }
  message
}

///|
fn response_explain(response : String) -> String raise {
  guard response_fields(response).get("explain") is Some(String(text)) else {
    fail("response has no \"explain\" field: \{response}")
  }
  text
}

///|
/// Finding codes inside the embedded report, in report order.
fn report_codes(response : String) -> Array[String] raise {
  guard response_fields(response).get("report") is Some(Object(report)) else {
    fail("response has no \"report\" object: \{response}")
  }
  guard report.get("findings") is Some(Array(findings)) else {
    fail("report has no \"findings\" array: \{response}")
  }
  let codes : Array[String] = []
  for item in findings {
    guard item is Object(finding) && finding.get("code") is Some(String(code)) else {
      fail("finding has no \"code\": \{response}")
    }
    codes.push(code)
  }
  codes
}

// ---------------------------------------------------------------------------
// Request envelope errors
// ---------------------------------------------------------------------------

///|
test "non-json request is rejected" {
  let response = verify_evidence("{ not json")
  assert_false(response_ok(response))
  assert_eq(response_error(response), "request is not valid JSON")
}

///|
test "non-object request is rejected" {
  let response = verify_evidence("[1, 2]")
  assert_false(response_ok(response))
  assert_eq(response_error(response), "request must be a JSON object")
}

///|
test "missing manifest field is rejected" {
  let response = verify_evidence(make_request())
  assert_false(response_ok(response))
  assert_eq(response_error(response), "\"manifest\" must be a string field")
}

///|
test "non-string manifest is rejected" {
  let response = verify_evidence("{\"manifest\": 42}")
  assert_false(response_ok(response))
  assert_eq(response_error(response), "\"manifest\" must be a string field")
}

///|
test "non-object files is rejected" {
  let response = verify_evidence(
    "{\"manifest\": \"x\", \"files\": \"not an object\"}",
  )
  assert_false(response_ok(response))
  assert_eq(response_error(response), "\"files\" must be an object")
}

///|
test "non-string file value is rejected" {
  let response = verify_evidence(
    make_request(manifest=golden_manifest, files=[
      ("files/a.txt", Json::number(7)),
    ]),
  )
  assert_false(response_ok(response))
  assert_eq(
    response_error(response),
    "files[\"files/a.txt\"] must be a hex string",
  )
}

///|
test "odd-length hex is rejected" {
  let response = verify_evidence(
    make_request(manifest=golden_manifest, files=[
      ("files/a.txt", Json::string("abc")),
    ]),
  )
  assert_false(response_ok(response))
  assert_eq(response_error(response), "files[\"files/a.txt\"] is not valid hex")
}

///|
test "non-hex character is rejected" {
  let response = verify_evidence(
    make_request(manifest=golden_manifest, files=[
      ("files/a.txt", Json::string("zz")),
    ]),
  )
  assert_false(response_ok(response))
  assert_eq(response_error(response), "files[\"files/a.txt\"] is not valid hex")
}

///|
test "non-string version chain is rejected" {
  let response = verify_evidence(
    "{\"manifest\": \"x\", \"version_chain\": [1]}",
  )
  assert_false(response_ok(response))
  assert_eq(response_error(response), "\"version_chain\" must be a string")
}

// ---------------------------------------------------------------------------
// Manifest pipeline pass-through
// ---------------------------------------------------------------------------

///|
test "golden pack verifies ok" {
  let response = verify_evidence(golden_request())
  assert_true(response_ok(response))
  assert_true(response_explain(response).has_prefix("verification OK"))
  assert_eq(report_codes(response).length(), 0)
}

///|
test "uppercase hex decodes equally" {
  let response = verify_evidence(
    make_request(manifest=golden_manifest, files=[
      ("files/a.txt", Json::string("68656C6C6F20776F726C640A")),
      ("files/b.bin", Json::string("")),
    ]),
  )
  assert_true(response_ok(response))
}

///|
test "tampered file reports e2003 in embedded report" {
  // "hello world!" instead of "hello world\n": same length, wrong digest.
  let response = verify_evidence(
    make_request(manifest=golden_manifest, files=[
      ("files/a.txt", Json::string("68656c6c6f20776f726c6421")),
      ("files/b.bin", Json::string("")),
    ]),
  )
  assert_false(response_ok(response))
  assert_true(response_explain(response).has_prefix("verification FAILED"))
  @debug.assert_eq(report_codes(response), ["E2003"])
}

///|
test "invalid manifest json becomes e1001 finding" {
  // Malformed manifest is a verification finding, not a request error.
  let response = verify_evidence(make_request(manifest="{ not json"))
  assert_false(response_ok(response))
  @debug.assert_eq(report_codes(response), ["E1001"])
}

///|
test "null files and version chain are treated as absent" {
  let response = verify_evidence(
    "{\"manifest\": \{Json::string(empty_manifest).stringify()}, \"files\": null, \"version_chain\": null}",
  )
  assert_true(response_ok(response))
  assert_eq(report_codes(response).length(), 0)
}

// ---------------------------------------------------------------------------
// Version chain merging
// ---------------------------------------------------------------------------

///|
test "valid version chain keeps pack ok" {
  let response = verify_evidence(
    make_request(
      manifest=golden_manifest,
      files=[
        ("files/a.txt", Json::string(GOLDEN_A_HEX)),
        ("files/b.bin", Json::string("")),
      ],
      version_chain="[{\"id\": \"v1\", \"parent\": null}]",
    ),
  )
  assert_true(response_ok(response))
  assert_eq(report_codes(response).length(), 0)
}

///|
test "broken parent in chain fails with e4002" {
  let response = verify_evidence(
    make_request(
      manifest=golden_manifest,
      files=[
        ("files/a.txt", Json::string(GOLDEN_A_HEX)),
        ("files/b.bin", Json::string("")),
      ],
      version_chain="[{\"id\": \"v1\", \"parent\": null}, {\"id\": \"v2\", \"parent\": \"missing\"}]",
    ),
  )
  assert_false(response_ok(response))
  @debug.assert_eq(report_codes(response), ["E4002"])
}

///|
test "invalid chain json becomes e1001 finding at version_chain" {
  let response = verify_evidence(
    make_request(manifest=empty_manifest, version_chain="{ not json"),
  )
  assert_false(response_ok(response))
  @debug.assert_eq(report_codes(response), ["E1001"])
  assert_true(response_explain(response).contains("version_chain"))
}

// ---------------------------------------------------------------------------
// End-to-end: dynamically built pack (digest + merkle cross-check)
// ---------------------------------------------------------------------------

///|
let wb_hex_digits : FixedArray[Char] = [
  '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f',
]

///|
fn bytes_to_hex(data : Bytes) -> String {
  let builder = StringBuilder::new(size_hint=data.length() * 2)
  for byte in data {
    let value = byte.to_int()
    builder.write_char(wb_hex_digits[value >> 4])
    builder.write_char(wb_hex_digits[value & 0x0f])
  }
  builder.to_string()
}

///|
test "dynamically built single-file pack verifies end to end" {
  // Build a pack from scratch with the library's own digest and merkle
  // primitives, then push it through the JS adapter: proves the hex
  // decoding, manifest pipeline, and root computation agree.
  let content = @digest.string_to_utf8_bytes("api adapter")
  let digest_hex = @digest.sha256_hex(content)
  let leaf = "{\"digest\":\"sha256:\{digest_hex}\",\"path\":\"files/x.txt\",\"size\":11}"
  guard @merkle.compute_root([@digest.string_to_utf8_bytes(leaf)]) is Some(root) else {
    fail("expected a merkle root for one leaf")
  }
  let manifest = Json::object({
    "schema": Json::string("moon-evidence/v0"),
    "subject": Json::object({
      "id": Json::string("api-pack"),
      "type": Json::string("dataset"),
    }),
    "hash_algorithm": Json::string("sha256"),
    "files": Json::array([
      Json::object({
        "path": Json::string("files/x.txt"),
        "size": Json::number(11),
        "digest": Json::string("sha256:\{digest_hex}"),
      }),
    ]),
    "merkle_root": Json::string("sha256:\{bytes_to_hex(root)}"),
    "version": Json::object({ "id": Json::string("v1") }),
  }).stringify()
  let response = verify_evidence(
    make_request(manifest~, files=[
      ("files/x.txt", Json::string(bytes_to_hex(content))),
    ]),
  )
  assert_true(response_ok(response))
  assert_eq(report_codes(response).length(), 0)
}

// ---------------------------------------------------------------------------
// compute_merkle_tree visualization adapter
// ---------------------------------------------------------------------------

///|
fn tree_response_fields(response : String) -> Map[String, Json] raise {
  guard @json.parse(response) is Object(fields) else {
    fail("compute_merkle_tree response is not a JSON object: \{response}")
  }
  fields
}

///|
fn tree_request(manifest : String) -> String {
  make_request(manifest~)
}

///|
test "compute_merkle_tree golden pack reports three levels and matching root" {
  let response = compute_merkle_tree(tree_request(golden_manifest))
  let fields = tree_response_fields(response) catch {
    err => fail("response not JSON: \{err}")
  }
  guard fields.get("ok") is Some(True) else {
    fail("compute_merkle_tree golden: not ok: \{response}")
  }
  // Two files -> one promoted-leaf -> two levels, two leaves at level 0.
  guard fields.get("tree") is Some(Object(tree)) else {
    fail("response has no tree object: \{response}")
  }
  guard tree.get("leaf_count") is Some(Number(lc, ..)) && lc.to_int() == 2 else {
    fail("leaf_count should be 2: \{response}")
  }
  guard tree.get("height") is Some(Number(h, ..)) && h.to_int() == 2 else {
    fail("height should be 2: \{response}")
  }
  guard tree.get("levels") is Some(Array(levels)) && levels.length() == 2 else {
    fail("levels length should be 2: \{response}")
  }
  // Level 0: two leaf hashes.
  guard levels[0] is Array(leaves) && leaves.length() == 2 else {
    fail("level 0 should have 2 nodes: \{response}")
  }
  // Root comparison reports a match.
  guard tree.get("root") is Some(Object(root)) else {
    fail("root object missing: \{response}")
  }
  guard root.get("matches") is Some(True) else {
    fail("root.matches should be true for golden pack: \{response}")
  }
  guard root.get("recorded") is Some(String(recorded)) else {
    fail("root.recorded missing: \{response}")
  }
  // Same as the manifest's recorded merkle_root.
  assert_true(recorded.has_prefix("sha256:"))
}

///|
test "compute_merkle_tree empty files returns null tree" {
  let response = compute_merkle_tree(tree_request(empty_manifest))
  let fields = tree_response_fields(response) catch {
    err => fail("response not JSON: \{err}")
  }
  guard fields.get("ok") is Some(True) else {
    fail("empty manifest should still be ok: \{response}")
  }
  guard fields.get("tree") is Some(Object(tree)) else {
    fail("response has no tree object: \{response}")
  }
  guard tree.get("leaf_count") is Some(Number(lc, ..)) && lc.to_int() == 0 else {
    fail("empty manifest leaf_count should be 0: \{response}")
  }
  guard tree.get("root") is Some(Null) else {
    fail("empty manifest root should be null: \{response}")
  }
}

///|
test "compute_merkle_tree bad request rejects with ok=false" {
  let response = compute_merkle_tree("{ not json")
  let fields = tree_response_fields(response) catch {
    err => fail("response not JSON: \{err}")
  }
  guard fields.get("ok") is Some(False) else {
    fail("bad request should be ok=false: \{response}")
  }
  guard fields.get("error") is Some(String(_)) else {
    fail("bad request should carry an error field: \{response}")
  }
}

///|
test "compute_merkle_tree tampered manifest root mismatches recorded" {
  // Replace a.txt digest with the wrong digest: recorded root no longer matches.
  let tampered = "{\n  \"schema\": \"moon-evidence/v0\",\n  \"subject\": { \"id\": \"golden-pack\", \"type\": \"dataset\" },\n  \"hash_algorithm\": \"sha256\",\n  \"files\": [\n    {\n      \"path\": \"files/a.txt\",\n      \"size\": 12,\n      \"digest\": \"sha256:0000000000000000000000000000000000000000000000000000000000000000\"\n    },\n    {\n      \"path\": \"files/b.bin\",\n      \"size\": 0,\n      \"digest\": \"sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855\"\n    }\n  ],\n  \"merkle_root\": \"sha256:07a4f4bf0c83169b056f07acbf3483a5e418e58e09e942a3f06421f9cca316a5\",\n  \"version\": { \"id\": \"v1\" }\n}"
  let response = compute_merkle_tree(tree_request(tampered))
  let fields = tree_response_fields(response) catch {
    err => fail("response not JSON: \{err}")
  }
  guard fields.get("ok") is Some(True) else {
    fail("compute_merkle_tree does not fail: \{response}")
  }
  guard fields.get("tree") is Some(Object(tree)) else {
    fail("response has no tree: \{response}")
  }
  guard tree.get("root") is Some(Object(root)) else {
    fail("root missing: \{response}")
  }
  guard root.get("matches") is Some(False) else {
    fail("tampered digest should make root.matches=false: \{response}")
  }
}

///|
test "compute_merkle_tree paths array covers the tree height" {
  let response = compute_merkle_tree(tree_request(golden_manifest))
  let fields = tree_response_fields(response) catch {
    err => fail("response not JSON: \{err}")
  }
  // example_path is the spine for leaf 0 (2 levels -> 2 entries).
  guard fields.get("example_path") is Some(Array(path)) && path.length() == 2 else {
    fail("example_path should have 2 entries: \{response}")
  }
  guard path[0] is Object(first) &&
    first.get("level") is Some(Number(fl, ..)) &&
    fl.to_int() == 0 &&
    first.get("node_index") is Some(Number(fi, ..)) &&
    fi.to_int() == 0 else {
    fail("first spine entry should be level 0 index 0: \{response}")
  }
  guard path[1] is Object(last) &&
    last.get("level") is Some(Number(ll, ..)) &&
    ll.to_int() == 1 &&
    last.get("node_index") is Some(Number(li, ..)) &&
    li.to_int() == 0 else {
    fail("last spine entry should be level 1 index 0 (root): \{response}")
  }
}

// ---------------------------------------------------------------------------
// create_evidence_pack API tests (P0-3: was zero coverage)
// ---------------------------------------------------------------------------

///|
fn parse_json_obj(s : String) -> Map[String, Json] raise {
  guard @json.parse(s) is Object(m) else { fail("expected JSON object: \{s}") }
  m
}

///|
/// Builds a JSON object string from key-value pairs.
fn json_request(pairs : Array[(String, Json)]) -> String {
  let m : Map[String, Json] = {}
  for pair in pairs {
    m[pair.0] = pair.1
  }
  Json::object(m).stringify()
}

///|
/// Builds a JSON object of { path: hex_string } pairs.
fn json_files(pairs : Array[(String, String)]) -> Json {
  let m : Map[String, Json] = {}
  for pair in pairs {
    m[pair.0] = Json::string(pair.1)
  }
  Json::object(m)
}

///|
/// Builds the Merkle leaf payload (canonical file entry text) as hex.
/// Mirrors `canonical_file_entry_text` in api.mbt so verify_proof can
/// reconstruct the exact bytes the proof was generated over.
fn leaf_payload_hex(path : String, content : Bytes) -> String {
  let digest_hex = @digest.sha256_hex(content)
  let doc = Json::object({
    "path": Json::string(path),
    "size": Json::number(content.length().to_double()),
    "digest": Json::string("sha256:\{digest_hex}"),
  })
  let canonical = @canonjson.canonicalize(doc.stringify()) catch {
    _ => doc.stringify()
  }
  bytes_to_hex(@digest.string_to_utf8_bytes(canonical))
}

///|
test "create_evidence_pack round-trip: create then verify succeeds" {
  let content_hex = bytes_to_hex(@digest.string_to_utf8_bytes("hello world"))
  let request = json_request([
    ("files", json_files([("files/a.txt", content_hex)])),
    (
      "subject",
      Json::object({
        "id": Json::string("api-create-test"),
        "type": Json::string("dataset"),
      }),
    ),
    ("algorithm", Json::string("sha256")),
    ("version_id", Json::string("v1")),
  ])
  let resp = create_evidence_pack(request)
  let fields = parse_json_obj(resp)
  guard fields.get("ok") is Some(True) else {
    fail("create should succeed: \{resp}")
  }
  guard fields.get("manifest") is Some(String(manifest)) else {
    fail("response should contain manifest: \{resp}")
  }
  // Now verify the created manifest.
  let verify_req = json_request([
    ("manifest", Json::string(manifest)),
    ("files", json_files([("files/a.txt", content_hex)])),
  ])
  let vresp = verify_evidence(verify_req)
  assert_true(response_ok(vresp))
  assert_eq(report_codes(vresp).length(), 0)
}

///|
test "create_evidence_pack accepts kind as backward-compat alias for type" {
  let content_hex = bytes_to_hex(@digest.string_to_utf8_bytes("data"))
  let request = json_request([
    ("files", json_files([("files/a.txt", content_hex)])),
    (
      "subject",
      Json::object({
        "id": Json::string("kind-test"),
        "kind": Json::string("archive"),
      }),
    ),
    ("version_id", Json::string("v1")),
  ])
  let resp = create_evidence_pack(request)
  let fields = parse_json_obj(resp)
  guard fields.get("ok") is Some(True) else {
    fail("create with kind should succeed: \{resp}")
  }
}

///|
test "create_evidence_pack rejects missing files" {
  let request = json_request([
    (
      "subject",
      Json::object({ "id": Json::string("x"), "type": Json::string("y") }),
    ),
    ("version_id", Json::string("v1")),
  ])
  let resp = create_evidence_pack(request)
  let fields = parse_json_obj(resp)
  guard fields.get("ok") is Some(False) else {
    fail("should reject missing files: \{resp}")
  }
}

///|
test "create_evidence_pack supports sha512 algorithm" {
  let content_hex = bytes_to_hex(@digest.string_to_utf8_bytes("x"))
  let request = json_request([
    ("files", json_files([("files/a.txt", content_hex)])),
    (
      "subject",
      Json::object({ "id": Json::string("x"), "type": Json::string("y") }),
    ),
    ("algorithm", Json::string("sha512")),
    ("version_id", Json::string("v1")),
  ])
  let resp = create_evidence_pack(request)
  let fields = parse_json_obj(resp)
  guard fields.get("ok") is Some(True) else {
    fail("sha512 should be supported: \{resp}")
  }
  // Verify the created sha512 manifest.
  guard fields.get("manifest") is Some(String(manifest)) else {
    fail("should have manifest: \{resp}")
  }
  let verify_req = json_request([
    ("manifest", Json::string(manifest)),
    ("files", json_files([("files/a.txt", content_hex)])),
  ])
  let vresp = verify_evidence(verify_req)
  assert_true(response_ok(vresp))
}

// ---------------------------------------------------------------------------
// generate_proof + verify_proof API tests (P0-3: was zero coverage)
// ---------------------------------------------------------------------------

///|
test "generate_proof then verify_proof round-trip succeeds" {
  // Create a pack first.
  let content_hex = bytes_to_hex(@digest.string_to_utf8_bytes("leaf0"))
  let content_b_hex = bytes_to_hex(@digest.string_to_utf8_bytes("leaf1"))
  let create_req = json_request([
    (
      "files",
      json_files([("files/a.txt", content_hex), ("files/b.txt", content_b_hex)]),
    ),
    (
      "subject",
      Json::object({
        "id": Json::string("proof-test"),
        "type": Json::string("dataset"),
      }),
    ),
    ("version_id", Json::string("v1")),
  ])
  let create_resp = create_evidence_pack(create_req)
  let create_fields = parse_json_obj(create_resp)
  guard create_fields.get("manifest") is Some(String(manifest)) else {
    fail("create failed: \{create_resp}")
  }
  // Generate proof for index 0.
  let gen_req = json_request([
    ("manifest", Json::string(manifest)),
    (
      "files",
      json_files([("files/a.txt", content_hex), ("files/b.txt", content_b_hex)]),
    ),
    ("index", Json::number(0.0)),
  ])
  let gen_resp = generate_proof(gen_req)
  let gen_fields = parse_json_obj(gen_resp)
  guard gen_fields.get("ok") is Some(True) else {
    fail("generate_proof should succeed: \{gen_resp}")
  }
  guard gen_fields.get("leaf_hash") is Some(String(_leaf_hash)) else {
    fail("should have leaf_hash: \{gen_resp}")
  }
  guard gen_fields.get("root") is Some(String(root)) else {
    fail("should have root: \{gen_resp}")
  }
  guard gen_fields.get("proof") is Some(Array(proof)) else {
    fail("should have proof: \{gen_resp}")
  }
  // Verify the proof: leaf must be the canonical file entry payload
  // (same bytes the proof was generated over), not the raw file content.
  let leaf_hex = leaf_payload_hex(
    "files/a.txt",
    @digest.string_to_utf8_bytes("leaf0"),
  )
  let verify_req = json_request([
    ("leaf", Json::string(leaf_hex)),
    ("proof", Json::array(proof)),
    ("root", Json::string(root)),
  ])
  let vresp = verify_proof(verify_req)
  let vfields = parse_json_obj(vresp)
  guard vfields.get("ok") is Some(True) else {
    fail("verify_proof should succeed: \{vresp}")
  }
  guard vfields.get("valid") is Some(True) else {
    fail("proof should be valid: \{vresp}")
  }
}

///|
test "generate_proof rejects out-of-range index" {
  let content_hex = bytes_to_hex(@digest.string_to_utf8_bytes("x"))
  let create_req = json_request([
    ("files", json_files([("files/a.txt", content_hex)])),
    (
      "subject",
      Json::object({ "id": Json::string("x"), "type": Json::string("y") }),
    ),
    ("version_id", Json::string("v1")),
  ])
  let manifest = match
    parse_json_obj(create_evidence_pack(create_req)).get("manifest") {
    Some(String(m)) => m
    _ => fail("create failed")
  }
  let gen_req = json_request([
    ("manifest", Json::string(manifest)),
    ("files", json_files([("files/a.txt", content_hex)])),
    ("index", Json::number(99.0)),
  ])
  let resp = generate_proof(gen_req)
  let fields = parse_json_obj(resp)
  guard fields.get("ok") is Some(False) else {
    fail("should reject bad index: \{resp}")
  }
}

///|
test "verify_proof rejects tampered proof" {
  let content_hex = bytes_to_hex(@digest.string_to_utf8_bytes("leaf0"))
  let content_b_hex = bytes_to_hex(@digest.string_to_utf8_bytes("leaf1"))
  let create_req = json_request([
    (
      "files",
      json_files([("files/a.txt", content_hex), ("files/b.txt", content_b_hex)]),
    ),
    (
      "subject",
      Json::object({
        "id": Json::string("tamper-proof"),
        "type": Json::string("dataset"),
      }),
    ),
    ("version_id", Json::string("v1")),
  ])
  let manifest = match
    parse_json_obj(create_evidence_pack(create_req)).get("manifest") {
    Some(String(m)) => m
    _ => fail("create failed")
  }
  let gen_req = json_request([
    ("manifest", Json::string(manifest)),
    (
      "files",
      json_files([("files/a.txt", content_hex), ("files/b.txt", content_b_hex)]),
    ),
    ("index", Json::number(0.0)),
  ])
  let gen_resp = generate_proof(gen_req)
  let gen_fields = parse_json_obj(gen_resp)
  guard gen_fields.get("root") is Some(String(root)) else {
    fail("should have root: \{gen_resp}")
  }
  guard gen_fields.get("proof") is Some(Array(proof)) else {
    fail("should have proof: \{gen_resp}")
  }
  // Tamper: use the correct path but wrong content (different digest).
  let tampered_leaf = leaf_payload_hex(
    "files/a.txt",
    @digest.string_to_utf8_bytes("TAMPERED"),
  )
  let verify_req = json_request([
    ("leaf", Json::string(tampered_leaf)),
    ("proof", Json::array(proof)),
    ("root", Json::string(root)),
  ])
  let vresp = verify_proof(verify_req)
  let vfields = parse_json_obj(vresp)
  guard vfields.get("valid") is Some(False) else {
    fail("tampered leaf should fail: \{vresp}")
  }
}

// ---------------------------------------------------------------------------
// audit_append + audit_verify API tests (P0-2/P0-3: was zero coverage)
// ---------------------------------------------------------------------------

///|
test "audit_append then audit_verify multi-entry round-trip" {
  // Start with empty log, append two entries.
  let req1 = json_request([
    ("log", Json::string("[]")),
    ("timestamp", Json::string("2026-07-05T10:00:00Z")),
    ("actor", Json::string("alice")),
    ("action", Json::string("created")),
    ("subject_id", Json::string("dataset-v1")),
  ])
  let resp1 = audit_append(req1)
  let f1 = parse_json_obj(resp1)
  guard f1.get("ok") is Some(True) else {
    fail("first append should succeed: \{resp1}")
  }
  guard f1.get("log") is Some(String(log1)) else {
    fail("should return log: \{resp1}")
  }
  // Append second entry using the returned log.
  let req2 = json_request([
    ("log", Json::string(log1)),
    ("timestamp", Json::string("2026-07-05T11:00:00Z")),
    ("actor", Json::string("bob")),
    ("action", Json::string("verified")),
    ("subject_id", Json::string("dataset-v1")),
  ])
  let resp2 = audit_append(req2)
  let f2 = parse_json_obj(resp2)
  guard f2.get("ok") is Some(True) else {
    fail("second append should succeed: \{resp2}")
  }
  guard f2.get("log") is Some(String(log2)) else {
    fail("should return log: \{resp2}")
  }
  // Verify the multi-entry log.
  let verify_req = json_request([("log", Json::string(log2))])
  let vresp = audit_verify(verify_req)
  let vf = parse_json_obj(vresp)
  guard vf.get("ok") is Some(True) else {
    fail("audit_verify should succeed: \{vresp}")
  }
  guard vf.get("chain_valid") is Some(True) else {
    fail("chain should be valid: \{vresp}")
  }
  guard vf.get("length") is Some(Number(n, ..)) else {
    fail("should have length: \{vresp}")
  }
  assert_eq(n.to_int(), 2)
}

///|
test "audit_verify detects tampered log" {
  // Build a valid log.
  let req1 = json_request([
    ("log", Json::string("[]")),
    ("timestamp", Json::string("2026-07-05T10:00:00Z")),
    ("actor", Json::string("alice")),
    ("action", Json::string("created")),
    ("subject_id", Json::string("ds1")),
  ])
  let log1 = match parse_json_obj(audit_append(req1)).get("log") {
    Some(String(l)) => l
    _ => fail("append failed")
  }
  // Tamper: change actor in the log JSON.
  let tampered = log1.replace(old="alice", new="eve")
  let verify_req = json_request([("log", Json::string(tampered))])
  let vresp = audit_verify(verify_req)
  let vf = parse_json_obj(vresp)
  guard vf.get("chain_valid") is Some(False) else {
    fail("tampered chain should be invalid: \{vresp}")
  }
}

// ---------------------------------------------------------------------------
// ed25519_keypair + sign + verify API tests (P0-3: was zero coverage)
// ---------------------------------------------------------------------------

///|
fn demo_seed_hex() -> String {
  bytes_to_hex(
    Bytes::from_array([
      1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21,
      22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32,
    ]),
  )
}

///|
test "ed25519_keypair sign verify round-trip succeeds" {
  // Generate keypair with explicit seed.
  let seed_hex = demo_seed_hex()
  let kp_req = json_request([("seed", Json::string(seed_hex))])
  let kp_resp = ed25519_keypair(kp_req)
  let kp = parse_json_obj(kp_resp)
  guard kp.get("ok") is Some(True) else {
    fail("keypair should succeed: \{kp_resp}")
  }
  guard kp.get("public_key") is Some(String(pk_hex)) else {
    fail("should have public_key: \{kp_resp}")
  }
  guard kp.get("secret_key") is Some(String(sk_hex)) else {
    fail("should have secret_key: \{kp_resp}")
  }
  // Sign a message.
  let msg_hex = bytes_to_hex(@digest.string_to_utf8_bytes("test message"))
  let sign_req = json_request([
    ("secret_key", Json::string(sk_hex)),
    ("message", Json::string(msg_hex)),
  ])
  let sign_resp = ed25519_sign(sign_req)
  let sf = parse_json_obj(sign_resp)
  guard sf.get("ok") is Some(True) else {
    fail("sign should succeed: \{sign_resp}")
  }
  guard sf.get("signature") is Some(String(sig_hex)) else {
    fail("should have signature: \{sign_resp}")
  }
  // Verify the signature.
  let verify_req = json_request([
    ("public_key", Json::string(pk_hex)),
    ("message", Json::string(msg_hex)),
    ("signature", Json::string(sig_hex)),
  ])
  let vresp = ed25519_verify(verify_req)
  let vf = parse_json_obj(vresp)
  guard vf.get("ok") is Some(True) else {
    fail("verify should succeed: \{vresp}")
  }
  guard vf.get("valid") is Some(True) else {
    fail("signature should be valid: \{vresp}")
  }
}

///|
test "ed25519_verify rejects wrong message" {
  let seed_hex = demo_seed_hex()
  let kp = parse_json_obj(
    ed25519_keypair(json_request([("seed", Json::string(seed_hex))])),
  )
  guard kp.get("public_key") is Some(String(pk_hex)) else { fail("no pk") }
  guard kp.get("secret_key") is Some(String(sk_hex)) else { fail("no sk") }
  let msg_hex = bytes_to_hex(@digest.string_to_utf8_bytes("original"))
  let sign_resp = ed25519_sign(
    json_request([
      ("secret_key", Json::string(sk_hex)),
      ("message", Json::string(msg_hex)),
    ]),
  )
  let sig_hex = match parse_json_obj(sign_resp).get("signature") {
    Some(String(s)) => s
    _ => fail("no sig")
  }
  // Verify with different message.
  let wrong_msg = bytes_to_hex(@digest.string_to_utf8_bytes("tampered"))
  let vresp = ed25519_verify(
    json_request([
      ("public_key", Json::string(pk_hex)),
      ("message", Json::string(wrong_msg)),
      ("signature", Json::string(sig_hex)),
    ]),
  )
  let vf = parse_json_obj(vresp)
  guard vf.get("valid") is Some(False) else {
    fail("wrong message should fail: \{vresp}")
  }
}

///|
test "ed25519_keypair warns when using demo seed" {
  let resp = ed25519_keypair("{}")
  let fields = parse_json_obj(resp)
  guard fields.get("ok") is Some(True) else { fail("should succeed: \{resp}") }
  // The warning field must be present when no seed is provided.
  guard fields.get("warning") is Some(String(_)) else {
    fail("should warn about demo seed: \{resp}")
  }
}

// ---------------------------------------------------------------------------
// audit_sign + audit_verify signature verification API tests
// ---------------------------------------------------------------------------

///|
/// Builds a one-entry audit log JSON string via audit_append.
fn make_one_entry_log(subject_id : String) -> String raise {
  let req = json_request([
    ("log", Json::string("[]")),
    ("timestamp", Json::string("2026-07-05T10:00:00Z")),
    ("actor", Json::string("alice")),
    ("action", Json::string("created")),
    ("subject_id", Json::string(subject_id)),
  ])
  match parse_json_obj(audit_append(req)).get("log") {
    Some(String(l)) => l
    _ => fail("audit_append should return a log")
  }
}

///|
test "audit_sign: sign last entry" {
  // Generate a keypair with a fixed seed.
  let seed_hex = demo_seed_hex()
  let kp = parse_json_obj(
    ed25519_keypair(json_request([("seed", Json::string(seed_hex))])),
  )
  guard kp.get("secret_key") is Some(String(sk_hex)) else {
    fail(
      "keypair should have secret_key: \{ed25519_keypair(json_request([("seed", Json::string(seed_hex))]))}",
    )
  }
  // Create a log with one entry.
  let log_json = make_one_entry_log("ds-sign") catch {
    err => fail("make_one_entry_log failed: \{err}")
  }
  // Sign the last entry.
  let sign_resp = audit_sign(
    json_request([
      ("log", Json::string(log_json)),
      ("secret_key", Json::string(sk_hex)),
    ]),
  )
  let sf = parse_json_obj(sign_resp)
  guard sf.get("ok") is Some(True) else {
    fail("audit_sign should succeed: \{sign_resp}")
  }
  guard sf.get("log") is Some(String(signed_log)) else {
    fail("audit_sign should return a log: \{sign_resp}")
  }
  // The returned log should contain a "signature" field on the last entry.
  assert_true(signed_log.contains("signature"))
}

///|
test "audit_verify: verify_signatures true with valid signature" {
  // Generate keypair, create log, sign it.
  let seed_hex = demo_seed_hex()
  let kp = parse_json_obj(
    ed25519_keypair(json_request([("seed", Json::string(seed_hex))])),
  )
  guard kp.get("public_key") is Some(String(pk_hex)) else {
    fail("no public_key")
  }
  guard kp.get("secret_key") is Some(String(sk_hex)) else {
    fail("no secret_key")
  }
  let log_json = make_one_entry_log("ds-verify-valid") catch {
    err => fail("make_one_entry_log failed: \{err}")
  }
  let sign_resp = audit_sign(
    json_request([
      ("log", Json::string(log_json)),
      ("secret_key", Json::string(sk_hex)),
    ]),
  )
  let signed_log = match parse_json_obj(sign_resp).get("log") {
    Some(String(l)) => l
    _ => fail("audit_sign should return a log: \{sign_resp}")
  }
  // Verify with verify_signatures=true and the public_key.
  let verify_req = json_request([
    ("log", Json::string(signed_log)),
    ("verify_signatures", Json::boolean(true)),
    ("public_key", Json::string(pk_hex)),
  ])
  let vresp = audit_verify(verify_req)
  let vf = parse_json_obj(vresp)
  guard vf.get("chain_valid") is Some(True) else {
    fail("chain should be valid: \{vresp}")
  }
  guard vf.get("signatures_valid") is Some(True) else {
    fail("signatures should be valid: \{vresp}")
  }
}

///|
test "audit_verify: verify_signatures true with tampered signature" {
  // Generate keypair, create log, sign it.
  let seed_hex = demo_seed_hex()
  let kp = parse_json_obj(
    ed25519_keypair(json_request([("seed", Json::string(seed_hex))])),
  )
  guard kp.get("public_key") is Some(String(pk_hex)) else {
    fail("no public_key")
  }
  guard kp.get("secret_key") is Some(String(sk_hex)) else {
    fail("no secret_key")
  }
  let log_json = make_one_entry_log("ds-verify-tamper") catch {
    err => fail("make_one_entry_log failed: \{err}")
  }
  let sign_resp = audit_sign(
    json_request([
      ("log", Json::string(log_json)),
      ("secret_key", Json::string(sk_hex)),
    ]),
  )
  let signed_log = match parse_json_obj(sign_resp).get("log") {
    Some(String(l)) => l
    _ => fail("audit_sign should return a log: \{sign_resp}")
  }
  // Extract the signature from the last entry, then tamper with it.
  guard @json.parse(signed_log) is Array(entries) else {
    fail("signed log should be a JSON array: \{signed_log}")
  }
  guard entries[entries.length() - 1] is Object(last_entry) else {
    fail("last entry should be a JSON object")
  }
  guard last_entry.get("signature") is Some(String(sig)) else {
    fail("last entry should have a signature")
  }
  // Inject non-hex characters at the front (preserving even length so the
  // decoder reaches per-character validation rather than the odd-length
  // early return). Mirrors the tamper approach in audit_log_wbtest.
  let tampered_sig = "zz" + sig
  let tampered_log = signed_log.replace(old=sig, new=tampered_sig)
  // Verify with verify_signatures=true.
  let verify_req = json_request([
    ("log", Json::string(tampered_log)),
    ("verify_signatures", Json::boolean(true)),
    ("public_key", Json::string(pk_hex)),
  ])
  let vresp = audit_verify(verify_req)
  let vf = parse_json_obj(vresp)
  guard vf.get("signatures_valid") is Some(False) else {
    fail("tampered signature should be invalid: \{vresp}")
  }
}

///|
test "audit_verify: verify_signatures false (default)" {
  // Create a log without any signatures.
  let log_json = make_one_entry_log("ds-default") catch {
    err => fail("make_one_entry_log failed: \{err}")
  }
  // Call audit_verify without the verify_signatures field.
  let verify_req = json_request([("log", Json::string(log_json))])
  let vresp = audit_verify(verify_req)
  let vf = parse_json_obj(vresp)
  guard vf.get("ok") is Some(True) else {
    fail("audit_verify should succeed: \{vresp}")
  }
  // Default when not verifying: signatures_valid should be true.
  guard vf.get("signatures_valid") is Some(True) else {
    fail("signatures_valid should default to true: \{vresp}")
  }
}
