# MoonEvidence 开发报告

> MoonBit OSC2026 开源生态挑战赛 · 项目验收材料
> 仓库：https://github.com/starlittle/MoonEvidence ｜ 规模：6891 行 MoonBit（实现 3590 + 测试 3301）｜ 提交：76 个

## 一、项目背景与定位

**MoonEvidence 是一个链无关的可信证据包验证库与 CLI。** 它回答一个具体问题：一组文件、元数据、Merkle 证明和版本记录，与当初承诺的状态相比，是否完整、未被篡改？

选题动机来自一个生态空白观察：上链存证、数据集归档、AI 产物审计的共同前置需求是"可复核的完整性验证"，而 Mooncakes 生态中没有同类项目（申报期与发布前两次碰撞检查均为零命中，`merkle` 关键词仅命中通用库 `zploc/loci`，证据见 `docs/research/MOONCAKES_COLLISION_CHECK.md` 与 RESULTS_LOG step 10）。MoonEvidence 刻意**不做**区块链应用或智能合约——它是任何存证流程都需要、但与链解耦的验证核心，对应赛题推荐方向中的「工程基础设施 / 面向特定格式的验证工具」。

项目为**原创实现**，遵循的外部参考是两份公开标准：RFC 8785（JSON Canonicalization Scheme）与 RFC 6962 风格的 Merkle 树域分离构造。

## 二、架构决策（完整记录见 docs/records/DECISION_LOG.md）

```text
适配层（唯一允许 IO 的地方）     纯验证核心（零 IO，三后端可移植）
┌─────────────────────┐        ┌──────────────────────────────────┐
│ src/cmd/main  CLI   │───────▶│ verify ── model ── digest        │
│ src/api  浏览器 esm  │───────▶│    │        │                    │
└─────────────────────┘        │  diag ── canonjson    merkle ────┘
                               └──────────────────────────────────┘
```

五个关键决策及其理由：

| 决策 | 内容与理由 |
| --- | --- |
| 纯核心 / 适配器分层 | 验证管线只接受 `Map[String, Bytes]`，文件读取全部留在适配层。这使同一套语义可在 native CLI、浏览器、CI 三后端矩阵中逐字节一致地复核（DECISION_LOG「MVP Boundary」） |
| 错误码冻结为公共契约 | `E1xxx`–`E5xxx`、`W1xxx` 在 spec 中冻结，测试与 CLI 都对码断言；报告完备式输出（非 fail-fast），用户一轮修完所有问题 |
| 数字序列化分级交付 | RFC 8785 最难的数字最短形式拆为 L1 安全子集 → L2 完整 ECMAScript shortest form 两级，L2 作为独立步骤交付并以 RFC 8785 Appendix B 向量钉死（DECISION_LOG step 8） |
| 路径穿越在解析期拒绝 | `files[].path` 拒绝 `..` 段、绝对路径、盘符、反斜杠、`.` 与空段别名——恶意 manifest 无法诱导 CLI 读包外文件。该缺口由开发中的安全自审发现，按 TDD 先红后绿修复（DECISION_LOG step 7） |
| 版本链形状与语义分离 | model 层只管形状（id 非空、parent 可空），verify 层管图语义（唯一根/可达/无环/无分叉），各自的错误码不互相越界 |

## 三、标准兼容证据

- **RFC 8785**：官方 Appendix B 数字向量全过；键按 UTF-16 code unit 排序；转义规则按规范实现。fixtures 在 `tests/fixtures/jcs/`
- **SHA-256**：纯 MoonBit 实现，NIST 标准向量钉死（`src/digest/sha256_wbtest.mbt`）
- **RFC 6962 风格 Merkle 树**：叶/内节点域分离（`0x00`/`0x01` 前缀），golden 数据由独立 Node 参考实现交叉生成（`tools/gen-merkle-fixtures.mjs`），两套实现逐字节对账
- **报告本身规范化**：`to_json` 输出 RFC 8785 规范 JSON——验证报告自己也可以被摘要、被存证

## 四、测试体系

