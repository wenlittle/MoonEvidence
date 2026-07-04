# MoonEvidence 健康体检与改进计划（第 2 轮，5 轮迭代）

> **面向 AI 代理的工作者：** 本计划是对项目做第二轮"如何把它做好"的全面健康体检后的改进路线，不是最小可改补丁清单。执行时使用 executing-plans 逐步骤实现；每个阶段完成后必须更新 `docs/records/RESULTS_LOG.md` 并单独 commit。**本轮只产出计划，不改任何代码。**

**体检日期：** 2026-07-04 Asia/Shanghai（紧接第 1 轮收尾之后）
**体检方法：** 5 轮迭代式勘察——广度扫描 → 定向核验 → 根因分析 → 完整性与优先级校准 → 整合定稿。三维度（源码 / 测试 / 文档与治理）并行深审 + 命令行权威数字核验。
**体检范围：** `src/` 全部 12 包 48 个 `.mbt` 文件、`tests/` 全部夹具、`tools/` 全部 10 个脚本、`docs/` 全部文档、CI 与构建配置、`moon.mod`/`moon.pkg`、`demo/`、`examples/`、根目录治理文件。
**与第 1 轮的关系：** 第 1 轮（同日早些时候）已完成阶段 0-4 + 第二轮根因修复，自评健康度 6.2 → 9.0。本轮在第 1 轮基础上复核，发现"事实对齐"机制本身存在系统性缺陷，量化漂移已在 3 个提交内重新出现，且增量验证路径存在未被第 1 轮捕获的功能性缺口。

**权威基线（本机实测，第 2 轮）：** 提交 **79**（第 1 轮记 76）；实现 **4024** 行 + 测试 **4344** 行 = **8368** 行（第 1 轮记 7593）；测试声明 **240**（第 1 轮记 234）；包 **12** 个（一致）；`moon.mod` 版本 **0.3.0**（CHANGELOG 已有 0.3.1 条目，版本未同步）；`wenlittle` 在比赛材料中 **0** 处（治理生效）；`moon check` 0 警告（治理生效）。

---

## 一、健康体检总览

### 三维度评分（第 2 轮）

| 维度 | 第 1 轮评分 | 第 2 轮评分 | 一句话诊断 |
| --- | --- | --- | --- |
| 源码架构与质量 | 7.5 / 10 | **8.0 / 10** | 第 1 轮 crypto 加固生效（S<l、Barrett、cofactor）；但增量路径计算 canonical JSON 后 `ignore` 丢弃，跳过 E2004 manifest 摘要断言，是主路径与增量路径的功能性契约分裂 |
| 测试与验证 | 6.5 / 10 | **7.5 / 10** | 240 测试全绿、CLI 41 用例、cross-verify 独立交叉、fuzz/长链已补；但增量路径 E2004 缺口无测试捕获，bench 声明计数口径误导（4 个 `b.bench()` 调用 ≠ 4 个 `bench` 声明） |
| 文档与工程治理 | 4.5 / 10 | **6.0 / 10** | 第 1 轮建立了 RESULTS_LOG 单一事实源与 STRUCTURE_TREE 重生成，但**机制本身在 3 个提交内即失效**——79/8368/240 的实测值未同步到任何文档，ACCEPTANCE_CHECKLIST 仍停在第 1 轮冻结前的 76/6891，STRUCTURE_TREE 仍写"22 用例"且漏 3 个 tools 文件 |
| **综合** | 6.2 / 10 | **7.2 / 10** | 第 1 轮把项目从"冻结快照分裂"拉到"全绿可演示"，但"事实对齐"是人工流程非自动门禁，漂移复发是结构性问题；增量路径契约缺口是新发现 |

### 核心问题一句话诊断（第 2 轮）

第 1 轮建立了"RESULTS_LOG 冻结基线 + 文档同步"的治理机制，但**该机制是程序性的（依赖人记得重跑），不是自动化的（无 CI 门禁强制文档数字 == 实测数字）**。第 1 轮收尾后仅 3 个提交（root-cause round 2 系列），量化指标已从 76/7593/234 漂移到 79/8368/240，而 README/README.zh/开发报告/CHANGELOG/ACCEPTANCE_CHECKLIST/STRUCTURE_TREE 全部停在旧值。这证明：**没有 CI 强制对齐的"单一事实源"必然复发漂移**。叠加增量验证路径 silently 跳过 E2004（计算后丢弃）、moon.mod 版本与 CHANGELOG 不一致、Stage 5 竞争力项全部未动，项目距离一等奖仍差"自动防漂移 + 功能契约完整 + 展示材料齐备"三块。

