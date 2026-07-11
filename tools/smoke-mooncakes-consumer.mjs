#!/usr/bin/env node

import {
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), "..");
const moduleName = "starlittle/MoonEvidence";
const currentVersion = readFileSync(join(repoRoot, "moon.mod"), "utf8")
  .match(/^version\s*=\s*"([^"]+)"/m)?.[1];
const requestedVersion = process.argv.find((arg) => arg.startsWith("--version="))
  ?.slice("--version=".length) ?? currentVersion;
const keep = process.argv.includes("--keep");

if (!requestedVersion) {
  throw new Error("moon.mod does not contain a version");
}

const moon = process.platform === "win32" ? "moon.exe" : "moon";
const workspace = mkdtempSync(join(tmpdir(), "moonevidence-consumer-"));
const project = join(workspace, "consumer");

function run(args, cwd = repoRoot) {
  const result = spawnSync(moon, args, {
    cwd,
    encoding: "utf8",
    stdio: "inherit",
  });
  if (result.error) {
    throw result.error;
  }
  if (result.status !== 0) {
    throw new Error(`moon ${args.join(" ")} exited with ${result.status}`);
  }
}

const consumerTests = `///|
fn sample_files(report : Bytes) -> Map[String, Bytes] {
  {
    "files/report.txt": report,
    "files/config.json": b"{\\"model\\":\\"v1\\"}",
  }
}

///|
test "published package creates and verifies a manifest" {
  let files = sample_files(b"reviewed result")
  let manifest = @create.create_manifest(files, {
    subject: { id: "release-smoke", kind: "review" },
    algorithm: @digest.Sha256,
    version_id: "v1",
    version_parent: None,
  })
  let report = @verify.verify_manifest(manifest, files)
  assert_true(report.ok)
  assert_true(@diag.explain(report).contains("verification OK"))
}

///|
test "published package rejects changed evidence" {
  let original = sample_files(b"reviewed result")
  let manifest = @create.create_manifest(original, {
    subject: { id: "release-smoke", kind: "review" },
    algorithm: @digest.Sha256,
    version_id: "v1",
    version_parent: None,
  })
  let changed = sample_files(b"changed result")
  let report = @verify.verify_manifest(manifest, changed)
  assert_false(report.ok)
  assert_true(@diag.explain(report).contains("E2003"))
}
`;

try {
  run(["new", project, "--user", "reviewer", "--name", "consumer"]);
  run(["add", `${moduleName}@${requestedVersion}`], project);

  writeFileSync(
    join(project, "moon.pkg"),
    `import {
  "${moduleName}/src/create",
  "${moduleName}/src/diag",
  "${moduleName}/src/digest",
  "${moduleName}/src/verify",
} for "wbtest"
`,
  );
  writeFileSync(join(project, "consumer_wbtest.mbt"), consumerTests);
  writeFileSync(join(project, "consumer_test.mbt"), "");

  run(["check", "--deny-warn", "--target", "all"], project);
  run(["test", "--deny-warn", "--target", "js"], project);

  const resolvedModule = readFileSync(join(project, "moon.mod"), "utf8");
  const exactDependency = `"${moduleName}@${requestedVersion}"`;
  if (!resolvedModule.includes(exactDependency)) {
    throw new Error(`consumer did not resolve ${exactDependency}`);
  }

  console.log(
    `Mooncakes consumer smoke passed: ${moduleName}@${requestedVersion} (2/2 tests)`,
  );
  if (keep) {
    console.log(`Consumer project kept at ${project}`);
  }
} finally {
  if (!keep) {
    rmSync(workspace, { recursive: true, force: true });
  }
}
