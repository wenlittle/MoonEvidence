# MoonEvidence 测试治理

> 适用版本：v0.5.x
>
> 详细覆盖：[TEST_PLAN.md](TEST_PLAN.md)
>
> 运行记录：[RESULTS_LOG.md](records/RESULTS_LOG.md)

本文件规定风险等级、合并条件、发布门禁和测试收口标准。测试计划负责说明覆盖内容和执行档位，CI 工作流负责执行自动门禁，结果记录负责保存可复核事实。

## 1. 治理原则

| 原则 | 执行要求 |
| --- | --- |
| 声明绑定证据 | 每个安全或质量结论指向标准样例、独立参考、测试、审计或协议记录 |
| 独立答案优先 | 安全关键结果优先采用 RFC/NIST/Wycheproof、Node.js 或独立固定夹具 |
| 测试可证伪 | mutation、先失败后修复的回归或定向守卫能够证明门禁会变红 |
| 层级服从风险 | 包测试定位算法，黑盒测试固定进程合同，实链实验固定协议行为 |
| 随机过程可复现 | 固定种子、轮次、环境和最小失败输入进入日志 |
| 结论按环境生效 | 性能、计时和真实网络结果记录工具链、机器、版本和日期 |
| 维护成本受控 | 新测试覆盖新的风险类别，重复样例合并到已有矩阵 |

本治理口径参考 NIST SSDF、OWASP ASVS、Google 工程实践和 mutation testing 实践。项目将通用方法映射到证据包规范、密码学实现、机器接口和 Fabric 适配边界。

## 2. 风险等级

### P0 核心阻断

P0 影响证据结论、密钥安全或不可逆外部记录。问题关闭前，受影响边界不得合并或发布。

典型范围：

- Canonical JSON、SHA-2、HMAC、Merkle 和 Ed25519 语义。
- Manifest 解析、路径约束、完整验证和外部摘要对照。
- 增量缓存、对象存储、审计签名和严格重建。
- CLI 在本地验证失败后仍进入 Fabric 提交。
- Chaincode 不可变语义、提交回执一致性和摘要回传。
- 宣称保护上述边界的 required CI 缺失或失败。

关闭条件：

1. 失败模式和攻击者可控输入已经列明。
2. 目标行为有独立 oracle 或可手工推导的边界值。
3. 反向证明能够捕获该故障。
4. 相关包、进程、后端和 required CI 全部通过。
5. 安全说明和结果记录同步更新。

### P1 发布阻断

P1 影响公开合同、可复现性或交付一致性。开发分支可以继续推进，标签、比赛提交和 ready 声明必须等待关闭。

典型范围：

- CLI/API schema、错误码、退出码和公开函数接口。
- native、wasm、wasm-gc、js 的构建与行为一致性。
- PowerShell/bash 黑盒对等。
- 固定夹具、生成接口、版本、包内容和依赖锁文件漂移。
- README 命令、公开数字、安全口径和许可证材料。
- Showcase、浏览器工作台和最小示例无法按文档复现。

关闭条件：

1. 用户可见合同有包测试或黑盒测试。
2. 生成文件由权威命令重建并保持稳定。
3. 文档、示例、版本和发布元数据一致。
4. 当前提交通过 canonical CI 和对应交付工作流。

### P2 计划增强

P2 提高性能、体验或保障深度。每一项保留明确触发条件、验收结果和责任边界。

典型范围：

- 已固定核心不变量后的更大 fuzz 轮次。
- 共享 runner 上的信息性基准。
- 已有 mutation 覆盖后的更多等价变异。
- UI 动效、演示节奏和非合同文案。
- 高价值生产环境的机器码复核、专业 timing 活动和组织治理。

P2 在触发条件出现时升级：公开性能承诺使相关基准进入 P1；目标工具链变化使 timing 复核进入生产认证门禁；新攻击类别影响接受/拒绝结论时进入 P0。

## 3. 变更分级

