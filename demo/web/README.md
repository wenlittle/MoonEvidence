# MoonEvidence · 浏览器演示（demo/web）

本目录包含两个独立的纯浏览器 HTML 页面，均依赖 MoonBit 编译出的 JS bundle，不需要后端服务。完整说明见上级 [`demo/README.md`](../README.md)。

## 页面

- `index.html` — 拖拽验证主页面。把 `manifest.json` 和对应文件拖进去，UI 显示通过 / 失败，并打印带错误码（E1001 / E2003 / E3003 等）的诊断。
- `tamper-lab.html` — Tamper Lab 篡改实验台。加载 manifest 和文件后一键随机篡改，实时展示 Merkle 树（被篡改叶子红、祖先节点橙、根失配闪红）与诊断报告。

## 启动方式

```bash
# 在仓库根目录构建 JS bundle
moon build --target js

# 启一个静态服务器（任选），从仓库根目录启动
python -m http.server 8000
# 然后打开：
#   http://localhost:8000/demo/web/index.html         拖拽验证
#   http://localhost:8000/demo/web/tamper-lab.html    篡改实验台
```

注意：不要直接 `file://` 打开，浏览器对 ES module 的 `import()` 有 CORS 限制，必须走 HTTP 协议。

## 产物依赖

两个页面引用 `_build/js/release/build/src/api/api.js`（Release 路径）。当前 moon 工具链只产 debug 构建，启动前需要做一次软链接：

```bash
mkdir -p _build/js/release/build/src/api
cp _build/js/debug/build/src/api/api.js _build/js/release/build/src/api/api.js
```

或者直接把 `import()` 的路径改成 `_build/js/debug/...`。
