import { existsSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

import { assertCanonicalDigest } from "./digest.js";
import { FabricAdapterError } from "./errors.js";
import type { InspectResult, VerifyReport } from "./types.js";

interface MoonCommandResult {
  exitCode: number;
  value: unknown;
}

function findRepositoryRoot(): string {
  let current = dirname(fileURLToPath(import.meta.url));
  for (let depth = 0; depth < 12; depth++) {
    if (existsSync(resolve(current, "moon.mod"))) {
      return current;
    }
    const parent = dirname(current);
    if (parent === current) {
      break;
    }
    current = parent;
  }
  throw new FabricAdapterError(
    "MOON_CLI_NOT_FOUND",
    "could not locate repository root containing moon.mod",
  );
}

export function resolveMoonCli(inputPath?: string): string {
  if (inputPath) {
    const explicit = resolve(inputPath);
    if (!existsSync(explicit)) {
      throw new FabricAdapterError(
        "MOON_CLI_NOT_FOUND",
        "MoonEvidence CLI path does not exist",
        { path: explicit },
      );
    }
    return explicit;
  }
  const root = findRepositoryRoot();
  const candidates = [
    resolve(root, "_build/js/debug/build/src/cmd/main/main.js"),
    resolve(root, "_build/js/release/build/src/cmd/main/main.js"),
    resolve(root, "_build/native/debug/build/src/cmd/main/main.exe"),
    resolve(root, "_build/native/debug/build/src/cmd/main/main"),
  ];
  const found = candidates.find((candidate) => existsSync(candidate));
  if (!found) {
    throw new FabricAdapterError(
      "MOON_CLI_NOT_FOUND",
      "build the MoonEvidence CLI or pass --moon-cli",
      { candidates },
    );
  }
  return found;
}

function runMoonJSON(cliPath: string, args: string[]): MoonCommandResult {
  const isJavaScript = cliPath.toLowerCase().endsWith(".js");
  const executable = isJavaScript ? process.execPath : cliPath;
  const commandArgs = isJavaScript ? [cliPath, ...args] : args;
  const result = spawnSync(executable, commandArgs, {
    cwd: process.cwd(),
    encoding: "utf8",
    maxBuffer: 4 * 1024 * 1024,
    timeout: 120_000,
    windowsHide: true,
  });
  if (result.error) {
    throw new FabricAdapterError(
      "MOON_CLI_FAILED",
      "failed to start MoonEvidence CLI",
      { cause: result.error.message },
    );
  }
  const exitCode = result.status ?? 2;
  const stdout = (result.stdout ?? "").trim();
  let value: unknown;
  try {
    value = JSON.parse(stdout);
  } catch (error) {
    throw new FabricAdapterError(
      "MOON_CLI_FAILED",
      "MoonEvidence CLI did not return one JSON object",
      {
        exit_code: exitCode,
        stdout,
        stderr: (result.stderr ?? "").trim(),
        cause: String(error),
      },
    );
  }
  return { exitCode, value };
}

function isObject(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function isNonEmptyString(value: unknown): value is string {
  return typeof value === "string" && value.length > 0;
}

function isCanonicalDigest(value: unknown): value is string {
  if (typeof value !== "string") {
    return false;
  }
  try {
    assertCanonicalDigest(value);
    return true;
  } catch {
    return false;
  }
}

function isInspectResult(value: unknown): value is InspectResult {
  if (!isObject(value) || !isObject(value.subject) || !isObject(value.version)) {
    return false;
  }
  const algorithm = value.algorithm;
  const merkleRoot = value.merkle_root;
  return (
    value.schema === "moon-evidence-inspect/v1" &&
    value.ok === true &&
    isNonEmptyString(value.pack_path) &&
    isNonEmptyString(value.manifest_path) &&
    isCanonicalDigest(value.manifest_digest) &&
    (algorithm === "sha256" || algorithm === "sha512") &&
    value.manifest_digest.startsWith(algorithm + ":") &&
    (merkleRoot === null ||
      (isCanonicalDigest(merkleRoot) && merkleRoot.startsWith(algorithm + ":"))) &&
    typeof value.files_total === "number" &&
    Number.isSafeInteger(value.files_total) &&
    value.files_total >= 0 &&
    isNonEmptyString(value.subject.id) &&
    isNonEmptyString(value.subject.type) &&
    isNonEmptyString(value.version.id) &&
    (value.version.parent === null || isNonEmptyString(value.version.parent))
  );
}

function isVerifyReport(value: unknown): value is VerifyReport {
  if (
    !isObject(value) ||
    typeof value.ok !== "boolean" ||
    !Array.isArray(value.findings) ||
    !isObject(value.stats)
  ) {
    return false;
  }
  const findingsValid = value.findings.every(
    (finding) =>
      isObject(finding) &&
      typeof finding.code === "string" &&
      typeof finding.severity === "string" &&
      typeof finding.path === "string" &&
      typeof finding.message === "string",
  );
  return (
    findingsValid &&
    typeof value.stats.files_total === "number" &&
    Number.isSafeInteger(value.stats.files_total) &&
    value.stats.files_total >= 0 &&
    typeof value.stats.files_passed === "number" &&
    Number.isSafeInteger(value.stats.files_passed) &&
    value.stats.files_passed >= 0 &&
    value.stats.files_passed <= value.stats.files_total &&
    typeof value.stats.merkle_checked === "boolean"
  );
}

export function inspectMoonPack(
  cliPath: string,
  packPath: string,
): InspectResult {
  const result = runMoonJSON(cliPath, [
    "inspect",
    "--json",
    resolve(packPath),
  ]);
  if (
    result.exitCode !== 0 ||
    !isInspectResult(result.value)
  ) {
    throw new FabricAdapterError(
      "MOON_INSPECT_FAILED",
      "MoonEvidence inspect rejected the pack",
      { exit_code: result.exitCode, response: result.value },
    );
  }
  return result.value;
}

export function verifyMoonPack(
  cliPath: string,
  packPath: string,
  expectedManifestDigest?: string,
): { exitCode: 0 | 1; report: VerifyReport } {
  const args = ["verify", "--json"];
  if (expectedManifestDigest) {
    assertCanonicalDigest(expectedManifestDigest);
    args.push(
      "--expected-manifest-digest",
      expectedManifestDigest,
    );
  }
  args.push(resolve(packPath));
  const result = runMoonJSON(cliPath, args);
  if (
    (result.exitCode !== 0 && result.exitCode !== 1) ||
    !isVerifyReport(result.value) ||
    (result.value.ok && result.exitCode !== 0) ||
    (!result.value.ok && result.exitCode !== 1)
  ) {
    throw new FabricAdapterError(
      "MOON_VERIFY_FAILED",
      "MoonEvidence verify did not return a verification report",
      { exit_code: result.exitCode, response: result.value },
    );
  }
  return {
    exitCode: result.exitCode as 0 | 1,
    report: result.value,
  };
}
