# Evidence Pack Spec

This is the first local draft. It is intentionally small so implementation can start without scope creep.

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

## Merkle Boundary

The first implementation must document:

- Leaf hash input format.
- Sibling order.
- Left/right position handling.
- Empty tree behavior.
- Single-leaf tree behavior.

