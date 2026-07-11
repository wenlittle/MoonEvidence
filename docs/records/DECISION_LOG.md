# Decision Log

## 2026-07-06: Test governance controls further test work

Decision: Add `docs/TEST_GOVERNANCE.md` as the controlling quality-gate and
stop-rule document for test work. `docs/TEST_PLAN.md` remains the backlog and
implementation plan, but governance decisions now use explicit P0/P1/P2 risk
classes, Definition of Done, release gate commands, and anti-pattern checks.

Reason:

- The project had accumulated detailed test plans, but the missing layer was a
  bounded decision process for "enough for now" versus "release-blocking".
- External guidance points in the same direction: NIST SSDF asks projects to
  define security-check criteria and document testing/triage; OWASP ASVS uses
  explicit verification requirements; Google review guidance asks whether tests
  are useful and would fail when code is broken; mutation testing validates
  test quality instead of relying on counts.
- For MoonEvidence, the practical rule is: P0 trust-boundary gaps block the
  affected change/release, P1 blocks release/submission, and P2 is real backlog
  with a trigger. This prevents anxiety-driven patching while keeping security
  work honest.

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

## 2026-07-04: Barrett-like reduction replaces slow reduce_scalar_512 (round 2)

Decision: Replace the "multiply by 256 then subtract l up to 256 times" loop with binary quotient decomposition using precomputed l*2^k multiples (k=0..8).

Reason:

- The old algorithm did ~500K byte-operations per call (64 bytes × up to 256 subtractions × 33-byte compare/subtract).
- The new algorithm does ~600 byte-operations (64 bytes × 9 compare+subtract × 34 bytes), an ~800x improvement.
- Correctness proven by all 4 RFC 8032 §7.1 KAT vectors passing (sign and verify paths both depend on reduce_scalar_512).
- This is a fundamental algorithm replacement, not a patch — the old "KNOWN PERFORMANCE BOTTLENECK" comment is deleted.

## 2026-07-04: E3002 implemented via prove/check-proof CLI commands (round 2)

Decision: Implement `prove` and `check-proof` CLI subcommands that expose merkle inclusion proof generation and verification. E3002 (proof format invalid) now has a real trigger path.

Reason:

- Round 1 left E3002 as "reserved for future" — a gap in the frozen error-code contract.
- merkle::compute_proof and merkle::verify_inclusion were already implemented but not exposed via CLI.
- Exposing them gives E3002 a real consumer path and adds user-facing value (inclusion proof verification).

## 2026-07-04: create sort uses code-point order (round 2)

Decision: `create_manifest` sorts paths using `@canonjson.compare_code_units` instead of MoonBit's default `String::compare` (shortlex).

Reason:

- Default sort is shortlex (length-first), which differs from RFC 8785 JCS code-point order.
- Cross-tool Merkle root consistency requires identical sort order across MoonBit/Node/Python.
- Test added proving "aa" < "b" in code-point order (shortlex would give "b" < "aa").

## 2026-07-04: audit signature covers canonical JSON (round 2)

Decision: `sign_last` signs the entry's canonical JSON (excluding signature field) instead of the `compute_hash()` output string.

Reason:

- Signing a hash string binds the signature to the hash value, not the full entry content. If `compute_hash` field set changes, signature semantics silently change.
- Signing canonical JSON binds the signature to the complete entry content, which is the correct semantic for an audit log.

## 2026-07-04: two dev reports merged into single authoritative version (round 2)

Decision: Merge `docs/DEVELOPMENT_REPORT.md` and `docs/report/DEVELOPMENT_REPORT.md` into a single authoritative report at `docs/report/DEVELOPMENT_REPORT.md`. The root copy becomes a one-line redirect.

Reason:

- Round 1 "archived with note" left two reports with conflicting numbers — a verification hazard.
- A single authoritative report eliminates the consistency risk entirely.

## 2026-07-04: MerkleTree materialization for visualization (round 3)

