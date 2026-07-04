# MoonEvidence 健康体检与改进计划（第 3 轮，5 轮迭代）

> **面向 AI 代理的工作者：** 本计划是对项目做第三轮"如何把它做好"的全面健康体检后的改进路线，不是最小可改补丁清单。执行时使用 executing-plans 逐步骤实现；每个阶段完成后必须更新 `docs/records/RESULTS_LOG.md` 并单独 commit。**本轮只产出计划，不改任何代码。**

**体检日期：** 2026-07-05 Asia/Shanghai
**体检方法：** 5 轮迭代式勘察——基线测量 + 三路并行广度扫描 → 定向核验（直接读文件 + 命令行实测）→ 根因聚类 → 优先级校准 → 整合定稿。三维度（源码 / 测试与 CI / 文档材料与竞争力）并行深审，每条 P0 均经直接读源码核验。
**体检范围：** `src/` 全部 12 包、`tests/` 全部夹具、`tools/` 全部 11 个脚本、`docs/` 全部文档（含三份申报书）、CI 与构建配置、`demo/web/`、`moon.mod`/`moon.pkg`、根目录治理文件。
**与第 1、2 轮的关系：** 第 1 轮（6.2/10）修了 Ed25519/incremental/文档对齐；第 2 轮（7.2/10）发现量化漂移复发 + 增量 E2004 缺口，执行 round 3 落地 Trust Workbench + check-metrics.mjs + E2004 修复，自评 9.0。本轮在第 2 轮基础上复核，发现**前两轮自评偏高**：SHA-512 多算法支持在 verify/merkle 两处断裂、JS API 审计层是空壳、api.mbt 80% pub 函数零测试、声称的 CI 防漂移门禁未实际接入 CI、申报书漏 4/6 创新点。项目工程内核仍强，但存在"系统性半成品 + 材料严重错配 + 治理机制形似而神不至"三类新问题。

**权威基线（本机实测，第 3 轮）：** 提交 **88**（docs 中 DEVELOPMENT_REPORT/ACCEPTANCE_CHECKLIST 仍写 86，漂移 2）；实现 **4719** 行 + 测试 **4832** 行 = **9551** 行；moon test --target js **254/254 passed**（grep '^test ' 计 258，含 4 个 bench 包）；包 **12** 个；`moon.mod` 版本 **0.4.0** == CHANGELOG 0.4.0 == tag v0.4.0；`wenlittle` 仅残留在历史日志与诊断文档（合理）；`moon check` 0 警告。

---

## 一、健康体检总览

### 四维度评分（第 3 轮）

| 维度 | 第 1 轮 | 第 2 轮 | 第 3 轮 | 一句话诊断 |
| --- | --- | --- | --- | --- |
| 源码架构与质量 | 7.5 | 8.0 | **7.0** | 分层与核心管线仍扎实，但 SHA-512 多算法在 verify/merkle 两处断裂、JS API 审计层是空壳、create/verify 布局不对称，"全功能"声称难支撑 |
| 测试与验证 | 6.5 | 7.5 | **6.5** | 库内核（merkle/ed25519/audit/verify）测试扎实，但 api.mbt 10 个 pub 函数 8 个零测试、最强验证工具（cross-verify/mutation-check/check-metrics）未入 CI、fuzz 仅防 panic |
| 文档与工程治理 | 4.5 | 6.0 | **6.0** | check-metrics 工具存在但未接入 CI（声称的"自动门禁"是空话）、申报书三格式漏 4/6 创新点且数字漂移、SECURITY.md 安全声称超前于代码 |
| 竞争力与展示 | — | — | **5.5** | Trust Workbench 6 视图已建却未进任何材料、Mooncakes 未发布、碰撞检查过期、申报书呈现 MVP 而非 0.4.0 平台 |
| **综合** | 6.2 | 7.2 | **6.3** | 工程内核优秀，但"系统性半成品 + 材料错配 + 治理形似神不至"叠加，前两轮自评 9.0 偏高 |

> **评分说明：** 第 3 轮评分低于第 2 轮自评的 7.2，并非项目退步，而是本轮发现了前两轮未捕获的实质性缺陷（SHA-512 断裂、audit 空壳、API 无测试、CI 门禁未接入、材料错配）。这些缺陷一直存在，只是前两轮的"全绿可演示"基线掩盖了它们。综合 6.3 反映的是经核验的真实健康度。

### 核心问题一句话诊断

第 2 轮自评 9.0 是建立在"254 测试全绿 + 0 警告 + check-metrics 工具已建"之上的，但本轮核验发现：**全绿是因为测试盲区**（无 SHA-512 端到端用例、api.mbt 80% pub 无测试），**check-metrics 工具已建但未接入 CI**（ci.yml 全文无引用，DEVELOPMENT_REPORT/ACCEPTANCE_CHECKLIST 漂移到 86 未被发现即为明证），**申报书停在 0.2/0.3 期**（漏 Ed25519/store/audit/可视化/Trust Workbench 五项，数字写 219/22/76/6891）。项目实际处于"工程内核强、API 层半成品、治理机制形似神不至、材料严重低估竞争力"的状态。

---

## 二、五轮勘察记录

### 第 1 轮：基线测量 + 三路并行广度扫描

