# Fabric v0.5.1 Release Record

This record binds the MoonEvidence `v0.5.1` module archive to a completed
two-organization Hyperledger Fabric transaction flow. The anchored material is
the real `moon package` archive and its SHA-256 sidecar, not a synthetic text
fixture.

## Release Asset

| Field | Value |
| --- | --- |
| Archive | `starlittle-MoonEvidence-0.5.1.zip` |
| Source commit | `fd5c7aa46a8e510497f6271a0c00c5812093d181` |
| Size | 740,918 bytes |
| Archive SHA-256 | `7208a2518994b0092540527f6a35dcbb0143a8d90379e2d8ed4ab4476479a3ef` |
| Evidence manifest | `sha256:2435ee0178697fbde634615f85b7458667a5bd00d56ba5d7ecdd361dfb2d3cb6` |
| Merkle root | `sha256:93ad81040ee35c8ff414a8d897e5c6bbb26798dc6f25c8dd3f1352e8cd7cbb07` |

Two consecutive `moon package` runs and a clean rebuild from the release-prep
commit produced the same 740,918-byte archive and SHA-256 value. The final tag
workflow builds the same module input; this record is updated only after the
published Release checksum is compared with the value above.

## Ledger Result

Org1 submitted the canonical evidence-manifest digest. Fabric committed the
transaction as `VALID` in block 8. Org1 and Org2 then returned the same anchor
record. An Org2 duplicate entered block 9 as `already_anchored` while preserving
the original transaction ID.

| Field | Value |
| --- | --- |
| Runtime | Hyperledger Fabric 3.1.4 |
| Channel | `evidencechannel` |
| Chaincode | `moonevidence` 1.0, sequence 1 |
| First transaction | `a6d812ac78e8b933d78f85f743fa8e067dc388f0083afb22b775a6884f4529dc` |
| First block | 8 |
| Duplicate block | 9 |
| Channel height after both commits | 10 |

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
