# Project Index

This file is the entry index for MoonEvidence. Update it whenever a new decision, source, result, or generated artifact becomes important.

## One-Sentence Goal

Build a reusable MoonBit library and CLI for trusted evidence pack verification: canonical JSON, digest validation, Merkle proof verification, version chain tracing, and explainable diagnostics.

## Current Decision

| Item | Decision |
| --- | --- |
| Project name | MoonEvidence |
| Primary contribution | MoonBit ecosystem trusted data verification infrastructure |
| Primary deliverable | MoonBit library + native CLI + browser experiences + examples + tests + CI |
| Not the goal | Full blockchain system, smart contract framework, PKI platform, or vertical mural-costume business system |
| MVP priority | Verification first, generation/seal later |

## Document Map

| File | Purpose |
| --- | --- |
| `README.md` / `README.zh.md` | Public project overview (bilingual) |
| `showcase/README.md` | Trust Observatory architecture, runtime data path, and launch commands |
| `docs/GUIDE.md` | User guide with three real scenarios |
| `docs/DEMO_SCRIPT.md` | 5-minute presentation demo script |
| `docs/ARCHITECTURE.md` | Layered package structure and frozen public API |
| `docs/DEVELOPMENT_REPORT.md` | Redirect to the authoritative report (single line) |
| `docs/report/DEVELOPMENT_REPORT.md` | Authoritative development report (merged: feature list + AI collaboration + engineering quality) |
| `docs/spec/EVIDENCE_PACK_SPEC.md` | Minimal evidence pack schema and verification semantics |
| `docs/ENVIRONMENT.md` | Toolchain prerequisites and current environment state |
| `docs/CODE_GUIDELINES.md` | Code style, comments, tests, and public API rules |
| `docs/ROADMAP.md` | Phased implementation plan and future directions |
| `docs/STRUCTURE_TREE.md` | Current project file structure tree |
| `docs/KNOWLEDGE_BASE.md` | **项目知识库（新会话首选入口）**：完整架构/API/数据流/错误码/常量/测试覆盖/CI/工具链/安全治理/测试盲点/深度测试计划 |
| `docs/TEST_GOVERNANCE.md` | Quality gate and stop-rule: P0/P1/P2 risk classes, Definition of Done, release gate commands, and anti-patterns for test quality |
| `docs/CONST_TIME_AUDIT.md` | Ed25519 constant-time audit: source-level branch inventory, public-vs-secret input classification, CT-001 scalar-reduction fix record, and native timing evidence |
| `docs/BRANCH_COVERAGE.md` | Manual branch coverage audit for security-relevant accept/reject/skip/warn paths; current pass covers verify/incremental/merkle/digest/crypto/create/store/audit/api |
| `docs/TEST_PLAN.md` | **测试计划（改进前置条件）**：策略决策/系统性缺陷诊断/9层测试模型/3阶段实施/用例清单/覆盖率度量/改进安全检查清单 |
| `docs/PROJECT_INDEX.md` | This index |
| `docs/records/RESULTS_LOG.md` | Timestamped research, verification, and environment results |
| `docs/records/DECISION_LOG.md` | Stable decisions and why they were made |
| `docs/records/ACCEPTANCE_CHECKLIST.md` | Acceptance requirements self-check |
| `docs/records/OSC2026_GUIDE_SELF_CHECK.md` | OSC2026 guide hard-gate self-review and reference-project comparison |
| `docs/research/MOONCAKES_COLLISION_CHECK.md` | Mooncakes keyword search and collision-risk record |
| `docs/plans/2026-06-10-competition-master-plan.md` | Competition master plan: innovation points, step-by-step roadmap, and delivery checklist |
| `docs/plans/2026-07-04-health-check-and-improvement-plan.md` | 2026-07-04 第 1 轮健康体检与改进计划（阶段 0-4 已执行） |
| `docs/plans/2026-07-04-health-check-round2-and-improvement-plan.md` | 2026-07-04 第 2 轮健康体检与改进计划（5 轮扫描，仅计划不改代码） |
| `tools/env-check.ps1` | Read-only local environment check script |
| `tools/check-branch-coverage-stale.mjs` | Branch-coverage drift guard: audited source changes must review `docs/BRANCH_COVERAGE.md` |
| `tools/check-package-contents.mjs` | Mooncakes package hygiene guard: repository-only contest/report/local-agent files must not ship |
| `tools/check-wycheproof-ed25519.mjs` | Wycheproof Ed25519 vector inventory guard |
| `tools/fuzz-api-malformed.mjs` | Deterministic malformed-request fuzz guard for all 12 public JS string adapters |
| `tools/property-api-semantic.mjs` | Deterministic semantic property guard for valid public JS API closed loops and tamper rejection |
| `tools/randomized-hardening.mjs` | Named CI/release/stress profiles for randomized API and differential hardening |
| `tools/timing-ed25519-verify.mjs` | Informational Ed25519 verify timing sampler for release/security audit notes |
| `tools/timing-ed25519-native.ps1` | Native Ed25519 dudect-style verify/sign timing runner for Windows/MSVC release builds |
| `tools/symlink-junction-probe.ps1` | Windows junction traversal probe for CLI create/verify depth-cap behavior |
| `.github/workflows/showcase-pages.yml` | Builds the MoonBit-powered 3D observatory and deploys it to GitHub Pages |

Important source packages:

| Source | Purpose |
| --- | --- |
| `src/timing` | Native-only timing experiment package; calls project MoonBit Ed25519 verify/sign and reports Welch t |

## Source Traceability Rule

Every important claim should record:

- Date and timezone.
- Source path or URL.
- Command or method used.
- Result summary.
- Current confidence and remaining uncertainty.

Use `docs/records/RESULTS_LOG.md` for measured facts and `docs/records/DECISION_LOG.md` for decisions.

## Next Actions

1. **远端 CI 最终确认**：GitHub Actions `main` 最新 run 需要在页面上显示 green；本地与 WSL 已复现核心 gate，但远端状态以 Actions 页面为准。
2. **演示视频**：按 `docs/DEMO_SCRIPT.md` 录制 5 分钟比赛展示视频，主视觉使用 Trust Observatory 的自动与挑战模式。
3. **Gitlink 默认分支确认**：确认 Gitlink 页面默认分支显示的是已同步的 `main`，且 README、LICENSE、源码、CI 文档可见。
4. **流式哈希生产化增强**：把流式 SHA-256 接入适配层，将大包内存峰值从 Σ(全部文件) 降到 max(单文件)。
5. 持续维护 `RESULTS_LOG.md` 与 `OSC2026_GUIDE_SELF_CHECK.md`，每次交付前重跑并记录命令与结果。
