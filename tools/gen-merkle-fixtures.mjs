// Independent Node.js reference implementation of the frozen Merkle boundary
// (docs/spec/EVIDENCE_PACK_SPEC.md): leaf = SHA256(0x00 || data),
// node = SHA256(0x01 || left || right), unpaired nodes promoted as-is.
//
// Generates golden roots and inclusion proofs so the MoonBit implementation
// is cross-checked against a second codebase instead of validating itself.
//
// Usage: node tools/gen-merkle-fixtures.mjs
// Output: tests/fixtures/merkle/golden.json (committed; CI may re-run this
// script and diff to detect fixture rot).

import { createHash } from "node:crypto";
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const sha256 = (...chunks) => {
  const hash = createHash("sha256");
  for (const chunk of chunks) hash.update(chunk);
  return hash.digest();
};

const leafHash = (data) => sha256(Buffer.from([0x00]), data);
const nodeHash = (left, right) => sha256(Buffer.from([0x01]), left, right);

function computeRoot(leaves) {
  if (leaves.length === 0) return null;
  let level = leaves.map(leafHash);
  while (level.length > 1) {
    const next = [];
    for (let i = 0; i + 1 < level.length; i += 2) {
      next.push(nodeHash(level[i], level[i + 1]));
    }
    if (level.length % 2 === 1) next.push(level[level.length - 1]);
    level = next;
  }
  return level[0];
}

function computeProof(leaves, index) {
  const proof = [];
  let level = leaves.map(leafHash);
  let position = index;
  while (level.length > 1) {
    const next = [];
    for (let i = 0; i + 1 < level.length; i += 2) {
      if (i === position) {
        proof.push({ sibling: level[i + 1].toString("hex"), side: "right" });
        position = next.length;
      } else if (i + 1 === position) {
        proof.push({ sibling: level[i].toString("hex"), side: "left" });
        position = next.length;
      }
      next.push(nodeHash(level[i], level[i + 1]));
    }
    if (level.length % 2 === 1) {
      const last = level.length - 1;
      if (last === position) position = next.length;
      next.push(level[last]);
    }
    level = next;
  }
  return proof;
}

// Same deterministic payloads as the MoonBit shape tests: "leaf-0", ...
const shapes = [1, 2, 3, 4, 5, 8].map((count) => {
  const leaves = Array.from({ length: count }, (_, i) =>
    Buffer.from(`leaf-${i}`, "utf8"),
  );
  return {
    count,
    leaves: leaves.map((l) => l.toString("utf8")),
    root: computeRoot(leaves).toString("hex"),
    proofs: leaves.map((_, index) => ({
      index,
      steps: computeProof(leaves, index),
    })),
  };
});

const outPath = join(
  dirname(fileURLToPath(import.meta.url)),
  "..",
  "tests",
  "fixtures",
  "merkle",
  "golden.json",
);
mkdirSync(dirname(outPath), { recursive: true });
writeFileSync(outPath, JSON.stringify({ shapes }, null, 2) + "\n");
console.log(`wrote ${outPath}`);
for (const shape of shapes) {
  console.log(`${shape.count} leaves -> root ${shape.root}`);
}
