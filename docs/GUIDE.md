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

MoonEvidence 是**验证方**，不规定打包方用什么语言。仓库内 `tools/gen-fixtures.mjs` 是一个独立的 Node 参考实现，可作为生成端的样例（计算文件摘要、组装 canonical 条目、计算 Merkle 根）。

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

**背景**：要把"某份资料在某时刻的状态"锚定到链上。最佳实践不是把文件上链，而是把 **manifest 的规范摘要**上链——MoonEvidence 提供这条链路的两端。

### 1. 计算要上链的锚点

manifest 本身先做 RFC 8785 规范化再摘要，所以格式化差异（空格、键序）不影响锚点值。生成端可用任何实现了 RFC 8785 的工具计算；库内入口是 `@canonjson.canonicalize` + `@digest.sha256_hex`。

### 2. 取证时对比链上记录值

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

### 3. 版本链：多次发布的线性历史

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

更多：[架构说明](ARCHITECTURE.md) · [证据包规范](spec/EVIDENCE_PACK_SPEC.md) · [浏览器 demo](../demo/web/index.html)
