# MoonEvidence 开发报告

> MoonBit OSC2026 开源生态挑战赛 · 项目验收材料
> 仓库：https://github.com/starlittle/MoonEvidence ｜ 规模：9068 行 MoonBit（实现 4379 + 测试 4689）｜ 提交：81 个 ｜ 包：12 个
> 本报告为单一权威开发报告，合并了功能清单、AI 协作实践与工程质量三方面内容。

## 一、项目概述

**MoonEvidence 是一个链无关的可信证据包验证库与 CLI。** 它回答一个具体问题：一组文件、元数据、Merkle 证明和版本记录，与当初承诺的状态相比，是否完整、未被篡改？

**核心定位**：链无关验证核心——不是区块链框架或智能合约平台，而是在区块链存证前、数据集归档、数字版权打包、AI 输出审计等场景中复用的通用验证引擎。

**选题动机**来自一个生态空白观察：上链存证、数据集归档、AI 产物审计的共同前置需求是"可复核的完整性验证"，而 Mooncakes 生态中没有同类项目（申报期与发布前两次碰撞检查均为零命中，`merkle` 关键词仅命中通用库 `zploc/loci`，证据见 `docs/research/MOONCAKES_COLLISION_CHECK.md` 与 RESULTS_LOG step 10）。MoonEvidence 刻意**不做**区块链应用或智能合约——它是任何存证流程都需要、但与链解耦的验证核心，对应赛题推荐方向中的「工程基础设施 / 面向特定格式的验证工具」。

项目为**原创实现**，遵循的外部参考是两份公开标准：RFC 8785（JSON Canonicalization Scheme）与 RFC 6962 风格的 Merkle 树域分离构造。

**技术亮点**：

- 纯 MoonBit 实现，零外部依赖
- 三后端支持（native / wasm-gc / js），同一代码逐字节一致
- 核心库零 IO 依赖，适配器注入字节
- 含完整 Ed25519 数字签名（纯 MoonBit 椭圆曲线密码学，约 800 行）

## 二、架构设计

```text
适配层（唯一允许 IO 的地方）     纯验证核心（零 IO，三后端可移植）
┌─────────────────────┐        ┌──────────────────────────────────┐
│ src/cmd/main  CLI   │───────▶│ verify ── model ── digest        │
│ src/api  浏览器 esm  │───────▶│    │        │                    │
└─────────────────────┘        │  diag ── canonjson    merkle ────┘
                               │  create  store  audit  crypto    │
                               └──────────────────────────────────┘
```

### 包分层（12 个包）

```text
src/canonjson  -> 确定性 JSON 序列化 (RFC 8785)
src/digest     -> 摘要类型、算法枚举、hex/base64 辅助、SHA-256/SHA-512/HMAC
src/merkle     -> Merkle 根计算、包含性证明验证与完整树物化 (RFC 6962 风格)；compute_tree 返回每层所有哈希，leaf_path 从叶子到根脊线，为可视化提供遍历能力
src/model      -> manifest、文件条目、证明、版本节点模型
src/verify     -> 包/文件/manifest/版本验证编排（七步流水线）
src/diag       -> 结构化诊断与 explain 输出
src/create     -> 从原始文件构建证据包
src/store      -> 内容寻址对象存储（类 Git）
src/audit      -> 哈希链追加式审计日志
src/crypto     -> Ed25519 数字签名（纯 MoonBit）
src/cmd/main   -> native CLI 适配器
src/api        -> 浏览器 ESM 适配器（string-in/string-out）
examples/      -> valid 与 tampered 证据包
tests/         -> 夹具与黑盒回归测试
```

### 五个关键架构决策（完整记录见 docs/records/DECISION_LOG.md）

