// Independent cross-verification of evidence packs, written in Node.js so
// the MoonBit create/store/audit pipeline is checked against a second
// implementation rather than validating itself.
//
// The MoonBit suite already verifies packs, but every verifier path shares
// the same MoonBit SHA-256, JCS canonicalization and Merkle code that
// produced the seals. A bug in any of those primitives would be invisible
// to `moon test`. This script recomputes everything with `node:crypto` and
// a hand-rolled RFC 6962 Merkle builder, then compares against the values
// sealed in the manifest:
//
//   1. Per-file SHA-256: rehash every file on disk under <pack>/files/ and
//      compare to manifest.files[].digest.
//   2. Merkle root: rebuild the tree from canonical file-entry JSON with
//      RFC 6962 domain separation (leaf = SHA256(0x00 || data),
//      node = SHA256(0x01 || left || right), unpaired nodes promoted) and
//      compare to manifest.merkle_root.
//   3. Pack sweep: run both checks against every golden pack under
//      tests/fixtures/packs/ and emit a per-pack PASS/FAIL report.
//
// Usage:
//   node tools/cross-verify.mjs                       # sweep all golden packs
//   node tools/cross-verify.mjs <pack-dir>            # verify one pack dir
//   node tools/cross-verify.mjs <manifest.json>       # verify a lone manifest
//
// Exit code: 0 if every checked pack passed, 1 if any check failed.

import { createHash } from "node:crypto";
import { readFileSync, readdirSync, statSync, existsSync } from "node:fs";
import { join, dirname, basename, resolve } from "node:path";
import { fileURLToPath } from "node:url";

// ---------------------------------------------------------------------------
// Independent crypto primitives (no MoonBit code involved)
// ---------------------------------------------------------------------------

const sha256 = (...chunks) => {
  const hash = createHash("sha256");
  for (const chunk of chunks) hash.update(chunk);
  return hash.digest();
};

const hex = (buffer) => buffer.toString("hex");
const digestOf = (bytes) => `sha256:${hex(sha256(bytes))}`;

// RFC 6962 domain separation, matching the frozen spec:
//   leaf  = SHA256(0x00 || data)
//   node  = SHA256(0x01 || left || right)
//   unpaired nodes at the tail of a level are promoted as-is (no self-pairing).
const leafHash = (data) => sha256(Buffer.from([0x00]), data);
const nodeHash = (left, right) => sha256(Buffer.from([0x01]), left, right);

// Canonical files[] entry rendering, matching the spec's leaf payload:
// keys sorted by UTF-16 code-unit order (digest < path < size), compact
// separators - RFC 8785 for this ASCII-only, integer-only payload.
const canonicalEntry = (entry) =>
  JSON.stringify({
    digest: entry.digest,
    path: entry.path,
    size: entry.size,
  });

