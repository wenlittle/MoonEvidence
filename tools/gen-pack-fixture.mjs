// Builds the golden "valid pack" used by verify tests: real file digests and
// a real Merkle root over canonical file entries, computed by an independent
// implementation (same frozen rules: JCS entry rendering, 0x00/0x01 domain
// separation). Keeps the MoonBit pipeline cross-checked end to end.
//
// Usage: node tools/gen-pack-fixture.mjs

import { createHash } from "node:crypto";

const sha256 = (...chunks) => {
  const hash = createHash("sha256");
  for (const chunk of chunks) hash.update(chunk);
  return hash.digest();
};
const hex = (buffer) => buffer.toString("hex");
const leafHash = (data) => sha256(Buffer.from([0x00]), data);
const nodeHash = (left, right) => sha256(Buffer.from([0x01]), left, right);

const fileA = Buffer.from("hello world\n", "utf8");
const fileB = Buffer.alloc(0);

const entries = [
  { path: "files/a.txt", size: fileA.length, digest: `sha256:${hex(sha256(fileA))}` },
  { path: "files/b.bin", size: 0, digest: `sha256:${hex(sha256(fileB))}` },
];

// Canonical entry rendering: keys sorted by UTF-16 code units
// (digest < path < size), compact separators - matches RFC 8785 for this
// ASCII-only, integer-only payload.
const canonicalEntry = (e) =>
  JSON.stringify({ digest: e.digest, path: e.path, size: e.size });

const leaves = entries.map((e) => leafHash(Buffer.from(canonicalEntry(e), "utf8")));
const root = nodeHash(leaves[0], leaves[1]);

console.log("file a digest:", entries[0].digest);
console.log("file b digest:", entries[1].digest);
console.log("canonical entry a:", canonicalEntry(entries[0]));
console.log("merkle root:", `sha256:${hex(root)}`);

// The manifest itself, plus its canonical digest (for the E2004 test).
const manifest = {
  schema: "moon-evidence/v0",
  subject: { id: "golden-pack", type: "dataset" },
  hash_algorithm: "sha256",
  files: entries,
  merkle_root: `sha256:${hex(root)}`,
  version: { id: "v1", parent: null },
};
const sortKeys = (value) => {
  if (Array.isArray(value)) return value.map(sortKeys);
  if (value && typeof value === "object") {
    return Object.fromEntries(
      Object.keys(value)
        .sort()
        .map((k) => [k, sortKeys(value[k])]),
    );
  }
  return value;
};
const canonicalManifest = JSON.stringify(sortKeys(manifest));
console.log("manifest json:", JSON.stringify(manifest));
console.log("canonical manifest digest:", `sha256:${hex(sha256(Buffer.from(canonicalManifest, "utf8")))}`);
