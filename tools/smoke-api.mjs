// Smoke check for the browser adapter, mirroring demo/web/index.html's
// request building (hex-encoded bytes, optional version chain). Run from
// the repository root after `moon build --target js --release src/api`:
//
//   node tools/smoke-api.mjs
//
// Covers all 12 exported pub API functions in closed loops:
//   0. digest_compute (SHA-256 / SHA-512 / HMAC-SHA256)
//   1. verify_evidence (golden + tampered + malformed)
//   2. create_evidence_pack → verify_evidence round-trip
//   3. generate_proof → verify_proof round-trip
//   4. audit_append → audit_verify round-trip
//   5. ed25519_keypair → ed25519_sign → ed25519_verify round-trip
//   6. audit_sign → audit_verify with signatures
//
// Exit code 0 on pass, 1 on any unexpected verdict.
import {
  digest_compute,
  verify_evidence,
  create_evidence_pack,
  generate_proof,
  verify_proof,
  audit_append,
  audit_verify,
  audit_sign,
  ed25519_keypair,
  ed25519_sign,
  ed25519_verify,
} from "../_build/js/release/build/src/api/api.js";
import { existsSync, readFileSync } from "node:fs";
import { createHash, createHmac } from "node:crypto";

const hex = (buf) =>
  [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, "0")).join("");

const utf8 = (s) => new TextEncoder().encode(s);

const sha256Hex = (buf) =>
  createHash("sha256").update(buf).digest("hex");

const sha512Hex = (buf) =>
  createHash("sha512").update(buf).digest("hex");

const hmacSha256Hex = (key, buf) =>
  createHmac("sha256", key).update(buf).digest("hex");

///|
/// Build the canonical file entry text (RFC 8785 JCS key order: digest, path, size).
/// Must match `canonical_file_entry_text` in api.mbt so verify_proof receives
/// the exact same bytes generate_proof used to compute the leaf hash.
const canonicalFileEntry = (path, content, algorithm = "sha256") => {
  const digest = createHash(algorithm).update(content).digest("hex");
  return JSON.stringify({
    digest: `${algorithm}:${digest}`,
    path,
    size: content.length,
  });
};

let pass = 0;
let fail = 0;

function check(label, condition, detail = "") {
  if (condition) {
    console.log(`  ✓ ${label}`);
    pass++;
  } else {
    console.log(`  ✗ ${label} ${detail}`);
    fail++;
  }
}

function call(fn, request) {
  return JSON.parse(fn(JSON.stringify(request)));
}

// ---------------------------------------------------------------------------
// digest_compute: SHA-256 / SHA-512 / HMAC-SHA256
// ---------------------------------------------------------------------------
console.log("0. digest_compute");

const digestPayload = utf8("hello world\n");
const digestKey = utf8("smoke key");
const digestSha256 = call(digest_compute, {
  algorithm: "sha256",
  data: hex(digestPayload),
});
check("sha256 succeeds", digestSha256.ok === true, JSON.stringify(digestSha256));
check("sha256 matches Node", digestSha256.digest === sha256Hex(digestPayload));
const digestSha512 = call(digest_compute, {
  algorithm: "sha512",
  data: hex(digestPayload),
});
check("sha512 succeeds", digestSha512.ok === true, JSON.stringify(digestSha512));
check("sha512 matches Node", digestSha512.digest === sha512Hex(digestPayload));
const digestHmac = call(digest_compute, {
  algorithm: "hmac-sha256",
  key: hex(digestKey),
  data: hex(digestPayload),
});
check("hmac-sha256 succeeds", digestHmac.ok === true, JSON.stringify(digestHmac));
check(
  "hmac-sha256 matches Node",
  digestHmac.digest === hmacSha256Hex(digestKey, digestPayload),
);

// ---------------------------------------------------------------------------
// 1. verify_evidence: golden + tampered + malformed
// ---------------------------------------------------------------------------
console.log("1. verify_evidence");