---

## 二、五轮勘察记录

### 第 1 轮：广度扫描（基线建立）

**目标：** 建立第 2 轮三维度基线，不预设结论。
**方法：** 命令行实测提交/行/测试/包数；grep `wenlittle`/`TODO`/`pub(all)`/`@fs` 信号；对照第 1 轮自评基线核验。
**新发现（要点）：**
- 提交数 **79**（第 1 轮记 76，3 个 round-2 提交后未同步）。
- 实现行数 **4024** + 测试行数 **4344** = **8368**（第 1 轮记 3700+3893=7593；ACCEPTANCE_CHECKLIST 更旧，记 3590+3301=6891）。
- 测试声明 **240**（第 1 轮记 234）。
- `wenlittle` 在比赛材料（申报书三格式/开发报告/OSC2026_APPLICATION/README/moon.mod）中 **0** 处——第 1 轮 P0-1 治理生效，仅历史日志与诊断文档保留记录（合理）。
- `pub(all)` 22 处全部用于数据类型（enum/struct）字段公开，是 MoonBit 正常模式，非问题。
- `@fs`/`@env`/`@sys` 全部在 `src/cmd/main/main.mbt`——IO 隔离边界干净。
- 源码无真实 TODO/FIXME（仅一处注释提到"not TODOs"是反向说明）。
- bench 声明：`grep '^bench '` 返回 0，实际是 4 处 `b.bench(...)` 调用包在 `test` 块内——RESULTS_LOG"238（234 测试 + 4 基准）"的口径误导。
**对计划的更新：** 确立"量化漂移复发"为第 2 轮头号发现，把"自动防漂移门禁"升为高优先级。

### 第 2 轮：定向核验（关键断言实测）

**目标：** 验证第 1 轮声称已修复的项是否真的修复且未退化；核验文档数字一致性。
**方法：** 实读 `incremental.mbt`、`verify.mbt`、`ed25519.mbt`、`audit_log.mbt`；逐文档 grep 量化数字；对照 CHANGELOG/STRUCTURE_TREE/ROADMAP 与实际文件。
**新发现：**
- **Ed25519 S<l 检查生效**：`ed25519.mbt:251` `scalar_lt_l(s_enc)` 存在（第 1 轮 P0-2 治理生效）。
- **audit verify_chain 验 hash 字段生效**：`audit_log.mbt:159-160` `entry.compute_hash()` vs `entry.hash` 比较存在（第 1 轮 P3-7 治理生效）。
- **主路径 E2004 存在**：`verify.mbt:65-74` 验证 `expected_manifest_digest`。
- **【新发现】增量路径跳过 E2004**：`incremental.mbt:49-52` 计算 `canonical_json = @canonjson.canonicalize(manifest_json) catch { _ => manifest_json }` 然后 `ignore(canonical_json)`——canonical 形式算了但丢弃，从未断言 manifest 摘要。这意味着 `verify_manifest_incremental` 不是 `verify_manifest` 的性能优化等价物，而是**静默弱化的验证**（少一道完整性检查）。第 1 轮未捕获。
- **【新发现】CHANGELOG 0.3.1 条目存在但 moon.mod 仍 0.3.0**：CHANGELOG 记录了 Barrett reduction、canonical JSON 签名、低阶点拒绝等实质性变更，按 SemVer 应 bump patch 到 0.3.1，但 `moon.mod:6` 仍是 `version = "0.3.0"`。版本与变更记录脱节。
- **【新发现】STRUCTURE_TREE 仍写"22 用例"且漏 3 个 tools 文件**：`docs/STRUCTURE_TREE.md:170` 注释 `cli-test.ps1 # 22 用例黑盒 CLI 套件`，实际 41 用例；`tools/` 实际 10 个文件（含 `cli-test.sh`/`cross-verify.mjs`/`mutation-check.mjs`/`check-fixtures.mjs`），STRUCTURE_TREE 只列 7 个。第 1 轮阶段 1.4 标记 STRUCTURE_TREE 重生成 `[x]`，但显然未真正重生成或重生成后被回退。
- **README.md:221 "234 unit tests"** vs 实测 240；**README.md:236 "implementation 3700 + tests 3893"** vs 实测 4024+4344。
- **docs/report/DEVELOPMENT_REPORT.md:4 "7593 行 / 76 个提交"** vs 实测 8368 / 79。
- **CHANGELOG 0.3.1 "76 提交 / 7593 行 / 234 测试"** vs 实测 79 / 8368 / 240。
- **ACCEPTANCE_CHECKLIST 全文停在 76/6891/3590/3301**（第 1 轮冻结前旧值，阶段 1.2 声称"全文档同步数字"但此文件漏改）。
**对计划的更新：** 把"增量路径 E2004 缺口"升为新 P1；把"版本与 CHANGELOG 不同步"升为新 P1；把"STRUCTURE_TREE 重生成未真正执行"从第 1 轮的 `[x]` 改判为**未完成**。