**目标：** 建立第 3 轮三维度基线，不预设结论。
**方法：** 命令行实测提交/行/测试/包/版本/tag/wenlittle 残留；三路并行 Explore 代理深审（源码架构与创新点 / 测试与 CI / 文档材料与竞争力）。
**新发现（要点）：**
- **源码：** verify.mbt:100 硬编码 `sha256_hex` 无视 `manifest.algorithm`；merkle.mbt:17 硬编码 `Sha256Ctx`；create.mbt:72 把 SHA-256 根贴 `algorithm.label()` 标签（标签造假）；api.mbt audit_append/audit_verify 丢弃输入日志建空 AuditLog；point_decode 缺 y>=p 检查与完整低阶点拒绝；CLI_VERSION=0.3.0 vs moon.mod 0.4.0；CLI create 不递归子目录与 verify 布局不一致；ed25519_keypair 无 seed 返回硬编码密钥。
- **测试：** api.mbt 10 个 pub 函数仅 verify_evidence/compute_merkle_tree 有测试（8 个零覆盖）；smoke-api.mjs 仅测 verify_evidence；cross-verify.mjs/mutation-check.mjs/check-metrics.mjs 未入 CI；bench job continue-on-error:true；manifest fuzz 400 轮仅断言"不 panic"；E3002 是死错误码；CLI create 子命令零黑盒覆盖。
- **文档材料：** 申报书.md/tex/html 核心数字 219/22/76/6891 vs 实测 254/258+41/88/9551；申报书核心功能只列 MVP 6 项，漏 Ed25519/store/audit/可视化/Trust Workbench；Trust Workbench 6 视图已建但零材料提及；申报书明文手机号；SECURITY.md:38 指向申报书联系方式；CHANGELOG 0.4.0 内部 254 vs 258 矛盾；DEMO_SCRIPT/ROADMAP/PROJECT_INDEX 数字过时；Mooncakes 碰撞检查过期 25 天。
**对计划的更新：** 确立五个新 P0 候选（SHA-512 断裂、audit 空壳、API 无测试、申报书漏功能、Trust Workbench 缺失），需第 2 轮直接读文件核验。

### 第 2 轮：定向核验（关键断言直接读源码）

**目标：** 验证第 1 轮高严重度断言，确保每条 P0 有 file:line 证据。
**方法：** 直接读 verify.mbt/merkle.mbt/api.mbt/audit_log.mbt/ed25519.mbt/create.mbt/SECURITY.md/申报书.md/ci.yml/demo/web/index.html；grep api.mbt pub 函数与 wbtest 覆盖；grep workflows 确认 check-metrics 是否入 CI。
**核验结论（全部属实）：**
- `verify.mbt:100` `let actual = @digest.sha256_hex(content)`——硬编码 SHA-256，无视 `manifest.algorithm`。对比 `incremental.mbt:122` 用 `Digest::of_bytes(manifest.algorithm, content)`，主路径与增量路径行为不一致。**SHA-512 包必然报 E2003 失败**。
- `merkle.mbt:17` `let ctx = @digest.Sha256Ctx::new()`——Merkle 树恒 SHA-256。`create.mbt:72` `"\{options.algorithm.label()}:\{hex}"`——把 SHA-256 根贴 "sha512:" 标签。
- `api.mbt:500-503` `Some(String(_log_json)) => @audit.AuditLog::new()`——丢弃输入；`:559-563` 同样。audit_verify 恒返回 `chain_valid:true, length:0`。根因：`audit_log.mbt` 无 `from_json`（grep 确认只有 `AuditAction::parse` 与 to_json 方向的 `@json.parse`）。
- `api.mbt` 10 个 pub 函数（verify_evidence/compute_merkle_tree/create_evidence_pack/generate_proof/verify_proof/audit_append/audit_verify/ed25519_keypair/ed25519_sign/ed25519_verify），wbtest 仅覆盖前 2 个——**8 个零测试**。
- `.github/workflows` grep `check-metrics|cross-verify|mutation-check|check-fixtures` **零命中**——声称的 CI 防漂移门禁**未接入 CI**。DECISION_LOG "CI auto anti-drift gate via check-metrics.mjs" 与 ci.yml 不符。
- `申报书.md:24-31` 核心功能确只列 MVP 6 项；`:36` "219 单元 + 22 黑盒"；`:39` "6891 行 / 76 commit"；`:9` 明文手机号 18718241181。
- `SECURITY.md:18` 声称"point_decode 拒绝低阶点与非规范编码"，但 `ed25519.mbt:321` 无 y>=p 检查、`:344` 仅查 `x=0&&sign==1`——**安全声称超前于代码**。
- `demo/web/index.html:6` "MoonEvidence · Trust Workbench"——6 视图工作台存在但零材料提及。
- moon test --target js 254/254 passed（无 SHA-512 端到端用例，bug 被盲区掩盖）。
**对计划的更新：** 五个 P0 全部确认，新增"声称的 CI 门禁未接入"为元问题级 P1，"SECURITY.md 安全声称超前"为 P1。

### 第 3 轮：根因分析（跨维度交叉）

**目标：** 找出第 3 轮问题之间的因果链，区分"症状"与"病因"。
**根因结论：**
1. **根因 α：多算法支持是"纸面功能"——接口层做了、实现层没做。** `HashAlgorithm::Sha512` 是一等枚举，digest/normalize/manifest/create/api 各层都接受解析，但 verify.mbt:100 与 merkle.mbt:17 两处实现硬编码 SHA-256，create.mbt:72 贴假标签。测试全用 SHA-256 故 254 全绿掩盖了断裂。这是"声明支持但管线未贯通"的典型分裂。
2. **根因 β：JS API 层是"先搭壳后填肉"的半成品。** api.mbt 一次性暴露 10 个 pub 函数，但只对前 2 个做了 wbtest + smoke。后 8 个是 c171f7f "API expansion" 提交批量加的，未走"先测后发"门禁。audit 因 audit_log 无 from_json 而成空壳。这是第 1 轮根因 B（后加功能绕过核心包门禁）在 API 层的重现。
3. **根因 γ：治理机制"形似而神不至"——工具建了但门禁未接入。** check-metrics.mjs 建了但 ci.yml 没接；bench 标 continue-on-error:true；fuzz 无断言仅防 panic。DECISION_LOG 写"CI gate"但 CI 没有。第 2 轮根因 A'（机制程序性非自动化）升级为"声明性"——文档说有但 CI 没有，比程序性更糟。
4. **根因 δ：申报材料停在 0.2/0.3 期，与 0.4.0 实际严重错配。** 申报书.md/tex/html 在 2026-06-10 申报期写定后未随 0.3/0.4 迭代；DEMO_SCRIPT/ROADMAP 同步停摆；check-metrics 盲区不覆盖申报材料。这是第 1 轮根因 C（材料分轨）的延续：0.4.0 后材料与代码未合轨。
5. **根因 ε：安全声称超前于代码实现。** SECURITY.md 在 round 1/2 加固后写"已具备低阶点/非规范拒绝防护"，但 point_decode 只做了一半；SHA-512 标签同理；audit 无签名静默放行。文档跟着计划写、代码没跟着做完。
**对计划的更新：** 改进计划按根因治理组织——阶段 0 治根因 α+δ（多算法贯通 + 材料合轨），阶段 1 治根因 β（API 层填肉），阶段 2 治根因 γ（门禁真接入），阶段 3 治根因 ε（安全声称对齐），阶段 4 推竞争力。

