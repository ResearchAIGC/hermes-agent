# Hermes Agent 架构图

打开 [`hermes-architecture.html`](./hermes-architecture.html) 即可查看可缩放的像素艺术架构图。

纯文本版本见 [`hermes-architecture-ascii.txt`](./hermes-architecture-ascii.txt)；可直接复制发布的小红书文案见 [`xiaohongshu-hermes-architecture.md`](./xiaohongshu-hermes-architecture.md)。

完整的从安装、配置、日常使用到二次开发、测试、部署和排障的中文实践手册见
[`hermes-agent-完全可操作实践指南.md`](./hermes-agent-完全可操作实践指南.md)。

如果电脑上已经安装官方 Desktop，请使用
[`hermes-agent-独立安全开发测试工作流.md`](./hermes-agent-独立安全开发测试工作流.md)
和 [`run-hermes-desktop-isolated.sh`](./run-hermes-desktop-isolated.sh)，它们会把源码版的
Hermes 状态、Electron 数据和运行入口与官方版分开。

1000 字符以内的精简发布版见 [`xiaohongshu-hermes-architecture-short.md`](./xiaohongshu-hermes-architecture-short.md)。

完整的一个月账号规划见 [`xiaohongshu-30day-persona-plan.md`](./xiaohongshu-30day-persona-plan.md)。

30 篇可直接修改发布的完整初稿见 [`xiaohongshu-30day-drafts.md`](./xiaohongshu-30day-drafts.md)。

图示范围：

- 入口层：CLI / TUI、Electron Desktop、Messaging Gateway、API / ACP
- 核心层：Turn Loop、Model Router、Tool Orchestrator、Policy
- 能力层：Memory + State、Skills + Plugins、Execution Tools、Automation
- 运行环境：Local、Docker、SSH、Singularity、Modal、Daytona、Vercel Sandbox

内容依据仓库根目录 `AGENTS.md`、`README.md` 与当前目录结构整理。箭头表示主要控制流，不表示所有异步事件或部署网络边界。
