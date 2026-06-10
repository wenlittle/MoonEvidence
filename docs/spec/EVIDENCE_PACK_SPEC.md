# Evidence Pack Spec

**Version: v1 (frozen 2026-06-10)**

This spec is frozen for the first implementation milestone. Changes after this point require a new entry in `docs/records/DECISION_LOG.md` and a version bump note here. The scope is intentionally small so implementation can proceed without scope creep.

## Pack Layout

```text
evidence-pack/
  manifest.json
  files/
    ...
  proofs/
    ...
  versions/
    version_chain.json
```

## Manifest Fields

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
      "digest": "sha256:..."
    }
  ],
  "merkle_root": "sha256:...",
  "version": {
    "id": "v1",
    "parent": null
  }
}
```

## Verification Semantics

The verifier should check:

1. Manifest JSON can be parsed and canonicalized.
2. Manifest canonical digest matches the recorded value when present.
3. Each listed file exists.
4. Each file digest matches the manifest entry.
5. Merkle proofs match the expected root.
6. Version chain is linear and every child references the expected parent.
7. Failures are returned as structured diagnostics.

## Canonical JSON Boundary

The first implementation should follow RFC 8785-style deterministic serialization where practical:

- Object keys are sorted.
- Whitespace is eliminated.
- Strings use deterministic escaping.
- Numbers need a carefully documented subset until full RFC-compatible number formatting is verified.

If a JSON number cannot be canonicalized safely, return `InvalidCanonicalJson` rather than guessing.

## Merkle Boundary (frozen)

The Merkle construction follows RFC 6962 style domain separation so leaf hashes
can never be confused with internal node hashes (second-preimage defense).

### Hash encoding

```text
leaf_hash = SHA256(0x00 || canonical_file_entry_bytes)
node_hash = SHA256(0x01 || left || right)
```

- `canonical_file_entry_bytes` is the UTF-8 encoding of the canonicalized JSON
  of one manifest `files[]` entry (path, size, digest fields included).
- `left` and `right` are the raw 32-byte child hashes, concatenated in order.

### Tree shape rules

- **Leaf order:** leaves follow the exact order of `files[]` in the manifest.
- **Odd level handling:** an unpaired node is promoted to the next level as-is.
  It is never paired with itself; self-pairing enables the duplicate-leaf
  attack documented in Bitcoin CVE-2012-2459.
- **Single-leaf tree:** `root = leaf_hash(entry)`. No node hash is applied.
- **Empty tree:** there is no valid empty-tree root. If `files[]` is non-empty,
  `merkle_root` must be present and well-formed. A `merkle_root` field that is
  omitted or is an empty/ill-formed string is reported as `E3001`.

### Proof format

```text
proof = [ { "sibling": "<64-char lowercase hex>", "side": "left" | "right" } ]
```

- `side` describes the sibling position relative to the running hash:
  `left` means `node_hash(sibling, current)`, `right` means
  `node_hash(current, sibling)`.
- Proof entries are ordered bottom-up (leaf level first).
- Verification recomputes from the leaf hash and compares the final value with
  `merkle_root` byte-for-byte.

