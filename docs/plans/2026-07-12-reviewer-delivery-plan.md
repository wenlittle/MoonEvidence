# MoonEvidence 评审交付计划

> 状态：执行中
>
> 建立日期：2026-07-12
>
> 目标版本：v0.5.1
>
> 收口原则：只处理公开交付一致性、首次使用路径和可复核展示；不继续扩展密码学原语、一般性测试数量或区块链类型。

## 完成定义

这一轮在以下条件同时成立时结束：

1. GitHub、GitLink、Mooncakes、CLI、Changelog 和公开页面指向同一版本。
2. 评审可以通过网页、CLI 和 MoonBit 示例完成一次真实验证。
3. CI 持续保护首页进入、正常验证、篡改拒绝和移动端布局。
4. Fabric 实验拥有可直接阅读的展示入口，并以真实发布资产完成复核。
5. 所有发布产物都绑定提交、版本和 SHA-256 校验值。

## 第一阶段：交付一致性

- [x] 将模块版本和 CLI 版本升级到 `0.5.1`。
- [x] 新增 `0.5.1` Changelog，准确归纳 `v0.5.0..HEAD` 的产品变更。
- [x] 修正 Showcase 和演示材料中的测试数字漂移。
- [x] 扩展 `tools/check-metrics.mjs`，覆盖 Showcase 和当前公开材料。
- [x] 移除 GitLink 优先展示的兼容跳转页 `README.zh.md`，同步文档索引和包内容门禁。
- [x] 新增跨平台干净消费者门禁 `tools/smoke-mooncakes-consumer.mjs`，可固定安装任意已发布版本并调用公开 API。
- [x] 发布后在干净临时目录固定安装 `0.5.1`，确认创建、验证和篡改拒绝 `2/2` 通过。
- [x] 发布 `v0.5.1` Git tag、GitHub Release、GitLink tag 和 Mooncakes 包。

验收条件：

- `moon info && git diff --exit-code -- 'src/**/*.mbti'` 无差异。
- `node tools/check-metrics.mjs` 和 `node tools/check-package-contents.mjs` 通过。
- Mooncakes 可查询 `0.5.1`，干净消费者运行成功。
- 两个公开仓库的 `main`、`v0.5.1` 和 Release 提交一致。

## 第二阶段：首次使用

- [x] 新增可直接运行的 `examples/quickstart` MoonBit 示例。
- [x] 示例覆盖创建、验证和篡改拒绝三个观察点。
- [x] 为 Release 生成经过 68 项黑盒验证的完整 JS CLI 发行物，并提供 Windows/Unix 启动器。
- [x] 为 Mooncakes 包和 CLI 发行物生成 SHA-256 校验文件。
- [x] 增加不超过 5 条的 Playwright 评审路径测试。
- [x] 将评审路径测试接入 Pages CI，并在失败时保留截图和 trace。

验收条件：

- 一条命令运行 quickstart。
- Release 下载后的 CLI 不依赖仓库源码和 MoonBit 工具链。
- Playwright 覆盖首页加载、工作台入口、正常验证、篡改拒绝和移动端无横向溢出。

## 第三阶段：评奖展示

- [x] 增加独立的“实链记录”页面，回放已有双组织 Fabric 实验。
- [x] 页面展示网络版本、组织、交易、区块、跨组织查询和摘要回传结果。
- [x] 使用确定性生成的 `v0.5.1` Release 压缩包创建证据包并完成 Fabric 提交、双组织查询和回灌验证。
- [x] 保存脱敏后的命令、交易回执、区块信息、摘要、制品哈希和校验结果。
- [x] 设置 GitHub 仓库简介、主页和 topics，提交 1280 x 640 社交预览图源文件。
- [ ] 在已登录的 GitHub 网页中上传自定义社交预览图。
- [ ] 在 GitLink 支持范围内同步简介、主页和 topics。

验收条件：

- 页面明确标注为已完成的真实网络实验记录，不模拟实时链上状态。
- 第三方可以从 Release 下载同一资产，复算摘要并与记录对照。
- 仓库链接分享时能够显示 MoonEvidence 品牌和项目定位。

## 最终发布

- [x] 运行 MoonBit 四后端、CLI、浏览器 API、Showcase、Fabric、随机差分和故障注入门禁。
- [x] 更新 `RESULTS_LOG.md`、验收清单、项目索引、结构树和开发报告中的最终基线。
- [x] 检查 Git 工作区只包含本轮预期变更。
- [x] 分阶段提交并同步 GitHub、GitLink。
- [x] 创建不可移动的 `v0.5.1` 标签并核对四个发布产物摘要。
- [x] 核验 GitHub Actions、GitHub Pages、GitHub Release 和 Mooncakes 的公开结果。

## 停止清单

- 不新增与本轮交付无关的算法、包和协议。
- 不用测试数量替代实际用户路径。
- 不重做已经稳定的首页视觉体系。
- 不建设生产级 Fabric CA、密钥托管、容灾和长期在线网络。
- 不增加重复报告，不复制 README 形成新的漂移源。
- 不制造 star、issue、用户评价或实时链上状态。
