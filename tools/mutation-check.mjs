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
    id: "ed25519-identity-reject",
    label: "ed25519 identity public key rejection removed",
    file: join(repoRoot, "src", "crypto", "ed25519.mbt"),
    find: "  if a_point.is_identity() {\n    return false\n  }",
    replace: "  if a_point.is_identity() {\n    ()\n  }",
    // The identity point (0, 1) has order 1; without rejection, an
    // all-zero signature verifies against it (S*B = O = R + k*O).
    // The explicit identity-rejection test must go red.
    expectHint: "identity point rejection",
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
