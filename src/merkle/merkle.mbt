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

///|
/// Resolves an optional algorithm to Sha256 when absent, so existing callers
/// that omit the parameter keep their SHA-256 behavior unchanged.
fn resolve_algo(algorithm : @digest.HashAlgorithm?) -> @digest.HashAlgorithm {
  match algorithm {
    Some(a) => a
    None => @digest.Sha256
  }
}

///|
/// Hashes one leaf payload: `<H>(0x00 || data)` where `H` is the algorithm
/// (SHA-256 by default for backward compatibility, SHA-512 when requested).
pub fn leaf_hash(data : Bytes, algorithm? : @digest.HashAlgorithm) -> Bytes {
  let algo = resolve_algo(algorithm)
  match algo {
    @digest.Sha256 => {
      let ctx = @digest.Sha256Ctx::new()
      ctx.update(b"\x00")
      ctx.update(data)
      ctx.finalize()
    }
    @digest.Sha512 => {
      let ctx = @digest.Sha512Ctx::new()
      ctx.update(b"\x00")
      ctx.update(data)
      ctx.finalize()
    }
  }
}

///|
/// Hashes one interior node: `<H>(0x01 || left || right)`.
pub fn node_hash(
  left : Bytes,
  right : Bytes,
  algorithm? : @digest.HashAlgorithm,
) -> Bytes {
  let algo = resolve_algo(algorithm)
  match algo {
    @digest.Sha256 => {
      let ctx = @digest.Sha256Ctx::new()
      ctx.update(b"\x01")
      ctx.update(left)
      ctx.update(right)
      ctx.finalize()
    }
    @digest.Sha512 => {
      let ctx = @digest.Sha512Ctx::new()
      ctx.update(b"\x01")
      ctx.update(left)
      ctx.update(right)
      ctx.finalize()
    }
  }
}

// ---------------------------------------------------------------------------
// Root computation
// ---------------------------------------------------------------------------

