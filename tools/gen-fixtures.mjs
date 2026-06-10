// Independent reference generator for the step-7 tamper matrix
// (tests/fixtures/packs/). Node's crypto is the second implementation the
// MoonBit pipeline is cross-checked against: every digest, leaf hash and
// Merkle root below is computed with the same frozen rules (JCS entry
// rendering, 0x00/0x01 domain separation) but none of the MoonBit code.
//
// Deterministic by construction: fixed payload bytes, fixed key order,
// 2-space JSON, LF line endings. Re-running must be byte-stable - CI runs
// this script and fails when `git diff` reports drift (fixture rot guard).
//
// Usage: node tools/gen-fixtures.mjs

import { createHash } from "node:crypto";
import { mkdirSync, writeFileSync, rmSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), "..");
const packsRoot = join(repoRoot, "tests", "fixtures", "packs");

// --- frozen crypto rules (independent of the MoonBit implementation) ------

const sha256 = (...chunks) => {
  const hash = createHash("sha256");
  for (const chunk of chunks) hash.update(chunk);
  return hash.digest();
};
const hex = (buffer) => buffer.toString("hex");
const digestOf = (bytes) => `sha256:${hex(sha256(bytes))}`;
const leafHash = (data) => sha256(Buffer.from([0x00]), data);
const nodeHash = (left, right) => sha256(Buffer.from([0x01]), left, right);

// Canonical files[] entry: keys in UTF-16 code-unit order
// (digest < path < size), compact separators - RFC 8785 for this
// ASCII-only, integer-only payload.
const canonicalEntry = (e) =>
  JSON.stringify({ digest: e.digest, path: e.path, size: e.size });

// RFC 6962-style root: unpaired nodes promote as-is (no self-pairing).
const merkleRoot = (entries) => {
  let level = entries.map((e) =>
    leafHash(Buffer.from(canonicalEntry(e), "utf8")),
  );
  if (level.length === 0) return null;
  while (level.length > 1) {
    const next = [];
    for (let i = 0; i + 1 < level.length; i += 2) {
      next.push(nodeHash(level[i], level[i + 1]));
    }
    if (level.length % 2 === 1) next.push(level[level.length - 1]);
    level = next;
  }
  return `sha256:${hex(level[0])}`;
};

// --- fixed payloads --------------------------------------------------------

const PAYLOAD_A = Buffer.from("hello fixtures\n", "utf8");
const PAYLOAD_A_TAMPERED = Buffer.from("hello tampered\n", "utf8");
const PAYLOAD_B = Buffer.from([0x00, 0x01, 0x02, 0x03]);
const PAYLOAD_EXTRA = Buffer.from("rogue\n", "utf8");
const PAYLOAD_GONE = Buffer.from("gone\n", "utf8"); // digested, never written

const entryFor = (path, payload) => ({
  path,
  size: payload.length,
  digest: digestOf(payload),
});

const baseEntries = () => [
  entryFor("files/a.txt", PAYLOAD_A),
  entryFor("files/b.bin", PAYLOAD_B),
];

const baseChain = [
  { id: "v1", parent: null },
  { id: "v2", parent: "v1" },
];

// --- pack matrix ------------------------------------------------------------
//
// Each spec: disk files, manifest entries, optional overrides. The expected
// CLI behaviour (exact code set, exit code) lives in the README table and is
// asserted by tools/cli-test.ps1.