### 第 3 轮：根因分析（跨维度交叉）

**目标：** 找出第 2 轮问题之间的因果链，区分"症状"与"病因"。
**方法：** 把第 1、2 轮发现按"是否共享同一上游根因"聚类。
**根因结论：**
1. **根因 A'（第 1 轮根因 A 的残留）：单一事实源机制是程序性的，非自动化的。** 第 1 轮把 RESULTS_LOG 当冻结基线，但：① 没有机制在每次 commit 后自动重测并回写；② 没有 CI 门禁断言"README/报告/清单中的数字 == 实测"；③ round-2 的 3 个提交改了代码与文档但作者忘了重测基线。结果是"单一事实源"本身在第 1 轮收尾时已是旧值（76/7593/234），此后再无刷新。**只要机制靠人，漂移必然复发**——这是结构性缺陷，不是疏忽。
2. **根因 B'（新）：增量验证与全量验证的功能契约未对齐。** 第 1 轮修了错误码（E2001→E2003、E3002→E3003），但没检查"增量路径是否覆盖主路径的全部验证步骤"。incremental.mbt 计算 canonical JSON 后丢弃，等于跳过 step 3（manifest 摘要断言 E2004）。这是"增量是优化的隐含契约"被违反——用户合理期望 `verify_manifest_incremental` 与 `verify_manifest` 在相同输入下产出相同 `ok`，但前者少一道检查。
3. **根因 C'（第 1 轮根因 C 残留 + 新）：版本治理缺位。** moon.mod 版本与 CHANGELOG 不同步是 SemVer 治理缺位；STRUCTURE_TREE"重生成 [x]"但实际未执行是"任务勾选与实际完成"脱节——两者同源于"完成判定无客观验收命令"。
4. **根因 D'（持续）：Stage 5 竞争力项零进展。** ROADMAP 中演示视频仍 `[ ]`（两处重复列出），GitHub Pages demo、API 文档、重复 setup 抽取全部未动。项目"全绿可演示"但缺展示材料，距离专项奖仍差临门一脚。
**对计划的更新：** 第 2 轮改进计划按"根因治理"组织——阶段 0 先补自动防漂移门禁（治根因 A'），阶段 1 补增量契约对齐（治根因 B'），阶段 2 补版本与结构树治理（治根因 C'），阶段 3 推进 Stage 5 竞争力（治根因 D'）。

### 第 4 轮：完整性与优先级校准

**目标：** 确认无遗漏，按"阻断 → 竞争力"排序，估算 ROI。
**方法：** 对照赛方四评分维度（完成度/生态贡献/工程质量/展示）+ 专项奖兜底，把发现映射到评分影响；对每项估"工作量 × 风险 × 评分增益"。
**校准结果：**
- **遗漏补查**：增量路径 E2004 缺口是否影响 CLI？查 `main.mbt` 的 `verify` 命令是否调用 incremental——若 CLI 只走全量路径，则 E2004 缺口仅影响库 API 直接调用者，严重度降为"库契约"而非"用户可见"。需在阶段 1 确认。
- **优先级锁定**：
  - **P1 高（影响可信度与契约）**：量化漂移复发（79/8368/240 未同步）+ 自动防漂移门禁缺失；增量路径跳过 E2004；moon.mod 版本与 CHANGELOG 不同步；STRUCTURE_TREE 漏 3 文件且用例数错；ACCEPTANCE_CHECKLIST 停在旧值。
  - **P2 中（影响竞争力）**：Stage 5 演示视频/Pages/API 文档未做；ROADMAP 重复列已完成项与未完成项混排；bench 声明计数口径误导。
  - **P3 低（锦上添花）**：根目录 `_capwin.ps1`/`_mev_cap.ps1`/`_mev_run.ps1`/`_termsetup.ps1` 为开发者本地脚本，建议移入 `tools/local/` 或 `.gitignore`。
