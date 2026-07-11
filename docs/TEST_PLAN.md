# MoonEvidence 测试计划

> 基线版本：v0.5.0
>
> 最近复核：2026-07-11 Asia/Shanghai
>
> 治理规则：[TEST_GOVERNANCE.md](TEST_GOVERNANCE.md)
>
> 实测记录：[RESULTS_LOG.md](records/RESULTS_LOG.md)

MoonEvidence 的测试围绕证据结论建立。每一层证据对应一个明确风险，能够指出什么被验证、由谁给出预期结果、实现出错时哪一道门禁会失败。

## 1. 质量目标

| 目标 | 需要守住的结论 | 失败信号 |
| --- | --- | --- |
| 文件完整性 | 当前文件字节与 manifest 记录一致 | `E2003`、缺失文件或摘要不一致 |
| 清单稳定性 | 相同语义生成相同规范字节和摘要 | 独立摘要不同、`E2004` |
| Merkle 一致性 | 文件集合、顺序和证明路径可复核 | 根摘要或包含证明不一致 |
| 签名正确性 | 有效 Ed25519 签名通过，异常编码和攻击输入被拒绝 | 标准向量、攻击向量或差分结果失败 |
| 审计连续性 | 条目顺序、前驱摘要和签名保持完整 | 链断裂、条目签名失败 |
| 缓存和对象存储 | 信任范围清楚，内容篡改和缺失对象可定位 | 完整性检查误报通过、严格重建未拒绝 |
| 机器接口 | CLI 和浏览器返回稳定结构、错误码和退出码 | 黑盒结果或 JSON 合同漂移 |
| 外部锚点 | 账本记录与本地规范摘要一致 | 提交前检查失败、回灌出现 `E2004` |

测试证据按以下路径逐层增强：

```mermaid
flowchart LR
    A["标准样例"] --> B["独立参考"]
    B --> C["单元与分支"]
    C --> D["属性与随机差分"]
    D --> E["故障注入"]
    E --> F["CLI 与浏览器"]
    F --> G["多后端 CI"]
    G --> H["Fabric 实链"]
```

标准样例固定已知答案，独立参考打破实现自证，随机化扩大输入空间，故障注入确认测试确实会失败，进程和实链实验覆盖系统边界。

## 2. 风险矩阵

| 信任边界 | 主要风险 | 核心证据 | 阻断门禁 |
| --- | --- | --- | --- |
| Canonical JSON | 字段顺序、转义或数字语义漂移 | RFC 8785 样例、性质测试、固定夹具 | 包测试、夹具重生成 |
| SHA-2 / HMAC | 填充边界、多块输入或算法分派错误 | NIST/RFC 样例、Node.js 随机差分 | digest 测试、差分门禁 |
| Merkle | 叶子域分隔、奇数提升或路径方向错误 | 独立金色根、规模边界、包含证明性质 | merkle 测试、cross-verify、mutation |
| Ed25519 | 非规范编码、可塑性、低阶点或标量边界被接受 | RFC 8032、Wycheproof、Node.js 差分、精确分支测试 | crypto 测试、向量清点、mutation |
| Manifest | 非法路径、字段约束或版本关系被接受 | 结构矩阵、路径矩阵、创建异常测试 | model/create 测试、CLI 黑盒 |
| 完整验证 | 文件、Merkle 根或外部摘要漏检 | 独立夹具、异常包、完整错误集合 | verify 测试、CLI 黑盒、mutation |
| 增量验证 | 缓存越过内容检查，或与完整验证语义分叉 | golden manifest、恶意缓存边界、差分结果 | incremental 测试、mutation |
| 对象存储 | 自生成摘要掩盖篡改，缺失对象未拒绝 | 硬编码独立摘要、直接篡改对象 Map | store 测试、mutation |
| 审计链 | 条目重排、前驱断裂或签名覆盖不完整 | 规范条目、签名篡改、JSON 往返 | audit/API 测试、property |
| CLI / API | 参数、JSON、退出码或错误码漂移 | 双 shell 黑盒、malformed fuzz、浏览器 smoke | required CI |
| 文件系统 | 路径逃逸、链接循环或遍历失控 | 路径拒绝矩阵、Windows junction probe | create/CLI 测试、手动安全探针 |
| Fabric | 本地失败仍提交、重复记录改变、回执不一致 | Gateway 单测、Chaincode race 测试、双组织实验 | Fabric required job、协议复跑 |