function runPack(pack, expectedManifestDigest) {
  const manifest = readFileSync(`examples/${pack}/manifest.json`, "utf8");
  const request = {
    manifest,
    files: {
      "files/a.txt": hex(readFileSync(`examples/${pack}/files/a.txt`)),
      "files/b.bin": hex(readFileSync(`examples/${pack}/files/b.bin`)),
    },
  };
  const chainPath = `examples/${pack}/versions/version_chain.json`;
  if (existsSync(chainPath)) {
    request.version_chain = readFileSync(chainPath, "utf8");
  }
  if (expectedManifestDigest) {
    request.expected_manifest_digest = expectedManifestDigest;
  }
  return JSON.parse(verify_evidence(JSON.stringify(request)));
}

const goldenManifestDigest =
  "sha256:16bbf1e91de3acfb8bd9091233926b454045c6d96c24327baec20272af583f1e";
const valid = runPack("valid-pack", goldenManifestDigest);
const tampered = runPack("tampered-pack");
const brokenVersionChain = JSON.parse(
  verify_evidence(
    JSON.stringify({
      manifest: readFileSync("examples/valid-pack/manifest.json", "utf8"),
      files: {
        "files/a.txt": hex(readFileSync("examples/valid-pack/files/a.txt")),
        "files/b.bin": hex(readFileSync("examples/valid-pack/files/b.bin")),
      },
      version_chain: '[{"id":"v2","parent":"missing"}]',
    }),
  ),
);
const wrongAnchor = runPack("valid-pack", "sha256:" + "0".repeat(64));
const bad = JSON.parse(verify_evidence("{ not json"));
const malformedAnchor = JSON.parse(
  verify_evidence(
    JSON.stringify({
      manifest: readFileSync("examples/valid-pack/manifest.json", "utf8"),
      expected_manifest_digest: "sha256:ABC",
    }),
  ),
);

check("valid-pack ok", valid.ok === true);
check("tampered-pack fails", tampered.ok === false);
check("tampered has E2003", tampered.report.findings.some((f) => f.code === "E2003"));
check(
  "forwarded version chain reports E4002",
  brokenVersionChain.ok === false &&
    brokenVersionChain.report.findings.some((finding) => finding.code === "E4002"),
  JSON.stringify(brokenVersionChain),
);
check(
  "wrong external anchor has only E2004",
  wrongAnchor.ok === false &&
    wrongAnchor.report.findings.length === 1 &&
    wrongAnchor.report.findings[0].code === "E2004",
);
check("malformed rejected", bad.ok === false);
check("malformed external anchor rejected", malformedAnchor.ok === false);

// ---------------------------------------------------------------------------
// 2. create_evidence_pack → verify_evidence round-trip
// ---------------------------------------------------------------------------
console.log("2. create_evidence_pack → verify_evidence");

const contentHex = hex(utf8("smoke create test"));
const created = call(create_evidence_pack, {
  files: { "files/a.txt": contentHex },
  subject: { id: "smoke-create", type: "dataset" },
  algorithm: "sha256",
  version_id: "v1",
});
check("create succeeds", created.ok === true, JSON.stringify(created));

if (created.ok) {
  const verified = call(verify_evidence, {
    manifest: created.manifest,
    files: { "files/a.txt": contentHex },
  });
  check("created pack verifies ok", verified.ok === true, JSON.stringify(verified));
  check("created pack has 0 findings", verified.report.findings.length === 0);
}

const sha512Content = utf8("smoke sha512 proof");
const sha512ContentHex = hex(sha512Content);
const sha512ContentB = utf8("smoke sha512 sibling");
const sha512Created = call(create_evidence_pack, {
  files: {
    "files/sha512.txt": sha512ContentHex,
    "files/sha512-b.txt": hex(sha512ContentB),
  },
  subject: { id: "smoke-sha512-proof", type: "dataset" },
  algorithm: "sha512",
  version_id: "v1",
});
check("sha512 proof pack create succeeds", sha512Created.ok === true, JSON.stringify(sha512Created));

