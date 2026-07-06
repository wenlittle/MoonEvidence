# MoonEvidence 测试计划

> **治理口径**：`docs/TEST_GOVERNANCE.md` 是质量门禁和停手规则；本文档是详细测试 backlog 与执行计划。

> **核心结论**：是的，必须先把测试计划完善并做好，再谈改进。具体而言——阶段1（P0高风险盲点）必须在任何密码学/安全路径改进之前完成，阶段2（P1安全网）在任何功能改进之前完成。
>
> **文档版本**：v1.0
> **最后更新**：2026-07-06
> **关联文档**：`docs/KNOWLEDGE_BASE.md` §8-§15；`docs/BRANCH_COVERAGE.md` 记录逐分支审计清单

> **2026-07-06 进度记录**：Phase 1 已完成七项加固：Wycheproof Ed25519 150 向量、Ed25519 精确分支 8 用例、store 完整性/严格重建 6 个独立 oracle、incremental golden manifest 5 个独立 oracle（含 Q3 缓存信任边界）、Ed25519 常量时间静态审计、create_manifest 5 个 panic 错误路径测试、CT-001 源码级修复。Phase 2 已开始：Ed25519 随机差分 oracle 入 CI，incremental 错误路径补齐 E1004/W1001/E3001，SHA/HMAC 随机差分 oracle 入 CI，Merkle 大规模/边界测试完成，mutation 扩展至 16/16 捕获，verify/incremental/merkle 首批分支审计完成并记录在 `docs/BRANCH_COVERAGE.md`。当前本地基线：`moon test --target js` 为 327/327 passed；`check-metrics` 口径为 331 个测试声明（327 可执行测试 + 4 基准 wrapper）。仍需注意：这是源码审计级常量时间结论，不等于 dudect/后端产物级证明。

---

## 0. 快速导航

