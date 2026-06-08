# Project Index

This file is the entry index for MoonEvidence. Update it whenever a new decision, source, result, or generated artifact becomes important.

## One-Sentence Goal

Build a reusable MoonBit library and CLI for trusted evidence pack verification: canonical JSON, digest validation, Merkle proof verification, version chain tracing, and explainable diagnostics.

## Current Decision

| Item | Decision |
| --- | --- |
| Project name | MoonEvidence |
| Primary contribution | MoonBit ecosystem trusted data verification infrastructure |
| Primary deliverable | MoonBit library + native CLI + examples + tests + CI |
| Not the goal | Full blockchain system, smart contract framework, PKI platform, or vertical mural-costume business system |
| MVP priority | Verification first, generation/seal later |

## Document Map

| File | Purpose |
| --- | --- |
| `README.md` | Public project overview |
| `docs/ARCHITECTURE.md` | Layered package structure and dependency rules |
| `docs/spec/EVIDENCE_PACK_SPEC.md` | Minimal evidence pack schema and verification semantics |
| `docs/ENVIRONMENT.md` | Toolchain prerequisites and current environment state |
| `docs/CODE_GUIDELINES.md` | Code style, comments, tests, and public API rules |
| `docs/ROADMAP.md` | Week-by-week implementation plan |
| `docs/STRUCTURE_TREE.md` | Current project file structure tree |
| `docs/records/RESULTS_LOG.md` | Timestamped research, verification, and environment results |
| `docs/records/DECISION_LOG.md` | Stable decisions and why they were made |
| `docs/research/MOONCAKES_COLLISION_CHECK.md` | Mooncakes keyword search and collision-risk record |
| `tools/env-check.ps1` | Read-only local environment check script |

## Source Traceability Rule

Every important claim should record:

- Date and timezone.
- Source path or URL.
- Command or method used.
- Result summary.
- Current confidence and remaining uncertainty.

Use `docs/records/RESULTS_LOG.md` for measured facts and `docs/records/DECISION_LOG.md` for decisions.

## Next Actions

1. Freeze the minimal `manifest.json` model in MoonBit and validate required fields.
2. Add one valid evidence pack fixture and one tampered fixture before expanding feature scope.
3. Implement Merkle root/proof verification with explicit leaf and sibling encoding rules.
4. Add structured diagnostics so CLI output can explain why a pack passed or failed.
5. Keep `RESULTS_LOG.md` updated after each verified result.
