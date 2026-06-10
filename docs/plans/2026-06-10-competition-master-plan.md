# MoonEvidence 比赛夺冠总体作战计划

> **面向 AI 代理的工作者：** 必需子技能：使用 executing-plans 逐步骤实现此计划；每个步骤完成后必须更新 `docs/records/RESULTS_LOG.md` 并单独 commit。

**目标：** 在 MoonBit OSC2026 中以「可信证据包验证库 + CLI」冲击一等奖：完成度高、可用性强、具有长期维护潜力。
**架构：** 纯验证内核（canonjson / digest / merkle / model / verify / diag 六个零 IO 纯包）+ 薄适配层（native CLI、wasm/js 绑定）。验证优先，生成/签名后置。
**技术栈：** MoonBit（moon test / moon build --target native,wasm-gc,js）、GitHub Actions CI、RFC 8785 (JCS)、FIPS 180-4 (SHA-256)、RFC 6962 (Merkle domain separation)。

---

## 一、夺冠策略：评分维度 → 打法映射

赛方综合评估四个维度，每个维度都要有可指认的证据：

| 评分维度 | 我们的打法 | 证据落点 |
| --- | --- | --- |
| 项目完成度 | MVP 七模块全部落地 + 三后端可构建 | `moon test` 全绿、CLI 可执行、wasm demo 可打开 |
| 生态贡献 | 填补 evidence/provenance 空白（碰撞检查已证明）、发布 Mooncakes、可被其他库复用 | Mooncakes 包页面、API 文档、双语 README |
| 工程质量 | 标准兼容（RFC 8785/6962/FIPS 向量）、property test、CI 三后端矩阵、错误码体系 | CI 徽章、测试向量文件、覆盖率报告 |
| 展示表现 | 「验证 AI 产物包」端到端 demo + 开发报告 + AI 协作证据链 | demo 脚本、DECISION_LOG/RESULTS_LOG |
| 专项奖兜底 | 最佳文档 / 最佳测试 / 最佳 AI 协作实践三个方向均有布局 | 文档体系、fixtures 矩阵、协作日志 |

## 二、创新点清单（差异化竞争力）

每个创新点都必须做到「生态内首个 + 有标准可对拍 + 有测试佐证」，否则降级删除：

1. **RFC 8785 (JCS) 规范化 JSON**：MoonBit 生态首个标准兼容实现，含 UTF-16 码元排序、确定性转义、数字格式化分级策略（见步骤 2）。
2. **纯 MoonBit SHA-256**：零 FFI，FIPS 180-4 + NIST CAVP 测试向量全过，三后端同源运行。
3. **RFC 6962 风格 Merkle**：`0x00`/`0x01` 前缀 domain separation 防二次原像攻击，空树/单叶语义显式定义——区别于玩具实现的关键标志。
4. **可解释诊断体系**：结构化错误码（E1xxx~E5xxx）+ 机器可读 JSON 报告 + `explain` 人类可读输出。直接呼应赛事痛点原话「AI 生成代码难以验证与长期维护」。
5. **moon prove / property test 双保险**：对「规范化幂等」「Merkle 验证可靠性」等核心性质做形式化或属性验证——赛方推荐清单明确点名 moon prove。
6. **三后端交付**：native CLI + wasm 浏览器 demo + js 包。MoonBit 官方评委最看重语言多后端优势的真实展示。
7. **交叉验证 fixtures**：用独立参考实现（Node 脚本）生成 golden 数据，与 MoonBit 实现对拍，杜绝「自己测自己」。

## 三、分步计划

### 第 0 步：基线冻结与申报抢跑（立即）

**目标：** 锁定规格与 API 形状，满足申报硬条件，拿下 150 元启动支持。

