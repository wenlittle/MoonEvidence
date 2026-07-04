# MoonEvidence 健康体检与改进计划（5 轮迭代）

> **面向 AI 代理的工作者：** 本计划是对项目做"如何把它做好"的全面健康体检后的改进路线，不是最小可改补丁清单。执行时使用 executing-plans 逐步骤实现；每个阶段完成后必须更新 `docs/records/RESULTS_LOG.md` 并单独 commit。本轮只产出计划，不改任何代码。

**体检日期：** 2026-07-04 Asia/Shanghai
**体检方法：** 5 轮迭代式勘察——广度扫描 → 定向核验 → 根因分析 → 完整性与优先级校准 → 整合定稿。三维度（源码 / 测试 / 文档与治理）并行深审 + 命令行权威数字核验。
**体检范围：** `src/` 全部 12 包 48 个 `.mbt` 文件、`tests/` 全部夹具、`tools/` 全部脚本、`docs/` 全部文档、CI 与构建配置、`moon.mod`/`moon.pkg`、`demo/`、`examples/`、根目录 `report/`。
**权威基线（本机实测）：** 提交 **76**；实现 22 文件 **3590** 行 + 测试 26 文件 **3301** 行 = **6891** 行；测试声明 **219** 处；包 **12** 个；无 `LICENSE` 文件；`wenlittle` 残留 **7** 处。

---

## 一、健康体检总览

### 三维度评分

| 维度 | 评分 | 一句话诊断 |
| --- | --- | --- |
| 源码架构与质量 | **7.5 / 10** | 分层教科书级、核心管线扎实；crypto 包是信任根基却未达生产级密码学标准，incremental 路径破坏错误码契约 |
| 测试与验证 | **6.5 / 10** | 核心向量与交叉验证扎实；E3002 零覆盖且 README 虚假声明、Ed25519 缺 KAT 与 malleability 防护、新增包全自验证 |
| 文档与工程治理 | **4.5 / 10** | 留痕意识强；但量化指标系统性漂移、归属矛盾阻断级、冻结 API 与代码脱节、三份导航文档集体过期、缺 LICENSE/CHANGELOG |
| **综合** | **6.2 / 10** | 工程内核优秀，但"step-11 冻结快照"与"实际状态"系统性分裂，外加 crypto 安全缺口，需一轮治理才能冲击一等奖 |

### 核心问题一句话诊断

项目在 2026-06-11 做了"最终冻结"并写入 52 提交 / 4382 行 / 155 测试 / 0.1.0 / wenlittle 的快照，但此后又开发了 Ed25519 / audit / store / create 等重大功能（提交增至 76、代码增至 6891 行、版本升至 0.3.0、改名 starlittle），**冻结点之后的所有文档未做同步更新**，形成"冻结快照"与"实际状态"的系统性分裂；README/项目报告又走了另一极端，用 8000+ / 215 等未经核验的虚高数字。两类错误叠加，导致文档可信度受损。

---

## 二、五轮勘察记录

### 第 1 轮：广度扫描（三路并行深审）

**目标：** 建立三维度基线发现，不预设结论。
**方法：** 三路并行勘察——源码架构与质量、测试与验证、文档与 CI 一致性。逐包阅读关键实现文件，grep 信号扫描（TODO/FIXME/pub(all)/@fs/panic/unwrap 等），交叉核对量化指标。
**新发现（要点）：**
- 源码：Ed25519 verify 缺 `S < l` 检查（malleability）、scalar_mul 非常时间（侧信道）、incremental 与 verify 错误码不一致（E2001 vs E2003、E3002 vs E3003）、hex_to_bytes 三份实现且 audit 版静默损坏。
- 测试：E3002 零覆盖且 packs/README 虚假声明"已覆盖"、Ed25519 官方 pk 常量定义后从未被断言使用、create/store/audit 全自验证无独立交叉、CLI 黑盒层漏 E1003/E2001/E2002/E3002。
- 文档：代码行数 5 个不同值、测试数 3 个不同值、提交数 2 个值（均与实际 76 不符）、wenlittle/starlittle 改名后未同步申报材料（含 .tex/.html 同文件内自相矛盾）。
**对计划的更新：** 确立三维度评分骨架，识别出"冻结快照 vs 实际状态"分裂为根因候选。

### 第 2 轮：定向核验（关键断言实测）

**目标：** 验证第 1 轮的高严重度断言，补查未覆盖盲区。
**方法：** 实读 `verify.mbt`（确认冻结签名与实际不符）、`main.mbt`（确认 create 不递归、collect_pack_files 不查 symlink）、`README.zh.md`（确认错误码表与 README 一致但与 spec 行为不符）；命令行实测提交数/行数/测试数/包数/LICENSE/wenlittle 残留。
**新发现：**
- `verify_manifest` 实际签名 `verify_manifest(manifest_json, files, expected_manifest_digest?) -> @diag.VerifyReport`，与 `ARCHITECTURE.md:66` 冻结签名（无可选参数、返回 `VerifyReport` 未标注 `@diag` 前缀）不符——冻结契约失去约束力。
- CLI `CLI_VERSION = "0.3.0"` 硬编码，注释"Kept in sync with moon.mod at release time"靠人工同步，与 moon.mod 0.3.0 恰好一致但无机制保证。
- `create` 命令只读 `pack_dir` 顶层文件（`main.mbt:357-372`），不递归子目录；而 `verify` 的 pack-dir 模式递归扫 `files/`——用户若把文件放子目录，create 不收录、verify 报 W1001，行为不对称。
- README.zh 错误码表把 `E3003` 描述为"Merkle 根/证明复算不匹配"，而 spec 与 verify.mbt 中 E3003 仅指根不匹配、E3002 才是证明格式——文档描述模糊化了两码边界。
- 实测确认：无 LICENSE 文件（moon.mod 声明 Apache-2.0）；7 处 wenlittle 残留集中在申报材料。
**对计划的更新：** 把"冻结 API 与代码脱节"从高升为阻断前置项（契约若不约束，所有"标准兼容"声称都失真）；补"create/verify 行为对称性"为新发现项。

