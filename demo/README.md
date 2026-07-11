# MoonEvidence 浏览器复核

`demo/web/` 提供两张轻量静态页面，直接加载 MoonBit 的 release JS 产物。页面可以部署到普通静态服务器，也可以在内网或本机运行。

完整产品体验位于[在线首页](https://wenlittle.github.io/MoonEvidence/)；日常验证可以直接进入[证据工作台](https://wenlittle.github.io/MoonEvidence/#workbench/verify)。

## 选择页面

| 页面 | 任务 | 入口 |
| --- | --- | --- |
| 拖拽验证 | 选择 manifest 和文件，查看通过或拒绝结果 | `demo/web/index.html` |
| 篡改实验 | 修改文件并观察摘要、Merkle 路径和诊断变化 | `demo/web/tamper-lab.html` |
| 完整工作台 | 创建、验证、证明、审计、签名和篡改实验 | `showcase/` |

轻量页面适合现场复核和静态托管。完整工作台提供更完整的操作流程和展示动画。

## 本地启动

在仓库根目录构建浏览器 API：

```powershell
moon build --target js --release src/api
```

从仓库根目录启动任意静态服务器：

```powershell
python -m http.server 8000
```

打开：

- `http://localhost:8000/demo/web/index.html`
- `http://localhost:8000/demo/web/tamper-lab.html`

页面依赖 ES module，需要通过 HTTP 访问。浏览器直接打开 `file://` 时会阻止模块加载。

## 验证文件

1. 打开拖拽验证页。
2. 选择证据包中的 `manifest.json`。
3. 选择 manifest 登记的文件。
4. 运行验证。
5. 查看结论、错误码、文件路径和摘要差异。

仓库中的 `examples/valid-pack` 会通过验证。`examples/tampered-pack` 会在 `files/a.txt` 返回 `E2003`。

## 观察篡改

1. 打开篡改实验页。
2. 加载 manifest 和对应文件。
3. 选择一个文件并触发字节修改。
4. 查看文件摘要、Merkle 根和验证结论。

页面将变化文件、受影响路径和根摘要分开显示。技术详情保留 MoonEvidence 返回的原始诊断。

## 数据边界

- 文件由浏览器本地读取。
- 验证请求在页面内调用 MoonBit JS API。
- 页面不上传文件，也不依赖后端服务。
- Fabric 锚定由独立 Gateway 完成，浏览器页面只负责本地复核。

两个页面都加载：

```text
_build/js/release/build/src/api/api.js
```

该产物由 `moon build --target js --release src/api` 生成。页面和 CI 的浏览器 smoke 使用同一个模块。

## 自查

```powershell
moon build --target js --release src/api
node tools/smoke-api.mjs
```

完整网页应用的构建和运行方式见 [`showcase/README.md`](../showcase/README.md)。CLI、脚本和 Fabric 操作见[用户指南](../docs/GUIDE.md)。
