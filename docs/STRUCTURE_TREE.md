# Structure Tree

Current preparation tree as of 2026-07-11 Asia/Shanghai.

```text
moon-evidence/
  .github/
    workflows/
      ci.yml
      release.yml
      showcase-pages.yml
      README.md
  .gitattributes
  .gitignore
  moon.mod
  package.json                  # local Node workspace helpers; excluded from Mooncakes
  README.md                     # Chinese primary project page
  README.en.md                  # English mirror
  README.zh.md                  # compatibility link to README.md
  docs/
    ARCHITECTURE.md
    CODE_GUIDELINES.md
    DEMO_SCRIPT.md
    DEVELOPMENT_REPORT.md
    ENVIRONMENT.md
    GUIDE.md
    KNOWLEDGE_BASE.md             # current handoff map; authoritative details stay in specs and records
    PROJECT_INDEX.md
    ROADMAP.md
    STRUCTURE_TREE.md
    申报书.html
    申报书.md
    申报书.pdf
    申报书.tex
    application/
      OSC2026_APPLICATION.md
    images/
      demo-web.png
      trust-observatory.png
    plans/
      2026-06-10-competition-master-plan.md
      2026-07-04-health-check-and-improvement-plan.md
    records/
      ACCEPTANCE_CHECKLIST.md
      DECISION_LOG.md
      KNOWLEDGE_BASE_2026-07-07.md # historical pre-restructure notebook
      RESULTS_LOG.md
      fabric-e2e/
        2026-07-11/             # sanitized real Fabric receipts and backfeed results
    report/
      DEVELOPMENT_REPORT.md
    research/
      MOONCAKES_COLLISION_CHECK.md
    spec/
      CLI_MACHINE_CONTRACT.md
      EVIDENCE_PACK_SPEC.md
      FABRIC_ANCHOR_SPEC.md
  demo/
    web/
      index.html
      tamper-lab.html
      README.md
  examples/
    tampered-pack/
      files/
        a.txt
        b.bin
      README.md
      manifest.json
    valid-pack/
      files/
        a.txt
        b.bin
      versions/
        version_chain.json
      README.md
      manifest.json
  showcase/                   # 沉浸式产品首页 + 原生证据工作台
    public/
      favicon.svg
    src/
      components/
        HomePage.tsx
        SiteHeader.tsx
      scene/
        EvidenceScene.tsx
        HeroScene.tsx
        useSceneVisibility.ts
      story/
        useScrollNarrative.ts
      workbench/              # 验证、创建、证明、审计、签名、篡改六项工具
      workers/
        moon.worker.ts
      App.tsx
      main.tsx
      moon-rpc.ts
      store.ts
      styles.css
      types.ts
      verify-request.ts       # manifest、payload 与可选版本链请求组装
    tools/
      prepare-api.mjs
    README.md
    package.json
    vite.config.ts
  integrations/
    fabric/
      README.md               # test-network deployment and adapter guide
      chaincode-go/
        chaincode/
          anchor_contract.go
          anchor_contract_test.go
        go.mod
        go.sum
        main.go
      gateway/
        profiles/
          test-network-org1.example.json
        src/
          anchor.ts
          cli.ts
          gateway.ts
          index.ts
          moon-cli.ts
          profile.ts
        test/
        package.json
        package-lock.json
        tsconfig.json
  src/
    README.md
    api/                       # 浏览器 ESM 适配器
      api.mbt
      api_wbtest.mbt
      moon.pkg
    audit/                     # 哈希链审计日志 + Ed25519 签名集成
      audit_log.mbt
      audit_log_wbtest.mbt
      moon.pkg
    canonjson/                 # RFC 8785 规范化 JSON
      README.md
      canonjson.mbt
      canonjson_jcs_wbtest.mbt
      canonjson_prop_wbtest.mbt
      canonjson_wbtest.mbt
      moon.pkg
    cmd/                       # CLI 适配器
      main/
        README.md
        main.mbt
        moon.pkg
    create/                    # 证据包创建
      create.mbt
      create_wbtest.mbt
      moon.pkg
    crypto/                    # Ed25519 数字签名（纯 MoonBit）
      ed25519.mbt
      ed25519_wbtest.mbt
      field25519.mbt
      field25519_wbtest.mbt
      moon.pkg
      point25519.mbt
      point25519_wbtest.mbt
    diag/                      # 结构化诊断 + explain
      README.md
      diag.mbt
      diag_wbtest.mbt
      moon.pkg
    digest/                    # SHA-256 / SHA-512 / HMAC
      README.md
      digest.mbt
      digest_bench_wbtest.mbt
      digest_wbtest.mbt
      hmac.mbt
      hmac_wbtest.mbt
      moon.pkg
      sha256.mbt
      sha256_wbtest.mbt
      sha512.mbt
      sha512_wbtest.mbt
      utf8.mbt
      utf8_wbtest.mbt
    merkle/                    # RFC 6962 风格 Merkle 树
      README.md
      merkle.mbt
      merkle_golden_wbtest.mbt
      merkle_prop_wbtest.mbt
      merkle_wbtest.mbt
      moon.pkg
    model/                     # manifest / 版本链模型
      README.md
      error.mbt
      manifest.mbt
      manifest_wbtest.mbt
      moon.pkg
      version.mbt
      version_wbtest.mbt
    store/                     # 内容寻址存储
      moon.pkg
      object_store.mbt
      object_store_wbtest.mbt
    timing/                    # native-only Ed25519 timing 实验
      main.mbt
      main_non_native.mbt
      moon.pkg
      native_timing_stub.c
    verify/                    # 七步验证流水线 + 版本链
      README.md
      chain.mbt
      chain_wbtest.mbt
      incremental.mbt
      incremental_wbtest.mbt
      moon.pkg
      verify.mbt
      verify_bench_wbtest.mbt
      verify_wbtest.mbt
  tests/
    README.md
    fixtures/
      README.md
      jcs/                     # RFC 8785 Appendix B 向量
      manifest/                # manifest 模型篡改夹具
        README.md
      merkle/                  # golden 数据
        golden.json
      packs/                   # 10 包篡改矩阵
        README.md
        bad-digest-field/
        bad-merkle-root/
        chain-broken/
        chain-cycle/
        chain-empty/
        chain-fork/
        missing-file/
        tampered-file/
        unlisted-file/
        valid/
      version-chain/           # 版本链篡改夹具
  tools/
    cli-test.ps1               # 67 用例黑盒 CLI 套件
    env-check.ps1              # 只读环境检查
    gen-fixtures.mjs           # 篡改矩阵生成（独立 Node 参考实现）
    gen-merkle-fixtures.mjs    # Merkle golden 数据生成
    gen-pack-fixture.mjs       # 单个证据包夹具生成
    smoke-api.mjs              # 浏览器适配器 37 断言烟测
    cli-test.sh                # 67 用例黑盒 CLI（bash 版，与 ps1 1:1 对等）
    cross-verify.mjs           # 独立 Node 交叉验证（create/store/audit 重算对比）
    differential-crypto.mjs    # Ed25519 JS API 与 Node.js crypto 随机差分对拍
    differential-digest.mjs    # SHA/HMAC JS API 与 Node.js crypto 随机差分对拍
    fuzz-api-malformed.mjs     # JS API malformed request fuzz 门禁
    property-api-semantic.mjs  # JS API valid-request 闭环 property 门禁
    randomized-hardening.mjs   # ci/release/stress 随机化加固 profile
    timing-ed25519-verify.mjs  # Ed25519 verify 动态时序采样探针
    timing-ed25519-native.ps1  # Ed25519 native verify/sign dudect-style timing runner
    mutation-check.mjs         # 变异验证（故意破坏实现确认测试会红）
    check-fixtures.mjs         # fixtures 防腐化校验
    check-metrics.mjs          # CI 数字对齐门禁（提交/行/测试/包/版本一致性断言）
    check-package-contents.mjs # Mooncakes 包内容卫生门禁
```

