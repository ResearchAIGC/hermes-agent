# Hermes Agent 完全可操作实践指南

> 面向希望**安装、使用、配置、扩展、调试和贡献 Hermes Agent** 的开发者。
> 本文以当前仓库结构为准；命令和配置项可能随版本演进，遇到差异时以仓库代码和
> `hermes <command> --help` 为准。

## 1. 你将学会什么

完成本指南后，你应该能够：

- 在 macOS、Linux、WSL2、Windows 或 Termux 上安装并完成首次对话；
- 理解 CLI、网关、TUI、Desktop、ACP 与 Agent Core 的关系；
- 配置模型、工具、技能、记忆、终端后端、消息平台和定时任务；
- 判断一个需求应该做成技能、插件、MCP，还是内置工具；
- 新增技能、插件、模型提供商、平台适配器和内置工具；
- 使用真实的临时 `HERMES_HOME` 复现问题并运行目标测试；
- 按项目规则提交安全、可维护、不会破坏提示缓存的改动。

## 2. 先建立正确的心智模型

Hermes 不是只有一个聊天 CLI，而是一套共用 Agent Core 的运行系统：

```text
入口层
  CLI / TUI / Desktop / 消息网关 / ACP / API / Batch
    ↓
Agent Core
  AIAgent → Prompt Builder → Provider Runtime → API 请求
         → Tool Registry → 工具执行 → 结果回填 → 下一轮
    ↓
持久化与扩展
  SQLite + FTS5 / Memory / Skills / Plugins / Cron / MCP
    ↓
执行环境
  Local / Docker / SSH / Modal / Daytona / Singularity / Vercel Sandbox
```

常用代码入口：

| 目标 | 首先阅读 |
| --- | --- |
| Agent 循环 | `run_agent.py`、`agent/conversation_loop.py`、`agent/turn_*.py` |
| Prompt 组装 | `agent/prompt_builder.py`、`agent/system_prompt.py` |
| Provider 解析 | `hermes_cli/auth.py`、`hermes_cli/runtime_provider.py` |
| 工具发现与分发 | `tools/registry.py`、`model_tools.py`、`toolsets.py` |
| CLI 与配置 | `cli.py`、`hermes_cli/config.py`、`hermes_cli/commands.py` |
| 会话存储 | `hermes_state.py`、`gateway/session.py` |
| 消息网关 | `gateway/run.py`、`gateway/platform_registry.py` |
| 插件 | `hermes_cli/plugins.py`、`plugins/` |
| 技能 | `skills/`、`optional-skills/` |
| 定时任务 | `cron/jobs.py`、`cron/scheduler.py` |
| 规范 | 根目录 `AGENTS.md` 和对应子目录 `AGENTS.md` |

### 两条必须牢记的设计不变量

1. **提示缓存优先。** 长会话会复用缓存前缀。不要在对话中途重建 system prompt、
   改变工具集、重新加载记忆或修改历史上下文。上下文压缩是唯一正式允许的上下文变更。
2. **核心保持窄。** 新能力优先放在已有代码、技能、服务门控工具、插件或 MCP；
   只有确实需要模型原生结构化调用时才增加内置核心工具。

## 3. 安装与首次运行

### 3.1 普通用户：官方安装器

macOS、Linux、WSL2：

```bash
curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
source ~/.bashrc  # zsh 用户使用 source ~/.zshrc
hermes doctor
hermes setup
hermes
```

Windows PowerShell：

```powershell
iex (irm https://hermes-agent.nousresearch.com/install.ps1)
hermes doctor
hermes setup
hermes
```

安装器通常把源码、虚拟环境和用户状态放到 `HERMES_HOME` 下。不要假设路径永远是
`~/.hermes`；脚本和代码应使用 `get_hermes_home()`，用户提示应使用
`display_hermes_home()`。

### 3.2 开发者：从仓库安装

要求 Python 3.11–3.13 和 `uv`。建议虚拟环境放在源码树外：

```bash
git clone https://github.com/NousResearch/hermes-agent.git
cd hermes-agent
uv venv ~/.hermes/venvs/hermes-dev --python 3.11
source ~/.hermes/venvs/hermes-dev/bin/activate
uv pip install -e ".[all,dev]"
```

需要浏览器、WhatsApp bridge 或前端时，再安装 Node 依赖：

```bash
npm install
```

验证开发环境：

```bash
hermes doctor
hermes chat -q "Hello"
scripts/run_tests.sh tests/ -k "smoke"
```