| 变更范围 | 默认等级 | 评审重点 |
| --- | --- | --- |
| `src/canonjson`、`digest`、`merkle`、`crypto` | P0 | 规范字节、算法边界、独立差分、mutation、后端一致性 |
| `src/model`、`create`、`verify`、`store`、`audit` | P0 | 输入分区、错误集合、路径、缓存、内容完整性 |
| `src/api`、`src/cmd`、CLI 机器合同 | P1；绕过验证时升为 P0 | schema、错误码、退出码、文件副作用、异常 envelope |
| Fabric Chaincode 和 Gateway | P1；不可变记录或提交前验证变化时升为 P0 | 状态语义、并发、身份、回执、摘要回传 |
| `moon.mod`、锁文件、CI 和发布流程 | P1；安全门禁失效时升为 P0 | 工具链、依赖、生成接口、包内容、发布来源 |
| README、规范、安全文档 | P1 | 命令可执行、声明有证据、版本和链接一致 |
| Showcase、demo 和展示材料 | P2；交付入口失效时升为 P1 | 构建、交互路径、浏览器错误、响应式布局 |
| 纯重排或格式化 | P2 | 语义 diff、生成文件和 stale-check |

一个变更触及多个范围时，使用最高等级。

## 4. 完成定义

### 4.1 安全核心

合并前应具备：

- 风险等级和信任边界。
- 正常、边界、异常和对抗输入分区。
- 独立答案或明确不变量。
- 能够失败的回归证据。
- 相关分支图复核。
- 相关包测试、差分、mutation 和多后端结果。
- 对公开安全结论的同步更新。

### 4.2 CLI 和浏览器 API

合并前应具备：

- 输入 schema、输出 schema、错误码和退出码测试。
- 正常、拒绝和运行错误三类进程结果。
- PowerShell/bash 对等用例。
- 浏览器 smoke、malformed fuzz 和 semantic property。
- 公开命令和示例复跑结果。

### 4.3 Fabric

合并前应具备：

- Go vet、race 和合同测试。
- TypeScript check、build 和 Gateway 单测。
- MoonBit CLI 失败在网络连接前终止的负向测试。
- 状态字段、幂等规则、MVCC 处理和回执一致性测试。

Chaincode、Gateway SDK、连接 profile、背书假设或提交处理变化时，发布前重跑双组织协议，并保存提交、双查询、重复和正负摘要回传记录。

### 4.4 文档和展示

合并前应具备：

- 本地链接和章节锚点有效。
- 精确数字通过 metrics 门禁或指向带时间记录。
- 命令在当前目录结构中可执行。
- 安全声明与 `SECURITY.md`、架构和测试证据一致。
- Showcase 通过 TypeScript 检查和生产构建。
- 可见 UI 变化经过桌面和移动端浏览器检查。

文档修改了命令、夹具、安全声明或交付路径时，运行对应功能门禁。

### 4.5 依赖和工具链

合并前应具备：

- 依赖锁文件更新可解释且可复现。
- `moon info` 生成接口无意外漂移。
- 全后端构建和测试。
- 密码学后端或编译器变化触发独立差分；高价值部署同时触发原生 timing 复核。
- Fabric SDK 变化触发适配器 required job 和协议复跑评估。

## 5. 门禁归属

| 工作流 | 性质 | 职责 |
| --- | --- | --- |
| `.github/workflows/ci.yml` / `check-test-build` | required | MoonBit 检查、生成接口、四后端、CLI、浏览器 API、随机差分和 mutation |
| `.github/workflows/ci.yml` / `fabric-adapters` | required | Chaincode vet/race/coverage 和 Gateway check/test |
| `.github/workflows/ci.yml` / `bench` | 信息性 | 共享 runner 上的性能趋势 |
| `.github/workflows/showcase-pages.yml` | 交付 | 构建真实 MoonBit API 和 Showcase，发布 Pages |
| `.github/workflows/release.yml` | 发布 | 检查、打包和 Mooncakes 发布 |

`.github/workflows/ci.yml` 是合并门禁的可执行来源。Release 工作流使用已经通过 canonical CI 的提交，标签指向与 CI 通过提交保持一致。

## 6. 变更门禁

