# Decision Log

## 2026-06-11: Manifest Path Hardening (spec hardening, step 7)

Decision: `Manifest::parse` rejects entry paths that are absolute, contain
backslashes or colons, or contain `..` / `.` / empty segments (E1002).

Reason:

- Step-6 security review: a hostile manifest could list
  `files/../../outside.txt` and make the CLI adapter read files outside the
  pack root (path concatenation in `main.mbt`).
- `.`/empty segments alias another entry (`files/./a.txt` vs `files/a.txt`)
  and would slip past the duplicate-path check, allowing two entries with
  conflicting digests for one disk file.
- Colons cover both Windows drive letters and NTFS alternate data streams.
- Parse-time rejection keeps the rule in one place; the pure pipeline and
  the IO adapter never see a hostile path.

Hardening within frozen v1 (tightens accepted inputs, never loosens):
documented in the spec under "File Path Constraints".

## 2026-06-11: Version Chain File Shape (spec clarification)

Decision: `versions/version_chain.json` is a bare JSON array of
`{ "id", "parent" }` nodes, oldest-first; empty arrays parse and `E4001` is a
verification finding, not a parse error.

Reason:

- The frozen v1 spec listed the file in the pack layout but never froze its
  shape; the model package (step 4) needed one.
- A bare array is the minimal shape that supports linear chains; a wrapper
  object adds nothing while the chain is linear (DAG stays out of MVP).
- Parse/verify split mirrors the manifest design: shape errors raise
  `ModelError` (E1xxx), semantic errors (empty/broken/cyclic/forked chain,
  E4xxx) become structured findings so the CLI can explain them.

This is a clarification (filling an undefined gap), not a change to frozen
semantics, so the spec stays at v1 with an "added" note.

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

