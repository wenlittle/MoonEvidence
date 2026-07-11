import assert from "node:assert/strict";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";

import { FabricAdapterError } from "../src/errors.js";
import {
  inspectMoonPack,
  resolveMoonCli,
  verifyMoonPack,
} from "../src/moon-cli.js";

const digest = "sha256:" + "1".repeat(64);

async function withCli(
  source: string,
  callback: (cliPath: string, directory: string) => Promise<void> | void,
): Promise<void> {
  const directory = mkdtempSync(join(tmpdir(), "me-fabric-cli-"));
  const cliPath = join(directory, "fake-cli.js");
  try {
    writeFileSync(cliPath, source);
    await callback(cliPath, directory);
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
}

function report(ok: boolean): object {
  return {
    ok,
    findings: ok
      ? []
      : [{ code: "E2003", severity: "error", path: "files/a", message: "changed" }],
    stats: { files_total: 1, files_passed: ok ? 1 : 0, merkle_checked: true },
  };
}

test("runs inspect and verify through an explicit JavaScript CLI", async () => {
  const inspect = {
    schema: "moon-evidence-inspect/v1",
    ok: true,
    pack_path: "pack",
    manifest_path: "pack/manifest.json",
    manifest_digest: digest,
    merkle_root: digest,
    algorithm: "sha256",
    files_total: 1,
    subject: { id: "sample", type: "dataset" },
    version: { id: "v1", parent: null },
  };
  await withCli(
    `const command = process.argv[2];\n` +
      `console.log(JSON.stringify(command === "inspect" ? ${JSON.stringify(inspect)} : ${JSON.stringify(report(true))}));\n`,
    (cliPath, directory) => {
      assert.deepEqual(inspectMoonPack(cliPath, directory), inspect);
      const verified = verifyMoonPack(cliPath, directory, digest);
      assert.equal(verified.exitCode, 0);
      assert.equal(verified.report.ok, true);
    },
  );
});

test("preserves a semantic verifier rejection and exit code one", async () => {
  await withCli(
    `console.log(${JSON.stringify(JSON.stringify(report(false)))}); process.exitCode = 1;\n`,
    (cliPath, directory) => {
      const verified = verifyMoonPack(cliPath, directory, digest);
      assert.equal(verified.exitCode, 1);
      assert.equal(verified.report.ok, false);
      assert.equal(verified.report.findings[0]?.code, "E2003");
    },
  );
});

test("rejects incomplete inspect output and inconsistent verify status", async () => {
  await withCli(
    `console.log(JSON.stringify({ok:true, manifest_digest:${JSON.stringify(digest)}}));\n`,
    (cliPath, directory) => {
      assert.throws(
        () => inspectMoonPack(cliPath, directory),
        (error) =>
          error instanceof FabricAdapterError &&
          error.code === "MOON_INSPECT_FAILED",
      );
    },
  );
  await withCli(
    `console.log(${JSON.stringify(JSON.stringify(report(true)))}); process.exitCode = 1;\n`,
    (cliPath, directory) => {
      assert.throws(
        () => verifyMoonPack(cliPath, directory, digest),
        (error) =>
          error instanceof FabricAdapterError &&
          error.code === "MOON_VERIFY_FAILED",
      );
    },
  );
});

test("resolves an explicit CLI and rejects a missing path", async () => {
  await withCli("console.log('{}');\n", (cliPath, directory) => {
    assert.equal(resolveMoonCli(cliPath), cliPath);
    assert.throws(
      () => resolveMoonCli(join(directory, "missing.js")),
      (error) =>
        error instanceof FabricAdapterError &&
        error.code === "MOON_CLI_NOT_FOUND",
    );
  });
});
