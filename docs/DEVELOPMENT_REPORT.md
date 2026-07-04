# MoonEvidence 开发报告

> **归档说明**：此为早期功能清单式版本，数字已同步到实测值（76 提交 / 6891 行 / 219 测试 / 12 包）。竞赛权威验收报告见 `docs/report/DEVELOPMENT_REPORT.md`（含 AI 协作实践、标准兼容证据与逐条验收自查）。

## 1. 项目概述

MoonEvidence 是一个纯 MoonBit 实现的可信证据包验证库和 CLI 工具，服务于 OSC2026 MoonBit 开源竞赛。

**核心定位**：链无关验证核心——不是区块链框架或智能合约平台，而是在区块链存证前、数据集归档、数字版权打包、AI 输出审计等场景中复用的通用验证引擎。

**技术亮点**：
- 纯 MoonBit 实现，零外部依赖
- 三后端支持（native / wasm-gc / js）
- 核心库零 IO 依赖，适配器注入字节
- 含完整 Ed25519 数字签名（纯 MoonBit 椭圆曲线密码学）

## 2. 功能清单

### 第一阶段：MVP（已完成）

| 功能 | 说明 |
| --- | --- |
| Canonical JSON | RFC 8785 规范化序列化 |
| SHA-256 | 纯 MoonBit 实现，NIST 向量验证 |
| Merkle 树 | RFC 6962 风格，根计算+证明验证 |
| 证据清单模型 | 带验证的 manifest 解析 |
| 版本链验证 | 时间线性+哈希链完整性 |
| 7 步验证流水线 | 解析到诊断的完整管线 |
| CLI 工具 | verify / explain / create 命令 |
| 浏览器端验证 | ESM 模块，纯客户端验证 |

### 第二阶段：功能扩展（已完成）

| 功能 | 说明 |
| --- | --- |
| 证据包创建 | create_manifest API + CLI create |
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

## 3. 架构设计

```
src/
  canonjson/    RFC 8785 规范化 JSON
  digest/       SHA-256 / SHA-512 / HMAC
  merkle/       Merkle 树 (RFC 6962)
  model/        证据清单模型
  verify/       7 步验证流水线
  diag/         诊断输出 + explain
  create/       证据包创建
  audit/        审计日志 + Ed25519 集成
  crypto/       Ed25519 (field → point → sign)
  store/        内容寻址存储
  api/          浏览器 ESM 适配器
  cmd/main/     CLI 适配器
```

**关键设计决策**：
- **纯库与适配器分离**：核心包（canonjson→digest→merkle→model→verify→diag）零 IO 依赖，接受 `Map[String, Bytes]` 输入
- **冻结退出码**：CLI 退出码 0/1/2 不变，便于 CI 集成
- **冻结错误码**：E1xxx-E5xxx / W1xxx 诊断码，机器可读
- **三后端兼容**：同一代码编译到 native / wasm-gc / js

## 4. 密码学实现细节

### Ed25519 (RFC 8032)

从零实现的椭圆曲线数字签名，不依赖任何外部密码学库：

1. **GF(2^255-19) 有限域**：16 × 16-bit limbs（TweetNaCl 方法），所有中间值安全在 UInt64 内
2. **扩展坐标点运算**：HWCD08 统一加法 + 专用倍点，避免分支
3. **标量乘法**：MSB-first double-and-add
4. **签名流程**：SHA-512 → 私钥 clamp → 确定性 nonce → R=rB → S=(r+kA)mod l
5. **验证流程**：解码点 → SHA-512 → S·B == R + k·A

## 5. 测试与质量

| 指标 | 数值 |
| --- | --- |
| 单元测试 | 219 |
| 黑盒 CLI 测试 | 22 |
| 属性测试 | 有（canonjson / merkle） |
| CI 三后端矩阵 | native / wasm-gc / js |
| 性能基准 | SHA-256 ~58 MiB/s, verify ~26 µs/file |

### 测试覆盖分布

| 包 | 测试数 |
| --- | --- |
| crypto (field + point + ed25519) | 18 |
| audit (含签名集成) | 10 |
| store (对象存储) | 10 |
| digest (SHA-256/512 + HMAC) | ~40 |
| canonjson | ~30 |
| merkle | ~20 |
| model + verify + diag | ~50 |
| 其他 | ~37 |

## 6. 工程实践

- **Git 工作流**：有意义的 commit message，feature 粒度提交
- **CI/CD**：GitHub Actions 三后端构建 + 黑盒测试 + 浏览器冒烟测试
- **代码规模**：6891 有效 MoonBit 行（实现 3590 + 测试 3301，满足 4-10k 要求）
- **双仓库同步**：GitHub + Gitlink
- **文档齐全**：README（中英双语）/ 架构文档 / 用户指南 / 证据包规范 / 环境搭建 / 代码规范 / 路线图

## 7. 项目价值

MoonBit 生态当前缺少数据完整性验证基础设施。MoonEvidence 填补了这一空白：

1. **首个纯 MoonBit Ed25519 实现**：从有限域到签名验签，约 800 行
2. **可发布的 Mooncakes 包**：核心验证逻辑可作为独立库复用
3. **跨平台演示**：同一代码在 CLI、CI、浏览器三种环境运行
4. **安全设计**：路径遍历防护、冻结错误码、确定性输出
