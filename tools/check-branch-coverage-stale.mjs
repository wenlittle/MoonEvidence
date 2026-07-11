#!/usr/bin/env node
// Guard the manual branch coverage map against drifting out of date.
//
// If a production source file covered by docs/BRANCH_COVERAGE.md changes, the
// same diff must also touch docs/BRANCH_COVERAGE.md. This does not prove the
// map is correct; it forces an explicit review at the point where drift starts.

import { execFileSync } from "child_process";
import { readFileSync } from "fs";
import { fileURLToPath } from "url";
import { dirname, join } from "path";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const repoRoot = join(__dirname, "..");

const COVERAGE_FILE = "docs/BRANCH_COVERAGE.md";
const AUDITED_SOURCE_FILES = new Set([
  "src/verify/verify.mbt",
  "src/verify/incremental.mbt",
  "src/merkle/merkle.mbt",
  "src/digest/digest.mbt",
  "src/digest/sha256.mbt",
  "src/digest/sha512.mbt",
  "src/digest/hmac.mbt",
  "src/crypto/ed25519.mbt",
  "src/crypto/field25519.mbt",
  "src/crypto/point25519.mbt",
  "src/create/create.mbt",
  "src/store/object_store.mbt",
  "src/audit/audit_log.mbt",
  "src/api/api.mbt",
  "src/cmd/main/main.mbt",
  "integrations/fabric/chaincode-go/chaincode/anchor_contract.go",
  "integrations/fabric/chaincode-go/main.go",
  "integrations/fabric/gateway/src/anchor.ts",
  "integrations/fabric/gateway/src/cli.ts",
  "integrations/fabric/gateway/src/digest.ts",
  "integrations/fabric/gateway/src/errors.ts",
  "integrations/fabric/gateway/src/gateway.ts",
  "integrations/fabric/gateway/src/index.ts",
  "integrations/fabric/gateway/src/moon-cli.ts",
  "integrations/fabric/gateway/src/profile.ts",
  "integrations/fabric/gateway/src/types.ts",
]);

function normalizePath(path) {
  return path.replaceAll("\\", "/");
}

function parseArgs(argv) {
  const args = { base: undefined, head: "HEAD", selfTest: false };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "--self-test") {
      args.selfTest = true;
    } else if (arg === "--base") {
      args.base = argv[++i];
    } else if (arg === "--head") {
      args.head = argv[++i];
    } else {
      throw new Error(`unknown argument: ${arg}`);
    }
  }
  return args;
}

function defaultBase() {
  if (process.env.GITHUB_BASE_REF) return `origin/${process.env.GITHUB_BASE_REF}`;
  if (process.env.GITHUB_EVENT_BEFORE && !/^0+$/.test(process.env.GITHUB_EVENT_BEFORE)) {
    return process.env.GITHUB_EVENT_BEFORE;
  }
  return "HEAD~1";
}

function gitDiffNames(base, head) {
  const ranges = [`${base}...${head}`, `${base}..${head}`];
  let lastError;
  for (const range of ranges) {
    try {
      const output = execFileSync("git", ["diff", "--name-only", range], {
        cwd: repoRoot,
        encoding: "utf8",
      });
      return output.split(/\r?\n/).filter(Boolean).map(normalizePath);
    } catch (error) {
      lastError = error;
    }
  }
  throw lastError;
}

function evaluateChangedFiles(changedFiles) {
  const changed = new Set(changedFiles.map(normalizePath));
  const touchedAuditedSources = [...AUDITED_SOURCE_FILES].filter((file) => changed.has(file));
  const touchedCoverage = changed.has(COVERAGE_FILE);
  return {
    touchedAuditedSources,
    touchedCoverage,
    ok: touchedAuditedSources.length === 0 || touchedCoverage,
  };
}

function evaluateCoverageMap(source) {
  const ids = [...source.matchAll(/^\| ([A-Z]+-\d+) \|/gm)].map((match) => match[1]);
  const duplicateIds = [...new Set(ids.filter((id, index) => ids.indexOf(id) !== index))];
  const gapIds = [...source.matchAll(/^\| ([A-Z]+-\d+) \|.*\| `gap` \|/gm)].map((match) => match[1]);
  const declaredMatch = source.match(/current map contains (\d+) audited invariants/);
  const declaredCount = declaredMatch ? Number.parseInt(declaredMatch[1], 10) : undefined;
  return {
    ids,
    duplicateIds,
    gapIds,
    declaredCount,
    ok:
      ids.length > 0 &&
      duplicateIds.length === 0 &&
      gapIds.length === 0 &&
      declaredCount === ids.length,
  };
}