任务：
1. 冻结 `docs/spec/EVIDENCE_PACK_SPEC.md` 为 v1：补全 Merkle 叶子编码（`leaf_hash = SHA256(0x00 || canonical_file_entry_bytes)`、`node_hash = SHA256(0x01 || left || right)`）、空树定义（`merkle_root` 字段省略或为空串视为 E3001）、单叶树（root = leaf hash）。
2. 冻结错误码表并写入 spec：
   - `E1xxx` 清单/格式类（E1001 manifest 不可解析、E1002 缺必填字段、E1003 schema 版本不支持、E1004 规范化失败）
   - `E2xxx` 摘要类（E2001 算法不支持、E2002 摘要格式非法、E2003 文件摘要不匹配、E2004 manifest 摘要不匹配）
   - `E3xxx` Merkle 类（E3001 根缺失/非法、E3002 证明格式非法、E3003 证明验证失败）
   - `E4xxx` 版本链类（E4001 链为空、E4002 父引用断裂、E4003 出现环、E4004 多头/分叉）
   - `E5xxx` IO/CLI 类（E5001 路径不存在、E5002 文件读取失败）
3. 冻结公共 API 签名（写入 `docs/ARCHITECTURE.md`）：
   ```text
   @canonjson.canonicalize(String) -> String raise
   @digest.sha256_hex(Bytes) -> String
   @merkle.compute_root(leaves: Array[Bytes]) -> Digest
   @merkle.verify_inclusion(leaf: Digest, proof: Proof, root: Digest) -> Bool
   @model.Manifest::parse(String) -> Manifest raise ModelError
   @verify.verify_manifest(manifest_json: String) -> VerifyReport
   @verify.verify_version_chain(nodes: Array[VersionNode]) -> ChainReport
   @diag.explain(report: VerifyReport) -> String
   ```
4. 建 GitHub Actions CI：`moon check` + `moon test` + `moon build --target native`（wasm/js 在第 9 步加入矩阵）。
5. 建 Gitlink 镜像仓库并配置同步。
6. 写一页 PDF 申报书（结构对照赛方 moon_elk 样本：基本信息/简介/核心功能范围/原创说明——本项目为原创，参考标准为 RFC 8785/6962）。
7. 重跑 Mooncakes 碰撞检查并更新记录文件。

验收：CI 绿灯徽章挂上 README；申报书提交；提交数 ≥ 10。
预计提交：6~8 个（spec 冻结、错误码、API 冻结、CI、申报材料、碰撞复查各自独立 commit）。

### 第 1 步：digest 完整化——纯 MoonBit SHA-256

**目标：** 摆脱「只有摘要字符串封装、没有真哈希」的现状，这是整个项目的密码学地基。

任务：
1. `src/digest/sha256.mbt`：实现 FIPS 180-4 SHA-256（消息调度 W[64]、压缩函数、Merkle–Damgård padding），API：
   ```text
   pub fn sha256(data : Bytes) -> Bytes        // 32 字节
   pub fn sha256_hex(data : Bytes) -> String   // 64 字符小写 hex
   pub struct Sha256Ctx { ... }                // update/finalize 增量 API
   ```
2. `src/digest/sha256_wbtest.mbt`：NIST 测试向量——空串、"abc"、"abc..." 448bit 边界、896bit 边界、百万字节 'a'（用增量 API 喂入避免大内存）、跨 64 字节块边界的增量一致性测试。
3. `Digest::of_bytes(algorithm, data)` 工厂函数，打通「字节 → Digest 结构」。
4. UTF-8 编码辅助：`string_to_utf8_bytes(String) -> Bytes`（MoonBit String 是 UTF-16，摘要计算必须显式走 UTF-8，这是跨实现一致性的关键坑，必须有双向测试）。

验收：`moon test` 全绿；NIST 向量逐条通过并记入 RESULTS_LOG。
预计提交：3~4 个。

### 第 2 步：canonjson 升级到 RFC 8785

**目标：** 从「排序 + stringify」雏形升级为可声称标准兼容的实现。

任务：
1. 字符串转义改为自实现（不依赖 `stringify` 默认行为）：仅转义 `\" \\ \b \f \n \r \t` 与 < 0x20 控制符（`\u00XX` 小写 hex），其余码元原样输出。
2. 键排序改为 UTF-16 码元序（RFC 8785 §3.2.3 要求，恰好与 MoonBit String 默认比较一致——写测试钉死这一假设，含代理对用例）。
3. 数字格式化分级策略：
   - L1（本步交付）：安全子集——整数（|n| ≤ 2^53-1）原样、`-0` 归一为 `0`、含小数/指数的输入若与最短表示不一致则 raise `CanonError::UnsupportedNumber`，绝不猜测输出。
   - L2（第 8 步攻坚）：实现 ECMAScript Number→String 最短表示算法，对拍 RFC 8785 附录测试向量。
