// Deterministic semantic property checks for the public JS adapter.
//
// Run after:
//   moon build --target js --release src/api
//
// Unlike fuzz-api-malformed.mjs, this script feeds valid but varied requests
// through closed loops and checks semantic invariants:
//   create -> verify -> materialize tree -> proof -> verify proof
//   audit append chain -> verify -> tamper rejection -> sign -> signature rejection
//   Ed25519 keypair -> sign -> verify -> tamper rejection
import {
  audit_append,
  audit_sign,
  audit_verify,
  compute_merkle_tree,
  create_evidence_pack,
  ed25519_keypair,
  ed25519_sign,
  ed25519_verify,
  generate_proof,
  verify_evidence,
  verify_proof,
} from "../_build/js/release/build/src/api/api.js";

const args = new Map();
for (let i = 2; i < process.argv.length; i++) {
  if (process.argv[i].startsWith("--")) {
    args.set(process.argv[i], process.argv[i + 1]);
    i++;
  }
}

const rounds = Number.parseInt(args.get("--rounds") ?? "64", 10);
if (!Number.isInteger(rounds) || rounds < 1) {
  throw new Error("--rounds must be a positive integer");
}

let state = 0x6d6f6f6e65766964n;
function rand64() {
  state = (state + 0x9e3779b97f4a7c15n) & 0xffffffffffffffffn;
  let z = state;
  z = ((z ^ (z >> 30n)) * 0xbf58476d1ce4e5b9n) & 0xffffffffffffffffn;
  z = ((z ^ (z >> 27n)) * 0x94d049bb133111ebn) & 0xffffffffffffffffn;
  return z ^ (z >> 31n);
}

function randInt(maxExclusive) {
  return Number(rand64() % BigInt(maxExclusive));
}

function randomBytes(length) {
  const out = new Uint8Array(length);
  for (let i = 0; i < out.length; i++) {
    out[i] = Number(rand64() & 0xffn);
  }
  return out;
}

