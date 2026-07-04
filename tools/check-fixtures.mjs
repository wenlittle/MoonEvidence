// Fixture-rot guard: regenerates the committed fixture trees and fails when
// the on-disk bytes drift from the generator output.
//
// The two generators under tools/ are the single source of truth for
// tests/fixtures/packs/ (tamper matrix) and tests/fixtures/merkle/ (golden
// roots + proofs). Hand-edits to those subtrees silently rot the test
// contract; this script regenerates both, then `git diff`s the subtrees so
// any drift surfaces as a CI failure rather than a silent regression.
//
// Designed to be called directly from CI:
//   node tools/check-fixtures.mjs
// Exit code: 0 when the committed fixtures match the regenerated output,
//            1 when drift is detected (print the diff and the offending
//              files so the failure is self-explanatory).

import { execFileSync } from "node:child_process";
import { existsSync } from "node:fs";
import { join, dirname, relative } from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), "..");
const toolsDir = join(repoRoot, "tools");

const generators = ["gen-fixtures.mjs", "gen-merkle-fixtures.mjs"];
const guardedSubtrees = [
  join(repoRoot, "tests", "fixtures", "packs"),
  join(repoRoot, "tests", "fixtures", "merkle"),
];

const runNode = (script) => {
  const scriptPath = join(toolsDir, script);
  if (!existsSync(scriptPath)) {
    throw new Error(`generator not found: ${scriptPath}`);
  }
  try {
    const stdout = execFileSync(process.execPath, [scriptPath], {
      cwd: repoRoot,
      encoding: "utf8",
      stdio: ["ignore", "pipe", "pipe"],
    });
    process.stdout.write(stdout);
  } catch (error) {
    process.stderr.write(
      `\n[check-fixtures] generator ${script} failed:\n${error.stderr || error.message}\n`,
    );
    return false;
  }
  return true;
};

// `git diff --exit-code` returns 0 when the pathspec is clean, 1 when there
// are unstaged changes, and a non-zero code on git errors. We capture the
// raw diff so the CI log points directly at the offending lines.
const diffSubtree = (subtree) => {
  let result;
  try {
    const diff = execFileSync(
      "git",
      ["-C", repoRoot, "diff", "--exit-code", "--", subtree],
      { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] },
    );
    result = { clean: true, diff };
  } catch (error) {
    // exit code 1 => changes present; anything else is a real git error.
    if (error.status === 1) {
      result = { clean: false, diff: error.stdout || "" };
    } else {
      result = {
        clean: false,
        diff: "",
        error: `git diff failed (status ${error.status}): ${error.stderr || error.message}`,
      };
    }
  }
  return result;
};

// Untracked files inside a guarded subtree are also rot: a freshly emitted
// fixture that was never `git add`-ed would be invisible to `git diff`.
const listUntracked = (subtree) => {
  try {
    const output = execFileSync(
      "git",
      ["-C", repoRoot, "status", "--porcelain", "--untracked-files=all", "--", subtree],
      { encoding: "utf8" },
    );
    return output
      .split("\n")
      .map((line) => line.trim())
      .filter((line) => line.startsWith("??"))
      .map((line) => line.slice(3).trim());
  } catch {
    return [];
  }
};

const main = () => {
  console.log("check-fixtures: regenerating committed fixtures");
  for (const gen of generators) {
    console.log(`  running ${gen}`);
    if (!runNode(gen)) {
      console.error(`check-fixtures: FAIL - generator ${gen} exited non-zero`);
      return 1;
    }
  }

  console.log("");
  console.log("check-fixtures: diffing guarded subtrees");
  let drifted = false;
  for (const subtree of guardedSubtrees) {
    const rel = relative(repoRoot, subtree).replace(/\\/g, "/");
    const result = diffSubtree(subtree);
    const untracked = listUntracked(subtree);
    if (result.error) {
      console.error(`  ${rel}: git error - ${result.error}`);
      drifted = true;
      continue;
    }
    if (result.clean && untracked.length === 0) {
      console.log(`  ${rel}: clean`);
      continue;
    }
    drifted = true;
    console.error(`  ${rel}: DRIFT detected`);
    if (!result.clean) {
      console.error(result.diff);
    }
    if (untracked.length > 0) {
      console.error("  untracked files (never committed):");
      for (const path of untracked) console.error(`    ${path}`);
    }
  }

  console.log("");
  if (drifted) {
    console.error(
      "check-fixtures: FAIL - fixtures drifted from generator output.",
    );
    console.error(
      "  Either a generator changed its bytes (re-commit the regenerated",
    );
    console.error(
      "  trees) or someone hand-edited a guarded subtree (revert and edit",
    );
    console.error("  the generator instead).");
    return 1;
  }
  console.log("check-fixtures: PASS - all fixtures match generator output.");
  return 0;
};

process.exit(main());