Decision: Add `compute_tree(leaves) -> MerkleTree?`, `MerkleTree::root/height/leaf_count/level/leaf_path` to `src/merkle`. `compute_root` stays as the canonical single-value API; `compute_tree` is a pure-additive companion that returns every hash on every level.

Reason:

- The Trust Workbench UI (`demo/web/tamper-lab.html`) needs to render the full Merkle tree, not just the root, so users can see which ancestor nodes change when a leaf is tampered.
- `compute_root` is frozen v1; reusing it would require callers to re-derive intermediate levels in JS, duplicating the promotion logic (CVE-2012-2459 defense) and risking divergence.
- `compute_tree` shares the same promotion rule as `compute_root` (odd node promoted unchanged, never self-paired); tests prove `tree.root() == compute_root(leaves)` for 8 shapes.
- `leaf_path(index)` returns the spine from leaf to root — one step per level, last step is the root — so the renderer can highlight the tampered leaf's ancestor chain without re-walking the tree in JS.

## 2026-07-04: incremental path now asserts E2004 manifest digest (round 3)

Decision: `verify_manifest_incremental` gains `expected_manifest_digest~ : String?` and now performs the E2004 manifest-digest assertion when the parameter is supplied, matching `verify_manifest` step 3. The old `ignore(canonical_json)` is removed.

Reason:

- Round 2 audit found the incremental path computed canonical JSON then threw it away, silently skipping the E2004 check the main path performs. This made `verify_manifest_incremental` a silently weakened verification, not a performance-equivalent optimization.
- A caller using the incremental path for "fast re-check" would miss a tampered manifest whose file digests still matched — a real security gap.
- The fix mirrors the main path's step 2 (canonicalize, E1004 on failure) and step 3 (compare canonical digest to expected, E2004 on mismatch). The parameter is optional (defaults to None) so existing callers stay source-compatible.
- Three new tests pin the behavior: E2004 on mismatch, pass on match, no E2004 when parameter is None.

## 2026-07-04: CI auto anti-drift gate via check-metrics.mjs (round 3)

Decision: Add `tools/check-metrics.mjs` as a CI gate that collects actual repo metrics (commits, MoonBit lines, test count, package count, moon.mod version) via Node.js fs APIs and asserts they match the numbers cited in README / README.zh / DEVELOPMENT_REPORT / ACCEPTANCE_CHECKLIST / STRUCTURE_TREE / moon.mod.

Reason:

- Rounds 1 and 2 both suffered "metric drift" — docs claiming 76 commits / 6891 lines when actuals were 79 / 8368. The root cause was that "single source of truth" was a human-remembered process, not an automated gate.
- `check-metrics.mjs` makes the gate automated: 19 assertions, exit 1 on any mismatch. Running it in CI means a PR that changes code but forgets to update docs will fail.
- Uses Node.js fs APIs (not shell `find`/`wc`) so it works identically on Windows and Linux CI runners.
- Also asserts `moon.mod version == CHANGELOG latest version` to prevent the round-2 moon.mod/CHANGELOG version desynchronization from recurring.

> **2026-07-05 update (round 4):** The original entry above claimed check-metrics was a CI gate, but `.github/workflows/ci.yml` did not actually reference it — the "gate" was manual-only. This has been corrected: ci.yml now runs `check-metrics.mjs`, `cross-verify.mjs`, and `mutation-check.mjs` as blocking steps. `cross-verify.mjs` was also updated to recognize negative test packs (bad-*/tampered-*/missing-*) so their expected verification failures count as PASS. `mutation-check.mjs` mutation targets were updated to match the post-SHA-512 multi-algorithm code structure.
>
> **2026-07-06 update:** `check-metrics.mjs` now also asserts `src/cmd/main/main.mbt` `CLI_VERSION == moon.mod version`, closing the remaining hard-coded CLI version drift gap.

## 2026-07-11: MoonBit remains the sole evidence-semantics authority