隔离运行一个不会污染真实用户状态的实例：

```bash
scripts/dev-sandbox.sh python -m hermes_cli.main
scripts/dev-sandbox.sh --persistent python -m hermes_cli.main desktop
```

### 3.3 最小凭据配置

秘密放在 `HERMES_HOME/.env`，非秘密配置放在 `HERMES_HOME/config.yaml`：

```bash
mkdir -p "${HERMES_HOME:-$HOME/.hermes}"/{cron,sessions,logs,memories,skills}
touch "${HERMES_HOME:-$HOME/.hermes}/.env"
```

例如：

```dotenv
OPENROUTER_API_KEY=sk-or-v1-...
```

也可以使用 Nous Portal：

```bash
hermes setup --portal
hermes portal info
```

不要把 API key 提交到 Git，不要把非秘密行为设置做成新的 `HERMES_*` 环境变量。

## 4. 日常使用工作流

### 4.1 CLI 基本命令

```bash
hermes                  # 交互式对话
hermes chat -q "..."    # 单次任务
hermes setup             # 设置向导
hermes model             # 选择提供商和模型
hermes tools             # 启用/禁用工具集
hermes config show       # 查看配置
hermes config set model.name <value>
hermes gateway           # 网关相关命令
hermes doctor            # 诊断
hermes update            # 更新安装
```

对话内常用斜杠命令：

```text
/new 或 /reset       新建会话
/model               切换模型
/skills              浏览技能
/compress            手动压缩上下文
/usage               查看用量
/retry               重试上一轮
/undo                撤销上一轮
/stop                中断当前任务
```

会改变 system-prompt 状态的命令应默认延迟到下一次会话生效；只有用户明确要求时才使用
项目已有的 `--now` 语义。

### 4.2 模型与 Provider

先尝试已有提供商或 OpenAI-compatible 自定义端点，不要为了一个 base URL 立刻修改核心：

```bash
hermes model
hermes model --help
```

运行时解析大致是：

```text
provider + model
  → credential/auth resolution
  → api_mode + api_key + base_url
  → chat_completions / codex_responses / anthropic_messages
  → request / usage / response normalization
```

复杂 Provider 要同时检查认证、模型目录、CLI 菜单、运行时解析、辅助模型和上下文长度。
只需 API key 的 OpenAI-compatible Provider，优先做 `plugins/model-providers/<name>/` 插件。

### 4.3 工具与工具集

工具不是默认全部可用：`check_fn`、工具集配置和平台预设共同决定模型看到的 schema。

```bash
hermes tools
hermes chat --toolsets web,terminal -q "..."
```

排查“模型不会调用某工具”时按顺序检查：

1. 工具是否被注册；
2. 工具所在 toolset 是否启用；
3. `check_fn` 是否通过；
4. API key、外部二进制或服务是否存在；
5. 当前平台是否有专属工具集限制。

### 4.4 技能

技能是“说明 + 现有工具”的首选扩展方式：

```text
/skills
/<skill-name>
```

技能常见位置：

- `skills/`：随发行版提供、普遍有用；
- `optional-skills/`：官方但较重或较专门；
- `HERMES_HOME/skills/`：用户自己的技能；
- Skills Hub：社区技能。

### 4.5 记忆、会话和上下文

用户状态通常包括配置、会话、记忆、日志、技能和 cron。会话使用 SQLite/FTS5 保存，
平台会把来源编码到 session key 中，不能手工拼接 session key。

长会话默认启用上下文压缩：

- Agent 内的主要压缩默认约在上下文窗口 50% 触发；
- 网关 session hygiene 是约 85% 的安全兜底；
- `/compress` 用于手动触发；
- 压缩失败会有冷却机制，避免每轮重复失败。

典型配置：

```yaml
compression:
  enabled: true
  threshold: 0.50
  target_ratio: 0.20
  tail_mode: lean
  in_place: true
```

## 5. 消息网关、定时任务和多 Profile

### 5.1 启动网关

先配置平台凭据和授权策略，再启动：

```bash
hermes gateway setup
hermes gateway start
hermes gateway status
```

网关处理链：

```text
平台事件 → Adapter → MessageEvent → 授权
  → session key → slash command 或 AIAgent
  → delivery 返回平台
```

授权默认是拒绝。优先使用平台 allowlist 或 DM pairing，不要在公网环境随意打开
`ALLOW_ALL_USERS`。

### 5.2 定时任务

