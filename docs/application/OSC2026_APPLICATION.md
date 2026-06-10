# MoonEvidence 项目申报书（MoonBit OSC2026）

> 结构对照赛方附录二 moon_elk 样本。`【待填】` 项需参赛者本人补充后导出为一页 PDF 提交。

## 基本信息

- 项目名称：MoonEvidence：可信证据包验证库与原生 CLI
- 参赛者：【待填：姓名/昵称】
- 联系方式：【待填：手机/邮箱】
- GitHub 仓库链接：https://github.com/wenlittle/MoonEvidence.git
- Gitlink 仓库链接：【待填：建仓后填写，与 GitHub 保持同步】
- 项目方向：工程基础设施 / 面向特定格式的验证工具（数据完整性、可信存证）
- 是否为移植项目：否（原创项目，实现对照 RFC 8785、RFC 6962、FIPS 180-4 公开标准）

## 项目简介

MoonEvidence 是一个链无关的「证据包」完整性验证内核：给定一组文件、manifest 元数据、Merkle 证明与版本记录，验证其是否完整、未被篡改、版本链是否连续，并输出机器可读与人类可读的双格式诊断。项目直接回应赛事痛点「AI 生成代码难以验证与长期维护」——AI 产物审计、数据集归档存证、上链前校验都需要一个可复用、可解释的验证层，而 MoonBit 生态目前不存在同类项目（碰撞检查记录见仓库 `docs/research/`）。交付物为可复用 MoonBit 库（发布至 Mooncakes）+ native CLI + wasm 浏览器 demo，展示 MoonBit 多后端能力。

## 核心功能范围

- RFC 8785 (JCS) 规范化 JSON：UTF-16 码元键排序、确定性转义、分级数字格式化策略——MoonBit 生态首个标准兼容实现；
- 纯 MoonBit SHA-256（FIPS 180-4）：零 FFI，NIST 测试向量全过，三后端同源运行；
- RFC 6962 风格 Merkle 树：`0x00`/`0x01` 前缀 domain separation 防二次原像攻击，含 inclusion proof 验证；
- manifest / 版本链强类型模型：全量字段校验，错误携带字段路径上下文；
- 七步验证编排与可解释诊断：结构化错误码 E1xxx~E5xxx + JSON 报告 + `explain` 人类可读输出；
- native CLI：`moon-evidence verify <pack>` / `explain`，退出码约定，可直接接入 CI 流水线；
- 三后端交付：native / wasm-gc / js 构建 + 浏览器在线验证 demo；
- 可信测试体系：篡改矩阵 fixtures、独立参考实现交叉验证 golden 数据、property test、benchmark；
- 双语 README 与用户指南，Mooncakes 0.1.0 发布。

## 原创说明

本项目为原创实现，不移植任何现有开源库；正确性以三类公开标准为对拍基准：RFC 8785 (JSON Canonicalization Scheme)、RFC 6962 (Certificate Transparency 的 Merkle 结构)、FIPS 180-4 (SHA-256)，并用独立参考实现生成 golden 测试向量交叉验证，杜绝「自己测自己」。Mooncakes 碰撞检查（2026-06-08 与 2026-06-10 两次，记录入库）确认生态内无功能重合项目；最近邻 `zploc/loci` 为 loci 运行时基底，与证据包验证领域不重合。本项目许可证：Apache-2.0。

## 工程现状（申报时点）

- 仓库已有规格冻结文档（证据包规格 v1、错误码表、公共 API 签名）、架构与路线图文档、决策/结果双日志；
- canonjson 与 digest 两包已实现并通过 `moon test`（9/9）；
- GitHub Actions CI 已接入，覆盖 `moon check` / `moon test` / `moon build --target native`；
- 有效提交 10+，全部为有实质内容的独立提交。
