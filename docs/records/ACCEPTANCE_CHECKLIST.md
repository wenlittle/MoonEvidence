# 验收要求自查清单

对照赛方九项硬性验收要求逐条核对。核对日期：2026-07-11 Asia/Shanghai。

| # | 要求 | 状态 | 证据 |
| --- | --- | --- | --- |
| 1 | 项目以 MoonBit 为主要实现语言 | ✅ | 证据模型、规范化、摘要、Merkle、创建、验证、诊断、签名与 CLI 语义均由 MoonBit 实现：12 个产品包 + 1 个 native timing 工具包，实现 6453 行 + 测试 8118 行，合计 **14571 行**。Go/TypeScript 仅是可选 Fabric 协议适配器，不重算证据语义，并被排除在 Mooncakes 包外 |
| 2 | GitHub 与 Gitlink 仓库公开可访问、提交记录清晰 | ✅ | 参赛者/维护者陈俊文对应 GitHub `wenlittle`、Gitlink 与 Mooncakes 命名空间 `starlittle`；双仓公开可访问且默认分支均为 `main`，本地分支 **140 个提交**以上，功能、测试、文档、展示与发布按逻辑单元提交 |
| 3 | 源代码结构清晰，能够完成声明的核心功能 | ✅ | 6 个零 IO 核心包 + 4 个扩展包 + CLI/浏览器 2 个 MoonBit 适配器 + 1 个 timing 工具包；`integrations/fabric` 独立放置 Go Chaincode 与 TypeScript Gateway。`docs/ARCHITECTURE.md` 冻结纯核心、机器接口和链上隐私边界；真实 create/verify/anchor/query/backfeed 闭环已跑通 |
| 4 | README 说明目标、安装、用法和示例，且可复现 | ✅ | 双语 README 提供 Mooncakes 安装、`pack`/`inspect`/`verify` 可复制命令、浏览器体验、Fabric 真实记录与测试基线；`docs/GUIDE.md` 按归档、AI 审计、Fabric 锚定三场景展开；`integrations/fabric/README.md` 给出 test-network 部署、profile、CLI 与 Node API |
| 5 | CI 覆盖检查、构建、测试流程 | ✅ | required MoonBit job 覆盖 deny-warn type check/test、fmt、`moon info` 漂移、native/wasm/wasm-gc/js、62 用例双 shell CLI、smoke/fuzz/property/differential/mutation；required Fabric job覆盖 `go vet`、`go test -race -cover`、TypeScript check/build/test；Pages job验证并发布真实 MoonBit 网页产物 |
| 6 | 至少一个可运行示例或最小使用样例 | ✅ | `examples/valid-pack` / `tampered-pack` 可直接由 CLI 和网页验证；在线首页与六工具工作台可运行；Fabric 适配器提供 `anchor-pack` 一条命令，脱敏记录保存首笔 block 6 `VALID` 交易、双组织查询和负向篡改回灌 |
| 7 | 提供完整测试，覆盖核心功能路径 | ✅ | 351 个测试声明（347 可执行 + 4 benchmark wrapper），三后端全绿；CLI 62/62；标准向量、Wycheproof、独立 Node oracle、随机差分、mutation 16/16、fuzz/property、native timing 均有门禁。Chaincode 覆盖率 82.1%，Gateway 19/19，并有真实 Fabric E2E 作为 mock 之外的协议证据 |
| 8 | 发布到 mooncakes.io | ✅ | `starlittle/MoonEvidence` v0.5.0 已发布；`moon.mod`、CLI_VERSION、CHANGELOG、Git tag 与注册表版本一致。包内容门禁确认 `integrations/`、Node workspace、比赛材料和本地记录不进入可复用 MoonBit 包 |
| 9 | 使用 OSI 许可证，参考/移植符合原许可证 | ✅ | 根目录 `LICENSE` 为 OSI 认可的 Apache-2.0；Fabric Contract API、Fabric Gateway 与 grpc-js 直接依赖均为 Apache-2.0 并由 go/npm lockfile 固定；Wycheproof 150 条测试向量在源文件中记录来源、版本和 Apache-2.0 许可证；未复制 Fabric 示例业务代码 |

## 最终远端确认

1. ✅ GitHub `main` 的 v0.5.0 基线 `8088147` 上，CI `check-test-build`、`fabric-adapters`、`bench` 与 Showcase Pages 全绿。
2. ✅ GitHub 与 Gitlink 默认分支均为 `main`；双仓 `v0.5.0` 注解标签均剥离到 `8088147`。
3. ✅ Mooncakes 已发布 `starlittle/MoonEvidence` v0.5.0；全新消费者项目可解析、导入并运行公开 API。
4. ⏳ 仓库外仅剩赛事运营动作：以赛事群或组委会通知为准，确认是否需要另填“完成支持”验收表。演示视频属于可选展示材料，不是九项基础验收硬门槛。
