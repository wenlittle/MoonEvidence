# Changelog

本文件记录 MoonEvidence 的版本演进。版本号遵循语义化版本（SemVer）。

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

[0.3.0]: https://github.com/starlittle/MoonEvidence/releases/tag/v0.3.0
[0.2.0]: https://github.com/starlittle/MoonEvidence/releases/tag/v0.2.0
[0.1.0]: https://github.com/starlittle/MoonEvidence/releases/tag/v0.1.0
