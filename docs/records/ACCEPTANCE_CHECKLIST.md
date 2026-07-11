# 验收要求自查清单

对照赛方九项硬性验收要求逐条核对。核对日期：2026-07-11 Asia/Shanghai。

| # | 要求 | 状态 | 证据 |
| --- | --- | --- | --- |
| 1 | 项目以 MoonBit 为主要实现语言 | ✅ | 证据模型、规范化、摘要、Merkle、创建、验证、诊断、签名与 CLI 语义均由 MoonBit 实现：12 个产品包 + 1 个 native timing 工具包，实现 6453 行 + 测试 8118 行，合计 **14571 行**。Go/TypeScript 仅是可选 Fabric 协议适配器，不重算证据语义，并被排除在 Mooncakes 包外 |
| 2 | GitHub 与 Gitlink 仓库公开可访问、提交记录清晰 | ✅ | GitHub `wenlittle/MoonEvidence` 与 Gitlink `starlittle/MoonEvidence` 公开可访问；本地分支 **140 个提交**以上，功能、测试、文档、展示与发布按逻辑单元提交；双仓同步状态在每次交付前复核 |
| 3 | 源代码结构清晰，能够完成声明的核心功能 | ✅ | 6 个零 IO 核心包 + 4 个扩展包 + CLI/浏览器 2 个 MoonBit 适配器 + 1 个 timing 工具包；`integrations/fabric` 独立放置 Go Chaincode 与 TypeScript Gateway。`docs/ARCHITECTURE.md` 冻结纯核心、机器接口和链上隐私边界；真实 create/verify/anchor/query/backfeed 闭环已跑通 |
| 4 | README 说明目标、安装、用法和示例，且可复现 | ✅ | 双语 README 提供 Mooncakes 安装、`pack`/`inspect`/`verify` 可复制命令、浏览器体验、Fabric 真实记录与测试基线；`docs/GUIDE.md` 按归档、AI 审计、Fabric 锚定三场景展开；`integrations/fabric/README.md` 给出 test-network 部署、profile、CLI 与 Node API |
| 5 | CI 覆盖检查、构建、测试流程 | ✅ | required MoonBit job 覆盖 deny-warn type check/test、fmt、`moon info` 漂移、native/wasm/wasm-gc/js、62 用例双 shell CLI、smoke/fuzz/property/differential/mutation；required Fabric job覆盖 `go vet`、`go test -race -cover`、TypeScript check/build/test；Pages job验证并发布真实 MoonBit 网页产物 |
| 6 | 至少一个可运行示例或最小使用样例 | ✅ | `examples/valid-pack` / `tampered-pack` 可直接由 CLI 和网页验证；在线首页与六工具工作台可运行；Fabric 适配器提供 `anchor-pack` 一条命令，脱敏记录保存首笔 block 6 `VALID` 交易、双组织查询和负向篡改回灌 |
| 7 | 提供完整测试，覆盖核心功能路径 | ✅ | 351 个测试声明（347 可执行 + 4 benchmark wrapper），三后端全绿；CLI 62/62；标准向量、Wycheproof、独立 Node oracle、随机差分、mutation 16/16、fuzz/property、native timing 均有门禁。Chaincode 覆盖率 82.1%，Gateway 19/19，并有真实 Fabric E2E 作为 mock 之外的协议证据 |
| 8 | 发布到 mooncakes.io | ✅ | `starlittle/MoonEvidence` v0.4.1 已作为稳定库基线发布；当前 HEAD 的 additive CLI/API 与 Fabric 工作记录在 CHANGELOG `Unreleased`，待下一 minor 发布。包内容门禁确认 `integrations/`、Node workspace、比赛材料和本地记录不进入可复用 MoonBit 包 |
| 9 | 使用 OSI 许可证，参考/移植符合原许可证 | ✅ | 根目录 `LICENSE` 为 OSI 认可的 Apache-2.0；Fabric Contract API、Fabric Gateway 与 grpc-js 直接依赖均为 Apache-2.0 并由 go/npm lockfile 固定；Wycheproof 来源与数量由专门清点门禁记录；未复制 Fabric 示例业务代码 |

## 远端确认项

1. 推送本轮提交后，确认 GitHub Actions `main` 的 `check-test-build`、`fabric-adapters` 与 Pages workflow 全绿。
2. 确认 Gitlink 默认分支包含相同提交，README、LICENSE、Fabric 集成源码与记录目录均公开可见。
3. 当前 Mooncakes 已发布 v0.4.1；本轮包含 additive CLI/API 与仓库级 Fabric 适配器。远端 CI 全绿后决定是否定版为 v0.5.0 并发布，发布前保持在 CHANGELOG `Unreleased`。
