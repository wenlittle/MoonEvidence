# Contributing

感谢你对 MoonEvidence 的兴趣。本文档说明贡献代码的约定。

## 代码风格

- 提交前一律运行官方格式化工具：`moon fmt`。CI 会对未格式化的代码报错。
- 一个源文件聚焦一个职责，文件首行写目的注释。
- 公共 API 必须带 `///` 文档注释；私有项按需注释"为什么"而非"做什么"。
- 纯核心包（`canonjson` / `digest` / `merkle` / `model` / `verify` / `diag` / `create` / `store` / `audit` / `crypto`）禁止任何文件系统或进程 IO；IO 只允许出现在 `cmd/main`、`api` 和仓库级 `integrations/` 适配器。Fabric Go/TypeScript 代码不得重算 manifest、文件摘要或 Merkle 语义。

## 测试要求

- **每个功能配测试**：新增/修改公共行为必须配套白盒测试（`*_wbtest.mbt`）。
- 测试命名清晰，断言精确（禁止"至少包含"式宽松断言）。
- 密码学与标准化实现必须对照公开测试向量（NIST / RFC 8785 Appendix B / RFC 8032 KAT）。
- 提交前本地全绿：
  ```powershell
  moon check
  moon test --target wasm-gc,js
  powershell -ExecutionPolicy Bypass -File tools/cli-test.ps1 -Target js
  bash ./tools/cli-test.sh js
  node tools/smoke-api.mjs
  npm run fabric:check
  npm run fabric:test
  Push-Location integrations/fabric/chaincode-go
  go vet ./...
  go test ./... -cover
  Pop-Location
  ```
- golden 数据（Merkle fixtures、篡改矩阵）由 `tools/gen-*.mjs` 独立 Node 参考实现生成；重新生成后 `git diff` 必须为空（防腐化校验）。

## 提交规范

遵循 [Conventional Commits](https://www.conventionalcommits.org/)：

```
<type>(<scope>): <subject>

<body>
```

- **type**：`feat`（新功能）/ `fix`（修复）/ `docs`（文档）/ `test`（测试）/ `refactor`（重构）/ `chore`（杂项）。
- **scope**：受影响的包名（如 `verify`、`crypto`、`docs`）。
- **subject**：祈使句，简短描述变更。
- 按逻辑单元划分提交，每个提交附验收记录（命令与结果）记入 `docs/records/RESULTS_LOG.md`。

示例：

```
feat(crypto): add ed25519_verify with RFC 8032 KAT
fix(verify): correct incremental path to surface E3003 not E3002
docs: unify quantitative claims to measured baseline (76/6891/219/12)
```

## 文档与记录

- 修改公共 API 需同步更新 `docs/ARCHITECTURE.md` 并在 `docs/records/DECISION_LOG.md` 记录决策。
- 修改 Fabric state/transaction/profile/receipt 语义需同步更新 `docs/spec/FABRIC_ANCHOR_SPEC.md`，并在真实协议或 SDK 边界变化时重跑双组织 E2E。
- 量化指标（提交数、行数、测试数、包数）一律引用 `docs/records/RESULTS_LOG.md` 中的实测基线，不要手填。