### 第 4 轮：完整性与优先级校准

**目标：** 确认无遗漏，按赛方四维度（完成度/生态贡献/工程质量/展示 + 专项奖）映射评分影响，估 ROI。
**校准结果：**
- **完成度：** P0-4/P0-5（申报书漏功能 + Trust Workbench 缺失）直接影响——评委看材料以为半成品，实际已是平台。
- **生态贡献：** P1-9（Mooncakes 未发布 + 碰撞检查过期 25 天，生态已从 1315 涨到约 1687 包）。
- **工程质量：** P0-1（SHA-512 断裂）、P0-2（audit 空壳）、P0-3（API 无测试）、P1-1（门禁未接入）、P1-2（安全声称不实）。
- **展示：** P0-5（Trust Workbench 未进材料）、P0-6（手机号）、DEMO_SCRIPT 过时。
- **ROI 排序（高→低）：** ① 申报材料刷新 + Trust Workbench 进材料（工作量中，完成度+展示双升）；② SHA-512 断裂修复（工作量中，消除评委翻车风险）；③ CI 门禁真接入（工作量小，治根因 γ）；④ API 层填肉 + 测试（工作量中，治根因 β）；⑤ audit from_json（工作量中，让审计创新点可演示）；⑥ 安全声称对齐（工作量小-中，诚信）。
**对计划的更新：** 形成最终 5 阶段计划（见第五节）。

### 第 5 轮：整合定稿

**目标：** 把四轮发现收敛为可执行计划，确保每条有"位置/问题/建议/验收/工作量"。
**方法：** 按 P0~P3 严重度归并去重，编写分阶段任务表，标注依赖与验收。
**产出：** 本文档第三~七节。

---

## 三、问题清单（按严重度分级）

> 每条格式：**【ID】标题** ｜ 位置 ｜ 问题 ｜ 建议 ｜ 证据 ｜ 评分影响

### P0 阻断级（功能断裂/材料错配/合规，必须先修）

**【P0-1】SHA-512 多算法支持在 verify + merkle 两处断裂** ｜ `src/verify/verify.mbt:100`、`src/merkle/merkle.mbt:17`、`src/create/create.mbt:72` ｜ `verify.mbt:100` 硬编码 `@digest.sha256_hex(content)` 无视 `manifest.algorithm`；`merkle.mbt:17` 硬编码 `Sha256Ctx`；`create.mbt:72` 把 SHA-256 算出的根贴 `algorithm.label()` 标签。SHA-512 包必然报 E2003 失败，Merkle 根标签造假破坏跨工具互操作。所有测试用 SHA-256，254 全绿掩盖了断裂。 ｜ verify.mbt:100 改为 `Digest::of_bytes(manifest.algorithm, content)`（与 incremental.mbt:122 对齐）；merkle leaf_hash/node_hash/compute_root 接受 `HashAlgorithm` 参数；create/verify 统一传递 `manifest.algorithm`；补 SHA-512 端到端 create→verify round-trip 测试 ｜ `verify.mbt:100` vs `incremental.mbt:122`；`merkle.mbt:17`；`create.mbt:72`；全仓 src/verify 无 Sha512 引用 ｜ 影响工程质量（声称功能断裂）+ 互操作

**【P0-2】JS API audit_append/audit_verify 是空壳，恒返回有效** ｜ `src/api/api.mbt:500-503`、`:559-563`；`src/audit/audit_log.mbt`（无 from_json） ｜ audit_append 收到 log 字段后 `@audit.AuditLog::new()` 建空日志，完全丢弃已有条目；audit_verify 同样，对任意输入恒返回 `chain_valid:true, length:0`。代码注释承认"AuditLog has no from_json"。审计日志完整性是可信证据包核心安全属性，当前 API 层形同虚设且测试全盲。 ｜ 为 AuditLog 实现 `from_json`（audit_log.mbt 已有 to_json，对称缺失）；api 层用 from_json 重建后再 append/verify；补 api_wbtest：传入多 entry 日志验证 length>0、传入篡改日志验证 chain_valid:false ｜ `api.mbt:500-503`/`:559-563`；grep 确认 audit_log.mbt 无 from_json ｜ 影响工程质量 + 创新点"审计日志"支撑力

**【P0-3】api.mbt 10 个 pub 函数中 8 个零测试覆盖** ｜ `src/api/api_wbtest.mbt`、`tools/smoke-api.mjs:8` ｜ api.mbt 导出 10 个 pub 函数，wbtest 仅测 verify_evidence + compute_merkle_tree；smoke-api.mjs 仅 import verify_evidence。create_evidence_pack/generate_proof/verify_proof/audit_append/audit_verify/ed25519_keypair/ed25519_sign/ed25519_verify 全裸奔。库层测试再强，对外 API 层 80% 未验证。 ｜ 为每个 pub 函数补至少 1 正路径 + 1 envelope 错误 + 1 业务错误；重点闭环：create→verify、generate_proof→verify_proof、ed25519_keypair→sign→verify；扩展 smoke-api.mjs 覆盖这些闭环 ｜ `api_wbtest.mbt` 仅 2 函数调用；`smoke-api.mjs:8` 仅 verify_evidence ｜ 影响工程质量（API 契约未验证）

