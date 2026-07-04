# Security Policy

## 项目密码学实现说明

MoonEvidence 含**自实现的密码学原语**，未依赖任何外部经审计的密码学库：

- **SHA-256 / SHA-512**（`src/digest`）：纯 MoonBit 实现，对照 NIST FIPS 180-4 标准测试向量验证。
- **HMAC-SHA256**（`src/digest`）：RFC 2104 消息认证码。
- **Ed25519 数字签名**（`src/crypto`）：从 GF(2^255-19) 有限域到 Curve25519 点运算再到 RFC 8032 签名/验签，全程纯 MoonBit 实现，约 800 行。

### Ed25519 实现现状（含 0.3.1 根因加固）

经 2026-07-04 两轮健康体检与根因修复，Ed25519 实现已具备以下防护：

- **反可塑性**：`ed25519_verify` 拒绝 `S >= l` 的签名（RFC 8032 §8.4），攻击者无法用 `S + l` 伪造另一合法签名。
- **恒定时间标量乘法**：`scalar_mul` 用 conditional select（cmov）替代 secret-dependent 分支，`Fe::eq` 改为 XOR 累加，降低侧信道泄露风险。
- **Barrett reduction**：标量归约（`reduce_scalar_512`）由逐次减法改为 Barrett reduction，签名路径从 ~500K 次操作降至 ~50 次乘法，同时消除归约路径的时序差异。
- **低阶点 / 非规范编码拒绝**：`point_decode` 拒绝低阶点（cofactor 相关的小群攻击防护）与非规范编码，避免攻击者构造特殊点绕过验证。
- **审计签名覆盖 canonical JSON**：`audit.sign_last` / `verify_signatures` 对 RFC 8785 规范化序列化后的条目签名，确保签名输入字节稳定、无歧义，杜绝等价 JSON 文本导致的签名漂移。
- **RFC 8032 §7.1 KAT**：4 组官方已知答案测试（含 verify-only 向量）精确对比公钥常量，验证互操作性。

## 安全审计状态

**重要声明**：本项目的密码学实现（尤其是 Ed25519）**尚未经过外部专业安全审计**。它通过了 RFC 8032 已知答案测试（KAT）与交叉对拍，并已补齐反可塑性、恒定时间、Barrett reduction、低阶点拒绝等防护，但不应在生产环境或高价值资产保护场景中作为唯一的信任根使用。如需生产级保证，请替换为经审计的密码学库。

### 残留限制

经两轮根因修复后残留的限制（详见 `docs/plans/2026-07-04-health-check-and-improvement-plan.md`）：

- 恒定时间实现为代码审查级别，尚未经正式侧信道分析工具（如 dudect）量化验证。
- 标量乘法虽用 cmov，但 MoonBit 编译器未承诺消除所有 secret-dependent 内存访问；native 后端的 C 编译器可能重新引入分支。

## 报告漏洞

如果你发现安全漏洞，请**不要**在公开 Issue 中直接披露。请通过以下任一渠道私有报告：

- **GitHub Issues**：创建 Issue 并标注 `security` 标签（适用于非敏感问题）。
- **私有渠道**：通过仓库所有者联系方式（见 `docs/申报书.md`）私下联系。

报告时请包含：问题描述、复现步骤、影响评估与建议修复方案。收到报告后将在合理时间内确认并跟进。

## 适用范围

本安全策略适用于 MoonEvidence 仓库内的源代码（`src/`）与工具脚本（`tools/`）。`tests/fixtures/` 与 `examples/` 中的数据为测试/演示用途，不构成安全边界。
