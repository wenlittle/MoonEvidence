#!/usr/bin/env node
// Guard the Mooncakes package surface. Competition/application materials,
// legacy course reports, generated report screenshots, and local agent files
// are useful in the repository but should not ship inside the reusable library
// package that users install from Mooncakes.

import { spawnSync } from "child_process";
import { dirname, join } from "path";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const repoRoot = join(dirname(__filename), "..");

const forbiddenPrefixes = [
  ".cursor/",
  ".workbuddy/",
  "docs/application/",
  "docs/plans/",
  "docs/records/",
  "docs/report/",
  "docs/research/",
  "docs/申报书",
  "integrations/",
  "report/",
  "showcase/",
];

const forbiddenExact = new Set([
  "package.json",
  "比赛要求.txt",
]);

const requiredFiles = [
  "LICENSE",
  "README.md",
  "README.en.md",
  "SECURITY.md",
  "moon.mod",
  "src/api/api.mbt",
  "src/cmd/main/main.mbt",
  "docs/spec/CLI_MACHINE_CONTRACT.md",
  "docs/spec/FABRIC_ANCHOR_SPEC.md",
  "examples/valid-pack/manifest.json",
  "tests/fixtures/packs/valid/manifest.json",
];

function normalizeLine(line) {
  return line.trim().replaceAll("\\", "/");
}

function looksLikePackagedPath(line) {
  if (!line) return false;
  if (line.startsWith("Blocking waiting ")) return false;
  if (line.startsWith("Running ")) return false;
  if (line.startsWith("Finished.")) return false;
  if (line.startsWith("Check ")) return false;
  if (line.startsWith("Package to ")) return false;
  if (line.startsWith("warning:")) return false;
  return true;
}

const result = spawnSync("moon", ["package", "--list"], {
  cwd: repoRoot,
  encoding: "utf8",
  stdio: ["ignore", "pipe", "pipe"],
});

const output = `${result.stdout ?? ""}\n${result.stderr ?? ""}`;
if (result.status !== 0) {
  console.error(output);
  process.exit(result.status ?? 1);
}

const files = output
  .split(/\r?\n/)
  .map(normalizeLine)
  .filter(looksLikePackagedPath);

const fileSet = new Set(files);
const failures = [];

for (const file of files) {
  if (forbiddenExact.has(file)) {
    failures.push(`forbidden package file: ${file}`);
  }
  for (const prefix of forbiddenPrefixes) {
    if (file.startsWith(prefix)) {
      failures.push(`forbidden package file: ${file}`);
      break;
    }
  }
}

for (const required of requiredFiles) {
  if (!fileSet.has(required)) {
    failures.push(`required package file missing: ${required}`);
  }
}

if (failures.length > 0) {
  console.error("Package content guard failed:");
  for (const failure of failures) {
    console.error(`- ${failure}`);
  }
  process.exit(1);
}

console.log(`Package content guard passed: ${files.length} files checked.`);
