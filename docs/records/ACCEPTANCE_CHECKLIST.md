# 验收要求自查清单

对照赛方「申请完成支持的项目应满足的要求」逐条核对。核对日期：2026-07-08 Asia/Shanghai。

| # | 要求 | 状态 | 证据 |
| --- | --- | --- | --- |
| 1 | 项目以 MoonBit 为主要实现语言 | ✅ | 全部核心逻辑为 MoonBit：12 个产品包 + 1 个 native timing 工具包，实现 5876 行 + 测试 8067 行，合计 **13943 行**；产品实现规模落在 4-10k 要求区间。仓库内 JS 仅为独立参考实现/烟测工具（`tools/*.mjs`）与 demo 页面胶水，不承担验证语义 |
| 2 | GitHub 与 Gitlink 仓库公开可访问、提交记录完整 | ✅ | GitHub `wenlittle/MoonEvidence` 与 Gitlink `starlittle/MoonEvidence` 均已同步推送 `main` 与 `codex/test-hardening-phase2`；本地分支 **140 个提交**以上（远超 10-20 有效提交要求），按逻辑单元划分、conventional commits 风格、每步附验收记录。 |
| 3 | 源代码结构清晰、架构表达完整核心功能 | ✅ | 12 个产品包（6 核心：canonjson/digest/merkle/model/verify/diag 零 IO + 4 扩展：create/store/audit/crypto + 2 适配器：cmd/main CLI、api 浏览器）+ 1 个 native timing 工具包分层；每包带 README；架构图见 `README.md` / `README.zh.md`（mermaid）与 `docs/ARCHITECTURE.md` |
| 4 | README 说明项目目标、安装方式、使用方法、示例，且可复现 | ✅ | 双语 README（英文主 + `README.zh.md`）：30 秒上手、在线滚动叙事首页与六工具工作台、浏览器试用（含截图）、API 速览、错误码表、性能数据；`examples/` 自带完好/篡改双包可即时复现；`docs/GUIDE.md` 三场景全部命令实跑验证过 |
| 5 | 使用持续集成工具且覆盖检查、构建、测试流程 | ✅ | `.github/workflows/ci.yml`：`moon check --deny-warn --target all`、`moon fmt --check`、`moon info && git diff --exit-code -- src/**/*.mbti`、`moon test --deny-warn --target wasm,wasm-gc,js`、`moon test --deny-warn --target native`、三后端构建、CLI 黑盒（native+js）、浏览器适配器烟测、fixtures 防腐化校验；`.github/workflows/showcase-pages.yml` 额外执行前端 TypeScript check 与生产构建后部署；本地 Windows/MSVC 与 WSL/Linux 已验证 native 单测与黑盒 |
| 6 | 记录完整项目申报材料 | ✅ | `docs/申报书.pdf`（一页申报 PDF）、`docs/application/OSC2026_APPLICATION.md`（申报书源文档）、`docs/report/DEVELOPMENT_REPORT.md`（开发报告）、`docs/records/`（决策日志 + 结果日志全程留痕）；根目录 `LICENSE` 提供 Apache-2.0 项目级开源许可证 |
| 7 | 开发过程公开可追踪（过程记录、提交记录、更新日志） | ✅ | 130+ 个提交按逻辑单元标注；`RESULTS_LOG.md` 时间线含每步验收命令与结果，已记录 Release readiness gate 与 native timing 长跑摘要；`DECISION_LOG.md` 含关键决策及理由；探针类失败（moon prove / moon doc）亦留痕 |

## 远端确认项

1. 看 GitHub Actions `main` 最新 CI 结果（本地 Windows/MSVC 与 WSL Linux/gcc 已验证 native 构建、单测与黑盒；远端 ubuntu/gcc 以 Actions 页面为准）
2. 若 GitHub 页面缓存未及时显示最新 run，重新推送 `main` 或手动重跑 workflow。
3. Mooncakes 已同步发布 `starlittle/MoonEvidence` v0.4.1，仓库版本与注册表版本一致。