**【P0-4】申报书三格式核心数字漂移 + 漏 0.3+/0.4.0 全部功能** ｜ `docs/申报书.md:24-31,36,39`、`docs/申报书.tex:49-63`、`docs/申报书.html:98-108,114,119` ｜ 三份申报书核心功能只列 MVP 6 项（Canonical JSON/SHA-256/Merkle/manifest/版本链/CLI/浏览器），完全无 Ed25519/store/audit/可视化/Trust Workbench；数字写 219 单元+22 黑盒/6891 行/76 commit，实测 254+41/9551/88。材料呈现 MVP 验证库，实际已是带密码学+审计+可视化的平台。 ｜ 三份申报书"核心功能"补 Ed25519/store/audit/可视化/Trust Workbench 五项；数字统一刷新到 88/9551/254/41；与 DEVELOPMENT_REPORT 第三节对齐 ｜ `申报书.md:24-31`（无 crypto/store/audit）；`DEVELOPMENT_REPORT.md:95-132`（实际有）；check-metrics 实测 ｜ 影响完成度 + 生态贡献（真实能力未申报）

**【P0-5】Trust Workbench（最新最大展示成果）在所有申报材料中缺失** ｜ `demo/web/index.html:6`（"Trust Workbench" 6 视图）；缺失于 `docs/申报书.{md,tex,html}`、`docs/report/DEVELOPMENT_REPORT.md`、`docs/DEMO_SCRIPT.md`、`README.md` ｜ 最新提交 c171f7f 把 demo 重写为 6 视图工作台（Verify/Create/Prove/Audit/Sign + Tamper Lab），但所有申报材料仍描述旧单页 demo。DEMO_SCRIPT.md:48-56 第 3 分钟仍演旧 demo。最强演示资产未进申报材料。 ｜ DEMO_SCRIPT 第 3 分钟改写为 Trust Workbench 6 视图演示；申报书 + 开发报告补"Trust Workbench 交互式工作台"作为展示亮点；README 补截图 ｜ `demo/web/index.html:6`；git log c171f7f；`DEMO_SCRIPT.md:48-56` ｜ 影响展示（最大短板）

**【P0-6】申报书明文手机号 + SECURITY.md 指向申报书** ｜ `docs/申报书.md:9`、`docs/申报书.tex:35`、`docs/申报书.html:82`、`SECURITY.md:38` ｜ 三份申报书明文写手机号 18718241181，SECURITY.md:38 引导漏洞报告者"通过仓库所有者联系方式（见 docs/申报书.md）私下联系"——公开仓库暴露个人手机号。 ｜ 申报书改用邮箱或脱敏；SECURITY.md 改为指向自带联系方式段落或邮箱 ｜ `申报书.md:9`；`SECURITY.md:38` ｜ 影响合规（隐私）

### P1 高（影响可信度/契约/竞争力）

**【P1-1】声称的 CI 防漂移门禁未实际接入 CI（元问题）** ｜ `.github/workflows/ci.yml`（全文无 check-metrics/cross-verify/mutation-check）；`docs/records/DECISION_LOG.md`（"CI auto anti-drift gate via check-metrics.mjs"） ｜ DECISION_LOG 声称 check-metrics.mjs 是 CI 门禁，但 ci.yml 只跑 gen-fixtures/moon check/moon fmt/moon test/moon build/cli-test.ps1/smoke-api.mjs。cross-verify.mjs/mutation-check.mjs/check-metrics.mjs 全是手动工具。直接证据：DEVELOPMENT_REPORT/ACCEPTANCE_CHECKLIST 漂移到 86 未被发现。第 2 轮 #1 根因修复"未真正落地"。 ｜ ci.yml 加 `node tools/check-metrics.mjs` + `node tools/cross-verify.mjs` + `node tools/mutation-check.mjs` 三步；故意改错一个数字能红 CI ｜ ci.yml 全文；grep workflows 零命中 ｜ 影响工程质量（治理机制形似神不至）

**【P1-2】SECURITY.md 声称"低阶点/非规范编码拒绝"与代码不符** ｜ `SECURITY.md:18`；`src/crypto/ed25519.mbt:321,344` ｜ SECURITY.md 声称 point_decode 拒绝低阶点 + 非规范编码，但 :321 `Fe::from_bytes` 后无 y>=p 检查（非规范 y 静默接受），:344 仅查 `x=0&&sign==1`（不覆盖所有低阶点），无 cofactor 乘法检查。libsodium/ref10 均拒绝这两类。 ｜ point_decode 加 y>=p 拒绝 + cofactor 乘法检查或显式低阶点拒绝；补负向攻击向量测试；SECURITY.md 残留限制段如实标注"低阶点拒绝仅 x=0&&sign=1" ｜ `ed25519.mbt:321,344`；`SECURITY.md:18` ｜ 影响工程质量（安全声称不实）

**【P1-3】CLI_VERSION = "0.3.0" vs moon.mod 0.4.0** ｜ `src/cmd/main/main.mbt:10` ｜ `--version` 输出 0.3.0，与 moon.mod 0.4.0 不符。 ｜ 同步为 0.4.0；CI 加 CLI_VERSION == moon.mod 版本校验 ｜ `main.mbt:10` ｜ 影响工程规范

**【P1-4】CLI create 不递归子目录，与 verify 布局不一致** ｜ `src/cmd/main/main.mbt:413-428` ｜ run_create 只读 pack_dir 顶层文件，verify 用 collect_pack_files 递归扫 files/。create 产出的包无法直接 verify。 ｜ create 递归扫描或统一放 files/ 下；补 create→verify 端到端黑盒测试 ｜ `main.mbt:413` vs `:203` ｜ 影响端到端可用性

**【P1-5】create_evidence_pack API 字段名 subject.kind vs manifest subject.type** ｜ `src/api/api.mbt:304`；`src/model/manifest.mbt:82` ｜ API 期望 subject.kind，manifest 用 subject.type。用户从 manifest 复制字段名到 API 请求会失败。 ｜ 统一为 type（与 manifest 一致） ｜ `api.mbt:304` vs `manifest.mbt:82` ｜ 影响 API 设计质量

