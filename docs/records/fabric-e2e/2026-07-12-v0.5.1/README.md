# Fabric v0.5.1 Release Record

This record binds the MoonEvidence `v0.5.1` module archive to a completed
two-organization Hyperledger Fabric transaction flow. The anchored material is
the real `moon package` archive and its SHA-256 sidecar, not a synthetic text
fixture.

## Release Asset

| Field | Value |
| --- | --- |
| Archive | `starlittle-MoonEvidence-0.5.1.zip` |
| Source commit | `9352e08c3b7fb6ab40f5fe8a9793782bddc5d406` |
| Size | 741,143 bytes |
| Archive SHA-256 | `2d47fff645044767e16d0d2bebbd06092ccca6bef344a09adc1759d017fcfa35` |
| Evidence manifest | `sha256:91bf70a0194e849c9ff692272fad0da1194e83051b52424feacf951f3ca3870e` |
| Merkle root | `sha256:0ca102a3b216fbaf028d0fd754954eadae63ba8d66fd6becb994f5e41e909cf0` |

Two consecutive `moon package` runs and a clean rebuild from the release-prep
commit produced the same 741,143-byte archive and SHA-256 value. The final tag
workflow builds the same module input; this record is updated only after the
published Release checksum is compared with the value above.

## Ledger Result

Org1 submitted the canonical evidence-manifest digest. Fabric committed the
transaction as `VALID` in block 12. Org1 and Org2 then returned the same anchor
record. An Org2 duplicate entered block 13 as `already_anchored` while preserving
the original transaction ID.

| Field | Value |
| --- | --- |
| Runtime | Hyperledger Fabric 3.1.4 |
| Channel | `evidencechannel` |
| Chaincode | `moonevidence` 1.0, sequence 1 |
| First transaction | `77dfcf43cad878a8f0eba42ed12ead827940f9b072560f44832039d361896018` |
| First block | 12 |
| Duplicate block | 13 |
| Channel height after both commits | 14 |

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