const packs = {
  valid: {
    disk: { "files/a.txt": PAYLOAD_A, "files/b.bin": PAYLOAD_B },
    entries: baseEntries(),
    chain: baseChain,
  },
  "tampered-file": {
    // Disk byte flip; manifest keeps the original digest -> E2003 only
    // (the Merkle tree attests manifest entries, not file bytes).
    disk: { "files/a.txt": PAYLOAD_A_TAMPERED, "files/b.bin": PAYLOAD_B },
    entries: baseEntries(),
    chain: baseChain,
  },
  "missing-file": {
    // Listed but absent on disk -> E2003 (root still matches the entries).
    disk: { "files/a.txt": PAYLOAD_A, "files/b.bin": PAYLOAD_B },
    entries: [...baseEntries(), entryFor("files/gone.txt", PAYLOAD_GONE)],
    chain: baseChain,
  },
  "unlisted-file": {
    // Extra payload on disk -> W1001 warning, verification still passes.
    disk: {
      "files/a.txt": PAYLOAD_A,
      "files/b.bin": PAYLOAD_B,
      "files/extra.bin": PAYLOAD_EXTRA,
    },
    entries: baseEntries(),
    chain: baseChain,
  },
  "bad-digest-field": {
    // Manifest digest field swapped after sealing; file untouched.
    // Double hit: file vs forged digest (E2003) and leaf bytes vs sealed
    // root (E3003) - each defense line fires for its own reason.
    disk: { "files/a.txt": PAYLOAD_A, "files/b.bin": PAYLOAD_B },
    entries: baseEntries(),
    chain: baseChain,
    mutate: (manifest) => {
      manifest.files[0].digest = digestOf(Buffer.from("wrong\n", "utf8"));
    },
  },
  "bad-merkle-root": {
    // Root field swapped for a well-formed but wrong digest -> E3003.
    disk: { "files/a.txt": PAYLOAD_A, "files/b.bin": PAYLOAD_B },
    entries: baseEntries(),
    chain: baseChain,
    mutate: (manifest) => {
      manifest.merkle_root = digestOf(Buffer.from("not the root", "utf8"));
    },
  },
  "chain-broken": {
    // v2 references a parent id that never existed -> E4002.
    disk: { "files/a.txt": PAYLOAD_A, "files/b.bin": PAYLOAD_B },
    entries: baseEntries(),
    chain: [
      { id: "v1", parent: null },
      { id: "v2", parent: "v0" },
    ],
  },
  "chain-cycle": {
    // Rootless two-node cycle -> E4003.
    disk: { "files/a.txt": PAYLOAD_A, "files/b.bin": PAYLOAD_B },
    entries: baseEntries(),
    chain: [
      { id: "v1", parent: "v2" },
      { id: "v2", parent: "v1" },
    ],
  },
  "chain-empty": {
    // Empty array parses but verification reports E4001.
    disk: { "files/a.txt": PAYLOAD_A, "files/b.bin": PAYLOAD_B },
    entries: baseEntries(),
    chain: [],
  },
  "chain-fork": {
    // Two children share one parent -> E4004 (chain must be linear).
    disk: { "files/a.txt": PAYLOAD_A, "files/b.bin": PAYLOAD_B },
    entries: baseEntries(),
    chain: [
      { id: "v1", parent: null },
      { id: "v2", parent: "v1" },
      { id: "v3", parent: "v1" },
    ],
  },
};

// --- writers ----------------------------------------------------------------

const writeLf = (path, text) => writeFileSync(path, text, { encoding: "utf8" });

const renderManifest = (name, entries, mutate) => {
  const manifest = {
    schema: "moon-evidence/v0",
    subject: { id: `fixture-${name}`, type: "dataset" },
    hash_algorithm: "sha256",
    files: entries,
    merkle_root: merkleRoot(entries),
    version: { id: "v1", parent: null },
  };
  if (mutate) mutate(manifest);
  return JSON.stringify(manifest, null, 2) + "\n";
};

// Only the managed pack dirs are wiped; README.md in packsRoot is hand-written.
for (const [name, spec] of Object.entries(packs)) {
  const packDir = join(packsRoot, name);
  rmSync(packDir, { recursive: true, force: true });
  mkdirSync(join(packDir, "files"), { recursive: true });
  for (const [relPath, payload] of Object.entries(spec.disk)) {
    const target = join(packDir, relPath);
    mkdirSync(dirname(target), { recursive: true });
    writeFileSync(target, payload);
  }
  writeLf(
    join(packDir, "manifest.json"),
    renderManifest(name, spec.entries, spec.mutate),
  );
  if (spec.chain !== undefined) {
    mkdirSync(join(packDir, "versions"), { recursive: true });
    writeLf(
      join(packDir, "versions", "version_chain.json"),
      JSON.stringify(spec.chain, null, 2) + "\n",
    );
  }
  console.log(`wrote ${name}`);
}
console.log(`packs root: ${packsRoot}`);
