import assert from "node:assert/strict";
import {
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";

import { FabricAdapterError } from "../src/errors.js";
import { loadFabricProfile } from "../src/profile.js";

function withFixture(
  callback: (directory: string, profilePath: string) => void,
): void {
  const directory = mkdtempSync(join(tmpdir(), "me-fabric-profile-"));
  try {
    for (const name of ["tls.pem", "cert.pem", "key.pem"]) {
      writeFileSync(join(directory, name), name);
    }
    const profilePath = join(directory, "profile.json");
    writeFileSync(
      profilePath,
      JSON.stringify({
        schema: "moon-evidence-fabric-profile/v1",
        channel: "evidencechannel",
        chaincode: "moonevidence",
        msp_id: "Org1MSP",
        peer_endpoint: "localhost:7051",
        peer_host_alias: "peer0.org1.example.com",
        tls_certificate_path: "tls.pem",
        certificate_path: "cert.pem",
        private_key_path: "key.pem",
      }),
    );
    callback(directory, profilePath);
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
}

test("loads relative credential paths and default timeouts", () => {
  withFixture((directory, profilePath) => {
    const profile = loadFabricProfile(profilePath);
    assert.equal(profile.channel, "evidencechannel");
    assert.equal(profile.msp_id, "Org1MSP");
    assert.equal(profile.certificate_path, join(directory, "cert.pem"));
    assert.deepEqual(profile.timeouts_ms, {
      evaluate: 5_000,
      endorse: 15_000,
      submit: 5_000,
      commit_status: 60_000,
    });
  });
});

test("rejects missing credential files", () => {
  withFixture((_directory, profilePath) => {
    const profile = JSON.parse(
      readFileSync(profilePath, "utf8"),
    ) as Record<string, unknown>;
    profile.private_key_path = "missing.pem";
    writeFileSync(profilePath, JSON.stringify(profile));
    assert.throws(
      () => loadFabricProfile(profilePath),
      (error) =>
        error instanceof FabricAdapterError &&
        error.code === "PROFILE_FILE_NOT_FOUND",
    );
  });
});

test("rejects non-positive timeout overrides", () => {
  withFixture((_directory, profilePath) => {
    const profile = JSON.parse(
      readFileSync(profilePath, "utf8"),
    ) as Record<string, unknown>;
    profile.timeouts_ms = { evaluate: 0 };
    writeFileSync(profilePath, JSON.stringify(profile));
    assert.throws(
      () => loadFabricProfile(profilePath),
      (error) =>
        error instanceof FabricAdapterError &&
        error.code === "INVALID_PROFILE",
    );
  });
});

test("rejects a non-object timeout section", () => {
  withFixture((_directory, profilePath) => {
    const profile = JSON.parse(
      readFileSync(profilePath, "utf8"),
    ) as Record<string, unknown>;
    profile.timeouts_ms = "fast";
    writeFileSync(profilePath, JSON.stringify(profile));
    assert.throws(
      () => loadFabricProfile(profilePath),
      (error) =>
        error instanceof FabricAdapterError &&
        error.code === "INVALID_PROFILE",
    );
  });
});