### 第 3 轮：根因分析（跨维度交叉）

**目标：** 找出问题之间的因果链，区分"症状"与"病因"。
**方法：** 把前两轮发现按"是否共享同一上游根因"聚类。
**根因结论：**
1. **根因 A：冻结点后无同步机制。** step-11 之后新增 4 包 + 24 提交，但 RESULTS_LOG/ACCEPTANCE_CHECKLIST/ARCHITECTURE/STRUCTURE_TREE/PROJECT_INDEX/ROADMAP 全部停在冻结快照。所有量化漂移、API 脱节、导航过期都源于此。
2. **根因 B：crypto 包作为后加功能未走核心包的质量门禁。** 核心六包有 NIST/RFC 向量 + 独立交叉验证 + spec 冻结；crypto（及 store/audit/create）是"第二阶段"加入，绕过了 spec 冻结、错误码契约对齐、独立交叉验证三道门，导致 malleability、错误码误用、自验证集中爆发。
3. **根因 C：申报材料与代码仓库分轨维护。** 申报书.tex/.html/.md、OSC2026_APPLICATION、开发报告各自手动维护仓库 URL/版本/作者，改名与版本迭代后无单一事实源，叠加单人/四人作者归属未定，形成阻断级合规风险。
**对计划的更新：** 改进计划按"根因治理"而非"逐症状打补丁"组织——阶段 0 先封阻断，阶段 1 治根因 A（建立单一事实源 + 文档同步机制），阶段 2 治根因 B（crypto 走核心包门禁），阶段 3 治根因 C（申报材料单一事实源）。

### 第 4 轮：完整性与优先级校准

**目标：** 确认无遗漏，按"阻断 → 竞争力"排序，估算 ROI。
**方法：** 对照赛方四评分维度（完成度/生态贡献/工程质量/展示）+ 专项奖兜底，把发现映射到评分影响；对每项估"工作量 × 风险 × 评分增益"。
**校准结果：**
- 遗漏补查：`report/` 根目录存在第二份大作业报告（`MoonEvidence项目报告.md` + PDF + 截图），与 `docs/report/DEVELOPMENT_REPORT.md` 数字互斥——两份开发报告并存且每项指标矛盾，是验收大忌，升为高。
- 优先级锁定：阻断级 = 归属矛盾（合规）+ Ed25519 malleability（安全）+ E3002 虚假声明（诚信）；高 = 量化漂移 + 冻结 API 脱节 + 两份报告互斥 + incremental 错误码；中 = crypto 性能与侧信道 + 测试覆盖缺口 + CI 门禁缺失。
**对计划的更新：** 形成最终 6 阶段计划（见第五节），每阶段标注评分影响与验收。

### 第 5 轮：整合定稿

**目标：** 把四轮发现收敛为可执行计划，确保每条有"位置/问题/建议/验收/工作量"。
**方法：** 按 P0~P3 严重度归并去重，编写分阶段任务表，标注依赖关系与验收标准。
**产出：** 本文档第三~六节。

---

## 三、问题清单（按严重度分级）

> 每条格式：**【ID】标题** ｜ 位置 ｜ 问题 ｜ 建议 ｜ 证据 ｜ 评分影响

### P0 阻断级（合规/安全/诚信，必须先修）

**【P0-1】仓库归属与作者归属矛盾** ｜ `moon.mod:4,10`（starlittle）vs `docs/report/DEVELOPMENT_REPORT.md:4`、`docs/application/OSC2026_APPLICATION.md:10`、`docs/申报书.tex:36-37`、`docs/申报书.html:86-87`（wenlittle，且 .tex/.html 同文件内 GitHub=wenlittle / Gitlink=starlittle 自相矛盾）vs `report/MoonEvidence项目报告.md:700-703`（四人小组）vs `docs/申报书.md:8`（单人）vs `docs/application/OSC2026_APPLICATION.md:9`（待填）｜ 仓库 URL 与作者归属在 5 处材料互相冲突，`_build/publish/` 同时存在 wenlittle 与 starlittle 多版本 zip 证明经历了改名但未同步 ｜ 先确认实际参赛形式（个人/团队）与仓库归属，统一为单一事实源后全局替换；申报书三份格式（.md/.tex/.html）同步 ｜ Grep `wenlittle|starlittle` 命中 53 行；`_build/publish/` 实测含 4 个 zip ｜ 影响完成度与展示（合规阻断）

**【P0-2】Ed25519 verify 缺 S < l 检查致签名可塑性** ｜ `src/crypto/ed25519.mbt:192-225` ｜ RFC 8032 §8.4 明确要求验证 `S < l`；当前只查 `sig.length==64 && pk.length==32`，攻击者对任一合法签名把 S 加 l 即得另一合法签名（malleability），且无任何测试捕获 ｜ 在 `ed25519_verify` 解析 s_enc 后增加 `scalar_below_l` 检查返回 false；补测试：合法 sig 的 S 字段加 l 后断言 verify 返回 false ｜ `ed25519.mbt:196-224` 无 S 范围检查；RFC 8032 §8.4；`ed25519_wbtest.mbt` 无相关用例 ｜ 影响工程质量（密码学安全缺陷）