const merkleRoot = (entries) => {
  if (entries.length === 0) return null;
  let level = entries.map((e) =>
    leafHash(Buffer.from(canonicalEntry(e), "utf8")),
  );
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

// ---------------------------------------------------------------------------
// Verification primitives
// ---------------------------------------------------------------------------

// Recompute SHA-256 for every file listed in the manifest and compare to
// the sealed digest. Returns one record per entry plus an overall flag.
const verifyFileDigests = (manifest, packRoot) => {
  const results = [];
  let allMatch = true;
  for (const entry of manifest.files) {
    const filePath = join(packRoot, entry.path);
    if (!existsSync(filePath)) {
      results.push({
        path: entry.path,
        status: "missing",
        expected: entry.digest,
        actual: null,
      });
      allMatch = false;
      continue;
    }
    const bytes = readFileSync(filePath);
    const actual = digestOf(bytes);
    const match = actual === entry.digest;
    if (!match) allMatch = false;
    // Also cross-check the size field while we have the bytes: a mismatch
    // here would mean the manifest lies about payload length even when the
    // digest happens to align (it cannot for SHA-256, but the check is
    // cheap and catches truncation bugs in fixture generators).
    const sizeMatch = bytes.length === entry.size;
    if (!sizeMatch) allMatch = false;
    results.push({
      path: entry.path,
      status: match && sizeMatch ? "match" : "mismatch",
      expected: entry.digest,
      actual,
      sizeExpected: entry.size,
      sizeActual: bytes.length,
    });
  }
  return { allMatch, results };
};

// Rebuild the Merkle root from the manifest's own file entries (NOT from
// file bytes - the tree attests the sealed entries) and compare to the
// recorded merkle_root field. Returns null when the manifest omits a root.
const verifyMerkleRoot = (manifest) => {
  if (!manifest.merkle_root) {
    return { status: "absent", expected: null, actual: null, match: false };
  }
  const recomputed = merkleRoot(manifest.files);
  if (recomputed === null) {
    return {
      status: "empty-files",
      expected: manifest.merkle_root,
      actual: null,
      match: false,
    };
  }
  const match = recomputed === manifest.merkle_root;
  return {
    status: match ? "match" : "mismatch",
    expected: manifest.merkle_root,
    actual: recomputed,
    match,
  };
};

// ---------------------------------------------------------------------------
// Driver
// ---------------------------------------------------------------------------

const verifyPackDir = (packDir) => {
  const manifestPath = join(packDir, "manifest.json");
  if (!existsSync(manifestPath)) {
    return { pack: basename(packDir), ok: false, error: "manifest.json not found" };
  }
  let manifest;
  try {
    manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
  } catch (error) {
    return {
      pack: basename(packDir),
      ok: false,
      error: `manifest.json is not valid JSON: ${error.message}`,
    };
  }
  const digestReport = verifyFileDigests(manifest, packDir);
  const merkleReport = verifyMerkleRoot(manifest);
  const ok = digestReport.allMatch && merkleReport.match;
  return {
    pack: basename(packDir),
    ok,
    digest: digestReport,
    merkle: merkleReport,
  };
};

// A lone manifest file (no pack dir): still recompute the Merkle root from
// the manifest entries; per-file digests cannot be checked without the
// files/ tree, so we report them as "skipped".
const verifyManifestFile = (manifestPath) => {
  let manifest;
  try {
    manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
  } catch (error) {
    return {
      manifest: basename(manifestPath),
      ok: false,
      error: `not valid JSON: ${error.message}`,
    };
  }
  const merkleReport = verifyMerkleRoot(manifest);
  return {
    manifest: basename(manifestPath),
    ok: merkleReport.match,
    digest: { allMatch: null, results: [], skipped: true },
    merkle: merkleReport,
  };
};

const formatDigestResult = (r) => {
  if (r.status === "missing") {
    return `    ${r.path}: MISSING (expected ${r.expected})`;
  }
  if (r.status === "match") {
    return `    ${r.path}: OK (${r.expected})`;
  }
  const sizeNote =
    r.sizeExpected !== r.sizeActual
      ? ` [size expected ${r.sizeExpected}, got ${r.sizeActual}]`
      : "";
  return `    ${r.path}: MISMATCH${sizeNote}
      expected: ${r.expected}
      actual:   ${r.actual}`;
};

const printReport = (report) => {
  const label = report.pack ?? report.manifest;
  const verdict = report.ok ? "PASS" : "FAIL";
  console.log(`${verdict}  ${label}`);
  if (report.error) {
    console.log(`    error: ${report.error}`);
    return;
  }
  if (report.digest?.skipped) {
    console.log("    digests: skipped (lone manifest, no files/ tree)");
  } else {
    console.log(
      `    digests: ${report.digest.allMatch ? "all match" : "mismatch detected"}`,
    );
    for (const r of report.digest.results) console.log(formatDigestResult(r));
  }
  const m = report.merkle;
  if (m.status === "absent") {
    console.log("    merkle: absent (manifest has no merkle_root)");
  } else if (m.status === "empty-files") {
    console.log(
      `    merkle: empty files[] (expected ${m.expected}, nothing to recompute)`,
    );
  } else if (m.status === "match") {
    console.log(`    merkle: OK (${m.expected})`);
  } else {
    console.log(`    merkle: MISMATCH`);
    console.log(`      expected: ${m.expected}`);
    console.log(`      actual:   ${m.actual}`);
  }
};

const listPackDirs = (packsRoot) =>
  readdirSync(packsRoot)
    .filter((name) => {
      const full = join(packsRoot, name);
      return statSync(full).isDirectory() && existsSync(join(full, "manifest.json"));
    })
    .map((name) => join(packsRoot, name))
    .sort();

const main = (argv) => {
  const repoRoot = join(dirname(fileURLToPath(import.meta.url)), "..");
  const packsRoot = join(repoRoot, "tests", "fixtures", "packs");

  const targets = [];
  for (const arg of argv) {
    const full = resolve(process.cwd(), arg);
    if (!existsSync(full)) {
      console.error(`error: path not found: ${arg}`);
      return 1;
    }
    if (statSync(full).isDirectory()) {
      targets.push({ kind: "pack", path: full });
    } else {
      targets.push({ kind: "manifest", path: full });
    }
  }
  if (targets.length === 0) {
    if (!existsSync(packsRoot)) {
      console.error(`error: packs root not found: ${packsRoot}`);
      return 1;
    }
    for (const dir of listPackDirs(packsRoot)) {
      targets.push({ kind: "pack", path: dir });
    }
    console.log(`cross-verify: sweeping ${targets.length} pack(s) under ${packsRoot}`);
    console.log("");
  }

  let failures = 0;
  for (const target of targets) {
    const report =
      target.kind === "pack"
        ? verifyPackDir(target.path)
        : verifyManifestFile(target.path);
    printReport(report);
    if (!report.ok) failures += 1;
  }

  console.log("");
  const total = targets.length;
  console.log(`cross-verify: ${total - failures}/${total} passed`);
  return failures > 0 ? 1 : 0;
};

process.exit(main(process.argv.slice(2)));
