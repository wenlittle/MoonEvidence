# Mooncakes Collision Check

## Purpose

Before finalizing the topic, check Mooncakes for direct overlap. This file records the check so the project claim can be traced.

## Checked Keywords

```text
moonevidence
evidence
trusted
trust
provenance
attestation
notarization
notary
merkle
content-addressed
```

## Result Summary

As of 2026-06-08 Asia/Shanghai, querying `https://mooncakes.io/api/v0/modules` returned 1310 modules.

Direct hits:

| Keyword | Hit |
| --- | --- |
| `moonevidence` | None |
| `evidence` | None |
| `provenance` | None |
| `attestation` | None |
| `notarization` | None |
| `merkle` | `zploc/loci` |
| `content-addressed` | `zploc/loci` |

## Recheck 2026-06-10 (application gate, master plan step 0 task 7)

As of 2026-06-10 Asia/Shanghai, querying `https://mooncakes.io/api/v0/modules` returned 1315 modules (+5 since last check). Matching ran against `name + description + keywords` with positive control `loci` (hit confirmed, so `None` results are trustworthy).

| Keyword | Hit |
| --- | --- |
| `moonevidence` / `evidence` / `trusted` / `trust` | None |
| `provenance` / `attestation` / `notarization` / `notary` | None |
| `merkle` | `zploc/loci` (unchanged) |
| `content-addressed` | `zploc/loci` (unchanged) |
| `jcs` / `canonical` / `8785` | None |
| `integrity` / `manifest` | None |

New keywords `jcs` / `canonical` / `8785` were added to back the innovation claim "first RFC 8785 (JCS) compatible implementation in the ecosystem": no existing module mentions canonical JSON serialization.

`zploc/loci` re-inspected (v0.1.0, created 2026-04-28): "Deterministic hashing, Merkle tree sealing, FST swarms, and AI inhabitation substrate for the loci runtime" — a runtime substrate, not an evidence pack verifier. No scope overlap; conclusion below still holds.

## Interpretation

MoonEvidence should not be framed as a generic Merkle tree package. The defensible differentiation is:

- Evidence manifest schema.
- Pack-level verification workflow.
- Linear version chain tracing.
- Explainable diagnostics.
- Library + CLI delivery for MoonBit users.

## Recheck Before Submission

Rerun this before project application and before final submission because Mooncakes changes quickly.