- **评分影响映射**：防漂移门禁 → 工程质量 + 展示可信度；增量契约对齐 → 工程质量；Stage 5 → 展示（专项奖兜底）。
**对计划的更新：** 形成最终 4 阶段计划（见第五节），每阶段标注评分影响与验收。

### 第 5 轮：整合定稿

**目标：** 把四轮发现收敛为可执行计划，确保每条有"位置/问题/建议/验收/工作量"。
**方法：** 按 P1~P3 严重度归并去重，编写分阶段任务表，标注依赖关系与验收标准。
**产出：** 本文档第三~六节。

---

## 三、问题清单（按严重度分级）

> 每条格式：**【ID】标题** ｜ 位置 ｜ 问题 ｜ 建议 ｜ 证据 ｜ 评分影响

### P1 高（影响可信度与契约，必须修）

**【P1-1】量化漂移复发，且"单一事实源"机制本身失效** ｜ README.md:221,236 / README.zh.md / docs/report/DEVELOPMENT_REPORT.md:4 / CHANGELOG.md:11 / docs/records/ACCEPTANCE_CHECKLIST.md:7-8,13 / docs/records/RESULTS_LOG.md:576-587 ｜ 实测 79 提交 / 8368 行 / 240 测试，但 README 写 234 测试 / 7593 行，开发报告写 76 提交 / 7593 行，CHANGELOG 0.3.1 写 76/7593/234，ACCEPTANCE_CHECKLIST 更旧写 76/6891/3590/3301。第 1 轮建立的 RESULTS_LOG 冻结基线（76/7593/234）在 round-2 的 3 个提交后未刷新，证明机制靠人不可靠 ｜ ① 立即重测并回写所有文档到 79/8368/240；② **建立 CI 自动门禁**：新增 `tools/check-metrics.mjs`，跑 git/wc/grep 取实测数字，正则扫描 README/报告/清单/CHANGELOG 中的数字断言，不一致则 CI 红；③ RESULTS_LOG 每次发版前由该脚本自动更新 ｜ 命令行实测全部数字 ｜ 影响工程质量与展示可信度

**【P1-2】增量验证路径跳过 E2004 manifest 摘要断言** ｜ `src/verify/incremental.mbt:49-52` ｜ 主路径 `verify.mbt:64-78` 在 step 3 用 canonical manifest 摘要比对 `expected_manifest_digest`（E2004）；增量路径 `incremental.mbt:49-52` 计算 `canonical_json` 后 `ignore(canonical_json)` 丢弃，从未断言。`verify_manifest_incremental` 不是 `verify_manifest` 的性能等价物，而是 silently 弱化的验证。用户若用增量路径做"快速复核"，会漏掉 manifest 被篡改但文件摘要仍匹配的攻击 ｜ ① 增量路径补 E2004 断言（与主路径同逻辑，复用 canonical_json）；② 补测试：构造 manifest 摘要不匹配的用例，断言增量路径返回 E2004；③ 在 ARCHITECTURE 补"增量路径与主路径验证步骤等价性"契约说明 ｜ `incremental.mbt:49-52` `ignore(canonical_json)`；`verify.mbt:64-78` 有 E2004 ｜ 影响工程质量（安全契约分裂）

**【P1-3】moon.mod 版本 0.3.0 与 CHANGELOG 0.3.1 条目脱节** ｜ `moon.mod:6` `version = "0.3.0"` vs `CHANGELOG.md:5` `## [0.3.1] - 2026-07-04` ｜ CHANGELOG 已记录 0.3.1 的实质性变更（Barrett reduction、canonical JSON 签名、低阶点拒绝、E3002 实现、cli-test.sh 对等），但 moon.mod 版本号未 bump。按 SemVer，含密码学性能与安全加固的变更至少是 patch bump。Mooncakes 发布与版本引用会取 moon.mod 的 0.3.0，导致"发布的包"与"变更记录"不一致 ｜ ① moon.mod 版本 bump 至 0.3.1；② 确认 0.3.1 的 git tag 是否存在（CHANGELOG 链接指向 `releases/tag/v0.3.1`，但仓库可能未打 tag）；③ CI 加"moon.mod version == CHANGELOG 最新版本 == 最新 git tag"一致性检查 ｜ `moon.mod:6` vs `CHANGELOG.md:5` ｜ 影响工程质量与生态贡献（发布合规）

