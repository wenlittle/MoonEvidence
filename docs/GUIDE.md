# MoonEvidence 用户指南

MoonEvidence 将文件目录转换成可复核证据包，并在交付、归档或上链后重新检查内容。下面的任务都从仓库根目录开始，命令使用真实样例和稳定接口。

## 开始之前

日常使用只需要 MoonBit 和 Node.js。浏览器工作台、native CLI 和 Fabric 锚定按需增加环境。

| 工具 | 用途 | 要求 |
| --- | --- | --- |
| MoonBit | 构建库和 CLI | 当前项目基线为 `moon 0.1.20260529` |
| Node.js | 运行 JS CLI、Fabric Gateway 和网页工具 | CLI/Gateway 需要 20+，完整工作台需要 22+ |
| Python | 启动轻量静态页面 | 任意带 `http.server` 的 Python 3，可选 |
| C 编译器 | 构建 native CLI | Windows 可使用 MSVC，可选 |
| Docker、Go、Fabric samples | 运行真实账本锚定 | 仅 Fabric 流程需要 |

先确认工具并构建默认 JS CLI：

```powershell
moon version
node --version
moon build --target js

$cli = "_build/js/debug/build/src/cmd/main/main.js"
node $cli --version
# moon-evidence 0.5.1
```

bash 或 WSL 使用同一产物：

```bash
moon build --target js
cli="_build/js/debug/build/src/cmd/main/main.js"
node "$cli" --version
```

Windows native 构建需要先加载 MSVC 环境。构建完成后的入口为 `_build/native/debug/build/src/cmd/main/main.exe`。完整环境说明见 [ENVIRONMENT.md](ENVIRONMENT.md)。

## 选择入口

