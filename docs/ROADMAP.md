# 开发路线图

## 第一阶段：MVP 开发（已完成）

### 第 1 周：骨架与验证核心

- 冻结最小证据包规范
- 验证 MoonBit 工具链安装
- 生成/验证模块和包配置文件
- 实现 `canonjson` MVP（RFC 8785 规范化 JSON）
- 实现 `digest` 封装和 SHA-256 集成
- 添加首组 valid 和 tampered 测试夹具
- 本地 `moon check` 和 `moon test` 通过后搭建 CI

### 第 2 周：清单与 Merkle 树

- 实现证据清单（manifest）模型和验证
- 实现 Merkle 根计算和证明验证（RFC 6962）
- 添加缺失文件、摘要不匹配、无效证明等篡改用例
- 添加结构化诊断输出

### 第 3 周：版本链与 CLI

- 实现线性版本链验证
- 实现 `verify` 和 `explain` CLI 命令
- 添加黑盒 CLI 回归测试夹具
- 编写面向用户的 README 示例

### 第 4 周：收尾打磨

- 添加 Canonical JSON 和 Merkle 证明的属性测试
- 添加性能基准测试（criterion 风格）
- 添加浏览器端验证 Demo（JS/Wasm 适配器）
- 发布 Mooncakes 包 + 准备比赛材料

## 第二阶段：功能扩展（2026-06-18 — 2026-07-12）

按性价比排序，服务 OSC2026 竞赛验收。

### 高优先级（必做）

- [x] **证据包创建**：`create_manifest` 纯 API + CLI `pack`/`seal` 完整目录创建 + legacy `create`，从"只能验"变成"能建能验"
- [x] **HMAC-SHA256**（约 300 行）：基于已有 SHA-256 实现消息认证码。为清单签名和认证元数据提供基础

### 中优先级（有时间就做）

- [x] **SHA-512 摘要**（约 500 行）：多算法支持，展示可扩展设计
- [x] **增量验证**（约 600 行）：只验证变更文件，跳过未改动部分
- [x] **批量 CLI 模式**：`verify dir1 dir2 dir3` 一次验证多个包，汇总通过/失败数

### 低优先级（锦上添花）

- [x] **内存去重 Map**（约 250 行）：SHA-256 键去重，含完整性验证和文件重建
- [x] **开发报告**：`docs/report/DEVELOPMENT_REPORT.md`（单一权威，合并功能清单/架构/密码学/测试/AI 协作/工程实践）
- [x] **可选演示视频资产**：Playwright 自动交互录制，H.264 1280x720 交付编码已验证；本地留存，不作为基础验收必交项
- [ ] **moondoc 完整性**：所有公开 API 补全文档注释

## 第三阶段：进阶探索（已完成核心功能）

### 已完成

- [x] **授权快照 / 审计日志**（287 行）：哈希链串联的追加式审计日志
  - `src/audit/audit_log.mbt` — 审计记录模型 + 哈希链验证 + JSON 序列化
  - 10 个测试（含 Ed25519 签名集成测试）
- [x] **Ed25519 数字签名**（约 800 行）：纯 MoonBit 实现（生态内已有 hustcer/ed25519 等同类实现）
  - `src/crypto/field25519.mbt` — GF(2^255-19) 有限域算术（16-limb TweetNaCl 风格）
  - `src/crypto/point25519.mbt` — 扩展坐标点运算（HWCD08 加法/倍点）
  - `src/crypto/ed25519.mbt` — RFC 8032 签名/验签 API + 点解码 + 标量模 l 算术
  - 18 个测试（字段算术 6 + 点运算 7 + 签名 5）
- [x] **审计日志 + Ed25519 集成**：审计记录可选 Ed25519 签名
  - `AuditLog::sign_last(sk)` / `AuditLog::verify_signatures(pk)`

## 第四阶段：Fabric 摘要锚定（2026-07-11 已完成）

- [x] CLI 机器合同：`pack` / `inspect` 版本化 JSON 与外部摘要 E2004 回灌
- [x] Go Chaincode：不可变 `CreateAnchor` / `ReadAnchor` / `AnchorExists`
- [x] TypeScript Gateway：TLS profile、commit status、顺序重复/MVCC 归一化、`anchor-pack` / `verify-anchor`
- [x] required CI：Chaincode vet/race/coverage + Gateway check/build/test
- [x] Fabric v3.1.4 双组织真实 E2E：block 6 `VALID`、双查询、重复提交、E2003/E2004 负向证据

### 当前统计

- MoonBit 测试：**351 个声明**（347 可执行 + 4 benchmark wrapper），三后端全绿
- CLI：PowerShell / bash 各 **62/62**
- Fabric：Chaincode 82.1% 语句覆盖；Gateway **19/19**；真实 E2E 已留存
- MoonBit 代码量：**14571** 有效行（实现 6453 + 测试 8118）

### 未来方向

> 以下均为尚未开始的真实待办（已完成项不再重复列出）。

- [ ] 其他账本适配器（沿用同一 digest-only 协议，不复制证据语义）
- [ ] Fabric 生产身份与治理：CA 动态 enrollment、外部密钥管理、长期 Gateway 服务
- [ ] 完整 in-toto/SLSA 兼容
- [ ] 版本 DAG（当前仅支持线性版本链）
- [ ] moondoc 完整性：所有公开 API 补全文档注释
