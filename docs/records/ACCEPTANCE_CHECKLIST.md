# OSC2026 验收证据

核对日期：2026-07-11 Asia/Shanghai

核对范围：赛事章程九项基础验收要求

| 序号 | 验收项 | 结论 | 可复核证据 |
| --- | --- | --- | --- |
| 1 | 项目以 MoonBit 为主要实现语言 | 通过 | 证据模型、规范化、摘要、Merkle、创建、验证、诊断、签名和 CLI 语义均位于 [`src/`](../../src/)。当前实现 6529 行 + 测试 8138 行，合计 **14667 行**；12 个产品包和 1 个原生计时工具包由 [`moon.mod`](../../moon.mod) 管理。Go/TypeScript 只承担 Fabric 协议适配，不重算证据语义 |
| 2 | GitHub 和 Gitlink 公开可访问，提交记录清晰 | 通过 | [GitHub](https://github.com/wenlittle/MoonEvidence)和 [GitLink](https://gitlink.org.cn/starlittle/MoonEvidence)公开；维护者陈俊文对应 GitHub `wenlittle`、GitLink/Mooncakes `starlittle`；双仓默认分支为 `main`，仓库保留 **140 个提交**以上，代码、测试、文档、展示和发布按逻辑单元提交 |
| 3 | 源码结构清晰，能够完成声明的核心功能 | 通过 | [架构文档](../ARCHITECTURE.md)固定四层职责、数据流和信任边界；[项目结构](../STRUCTURE_TREE.md)映射源码、适配器和示例；创建、完整验证、篡改定位、外部摘要对照和 Fabric 回传均有实现与记录 |
| 4 | README 说明目标、安装、使用和示例，并可复现 | 通过 | [中文 README](../../README.md)和 [English README](../../README.en.md)提供安装、五分钟命令路径、预期输出和在线入口；[用户指南](../GUIDE.md)按封装、验证、自动化、浏览器和 Fabric 任务组织；README 流程已在干净目录复跑，环境、命令和输出保存在[结果记录](RESULTS_LOG.md) |
| 5 | CI 覆盖检查、构建和测试 | 通过 | [CI 工作流](../../.github/workflows/ci.yml)包含 deny-warn、格式、`moon info`、四后端构建/测试、双 shell CLI、浏览器 API、fuzz、property、差分、mutation 和 Fabric 适配器；[Pages 工作流](../../.github/workflows/showcase-pages.yml)构建真实 MoonBit JS 产物和 Showcase |
| 6 | 提供可运行示例或最小样例 | 通过 | [`examples/valid-pack`](../../examples/valid-pack)和 [`examples/tampered-pack`](../../examples/tampered-pack)可由 CLI 与浏览器直接验证；[在线 Showcase](https://wenlittle.github.io/MoonEvidence/)提供首页和六工具工作台；[Fabric 指南](../../integrations/fabric/README.md)提供一条命令的锚定入口 |
| 7 | 测试覆盖核心功能路径 | 通过 | [测试计划](../TEST_PLAN.md)将标准样例、独立 oracle、随机差分、异常输入、故障注入、进程黑盒和实链实验映射到风险；当前 352 个测试声明，348 个可执行测试，四后端全绿，CLI 每个 shell/target 组合 `67/67`，mutation `16/16`；详细命令见[结果记录](RESULTS_LOG.md) |
| 8 | 发布到 mooncakes.io | 通过 | [`starlittle/MoonEvidence` v0.5.0](https://mooncakes.io/docs/#/starlittle/MoonEvidence)已发布；`moon.mod`、CLI 版本、CHANGELOG、Git tag 和注册表版本一致；包内容门禁检查 233 个文件，并排除 Fabric、比赛材料和本地记录 |
| 9 | 采用 OSI 许可证，引用和移植合规 | 通过 | 根目录 [`LICENSE`](../../LICENSE)为 OSI 认可的 Apache-2.0；Fabric 直接依赖由 Go/npm 锁文件固定；[Wycheproof 向量文件](../../src/crypto/ed25519_wycheproof_wbtest.mbt)记录来源、版本和 Apache-2.0 许可证；Fabric 业务实现围绕项目摘要合同独立编写 |

## 发布证据

| 证据 | 当前记录 |
| --- | --- |
| 发布版本 | [GitHub Release v0.5.0](https://github.com/wenlittle/MoonEvidence/releases/tag/v0.5.0)，GitHub/GitLink 注解标签均指向发布提交 `8088147` |
| Mooncakes | v0.5.0 可由全新消费者项目解析、导入并运行公开 API |
| CI | MoonBit 主任务、Fabric 适配器和 Showcase Pages 均有公开成功记录；工作流入口位于 [GitHub Actions](https://github.com/wenlittle/MoonEvidence/actions) |
| 质量基线 | native、wasm、wasm-gc、js 各 `348/348`；独立参考、随机差分和 mutation 全绿 |
| Fabric | [双组织记录](fabric-e2e/2026-07-11/)保存 block 6 `VALID` 交易、跨组织查询、幂等重复和 `E2003`/`E2004` 回传 |
| 许可证 | GitHub 已识别 Apache-2.0，Mooncakes 发布元数据保持一致 |

## 运营动作

仓库侧九项要求已经形成可复核证据。赛事群或组委会发布最终提交入口后，提交 GitHub、GitLink 和指定表单；演示视频作为展示材料随通知提供。