Cron 是 Agent 任务，不是简单 shell 定时器：它会创建新 Agent、加载指定技能、执行 prompt，
再把结果投递到目标平台。建议先用测试 prompt 验证投递，再长期运行。

```bash
hermes cron --help
hermes cron list
hermes cron add --help
```

定时任务默认是独立会话；不要假设它会继承交互式会话的记忆或上下文。

### 5.3 Profile 隔离

不同 profile 拥有独立的配置、会话、记忆、日志和网关状态：

```bash
hermes profile --help
hermes -p work
hermes -p personal
```

Profile 的隔离是设计目标，不要通过“实时继承默认 profile 配置”来绕过它；需要复制初始
配置时使用项目已有的 clone 机制。

## 6. 需求应该落在哪个扩展层

按以下顺序选择，越靠前越不侵入核心：

| 需求 | 推荐实现 |
| --- | --- |
| 现有工具加一个参数或变体 | 扩展现有实现 |
| 可由说明、终端和现有工具完成 | Skill |
| 个人/项目专用 Python 工具或钩子 | Plugin |
| 外部标准工具服务 | MCP |
| 新模型后端 | Model-provider plugin；复杂场景才进核心 |
| 新消息平台 | Platform adapter/plugin |
| 必须结构化、流式、二进制或 API 集成 | Service-gated tool |
| 所有会话都必须拥有的基础能力 | 最后才考虑 core tool |

不要为了“看起来完整”增加没有实际消费者的 hook、抽象层或环境变量。

## 7. 创建一个技能：最推荐的二次开发路径

目录：

```text
skills/productivity/my-skill/
├── SKILL.md
├── scripts/       # 可选：确定性脚本
└── references/    # 可选：补充资料
```

最小 `SKILL.md`：

```markdown
---
name: my-skill
description: 用现有 Hermes 工具完成某类任务
version: 1.0.0
author: Your Name
license: MIT
metadata:
  hermes:
    tags: [productivity]
---

# My Skill

## When to Use
说明触发条件。

## Procedure
1. 检查输入。
2. 使用已有工具或 `terminal`。
3. 验证结果并报告失败原因。

## Pitfalls
列出权限、路径、平台和网络限制。

## Verification
给出可重复的成功判断。
```

秘密用 `required_environment_variables` 声明，路径和偏好用
`metadata.hermes.config` 声明，不要把 secret 写进 `config.yaml`：

```yaml
required_environment_variables:
  - name: MY_API_KEY
    prompt: My API key
    help: https://example.com/keys
    required_for: API access
metadata:
  hermes:
    config:
      - key: myskill.output_dir
        description: 输出目录
        default: "~/my-output"
```

测试：

```bash
hermes chat --toolsets skills -q "使用 my-skill 完成一个最小示例"
```

写技能时优先使用标准库、`curl` 和现有工具；复杂解析放到 `scripts/`，不要每次让模型临时
编写解析器。除非明确启用，否则不要使用会在宿主机执行的 inline shell。

## 8. 创建插件：不改核心的可复用能力

原生插件通常包含：

```text
my-plugin/
├── plugin.yaml
└── __init__.py
```

插件可以注册工具、hooks、CLI 命令、技能或专用 Provider。用户插件放在
`HERMES_HOME/plugins/`；项目插件可放在项目 `.hermes/plugins/`；也可通过 pip entry point
分发。

通用工具插件的原则：

1. 在 `register(ctx)` 中注册，不直接修改 `tools/` 或 `toolsets.py`；
2. 为危险操作设计明确的授权和错误路径；
3. 只把能力暴露给需要它的 toolset；
4. 在临时 `HERMES_HOME` 中验证发现、启用和调用；
5. 第三方 SaaS、观测和厂商集成优先作为独立插件仓库发布，不并入核心。

可移植 Agent Plugin v1 包通常包含 `plugin.json`、`skills/` 和可选的 `mcp.json`。安装后默认
不启用，必须显式 `hermes plugins enable <name>`；不要把凭据放入 `mcp.json`。

## 9. 添加内置工具：只有确实需要时才做

内置工具通常涉及两个文件：

1. `tools/your_tool.py`：handler、schema、`check_fn`、注册；
2. `toolsets.py`：把工具加入核心或指定 toolset。

最小结构：

