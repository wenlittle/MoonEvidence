// Cross-validation against the independent Node.js reference implementation
// (tools/gen-merkle-fixtures.mjs). Golden values are mirrored from
// tests/fixtures/merkle/golden.json so SHA-256 and SHA-512 trees are checked
// against a second codebase instead of validating themselves. Payloads are
// "leaf-0".. in UTF-8, matching the generator.

///|
fn golden_leaves(count : Int) -> Array[Bytes] {
  let leaves : Array[Bytes] = []
  for index in 0..<count {
    leaves.push(@digest.string_to_utf8_bytes("leaf-\{index}"))
  }
  leaves
}

///|
fn root_hex(leaves : Array[Bytes]) -> String raise {
  root_hex_with(leaves, @digest.Sha256)
}

///|
fn root_hex_with(
  leaves : Array[Bytes],
  algorithm : @digest.HashAlgorithm,
) -> String raise {
  match compute_root(leaves, algorithm~) {
    Some(root) => @digest.bytes_to_lower_hex(root)
    None => fail("expected a root for \{leaves.length()} leaves")
  }
}

///|
/// Thin wrapper over `@digest.hex_to_bytes` so test fixtures can use a
/// raising `Bytes` interface. Invalid hex fails the test instead of
/// silently decoding to wrong bytes.
fn hex_to_bytes(hex : String) -> Bytes raise {
  match @digest.hex_to_bytes(hex) {
    Some(bytes) => bytes
    None => fail("invalid hex in fixture: \{hex}")
  }
}

// ---------------------------------------------------------------------------
// Golden roots (every shape)
// ---------------------------------------------------------------------------

///|
test "golden roots match the node reference for every shape" {
  let expectations = [
    (1, "305df59f9590c3c9ac63d2b2743c388e3792449078cebf7fb3dbe6471643b2b7"),
    (2, "60a53eed0de87a90c8e59427c59c46253c33a76a09502a51801300927b7e6bdc"),
    (3, "cf763a041c81ceef1578a6083f75c61bef2e0014f2a3e683a97fcfca5be7f19a"),
    (4, "bdd1c5ff55b19cb6b0e7c761bf9a6ccaa27fbbfc07b74f1fabb6e911a0bd2ab3"),
    (5, "00d21829a5503145348abcf712513eacf2a274211ad83e970202bb5b6d80b286"),
    (8, "ca6b7b3e674ac86c1027b59c87c064fc3bc27b313294c75f83bd05fdd13f0dcf"),
  ]
  for expectation in expectations {
    let (count, expected) = expectation
    assert_eq(root_hex(golden_leaves(count)), expected)
  }
}

///|
test "sha512 golden roots match the node reference for every shape" {
  let expectations = [
    (
      1, "5902d7173d5cb994c117c23e787f94448f784b530b84b2da0c00db257c360f39825227a7d2ae7bf6b505cb48e4a0efb8f678a1a43b5e7a296a1b8622d9ed965d",
    ),
    (
      2, "a3a9f52ec3e6a1adf54a1d97f1e074667ada50c784230e0059a69758dc24819df4cd7d63f746528d73c933a08cfdca573858ace5ff6036e3c42c465b32c0954f",
    ),
    (
      3, "abac9499dee08aa674fbe37dadde62eca33889267020f5198c220122c10efb72e47576d58d72817a2f2121181fae0f63a817231ade266059fd82e3720bf4eb9a",
    ),
    (
      4, "6a40fd3512b105fc08f3345c2b01ccd88eebaddf218b3d4ac45aa39fbbfee34e70341931883bb582fb972e67b1977dceca6d4dabbc4bb0bc4010a763459eefe4",
    ),
    (
      5, "4eef72eadcfb0fda54d68c356c5cdfe7db659aa308a7afae4525a6e6af8185c2c25106c1d363e7bae718899718b8ef1b8bd9e2cc582e979f2590649964ab8965",
    ),
    (
      8, "6e28c3abf294705080398b9ebabc2cc7dff9379a81afdcd4af3254bb48a1ef5da370ed617e31cbedf50b7308f300d220e9913463401b731d6a52d0dd70d7cd4b",
    ),
  ]
  for expectation in expectations {
    let (count, expected) = expectation
    assert_eq(root_hex_with(golden_leaves(count), @digest.Sha512), expected)
  }
}

// ---------------------------------------------------------------------------
// Golden proofs (spot checks pinned from golden.json)
// ---------------------------------------------------------------------------

