# MoonEvidence 健康体检与改进计划（第 4 轮，5 轮迭代）

> **面向 AI 代理的工作者：** 本计划是对项目做第四轮"如何把它做好"的全面健康体检后的改进路线，不是最小可改补丁清单。**本轮只产出计划，不改任何代码。**
>
> **与前三轮的关系：** 第 3 轮（6.3/10）修了 SHA-512 贯通、API 空壳、CI 门禁、安全声称对齐——5 个根因（α 多算法断裂 / β API 空壳 / γ 治理形似神不至 / δ 材料过时 / ε 安全超前）全部封堵。第 4 轮在前 3 轮"工程内核已强"的基础上，聚焦**竞争力、创新点真伪、使用体验、测试质量、UI 演示效果**五个维度，发现"纸面功能、create 半成品、demo 主流程损坏、安全演示降级、声称夸大"五类**更深层的根因**。

**体检日期：** 2026-07-05 Asia/Shanghai
**体检方法：** 5 轮迭代式勘察——3 路并行子代理深度审计（竞争力+创新点 / 使用+测试质量 / UI+Trust Workbench），每条发现均有 file:line 证据或命令行实测；5 轮：基线快照 → 并行深审 → 根因聚类 → 优先级校准 → 计划定稿。
**体检范围：** `src/` 12 包代码、`demo/web/` 2 个 HTML、`docs/` 全部文档、`tools/` 11 脚本、`examples/` 2 pack、`moon.mod`/`CHANGELOG`。
**权威基线：** 提交 94；实现 4896 行 + 测试 5542 行 = 10438 行；moon test js/wasm-gc 275/275 通过；check-metrics 19/19 PASS；cross-verify 10/10；mutation 3/3 caught；smoke-api 24/24。

---

## 第 4 轮发现：5 类根因 + 22 个问题

### 根因 α：纸面功能（代码存在但用户够不到）

| # | 问题 | 证据 | 严重度 |
|---|------|------|--------|
| R4-α1 | **增量验证声称"已完成"但 CLI/API 均未接入** | `dev_report:91` 勾"已完成"；`incremental.mbt:27` 实现完整；但 `grep incremental main.mbt` = 0，`grep incremental api.mbt` = 0——用户无法通过任何入口使用 | P0 |
| R4-α2 | **审计签名验证声称"已完成"但 API/UI 未暴露** | `dev_report:103` 勾"已完成"；`audit_log.mbt:175/194` `sign_last`/`verify_signatures` 实现；但 `grep sign_last api.mbt` = 0，`index.html` audit 视图无签名按钮 | P0 |
| R4-α3 | **index.html 内 Tamper Lab 视图是空壳** | `index.html:326-335` 只显示"请使用 Tamper Lab 完整版"链接，无任何 Merkle 可视化 | P0 |
| R4-α4 | **Ed25519"生态首个"声称无碰撞检查证据** | `MOONCAKES_COLLISION_CHECK.md:9-20` 关键词列表无 ed25519/sha256/digest/crypto——即使 Mooncakes 已有这些包也不会发现 | P1 |

### 根因 β：create 是半成品

| # | 问题 | 证据 | 严重度 |
|---|------|------|--------|
| R4-β1 | **CLI create 静默丢弃子目录** | `main.mbt:413-428` `read_dir` 只读一层，子目录走 else 无日志；verify 侧 `collect_pack_files` 递归（`max_pack_depth=32`）——create 产出不完整但用户以为成功 | P0 |
| R4-β2 | **CLI create 零黑盒测试** | `grep create cli-test.ps1` = 0，`grep create cli-test.sh` = 0——create→verify 闭环无端到端测试 | P1 |
| R4-β3 | **API 与 CLI 路径约定不一致** | API 产出 `"files/a.txt"`（`api_wbtest.mbt:675`），CLI 产出裸 `"a.txt"`（`main.mbt:426`）——同一项目两处入口路径约定矛盾 | P1 |
| R4-β4 | **create 无 symlink 防护** | verify 有 depth/file cap（`main.mbt:267-274`），create 无任何防护 | P2 |