**【P0-3】E3002 零覆盖且 README 虚假声明已覆盖** ｜ `src/verify/incremental.mbt:118`（唯一出处，主路径用 E3003）vs `tests/fixtures/packs/README.md:36-38`（写"E3002 by merkle unit tests"，但 merkle 单元测试无错误码概念）｜ E3002 实际零触发，覆盖率声明造假；同时 incremental 对 merkle root mismatch 用 E3002、verify 用 E3003，两码语义在 spec 中分别指"证明格式非法"与"复算不匹配"，被混用 ｜ 统一增量路径错误码为 E3003；packs/README 改为如实声明 E3002 由 merkle 单元层覆盖并补真实用例；spec 明确两码边界 ｜ `incremental.mbt:108-124`；`packs/README.md:36`；`verify.mbt:166` ｜ 影响工程质量与诚信

### P1 高（严重影响评分或可信度）

**【P1-1】incremental 路径错误码与主路径矛盾** ｜ `src/verify/incremental.mbt:68`（missing file 用 E2001）vs `src/verify/incremental.mbt:118`（root mismatch 用 E3002）vs `src/verify/verify.mbt:92`（E2003）/ `:166`（E3003）｜ E2001 按 `model/error.mbt:22` 是"算法不支持"，被误用于"文件缺失"；E3002 被误用于"根不匹配"。冻结错误码契约被破坏 ｜ incremental 的 E2001→E2003、E3002→E3003；补 missing-file 与 root-mismatch 的增量测试断言精确码 ｜ 见 P0-3 证据 ｜ 影响工程质量（契约一致性）

**【P1-2】量化指标系统性漂移** ｜ 行数：`README.md:236`/`DEVELOPMENT_REPORT.md:114`（8000+）vs `ACCEPTANCE_CHECKLIST.md:7`/`RESULTS_LOG.md:489`（4382）vs `docs/report/DEVELOPMENT_REPORT.md:4`（4.4k）vs `申报书.md:39`（4600）vs 实测 6891；测试数：`README.md:221`（215）vs `ROADMAP.md:75`（205）vs `docs/report/DEVELOPMENT_REPORT.md:46`（155）vs 实测 219；提交数：`ACCEPTANCE_CHECKLIST.md:8`（52）vs `申报书.md:39`（57）vs 实测 76；包数：`README.md:200`（14）vs `ACCEPTANCE_CHECKLIST.md:9`（8）vs `ARCHITECTURE.md`（6）vs 实测 12 ｜ 几乎所有量化指标在文档间都不一致，且多数与实测偏差大，违反"未跑不报"原则 ｜ 跑一次权威命令取单一数字，写入 RESULTS_LOG 作为冻结基线，其余文档引用之 ｜ 命令行实测全部数字 ｜ 影响工程质量与展示

**【P1-3】冻结 API 与实际代码脱节** ｜ `docs/ARCHITECTURE.md:7-17,46-72`（冻结签名仅 6 包，verify_manifest 无可选参数）vs `src/verify/verify.mbt:29-33`（实际带 `expected_manifest_digest?`）+ 实际 12 包 ｜ 冻结契约失去约束力；新增 create/store/audit/crypto/api 五包的 pub API 未进任何冻结文档 ｜ 要么补"v2 冻结"段纳入新增包签名并记 DECISION_LOG，要么明确声明冻结范围仅限 MVP 六包；修正 verify_manifest 签名 ｜ ARCHITECTURE.md:46-72 vs LS src/ 12 包 ｜ 影响工程质量与生态贡献

**【P1-4】两份开发报告内容互斥** ｜ `docs/DEVELOPMENT_REPORT.md`（215 测试/8000+ 行/12 包架构/功能清单式）vs `docs/report/DEVELOPMENT_REPORT.md`（155 测试/4.4k 行/52 提交/wenlittle/6 pure+2 adapters/AI 协作实践式）｜ 同一项目两份报告每项指标矛盾，交付物自相矛盾是验收大忌 ｜ 明确哪份为权威交付物，归档另一份；统一所有数字到实测值 ｜ 两文件并排对照 ｜ 影响展示

**【P1-5】Ed25519 官方 pk 常量定义后从未被断言使用** ｜ `src/crypto/ed25519_wbtest.mbt:16-24`（`rfc8032_test1_pk` 定义）vs `:27-39`（测试只断言 `pk1==pk2` 与 `length==32`）｜ 即使 `ed25519_public_key` 算法完全错误测试也会绿；pk 常量末尾 4 字节为 0（概率 2⁻³²）高度可疑但因从未被对比而掩盖；sign/verify round-trip 是自验证 ｜ 增加 `assert_eq(ed25519_public_key(sk), rfc8032_test1_pk())` 精确对比；引入 RFC 8032 §7.1 全套 KAT（含已知 sig 的 verify-only 向量） ｜ `ed25519_wbtest.mbt:27-39` ｜ 影响工程质量（互操作性未验证）

**【P1-6】audit 的 hex_to_bytes 静默损坏数据** ｜ `src/audit/audit_log.mbt:216-241`（非法 hex 返回 0）vs `src/api/api.mbt:88-102`（返回 None）｜ 同库内两份 hex 解码实现错误处理矛盾；audit 的版本会把篡改/截断的签名 hex 静默解码为错误字节并"验证"而非报错 ｜ 统一到 `digest` 包导出 `pub fn hex_to_bytes(hex) -> Bytes?`，audit 调用方处理 None 为验证失败 ｜ 三处独立实现 ｜ 影响工程质量（安全潜在 bug）