///|
test "golden proof for eight leaves index three matches node reference" {
  let leaves = golden_leaves(8)
  let proof = match compute_proof(leaves, 3) {
    Some(proof) => proof
    None => fail("expected a proof")
  }
  let expected : Array[ProofStep] = [
    {
      sibling: hex_to_bytes(
        "fca89f57c9f8c8eb4047a7ff9d333acf9e0f3384b20b255bceab0f216dcca267",
      ),
      side: Left,
    },
    {
      sibling: hex_to_bytes(
        "60a53eed0de87a90c8e59427c59c46253c33a76a09502a51801300927b7e6bdc",
      ),
      side: Left,
    },
    {
      sibling: hex_to_bytes(
        "f58aaab46122102d66b00c5eb50b13dd763b5f800139b424fda8b1cacae1408a",
      ),
      side: Right,
    },
  ]
  @debug.assert_eq(proof, expected)
  assert_true(
    verify_inclusion(
      leaves[3],
      proof,
      hex_to_bytes(
        "ca6b7b3e674ac86c1027b59c87c064fc3bc27b313294c75f83bd05fdd13f0dcf",
      ),
    ),
  )
}

///|
test "golden proof for five leaves promoted index matches node reference" {
  // The 5th leaf is promoted twice; its single proof step combines it with
  // the root of the 4-leaf subtree on the LEFT - pinning the promotion rule
  // against the reference implementation.
  let leaves = golden_leaves(5)
  let proof = match compute_proof(leaves, 4) {
    Some(proof) => proof
    None => fail("expected a proof")
  }
  let expected : Array[ProofStep] = [
    {
      sibling: hex_to_bytes(
        "bdd1c5ff55b19cb6b0e7c761bf9a6ccaa27fbbfc07b74f1fabb6e911a0bd2ab3",
      ),
      side: Left,
    },
  ]
  @debug.assert_eq(proof, expected)
  assert_true(
    verify_inclusion(
      leaves[4],
      proof,
      hex_to_bytes(
        "00d21829a5503145348abcf712513eacf2a274211ad83e970202bb5b6d80b286",
      ),
    ),
  )
}

///|
test "sha512 golden proofs match node reference pairing and promotion" {
  let eight_leaves = golden_leaves(8)
  let index_three = match
    compute_proof(eight_leaves, 3, algorithm=@digest.Sha512) {
    Some(proof) => proof
    None => fail("expected SHA-512 proof for eight leaves")
  }
  let expected_three : Array[ProofStep] = [
    {
      sibling: hex_to_bytes(
        "a5c2611f2255e702a9c19fbf0e8eea88ad5244ad3b475dfce66e37e4e5468f1d4c239c82e9edae02ecae73d4c4316ff8895889eeb6bfa2b5d590d8e60a21f640",
      ),
      side: Left,
    },
    {
      sibling: hex_to_bytes(
        "a3a9f52ec3e6a1adf54a1d97f1e074667ada50c784230e0059a69758dc24819df4cd7d63f746528d73c933a08cfdca573858ace5ff6036e3c42c465b32c0954f",
      ),
      side: Left,
    },
    {
      sibling: hex_to_bytes(
        "3ebfe96db2ea1dfee22d61d7e2f1851dd3d00a962c7511fb3fb2436b505edafe684a0eac51f50e059e7d531297415fe2236c8963f4ac6506dcfe38a15139667d",
      ),
      side: Right,
    },
  ]
  @debug.assert_eq(index_three, expected_three)
  assert_true(
    verify_inclusion(
      eight_leaves[3],
      index_three,
      hex_to_bytes(
        "6e28c3abf294705080398b9ebabc2cc7dff9379a81afdcd4af3254bb48a1ef5da370ed617e31cbedf50b7308f300d220e9913463401b731d6a52d0dd70d7cd4b",
      ),
      algorithm=@digest.Sha512,
    ),
  )

  let five_leaves = golden_leaves(5)
  let promoted = match compute_proof(five_leaves, 4, algorithm=@digest.Sha512) {
    Some(proof) => proof
    None => fail("expected promoted SHA-512 proof")
  }
  let expected_promoted : Array[ProofStep] = [
    {
      sibling: hex_to_bytes(
        "6a40fd3512b105fc08f3345c2b01ccd88eebaddf218b3d4ac45aa39fbbfee34e70341931883bb582fb972e67b1977dceca6d4dabbc4bb0bc4010a763459eefe4",
      ),
      side: Left,
    },
  ]
  @debug.assert_eq(promoted, expected_promoted)
  assert_true(
    verify_inclusion(
      five_leaves[4],
      promoted,
      hex_to_bytes(
        "4eef72eadcfb0fda54d68c356c5cdfe7db659aa308a7afae4525a6e6af8185c2c25106c1d363e7bae718899718b8ef1b8bd9e2cc582e979f2590649964ab8965",
      ),
      algorithm=@digest.Sha512,
    ),
  )
}