```python
import json
import os

from tools.registry import registry


def check_requirements() -> bool:
    return bool(os.getenv("EXAMPLE_API_KEY"))


def handle_example(args: dict, **kwargs) -> str:
    value = args.get("value", "")
    return json.dumps({"value": value}, ensure_ascii=False)


EXAMPLE_SCHEMA = {
    "name": "example",
    "description": "执行一个确定性的示例操作。",
    "parameters": {
        "type": "object",
        "properties": {"value": {"type": "string"}},
        "required": ["value"],
    },
}

registry.register(
    name="example",
    toolset="example",
    schema=EXAMPLE_SCHEMA,
    handler=handle_example,
    check_fn=check_requirements,
    requires_env=["EXAMPLE_API_KEY"],
)
```

必须遵守：

- handler 返回 JSON 字符串，不返回裸 dict；
- 失败返回 `{"error": "..."}`，不要把预期错误静默吞掉；
- 顶层调用 `registry.register()`，这样自动发现才能导入；
- schema 的 description 必须准确，不能引用可能未启用的其他工具；
- `check_fn` 表示可达性/用户是否配置，不表示 GUI 等 session surface；
- 需要 API key 时接入 `hermes_cli/config.py` 的 `OPTIONAL_ENV_VARS`；
- 通过 registry 的真实 dispatch 测试，不只测试裸函数。

## 10. 添加模型 Provider

### 10.1 只需 API key 的 OpenAI-compatible Provider

优先新建：

```text
plugins/model-providers/<provider>/
├── __init__.py
└── plugin.yaml
```

在模块加载时调用 `register_provider(profile)`，提供 provider id、标签、base URL、环境变量
和 fallback models。之后验证：

```bash
hermes model
hermes chat --provider <provider> -q "hello"
```

### 10.2 复杂或原生协议 Provider

必须统一 provider id，并检查这些层：

1. `hermes_cli/auth.py`：凭据来源和别名；
2. `hermes_cli/models.py`：目录、标签、模型别名；
3. `hermes_cli/runtime_provider.py`：`api_mode/base_url/api_key/source`；
4. `hermes_cli/main.py`：CLI 和 setup；
5. `agent/auxiliary_client.py`：压缩、标题、视觉等侧任务；
6. `agent/model_metadata.py`：上下文长度和能力；
7. `agent/<provider>_adapter.py` 与 `run_agent.py`：非 OpenAI wire format；
8. 测试和用户文档。

Hermes 内部以 OpenAI chat-completions 形状保存消息。原生 adapter 应从该规范形状转换到
供应商格式，并测试 tool call、usage、错误、取消和重试。

## 11. 添加平台适配器

先阅读 `gateway/platforms/ADDING_A_PLATFORM.md` 和现有插件平台。适配器需要解决：

- 原始事件到 `MessageEvent` 的标准化；
- 收发文本、文件、语音和媒体；
- 用户授权、allowlist 或 pairing；
- session key 和线程/主题；
- 长消息拆分、重试、限流；
- `/stop`、`/approve`、`/new` 等忙碌态命令；
- 启动、关闭和状态报告。

不要在平台适配器中复制 Agent loop；平台差异应停留在入口和 delivery 层。

## 12. 调试与排障

### 12.1 第一轮诊断

```bash
hermes doctor
hermes config show
hermes tools
hermes gateway status
```

再检查：

```bash
echo "$HERMES_HOME"
ls -la "${HERMES_HOME:-$HOME/.hermes}"
tail -n 100 "${HERMES_HOME:-$HOME/.hermes}/logs/errors.log"
```

路径仅作为命令示例；代码里不要硬编码 `~/.hermes`。

### 12.2 “工具不存在”

依次检查：

```bash
hermes tools
hermes config show
which <required-binary>
```

然后查看工具的 `check_fn`、依赖安装路径、平台 toolset 和当前 profile。工具被
`check_fn` 排除时，模型 schema 中不会出现它。

### 12.3 “网关收不到消息”

1. `hermes gateway status` 确认进程和 profile；
2. 检查 bot token、平台 allowlist 和 pairing；
3. 检查平台插件是否启用；
4. 查看 `gateway.log` 和 `errors.log`；
5. 确认没有另一个 profile 占用同一 token；
6. 用最小消息和 `/status` 验证，不要先排查 Agent 复杂任务。

### 12.4 “长会话变慢或超上下文”

先执行 `/compress`，确认 `compression.enabled`，检查压缩辅助模型和额度。不要通过每轮
重建 system prompt 来“刷新上下文”，那会破坏缓存并增加成本。

### 12.5 “改了代码但行为没变”

常见原因：