详细分支映射位于 [BRANCH_COVERAGE.md](BRANCH_COVERAGE.md)。该清单覆盖安全相关的接受、拒绝、跳过和警告路径，并由源码变更防漂移脚本维护。

## 3. 证据分层

### 3.1 已知答案

这一层使用外部标准和手工边界值固定结果：

- SHA-256、SHA-512 使用 NIST 样例和填充边界。
- HMAC-SHA256 使用 RFC 2104 结果。
- Ed25519 使用 RFC 8032 的 4 条样例。
- Canonical JSON 使用 RFC 8785 语义。
- Manifest、路径和错误码使用明确的输入分区表。

### 3.2 独立参考

Node.js `crypto` 和独立生成的固定夹具提供第二套实现：

- `tools/cross-verify.mjs` 重算证据包摘要和 Merkle 根。
- `tools/differential-crypto.mjs` 对比公钥、签名、交叉验签和篡改拒绝。
- `tools/differential-digest.mjs` 对比 SHA-256、SHA-512 和 HMAC-SHA256。
- store 和 incremental 测试直接使用外部固定摘要，绕开被测生成路径。
- Google Wycheproof 提供 150 条 Ed25519 攻击与合法向量。

### 3.3 行为性质

确定性随机种子扩展人工样例，同时保留失败复现能力：

- Canonical JSON、Merkle 和 Ed25519 检查代数或往返性质。
- `tools/property-api-semantic.mjs` 覆盖创建、验证、证明、审计和签名闭环。
- `tools/fuzz-api-malformed.mjs` 覆盖 12 个浏览器 API 的异常请求外壳。
- `tools/randomized-hardening.mjs` 固定 `ci`、`release` 和 `stress` 三档轮次。

性质测试承担输入扩展，预期结果仍来自不变量、独立参考或明确拒绝合同。

### 3.4 反向证明

`tools/mutation-check.mjs` 对安全不变量注入 16 个实现故障。当前测试全部捕获，覆盖摘要检查、Merkle、外部锚点、低阶公钥、审计签名、增量缓存和对象存储等关键路径。

新增安全不变量时，应同时增加可观察的失败样例。可使用 mutation、独立参考或先失败后修复的回归用例，证明门禁能够识别目标故障。

### 3.5 系统边界

系统级证据覆盖实现内部单测无法观察的合同：

- PowerShell 和 bash 从真实进程检查参数、退出码、JSON 和文件副作用。
- 浏览器 smoke 调用发布版 MoonBit JS 产物。
- native、wasm、wasm-gc、js 共用核心测试。
- Fabric Chaincode、Gateway 和双组织网络覆盖提交、验证、查询、重复与摘要回传。
- native timing runner 对发布构建执行随机交错采样，记录 Welch t 统计量。

## 4. 当前基线

| 证据面 | 2026-07-11 基线 | 权威记录 |
| --- | --- | --- |
| MoonBit | 357 个测试声明，353 个可执行测试，4 个基准包装 | native、wasm、wasm-gc、js 各 `353/353` |
| CLI | PowerShell、bash 各覆盖 native 和 js | 每个 shell/target 组合 `68/68`，含 SHA-512 独立 pack、目录清单完整性与 IO 退出码 |
| 浏览器 API | 12 个字符串接口 | smoke `41/41`，含版本链透传和 SHA-512 proof；malformed 与 semantic profile 进入 CI |
| Ed25519 标准 | RFC 8032 4 条样例 | 逐字节已知答案 |
| Ed25519 攻击输入 | Wycheproof 150 条 | 88 条合法、62 条非法、7 类攻击 |
| 独立差分 | Ed25519、SHA-2、HMAC、证据包 | CI 每类 64 轮，发布候选 1000 轮记录通过 |
| 故障注入 | 16 个定向变异 | `16/16` 捕获，源码恢复检查通过 |
| 分支审计 | MoonBit 核心、CLI 和 Fabric 共 221 个审计不变量 | 当前清单无开放 gap，注册源码改动触发 stale-check |
| Fabric Chaincode | Go vet、race 和覆盖率 | 核心语句覆盖率 82.1% |
| Fabric Gateway | TypeScript check、build、test | `19/19` |
| Fabric 实链 | Fabric v3.1.4，Org1/Org2 | 首笔 `VALID`、双组织查询、幂等重复、`E2003`/`E2004` 回传 |
| 原生计时 | Windows/MSVC release | verify、sign-message、sign-secret 各 50,000 样本 |

