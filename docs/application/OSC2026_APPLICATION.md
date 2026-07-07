# MoonEvidence 项目申报书（MoonBit OSC2026）

> 一页 PDF 提交源文档同步见 `docs/申报书.md` 与 `docs/申报书.pdf`。

## 基本信息

项目名称：MoonEvidence：可信证据包验证核心

参赛者：陈俊文

联系方式：187****1181

GitHub 仓库链接：https://github.com/starlittle/MoonEvidence

Gitlink 仓库链接：https://gitlink.org.cn/starlittle/MoonEvidence

项目方向：工程基础设施与工具链 / 数据完整性验证

是否为移植项目：否，原创项目，参考 RFC 8785、RFC 6962、RFC 8032、NIST FIPS 180-4 等公开标准实现

项目级开源许可证：Apache-2.0，根目录已提供 `LICENSE` 文件

## 项目简介

MoonEvidence 是一个纯 MoonBit 实现的可信证据包验证核心，用于验证一组文件、manifest 元数据、Merkle 根、版本链、审计日志和 Ed25519 签名是否一致、完整、可复核。

项目面向区块链存证前校验、AI 生成内容审计、数据集归档、学术成果发布、数字版权打包等场景，为 MoonBit 生态提供可复用的数据完整性验证基础设施。

项目采用“链无关 + 可嵌入 + 可解释”的工程定位：核心包保持零 IO 依赖，可被 CLI、CI、浏览器和后续链上流程复用；验证结果输出结构化错误码和人类可读 explain 报告，便于定位篡改位置、接入流水线和长期维护。

## 核心功能范围

提供 RFC 8785 Canonical JSON 序列化，覆盖 UTF-16 code-unit 键排序、确定性转义与 ECMAScript 数字表示，是 MoonBit 生态中的 JCS 基础实现；

提供纯 MoonBit SHA-256 / SHA-512 摘要实现，通过 NIST 标准向量验证，并支持证据包内多算法摘要策略；

提供 RFC 6962 风格 Merkle 树构建与 inclusion proof 验证，使用域分离前缀并与独立 Node 参考实现交叉对拍；

提供 manifest 强类型解析、路径安全校验、文件摘要比对、Merkle 根重算和版本链连续性验证，形成完整七步验证流水线；

提供 Ed25519 签名/验签、内容寻址对象存储和追加式哈希链审计日志，支持审计记录签名和篡改检测；

提供 native CLI 的 `create`、`verify`、`explain` 命令，冻结退出码并支持机器可读 JSON 与人类可读诊断输出；

提供浏览器端 Trust Workbench，覆盖验证、创建、证明、审计、签名和 Tamper Lab 六个视图，支持 Merkle 树可视化和实时篡改对比；

提供 native / wasm-gc / js 三后端交付，同一核心可运行于本地命令行、CI 流水线和浏览器端。

## 工程质量与交付状态

当前规模：12 个产品包 + 1 个 native timing 工具包；产品实现 5876 行，测试 8049 行，总计 13925 行 MoonBit，产品实现规模符合 4-10k 参考区间。

测试体系：344 个可执行 MoonBit 测试、348 个测试声明、54 个 CLI 黑盒用例，覆盖 RFC 8032 / Wycheproof / NIST / RFC 8785 向量、随机差分、变异验证、malformed fuzz、分支审计和 stale-check 门禁。

构建验证：native / wasm-gc / js 本地全绿，Windows MSVC native 环境已验证；CI 设计覆盖格式检查、构建、测试、烟测、fixture 防腐化和文档指标一致性。

安全 assurance：Ed25519 通过 RFC KAT、Wycheproof 150 向量、源码级常量时间审计和本机 native timing 50k 长跑；侧信道验证以工程化 assurance 层交付，正式 dudect/后端产物审计纳入生产化认证路线。

开源规范：仓库包含 Apache-2.0 `LICENSE`、README / README.zh、SECURITY、CONTRIBUTING、CHANGELOG、开发报告、验收清单、决策日志和结果日志。

## 原创与生态价值

MoonEvidence 为原创实现，设计对照 RFC 8785、RFC 6962、RFC 8032 与 NIST FIPS 180-4 等公开标准，不移植或重复 MoonBit 生态中的现有成熟项目。

项目把“文件是否被改过”的验证能力做成可复用基础层，为 MoonBit 在可信数据、AI 产物审计、归档存证和浏览器端验证场景中提供工程样板。

项目以可复跑测试、可解释诊断和可视化 Trust Workbench 作为展示入口，体现 MoonBit 在多后端、强类型和工程化交付上的综合能力。
