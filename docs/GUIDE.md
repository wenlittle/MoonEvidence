# MoonEvidence 用户指南

本指南用三个真实场景走通 MoonEvidence 的核心工作流。所有命令都可以在本仓库根目录直接复制运行（CLI 前置条件：`moon build --target js`；浏览器 demo 前置条件：`moon build --target js --release src/api`；有 C 编译器的机器也可用 native 产物）。

```powershell
# 本指南统一使用 js 产物 + node；native 用户把命令换成可执行文件即可
moon build --target js
moon build --target js --release src/api
$cli = "_build/js/debug/build/src/cmd/main/main.js"
```

## 证据包是什么

一个证据包（evidence pack）就是一个目录：

```text
my-pack/
├── manifest.json                 # 清单：登记每个文件的路径、大小、SHA-256 摘要
├── files/                        # 被存证的文件（任意层级）
│   └── ...
└── versions/
    └── version_chain.json        # 可选：版本演进的线性历史
```

`manifest.json` 是唯一的事实来源。验证器回答一个问题：**目录里的字节和清单承诺的字节是否完全一致？** 任何偏离都会映射到一个冻结的错误码（完整表见 [README](../README.zh.md#错误码表) 与 [规范](spec/EVIDENCE_PACK_SPEC.md)）。

MoonEvidence 是**验证方**，不规定外部系统使用什么语言。日常打包可直接使用 `pack`：它复制源目录、生成 manifest，并返回可供脚本或账本适配器消费的规范摘要。仓库内 `tools/gen-fixtures.mjs` 仍作为独立 Node 参考实现，用于交叉验证而不是生产语义来源。

---

## 场景一：数据集归档存证

**背景**：课题组发布一份数据集，半年后审稿人质疑数据是否被改过。如果发布时打包成证据包，验证只需一条命令。

### 1. 验证一个完好的包

```powershell
node $cli verify examples/valid-pack
# 退出码 0；输出 verification OK
```

### 2. 看一份"被改过的数据集"长什么样

`examples/tampered-pack` 与 valid-pack 结构相同，但 `files/a.txt` 的内容被改动过：

```powershell
node $cli explain examples/tampered-pack
```

```text
verification FAILED
  [E2003] files/a.txt: digest mismatch, expected sha256:a948904f.. got sha256:7509e5bd..
checked 2 files, 1 passed; merkle root verified; 1 error, 0 warnings
```

报告是**完备式**的（不是遇错即停）：所有文件的问题一次列全，修复一轮即可。

### 3. 脚本化消费

```powershell
node $cli verify --json examples/tampered-pack
# {"findings":[{"code":"E2003",...}],"ok":false,"stats":{...}}
# 退出码：0 通过 / 1 失败 / 2 用法或 IO 错误
```

JSON 报告是规范化 JSON（RFC 8785 键序），同一验证结果的报告字节恒定——报告本身也可以被摘要、被存证。

---

## 场景二：AI 产物审计

**背景**：团队交付一批模型生成产物（图像、文本、权重），需要向客户证明"交付之后没人动过"，包括生成参数等元数据。

### 1. 打包思路

把产物与元数据都放进 `files/`，让 manifest 为每个文件作证：

```text
ai-delivery/
├── manifest.json
└── files/
    ├── outputs/sample-001.png
    ├── outputs/sample-002.png
    └── meta/generation-params.json   # 模型、种子、提示词……同样被摘要锁定
```

`subject` 字段标明被存证对象（`"type": "dataset"` 等任意词汇均可，详见规范）。

### 2. 现场篡改演示（可在本仓库实际运行）

```powershell
# 复制一份完好的包，改动一个字节，再验证
Copy-Item -Recurse examples/valid-pack $env:TEMP/audit-demo -Force
[IO.File]::AppendAllText("$env:TEMP/audit-demo/files/a.txt", "x")
node $cli explain $env:TEMP/audit-demo
# [E2003] files/a.txt: digest mismatch ...  —— 单字节篡改即被抓住
Remove-Item -Recurse -Force $env:TEMP/audit-demo
```

### 3. 浏览器端复核（审计方无需安装任何东西）

审计方拿到包后，打开 `demo/web/` 页面（任何静态托管均可），选择包目录——验证在浏览器本地完成，文件不上传第三方。结论与 CLI 逐字节一致。

### 4. 警告语义

如果包里出现 manifest 没登记的文件，报告给出 `W1001` 警告但不判失败——"多出来的东西"与"承诺的东西被改"是两种风险等级，由审计策略自行决定是否接受。

---

## 场景三：上链前校验与版本锚点

**背景**：要把某份资料的确定状态锚定到共享账本。文件、路径和完整 manifest 留在本地，链上只保存 **manifest 的规范摘要**。MoonEvidence 已提供从本地打包、验证、Fabric 提交、双组织查询到摘要回灌复核的完整路径。

### 1. 一条命令打包并得到锚点

```powershell
node $cli pack .\my-files -o .\my-pack --subject-id dataset-001 --json
node $cli inspect --json .\my-pack
node $cli verify --json .\my-pack
```

manifest 会先按 RFC 8785 规范化再摘要，因此空格和键序不改变锚点。`inspect` 只读取并解释 manifest；提交前仍必须运行 `verify` 检查真实文件字节。`anchor-pack` 会自动执行这两个步骤。

### 2. 提交到 Hyperledger Fabric

先按 [Fabric 集成指南（源码仓库）](https://github.com/wenlittle/MoonEvidence/blob/main/integrations/fabric/README.md) 部署 `moonevidence` Chaincode，并把真实连接配置放在 Git 忽略的 `.local/` 目录。然后从仓库根目录执行：

```powershell
npm --prefix integrations/fabric/gateway ci
npm run fabric:build

$gateway = "integrations/fabric/gateway/dist/src/cli.js"
$profile = "integrations/fabric/gateway/.local/org1.json"
$receipt = node $gateway anchor-pack examples/valid-pack `
  --profile $profile `
  --moon-cli $cli `
  --json | ConvertFrom-Json

$receipt.receipt.commit
# transaction_id / block_number / status_code=0 / successful=true
```

提交参数只有 `sha256:<64位小写hex>`（也兼容 SHA-512）。链上状态不包含文件、文件名、路径、逐文件摘要、Merkle 叶子、完整 manifest 或本地凭据。

### 3. 从账本查询并回灌验证

```powershell
$digest = $receipt.receipt.manifest_digest

node $gateway query `
  --profile $profile `
  --manifest-digest $digest `
  --json

node $gateway verify-anchor examples/valid-pack `
  --profile $profile `
  --manifest-digest $digest `
  --moon-cli $cli `
  --json
```

`verify-anchor` 先查询链上不可变记录，再把查询键对应的 digest 交给 MoonEvidence 的 `--expected-manifest-digest`。一次调用同时覆盖 Fabric 记录存在性和本地证据完整性。

库 API 也支持同一条回灌边界：

库 API `verify_manifest` 支持传入外部记录的摘要（例如从链上交易里读出的值）：

```moonbit
let report = @verify.verify_manifest(
  manifest_text,
  files,
  expected_manifest_digest="sha256:16bbf1e91de3acfb8bd9091233926b454045c6d96c24327baec20272af583f1e",
)
// 不一致时报告 E2004：canonical digest mismatch
```

这样一次验证同时回答三层问题：文件 ↔ manifest 一致（E2003）、manifest ↔ 链上锚点一致（E2004）、条目 ↔ Merkle 根一致（E3003）。

### 4. 两种篡改会被不同层抓住

```powershell
# 文件被改，manifest 没改：E2003
node $gateway verify-anchor examples/tampered-pack `
  --profile $profile --manifest-digest $digest --moon-cli $cli --json

# 攻击者连 manifest 一起重建：本地文件自洽，但旧链上摘要触发 E2004
Remove-Item -Recurse -Force "$env:TEMP\fabric-repacked" -ErrorAction SilentlyContinue
node $cli pack examples/tampered-pack/files `
  -o "$env:TEMP\fabric-repacked" --subject-id golden-pack --subject-type dataset
node $gateway verify-anchor "$env:TEMP\fabric-repacked" `
  --profile $profile --manifest-digest $digest --moon-cli $cli --json
```

真实双组织实验的首笔 `VALID` 交易、区块号、双组织查询、重复提交以及这两个拒绝结果，已脱敏保存在 [Fabric E2E 记录](https://github.com/wenlittle/MoonEvidence/tree/main/docs/records/fabric-e2e/2026-07-11)。

### 5. 版本链：多次发布的线性历史

资料多次更新、多次上链时，`versions/version_chain.json` 记录线性演进：

```json
[
  { "id": "v1", "parent": null },
  { "id": "v2", "parent": "v1" },
  { "id": "v3", "parent": "v2" }
]
```

验证器检查链的**线性性**：唯一根（E4004）、父引用可达（E4002）、无环（E4003）、不分叉（E4004）。`examples/valid-pack` 自带单节点链可直接体验；CLI 在包目录存在 `versions/version_chain.json` 时自动验证并合并进报告。

---

## 排查速查

| 现象 | 多半是 | 第一步 |
| --- | --- | --- |
| `E1001` | manifest 不是合法 JSON | 检查 JSON 语法 |
| `E1002` + `files[i].path` | 路径含 `..`、绝对路径、`\` 或盘符 | 路径必须是包内相对的 `/` 分隔形式 |
| `E2003` 大面积出现 | 文件被改、或编辑器重写了换行符（CRLF） | 用 `.gitattributes` 把包子树标成 binary |
| `E2004` | manifest 改过（哪怕只动了元数据） | 与链上/外部记录的版本核对 |
| `E3003` | manifest 条目被改（树作证条目，不作证内容） | 与 E2003 一起读：双防线各抓各的 |
| `W1001` | 包里有未登记文件 | 决定登记它或删除它 |
| 退出码 2 | 路径不存在 / 文件读失败（E5001/E5002） | 检查路径与权限 |

更多：[架构说明](ARCHITECTURE.md) · [证据包规范](spec/EVIDENCE_PACK_SPEC.md) · [Fabric 集成](https://github.com/wenlittle/MoonEvidence/tree/main/integrations/fabric) · [浏览器 demo](../demo/web/index.html)