if (sha512Created.ok) {
  const sha512Proof = call(generate_proof, {
    manifest: sha512Created.manifest,
    index: 0,
  });
  check("sha512 generate_proof succeeds", sha512Proof.ok === true, JSON.stringify(sha512Proof));
  if (sha512Proof.ok) {
    check(
      "sha512 proof uses 64-byte nodes",
      sha512Proof.algorithm === "sha512" &&
        sha512Proof.root.length === 128 &&
        sha512Proof.proof.length > 0 &&
        sha512Proof.proof.every((step) => step.sibling.length === 128),
      JSON.stringify(sha512Proof),
    );
    const sha512Entry = JSON.parse(sha512Created.manifest).files[0];
    const sha512Leaf = hex(
      utf8(
        JSON.stringify({
          digest: sha512Entry.digest,
          path: sha512Entry.path,
          size: sha512Entry.size,
        }),
      ),
    );
    const sha512Verified = call(verify_proof, {
      leaf: sha512Leaf,
      proof: sha512Proof.proof,
      root: sha512Proof.root,
      algorithm: sha512Proof.algorithm,
    });
    check(
      "sha512 verify_proof accepts valid proof",
      sha512Verified.ok === true && sha512Verified.valid === true,
      JSON.stringify(sha512Verified),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. generate_proof → verify_proof round-trip
// ---------------------------------------------------------------------------
console.log("3. generate_proof → verify_proof");

if (created.ok) {
  const proofResp = call(generate_proof, {
    manifest: created.manifest,
    files: { "files/a.txt": contentHex },
    index: 0,
  });
  check("generate_proof succeeds", proofResp.ok === true, JSON.stringify(proofResp));

  if (proofResp.ok) {
    // verify_proof expects the raw leaf payload (canonical file entry text),
    // not the leaf hash. Reconstruct it from the known content.
    const content = utf8("smoke create test");
    const leafHex = hex(utf8(canonicalFileEntry("files/a.txt", content)));
    const verifyResp = call(verify_proof, {
      leaf: leafHex,
      proof: proofResp.proof,
      root: proofResp.root,
    });
    check("verify_proof accepts valid proof", verifyResp.ok === true, JSON.stringify(verifyResp));
    if (verifyResp.ok) {
      check("proof is valid", verifyResp.valid === true);
    }

    // Tamper: wrong content produces a different leaf payload
    const tamperedContent = utf8("tampered-content");
    const tamperedLeafHex = hex(utf8(canonicalFileEntry("files/a.txt", tamperedContent)));
    const tamperedResp = call(verify_proof, {
      leaf: tamperedLeafHex,
      proof: proofResp.proof,
      root: proofResp.root,
    });
    check("verify_proof rejects tampered leaf", tamperedResp.valid === false, JSON.stringify(tamperedResp));
  }
}

// ---------------------------------------------------------------------------
// 4. audit_append → audit_verify round-trip
// ---------------------------------------------------------------------------
console.log("4. audit_append → audit_verify");

const auditResp1 = call(audit_append, {
  log: "[]",
  timestamp: "2026-07-05T10:00:00Z",
  actor: "smoke-tester",
  action: "created",
  subject_id: "smoke-ds-v1",
});
check("first audit_append succeeds", auditResp1.ok === true, JSON.stringify(auditResp1));

if (auditResp1.ok) {
  const auditResp2 = call(audit_append, {
    log: auditResp1.log,
    timestamp: "2026-07-05T11:00:00Z",
    actor: "smoke-verifier",
    action: "verified",
    subject_id: "smoke-ds-v1",
  });
  check("second audit_append succeeds", auditResp2.ok === true, JSON.stringify(auditResp2));

  if (auditResp2.ok) {
    const verifyResp = call(audit_verify, { log: auditResp2.log });
    check("audit_verify succeeds", verifyResp.ok === true, JSON.stringify(verifyResp));
    if (verifyResp.ok) {
      check("chain_valid is true", verifyResp.chain_valid === true);
      check("length is 2", verifyResp.length === 2, `got ${verifyResp.length}`);
    }

    // Tamper: change actor in the log
    const tamperedLog = auditResp2.log.replace("smoke-tester", "attacker");
    const tamperedResp = call(audit_verify, { log: tamperedLog });
    check("audit_verify detects tampered log", tamperedResp.chain_valid === false, JSON.stringify(tamperedResp));
  }
}

// ---------------------------------------------------------------------------
// 5. ed25519_keypair → ed25519_sign → ed25519_verify round-trip
// ---------------------------------------------------------------------------
console.log("5. ed25519_keypair → ed25519_sign → ed25519_verify");

const seedHex = hex(new Uint8Array(32).fill(0).map((_, i) => i + 1));
const kpResp = call(ed25519_keypair, { seed: seedHex });
check("keypair succeeds", kpResp.ok === true, JSON.stringify(kpResp));

if (kpResp.ok) {
  check("has public_key", typeof kpResp.public_key === "string");
  check("has secret_key", typeof kpResp.secret_key === "string");

  const msgHex = hex(utf8("smoke sign test"));
  const signResp = call(ed25519_sign, {
    secret_key: kpResp.secret_key,
    message: msgHex,
  });
  check("sign succeeds", signResp.ok === true, JSON.stringify(signResp));

  if (signResp.ok) {
    const verifyResp = call(ed25519_verify, {
      public_key: kpResp.public_key,
      message: msgHex,
      signature: signResp.signature,
    });
    check("verify accepts valid signature", verifyResp.valid === true, JSON.stringify(verifyResp));

    // Tamper: wrong message
    const wrongMsg = hex(utf8("tampered"));
    const tamperedResp = call(ed25519_verify, {
      public_key: kpResp.public_key,
      message: wrongMsg,
      signature: signResp.signature,
    });
    check("verify rejects wrong message", tamperedResp.valid === false, JSON.stringify(tamperedResp));
  }
}

// Demo seed warning
const demoKp = call(ed25519_keypair, {});
check("demo keypair has warning", typeof demoKp.warning === "string", JSON.stringify(demoKp));

// ---------------------------------------------------------------------------
// 6. audit_sign → audit_verify with signatures
// ---------------------------------------------------------------------------
console.log("6. audit_sign → audit_verify with signatures");

if (kpResp.ok) {
  // Create a fresh audit log for signing.
  const signAuditResp = call(audit_append, {
    log: "[]",
    timestamp: "2026-07-05T12:00:00Z",
    actor: "audit-signer",
    action: "sealed",
    subject_id: "smoke-ds-v1",
  });
  check("audit_append for signing succeeds", signAuditResp.ok === true, JSON.stringify(signAuditResp));

  if (signAuditResp.ok) {
    // Sign the last entry with the keypair from section 5.
    const signResp = call(audit_sign, {
      log: signAuditResp.log,
      secret_key: kpResp.secret_key,
    });
    check("audit_sign succeeds", signResp.ok === true, JSON.stringify(signResp));

    if (signResp.ok) {
      // Verify with valid signatures.
      const sigVerifyResp = call(audit_verify, {
        log: signResp.log,
        verify_signatures: true,
        public_key: kpResp.public_key,
      });
      check("audit_verify signatures_valid is true", sigVerifyResp.signatures_valid === true, JSON.stringify(sigVerifyResp));

      // Tamper: prepend "zz" to the signature hex (invalid hex chars).
      const tamperedLog = signResp.log.replace(/("signature":")([0-9a-f])/, '$1zz$2');
      const tamperedSigResp = call(audit_verify, {
        log: tamperedLog,
        verify_signatures: true,
        public_key: kpResp.public_key,
      });
      check("audit_verify detects tampered signature", tamperedSigResp.signatures_valid === false, JSON.stringify(tamperedSigResp));
    }
  }
}

// ---------------------------------------------------------------------------
// Summary
// ---------------------------------------------------------------------------
console.log("");
console.log(`SMOKE: ${pass} passed, ${fail} failed`);
if (fail > 0) {
  console.log("SMOKE FAIL");
  process.exit(1);
} else {
  console.log("SMOKE PASS");
}
