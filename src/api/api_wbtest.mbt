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
  make_request(manifest=manifest)
}

///|
test "compute_merkle_tree golden pack reports three levels and matching root" {
  let response = compute_merkle_tree(
    tree_request(golden_manifest),
  )
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
  guard tree.get("leaf_count") is Some(Number(lc, ..)) &&
        lc.to_int() == 2 else {
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
        first.get("level") is Some(Number(fl, ..)) && fl.to_int() == 0 &&
        first.get("node_index") is Some(Number(fi, ..)) && fi.to_int() == 0 else {
    fail("first spine entry should be level 0 index 0: \{response}")
  }
  guard path[1] is Object(last) &&
        last.get("level") is Some(Number(ll, ..)) && ll.to_int() == 1 &&
        last.get("node_index") is Some(Number(li, ..)) && li.to_int() == 0 else {
    fail("last spine entry should be level 1 index 0 (root): \{response}")
  }
}