### 根因 γ：demo 主流程损坏

| # | 问题 | 证据 | 严重度 |
|---|------|------|--------|
| R4-γ1 | **Verify 视图拖目录主流程逻辑损坏** | `index.html:374` manifest.json 存为 hex，`:380-396` 无法解码回 text，回退 `alert("请通过粘贴 manifest JSON 来验证")`——拖目录形同虚设 | P0 |
| R4-γ2 | **tamper-lab.html 示例加载路径 404** | `tamper-lab.html:437` `fetch("../examples/valid-pack/manifest.json")` 解析为 `demo/examples/`，实际在 `examples/`——"装入示例"按钮必失败 | P0 |
| R4-γ3 | **DEMO_SCRIPT 与实际 UI 三处矛盾** | `DEMO_SCRIPT:52` 承诺"红色 FAILED 横幅 + E2003 表格"，实际 `index.html:420` 是 `JSON.stringify` 裸 JSON；`:53` 承诺"Tamper Lab 视图可视化 Merkle 树"，实际是空壳；`:53` "篡改 a.txt"按钮不存在 | P0 |
| R4-γ4 | **Verify 结果纯 JSON 输出，无表格** | `index.html:420` `box.textContent = JSON.stringify(resp, null, 2)`——评委看到一坨 JSON，无错误码高亮、无 expected/actual 对比 | P1 |
| R4-γ5 | **错误反馈全部用 alert()** | `index.html:385,392,405,472,523,531`——阻塞 UI、移动端差、无法复制 | P2 |
| R4-γ6 | **模块加载失败无全局禁用态** | `index.html:344-350` 加载失败只改顶部小字，按钮仍可点击 | P2 |

### 根因 δ：安全演示降级

| # | 问题 | 证据 | 严重度 |
|---|------|------|--------|
| R4-δ1 | **ed25519_keypair 无 CSPRNG，demo 每次相同密钥** | `api.mbt:631-640` 不传 seed 用硬编码 `[1,2,...,32]`；`index.html:551` 调用不传 seed；`index.html:552-558` 不显示 warning——评委点两次"生成密钥对"得到相同结果 | P0 |
| R4-δ2 | **mutation 只覆盖 Merkle，crypto/digest 零 mutation** | `mutation-check.mjs:34-68` 3 个目标全在 `merkle.mbt`——无法证明 Ed25519 KAT 会抓到签名 bug、SHA 会抓到压缩函数 bug | P1 |
| R4-δ3 | **SHA-512 缺长消息 FIPS 向量** | `sha512_wbtest.mbt` 仅 empty/abc/448-bit，缺 896-bit + 1M 'a'——second-block padding 路径覆盖不足 | P2 |

### 根因 ε：声称夸大

| # | 问题 | 证据 | 严重度 |
|---|------|------|--------|
| R4-ε1 | **store 包"类 Git object store"名不副实** | `object_store.mbt:1-144` 是内存 `Map[String,Bytes]` + SHA-256 键，无 packfile/tree对象/reflog/GC——Git 有这些，这里没有 | P1 |
| R4-ε2 | **包名 `starlittle/MoonEvidence` 含大写** | `moon.mod:4`——Mooncakes 生态其他包（moonbitlang/x、zploc/loci）全小写；大写可能导致 `moon publish` 拒绝 | P0/P1 |
| R4-ε3 | **CHANGELOG "Barrett reduction" 命名不准确** | `reduce_scalar_512` 实为 binary quotient decomposition（逐位预计算 l*2^k 减法），非真正 Barrett（倒数近似） | P2 |
| R4-ε4 | **README docs/ 链接在 Mooncakes 包首页失效** | `moon.mod:28-30` exclude docs/，但 `README.md:86-101` 引用多个 docs/ 子文档 | P2 |
| R4-ε5 | **check-metrics 41 用例数硬编码** | `check-metrics.mjs:187` `expected: 41` 注释"not derived from grep"——不实际解析 cli-test.ps1 | P2 |

