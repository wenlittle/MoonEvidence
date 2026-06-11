# MoonEvidence 5 分钟演示脚本

> 目标：让评委在 5 分钟内看到"承诺 → 篡改 → 抓住 → 解释"的完整闭环，外加三后端与浏览器亮点。
> 前置（演示前完成，不计时）：`moon build --target js`；起一个静态服务器 `python -m http.server 8765`；浏览器开好 `http://localhost:8765/demo/web/` 待命。

## 第 0 分钟 · 开场一句话

> "MoonEvidence 验证一组文件是否和当初承诺的完全一致——纯 MoonBit 写的验证核心，同一套代码跑在 CLI、CI 和浏览器里。"

## 第 1 分钟 · 完好的包验证通过

```powershell
$cli = "_build/js/debug/build/src/cmd/main/main.js"

# 看一眼包的结构：manifest 承诺了每个文件的摘要 + Merkle 根
Get-Content examples/valid-pack/manifest.json

node $cli verify examples/valid-pack
# verification OK ... 退出码 0
```

讲解点：manifest 是唯一事实来源；报告最后一行的统计（2 files, 2 passed; merkle root verified）。

## 第 2 分钟 · 现场篡改一个字节

```powershell
Copy-Item -Recurse examples/valid-pack $env:TEMP/live-demo -Force
[IO.File]::AppendAllText("$env:TEMP/live-demo/files/a.txt", "x")   # 只追加 1 个字节

node $cli explain $env:TEMP/live-demo
```

预期输出（强调逐条诊断 + 期望/实际摘要都给全）：

```text
verification FAILED
  [E2003] files/a.txt: digest mismatch, expected sha256:a948904f.. got sha256:9436accd..
checked 2 files, 1 passed; merkle root verified; 1 error, 0 warnings
```

讲解点：错误码是冻结契约（E1xxx 模型 / E2xxx 摘要 / E3xxx Merkle / E4xxx 版本链 / E5xxx IO / W1xxx 警告）；报告完备式输出，所有问题一次列全。

```powershell
node $cli verify --json $env:TEMP/live-demo   # 给脚本消费的规范 JSON 报告
Remove-Item -Recurse -Force $env:TEMP/live-demo
```

## 第 3 分钟 · 同一核心在浏览器里跑

切到已开好的 demo 页面：

1. 点「选择 evidence pack 目录」→ 选 `examples/tampered-pack` → 红色 FAILED 横幅 + E2003 表格，**与 CLI 输出逐字节一致**（展开"explain 原文"对照）
2. 强调：文件没有离开本机——纯核心编译成 esm bundle 在浏览器本地算
3. （可选）粘贴模式：把 manifest 里 merkle_root 改一位 → E3003

讲解点：这就是 MoonBit 多后端的实际收益——`src/api` 适配器 + 零 IO 纯核心，CI 里 native/wasm-gc/js 三后端矩阵钉死跨端一致性。

## 第 4 分钟 · 质量底座（一屏讲完）

```powershell
moon test --target wasm-gc,js    # 155/155 双后端
powershell -ExecutionPolicy Bypass -File tools/cli-test.ps1 -Target js   # 22/22 黑盒
```

讲解点（不必全跑，指着 CI 页面/README 说）：

- 10 包篡改矩阵：每个错误码族一个 pack，由**独立 Node 参考实现**生成，CI 防腐化校验
- property 测试经变异验证；SHA-256 过 NIST 向量、canonjson 过 RFC 8785 Appendix B 向量
- 性能：~26 µs/文件，10k 文件 manifest 全量验证 280 ms（js 后端）

## 第 5 分钟 · 收尾

> "上链存证、数据集归档、AI 产物审计，链上锚点只需要 manifest 的规范摘要——验证这件事，MoonEvidence 把它做成了 MoonBit 生态里可复用的基础件。六个纯包各自独立可用，欢迎拆着用。"

指一下 `docs/GUIDE.md`（三场景）与 `README.zh.md`（架构图 + API 速览）作为延伸阅读。

---

## 彩排核对清单

- [ ] `moon build --target js` 已构建（`$cli` 路径存在）
- [ ] 静态服务器已起、demo 页面已打开过一次（esm bundle 已被浏览器缓存）
- [ ] 终端字体够大；`$cli` 变量已设
- [ ] 临时目录 `$env:TEMP/live-demo` 不存在残留
- [ ] 计时一遍 ≤ 5 分钟（2026-06-11 彩排实测：全部命令含 155 双后端测试与 22 黑盒仅 **5.7 秒**，时间几乎全部留给讲解，余量极大）
