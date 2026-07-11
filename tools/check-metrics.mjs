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
//   3. Declared/executable test counts match public and application docs
//   4. Package count (find src -name 'moon.pkg') matches numbers in docs
//   5. moon.mod version matches CHANGELOG latest version
//   6. CLI_VERSION in the native adapter matches moon.mod version

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

function parseMetricNumber(value) {
  return parseInt(value.replaceAll(",", ""), 10);
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
let benchmarkWrapperCount = 0;
for (const f of wbTestFiles) {
  const content = readFileSync(f, "utf-8");
  const lines = content.split("\n");
  for (const line of lines) {
    if (line.match(/^test /)) {
      testCount++;
      if (line.match(/^test\s+"bench:/)) benchmarkWrapperCount++;
    }
  }
}
const executableTestCount = testCount - benchmarkWrapperCount;

const commits = parseInt(run("git rev-list --count HEAD"), 10);
const pkgCount = moonPkgFiles.length;

// moon.mod version
const moonMod = readFileSync(join(repoRoot, "moon.mod"), "utf-8");
const versionMatch = moonMod.match(/^version\s*=\s*"([^"]+)"/m);
const moonModVersion = versionMatch ? versionMatch[1] : "UNKNOWN";

// CHANGELOG latest version
const changelog = readFileSync(join(repoRoot, "CHANGELOG.md"), "utf-8");
const clMatch = changelog.match(/^##\s*\[(\d+\.\d+\.\d+)\]/m);
const changelogVersion = clMatch ? clMatch[1] : "UNKNOWN";

// CLI_VERSION in native CLI adapter
const cmdMain = readFileSync(join(repoRoot, "src", "cmd", "main", "main.mbt"), "utf-8");
const cliVersionMatch = cmdMain.match(/^const\s+CLI_VERSION\s*:\s*String\s*=\s*"([^"]+)"/m);
const cliVersion = cliVersionMatch ? cliVersionMatch[1] : "UNKNOWN";

const actual = {
  commits,
  totalLines: allMbtLines,
  implLines: implOnly,
  testLines: testLines,
  testCount,
  executableTestCount,
  benchmarkWrapperCount,
  pkgCount,
  moonModVersion,
  changelogVersion,
  cliVersion,
};

console.log("Actual metrics:");
console.log(JSON.stringify(actual, null, 2));

// ---------------------------------------------------------------------------
// Assertion rules: (file, regex, expectedGroup, actualValue, description)
// `minimum: true` means the doc value must be >= actual (for monotonically
// increasing metrics like commit count, which drift +1 on every commit).
// ---------------------------------------------------------------------------
const assertions = [
  // README.md
  {
    file: "README.md",
    pattern: /MoonBit 测试\s*\|\s*\*{2}([\d,]+)\*{2}\s+个测试声明/,
    expected: testCount,
    desc: "README.md test declaration count",
  },
  {
    file: "README.md",
    pattern: /MoonBit 源码\s*\|\s*\*{2}([\d,]+)\*{2}\s+行（实现\s+([\d,]+)\s+\+\s+测试\s+([\d,]+)）/,
    expected: { 1: allMbtLines, 2: implOnly, 3: testLines },
    desc: "README.md line counts",
  },
  // README.en.md mirrors the same public facts.
  {
    file: "README.en.md",
    pattern: /MoonBit tests\s*\|\s*\*{2}([\d,]+)\*{2}\s+test declarations/,
    expected: testCount,
    desc: "README.en.md test declaration count",
  },
  {
    file: "README.en.md",
    pattern: /MoonBit source\s*\|\s*\*{2}([\d,]+)\*{2}\s+lines:\s+([\d,]+)\s+implementation\s+\+\s+([\d,]+)\s+tests/,
    expected: { 1: allMbtLines, 2: implOnly, 3: testLines },
    desc: "README.en.md line counts",
  },
  // DEVELOPMENT_REPORT.md
  // Commit count uses `minimum` because it increases on every commit,
  // including this check's own fix commit — exact match would endlessly drift.
  {
    file: "docs/report/DEVELOPMENT_REPORT.md",
    pattern: /规模：(\d+)\s+行\s+MoonBit（实现\s+(\d+)\s+\+\s+测试\s+(\d+)）｜\s+提交：(\d+)\s+个\s+｜\s+包：(\d+)\s+个/,
    expected: { 1: allMbtLines, 2: implOnly, 3: testLines, 4: commits, 5: pkgCount },
    minimum: { 4: true },
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
    minimum: true,
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
    minimum: true,
    desc: "ACCEPTANCE_CHECKLIST.md commit count",
  },
  // STRUCTURE_TREE.md — CLI case count
  {
    file: "docs/STRUCTURE_TREE.md",
    pattern: /(\d+)\s+用例黑盒 CLI/,
    expected: 62, // CLI black-box is maintained by both shell implementations
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
  {
    file: "src/cmd/main/main.mbt",
    pattern: /^const\s+CLI_VERSION\s*:\s*String\s*=\s*"([^"]+)"/m,
    expected: moonModVersion,
    desc: `CLI_VERSION (${cliVersion}) == moon.mod version (${moonModVersion})`,
    isVersion: true,
  },
  ...[
    ["docs/application/OSC2026_APPLICATION.md", "OSC2026 application"],
    ["docs/申报书.md", "one-page application Markdown"],
    ["docs/申报书.html", "one-page application HTML"],
    ["docs/申报书.tex", "one-page application TeX"],
  ].flatMap(([file, label]) => [
    {
      file,
      pattern: /产品实现\s*(\d+)\s*行，测试\s*(\d+)\s*行，总计\s*(\d+)\s*行 MoonBit/,
      expected: { 1: implOnly, 2: testLines, 3: allMbtLines },
      desc: `${label} line counts`,
    },
    {
      file,
      pattern: /测试体系[：:]\s*(\d+)\s*个可执行 MoonBit 测试、(\d+)\s*个测试声明、(\d+)\s*个 CLI 黑盒用例/,
      expected: { 1: executableTestCount, 2: testCount, 3: 62 },
      desc: `${label} test counts`,
    },
  ]),
];

// ---------------------------------------------------------------------------
// Run assertions
// ---------------------------------------------------------------------------
let failures = 0;
let checks = 0;

for (const a of assertions) {
  let content;
  try {
    content = readFileSync(join(repoRoot, a.file), "utf-8");
  } catch {
    checks++;
    failures++;
    console.log(`✗ FAIL ${a.desc}: required file ${a.file} not found`);
    continue;
  }
  const match = content.match(a.pattern);
  if (!match) {
    checks++;
    failures++;
    console.log(`✗ FAIL ${a.desc}: required pattern not found in ${a.file}`);
    continue;
  }

  if (a.isVersion) {
    const found = match[1];
    checks++;
    if (found !== a.expected) {
      console.log(`✗ FAIL ${a.desc}: found "${found}", expected "${a.expected}"`);
      failures++;
    } else {
      console.log(`✓ PASS ${a.desc}`);
    }
    continue;
  }

  if (typeof a.expected === "object") {
    const minMap = typeof a.minimum === "object" ? a.minimum : {};
    for (const [group, expectedVal] of Object.entries(a.expected)) {
      const found = parseMetricNumber(match[parseInt(group)]);
      checks++;
      // For minimum checks: actual (expectedVal) must be >= doc (found),
      // i.e. the repo meets the floor stated in docs. This prevents the
      // chicken-and-egg where every commit increments the count.
      const isMin = minMap[group] === true;
      const pass = isMin ? expectedVal >= found : found === expectedVal;
      if (!pass) {
        console.log(`✗ FAIL ${a.desc}: found ${found}, ${isMin ? "minimum" : "expected"} ${expectedVal}`);
        failures++;
      } else {
        console.log(`✓ PASS ${a.desc} (group ${group})`);
      }
    }
  } else {
    const found = parseMetricNumber(match[1]);
    checks++;
    const isMin = a.minimum === true;
    const pass = isMin ? a.expected >= found : found === a.expected;
    if (!pass) {
      console.log(`✗ FAIL ${a.desc}: found ${found}, ${isMin ? "minimum" : "expected"} ${a.expected}`);
      failures++;
    } else {
      console.log(`✓ PASS ${a.desc}`);
    }
  }
}

console.log("");
if (failures === 0) {
  console.log(`✅ All metric assertions pass (${checks}/${checks}).`);
  process.exit(0);
} else {
  console.log(`❌ ${failures}/${checks} assertion(s) failed. Update the docs to match actual metrics.`);
  process.exit(1);
}
