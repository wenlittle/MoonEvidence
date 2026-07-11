# Evidence Pack Specification

Status: current v0.5.x contract

Contract revision: 1.1, clarified 2026-07-11

Manifest schema: `moon-evidence/v0`

This specification defines the bytes and checks shared by the MoonBit library,
CLI, browser API, and external digest adapters. Revision 1.1 aligns the written
contract with the existing multi-algorithm implementation and does not change
the `moon-evidence/v0` data format.

Version names have separate scopes: v0.5.x identifies the software release,
`moon-evidence/v0` identifies manifest bytes, revision 1.1 identifies this
document, and `/v1` suffixes identify process or adapter envelopes. A
manifest's `version.id` is user data for one evidence release.

## Core Pack

The self-contained core pack has two required entries:

```text
evidence-pack/
  manifest.json
  files/
    ...
```

`pack` and `seal` create this layout. Every source file is copied below
`files/`, including a source file named `manifest.json`.

One optional extension is recognized by the CLI:

```text
evidence-pack/
  versions/
    version_chain.json
```

When present, the CLI validates the version chain and merges its findings into
the verification report. Its absence leaves core-pack verification unchanged.

Inclusion proofs are generated and checked through the Merkle library and
browser API. They are separate exchange artifacts. `pack` does not create a
`proofs/` directory, and complete pack verification does not require one.

## Manifest

```json
{
  "schema": "moon-evidence/v0",
  "subject": {
    "id": "example-pack",
    "type": "dataset"
  },
  "hash_algorithm": "sha256",
  "files": [
    {
      "path": "files/example.txt",
      "size": 12,
      "digest": "sha256:<64 lowercase hex>"
    }
  ],
  "merkle_root": "sha256:<64 lowercase hex>",
  "version": {
    "id": "v1",
    "parent": null
  }
}
```

| Field | Contract |
| --- | --- |
| `schema` | Required string, exactly `moon-evidence/v0` |
| `subject.id` | Required non-empty string |
| `subject.type` | Required non-empty string |
| `hash_algorithm` | Required, `sha256` or `sha512` |
| `files` | Required array; paths are unique and retain array order for Merkle construction |
| `files[].path` | Required pack-relative path satisfying the path rules below |
| `files[].size` | Integer from 0 through `2^53-1` |
| `files[].digest` | Canonical digest using the manifest algorithm |
| `merkle_root` | Required for non-empty `files`; absent or `null` for an empty file set |
| `version.id` | Required non-empty string |
| `version.parent` | Absent, `null`, or a non-empty string |

Unknown fields are accepted for forward compatibility. They remain part of the
canonical full-manifest bytes and therefore affect the external manifest
digest. Merkle leaves contain the validated `path`, `size`, and `digest` fields
only.

## Path Rules

`files[].path` is relative to the pack root. Parsing rejects `E1002` for:

- a leading `/`;
- backslash separators;
- a colon, including drive-letter and NTFS alternate-stream forms;
- empty, `.` or `..` path segments;
- a null byte or control character below U+0020.

Only `/` separates path segments. Path validation completes before any IO
adapter combines the value with the pack root.

## Canonical JSON

The full manifest and each Merkle file entry use RFC 8785 JSON
Canonicalization Scheme semantics:

- object keys sort by UTF-16 code units;
- whitespace is removed;
- strings use deterministic JSON escaping;
- finite numbers use ECMAScript shortest-round-trip formatting;
- `-0` canonicalizes to `0`;
- integer literals beyond `2^53` follow IEEE 754 double parsing semantics.

NaN, Infinity, and literals overflowing the finite double range have no
canonical representation and produce `E1004`.

## Digest Algorithms

The selected `hash_algorithm` drives all digest-bearing fields in one
manifest:

| Algorithm | Digest bytes | Lowercase hex characters | Prefix |
| --- | ---: | ---: | --- |
| SHA-256 | 32 | 64 | `sha256:` |
| SHA-512 | 64 | 128 | `sha512:` |

File digests, the Merkle root, inclusion-proof siblings, and an external
canonical manifest digest all use the selected algorithm. Mixed-algorithm
entries are rejected as `E2002`.

The external manifest digest is:

```text
manifest_digest = H(UTF8(JCS(manifest.json)))
```

It is stored outside the evidence pack when it acts as a historical anchor.
Verification receives it through `expected_manifest_digest` or
`--expected-manifest-digest`.

## Merkle Construction

Let `H` be the manifest's selected SHA-256 or SHA-512 algorithm:

```text
canonical_file_entry = JCS({"digest": ..., "path": ..., "size": ...})
leaf_hash = H(0x00 || UTF8(canonical_file_entry))
node_hash = H(0x01 || left || right)
```

