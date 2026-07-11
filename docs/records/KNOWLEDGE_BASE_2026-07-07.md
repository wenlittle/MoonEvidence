# MoonEvidence 项目知识库（历史快照）

> 快照日期：2026-07-07。本文保留当时的 API、测试盲点和阶段记录，不再作为当前事实来源。
>
> 当前接手入口：[项目知识库](../KNOWLEDGE_BASE.md) · [项目索引](../PROJECT_INDEX.md) · [结果记录](RESULTS_LOG.md)

> **用途**：新会话快速了解项目全貌的表层文档。涵盖架构、API、数据流、错误码、常量、测试覆盖、CI、工具链、安全治理、测试盲点与改进建议。
> **最后更新**：2026-07-11
> **维护规则**：每次重大变更后更新对应章节，在文末「更新日志」记录。

---

## 0. 快速导航

| 想了解 | 跳转章节 |
|---|---|
| 项目是什么 | [§1 项目概览](#1-项目概览) |
| 代码怎么分层 | [§2 包架构与依赖图](#2-包架构与依赖图) |
| 每个包有哪些函数 | [§3 完整公开API清单](#3-完整公开api清单) |
| 创建→验证怎么走 | [§4 核心数据流](#4-核心数据流) |
| 错误码有哪些 | [§5 错误码冻结契约](#5-错误码冻结契约) |
| 有哪些常量 | [§6 常量与配置](#6-常量与配置) |
| CLI怎么用 | [§7 CLI命令与JS API](#7-cli命令与js-api) |
| 测试覆盖怎么样 | [§8 测试覆盖全景](#8-测试覆盖全景) |
| 哪里没测到 | [§9 测试盲点清单](#9-测试盲点清单) |
| CI怎么跑 | [§10 CI流水线](#10-ci流水线) |
| 有哪些工具脚本 | [§11 工具脚本清单](#11-工具脚本清单) |
| 变异测试怎么做的 | [§12 变异测试](#12-变异测试) |
| 首批分支覆盖图在哪 | [docs/BRANCH_COVERAGE.md](../BRANCH_COVERAGE.md) |
| 安全措施和残留风险 | [§13 安全治理](#13-安全治理) |
| 三后端有什么区别 | [§14 三后端差异](#14-三后端差异) |
| 怎么系统化深度测试 | [§15 系统化深度测试计划](#15-系统化深度测试计划)（门禁/停手规则见 [TEST_GOVERNANCE.md](../TEST_GOVERNANCE.md)，详细 backlog 见 [TEST_PLAN.md](../TEST_PLAN.md)） |
| 关键文件在哪 | [§16 关键文件索引](#16-关键文件索引) |

---

## 1. 项目概览

| 属性 | 值 |
|---|---|
| 模块名 | `starlittle/MoonEvidence` |
| 版本 | `0.5.0` |
| 许可 | Apache-2.0 |
| 语言 | MoonBit 主体；Go/TypeScript 仅用于可选 Fabric 协议适配器 |
| Mooncakes 唯一外部依赖 | `moonbitlang/x@0.4.45` |
| 定位 | 链无关可信证据包创建/验证核心 + CLI/浏览器 + 可选 Fabric 摘要锚定 |
| 适用场景 | 区块链公证前完整性验证、数据集归档、数字版权打包、AI 输出审计、科研产物发布 |
| 代码规模 | 14571 有效 MoonBit 行（实现 6453 + 测试 8118） |
| 测试 | 351 个测试声明（347 个可执行测试 + 4 个基准 wrapper）+ 62 例黑盒 CLI + Fabric adapter/E2E |
| CI | MoonBit required job + Fabric adapter required job + 非阻塞 benchmark，保留独立 oracle/fuzz/property/differential/mutation 门禁 |
| 核心问题 | 一组文件、元数据、Merkle 证明与版本记录，是否完整、未被篡改？ |

### 设计原则

1. **纯核心 + IO 适配器边界**：核心包（canonjson/digest/crypto/merkle/model/store/diag/verify/create/audit）零 IO，文件字节由 `Map[String, Bytes]` 注入。相同语义在 CLI、CI 三后端、浏览器中运行。
2. **跨后端确定性**：SHA-256/SHA-512/Ed25519 全部纯 MoonBit 实现，无 FFI，native/wasm-gc/js 产出一致。
3. **规范 JSON 稳定性**：RFC 8785 全套实现，manifest 字节 digest 稳定可复现，跨 Node/Python 实现一致。
4. **穷举式验证**：verify_manifest 一次运行列出所有 finding（非 fail-fast），用户一次修复所有问题。
5. **冻结契约**：错误码（E1xxx-E5xxx/W1xxx）、退出码（0/1/2）、schema 版本（`moon-evidence/v0`）均为冻结公开契约。
6. **create→verify 往返不变量**：create 组装什么，verify 拆解校验什么，`create → verify = OK` 是首要正确性不变量。
7. **链上最小披露**：Fabric 只接收 MoonBit 输出的规范 manifest 摘要；文件、路径、逐文件摘要、Merkle 叶子、完整 manifest 和凭据不上链。

---

## 2. 包架构与依赖图

### 2.1 四层架构（L0-L3）

```
L3 Adapters（适配层，唯一含 IO）
├── api          ──► verify, diag, digest, model, merkle, canonjson, create, audit, crypto
└── cmd/main     ──► model, verify, diag, create, digest, canonjson (+ moonbitlang/x/fs, sys)

External Adapters（仓库级可选集成，排除在 Mooncakes 包外）
├── integrations/fabric/gateway      ──► CLI machine contract + Fabric Gateway
└── integrations/fabric/chaincode-go ──► canonical manifest digest only

L4 Measurement（实验工具，不作为产品 API）
└── timing       ──► crypto (+ native C timer stub)

L2 Verification（验证层，零 IO）
├── verify       ──► model, diag, canonjson, digest, merkle
├── create       ──► canonjson, digest, merkle, model
└── audit        ──► digest, canonjson, crypto

L1 Core（核心层）
├── merkle       ──► digest
├── model        ──► digest
├── store        ──► digest, canonjson
└── diag         ──► canonjson

L0 Foundation（基础层，无内部依赖）
├── canonjson    ──► (core/json, core/double, core/string)
├── digest       ──► (core/debug)
└── crypto       ──► digest
```

### 2.2 包间依赖明细

| 包 | 内部依赖 | 外部依赖 |
|---|---|---|
| `canonjson` | 无 | core/json, core/double, core/string |
| `digest` | 无 | core/debug |
| `crypto` | digest | 无 |
| `merkle` | digest | core/debug |
| `model` | digest | core/json, core/double, core/debug |
| `store` | digest, canonjson | core/json |
| `diag` | canonjson | core/debug |
| `verify` | model, diag, canonjson, digest, merkle | core/debug (create 仅 wbtest) |
| `create` | canonjson, digest, merkle, model | core/json (verify 仅 wbtest) |
| `audit` | digest, canonjson, crypto | core/debug, core/json |
| `api` | verify, diag, digest, model, merkle, canonjson, create, audit, crypto | core/json, core/debug |
| `cmd/main` | model, verify, diag, create, digest, canonjson | core/env, core/json, x/fs, x/sys |
| `timing` | crypto | core/env, x/sys, native C timer stub |

### 2.3 各包职责

| 包 | 层级 | 职责 |
|---|---|---|
| `canonjson` | L0 | RFC 8785 规范化 JSON（JCS 转义、UTF-16 code-unit 键序、ECMAScript 最短形式数字） |
| `digest` | L0 | 哈希算法抽象（SHA-256/SHA-512/HMAC-SHA256）、hex 编解码、Digest 类型 |
| `crypto` | L0 | Ed25519 数字签名（GF(2^255-19) 有限域 → Curve25519 点运算 → RFC 8032 签名/验签） |
| `merkle` | L1 | RFC 6962 风格 Merkle 树（域分离 0x00/0x01、奇数节点提升防 CVE-2012-2459） |
| `model` | L1 | 证据包数据模型（Manifest、FileEntry、VersionNode）+ 错误码 + 路径校验 |
| `store` | L1 | 内存内容寻址存储（SHA-256 去重 + 完整性验证 + 重建） |
| `diag` | L1 | 结构化诊断（Finding/VerifyReport/CheckStats）+ explain/to_json 输出 |
| `verify` | L2 | 验证编排（7步管线 + 版本链验证 + 增量验证） |
| `create` | L2 | 证据包创建（路径排序 → digest → Merkle根 → 规范化 manifest） |
| `audit` | L2 | 哈希链审计日志（append-only + Ed25519 签名覆盖 canonical JSON） |
| `api` | L3 | 浏览器/JS 适配层（字符串进字符串出，12个ESM导出函数） |
| `cmd/main` | L3 | JS/native CLI 入口（pack/inspect/verify/explain/create + 版本化机器 JSON） |
| `timing` | L4 | native-only Ed25519 timing 实验入口（verify/sign-message/sign-secret Welch t），不作为产品 API |

---

## 3. 完整公开API清单

### 3.1 canonjson（RFC 8785 规范化 JSON）

```moonbit
pub(all) suberror CanonError {
  ParseFailed(String)
  UnsupportedNumber(String)
} derive(Eq)

pub fn canonicalize(String) -> String raise CanonError
pub fn canonicalize_or_none(String) -> String?
pub fn compare_code_units(String, String) -> Int
pub fn same_canonical_payload(String, String) -> Bool
pub impl Show for CanonError
```

### 3.2 digest（哈希算法抽象）

```moonbit
pub(all) enum HashAlgorithm { Sha256; Sha512 } derive(Eq, @debug.Debug)
pub(all) struct Digest { algorithm : HashAlgorithm; hex : String } derive(Eq, @debug.Debug)
pub struct Sha256Ctx { ... }
pub struct Sha512Ctx { ... }

// 函数
pub fn bytes_to_lower_hex(Bytes) -> String
pub fn hex_to_bytes(String) -> Bytes?
pub fn hmac_sha256(Bytes, Bytes) -> Bytes
pub fn hmac_sha256_hex(Bytes, Bytes) -> String
pub fn is_hex(String) -> Bool
pub fn is_supported_algorithm(String) -> Bool
pub fn normalize_algorithm(String) -> HashAlgorithm?
pub fn normalize_hex(String) -> String?
pub fn parse_digest(String) -> Digest?
pub fn same_digest(String, String) -> Bool
pub fn sha256(Bytes) -> Bytes
pub fn sha256_hex(Bytes) -> String
pub fn sha512_hex(Bytes) -> String
pub fn string_to_utf8_bytes(String) -> Bytes

// 方法
pub fn HashAlgorithm::label(Self) -> String
pub fn Digest::of_bytes(HashAlgorithm, Bytes) -> Self
pub fn Digest::to_string(Self) -> String
pub fn Sha256Ctx::new() -> Self
pub fn Sha256Ctx::update(Self, Bytes) -> Unit
pub fn Sha256Ctx::finalize(Self) -> Bytes
pub fn Sha512Ctx::new() -> Self
pub fn Sha512Ctx::update(Self, Bytes) -> Unit
pub fn Sha512Ctx::finalize(Self) -> Bytes
pub impl Show for HashAlgorithm
pub impl Show for Digest
```

### 3.3 crypto（Ed25519 数字签名，纯 MoonBit）

```moonbit
pub struct Fe { limbs : FixedArray[UInt64] }
pub struct Point { x : Fe; y : Fe; z : Fe; t : Fe }

// 顶层函数
pub fn ed25519_public_key(Bytes) -> Bytes        // 32字节seed → 32字节公钥
pub fn ed25519_sign(Bytes, Bytes) -> Bytes        // (seed, message) → 64字节签名
pub fn ed25519_verify(Bytes, Bytes, Bytes) -> Bool // (pk, message, sig) → bool
pub fn point_decode(Bytes) -> Point?              // 32字节编码 → Point?

// Fe 方法
pub fn Fe::add(Self, Self) -> Self
pub fn Fe::eq(Self, Self) -> Bool
pub fn Fe::from_bytes(Bytes) -> Self
pub fn Fe::from_small(UInt64) -> Self
pub fn Fe::invert(Self) -> Self
pub fn Fe::mul(Self, Self) -> Self
pub fn Fe::one() -> Self
pub fn Fe::pow2(Self, Int) -> Self
pub fn Fe::square(Self) -> Self
pub fn Fe::sub(Self, Self) -> Self
pub fn Fe::to_bytes(Self) -> Bytes
pub fn Fe::zero() -> Self

// Point 方法
pub fn Point::add(Self, Self) -> Self
pub fn Point::base_point() -> Self
pub fn Point::double(Self) -> Self
pub fn Point::encode(Self) -> Bytes
pub fn Point::eq(Self, Self) -> Bool
pub fn Point::from_affine(Fe, Fe) -> Self
pub fn Point::identity() -> Self
pub fn Point::is_identity(Self) -> Bool
pub fn Point::scalar_mul(Self, Bytes) -> Self
```

### 3.4 merkle（RFC 6962 风格 Merkle 树）

```moonbit
pub(all) enum Side { Left; Right } derive(Eq, @debug.Debug)
pub(all) struct MerkleTree { levels : Array[Array[Bytes]] } derive(Eq)
pub(all) struct PathStep { level : Int; node_index : Int } derive(Eq, @debug.Debug)
pub(all) struct ProofStep { sibling : Bytes; side : Side } derive(Eq, @debug.Debug)

// 顶层函数
pub fn compute_proof(Array[Bytes], Int, algorithm? : HashAlgorithm) -> Array[ProofStep]?
pub fn compute_root(Array[Bytes], algorithm? : HashAlgorithm) -> Bytes?
pub fn compute_tree(Array[Bytes], algorithm? : HashAlgorithm) -> MerkleTree?
pub fn leaf_hash(Bytes, algorithm? : HashAlgorithm) -> Bytes
pub fn node_hash(Bytes, Bytes, algorithm? : HashAlgorithm) -> Bytes
pub fn verify_inclusion(Bytes, Array[ProofStep], Bytes, algorithm? : HashAlgorithm) -> Bool

// MerkleTree 方法
pub fn MerkleTree::height(Self) -> Int
pub fn MerkleTree::leaf_count(Self) -> Int
pub fn MerkleTree::leaf_path(Self, Int) -> Array[PathStep]?
pub fn MerkleTree::level(Self, Int) -> Array[Bytes]
pub fn MerkleTree::root(Self) -> Bytes?
```

### 3.5 model（证据包数据模型 + 版本链）

```moonbit
pub(all) suberror ModelError {
  ParseFailed(String)                    // E1001
  MissingField(String)                   // E1002
  InvalidField(String, String)           // E1002
  UnsupportedSchema(String, String)      // E1003
  UnsupportedAlgorithm(String, String)   // E2001
  InvalidDigest(String, String)          // E2002
} derive(Eq, @debug.Debug)

pub(all) struct Subject { id : String; kind : String }
pub(all) struct FileEntry { path : String; size : Int64; digest : @digest.Digest }
pub(all) struct VersionRef { id : String; parent : String? }
pub(all) struct VersionNode { id : String; parent : String? }
pub(all) struct Manifest {
  schema : String
  subject : Subject
  algorithm : @digest.HashAlgorithm
  files : Array[FileEntry]
  merkle_root : @digest.Digest?
  version : VersionRef
}

pub fn parse_version_chain(String) -> Array[VersionNode] raise ModelError
pub fn Manifest::parse(String) -> Self raise ModelError
pub fn ModelError::detail(Self) -> String
pub fn ModelError::error_code(Self) -> String
pub fn ModelError::field_path(Self) -> String
pub fn validate_entry_path(String, String) -> Unit raise ModelError  // 内部 pub
```

### 3.6 diag（结构化诊断）

```moonbit
pub(all) enum Severity { Error; Warning } derive(Eq, @debug.Debug)
pub(all) struct Finding { code : String; severity : Severity; path : String; message : String }
pub(all) struct CheckStats { files_total : Int; files_passed : Int; merkle_checked : Bool }
pub(all) struct VerifyReport { ok : Bool; findings : Array[Finding]; checked : CheckStats }

pub fn explain(VerifyReport) -> String
pub fn to_json(VerifyReport) -> String
pub fn VerifyReport::error_count(Self) -> Int
pub fn VerifyReport::warning_count(Self) -> Int
```

### 3.7 store（内存内容寻址存储 + 去重）

```moonbit
pub struct ObjectStore { objects : Map[String, Bytes] }
pub(all) struct DeduplicateResult {
  index : Map[String, String]
  store : ObjectStore
  total_files : Int
  unique_objects : Int
  bytes_saved : Int64
}

pub fn deduplicate(Map[String, Bytes]) -> DeduplicateResult
pub fn ObjectStore::new() -> Self
pub fn ObjectStore::put(Self, Bytes) -> String        // 返回 sha256:<hex>
pub fn ObjectStore::get(Self, String) -> Bytes?
pub fn ObjectStore::has(Self, String) -> Bool
pub fn ObjectStore::count(Self) -> Int
pub fn ObjectStore::list_hashes(Self) -> Array[String]
pub fn ObjectStore::remove(Self, String) -> Bool
pub fn DeduplicateResult::to_json(Self) -> String
pub fn DeduplicateResult::verify_integrity(Self) -> Bool
pub fn DeduplicateResult::reconstruct(Self) -> Map[String, Bytes]
pub fn DeduplicateResult::reconstruct_strict(Self) -> Result[...]  // .mbti未列出
```

### 3.8 create（证据包创建）

```moonbit
pub(all) struct SubjectInfo { id : String; kind : String }
pub(all) struct CreateOptions {
  subject : SubjectInfo
  algorithm : @digest.HashAlgorithm
  version_id : String
  version_parent : String?
}

pub fn create_manifest(Map[String, Bytes], CreateOptions) -> String
```

### 3.9 audit（哈希链审计日志 + 签名）

```moonbit
pub(all) enum AuditAction { Created; Verified; Sealed; Signed; Shared; Custom(String) }
pub(all) struct AuditEntry {
  timestamp : String; actor : String; action : AuditAction
  subject_id : String; manifest_digest : String?
  prev_hash : String?; hash : String; signature : String?
}
pub struct AuditLog { entries : Array[AuditEntry]; mut last_hash : String? }

pub fn AuditAction::parse(String) -> Self
pub fn AuditAction::to_string(Self) -> String
pub fn AuditEntry::compute_hash(Self) -> String
pub fn AuditEntry::to_json(Self) -> String
pub fn AuditLog::new() -> Self
pub fn AuditLog::append(Self, String, String, AuditAction, String, manifest_digest? : String) -> Unit
pub fn AuditLog::length(Self) -> Int
pub fn AuditLog::sign_last(Self, Bytes) -> Unit
pub fn AuditLog::to_json(Self) -> String
pub fn AuditLog::verify_chain(Self) -> Bool
pub fn AuditLog::verify_signatures(Self, Bytes) -> Bool
// 注：AuditLog::from_json 存在于源码但未在 .mbti 中列出
```

### 3.10 verify（验证编排）

```moonbit
pub(all) struct ChainReport { ok : Bool; ordered_ids : Array[String]; findings : Array[@diag.Finding] }
pub(all) struct IncrementalReport { report : @diag.VerifyReport; files_rehashed : Int; files_skipped : Int }

pub fn verify_chain_text(String, path~ : String) -> Array[@diag.Finding]
pub fn verify_manifest(String, Map[String, Bytes], expected_manifest_digest? : String) -> @diag.VerifyReport
pub fn verify_manifest_incremental(String, Map[String, Bytes], Map[String, String], expected_manifest_digest~ : String?) -> IncrementalReport
pub fn verify_version_chain(Array[@model.VersionNode]) -> ChainReport
```

### 3.11 api（浏览器/JS 适配层）

```moonbit
// .mbti 导出
pub fn compute_merkle_tree(String) -> String
pub fn verify_evidence(String) -> String

// 源码中存在 + JS exports 列出但 .mbti 未列出的 pub fn
pub fn create_evidence_pack(String) -> String
pub fn generate_proof(String) -> String
pub fn verify_proof(String) -> String
pub fn audit_append(String) -> String
pub fn audit_verify(String) -> String
pub fn audit_sign(String) -> String
pub fn ed25519_keypair(String) -> String
pub fn ed25519_sign(String) -> String
pub fn ed25519_verify(String) -> String
```

JS ESM 导出（`moon.pkg` 中 `link.js.exports`）：`digest_compute`, `verify_evidence`, `compute_merkle_tree`, `create_evidence_pack`, `generate_proof`, `verify_proof`, `audit_append`, `audit_verify`, `audit_sign`, `ed25519_keypair`, `ed25519_sign`, `ed25519_verify`

### 3.12 cmd/main（CLI 入口）

无公开 API（main 包）。`fn main` 为入口。平台特定文件：
- `main_native.mbt`（native/llvm）+ `native_stub.c`（stderr FFI）
- `main_js.mbt`（js）
- `main_wasm.mbt`（wasm/wasm-gc）

---

## 4. 核心数据流

### 4.1 创建流程（create_manifest）

```
入口：create_manifest(files : Map[String, Bytes], options : CreateOptions) -> String

1. 元数据校验
   ├── subject.id 非空（abort if empty）
   ├── subject.kind 非空（abort if empty）
   ├── version_id 非空（abort if empty）
   └── version_parent 若存在则非空（abort if empty string）

2. 路径排序
   └── 按 UTF-16 code-unit 顺序排序（RFC 8785 §3.2.3），非 MoonBit 默认 shortlex

3. 逐文件处理
   ├── @model.validate_entry_path 校验路径（防目录穿越/null字节/控制字符/反斜杠/冒号/绝对路径/./..）
   ├── @digest.Digest::of_bytes(algorithm, data) 计算 digest
   ├── 构造 file entry JSON: {path, size, digest}
   └── 对每个 entry 做 canonicalize 得到 leaf payload bytes

4. Merkle 根计算
   └── @merkle.compute_root(leaf_payloads, algorithm) → "algo:hex" 形式

5. 组装 manifest
   └── {schema:"moon-evidence/v0", subject:{id,type}, hash_algorithm, files:[...], merkle_root, version:{id,parent}}

6. 规范化输出
   └── @canonjson.canonicalize(raw_json) 返回 RFC 8785 规范 JSON
```

### 4.2 验证流程（verify_manifest，7步管线）

> 报告为**穷举式**（非 fail-fast），一次列出所有问题。

| 步骤 | 操作 | 错误码 |
|---|---|---|
| Step 1 | 解析 + 校验 manifest 模型（`Manifest::parse`） | E1001/E1002/E1003/E2001/E2002 |
| Step 2 | 规范化 manifest 文档（`canonjson.canonicalize`） | E1004（失败） |
| Step 3 | manifest 规范 digest 对比外部记录值（当 `expected_manifest_digest` 给定） | E2004 |
| Step 4 | 逐文件 digest 校验（`Digest::of_bytes` 对比 `entry.digest`），同时记录已列路径 | E2003（内容未提供/digest 不匹配） |
| Step 5 | 检测 pack 中存在但 manifest 未列出的文件 | W1001（警告） |
| Step 6 | Merkle 根校验：对规范 file entry 重算 leaf payload → `merkle.compute_root` 对比 `merkle_root` | E3001（缺失/空文件[]）/ E3003（不匹配） |
| Step 7 | 聚合：`ok = 无 Error 级 finding`，统计 `files_total/files_passed/merkle_checked` | — |

### 4.3 版本链验证（verify_version_chain）

```
verify_version_chain(nodes : Array[VersionNode]) -> ChainReport

├── 空链 → E4001
├── 重复 id 检测 → E4004（提前返回）
├── 断裂的 parent 引用（parent id 不在节点集中）→ E4002
├── fork 检测（一个 parent 有多个 children）→ E4004
├── 根基数判断：
│   ├── 0 根 = 存在环 → E4003
│   ├── 多根 = 平行头 → E4004
│   └── 1 根 → 从根走到 head
├── ordered_ids.length() < nodes.length() → 残留 detached 环 → E4003
└── 成功：ok=true，ordered_ids 为根到头的有序 id
```

### 4.4 增量验证（verify_manifest_incremental）

> **信任模型**：`previous` 缓存必须来自此前对同一 pack 的成功验证。若缓存被篡改，可导致被修改文件跳过内容哈希。manifest digest 检查（E2004）仍能检测 manifest 篡改，Merkle 根仍能捕获结构性变更，但单文件内容完整性仅与缓存源同等可信。

步骤与 `verify_manifest` 镜像，差异在 Step 4：
- 对每个文件，若 `(path, expected_digest)` 匹配 `previous` 缓存 → `skipped++`，`files_passed++`（跳过 SHA 计算）
- 否则 → `rehashed++`，重算 digest 对比
- **Merkle 根始终全量重算**
- 返回额外统计：`files_rehashed`、`files_skipped`

### 4.5 CLI 适配器数据流（run_verify_single）

```
1. 解析路径：目录 → manifest.json；文件 → 该文件为 manifest，parent 为 pack root
2. 读 manifest（E5002）
3. 解析 manifest → 遍历 files[] 读磁盘字节注入 Map[String, Bytes]（读失败 → E5002）
4. 目录模式：递归收集 files/ 下未列出文件（W1001 来源），深度上限 32、文件上限 10000
5. 纯验证：有 cache_dir → verify_manifest_incremental；否则 verify_manifest
6. 版本链（可选）：读 versions/version_chain.json → verify_chain_text
7. 合并：io_findings + report.findings + chain_findings → 聚合 ok
8. 验证成功后保存增量缓存（cache.json：manifest_digest + path→digest）
9. 输出：--json → diag.to_json；否则 diag.explain + 增量统计
```

### 4.6 Fabric 锚定与回灌数据流

```text
source
  -> MoonBit pack
  -> inspect + verify
  -> canonical manifest_digest
  -> TypeScript Gateway submitAsync
  -> Go CreateAnchor
  -> Fabric endorsement/order/validation
  -> tx ID + block number + status
  -> Org1/Org2 ReadAnchor
  -> MoonBit verify --expected-manifest-digest
```

- TypeScript/Go 不规范化、不哈希、不解释证据文件。
- 链上 key 为 `anchor:<manifest_digest>`，首写不可变，顺序重复不覆盖。
- concurrent duplicate 的 MVCC loser 只有在查询到相同锚点后才归一化。
- 真实 Fabric v3.1.4 双组织记录在 `docs/records/fabric-e2e/2026-07-11/`。

---

## 5. 错误码冻结契约

> 错误码为**冻结契约**（`E1xxx`..`E5xxx`，`W1xxx`），测试与 CLI 均断言于此。

| 错误码 | 严重度 | 来源包 | 含义 |
|---|---|---|---|
| **E1001** | Error | model | 输入非合法 JSON（`ParseFailed`） |
| **E1002** | Error | model | 必填字段缺失/为空，或字段格式错误（`MissingField`/`InvalidField`） |
| **E1003** | Error | model | schema 版本不支持（期望 `moon-evidence/v0`）（`UnsupportedSchema`） |
| **E1004** | Error | verify | manifest 规范化失败（`canonjson.canonicalize` 抛错） |
| **E2001** | Error | model | 哈希算法不支持（`UnsupportedAlgorithm`） |
| **E2002** | Error | model | digest 字符串格式无效（非 `<algo>:<lowercase-hex>`、非规范小写、算法不匹配）（`InvalidDigest`） |
| **E2003** | Error | verify | 文件内容未提供 / digest 不匹配 |
| **E2004** | Error | verify | manifest 规范 digest 与外部记录值不匹配 |
| **E3001** | Error | verify | merkle_root 缺失但 files[] 非空 / merkle_root 存在但 files[] 为空 |
| **E3002** | Error | verify | 证明格式非法（**保留但未实现**，CLI 不提供 proofs/ 消费者） |
| **E3003** | Error | verify | merkle 根不匹配（recorded vs actual） |
| **E4001** | Error | verify | 版本链为空 |
| **E4002** | Error | verify | 断裂的 parent 引用（parent id 未知） |
| **E4003** | Error | verify | 环 / 无根 / 不可达尾部 |
| **E4004** | Error | verify | fork（重复 id / 多根 / 一个 parent 多 children） |
| **E5001** | Error | cmd/main | 路径不存在 |
| **E5002** | Error | cmd/main | 文件读取失败 / 写入失败 |
| **W1001** | Warning | verify | 文件存在于 pack 但未在 manifest 中列出 |

**ModelError 变体映射**：
- `ParseFailed(_) => "E1001"`
- `MissingField(_) => "E1002"`
- `InvalidField(_, _) => "E1002"`
- `UnsupportedSchema(_, _) => "E1003"`
- `UnsupportedAlgorithm(_, _) => "E2001"`
- `InvalidDigest(_, _) => "E2002"`

---

## 6. 常量与配置

### 6.1 CLI 配置（`cmd/main/main.mbt`）

| 常量 | 值 | 说明 |
|---|---|---|
| `CLI_VERSION` | `"0.5.0"` | 与 `moon.mod` 同步，已由 `check-metrics.mjs` CI 门禁校验 |
| `max_pack_depth` | `32` | 目录递归深度上限（防 symlink-to-dir 循环）；create 触碰该上限时 E5002 失败以避免静默漏收 |
| `max_pack_files` | `10000` | 最大文件收集数（防 symlink 炸弹） |

退出码（冻结）：`0` 验证通过、`1` 验证失败、`2` 用法/IO 错误。

### 6.2 模型配置（`model/manifest.mbt`）

| 常量 | 值 | 说明 |
|---|---|---|
| `SUPPORTED_SCHEMA` | `"moon-evidence/v0"` | 支持的 schema 标识符 |
| size 上限 | `9007199254740991`（2^53-1） | JSON number 精确表示上限 |
| 路径校验规则 | 拒绝 0x00、<0x20 控制字符、0x5c `\`、0x3a `:`、绝对路径(`/`开头)、空段、`.` 段、`..` 段 | 防目录穿越/注入 |

### 6.3 Digest 配置（`digest/`）

| 常量 | 值 | 说明 |
|---|---|---|
| `sha256_round_constants` | 64 个 UInt | FIPS 180-4 §4.2.2 立方根小数部分 |
| `sha256_initial_state` | 8 个 UInt | FIPS 180-4 §5.3.3 平方根小数部分 |
| `hmac_block_size` | `64` 字节（512 bit） | HMAC-SHA256 块大小 |
| HashAlgorithm 标签 | `"sha256"` / `"sha512"` | 规范小写标签 |
| digest 文本格式 | `<algo>:<lowercase-hex>` | 规范 digest 字符串形式 |
| `normalize_algorithm` 接受 | `sha256`/`sha-256`/`sha512`/`sha-512`（大小写不敏感） | 算法名归一化 |

### 6.4 Merkle 配置（`merkle/merkle.mbt`）

| 常量 | 值 | 说明 |
|---|---|---|
| 叶子哈希前缀 | `0x00` | 域分离：`H(0x00 ‖ data)` |
| 内部节点哈希前缀 | `0x01` | 域分离：`H(0x01 ‖ left ‖ right)` |
| 奇数节点处理 | 提升到下一层不变（绝不自配对） | 防 CVE-2012-2459 |
| 默认算法 | Sha256（`algorithm?` 缺省时） | 向后兼容 |

### 6.5 Canonjson 配置（`canonjson/canonjson.mbt`）

| 常量 | 值 | 说明 |
|---|---|---|
| `lower_hex_digits` | `['0'..'9','a'..'f']` | JCS 转义用小写 hex |
| 字符串转义集合 | `\"` `\\` `\b` `\f` `\n` `\r` `\t` + `\u00xx`（<U+0020） | RFC 8785 §3.2.2.2 |
| 数字序列化 | ECMAScript shortest-form（§3.2.2.3） | NaN/Infinity → `UnsupportedNumber` |
| 键排序 | UTF-16 code-unit 词典序（非 shortlex） | RFC 8785 §3.2.3 |

### 6.6 API 默认值（`api/api.mbt`）

| 配置 | 默认值 | 说明 |
|---|---|---|
| 默认算法 | `sha256` | `algorithm` 缺省时 |
| 默认 timestamp | `"2026-07-05T00:00:00Z"` | demo 用，**非生产安全** |
| demo seed | `[1,2,...,32]` | Ed25519 keypair 缺省 seed，**非生产安全** |
| 公钥长度 | 32 字节 | Ed25519 |
| 私钥/seed 长度 | 32 字节 | Ed25519 |
| 签名长度 | 64 字节 | Ed25519 |
| audit hash 格式 | `"sha256:" + 64 hex`（共 71 字符） | 审计条目哈希格式校验 |

### 6.7 Create 默认值（`cmd/main/main.mbt` run_create）

| 配置 | 默认值 |
|---|---|
| `--subject-type` | `"generic"` |
| `--algorithm` | `sha256` |
| `--version-id` | `"v1"` |
| `-o`/`--output` | `<dir>/manifest.json` |
| 排除文件 | 根级 `manifest.json`（输出文件本身） |

### 6.8 增量缓存格式（`cache.json`）

```json
{
  "manifest_digest": "sha256:<hex>",
  "files": { "<path>": "<digest>", ... }
}
```

---

## 7. CLI命令与JS API

### 7.1 CLI 命令

```
moon-evidence pack <source-dir> [-o <pack-dir>] [--json]
moon-evidence inspect [--json] <path>
moon-evidence verify [--json] [--incremental <cache-dir>]
                     [--expected-manifest-digest <digest>] <path> [<path> ...]
moon-evidence explain <path> [<path> ...]
moon-evidence create <dir> --subject-id <id> [--subject-type <type>]
                        [--algorithm sha256|sha512]
                        [--version-id <id>] [--version-parent <hash>]
                        [-o <out>]
moon-evidence --version
moon-evidence --help
```

| 命令 | 别名 | 说明 |
|---|---|---|
| `pack` | `seal` | 复制源目录并创建完整 `manifest.json + files/` 证据包；可输出机器 JSON |
| `inspect` | — | 解析 manifest 并输出规范摘要/元数据，不替代文件验证 |
| `verify` | — | 验证证据包，支持 `--json` 规范 JSON 报告 |
| `explain` | — | 验证并打印人类可读 findings 报告（禁用 `--json`） |
| `create` | — | 从目录创建 manifest |
| `--version` | `-v`, `version` | 打印 `moon-evidence 0.5.0` |
| `--help` | `-h`, `help` | 打印用法 |

**verify/explain 选项**：

| 选项 | 说明 |
|---|---|
| `--json` | 输出规范 JSON（仅 verify） |
| `--incremental <dir>` | 缓存 file digest 到 `<dir>`，未变文件跳过重哈希 |
| `--expected-manifest-digest <digest>` | 对比外部/链上规范摘要，不一致报告 E2004 |
| 多路径 | 批量模式，全部通过才退出 0；任一失败退出 1；用法错误退出 2 |

**create 选项**：

| 选项 | 必填 | 默认 |
|---|---|---|
| `<dir>` | 是 | — |
| `--subject-id <id>` | 是 | — |
| `--subject-type <type>` | 否 | `generic` |
| `--algorithm <name>` | 否 | `sha256` |
| `--version-id <id>` | 否 | `v1` |
| `--version-parent <hash>` | 否 | 无 |
| `-o, --output <path>` | 否 | `<dir>/manifest.json` |

### 7.2 JS API（ESM 导出，字符串进字符串出）

| API | 请求 JSON | 响应 JSON |
|---|---|---|
| `verify_evidence` | `{manifest, files?, version_chain?, expected_manifest_digest?}` | `{ok, explain, report}` 或 `{ok:false, error}` |
| `compute_merkle_tree` | `{manifest, files?}` | `{ok, tree:{leaves,levels,root,paths}, example_path}` |
| `create_evidence_pack` | `{files, subject:{id,type/kind}, algorithm?, version_id, version_parent?}` | `{ok:true, manifest}` |
| `generate_proof` | `{manifest, files?, index}` | `{ok, proof, leaf_hash, root, algorithm}` |
| `verify_proof` | `{leaf, proof:[{side,sibling}], root, algorithm?}` | `{ok:true, valid}` |
| `audit_append` | `{log?, actor, action, subject_id, manifest_digest?, timestamp?}` | `{ok, log, entry_hash}` |
| `audit_verify` | `{log, verify_signatures?, public_key?}` | `{ok, chain_valid, signatures_valid, length}` |
| `audit_sign` | `{log, secret_key}` | `{ok, log}` |
| `ed25519_keypair` | `{seed?}` | `{ok, public_key, secret_key, warning?}` |
| `ed25519_sign` | `{secret_key, message}` | `{ok, signature}` |
| `ed25519_verify` | `{public_key, message, signature}` | `{ok, valid}` |

---

## 8. 测试覆盖全景

### 8.1 总体统计

| 指标 | 值 |
|---|---|
| 测试文件总数 | 27 个白盒测试文件（`*_wbtest.mbt`） |
| 测试函数总数 | 351 个声明（347 个可执行测试 + 4 个基准 wrapper） |
| 黑盒测试 | 62 例 CLI 套件（`cli-test.ps1` / `cli-test.sh`） |
| Fabric adapter | Chaincode 82.1% 语句覆盖；Gateway 19/19；真实双组织 E2E |
| 属性测试 | 3 个文件（canonjson_prop, merkle_prop, manifest fuzz） |
| 基准测试 | 2 个文件（digest_bench, verify_bench） |
| 变异测试 | 16 个变异点（全部被捕获） |
| 分支清单审计 | `docs/BRANCH_COVERAGE.md` 覆盖 verify/incremental/merkle/digest/crypto/create/store/audit/api 194 个关键分支，0 个 open gap |

### 8.2 各包测试分布

| 包 | 测试文件数 | 测试函数数 | 覆盖评价 |
|---|---|---|---|
| `api` | 1 | 42 | 最全面；含外部摘要通过/拒绝/格式边界 |
| `model` | 2 | 34 | 良好 |
| `digest` | 6 | 46 | SHA/HMAC 差分 oracle 已入 CI；解析错误分支与 SHA-512 padding 边界已补 |
| `verify` | 4 | 44 | 良好（增量验证独立 oracle 已补，错误路径仍可扩展） |
| `canonjson` | 3 | 31 | 良好 |
| `crypto` | 4 | 48 | Wycheproof oracle 与精确分支覆盖已补；常量时间静态审计已完成，CT-001（`reduce_scalar_512` secret-derived 分支）已源码级修复；Fe 规范化边界已补 |
| `merkle` | 3 | 36 | 良好（边界/大规模/SHA-512 域分离已补） |
| `audit` | 1 | 26 | 良好；签名跳过/空日志签名/解析分支已补 |
| `create` | 1 | 16 | 5 个 panic 测试覆盖 create_manifest abort 分支，空文件 Merkle null 分支已补 |
| `store` | 1 | 18 | 安全函数独立 oracle 已补；严格/宽松重建边界已覆盖 |
| `diag` | 1 | 7 | 单复数 summary 分支已覆盖 |
| **合计** | **27** | **351** | — |

### 8.3 CLI 黑盒测试（62例）

| 部分 | 用例数 | 内容 |
|---|---|---|
| Part 1 命令形状 | 12 | --version、--help、无参数、未知命令等 |
| Part 2 篡改矩阵 | 10 | tampered-file/missing-file/unlisted-file/bad-digest-field/bad-merkle-root/chain-broken/chain-cycle/chain-empty/chain-fork |
| Part 3 manifest 错误码矩阵 | 19 | E1001-E4004 全覆盖 |
| Part 4 create | 10 | 创建+验证往返 + depth-cap abort |
| Part 5 incremental | 3 | 增量验证 |
| Part 6 机器合同 | 8 | inspect、外部摘要正反例、pack、覆盖拒绝、seal、create JSON |

### 8.4 密码学安全测试现状

**Ed25519 已覆盖的安全检查**：

| 安全检查 | 源码位置 | 测试状态 |
|---|---|---|
| S ≥ l (可塑性) | `ed25519.mbt:260` | ✅ 已测 |
| S = l (群阶) | `ed25519.mbt:260` | ✅ 已测 |
| S 高位进位 (2^256) | `ed25519.mbt:260` | ✅ 已测 |
| 非规范 y (y ≥ p) | `ed25519.mbt:350` | ✅ 已测 |
| 单位点公钥 | `ed25519.mbt:271` | ✅ 已测 |
| 低阶点 (cofactor=8) | `ed25519.mbt:279-282` | ✅ 已测 |
| RFC 8032 §7.1 KAT (4组) | — | ✅ 已测 |
| Wycheproof Ed25519 (150向量) | `ed25519_wycheproof_wbtest.mbt` | ✅ 已测（88 valid + 62 attack vectors） |

**Merkle 证明伪造测试**：

| 伪造类型 | 测试状态 |
|---|---|
| 伪造兄弟哈希 | ✅ 已测 |
| 翻转方向 (Left↔Right) | ✅ 已测 |
| 截断证明 | ✅ 已测 |
| 扩展证明 (多余步骤) | ✅ 已测 |
| 错误叶子 | ✅ 已测 |
| 域分离绕过 (叶哈希充当节点) | ✅ 已测 |
| 越界索引 | ✅ 已测 |

---

## 9. 测试盲点清单

### 9.1 高风险盲点（4项）

| # | 盲点 | 源码位置 | 风险描述 |
|---|---|---|---|
| H1 | Ed25519 错误长度输入 | `ed25519.mbt:245` | `ed25519_verify` 对 `sig.length≠64` 和 `pk.length≠32` 的 early return 未被测试。攻击者可能利用错误长度的输入触发未定义行为。 |
| H2 | Ed25519 无效点解码 | `ed25519.mbt:264-267, 284-287` | `point_decode` 返回 None 时 verify 返回 false 的两个分支都未测试。需构造非法点编码（非规范 y、不在曲线上的点）。 |
| H3 | Ed25519 x=0 + sign=1 | `ed25519.mbt:375-377` | RFC 8032 §5.1.3 明确要求拒绝的编码，未被测试。 |
| H4 | 常量时间审计、CT-001 修复与 native timing | `field25519.mbt:199,214`; `point25519.mbt:129,144`; `ed25519.mbt:81-153`; `src/timing`; `docs/CONST_TIME_AUDIT.md` | 静态审计确认 `scalar_mul`/`cmov` 源码层面无明显 secret-dependent 分支；`reduce_scalar_512` 的比较与 borrow 分支已改为 arithmetic mask/selection。native 50000 样本长跑未观察到明显 timing difference；正式 dudect/后端产物审计定位为生产化认证路线。 |

### 9.2 中风险盲点/进度（6项）

| # | 盲点 | 源码位置 | 风险描述 |
|---|---|---|---|
| M1 | create.mbt 的 abort 分支 | `create.mbt:41-53, 69-71` | 5 个 abort 分支全部未测试：空 subject.id、空 subject.kind、空 version_id、空 version_parent、非法文件路径。 |
| M2 | store 的 verify_integrity 和 reconstruct_strict | `object_store.mbt:126-140, 168-184` | 2026-07-06 已补 6 个独立 oracle 测试：硬编码 Node-computed SHA-256，绕过 `put()`，覆盖篡改/缺失/多缺失/严格重建。 |
| M3 | 增量验证缓存篡改安全 | `incremental.mbt:125` | 2026-07-06 已补 Q3 信任边界测试：恶意缓存会隐藏内容篡改，full verify 会检测；剩余增量错误路径见 M6。 |
| M4 | 大规模 Merkle 树 | `merkle_wbtest.mbt` | Done：覆盖 2^k-1/2^k/2^k+1 边界、10000 叶 SHA-256/SHA-512 根与代表性 proof。 |
| M5 | SHA-512 在各模块中的覆盖 | merkle/verify/incremental | SHA-512 路径未被直接测试，仅通过 create 的往返间接覆盖。 |
| M6 | 增量验证错误路径 | `incremental.mbt:43-78, 146-155, 183-191` | manifest 解析失败(E1001)、canonicalize失败(E1004)、W1001、E3001 在增量验证中均未被测试。 |

### 9.3 低风险盲点（7项）

| # | 盲点 | 源码位置 | 风险描述 |
|---|---|---|---|
| L1 | point_decode 错误长度 | `ed25519.mbt:335` | `data.length() != 32` 分支未被直接测试（间接通过 ed25519_verify 的长度检查覆盖）。 |
| L2 | point_decode sqrt(-1) 乘法路径 | `ed25519.mbt:362-364` | x^2 不是二次剩余时乘以 sqrt(-1) 的分支未被测试。 |
| L3 | point_decode 点不在曲线上 | `ed25519.mbt:365-367` | 乘以 sqrt(-1) 后仍不匹配返回 None 的分支未被测试。 |
| L4 | Fe::from_small 无直接测试 | `field25519.mbt:27` | Done：`field25519_wbtest` 直接断言 UInt64 limb 小端序列化。 |
| L5 | Fe::to_bytes 条件减 p | `field25519.mbt:161-186` | Done：`field25519_wbtest` 覆盖 p->0、p+1->1、p-1 不变。 |
| L6 | diag 单复数分支 | `diag.mbt:139, 141` | Done：`diag_wbtest` 覆盖 0/1/2 个 error/warning 的 summary 文案。 |
| L7 | digest parse_digest 失败分支 | `digest.mbt:119-127` | Done：`digest_wbtest` 覆盖无冒号、多冒号、未知算法、空 hex、非 hex。 |

### 9.4 已知治理缺口

| 缺口 | 说明 |
|---|---|
| CLI_VERSION 一致性 | 2026-07-06 已纳入 `check-metrics.mjs`：`src/cmd/main/main.mbt` 的 `CLI_VERSION` 必须等于 `moon.mod` version |
| E3002 错误码未覆盖 | CLI 不提供 proofs/ 消费者，无 manifest 夹具能触发 E3002 |
| bash cli-test 对齐 | 两套脚本均为 62 例：原 create/incremental 合同 + 8 个机器接口/外部锚点用例 |
| 基准测试仅 js 后端 | native 后端预期更快但未实测 |
| fuzz 有界抽样 | malformed API fuzz 已入 CI，stress 10000 轮已跑；仍不等于全输入证明 |
| 符号链接安全缓解为运行时上限 | `@fs` 包不暴露 symlink 检测 API，只能用深度+文件数双上限；Windows junction probe 已实测 native/js create 安全失败、verify 有界终止 |

---

## 10. CI流水线

### 10.1 流水线概览

- **配置文件**：`.github/workflows/ci.yml`
- **触发条件**：push/PR 到 `main` 分支
- **运行环境**：`ubuntu-latest`
- **权限**：`contents: read`
- **三个 Job**：`check-test-build`（阻塞性）+ `fabric-adapters`（阻塞性）+ `bench`（非阻塞）

### 10.2 check-test-build 21步

| 步骤 | 命令/工具 | 作用 | 防线 |
|---|---|---|---|
| 1 | `actions/checkout@v4`（fetch-depth: 0） | 拉取完整历史 | — |
| 2 | `curl ... install/unix.sh` | 安装 MoonBit CLI | — |
| 3 | `moon version --all` | 记录工具链版本 | — |
| 4 | `node tools/check-metrics.mjs` | **指标漂移门禁**：校验文档数字与仓库实测一致 | 第1道 |
| 5 | `node tools/check-branch-coverage-stale.mjs` | **分支覆盖防漂移门禁**：已审计源码变更必须同步 review 分支图 | 第1道 |
| 5 | `node tools/gen-fixtures.mjs` + `git diff` | **夹具防腐化门禁**：重生成夹具必须字节一致 | 第1道 |
| 6 | `node tools/cross-verify.mjs` | **交叉对拍**：用 Node.js crypto 独立复算摘要和 Merkle 根 | 第2道 |
| 7 | `node tools/check-wycheproof-ed25519.mjs` | Wycheproof Ed25519 向量清点门禁 | 第2道 |
| 8 | `moon check` | 类型检查（0 warning） | — |
| 9 | `moon fmt --check` | 格式化门禁 | — |
| 10 | `moon test --target wasm-gc,js` | wasm-gc + js 单元测试 | — |
| 11 | `moon build --target native` | 构建 native | — |
| 12 | `moon test --target native` | native 单元测试 | — |
| 13 | `pwsh ./tools/cli-test.ps1 -Target native` | CLI 黑盒（62例，native） | — |
| 14 | `moon build --target wasm-gc` | 构建 wasm-gc | — |
| 15 | `moon build --target js` | 构建 js | — |
| 16 | `pwsh ./tools/cli-test.ps1 -Target js` | CLI 黑盒（62例，js） | — |
| 17 | `node tools/smoke-api.mjs` | 浏览器适配器烟测（12个API） | — |
| 18 | `node tools/fuzz-api-malformed.mjs --rounds 64` | 公共 JS API malformed-request fuzz：12 个 string adapter 不崩溃且返回 JSON envelope | 第3道 |
| 19 | `node tools/property-api-semantic.mjs --rounds 16` | 公共 JS API semantic property：valid request 闭环不变量与篡改拒绝 | 第3道 |
| 20 | `node tools/differential-crypto.mjs --rounds 64` | Ed25519 JS API 与 Node.js crypto 随机差分对拍 | 第2道 |
| 21 | `node tools/differential-digest.mjs --rounds 64` | SHA-256/SHA-512/HMAC-SHA256 JS API 与 Node.js crypto 随机差分对拍 | 第3道 |
| 22 | `node tools/mutation-check.mjs` | **变异测试**：逐字节改写源码，确认测试变红 | 第4道 |

`fabric-adapters` job 单独运行 Go vet/race/coverage 和 Gateway
`npm ci`/TypeScript check/build/12 tests。真实 Docker Fabric 网络按协议或 SDK
变更触发复跑，收据不以 mock 结果代替。

### 10.3 bench Job（非阻塞）

- 依赖 `check-test-build` 完成
- `continue-on-error: true`
- 运行 `moon bench --target js`
- 跟踪 SHA-256 吞吐和端到端验证耗时
- README 明确：共享 runner 噪声大，回归不阻断主 CI

### 10.4 发布流程（release.yml）

- 触发：推送匹配 `v*` 的 tag
- 步骤：checkout → 安装 → `moon check` → `moon package` → 计算 SHA256 → `gh release create`
- 产物：`_build/publish/<owner>-<Module>-<version>.zip` + `.sha256` sidecar
- 完整性契约镜像：SHA256 sidecar 让下游消费者验证发布包未被篡改

---

## 11. 工具脚本清单

> 所有脚本路径前缀：`tools/`

### 11.1 CI 门禁类（Node.js ESM）

| 文件 | 用途 | 关键参数/机制 |
|---|---|---|
| `check-metrics.mjs` | 指标漂移门禁。校验文档数字与仓库实测一致，并校验 `moon.mod`/CHANGELOG/CLI_VERSION 版本一致 | `--fix` 打印建议修复（不写入）。提交数用 `minimum` 语义 |
| `check-branch-coverage-stale.mjs` | 分支覆盖图防漂移门禁。已审计源码变更必须同步触碰 `docs/BRANCH_COVERAGE.md` | 支持 `--self-test`；当前守护 verify/incremental/merkle/digest/crypto/create/store/audit/api 源码 |
| `cross-verify.mjs` | 独立交叉对拍。用 `node:crypto` 重算所有金色包的摘要和 Merkle 根 | 负面包（`bad-`/`tampered-`/`missing-` 前缀）失败=预期通过。RFC 6962 域分离 |
| `check-wycheproof-ed25519.mjs` | Wycheproof Ed25519 向量清点门禁 | 校验 150 向量总数、88/62 valid/invalid 分布、7 个攻击类别计数 |
| `fuzz-api-malformed.mjs` | 公共 JS API malformed-request fuzz。对 12 个导出的 string-in/string-out adapter 投喂无效 JSON、非对象 JSON、错类型字段、坏 hex、坏 proof/audit/signature/key 形状 | 默认 128 轮；CI 固定 64 轮；验证不 throw、返回 JSON 对象、`ok` 为布尔值，确定 malformed envelope 返回 `ok:false + error` |
| `property-api-semantic.mjs` | 公共 JS API semantic property。对有效随机请求跑 create→verify→proof、audit append/sign/verify、Ed25519 sign/verify 闭环，并检查篡改必须失败 | 默认 64 轮；CI 固定 16 轮；发布候选可手动 `--rounds 64` 或更高 |
| `randomized-hardening.mjs` | 随机化加固 profile 编排器。统一运行 malformed API fuzz、API semantic property、Ed25519 differential、digest differential | `--profile ci` = CI 轮次；`--profile release` = 发布候选长轮次；`--profile stress` = 10000 级别压力抽样；支持 `--dry-run` 和单项轮次覆盖 |
| `timing-ed25519-verify.mjs` | Ed25519 verify JS 动态时序采样。比较两类同形 valid verify 请求，输出均值、方差和 Welch t 统计 | 默认 10000 samples；发布/审计时手动运行；作为 JS 后端的轻量 timing assurance 信号 |
| `timing-ed25519-native.ps1` | Ed25519 native dudect-style timing runner。构建 `src/timing` native release，覆盖 verify/sign-message/sign-secret，输出均值、方差、Welch t 与环境信息 | 50k 长跑已记录为本机工程化侧信道 assurance 证据；正式 dudect/后端产物审计属于生产化认证路线 |
| `differential-crypto.mjs` | Ed25519 随机差分对拍。比较编译后的 MoonBit JS API 与 Node.js `crypto` | 默认 64 轮；CI 固定 64 轮；发布候选可手动 `--rounds 1000` |
| `differential-digest.mjs` | SHA-256/SHA-512/HMAC-SHA256 随机差分对拍。比较编译后的 MoonBit JS API 与 Node.js `crypto` | 默认 64 轮；CI 固定 64 轮；发布候选可手动 `--rounds 1000` |
| `mutation-check.mjs` | 变异测试。逐字节改写源码，跑测试，确认变红，再恢复 | 支持 `--merkle`/`--hmac` 等前缀过滤。16 个变异。exit 0=全捕获 |

### 11.2 夹具生成类

| 文件 | 用途 |
|---|---|
| `gen-fixtures.mjs` | 生成篡改矩阵夹具（10个包：valid/tampered/missing/unlisted/bad-digest/bad-merkle/chain-broken/cycle/empty/fork） |
| `gen-merkle-fixtures.mjs` | 生成 Merkle 金色根和包含性证明（6种形状：1/2/3/4/5/8叶子） |
| `gen-pack-fixture.mjs` | 构建 verify 测试用的"valid pack"金色夹具 |
| `check-fixtures.mjs` | 夹具防腐化守护。重新生成 + `git diff` 检测漂移 |

### 11.3 CLI 黑盒测试类

| 文件 | 用例数 | 说明 |
|---|---|---|
| `cli-test.ps1` | 54 | PowerShell 黑盒套件，5部分（命令形状12 + 篡改矩阵10 + manifest错误码19 + create10 + incremental3）。`-Target js\|native` |
| `cli-test.sh` | 54 | bash 1:1 对等移植版（Part1-5）。**强制依赖 jq**；CI 同时跑 native/js |

### 11.4 辅助类

| 文件 | 用途 |
|---|---|
| `smoke-api.mjs` | 浏览器适配器烟测，覆盖 12 个 pub API 闭环（含 `digest_compute`） |
| `env-check.ps1` | 环境体检（git/node/npm/moon + 网络连通性）。`-Json` 输出 JSON |
| `record-demo.ps1` | 演示视频录制（ffmpeg + gdigrab）。`-Duration 10`（分钟） |
| `play-demo.ps1` | 演示播放辅助（自动翻页 + http.server:8765） |

---

## 12. 变异测试

### 12.1 机制

对每个声明变异：逐字节改写生产源码（**绝不改测试文件**）→ 跑 `moon test --target js`（180s 超时）→ 确认至少一个测试变红 → 恢复原始字节（即使 harness 自身抛错也恢复）。

`find` 字符串必须在文件中**唯一出现**，否则拒绝应用。

### 12.2 判定逻辑

- `CAUGHT`：测试变红（预期）
- `SLIPPED`：测试保持绿色（属性套件有覆盖盲区=真实测试质量 bug）
- `ERRORED`：无法应用（find 字符串移动或多次匹配）

exit 0 = 全部捕获；exit 1 = 有逃逸或无法应用。**阻塞性门禁**。

### 12.3 16个变异用例

| ID | 标签 | 目标文件 | 变异内容 | 预期捕获 |
|---|---|---|---|---|
| `merkle-leaf-prefix` | 叶子域分隔符 0x00→0x01 | `merkle.mbt` | 翻转 RFC 6962 叶子前缀 | 域分离属性测试 |
| `merkle-node-prefix` | 节点域分隔符 0x01→0x00 | `merkle.mbt` | 翻转节点前缀 | 域分离属性测试 |
| `merkle-sha512-leaf-prefix` | SHA-512 叶子域分隔符 0x00→0x01 | `merkle.mbt` | 翻转 SHA-512 分支叶子前缀 | SHA-512 域分离测试 |
| `merkle-sha512-node-prefix` | SHA-512 节点域分隔符 0x01→0x00 | `merkle.mbt` | 翻转 SHA-512 分支节点前缀 | SHA-512 域分离测试 |
| `merkle-self-pair` | 奇节点自我配对（CVE-2012-2459） | `merkle.mbt` | 将"提升未配对节点"改为"自我配对" | 提升属性测试 |
| `merkle-tree-self-pair` | 物化树奇节点自我配对 | `merkle.mbt` | 将 `compute_tree` 的提升改为自我配对 | 物化树 root/shape 测试 |
| `ed25519-canonical-s` | canonical S 检查反转 | `ed25519.mbt` | `!scalar_lt_l` → `scalar_lt_l` | RFC KAT + 可塑性测试 |
| `ed25519-low-order-reject` | 低阶点拒绝移除 | `ed25519.mbt` | 8*A 检查的 `return false` 改为 `()` | 低阶点测试 |
| `ed25519-noncanonical-y` | 非规范 y 拒绝移除 | `ed25519.mbt` | 往返检查的 `return None` 改为 `()` | 非规范 y 测试 |
| `hmac-ipad-constant` | HMAC ipad 常数翻转 | `hmac.mbt` | `0x36` → `0x37` | RFC 4231 HMAC 向量 |
| `hmac-opad-constant` | HMAC opad 常数翻转 | `hmac.mbt` | `0x5c` → `0x5d` | RFC 4231 HMAC 向量 |
| `sha256-initial-h0` | SHA256 初始 H0 翻转 | `sha256.mbt` | `0x6a09e667U` → `0x6a09e668U` | NIST "abc" KAT |
| `sha256-round-k0` | SHA256 轮常数 K0 翻转 | `sha256.mbt` | `0x428a2f98U` → `0x428a2f99U` | NIST "abc" KAT |
| `sha512-initial-h0` | SHA512 初始 H0 翻转 | `sha512.mbt` | `0x6a09e667f3bcc908UL` → `...909UL` | SHA-512/Ed25519 向量 |
| `sha512-round-k0` | SHA512 轮常数 K0 翻转 | `sha512.mbt` | `0x428a2f98d728ae22UL` → `...e23UL` | SHA-512/Ed25519 向量 |
| `incremental-e2004-disabled` | incremental E2004 禁用 | `incremental.mbt` | `actual != expected` → `false` | manifest digest mismatch 测试 |

---

## 13. 安全治理

### 13.1 密码学实现现状

- **SHA-256/SHA-512**：纯 MoonBit，对照 NIST FIPS 180-4 标准测试向量验证
- **HMAC-SHA256**：RFC 2104
- **Ed25519**：从 GF(2^255-19) 有限域 → Curve25519 点运算 → RFC 8032 签名/验签，全程纯 MoonBit，约 800 行，零外部密码学依赖

### 13.2 已具备的防护（2026-07-04 两轮根因加固）

| # | 防护 | 说明 |
|---|---|---|
| 1 | 反可塑性 | `ed25519_verify` 拒绝 `S >= l`（RFC 8032 §8.4） |
| 2 | 恒定时间标量乘法 | `scalar_mul` 用 conditional select（cmov）替代 secret-dependent 分支 |
| 3 | Binary quotient decomposition | 标量归约从逐次减法改为二进制商分解，~500K次→~50次乘法 |
| 4 | 非规范编码拒绝 | `point_decode` 通过 `Fe::to_bytes()` 往返规范化检查拒绝 y ≥ p |
| 5 | 低阶公钥拒绝 | 显式拒绝 identity 公钥，并通过 `8*A` cofactor 检查拒绝 cofactor=8 torsion subgroup |
| 6 | 审计签名覆盖 canonical JSON | `sign_last`/`verify_signatures` 对 RFC 8785 规范化后的条目签名 |
| 7 | RFC 8032 §7.1 KAT | 4 组官方已知答案测试 |

### 13.3 残留限制

| # | 限制 | 风险 |
|---|---|---|
| 1 | 恒定时间实现为源码审计 + 本机 native timing 经验性证据 | `docs/CONST_TIME_AUDIT.md` 已记录 CT-001 源码级修复与 50000 样本 native timing；正式 dudect/专业审计作为生产化认证路线 |
| 2 | MoonBit 编译器不承诺消除 secret-dependent 内存访问 | native 后端的 C 编译器可能重新引入分支；当前 timing 只覆盖本机 Windows/MSVC release 环境 |
| 3 | 低阶公钥检查为验证路径防护 | `ed25519_verify` 覆盖 identity 与 `8*A` cofactor 检查；生产级认证仍建议补后端产物审计和外部密码学评审 |
| 4 | 符号链接安全缓解为运行时上限 | `@fs` 包不暴露 symlink 检测 API，只能用 `max_pack_depth=32` + `max_pack_files=10000`；create 触深度上限时 E5002，junction probe 已覆盖 native/js |

### 13.4 重要声明

> 本项目面向课程/竞赛场景中的本地 Evidence Pack 可信校验核心，密码学路径采用分层 assurance 策略：RFC 8032 KAT、Wycheproof、交叉对拍、源码级侧信道审计与本机 native dudect-style timing 长跑共同构成当前交付级证据包，并已补齐反可塑性、源码级分支收敛、branch-free 源码级标量归约、binary quotient decomposition、低阶公钥 cofactor 检查等防护；正式 dudect 审计和后端产物审计定位为面向生产级高价值资产的后续认证路线。

### 13.5 漏洞报告渠道

- GitHub Issues 标注 `security` 标签（非敏感问题）
- GitHub Security Advisory 私有报告（敏感问题）

---

## 14. 三后端差异

### 14.1 后端配置

| 后端 | 平台文件 | 特殊依赖 |
|---|---|---|
| native/llvm | `main_native.mbt` + `native_stub.c` | C FFI（`moon_evidence_eprintln_stderr` 写 stderr） |
| js | `main_js.mbt` | 无 |
| wasm/wasm-gc | `main_wasm.mbt` | 无 |

### 14.2 测试覆盖矩阵

| 后端 | moon check | moon test | moon build | CLI 黑盒 | 说明 |
|---|---|---|---|---|---|
| wasm-gc | ✅ | ✅（与 js 同步） | ✅ | ✗ | 单元测试在可移植后端跑 |
| js | ✅ | ✅（与 wasm-gc 同步） | ✅ | ✅（62例） | 浏览器适配器烟测 + 变异测试也用 js |
| native | ✅ | ✅ | ✅ | ✅（62例） | 本地 Windows/MSVC 已验证；CI ubuntu/gcc 继续覆盖 |

### 14.3 关键差异

1. **native 后端需要 C 编译器**：本地 Windows 已通过 Visual Studio 2022 MSVC 19.44 + Windows SDK 10.0.26100.0 验证 native 构建、单测与黑盒；普通 PowerShell 需要先加载 `vcvars64.bat` 或使用 x64 Native Tools Prompt
2. **纯核心包后端无关**：canonjson/digest/merkle/model/diag/verify 的单元测试后端无关
3. **js 后端的特殊角色**：变异测试固定用 js、基准测试固定用 js、smoke-api.mjs 从 js 产物导入
4. **wasm-gc 不跑黑盒**：CLI 黑盒只覆盖 native + js

---

## 15. 系统化深度测试计划

> **核心决策**：是的，必须先把测试计划完善并做好，再谈改进。详细计划见 **[docs/TEST_PLAN.md](../TEST_PLAN.md)**。

### 15.1 策略结论

| 改进类型 | 前置条件 |
|---|---|
| crypto/digest/merkle 包的任何改进 | 阶段1全部完成 |
| verify/create/store 包的功能改进 | 阶段1 + 阶段2完成 |
| diag/model 等非安全包改进 | 阶段1完成即可 |
| CLI/CI 治理改进 | 可与阶段2并行 |

### 15.2 系统性缺陷根因

| 根因 | 涉及盲点 | 本质 |
|---|---|---|
| A: Happy-path bias | H1,H3,M1,L1,L7 | 从"能做什么"正向生成，而非从"每种输入该返回什么"逆向生成 |
| B: 无分支覆盖率模型 | H2,H3,L2-L6 | MoonBit 缺 coverage 工具，"351个测试声明"仍是数量非覆盖 |
| C: 密码学测试未对标行业标准 | H2,H3,H4 | Wycheproof Ed25519 已补 150 向量；静态常量时间审计已补，CT-001 已源码级修复；native dudect-style timing 已补；正式 dudect/后端产物审计进入生产化认证路线 |
| D: 安全函数测试优先级低 | M2,M3 | 功能先测，防篡改安全函数后测 |
| E: 测试资产双轨漂移 | 6项治理缺口 | ps1/sh 已对齐到 62 例；仍需避免未来人工移植再次漂移 |

**关键数据**：76%的盲点都是"没测异常路径"，不是个别遗漏而是默认取向。

### 15.3 九层测试模型

| 层次 | 名称 | 现状 | 目标 |
|---|---|---|---|
| L0 | 单元测试 | 351个声明（347可执行+4基准wrapper）+ verify/incremental/merkle/digest/crypto/create/store/audit/api 分支图 + stale-check gate + API malformed fuzz gate + API semantic property gate + CLI_VERSION gate | 继续按高风险变更补 oracle/mutation；正式 dudect/后端产物级审计作为生产化认证路线 |
| L1 | 集成测试 | MoonBit 闭环 + CLI 机器合同 + Fabric 双组织 E2E | 协议/SDK 变化时复跑真实网络 |
| L2 | 属性测试 | 3个 | +8（Ed25519/Fe/canonjson） |
| L3 | 差分测试 | 固定夹具 | +随机差分harness |
| L4 | CLI黑盒 | ps1=62,sh=62 | 后续改 CLI 时双脚本同步 |
| L5 | 变异测试 | 16点 | 继续按高风险改动补点 |
| L6 | 模糊测试 | CI 有界 fuzz + stress 10000 轮 | 保持分层 profile |
| L7 | 性能基准 | 仅js | +native/wasm-gc |
| L8 | 安全测试 | 源码审计 + JS timing + native verify/sign timing | 当前形成工程化侧信道 assurance 层；正式 dudect/后端产物审计进入生产化认证路线 |

### 15.4 三阶段实施

| 阶段 | 优先级 | 内容 | 工作量 | 前置条件 |
|---|---|---|---|---|
| **阶段1** | P0阻断 | 已完成 Wycheproof Ed25519 oracle、Ed25519 精确分支、store 安全函数 oracle、增量缓存信任边界、常量时间静态审计、create abort panic 测试、CT-001 源码级修复 | 源码与测试治理收口 | 无 |
| **阶段2** | P1安全网 | 补12项中风险+治理缺口（大规模树/SHA-512/增量错误路径/bash补齐/CLI_VERSION门禁/属性测试/变异扩展/差分测试） | 4-6天 | 阶段1 |
| **阶段3** | P2技术债 | 补7项低风险+高级测试（diag单复数/parse_digest/模糊测试/动态时序/Wycheproof移植） | 3-5天 | 阶段2 |

### 15.5 改进安全检查清单

任何代码改进合并前必须通过：
1. 涉及的包是否有未覆盖盲点？→ 高风险 BLOCKED，中低风险同PR补测试
2. 涉及 crypto/digest/merkle？→ 变异测试新增且捕获 + 常量时间审计复查
3. 涉及 CLI？→ bash 和 PowerShell 都更新 + 三目标验证
4. 改变错误码？→ 分支清单更新 + CLI断言更新
5. 指标守卫 + 变异测试 + 交叉对拍 全绿

> 完整的测试用例清单、分支清单审计表、差分测试harness代码、属性测试示例、风险登记册等详见 **[docs/TEST_PLAN.md](../TEST_PLAN.md)**。

---

## 16. 关键文件索引

### 16.1 源码文件

| 文件路径 | 行数(约) | 职责 |
|---|---|---|
| `src/canonjson/canonjson.mbt` | ~300 | RFC 8785 规范化 JSON |
| `src/digest/digest.mbt` | ~160 | 哈希算法抽象、hex编解码 |
| `src/digest/sha256.mbt` | ~180 | SHA-256 实现 |
| `src/digest/sha512.mbt` | ~200 | SHA-512 实现 |
| `src/digest/hmac.mbt` | ~80 | HMAC-SHA256 |
| `src/digest/utf8.mbt` | ~60 | UTF-8 编码 |
| `src/crypto/field25519.mbt` | ~230 | GF(2^255-19) 有限域 |
| `src/crypto/point25519.mbt` | ~200 | Curve25519 点运算 |
| `src/crypto/ed25519.mbt` | ~400 | Ed25519 签名/验签 |
| `src/merkle/merkle.mbt` | ~380 | Merkle 树 |
| `src/model/manifest.mbt` | ~250 | Manifest 数据模型 |
| `src/model/error.mbt` | ~80 | 错误码定义 |
| `src/model/version.mbt` | ~60 | 版本链模型 |
| `src/store/object_store.mbt` | ~190 | 内容寻址存储 |
| `src/diag/diag.mbt` | ~190 | 诊断报告 |
| `src/verify/verify.mbt` | ~210 | 7步验证管线 |
| `src/verify/chain.mbt` | ~160 | 版本链验证 |
| `src/verify/incremental.mbt` | ~200 | 增量验证 |
| `src/create/create.mbt` | ~110 | 证据包创建 |
| `src/audit/audit_log.mbt` | ~200 | 审计日志 |
| `src/api/api.mbt` | ~400 | JS 适配层 |
| `src/cmd/main/main.mbt` | ~500 | CLI 入口 |
| `src/cmd/main/main_native.mbt` | ~30 | native 平台 |
| `src/cmd/main/main_js.mbt` | ~30 | js 平台 |
| `src/cmd/main/main_wasm.mbt` | ~30 | wasm 平台 |
| `src/cmd/main/native_stub.c` | ~20 | C FFI（stderr） |
| `src/timing/main.mbt` | ~390 | native Ed25519 timing sampler |
| `src/timing/native_timing_stub.c` | ~70 | native 高精度计时与环境输出 FFI |

### 16.2 测试文件

| 文件路径 | 测试数 |
|---|---|
| `src/canonjson/canonjson_wbtest.mbt` | 23 |
| `src/canonjson/canonjson_jcs_wbtest.mbt` | 6 |
| `src/canonjson/canonjson_prop_wbtest.mbt` | 2 |
| `src/digest/digest_wbtest.mbt` | 9 |
| `src/digest/sha256_wbtest.mbt` | 10 |
| `src/digest/sha512_wbtest.mbt` | 6 |
| `src/digest/hmac_wbtest.mbt` | 6 |
| `src/digest/utf8_wbtest.mbt` | 8 |
| `src/digest/digest_bench_wbtest.mbt` | 2 |
| `src/crypto/ed25519_wbtest.mbt` | 17 |
| `src/crypto/ed25519_wycheproof_wbtest.mbt` | 9 |
| `src/crypto/field25519_wbtest.mbt` | 6 |
| `src/crypto/point25519_wbtest.mbt` | 7 |
| `src/merkle/merkle_wbtest.mbt` | 25 |
| `src/merkle/merkle_golden_wbtest.mbt` | 3 |
| `src/merkle/merkle_prop_wbtest.mbt` | 2 |
| `src/model/manifest_wbtest.mbt` | 26 |
| `src/model/version_wbtest.mbt` | 8 |
| `src/store/object_store_wbtest.mbt` | 16 |
| `src/diag/diag_wbtest.mbt` | 6 |
| `src/verify/verify_wbtest.mbt` | 15 |
| `src/verify/incremental_wbtest.mbt` | 14 |
| `src/verify/chain_wbtest.mbt` | 9 |
| `src/verify/verify_bench_wbtest.mbt` | 2 |
| `src/create/create_wbtest.mbt` | 10 |
| `src/audit/audit_log_wbtest.mbt` | 22 |
| `src/api/api_wbtest.mbt` | 39 |

### 16.3 关键文档

| 文件路径 | 用途 |
|---|---|
| `docs/ARCHITECTURE.md` | 当前分层、数据流、验证流程、信任边界和核心契约 |
| `docs/PROJECT_INDEX.md` | 项目入口索引 |
| `docs/spec/EVIDENCE_PACK_SPEC.md` | 证据包规范 + 错误码表 |
| `docs/report/DEVELOPMENT_REPORT.md` | 权威开发报告 |
| `docs/CODE_GUIDELINES.md` | 代码风格/注释/测试规则 |
| `docs/ROADMAP.md` | 路线图 |
| `docs/STRUCTURE_TREE.md` | 文件结构树 |
| `docs/BRANCH_COVERAGE.md` | 手工分支覆盖审计图：当前覆盖 verify/incremental/merkle/digest/crypto/create/store/audit/api 关键接受/拒绝/跳过/警告分支 |
| `docs/records/RESULTS_LOG.md` | 实测结果记录 |
| `docs/records/DECISION_LOG.md` | 决策记录 |
| `docs/records/ACCEPTANCE_CHECKLIST.md` | 验收清单 |
| `SECURITY.md` | 安全模型、保障范围、密钥职责、部署级别、版本支持和报告渠道 |
| `CONTRIBUTING.md` | 贡献指南 |
| `CHANGELOG.md` | 变更日志 |

### 16.4 CI/工具文件

| 文件路径 | 用途 |
|---|---|
| `.github/workflows/ci.yml` | CI 流水线（17步 + bench） |
| `.github/workflows/release.yml` | 发布流程 |
| `.github/workflows/README.md` | 流水线说明 |
| `tools/check-metrics.mjs` | 指标漂移门禁 |
| `tools/check-branch-coverage-stale.mjs` | 分支覆盖图防漂移门禁 |
| `tools/cross-verify.mjs` | 交叉对拍 |
| `tools/fuzz-api-malformed.mjs` | 公共 JS API malformed-request fuzz |
| `tools/property-api-semantic.mjs` | 公共 JS API semantic property 闭环检查 |
| `tools/randomized-hardening.mjs` | 随机化加固 profile 编排器（ci/release/stress） |
| `tools/timing-ed25519-verify.mjs` | Ed25519 verify JS 动态时序采样探针 |
| `tools/timing-ed25519-native.ps1` | Ed25519 native verify/sign dudect-style timing runner |
| `tools/mutation-check.mjs` | 变异测试 |
| `tools/gen-fixtures.mjs` | 夹具生成 |
| `tools/gen-merkle-fixtures.mjs` | Merkle 金色夹具 |
| `tools/gen-pack-fixture.mjs` | valid pack 夹具 |
| `tools/check-fixtures.mjs` | 夹具防腐化 |
| `tools/cli-test.ps1` | PowerShell 黑盒（54例） |
| `tools/cli-test.sh` | bash 黑盒（54例） |
| `tools/symlink-junction-probe.ps1` | Windows junction traversal probe：native/js create 自循环安全失败，verify 有界终止 |
| `tools/smoke-api.mjs` | API 烟测 |
| `tools/env-check.ps1` | 环境体检 |
| `tools/record-demo.ps1` | 演示录制 |
| `tools/play-demo.ps1` | 演示播放 |

### 16.5 项目配置

| 文件路径 | 用途 |
|---|---|
| `moon.mod` | 模块配置（名称、版本、依赖） |
| `src/*/moon.pkg` | 各包构建配置 |
| `.gitignore` | Git 忽略规则 |
| `.gitattributes` | Git 属性 |

---

## 17. 更新日志

| 日期 | 更新内容 | 更新者 |
|---|---|---|
| 2026-07-06 | 初始创建：完整架构/API/数据流/错误码/常量/测试覆盖/CI/工具链/安全治理/测试盲点/深度测试建议 | TRAE AI |
| 2026-07-06 | 补充 Ed25519 常量时间静态审计入口与 CT-001：`reduce_scalar_512` 仍有 secret-derived 分支，安全声明同步降级为真实状态 | Codex |
| 2026-07-06 | 修复 CT-001：`reduce_scalar_512` 比较/borrow 改为 arithmetic mask/selection，常量时间声明更新为源码审计级，并把 dudect/后端验证定义为生产化认证路线 | Codex |
| 2026-07-06 | 新增 `docs/BRANCH_COVERAGE.md`：首批 verify/incremental/merkle 分支审计 45 项，0 个 open gap，并记录后续扩展方向 | Codex |
| 2026-07-06 | 新增 `tools/check-branch-coverage-stale.mjs` 并接入 CI：已审计源码变更必须同步 review `docs/BRANCH_COVERAGE.md` | Codex |
| 2026-07-06 | 新增 `tools/fuzz-api-malformed.mjs` 并接入 CI：12 个公共 JS adapter 的 malformed request 必须不崩溃且返回稳定 JSON envelope | Codex |
| 2026-07-06 | 扩展 `docs/BRANCH_COVERAGE.md` 到 `src/api/api.mbt`：49 个公共 JS adapter 分支，stale-check 同步守护 API 源码 | Codex |
| 2026-07-06 | 新增 `tools/property-api-semantic.mjs` 并接入 CI：公共 JS adapter 的有效请求必须满足闭环不变量，且 proof/audit/signature 篡改必须被拒绝 | Codex |
| 2026-07-06 | 扩展 `tools/check-metrics.mjs`：新增 CLI_VERSION == moon.mod version 校验，关闭硬编码 CLI 版本漂移缺口 | Codex |
| 2026-07-06 | 新增 `tools/randomized-hardening.mjs`：把 CI、release、stress 三档随机化测试轮次固化成 profile，避免临时补丁式决定 fuzz/differential 深度 | Codex |
| 2026-07-06 | 实跑 `tools/randomized-hardening.mjs --profile release`：1000 malformed fuzz、256 semantic property、1000 Ed25519 differential、1000 digest differential 全部通过 | Codex |
| 2026-07-06 | Phase 3 收口：补 `diag` 单复数、`Fe::from_small`/`Fe::to_bytes` 边界测试；新增并实跑 `timing-ed25519-verify.mjs --samples 10000` | Codex |
| 2026-07-06 | 最终加固闭环：stress 随机化四段实跑；新增 Windows junction probe；create depth-cap abort 修复静默截断；CLI 黑盒升至 54/54 | Codex |
| 2026-07-07 | 新增 native Ed25519 timing evidence：`src/timing` + `tools/timing-ed25519-native.ps1`，50000 样本长跑覆盖 verify/sign-message/sign-secret，三项均 `|t| < 4.5`；更新侧信道边界为经验性证据而非形式化证明 | Codex |

---

## 附录：moon.mod 配置

```json
name = "starlittle/MoonEvidence"
version = "0.5.0"
readme = "README.md"
repository = "https://github.com/wenlittle/MoonEvidence.git"
license = "Apache-2.0"
keywords = ["evidence", "verification", "canonical-json", "merkle", "provenance"]
description = "Trusted evidence pack verification library and CLI for MoonBit."
import { "moonbitlang/x@0.4.45" }
options(exclude: ["docs/plans", "docs/research", "docs/report", "docs/records"])
```

## 附录：CHANGELOG 版本演进

| 版本 | 日期 | 里程碑 |
|---|---|---|
| 0.1.0 | 2026-06-11 | MVP，三后端全绿 |
| 0.2.0 | 2026-06-18 | 扩展为"能建能验"，HMAC/SHA-512/增量验证 |
| 0.3.0 | 2026-07-04 | Ed25519 数字签名 + 审计日志，仓库改名 starlittle |
| 0.3.1 | 2026-07-04 | 第二轮根因修复，合并两份开发报告，cli-test.sh 1:1 对等移植 |
| 0.4.0 | 2026-07-04 | Merkle 完整树物化 + 增量验证契约对齐 + CI 防漂移门禁 + Tamper Lab |
| 0.4.1 | 2026-07-09 | Mooncakes 包卫生同步 + 浏览器复现命令/API 文档收口 |
| 0.5.0 | 2026-07-11 | CLI 外部锚点机器合同 + 真实 Fabric 双组织摘要锚定闭环 |
