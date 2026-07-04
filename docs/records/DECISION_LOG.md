# Decision Log

## 2026-06-11: Number Serialization L2 via Core Double::to_string (step 8)

Decision: canonjson numbers upgrade from the L1 safe subset to the full
RFC 8785 §3.2.2.3 ECMAScript algorithm by delegating finite doubles to
MoonBit core `Double::to_string`, with the RFC 8785 Appendix B vector table
(all 24 published edge cases, bit-pattern level) plus the cyberphone
`values.json` mixed vector pinning the behavior on both js and wasm-gc
backends. Integer literals the parser cannot capture losslessly (beyond
2^53, kept as source text) resolve through `@string.parse_double` the way
an ES engine parses them; overflow to Infinity and NaN raise
`UnsupportedNumber` (E1004) per the RFC note.

Reason:

- The spec defined L2 as a planned second delivery level since step 2, so
  this fulfils the frozen roadmap rather than changing frozen semantics.
- Core `Double::to_string` is a Ryu port explicitly adjusted to the
  ECMAScript shortest-round-trip rule (js backend calls
  `Number.prototype.toString` directly). Hand-rolling Grisu/Ryu (~1k lines)
  would duplicate an audited implementation and add divergence risk, against
  the correctness-first instruction in the master plan.
- The real risk is the *assumption* that `to_string` matches ES on every
  backend; the Appendix B table turns that assumption into a tested fact on
  two independent code paths (Ryu port on wasm-gc/native, host engine on js).

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

## 2026-07-04: Ed25519 verify S<l check (RFC 8032 §8.4, anti-malleability)

Decision: `verify` rejects signatures where the scalar `S` is not in `[0, l)`,
per the RFC 8032 §8.4 malleability rule.

Reason:

- Without the bound, a signer's valid signature `(R, S)` can be reborn as
  `(R, l - S)` (or `S + l`) that also verifies, breaking the "one signature
  per message" assumption auditors rely on.
- The check is a single comparison after the existing `S` decode; cost is
  negligible and it closes a P0 blocker flagged in the 2026-07-04 health check.
- Three malleability regression tests pin both the canonical and the malleable
  forms.

## 2026-07-04: incremental path error codes unified with main path (E2003/E3003)

Decision: the incremental verification path reports the same error codes as
the main path (E2003 file-digest mismatch, E3003 merkle-root mismatch),
replacing the drifted E2001/E3002 it previously emitted.

Reason:

- Two code paths emitting different codes for the same fault class broke the
  CLI error-code matrix and any consumer doing code-based routing.
- Unifying on the main-path codes keeps a single error-code contract; the
  incremental path is a performance optimization, not separate semantics.

## 2026-07-04: hex_to_bytes unified to the digest package

Decision: all `hex_to_bytes` callers route through the single implementation
in `src/digest`; the duplicate copies in audit and other packages were
removed.

Reason:

- Three independent implementations had diverged on error handling; the audit
  copy silently truncated/kept bad input, which could mask a tampered digest
  as valid (silent corruption of the trust root).
- A single audited implementation with explicit length validation and
  canonical-form enforcement removes the divergence risk.

## 2026-07-04: ARCHITECTURE v2 frozen (create/store/audit/crypto/api signatures)

Decision: `docs/ARCHITECTURE.md` v2 freezes the public signatures of the six
core packages (create, store, audit, crypto, api, plus the existing four),
not just the original verify-side set.

Reason:

- The codebase grew four new packages after the v1 freeze without a frozen API
  surface, so the doc and the code had drifted.
- Freezing v2 gives the error-code matrix, the CLI, and the browser adapter a
  stable contract to program against; later hardening tightens inputs, never
  loosens frozen signatures.

## 2026-07-04: CI moon fmt --check gate (prevent fmt drift recurrence)

Decision: CI runs `moon fmt --check` as a required gate on every push/PR.

Reason:

- The 2026-06-11 post-freeze audit found the whole codebase had never been
  formatted (475/144 line churn on the first run); without a gate, drift
  recurs.
- A `--check` gate fails the build on any unformatted file, keeping formatting
  canonical without relying on contributors remembering to run `moon fmt`.