| 想了解 | 跳转 |
|---|---|
| 为什么必须先测试后改进 | [§1 策略决策](#1-策略决策) |
| 测试体系有哪些系统性问题 | [§2 系统性缺陷诊断](#2-系统性缺陷诊断) |
| 测试分几层、每层做什么 | [§3 九层测试模型](#3-九层测试模型) |
| 分几个阶段、每阶段做什么 | [§4 分阶段实施计划](#4-分阶段实施计划) |
| 具体要写哪些测试用例 | [§5 测试用例清单](#5-测试用例清单) |
| 怎么度量覆盖率 | [§6 覆盖率度量方案](#6-覆盖率度量方案) |
| 改进前要过什么检查 | [§7 改进安全检查清单](#7-改进安全检查清单) |
| 测试用例怎么设计 | [§8 测试用例设计规范](#8-测试用例设计规范) |

---

## 1. 策略决策

### 1.1 结论：分阶段"先测试后改进"

| 改进类型 | 前置条件 | 理由 |
|---|---|---|
| **crypto/digest/merkle 包的任何改进** | 阶段1全部完成 | 当前4个高风险盲点全在密码学核心，无安全网 |
| **verify/create/store 包的功能改进** | 阶段1 + 阶段2完成 | 需要错误路径测试和增量验证对称性测试 |
| **diag/model 等非安全包改进** | 阶段1完成即可 | 不涉及安全语义，有基本安全网即可 |
| **CLI/CI 治理改进** | 可与阶段2并行 | 不影响核心验证逻辑 |

### 1.2 为什么不能"边测边改"

| 风险 | 说明 |
|---|---|
| **回归不可归因** | 改了 verify 又改了 incremental，某个测试红了，无法判断是哪边引入的（因为两边都缺错误路径测试） |
| **确认偏差** | 改完代码再写测试，测试者会下意识选能通过的输入，弱化了测试的证伪能力。这正是 H1/H2 产生的心理根源 |
| **改进被测试债务绑架** | 想优化 `reduce_scalar_512`，但发现没有常量时间测试，改完无法验证是否破坏了时序安全性，只好不敢改 |
| **密码学安全回归不可检测** | `ed25519_verify` 的输入长度检查（L245）和低阶点拒绝（L280）完全未测。若改进时意外移除这些 guard，无测试会变红，可能导致伪造签名被接受 |

### 1.3 为什么不能"全部补完再改"

| 限制 | 说明 |
|---|---|
| **H4 常量时间计时测试成本高** | 需要 native 后端 + dudect 风格统计框架，可能需 C 扩展，工期长 |
| **Wycheproof 级别消极向量集** | 需要上千用例的移植，一次性投入大 |
| **某些盲点需要改进代码才能测** | 如 L4/L5 的 Fe 内部分支，若函数不可观察中间状态，需先重构出可测试接口 |
| **纯补测试不改代码可能补出脆弱测试** | over-fitting 到当前实现，后续改进时大量测试红 |

---

## 2. 系统性缺陷诊断

### 2.1 五大根因

| 根因 | 涉及盲点 | 本质 |
|---|---|---|
| **A: Happy-path bias** | H1, H3, M1, L1, L7 | 测试用例从"功能说明书"正向生成（能做什么），而非从"输入空间划分"逆向生成（每种输入该返回什么） |
| **B: 无分支覆盖率模型** | H2, H3, L2-L6 | MoonBit 缺乏成熟 coverage 工具，只能靠"331个测试声明"粗粒度指标，无法看到哪些分支从没被触达 |
| **C: 密码学测试未对标行业标准** | H2, H3, H4 | RFC 8032 §7.1 KAT + Wycheproof Ed25519 150 向量已覆盖签名 oracle；仍缺 dudect 侧信道验证 |
| **D: 安全函数测试优先级被低估** | M2, M3 | 功能路径先测，防篡改/防绕过的安全函数后测甚至不测 |
| **E: 测试资产双轨漂移** | 6项治理缺口 | cli-test.ps1 与 cli-test.sh 已对齐到 53 例；后续仍需防止人工移植漂移 |

### 2.2 结构性失衡

| 指标 | 数据 | 含义 |
|---|---|---|
| 鲁棒性缺失占比 | 13/17 = **76%** | 76%的盲点都是"没测异常路径"，不是个别遗漏而是默认取向 |
| 密码学测试三支柱 | 只剩1根（KAT） | 缺消极向量集 + 缺侧信道验证 = 结构性缺陷 |
| 测试用例生成方式 | 仅3种（KAT+手工攻击+3个属性测试） | 缺差分测试 + 缺模糊测试 = 只能测"想到的" |
| 覆盖率度量 | "331个测试声明" + `docs/BRANCH_COVERAGE.md` 首批分支图 | 数量指标只能说明测试规模；分支图回答 verify/incremental/merkle 的关键分支是否有证据覆盖 |

---

## 3. 九层测试模型

### 层次总览

| 层次 | 名称 | 现状 | 目标 | 优先级 |
|---|---|---|---|---|
| L0 | 单元测试（白盒） | 331个声明（327可执行+4基准wrapper）+ verify/incremental/merkle 首批分支图 | 扩展分支审计到 digest/crypto/create/store/audit | P0/P1 |
| L1 | 集成测试 | ~15个 | +10（跨包闭环） | P1 |
| L2 | 属性测试 | 3个 | +8（Ed25519/Fe/canonjson扩展） | P1 |
| L3 | 差分测试 | 固定夹具 | +随机差分harness（Ed25519/SHA/HMAC） | P1 |
| L4 | CLI黑盒 | ps1=53, sh=53 | 后续改 CLI 时双脚本同步 | P1 |
| L5 | 变异测试 | 16点 | 继续按高风险改动补点 | P1 |
| L6 | 模糊测试 | 无 | 10000轮随机输入不崩溃 | P2 |
| L7 | 性能/基准 | 仅js | +native/wasm-gc + Ed25519基准 | P2 |
| L8 | 安全测试（侧信道） | 无 | 静态审计清单 + 轻量计时统计 | P1 |

### 各层详细定义

#### L0 单元测试

- **目标**：每个函数/方法在隔离环境下的正确性，包括正常路径、边界值、错误路径
- **方法**：MoonBit 白盒测试（`*_wbtest.mbt`），可访问私有成员
- **验收标准**：每个公开函数至少1个正常路径+1个错误路径；每个 `return None`/`return false`/`abort` 分支至少1个触发测试；`moon test --target wasm-gc,js,native` 全绿

#### L1 集成测试

- **目标**：跨包协作正确性，特别是 create→verify 往返闭环
- **覆盖**：create→verify_manifest、create→incremental→verify、create→store→reconstruct→verify、chain 链式验证
- **验收标准**：每个L2层管线至少1个完整闭环；每个算法×每个路径至少1个

#### L2 属性测试

- **目标**：通过随机化输入验证不变式，覆盖人工难以枚举的边界
- **方法**：手写 PRNG（splitmix64），零依赖、确定性种子、可复现
- **验收标准**：每个属性测试至少60轮随机化；失败消息携带轮次号

#### L3 差分测试

- **目标**：用独立实现（Node.js crypto）交叉验证，捕获"自我验证自我"的盲区
- **现状**：`cross-verify.mjs` 只对固定金色夹具做对拍
- **目标**：升级为随机输入差分，覆盖 SHA-256/SHA-512/Ed25519/HMAC
- **验收标准**：CI 固定轮次差分全绿；发布候选 1000 组随机向量字节级一致

#### L4 CLI黑盒

- **目标**：从CLI边界验证端到端行为
- **验收标准**：PowerShell和bash两套用例数完全一致；每个错误码至少1个触发用例

#### L5 变异测试

- **目标**：通过注入人工变异验证测试套件的"牙齿"
- **现状**：16个变异点，全部被捕获
- **目标**：已扩展到16个，保持100%捕获率；后续随高风险改动继续补点
- **验收标准**：0个变异逃逸

#### L6 模糊测试

- **目标**：大规模随机输入发现崩溃/panic/未处理边界
- **方法**：MoonBit 无原生fuzzing框架，用属性测试扩展（轮次10000+）或 Node.js fuzz harness 调用JS构建产物
- **验收标准**：10000轮随机输入无崩溃

#### L7 性能/基准

- **目标**：跟踪性能回归
- **现状**：仅js目标，2个基准
- **目标**：+native/wasm-gc + Ed25519签名/验证基准 + 大规模Merkle基准
- **验收标准**：三目标覆盖；结果记录在 RESULTS_LOG

#### L8 安全测试（侧信道）

- **目标**：验证密码学实现不在秘密依赖的数据上分支
- **方法**：静态审计（分支清单）+ 动态时序测量（Node.js performance.now 统计）
- **验收标准**：静态审计清单完成；Ed25519验证时序方差不随输入变化

---

## 4. 分阶段实施计划

### 阶段1（P0：必须先做，阻断性）

> **原则**：这些测试保护的是密码学安全核心。在此阶段完成前，禁止修改 `src/crypto/` 下的任何文件。

| 序号 | 盲点 | 层次 | 目标文件 | 测试用例 | 依赖 |
|---|---|---|---|---|---|
| 1.1 | Ed25519错误长度输入 | L0 | `ed25519_wbtest.mbt` | pk=31/33字节、sig=63/65字节，均 assert_false | 无 |
| 1.2 | point_decode无效点 | L0 | `ed25519_wbtest.mbt` | 非曲线y值、x²≠x2路径、data长度≠32 | 无 |
| 1.3 | x=0+sign=1 | L0 | `ed25519_wbtest.mbt` | 构造使x=0且sign=1的输入，assert None | 需计算满足条件的y值 |
| 1.4 | 常量时间静态审计 | L8 | `docs/CONST_TIME_AUDIT.md` | 分支清单：scalar_mul/fe_cmov/Fe::eq/Fe::to_bytes/reduce_scalar_512 中所有涉及秘密数据的分支；CT-001 已源码级修复 | 无 |
| 1.5 | create abort分支 | L0 | `create_wbtest.mbt` | 空subject.id、空subject.kind、空version_id、空version_parent、无效路径 | 已用 `panic` 测试覆盖 |
| 1.6 | store安全函数 | L0 | `object_store_wbtest.mbt` | verify_integrity内容篡改→false、reconstruct_strict缺失→Err、remove不存在→false | 无 |
| 1.7 | 增量验证缓存篡改 | L1 | `incremental_wbtest.mbt` | 篡改缓存使坏文件跳过哈希、缓存指向不存在文件 | 无 |

**已完成（2026-07-06）**：
- `src/crypto/ed25519_wycheproof_wbtest.mbt`：150 条 Wycheproof Ed25519 向量（88 valid + 62 invalid），并补 `tools/check-wycheproof-ed25519.mjs` 清点门禁。
- `src/crypto/ed25519_wbtest.mbt`：8 个精确分支测试，覆盖 pk/sig 长度 guard、`point_decode` 长度 guard、非曲线 y、`x=0 && sign=1`、sqrt(-1) 修正路径、verify 的 pk/R 解码失败分支。
- `src/store/object_store_wbtest.mbt`：6 个 independent oracle，绕过 `put()`/`sha256_hex`，覆盖篡改、缺失、多缺失、严格重建成功/失败。
- `src/verify/incremental_wbtest.mbt`：5 个 golden manifest independent oracle，覆盖全缓存、空缓存、E2004 正反例、Q3 恶意缓存信任边界。
- `docs/CONST_TIME_AUDIT.md`：Ed25519 静态常量时间审计，区分 secret path 与 public-input rejection path；CT-001 已修复为 arithmetic mask/borrow selection。
- `src/create/create_wbtest.mbt`：5 个 `panic` 测试覆盖 `create_manifest` 的空 subject.id、空 subject.kind、空 version_id、空 version_parent、非法路径 abort 分支。

**仍需完成**：Phase 1 测试项与 CT-001 源码级修复已收口；生产级侧信道声明仍需 dudect/后端产物审计。

**工作量**：约15-20个测试用例，2-3天专注工作

**验收门禁**：
- 三目标全绿
- 变异测试保持16/16捕获率
- 新增变异点（1.2/1.3对应）也被捕获

### 阶段2（P1：建立安全网，应在改进前完成）

> **原则**：阶段1完成后进行，提升测试覆盖完整性和CI防护力。

| 序号 | 内容 | 层次 | 依赖 |
|---|---|---|---|
| 2.1 | 大规模Merkle树（10000叶闭环） | L1/L7 | Done: boundary shapes 2^k-1/2^k/2^k+1 plus 10000-leaf SHA-256/SHA-512 roots and representative inclusion proofs |
| 2.2 | SHA-512路径（merkle/verify/incremental） | L0/L3 | 阶段1 |
| 2.3 | 增量验证错误路径（E1004/E2003/E2004/E3001/E3003/W1001） | L0 | Done: incremental_wbtest covers E1004, E2003, E2004, E3001 (missing root and empty tree), E3003, and W1001 |
| 2.4 | bash cli-test补齐Part4+Part5（12例） | L4 | Done: `cli-test.sh` now covers 53/53 cases and CI runs bash parity for native/js |
| 2.5 | CLI_VERSION CI门禁 | L4/治理 | 无 |
| 2.6 | Ed25519属性测试（sign→verify往返60轮 + 篡改检测120轮） | L2 | 阶段1 |
| 2.7 | Fe域运算属性（分配律/交换律/可逆性60轮） | L2 | 无 |
| 2.8 | 变异测试扩展（已扩展到16个变异点） | L5 | 阶段1 |
| 2.9 | 基准测试扩展（native/wasm-gc + Ed25519基准） | L7 | 无 |
| 2.10 | point_decode边界（y=p/p+1/2p-1 + sign=0/1组合） | L0 | 阶段1 |
| 2.11 | Ed25519差分测试（Node.js crypto 随机向量；CI 64组，发布候选1000组） | L3 | Done: `tools/differential-crypto.mjs` compares key derivation, signatures, cross-verification, and tamper rejection against Node.js crypto |
| 2.12 | SHA/HMAC差分测试（随机长度0-65536字节） | L3 | Done: `tools/differential-digest.mjs` compares SHA-256/SHA-512/HMAC-SHA256 against Node.js crypto; CI runs 64 rounds, release candidates can run 1000 |
| 2.13 | 分支清单审计（verify/incremental/merkle 首批） | L0/L8 | Done: `docs/BRANCH_COVERAGE.md` maps 45 audited branches with 0 open gaps for the first pass |

**工作量**：约30-40个测试用例 + 12个CLI用例 + 已完成的变异点扩展，4-6天

**验收门禁**：
- 变异测试捕获率 16/16 = 100%
- bash 和 PowerShell CLI 用例数一致（53/53）
- CI 增加 CLI_VERSION 门禁步骤
- Ed25519 差分测试 CI 64 组全通过；发布候选手动 `--rounds 1000` 全通过

### 阶段3（P2：技术债务，择机补）

> **原则**：不阻塞改进工作，在每次相关功能改进时顺带补。

| 序号 | 内容 | 层次 |
|---|---|---|
| 3.1 | diag单复数分支 | L0 |
| 3.2 | parse_digest失败分支（无冒号/未知算法/非hex） | L0 |
| 3.3 | Fe::from_small / Fe::to_bytes条件减p 直接测试 | L0 |
| 3.4 | 模糊测试harness（10000轮随机输入不崩溃） | L6 |
| 3.5 | 动态时序测量（Ed25519验证10000次采样+统计） | L8 |
| 3.6 | E3002覆盖（实现proof CLI 或记录为保留码） | L4 |
| 3.7 | 符号链接缓解验证 | L8 |
| 3.8 | Wycheproof EdDSA测试向量移植 | L0（已提前完成 Ed25519 150 向量；后续可扩展到来源生成/差分复核） |

**工作量**：约15-20个测试用例 + fuzzing/timing harness，3-5天

---

## 5. 测试用例清单

### 5.1 阶段1详细用例

#### 1.1 Ed25519错误长度输入（4例）

```moonbit
test "ed25519_verify rejects 31-byte public key" {
  let short_pk = Bytes::make(31, b'\x00')
  let msg = Bytes::empty()
  let sig = Bytes::make(64, b'\x00')
  assert_false(ed25519_verify(short_pk, msg, sig))
}

test "ed25519_verify rejects 33-byte public key" { ... }
test "ed25519_verify rejects 63-byte signature" { ... }
test "ed25519_verify rejects 65-byte signature" { ... }
```

**覆盖分支**：`ed25519.mbt:245` — `sig.length() != 64 || pk.length() != 32`

#### 1.2 point_decode无效点（3例）

```moonbit
test "point_decode rejects data not on curve" {
  // 构造 y 值使 -x^2 + y^2 != 1 + d*x^2*y^2
  // 乘以 sqrt(-1) 后仍不匹配 → return None
}

test "point_decode triggers sqrt(-1) multiplication path" {
  // 构造 y 使 (y^2-1)/(d*y^2+1) 的平方根需要乘以 sqrt(-1)
  // 但乘以后 x^2 == x2 → 正确解码
}

test "point_decode rejects wrong length (31 bytes)" {
  let bad = Bytes::make(31, b'\x00')
  assert_true(point_decode(bad) is None)
}
```

**覆盖分支**：`ed25519.mbt:335`（长度）、`:362-364`（sqrt(-1)路径）、`:365-367`（不在曲线上）

#### 1.3 x=0+sign=1（1例）

```moonbit
test "point_decode rejects x=0 with sign=1 (RFC 8032 §5.1.3)" {
  // identity point (x=0, y=1) 的编码，但 sign bit 设为 1
  // 编码: 0x81 + 31 个 0x00
  let bad_enc : Array[Byte] = [b'\x81']
  for _ in 0..<31 { bad_enc.push(b'\x00') }
  let pk = Bytes::from_array(bad_enc)
  assert_true(point_decode(pk) is None)
}
```

**覆盖分支**：`ed25519.mbt:375-377` — `x.eq(Fe::zero()) && sign == 1`

#### 1.4 常量时间静态审计

产出文档 `docs/CONST_TIME_AUDIT.md`，包含分支清单：

| 函数 | 行号 | 分支类型 | 涉及秘密 | branchless? | 备注 |
|---|---|---|---|---|---|
| `Fe::eq` | field25519.mbt:199-207 | XOR累积比较 | 两个Fe值 | ✅ | XOR累加，无分支 |
| `fe_cmov` | field25519.mbt:214-227 | 条件拷贝 | Fe值+条件 | ✅ | OR掩码，无分支 |
| `point_cmov` | point25519.mbt:129-136 | 条件拷贝 | Point值+条件 | ✅ | 逐limb cmov |
| `scalar_mul` | point25519.mbt:144-161 | double-and-add | 标量 | ✅ | 每bit都执行add+double |
| `reduce_scalar_512` | ed25519.mbt:81-153 | 算术 mask + 条件减法 | 512位标量 | ✅ | 比较用 `byte_gt_mask`/`byte_lt_mask`，borrow 用算术选择，无源码级 secret-dependent 分支 |
| `Fe::to_bytes` | field25519.mbt:161-186 | 条件减p | Fe值 | ✅ | borrow计算无分支 |
| `scalar_lt_l` | ed25519.mbt:223-239 | **逐字节比较** | verify 的公开 S 字段 | ⚠️ | 有 early return，但当前只用于公开签名输入 |
| `point_decode` sign检查 | ed25519.mbt:371-375 | **sign bit分支** | 解码点 | ⚠️ | **有if分支** |

**已知非常量时间/需保守声明路径**：
- `scalar_lt_l` 的 `sv < lv` / `sv > lv` early return（当前仅用于 verify 的公开 S 字段，可接受；不可复用到 secret scalar）。
- `point_decode` 的 `x_sign != sign` 和 `x.eq(Fe::zero()) && sign == 1` 分支（当前仅用于 verify 的公开 pk/R，可接受）。
- `reduce_scalar_512` 的 CT-001 已在源码级修复；仍需后端产物/动态时序验证，才能作生产级侧信道声明。

#### 1.5 create abort分支（5例）

```moonbit
test "panic create_manifest rejects empty subject id" {
  let options = CreateOptions::{ subject: SubjectInfo::{ id: "", kind: "test" }, ... }
  ignore(create_manifest(options))
}
// 类似: 空 subject.kind、空 version_id、空 version_parent、非法路径
```

**实际实现**：MoonBit 测试名以 `panic` 开头时，测试只有在触发 panic/abort 时才通过。当前已在
`src/create/create_wbtest.mbt` 中落地 5 个 `panic` 测试，覆盖空 `subject.id`、空 `subject.kind`、
空 `version_id`、空 `version_parent`、非法路径 5 条 abort/error-path 分支。此处没有改
`create_manifest` API，也没有把 `abort` 临时重构成 `Result`，避免为了测试引入行为变更。

#### 1.6 store安全函数（3例）

```moonbit
test "verify_integrity returns false when content is tampered" {
  let result = deduplicate(files)
  // 篡改 store 中的某个对象
  result.store.objects[hash] = Bytes::of_string("tampered")
  assert_false(result.verify_integrity())
}

test "reconstruct_strict returns Err when content is missing" {
  let result = deduplicate(files)
  // 删除 store 中的某个对象
  result.store.remove(hash)
  assert_true(result.reconstruct_strict() is Err(_))
}

test "remove returns false for non-existent hash" {
  let store = ObjectStore::new()
  assert_false(store.remove("sha256:nonexistent"))
}
```

#### 1.7 增量验证缓存篡改（2例）

```moonbit
test "incremental verify with tampered cache skips rehashing of bad file" {
  // 构造 manifest + files，验证通过
  // 篡改 cache.json 中的某个 digest 为正确值
  // 修改对应文件内容
  // 增量验证应该跳过该文件（因为缓存匹配）
  // 但 Merkle 根仍会检测到不匹配 → E3003
  // 验证：文档化的信任模型边界
}

test "incremental verify with cache pointing to missing file" {
  // cache 中有路径但 files 中没有
  // 预期: E2003
}
```

### 5.2 阶段2关键用例

#### 2.6 Ed25519属性测试

```moonbit
test "ed25519 sign→verify round-trip property (60 rounds)" {
  let rng = PropRng::make(0xED25519)
  for round in 0..<60 {
    let sk = random_bytes(rng, 32)
    let msg = random_bytes(rng, rng.below(256))
    let pk = ed25519_public_key(sk)
    let sig = ed25519_sign(sk, msg)
    assert_true(ed25519_verify(pk, msg, sig))
  }
}

test "ed25519 tamper detection property (120 rounds)" {
  let rng = PropRng::make(0xTAMPER)
  for round in 0..<120 {
    let sk = random_bytes(rng, 32)
    let msg = random_bytes(rng, rng.below(256))
    let pk = ed25519_public_key(sk)
    let sig = ed25519_sign(sk, msg)
    // 翻转 msg/sig/pk 的随机1字节
    let tampered = flip_random_byte(rng, msg)  // 或 sig 或 pk
    assert_false(ed25519_verify(pk, tampered, sig))
  }
}
```

#### 2.11 Ed25519差分测试

```javascript
// tools/differential-crypto.mjs
// CI: node tools/differential-crypto.mjs --rounds 64
// Release candidate: node tools/differential-crypto.mjs --rounds 1000
//
// Uses deterministic SplitMix64 seeds/messages and Node.js crypto Ed25519
// as the independent oracle for the compiled MoonBit JS API.
```

**实际检查**：公钥推导一致、确定性签名逐字节一致、Node 接受 MoonBit 签名、MoonBit 接受
Node 签名、篡改消息被 MoonBit 拒绝。该脚本不把向量固化进仓库，避免 fixture 腐化；随机源是
固定种子 PRNG，所以失败可复现。

---

## 6. 覆盖率度量方案

### 6.1 多维度度量

| 维度 | 方法 | 目标 | 当前 |
|---|---|---|---|
| **MoonBit覆盖率** | `moon test --enable-coverage` | 行覆盖 >90% | 未测量 |
| **变异测试得分** | `mutation-check.mjs` | 100%捕获 | 16/16 (100%) |
| **分支清单审计** | `docs/BRANCH_COVERAGE.md` 人工逐包建立分支清单 | 100%关键分支有触发测试或明确 accepted-risk | verify/incremental/merkle 首批 45 个分支，0 个 open gap |
| **错误码触发覆盖** | CLI黑盒断言 | 100%（除E3002保留） | ~95% |
| **指标漂移守卫** | `check-metrics.mjs` | 0 mismatch | 0 |

### 6.2 分支清单审计方法

对每个包执行：
1. Grep 搜索 `return None`、`return false`、`abort(`、`return Err`、`catch`
2. 建立分支清单表格（文件、行号、触发条件、是否被测试覆盖）
3. 逐个编写触发测试

**示例：ed25519.mbt 分支清单**

| 行号 | 分支条件 | 触发输入 | 覆盖状态 | 测试ID |
|---|---|---|---|---|
| 245 | `sig.length() != 64` | sig=63字节 | ❌ TODO | 1.1 |
| 245 | `pk.length() != 32` | pk=31字节 | ❌ TODO | 1.1 |
| 260 | `!scalar_lt_l(s_enc)` | S=l | ✅ 已测 | ed25519_wbtest #12 |
| 264 | `point_decode(pk) = None` | 非规范y=pk | ❌ TODO | 1.2 |
| 271 | `a_point.is_identity()` | identity点pk | ✅ 已测 | ed25519_wbtest #14 |
| 280 | `a_doubled.is_identity()` | 低阶点(0,-1) | ✅ 已测 | ed25519_wbtest #15 |
| 284 | `point_decode(r_enc) = None` | 非规范R | ❌ TODO | 1.2 |
| 335 | `data.length() != 32` | data=31字节 | ❌ TODO | 1.2 |
| 350 | `y_original != y.to_bytes()` | y=p | ✅ 已测 | ed25519_wbtest #13 |
| 362 | `x.square().eq(x2) == false` (第一次) | 特定y值 | ❌ TODO | 1.2 |
| 365 | `x.square().eq(x2) == false` (第二次) | 非曲线点 | ❌ TODO | 1.2 |
| 375 | `x.eq(Fe::zero()) && sign == 1` | x=0+sign=1 | ❌ TODO | 1.3 |

---

## 7. 改进安全检查清单

> 在任何代码改进合并前，必须通过以下检查。

```
[ ] 该改进涉及的包是否有未覆盖的盲点？（查本文档 §5）
    [ ] 若有高风险盲点 → 改进 BLOCKED，先补测试（阶段1）
    [ ] 若有中低风险盲点 → 改进 ALLOWED，但须在同PR中补测试

[ ] 该改进是否涉及 crypto/digest/merkle 包？
    [ ] 是 → 变异测试是否新增了对应变异点且被捕获？
    [ ] 是 → 常量时间审计清单是否复查通过？（查 §5.1.4）

[ ] 该改进是否涉及 CLI 行为？
    [ ] 是 → bash 和 PowerShell CLI 测试是否都更新？
    [ ] 是 → 三目标（wasm-gc/js/native）是否都验证？

[ ] 该改进是否改变错误码行为？
    [ ] 是 → 分支清单是否更新？
    [ ] 是 → CLI测试的错误码多集断言是否更新？

[ ] 指标漂移守卫是否通过？（node tools/check-metrics.mjs）
[ ] 变异测试是否全绿？（node tools/mutation-check.mjs）
[ ] 交叉对拍是否全绿？（node tools/cross-verify.mjs）
```

---

## 8. 测试用例设计规范

### 8.1 密码学测试：标准向量对照

| 算法 | 标准来源 | 现有 | 需补充 |
|---|---|---|---|
| SHA-256 | NIST FIPS 180-4 + CAVP | 4个NIST向量 | 块边界（55/56/64字节） |
| SHA-512 | NIST FIPS 180-4 | 3个NIST向量 | 多块（>128字节）+ 百万'a' |
| Ed25519 | RFC 8032 §7.1 | 4组KAT | Wycheproof消极向量 + orlp/ed25519 1024组 |
| Merkle | RFC 6962 | golden向量 | SHA-512变体 + 大规模树 |

### 8.2 边界值枚举

| 模块 | 边界值 | 确定依据 |
|---|---|---|
| Fe (GF(2^255-19)) | 0, 1, p-1, p, p+1, 2p-1, 2^256-1 | 素数域规范表示边界 |
| Ed25519 S字段 | 0, l-1, l, l+1, 2^256-1 | RFC 8032 §8.4 S<l 检查边界 |
| Ed25519 公钥点 | identity(0,1), (0,-1), base, y=p, y=p+1 | RFC 8032 §5.1.3 规范编码边界 |
| SHA-256 输入 | 0, 55, 56, 64, 111, 112字节 | 填充块边界 |
| Merkle叶子数 | 0, 1, 2, 3, 2^k-1, 2^k, 2^k+1, 10000 | 树高度变化 + 奇偶提升 + 规模 |

### 8.3 错误路径系统化覆盖

对每个包：
1. Grep 搜索所有错误出口（`return None`/`return false`/`abort`/`return Err`/`catch`）
2. 建立分支清单表格
3. 对每个未覆盖的错误出口，构造能精确触发该分支的输入
4. 在测试计划中记录映射关系

---

## 9. 风险登记册

| 风险ID | 描述 | 概率 | 影响 | 缓解措施 |
|---|---|---|---|---|
| RISK-001 | 密码学改进引入安全回归但未被检测 | 高 | 严重 | 阶段1先补测试；禁止在阶段1前改 crypto/ |
| RISK-002 | abort分支无法在测试中捕获 | 中 | 中 | 改为Result类型（测试驱动的改进） |
| RISK-003 | 改进后变异测试逃逸率上升 | 中 | 高 | 变异点与源码行号绑定；扩展优先于改进 |
| RISK-004 | 常量时间属性被破坏 | 中 | 严重 | 静态审计前置；审计清单纳入代码审查 |
| RISK-005 | bash CLI测试盲区导致CI通过但行为退化 | 低 | 高 | 已补齐到53例；CI native/js 同跑 bash 与 PowerShell |
| RISK-006 | 性能优化引入native/wasm-gc特有bug | 低 | 严重 | 三目标基准；基准非阻塞但记录 |

---

## 10. 变更历史

| 日期 | 变更内容 | 变更人 |
|---|---|---|
| 2026-07-06 | 初始版本：基于3个子线程深度分析，确定"先测试后改进"策略，设计9层测试模型和3阶段实施计划 | TRAE AI |
| 2026-07-06 | Phase 1 部分落地：Wycheproof Ed25519、store independent oracle、incremental golden oracle；记录 304/304 实跑与 308 声明口径差异 | Codex |
| 2026-07-06 | Phase 1 Ed25519 精确分支收口：新增 8 个白盒测试，记录 312/312 实跑与 316 声明口径差异 | Codex |
| 2026-07-06 | Phase 1 create abort 收口：新增 5 个 panic 测试，记录 317/317 实跑与 321 声明口径差异；CT-001 保持为实现风险 | Codex |
| 2026-07-06 | CT-001 源码级修复：`reduce_scalar_512` 比较/borrow 改为 arithmetic mask/selection；Phase 1 源码与测试治理收口 | Codex |
| 2026-07-06 | Phase 2 首批分支清单审计：新增 `docs/BRANCH_COVERAGE.md`，覆盖 verify/incremental/merkle 45 个关键分支，0 个 open gap | Codex |
