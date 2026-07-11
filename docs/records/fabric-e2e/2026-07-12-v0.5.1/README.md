# Fabric v0.5.1 Release Record

This record binds the MoonEvidence `v0.5.1` module archive to a completed
two-organization Hyperledger Fabric transaction flow. The anchored material is
the real `moon package` archive and its SHA-256 sidecar, not a synthetic text
fixture.

## Release Asset

| Field | Value |
| --- | --- |
| Archive | `starlittle-MoonEvidence-0.5.1.zip` |
| Source commit | `86d9ce49bbf69d587f5dfee46cfa539f7ceb11e6` |
| Size | 741,180 bytes |
| Archive SHA-256 | `0c462427fe9f6ed6d1186f018a36bae5175db242c9cabf321a00a909073b7b7d` |
| Evidence manifest | `sha256:58410f36cc89b40b2decf79895128bf6ed81c545127f1db6d25e5ce1a154ff69` |
| Merkle root | `sha256:0230021d6f323b62ede761004b0e9ea55f6d6e59eed4f37b8569c956d98108c4` |

Two consecutive `moon package` runs and a clean rebuild from the release-prep
commit produced the same 741,180-byte archive and SHA-256 value. The final tag
workflow builds the same module input; this record is updated only after the
published Release checksum is compared with the value above.

## Ledger Result

Org1 submitted the canonical evidence-manifest digest. Fabric committed the
transaction as `VALID` in block 14. Org1 and Org2 then returned the same anchor
record. An Org2 duplicate entered block 15 as `already_anchored` while preserving
the original transaction ID.

| Field | Value |
| --- | --- |
| Runtime | Hyperledger Fabric 3.1.4 |
| Channel | `evidencechannel` |
| Chaincode | `moonevidence` 1.0, sequence 1 |
| First transaction | `43c9247f5b078ee7b96b71c99d1befcb7898b8cc9af6158b05f0cc43b497802f` |
| First block | 14 |
| Duplicate block | 15 |
| Channel height after both commits | 16 |

## Backfeed Result

The ledger digest was returned to the `v0.5.1` release CLI:

1. The original release evidence pack passed with 2/2 files.
2. Changing the SHA-256 sidecar without rebuilding the manifest produced
   `E2003` at the exact sidecar path.
3. Rebuilding the manifest around that change produced `E2004` against the
   digest retained by Fabric.

## Reproduction Commands

The run used local identity profiles excluded by `.gitignore`. The sanitized
command shape is:

```powershell
moon package
node $cli pack $releaseInput -o $pack --subject-id moonevidence-release-v0.5.1 `
  --subject-type release-artifact --version-id v0.5.1 --json
node $gateway anchor-pack $pack --profile $org1 --moon-cli $cli --json
node $gateway query --profile $org2 --manifest-digest $digest --json
node $gateway verify-anchor $pack --profile $org2 `
  --manifest-digest $digest --moon-cli $cli --json
```

The public files retain no evidence payload, certificate, private key,
connection profile, local absolute path, phone number, or access token.

## Files

| File | Contents |
| --- | --- |
| `deployment.json` | Release artifact, source hashes, Fabric definition, approvals and channel tip |
| `transactions.json` | First commit, cross-organization queries and duplicate receipt |
| `verification.json` | Original pass plus `E2003` and `E2004` backfeed outcomes |
