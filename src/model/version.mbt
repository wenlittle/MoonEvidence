// Version chain file model (`versions/version_chain.json`). The file is a
// bare JSON array of nodes ordered oldest-first by convention:
//
//   [ { "id": "v1", "parent": null }, { "id": "v2", "parent": "v1" } ]
//
// Parsing is shape-only: an empty array is accepted here, and linearity
// rules (E4001 empty chain, E4002 broken parent, E4003 cycle, E4004 fork)
// are verification semantics owned by the verify package.

///|
/// One node in the version chain. The root node has `parent: None`.
pub(all) struct VersionNode {
  id : String
  parent : String?
} derive(Eq, @debug.Debug)

///|
/// Parses `version_chain.json`. Each node needs a non-empty `id`; `parent`
/// is absent, `null`, or a non-empty string.
pub fn parse_version_chain(
  input : String,
) -> Array[VersionNode] raise ModelError {
  let document = @json.parse(input) catch {
    error => raise ModelError::ParseFailed(error.to_json().stringify())
  }
  guard document is Array(items) else {
    raise ModelError::InvalidField("version_chain", "expected an array")
  }
  let nodes : Array[VersionNode] = []
  for index in 0..<items.length() {
    let node_path = "version_chain[\{index}]"
    let fields = expect_object(items[index], node_path)
    nodes.push(VersionNode::{
      id: expect_string(fields, "id", "\{node_path}.id"),
      parent: expect_optional_string(fields, "parent", "\{node_path}.parent"),
    })
  }
  nodes
}