| 路径或合同 | 必跑检查 |
| --- | --- |
| `src/crypto/**` | crypto 单测、Wycheproof 清点、Ed25519 差分、mutation、分支图、四后端 |
| `src/digest/**` | digest/HMAC 单测、Node.js 差分、mutation、四后端 |
| `src/canonjson/**`、`src/merkle/**` | 包测试、夹具、cross-verify、mutation、四后端 |
| `src/model/**`、`src/create/**`、`src/verify/**`、`src/store/**`、`src/audit/**` | 包测试、分支图、相关 golden oracle、CLI/API 回归 |
| `src/api/**` | API wbtest、release JS 构建、smoke、malformed、semantic、相关差分 |
| `src/cmd/**`、CLI 契约 | native/js 构建，PowerShell/bash 四组黑盒，README/GUIDE 命令 |
| `integrations/fabric/**` | Fabric required job；协议语义变化追加双组织实跑 |
| `showcase/**`、`demo/**` | 构建、浏览器控制台、关键交互、桌面/移动布局 |
| `docs/**`、README | 链接、metrics、命令复现、声明一致性 |
| `moon.mod`、`.github/**`、发布元数据 | 完整 canonical CI、包内容、干净消费者或发布 dry-run |

安全相关源码出现在 [BRANCH_COVERAGE.md](BRANCH_COVERAGE.md) 的审计范围内时，源码和分支图在同一变更中复核。`tools/check-branch-coverage-stale.mjs` 执行这一约束。

## 7. 收口规则

测试工作在以下条件全部满足时完成：

1. 受影响边界已分级，最高风险等级明确。
2. P0 失败模式均有直接证据并关闭。
3. 发布或提交相关的 P1 门禁全部通过。
4. 最强公开声明能够追溯到当前结果。
5. 安全关键不变量具备独立答案和反向证明中的至少各一项。
6. 剩余 P2 项写明触发条件、验收结果和证据入口。

新增测试须覆盖新的输入等价类、信任边界、oracle 来源、平台后端或历史逃逸类型。已有证据能够识别同一故障时，优先维护现有用例。

## 8. 结果记录

支持公开结论的运行结果追加到 [RESULTS_LOG.md](records/RESULTS_LOG.md)，至少包含：

| 字段 | 内容 |
| --- | --- |
| 范围 | 受影响模块、合同和风险等级 |
| 来源 | 提交、数据集版本、参考实现和许可证 |
| 环境 | 日期、时区、操作系统、工具链和目标后端 |
| 方法 | 命令、轮次、随机种子和输入规模 |
| 结果 | 通过数量、拒绝信号、统计量或交易回执 |
| 结论 | 当前证据支持的声明和下一次触发条件 |

性能、计时和真实网络记录保留原始环境。后续机器或工具链结果追加新条目，历史结果继续作为对应环境的证据。

## 9. 评审拒绝项

| 拒绝项 | 合格替代 |
| --- | --- |
| 只用测试总数说明质量 | 展示风险、oracle、反向证明和系统边界 |
| 只用 `sign -> verify` 证明 Ed25519 | 加入 RFC、Wycheproof 和独立差分 |
| 只用 `create -> verify` 证明证据包 | 加入独立固定摘要、篡改包和外部摘要 |
| `put()` 与 `verify_integrity()` 互相生成预期值 | 直接写入对象 Map 并使用外部摘要 |
| 只断言非空、无 panic 或返回 true | 断言业务值、错误码、路径和副作用 |
| 工具脚本未进入 CI，却称为门禁 | 接入工作流或标记为手动审计 |
| 大型端到端测试重复包级逻辑 | 包级测试负责定位，端到端测试负责边界 |
| 随机失败无法复现 | 固定种子并记录最小输入 |
| 精确数字没有时间和来源 | 绑定 `RESULTS_LOG.md` 或自动 metrics |

## 10. 参考

- [NIST SP 800-218, Secure Software Development Framework v1.1](https://csrc.nist.gov/pubs/sp/800/218/final)
- [OWASP Application Security Verification Standard](https://owasp.org/www-project-application-security-verification-standard/)
- [Google Engineering Practices: What to look for in a code review](https://google.github.io/eng-practices/review/reviewer/looking-for.html)
- [Martin Fowler: Test Pyramid](https://martinfowler.com/bliki/TestPyramid.html)
- [Software Engineering at Google: Larger Testing](https://abseil.io/resources/swe-book/html/ch14.html)
- [Google Research: State of Mutation Testing at Google](https://research.google/pubs/state-of-mutation-testing-at-google/)
