// RFC 6962 style Merkle tree with domain separation, implementing the frozen
// "Merkle Boundary" section of docs/spec/EVIDENCE_PACK_SPEC.md.
//
// Domain separation: leaves are hashed under prefix 0x00 and interior nodes
// under 0x01, so a leaf hash can never be replayed as an interior node
// (second-preimage defense). Unpaired nodes are promoted to the next level
// as-is - never paired with themselves, which is the root cause of the
// Bitcoin duplicate-leaf attack (CVE-2012-2459).

// ---------------------------------------------------------------------------
// Hash encoding
// ---------------------------------------------------------------------------

/// Hashes one leaf payload: `SHA256(0x00 || data)`.
pub fn leaf_hash(data : Bytes) -> Bytes {
  let ctx = @digest.Sha256Ctx::new()
  ctx.update(b"\x00")
  ctx.update(data)
  ctx.finalize()
}

/// Hashes one interior node: `SHA256(0x01 || left || right)`.
pub fn node_hash(left : Bytes, right : Bytes) -> Bytes {
  let ctx = @digest.Sha256Ctx::new()
  ctx.update(b"\x01")
  ctx.update(left)
  ctx.update(right)
  ctx.finalize()
}

// ---------------------------------------------------------------------------
// Root computation
// ---------------------------------------------------------------------------

/// Computes the Merkle root of `leaves` (raw leaf payloads, in manifest
/// order). Returns `None` for the empty input: the spec defines no valid
/// empty-tree root. A single leaf is its own root (`leaf_hash`, no node
/// hash applied).
pub fn compute_root(leaves : Array[Bytes]) -> Bytes? {
  if leaves.length() == 0 {
    return None
  }
  let mut level : Array[Bytes] = leaves.map(leaf_hash)
  while level.length() > 1 {
    let next : Array[Bytes] = []
    let mut index = 0
    while index + 1 < level.length() {
      next.push(node_hash(level[index], level[index + 1]))
      index = index + 2
    }
    if index < level.length() {
      // Odd node out: promote unchanged (never self-pair, CVE-2012-2459).
      next.push(level[index])
    }
    level = next
  }
  Some(level[0])
}

// ---------------------------------------------------------------------------
// Inclusion proofs
// ---------------------------------------------------------------------------

/// Position of the sibling hash relative to the running hash while walking
/// the proof bottom-up.
pub(all) enum Side {
  Left
  Right
} derive(Eq)

/// Renders `left` / `right`, the spec's wire spelling.
pub impl Show for Side with output(self, logger) {
  match self {
    Left => logger.write_string("left")
    Right => logger.write_string("right")
  }
}

/// One bottom-up proof entry: combine the running hash with `sibling` on
/// the given side (`Left` means `node_hash(sibling, current)`).
pub(all) struct ProofStep {
  sibling : Bytes
  side : Side
} derive(Eq)

/// Renders `side:sibling-hex`, compact enough for failed-assertion output.
pub impl Show for ProofStep with output(self, logger) {
  logger.write_string(self.side.to_string())
  logger.write_string(":")
  for byte in self.sibling {
    let value = byte.to_int()
    logger.write_char(proof_hex_digits[value >> 4])
    logger.write_char(proof_hex_digits[value & 0x0f])
  }
}

let proof_hex_digits : FixedArray[Char] = [
  '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f',
]

/// Builds the inclusion proof for `leaves[index]`, bottom-up. Returns `None`
/// when the index is out of range (which includes the empty tree). The proof
/// for a single-leaf tree is empty: the leaf hash already equals the root.
pub fn compute_proof(leaves : Array[Bytes], index : Int) -> Array[ProofStep]? {
  if index < 0 || index >= leaves.length() {
    return None
  }
  let proof : Array[ProofStep] = []
  let mut level : Array[Bytes] = leaves.map(leaf_hash)
  let mut position = index
  while level.length() > 1 {
    let next : Array[Bytes] = []
    let mut cursor = 0
    while cursor + 1 < level.length() {
      if cursor == position {
        proof.push({ sibling: level[cursor + 1], side: Right })
        position = next.length()
      } else if cursor + 1 == position {
        proof.push({ sibling: level[cursor], side: Left })
        position = next.length()
      }
      next.push(node_hash(level[cursor], level[cursor + 1]))
      cursor = cursor + 2
    }
    if cursor < level.length() {
      // Unpaired node carries straight up; no proof step is emitted for it.
      if cursor == position {
        position = next.length()
      }
      next.push(level[cursor])
    }
    level = next
  }
  Some(proof)
}

/// Recomputes the root from `leaf` (raw payload, not yet hashed) and the
/// bottom-up `proof`, then compares it with `root` byte-for-byte.
pub fn verify_inclusion(
  leaf : Bytes,
  proof : Array[ProofStep],
  root : Bytes,
) -> Bool {
  let mut current = leaf_hash(leaf)
  for step in proof {
    current = match step.side {
      Left => node_hash(step.sibling, current)
      Right => node_hash(current, step.sibling)
    }
  }
  current == root
}