| 决策 | 内容与理由 |
| --- | --- |
| 纯核心 / 适配器分层 | 验证管线只接受 `Map[String, Bytes]`，文件读取全部留在适配层。这使同一套语义可在 native CLI、浏览器、CI 三后端矩阵中逐字节一致地复核（DECISION_LOG「MVP Boundary」） |
| 错误码冻结为公共契约 | `E1xxx`–`E5xxx`、`W1xxx` 在 spec 中冻结，测试与 CLI 都对码断言；报告完备式输出（非 fail-fast），用户一轮修完所有问题 |
| 数字序列化分级交付 | RFC 8785 最难的数字最短形式拆为 L1 安全子集 → L2 完整 ECMAScript shortest form 两级，L2 作为独立步骤交付并以 RFC 8785 Appendix B 向量钉死（DECISION_LOG step 8） |
| 路径穿越在解析期拒绝 | `files[].path` 拒绝 `..` 段、绝对路径、盘符、反斜杠、`.` 与空段别名——恶意 manifest 无法诱导 CLI 读包外文件。该缺口由开发中的安全自审发现，按 TDD 先红后绿修复（DECISION_LOG step 7） |
| 版本链形状与语义分离 | model 层只管形状（id 非空、parent 可空），verify 层管图语义（唯一根/可达/无环/无分叉），各自的错误码不互相越界 |

### 冻结 API v2（2026-07-04）

公共 API 已冻结至 v2（见 `docs/ARCHITECTURE.md`）。v1 冻结覆盖六个核心包（canonjson/digest/merkle/model/verify/diag）；v2 扩展冻结纳入 `create`/`store`/`audit`/`crypto`/`api` 五个新增包的公共签名。改变签名需记 `DECISION_LOG.md` 条目。

## 三、功能清单

### 第一阶段：MVP（已完成）

| 功能 | 说明 |
| --- | --- |
| Canonical JSON | RFC 8785 规范化序列化 |
| SHA-256 | 纯 MoonBit 实现，NIST 向量验证 |
| Merkle 树 | RFC 6962 风格，根计算+证明验证；`compute_tree` 物化每层所有哈希，`leaf_path` 返回叶子到根的脊线，供可视化层零成本遍历 |
| 证据清单模型 | 带验证的 manifest 解析 |
| 版本链验证 | 时间线性+哈希链完整性 |
| 7 步验证流水线 | 解析到诊断的完整管线 |
| CLI 工具 | verify / explain 命令 |
| 浏览器端验证 | ESM 模块，纯客户端验证 |

### 第二阶段：功能扩展（已完成）

| 功能 | 说明 |
| --- | --- |
| 证据包创建 | create_manifest API + CLI create 命令 |
| HMAC-SHA256 | RFC 2104 消息认证码 |
| SHA-512 | 多算法支持 |
| 增量验证 | 摘要缓存，跳过未改动文件 |
| 批量 CLI | 一次验证多个包 |
| 内容寻址存储 | 类 Git object store，SHA-256 去重 |

### 第三阶段：进阶探索（已完成核心）

| 功能 | 说明 |
| --- | --- |
| 审计日志 | 哈希链串联的追加式操作记录 |
| GF(2^255-19) | 16-limb TweetNaCl 风格有限域 |
| Curve25519 点运算 | HWCD08 扩展坐标加法/倍点 |
| Ed25519 签名 | RFC 8032 sign/verify API |
| 审计日志签名集成 | 可选 Ed25519 签名验证 |

### 逐包功能说明

**6 核心包（纯库，零 IO）：**

| 包 | 功能 |
| --- | --- |
| `canonjson` | RFC 8785 规范化 JSON——生态首个实现；键按 UTF-16 code unit 排序，数字最短形式分两级交付，转义规则按规范实现 |
| `digest` | 纯 MoonBit SHA-256/SHA-512/HMAC 含流式 API；NIST FIPS 180-4 向量钉死；统一 `hex_to_bytes` 单一实现 |
| `merkle` | RFC 6962 风格域分离树（`0x00`/`0x01` 前缀）+ 包含性证明；golden 数据由独立 Node 参考实现交叉生成 |
| `model` | manifest / 版本链模型，路径穿越在解析期拒绝（`..`/绝对路径/盘符/反斜杠/空段/null 字节） |
| `verify` | 七步验证流水线（解析→规范化→摘要→文件→Merkle→版本链→报告）；含增量验证路径 |
| `diag` | 结构化诊断 + explain；`to_json` 输出 RFC 8785 规范 JSON——验证报告自己也可被摘要、被存证 |