Decision: Manifest construction, canonicalization, digest calculation, Merkle
semantics, and evidence verification remain in the MoonBit core and CLI. The
Fabric adapter consumes MoonBit's versioned manifest receipts and stable
verification report, and does not reimplement those rules in TypeScript or Go.

Reason:

- One semantic implementation prevents cross-language drift at the trust
  boundary.
- The adapter can be replaced or extended without changing evidence-pack
  meaning.
- Process-contract tests reject malformed or inconsistent CLI responses before
  any ledger submission.

## 2026-07-11: Fabric stores one canonical digest and immutable context only

Decision: Fabric world state stores the canonical manifest digest, the first
committing transaction ID, and submitter MSP. Files, manifests, paths,
per-file digests, Merkle leaves, and subject metadata remain off-chain. The v1
contract exposes no update or delete transaction.

Reason:

- Fabric transaction arguments are recorded in block data, so omitting
  sensitive fields only from world state would not protect them.
- Digest-only anchoring minimizes disclosure and ledger growth while retaining
  a deterministic value that MoonEvidence can verify later.
- An immutable first-write record gives retries one stable reference instead
  of creating competing versions of the same anchor.

## 2026-07-11: Commit evidence is transaction ID, block, and validation status

Decision: A successful anchor receipt records Fabric transaction ID, block
number, numeric validation code, and success flag. Fabric proposal timestamps
are not presented as independently trusted time. Only validation code 11 may be
normalized as a concurrent MVCC duplicate after a matching ledger query.

Reason:

- `GetTxTimestamp()` comes from the proposal channel header supplied by the
  client; endorsement consistency does not turn it into an independent clock.
- Commit status proves whether ordering and validation accepted the
  transaction, while an endorsement result alone does not.
- Restricting duplicate normalization to the actual MVCC conflict code avoids
  converting unrelated invalid transactions into apparent success.

## 2026-07-11: Fabric samples is the protocol-integration environment

Decision: The two-organization Fabric samples test-network records an
implemented path across Gateway, endorsement, ordering, validation,
world-state, and cross-organization query boundaries. Production identity
enrollment, governance, availability, private-data policy, and trusted-time
policy remain deployment concerns.

Reason:

- This topology is sufficient to distinguish a real protocol execution from a
  mock or chaincode-only unit test.
- It does not represent a production consortium or legal timestamp service,
  so those operational properties must not be inferred from the experiment.

## 2026-07-11: public contracts separate core packs, extensions, and process shapes

Decision: The core evidence pack consists of `manifest.json` and `files/`.
`versions/version_chain.json` is an optional CLI extension. Inclusion proofs
are explicit Merkle/API artifacts and are not required by complete pack
verification. The manifest-selected SHA-256 or SHA-512 algorithm drives file,
Merkle, proof-sibling, and external manifest digest lengths.

The CLI process contract uses versioned schema receipts for `pack`, `create`,
and `inspect`. Single-pack `verify --json` keeps the shared stable
`VerifyReport` shape with `ok`, `findings`, and `stats` and no schema field.

Reason:

- These boundaries match the existing v0.5.0 implementation and published
  data without a schema migration.
- Core packs stay self-contained and small; optional history and proofs retain
  explicit ownership.
- Automation can select the correct parser from the command and exit code,
  while schema fields continue to version manifest receipts.
- SHA-512 packs remain interoperable because every digest length is derived
  from the selected algorithm.

## 2026-07-11: Fabric integration ships as v0.5.0

Decision: Release the additive MoonBit machine contract and external-anchor
verification as v0.5.0. Keep the Go/TypeScript Fabric adapter in the repository
but outside the Mooncakes artifact.

Reason:

- `pack`, `inspect`, and external digest verification add public behavior, so a
  minor version communicates the expanded surface more accurately than another
  0.4.x patch.
- Existing MoonBit core signatures and evidence schemas remain compatible;
  this is not a breaking major-version change.
- Excluding `integrations/` preserves the dependency and portability contract
  of the published MoonBit library while still delivering a reproducible real
  ledger integration alongside it.
