# demo/web

本目录保存 MoonEvidence 的轻量静态复核页面。

| 文件 | 用途 |
| --- | --- |
| `index.html` | 拖拽验证 manifest 和文件，显示结构化诊断 |
| `tamper-lab.html` | 修改一个文件，展示摘要和 Merkle 路径变化 |

两张页面都引用仓库根目录下的 release API：

```text
_build/js/release/build/src/api/api.js
```

构建、启动和操作步骤统一维护在 [`demo/README.md`](../README.md#本地启动)。页面需要通过 HTTP 访问。

修改页面或浏览器 API 后，运行：

```powershell
moon build --target js --release src/api
node tools/smoke-api.mjs
```
