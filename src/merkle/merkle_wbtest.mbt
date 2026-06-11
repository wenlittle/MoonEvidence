// Shape coverage and adversarial tests for the Merkle implementation.
// Golden cross-checks against the independent Node.js reference live in
// merkle_golden_wbtest.mbt.

///|
/// Deterministic distinct leaf payloads: "leaf-0", "leaf-1", ...
fn make_leaves(count : Int) -> Array[Bytes] {
  let leaves : Array[Bytes] = []
  for index in 0..<count {
    leaves.push(@digest.string_to_utf8_bytes("leaf-\{index}"))
  }
  leaves
}

///|
fn must_root(leaves : Array[Bytes]) -> Bytes raise {
  match compute_root(leaves) {
    Some(root) => root
    None => fail("expected a root for \{leaves.length()} leaves")
  }
}

///|
fn must_proof(leaves : Array[Bytes], index : Int) -> Array[ProofStep] raise {
  match compute_proof(leaves, index) {
    Some(proof) => proof
    None => fail("expected a proof for index \{index}")
  }
}

// ---------------------------------------------------------------------------
// Tree shapes
// ---------------------------------------------------------------------------

///|
test "empty tree has no root" {
  assert_true(compute_root([]) is None)
}

///|
test "single leaf root is the leaf hash with no node hash applied" {
  let leaves = make_leaves(1)
  assert_eq(must_root(leaves), leaf_hash(leaves[0]))
}

///|
test "two leaf root is the node hash of both leaf hashes" {
  let leaves = make_leaves(2)
  assert_eq(
    must_root(leaves),
    node_hash(leaf_hash(leaves[0]), leaf_hash(leaves[1])),
  )
}

///|
test "three leaf root promotes the odd leaf without self pairing" {
  // Level 0: h0 h1 h2 -> level 1: node(h0,h1), h2 (promoted) -> root.
  let leaves = make_leaves(3)
  let expected = node_hash(
    node_hash(leaf_hash(leaves[0]), leaf_hash(leaves[1])),
    leaf_hash(leaves[2]),
  )
  assert_eq(must_root(leaves), expected)
  // Self-pairing (the CVE-2012-2459 mistake) would have produced this
  // different value instead; pin that they disagree.
  let self_paired = node_hash(
    node_hash(leaf_hash(leaves[0]), leaf_hash(leaves[1])),
    node_hash(leaf_hash(leaves[2]), leaf_hash(leaves[2])),
  )
  assert_true(must_root(leaves) != self_paired)
}

///|
test "five leaf root promotes across two levels" {
  // 5 leaves: the lone 5th leaf is promoted twice before joining the root.
  let leaves = make_leaves(5)
  let n01 = node_hash(leaf_hash(leaves[0]), leaf_hash(leaves[1]))
  let n23 = node_hash(leaf_hash(leaves[2]), leaf_hash(leaves[3]))
  let expected = node_hash(node_hash(n01, n23), leaf_hash(leaves[4]))
  assert_eq(must_root(leaves), expected)
}

///|
test "proof round trip verifies for every index in every shape" {
  for count in [1, 2, 3, 4, 5, 8] {
    let leaves = make_leaves(count)
    let root = must_root(leaves)
    for index in 0..<count {
      let proof = must_proof(leaves, index)
      assert_true(verify_inclusion(leaves[index], proof, root))
    }
  }
}

///|
test "single leaf proof is empty" {
  let leaves = make_leaves(1)
  assert_eq(must_proof(leaves, 0).length(), 0)
}

///|
test "proof for out of range index is none" {
  assert_true(compute_proof(make_leaves(3), 3) is None)
  assert_true(compute_proof(make_leaves(3), -1) is None)
  assert_true(compute_proof([], 0) is None)
}

// ---------------------------------------------------------------------------
// Adversarial cases
// ---------------------------------------------------------------------------

///|
test "forged sibling fails verification" {
  let leaves = make_leaves(4)
  let root = must_root(leaves)
  let proof = must_proof(leaves, 1)
  let forged : Array[ProofStep] = []
  for step in proof {
    forged.push({ sibling: leaf_hash(b"forged"), side: step.side })
  }
  assert_false(verify_inclusion(leaves[1], forged, root))
}

///|
test "flipped side fails verification" {
  let leaves = make_leaves(4)
  let root = must_root(leaves)
  let proof = must_proof(leaves, 2)
  let flipped : Array[ProofStep] = []
  for step in proof {
    let side = match step.side {
      Left => Side::Right
      Right => Side::Left
    }
    flipped.push({ sibling: step.sibling, side })
  }
  assert_false(verify_inclusion(leaves[2], flipped, root))
}

///|
test "truncated proof fails verification" {
  let leaves = make_leaves(8)
  let root = must_root(leaves)
  let proof = must_proof(leaves, 0)
  let truncated : Array[ProofStep] = []
  for index in 0..<(proof.length() - 1) {
    truncated.push(proof[index])
  }
  assert_false(verify_inclusion(leaves[0], truncated, root))
}

///|
test "extended proof fails verification" {
  let leaves = make_leaves(4)
  let root = must_root(leaves)
  let proof = must_proof(leaves, 0)
  proof.push({ sibling: leaf_hash(b"extra"), side: Right })
  assert_false(verify_inclusion(leaves[0], proof, root))
}

///|
test "wrong leaf fails verification" {
  let leaves = make_leaves(4)
  let root = must_root(leaves)
  let proof = must_proof(leaves, 0)
  assert_false(verify_inclusion(leaves[1], proof, root))
}

///|
test "domain separation keeps leaf and node hashes apart" {
  // Without the 0x00/0x01 prefixes, hashing the concatenation of two leaf
  // hashes as a LEAF would collide with the interior NODE above them - the
  // classic second-preimage attack. Pin that the domains never meet.
  let left = leaf_hash(b"a")
  let right = leaf_hash(b"b")
  let concatenated : Array[Byte] = []
  for byte in left {
    concatenated.push(byte)
  }
  for byte in right {
    concatenated.push(byte)
  }
  let as_leaf = leaf_hash(Bytes::from_array(concatenated))
  let as_node = node_hash(left, right)
  assert_true(as_leaf != as_node)
}

///|
test "leaf hash used as node input cannot replay as proof step" {
  // A two-leaf tree whose root is node_hash(h0, h1). An attacker who only
  // controls leaf payloads cannot craft data whose LEAF hash equals an
  // interior node, because the prefixes differ. Verify a malicious payload
  // that embeds (h0 || h1) does not verify against the root with an empty
  // proof - the single-leaf root path.
  let leaves = make_leaves(2)
  let root = must_root(leaves)
  let h0 = leaf_hash(leaves[0])
  let h1 = leaf_hash(leaves[1])
  let payload : Array[Byte] = []
  for byte in h0 {
    payload.push(byte)
  }
  for byte in h1 {
    payload.push(byte)
  }
  assert_false(verify_inclusion(Bytes::from_array(payload), [], root))
}
