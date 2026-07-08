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

## Recheck 2026-07-05 (pre-submission gate, full keyword sweep)

As of 2026-07-05 Asia/Shanghai, querying `https://mooncakes.io/api/v0/modules` returned **1400 modules** (+85 since the 2026-06-10 check). Matching ran against `name + description + keywords` (case-insensitive). Positive controls: `merkle` and `canonical` both self-hit `starlittle/MoonEvidence`, so zero-count results are trustworthy.

MoonEvidence itself is now registered: `starlittle/MoonEvidence` v0.3.0 (created 2026-06-18).

### Keyword-by-keyword results

| Keyword | Match count | Matches (excluding self where noted) | Functional overlap with MoonEvidence? |
| --- | --- | --- | --- |
| `ed25519` | 1 | `hustcer/ed25519` v0.5.0 (created 2026-06-12) — pure MoonBit Ed25519 signing and verification | No — cryptographic primitive, not an evidence-pack system |
| `sha256` | 5 | `gmlewis/sha256`, `shu-kitamura/sha256`, `Tigls/mb-hash` (SHA-256/512), `Tigls/mb-hmac` (HMAC-SHA256/512), `mizchi/simd` (SIMD SHA-256/512) | No — hash/HMAC primitives only |
| `digest` | 0 | — | — |
| `crypto` | 22 | AEGIS, AES/Rijndael, RSA, P-256/ECDSA, ChaCha20, JWT, Keccak256, Dilithium, getrandom, mooncrypto, etc. | No — all primitives/libraries, none is an evidence verifier |
| `hash` | 24 | SwissTable, xxHash, rapidhash, crc32, md5, sha1, bloom filters, indexmap, etc. | No — hash primitives & data structures |
| `merkle` | 2 | `starlittle/MoonEvidence` (self); `zploc/loci` v0.1.0 (unchanged) | No — `zploc/loci` is an AI inhabitation substrate; Merkle tree sealing is a sub-feature with no Ed25519 / evidence packs / RFC 8785 / audit logs |
| `evidence` | 1 | `starlittle/MoonEvidence` (self only) | No competitor |
| `audit` | 2 | `clhhhhh/moon-csv-lite` (CSV quality toolkit); `Tino-hue/depsight` (dependency health diagnostic) | No — neither is crypto/evidence related |
| `signature` | 2 | `hustcer/ed25519` (primitive); `ruifeng/moondsa` (Dilithium post-quantum) | No — signature primitives |
| `canonical` | 2 | `Luna-Flow/luna-poly` (polynomial canonical form — unrelated); `starlittle/MoonEvidence` (self) | No |
| `json` | 50 | JSON parsers/serializers/schema validators (jq clones, JSONPath, JSON-RPC, jsonschema, etc.) | No — none mention canonical JSON or RFC 8785 |
| `rfc 8785` / `rfc8785` / `8785` / `jcs` | 0 | — | — |

### Verdict (2026-07-05)

- **Claim: "First RFC 8785 (JCS) implementation in the Mooncakes ecosystem."** — **SUPPORTED.** Zero matches for `rfc 8785`, `rfc8785`, `8785`, and `jcs` across all 1400 modules; `canonical` only self-matches. No existing module advertises canonical JSON serialization.
- **Claim: "No functional competitors."** — **SUPPORTED.** The only non-self `merkle` hit (`zploc/loci`) is a different-domain runtime substrate. All remaining hits are cryptographic primitives (Ed25519, SHA-256/512, hashes, Dilithium, RSA, ECDSA) or unrelated JSON/audit/CSV tools — building blocks MoonEvidence consumes, not competing trusted-evidence-pack verifiers. No module combines Ed25519 signatures + Merkle trees + SHA-256/512 digests + RFC 8785 canonical JSON + audit logs.

## Interpretation

MoonEvidence should not be framed as a generic Merkle tree package. The defensible differentiation is:

- Evidence manifest schema.
- Pack-level verification workflow.
- Linear version chain tracing.
- Explainable diagnostics.
- Library + CLI delivery for MoonBit users.
- RFC 8785 (JCS) canonical JSON serialization — unique in the ecosystem as of 2026-07-08.

## Recheck 2026-07-08 (pre-acceptance version-sync gate)

As of 2026-07-08 Asia/Shanghai, querying `https://mooncakes.io/api/v0/modules` returned **1485 modules**. MoonEvidence is registered as `starlittle/MoonEvidence` v0.4.0 with Apache-2.0 license and repository `https://github.com/wenlittle/MoonEvidence.git`.

Focused overlap check:

| Keyword | Matches | Functional overlap with MoonEvidence? |
| --- | --- | --- |
| `moonevidence` | `starlittle/MoonEvidence` | Self |
| `rfc 8785` / `rfc8785` / `8785` / `jcs` | None | No competitor |
| `canonical` | `Luna-Flow/luna-poly`; `starlittle/MoonEvidence` | No - `luna-poly` is polynomial canonical form, not canonical JSON |
| `merkle` | `zploc/loci`; `starlittle/MoonEvidence` | No - `loci` remains a different-domain runtime substrate |

Result: the release version mismatch is closed (`moon.mod` 0.4.0 == Mooncakes 0.4.0), and the RFC 8785/JCS uniqueness claim remains supported.

## Recheck 2026-07-09 (package-hygiene sync)

As of 2026-07-09 Asia/Shanghai, querying `https://mooncakes.io/api/v0/modules`
returned **1497 modules**. MoonEvidence is registered as
`starlittle/MoonEvidence` v0.4.1 with Apache-2.0 license and repository
`https://github.com/wenlittle/MoonEvidence.git`.

Result: the installable Mooncakes package now matches the current repository
package hygiene rules and reviewer-facing documentation. The version-sync gate
is `moon.mod` 0.4.1 == Mooncakes 0.4.1.

Rerun this before project application and before final submission because Mooncakes changes quickly. Last recheck: 2026-07-08 (1485 modules).