**【P1-6】ed25519_keypair API 无 seed 时返回硬编码可预测密钥** ｜ `src/api/api.mbt:594-598` ｜ 无 seed 返回 [1,2,...,32]，pub 导出且无运行时警告。所有无 seed 调用方得到同一密钥对。 ｜ 无 seed 时返回错误或接入 CSPRNG（JS 用 crypto.getRandomValues） ｜ `api.mbt:594-598` ｜ 影响安全足迹

**【P1-7】文档数字漂移复发 + check-metrics 盲区** ｜ `docs/report/DEVELOPMENT_REPORT.md:4,224`、`docs/records/ACCEPTANCE_CHECKLIST.md:8,13`（86 vs 88）；`docs/DEMO_SCRIPT.md:62,63,85`（219/22）；`docs/ROADMAP.md:75,76`（219/6891）；`docs/PROJECT_INDEX.md:58`（0.3.0）；`CHANGELOG.md:25,30`（254 vs 258 内部矛盾）；`tools/check-metrics.mjs:124-198`（不覆盖申报书/DEMO_SCRIPT/ROADMAP） ｜ 多文档漂移；check-metrics 盲区致申报材料过时数字逃过门禁。 ｜ 全文档同步到 88/9551/254/12；check-metrics 断言扩展到申报书.md/DEMO_SCRIPT/ROADMAP ｜ check-metrics 3 FAIL；各文件行号 ｜ 影响工程质量 + 展示可信度

**【P1-8】E3002 是死错误码** ｜ `tools/cli-test.ps1:180-183`（注释承认）；`src/api/api.mbt:426-476`；`src/verify/verify.mbt` ｜ 规范保留 E3002 但实现无触发路径：CLI 无 proofs 消费者，verify_proof 对畸形 proof 返回 envelope error 而非 E3002 finding。规范-实现漂移。 ｜ verify_proof 将 proof 解析错误映射为 E3002 finding，或从规范移除并标注"reserved, untriggerable" ｜ grep E3002 在 src/ 仅注释/文档 ｜ 影响工程质量（错误码矩阵含死码）

**【P1-9】Mooncakes 碰撞检查过期 + Mooncakes 未发布** ｜ `docs/research/MOONCAKES_COLLISION_CHECK.md:40`（2026-06-10, 1315 包）；`docs/records/ACCEPTANCE_CHECKLIST.md:21`（moon publish 可选） ｜ 碰撞检查 25 天前，文档自声明"recheck before final submission"但未执行；生态已涨到约 1687 包，"RFC 8785 首实现"缺最新证据。Mooncakes 实际未发布，"生态贡献"只是声称。 ｜ 提交前重跑 Mooncakes API 碰撞检查并更新文档；完成 moon login + moon publish 0.4.0 ｜ `MOONCAKES_COLLISION_CHECK.md:40`；`ACCEPTANCE_CHECKLIST.md:21` ｜ 影响生态贡献 + 创新点时效性

**【P1-10】audit_verify_signatures 对无签名条目静默放行** ｜ `src/audit/audit_log.mbt:194-211` ｜ signature: None 直接跳过，攻击者剥离签名后链完整性 + 签名验证都通过。无法区分"本应有签名但被剥离"与"从未签名"。 ｜ 增加 verify_signatures_strict 模式要求所有条目必须有签名；或记录签名存在性状态 ｜ `audit_log.mbt:197-208` ｜ 影响审计安全语义

### P2 中（影响竞争力与可维护性）

**【P2-1】smoke-api.mjs 名不副实——仅覆盖 verify_evidence** ｜ `tools/smoke-api.mjs:8,36-37` ｜ CI 步骤名"Browser adapter smoke"暗示覆盖 JS 适配层，实际仅 verify_evidence。结合 P0-3，CI 对 api.mbt 80% 公共面零执行。 ｜ 扩展 smoke-api.mjs 跑 create→verify/proof/ed25519 闭环 ｜ `smoke-api.mjs:8` ｜ 影响工程质量

**【P2-2】bench job continue-on-error:true——门禁可被完全绕过** ｜ `.github/workflows/ci.yml:80` ｜ bench 失败不阻塞 CI，"bench guard"实为信息性，无法防回归。 ｜ 若要真门禁改阻塞 + 阈值断言；若保留信息性则在 README/RESULTS_LOG 明确标注"非阻塞" ｜ `ci.yml:80` ｜ 影响工程质量

**【P2-3】manifest fuzz 400 轮仅断言"不 panic"** ｜ `src/model/manifest_wbtest.mbt:431-460` ｜ 200 随机 + 200 变异 fuzz，末尾仅 `assert_true(true)`。崩溃安全网非正确性网，无法发现"错误接受非法输入"。 ｜ fuzz 循环对 Manifest::parse 结果做不变量断言：合法结构返回 Manifest，非法 raise ModelError ｜ `manifest_wbtest.mbt:439-446` ｜ 影响测试质量

**【P2-4】E2004 经 JS API 不可触发** ｜ `src/api/api.mbt:51` ｜ verify_evidence 调 verify_manifest 未传 expected_manifest_digest，E2004 在 JS 适配层永远不触发。 ｜ 文档标注"E2004 仅库层可达"或 verify_evidence 增加可选字段 ｜ `api.mbt:51` ｜ 影响错误码可达性一致性

**【P2-5】CLI create 子命令零黑盒覆盖** ｜ `tools/cli-test.ps1:76-89` ｜ Part1 cases 无 create 用例。run_create 的参数解析/E5001/E5002/输出逻辑均无黑盒测试。 ｜ 增加 create 黑盒用例：正常创建并验证、缺 --subject-id、非目录、-o 自定义输出 ｜ `cli-test.ps1:76-89` ｜ 影响工程质量

**【P2-6】generate_proof/verify_proof JS 适配层无端到端测试** ｜ `src/api/api.mbt:350-476` ｜ 库层 compute_proof/verify_inclusion 测试充分，JS 适配层 JSON 解析/index 越界/proof 结构校验无测试。 ｜ 增加 generate_proof→verify_proof 闭环测试 ｜ `api.mbt:350,426` ｜ 影响工程质量

