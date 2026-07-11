import assert from "node:assert/strict";
import test from "node:test";

import {
  FabricAdapterError,
  assertCanonicalDigest,
  connectFabric,
  inspectMoonPack,
  loadFabricProfile,
  queryAnchor,
  resolveMoonCli,
  submitAnchor,
  verifyMoonPack,
} from "../src/index.js";

test("public entry point exports the supported adapter surface", () => {
  for (const value of [
    assertCanonicalDigest,
    connectFabric,
    inspectMoonPack,
    loadFabricProfile,
    queryAnchor,
    resolveMoonCli,
    submitAnchor,
    verifyMoonPack,
  ]) {
    assert.equal(typeof value, "function");
  }
  assert.equal(typeof FabricAdapterError, "function");
});
