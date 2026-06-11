// Version chain linearity verification (E4xxx). The model layer guarantees
// shape (ids non-empty, parents absent/null/non-empty); this file owns the
// graph semantics: exactly one root, every parent resolvable, no cycles, no
// forks, every node reachable.

///|
/// Outcome of a version chain verification. `ordered_ids` is the
/// root-to-head order; on failure it holds the prefix that could be walked
/// before the problem (useful context for explain output).
pub(all) struct ChainReport {
  ok : Bool
  ordered_ids : Array[String]
  findings : Array[@diag.Finding]
} derive(Eq, @debug.Debug)

///|
fn chain_finding(
  code : String,
  path : String,
  message : String,
) -> @diag.Finding {
  { code, severity: Error, path, message }
}

///|
/// Verifies that `nodes` forms one linear chain. Frozen codes:
/// E4001 empty chain, E4002 broken parent reference, E4003 cycle (or no
/// root / unreachable tail), E4004 fork (duplicate id, multiple roots, or a
/// parent with two children).
pub fn verify_version_chain(nodes : Array[@model.VersionNode]) -> ChainReport {
  let findings : Array[@diag.Finding] = []
  let ordered_ids : Array[String] = []
  if nodes.length() == 0 {
    findings.push(
      chain_finding("E4001", "version_chain", "version chain is empty"),
    )
    return { ok: false, ordered_ids, findings }
  }

  // Duplicate ids make every reference ambiguous: report and stop early.
  let ids : Map[String, Bool] = {}
  for node in nodes {
    if ids.get(node.id) is Some(_) {
      findings.push(
        chain_finding(
          "E4004",
          "version_chain",
          "duplicate version id \"\{node.id}\"",
        ),
      )
    }
    ids[node.id] = true
  }
  if findings.length() > 0 {
    return { ok: false, ordered_ids, findings }
  }

  // Broken parent references (E4002).
  for node in nodes {
    if node.parent is Some(parent_id) && ids.get(parent_id) is None {
      findings.push(
        chain_finding(
          "E4002",
          "version_chain",
          "version \"\{node.id}\" references unknown parent \"\{parent_id}\"",
        ),
      )
    }
  }

  // Fork detection: a parent with more than one child (E4004).
  let child_of : Map[String, Array[String]] = {}
  let roots : Array[String] = []
  for node in nodes {
    match node.parent {
      None => roots.push(node.id)
      Some(parent_id) =>
        match child_of.get(parent_id) {
          Some(children) => children.push(node.id)
          None => child_of[parent_id] = [node.id]
        }
    }
  }
  for parent_id, children in child_of {
    if children.length() > 1 {
      findings.push(
        chain_finding(
          "E4004",
          "version_chain",
          "version \"\{parent_id}\" has \{children.length()} children (chain must be linear)",
        ),
      )
    }
  }

  // Root cardinality: zero roots means every node has a parent - a cycle
  // (E4003); several roots mean parallel heads (E4004).
  if roots.length() == 0 {
    findings.push(
      chain_finding(
        "E4003", "version_chain", "no root version (every node has a parent), chain contains a cycle",
      ),
    )
  } else if roots.length() > 1 {
    let mut listed = roots[0]
    for index in 1..<roots.length() {
      listed = listed + "\", \"" + roots[index]
    }
    findings.push(
      chain_finding(
        "E4004",
        "version_chain",
        "multiple root versions (\"\{listed}\"), chain must be linear",
      ),
    )
  }
  if findings.length() > 0 {
    return { ok: false, ordered_ids, findings }
  }

  // Single root, all parents resolve, no forks: walk to the head.
  let mut current = roots[0]
  ordered_ids.push(current)
  while child_of.get(current) is Some(children) {
    current = children[0]
    ordered_ids.push(current)
  }
  if ordered_ids.length() < nodes.length() {
    // Unreachable remainder despite a clean walk: a detached cycle.
    findings.push(
      chain_finding(
        "E4003",
        "version_chain",
        "\{nodes.length() - ordered_ids.length()} version(s) unreachable from the root, chain contains a cycle",
      ),
    )
    return { ok: false, ordered_ids, findings }
  }
  { ok: true, ordered_ids, findings }
}