数字、环境和命令以 [RESULTS_LOG.md](records/RESULTS_LOG.md) 的时间戳记录为准。公开材料引用同一记录，指标漂移由 `tools/check-metrics.mjs` 阻断。

## 5. 覆盖索引

| 模块或合同 | 重点输入 | 主要测试资产 |
| --- | --- | --- |
| `canonjson` | 键顺序、转义、Unicode、数字拒绝、幂等性 | `src/canonjson/*_wbtest.mbt` |
| `digest` | 空输入、块边界、多块输入、算法标签、HMAC key | `src/digest/*_wbtest.mbt`、`differential-digest.mjs` |
| `merkle` | 0/1/奇偶叶、`2^k±1`、10,000 叶、证明方向 | `src/merkle/*_wbtest.mbt`、`cross-verify.mjs` |
| `crypto` | 长度、编码、标量、低阶点、可塑性、篡改 | `src/crypto/*_wbtest.mbt`、Wycheproof、`differential-crypto.mjs` |
| `model` | schema、路径、版本链、错误码 | `src/model/*_wbtest.mbt`、CLI manifest 矩阵 |
| `create` | 排序、SHA-512、空树、非法字段、深度上限 | `src/create/create_wbtest.mbt`、CLI 黑盒 |
| `verify` | 文件缺失/变化、外部摘要、Merkle 根、完整诊断 | `src/verify/verify_wbtest.mbt`、golden packs、mutation |
| `incremental` | 命中、失效、恶意缓存、外部摘要、完整验证对等 | `src/verify/incremental_wbtest.mbt`、mutation |
| `store` | 去重、篡改、缺失对象、严格/宽松重建 | `src/store/object_store_wbtest.mbt`、mutation |
| `audit` | 前驱摘要、重排、JSON、签名、未签名条目 | `src/audit/audit_log_wbtest.mbt`、API property |
| 浏览器 API | 异常 JSON、类型、hex、闭环行为、稳定 envelope | `src/api/api_wbtest.mbt`、smoke、fuzz、property |
| CLI | 命令、文件副作用、JSON schema、退出码、错误码 | `tools/cli-test.ps1`、`tools/cli-test.sh` |
| Fabric | 状态不可变、并发、提交回执、身份和回传 | `integrations/fabric/**/test*`、`docs/records/fabric-e2e/` |

## 6. 执行档位

| 档位 | 触发条件 | 执行范围 |
| --- | --- | --- |
| 定向检查 | 开发中修改单个包或合同 | 对应包测试、相关独立参考、相关 mutation |
| 合并检查 | Pull Request 或 main 推送 | `.github/workflows/ci.yml` 的两个 required job |
| 发布候选 | 标签、比赛交付或公开 ready 声明 | 完整 CI、发布随机档、mutation、包内容、Showcase 构建 |
| 协议复跑 | Chaincode、Gateway、Fabric SDK、profile、背书或提交处理变化 | 双组织部署、提交、双查询、重复、正负回传 |
| 生产认证 | 高价值资产、目标工具链或 CPU 变化 | 独立密码学评审、最终机器码、目标机 timing、密钥和组织治理 |

### 6.1 基础门禁

```powershell
moon check --deny-warn --target all
moon fmt --check
moon info
git diff --exit-code -- 'src/**/*.mbti'
moon test --deny-warn --target wasm,wasm-gc,js
moon test --deny-warn --target native
node tools/check-metrics.mjs
node tools/check-package-contents.mjs
```

### 6.2 独立证据

```powershell
node tools/cross-verify.mjs
node tools/check-wycheproof-ed25519.mjs
node tools/check-branch-coverage-stale.mjs
node tools/smoke-api.mjs
node tools/randomized-hardening.mjs --profile release --skip-build
node tools/mutation-check.mjs
```

### 6.3 适配器