**【P1-4】STRUCTURE_TREE 漏 3 个 tools 文件且用例数错误** ｜ `docs/STRUCTURE_TREE.md:170` `cli-test.ps1 # 22 用例` + 漏 `cli-test.sh`/`cross-verify.mjs`/`mutation-check.mjs`/`check-fixtures.mjs` ｜ 第 1 轮阶段 1.4 标记 STRUCTURE_TREE 重生成 `[x]` 并称"CI 有 drift 检查"，但实际：① 用例数仍写 22（实际 41）；② 漏 3 个 round-2 新增 tools 文件；③ 所谓 drift 检查在 CI 中不存在。任务勾选与实际完成脱节 ｜ ① 重新生成 STRUCTURE_TREE 到当前实际状态（含 10 个 tools 文件、41 用例）；② CI 加 STRUCTURE_TREE drift 检查（或用脚本生成而非手写）；③ 复核第 1 轮所有标记 `[x]` 的任务是否真正完成 ｜ `STRUCTURE_TREE.md:170` vs `ls tools/` 10 文件 ｜ 影响工程质量与导航可信度

**【P1-5】ACCEPTANCE_CHECKLIST 停在第 1 轮冻结前的旧值** ｜ `docs/records/ACCEPTANCE_CHECKLIST.md:7-8,13` ｜ 该清单是赛方验收自查的权威文档，仍写"12 个包，实现 3590 行 + 测试 3301 行，合计 6891 行""76 个提交"——这是第 1 轮**治理之前**的值。第 1 轮阶段 1.2 声称"全文档同步数字"但漏了此文件。若评委照此清单核对，数字与实际差 1477 行 / 3 提交，可信度受损 ｜ 立即同步到 79/8368/240/12；纳入 P1-1 的自动门禁覆盖范围 ｜ 行号直接对照 ｜ 影响展示与验收可信度

### P2 中（影响竞争力与可维护性）

**【P2-1】Stage 5 竞争力项零进展** ｜ `docs/ROADMAP.md:55,85`（演示视频 `[ ]` 重复两处）/ 第 1 轮计划阶段 5 全部 `[ ]` ｜ 演示视频、GitHub Pages demo、API 文档（moon doc 工具链就绪后）、重复 setup 抽取、CLI_VERSION CI 校验全部未做。项目"全绿可演示"但无视频、无在线 demo、无 API 文档站点，展示维度扣分 ｜ 按性价比推进：① 演示视频（5 分钟，按 DEMO_SCRIPT 录制）——展示分最高 ROI；② GitHub Pages 部署 demo/web（首次推送后）；③ CLI_VERSION CI 校验（轻量）；④ 重复 setup 抽取到 test_helpers（轻量）；⑤ API 文档待 moon doc 工具链 ｜ ROADMAP + 第 1 轮阶段 5 表 ｜ 影响展示与专项奖

**【P2-2】ROADMAP 未来方向与已完成项混排** ｜ `docs/ROADMAP.md:80-87` ｜ "未来方向"段列出"多链适配器/in-toto/SLSA/版本 DAG/演示视频/moondoc 完整性"，其中演示视频与 moondoc 完整性在第二阶段已部分触及，且演示视频重复出现在第 55 行。已完成项与待办边界模糊 ｜ 重写"未来方向"段：明确区分"真正未开始"（多链/in-toto/SLSA/版本 DAG）与"已部分完成待收尾"（演示视频/moondoc）；删除重复 ｜ 行号直接对照 ｜ 影响工程质量（导航清晰度）

**【P2-3】bench 声明计数口径误导** ｜ `docs/records/RESULTS_LOG.md:582` "测试声明 238（234 测试 + 4 基准）" ｜ 实测 `grep '^test '` = 240，`grep '^bench '` = 0。4 个基准是 `b.bench(...)` 调用包在 `test` 块内，不是独立 `bench` 声明。"238（234+4）"口径把 bench 调用当声明计，误导后续引用 ｜ 统一口径：测试声明 = `grep '^test '` = 240；基准调用 = 4（在 test 块内）；RESULTS_LOG 与 README 据此修正 ｜ 命令行实测 ｜ 影响工程质量（数据准确）