The prefixes separate leaf and internal-node domains.

Tree rules:

- leaves follow the exact `files[]` order;
- an unpaired node is promoted unchanged;
- a node is never paired with itself;
- a single-leaf root equals its leaf hash;
- an empty file set has no Merkle root.

Complete verification rebuilds this root from the manifest entries. It checks
that the manifest's file inventory is internally committed, independently of
the separate per-file byte checks.

### Inclusion Proof

A proof is a bottom-up array:

```json
[
  {
    "sibling": "<64 hex for sha256 or 128 hex for sha512>",
    "side": "left"
  }
]
```

`left` applies `node_hash(sibling, current)` and `right` applies
`node_hash(current, sibling)`. The selected algorithm determines sibling and
root length. A single-leaf tree has an empty proof.

The array travels with four companion values: the canonical file-entry bytes
used as the leaf payload, the selected algorithm, the expected root, and the
target entry identity or index. `generate_proof` returns `algorithm`, `root`,
and `proof`; the caller retains the canonical entry and target identity.
`verify_proof` receives the leaf payload as hex.

Proof generation and proof verification are explicit operations. They do not
replace the complete pack verification flow below. The browser-facing
`verify_proof` API reports malformed requests through its API error envelope;
a well-formed proof that does not reach the supplied root returns
`{"ok":true,"valid":false}`.

## Version Chain Extension

`versions/version_chain.json` is a bare JSON array of nodes. Oldest-first
ordering is conventional; graph semantics determine validity.

```json
[
  { "id": "v1", "parent": null },
  { "id": "v2", "parent": "v1" }
]
```

Rules:

- `id` is required and non-empty;
- `parent` is absent, `null`, or a non-empty string;
- duplicate IDs, missing parents, cycles, multiple roots, and forks are
  rejected by chain verification;
- an empty array parses and then produces `E4001`;
- format errors use the same `E1xxx` family as the manifest.

## Complete Verification

The pure `verify_manifest` operation accepts:

1. manifest JSON text;
2. a map from manifest path to current file bytes;
3. an optional externally stored manifest digest.

It performs:

1. manifest parse and field validation;
2. full-manifest canonicalization;
3. optional external manifest-digest comparison;
4. exhaustive current-file digest checks;
5. unlisted-file detection;
6. Merkle-root reconstruction from manifest entries;
7. report aggregation.

The report contains `ok`, all findings, file counts, and whether the Merkle
root was checked. One file failure does not stop checks for remaining files.

The CLI owns filesystem IO. It reads `manifest.json`, gathers current file
bytes, merges IO findings, and checks `versions/version_chain.json` when that
optional file exists. Inclusion proofs remain a separate API operation.

A payload-only change produces `E2003`; the unchanged manifest's Merkle root
can still be internally valid. Regenerating the file entry changes the Merkle
root and full manifest digest. Comparison with an independently saved old
manifest digest then produces `E2004`.

## Diagnostics

### Manifest and format

| Code | Meaning |
| --- | --- |
| `E1001` | manifest or version JSON cannot be parsed |
| `E1002` | required field missing, empty, wrong type, or invalid path |
| `E1003` | schema unsupported; expected `moon-evidence/v0` |
| `E1004` | canonicalization failed |

### Digest

| Code | Meaning |
| --- | --- |
| `E2001` | hash algorithm unsupported |
| `E2002` | digest form, case, length, or algorithm invalid |
| `E2003` | a listed payload is absent/not supplied, or its current bytes differ from the manifest digest |
| `E2004` | canonical manifest digest differs from an external anchor |

### Merkle

| Code | Meaning |
| --- | --- |
| `E3001` | Merkle root is missing, malformed, or incompatible with an empty file set |
| `E3002` | reserved for adapters that persist proof documents; the v0.5.x CLI has no stored-proof consumer |
| `E3003` | reconstructed manifest Merkle root differs from the recorded root |

### Version chain

| Code | Meaning |
| --- | --- |
| `E4001` | version chain is empty |
| `E4002` | parent reference is missing |
| `E4003` | cycle or unreachable component detected |
| `E4004` | duplicate ID, multiple roots, or a fork detected |

### IO and warning

| Code | Meaning |
| --- | --- |
| `E5001` | a CLI argument path or required manifest path does not exist |
| `E5002` | file or directory operation failed |
| `W1001` | a payload found below the pack's `files/` tree is absent from the manifest; verification may still pass |

Manifest and version-chain verification emit `E1xxx` through `E4xxx` and
`W1xxx`. `E5xxx` belongs to the CLI and filesystem adapter. Browser proof
operations use their own API envelope and boolean `valid` result.

Contract changes that alter accepted bytes or verification results require a
decision-log entry and an explicit schema or compatibility decision.
