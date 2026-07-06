// Wycheproof Ed25519 vector guard.
//
// The MoonBit test file embeds a hand-ported subset of Google Wycheproof's
// Ed25519 vectors. This guard checks the embedded vector inventory so future
// edits cannot silently drop a case or skew an attack category.
//
// Usage:
//   node tools/check-wycheproof-ed25519.mjs

import { readFileSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), "..");
const testPath = join(
  repoRoot,
  "src",
  "crypto",
  "ed25519_wycheproof_wbtest.mbt",
);

const expected = {
  valid: 88,
  invalid: 62,
  categories: {
    InvalidSignature: 20,
    TruncatedSignature: 3,
    SignatureWithGarbage: 5,
    CompressedSignature: 4,
    InvalidEncoding: 21,
    SignatureMalleability: 8,
    InvalidKtv: 1,
  },
};

const source = readFileSync(testPath, "utf8");

function extractCasesBlock(testTitle) {
  const testIndex = source.indexOf(`test "${testTitle}"`);
  if (testIndex < 0) throw new Error(`test not found: ${testTitle}`);
  const casesIndex = source.indexOf("let cases = [", testIndex);
  if (casesIndex < 0) throw new Error(`cases array not found: ${testTitle}`);
  const endIndex = source.indexOf("\n  ]", casesIndex);
  if (endIndex < 0) throw new Error(`cases array end not found: ${testTitle}`);
  return source.slice(casesIndex, endIndex);
}

function tupleLines(block) {
  return block
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => line.startsWith('("'));
}

function parseTuple(line) {
  const json = `[${line.replace(/^\(/, "").replace(/\),?$/, "")}]`;
  return JSON.parse(json);
}

function assertEqual(label, actual, want) {
  if (actual !== want) {
    throw new Error(`${label}: got ${actual}, expected ${want}`);
  }
}

const validLines = tupleLines(
  extractCasesBlock("wycheproof: all 88 valid vectors verify (independent oracle)"),
);
const invalidLines = tupleLines(
  extractCasesBlock("wycheproof: all 62 invalid vectors rejected (attack oracle)"),
);

assertEqual("valid vector count", validLines.length, expected.valid);
assertEqual("invalid vector count", invalidLines.length, expected.invalid);

const categories = new Map();
for (const line of invalidLines) {
  const tuple = parseTuple(line);
  const category = tuple[4];
  categories.set(category, (categories.get(category) || 0) + 1);
}

for (const [category, count] of Object.entries(expected.categories)) {
  assertEqual(`category ${category}`, categories.get(category) || 0, count);
}

const unexpected = [...categories.keys()].filter(
  (category) => !(category in expected.categories),
);
if (unexpected.length > 0) {
  throw new Error(`unexpected categories: ${unexpected.join(", ")}`);
}

const total = validLines.length + invalidLines.length;
assertEqual("total vector count", total, expected.valid + expected.invalid);

console.log(
  `Wycheproof Ed25519 guard PASS: ${total} vectors ` +
    `(${validLines.length} valid + ${invalidLines.length} invalid)`,
);
for (const [category, count] of Object.entries(expected.categories)) {
  console.log(`  ${category}: ${count}`);
}
