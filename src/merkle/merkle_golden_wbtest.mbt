// Cross-validation against the independent Node.js reference implementation
// (tools/gen-merkle-fixtures.mjs). Golden values are mirrored from
// tests/fixtures/merkle/golden.json so the MoonBit tree is checked against a
// second codebase instead of validating itself. Payloads are "leaf-0".. in
// UTF-8, matching the generator.

fn golden_leaves(count : Int) -> Array[Bytes] {
  let leaves : Array[Bytes] = []
  for index in 0..<count {
    leaves.push(@digest.string_to_utf8_bytes("leaf-\{index}"))
  }
  leaves
}

fn root_hex(leaves : Array[Bytes]) -> String raise {
  match compute_root(leaves) {
    Some(root) => bytes_to_hex(root)
    None => fail("expected a root for \{leaves.length()} leaves")
  }
}

fn bytes_to_hex(data : Bytes) -> String {
  let builder = StringBuilder::new(size_hint=data.length() * 2)
  for byte in data {
    let value = byte.to_int()
    builder.write_char(proof_hex_digits[value >> 4])
    builder.write_char(proof_hex_digits[value & 0x0f])
  }
  builder.to_string()
}

fn hex_to_bytes(hex : String) -> Bytes raise {
  guard hex.length() % 2 == 0 else { fail("odd hex length") }
  Bytes::makei(hex.length() / 2, fn(index) {
    let high = hex_digit_value(hex[index * 2].to_int())
    let low = hex_digit_value(hex[index * 2 + 1].to_int())
    ((high << 4) | low).to_byte()
  })
}

fn hex_digit_value(unit : Int) -> Int {
  if unit >= 0x30 && unit <= 0x39 {
    unit - 0x30
  } else if unit >= 0x61 && unit <= 0x66 {
    unit - 0x61 + 10
  } else {
    -1
  }
}

// ---------------------------------------------------------------------------
// Golden roots (every shape)
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Golden proofs (spot checks pinned from golden.json)
// ---------------------------------------------------------------------------

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
