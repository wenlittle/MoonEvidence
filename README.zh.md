# MoonEvidence

[![CI](https://github.com/starlittle/MoonEvidence/actions/workflows/ci.yml/badge.svg)](https://github.com/starlittle/MoonEvidence/actions/workflows/ci.yml)

[English](README.md) | 中文

MoonEvidence 是一个用 MoonBit 编写的**可信证据包验证库与 CLI**：验证一组文件、元数据、Merkle 证明和版本记录是否完整、未被篡改。

## 定位

MoonEvidence **不是**区块链应用，也不是智能合约框架。它是**链无关**的验证核心，适用于上链存证之前、数据集归档、数字版权打包、AI 产物审计、科研资料发布等任何需要"可复核完整性"的场景。

- **确定性**：规范化 JSON（RFC 8785）保证同一份数据在任何机器上得到同一个摘要。
- **可解释**：每个失败映射到冻结的错误码（`E1xxx`–`E5xxx`、`W1xxx`），`explain` 输出人类可读的逐条诊断。
- **可移植**：纯验证核心零 IO，native / wasm-gc / js 三后端编译，同一套语义跑在 CLI 和浏览器里。

## 30 秒上手

```powershell
# 构建 CLI（js 产物用 node 运行；有 C 编译器的机器可用 native）
moon build --target js
$cli = "_build/js/debug/build/src/cmd/main/main.js"

# 验证内置示例包：一个完好、一个被篡改
node $cli verify examples/valid-pack
node $cli explain examples/tampered-pack

# 创建自己的证据包
node $cli create examples/valid-pack/files my-pack
node $cli verify my-pack
```

退出码冻结：`0` 验证通过，`1` 验证失败，`2` 用法或 IO 错误。

`explain` 对篡改包的输出（与浏览器 demo 逐字节一致）：

```text
verification FAILED
  [E2003] files/a.txt: digest mismatch, expected sha256:a948904f.. got sha256:7509e5bd..
checked 2 files, 1 passed; merkle root verified; 1 error, 0 warnings
```

## 在浏览器试用

同一个纯核心编译为自包含 esm bundle（`src/api`，导出字符串进/字符串出的 `verify_evidence`），证据包验证完全在浏览器本地完成——文件不上传：

```powershell
moon build --target js
python -m http.server 8765   # 任何静态服务器均可，从仓库根目录启动
# 打开 http://localhost:8765/demo/web/
```

页面中选择 `examples/valid-pack` 或 `examples/tampered-pack` 目录，或直接粘贴 manifest JSON 做结构校验：

![浏览器 demo 验证被篡改的 manifest](docs/images/demo-web.png)

## 架构

```mermaid
graph TD
  subgraph adapters["适配层（唯一允许 IO 的地方）"]
    CLI["src/cmd/main<br/>CLI：verify / explain / create"]
    API["src/api<br/>浏览器 esm 适配器"]
    CREATE["src/create<br/>证据包创建"]
    AUDIT["src/audit<br/>审计日志 + 签名"]
  end
  subgraph core["验证核心（零 IO · 三后端可移植）"]
    VERIFY["verify<br/>七步验证管线 + 版本链"]
    MODEL["model<br/>manifest / 版本链模型"]
    DIAG["diag<br/>结构化诊断 · explain"]
  end
  subgraph foundation["基础能力层"]
    CANON["canonjson<br/>RFC 8785 规范化"]
    DIGEST["digest<br/>SHA-256 / SHA-512 / HMAC"]
    MERKLE["merkle<br/>RFC 6962 Merkle 树"]
    CRYPTO["crypto<br/>Ed25519 数字签名"]
    STORE["store<br/>内容寻址存储"]
  end
  CLI --> VERIFY
  CLI --> CREATE
  API --> VERIFY
  CREATE --> DIGEST
  CREATE --> MERKLE
  CREATE --> CANON
  AUDIT --> CRYPTO
  AUDIT --> DIGEST
  VERIFY --> MODEL
  VERIFY --> DIAG
  VERIFY --> CANON
  VERIFY --> MERKLE
  VERIFY --> DIGEST
  MODEL --> DIGEST
  MERKLE --> DIGEST
  DIAG --> CANON
```

文件字节由适配层注入（`Map[String, Bytes]`），核心只做纯计算——这也是三后端测试矩阵能钉死跨端语义一致的原因。

## API 速览

### 验证核心

| 包 | 入口 | 作用 |
| --- | --- | --- |
| `verify` | `verify_manifest(manifest_json, files, expected_manifest_digest?)` | 七步管线：解析 → 规范化 → manifest 摘要 → 逐文件摘要 → 未登记文件 → Merkle 根，返回完备（非 fail-fast）报告 |
| `verify` | `verify_version_chain(nodes)` | 版本链线性性：唯一根、父引用可达、无环、无分叉 |
| `model` | `Manifest::parse(input)` | 解析并校验 manifest（路径穿越在解析期拒绝） |
| `model` | `parse_version_chain(input)` | 解析 `versions/version_chain.json` |
| `canonjson` | `canonicalize(input)` | RFC 8785 规范化（键序、转义、ECMAScript 最短数字） |
| `digest` | `sha256_hex(data)` / `sha512_hex(data)` / `hmac_sha256(...)` | 纯 MoonBit SHA-256 / SHA-512 / HMAC，`<algo>:<hex>` 文本形式 |
| `merkle` | `compute_root` / `compute_proof` / `verify_inclusion` | 域分离的叶/内节点哈希、根计算、包含性证明 |
| `diag` | `explain(report)` / `to_json(report)` | 人类可读报告 / 规范 JSON 报告（字节稳定） |

### 创建与扩展

| 包 | 入口 | 作用 |
| --- | --- | --- |
| `create` | `create_manifest(files, options)` | 从文件构建证据包，生成 manifest.json |
| `store` | `ObjectStore` | 内容寻址存储，类 Git object store，SHA-256 去重 |
| `audit` | `AuditLog` | 哈希链串联的追加式审计日志，支持 Ed25519 签名 |
| `crypto` | `Ed25519::sign` / `Ed25519::verify` | 纯 MoonBit Ed25519 数字签名（RFC 8032） |

### 适配层

| 包 | 入口 | 作用 |
| --- | --- | --- |
| `cmd/main` | CLI：`verify` / `explain` / `create` | 命令行工具，冻结退出码 0/1/2 |
| `api` | `verify_evidence(request_json)` | 浏览器边界：JSON 字符串进出，零 MoonBit 类型跨界 |

## 错误码表

| 码段 | 含义 |
| --- | --- |
| `E1001` | manifest JSON 无法解析 |
| `E1002` | 必填字段缺失、为空或非法（含路径穿越拒绝） |
| `E1003` | schema 版本不支持（要求 `moon-evidence/v0`） |
| `E1004` | 规范化失败（含无最短形式的数字） |
| `E2001` | 哈希算法不支持 |
| `E2002` | 摘要字符串格式非法（要求 `<algo>:<小写hex>`） |
| `E2003` | 文件内容摘要与 manifest 条目不符 |
| `E2004` | manifest 规范摘要与外部记录值不符 |
| `E3001` | files 非空但 Merkle 根缺失（或根存在但 files 为空） |
| `E3002` | 证明格式非法 |
| `E3003` | Merkle 根/证明复算不匹配 |
| `E4001` | 版本链为空 |
| `E4002` | 父版本引用断裂 |
| `E4003` | 版本链成环或存在不可达节点 |
| `E4004` | 重复 id / 多根 / 分叉（链必须线性） |
| `E5001` | 路径不存在（适配层） |
| `E5002` | 文件读取失败（适配层） |
| `W1001` | 包内存在未登记文件（警告，不导致失败） |

## 性能

js 后端实测（moon 0.1.20260529 / Node v22.22.0 / Windows，确定性负载，`moon bench`）：

| 基准 | 均值 ± σ | 折算 |
| --- | --- | --- |
| SHA-256，1 MiB | 17.10 ms ± 0.21 ms | ~58 MiB/s |
| SHA-256，64 KiB | 1.12 ms ± 0.02 ms | ~56 MiB/s |
| 全量验证，1k 文件 manifest | 25.65 ms ± 0.78 ms | ~26 µs/文件 |
| 全量验证，10k 文件 manifest | 283.52 ms ± 6.18 ms | ~28 µs/文件 |

耗时随文件数近线性增长（10 倍文件 → 11.05 倍耗时，残差为 Merkle 树对数深度项）。方法学与原始输出见 `docs/records/RESULTS_LOG.md`。

## 功能总览

### 核心验证
- Canonical JSON（RFC 8785）规范化序列化
- SHA-256 / SHA-512 纯 MoonBit 实现，NIST 向量全过
- HMAC-SHA256 消息认证码（RFC 2104）
- Merkle 树（RFC 6962 风格）：根计算 + 证明验证
- 证据清单模型：路径穿越在解析期即拒绝
- 线性版本链验证：唯一根、无环、不分叉
- 7 步验证流水线：解析 → 规范化 → 摘要 → Merkle → 版本链 → 诊断

### 证据包创建与扩展
- **证据包创建**：`create` 命令 + `create_manifest` API，从文件构建证据包
- **增量验证**：摘要缓存，跳过未改动文件，大幅提速
- **批量 CLI 模式**：一次验证多个包，汇总通过/失败数
- **内容寻址存储**：类 Git object store，SHA-256 去重，支持完整性验证和文件重建

### 进阶能力
- **审计日志**：哈希链串联的追加式操作记录
- **Ed25519 数字签名**：纯 MoonBit 实现，从有限域到签名验签全栈（约 800 行）
- **审计日志签名集成**：可选 Ed25519 签名验证

## 测试与质量

- **265 个单元测试**在 native / wasm-gc / js 三后端全绿；NIST SHA-256/512 向量、RFC 8785 Appendix B 向量全过
- **41 用例 CLI 黑盒套件**：12 个示例包用例 + 10 包篡改矩阵 + 19 错误码夹具（独立 Node 参考实现生成，CI 防腐化校验）
- **变异验证过的 property 测试**：规范化幂等、Merkle 证明可靠性
- **CI 三后端矩阵**：native / wasm-gc / js 构建与测试，js 产物浏览器适配器烟测

```powershell
moon check
moon test --target wasm-gc,js
powershell -ExecutionPolicy Bypass -File tools/cli-test.ps1 -Target js
node tools/smoke-api.mjs
```

## 项目文档

### 入门
- [用户指南（三个真实场景）](docs/GUIDE.md)
- [环境搭建](docs/ENVIRONMENT.md)
- [演示脚本（5分钟展示）](docs/DEMO_SCRIPT.md)

### 深入了解
- [架构说明](docs/ARCHITECTURE.md)
- [证据包规范](docs/spec/EVIDENCE_PACK_SPEC.md)
- [开发路线图](docs/ROADMAP.md)
- [开发报告](docs/report/DEVELOPMENT_REPORT.md)

### 工程与质量
- [项目索引](docs/PROJECT_INDEX.md)
- [代码规范](docs/CODE_GUIDELINES.md)
- [结果记录](docs/records/RESULTS_LOG.md)
- [验收自查清单](docs/records/ACCEPTANCE_CHECKLIST.md)
- [决策日志](docs/records/DECISION_LOG.md)

## 许可证

Apache-2.0