**【P2-4】根目录散落开发者本地 PowerShell 脚本** ｜ `_capwin.ps1` / `_mev_cap.ps1` / `_mev_run.ps1` / `_termsetup.ps1` ｜ 4 个下划线前缀的 .ps1 是开发者本地录屏/终端设置脚本，与项目交付无关，混在仓库根目录污染结构 ｜ 移入 `tools/local/` 或加入 `.gitignore`（若不需版本化）｜ `ls` 根目录 ｜ 影响工程质量（结构整洁）

### P3 低（锦上添花）

**【P3-1】PROJECT_INDEX Next Actions 部分项已过期** ｜ `docs/PROJECT_INDEX.md:57-61` ｜ "Next Actions"列"流式哈希接入适配层"等项，需复核是否仍在待办 ｜ 复核并刷新为真实当前待办 ｜ 行号对照 ｜ 可维护性
**【P3-2】第 1 轮计划文档自身含旧基线数字** ｜ `docs/plans/2026-07-04-health-check-and-improvement-plan.md:8` "提交 76…6891 行…219 测试" ｜ 历史诊断文档保留旧值合理（是当时的实测），但应在文档头注明"本基线为体检时实测，非当前值"避免误引 ｜ 加一行注解 ｜ 行号对照 ｜ 可维护性
**【P3-3】git tag 0.3.1 可能未打** ｜ CHANGELOG 链接 `releases/tag/v0.3.1` ｜ 需确认仓库是否有该 tag；若无，CHANGELOG 链接是死链 ｜ 推送后打 tag 或修正链接 ｜ `git tag -l` ｜ 工程质量

---

## 四、根因与治理策略

| 根因 | 症状群 | 治理策略 |
| --- | --- | --- |
| A'. 单一事实源是程序性非自动化 | 量化漂移复发（79/8368/240 未同步）、ACCEPTANCE_CHECKLIST 停旧值、STRUCTURE_TREE 漏文件 | 建立 CI 自动门禁：脚本取实测数字 + 正则扫描文档断言 + 不一致红 CI；RESULTS_LOG 由脚本自动刷新 |
| B'. 增量路径与主路径契约未对齐 | incremental.mbt 跳过 E2004 | 补 E2004 断言 + 等价性测试 + ARCHITECTURE 契约说明 |
| C'. 版本与任务完成治理缺位 | moon.mod 0.3.0 vs CHANGELOG 0.3.1；STRUCTURE_TREE 重生成标记 [x] 但未执行 | CI 加"moon.mod version == CHANGELOG 最新 == 最新 tag"检查；任务勾选必须有客观验收命令 |
| D'. Stage 5 零进展 | 演示视频/Pages/API 文档未做 | 按性价比推进，演示视频优先 |

---

## 五、改进计划（分阶段）

> 阶段顺序按"根因 → 竞争力"排列。每阶段独立可交付，任意截断点上项目都处于"全绿可演示"状态。**本轮计划仅规划，不在此阶段改代码。**

### 阶段 0：自动防漂移门禁（治根因 A'，预计 2-3 个提交）

**目标：** 让"文档数字 == 实测数字"由 CI 强制，而非靠人记得。

| 任务 | 对应问题 | 验收 |
| --- | --- | --- |
| 0.1 编写 `tools/check-metrics.mjs`：跑 git/wc/grep 取实测（提交/实现行/测试行/测试声明/包数/wenlittle 残留/moon.mod 版本），正则扫描 README/README.zh/开发报告/ACCEPTANCE_CHECKLIST/CHANGELOG/STRUCTURE_TREE 中的数字断言，不一致 exit 1 | P1-1, P1-4, P1-5 | 脚本本地跑红（暴露全部漂移）；CI 集成后 push 触发 |
| 0.2 全文档同步到 79/8368/240/12（README/README.zh/开发报告/ACCEPTANCE_CHECKLIST/CHANGELOG/RESULTS_LOG/STRUCTURE_TREE） | P1-1, P1-5 | `check-metrics.mjs` 本地 exit 0 |
| 0.3 STRUCTURE_TREE 重新生成到当前实际（10 tools 文件、41 用例、12 包） | P1-4 | 树与 `ls`/`find` 一致 |
| 0.4 CI workflow 加 `node tools/check-metrics.mjs` 步骤 | P1-1 | CI 有该步骤；故意改错一个数字能红 CI |

预计提交：3~4 个。

### 阶段 1：增量验证契约对齐（治根因 B'，预计 1-2 个提交）

**目标：** 让 `verify_manifest_incremental` 与 `verify_manifest` 在相同输入下产出相同 `ok`。

