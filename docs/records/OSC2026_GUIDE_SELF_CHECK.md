# OSC2026 Guide Self-Check

Date: 2026-07-08 Asia/Shanghai

Sources:

- `https://gitlink.org.cn/MilkyNatas/osc2026-guide`
- Reference projects inspected for CI shape only:
  - `https://github.com/wzzc-dev/MoUI`
  - `https://github.com/howtomakeaname/tokenizers-moonbit`

## Verdict

MoonEvidence meets the guide's repository-side hard gates in the local checkout:
valid MoonBit project, root license, README, examples, tests, `moon check`,
`moon test`, `moon info && git diff --exit-code`, Mooncakes publication, and
clear engineering purpose. The remaining external confirmation is the latest
GitHub Actions `main` run turning green on the hosting page.

## Hard Gates

| Gate | Status | Evidence |
| --- | --- | --- |
| Valid MoonBit project | Pass | `moon.mod` declares `starlittle/MoonEvidence` v0.4.0 with Apache-2.0 license and GitHub repository metadata |
| Standard check/test | Pass | Local `moon check --deny-warn`; local `moon test --deny-warn --target wasm,wasm-gc,js` passed 344/344 per backend; native gate previously reproduced on WSL/Linux and Windows/MSVC, and remains in CI |
| Public interface drift | Pass | `moon info && git diff --exit-code -- '**/pkg.generated.mbti'` passed locally |
| Formatting | Pass | `moon fmt --check` passed locally |
| Packaging | Pass | `moon package` produced `_build/publish/starlittle-MoonEvidence-0.4.0.zip` |
| Package hygiene | Pass | `tools/check-package-contents.mjs` keeps contest application PDFs, legacy course reports, and local agent files out of the Mooncakes package |
| Mooncakes publication | Pass | `starlittle/MoonEvidence` v0.4.0 is published; version matches `moon.mod` |
| License | Pass | Root `LICENSE` is Apache-2.0 |
| README and examples | Pass | `README.md`, `README.zh.md`, `docs/GUIDE.md`, `examples/`, and `demo/web/` describe runnable CLI/API/browser flows |
| Repository CI | Pass locally, remote pending page check | CI now includes `moon update`, `moon check --deny-warn --target all`, `moon fmt --check`, `moon info` drift gate, `moon test --deny-warn` on portable/native targets, builds, CLI black-box tests, fuzz/property/differential/mutation gates |
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
```
