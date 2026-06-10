// Version chain linearity tests covering every E4xxx code.

fn node(id : String, parent : String?) -> @model.VersionNode {
  { id, parent }
}

fn chain_codes(report : ChainReport) -> Array[String] {
  report.findings.map(fn(item) { item.code })
}

test "linear chain verifies and orders root to head" {
  let report = verify_version_chain([
    node("v2", Some("v1")),
    node("v1", None),
    node("v3", Some("v2")),
  ])
  assert_true(report.ok)
  assert_eq(report.findings.length(), 0)
  @debug.assert_eq(report.ordered_ids, ["v1", "v2", "v3"])
}

test "single version chain is linear" {
  let report = verify_version_chain([node("v1", None)])
  assert_true(report.ok)
  @debug.assert_eq(report.ordered_ids, ["v1"])
}

test "empty chain reports e4001" {
  let report = verify_version_chain([])
  assert_false(report.ok)
  @debug.assert_eq(chain_codes(report), ["E4001"])
}

test "broken parent reference reports e4002" {
  let report = verify_version_chain([
    node("v1", None),
    node("v2", Some("ghost")),
  ])
  assert_false(report.ok)
  assert_true(chain_codes(report).contains("E4002"))
}

test "full cycle reports e4003" {
  // Every node has a parent: no root can exist.
  let report = verify_version_chain([
    node("v1", Some("v2")),
    node("v2", Some("v1")),
  ])
  assert_false(report.ok)
  @debug.assert_eq(chain_codes(report), ["E4003"])
}

test "detached cycle reports e4003 with walked prefix" {
  // Clean root v1, but v2/v3 reference each other and never join the walk.
  let report = verify_version_chain([
    node("v1", None),
    node("v2", Some("v3")),
    node("v3", Some("v2")),
  ])
  assert_false(report.ok)
  @debug.assert_eq(chain_codes(report), ["E4003"])
  @debug.assert_eq(report.ordered_ids, ["v1"])
}

test "duplicate id reports e4004" {
  let report = verify_version_chain([
    node("v1", None),
    node("v1", Some("v1")),
  ])
  assert_false(report.ok)
  @debug.assert_eq(chain_codes(report), ["E4004"])
}

test "multiple roots report e4004" {
  let report = verify_version_chain([node("a", None), node("b", None)])
  assert_false(report.ok)
  @debug.assert_eq(chain_codes(report), ["E4004"])
  assert_true(report.findings[0].message.contains("multiple root versions"))
}

test "fork reports e4004" {
  let report = verify_version_chain([
    node("v1", None),
    node("v2a", Some("v1")),
    node("v2b", Some("v1")),
  ])
  assert_false(report.ok)
  @debug.assert_eq(chain_codes(report), ["E4004"])
  assert_true(report.findings[0].message.contains("2 children"))
}
