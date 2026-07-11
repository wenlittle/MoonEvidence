# MoonEvidence 项目索引

> 当前版本：v0.5.0
>
> 主要仓库：[GitHub](https://github.com/wenlittle/MoonEvidence) · [GitLink](https://gitlink.org.cn/starlittle/MoonEvidence)
>
> 发布包：[Mooncakes](https://mooncakes.io/docs/#/starlittle/MoonEvidence)

MoonEvidence 使用 MoonBit 创建和验证证据包，定位文件变化，并把已验证的规范摘要交给归档系统或 Hyperledger Fabric 保存。

## 1. 项目组成

| 交付面 | 职责 | 入口 |
| --- | --- | --- |
| MoonBit 库 | 规范化、摘要、Merkle、manifest、验证、审计和签名 | [`src/`](../src/) |
| CLI | 封装目录、检查证据包、输出稳定 JSON 和退出码 | [`src/cmd/main`](../src/cmd/main/) |
| 浏览器 API | 以字符串输入/输出调用同一 MoonBit 核心 | [`src/api`](../src/api/) |
| Showcase | 沉浸首页、六工具工作台和真实 MoonBit JS 产物 | [`showcase/`](../showcase/) |
| 轻量 demo | 无框架静态页面和篡改实验 | [`demo/`](../demo/) |
| Fabric 适配器 | 提交规范摘要、读取回执、查询并回传验证 | [`integrations/fabric/`](../integrations/fabric/) |
| Mooncakes 包 | 复用 MoonBit 产品包、规范、示例和指南 | [`moon.mod`](../moon.mod) |

## 2. 阅读路径

| 读者任务 | 建议顺序 |
| --- | --- |
| 五分钟判断项目 | [README](../README.md) -> [在线 Showcase](https://wenlittle.github.io/MoonEvidence/) -> [验收证据](records/ACCEPTANCE_CHECKLIST.md) |
| 创建和验证证据包 | [用户指南](GUIDE.md) -> [证据包规范](spec/EVIDENCE_PACK_SPEC.md) -> [CLI 契约](spec/CLI_MACHINE_CONTRACT.md) |
| 评审设计和实现 | [开发报告](report/DEVELOPMENT_REPORT.md) -> [架构](ARCHITECTURE.md) -> [安全说明](../SECURITY.md) |
| 评审测试可信度 | [测试计划](TEST_PLAN.md) -> [测试治理](TEST_GOVERNANCE.md) -> [分支审计](BRANCH_COVERAGE.md) -> [结果记录](records/RESULTS_LOG.md) |
| 复跑 Fabric | [Fabric 指南](../integrations/fabric/README.md) -> [锚定规范](spec/FABRIC_ANCHOR_SPEC.md) -> [实链记录](records/fabric-e2e/2026-07-11/) |
| 参与开发 | [架构](ARCHITECTURE.md) -> [代码规范](CODE_GUIDELINES.md) -> [贡献指南](../CONTRIBUTING.md) -> [安全报告](../SECURITY.md#报告渠道) |
| 检查比赛交付 | [验收证据](records/ACCEPTANCE_CHECKLIST.md) -> [自查记录](records/OSC2026_GUIDE_SELF_CHECK.md) -> [申报材料](application/) |

## 3. 文档职责

### 3.1 项目入口

| 文件 | 唯一职责 |
| --- | --- |
| [`README.md`](../README.md) | 中文项目首页、核心流程、体验入口和质量摘要 |
| [`README.en.md`](../README.en.md) | 与中文首页同结构的英文入口 |
| [`GUIDE.md`](GUIDE.md) | 按任务组织安装、封装、验证、自动化、浏览器和 Fabric 操作 |
| [`DEMO_SCRIPT.md`](DEMO_SCRIPT.md) | 五分钟现场演示顺序和可观察结果 |
| [`showcase/README.md`](../showcase/README.md) | Showcase 运行、数据路径和前端结构 |
| [`demo/README.md`](../demo/README.md) | 轻量静态 demo 启动方式 |

### 3.2 设计说明

| 文件 | 唯一职责 |
| --- | --- |
| [`report/DEVELOPMENT_REPORT.md`](report/DEVELOPMENT_REPORT.md) | 场景、目标、方案、实现、Fabric 实验、质量和生态价值的完整论证 |
| [`DEVELOPMENT_REPORT.md`](DEVELOPMENT_REPORT.md) | 旧开发报告链接的兼容入口 |
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | 当前分层、组件职责、数据流、信任边界、合同和扩展点 |
| [`SECURITY.md`](../SECURITY.md) | 安全模型、保障范围、密钥职责、部署级别和报告渠道 |
| [`ROADMAP.md`](ROADMAP.md) | 后续能力和生产化里程碑 |
| [`STRUCTURE_TREE.md`](STRUCTURE_TREE.md) | 当前目录和关键文件结构 |
| [`KNOWLEDGE_BASE.md`](KNOWLEDGE_BASE.md) | 新任务快速接手所需的项目模型、合同入口、质量基线和常用命令 |

### 3.3 稳定合同

| 文件 | 唯一职责 |
| --- | --- |
| [`spec/EVIDENCE_PACK_SPEC.md`](spec/EVIDENCE_PACK_SPEC.md) | manifest、规范字节、摘要、Merkle 和验证语义 |
| [`spec/CLI_MACHINE_CONTRACT.md`](spec/CLI_MACHINE_CONTRACT.md) | CLI JSON schema、退出码、错误阶段和外部摘要参数 |
| [`spec/FABRIC_ANCHOR_SPEC.md`](spec/FABRIC_ANCHOR_SPEC.md) | Fabric 状态、交易、隐私、幂等和回执合同 |
| [`src/**/pkg.generated.mbti`](../src/) | 当前 MoonBit 包的生成接口 |

### 3.4 质量体系

| 文件 | 唯一职责 |
| --- | --- |
| [`TEST_PLAN.md`](TEST_PLAN.md) | 风险面、证据分层、当前覆盖、执行档位和维护触发器 |
| [`TEST_GOVERNANCE.md`](TEST_GOVERNANCE.md) | P0/P1/P2、完成定义、门禁归属和收口规则 |
| [`BRANCH_COVERAGE.md`](BRANCH_COVERAGE.md) | 安全相关分支到测试证据的映射 |
| [`CONST_TIME_AUDIT.md`](CONST_TIME_AUDIT.md) | Ed25519 秘密输入分类、源码审计和原生计时 |
| [`CODE_GUIDELINES.md`](CODE_GUIDELINES.md) | 代码风格、注释、测试和公开 API 规则 |
| [`.github/workflows/ci.yml`](../.github/workflows/ci.yml) | 合并门禁的可执行来源 |

### 3.5 记录材料

| 文件 | 唯一职责 |
| --- | --- |
| [`records/RESULTS_LOG.md`](records/RESULTS_LOG.md) | 带时间、环境、方法和结果的追加式记录 |
| [`records/DECISION_LOG.md`](records/DECISION_LOG.md) | 稳定技术决策和取舍依据 |
| [`records/KNOWLEDGE_BASE_2026-07-07.md`](records/KNOWLEDGE_BASE_2026-07-07.md) | 重构前的 API、测试盲点和阶段知识库快照 |
| [`records/ACCEPTANCE_CHECKLIST.md`](records/ACCEPTANCE_CHECKLIST.md) | 赛事九项要求到仓库证据的映射 |
| [`records/OSC2026_GUIDE_SELF_CHECK.md`](records/OSC2026_GUIDE_SELF_CHECK.md) | 赛事自查技能和参考项目对照结果 |
| [`records/fabric-e2e/2026-07-11/`](records/fabric-e2e/2026-07-11/) | Fabric 部署、交易、查询和摘要回传证据 |
| [`research/MOONCAKES_COLLISION_CHECK.md`](research/MOONCAKES_COLLISION_CHECK.md) | Mooncakes 同类关键词和命名碰撞检查 |
| [`application/`](application/) | 一页申报书及生成源文件 |

### 3.6 工作计划

| 文件 | 唯一职责 |
| --- | --- |
| [`plans/2026-07-12-reviewer-delivery-plan.md`](plans/2026-07-12-reviewer-delivery-plan.md) | v0.5.1 交付一致性、首次使用、评奖展示和最终发布清单 |
| [`plans/2026-07-11-documentation-restructure-plan.md`](plans/2026-07-11-documentation-restructure-plan.md) | 本轮写作合同、结构树、图表方案和读者测试 |
| [`plans/2026-06-10-competition-master-plan.md`](plans/2026-06-10-competition-master-plan.md) | 比赛开发和交付总计划 |
| [`plans/2026-07-04-health-check-and-improvement-plan.md`](plans/2026-07-04-health-check-and-improvement-plan.md) | 第一轮仓库健康检查记录 |
| [`plans/2026-07-04-health-check-round2-and-improvement-plan.md`](plans/2026-07-04-health-check-round2-and-improvement-plan.md) | 第二轮多视角健康检查记录 |

## 4. 证据来源

| 声明 | 权威来源 |
| --- | --- |
| 当前版本和依赖 | `moon.mod`、各包 `moon.pkg`、锁文件、Git tag、Mooncakes |
| 公开 MoonBit 接口 | `src/**/pkg.generated.mbti` |
| 证据包语义 | `spec/EVIDENCE_PACK_SPEC.md` |
| CLI 进程语义 | `spec/CLI_MACHINE_CONTRACT.md` |
| Fabric 状态语义 | `spec/FABRIC_ANCHOR_SPEC.md` |
| 当前架构和信任边界 | `ARCHITECTURE.md`、`SECURITY.md` |
| 测试数量和源码行数 | `tools/check-metrics.mjs` |
| 运行结果 | `records/RESULTS_LOG.md` |
| Fabric 交易结论 | `records/fabric-e2e/2026-07-11/` |
| 设计取舍 | `records/DECISION_LOG.md` |
| 赛事验收状态 | `records/ACCEPTANCE_CHECKLIST.md` |

## 5. 维护规则

1. 精确数字绑定时间、提交和运行记录。
2. 当前接口以生成的 `pkg.generated.mbti` 为准，历史接口进入变更记录。
3. 每个主题保留一份完整来源，其他文档使用短摘要和链接。
4. 安全声明同步复核架构、测试计划和侧信道记录。
5. Fabric 结论链接交易 ID、区块号、状态和回传结果。
6. 新增文档、工具或证据目录时更新本索引。
7. 发布前执行干净克隆复现、链接检查、指标门禁和无背景读者测试。

## 6. 当前交付

| 项目 | 状态 |
| --- | --- |
| MoonEvidence v0.5.0 | GitHub Release、GitLink tag 和 Mooncakes 已发布 |
| 在线体验 | GitHub Pages 首页和工作台可访问 |
| 质量基线 | 四后端、CLI、浏览器 API、独立参考、随机差分和 mutation 已记录 |
| Fabric | 双组织真实协议闭环和脱敏证据已保存 |
| 比赛材料 | 一页申报书、README、开发报告和九项验收映射齐备 |

下一次公开交付先运行 [测试治理](TEST_GOVERNANCE.md)定义的发布门禁，再更新结果记录和验收证据。
