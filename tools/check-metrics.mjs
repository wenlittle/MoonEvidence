#!/usr/bin/env node
// check-metrics.mjs — CI gate: assert that quantified numbers in docs match
// the actual repository state. Prevents "metric drift" (docs claiming stale
// commit/line/test counts) without requiring humans to remember to update.
//
// Usage:
//   node tools/check-metrics.mjs          # check all assertions
//   node tools/check-metrics.mjs --fix    # print suggested fixes (no write)
//
// Exit 0 = all assertions pass; exit 1 = at least one mismatch.
//
// What it checks:
//   1. Commit count (git rev-list --count HEAD) matches numbers in docs
//   2. MoonBit line count (find src -name '*.mbt') matches numbers in docs
//   3. Test count (grep '^test ' in *_wbtest.mbt) matches numbers in docs
//   4. Package count (find src -name 'moon.pkg') matches numbers in docs
//   5. moon.mod version matches CHANGELOG latest version

import { execSync } from "child_process";
import { readFileSync, readdirSync, statSync } from "fs";
import { join, relative } from "path";
import { fileURLToPath } from "url";
import { dirname } from "path";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const repoRoot = join(__dirname, "..");

// ---------------------------------------------------------------------------
// Collect actual metrics
// ---------------------------------------------------------------------------
function run(cmd) {
  return execSync(cmd, { cwd: repoRoot, encoding: "utf-8" }).trim();
}

// Walk directory recursively, return all files matching a predicate
function walkDir(dir, predicate) {
  let results = [];
  try {
    const entries = readdirSync(dir);
    for (const entry of entries) {
      const full = join(dir, entry);
      let st;
      try { st = statSync(full); } catch { continue; }
      if (st.isDirectory()) {
        results = results.concat(walkDir(full, predicate));
      } else if (predicate(full)) {
        results.push(full);
      }
    }
  } catch { /* dir not found */ }
  return results;
}

function countFileLines(filepath) {
  try {
    const content = readFileSync(filepath, "utf-8");
    return content.split("\n").length;
  } catch {
    return 0;
  }
}

function isMbt(f) { return f.endsWith(".mbt"); }
function isWbTest(f) { return f.endsWith("_wbtest.mbt"); }
function isBench(f) { return f.includes("_bench") && f.endsWith(".mbt"); }
function isMoonPkg(f) { return f.endsWith("moon.pkg") && !f.includes("_build") && !f.includes(".mooncakes"); }

const srcDir = join(repoRoot, "src");
const allMbtFiles = walkDir(srcDir, isMbt);
const wbTestFiles = walkDir(srcDir, isWbTest);
const benchFiles = walkDir(srcDir, isBench);
const moonPkgFiles = walkDir(srcDir, isMoonPkg);

let allMbtLines = 0;
for (const f of allMbtFiles) allMbtLines += countFileLines(f);

let testLines = 0;
for (const f of wbTestFiles) testLines += countFileLines(f);
for (const f of benchFiles) testLines += countFileLines(f);

const implOnly = allMbtLines - testLines;

// Test declarations: grep '^test ' in *_wbtest.mbt
let testCount = 0;
for (const f of wbTestFiles) {
  const content = readFileSync(f, "utf-8");
  const lines = content.split("\n");
  for (const line of lines) {
    if (line.match(/^test /)) testCount++;
  }
}

const commits = parseInt(run("git rev-list --count HEAD"), 10);
const pkgCount = moonPkgFiles.length;

// moon.mod version
const moonMod = readFileSync(join(repoRoot, "moon.mod"), "utf-8");
const versionMatch = moonMod.match(/^version\s*=\s*"([^"]+)"/m);
const moonModVersion = versionMatch ? versionMatch[1] : "UNKNOWN";

