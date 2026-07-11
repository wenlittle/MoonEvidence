# Fabric v0.5.1 Release Record

This record binds the MoonEvidence `v0.5.1` module archive to a completed
two-organization Hyperledger Fabric transaction flow. The anchored material is
the real `moon package` archive and its SHA-256 sidecar, not a synthetic text
fixture.

## Release Asset

| Field | Value |
| --- | --- |
| Archive | `starlittle-MoonEvidence-0.5.1.zip` |
| Release | `https://github.com/wenlittle/MoonEvidence/releases/tag/v0.5.1` |
| Tag commit | `c59f93a5918f825a893bfac8dc2006f020d02749` |
| Size | 741,249 bytes |
| Archive SHA-256 | `ab0dd9b6fcd30ce5ee3fc42a4105dd5e5dc4c245ab69e4c60a41a731897b5bd3` |
| Evidence manifest | `sha256:564b79c16878c4fac3d50e5b8b61ac4b82207aa01a45b02fb97210a049a53a0d` |
| Merkle root | `sha256:cd57e042bbe316c55f29bd5789db683f597e883865f57a210d88a11712b4aa77` |

The archive and its published SHA-256 sidecar match exactly. The Mooncakes
`0.5.1` archive has SHA-256
`0c462427fe9f6ed6d1186f018a36bae5175db242c9cabf321a00a909073b7b7d`.
Cross-platform extraction found the same 245 entries: 241 were byte-identical,
and four PowerShell scripts were identical after CRLF/LF normalization. Each
distribution keeps its own published archive checksum.

## Ledger Result

Org1 submitted the canonical evidence-manifest digest. Fabric committed the
transaction as `VALID` in block 16. Org1 and Org2 then returned the same anchor
record. An Org2 duplicate entered block 17 as `already_anchored` while preserving
the original transaction ID.

| Field | Value |
| --- | --- |
| Runtime | Hyperledger Fabric 3.1.4 |
| Channel | `evidencechannel` |
| Chaincode | `moonevidence` 1.0, sequence 1 |
| First transaction | `f004f179600854ee3faea0e2706c08cf938073d969ccd6434fcca3be48965c2d` |
| First block | 16 |
| Duplicate block | 17 |
| Channel height after both commits | 18 |

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
