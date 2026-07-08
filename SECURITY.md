# Security Policy

## 项目密码学实现说明

MoonEvidence 含自实现的密码学原语，主要服务于 Evidence Pack 的本地完整性校验、审计链和签名验证：

- **SHA-256 / SHA-512**（`src/digest`）：纯 MoonBit 实现，对照 NIST FIPS 180-4 标准测试向量验证。
- **HMAC-SHA256**（`src/digest`）：RFC 2104 消息认证码。
- **Ed25519 数字签名**（`src/crypto`）：从 GF(2^255-19) 有限域、Curve25519 点运算到 RFC 8032 签名/验签，全程纯 MoonBit 实现。

## Ed25519 Assurance

当前 Ed25519 路径采用分层 assurance：标准向量、攻击向量、差分 oracle、mutation gate、源码级审计和 native timing 探针共同覆盖正确性与工程风险。

- **反可塑性**：`ed25519_verify` 拒绝 `S >= l` 的签名（RFC 8032 §8.4），覆盖 `S + l` 类签名可塑性攻击。
- **源码级分支收敛**：`scalar_mul` 使用 conditional select（cmov）替代标量位直接分支，`Fe::eq` 使用 XOR 累加；`reduce_scalar_512` 的比较与 borrow 传播已改为算术 mask/选择。
- **Binary quotient decomposition**：标量归约由逐次减法改为 binary quotient decomposition，减少签名路径中的极端循环成本。
- **非规范编码拒绝**：`point_decode` 通过 `Fe::to_bytes()` 往返规范化检查拒绝 `y >= p` 的非规范编码（RFC 8032 §5.1.3）。
- **低阶公钥拒绝**：`ed25519_verify` 先显式拒绝 identity 公钥，再计算 `8*A` 并拒绝结果为 identity 的公钥，覆盖 cofactor=8 torsion subgroup。
- **审计签名覆盖 canonical JSON**：`audit.sign_last` / `verify_signatures` 对 RFC 8785 规范化后的条目签名，确保签名输入字节稳定。
- **独立 oracle 覆盖**：RFC 8032 KAT、Google Wycheproof 150 条 Ed25519 向量、Node.js crypto 差分测试和 mutation gate 共同守住回归边界。

## 安全审计状态

本项目定位为课程/竞赛交付和本地可信校验核心。当前交付级证据链覆盖功能正确性、常见攻击向量、跨实现差分和源码级侧信道风险收敛；面向生产级高价值资产时，应把独立专业密码学审计、正式 dudect 基准和后端机器码审计作为发布前认证流程。

### 已知边界

- 侧信道 assurance 由源码审计与本机 native timing 探针组成，属于工程证据层，不等同于正式 dudect 证明。
- MoonBit 编译器和 native 后端 C 编译器可能改变源码级分支形态；生产级部署需要对最终产物做机器码级复核。
- 小子群处理已在公钥路径加入 `8*A` cofactor 检查，并由低阶点回归测试与 mutation gate 覆盖；生产级安全认证仍应补充后端产物审计和更完整的外部密码学评审。

## 报告漏洞

请不要在公开 Issue 中披露敏感安全问题。

- 敏感漏洞：使用 GitHub Security Advisory（仓库 Security 标签页 -> Report a vulnerability）私下报告。
- 非敏感问题：可创建公开 Issue，并标注 `security` 标签。

报告时请包含问题描述、复现步骤、影响评估与建议修复方案。收到报告后将在合理时间内确认并跟进。

## 适用范围

本安全策略适用于 MoonEvidence 仓库内的源代码（`src/`）与工具脚本（`tools/`）。`tests/fixtures/` 与 `examples/` 中的数据为测试/演示用途，不构成安全边界。