---

## 改进计划（5 阶段）

> 阶段顺序按"演示阻断 → 功能可达 → 安全可信 → 声称诚实 → 竞争力收尾"排列。每阶段独立可交付。

### 阶段 0：demo 演示阻断修复（立即，2-3 个提交）

**目标：** 让评委按 DEMO_SCRIPT 操作能完整跑通 5 分钟闭环。

| 任务 | 对应问题 | 验收 |
| --- | --- | --- |
| 0.1 修复 Verify 视图拖目录逻辑：manifest.json 单独存为 text（不转 hex），或验证时从 hex 解码 | R4-γ1 | 拖入 valid-pack → 绿色 OK；拖入 tampered-pack → 红色 FAILED + E2003 |
| 0.2 修复 tamper-lab.html 示例路径：`../examples` → `../../examples` | R4-γ2 | "装入示例"按钮成功加载 valid-pack |
| 0.3 Verify 结果渲染为错误码表格：解析 findings，渲染 code/severity/path/message 表格，红色 Error 行高亮 | R4-γ4 | tampered-pack 验证后显示 E2003 表格而非裸 JSON |
| 0.4 重写 DEMO_SCRIPT 与实际 UI 对齐：修正三处矛盾，或按脚本修 UI | R4-γ3 | DEMO_SCRIPT 每步与 UI 实际行为一致 |
| 0.5 index.html Tamper Lab 视图：内嵌 Merkle 可视化 iframe，或改 DEMO_SCRIPT 直接跳转 tamper-lab.html | R4-α3 | 评委点"篡改实验室"能看到 Merkle 树 |

### 阶段 1：功能可达性（治根因 α，2-3 个提交）

**目标：** 让"已完成"的功能真正可达——CLI/API/UI 三入口至少一处可用。

| 任务 | 对应问题 | 验收 |
| --- | --- | --- |
| 1.1 CLI 接入增量验证：`moon-evidence verify --incremental <cache-dir>` 调 `verify_manifest_incremental` | R4-α1 | CLI `verify --incremental` 可用，二次验证跳过未改文件 |
| 1.2 API 暴露审计签名：`audit_sign` 调 `sign_last`，`audit_verify` 增加 `verify_signatures: true` 选项调 `verify_signatures` | R4-α2 | API 可签名审计日志、可验证签名 |
| 1.3 UI Audit 视图增加签名/验签按钮 | R4-α2 | demo 可演示"签名 → 验签"闭环 |
| 1.4 ed25519_keypair CSPRNG：JS 后端用 `crypto.getRandomValues`，或 API 接受随机 seed 由前端生成 | R4-δ1 | 两次"生成密钥对"得到不同密钥；warning 不再出现 |

### 阶段 2：create 补完（治根因 β，1-2 个提交）

**目标：** 让 create 成为 verify 的真正对称 counterpart。

| 任务 | 对应问题 | 验收 |
| --- | --- | --- |
| 2.1 CLI create 递归子目录：`collect_files` 复用 verify 的递归逻辑；子目录文件路径加 `files/` 前缀 | R4-β1, R4-β3 | create 含子目录的目录 → verify 闭环成功 |
| 2.2 CLI create 黑盒测试：cli-test 增加 create→verify 闭环用例（扁平目录、嵌套目录、空目录） | R4-β2 | create 至少 3 个黑盒用例 |
| 2.3 create symlink 防护：复用 verify 的 depth/file cap | R4-β4 | symlink 循环不导致无限递归 |

### 阶段 3：安全与测试加固（治根因 δ，1-2 个提交）

**目标：** 让安全演示可信、mutation 守门覆盖最危险路径。