| 任务 | 对应问题 | 验收 |
| --- | --- | --- |
| 1.1 incremental.mbt 补 E2004 断言：用已计算的 canonical_json 比对 expected_manifest_digest（与 verify.mbt:64-78 同逻辑）；移除 `ignore` | P1-2 | 增量路径在 manifest 摘要不匹配时返回 E2004 |
| 1.2 补测试：构造 manifest 摘要不匹配用例，断言增量路径返回 E2004；补"增量 vs 全量等价性"property 测试 | P1-2 | 测试覆盖 E2004 增量路径；等价性测试绿 |
| 1.3 ARCHITECTURE.md 补"增量路径验证步骤与主路径等价"契约说明；DECISION_LOG 记录 | P1-2 | 契约文档化 |

预计提交：2~3 个。

### 阶段 2：版本与结构治理（治根因 C'，预计 1-2 个提交）

**目标：** moon.mod 版本、CHANGELOG、git tag 三者一致；任务勾选有客观验收。

| 任务 | 对应问题 | 验收 |
| --- | --- | --- |
| 2.1 moon.mod 版本 bump 至 0.3.1（与 CHANGELOG 最新一致） | P1-3 | moon.mod == CHANGELOG 最新 |
| 2.2 确认/补打 git tag v0.3.1；CHANGELOG 链接可达 | P1-3, P3-3 | `git tag -l v0.3.1` 命中；链接可达 |
| 2.3 CI 加"moon.mod version == CHANGELOG 最新版本 == 最新 git tag"一致性检查 | P1-3 | 故意改版本能红 CI |
| 2.4 复核第 1 轮所有 `[x]` 任务：STRUCTURE_TREE 重生成、PROJECT_INDEX 刷新等是否真正完成 | P1-4, P3-1 | 复核记录入 RESULTS_LOG |
| 2.5 ROADMAP 重写"未来方向"段，区分真正未开始与已部分完成；删除重复 | P2-2 | ROADMAP 无重复项 |
| 2.6 根目录本地脚本移入 `tools/local/` 或 .gitignore | P2-4 | 根目录无下划线前缀 .ps1 |

预计提交：2~3 个。

### 阶段 3：竞争力推进（治根因 D'，预计 3-5 个提交）

**目标：** 补齐展示材料，冲击专项奖。

| 任务 | 对应问题 | 验收 |
| --- | --- | --- |
| 3.1 录制 5 分钟演示视频（按 DEMO_SCRIPT），README 嵌链接 | P2-1 | 视频可播放；README 有链接 |
| 3.2 首次推送后部署 demo/web 到 GitHub Pages | P2-1 | demo 在线可访问 |
| 3.3 CLI_VERSION CI 校验（与 moon.mod 一致） | P2-1 | 改版本不更新 CLI_VERSION 红 CI |
| 3.4 重复 setup 抽取到 test_helpers（splitmix64/RFC8032 sk/golden_manifest） | P2-1 | 无跨文件复制 |
| 3.5 API 文档（moon doc 工具链就绪后补全；当前 100% pub 注释已达标） | P2-1 | moon doc 生成无缺 |
| 3.6 bench 声明计数口径修正（RESULTS_LOG/README） | P2-3 | 口径统一为 240 测试 + 4 bench 调用 |

预计提交：3~5 个。

---

## 六、风险与对策

| 风险 | 概率 | 对策 |
| --- | --- | --- |
| 自动门禁脚本正则误报（文档中合理出现的数字被当断言） | 中 | 脚本只匹配明确断言句式（如"N 单位测试""N 行"），白名单历史日志段 |
| 增量路径补 E2004 后性能优势被削弱 | 低 | E2004 只是一次摘要比对，成本远低于文件哈希；bench 对比验证 |
| 演示视频录制耗时 | 中 | 按 DEMO_SCRIPT 实测命令部分仅 5.7s，录制主要耗时在 narration |
| GitHub Pages 首次部署需仓库远程 | 中 | 阶段 3.2 依赖首次推送，与所有者确认时间线 |
| 复核第 1 轮 [x] 任务发现更多未真正完成项 | 中 | 阶段 2.4 预留时间；发现问题补入计划 |

---

## 七、交付物与验收

### 阶段性交付物

