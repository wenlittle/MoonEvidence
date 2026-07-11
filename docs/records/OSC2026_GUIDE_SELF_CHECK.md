# OSC2026 Guide Self-Check

Date: 2026-07-11 Asia/Shanghai

Sources:

- `https://gitlink.org.cn/MilkyNatas/osc2026-guide`
- Reference projects inspected for CI shape only:
  - `https://github.com/wzzc-dev/MoUI`
  - `https://github.com/howtomakeaname/tokenizers-moonbit`

## Verdict

MoonEvidence meets the guide's repository-side hard gates in the local checkout:
valid MoonBit project, root license, README, examples, tests, `moon check`,
`moon test`, `moon info && git diff --exit-code`, Mooncakes publication, and
clear engineering purpose. GitHub Actions `main` CI and Showcase Pages are
both green for the Fabric integration baseline.

## Hard Gates

| Gate | Status | Evidence |
| --- | --- | --- |
| Valid MoonBit project | Pass | `moon.mod` declares `starlittle/MoonEvidence` v0.5.0 with Apache-2.0 license and GitHub repository metadata |
| Standard check/test | Pass | Local `moon check --deny-warn`; local `moon test --deny-warn --target wasm,wasm-gc,js` passed 347/347 per backend; native passes on Windows/MSVC and remains required in CI |
| Public interface drift | Pass | `moon info && git diff --exit-code -- '**/pkg.generated.mbti'` passed locally |
| Formatting | Pass | `moon fmt --check` passed locally |
| Packaging | Pass | `moon package` produced `_build/publish/starlittle-MoonEvidence-0.5.0.zip` |
| Package hygiene | Pass | `tools/check-package-contents.mjs` keeps contest materials, local records, root Node metadata, and optional Go/TypeScript Fabric integration out of the Mooncakes package |
| Mooncakes publication | Pass | `starlittle/MoonEvidence` v0.5.0 is published; version matches `moon.mod` |
| License | Pass | Root `LICENSE` is Apache-2.0 |
| README and examples | Pass | Bilingual README, `docs/GUIDE.md`, examples, browser workbench, CLI machine contract, and Fabric integration guide describe runnable local and ledger-backed flows |
| Repository CI | Pass locally and remotely | MoonBit required job covers standard gates and 62-case dual-shell CLI/fuzz/property/differential/mutation; separate required Fabric job covers Go vet/race/coverage and Gateway TypeScript build/test |
| Declared core function | Pass | Real Fabric v3.1.4 two-organization record proves anchor/query/duplicate/backfeed beyond unit mocks; sanitized tx/block/status and E2003/E2004 results are committed under `docs/records/fabric-e2e/` |
| Repository surface | Pass | Public tree keeps source, reusable docs, examples, tests, and CI; local agent folders and legacy root course-report artifacts are ignored/removed |

## Reference Project Takeaways

`MoUI` is stronger on platform-specific evidence: it keeps explicit Linux,
macOS, and Windows jobs plus packaging smoke tests. MoonEvidence does not need
that breadth for a pure verification library, but the native CLI path is still
covered by Ubuntu native build/test and black-box runs.

`tokenizers-moonbit` is a close reference for a reusable MoonBit library: it
uses target-matrix CI with `moon update`, `moon check --deny-warn`, `moon test
--deny-warn`, release gates for `moon fmt`, `moon info`, and `moon package`.
MoonEvidence now mirrors the relevant parts directly in its main and release
workflows.

## Current Optimizations Applied

- Added manual `workflow_dispatch` to the main CI workflow so the run can be
  re-triggered without making empty commits.
- Upgraded CI type checking to `moon check --deny-warn --target all`.
- Added the missing `moon info` + generated-interface drift gate to CI.
- Expanded portable unit tests in CI from `wasm-gc,js` to
  `wasm,wasm-gc,js`, all with `--deny-warn`.
- Upgraded native unit tests in CI to `moon test --deny-warn --target native`.
- Added `moon update`, `moon check --deny-warn`, and `moon info` drift checking
  to the release workflow before `moon package`.
- Added `tools/check-package-contents.mjs` and tightened `moon.mod` excludes so
  the public Mooncakes package ships the reusable library surface instead of
  repository-only application/report artifacts.
- Added versioned `pack`/`inspect`/external-digest machine contracts, 62-case
  PowerShell/bash parity, and API anchor properties.
- Added immutable Go Fabric chaincode, strict TypeScript Gateway adapter,
  required CI job, and a real two-organization E2E record while preserving the
  MoonBit package's dependency boundary.
- Removed tracked local-agent folders and legacy root report outputs from the
  public repository surface; `.gitignore` now keeps them local if regenerated.

## Remaining Checks Before Final Submission

1. Open the GitHub Actions page and confirm the latest `main` run is green.
2. Open Gitlink and confirm the default branch shows the synchronized README,
   LICENSE, source, docs, and latest commit.
3. Re-run this command set immediately before final submission:

```bash
moon update
moon check --deny-warn --target all
moon fmt --check
moon info
git diff --exit-code -- '**/pkg.generated.mbti'
moon test --deny-warn --target wasm,wasm-gc,js
moon package
node tools/check-package-contents.mjs
node tools/check-metrics.mjs
npm --prefix integrations/fabric/gateway ci
npm run fabric:check
npm run fabric:test
cd integrations/fabric/chaincode-go && go vet ./... && go test ./... -cover
```
