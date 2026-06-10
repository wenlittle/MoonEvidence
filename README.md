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

## Current Status

Project preparation is complete enough for implementation. MoonBit CLI is installed on the D drive, `canonjson` and `digest` MVP packages are implemented, and the current local verification result is:

```powershell
moon test
moon build --target native
```

Both commands pass locally as of 2026-06-08 Asia/Shanghai.
