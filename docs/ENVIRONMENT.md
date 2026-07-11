# MoonEvidence 环境准备

MoonEvidence 的默认体验使用 MoonBit 和 Node.js。native、网页开发和
Fabric 集成按任务增加工具，不影响 Mooncakes 库的基础使用。

## 基础环境

| 工具 | 用途 | 建议版本 |
| --- | --- | --- |
| Git | 获取仓库和版本记录 | 2.40+ |
| MoonBit CLI | 检查、构建、测试和打包 | 官方当前稳定版 |
| Node.js | 运行 JS CLI 和参考检查 | 20+；Showcase 使用 22+ |
| PowerShell 或 bash | 执行本地命令和黑盒测试 | 当前稳定版 |
| Python | 启动轻量静态页面 | Python 3，可选 |

安装后从仓库根目录检查：

```powershell
git --version
moon version --all
node --version
moon update
moon check --deny-warn --target all
moon build --target js
```

JS CLI 位于：

```text
_build/js/debug/build/src/cmd/main/main.js
```

MoonBit 官方安装入口：

- [MoonBit 下载](https://www.moonbitlang.com/download/)
- [MoonBit CLI 文档](https://docs.moonbitlang.com/en/latest/toolchain/moon/)

终端找不到 `moon` 时，重新打开终端并确认 MoonBit 安装目录已经进入用户
`PATH`。使用 `Get-Command moon` 或 `which moon` 查看当前解析结果。

## Native 后端

native 构建需要 C 编译器：

| 平台 | 编译环境 | 检查命令 |
| --- | --- | --- |
| Windows | Visual Studio 2022 Build Tools，C++ 工作负载 | 在 x64 Native Tools Prompt 中运行 `cl` |
| Linux / WSL | GCC 或 Clang | `cc --version` |
| macOS | Xcode Command Line Tools | `clang --version` |

Windows 打开 Visual Studio 提供的 x64 Developer PowerShell 或 x64 Native
Tools Command Prompt 后运行：

```powershell
moon build --target native
moon test --deny-warn --target native
```

产物位于 `_build/native/debug/build/src/cmd/main/main.exe`。CI 在 Ubuntu/GCC
上重复 native 构建和测试，Windows/MSVC 结果作为第二个工具链记录。

## 浏览器工作台

Showcase 使用 Node.js 22 和 npm：

```powershell
npm --prefix showcase ci
npm --prefix showcase run check
npm --prefix showcase run dev
```

生产构建：

```powershell
npm --prefix showcase run build
npm --prefix showcase run preview -- --host 127.0.0.1 --port 4173
```

轻量页面只需要先构建发布版 MoonBit API，再从仓库根目录启动任意静态
HTTP 服务：

```powershell
moon build --target js --release src/api
python -m http.server 8000
```

## Fabric 集成

真实 Fabric 流程增加：

- Go，版本以 `integrations/fabric/chaincode-go/go.mod` 为准；
- Docker Engine 或 Docker Desktop；
- Hyperledger Fabric samples test-network；
- Node.js 22；
- 两个组织的本地证书、私钥和 TLS 连接信息。

先运行离线适配器检查：

```powershell
npm --prefix integrations/fabric/gateway ci
npm run fabric:check
npm run fabric:test
npm run fabric:build

Push-Location integrations/fabric/chaincode-go
go vet ./...
go test ./... -cover
Pop-Location
```

Ubuntu required CI 额外执行 `go test -race -cover ./...`。双组织网络部署、
profile 字段和提交命令见 [Fabric 集成指南](../integrations/fabric/README.md)。

## 环境自检

Windows 可运行只读检查脚本：

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\env-check.ps1
```

脚本检查工具可用性和 Mooncakes 访问，不写入项目源码。

## 已验证基线

2026-07-11 的发布记录包含：

| 环境 | 结果 |
| --- | --- |
| Windows / MoonBit 2026-05-29 / MSVC 19.44 | native `347/347` |
| Windows / Node.js 24 | JS CLI、浏览器 API、Showcase 和 Gateway 通过 |
| required CI / Ubuntu | wasm、wasm-gc、js、native 和 Go race 门禁通过 |
| WSL / Fabric v3.1.4 | 双组织提交、查询、重复和摘要回传完成 |

精确版本、命令和时间记录在 [RESULTS_LOG.md](records/RESULTS_LOG.md)。

## 凭据边界

Fabric 凭据和 Gateway profile 放在
`integrations/fabric/gateway/.local/`。该目录已被 Git 忽略。仓库中的
`profiles/test-network-org1.example.json` 只提供字段形状，不包含可用身份。

私钥、证书副本、访问令牌和本机绝对路径不进入提交、证据包或错误日志。
