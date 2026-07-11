// Mutation-check harness for the property tests.
//
// Property tests only earn their keep if they actually go red when the
// implementation drifts from the spec. Doing that check by hand every
// release is unsustainable, so this script automates it: for each
// declared mutation it rewrites one source byte, runs the test suite,
// confirms at least one test failed, then restores the original byte -
// even on error - so the working tree is never left mutated.
//
// Each mutation is a surgical, byte-accurate change to a production
// source file (never a test file). The harness records:
//   - whether the mutation applied cleanly,
//   - whether `moon test` went red,
//   - a snippet of the failing test output so the report is self-auditing.
//
// Usage:
//   node tools/mutation-check.mjs            # run all declared mutations
//   node tools/mutation-check.mjs --merkle   # run only the merkle mutations
//
// Exit code: 0 when every mutation was caught (tests went red),
//            1 when a mutation slipped through (tests stayed green) or
//              the harness could not apply/restore a mutation safely.

import { execFileSync } from "node:child_process";
import { readFileSync, writeFileSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), "..");

// Each mutation targets a single, spec-load-bearing line. The `find`
// string must occur exactly once in the file so the rewrite is
// unambiguous; the harness asserts that before touching the file.
const mutations = [
  {
    id: "merkle-leaf-prefix",
    label: "merkle leaf domain separator 0x00 -> 0x01",
    file: join(repoRoot, "src", "merkle", "merkle.mbt"),
    find: 'Sha256Ctx::new()\n      ctx.update(b"\\x00")\n      ctx.update(data)',
    replace: 'Sha256Ctx::new()\n      ctx.update(b"\\x01")\n      ctx.update(data)',
    // Flips the RFC 6962 leaf prefix in the Sha256 branch. The property test
    // "leaf hash uses 0x00 domain separator, node hash uses 0x01"
    // recomputes the expected leaf independently and must fail.
    expectHint: "0x00 domain separator",
  },
  {
    id: "merkle-node-prefix",
    label: "merkle node domain separator 0x01 -> 0x00",
    file: join(repoRoot, "src", "merkle", "merkle.mbt"),
    find: 'Sha256Ctx::new()\n      ctx.update(b"\\x01")\n      ctx.update(left)',
    replace: 'Sha256Ctx::new()\n      ctx.update(b"\\x00")\n      ctx.update(left)',
    // Collapses leaf and node domains in the Sha256 branch - the same
    // property test also pins the node prefix to 0x01, so this mutation
    // must be caught.
    expectHint: "0x01 domain separator",
  },
  {
    id: "merkle-sha512-leaf-prefix",
    label: "merkle SHA-512 leaf domain separator 0x00 -> 0x01",
    file: join(repoRoot, "src", "merkle", "merkle.mbt"),
    find: '@digest.Sha512 => {\n      let ctx = @digest.Sha512Ctx::new()\n      ctx.update(b"\\x00")\n      ctx.update(data)',
    replace: '@digest.Sha512 => {\n      let ctx = @digest.Sha512Ctx::new()\n      ctx.update(b"\\x01")\n      ctx.update(data)',
    // Guards the multi-algorithm branch added for SHA-512. SHA-256 prefix
    // mutations do not prove that the SHA-512 branch uses the same RFC 6962
    // leaf domain separation.
    expectHint: "SHA-512 leaf 0x00 domain separator",
  },
  {
    id: "merkle-sha512-node-prefix",
    label: "merkle SHA-512 node domain separator 0x01 -> 0x00",
    file: join(repoRoot, "src", "merkle", "merkle.mbt"),
    find: '@digest.Sha512 => {\n      let ctx = @digest.Sha512Ctx::new()\n      ctx.update(b"\\x01")\n      ctx.update(left)',
    replace: '@digest.Sha512 => {\n      let ctx = @digest.Sha512Ctx::new()\n      ctx.update(b"\\x00")\n      ctx.update(left)',
    // Same invariant as the SHA-256 node mutation, but on the SHA-512 branch
    // used by the newer boundary tree tests.
    expectHint: "SHA-512 node 0x01 domain separator",
  },
  {
    id: "merkle-self-pair",
    label: "odd node promoted via self-pairing (CVE-2012-2459 regression)",
    file: join(repoRoot, "src", "merkle", "merkle.mbt"),
    find: "    if index < level.length() {\n      // Odd node out: promote unchanged (never self-pair, CVE-2012-2459).\n      next.push(level[index])\n    }",
    replace: "    if index < level.length() {\n      // MUTANT: self-pair the odd node instead of promoting it.\n      next.push(node_hash(level[index], level[index]))\n    }",
    // The property "unpaired nodes are promoted unchanged" asserts the
    // root of [a, b, c] equals node_hash(node_hash(a, b), leaf_hash(c));
    // self-pairing c would change that root.
    expectHint: "unpaired nodes are promoted",
  },
  {
    id: "merkle-tree-self-pair",
    label: "materialized merkle tree odd node promoted via self-pairing",
    file: join(repoRoot, "src", "merkle", "merkle.mbt"),
    find: "    if index < current.length() {\n      // Odd node out: promote unchanged (never self-pair, CVE-2012-2459).\n      next.push(current[index])\n    }",
    replace: "    if index < current.length() {\n      // MUTANT: self-pair the odd node instead of promoting it.\n      next.push(node_hash(current[index], current[index], algorithm=algo))\n    }",
    // compute_tree is a separate materialization path for visualization/API
    // callers. It must keep the same odd-node promotion invariant as
    // compute_root; otherwise the displayed tree can disagree with the root.
    expectHint: "materialized tree root equals compute_root",
  },
  {
    id: "ed25519-canonical-s",
    label: "ed25519 canonical S check inverted (!scalar_lt_l -> scalar_lt_l)",
    file: join(repoRoot, "src", "crypto", "ed25519.mbt"),
    find: "  if !scalar_lt_l(s_enc) {\n    return false\n  }",
    replace: "  if scalar_lt_l(s_enc) {\n    return false\n  }",
    // Flips the RFC 8032 §8.4 S < l check: valid signatures (S < l) are
    // now rejected, while malleable ones (S >= l) slip through. Both
    // the RFC KAT tests and the malleability tests must go red.
    expectHint: "S < l canonical encoding check",
  },
  {
    id: "ed25519-low-order-reject",
    label: "ed25519 low-order point rejection removed (cofactor=8 torsion)",
    file: join(repoRoot, "src", "crypto", "ed25519.mbt"),
    find: "  let a_doubled = a_point.double().double().double()\n  if a_doubled.is_identity() {\n    return false\n  }",
    replace: "  let a_doubled = a_point.double().double().double()\n  if a_doubled.is_identity() {\n    ()\n  }",
    // The 8*A check rejects all 8 small-order points (cofactor=8 torsion).
    // Without it, an attacker using a low-order public key (e.g. (0,-1))
    // can forge signatures with ~50% success probability per attempt.
    // The low-order point test must go red.
    expectHint: "low-order point (cofactor=8) rejection",
  },
  {
    id: "ed25519-noncanonical-y",
    label: "ed25519 non-canonical y rejection removed (RFC 8032 §5.1.3)",
    file: join(repoRoot, "src", "crypto", "ed25519.mbt"),
    find: "  let y_original = Bytes::from_array(y_arr)\n  if y_original != y.to_bytes() {\n    return None\n  }",
    replace: "  let y_original = Bytes::from_array(y_arr)\n  if y_original != y.to_bytes() {\n    ()\n  }",
    // Non-canonical y (y >= p) is no longer rejected by point_decode.
    // The round-trip check test that feeds y = p must go red.
    expectHint: "non-canonical y round-trip check",
  },
  {
    id: "hmac-ipad-constant",
    label: "hmac ipad constant bit-flipped (0x36 -> 0x37)",
    file: join(repoRoot, "src", "digest", "hmac.mbt"),
    find: "  let ipad_key = xor_pad(k_prime, 0x36)",
    replace: "  let ipad_key = xor_pad(k_prime, 0x37)",
    // HMAC is not just SHA(key || message): RFC 2104 depends on the exact
    // ipad/opad constants. The RFC vectors must catch a one-bit drift.
    expectHint: "RFC 2104 ipad constant",
  },
  {
    id: "hmac-opad-constant",
    label: "hmac opad constant bit-flipped (0x5c -> 0x5d)",
    file: join(repoRoot, "src", "digest", "hmac.mbt"),
    find: "  let opad_key = xor_pad(k_prime, 0x5c)",
    replace: "  let opad_key = xor_pad(k_prime, 0x5d)",
    // Complements the ipad mutation so both HMAC pads are falsified directly.
    expectHint: "RFC 2104 opad constant",
  },
  {
    id: "sha256-initial-h0",
    label: "sha256 initial hash H0 bit-flipped (0x6a09e667 -> 0x6a09e668)",
    file: join(repoRoot, "src", "digest", "sha256.mbt"),
    find: "0x6a09e667U, 0xbb67ae85U",
    replace: "0x6a09e668U, 0xbb67ae85U",
    // Flips the LSB of the first FIPS 180-4 §5.3.3 initial value.
    // The NIST "abc" KAT must produce a different digest.
    expectHint: "FIPS 180-4 initial hash state",
  },
  {
    id: "sha256-round-k0",
    label: "sha256 round constant K0 bit-flipped (0x428a2f98 -> 0x428a2f99)",
    file: join(repoRoot, "src", "digest", "sha256.mbt"),
    find: "0x428a2f98U, 0x71374491U",
    replace: "0x428a2f99U, 0x71374491U",
    // Flips the LSB of the first FIPS 180-4 §4.2.2 round constant.
    // The NIST "abc" KAT must produce a different digest.
    expectHint: "FIPS 180-4 round constant",
  },
  {
    id: "sha512-initial-h0",
    label: "sha512 initial hash H0 bit-flipped",
    file: join(repoRoot, "src", "digest", "sha512.mbt"),
    find: "0x6a09e667f3bcc908UL, 0xbb67ae8584caa73bUL",
    replace: "0x6a09e667f3bcc909UL, 0xbb67ae8584caa73bUL",
    // Flips the LSB of the first FIPS 180-4 SHA-512 initial value. SHA-256
    // mutations cannot prove that the SHA-512 implementation is guarded.
    expectHint: "FIPS 180-4 SHA-512 initial hash state",
  },
  {
    id: "sha512-round-k0",
    label: "sha512 round constant K0 bit-flipped",
    file: join(repoRoot, "src", "digest", "sha512.mbt"),
    find: "0x428a2f98d728ae22UL, 0x7137449123ef65cdUL",
    replace: "0x428a2f98d728ae23UL, 0x7137449123ef65cdUL",
    // Flips the first SHA-512 round constant, complementing the SHA-256 K0
    // mutation and pinning the second digest core.
    expectHint: "FIPS 180-4 SHA-512 round constant",
  },
  {
    id: "incremental-e2004-disabled",
    label: "incremental manifest digest mismatch check disabled",
    file: join(repoRoot, "src", "verify", "incremental.mbt"),
    find: "    if actual != expected {\n      findings.push({\n        code: \"E2004\",",
    replace: "    if false {\n      findings.push({\n        code: \"E2004\",",
    // Proves the independent golden-manifest tests really enforce the trust
    // boundary: expected_manifest_digest must reject a changed manifest.
    expectHint: "incremental E2004 manifest digest mismatch",
  },
  {
    id: "audit-signature-verification-disabled",
    label: "audit signature verification result ignored",
    file: join(repoRoot, "src", "audit", "audit_log.mbt"),
    find: "            if @crypto.ed25519_verify(pk, hash_bytes, sig) == false {\n              return false\n            }",
    replace: "            if false {\n              return false\n            }",
    // A syntactically valid but forged signature must not be accepted merely
    // because it decoded from hex. The wrong-public-key audit test exercises
    // this verification result independently of the signing happy path.
    expectHint: "audit Ed25519 signature verification",
  },
  {
    id: "store-integrity-comparison-disabled",
    label: "object-store digest comparison disabled",
    file: join(repoRoot, "src", "store", "object_store.mbt"),
    find: "        if recomputed != hash {\n          return false\n        }",
    replace: "        if false {\n          return false\n        }",
    // A present object is not sufficient: its bytes must still hash to the
    // index key. The independent hardcoded-digest tamper test must catch this
    // disabled comparison without relying on ObjectStore::put.
    expectHint: "object-store content digest comparison",
  },
];

