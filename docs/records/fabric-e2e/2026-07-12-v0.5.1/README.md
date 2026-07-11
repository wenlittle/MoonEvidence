# Fabric v0.5.1 Release Record

This record binds the MoonEvidence `v0.5.1` module archive to a completed
two-organization Hyperledger Fabric transaction flow. The anchored material is
the real `moon package` archive and its SHA-256 sidecar, not a synthetic text
fixture.

## Release Asset

| Field | Value |
| --- | --- |
| Archive | `starlittle-MoonEvidence-0.5.1.zip` |
| Source commit | `38e5a7d80690055b8b8c09b1e040f644f440c616` |
| Size | 741,188 bytes |
| Archive SHA-256 | `b6a69a3547d827624265aa4988ec5f4ec3d1789d7c2e9b178993c7b6e07b7c2b` |
| Evidence manifest | `sha256:fd31247052458a221ec63b8a2ad4e6533a978ecfe5c87b69cb232b1978925722` |
| Merkle root | `sha256:5c9a0e0bcbd7bf1f6e6d2da8d0ae63fdf577f770b40d900fc69eaa25cd60a5d6` |

Two consecutive `moon package` runs and a clean rebuild from the release-prep
commit produced the same 741,188-byte archive and SHA-256 value. The final tag
workflow builds the same module input; this record is updated only after the
published Release checksum is compared with the value above.

## Ledger Result

Org1 submitted the canonical evidence-manifest digest. Fabric committed the
transaction as `VALID` in block 10. Org1 and Org2 then returned the same anchor
record. An Org2 duplicate entered block 11 as `already_anchored` while preserving
the original transaction ID.

| Field | Value |
| --- | --- |
| Runtime | Hyperledger Fabric 3.1.4 |
| Channel | `evidencechannel` |
| Chaincode | `moonevidence` 1.0, sequence 1 |
| First transaction | `da1528196809eb6e1abc86fb6dac09663e8cf66776bad233d2b538404f9233fe` |
| First block | 10 |
| Duplicate block | 11 |
| Channel height after both commits | 12 |

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