| 任务 | 对应问题 | 验收 |
| --- | --- | --- |
| 3.1 mutation 扩展：增加 Ed25519 mutation 目标（如 flip scalar reduction 某位、swap point_add/point_double）、SHA-256 mutation（flip round constant） | R4-δ2 | mutation-check 至少 6 个目标，覆盖 crypto+digest |
| 3.2 SHA-512 补 FIPS 长消息向量：896-bit + 1M 'a' | R4-δ3 | sha512_wbtest 覆盖多块 padding 路径 |
| 3.3 verify_proof API 文档：在 api.mbt 注释中明确说明 leaf 是 canonical file entry text hex，非文件内容 | — | API 注释自解释，用户不需读测试才知道契约 |

### 阶段 4：声称诚实 + 竞争力收尾（治根因 ε，2-3 个提交）

**目标：** 每条声称都站得住，Mooncakes 发布就绪。

| 任务 | 对应问题 | 验收 |
| --- | --- | --- |
| 4.1 store 声称降级："类 Git object store" → "内存内容寻址去重 Map" | R4-ε1 | dev report / README 措辞与代码一致 |
| 4.2 Mooncakes 碰撞检查补查：ed25519/sha256/digest/crypto/hash 关键词 | R4-α4 | "生态首个"声称有完整证据 |
| 4.3 包名验证：`moon publish --dry-run` 测试大写是否阻断；若阻断则改名 `starlittle/moon-evidence` | R4-ε2 | `moon publish --dry-run` exit 0 |
| 4.4 CHANGELOG 修正：Barrett → binary quotient decomposition | R4-ε3 | 命名与实现一致 |
| 4.5 README Mooncakes 首页适配：docs/ 链接改为相对描述或内联关键信息 | R4-ε4 | Mooncakes 包首页无失效链接 |
| 4.6 check-metrics 41 用例数动态化：解析 cli-test.ps1 的用例计数 | R4-ε5 | cli-test 增删用例时 check-metrics 自动发现 |

---

## 评分（4 维度）

| 维度 | 第 3 轮 | 第 4 轮 | 变化 | 根因 |
|------|---------|---------|------|------|
| 竞争力+创新点 | 5.5 | 6.0 | +0.5 | 创新点实现真实，但"生态首个"证据不全 + store 声称夸大 |
| 使用+测试 | 6.5 | 6.0 | -0.5 | 测试 KAT 真实但 create 半成品 + 增量验证不可达 |
| UI+演示 | 5.5 | 4.5 | -1.0 | demo 主流程损坏 + Tamper Lab 空壳 + DEMO_SCRIPT 矛盾 |
| 文档+治理 | 6.0 | 7.5 | +1.5 | CI 门禁已接入 + check-metrics 全通过 + 文档数字同步 |
| **综合** | **6.3** | **6.0** | **-0.3** | 上轮修的是工程内核，本轮暴露的是用户体验层 |

**为什么评分下降：** 第 3 轮聚焦"工程内核是否扎实"（SHA-512/API/CI/安全），评分提升到 6.3。第 4 轮聚焦"用户/评委实际用起来如何"，发现 demo 主流程损坏、create 半成品、功能不可达——这些问题在"工程内核"视角下不可见，但在"用户体验"视角下是阻断性的。**项目不是"不好"，而是"内核强但表面还没打磨到能用"**。

---

## 非问题（已验证为真）

以下声称经本轮深审确认**真实可靠**，无需修改：
- RFC 8785 JCS 实现（Appendix B 23 向量，UTF-16 code unit 排序，非简化版）
- Merkle RFC 6962 style 域分离（CVE-2012-2459 self-pairing 反例测试）
- SHA-256 FIPS 180-4 官方向量（empty/abc/448/896/1M'a' + 流式不变性）
- Ed25519 RFC 8032 Test Vector 1-3 KAT + 反可塑性检查
- 41 个 CLI 黑盒用例真实且断言严格（精确错误码 multiset 比较）
- 前端调用真实 MoonBit 编译产物，无 mock 响应
- crypto 全部纯 MoonBit，无 FFI，跨后端语义一致
- 核心六包（canonjson/digest/merkle/model/verify/diag）质量高
- Tamper Lab SVG Merkle 可视化是杀手级特性（若能展示）