**【P2-7】crypto Fe/Point 内部表示完全暴露** ｜ `src/crypto/pkg.generated.mbti:16-17,32-36` ｜ Fe.limbs 和 Point.{x,y,z,t} 均 public，外部可构造越界 Fe 或不在曲线上的 Point 绕过不变量。libsodium 完全封装。 ｜ 改 opaque 类型，仅暴露必要方法；from_bytes 加范围检查 ｜ `pkg.generated.mbti:16` ｜ 影响 crypto 生产级差距

**【P2-8】canonjson 跨后端数字格式化依赖 to_string 一致性** ｜ `src/canonjson/cononjson.mbt:247` ｜ RFC 8785 要求 ES Number::toString，js 后端调 Number.prototype.toString，native/wasm 用 Ryu 移植。Appendix B 覆盖已发布边界，未覆盖边界可能差异。 ｜ 补 subnormal/极大极小指数边界测试 ｜ `canonjson.mbt:218-222,247` ｜ 影响跨后端确定性声称

**【P2-9】错误码段四处不一致，三处漏 E5xxx** ｜ `README.md:156`、`docs/申报书.tex:57`、`docs/申报书.html:105`（且用 U+2011 非断字连字符） ｜ 完整范围是 E1xxx–E5xxx + W1xxx（spec:148），但 README 英文版/申报书.tex/申报书.html 漏 E5xxx。 ｜ 三处统一为 E1xxx–E5xxx、W1xxx；申报书.html 连字符改 ASCII ｜ `spec/EVIDENCE_PACK_SPEC.md:148` ｜ 影响公共契约一致性

**【P2-10】STRUCTURE_TREE 漏 tamper-lab.html/check-metrics.mjs/2 plans** ｜ `docs/STRUCTURE_TREE.md:34-36,48-49,169-179` ｜ demo/web/ 漏 tamper-lab.html；tools/ 漏 check-metrics.mjs；plans/ 漏 2 个 plan 文件。 ｜ 补全 4 个漏列项 ｜ 行号对照 ｜ 影响导航可信度

**【P2-11】OSC2026_APPLICATION.md 大量待填 + 版本错误 + 停早期** ｜ `docs/application/OSC2026_APPLICATION.md:8,9,11,29,38-40` ｜ 参赛者/联系方式/Gitlink 待填；第 29 行"Mooncakes 0.1.0"vs v0.4.0；第 38-40 行工程现状停在 2026-06-10（9/9 测试/10+ 提交）。两份申报材料并存差异巨大。 ｜ 删除早期版本（申报书.md 已是正式版）或补全刷新 ｜ `OSC2026_APPLICATION.md:8-11,29,38-40` ｜ 影响展示（评委可能误用早期版）

**【P2-12】申报书 Gitlink URL 状态与验收清单矛盾** ｜ `docs/申报书.md:14`（填 URL）vs `docs/records/ACCEPTANCE_CHECKLIST.md:8,17`（⏳ 推送后即满足） ｜ 申报书已填 Gitlink URL，但验收清单显示双推待办。申报书填的可能是预留 URL。 ｜ 确认 Gitlink 仓库实际状态；未推送则标注"推送后生效"或先完成推送 ｜ 行号对照 ｜ 影响完成度（双仓库公开是硬要求）

**【P2-13】DECISION_LOG 对 Trust Workbench 指向不准确** ｜ `docs/records/DECISION_LOG.md:224` ｜ 写"Trust Workbench UI (demo/web/tamper-lab.html)"，但 c171f7f 实际重写 index.html 为 Trust Workbench 6 视图，tamper-lab.html 是独立子页。 ｜ 修正指向 demo/web/index.html ｜ `DECISION_LOG.md:224`；`demo/web/index.html:6` ｜ 影响决策记录准确性

**【P2-14】CLI create 硬编码 SHA-256，无 --algorithm 参数** ｜ `src/cmd/main/main.mbt:431` ｜ CLI 只能创建 SHA-256 包（虽 P0-1 表明 SHA-512 路径本身断裂）。 ｜ 增加 --algorithm sha256|sha512 参数（依赖 P0-1 先修通） ｜ `main.mbt:431` ｜ 影响 CLI 功能完整度

**【P2-15】verify_manifest vs incremental 风格不一致** ｜ `src/verify/verify.mbt:180` vs `src/verify/incremental.mbt:186` ｜ 同一语义两套写法，增加维护成本。 ｜ 统一用 finding helper 和同一聚合表达式 ｜ 行号对照 ｜ 影响代码一致性

### P3 低（锦上添花）

**【P3-1】canonical_file_entry 逻辑三处重复** ｜ create.mbt:56-66 / verify.mbt:195-206 / api.mbt:240-249 ｜ 提取到 model 包作为 FileEntry::to_canonical_json() ｜ 三处重复 ｜ 可维护性
**【P3-2】audit_append 默认时间戳硬编码 2026-07-04** ｜ `src/api/api.mbt:522` ｜ JS 后端用 new Date().toISOString() ｜ 见代码 ｜ 审计实用性
**【P3-3】chain_wbtest broken parent 用 contains 非精确** ｜ `src/verify/chain_wbtest.mbt:46` ｜ 改 @debug.assert_eq 精确匹配 ｜ 见代码 ｜ 测试质量
**【P3-4】ed25519_verify 错误长度输入无负向测试** ｜ `src/crypto/ed25519.mbt:236` ｜ 补 sig 长度 63/65、pk 长度 31/33 断言 false ｜ 见代码 ｜ 测试质量
**【P3-5】CONTRIBUTING 示例用过时数字** ｜ `CONTRIBUTING.md:46` ｜ 改当前基线或泛化示例 ｜ 见代码 ｜ 可维护性
**【P3-6】README "12 example packs" 措辞歧义** ｜ `README.md:223`、`README.zh.md:191` ｜ 改"12 command-shape cases" ｜ examples/ 实际仅 2 包 ｜ 展示清晰度
**【P3-7】ACCEPTANCE_CHECKLIST 核对日期过时** ｜ `docs/records/ACCEPTANCE_CHECKLIST.md:3`（2026-06-11） ｜ 更新到最新冻结日 ｜ 见代码 ｜ 极小

---

## 四、根因与治理策略

