// Version chain parsing tests. Shape rules only: linearity semantics
// (E4xxx) belong to the verify package. Samples mirror
// tests/fixtures/version-chain/.

///|
fn chain_error(input : String) -> ModelError raise {
  try parse_version_chain(input) catch {
    error => error
  } noraise {
    _ => fail("expected ModelError, chain parsed successfully")
  }
}

///|
test "valid chain parses oldest first" {
  let input =
    #|[
    #|  { "id": "v1", "parent": null },
    #|  { "id": "v2", "parent": "v1" },
    #|  { "id": "v3", "parent": "v2" }
    #|]
  let nodes = parse_version_chain(input) catch {
    error => fail("unexpected: \{error}")
  }
  assert_eq(nodes.length(), 3)
  @debug.assert_eq(nodes[0], VersionNode::{ id: "v1", parent: None })
  @debug.assert_eq(nodes[2], VersionNode::{ id: "v3", parent: Some("v2") })
}

///|
test "empty chain array is accepted at model layer" {
  // E4001 (empty chain) is a verification rule, not a parse rule.
  let nodes = parse_version_chain("[]") catch {
    error => fail("unexpected: \{error}")
  }
  assert_eq(nodes.length(), 0)
}

///|
test "parent absent is none" {
  let nodes = parse_version_chain("[{ \"id\": \"v1\" }]") catch {
    error => fail("unexpected: \{error}")
  }
  assert_true(nodes[0].parent is None)
}

///|
test "invalid chain json reports e1001" {
  assert_eq(chain_error("[ {").error_code(), "E1001")
}

///|
test "non array chain reports e1002 invalid field" {
  let error = chain_error("{ \"chain\": [] }")
  assert_eq(error.error_code(), "E1002")
  inspect(error, content="[E1002] version_chain: expected an array")
}

///|
test "missing node id reports e1002 with index" {
  let error = chain_error("[{ \"parent\": null }]")
  assert_eq(error.error_code(), "E1002")
  inspect(
    error,
    content="[E1002] version_chain[0].id: required field missing or empty",
  )
}

///|
test "empty parent string reports e1002 invalid field" {
  let error = chain_error("[{ \"id\": \"v1\", \"parent\": \"\" }]")
  assert_eq(error.error_code(), "E1002")
  inspect(
    error,
    content="[E1002] version_chain[0].parent: must not be empty when present",
  )
}

///|
test "non object node reports e1002 with index" {
  let error = chain_error("[42]")
  assert_eq(error.error_code(), "E1002")
  inspect(error, content="[E1002] version_chain[0]: expected an object")
}