function hex(bytes) {
  return [...bytes].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function utf8(text) {
  return new TextEncoder().encode(text);
}

function call(fn, request, label) {
  const raw = fn(JSON.stringify(request));
  let parsed;
  try {
    parsed = JSON.parse(raw);
  } catch {
    throw new Error(`${label} returned non-JSON: ${raw}`);
  }
  if (parsed === null || typeof parsed !== "object" || typeof parsed.ok !== "boolean") {
    throw new Error(`${label} returned invalid envelope: ${raw}`);
  }
  return parsed;
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function canonicalFileEntryHex(entry) {
  const canonical = JSON.stringify({
    digest: entry.digest,
    path: entry.path,
    size: entry.size,
  });
  return hex(utf8(canonical));
}

function buildFiles(round) {
  const fileCount = randInt(6); // includes empty-pack boundary
  const files = {};
  for (let i = 0; i < fileCount; i++) {
    const path = `files/r${round}-${i}-${randInt(1000)}.bin`;
    const size = [0, 1, 2, 31, 32, 55, 56, 63, 64, 65, 127, 128, 129, randInt(300)][randInt(14)];
    files[path] = hex(randomBytes(size));
  }
  return files;
}

function checkCreateVerifyProofRound(round) {
  const algorithm = round % 2 === 0 ? "sha256" : "sha512";
  const files = buildFiles(round);
  const createResp = call(create_evidence_pack, {
    files,
    subject: { id: `semantic-${round}`, type: round % 3 === 0 ? "dataset" : "archive" },
    algorithm,
    version_id: `v${round}`,
    version_parent: round % 4 === 0 ? `v${round - 1}` : null,
  }, `create round ${round}`);
  assert(createResp.ok === true, `create failed round ${round}: ${JSON.stringify(createResp)}`);

  const verifyResp = call(verify_evidence, {
    manifest: createResp.manifest,
    files,
  }, `verify round ${round}`);
  assert(verifyResp.ok === true, `created pack did not verify round ${round}: ${JSON.stringify(verifyResp)}`);
  assert(verifyResp.report.findings.length === 0, `created pack had findings round ${round}`);

  const manifest = JSON.parse(createResp.manifest);
  const treeResp = call(compute_merkle_tree, {
    manifest: createResp.manifest,
    files,
  }, `tree round ${round}`);
  assert(treeResp.ok === true, `tree failed round ${round}: ${JSON.stringify(treeResp)}`);
  if (manifest.files.length === 0) {
    assert(manifest.merkle_root === null, `empty manifest should have null merkle root round ${round}`);
    assert(treeResp.tree.root === null, `empty tree should report null root round ${round}`);
    return;
  }
  assert(treeResp.tree.root.matches === true, `tree root should match manifest round ${round}`);
  assert(treeResp.tree.root.recorded === manifest.merkle_root, `recorded root mismatch round ${round}`);

  const index = randInt(manifest.files.length);
  const proofResp = call(generate_proof, {
    manifest: createResp.manifest,
    files,
    index,
  }, `generate proof round ${round}`);
  assert(proofResp.ok === true, `proof generation failed round ${round}: ${JSON.stringify(proofResp)}`);
  assert(proofResp.root === manifest.merkle_root.split(":")[1], `proof root mismatch round ${round}`);

  const leafHex = canonicalFileEntryHex(manifest.files[index]);
  const verifyProofResp = call(verify_proof, {
    leaf: leafHex,
    proof: proofResp.proof,
    root: proofResp.root,
    algorithm: proofResp.algorithm,
  }, `verify proof round ${round}`);
  assert(verifyProofResp.ok === true && verifyProofResp.valid === true, `proof did not verify round ${round}`);

  const tamperedLeaf = canonicalFileEntryHex({
    ...manifest.files[index],
    digest: manifest.files[index].digest.replace(/[0-9a-f]$/, (c) => (c === "0" ? "1" : "0")),
  });
  const tamperedProofResp = call(verify_proof, {
    leaf: tamperedLeaf,
    proof: proofResp.proof,
    root: proofResp.root,
    algorithm: proofResp.algorithm,
  }, `verify tampered proof round ${round}`);
  assert(tamperedProofResp.ok === true && tamperedProofResp.valid === false, `tampered proof accepted round ${round}`);
}

function checkAuditRound(round) {
  let log = "[]";
  const length = 1 + randInt(5);
  for (let i = 0; i < length; i++) {
    const resp = call(audit_append, {
      log,
      timestamp: `2026-07-06T00:00:${String(i).padStart(2, "0")}Z`,
      actor: `actor-${round}-${i}`,
      action: ["created", "verified", "sealed", `custom-${i}`][i % 4],
      subject_id: `subject-${round}`,
      manifest_digest: i % 2 === 0 ? `sha256:${"0".repeat(63)}${i % 10}` : null,
    }, `audit append round ${round}.${i}`);
    assert(resp.ok === true, `audit append failed round ${round}.${i}`);
    log = resp.log;
  }

  const verifyResp = call(audit_verify, { log }, `audit verify round ${round}`);
  assert(verifyResp.ok === true, `audit verify failed round ${round}`);
  assert(verifyResp.chain_valid === true, `audit chain invalid round ${round}`);
  assert(verifyResp.length === length, `audit length mismatch round ${round}`);

  const tampered = log.replace(`actor-${round}-0`, `attacker-${round}`);
  const tamperedResp = call(audit_verify, { log: tampered }, `audit tamper round ${round}`);
  assert(tamperedResp.ok === true && tamperedResp.chain_valid === false, `tampered audit chain accepted round ${round}`);

  const keypair = call(ed25519_keypair, { seed: hex(randomBytes(32)) }, `audit keypair round ${round}`);
  assert(keypair.ok === true, `audit keypair failed round ${round}`);
  const signedResp = call(audit_sign, {
    log,
    secret_key: keypair.secret_key,
  }, `audit sign round ${round}`);
  assert(signedResp.ok === true, `audit sign failed round ${round}: ${JSON.stringify(signedResp)}`);

  const signatureVerifyResp = call(audit_verify, {
    log: signedResp.log,
    verify_signatures: true,
    public_key: keypair.public_key,
  }, `audit signature verify round ${round}`);
  assert(signatureVerifyResp.ok === true, `signed audit verify failed round ${round}`);
  assert(signatureVerifyResp.chain_valid === true, `signed audit chain invalid round ${round}`);
  assert(signatureVerifyResp.signatures_valid === true, `signed audit signature invalid round ${round}`);

  const tamperedSignedLog = signedResp.log.replace(/("signature":")([0-9a-f])/, "$1ff$2");
  const tamperedSignatureResp = call(audit_verify, {
    log: tamperedSignedLog,
    verify_signatures: true,
    public_key: keypair.public_key,
  }, `audit signature tamper round ${round}`);
  assert(
    tamperedSignatureResp.ok === true && tamperedSignatureResp.signatures_valid === false,
    `tampered audit signature accepted round ${round}`,
  );
}

function checkEd25519Round(round) {
  const seed = randomBytes(32);
  const message = randomBytes(randInt(256));
  const keypair = call(ed25519_keypair, { seed: hex(seed) }, `keypair round ${round}`);
  assert(keypair.ok === true, `keypair failed round ${round}`);
  const signed = call(ed25519_sign, {
    secret_key: keypair.secret_key,
    message: hex(message),
  }, `sign round ${round}`);
  assert(signed.ok === true, `sign failed round ${round}`);
  const verified = call(ed25519_verify, {
    public_key: keypair.public_key,
    message: hex(message),
    signature: signed.signature,
  }, `verify sig round ${round}`);
  assert(verified.ok === true && verified.valid === true, `signature did not verify round ${round}`);
  if (message.length > 0) message[0] ^= 0x01;
  const tampered = call(ed25519_verify, {
    public_key: keypair.public_key,
    message: hex(message.length > 0 ? message : Uint8Array.of(1)),
    signature: signed.signature,
  }, `verify tampered sig round ${round}`);
  assert(tampered.ok === true && tampered.valid === false, `tampered signature accepted round ${round}`);
}

let checks = 0;
for (let round = 0; round < rounds; round++) {
  checkCreateVerifyProofRound(round);
  checks++;
  checkAuditRound(round);
  checks++;
  checkEd25519Round(round);
  checks++;
}

console.log(`API SEMANTIC PROPERTY PASS: ${checks} closed-loop checks across ${rounds} rounds`);
