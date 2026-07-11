# MoonEvidence 项目知识库

> 当前版本：v0.5.1
>
> 更新日期：2026-07-11 Asia/Shanghai
>
> 用途：让新的维护者或 AI 会话快速找到当前事实来源。精确接口、数字和运行结果不在本文复制维护。

## 项目模型

MoonEvidence 使用 MoonBit 创建和验证可信证据包。它固定一组文件的路径、大小和摘要，复核时定位缺失或变化的文件，并把完整结果交给人、脚本或浏览器。规范 manifest 摘要可以单独保存到归档系统、数据库或 Hyperledger Fabric，之后再回传给验证器检查历史一致性。

```text
原始文件 -> 核心证据包 -> 本地完整验证 -> 规范 manifest 摘要
              |                   |                 |
              |                   |                 +-> 归档或 Fabric
              |                   +-> VerifyReport
              +-> manifest.json + files/
```

三个边界需要始终分开：

1. 核心证据包由 `manifest.json` 和 `files/` 组成。
2. `versions/version_chain.json` 是可选发布历史扩展。
3. Merkle 包含性证明由库和浏览器 API 单独生成，不是完整验证的必需目录。

manifest 选择 SHA-256 或 SHA-512 后，文件摘要、Merkle 根、证明兄弟节点和外部 manifest 摘要使用同一算法。HMAC-SHA256 是摘要库的独立能力，不进入 manifest 算法字段。

## 交付组成

| 交付面 | 当前职责 | 入口 |
| --- | --- | --- |
| MoonBit 核心 | 规范 JSON、摘要、Merkle、模型、创建、验证、审计和签名 | [`src/`](../src/) |
| CLI | 目录封装、完整验证、机器回执和固定退出码 | [`src/cmd/main`](../src/cmd/main/) |
| 浏览器 API | 12 个字符串输入/输出接口，共用 MoonBit JS 产物 | [`src/api`](../src/api/) |
| Showcase | 首页、六工具工作台和篡改传播展示 | [`showcase/`](../showcase/) |
| Fabric 适配器 | 链下验证、摘要提交、交易回执、查询和摘要回传 | [`integrations/fabric/`](../integrations/fabric/) |
| Mooncakes | 12 个产品包，不包含仓库级 Fabric 依赖 | [`moon.mod`](../moon.mod) |

依赖从入口流向纯核心。纯核心只接收文本、字节和结构化参数，不读取文件、不启动进程、不连接网络。当前 MoonBit 测试覆盖 native、wasm、wasm-gc 和 js 四个后端。

## 稳定合同

| 主题 | 当前来源 | 关键约束 |
| --- | --- | --- |
| 证据包 | [证据包规范](spec/EVIDENCE_PACK_SPEC.md) | `moon-evidence/v0`、路径规则、SHA-256/SHA-512、Merkle、E1xxx-E4xxx |
| CLI | [CLI 契约](spec/CLI_MACHINE_CONTRACT.md) | 回执携带 schema；`verify --json` 使用 schema-less `VerifyReport`；退出码 0/1/2 |
| Fabric | [Fabric 规范](spec/FABRIC_ANCHOR_SPEC.md) | 链上只接收规范摘要；v1 保存首笔记录，没有更新或删除交易 |
| MoonBit API | [`pkg.generated.mbti`](../src/) | `moon info` 生成，CI 阻断接口漂移 |

自动化先检查进程退出码。`pack`、`seal`、`create` 和 `inspect` 的成功回执再检查 `schema`；单包 `verify --json` 检查 `ok`、`findings` 和 `stats`。长期集成同时固定并检查 `moon-evidence --version`。

## 诊断语义

| 代码 | 当前含义 |
| --- | --- |
| `E2003` | manifest 登记的文件缺失、未提供或当前字节摘要不同 |
| `E2004` | 当前规范 manifest 摘要与外部历史摘要不同 |
| `E3003` | manifest 内文件条目重建出的 Merkle 根与记录根不同 |
| `W1001` | `files/` 中存在 manifest 未登记的文件；默认保持警告，严格归档策略可升级为拒绝 |