| 根因 | 症状群 | 治理策略 |
| --- | --- | --- |
| α. 多算法是纸面功能（接口做了实现没做） | P0-1, P2-14 | verify/merkle/create 三处按 algorithm 分派；补 SHA-512 端到端测试钉住 |
| β. JS API 层先搭壳后填肉 | P0-2, P0-3, P1-5, P1-6, P2-1, P2-6 | API 层走"先测后发"：8 pub 函数补 round-trip 测试；audit 实现 from_json；字段名统一；硬编码密钥改 CSPRNG |
| γ. 治理机制形似神不至（工具建了门禁没接） | P1-1, P2-2, P2-3 | ci.yml 真接 check-metrics/cross-verify/mutation-check；bench 改阻塞或标注非阻塞；fuzz 加不变量断言 |
| δ. 申报材料停在 0.2/0.3 期 | P0-4, P0-5, P1-7, P1-9, P2-11, P2-12 | 申报书三格式 + DEMO_SCRIPT + ROADMAP 刷新到 0.4.0；check-metrics 覆盖申报材料；Mooncakes 碰撞重跑 |
| ε. 安全声称超前于代码 | P1-2, P0-1 标签, P1-10 | point_decode 补全或 SECURITY.md 如实标注；audit 无签名 strict 模式；CLI_VERSION 同步 |

---

## 五、改进计划（分阶段）

> 阶段顺序按"阻断 → 根因 → 竞争力"排列。每阶段独立可交付，任意截断点上项目都处于"全绿可演示"状态。**本轮计划仅规划，不在此阶段改代码。**

### 阶段 0：阻断项封堵（立即，预计 3-4 个提交）

**目标：** 消除功能断裂、材料错配、合规三处阻断。

| 任务 | 对应问题 | 验收 |
| --- | --- | --- |
| 0.1 SHA-512 多算法贯通：verify.mbt:100 改 Digest::of_bytes(manifest.algorithm,...)；merkle leaf_hash/node_hash/compute_root 接受 HashAlgorithm；create/verify 统一传 algorithm | P0-1 | SHA-512 端到端 create→verify round-trip 测试绿；merkle 根标签与实际算法一致 |
| 0.2 audit from_json：AuditLog 实现 from_json；api 层 audit_append/audit_verify 用 from_json 重建；补 wbtest（多 entry length>0、篡改 chain_valid:false） | P0-2 | audit API 不再恒返回有效；测试覆盖 |
| 0.3 申报书三格式刷新：核心功能补 Ed25519/store/audit/可视化/Trust Workbench 五项；数字统一 88/9551/254/41；Trust Workbench 进 DEMO_SCRIPT 第 3 分钟 | P0-4, P0-5 | 三份申报书与 DEVELOPMENT_REPORT 对齐；DEMO_SCRIPT 演 Trust Workbench |
| 0.4 申报书手机号脱敏；SECURITY.md 联系方式改邮箱 | P0-6 | 申报书无明文手机号 |

预计提交：4~5 个。

### 阶段 1：API 层填肉（治根因 β，预计 3-4 个提交）

**目标：** 让 api.mbt 10 个 pub 函数都有测试，对外契约可验证。

| 任务 | 对应问题 | 验收 |
| --- | --- | --- |
| 1.1 8 个无测试 pub 函数补 round-trip wbtest：create→verify、generate_proof→verify_proof、ed25519_keypair→sign→verify、audit_append→audit_verify | P0-3 | api_wbtest 覆盖全部 10 pub 函数 |
| 1.2 smoke-api.mjs 扩展覆盖 create/proof/ed25519/audit 闭环 | P2-1 | smoke 不再仅 verify_evidence |
| 1.3 create_evidence_pack 字段名 subject.kind→type（与 manifest 一致） | P1-5 | API 与 manifest 字段名一致 |
| 1.4 ed25519_keypair 无 seed 改 CSPRNG 或返回错误 | P1-6 | 无硬编码密钥 |

预计提交：4~5 个。

### 阶段 2：治理机制真接入 CI（治根因 γ，预计 1-2 个提交）

**目标：** 让"门禁"名副其实——CI 强制而非声明。

| 任务 | 对应问题 | 验收 |
| --- | --- | --- |
| 2.1 ci.yml 加 node tools/check-metrics.mjs + cross-verify.mjs + mutation-check.mjs 三步 | P1-1 | 故意改错数字能红 CI |
| 2.2 check-metrics 断言扩展到申报书.md/DEMO_SCRIPT/ROADMAP/PROJECT_INDEX | P1-7 | 申报材料过时数字逃不过门禁 |
| 2.3 全文档同步到 88/9551/254/12；补 RESULTS_LOG R4 基线 + CHANGELOG 0.4.1 | P1-7 | check-metrics 本地 exit 0 |
| 2.4 bench job：改阻塞 + 阈值断言，或 README 明确标注"非阻塞" | P2-2 | bench 门禁名实一致 |
| 2.5 manifest fuzz 加不变量断言（合法返 Manifest，非法 raise ModelError） | P2-3 | fuzz 不再仅防 panic |

预计提交：2~3 个。

### 阶段 3：安全声称对齐代码（治根因 ε，预计 2-3 个提交）

**目标：** SECURITY.md 每条声称都有代码支撑，或如实标注残留。

| 任务 | 对应问题 | 验收 |
| --- | --- | --- |
| 3.1 point_decode 加 y>=p 拒绝 + cofactor 乘法检查或显式低阶点拒绝；补负向攻击向量 | P1-2 | SECURITY.md"低阶点/非规范拒绝"声称属实 |
| 3.2 CLI_VERSION 同步 0.4.0；CI 加 CLI_VERSION == moon.mod 校验 | P1-3 | --version 输出 0.4.0 |
| 3.3 CLI create 递归子目录与 verify 布局对齐；补 create→verify 黑盒 | P1-4, P2-5 | create 产出可直接 verify |
| 3.4 audit verify_signatures_strict 模式（要求所有条目有签名） | P1-10 | 无签名剥离攻击可检测 |
| 3.5 E3002：verify_proof 映射为 E3002 finding 或规范标注 reserved | P1-8 | 错误码矩阵无死码 |
| 3.6 E2004 经 JS API 可达性决策（暴露字段或文档标注仅库层） | P2-4 | 错误码可达性一致 |

