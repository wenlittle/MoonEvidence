# 验收要求自查清单

对照赛方「申请完成支持的项目应满足的要求」逐条核对。核对日期：2026-06-11 Asia/Shanghai。

| # | 要求 | 状态 | 证据 |
| --- | --- | --- | --- |
| 1 | 项目以 MoonBit 为主要实现语言 | ✅ | 全部核心逻辑为 MoonBit：12 个包，实现 4896 行 + 测试 5542 行，合计 **10438 行**（落在 4-10k 要求区间）。仓库内 JS 仅为独立参考实现/烟测工具（`tools/*.mjs`）与 demo 页面胶水，不承担验证语义 |
| 2 | GitHub 与 Gitlink 仓库公开可访问、提交记录完整 | ⏳ 推送后即满足 | 本地 main 分支 **91 个提交**（远超 10-20 有效提交要求），按逻辑单元划分、conventional commits 风格、每步附验收记录。待执行：双推 GitHub + Gitlink 并确认 CI 首跑绿（推送属外部可见操作，由仓库所有者执行） |
| 3 | 源代码结构清晰、架构表达完整核心功能 | ✅ | 12 个包（6 核心：canonjson/digest/merkle/model/verify/diag 零 IO + 4 扩展：create/store/audit/crypto + 2 适配器：cmd/main CLI、api 浏览器）分层；每包带 README；架构图见 `README.md` / `README.zh.md`（mermaid）与 `docs/ARCHITECTURE.md` |
| 4 | README 说明项目目标、安装方式、使用方法、示例，且可复现 | ✅ | 双语 README（英文主 + `README.zh.md`）：30 秒上手、浏览器试用（含截图）、API 速览、错误码表、性能数据；`examples/` 自带完好/篡改双包可即时复现；`docs/GUIDE.md` 三场景全部命令实跑验证过 |
| 5 | 使用持续集成工具且覆盖检查、构建、测试流程 | ✅ | `.github/workflows/ci.yml`：`moon check`（检查）+ 三后端 `moon build`（构建）+ `moon test --target wasm-gc,js`、CLI 黑盒（native+js）、浏览器适配器烟测、fixtures 防腐化校验（测试） |
| 6 | 记录完整项目申报材料 | ✅ | `docs/application/OSC2026_APPLICATION.md`（申报书）、`docs/report/DEVELOPMENT_REPORT.md`（开发报告）、`docs/records/`（决策日志 + 结果日志全程留痕） |
| 7 | 开发过程公开可追踪（过程记录、提交记录、更新日志） | ✅ | 91 个提交按步骤标注（step N task M）；`RESULTS_LOG.md` 时间线含每步验收命令与结果；`DECISION_LOG.md` 含 5 项关键决策及理由；探针类失败（moon prove / moon doc）亦留痕 |

## 唯一待办

仓库双推（GitHub + Gitlink）后：

1. 确认两仓库公开可访问 → 勾掉第 2 条
2. 看 CI 首跑结果（native 构建与黑盒为本地不可验证步骤，预期绿；如红按日志修复）
3. （可选）`moon login` 后 `moon publish` 发布 0.1.0 到 Mooncakes —— 发布就绪状态见 RESULTS_LOG step 10