| 任务 | 推荐入口 | 特点 |
| --- | --- | --- |
| 立即体验 | [在线工作台](https://wenlittle.github.io/MoonEvidence/#workbench/verify) | 内置完好包和篡改包，无需安装 |
| 批量处理目录 | CLI | 适合脚本、CI 和归档流水线 |
| 嵌入 MoonBit 项目 | MoonBit 库 | 直接传入 manifest 文本和文件字节 |
| 内网浏览器复核 | `demo/web/` | 纯静态页面，文件留在浏览器 |
| 交互式展示 | `showcase/` | 首页、工作台、篡改传播动画 |
| 共享账本锚定 | Fabric Gateway | 本地验证后提交规范摘要 |

CLI 是本指南的默认入口。浏览器和 Fabric 流程消费同一套 MoonBit 验证结果。

## 创建证据包

### 准备文件

源目录可以包含任意层级的常规文件：

```text
delivery/
├── outputs/
│   ├── report.pdf
│   └── summary.json
└── meta/
    └── generation.json
```

`pack` 会复制目录内容，并创建新的证据包：

```text
delivery-evidence-pack/
├── manifest.json
└── files/
    ├── outputs/
    └── meta/
```

### PowerShell

下面的命令使用仓库样例创建一份临时证据包：

```powershell
$pack = Join-Path $env:TEMP "moon-evidence-guide-pack"
Remove-Item -LiteralPath $pack -Recurse -Force -ErrorAction SilentlyContinue

node $cli pack examples/valid-pack/files `
  -o $pack `
  --subject-id review-001 `
  --subject-type dataset `
  --json
```

### bash 或 WSL

```bash
workspace="$(mktemp -d)"
pack="$workspace/moon-evidence-guide-pack"

node "$cli" pack examples/valid-pack/files \
  -o "$pack" \
  --subject-id review-001 \
  --subject-type dataset \
  --json
```

成功结果使用固定 schema：

```json
{
  "algorithm": "sha256",
  "files_total": 2,
  "manifest_digest": "sha256:<64 lowercase hex>",
  "manifest_path": ".../moon-evidence-guide-pack/manifest.json",
  "merkle_root": "sha256:<64 lowercase hex>",
  "ok": true,
  "pack_path": ".../moon-evidence-guide-pack",
  "schema": "moon-evidence-pack-result/v1",
  "subject": { "id": "review-001", "type": "dataset" },
  "version": { "id": "v1", "parent": null }
}
```

常用选项：

| 选项 | 作用 | 默认值 |
| --- | --- | --- |
| `--subject-id` | 证据对象标识 | 源目录名称 |
| `--subject-type` | 对象类别 | `generic` |
| `--algorithm` | 文件、Merkle 根和清单摘要算法 | `sha256`，也支持 `sha512` |
| `--version-id` | 当前版本标识 | `v1` |
| `--version-parent` | 上一版本标识 | 空 |
| `-o`、`--output` | 新证据包目录 | `<source>-evidence-pack` |
| `--json` | 输出机器可读结果 | 关闭 |

输出目录必须是新路径。创建过程发生错误时，CLI 会清理已经生成的不完整目录。`seal` 是 `pack` 的等价命令。

## 验证证据包

### 查看结论

```powershell
node $cli verify examples/valid-pack
```

```text
verification OK
checked 2 files, 2 passed; merkle root verified; 0 errors, 0 warnings
```

`explain` 使用相同验证流程，并把每条异常展开成可读诊断：

```powershell
node $cli explain examples/tampered-pack
```

```text
verification FAILED
  [E2003] files/a.txt: digest mismatch, expected sha256:a948... got sha256:7509...
checked 2 files, 1 passed; merkle root verified; 1 error, 0 warnings
```

### 读取机器结果

```powershell
node $cli verify --json examples/valid-pack
```

```json
{"findings":[],"ok":true,"stats":{"files_passed":2,"files_total":2,"merkle_checked":true}}
```

| 退出码 | 含义 | 脚本动作 |
| --- | --- | --- |
| `0` | 命令成功，或所有证据包验证通过 | 继续后续流程 |
| `1` | 验证完成，并拒绝至少一个证据包 | 读取 `findings` |
| `2` | 参数、路径、权限或 IO 错误 | 修复输入或运行环境 |

### 批量验证

```powershell
node $cli verify examples/valid-pack examples/tampered-pack
```

CLI 会逐包输出结论，并在末尾汇总通过数和失败数。任意证据包被拒绝时，整次命令返回退出码 `1`。

### 重复验证

可信本地环境可以保存摘要缓存，减少重复读取：

```powershell
$cache = Join-Path $env:TEMP "moon-evidence-guide-cache"
New-Item -ItemType Directory -Force $cache | Out-Null

node $cli verify --incremental $cache examples/valid-pack
# incremental: 2 rehashed, 0 skipped

node $cli verify --incremental $cache examples/valid-pack
# incremental: 0 rehashed, 2 skipped
```

增量缓存属于受信任的本地性能状态。外部交付、上链提交、缓存权限变化和正式验收使用完整 `verify`，重新读取全部文件。

## 定位篡改

### 修改一个字节

PowerShell：

```powershell
$lab = Join-Path $env:TEMP "moon-evidence-tamper-lab"
Remove-Item -LiteralPath $lab -Recurse -Force -ErrorAction SilentlyContinue
Copy-Item -LiteralPath examples/valid-pack -Destination $lab -Recurse

$target = Join-Path $lab "files/a.txt"
$bytes = [IO.File]::ReadAllBytes($target)
$bytes[0] = $bytes[0] -bxor 1
[IO.File]::WriteAllBytes($target, $bytes)

node $cli explain $lab
```

bash 或 WSL：

```bash
lab="$(mktemp -d)/pack"
cp -R examples/valid-pack "$lab"

node -e 'const fs=require("fs");const p=process.argv[1];const b=fs.readFileSync(p);b[0]^=1;fs.writeFileSync(p,b)' \
  "$lab/files/a.txt"

node "$cli" explain "$lab"
```

文件长度保持不变，`E2003` 仍会指出内容摘要变化。验证器会继续检查剩余文件，并在一次报告中列出全部发现。

此时 manifest 没有变化。报告中的 `merkle root verified` 表示记录在 manifest 中的文件条目仍与记录根一致，`E2003` 则表示磁盘上的当前字节已经偏离该条目。篡改实验还会重算一份候选文件条目，因此能同时展示候选 Merkle 根与原始根的分叉。

### 检查额外文件

以证据包目录运行 `verify` 时，验证器会完整扫描 `files/`。目录中出现清单未登记的文件时返回 `W1001`。警告不会直接把报告改成失败；需要封闭文件清单的归档流程把该警告升级为拒绝策略。

完整扫描是 `W1001` 可信的前提。`files/` 缺失、不是目录、无法读取，或扫描触及深度和文件数量上限时，命令以退出码 `2` 中止。单个已登记文件确实不存在时，验证已经获得完整结论，返回 `E2003` 和退出码 `1`；路径存在但无法读取时返回 `E5002` 和退出码 `2`。

`create` 保留“原目录就地生成 manifest”的兼容模式，复核时传入它输出的 `manifest.json` 路径。需要归档、移交或上链前封装时使用 `pack`，它会生成标准的 `manifest.json + files/` 自包含目录，并启用上述完整清单检查。

### 对照历史锚点

`inspect` 输出当前清单的规范摘要：

```powershell
$metadata = node $cli inspect --json examples/valid-pack | ConvertFrom-Json
$metadata.manifest_digest
# sha256:16bbf1e91de3acfb8bd9091233926b454045c6d96c24327baec20272af583f1e
```

将归档系统或账本保存的摘要传回验证器：

```powershell
node $cli verify --json `
  --expected-manifest-digest $metadata.manifest_digest `
  examples/valid-pack
```

当前清单和历史摘要不一致时，报告返回 `E2004`。这条检查可以识别文件和清单被一起重新生成后的历史变化。

| 结果 | 表示的变化 |
| --- | --- |
| `E2003` | 当前文件字节和 manifest 登记值不同 |
| `E2004` | 当前 manifest 和外部历史摘要不同 |
| `E3003` | manifest 中的文件条目和 Merkle 根不同 |
| `W1001` | 证据包包含未登记文件 |

完整错误码定义见[证据包规范](spec/EVIDENCE_PACK_SPEC.md#diagnostics)。

## 接入脚本

### PowerShell

```powershell
$json = node $cli verify --json examples/valid-pack
$status = $LASTEXITCODE

if ($status -eq 2) {
  Write-Error $json
  exit $status
}

$report = $json | ConvertFrom-Json

if ($status -eq 0 -and $report.ok) {
  Write-Host "证据包通过，共检查 $($report.stats.files_total) 个文件"
} else {
  $report.findings | Format-Table code, path, message
  exit $status
}
```

### bash 或 WSL

下面的示例使用 `jq` 读取结果：

```bash
report="$(node "$cli" verify --json examples/valid-pack)"
status=$?

if [ "$status" -eq 2 ]; then
  printf '%s\n' "$report" >&2
  exit "$status"
elif [ "$status" -eq 0 ] && [ "$(jq -r '.ok' <<<"$report")" = "true" ]; then
  jq -r '"evidence passed: \(.stats.files_total) files"' <<<"$report"
else
  jq -r '.findings[] | "[\(.code)] \(.path): \(.message)"' <<<"$report"
  exit "$status"
fi
```

自动化程序先检查进程退出码。`pack`、`create` 和 `inspect` 的成功回执再检查 `schema` 与 `ok`；单包 `verify --json` 检查 `ok`、`findings[].code` 和 `stats`，其 `VerifyReport` 没有 `schema` 字段。退出码 `2` 的 verify 预检信息按文本处理。人类可读的 `message` 允许随诊断质量改进，不作为稳定字段。

MoonBit 应用可以直接调用 `@create.create_manifest` 和 `@verify.verify_manifest`。可编译的最小示例见项目 [README](../README.md#moonbit-接入)，完整接口以 `pkg.generated.mbti` 为准。

## 浏览器复核

### 在线工作台

[验证工作台](https://wenlittle.github.io/MoonEvidence/#workbench/verify) 可以加载内置样例和本地证据包。[篡改实验](https://wenlittle.github.io/MoonEvidence/#workbench/tamper) 会同时展示当前字节产生的候选文件摘要、候选 Merkle 根和针对原 manifest 的 `E2003` 结论。

计算发生在浏览器 Web Worker 中，本地文件不会上传到服务端。

### 本地工作台

完整工作台使用 Node.js 22 或更高版本：

```powershell
npm --prefix showcase ci
npm --prefix showcase run dev
```

Vite 会打印本地地址。生产构建使用：

```powershell
npm --prefix showcase run build
npm --prefix showcase run preview -- --host 127.0.0.1 --port 4173
```

### 轻量静态页面

`demo/web/` 提供拖拽验证页和 Merkle 篡改实验页。先构建 release 浏览器产物，再从仓库根目录启动 HTTP 服务：

```powershell
moon build --target js --release src/api
python -m http.server 8000
```

打开：

- `http://localhost:8000/demo/web/index.html`
- `http://localhost:8000/demo/web/tamper-lab.html`

页面通过 ES module 加载 `_build/js/release/build/src/api/api.js`，因此需要 HTTP 服务。完整说明见 [`demo/README.md`](../demo/README.md)。

## Fabric 锚定

标准 Fabric 流程先在本地完成验证，再提交规范摘要。完整清单和文件留在链下，交易回执保留交易 ID、区块号和 Fabric 提交状态。账本记录证明某个 Fabric 身份提交了该摘要；本地验证结论由 `anchor-pack` 流程和 MoonEvidence 报告保存。

下面的命令假定 `evidencechannel`、`moonevidence` Chaincode 和本地 Gateway profile 已准备完成。部署和身份配置见 [Fabric 集成指南](../integrations/fabric/README.md)。

### 构建适配器

```powershell
moon build --target js
npm --prefix integrations/fabric/gateway ci
npm run fabric:check
npm run fabric:test
npm run fabric:build

$gateway = "integrations/fabric/gateway/dist/src/cli.js"
$profile = "integrations/fabric/gateway/.local/org1.json"
```

### 提交摘要

`anchor-pack` 会执行 `inspect`、完整 `verify` 和链上提交：

```powershell
$anchor = node $gateway anchor-pack examples/valid-pack `
  --profile $profile `
  --moon-cli $cli `
  --json | ConvertFrom-Json

$digest = $anchor.receipt.manifest_digest
$anchor.receipt.commit
```

成功回执包含 `status_code: 0`、区块号和 `successful: true`。Fabric 账本记录中的验证状态为 `VALID`。

### 查询复核

```powershell
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

`verify-anchor` 查询账本记录，并把原始摘要回传给 MoonEvidence。文件变化触发 `E2003`；围绕变化文件重新生成 manifest 后，对照原始锚点触发 `E2004`。

WSL 使用相同参数，将 PowerShell 续行符改为 `\`，并在 profile 中填写 Linux 证书路径。Windows Node.js 也可以通过 `\\wsl.localhost\<distribution>\...` 读取 WSL 中的 test-network 身份文件。

2026-07-12 的双组织实验使用 `v0.5.1` 发布压缩包，记录了 block 8 `VALID` 首笔交易、Org1/Org2 一致查询、重复提交和两类篡改回灌结果。完整产物位于 [Fabric 发布 E2E 记录](records/fabric-e2e/2026-07-12-v0.5.1/)。

## 版本记录

创建证据包时可以登记当前版本和父版本：

```powershell
node $cli pack .\release-v2 `
  -o .\release-v2-pack `
  --subject-id dataset-001 `
  --version-id v2 `
  --version-parent v1 `
  --json
```

多版本历史放在 `versions/version_chain.json`：

```json
[
  { "id": "v1", "parent": null },
  { "id": "v2", "parent": "v1" },
  { "id": "v3", "parent": "v2" }
]
```

CLI 在验证证据包时自动读取该文件。验证规则包括唯一根节点、父引用可达、无环和无分叉。`examples/valid-pack` 提供可直接运行的单节点样例。

每个证据包仍然独立保存当前版本内容。版本链负责描述发布顺序，外部锚点负责固定每次发布的清单摘要。

## 故障排查

| 现象 | 检查项 | 处理方式 |
| --- | --- | --- |
| 找不到 `moon` | MoonBit 未进入 `PATH` | 重启终端，并按 [ENVIRONMENT.md](ENVIRONMENT.md) 检查官方安装目录是否进入 `PATH` |
| 找不到 CLI JS | 尚未构建 debug JS 产物 | 运行 `moon build --target js` |
| native 提示没有 C 编译器 | 当前终端未加载编译环境 | Windows 使用 x64 Native Tools Prompt 或 `vcvars64.bat` |
| `pack` 拒绝输出目录 | 目标路径已经存在 | 选择新目录，或确认路径后清理旧输出 |
| `E1001` | manifest 不是合法 JSON | 检查 JSON 语法和文件编码 |
| `E1002` 指向路径 | 路径含 `..`、绝对路径、反斜杠或盘符 | 使用包内 `/` 分隔的相对路径 |
| `E2003` | 文件缺失或字节变化 | 对照 `path`、期望摘要和实际摘要 |
| `E2004` | 当前 manifest 和历史摘要不同 | 核对归档版本或账本交易 |
| `W1001` | 包中存在未登记文件 | 登记文件，或从交付包移除 |
| 浏览器模块加载失败 | release API 未构建，或页面通过 `file://` 打开 | 构建 `src/api` 并从仓库根目录启动 HTTP 服务 |
| Fabric 连接失败 | profile、证书路径、TLS endpoint 或网络状态异常 | 先运行 Gateway 测试，再按集成指南检查身份配置 |

更多技术定义：[架构文档](ARCHITECTURE.md) · [证据包规范](spec/EVIDENCE_PACK_SPEC.md) · [CLI 契约](spec/CLI_MACHINE_CONTRACT.md) · [Fabric 规范](spec/FABRIC_ANCHOR_SPEC.md)