- 改了定义模块，但生产代码在 facade 中重新导入了符号；
- 工具文件没有顶层注册；
- 工具注册了但不在 toolset；
- 运行的是另一个 profile 或另一个 Python；
- gateway 进程仍在使用旧代码。

先运行：

```bash
which hermes
python -c "import sys; print(sys.executable)"
hermes -p <profile> doctor
```

测试 monkeypatch 时，patch 生产调用处实际读取的 binding。

## 13. 测试、质量和提交

### 13.1 必须使用项目测试入口

```bash
scripts/run_tests.sh
scripts/run_tests.sh tests/agent/
scripts/run_tests.sh tests/tools/test_registry.py -k registry
scripts/run_tests.sh tests/gateway/ -v
```

不要用裸 `pytest` 代替它。项目脚本会隔离凭据、设置临时 `HERMES_HOME`、统一时区和语言，
并按文件隔离测试进程。

前端或 TUI 改动再运行对应 package 的既有命令，例如：

```bash
npm test
npm run build
```

以该 package 的 `package.json` scripts 为准，不要新增临时测试框架。

### 13.2 测试写法

优先测试行为契约，而不是当前数量或字符串快照：

- 工具可以真实注册、过滤、dispatch；
- Provider 解析出的 `api_mode/base_url` 彼此一致；
- 会话保持角色交替；
- system prompt 在非压缩轮次保持稳定；
- 安全边界在临时 `HERMES_HOME` 中真实生效；
- 跨平台路径、编码和进程行为符合目标平台。

不要写读取源代码文本的测试，不要用断言模型列表数量的 change-detector。

### 13.3 提交前清单

- [ ] 读过目标目录的 `AGENTS.md`；
- [ ] 先确认需求不是已有能力；
- [ ] 没有破坏 prompt caching、角色交替或 profile 隔离；
- [ ] 没有硬编码 `~/.hermes`；
- [ ] 错误被明确返回或记录，没有 `except: pass`；
- [ ] 新配置放在 `config.yaml`，秘密只进 `.env`；
- [ ] 有最小行为测试，并使用真实解析链验证；
- [ ] 运行了目标测试和必要的格式/构建命令；
- [ ] 文档、命令帮助和迁移行为同步更新。

## 14. 推荐源码阅读路线

第一次深入代码时按这个顺序：

1. 根目录 `AGENTS.md`；
2. `website/docs/developer-guide/architecture.md`；
3. `agent/AGENTS.md` 和 Agent Loop 文档；
4. `agent/prompt_builder.py`、`agent/conversation_loop.py`；
5. `hermes_cli/runtime_provider.py`；
6. `tools/registry.py`、`model_tools.py`、`toolsets.py`；
7. `hermes_state.py` 和 `gateway/session.py`；
8. `gateway/run.py`；
9. `plugins/`、`skills/`、`cron/`；
10. 对应领域的测试，再开始改代码。

不要从最大的 facade 文件盲目通读。当前仓库大量采用 facade + topical sibling 结构；先按
主题搜索 `agent/turn_*.py`、`gateway/run_*.py`、`hermes_cli/*_mixin.py`。

## 15. 一套完整的实战演练

下面的流程适合验证一次从安装到扩展的闭环：

```bash
# 1. 安装并诊断
hermes doctor
hermes setup

# 2. 选择模型和工具
hermes model
hermes tools

# 3. 运行最小任务
hermes chat -q "列出当前工作目录，并说明你使用了哪些工具"

# 4. 创建一个技能目录并编写 SKILL.md
# 5. 用 skills toolset 验证技能
hermes chat --toolsets skills,terminal -q "使用我的技能完成一个最小示例"

# 6. 在隔离环境测试改动
scripts/dev-sandbox.sh python -m hermes_cli.main

# 7. 运行目标测试
scripts/run_tests.sh tests/skills/ tests/tools/ -v

# 8. 检查最终状态
git diff --check
git status --short
```

## 16. 最后的判断标准

一个合格的 Hermes 改动应该同时满足：

1. 用户能通过现有 setup/config/tools UX 找到并启用它；
2. 它只在需要的 session、平台或 toolset 中出现；
3. 它不把无关能力永久塞进每次 API 请求；
4. 它不会破坏提示缓存、消息顺序、授权和 profile 隔离；
5. 它能在临时状态目录中被真实测试；
6. 文档告诉用户如何安装、运行、验证和排错。

如果一个实现无法满足以上条件，先退回到更低侵入的 Skill、Plugin 或 MCP 方案。
