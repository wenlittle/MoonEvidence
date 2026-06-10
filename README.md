# MoonEvidence

[![CI](https://github.com/wenlittle/MoonEvidence/actions/workflows/ci.yml/badge.svg)](https://github.com/wenlittle/MoonEvidence/actions/workflows/ci.yml)

MoonEvidence is a MoonBit ecosystem project for trusted evidence pack verification.

The project goal is to provide a reusable MoonBit library and native CLI that can verify whether a group of files, metadata, Merkle proofs, and version records remain complete and untampered.

## Positioning

MoonEvidence is not a blockchain application or smart contract framework. It is a chain-agnostic verification core that can be used before blockchain notarization, dataset archival, digital copyright packaging, AI output audit, or research artifact release.

## MVP Scope

- Canonical JSON serialization for stable digests.
- SHA-256 digest wrapper and digest comparison.
- Evidence manifest model and validation.
- Merkle root/proof verification.
- Linear version chain verification.
- Structured diagnostics and human-readable explain output.
- Native CLI entry points: `verify` and `explain`.

## Project Documents

- [Project Index](docs/PROJECT_INDEX.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Evidence Pack Spec](docs/spec/EVIDENCE_PACK_SPEC.md)
- [Environment Setup](docs/ENVIRONMENT.md)
- [Code Guidelines](docs/CODE_GUIDELINES.md)
- [Roadmap](docs/ROADMAP.md)
- [Results Log](docs/records/RESULTS_LOG.md)

## Quick Start (CLI)

```powershell
# build the CLI (js artifact, runs via node; native works wherever a C compiler exists)
moon build --target js

# verify the bundled example packs
node _build/js/debug/build/src/cmd/main/main.js verify examples/valid-pack
node _build/js/debug/build/src/cmd/main/main.js verify examples/tampered-pack

# machine-readable report / human-readable findings
node _build/js/debug/build/src/cmd/main/main.js verify --json examples/valid-pack
node _build/js/debug/build/src/cmd/main/main.js explain examples/tampered-pack

# run the full black-box suite (12 cases)
powershell -ExecutionPolicy Bypass -File tools/cli-test.ps1 -Target js
```

Exit codes are frozen: `0` verification passed, `1` verification failed,
`2` usage or IO error. On machines with a system C compiler (and in CI) the
same CLI builds natively: `moon build --target native` then
`tools/cli-test.ps1 -Target native`.

## Diagnostics Preview

Every verification failure maps to a frozen error code (`E1xxx`..`E4xxx`,
`W1xxx`). The `explain` renderer prints one finding per line and always
closes with a summary:

```text
verification FAILED
  [E2003] files/data.csv: digest mismatch, expected sha256:ab.. got sha256:cd..
  [W1001] files/extra.bin: file present in pack but not listed in manifest
checked 12 files, 11 passed; merkle root verified; 1 error, 1 warning
```

The machine-readable twin (`to_json`) emits the same report as canonical
JSON (RFC 8785 key order), so report bytes are digest-stable:

```json
{"findings":[],"ok":true,"stats":{"files_passed":2,"files_total":2,"merkle_checked":true}}
```

## Current Status

All six pure library packages are implemented and green: `canonjson`
(RFC 8785 escaping, code-unit key order, L1 numbers), `digest` (pure
MoonBit SHA-256, NIST vectors), `merkle` (RFC 6962 style domain separation,
cross-checked against an independent Node reference), `model` (validated
manifest + version chain), `verify` (seven-step pipeline), and `diag`
(structured findings, explain, canonical JSON reports). On top of them the
thin CLI adapter (`src/cmd/main`) ships `verify [--json]` / `explain` with
frozen exit codes, exercised by a 12-case black-box suite over the bundled
`examples/valid-pack` and `examples/tampered-pack`.

```powershell
moon check
moon test
moon build --target js
powershell -ExecutionPolicy Bypass -File tools/cli-test.ps1 -Target js
```

All commands pass locally (125/125 unit tests, 12/12 black-box cases) as of
2026-06-11 Asia/Shanghai; CI additionally builds the native CLI and runs the
same black-box suite against it. Next up: the fixtures full matrix
(master plan step 7).
