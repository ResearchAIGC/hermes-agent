# 一张 ASCII 图看懂 Hermes Agent

AI Agent 不只是“提问 → 回答”，还要连接工具、记忆和运行环境。

```text
       +----------+  +---------+  +---------+
       | CLI/TUI  |  | Desktop |  | Gateway |
       +-----+----+  +----+----+  +----+----+
             \            |            /
              +-----------v-----------+
              |      AGENT CORE      |
              | context -> model -> tool
              +-----------+-----------+
                          |
              +-----------v-----------+
              | Model | Tools | Policy|
              +-----------+-----------+
                          |
              +-----------v-----------+
              | Memory | Skills | Cron|
              |       Sandbox       |
              +---------------------+
```

入口层接收请求；Core 编排上下文、模型和工具；模型负责推理，工具负责行动；Memory 保存历史，Skills/Plugins 扩展能力，Cron 自动化；Sandbox 承载执行。

Hermes 的取舍：**核心做窄，能力做宽**。保持 Agent Loop 稳定，把新能力放到 skill、plugin 或 MCP 中。

这是主要控制流示意，不是完整类图。

#AI智能体 #Agent架构 #开源项目 #软件架构 #HermesAgent #技术分享