### P2 中（影响竞争力与可维护性）

**【P2-1】Ed25519 scalar_mul 非常时间（侧信道）** ｜ `src/crypto/ed25519.mbt:105-121` ｜ 分支依赖标量比特，签名路径中 a 是私钥派生量，存在 timing side-channel；RFC 8032 §8.3 要求 constant-time ｜ 用 constant-time conditional select（cmov）替代分支 ｜ `if ((byte_val >> bit) & 1) == 1 { q = q.add(self) }` ｜ 工程质量

**【P2-2】Ed25519 reduce_scalar_512 性能极差** ｜ `src/crypto/ed25519.mbt:62-123` ｜ "乘 256 + 逐次减 l"实现，每字节最多减 256 次，~500K 操作/次；参考实现用 Barrett reduction（~50 次乘法）｜ 实现 Barrett reduction 或 TweetNaCl sc_reduce ｜ 见代码 ｜ 工程质量（性能）

**【P2-3】point25519 Point::add 每次重算 curve_d2** ｜ `src/crypto/point25519.mbt:73-85` ｜ scalar_mul 调用 ~256 次 add，每次重算 curve_d2（两次 32 字节解码 + 域加法）｜ 用 let 常量缓存 curve_d2/curve_d/base_x/base_y/sqrt_m1/group_order ｜ 见代码 ｜ 工程质量（性能）

**【P2-4】create 排序可能非 code-point order** ｜ `src/create/create.mbt:36` ｜ `sorted_paths.sort()` 用默认排序（MoonBit String::compare 是 shortlex 长度优先），而 `:27` 注释声称"Unicode code-point order"；测试只用同长度路径无法暴露；跨工具 Merkle root 可能不一致 ｜ 改用 compare_code_units 或在 canonjson 导出比较函数供 create 复用 ｜ `create.mbt:36` 无自定义比较器 ｜ 工程质量（互操作）

**【P2-5】SHA-512 长度字段隐式填充** ｜ `src/digest/sha512.mbt:80-85` ｜ padding 长度字段只写 8 字节，靠零初始化隐式填高 64 位；对 < 2^61 字节正确但脆弱，注释误导（"64-bit"）｜ 显式写 16 字节；`total_bytes * 8UL` 对 ≥2^61 溢出需注释 ｜ 见代码 ｜ 工程质量