| 层 | 数量与内容 |
| --- | --- |
| 单元测试 | **219 个**，wasm-gc 与 js 双后端全绿；含 NIST/RFC 向量、JCS fixtures、版本链图语义 |
| CLI 黑盒 | **22 用例**（`tools/cli-test.ps1`）：12 个示例包用例 + 10 包篡改矩阵逐 pack 断言**精确错误码集合**（禁止"至少包含"式宽松断言） |
| 篡改矩阵 | `tests/fixtures/packs/` 10 个 pack 由独立 Node 参考实现生成，覆盖每个错误码族；CI 设防腐化校验（重新生成后 `git diff` 必须为空） |
| Property 测试 | 规范化幂等、Merkle 证明可靠性——并经**变异验证**（故意破坏实现确认测试会红，证明断言非恒真） |
| 浏览器适配器 | 18 个 wbtest + Node 烟测（`tools/smoke-api.mjs`）+ Playwright 实浏览器会话验证 |
| 基准 | `moon bench`：SHA-256 ~58 MiB/s（js 后端），全量验证 ~26-28 µs/文件，10 倍文件量 → 11.05 倍耗时（近线性） |
| CI | 三后端矩阵（native/wasm-gc/js 构建，wasm-gc+js 测试，native+js 黑盒，js 适配器烟测）+ fixtures 防腐化 |

## 五、AI 协作实践总结

本项目按"AI 执行 + 过程记录留痕"的模式开发，全程证据链在 `docs/records/RESULTS_LOG.md`（时间线）与 `docs/records/DECISION_LOG.md`（决策）中可复核。实践中沉淀出四条有效经验：

1. **探针优先于硬刚**：`moon prove` 本地无 Why3 环境、`moon doc` 与新版 `moon.mod` 格式不兼容——两次都是先做最小探针、记录失败根因与决策依据，再走 property 测试 / 人工核对的 fallback，探针记录本身成为交付物（RESULTS_LOG step 8/10）
2. **独立参考实现对账**：所有 golden 数据（摘要、Merkle 根、篡改矩阵）由 Node 独立实现生成，MoonBit 实现必须与之逐字节一致——任何一方出错都会被另一方抓住
3. **事故即叙事**：开发期 `examples/valid-pack` 被编辑器 CRLF 重写、基线变红——工具自己抓住了自家示例被篡改（E2003），处置后将整个 fixtures 子树标记 `-text` 固化教训（RESULTS_LOG step 7），这正是项目要解决的问题的现场版
4. **验证先于声称**：每步交付前全量重跑并把命令与结果记入 RESULTS_LOG；文档中的每条命令（含 GUIDE 的篡改演示）都在写入前实际执行过

## 六、生态价值与后续路线

**可复用价值**：12 个包（6 核心 + 4 扩展 + 2 适配）均可独立复用——`canonjson`（生态首个 RFC 8785 实现）、`digest`（纯 MoonBit SHA-256/SHA-512/HMAC 含流式 API）、`merkle`（域分离树 + 包含性证明）、`create`（证据包创建）、`store`（内容寻址存储）、`audit`（哈希链审计日志）、`crypto`（纯 MoonBit Ed25519）对其他项目是直接可用的构件；`verify_evidence` 字符串边界让任何 JS 宿主零成本集成。

**后续路线**：
- 流式哈希接入适配层，把大包内存峰值从 Σ(全部文件) 降到 max(单文件)
- `verify --watch` 持续监视模式与增量验证（`(path, mtime, size) → digest` 索引缓存）
- Merkle 包含性证明的 CLI 暴露（单文件审计无需全包）
- GitHub Pages 托管浏览器 demo（页面已是纯静态形态）
- 多哈希算法位（`HashAlgorithm` 枚举已为编译器引导的扩展点）

## 附录：验收要求自查

见 `docs/records/ACCEPTANCE_CHECKLIST.md`（逐条对照打勾 + 证据指引）；最终冻结快照（命令、结果、commit hash）见 RESULTS_LOG step 11 条目。