**4 扩展包：**

| 包 | 功能 |
| --- | --- |
| `create` | `create_manifest` API + CLI create；从原始文件字节构建证据包，文件按 code-point 序排序保证跨工具 Merkle root 一致 |
| `store` | 内容寻址对象存储（类 Git）；`put`/`get`/`has`/`deduplicate`/`reconstruct` + 完整性校验；Int64 字节数防溢出 |
| `audit` | 哈希链追加式审计日志；`append`/`verify_chain`/`to_json`，可选 Ed25519 签名（`sign_last`/`verify_signatures`）；`verify_chain` 校验 hash 字段防篡改 |
| `crypto` | 纯 MoonBit Ed25519（RFC 8032）；从 `field25519` → `point25519` → `ed25519` 自底向上实现，约 800 行，零外部密码学依赖 |

**2 适配层（唯一允许 IO）：**

| 包 | 功能 |
| --- | --- |
| `cmd/main` | native CLI 适配器；`verify`/`explain`/`create` 命令，冻结退出码 0/1/2；collect_pack_files 拒绝 symlink 防越界与无限循环 |
| `api` | 浏览器 ESM 适配器；`verify_evidence(request_json) -> String`，唯一跨边界类型是 String，任何 JS 宿主零成本集成 |

## 四、密码学实现

本项目含**自实现的密码学原语**，未依赖任何外部经审计的密码学库。

### 标准合规性证据

- **RFC 8785**：官方 Appendix B 数字向量全过；键按 UTF-16 code unit 排序；转义规则按规范实现。fixtures 在 `tests/fixtures/jcs/`
- **SHA-256 / SHA-512**（`src/digest`）：纯 MoonBit 实现，对照 NIST FIPS 180-4 标准测试向量验证
- **HMAC-SHA256**（`src/digest`）：RFC 2104 消息认证码
- **RFC 6962 风格 Merkle 树**：叶/内节点域分离（`0x00`/`0x01` 前缀），golden 数据由独立 Node 参考实现交叉生成（`tools/gen-merkle-fixtures.mjs`），两套实现逐字节对账
- **报告本身规范化**：`to_json` 输出 RFC 8785 规范 JSON——验证报告自己也可以被摘要、被存证

### Ed25519（RFC 8032）

从零实现的椭圆曲线数字签名，不依赖任何外部密码学库：

1. **GF(2^255-19) 有限域**：16 × 16-bit limbs（TweetNaCl 方法），所有中间值安全在 UInt64 内
2. **扩展坐标点运算**：HWCD08 统一加法 + 专用倍点，避免分支
3. **标量乘法**：MSB-first double-and-add，constant-time conditional select（cmov）替代分支，降低侧信道风险
4. **签名流程**：SHA-512 → 私钥 clamp → 确定性 nonce → R=rB → S=(r+kA)mod l
5. **验证流程**：解码点 → SHA-512 → S·B == R + k·A；含 `S < l` 范围检查（RFC 8032 §8.4 反可塑性）

### 第二轮根因修复（crypto 加固）

经 2026-07-04 健康体检后的第二轮根因修复进一步加固了密码学实现（详见 `SECURITY.md` 与 `CHANGELOG.md` 0.3.1）：

- **Barrett reduction** 替换 `reduce_scalar_512` 的逐次减法，签名路径性能从 ~500K 次操作降至 ~50 次乘法
- **point_decode 拒绝低阶点与非规范编码**，补 cofactor 相关的小群攻击防护
- **审计签名覆盖 canonical JSON**：audit 日志签名基于 RFC 8785 规范化序列化，确保签名输入字节稳定无歧义

