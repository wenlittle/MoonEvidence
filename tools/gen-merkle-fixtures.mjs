// Independent Node.js reference implementation of the frozen Merkle boundary
// (docs/spec/EVIDENCE_PACK_SPEC.md): leaf = H(0x00 || data),
// node = H(0x01 || left || right), unpaired nodes promoted as-is. Both
// supported hash algorithms are generated from Node's crypto implementation.
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

const digest = (algorithm, ...chunks) => {
  const hash = createHash(algorithm);
  for (const chunk of chunks) hash.update(chunk);
  return hash.digest();
};

const leafHash = (algorithm, data) =>
  digest(algorithm, Buffer.from([0x00]), data);
const nodeHash = (algorithm, left, right) =>
  digest(algorithm, Buffer.from([0x01]), left, right);

function computeRoot(algorithm, leaves) {
  if (leaves.length === 0) return null;
  let level = leaves.map((leaf) => leafHash(algorithm, leaf));
  while (level.length > 1) {
    const next = [];
    for (let i = 0; i + 1 < level.length; i += 2) {
      next.push(nodeHash(algorithm, level[i], level[i + 1]));
    }
    if (level.length % 2 === 1) next.push(level[level.length - 1]);
    level = next;
  }
  return level[0];
}

function computeProof(algorithm, leaves, index) {
  const proof = [];
  let level = leaves.map((leaf) => leafHash(algorithm, leaf));
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
      next.push(nodeHash(algorithm, level[i], level[i + 1]));
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
const buildShapes = (algorithm) =>
  [1, 2, 3, 4, 5, 8].map((count) => {
    const leaves = Array.from({ length: count }, (_, i) =>
      Buffer.from(`leaf-${i}`, "utf8"),
    );
    return {
      count,
      leaves: leaves.map((leaf) => leaf.toString("utf8")),
      root: computeRoot(algorithm, leaves).toString("hex"),
      proofs: leaves.map((_, index) => ({
        index,
        steps: computeProof(algorithm, leaves, index),
      })),
    };
  });

const algorithms = Object.fromEntries(
  ["sha256", "sha512"].map((algorithm) => [algorithm, buildShapes(algorithm)]),
);

const outPath = join(
  dirname(fileURLToPath(import.meta.url)),
  "..",
  "tests",
  "fixtures",
  "merkle",
  "golden.json",
);
mkdirSync(dirname(outPath), { recursive: true });
writeFileSync(
  outPath,
  JSON.stringify(
    { schema: "moon-evidence-merkle-fixtures/v1", algorithms },
    null,
    2,
  ) + "\n",
);
console.log(`wrote ${outPath}`);
for (const [algorithm, shapes] of Object.entries(algorithms)) {
  for (const shape of shapes) {
    console.log(`${algorithm} ${shape.count} leaves -> root ${shape.root}`);
  }
}
