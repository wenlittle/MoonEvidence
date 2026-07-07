# Security Policy

## 项目密码学实现说明

MoonEvidence 含**自实现的密码学原语**，未依赖任何外部经审计的密码学库：

- **SHA-256 / SHA-512**（`src/digest`）：纯 MoonBit 实现，对照 NIST FIPS 180-4 标准测试向量验证。
- **HMAC-SHA256**（`src/digest`）：RFC 2104 消息认证码。
- **Ed25519 数字签名**（`src/crypto`）：从 GF(2^255-19) 有限域到 Curve25519 点运算再到 RFC 8032 签名/验签，全程纯 MoonBit 实现，约 800 行。

### Ed25519 实现现状（含 0.3.1 根因加固）

经 2026-07-04 两轮健康体检与根因修复，Ed25519 实现已具备以下防护：

- **反可塑性**：`ed25519_verify` 拒绝 `S >= l` 的签名（RFC 8032 §8.4），攻击者无法用 `S + l` 伪造另一合法签名。
- **恒定时间标量乘法（静态审计级）**：`scalar_mul` 用 conditional select（cmov）替代 secret-dependent 分支，`Fe::eq` 改为 XOR 累加，降低侧信道泄露风险。
- **Binary quotient decomposition**：标量归约（`reduce_scalar_512`）由逐次减法改为 binary quotient decomposition，签名路径从 ~500K 次操作降至 ~50 次乘法。2026-07-06 已修复 CT-001：比较与 borrow 传播改为算术 mask/选择，源码层面不再包含该处 secret-derived 分支。
- **非规范编码拒绝**：`point_decode` 通过 Fe::to_bytes() 往返规范化检查拒绝 y ≥ p 的非规范编码（RFC 8032 §5.1.3），防止非规范 y 坐标导致的编码歧义。
- **Identity point 拒绝**：`ed25519_verify` 显式拒绝 identity 公钥（RFC 8032 §5.1.3），阻断 R = S·B 伪造路径。
- **审计签名覆盖 canonical JSON**：`audit.sign_last` / `verify_signatures` 对 RFC 8785 规范化序列化后的条目签名，确保签名输入字节稳定、无歧义，杜绝等价 JSON 文本导致的签名漂移。
- **RFC 8032 §7.1 KAT**：4 组官方已知答案测试（含 verify-only 向量）精确对比公钥常量，验证互操作性。

## 安全审计状态

**安全保证定位**：本项目面向课程/竞赛场景中的本地 Evidence Pack 可信校验核心，密码学路径采用分层 assurance 策略：RFC 8032 已知答案测试（KAT）、Wycheproof 攻击向量、交叉对拍、源码级常量时间审计与本机 native dudect-style timing 长跑共同构成当前交付级证据包。项目已补齐反可塑性、恒定时间标量乘法、branch-free 源码级标量归约、binary quotient decomposition、低阶点拒绝等防护；若未来承载生产级高价值资产，下一层升级门槛是独立专业审计、正式 dudect 基准与后端产物审计。

### 残留限制

经两轮根因修复后残留的限制（详见 `docs/plans/2026-07-04-health-check-and-improvement-plan.md`）：

- 恒定时间实现采用“源码审计 + native timing 证据层”的工程取舍；`docs/CONST_TIME_AUDIT.md` 已记录 CT-001 的源码级修复与 50000 样本 native timing 长跑。正式 dudect/后端产物审计被列为生产化升级项，而不是当前课程交付的阻塞项。
- 标量乘法虽用 cmov，但 MoonBit 编译器未承诺消除所有 secret-dependent 内存访问；native 后端的 C 编译器可能重新引入分支。
- 低阶点检查仅覆盖 identity point（显式拒绝），未实现完整 cofactor 8 乘法检查（7 个非 identity 低阶点仍可能通过 point_decode）。在 cofactorless Ed25519 验证中风险有限，但生产级实现应补齐完整 cofactor 检查。

## 报告漏洞

如果你发现安全漏洞，请**不要**在公开 Issue 中直接披露。请通过以下任一渠道私有报告：

- **GitHub Issues**：创建 Issue 并标注 `security` 标签（适用于非敏感问题）。
- **私有渠道**：通过 GitHub Security Advisory（仓库 Security 标签页 → Report a vulnerability）私下联系，或通过申报书中的脱敏联系方式协商安全通信渠道。

报告时请包含：问题描述、复现步骤、影响评估与建议修复方案。收到报告后将在合理时间内确认并跟进。

## 适用范围

本安全策略适用于 MoonEvidence 仓库内的源代码（`src/`）与工具脚本（`tools/`）。`tests/fixtures/` 与 `examples/` 中的数据为测试/演示用途，不构成安全边界。
