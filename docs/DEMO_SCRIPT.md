# MoonEvidence 5 分钟演示脚本

> 目标：让评委在 5 分钟内看到“承诺 → 篡改 → 抓住 → 解释”的完整闭环，并现场体验滚动叙事首页与真实证据工作台。
> 前置（演示前完成，不计时）：根目录执行 `moon build --target js src/cmd/main`；`showcase/` 目录执行 `npm ci`、`npm run build`、`npm run preview`；浏览器开好 `http://localhost:4173/`；Fabric 环节使用已保存的双组织交易记录，现场网络可用时再执行查询命令。

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

## 第 3 分钟 · 滚动叙事首页与证据工作台

切到已开好的网页体验（`http://localhost:4173/`）：

1. **沉浸首屏**：一句话说明 MoonEvidence 在提交、归档或上链前完成文件可信校验，点击“了解原理”。
2. **四章叙事**：滚动展示材料进入、形成凭证、单字节修改导致结果分叉、准确定位并拒绝不一致材料。
3. **真实工作台**：在结尾点击“试试篡改实验”，直接进入 `#workbench/tamper`；选择 `files/a.txt` 并点击“篡改一个字节”。
4. **现场结果**：指出“已改变”的文件节点、证据根不匹配和“篡改已被发现”结论同步出现；展开“查看技术详情”可继续复核 `E2003` 原始诊断。
5. 切换到“验证证据包”，先运行完好样例，再运行篡改样例，展示“结论优先、技术细节按需展开”的完整路径。
6. 强调：工作台中的摘要、根、签名和错误码全部由 Web Worker 调用编译后的 MoonBit API 现场计算，输入就是仓库的 `examples/valid-pack`；文件没有上传。

讲解点：这是 MoonBit 多后端的直接收益——`src/api` 适配器与零 IO 纯核心让同一语义进入 CLI、CI 和浏览器。React/Three.js 负责交互与叙事，可信计算仍由 MoonBit 完成。

## 第 4 分钟 · 真实 Fabric 锚定 + 质量底座

先打开 `docs/records/fabric-e2e/2026-07-11/transactions.json`，指出首笔交易：

- `VALID`，第 6 区块；
- Org1/Org2 查询记录完全一致；
- Org2 重复提交保留首笔 anchor 交易 ID；
- 链上摘要回灌后，改文件触发 `E2003`，重建 manifest 触发 `E2004`。

现场网络已启动时只跑查询，不把部署过程塞进 5 分钟：

```powershell
node integrations/fabric/gateway/dist/src/cli.js query `
  --profile integrations/fabric/gateway/.local/org1.json `
  --manifest-digest sha256:16bbf1e91de3acfb8bd9091233926b454045c6d96c24327baec20272af583f1e `
  --json
```

最后用一屏 CI/本地基线收口：

```powershell
moon test --target wasm-gc,js    # 347/347 双后端
powershell -ExecutionPolicy Bypass -File tools/cli-test.ps1 -Target js   # 62/62 黑盒
bash ./tools/cli-test.sh js      # 62/62 bash 对等黑盒
npm run fabric:test              # Gateway 19/19
```

讲解点（不必全跑，指着 CI 页面/README 说）：

- 10 包篡改矩阵：每个错误码族一个 pack，由**独立 Node 参考实现**生成，CI 防腐化校验
- property 测试经变异验证；SHA-256 过 NIST 向量、canonjson 过 RFC 8785 Appendix B 向量、Ed25519 过 RFC 8032 KAT
- 性能：~26 µs/文件，10k 文件 manifest 全量验证 280 ms（js 后端）

## 第 5 分钟 · 收尾

> "上链存证、数据集归档、AI 产物审计，MoonEvidence 先用 MoonBit 验证本地证据，再把唯一的规范摘要锚定到 Fabric，最后把链上值回灌复核。证据语义只有一套，CLI、浏览器和账本共用同一个可信核心。"

指一下 `docs/GUIDE.md`（完整操作路径）与 `README.md`（项目首页、架构和质量证据）作为延伸阅读。

---

## 彩排核对清单

- [ ] `showcase/` 已执行 `npm ci`、`npm run build`，`npm run preview` 正在运行
- [ ] `moon build --target js src/cmd/main` 已构建（`$cli` 路径存在）
- [ ] `npm run fabric:build` 已执行；现场查询时本地 Fabric 网络和 `.local` profile 可用
- [ ] `docs/records/fabric-e2e/2026-07-11/transactions.json` 已提前打开，网络不可用时仍可展示完整收据
- [ ] MoonEvidence 首页已在 `http://localhost:4173/` 打开过一次（MoonBit API 与场景资源已缓存）
- [ ] 终端字体够大；`$cli` 变量已设
- [ ] 临时目录 `$env:TEMP/live-demo` 不存在残留
- [ ] 计时一遍 ≤ 5 分钟