const countOccurrences = (haystack, needle) =>
  haystack.split(needle).length - 1;

const runTests = () => {
  try {
    const output = execFileSync("moon", ["test", "--target", "js"], {
      cwd: repoRoot,
      encoding: "utf8",
      stdio: ["ignore", "pipe", "pipe"],
      timeout: 180_000,
    });
    return { ok: true, output };
  } catch (error) {
    // moon test exits non-zero when any test fails - that is the signal
    // we want. The combined stdout+stderr carries the failure summary.
    return {
      ok: false,
      output: `${error.stdout || ""}${error.stderr || ""}`,
    };
  }
};

const summarize = (output) => {
  const summaryLine = output
    .split("\n")
    .map((line) => line.trim())
    .find((line) => line.startsWith("Total tests:"));
  return summaryLine || "(no Total tests line found)";
};

const pickFailureSnippet = (output) => {
  const lines = output.split("\n");
  const failing = [];
  for (const line of lines) {
    const trimmed = line.trim();
    if (
      trimmed.includes("FAILED") ||
      trimmed.includes("failed:") ||
      (trimmed.includes("failed") && trimmed.includes("assert"))
    ) {
      failing.push(trimmed);
      if (failing.length >= 5) break;
    }
  }
  return failing.length > 0 ? failing.join("\n      ") : "(no failure line captured)";
};

