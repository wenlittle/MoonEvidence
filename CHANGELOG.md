# Changelog

本文件记录 MoonEvidence 的版本演进。版本号遵循语义化版本（SemVer）。

## [0.4.0] - 2026-07-04

可视化公开：把 Merkle 树从内部数据结构暴露为可观察、可验证的运行时对象。

### Added

- **Merkle 完整树物化**：`src/merkle` 新增 `compute_tree(leaves)`（→ `MerkleTree`）、`tree.root()`、`tree.level(i)`、`tree.height()`、`tree.leaf_count()`、`tree.leaf_path(index)` API。树高度 = 内部层数；奇数叶节点被无损提升到上一层（字节相等的复制，不重新哈希）。
- **Merkle 路径节点**：`PathStep { level, node_index }` 描述从叶到根的完整爬升路径，含边界检查与索引校验。
- **`compute_merkle_tree` 浏览器适配**：JS 字符串接口新增 `compute_merkle_tree(request)`，输出 `{ok, tree:{leaf_count, height, levels, root:{recorded, actual, matches}, leaves_meta, example_path}, error?}`，便于可视化 audit 视图直接消费。

### Tests

- `src/merkle/merkle_wbtest.mbt` +8 树形与路径覆盖（含 1/2/3/4/5/7/8/16 形状、根一致性、空树、边界索引）。
- `src/api/api_wbtest.mbt` +4 compute_merkle_tree 白盒（金色包、空 files、坏请求、根不匹配、path 长度）。总数 246 → 251。

## [0.3.1] - 2026-07-04

第二轮根因修复：消除第一轮"归档加注释 / 核心矩阵移植"式的缝补，改用根本方案。本条目仅记录文档与测试脚本侧的根因修复；crypto 与 verify/create 代码侧的根因修复由并行代理同步进行。

### Changed

- **合并两份开发报告为单一权威**：`docs/report/DEVELOPMENT_REPORT.md` 现为唯一权威开发报告，合并了功能清单（完整度）、AI 协作实践（创新点）与工程质量（密码学/测试/CI）三方面优点，量化数据统一到 76 提交 / 7593 行 / 234 测试 / 12 包。`docs/DEVELOPMENT_REPORT.md` 改为单行重定向。`PROJECT_INDEX.md`、`README.md`、`README.zh.md` 的引用同步指向权威报告。

### Added

- **cli-test.sh 完整 1:1 对等移植**：`tools/cli-test.sh` 与 `tools/cli-test.ps1` 用例完全对等——补齐 Part 3（19 个 manifest 错误码矩阵夹具），修正 Part 1 多模式断言（与 PowerShell MustMatch 数组 AND 语义一致），jq 缺失时明确报错退出而非静默跳过。bash 版与 PowerShell 版均覆盖 41 用例（12 命令形状 + 10 篡改矩阵 + 19 manifest 矩阵）。
- **ARCHITECTURE.md 0.3.1 根因加固说明**：记录 crypto（Barrett reduction、point_decode 低阶点拒绝、审计签名覆盖 canonical JSON）与 E3002 错误码契约的根因修复说明。E3002 错误码契约已明确（详见 `DECISION_LOG` 最新条目）。
- **SECURITY.md 密码学实现更新**：反映 Ed25519 现已具备 Barrett reduction、cofactor / 低阶点检查、恒定时间标量乘法、审计签名覆盖 canonical JSON 等防护；更新残留限制说明。

## [0.3.0] - 2026-07-04

进阶探索：把验证库扩展为带可信审计与数字签名的完整性平台。

### Added

- **内容寻址存储**（`src/store`）：类 Git object store，SHA-256 去重，含 `put`/`get`/`has`/`deduplicate`/`reconstruct` 与完整性校验。
- **审计日志**（`src/audit`）：哈希链串联的追加式操作记录，`append`/`verify_chain`/`to_json`，可选 Ed25519 签名（`sign_last`/`verify_signatures`）。
- **Ed25519 数字签名**（`src/crypto`）：纯 MoonBit 实现，从 GF(2^255-19) 有限域（16-limb TweetNaCl 风格）→ Curve25519 扩展坐标点运算（HWCD08）→ RFC 8032 签名/验签，约 800 行，零外部密码学依赖。
- **审计日志 + 签名集成**：审计记录可选 Ed25519 签名验证。

### Changed

- 仓库由 `wenlittle` 改名为 `starlittle`，所有材料统一归属。
- 公共 API 冻结至 v2（见 `docs/ARCHITECTURE.md`）。

## [0.2.0] - 2026-06-18

功能扩展：从"只能验"扩展为"能建能验"，并补齐多算法与性能优化。

### Added

- **证据包创建**（`src/create`）：`create_manifest` API + CLI `create` 命令，从文件构建证据包。
- **HMAC-SHA256**（RFC 2104）：基于已有 SHA-256 实现消息认证码，为清单签名和认证元数据提供基础。
- **SHA-512 摘要**：多算法支持，展示可扩展设计。
- **增量验证**：摘要缓存，跳过未改动文件，大幅提速。
- **批量 CLI 模式**：`verify dir1 dir2 dir3` 一次验证多个包，汇总通过/失败数。

## [0.1.0] - 2026-06-11

MVP：可信证据包验证核心，三后端全绿，可发布 Mooncakes。

### Added

- **六个纯核心包**（零 IO）：`canonjson`（RFC 8785 规范化 JSON）、`digest`（纯 MoonBit SHA-256，NIST 向量全过）、`merkle`（RFC 6962 风格域分离树 + 包含性证明）、`model`（manifest / 版本链模型，路径穿越在解析期拒绝）、`verify`（七步验证流水线）、`diag`（结构化诊断 + explain）。
- **CLI 工具**（`src/cmd/main`）：`verify` / `explain` 命令，冻结退出码 0/1/2，冻结错误码 E1xxx–E5xxx / W1xxx。
- **浏览器端验证 Demo**（`src/api` + `demo/web/`）：同一核心编译为 ESM 模块，纯客户端验证无需上传。
- **三后端支持**：native / wasm-gc / js 全部通过构建和测试，GitHub Actions CI 三后端矩阵。
- **测试体系**：篡改矩阵 fixtures、独立 Node 参考实现交叉验证 golden 数据、property test、benchmark。
- **双语 README** 与用户指南、证据包规范、架构文档、决策/结果双日志。

[0.3.1]: https://github.com/starlittle/MoonEvidence/releases/tag/v0.3.1
[0.3.0]: https://github.com/starlittle/MoonEvidence/releases/tag/v0.3.0
[0.2.0]: https://github.com/starlittle/MoonEvidence/releases/tag/v0.2.0
[0.1.0]: https://github.com/starlittle/MoonEvidence/releases/tag/v0.1.0