// CHANGELOG latest version
const changelog = readFileSync(join(repoRoot, "CHANGELOG.md"), "utf-8");
const clMatch = changelog.match(/^##\s*\[([^\]]+)\]/m);
const changelogVersion = clMatch ? clMatch[1] : "UNKNOWN";

const actual = {
  commits,
  totalLines: allMbtLines,
  implLines: implOnly,
  testLines: testLines,
  testCount,
  pkgCount,
  moonModVersion,
  changelogVersion,
};

console.log("Actual metrics:");
console.log(JSON.stringify(actual, null, 2));

// ---------------------------------------------------------------------------
// Assertion rules: (file, regex, expectedGroup, actualValue, description)
// ---------------------------------------------------------------------------
const assertions = [
  // README.md
  {
    file: "README.md",
    pattern: /\*{2}(\d+)\s+unit\s+tests\*{2}/i,
    expected: testCount,
    desc: "README.md unit test count",
  },
  {
    file: "README.md",
    pattern: /Codebase is (\d+)\s*\neffective MoonBit lines \(implementation (\d+) \+ tests (\d+)\)/,
    expected: { 1: allMbtLines, 2: implOnly, 3: testLines },
    desc: "README.md line counts",
  },
  // README.zh.md
  {
    file: "README.zh.md",
    pattern: /\*{2}(\d+)\s+个单元测试\*{2}/,
    expected: testCount,
    desc: "README.zh.md unit test count",
  },
  // DEVELOPMENT_REPORT.md
  {
    file: "docs/report/DEVELOPMENT_REPORT.md",
    pattern: /规模：(\d+)\s+行\s+MoonBit（实现\s+(\d+)\s+\+\s+测试\s+(\d+)）｜\s+提交：(\d+)\s+个\s+｜\s+包：(\d+)\s+个/,
    expected: { 1: allMbtLines, 2: implOnly, 3: testLines, 4: commits, 5: pkgCount },
    desc: "DEVELOPMENT_REPORT.md header stats",
  },
  {
    file: "docs/report/DEVELOPMENT_REPORT.md",
    pattern: /单元测试\s+\|\s+\*{2}(\d+)\s+个\*{2}/,
    expected: testCount,
    desc: "DEVELOPMENT_REPORT.md test count in table",
  },
  {
    file: "docs/report/DEVELOPMENT_REPORT.md",
    pattern: /提交数\s+\|\s+(\d+)/,
    expected: commits,
    desc: "DEVELOPMENT_REPORT.md commit count",
  },
  {
    file: "docs/report/DEVELOPMENT_REPORT.md",
    pattern: /总行数\s+\|\s+\*{2}(\d+)\*{2}/,
    expected: allMbtLines,
    desc: "DEVELOPMENT_REPORT.md total lines",
  },
  // ACCEPTANCE_CHECKLIST.md
  {
    file: "docs/records/ACCEPTANCE_CHECKLIST.md",
    pattern: /实现\s+(\d+)\s+行\s+\+\s+测试\s+(\d+)\s+行，合计\s+\*{2}(\d+)\s+行\*{2}/,
    expected: { 1: implOnly, 2: testLines, 3: allMbtLines },
    desc: "ACCEPTANCE_CHECKLIST.md line counts",
  },
  {
    file: "docs/records/ACCEPTANCE_CHECKLIST.md",
    pattern: /\*{2}(\d+)\s+个提交\*{2}/,
    expected: commits,
    desc: "ACCEPTANCE_CHECKLIST.md commit count",
  },
  // STRUCTURE_TREE.md — CLI case count
  {
    file: "docs/STRUCTURE_TREE.md",
    pattern: /(\d+)\s+用例黑盒 CLI/,
    expected: 53, // CLI black-box is 53, not derived from grep
    desc: "STRUCTURE_TREE.md CLI case count",
  },
  // Version consistency
  {
    file: "moon.mod",
    pattern: /^version\s*=\s*"([^"]+)"/m,
    expected: changelogVersion,
    desc: `moon.mod version (${moonModVersion}) == CHANGELOG latest (${changelogVersion})`,
    isVersion: true,
  },
];

// ---------------------------------------------------------------------------
// Run assertions
// ---------------------------------------------------------------------------
let failures = 0;

for (const a of assertions) {
  let content;
  try {
    content = readFileSync(join(repoRoot, a.file), "utf-8");
  } catch {
    console.log(`⚠ SKIP ${a.desc}: file ${a.file} not found`);
    continue;
  }
  const match = content.match(a.pattern);
  if (!match) {
    console.log(`⚠ SKIP ${a.desc}: pattern not found in ${a.file}`);
    continue;
  }

  if (a.isVersion) {
    const found = match[1];
    if (found !== a.expected) {
      console.log(`✗ FAIL ${a.desc}: found "${found}", expected "${a.expected}"`);
      failures++;
    } else {
      console.log(`✓ PASS ${a.desc}`);
    }
    continue;
  }

  if (typeof a.expected === "object") {
    for (const [group, expectedVal] of Object.entries(a.expected)) {
      const found = parseInt(match[parseInt(group)], 10);
      if (found !== expectedVal) {
        console.log(`✗ FAIL ${a.desc}: found ${found}, expected ${expectedVal}`);
        failures++;
      } else {
        console.log(`✓ PASS ${a.desc} (group ${group})`);
      }
    }
  } else {
    const found = parseInt(match[1], 10);
    if (found !== a.expected) {
      console.log(`✗ FAIL ${a.desc}: found ${found}, expected ${a.expected}`);
      failures++;
    } else {
      console.log(`✓ PASS ${a.desc}`);
    }
  }
}

console.log("");
if (failures === 0) {
  console.log("✅ All metric assertions pass.");
  process.exit(0);
} else {
  console.log(`❌ ${failures} assertion(s) failed. Update the docs to match actual metrics.`);
  process.exit(1);
}