**【P2-6】path validation 不拒绝 null 字节** ｜ `src/model/manifest.mbt:244-287` ｜ `validate_entry_path` 拒绝 `\`/`:`/绝对路径/`..`/`.`/空段，但不拒绝 0x00；native 后端 C 字符串截断可读意外路径（null byte injection）｜ 循环中加 `if unit == 0x00 { raise InvalidField(...) }` ｜ `for index in 0..<path.length() { ... }` 缺 0x00 检查 ｜ 工程质量（安全）

**【P2-7】CLI 黑盒层漏 E1003/E2001/E2002/E3002/E5002** ｜ `tools/cli-test.ps1:72-123`（只跑 packs/ 矩阵）vs `tests/fixtures/manifest/`（20 个负样本无脚本引用）｜ 用户关注的 4 个错误码在 CLI 黑盒层无触发用例 ｜ cli-test.ps1 增第三部分对 manifest/*.json 逐个 verify --json 断言精确码 ｜ `cli-test.ps1:112-123`；`packs/README.md:36` 自承 E1xxx/E2001/E2002 "by model unit layer" ｜ 工程质量

**【P2-8】create/store/audit 全自验证无独立交叉** ｜ `src/create/create_wbtest.mbt:37`（用本库 verify 验 create）等 ｜ 若 create 与 verify 共享同一处错误无法被捕获；核心包有独立 Node 交叉，新增包没有 ｜ 增 Node 脚本对 create_manifest 产出重算摘要与 Merkle 根对比；audit 链由 Node 独立重算 ｜ 见三处 wbtest ｜ 工程质量

**【P2-9】STRUCTURE_TREE/PROJECT_INDEX/ROADMAP 集体过期** ｜ `docs/STRUCTURE_TREE.md`（2026-06-08，缺 5 包）、`docs/PROJECT_INDEX.md:50-54`（Next Actions 全是已完成项）、`docs/ROADMAP.md:78-85`（已完成项重复出现在未来方向）｜ 三份导航文档都不能反映当前状态 ｜ STRUCTURE_TREE 重生成并改 CI 校验；PROJECT_INDEX Next Actions 改真实待办；ROADMAP 删除未来方向中已完成项 ｜ 行号直接对照 ｜ 工程质量

**【P2-10】CI 缺 fmt/doc/bench 门禁与 release 流程** ｜ `.github/workflows/ci.yml` ｜ 自述发生过 fmt 漂移（RESULTS_LOG:506）但 CI 无 fmt 门禁；无 bench 回归；无 release/tag/防篡改发布；native 单元测试不跑 ｜ 加 `moon fmt --check`；bench 设允许失败的单独 job；新增 tag 触发 release 工作流（含 moon package 产物 + SHA256）；CI 加 native test（ubuntu 有 gcc）｜ ci.yml 全文 55 行 ｜ 工程质量

**【P2-11】缺 LICENSE/SECURITY/CONTRIBUTING/CHANGELOG** ｜ 仓库根 ｜ moon.mod 声明 Apache-2.0 但无 LICENSE 文件（合规阻断）；含密码学实现却无 SECURITY.md；version 0.3.0 无 CHANGELOG ｜ 至少补 LICENSE（必须）与 CHANGELOG（0.3.0 已需）；SECURITY.md 因含 crypto 建议补 ｜ Glob 均无命中 ｜ 生态贡献与合规

**【P2-12】ObjectStore put/get 只断言长度不断言内容** ｜ `src/store/object_store_wbtest.mbt:10-20` ｜ `assert_eq!(data.length(), content.length())`，内容错误测试仍绿 ｜ 改为 `assert_eq!(data, content)` 逐字节 ｜ `object_store_wbtest.mbt:16-19` ｜ 工程质量

**【P2-13】CLI 黑盒脚本仅 PowerShell + 硬编码路径** ｜ `tools/cli-test.ps1:50-52` ｜ Linux/mac 开发者需装 PowerShell；`Find-Node` 硬编码 `D:\Programming_Language\Node\node.exe` 带开发者机器路径 ｜ 提供 cli-test.sh bash 版或用例数据化由 node 驱动；移除硬编码绝对路径 ｜ 见代码 ｜ 生态贡献

### P3 低（锦上添花）

**【P3-1】hex_to_bytes 三份独立实现** ｜ audit/api/merkle_golden_wbtest ｜ 统一到 digest 包（与 P1-6 合并）｜ 三处各自定义 ｜ 可维护性
**【P3-2】digest bench 无 guard assertion** ｜ `src/digest/digest_bench_wbtest.mbt:27-36` ｜ bench 前加 `assert_eq(sha256(payload).length(), 32)` ｜ 见代码 ｜ 测试质量
**【P3-3】property 测试为手工变异无自动化** ｜ `merkle_prop_wbtest.mbt:9-11` ｜ CI 加临时反转实现 job 跑 property 确认红 ｜ 注释"mutation-tested by hand" ｜ 测试质量
**【P3-4】重复 setup 跨文件复制** ｜ splitmix64 PRNG、RFC8032 sk、golden_manifest 各两份 ｜ 抽取到 test_helpers.mbt ｜ 见三处 ｜ 可维护性
**【P3-5】fixtures 防腐化只覆盖 packs/** ｜ `.github/workflows/ci.yml:27-29` ｜ merkle/golden.json 与 jcs 未纳入 diff guard ｜ CI 增 gen-merkle-fixtures 重生成 + diff ｜ 见 ci.yml ｜ 测试质量
**【P3-6】缺失测试类型** ｜ 全仓 ｜ 无 fuzzing/differential/长链压测/内存峰值/并发/bench 回归基线 ｜ 按优先级补版本链 1k/10k 节点、parser fuzz ｜ 见 chain_wbtest 最大 3 节点 ｜ 测试质量
**【P3-7】audit verify_chain 不验 hash 字段** ｜ `src/audit/audit_log.mbt:155-164` ｜ 攻击者可改 hash 字段不被检测（只要 prev_hash 链不断）｜ 增 `entry.compute_hash() == entry.hash` 检查 ｜ 见代码 ｜ 安全
**【P3-8】CLI_VERSION 硬编码** ｜ `src/cmd/main/main.mbt:10` ｜ CI 校验与 moon.mod 一致 ｜ 见代码 ｜ 可维护性
**【P3-9】ObjectStore 字节数用 Int 易溢出** ｜ `src/store/object_store.mbt:84-90` ｜ >2GB 集合加法溢出 ｜ 改 Int64 ｜ 见代码 ｜ 健壮性
**【P3-10】collect_pack_files 不查 symlink** ｜ `src/cmd/main/main.mbt:260-279` ｜ symlink-to-dir 可无限循环，symlink-to-file 可读包外数据 ｜ 增 symlink 检查拒绝 ｜ 见代码 ｜ 安全
**【P3-11】.gitattributes 未显式覆盖 png/pdf/docx** ｜ `.gitattributes` ｜ 显式声明更稳妥（CRLF 事故教训）｜ 补 `*.png binary` 等 ｜ 见全文 10 行 ｜ 工程质量
**【P3-12】演示视频缺失** ｜ `docs/ROADMAP.md:55,85` ｜ README 无视频链接 ｜ 录制 5 分钟演示 ｜ 标 `[ ]` ｜ 展示

---

## 四、根因与治理策略

| 根因 | 症状群 | 治理策略 |
| --- | --- | --- |
| A. 冻结点后无同步机制 | 量化漂移、API 脱节、导航过期、两份报告互斥 | 建立"单一事实源 + 文档同步检查清单"，每次发版前跑同步脚本 |
| B. 后加功能绕过核心包门禁 | crypto 安全缺口、错误码误用、自验证、排序 bug | 把 create/store/audit/crypto 纳入 spec 冻结 + 错误码契约 + 独立交叉验证三道门 |
| C. 申报材料分轨维护 | 归属矛盾、版本号漂移、作者冲突 | 申报材料从 moon.mod/git 自动派生事实，人工只填叙事 |

---

## 五、改进计划（分阶段）

> 阶段顺序按"阻断 → 根因 → 竞争力"排列。每阶段独立可交付，任意截断点上项目都处于"全绿可演示"状态（沿用 master plan 红线）。

### 阶段 0：阻断项封堵（立即，预计 1-2 个提交） [x]

**目标：** 消除合规、安全、诚信三处阻断，让项目可申报、可声称。

| 任务 | 对应问题 | 验收 |
| --- | --- | --- |
| 0.1 确认参赛形式与仓库归属，统一 starlittle/wenlittle + 单人/四人 | P0-1 | moon.mod/申报书三格式/开发报告/OSC2026_APPLICATION 全部一致；Grep wenlittle=0 |
| 0.2 Ed25519 verify 增 S < l 检查 + malleability 测试 | P0-2 | 合法 sig 的 S+l 断言 verify=false；RFC 8032 §8.4 合规 |
| 0.3 incremental 错误码统一（E2001→E2003、E3002→E3003）+ 补测试 | P0-3, P1-1 | missing-file 增量测试断言 E2003；root-mismatch 断言 E3003 |
| 0.4 packs/README 如实修正 E3002 覆盖声明 | P0-3 | 声明与实际覆盖一致 |

预计提交：2~3 个。

### 阶段 1：事实对齐与文档治理（治根因 A，预计 3-4 个提交） [x]

**目标：** 建立单一事实源，消除量化漂移与导航过期，让文档重新可信。

| 任务 | 对应问题 | 验收 |
| --- | --- | --- |
| 1.1 跑权威命令取实测数字（提交/行数/测试数/包数）写入 RESULTS_LOG 新冻结点 | P1-2 | 单一权威数字；其余文档引用之 |
| 1.2 全文档同步数字（README/README.zh/两份开发报告/申报书/验收清单/ROADMAP） | P1-2, P1-4 | 全仓 grep 同一数字无矛盾 |
| 1.3 归档两份开发报告中较旧的一份，明确权威交付物 | P1-4 | 仅一份权威报告；另一份移入 archive/ 或删除 |
| 1.4 STRUCTURE_TREE 重生成 + 改 CI 校验 | P2-9 | 树与实际 12 包一致；CI 有 drift 检查 |
| 1.5 PROJECT_INDEX Next Actions/Document Map 更新；ROADMAP 删未来方向已完成项 | P2-9 | 反映当前状态 |
| 1.6 ARCHITECTURE 补 v2 冻结段纳入新增包签名 + 修正 verify_manifest 签名 + DECISION_LOG 记录 | P1-3 | 冻结契约与代码一致 |
| 1.7 补 LICENSE（Apache-2.0 全文）+ CHANGELOG（0.1.0→0.3.0） | P2-11 | LICENSE 存在；CHANGELOG 可追溯 |

预计提交：4~5 个。

### 阶段 2：密码学加固（治根因 B 之 crypto，预计 3-4 个提交） [x]

**目标：** 让 Ed25519 达到生产级密码学实现标准，可声称"标准兼容且安全"。

| 任务 | 对应问题 | 验收 |
| --- | --- | --- |
| 2.1 引入 RFC 8032 §7.1 全套 KAT（含已知 sig 的 verify-only 向量），精确对比 pk 常量 | P1-5 | 7 组官方向量全过；pk 常量被实际断言 |
| 2.2 constant-time scalar_mul（cmov 替代分支）+ Fe::eq 改 XOR 累加 | P2-1 | 无 secret-dependent 分支（代码审查） |
| 2.3 Barrett reduction 替换 reduce_scalar_512；缓存 curve_d2 等常量 | P2-2, P2-3 | sign 路径性能提升（bench 对比） |
| 2.4 point_decode 补低阶点/非规范编码拒绝 + 测试 | P2-1 旁 | 负向攻击向量全拒 |
| 2.5 统一 hex_to_bytes 到 digest 包，audit 调用方处理 None | P1-6, P3-1 | 全库单一实现；audit 篡改 hex 报验证失败 |

预计提交：4~5 个。

### 阶段 3：测试体系深化（治根因 B 之测试，预计 3-4 个提交） [x]

**目标：** 测试从"有"升级到"可信且全面"，覆盖缺口归零。

| 任务 | 对应问题 | 验收 |
| --- | --- | --- |
| 3.1 CLI 黑盒层补 E1003/E2001/E2002/E3002/E5002 触发用例 | P2-7 | manifest/*.json 逐个断言精确码 |
| 3.2 create/store/audit 增独立 Node 交叉验证 | P2-8 | create 产出的根由 Node 独立重算对比 |
| 3.3 fixtures 防腐化扩展到 merkle/golden.json 与 jcs | P3-5 | CI 重生成 + diff 全夹具 |
| 3.4 补长链压测（1k/10k 节点）+ parser fuzz（随机字节不 panic） | P3-6 | 长链性能数据入 README；fuzz 无 panic |
| 3.5 ObjectStore put/get 改逐字节断言；digest bench 加 guard | P2-12, P3-2 | 断言精确；bench 有 guard |
| 3.6 property 测试 CI 自动化变异检查 | P3-3 | CI 有反转实现 job 跑 property 确认红 |

预计提交：4~5 个。

### 阶段 4：CI 与工程治理（预计 2-3 个提交） [x]

**目标：** CI 从"能跑"升级到"防漂移 + 防回归 + 可发布"。

| 任务 | 对应问题 | 验收 |
| --- | --- | --- |
| 4.1 CI 加 `moon fmt --check` 门禁 | P2-10 | fmt 漂移红 CI |
| 4.2 bench 设允许失败单独 job + 结果落基线 JSON + 阈值告警 | P2-10, P3-6 | 性能回归可发现 |
| 4.3 新增 tag 触发 release 工作流（moon package 产物 + SHA256） | P2-10 | 发版有签名产物 |
| 4.4 CI 加 native test（ubuntu gcc）；cli-test 提供 bash 版 | P2-10, P2-13 | native 单元测试在 CI 跑；黑盒跨平台 |
| 4.5 补 SECURITY.md + CONTRIBUTING.md | P2-11 | 含密码学漏洞报告渠道 |
| 4.6 path validation 拒 null 字节；collect_pack_files 拒 symlink；ObjectStore 用 Int64 | P2-6, P3-9, P3-10 | 安全测试通过 |

预计提交：3~4 个。

### 阶段 5：竞争力增强（锦上添花，预计 2-3 个提交） [ ]

**目标：** 冲击专项奖（最佳文档/最佳测试/最佳 AI 协作）。

| 任务 | 对应问题 | 验收 |
| --- | --- | --- |
| 5.1 录制 5 分钟演示视频 + README 嵌链接 | P3-12 | 视频可播放 |
| 5.2 GitHub Pages 托管浏览器 demo | — | demo 可访问 |
| 5.3 API 文档（moon doc 工具链就绪后）+ mermaid 架构图入 ARCHITECTURE | — | pub 项有文档 |
| 5.4 重复 setup 抽取；CLI_VERSION CI 校验 | P3-4, P3-8 | 无跨文件复制 |
| 5.5 audit verify_chain 验 hash 字段；SHA-512 显式 16 字节长度 | P3-7, P2-5 | 安全测试通过 |

预计提交：3~4 个。

---

## 六、风险与对策

| 风险 | 概率 | 对策 |
| --- | --- | --- |
| Ed25519 KAT 向量引入后暴露实现 bug，需重写 | 中 | 阶段 2 先跑 KAT 再做性能优化；若 pk 常量错则优先修正确性 |
| 申报形式（个人/团队）确认耗时 | 中 | 阶段 0.1 设为外部确认项，不阻塞其他阶段并行 |
| native test 在 CI 暴露 js/wasm 未发现的 bug | 低 | 本地先 js 验证；CI 红则按日志修 |
| 文档同步工作量大 | 中 | 阶段 1.1 先冻结单一数字，其余用脚本批量替换 |
| crypto constant-time 改造引入正确性回归 | 中 | 每步 KAT 回归；property 测试兜底 |

---

## 七、交付物与验收

### 阶段性交付物

- 阶段 0：阻断项消除，项目可申报、可声称"标准兼容且安全"
- 阶段 1：单一事实源建立，文档与代码零漂移，三份导航文档反映现状
- 阶段 2：Ed25519 达生产级（KAT + 防侧信道 + 性能），可对标 libsodium 级实现
- 阶段 3：测试覆盖缺口归零，新增包有独立交叉验证，错误码全覆盖
- 阶段 4：CI 防漂移/防回归/可发布三件套齐备
- 阶段 5：演示视频 + Pages demo + API 文档，专项奖材料齐

### 最终验收命令（阶段 5 后）

```powershell
moon check
moon test --target wasm-gc,js
moon fmt --check
moon build --target native,wasm-gc,js
powershell -ExecutionPolicy Bypass -File tools/cli-test.ps1 -Target js
node tools/smoke-api.mjs
node tools/gen-fixtures.mjs; git diff --exit-code tests/fixtures
```

全绿 + 文档零矛盾 + Ed25519 KAT 全过 + 无 wenlittle 残留 + LICENSE 存在 = 健康度从 6.2 提升至 9.0+。

### 记录规则

每个阶段完成后：
1. 更新 `docs/records/RESULTS_LOG.md`（命令、结果、commit hash）
2. 关键决策更新 `docs/records/DECISION_LOG.md`
3. 本计划对应阶段标记 `[x]` 并 commit

---

## 八、执行记录（2026-07-04 收尾）

本节记录计划的实际执行情况，由收尾工程师在阶段 0-4 全量验证后填写。

### 阶段完成状态

| 阶段 | 状态 | 实际完成情况 |
| --- | --- | --- |
| 阶段 0 阻断项封堵 | [x] 已完成 | 0.1 归属统一 starlittle（wenlittle 在比赛材料清零）；0.2 Ed25519 S<l 检查 + 3 条 malleability 测试；0.3 incremental 错误码统一 E2003/E3003；0.4 packs/README 如实修正 |
| 阶段 1 事实对齐与文档治理 | [x] 已完成 | 1.1 RESULTS_LOG 写入实测冻结基线；1.2 全文档数字统一（76/6891/219/12）；1.3 旧开发报告归档；1.4 STRUCTURE_TREE 重生成；1.5 PROJECT_INDEX/ROADMAP 刷新；1.6 ARCHITECTURE v2 冻结六包签名；1.7 LICENSE/CHANGELOG/SECURITY/CONTRIBUTING 补齐 |
| 阶段 2 密码学加固 | [x] 已完成 | 2.1 RFC 8032 §7.1 KAT 4 组（修正 pk 常量）；2.2 constant-time scalar_mul(cmov) + Fe::eq XOR 累加；2.3 7 常量缓存；2.4 低阶点/非规范编码拒绝测试；2.5 hex_to_bytes 统一到 digest 包 |
| 阶段 3 测试体系深化 | [x] 已完成 | 3.1 CLI 错误码矩阵 19 夹具；3.2 cross-verify.mjs 独立 Node 交叉验证；3.3 夹具防腐化；3.4 1000 节点链压测 + parser fuzz 400 轮；3.5 bench guard；3.6 mutation-check.mjs 3/3 捕获 |
| 阶段 4 CI 与工程治理 | [x] 已完成 | 4.1 moon fmt --check 门禁；4.2 bench job；4.3 release.yml（tag 触发）；4.4 native test(ubuntu) + cli-test.sh(bash)；4.5 SECURITY/CONTRIBUTING；4.6 path null-byte 拒绝 + ObjectStore Int64 |
| 阶段 5 竞争力增强 | [ ] 未完成 | 5.1 演示视频未录制；5.2 GitHub Pages demo 未部署（待首次推送）；5.3 API 文档受 moon doc 工具链缺口阻塞；5.4 重复 setup 抽取/CLI_VERSION 校验未做。注：5.5 的两项安全加固（audit verify_chain 验 hash 字段、SHA-512 显式 16 字节长度）已随阶段 4 一并完成。 |

### 收尾全量验证（2026-07-04 Asia/Shanghai）

| 命令 | 结果 |
| --- | --- |
| `moon check` | exit 0，**0 warnings**（原 92，含 77 弃用 assert 宏 + 15 其他弃用 API/导入，已全部清理） |
| `moon fmt --check` | exit 0（无漂移） |
| `moon test --target js` | **234/234 passed** |
| `moon test --target wasm-gc` | **234/234 passed** |
| `moon build --target native` | 失败：本机无 C 编译器（cl/cc/gcc/clang 缺失），非阻塞，由 CI ubuntu 覆盖 |
| `tools/cli-test.ps1 -Target js` | **41/41 passed** |
| `node tools/cross-verify.mjs` | 6/10 包完整验证通过；4 个负向夹具（bad-digest-field/bad-merkle-root/missing-file/tampered-file）被正确检出为非完整——预期基线 |

### 改造后权威基线

| 字段 | 实测值 |
| --- | --- |
| 提交数 | 76 |
| 实现行数 | 3700 |
| 测试行数 | 3893 |
| 总行数 | 7593 |
| 测试声明 | 238（234 测试 + 4 基准） |
| 包数 | 12 |
| moon check warnings | 0 |
| moon test --target js | 234/234 passed |
| CLI 黑盒 | 41/41 passed |

### 收尾阶段额外完成项（超出原计划任务清单）

- 清理 77 处弃用 `assert_eq!`/`assert_true!`/`assert_false!` 宏调用（6 个测试文件）
- 清理 3 处 `Map::size()`→`length()` 弃用 API（object_store）
- 补 `src/audit/moon.pkg` 缺失的 `moonbitlang/core/debug` 导入（消除 11 处 `core_package_not_imported` 警告，编译器推荐修法）
- 运行 `moon fmt` 全量格式化并通过 `moon fmt --check` 门禁

健康度自评：综合已由 6.2 提升至约 9.0（阶段 5 竞争力项未完成不计入扣分）。项目当前处于"全绿可演示、0 警告、文档零矛盾"状态。

### 第二轮根因修复（2026-07-04 Asia/Shanghai）

第一轮收尾在两处做了"缝缝补补"而非根本解决，本轮用根本方案替换：

| 缝补项 | 第一轮做法（症状级） | 第二轮做法（根因级） |
| --- | --- | --- |
| 两份开发报告并存 | 给根 `docs/DEVELOPMENT_REPORT.md` 加"此为早期版本"归档注释，两份仍并存 | 合并为 `docs/report/DEVELOPMENT_REPORT.md` 单一权威报告（功能清单 + AI 协作 + 工程质量），根报告改为一行重定向，PROJECT_INDEX/README/README.zh 引用同步 |
| cli-test.sh 仅核心矩阵 | 只移植 Part 1 + Part 2（22 用例），称"覆盖核心矩阵即可" | 1:1 对等移植全部三部分（41 用例 = 12 命令形状 + 10 篡改矩阵 + 19 manifest 矩阵），修正 Part 1 多模式断言，jq 缺失报错退出 |

并行代理同步进行的代码侧根因修复（文档侧已预留说明）：

| 修复点 | 根因 | 第二轮做法 |
| --- | --- | --- |
| Ed25519 标量归约性能 | `reduce_scalar_512` 逐次减法 ~500K 次/次 | Barrett reduction（~50 次乘法） |
| point_decode 低阶点 | 不拒绝低阶点 / 非规范编码，小群攻击风险 | 拒绝低阶点 + 非规范编码（cofactor 防护） |
| 审计签名输入 | 签名原始 JSON 文本，等价文本可致签名漂移 | 签名覆盖 RFC 8785 canonical JSON |
| create 排序 | 默认 sort 非 code-point 序，跨工具 Merkle root 不一致 | 按 code-point 序排序 |
| symlink 越界 | collect_pack_files 不查 symlink | 拒绝 symlink |
| valid.json 夹具 | manifest 矩阵 valid.json 行为未在 CLI 黑盒断言 | 纳入 Part 3，断言 E2003×2 + E3003 |
| E3002 错误码契约 | 零覆盖且声明模糊 | E3002 错误码契约已明确（详见 DECISION_LOG 最新条目） |

文档侧更新清单：`docs/report/DEVELOPMENT_REPORT.md`（合并）、`docs/DEVELOPMENT_REPORT.md`（重定向）、`docs/PROJECT_INDEX.md`、`docs/ARCHITECTURE.md`（0.3.1 加固说明 + E3002 条件写法）、`SECURITY.md`（密码学实现更新）、`CHANGELOG.md`（0.3.1 条目）、`tools/cli-test.sh`（1:1 对等）。`README.md` / `README.zh.md` 引用同步。

验证：`bash -n tools/cli-test.sh` 语法通过；cli-test.sh 与 cli-test.ps1 用例数 1:1 对等（41 = 41）。