- 阶段 0：CI 自动防漂移门禁上线，文档与实测零漂移，STRUCTURE_TREE 反映当前状态
- 阶段 1：增量验证与全量验证功能等价，E2004 在两路径都触发，契约文档化
- 阶段 2：moon.mod/CHANGELOG/tag 三者一致，第 1 轮任务勾选复核完毕，ROADMAP 清晰
- 阶段 3：演示视频 + Pages demo + CLI_VERSION 校验，展示材料齐备

### 最终验收命令（阶段 3 后）

```powershell
moon check
moon test --target wasm-gc,js
moon fmt --check
node tools/check-metrics.mjs          # 新增：文档数字 == 实测
node tools/cross-verify.mjs
powershell -ExecutionPolicy Bypass -File tools/cli-test.ps1 -Target js
bash tools/cli-test.sh                 # 跨平台黑盒
git tag -l v0.3.1                      # 版本一致
```

全绿 + 文档零漂移（CI 强制）+ 增量路径 E2004 覆盖 + 版本三者一致 + 演示视频在线 = 健康度从 7.2 提升至 9.5。

### 记录规则

每个阶段完成后：
1. 更新 `docs/records/RESULTS_LOG.md`（命令、结果、commit hash）——**由 check-metrics.mjs 辅助确保数字准确**
2. 关键决策更新 `docs/records/DECISION_LOG.md`
3. 本计划对应阶段标记 `[x]` 并 commit——**标记前必须跑客观验收命令**

---

## 八、第 2 轮与第 1 轮的对照

| 维度 | 第 1 轮发现 | 第 1 轮处理 | 第 2 轮复核 |
| --- | --- | --- | --- |
| 仓库归属 wenlittle/starlittle | P0-1 | 统一 starlittle，比赛材料清零 | ✅ 治理生效，0 残留 |
| Ed25519 S<l malleability | P0-2 | 加 scalar_lt_l 检查 | ✅ 治理生效，代码在 |
| E3002 零覆盖 | P0-3 | 实现 prove/check-proof CLI | ✅ 治理生效 |
| incremental 错误码 E2001/E3002 | P1-1 | 统一为 E2003/E3003 | ✅ 治理生效 |
| 量化漂移 | P1-2 | RESULTS_LOG 冻结基线 + 全文档同步 | ❌ **复发**：79/8368/240 未同步，机制失效 |
| 冻结 API 脱节 | P1-3 | ARCHITECTURE v2 冻结 | ✅ 治理生效 |
| 两份开发报告互斥 | P1-4 | 合并为单一权威 | ✅ 治理生效 |
| Ed25519 pk 常量未断言 | P1-5 | RFC 8032 KAT 4 组 | ✅ 治理生效 |
| audit hex_to_bytes 静默损坏 | P1-6 | 统一到 digest 包 | ✅ 治理生效 |
| Ed25519 非常时间 | P2-1 | cmov + Fe::eq XOR | ✅ 治理生效 |
| Ed25519 reduce 慢 | P2-2 | Barrett reduction | ✅ 治理生效 |
| create 排序非 code-point | P2-4 | compare_code_units | ✅ 治理生效 |
| path null 字节 | P2-6 | 拒绝 | ✅ 治理生效 |
| CLI 黑盒漏错误码 | P2-7 | 19 夹具矩阵 | ✅ 治理生效 |
| 自验证无交叉 | P2-8 | cross-verify.mjs | ✅ 治理生效 |
| STRUCTURE_TREE 过期 | P2-9 | 标记重生成 [x] | ❌ **未真正执行**：仍 22 用例、漏 3 文件 |
| CI 缺 fmt/bench/release | P2-10 | 全补 | ✅ 治理生效 |
| 缺 LICENSE/CHANGELOG | P2-11 | 全补 | ✅ 治理生效 |
| **【新】增量路径跳过 E2004** | 未发现 | — | ❌ 第 2 轮新发现，P1-2 |
| **【新】moon.mod vs CHANGELOG 版本脱节** | 未发现 | — | ❌ 第 2 轮新发现，P1-3 |
| **【新】自动防漂移门禁缺失** | 未发现 | — | ❌ 第 2 轮新发现，P1-1 根因 |
| Stage 5 竞争力 | P3-12 | 标记 [ ] 未做 | ⏳ 仍未做，P2-1 |

**结论：** 第 1 轮修复的 18 项中 16 项治理生效、2 项复发或未真正执行；第 2 轮新发现 3 项（含 1 项功能性契约缺口）。项目工程质量持续向好，但"自动防漂移"与"增量契约完整"是冲击一等奖的最后两块结构性短板。