function validateCoverageMap() {
  const source = readFileSync(join(repoRoot, COVERAGE_FILE), "utf8");
  const result = evaluateCoverageMap(source);
  if (result.ids.length === 0) throw new Error("branch coverage map contains no invariant rows");
  if (result.duplicateIds.length > 0) {
    throw new Error(`branch coverage map has duplicate IDs: ${result.duplicateIds.join(", ")}`);
  }
  if (result.gapIds.length > 0) {
    throw new Error(`branch coverage map has open gaps: ${result.gapIds.join(", ")}`);
  }
  if (result.declaredCount === undefined) {
    throw new Error("branch coverage map is missing its declared invariant count");
  }
  if (result.declaredCount !== result.ids.length) {
    throw new Error(
      `branch coverage map count drift: declares ${result.declaredCount}, contains ${result.ids.length}`,
    );
  }
  return result;
}

function runSelfTest() {
  const cases = [
    { name: "no audited source", files: ["README.md"], ok: true },
    { name: "audited source with coverage doc", files: ["src/verify/verify.mbt", COVERAGE_FILE], ok: true },
    { name: "audited source without coverage doc", files: ["src/api/api.mbt"], ok: false },
    { name: "CLI source without coverage doc", files: ["src/cmd/main/main.mbt"], ok: false },
    {
      name: "Fabric source with coverage doc",
      files: ["integrations/fabric/gateway/src/gateway.ts", COVERAGE_FILE],
      ok: true,
    },
  ];
  let failed = 0;
  for (const tc of cases) {
    const got = evaluateChangedFiles(tc.files).ok;
    if (got !== tc.ok) {
      console.error(`FAIL self-test ${tc.name}: got ${got}, expected ${tc.ok}`);
      failed++;
    }
  }
  const mapCases = [
    {
      name: "valid coverage map",
      source:
        "The current map contains 2 audited invariants.\n| V-01 | branch | `covered` |\n| V-02 | branch | `accepted-risk` |",
      ok: true,
    },
    {
      name: "duplicate coverage ID",
      source:
        "The current map contains 2 audited invariants.\n| V-01 | branch | `covered` |\n| V-01 | branch | `covered` |",
      ok: false,
    },
    {
      name: "open coverage gap",
      source: "The current map contains 1 audited invariants.\n| V-01 | branch | `gap` |",
      ok: false,
    },
    {
      name: "coverage count drift",
      source: "The current map contains 2 audited invariants.\n| V-01 | branch | `covered` |",
      ok: false,
    },
  ];
  for (const tc of mapCases) {
    const got = evaluateCoverageMap(tc.source).ok;
    if (got !== tc.ok) {
      console.error(`FAIL self-test ${tc.name}: got ${got}, expected ${tc.ok}`);
      failed++;
    }
  }
  if (failed > 0) process.exit(1);
  const total = cases.length + mapCases.length;
  console.log(`branch coverage stale-check self-test passed (${total}/${total})`);
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  const map = validateCoverageMap();
  if (args.selfTest) {
    runSelfTest();
    return;
  }
  const base = args.base ?? defaultBase();
  const changedFiles = gitDiffNames(base, args.head);
  const result = evaluateChangedFiles(changedFiles);
  if (!result.ok) {
    console.error("docs/BRANCH_COVERAGE.md is stale or unreviewed.");
    console.error("Audited source files changed without touching the branch coverage map:");
    for (const file of result.touchedAuditedSources) console.error(`  - ${file}`);
    console.error(`Update or explicitly review ${COVERAGE_FILE} in the same change.`);
    process.exit(1);
  }
  if (result.touchedAuditedSources.length === 0) {
    console.log("Branch coverage stale-check passed: no audited source files changed.");
  } else {
    console.log(
      `Branch coverage stale-check passed: ${result.touchedAuditedSources.length} audited source file(s) changed and ${COVERAGE_FILE} was updated.`,
    );
  }
  console.log(`Branch coverage map integrity passed: ${map.ids.length} invariants, 0 open gaps.`);
}

main();