## Package Summary

`src/` 下共 **13 个包**（12 个产品包 + 1 个 native timing 工具包）：

- **核心包（零 IO）**：`canonjson` / `digest` / `merkle` / `model` / `verify` / `diag`
- **扩展包**：`create`（证据包创建）/ `store`（内容寻址存储）/ `audit`（审计日志）/ `crypto`（Ed25519 签名）
- **适配器**：`cmd/main`（JS/native CLI）/ `api`（浏览器 ESM）
- **实验工具包**：`timing`（native-only Ed25519 verify/sign timing evidence，不作为产品 API）

`integrations/fabric/` 是公开源码仓库中的可选跨系统适配器：Go Chaincode
按 v1 规则保存首笔 manifest 摘要，TypeScript Gateway 负责提交、查询和把链上摘要
回灌 MoonBit CLI。它与根 `package.json` 均被 `moon.mod` 和包内容门禁排除，
不会把 Go/Node 依赖带入 Mooncakes 库包。

## Tracking Rule

Update this file when a top-level directory, package boundary, or reusable tool changes.

## Repository Surface Rule

Root-level local agent folders (`.cursor/`, `.workbuddy/`) and legacy generated
course-report outputs (`report/`) are intentionally excluded from the public
repository surface. The authoritative project report is
`docs/report/DEVELOPMENT_REPORT.md`; contest application materials stay under
`docs/`.
