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
| `README.md` / `README.zh.md` | Public project overview (bilingual) |
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
| `docs/TEST_PLAN.md` | **测试计划（改进前置条件）**：策略决策/系统性缺陷诊断/9层测试模型/3阶段实施/用例清单/覆盖率度量/改进安全检查清单 |
| `docs/PROJECT_INDEX.md` | This index |
| `docs/records/RESULTS_LOG.md` | Timestamped research, verification, and environment results |
| `docs/records/DECISION_LOG.md` | Stable decisions and why they were made |
| `docs/records/ACCEPTANCE_CHECKLIST.md` | Acceptance requirements self-check |
| `docs/research/MOONCAKES_COLLISION_CHECK.md` | Mooncakes keyword search and collision-risk record |
| `docs/plans/2026-06-10-competition-master-plan.md` | Competition master plan: innovation points, step-by-step roadmap, and delivery checklist |
| `docs/plans/2026-07-04-health-check-and-improvement-plan.md` | 2026-07-04 第 1 轮健康体检与改进计划（阶段 0-4 已执行） |
| `docs/plans/2026-07-04-health-check-round2-and-improvement-plan.md` | 2026-07-04 第 2 轮健康体检与改进计划（5 轮扫描，仅计划不改代码） |
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

1. **Mooncakes 发布**：`moon login` 后发布 0.3.0 到 Mooncakes（碰撞检查已清、package 已构建，仅缺凭证）。
2. **演示视频**：按 `docs/DEMO_SCRIPT.md` 录制 5 分钟比赛展示视频。
3. **流式哈希**：把流式 SHA-256 接入适配层，将大包内存峰值从 Σ(全部文件) 降到 max(单文件)。
4. 仓库双推 GitHub + Gitlink，确认 CI 首跑绿，勾掉 `ACCEPTANCE_CHECKLIST.md` 第 2 条。
5. 持续维护 `RESULTS_LOG.md`，每步交付前重跑并记录命令与结果。