文件被直接修改时，`E2003` 对照原 manifest 定位路径。CLI 文本中的 `merkle root verified` 只表示原 manifest 条目与其记录根内部一致。浏览器篡改实验会另外重建候选条目和候选根，因此可以显示当前字节产生的分叉。文件和 manifest 一起重建后，外部旧摘要通过 `E2004` 识别历史变化。

## Fabric 口径

标准 `anchor-pack` 在链下执行 `inspect` 和完整 `verify`，通过后才提交规范摘要。账本记录确认某个 Fabric 身份提交了该摘要；本地验证结论保存在 MoonEvidence 报告和 Gateway 回执中。

2026-07-11 的脱敏记录覆盖 SHA-256、双组织查询、顺序重复、交易提交和摘要回传。顺序重复返回已保存的首笔记录；并发首写失败方只有在 Fabric 返回 MVCC validation code `11`，并经后续查询确认同一记录后才归一化。公开材料允许检查结构、源码哈希和运行结果，并可在 Fabric samples 上复跑等价流程；原始私有通道只对保留访问权的成员可查询。生产部署继续增加联盟治理、CA、ACL、备份、监控和可信时间控制。

## 质量基线

当前稳定数字由 [结果记录](records/RESULTS_LOG.md) 和 `tools/check-metrics.mjs` 维护：

| 验证面 | 当前基线 |
| --- | --- |
| MoonBit | 357 个测试声明，353 个可执行测试，四后端全绿 |
| CLI | PowerShell 和 bash、JS 和 native，每个组合 68/68 |
| 独立 oracle | RFC/NIST/Wycheproof；仓库内 Node.js 参考实现不调用 MoonBit 被测代码 |
| 随机与反向验证 | malformed fuzz、语义性质、差分检查、mutation 18/18 |
| 浏览器 | 12 个 MoonBit API，smoke 41/41，Showcase 生产构建通过 |
| Fabric | Gateway 19/19；Chaincode 82.1% 语句覆盖；双组织协议记录已保存 |

这些结果属于工程交付级保障。高价值生产部署把独立密码学审计、后端机器码复核、目标环境计时、托管密钥和运行监控设为发布门禁。

## 常用命令

```powershell
moon fmt --check
moon check --deny-warn --target all
moon info
moon test --deny-warn --target wasm,wasm-gc,js
moon test --deny-warn --target native

node tools/check-metrics.mjs
node tools/check-package-contents.mjs
node tools/check-branch-coverage-stale.mjs --self-test
powershell -ExecutionPolicy Bypass -File tools/cli-test.ps1 -Target js
npm --prefix showcase run check
npm --prefix showcase run build
npm run fabric:test
```

Windows native 命令需要先加载 MSVC 环境。完整前置条件见[环境准备](ENVIRONMENT.md)，发布门禁和随机化档位见[测试治理](TEST_GOVERNANCE.md)与[测试计划](TEST_PLAN.md)。

## 阅读路径

| 任务 | 建议入口 |
| --- | --- |
| 五分钟理解和复现 | [README](../README.md) -> [用户指南](GUIDE.md) |
| 评审系统设计 | [开发报告](report/DEVELOPMENT_REPORT.md) -> [架构](ARCHITECTURE.md) -> [安全说明](../SECURITY.md) |
| 评审测试可信度 | [测试计划](TEST_PLAN.md) -> [测试治理](TEST_GOVERNANCE.md) -> [结果记录](records/RESULTS_LOG.md) |
| 复跑 Fabric | [Fabric 指南](../integrations/fabric/README.md) -> [发布协议记录](records/fabric-e2e/2026-07-12-v0.5.1/) |
| 检查比赛交付 | [验收证据](records/ACCEPTANCE_CHECKLIST.md) -> [项目索引](PROJECT_INDEX.md) |

## 维护规则

1. 接口以 `pkg.generated.mbti` 和三份规范为准。
2. 精确数字只从 metrics 和带提交、环境、命令的结果记录引用。
3. 安全声明同时复核 `SECURITY.md`、架构和测试计划。
4. Fabric 结论分开描述链下验证、适配器测试和协议运行记录。
5. 发布前执行干净克隆、链接检查、四后端测试和无背景读者测试。

2026-07-07 的长篇阶段知识库保存在[历史快照](records/KNOWLEDGE_BASE_2026-07-07.md)，只用于追溯当时的 API、盲点和加固过程。
