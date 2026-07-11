import assert from "node:assert/strict";
import test from "node:test";

import { assertCanonicalDigest } from "../src/digest.js";
import { FabricAdapterError } from "../src/errors.js";

test("accepts canonical SHA-256 and SHA-512 digests", () => {
  assert.doesNotThrow(() =>
    assertCanonicalDigest("sha256:" + "a".repeat(64)),
  );
  assert.doesNotThrow(() =>
    assertCanonicalDigest("sha512:" + "0".repeat(128)),
  );
});
test("rejects uppercase, truncated, and unsupported digests", () => {
  for (const value of [
    "sha256:" + "A".repeat(64),
    "sha256:1234",
    "md5:" + "0".repeat(32),
  ]) {
    assert.throws(
      () => assertCanonicalDigest(value),
      (error) =>
        error instanceof FabricAdapterError &&
        error.code === "INVALID_MANIFEST_DIGEST",
    );
  }
});
