import assert from "node:assert/strict";
import test from "node:test";

import {
  anchorExists,
  queryAnchor,
  submitAnchor,
  type ContractClient,
} from "../src/anchor.js";
import { FabricAdapterError } from "../src/errors.js";
import type { AnchorRecord, CreateAnchorResult } from "../src/types.js";

const digest = "sha256:" + "1".repeat(64);
const encoder = new TextEncoder();

function anchor(
  transactionId = "tx-original",
  submitterMSP = "Org1MSP",
): AnchorRecord {
  return {
    schema: "moon-evidence-anchor/v1",
    manifest_digest: digest,
    transaction_id: transactionId,
    submitter_msp: submitterMSP,
  };
}

function jsonBytes(value: unknown): Uint8Array {
  return encoder.encode(JSON.stringify(value));
}

function fakeContract(options?: {
  create?: CreateAnchorResult;
  successful?: boolean;
  statusCode?: number;
  query?: AnchorRecord;
  queryError?: Error;
}): ContractClient {
  const create = options?.create ?? {
    created: true,
    anchor: anchor("tx-submit"),
  };
  return {
    async submitAsync() {
      return {
        getResult: () => jsonBytes(create),
        async getStatus() {
          return {
            blockNumber: 9n,
            code: options?.statusCode ?? 0,
            successful: options?.successful ?? true,
            transactionId: "tx-submit",
          };
        },
      };
    },
    async evaluateTransaction(name) {
      if (options?.queryError) {
        throw options.queryError;
      }
      if (name === "AnchorExists") {
        return jsonBytes(Boolean(options?.query));
      }
      return jsonBytes(options?.query ?? anchor());
    },
  };
}

test("submits a first anchor and preserves commit evidence", async () => {
  const receipt = await submitAnchor(fakeContract(), digest);
  assert.equal(receipt.outcome, "created");
  assert.equal(receipt.commit.transaction_id, "tx-submit");
  assert.equal(receipt.commit.block_number, "9");
  assert.equal(receipt.commit.status_code, 0);
  assert.equal(receipt.commit.successful, true);
  assert.equal(receipt.anchor.transaction_id, "tx-submit");
});

test("normalizes sequential duplicate result", async () => {
  const receipt = await submitAnchor(
    fakeContract({ create: { created: false, anchor: anchor() } }),
    digest,
  );
  assert.equal(receipt.outcome, "already_anchored");
  assert.equal(receipt.anchor.transaction_id, "tx-original");
});

test("normalizes concurrent MVCC loser only after successful query", async () => {
  const receipt = await submitAnchor(
    fakeContract({
      successful: false,
      statusCode: 11,
      query: anchor("tx-winner", "Org2MSP"),
    }),
    digest,
  );
  assert.equal(receipt.outcome, "already_anchored_after_conflict");
  assert.equal(receipt.commit.successful, false);
  assert.equal(receipt.commit.status_code, 11);
  assert.equal(receipt.anchor.transaction_id, "tx-winner");
});

test("does not hide a rejected commit when no anchor can be queried", async () => {
  await assert.rejects(
    submitAnchor(
      fakeContract({
        successful: false,
        statusCode: 11,
        queryError: new Error("not found"),
      }),
      digest,
    ),
    (error) =>
      error instanceof FabricAdapterError &&
      error.code === "FABRIC_COMMIT_REJECTED",
  );
});

test("does not normalize a non-MVCC rejection even when an anchor exists", async () => {
  await assert.rejects(
    submitAnchor(
      fakeContract({
        successful: false,
        statusCode: 10,
        query: anchor("tx-existing"),
      }),
      digest,
    ),
    (error) =>
      error instanceof FabricAdapterError &&
      error.code === "FABRIC_COMMIT_REJECTED",
  );
});

test("rejects a first-write response with a different transaction ID", async () => {
  await assert.rejects(
    submitAnchor(
      fakeContract({
        create: { created: true, anchor: anchor("tx-not-submit") },
      }),
      digest,
    ),
    (error) =>
      error instanceof FabricAdapterError &&
      error.code === "INVALID_CHAINCODE_RESPONSE",
  );
});

test("query and exists validate chaincode response", async () => {
  assert.deepEqual(
    await queryAnchor(fakeContract({ query: anchor() }), digest),
    anchor(),
  );
  assert.equal(
    await anchorExists(fakeContract({ query: anchor() }), digest),
    true,
  );
  assert.equal(await anchorExists(fakeContract(), digest), false);
});

test("rejects malformed chaincode JSON", async () => {
  const contract: ContractClient = {
    async submitAsync() {
      throw new Error("not used");
    },
    async evaluateTransaction() {
      return encoder.encode("{");
    },
  };
  await assert.rejects(
    queryAnchor(contract, digest),
    (error) =>
      error instanceof FabricAdapterError &&
      error.code === "INVALID_CHAINCODE_RESPONSE",
  );
});
