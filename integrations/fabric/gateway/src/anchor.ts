import { assertCanonicalDigest } from "./digest.js";
import { FabricAdapterError } from "./errors.js";
import type {
  AnchorReceipt,
  AnchorRecord,
  CreateAnchorResult,
} from "./types.js";

interface CommitStatus {
  blockNumber: bigint;
  code: number;
  successful: boolean;
  transactionId: string;
}

interface SubmittedCommit {
  getResult(): Uint8Array;
  getStatus(): Promise<CommitStatus>;
}

export interface ContractClient {
  submitAsync(
    transactionName: string,
    options: { arguments: string[] },
  ): Promise<SubmittedCommit>;
  evaluateTransaction(
    transactionName: string,
    ...args: string[]
  ): Promise<Uint8Array>;
}

const decoder = new TextDecoder("utf-8", { fatal: true });
const mvccReadConflictStatusCode = 11;

function decodeJSON(value: Uint8Array, context: string): unknown {
  try {
    return JSON.parse(decoder.decode(value));
  } catch (error) {
    throw new FabricAdapterError(
      "INVALID_CHAINCODE_RESPONSE",
      context + " did not return valid UTF-8 JSON",
      { cause: String(error) },
    );
  }
}

function isObject(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function parseAnchor(value: unknown, expectedDigest: string): AnchorRecord {
  if (
    !isObject(value) ||
    value.schema !== "moon-evidence-anchor/v1" ||
    value.manifest_digest !== expectedDigest ||
    typeof value.transaction_id !== "string" ||
    value.transaction_id.length === 0 ||
    typeof value.submitter_msp !== "string" ||
    value.submitter_msp.length === 0
  ) {
    throw new FabricAdapterError(
      "INVALID_CHAINCODE_RESPONSE",
      "anchor response does not match the requested digest and schema",
    );
  }
  return {
    schema: "moon-evidence-anchor/v1",
    manifest_digest: expectedDigest,
    transaction_id: value.transaction_id,
    submitter_msp: value.submitter_msp,
  };
}

function parseCreateResult(
  value: Uint8Array,
  expectedDigest: string,
): CreateAnchorResult {
  const parsed = decodeJSON(value, "CreateAnchor");
  if (!isObject(parsed) || typeof parsed.created !== "boolean") {
    throw new FabricAdapterError(
      "INVALID_CHAINCODE_RESPONSE",
      "CreateAnchor response is missing created",
    );
  }
  return {
    created: parsed.created,
    anchor: parseAnchor(parsed.anchor, expectedDigest),
  };
}

export async function queryAnchor(
  contract: ContractClient,
  manifestDigest: string,
): Promise<AnchorRecord> {
  assertCanonicalDigest(manifestDigest);
  const result = await contract.evaluateTransaction(
    "ReadAnchor",
    manifestDigest,
  );
  return parseAnchor(decodeJSON(result, "ReadAnchor"), manifestDigest);
}

export async function anchorExists(
  contract: ContractClient,
  manifestDigest: string,
): Promise<boolean> {
  assertCanonicalDigest(manifestDigest);
  const result = decodeJSON(
    await contract.evaluateTransaction("AnchorExists", manifestDigest),
    "AnchorExists",
  );
  if (typeof result !== "boolean") {
    throw new FabricAdapterError(
      "INVALID_CHAINCODE_RESPONSE",
      "AnchorExists response is not boolean JSON",
    );
  }
  return result;
}

export async function submitAnchor(
  contract: ContractClient,
  manifestDigest: string,
): Promise<AnchorReceipt> {
  assertCanonicalDigest(manifestDigest);
  const commit = await contract.submitAsync("CreateAnchor", {
    arguments: [manifestDigest],
  });
  const chaincodeResult = parseCreateResult(
    commit.getResult(),
    manifestDigest,
  );
  const status = await commit.getStatus();
  if (
    status.transactionId.length === 0 ||
    status.blockNumber < 0n ||
    !Number.isInteger(Number(status.code))
  ) {
    throw new FabricAdapterError(
      "INVALID_COMMIT_STATUS",
      "Fabric returned an invalid commit status",
    );
  }
  const commitReceipt = {
    transaction_id: status.transactionId,
    block_number: status.blockNumber.toString(),
    status_code: Number(status.code),
    successful: status.successful,
  };

  if (status.successful) {
    if (
      chaincodeResult.created &&
      chaincodeResult.anchor.transaction_id !== status.transactionId
    ) {
      throw new FabricAdapterError(
        "INVALID_CHAINCODE_RESPONSE",
        "a newly created anchor must record the committing transaction ID",
      );
    }
    return {
      schema: "moon-evidence-fabric-receipt/v1",
      ok: true,
      outcome: chaincodeResult.created ? "created" : "already_anchored",
      manifest_digest: manifestDigest,
      anchor: chaincodeResult.anchor,
      commit: commitReceipt,
    };
  }

  if (Number(status.code) !== mvccReadConflictStatusCode) {
    throw new FabricAdapterError(
      "FABRIC_COMMIT_REJECTED",
      "CreateAnchor transaction did not commit",
      {
        transaction_id: status.transactionId,
        block_number: status.blockNumber.toString(),
        status_code: Number(status.code),
      },
    );
  }

  // Two concurrent first submissions can both endorse an empty key. Fabric
  // commits one and rejects the other with an MVCC conflict. Querying after
  // the failed status makes the client operation idempotent without hiding
  // the rejected transaction details in the receipt.
  try {
    const existing = await queryAnchor(contract, manifestDigest);
    return {
      schema: "moon-evidence-fabric-receipt/v1",
      ok: true,
      outcome: "already_anchored_after_conflict",
      manifest_digest: manifestDigest,
      anchor: existing,
      commit: commitReceipt,
    };
  } catch (queryError) {
    throw new FabricAdapterError(
      "FABRIC_COMMIT_REJECTED",
      "CreateAnchor transaction did not commit and no matching anchor was found",
      {
        transaction_id: status.transactionId,
        block_number: status.blockNumber.toString(),
        status_code: Number(status.code),
        query_error: String(queryError),
      },
    );
  }
}