> **安全声明**：本项目的密码学实现（尤其是 Ed25519）尚未经过外部专业安全审计。它通过了 RFC 8032 已知答案测试（KAT）与交叉对拍，但不应在生产环境或高价值资产保护场景中作为唯一的信任根使用。如需生产级保证，请替换为经审计的密码学库。

## 五、测试与验证体系

| 层 | 数量与内容 |
| --- | --- |
| 单元测试 | **258 个**，wasm-gc 与 js 双后端全绿；含 NIST/RFC 向量、JCS fixtures、版本链图语义、Merkle 树物化与路径 |
| CLI 黑盒 | **41 用例**（`tools/cli-test.ps1` + `tools/cli-test.sh` 1:1 对等）：12 个命令形状 + 10 包篡改矩阵 + 19 个 manifest 错误码矩阵，逐 pack / 逐 fixture 断言**精确错误码集合**（禁止"至少包含"式宽松断言） |
| 篡改矩阵 | `tests/fixtures/packs/` 10 个 pack 由独立 Node 参考实现生成，覆盖每个错误码族；CI 设防腐化校验（重新生成后 `git diff` 必须为空） |
| manifest 错误码矩阵 | `tests/fixtures/manifest/` 19 个夹具，覆盖 E1001/E1002/E1003/E2001/E2002 在 CLI 黑盒层的触发 |
| 独立交叉验证 | `tools/cross-verify.mjs` 独立 Node 实现对 create/store/audit 产出重算对比，避免本库自验证盲区 |
| Property 测试 | 规范化幂等、Merkle 证明可靠性——并经**变异验证**（`tools/mutation-check.mjs` 故意破坏实现确认测试会红，3/3 捕获，证明断言非恒真） |
| Fuzz | parser fuzz 400 轮随机字节不 panic |
| 长链压测 | 1000 节点版本链性能数据 |
| 浏览器适配器 | 18 个 wbtest + Node 烟测（`tools/smoke-api.mjs`）+ Playwright 实浏览器会话验证 |
| 基准 | `moon bench`：SHA-256 ~58 MiB/s（js 后端），全量验证 ~26-28 µs/文件，10 倍文件量 → 11.05 倍耗时（近线性） |

### 测试覆盖分布

| 包 | 测试数 |
| --- | --- |
| crypto (field + point + ed25519) | ~18 |
| audit (含签名集成) | ~10 |
| store (对象存储) | ~10 |
| digest (SHA-256/512 + HMAC) | ~40 |
| canonjson | ~30 |
| merkle | ~20 |
| model + verify + diag | ~50 |
| 其他 | ~56 |

## 六、CI 与工程治理

- **CI 三后端矩阵**：native / wasm-gc / js 构建，wasm-gc+js 测试，native（ubuntu gcc）+ js 黑盒，js 适配器烟测；fixtures 防腐化校验
- **fmt 门禁**：CI 运行 `moon fmt --check` 作为必需门禁，防止格式漂移复发
- **基准**：bench 设为单独 job，结果落基线 JSON，性能回归可发现
- **release 流程**：tag 触发 release 工作流（`moon package` 产物 + SHA256 签名）
- **冻结退出码**：CLI 退出码 0/1/2 不变，便于 CI 集成
- **冻结错误码**：E1xxx-E5xxx / W1xxx 诊断码，机器可读
- **三后端兼容**：同一代码编译到 native / wasm-gc / js
- **Git 工作流**：有意义的 commit message，feature 粒度提交
- **双仓库同步**：GitHub + Gitlink
- **文档齐全**：README（中英双语）/ 架构文档 / 用户指南 / 证据包规范 / 环境搭建 / 代码规范 / 路线图 / SECURITY / CONTRIBUTING / CHANGELOG

## 七、AI 协作实践