```powershell
./tools/cli-test.ps1 -Target native
./tools/cli-test.ps1 -Target js
bash ./tools/cli-test.sh native
bash ./tools/cli-test.sh js
npm run fabric:check
npm run fabric:test
npm --prefix showcase run check
npm --prefix showcase run build
```

Go Chaincode 的 `go test -race -cover ./...` 由 Ubuntu required CI 执行。Windows 本地覆盖运行保留为快速检查，不能替代 race 结果。

## 7. 用例设计

每个新增或修改的安全结论按以下顺序落地：

1. 标出信任边界和失败影响。
2. 划分正常、边界、异常和对抗输入。
3. 选择标准、独立实现、固定夹具、手工推导或性质不变量作为 oracle。
4. 选择能够最短定位故障的测试层。
5. 保存随机种子、轮次和最小失败输入。
6. 为安全关键不变量增加反向证明。
7. 将公开结论的运行结果追加到 `RESULTS_LOG.md`。

合格用例应满足：

- 断言业务值、错误码、退出码或文件副作用。
- 失败信息能够定位轮次、路径或输入分区。
- 随机测试使用确定性种子。
- 异常输入精确触发目标分支。
- 自生成闭环同时配有独立答案或攻击样例。
- 大型端到端测试只承担跨进程、跨后端或跨协议合同。

## 8. 维护触发器

| 变化 | 必须同步的证据 |
| --- | --- |
| 修改已审计源码 | 更新或复核 `BRANCH_COVERAGE.md`，通过 stale-check |
| 修改摘要、Merkle 或 Ed25519 | 标准样例、独立差分、相关 mutation、全部后端 |
| 修改 manifest 或路径处理 | schema/path 矩阵、创建和验证黑盒、异常文件系统探针 |
| 修改 CLI 或 API | 双 shell 黑盒、smoke、malformed、semantic、机器合同文档 |
| 修改 Chaincode 或 Gateway | Go/TypeScript 门禁和真实 Fabric 协议复跑 |
| 修改依赖或编译后端 | 全后端回归、差分检查、必要时 native timing |
| 修改公开数字或安全声明 | metrics、链接、对应命令和 `RESULTS_LOG.md` |
| 新增发布文件 | Mooncakes 包内容门禁和干净消费者检查 |

当前 v0.5.0 没有开放的 P0 或 P1 测试缺口。流式摘要、目标机器码复核、专门 dudect 活动和生产 Fabric 治理由部署等级触发，验收条件已经写入 [SECURITY.md](../SECURITY.md) 和 [CONST_TIME_AUDIT.md](CONST_TIME_AUDIT.md)。

## 9. 完成条件

一轮测试工作在以下条件同时成立时收口：

1. 触及的信任边界已完成风险分级。
2. 对应 P0 项全部关闭。
3. 发布相关 P1 门禁全部通过。
4. 最强公开声明能够指向测试、独立参考、审计或实链记录。
5. 安全关键结论具备反向证明。
6. 后续增强项带有明确触发条件和验收结果。

满足这些条件后，新增测试只服务新的输入分区、信任边界、参考来源、平台差异或历史逃逸类型。完整分级和停手规则见 [TEST_GOVERNANCE.md](TEST_GOVERNANCE.md)。

## 10. 证据入口

| 资料 | 职责 |
| --- | --- |
| [TEST_GOVERNANCE.md](TEST_GOVERNANCE.md) | 风险分级、完成定义、门禁归属和停手规则 |
| [BRANCH_COVERAGE.md](BRANCH_COVERAGE.md) | 安全相关分支到测试的映射 |
| [CONST_TIME_AUDIT.md](CONST_TIME_AUDIT.md) | Ed25519 源码审计和原生计时记录 |
| [RESULTS_LOG.md](records/RESULTS_LOG.md) | 带时间、环境、命令和结果的运行记录 |
| [ACCEPTANCE_CHECKLIST.md](records/ACCEPTANCE_CHECKLIST.md) | 赛事九项要求到仓库证据的映射 |
| [CI 工作流](../.github/workflows/ci.yml) | 合并门禁的可执行来源 |
| [Fabric 记录](records/fabric-e2e/2026-07-11/) | 双组织部署、交易、查询和回传证据 |