预计提交：3~4 个。

### 阶段 4：竞争力收尾（预计 3-5 个提交）

**目标：** 把"生态贡献"和"展示"从声称变实证，冲击专项奖。

| 任务 | 对应问题 | 验收 |
| --- | --- | --- |
| 4.1 Mooncakes 碰撞检查重跑（生态已约 1687 包）+ 更新文档 | P1-9 | "RFC 8785 首实现"有最新证据 |
| 4.2 moon login + moon publish 0.4.0 | P1-9 | Mooncakes 可安装 |
| 4.3 申报书 Gitlink 仓库确认/推送；双推完成勾掉验收第 2 条 | P2-12 | 双仓库公开可访问 |
| 4.4 OSC2026_APPLICATION 删除或补全刷新；STRUCTURE_TREE 补漏 | P2-11, P2-10 | 无两份材料并存 |
| 4.5 录制 5 分钟演示视频（按 Trust Workbench 6 视图）+ README 嵌链接 | P0-5 | 视频可播放 |
| 4.6 crypto Fe/Point opaque 封装（可选，工作量大） | P2-7 | 内部表示不暴露 |

预计提交：4~6 个。

---

## 六、风险与对策

| 风险 | 概率 | 对策 |
| --- | --- | --- |
| SHA-512 贯通后暴露 merkle/create 更多硬编码 | 中 | 阶段 0.1 先跑 SHA-512 端到端测试（会红），再逐处修 |
| audit from_json 实现复杂（entries 含签名重建） | 中 | from_json 先支持无签名条目，签名条目按 canonical JSON 重建 |
| 申报书三格式同步工作量大 | 中 | 以 .md 为权威，.tex/.html 用脚本或手工对齐 |
| Mooncakes 发布需所有者凭证 | 中 | 阶段 4.2 设为外部确认项，不阻塞其他阶段 |
| point_decode 补全引入正确性回归 | 中 | 每步 RFC 8032 KAT 回归；property 测试兜底 |
| check-metrics 扩展断言误报 | 中 | 只匹配明确断言句式，白名单历史日志段 |

---

## 七、交付物与验收

### 阶段性交付物

- 阶段 0：SHA-512 全链路可用、audit API 不再空壳、申报材料反映 0.4.0 全貌、手机号脱敏
- 阶段 1：api.mbt 10 pub 函数全覆盖、对外契约可验证、字段名统一
- 阶段 2：CI 真门禁（check-metrics/cross-verify/mutation-check 入 CI）、文档零漂移
- 阶段 3：SECURITY.md 每条声称有代码支撑、错误码矩阵无死码、create/verify 对称
- 阶段 4：Mooncakes 已发布、碰撞检查最新、演示视频在线、双仓库公开

### 最终验收命令（阶段 4 后）

```powershell
moon check
moon test --target wasm-gc,js
moon fmt --check
node tools/check-metrics.mjs          # 含申报材料断言
node tools/cross-verify.mjs
node tools/mutation-check.mjs
powershell -ExecutionPolicy Bypass -File tools/cli-test.ps1 -Target js
node tools/smoke-api.mjs              # 含 create/proof/ed25519/audit 闭环
git tag -l v0.4.0
```

全绿 + 文档零漂移（CI 强制）+ SHA-512 端到端可用 + API 全测试 + 安全声称属实 + Mooncakes 已发布 + 演示视频在线 = 健康度从 6.3 提升至 9.0+。

### 记录规则

每个阶段完成后：
1. 更新 `docs/records/RESULTS_LOG.md`（命令、结果、commit hash）——由 check-metrics.mjs 辅助确保数字准确
2. 关键决策更新 `docs/records/DECISION_LOG.md`
3. 本计划对应阶段标记 `[x]` 并 commit——标记前必须跑客观验收命令

---

## 八、与第 1、2 轮的对照

| 维度 | 第 1 轮 | 第 2 轮 | 第 3 轮 |
| --- | --- | --- | --- |
| 综合评分 | 6.2 | 7.2（自评） | 6.3（经核验） |
| Ed25519 S<l | P0，已修 | ✅ 生效 | ✅ 生效 |
| incremental E2004 | 未发现 | P1，已修 | ✅ 生效 |
| 量化漂移 | P1，建 RESULTS_LOG | ❌ 复发 | ❌ 仍漂移（86 vs 88）+ check-metrics 未入 CI |
| check-metrics 门禁 | — | P1，声称已建 | ❌ **工具建了但未接入 CI**（元问题） |
| **SHA-512 多算法断裂** | 未发现 | 未发现 | ❌ **P0 新发现**（verify/merkle 硬编码） |
| **audit API 空壳** | 未发现 | 未发现 | ❌ **P0 新发现**（恒返回有效） |
| **api.mbt 80% 无测试** | 未发现 | 未发现 | ❌ **P0 新发现** |
| **申报书漏 4/6 创新点** | 未发现 | 未发现 | ❌ **P0 新发现** |
| **Trust Workbench 未进材料** | — | — | ❌ **P0 新发现** |
| **SECURITY.md 安全声称超前** | 未发现 | 未发现 | ❌ P1 新发现 |
| Mooncakes 发布 | 待办 | 待办 | ⏳ 仍未做 |
| 演示视频 | P3 | P2 | ⏳ 仍未做 |

**结论：** 第 1、2 轮修复的 18 项中绝大多数治理生效，但第 2 轮自评 9.0 偏高——本轮发现 5 个新 P0（SHA-512 断裂/audit 空壳/API 无测试/申报书漏功能/Trust Workbench 缺失）+ 1 个元问题（CI 门禁未接入）+ 1 个诚信问题（安全声称超前）。项目工程内核持续向好，但"系统性半成品 + 材料错配 + 治理形似神不至"是冲击一等奖的三块结构性短板，需本轮 5 阶段计划落地。
