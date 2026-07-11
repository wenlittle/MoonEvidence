# Fabric E2E Record - 2026-07-11

This directory preserves the sanitized result set from a MoonEvidence
digest-anchor run against a live two-organization Hyperledger Fabric network.
Unit tests and CI cover adapter branches separately; this record captures the
protocol boundary, transaction context, channel state, cross-organization
queries, and digest backfeed observed during the run.

## Topology And Deployment

- Fabric runtime: v3.1.4 peers and orderer, two peer organizations.
- Dedicated channel: `evidencechannel`.
- Chaincode: `moonevidence`, version 1.0, sequence 1.
- Endorsement: channel default policy; both Org1MSP and Org2MSP approved.
- Package ID:
  `moonevidence_1.0:40f8ec7d43ff2d659825a9759cec1bea0a1f059e3149ddd08a0757ffd41bdafb`.
- Both peers reported the same committed definition and the same channel tip.

The local Fabric CLI was a Dockerized v2.5.15 compatibility client that only
mounted `/root`. The exact repository chaincode source was therefore copied to
a private ASCII-only WSL cache path before lifecycle packaging. Source hashes
are captured in `deployment.json`; no source file was rewritten for deployment.

## Executed Flow

1. MoonEvidence `inspect --json` derived the canonical digest of
   `examples/valid-pack`.
2. MoonEvidence `verify --expected-manifest-digest` verified the pack locally.
3. The Org1 Gateway submitted only that digest to `CreateAnchor`.
4. Fabric committed transaction
   `ca3dc7810d375ddabd3ba7d0bbba6f3e95a48c1224c6dfbd892d50edf7a28393`
   as `VALID` in block 6.
5. Org1 and Org2 independently queried the same first-write anchor record.
6. Org2 submitted the digest again. The chaincode returned
   `already_anchored`; the original anchor transaction ID remained unchanged.
7. The ledger digest was fed back into MoonEvidence verification:
   - original pack: pass;
   - payload changed without manifest change: exactly `E2003`;
   - payload changed and manifest regenerated: exactly `E2004` against the
     original ledger anchor.

## Files

| File | Contents |
| --- | --- |
| `deployment.json` | Tool/runtime versions, source hashes, chaincode definition, channel tip |
| `transactions.json` | First commit, Org1/Org2 queries, and idempotent Org2 duplicate |
| `verification.json` | Original, payload-tampered, and repacked verification envelopes |

All records are sanitized. They contain no evidence payloads, full manifests,
file paths, certificates, private keys, connection profiles, phone numbers, or
access tokens.

## Evidence Layers

| Layer | Evidence |
| --- | --- |
| Chaincode and Gateway behavior | Public source, required [CI workflow](https://github.com/wenlittle/MoonEvidence/actions/workflows/ci.yml), and the current [results log](../../RESULTS_LOG.md) |
| Protocol observation | Runtime and source hashes in `deployment.json`; transaction IDs, blocks, validation codes, organization queries, and channel tip hashes in this directory |
| Local verification | Original, payload-only change, and regenerated-manifest reports in `verification.json` |
| Reproduction | Deployment, profile, submit, query, and backfeed commands in the [Fabric integration guide](../../../../integrations/fabric/README.md) |

The transaction and channel identifiers can be checked by members retaining
access to the recorded channel. Public reviewers can inspect the sanitized
operator record, compare source hashes, and replay an equivalent workflow on
Fabric samples test-network; the public artifacts do not expose the original
private channel for independent queries.

## Interpretation

The combined record is evidence that the run crossed Fabric Gateway,
endorsement, ordering, validation, world-state, and cross-organization query
boundaries. Transaction ID, block number, validation status, equal organization
queries, and channel tip hashes form the commit trace. Fabric proposal
timestamps are excluded from trusted-time claims.

Rerun instructions and configuration boundaries are in
`integrations/fabric/README.md`; the frozen contracts are in
`docs/spec/CLI_MACHINE_CONTRACT.md` and `docs/spec/FABRIC_ANCHOR_SPEC.md`.
