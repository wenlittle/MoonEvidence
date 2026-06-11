# Code Guidelines

MoonEvidence should read like an open-source library, not a one-off course demo.

## General Rules

- Keep public APIs small and stable.
- Prefer explicit data types over loosely typed strings.
- Separate pure verification logic from IO adapters.
- Do not hide failures behind `Bool` when a diagnostic is useful.
- Add tests with each feature before expanding scope.

## Comments

Comments are required where they clarify an external rule, verification invariant, or non-obvious algorithm step.

Use comments for:

- Public API intent and expected inputs.
- Canonical JSON ordering rules.
- Merkle proof sibling ordering and domain separation rules.
- Version-chain invariants.
- Diagnostic meaning when the enum name is not enough.

Avoid comments that only repeat the code.

## Diagnostics

Diagnostics should be structured first and rendered second.

The draft diagnostic kinds listed in early revisions of this file evolved
into the frozen error-code contract in
`docs/spec/EVIDENCE_PACK_SPEC.md` ("Error Codes": `E1xxx` model,
`E2xxx` digest, `E3xxx` merkle, `E4xxx` version chain, `E5xxx` adapter IO,
`W1xxx` warnings); see DECISION_LOG for the rationale. The structural rule
stands: every finding carries `code`, `severity`, `path`, and a `message`
with enough context to locate the failed item (expected and actual digests
included on mismatches).

## Testing Rules

Each core module should include:

- Happy path.
- Boundary case.
- Tamper/failure case.
- Regression fixture.

Test names should describe behavior clearly, for example:

```text
test_canonjson_reordered_fields_keeps_same_digest
test_merkle_tampered_sibling_rejects_proof
test_version_chain_missing_parent_reports_mismatch
```

## Documentation Rules

Every release-worthy feature needs:

- Library API example.
- CLI example if user-facing.
- One valid fixture.
- One tampered fixture.
- Result logged in `docs/records/RESULTS_LOG.md`.

