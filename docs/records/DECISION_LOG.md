# Decision Log

## 2026-06-08: Project Direction

Decision: Use MoonEvidence as the competition project direction.

Reason:

- Fits MoonBit open-source ecosystem contribution better than a vertical blockchain demo.
- Mooncakes search did not show a direct evidence/provenance/attestation package.
- Merkle-only direction has collision risk, so Merkle should be a submodule rather than the project identity.
- The scope can fit the competition range if signing, multi-chain integration, and full provenance compatibility stay out of MVP.

## 2026-06-08: MVP Boundary

Decision: MVP is verification-first.

Included:

- Canonical JSON subset.
- SHA-256 digest wrapper.
- Manifest validation.
- File digest validation.
- Merkle proof verification.
- Linear version chain validation.
- Structured diagnostics.
- CLI `verify` and `explain`.

Excluded:

- Full evidence pack generation.
- Smart contract adapters.
- PKI/signing framework.
- Version DAG.
- Authorization snapshot.

