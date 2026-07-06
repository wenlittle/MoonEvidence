// Deterministic malformed-request fuzzing for the JS string adapter.
//
// Run after:
//   moon build --target js --release src/api
//
// The adapter contract is intentionally narrow: every exported function takes
// a JSON string and returns a JSON string. Bad caller input must become an
// `{ ok: false, error: "..." }` response, not a thrown JS exception or a
// non-JSON response.
import {
  audit_append,
  audit_sign,
  audit_verify,
  compute_merkle_tree,
  create_evidence_pack,
  digest_compute,
  ed25519_keypair,
  ed25519_sign,
  ed25519_verify,
  generate_proof,
  verify_evidence,
  verify_proof,
} from "../_build/js/release/build/src/api/api.js";

const exportsUnderTest = [
  ["digest_compute", digest_compute],
  ["verify_evidence", verify_evidence],
  ["compute_merkle_tree", compute_merkle_tree],
  ["create_evidence_pack", create_evidence_pack],
  ["generate_proof", generate_proof],
  ["verify_proof", verify_proof],
  ["audit_append", audit_append],
  ["audit_verify", audit_verify],
  ["audit_sign", audit_sign],
  ["ed25519_keypair", ed25519_keypair],
  ["ed25519_sign", ed25519_sign],
  ["ed25519_verify", ed25519_verify],
];

const args = new Map();
for (let i = 2; i < process.argv.length; i++) {
  if (process.argv[i].startsWith("--")) {
    args.set(process.argv[i], process.argv[i + 1]);
    i++;
  }
}

const rounds = Number.parseInt(args.get("--rounds") ?? "128", 10);
if (!Number.isInteger(rounds) || rounds < 1) {
  throw new Error("--rounds must be a positive integer");
}

let state = 0x9e3779b97f4a7c15n;
function rand64() {
  state = (state + 0x9e3779b97f4a7c15n) & 0xffffffffffffffffn;
  let z = state;
  z = ((z ^ (z >> 30n)) * 0xbf58476d1ce4e5b9n) & 0xffffffffffffffffn;
  z = ((z ^ (z >> 27n)) * 0x94d049bb133111ebn) & 0xffffffffffffffffn;
  return z ^ (z >> 31n);
}

function pick(items) {
  return items[Number(rand64() % BigInt(items.length))];
}

function randomHexLike() {
  const choices = [
    "",
    "0",
    "abc",
    "zz",
    "00zz",
    "0".repeat(63),
    "0".repeat(65),
    "f".repeat(4097),
  ];
  return pick(choices);
}

function randomInvalidHex() {
  return pick(["0", "abc", "zz", "00zz", "0".repeat(63), "f".repeat(4097)]);
}

const nonObjects = [
  "null",
  "true",
  "false",
  "0",
  "[]",
  '"string"',
];

const invalidJson = [
  "",
  "{",
  "{ not json",
  "[1,",
  "\u0000",
];

const junkValues = [
  null,
  true,
  false,
  0,
  1.25,
  [],
  [1],
  {},
  { nested: [] },
  "",
  "not-json",
  randomHexLike,
];

function materialize(value) {
  if (typeof value === "function") {
    return value();
  }
  if (Array.isArray(value)) {
    return value.map(materialize);
  }
  if (value !== null && typeof value === "object") {
    const obj = {};
    for (const [key, child] of Object.entries(value)) {
      obj[key] = materialize(child);
    }
    return obj;
  }
  return value;
}

function objectWith(fields) {
  const obj = {};
  for (const [key, value] of Object.entries(fields)) {
    obj[key] = materialize(value);
  }
  return JSON.stringify(obj);
}