///|
/// Computes the Merkle root of `leaves` (raw leaf payloads, in manifest
/// order). Returns `None` for the empty input: the spec defines no valid
/// empty-tree root. A single leaf is its own root (`leaf_hash`, no node
/// hash applied).
pub fn compute_root(
  leaves : Array[Bytes],
  algorithm? : @digest.HashAlgorithm,
) -> Bytes? {
  if leaves.length() == 0 {
    return None
  }
  let algo = resolve_algo(algorithm)
  let mut level : Array[Bytes] = leaves.map(fn(data) {
    leaf_hash(data, algorithm=algo)
  })
  while level.length() > 1 {
    let next : Array[Bytes] = []
    let mut index = 0
    while index + 1 < level.length() {
      next.push(node_hash(level[index], level[index + 1], algorithm=algo))
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
// Full tree materialization (for visualization; does not change compute_root)
// ---------------------------------------------------------------------------

///|
/// A materialized Merkle tree: every hash on every level, from leaf hashes
/// up to the single root. `levels[0]` holds the leaf hashes (in manifest
/// order); `levels[last]` holds exactly one element, the root. Odd nodes
/// are promoted unchanged between adjacent levels, mirroring `compute_root`
/// and `compute_proof` exactly.
///
/// The struct exists to let a visualization layer walk the tree without
/// re-deriving it; `compute_root` remains the canonical single-value API.
pub(all) struct MerkleTree {
  levels : Array[Array[Bytes]]
} derive(Eq)

///|
/// Returns the root hash, or `None` when the tree is empty.
pub fn MerkleTree::root(self : MerkleTree) -> Bytes? {
  let top = self.levels[self.levels.length() - 1]
  if top.length() == 0 {
    None
  } else {
    Some(top[0])
  }
}

///|
/// Number of levels (1 = single-leaf tree, 0 = empty). For a non-empty
/// tree this is `ceil(log2(n)) + 1` where `n` is the leaf count, clamped so
/// that a single leaf still counts as one level.
pub fn MerkleTree::height(self : MerkleTree) -> Int {
  self.levels.length()
}

///|
/// Leaf count of the original input (the width of level 0).
pub fn MerkleTree::leaf_count(self : MerkleTree) -> Int {
  if self.levels.length() == 0 {
    0
  } else {
    self.levels[0].length()
  }
}

///|
/// Snapshot of one level's hashes. Out-of-range `level` returns an empty
/// array so callers can render defensively without bounds checks.
pub fn MerkleTree::level(self : MerkleTree, level : Int) -> Array[Bytes] {
  if level < 0 || level >= self.levels.length() {
    []
  } else {
    self.levels[level]
  }
}

///|
/// Builds the full Merkle tree of `leaves` (raw leaf payloads, in manifest
/// order). Returns `None` for the empty input, identical to `compute_root`.
/// The returned tree's root always equals `compute_root(leaves)`.
///
/// Visualization note: a caller rendering this tree should treat an odd
/// promoted node (a hash that appears unchanged on two adjacent levels) as
/// the same logical node, not a fresh child, to avoid misleading the viewer
/// into thinking self-pairing happened. `leaf_path` below encodes the
/// promotion structure faithfully.
pub fn compute_tree(
  leaves : Array[Bytes],
  algorithm? : @digest.HashAlgorithm,
) -> MerkleTree? {
  if leaves.length() == 0 {
    return None
  }
  let algo = resolve_algo(algorithm)
  let levels : Array[Array[Bytes]] = []
  // Level 0: leaf hashes.
  let mut current : Array[Bytes] = leaves.map(fn(data) {
    leaf_hash(data, algorithm=algo)
  })
  levels.push(current)
  while current.length() > 1 {
    let next : Array[Bytes] = []
    let mut index = 0
    while index + 1 < current.length() {
      next.push(node_hash(current[index], current[index + 1], algorithm=algo))
      index = index + 2
    }
    if index < current.length() {
      // Odd node out: promote unchanged (never self-pair, CVE-2012-2459).
      next.push(current[index])
    }
    levels.push(next)
    current = next
  }
  Some({ levels, })
}

///|
/// One step on the path from a leaf up to the root. `level` is the level
/// the step *starts* on (0 = leaf-hash level), `node_index` is that
/// node's position on its level. Walking `leaf_path(i)` from first to
/// last reconstructs the spine from `leaves[i]` to the root: every step
/// is one of the ancestor hashes whose value depends on the starting
/// leaf (or on a sibling of it). The final element is the root itself.
///
/// A step is *not* recorded for an interior hash that is the parent of
/// two distinct paired children produced by `node_hash(...)`; that parent
/// is one of the ancestors we did walk through, but recording every level
/// would double-count when the spine stays on the left edge. To keep the
/// list monotone and aligned with what a renderer's "highlight this leaf
/// and its ancestors" call needs, each step is the node on `level` whose
/// hash is part of the path from `leaves[i]` to the root.
pub(all) struct PathStep {
  level : Int
  node_index : Int
} derive(Eq, @debug.Debug)

///|
pub impl Show for PathStep with fn output(self, logger) {
  logger.write_string("\{self.level}:\{self.node_index}")
}

///|
/// Returns the spine from `leaves[index]` up to the root. `None` when
/// `index` is out of range or the tree is empty. For an N-leaf tree with
/// `promoted` odd-nodes folding into the next level, the path always
/// ends at `(height-1, 0)` and contains exactly one step per level
/// (the level where the spine's node lives), so `leaf_path(i).length()
/// == tree.height()`.
pub fn MerkleTree::leaf_path(
  self : MerkleTree,
  index : Int,
) -> Array[PathStep]? {
  if self.levels.length() == 0 || index < 0 || index >= self.leaf_count() {
    return None
  }
  let path : Array[PathStep] = []
  // Walk down levels; at each level record the node on the spine, then
  // compute the position of that node's parent on the next level.
  let mut position = index
  for level in 0..<self.levels.length() {
    path.push({ level, node_index: position })
    // Compute the position on the next level (unless this is the root).
    if level < self.levels.length() - 1 {
      let nodes = self.levels[level]
      let odd_promoted = nodes.length() % 2 == 1 &&
        position == nodes.length() - 1
      position = if odd_promoted {
        // Promoted node: count of pairs (floor(n/2)) plus one slot at
        // the end for the promotion.
        nodes.length() / 2
      } else {
        position / 2
      }
    }
  }
  Some(path)
}

// ---------------------------------------------------------------------------
// Inclusion proofs
// ---------------------------------------------------------------------------

///|
/// Position of the sibling hash relative to the running hash while walking
/// the proof bottom-up.
pub(all) enum Side {
  Left
  Right
} derive(Eq, @debug.Debug)

///|
/// Renders `left` / `right`, the spec's wire spelling.
pub impl Show for Side with fn output(self, logger) {
  match self {
    Left => logger.write_string("left")
    Right => logger.write_string("right")
  }
}

///|
/// One bottom-up proof entry: combine the running hash with `sibling` on
/// the given side (`Left` means `node_hash(sibling, current)`).
pub(all) struct ProofStep {
  sibling : Bytes
  side : Side
} derive(Eq, @debug.Debug)

///|
/// Renders `side:sibling-hex`, compact enough for failed-assertion output.
pub impl Show for ProofStep with fn output(self, logger) {
  logger.write_string(self.side.to_string())
  logger.write_string(":")
  logger.write_string(@digest.bytes_to_lower_hex(self.sibling))
}

///|
/// Builds the inclusion proof for `leaves[index]`, bottom-up. Returns `None`
/// when the index is out of range (which includes the empty tree). The proof
/// for a single-leaf tree is empty: the leaf hash already equals the root.
pub fn compute_proof(
  leaves : Array[Bytes],
  index : Int,
  algorithm? : @digest.HashAlgorithm,
) -> Array[ProofStep]? {
  if index < 0 || index >= leaves.length() {
    return None
  }
  let algo = resolve_algo(algorithm)
  let proof : Array[ProofStep] = []
  let mut level : Array[Bytes] = leaves.map(fn(data) {
    leaf_hash(data, algorithm=algo)
  })
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
      next.push(node_hash(level[cursor], level[cursor + 1], algorithm=algo))
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

///|
/// Recomputes the root from `leaf` (raw payload, not yet hashed) and the
/// bottom-up `proof`, then compares it with `root` byte-for-byte.
pub fn verify_inclusion(
  leaf : Bytes,
  proof : Array[ProofStep],
  root : Bytes,
  algorithm? : @digest.HashAlgorithm,
) -> Bool {
  let algo = resolve_algo(algorithm)
  let mut current = leaf_hash(leaf, algorithm=algo)
  for step in proof {
    current = match step.side {
      Left => node_hash(step.sibling, current, algorithm=algo)
      Right => node_hash(current, step.sibling, algorithm=algo)
    }
  }
  current == root
}
