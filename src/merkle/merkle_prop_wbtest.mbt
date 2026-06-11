// Property tests for the Merkle implementation: randomized tree shapes and
// adversarial mutations beyond the hand-picked cases in merkle_wbtest.mbt.
//
// Generators are hand-rolled (splitmix64) instead of pulling a quickcheck
// dependency: the suite stays zero-dependency, deterministic (fixed seeds,
// reproducible on every backend), and each failure message carries the
// round number so a regression replays exactly.
//
// Teeth check (mutation-tested by hand): forcing `verify_inclusion` to
// return `true` fails the tamper property; flipping a proof side in
// `compute_proof` fails the round-trip property.

// ---------------------------------------------------------------------------
// Deterministic PRNG (splitmix64)
// ---------------------------------------------------------------------------

///|
priv struct PropRng {
  mut state : UInt64
}

///|
fn PropRng::make(seed : UInt64) -> PropRng {
  { state: seed }
}

///|
fn PropRng::next(self : PropRng) -> UInt64 {
  self.state = self.state + 0x9E3779B97F4A7C15UL
  let mut z = self.state
  z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9UL
  z = (z ^ (z >> 27)) * 0x94D049BB133111EBUL
  z ^ (z >> 31)
}

///|
/// Uniform-ish draw in `0..<bound` (modulo bias is irrelevant for tests).
fn PropRng::below(self : PropRng, bound : Int) -> Int {
  (self.next() % bound.to_uint64()).to_int()
}

// ---------------------------------------------------------------------------
// Generators
// ---------------------------------------------------------------------------

///|
/// Random payload with a 4-byte little-endian `tag` prefix. Distinct tags
/// guarantee distinct payloads, which the tamper property relies on.
fn random_payload(rng : PropRng, tag : Int) -> Bytes {
  let bytes : Array[Byte] = [
    (tag & 0xff).to_byte(),
    ((tag >> 8) & 0xff).to_byte(),
    ((tag >> 16) & 0xff).to_byte(),
    ((tag >> 24) & 0xff).to_byte(),
  ]
  let body_length = rng.below(48)
  for _ in 0..<body_length {
    bytes.push(rng.below(256).to_byte())
  }
  Bytes::from_array(bytes)
}

///|
fn random_leaves(rng : PropRng, count : Int) -> Array[Bytes] {
  let leaves : Array[Bytes] = []
  for index in 0..<count {
    leaves.push(random_payload(rng, index))
  }
  leaves
}

///|
fn random_hash(rng : PropRng) -> Bytes {
  let bytes : Array[Byte] = []
  for _ in 0..<32 {
    bytes.push(rng.below(256).to_byte())
  }
  Bytes::from_array(bytes)
}

// ---------------------------------------------------------------------------
// Properties
// ---------------------------------------------------------------------------

///|
test "property: every inclusion proof verifies against its root" {
  let rng = PropRng::make(0x6d6f6f6e2d657631UL) // "moon-ev1"
  for round in 0..<60 {
    let count = 1 + rng.below(24)
    let leaves = random_leaves(rng, count)
    let root = match compute_root(leaves) {
      Some(root) => root
      None => fail("round \{round}: no root for \{count} leaves")
    }
    for index in 0..<count {
      let proof = match compute_proof(leaves, index) {
        Some(proof) => proof
        None => fail("round \{round}: no proof for index \{index}")
      }
      if !verify_inclusion(leaves[index], proof, root) {
        fail("round \{round}: proof for leaf \{index}/\{count} did not verify")
      }
    }
  }
}

///|
test "property: any single tamper breaks verification" {
  let rng = PropRng::make(0x6d6f6f6e2d657632UL) // "moon-ev2"
  for round in 0..<120 {
    let count = 1 + rng.below(24)
    let leaves = random_leaves(rng, count)
    let root = match compute_root(leaves) {
      Some(root) => root
      None => fail("round \{round}: no root for \{count} leaves")
    }
    let index = rng.below(count)
    let proof = match compute_proof(leaves, index) {
      Some(proof) => proof
      None => fail("round \{round}: no proof for index \{index}")
    }

    // Pick one applicable mutation. Proof-step mutations need a non-empty
    // proof (single-leaf trees have empty proofs); cross-leaf needs >= 2.
    let mut kind = rng.below(6)
    if proof.length() == 0 && (kind == 2 || kind == 3 || kind == 4) {
      kind = 0
    }
    if count < 2 && kind == 1 {
      kind = 0
    }
    let (label, verified) = match kind {
      0 => {
        // Replace the leaf payload with a fresh one (tag 0x7fffffff never
        // collides with generated tags, so payloads always differ).
        let forged = random_payload(rng, 0x7fffffff)
        ("forged leaf", verify_inclusion(forged, proof, root))
      }
      1 => {
        // Verify a different (distinct by construction) leaf against this
        // leaf's proof.
        let other = (index + 1 + rng.below(count - 1)) % count
        ("cross leaf", verify_inclusion(leaves[other], proof, root))
      }
      2 => {
        // Flip the side of one random step.
        let at = rng.below(proof.length())
        let mutated : Array[ProofStep] = []
        for position in 0..<proof.length() {
          let step = proof[position]
          if position == at {
            let side = match step.side {
              Left => Side::Right
              Right => Side::Left
            }
            mutated.push({ sibling: step.sibling, side })
          } else {
            mutated.push(step)
          }
        }
        ("flipped side", verify_inclusion(leaves[index], mutated, root))
      }
      3 => {
        // Replace one sibling with a random 32-byte hash.
        let at = rng.below(proof.length())
        let mutated : Array[ProofStep] = []
        for position in 0..<proof.length() {
          let step = proof[position]
          if position == at {
            mutated.push({ sibling: random_hash(rng), side: step.side })
          } else {
            mutated.push(step)
          }
        }
        ("swapped sibling", verify_inclusion(leaves[index], mutated, root))
      }
      4 => {
        // Truncate the last step.
        let mutated : Array[ProofStep] = []
        for position in 0..<(proof.length() - 1) {
          mutated.push(proof[position])
        }
        ("truncated proof", verify_inclusion(leaves[index], mutated, root))
      }
      _ => {
        // Append a forged extra step.
        let mutated : Array[ProofStep] = []
        for step in proof {
          mutated.push(step)
        }
        let side = if rng.below(2) == 0 { Side::Left } else { Side::Right }
        mutated.push({ sibling: random_hash(rng), side })
        ("extended proof", verify_inclusion(leaves[index], mutated, root))
      }
    }
    if verified {
      fail(
        "round \{round}: \{label} still verified (\{count} leaves, index \{index})",
      )
    }
  }
}
