# MoonEvidence · 浏览器演示

两份独立的 HTML，都跑在原生浏览器里，不需要后端服务。

## demo/web/index.html · 拖拽验证

主验证页面。把 `manifest.json` 和对应文件拖进去，UI 会显示通过 / 失败，并打印
带错误码（E1001 / E2003 / E3003 等）的诊断。

适用场景：评审现场演示"我的库能验出篡改"，不需要装 MoonBit。

## demo/web/tamper-lab.html · Tamper Lab（篡改实验台）

可视化页面。把 manifest 和文件加载进来后，按钮一键随机篡改一个文件，右侧实时
展示：

- **文件清单**：被篡改的文件标红，原始 digest 与当前 digest 并列
- **Merkle 树**：完整树状图，篡改的叶子节点红、所有祖先节点橙、根不匹配时根闪红
- **诊断报告**：MoonEvidence 实际返回的错误码与诊断 message

适用场景：讲课时现场演示"为什么动一个 byte，整棵 Merkle 树会从根到叶塌掉"。

## 启动方式

两个 HTML 都依赖 MoonBit 编译出的 JS bundle：

```bash
# 在仓库根目录
moon build --target js --release src/api

# 启一个静态服务器（任选）
python -m http.server 8000
# 然后打开：
#   http://localhost:8000/demo/web/index.html         拖拽验证
#   http://localhost:8000/demo/web/tamper-lab.html    篡改实验台
```

注意：不要直接 `file://` 打开，浏览器对 ES module 的 `import()` 有 CORS 限制，
必须走 HTTP 协议。

## 产物依赖

两个页面当前引用 `_build/js/release/build/src/api/api.js`（Release 路径）。
该路径由 `moon build --target js --release src/api` 直接生成，也是 CI
中 `tools/smoke-api.mjs` 消费的同一个浏览器适配器产物。

- `verify_evidence(manifest_json, files_hex)`：核心验证入口，返回 `{ ok, report, findings, explain }`
- `compute_merkle_tree(manifest_json, files_hex)`：返回完整树（含 `levels` / `leaves_meta` / `root.recorded` / `root.actual` / `root.matches`）

只在 tamper-lab 用到第二个；index.html 用第一个就够了。
