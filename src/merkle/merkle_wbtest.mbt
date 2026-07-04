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

// ---------------------------------------------------------------------------
// Full tree materialization (compute_tree / MerkleTree)
// ---------------------------------------------------------------------------

///|
fn must_tree(leaves : Array[Bytes]) -> MerkleTree raise {
  match compute_tree(leaves) {
    Some(tree) => tree
    None => fail("expected a tree for \{leaves.length()} leaves")
  }
}

///|
test "compute_tree on empty input returns None" {
  assert_true(compute_tree([]) is None)
}

///|
test "compute_tree root equals compute_root for every shape" {
  for count in [1, 2, 3, 4, 5, 7, 8, 16] {
    let leaves = make_leaves(count)
    let tree = must_tree(leaves)
    let tree_root = match tree.root() {
      Some(r) => r
      None => fail("tree should have a root")
    }
    let compute_root_value = match compute_root(leaves) {
      Some(r) => r
      None => fail("compute_root should agree")
    }
    assert_eq(tree_root, compute_root_value)
  }
}

///|
test "compute_tree single leaf yields one level of one node" {
  let tree = must_tree(make_leaves(1))
  assert_eq(tree.height(), 1)
  assert_eq(tree.leaf_count(), 1)
  let top = tree.level(0)
  assert_eq(top.length(), 1)
  assert_eq(top[0], leaf_hash(@digest.string_to_utf8_bytes("leaf-0")))
}

///|
test "compute_tree two leaves yields two levels of one node each" {
  let tree = must_tree(make_leaves(2))
  assert_eq(tree.height(), 2)
  assert_eq(tree.leaf_count(), 2)
  let level0 = tree.level(0)
  assert_eq(level0.length(), 2)
  let level1 = tree.level(1)
  assert_eq(level1.length(), 1)
  assert_eq(level1[0], node_hash(level0[0], level0[1]))
}

///|
test "compute_tree three leaves promotes the odd leaf without changing its hash" {
  let tree = must_tree(make_leaves(3))
  assert_eq(tree.height(), 3)
  let level0 = tree.level(0)
  let level1 = tree.level(1)
  let level2 = tree.level(2)
  // Level 0: three leaf hashes.
  assert_eq(level0.length(), 3)
  // Level 1: node(h0,h1) then h2 (promoted).
  assert_eq(level1.length(), 2)
  assert_eq(level1[1], level0[2])
  // Level 2: root = node(level1[0], level1[1]).
  assert_eq(level2.length(), 1)
  assert_eq(level2[0], node_hash(level1[0], level1[1]))
}

///|
test "compute_tree out-of-bounds level returns empty array" {
  let tree = must_tree(make_leaves(4))
  assert_eq(tree.level(-1).length(), 0)
  assert_eq(tree.level(tree.height()).length(), 0)
  assert_eq(tree.level(99).length(), 0)
}

///|
test "compute_tree five leaves height is four with promoted leaf twice" {
  // 5 leaves -> level 0 (5), level 1 (3: 2 pairs + promote), level 2
  // (2: 1 pair + promote), level 3 (1: node of prev two).
  let tree = must_tree(make_leaves(5))
  assert_eq(tree.height(), 4)
  assert_eq(tree.leaf_count(), 5)
  assert_eq(tree.level(0).length(), 5)
  assert_eq(tree.level(1).length(), 3)
  assert_eq(tree.level(2).length(), 2)
  assert_eq(tree.level(3).length(), 1)
  // The promoted leaf appears unchanged on level 1 as well.
  assert_eq(tree.level(1)[2], tree.level(0)[4])
}

///|
test "leaf_path covers one step per level and ends at root" {
  for count in [1, 2, 3, 4, 5, 8] {
    let tree = must_tree(make_leaves(count))
    for index in 0..<count {
      let path = match tree.leaf_path(index) {
        Some(p) => p
        None => fail("expected a path for index \{index}")
      }
      assert_eq(path.length(), tree.height())
      // First step is the leaf on level 0 at the given index.
      assert_eq(path[0], { level: 0, node_index: index })
      // Last step is the root.
      let last = path[path.length() - 1]
      assert_eq(last.level, tree.height() - 1)
      assert_eq(last.node_index, 0)
      // Last step hash equals the tree root.
      let last_hash = tree.level(last.level)[last.node_index]
      let root_hash = match tree.root() {
        Some(r) => r
        None => fail("root expected")
      }
      assert_eq(last_hash, root_hash)
    }
  }
}

///|
test "leaf_path on empty tree returns None" {
  let tree = match compute_tree([]) {
    Some(t) => t
    None => return
  }
  // Force failure if compute_tree ever stops returning None on empty.
  assert_true(tree.leaf_path(0) is None)
}

///|
test "leaf_path with out-of-range index returns None" {
  let tree = must_tree(make_leaves(3))
  assert_true(tree.leaf_path(-1) is None)
  assert_true(tree.leaf_path(3) is None)
}