4. 引入 RFC 8785 官方测试向量文件（`tests/fixtures/jcs/`），逐条对拍。
5. 幂等性测试：`canonicalize(canonicalize(x)) == canonicalize(x)`。

验收：JCS 向量（数字 L2 项除外，显式标注 skip 清单）通过；幂等测试通过。
预计提交：3~4 个。

### 第 3 步：merkle 包

**目标：** RFC 6962 风格、有防御性语义的 Merkle 实现。

任务：
1. `src/merkle/merkle.mbt`：
   ```text
   pub fn leaf_hash(data : Bytes) -> Bytes          // SHA256(0x00 || data)
   pub fn node_hash(l : Bytes, r : Bytes) -> Bytes  // SHA256(0x01 || l || r)
   pub fn compute_root(leaves : Array[Bytes]) -> Bytes?   // None 当 leaves 为空
   pub struct ProofStep { sibling : Bytes; side : Side }  // Side = Left | Right
   pub fn verify_inclusion(leaf : Bytes, proof : Array[ProofStep], root : Bytes) -> Bool
   ```
2. 奇数层处理策略写死并文档化：落单节点直接晋升（不与自身配对——自配对是 Bitcoin CVE-2012-2459 重复叶攻击的根源，文档中引用说明）。
3. 防御测试：空树、单叶、2/3/4/5/8 叶全形状、伪造 sibling、side 翻转、proof 截断/加长、leaf 与 node 前缀混用攻击（用 leaf_hash 结果冒充 node 必须失败）。
4. 与参考实现对拍：`tools/gen-merkle-fixtures.mjs`（Node 脚本，同样的前缀规则）生成 golden root/proof 写入 `tests/fixtures/merkle/`。

验收：全形状 + 全攻击用例通过；golden 对拍一致。
预计提交：3~4 个。

### 第 4 步：model 包

**目标：** manifest 与版本链的强类型模型 + 全量字段校验。

任务：
1. `src/model/manifest.mbt`：`Manifest` / `Subject` / `FileEntry` / `VersionRef` 结构体，`Manifest::parse(String) -> Manifest raise ModelError`，校验：schema 必须 `moon-evidence/v0`、`hash_algorithm` 受支持、files 路径非空不重复、digest 格式合法、size ≥ 0。
2. `src/model/version.mbt`：`VersionNode { id, parent : String? }`，解析 `version_chain.json`。
3. `ModelError` 枚举与错误码表一一映射（每个变体携带字段路径上下文，如 `files[3].digest`）。
4. 表驱动测试：合法 manifest 1 份 + 每条校验规则各 1 份非法样本（≥ 10 份），全部以 fixtures 文件形式存放而非内联字符串（复用给第 7 步 CLI 黑盒测试）。

验收：每条校验规则均有正/反用例；错误码与 spec 表一致。
预计提交：3~4 个。

### 第 5 步：verify 编排 + diag 诊断

**目标：** 把验证语义串成可解释的报告流水线。

任务：
1. `src/diag/diag.mbt`：
   ```text
   pub(all) struct Finding { code : String; severity : Severity; path : String; message : String }
   pub(all) struct VerifyReport { ok : Bool; findings : Array[Finding]; checked : CheckStats }
   pub fn explain(report : VerifyReport) -> String   // 人类可读多行文本
   pub fn to_json(report : VerifyReport) -> String   // 机器可读（canonjson 渲染）
   ```
2. `src/verify/verify.mbt`：按 spec 七步语义编排（解析→规范化→manifest 摘要→文件摘要→Merkle→版本链→汇总）。纯包不做 IO：文件内容由调用方以 `Map[String, Bytes]` 注入，CLI 负责读盘——保持「纯内核 + 薄适配」架构红线。
3. 版本链验证：从无 parent 的根出发重建链，检测 E4001~E4004（空链/断裂/环/分叉），输出 `ChainReport { ordered_ids, findings }`。
4. explain 输出格式定稿并写进 README 示例（每条 finding 一行：`[E2003] files/data.csv: digest mismatch, expected sha256:ab.. got sha256:cd..`）。