const runMutation = (mutation) => {
  const original = readFileSync(mutation.file, "utf8");
  const occurrences = countOccurrences(original, mutation.find);
  if (occurrences === 0) {
    return {
      ...mutation,
      applied: false,
      caught: null,
      detail: "find string not present (mutation target may have moved)",
    };
  }
  if (occurrences > 1) {
    return {
      ...mutation,
      applied: false,
      caught: null,
      detail: `find string matched ${occurrences} times (mutation must be unambiguous)`,
    };
  }

  const mutated = original.replace(mutation.find, mutation.replace);
  writeFileSync(mutation.file, mutated, "utf8");

  let result;
  try {
    const testResult = runTests();
    const caught = !testResult.ok;
    result = {
      ...mutation,
      applied: true,
      caught,
      summary: summarize(testResult.output),
      snippet: pickFailureSnippet(testResult.output),
      detail: caught
        ? "tests went red as expected"
        : "tests stayed GREEN - property suite has a coverage gap",
    };
  } finally {
    // Restore the original byte-for-byte, even if the harness itself threw.
    writeFileSync(mutation.file, original, "utf8");
  }
  return result;
};

const filterMutations = (argv) => {
  if (argv.length === 0) return mutations;
  const selected = [];
  for (const arg of argv) {
    if (arg.startsWith("--")) {
      const tag = arg.slice(2);
      for (const mutation of mutations) {
        if (mutation.id.startsWith(tag)) selected.push(mutation);
      }
    }
  }
  return selected.length > 0 ? selected : mutations;
};

const main = (argv) => {
  const selected = filterMutations(argv);
  console.log(`mutation-check: running ${selected.length} mutation(s)`);
  console.log("");

  let slipped = 0;
  let errored = 0;
  for (const mutation of selected) {
    console.log(`MUTATION  ${mutation.label}`);
    const result = runMutation(mutation);
    if (!result.applied) {
      errored += 1;
      console.log(`  ERROR    could not apply: ${result.detail}`);
      console.log("");
      continue;
    }
    const verdict = result.caught ? "CAUGHT" : "SLIPPED";
    if (!result.caught) slipped += 1;
    console.log(`  ${verdict}   ${result.detail}`);
    console.log(`  summary  ${result.summary}`);
    if (result.caught) {
      console.log(`  failures:`);
      console.log(`      ${result.snippet}`);
    }
    console.log("");
  }

  const total = selected.length;
  const caught = total - slipped - errored;
  console.log(
    `mutation-check: ${caught}/${total} mutations caught (${slipped} slipped, ${errored} errored)`,
  );
  return slipped > 0 || errored > 0 ? 1 : 0;
};

process.exit(main(process.argv.slice(2)));
