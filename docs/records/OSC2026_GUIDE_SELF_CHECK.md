# OSC2026 Guide Self-Check

Date: 2026-07-12 Asia/Shanghai

Sources:

- `https://gitlink.org.cn/MilkyNatas/osc2026-guide`
- Reference projects inspected for CI shape only:
  - `https://github.com/wzzc-dev/MoUI`
  - `https://github.com/howtomakeaname/tokenizers-moonbit`

## Verdict

MoonEvidence passes the guide's final-acceptance hard standards with no
repository-side blocker found. The review covered project validity, standard
and strict MoonBit gates, latest remote CI, Mooncakes installation, proposal
promise coverage, license provenance, repository hygiene, contributor/account
mapping, real CLI/browser behavior, and the optional Fabric protocol boundary.

## Hard Gates

| Gate | Status | Evidence |
| --- | --- | --- |
| Valid MoonBit project | Pass | `moon.mod` declares `starlittle/MoonEvidence` v0.5.1 with Apache-2.0 license and GitHub repository metadata |
| Standard check/test | Pass | `moon check --deny-warn --target all`; wasm/wasm-gc/js and Windows/MSVC native each passed 353/353 |
| Public interface drift | Pass | `moon info && git diff --exit-code -- '**/pkg.generated.mbti'` passed locally |
| Formatting | Pass | `moon fmt --check` passed locally |
| Packaging | Pass | `moon package` produced `_build/publish/starlittle-MoonEvidence-0.5.1.zip` |
| Package hygiene | Pass | `tools/check-package-contents.mjs` keeps contest materials, local records, root Node metadata, and optional Go/TypeScript Fabric integration out of the Mooncakes package |
| Mooncakes publication | Pass | `starlittle/MoonEvidence` v0.5.1 is published; version matches `moon.mod` |
| License and provenance | Pass | Root `LICENSE` is Apache-2.0; the converted Wycheproof corpus records source, version, and Apache-2.0 license; Fabric dependencies are lockfile-pinned and permissively licensed |
| README and examples | Pass | Bilingual README, `docs/GUIDE.md`, examples, browser workbench, CLI machine contract, and Fabric integration guide describe runnable local and ledger-backed flows |
| Repository CI | Pass locally and remotely | GitHub `main` run `29147807818` succeeded at `8088147`: `check-test-build`, `fabric-adapters`, and `bench`; Showcase Pages run `29147807822` also succeeded |
| Declared core function | Pass | Real Fabric v3.1.4 two-organization record proves anchor/query/duplicate/backfeed beyond unit mocks; sanitized tx/block/status and E2003/E2004 results are committed under `docs/records/fabric-e2e/` |
| Runnable behavior | Pass | JS/native CLI suites passed 68/68 each; browser API smoke passed 41/41; Showcase production build passed; Gateway passed 19/19; clean Mooncakes consumer passed 2/2 |
| Proposal completion | Pass | The one-page proposal is an A4 single-page PDF; declared canonicalization, digest, Merkle, manifest, Ed25519/store/audit, CLI, browser, multi-backend, and Fabric functions all have implemented evidence |
| Contributor relationship | Pass with documented mapping | Maintainer/applicant Chen Junwen maps to GitHub `wenlittle` and Gitlink/Mooncakes `starlittle`; both repository links are present in the proposal and README |
| Repository surface | Pass | Public tree keeps source, reusable docs, examples, tests, and CI; `.gitignore` anchors the legacy root `report/` exclusion so it no longer masks the tracked authoritative report under `docs/report/` |

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
- Added versioned `pack`/`inspect`/external-digest machine contracts, 68-case
  PowerShell/bash parity, and API anchor properties.
- Added immutable Go Fabric chaincode, strict TypeScript Gateway adapter,
  required CI job, and a real two-organization E2E record while preserving the
  MoonBit package's dependency boundary.
- Removed tracked local-agent folders and legacy root report outputs from the
  public repository surface; `.gitignore` now keeps them local if regenerated.

## Final Review Evidence

| Check | Result |
| --- | --- |
| `moon update`; `moon check --deny-warn --target all`; `moon fmt --check`; `moon info` interface diff | Pass |
| `moon test --deny-warn --target wasm,wasm-gc,js` | Pass: 353/353 on each backend |
| Windows/MSVC `moon test --deny-warn --target native` | Pass: 353/353 |
| PowerShell CLI black box, JS and native | Pass: 68/68 per target |
| Browser adapter and Showcase | API smoke 41/41; TypeScript check and production build pass |
| Package and document guards | `moon package` pass; 245 files; metrics 51/51; branch audit current |
| Fabric adapters | Gateway check/build and 19/19 tests pass; local Go vet and 82.1% coverage pass; latest required CI also passes Go race |
| Remote repositories and release | GitHub/Gitlink default branch `main`; both v0.5.1 tags point to the release commit; GitHub Release and Mooncakes v0.5.1 available |

## Remaining External Action

The repository is ready for acceptance. The only unverified item is operational:
the public charter does not expose a separate completion-support submission
form, so the contestant must follow the competition group or organizer notice
for any final questionnaire. A usage video is optional showcase material, not
one of the nine basic acceptance gates.

## Environment Notes

- The current Windows shell uses moonc v0.9.3, older than the guide's suggested
  v0.10.3 baseline. Latest-toolchain compatibility is independently covered by
  the green required CI and the recorded WSL v0.10.3 run; this is not a project
  acceptance blocker.
- Local `go test -race` cannot start with `CGO_ENABLED=0`; the same race gate
  passes in the latest required Linux CI. Local non-race tests pass with 82.1%
  core statement coverage.
- `moonbitlang/skills` is not installed in the current agent skill directories.
  It is an optional local-development aid, not a submission requirement.