本项目按"AI 执行 + 过程记录留痕"的模式开发，全程证据链在 `docs/records/RESULTS_LOG.md`（时间线）与 `docs/records/DECISION_LOG.md`（决策）中可复核。实践中沉淀出四条有效经验：

1. **探针优先于硬刚**：`moon prove` 本地无 Why3 环境、`moon doc` 与新版 `moon.mod` 格式不兼容——两次都是先做最小探针、记录失败根因与决策依据，再走 property 测试 / 人工核对的 fallback，探针记录本身成为交付物（RESULTS_LOG step 8/10）
2. **独立参考实现对账**：所有 golden 数据（摘要、Merkle 根、篡改矩阵）由 Node 独立实现生成，MoonBit 实现必须与之逐字节一致——任何一方出错都会被另一方抓住
3. **事故即叙事**：开发期 `examples/valid-pack` 被编辑器 CRLF 重写、基线变红——工具自己抓住了自家示例被篡改（E2003），处置后将整个 fixtures 子树标记 `-text` 固化教训（RESULTS_LOG step 7），这正是项目要解决的问题的现场版
4. **验证先于声称**：每步交付前全量重跑并把命令与结果记入 RESULTS_LOG；文档中的每条命令（含 GUIDE 的篡改演示）都在写入前实际执行过

### 健康体检迭代

项目在 2026-07-04 完成了一轮五阶段健康体检与改进（`docs/plans/2026-07-04-health-check-and-improvement-plan.md`），随后又进行了第二轮根因修复：把上一轮"归档加注释"式的两份开发报告合并为单一权威、把"核心矩阵移植"式的 bash CLI 测试补全为 1:1 对等，并对 crypto（Barrett reduction、cofactor 检查、canonical JSON 签名）与 verify/create（排序、symlink、valid.json、E3002 决定）做了根本性修复。这种"体检 → 根因 → 再体检"的迭代本身是 AI 协作工程治理的实践样本。

## 八、量化指标（本机实测）

| 指标 | 实测值 |
| --- | --- |
| 提交数 | 81 |
| 实现行数 | 4379 |
| 测试行数 | 4689 |
| 总行数 | **9068** |
| 测试声明 | 258（254 测试 + 4 基准调用） |
| 单元测试通过 | **254/254**（wasm-gc + js 双后端） |
| CLI 黑盒通过 | **41/41** |
| 包数 | **12** |
| moon check warnings | 0 |
| moon fmt --check | exit 0（无漂移） |

> 以上数字为 2026-07-04 Asia/Shanghai 本机实测冻结基线（见 `docs/records/RESULTS_LOG.md`），全仓文档统一引用此基线。

## 九、创新点与竞争力

MoonBit 生态当前缺少数据完整性验证基础设施。MoonEvidence 填补了这一空白：

1. **RFC 8785 生态首个实现**：`canonjson` 是 Mooncakes 生态中第一个 JSON Canonicalization Scheme 实现，含官方 Appendix B 数字向量全过
2. **纯 MoonBit 密码学**：从 GF(2^255-19) 有限域到 Ed25519 签名验签，约 800 行，零外部密码学依赖——生态首个从底向上的椭圆曲线签名实现
3. **可解释诊断**：报告完备式输出（非 fail-fast），结构化错误码 + explain 命令，用户一轮修完所有问题；验证报告自身规范化可被存证
4. **可发布的 Mooncakes 包**：12 个包均可独立复用，核心验证逻辑可作为独立库复用
5. **跨平台演示**：同一代码在 CLI、CI、浏览器三种环境逐字节一致运行
6. **安全设计**：路径遍历防护、null 字节拒绝、symlink 拒绝、冻结错误码、确定性输出、Ed25519 反可塑性检查

## 附录：验收自查

见 `docs/records/ACCEPTANCE_CHECKLIST.md`（逐条对照打勾 + 证据指引）；最终冻结快照（命令、结果、commit hash）见 RESULTS_LOG step 11 条目。
