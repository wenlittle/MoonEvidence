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

- Object keys are sorted by UTF-16 code units (RFC 8785 §3.2.3).
- Whitespace is eliminated.
- Strings use deterministic escaping.
- Numbers need a carefully documented subset until full RFC-compatible number formatting is verified.

Number formatting is delivered in two levels:

- **L1 (safe subset, frozen):** integers with |n| ≤ 2^53-1 pass through, `-0`
  normalizes to `0`. Any number whose canonical form cannot be guaranteed
  (decimals, exponents) is rejected.
- **L2 (full RFC 8785):** ECMAScript shortest-representation formatting,
  delivered as a later hardening step.

If a JSON number cannot be canonicalized safely, fail with `E1004` rather than guessing.

## Error Codes (frozen)

Every verification failure maps to exactly one stable code. Codes are part of
the public contract: tests assert exact code sets and the CLI prints them.

### E1xxx — manifest / format

| Code | Meaning |
| --- | --- |
| E1001 | manifest JSON cannot be parsed |
| E1002 | required manifest field missing or empty |
| E1003 | schema version not supported (must be `moon-evidence/v0`) |
| E1004 | canonicalization failed (includes unsupported number forms) |

### E2xxx — digest

| Code | Meaning |
| --- | --- |
| E2001 | hash algorithm not supported |
| E2002 | digest string format invalid (`<algo>:<lowercase-hex>` expected) |
| E2003 | file content digest does not match manifest entry |
| E2004 | manifest canonical digest does not match recorded value |

### E3xxx — merkle

| Code | Meaning |
| --- | --- |
| E3001 | merkle root missing, empty, or ill-formed while `files[]` is non-empty |
| E3002 | proof format invalid (bad sibling hex, unknown side, wrong length) |
| E3003 | proof verification failed (recomputed root differs) |

### E4xxx — version chain

| Code | Meaning |
| --- | --- |
| E4001 | version chain is empty |
| E4002 | parent reference broken (parent id not found) |
| E4003 | cycle detected in version chain |
| E4004 | multiple heads / fork detected (chain must be linear) |

### E5xxx — IO / CLI (adapter layer only)

| Code | Meaning |
| --- | --- |
| E5001 | path does not exist |
| E5002 | file read failed |

### W1xxx — warnings (verification still passes)

| Code | Meaning |
| --- | --- |
| W1001 | file present in pack but not listed in manifest |

Pure library packages may only emit `E1xxx`–`E4xxx` and `W1xxx`; `E5xxx` is
reserved for the CLI/IO adapter so the verification core stays IO-free.

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

