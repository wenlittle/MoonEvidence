# Fabric Anchor Contract v1

Status: frozen for the first reproducible Hyperledger Fabric experiment.

## Purpose

The contract records that a Fabric identity submitted a MoonEvidence canonical
manifest digest. MoonEvidence remains responsible for manifest creation,
canonicalization, hashing, Merkle construction, and local verification.

The contract does not claim that the submitter verified the files before
anchoring. Consumers prove that separately by querying the anchor and passing
its manifest_digest to MoonEvidence verification.

## Privacy Boundary

The only client-supplied transaction argument is the canonical manifest digest.
The following data must not be sent as transaction arguments or ledger state:

- original files or full manifest JSON;
- file names, file paths, per-file digests, or Merkle leaves;
- subject/version metadata or local audit logs;
- absolute paths, private keys, access tokens, or connection credentials.

Fabric records transaction arguments in block data. Omitting a field from world
state alone does not make that field private.

## State

World-state key:

~~~text
anchor:<manifest_digest>
~~~

State value:

~~~json
{
  "schema": "moon-evidence-anchor/v1",
  "manifest_digest": "sha256:<64 lowercase hex>",
  "transaction_id": "<Fabric transaction ID>",
  "submitter_msp": "Org1MSP"
}
~~~

SHA-512 with 128 lowercase hexadecimal characters is also accepted for
compatibility with the MoonEvidence manifest algorithm. The competition
experiment uses SHA-256.

The transaction proposal timestamp is deliberately absent. Fabric
GetTxTimestamp() reads the timestamp supplied in the transaction channel
header; it is consistent across endorsers but is not an independent trusted
clock. The off-chain receipt records transaction ID, block number, and commit
validation status.

## Transactions

### CreateAnchor(manifestDigest)

- Rejects a non-canonical digest before touching state.
- Derives the state key from the digest.
- On first submission, stores a record derived from Fabric transaction context
  and emits AnchorCreated with that record as JSON payload.
- On a sequential duplicate, returns the original record with created:false;
  it does not overwrite state or emit another event.
- Concurrent duplicates may produce validation code 11 (`MVCC_READ_CONFLICT`).
  Only for that code may the Gateway query the key and normalize an identical
  existing record to `already_anchored_after_conflict`. Every other rejected
  commit remains an error even if an older matching anchor exists.

Response:

~~~json
{
  "created": true,
  "anchor": {
    "schema": "moon-evidence-anchor/v1",
    "manifest_digest": "sha256:<64 lowercase hex>",
    "transaction_id": "<first transaction ID>",
    "submitter_msp": "Org1MSP"
  }
}
~~~

### ReadAnchor(manifestDigest)

Returns the immutable record. Missing or corrupted state is an error.

### AnchorExists(manifestDigest)

Returns a boolean. A state read failure is an error.

There is no update or delete transaction in v1.

## Stable Error Prefixes

| Prefix | Meaning |
| --- | --- |
| MEANCHOR_INVALID_DIGEST | Digest is not canonical SHA-256/SHA-512 |
| MEANCHOR_IDENTITY_FAILED | Invoking MSP could not be derived |
| MEANCHOR_TXID_MISSING | Fabric transaction context has no transaction ID |
| MEANCHOR_READ_FAILED | World-state read failed |
| MEANCHOR_WRITE_FAILED | World-state write failed |
| MEANCHOR_EVENT_FAILED | Chaincode event creation failed |
| MEANCHOR_NOT_FOUND | No anchor exists for the digest |
| MEANCHOR_CORRUPT_STATE | Existing JSON is invalid or conflicts with its key |

Clients branch on the prefix, not the remainder of the message.

## Endorsement And Deployment

- Chaincode name: moonevidence
- Initial version/sequence: 1.0 / 1
- Channel for the local experiment: evidencechannel
- Endorsement: channel default MAJORITY; no Org1-only override
- Test topology: Fabric samples test-network, two peer organizations

The samples test-network is an integration environment, not a production
network topology or legal timestamp service.