const malformedByExport = {
  digest_compute: [
    {},
    { algorithm: 1, data: "00" },
    { algorithm: "sha256" },
    { algorithm: "sha256", data: randomInvalidHex },
    { algorithm: "hmac-sha256", data: "00" },
    { algorithm: "hmac-sha256", data: "00", key: randomInvalidHex },
    { algorithm: "unknown", data: "00" },
  ],
  verify_evidence: [
    {},
    { manifest: 42 },
    { manifest: "{}", files: "not-object" },
    { manifest: "{}", files: { "files/a.txt": 7 } },
    { manifest: "{}", files: { "files/a.txt": randomInvalidHex } },
    { manifest: "{}", version_chain: [] },
  ],
  compute_merkle_tree: [
    {},
    { manifest: 42 },
    { manifest: "{}", files: [] },
    { manifest: "{}", files: { "files/a.txt": false } },
    { manifest: "{}", files: { "files/a.txt": randomInvalidHex } },
    { manifest: "{ not manifest json" },
  ],
  create_evidence_pack: [
    {},
    { files: null },
    { files: [] },
    { files: { "files/a.txt": 9 } },
    { files: { "files/a.txt": randomInvalidHex } },
    { files: {}, subject: "x", version_id: "v1" },
    { files: {}, subject: { id: 1, type: "dataset" }, version_id: "v1" },
    { files: {}, subject: { id: "x", type: 1 }, version_id: "v1" },
    { files: {}, subject: { id: "x", type: "dataset" }, algorithm: "md5", version_id: "v1" },
    { files: {}, subject: { id: "x", type: "dataset" }, version_id: 1 },
    { files: {}, subject: { id: "x", type: "dataset" }, version_id: "v1", version_parent: 1 },
  ],
  generate_proof: [
    {},
    { manifest: 1, index: 0 },
    { manifest: "{}", files: [], index: 0 },
    { manifest: "{}", files: { "files/a.txt": randomInvalidHex }, index: 0 },
    { manifest: "{}", index: "0" },
    { manifest: "{ not manifest json", index: 0 },
  ],
  verify_proof: [
    {},
    { leaf: 1, proof: [], root: "00" },
    { leaf: randomInvalidHex, proof: [], root: "00" },
    { leaf: "00", proof: "x", root: "00" },
    { leaf: "00", proof: [{ side: "up", sibling: "00" }], root: "00" },
    { leaf: "00", proof: [{ side: "left", sibling: randomInvalidHex }], root: "00" },
    { leaf: "00", proof: [], root: randomInvalidHex },
    { leaf: "00", proof: [], root: "00", algorithm: "md5" },
  ],
  audit_append: [
    {},
    { log: 1, actor: "a", action: "created", subject_id: "s" },
    { log: "{ not log", actor: "a", action: "created", subject_id: "s" },
    { log: "[]", actor: 1, action: "created", subject_id: "s" },
    { log: "[]", actor: "a", action: 1, subject_id: "s" },
    { log: "[]", actor: "a", action: "created", subject_id: 1 },
    { log: "[]", actor: "a", action: "created", subject_id: "s", manifest_digest: [] },
    { log: "[]", actor: "a", action: "created", subject_id: "s", timestamp: [] },
  ],
  audit_verify: [
    {},
    { log: 1 },
    { log: "{ not log" },
    { log: "[]", verify_signatures: true },
    { log: "[]", verify_signatures: true, public_key: randomInvalidHex },
    { log: "[]", verify_signatures: true, public_key: 1 },
  ],
  audit_sign: [
    {},
    { log: 1, secret_key: "00" },
    { log: "{ not log", secret_key: "00" },
    { log: "[]", secret_key: 1 },
    { log: "[]", secret_key: randomInvalidHex },
    { log: "[]", secret_key: "00" },
  ],
  ed25519_keypair: [
    { seed: 1 },
    { seed: randomInvalidHex },
    { seed: "00" },
    { seed: "00".repeat(31) },
    { seed: "00".repeat(33) },
  ],
  ed25519_sign: [
    {},
    { secret_key: 1, message: "00" },
    { secret_key: randomInvalidHex, message: "00" },
    { secret_key: "00", message: "00" },
    { secret_key: "00".repeat(32), message: 1 },
    { secret_key: "00".repeat(32), message: randomInvalidHex },
  ],
  ed25519_verify: [
    {},
    { public_key: 1, message: "00", signature: "00" },
    { public_key: randomInvalidHex, message: "00", signature: "00" },
    { public_key: "00".repeat(31), message: "00", signature: "00".repeat(64) },
    { public_key: "00".repeat(32), message: 1, signature: "00".repeat(64) },
    { public_key: "00".repeat(32), message: randomInvalidHex, signature: "00".repeat(64) },
    { public_key: "00".repeat(32), message: "00", signature: randomInvalidHex },
    { public_key: "00".repeat(32), message: "00", signature: "00".repeat(63) },
  ],
};

function assertEnvelope(name, request, expectedOkFalse = true) {
  let raw;
  try {
    raw = exportsByName.get(name)(request);
  } catch (error) {
    throw new Error(`${name} threw for ${JSON.stringify(request)}: ${error?.stack ?? error}`);
  }
  if (typeof raw !== "string") {
    throw new Error(`${name} returned non-string for ${JSON.stringify(request)}: ${typeof raw}`);
  }
  let parsed;
  try {
    parsed = JSON.parse(raw);
  } catch {
    throw new Error(`${name} returned non-JSON for ${JSON.stringify(request)}: ${raw}`);
  }
  if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed)) {
    throw new Error(`${name} returned non-object JSON for ${JSON.stringify(request)}: ${raw}`);
  }
  if (typeof parsed.ok !== "boolean") {
    throw new Error(`${name} response has no boolean ok for ${JSON.stringify(request)}: ${raw}`);
  }
  if (expectedOkFalse) {
    if (parsed.ok !== false) {
      throw new Error(`${name} accepted malformed request ${JSON.stringify(request)}: ${raw}`);
    }
    if (typeof parsed.error !== "string" || parsed.error.length === 0) {
      throw new Error(`${name} malformed response lacks error string for ${JSON.stringify(request)}: ${raw}`);
    }
  }
}

const exportsByName = new Map(exportsUnderTest);

let cases = 0;
for (const [name] of exportsUnderTest) {
  for (const request of invalidJson) {
    assertEnvelope(name, request);
    cases++;
  }
  for (const request of nonObjects) {
    assertEnvelope(name, request);
    cases++;
  }
  for (const objectCase of malformedByExport[name]) {
    assertEnvelope(name, objectWith(objectCase));
    cases++;
  }
}

for (let round = 0; round < rounds; round++) {
  const [name] = pick(exportsUnderTest);
  const template = pick(malformedByExport[name]);
  const mutated = {};
  for (const key of Object.keys(template)) {
    mutated[key] = pick(junkValues);
  }
  assertEnvelope(name, objectWith(mutated), false);
  cases++;
}

console.log(`MALFORMED API FUZZ PASS: ${cases} cases across ${exportsUnderTest.length} exports (${rounds} random rounds)`);