验收：valid pack 报告 ok=true 零 findings；每个错误码均有触发用例且 explain 文本可读。
预计提交：3~4 个。

### 第 6 步：native CLI

**目标：** `moon-evidence verify <pack-dir>` / `explain` 可执行落地。

任务：
1. 先做 IO spike：验证 MoonBit native 目标读文件/命令行参数的可用 API（`@env.args()` 与文件读取），结论记入 RESULTS_LOG；若目录遍历受限，fallback 方案为「CLI 接收 manifest 路径 + 按 manifest.files 列表逐个读文件」（不需要目录遍历，规避能力缺口）。
2. `src/cmd/main/main.mbt`：参数解析（`verify [--json] <path>`、`explain <path>`、`--version`、`--help`），退出码约定：0 验证通过 / 1 验证失败 / 2 用法或 IO 错误。
3. 黑盒测试脚本 `tools/cli-test.ps1` + CI 步骤：对 examples 下 valid/tampered 两个 pack 跑 CLI，断言退出码与关键输出行。
4. `examples/valid-pack` 与 `examples/tampered-pack` 填充真实内容（配套 README 讲清每个 pack 演示什么）。

验收：本地与 CI 上 CLI 黑盒测试通过；README 快速开始章节可照抄复现。
预计提交：4~5 个。

### 第 7 步：fixtures 全矩阵与交叉验证

**目标：** 测试体系从「有测试」升级到「可信测试」，冲最佳测试专项。

任务：
1. 篡改矩阵补全（每种一个 fixtures 目录）：改文件内容、删文件、加未登记文件（警告级 W1001）、改 manifest 字段、坏 Merkle 证明、版本链断裂/环。
2. `tools/gen-fixtures.mjs`：独立参考实现生成全部 golden 摘要/根/证明，确保 MoonBit 与参考实现互证；脚本与生成物都提交入库，CI 校验生成物与库内文件一致（防 fixtures 腐化）。
3. 锁定回归基线：`tests/` 黑盒测试逐 fixtures 断言错误码集合（精确匹配，不允许「至少包含」式宽松断言）。

验收：矩阵全覆盖错误码表；CI 含 fixtures 一致性校验步骤。
预计提交：3~4 个。

### 第 8 步：质量攻坚（最短数字 + property + prove + benchmark）

**目标：** 把「能用」打磨成「硬核」。

任务：
1. canonjson L2：实现 ECMAScript 最短数字表示（Grisu 风格或经典 digit-by-digit 实现均可，以正确性优先），通过 RFC 8785 数字向量，移除第 2 步的 skip 清单。
2. property test（MoonBit `quickcheck` 风格或自写生成器）：随机 JSON 值幂等性、随机叶集 Merkle proof 必验证通过、随机篡改任一叶必验证失败。
3. moon prove 尝试：对 `normalize_hex` 幂等、`Side` 配对对称性等小性质上证明；若工具链不成熟，结论与原因记入 RESULTS_LOG（写明「尝试过」本身就是展示材料）。
4. benchmark：1k/10k 文件 manifest 验证耗时、1MB 文件摘要吞吐，结果写入 README 性能小节。

验收：property 测试纳入 CI；数字向量全过；benchmark 数据入 README。
预计提交：4~5 个。

### 第 9 步：三后端交付与浏览器 demo

**目标：** 展示 MoonBit 多后端能力——评委级亮点。

任务：
1. CI 矩阵扩展：`moon build --target native,wasm-gc,js` + `moon test --target wasm-gc,js`（纯包零 IO，理论上直接通过；不过 String/Bytes 行为差异要靠 CI 钉死）。
2. `demo/web/`：静态页面加载 js 产物，粘贴 manifest JSON → 实时验证 → 渲染 findings 表格与 explain 文本。无构建框架，单 HTML + 原生 JS，保持可托管到 GitHub Pages。
3. README 增加「在浏览器试用」链接与截图。

验收：三后端 CI 全绿；GitHub Pages demo 可访问可操作。
预计提交：3~4 个。

### 第 10 步：发布与文档收口

**目标：** 从「参赛仓库」变成「生态正式成员」。

任务：
1. 发布到 Mooncakes（`moon publish`），版本 0.1.0；发布前重跑碰撞检查。
2. 双语 README（中文为主文档 + English 段落或独立 README.en.md），含：30 秒上手、API 速览、错误码表、性能数据、架构图（mermaid）。
3. `moon doc` 生成 API 文档并核对全部 pub 项有文档注释。
4. 用户指南 `docs/GUIDE.md`：三个真实场景走一遍——数据集存证、AI 输出审计、上链前校验。

验收：Mooncakes 页面可见；README 双语完整；moon doc 无缺失警告。
预计提交：4~5 个。

### 第 11 步：比赛交付物与验收自查

**目标：** 把工程成果翻译成评委语言。

任务：
1. 开发报告：项目背景→架构决策（引用 DECISION_LOG）→标准兼容证据→测试体系→AI 协作实践总结（引用 RESULTS_LOG 时间线）→生态价值与后续路线。
2. demo 演示脚本：5 分钟流程——CLI 验证通过→现场篡改一个字节→重新验证给出 E2003 与 explain→浏览器 demo 同步演示。
3. 对照「申请完成支持的项目应满足的要求」逐条自查打勾（MoonBit 主语言/双仓库公开/结构清晰/README 可复现/CI 覆盖检查构建测试）。
4. 最终冻结：重跑全部验证命令，结果与 commit hash 记入 RESULTS_LOG 作为提交快照。

验收：自查清单全勾；演示脚本彩排一遍计时 ≤ 5 分钟。
预计提交：3~4 个。

## 四、代码行数预算（目标区间 4~10k 有效行）

| 包 | 实现 | 测试 | 小计 |
| --- | --- | --- | --- |
| digest（含 SHA-256） | ~450 | ~350 | ~800 |
| canonjson（含 L2 数字） | ~700 | ~500 | ~1200 |
| merkle | ~300 | ~400 | ~700 |
| model | ~600 | ~500 | ~1100 |
| verify + diag | ~800 | ~600 | ~1400 |
| cmd/main + demo 绑定 | ~500 | ~300 | ~800 |
| property/prove/bench | — | ~700 | ~700 |
| **合计** | **~3350** | **~3350** | **~6700** |

落在区间中部，无需注水，也留有 L2 砍掉时的安全余量（砍后 ~5800 仍达标）。

## 五、风险与对策

| 风险 | 概率 | 对策 |
| --- | --- | --- |
| RFC 8785 数字格式化工作量超预期 | 中 | 分级策略：L1 安全子集先交付，L2 独立步骤可整体降级，spec 已定义 UnsupportedNumber 语义 |
| MoonBit native 文件/目录 IO 能力不足 | 中 | 第 6 步先 spike；fallback 按 manifest 列表读文件，不依赖目录遍历 |
| moon prove 工具链不成熟 | 高 | 定位为尝试项，property test 兜底；尝试记录本身作为展示材料 |
| wasm/js 后端字符串行为差异 | 低 | 纯包零 IO 设计 + CI 三后端测试矩阵尽早拉起（第 9 步可提前到任何时点） |
| Mooncakes 期间出现同类项目 | 低 | 申报抢跑（第 0 步）锁定方向；提交前重跑碰撞检查留证 |
| 单人项目节奏断档 | 中 | 每步独立可交付，任意截断点上项目都处于「全绿可演示」状态 |

## 六、交付物总清单

- 代码：六纯包 + CLI + web demo，三后端构建
- 测试：单元 + 黑盒 fixtures 矩阵 + property + 交叉验证 golden + benchmark
- CI：check / build / test 三后端矩阵 + fixtures 一致性校验
- 文档：双语 README、GUIDE、ARCHITECTURE、SPEC v1、错误码表、API 文档
- 生态：Mooncakes 0.1.0 发布
- 比赛材料：申报书 PDF、开发报告、5 分钟演示脚本、AI 协作实践证据链
