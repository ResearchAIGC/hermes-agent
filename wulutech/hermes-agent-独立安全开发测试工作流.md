# Hermes Agent 独立安全开发测试工作流

本流程用于在已经安装官方 Hermes Agent Desktop 的电脑上，使用当前源码开发和测试，
同时避免覆盖官方版、复用官方会话或抢占官方 Desktop 的数据。

适用仓库：

```text
/Users/wulu/Documents/GitHub/hermes-agent
```

## 1. 隔离目标

源码版和官方版必须至少隔离以下四类资源：

| 资源 | 官方版 | 源码版 |
| --- | --- | --- |
| Hermes 配置、会话、记忆、技能、日志 | 官方 `HERMES_HOME` | `~/.hermes-source-desktop/hermes-home` |
| Electron userData、连接、OAuth token、窗口状态 | 官方 Electron userData | `~/.hermes-source-desktop/electron-user-data` |
| 后端源码 | 官方/托管安装 | 当前 Git checkout |
| 进程识别名称 | `Hermes` | `Hermes Source Dev` |

不要在源码版中设置官方的 `HERMES_HOME`，也不要把官方 `userData` 路径传给源码版。

## 2. 一键隔离入口

仓库已经提供脚本：

```bash
/Users/wulu/Documents/GitHub/hermes-agent/wulutech/run-hermes-desktop-isolated.sh
```

脚本默认设置：

```text
HERMES_HOME=~/.hermes-source-desktop/hermes-home
HERMES_DESKTOP_USER_DATA_DIR=~/.hermes-source-desktop/electron-user-data
HERMES_DESKTOP_HERMES_ROOT=/Users/wulu/Documents/GitHub/hermes-agent
HERMES_DESKTOP_APP_NAME=Hermes Source Dev
```

其中：

- `HERMES_HOME` 隔离 Agent 配置、`.env`、sessions、memories、skills、logs；
- `HERMES_DESKTOP_USER_DATA_DIR` 隔离 Electron 连接配置、窗口状态、Desktop token 和缓存；
- `HERMES_DESKTOP_HERMES_ROOT` 强制 Desktop 使用当前源码；
- `HERMES_DESKTOP_APP_NAME` 区分开发版进程和窗口名称。

## 3. 第一次准备

先确认 Node.js 版本满足 Desktop 的要求（当前 `apps/desktop/package.json` 声明
Node 22.22、24.11 或 26+），然后在仓库根目录安装依赖：

```bash
cd /Users/wulu/Documents/GitHub/hermes-agent
npm install
```

脚本会通过根目录的 workspace 安装并链接 `apps/desktop`。如果依赖尚未完成，再执行：

```bash
cd /Users/wulu/Documents/GitHub/hermes-agent/apps/desktop
npm install
```

检查脚本实际使用的隔离路径：

```bash
/Users/wulu/Documents/GitHub/hermes-agent/wulutech/run-hermes-desktop-isolated.sh print-env
```

确认输出路径都是 `~/.hermes-source-desktop/`，再启动应用。

## 4. 日常开发运行

```bash
/Users/wulu/Documents/GitHub/hermes-agent/wulutech/run-hermes-desktop-isolated.sh dev
```

开发版会启动 Vite renderer 和 Electron。首次使用时，它使用的是全新的源码版
`HERMES_HOME`，需要重新选择模型并配置测试用 API key。

为了安全，建议为源码版使用专门的低权限 API key、低额度账户或测试 Provider。不要把官方
版的 `.env` 复制进源码版。

测试启动遮罩和启动流程：

```bash
/Users/wulu/Documents/GitHub/hermes-agent/wulutech/run-hermes-desktop-isolated.sh fake-boot
```

## 5. 测试源码版功能

在应用内完成最小验证：

1. 确认窗口标题是 `Hermes Source Dev`；
2. 打开设置，确认配置为空或仅有测试配置；
3. 选择测试 Provider 和模型；
4. 发送一个最小任务；
5. 确认源码修改已经反映；
6. 关闭源码版，再启动官方版，确认官方会话和设置不变。

检查隔离目录：

```bash
find "$HOME/.hermes-source-desktop" -maxdepth 2 -type f -print
```

不应在源码运行后发现官方 `~/.hermes` 下新增源码测试会话或日志。

## 6. 构建但不安装：首选打包验证方式

先构建未安装目录，不要覆盖系统应用：

```bash
/Users/wulu/Documents/GitHub/hermes-agent/wulutech/run-hermes-desktop-isolated.sh pack
```

输出在：

```text
/Users/wulu/Documents/GitHub/hermes-agent/apps/desktop/release/
```

`pack` 只生成 unpacked app，不把源码版安装到 `/Applications`，因此不会替换官方应用。
在 macOS 上，可直接从 `release/` 中找到生成的 `.app`，再用同一组隔离环境变量启动。

如果需要 DMG 供人工验收：

```bash
/Users/wulu/Documents/GitHub/hermes-agent/wulutech/run-hermes-desktop-isolated.sh dist-mac
```

不要双击安装到 `/Applications`，因为当前默认打包身份仍然是官方身份：

```json
"appId": "com.nousresearch.hermes",
"productName": "Hermes"
```

这会带来应用注册、单实例锁、`hermes://` 协议和更新路径冲突。

## 7. 需要“安装版源码应用”时的额外要求

只有在确实需要验证安装器、自动更新、协议关联或系统通知时，才创建独立安装版。
必须同时修改并验证：

```json
{
  "build": {
    "appId": "com.nousresearch.hermes.source",
    "productName": "Hermes Source",
    "executableName": "HermesSource",
    "artifactName": "Hermes-Source-${version}-${os}-${arch}.${ext}"
  }
}
```

还必须把源码版的深链接协议从 `hermes://` 改为独立协议，例如
`hermes-source://`，并同步修改注册、解析和测试。只改显示名称不够，因为 Electron
的系统身份仍可能相同。

建议不要直接修改主 `package.json` 来做个人本地安装版。更安全的做法是建立本地开发分支
或使用构建前的专用配置变体，并在构建结束后检查：

```bash
codesign -dv --verbose=4 /path/to/Hermes\ Source.app 2>&1 | grep -E 'Identifier|TeamIdentifier'
```

源码版的 Identifier 必须不同于官方版。

## 8. 开发测试命令

源码改动后，从 `apps/desktop` 运行已有检查：

```bash
cd /Users/wulu/Documents/GitHub/hermes-agent/apps/desktop
npm run typecheck
npm run lint
npm run test:ui
npm run test:desktop:platforms
```

需要完整 Desktop 检查时：

```bash
npm run check
```

涉及 Python Agent、网关、工具或配置解析时，从仓库根目录使用项目测试入口：

```bash
cd /Users/wulu/Documents/GitHub/hermes-agent
scripts/run_tests.sh tests/agent/
scripts/run_tests.sh tests/tools/
scripts/run_tests.sh tests/gateway/
```

不要用裸 `pytest` 替代 `scripts/run_tests.sh`，因为项目测试入口会隔离凭据和
`HERMES_HOME`。

## 9. 关闭、重置和清理

正常关闭源码 Desktop 后，隔离数据仍保留，便于下次继续测试。

只查看大小：

```bash
du -sh "$HOME/.hermes-source-desktop"
```

确认不再需要源码版测试数据后，才删除**明确的隔离目录**：

```bash
rm -rf "$HOME/.hermes-source-desktop"
```

不要删除 `~/.hermes`，也不要使用包含通配符的递归删除命令。

需要另一个独立实验环境时，使用不同目录：

```bash
HERMES_SOURCE_DESKTOP_ROOT="$HOME/.hermes-source-desktop-experiment" \
/Users/wulu/Documents/GitHub/hermes-agent/wulutech/run-hermes-desktop-isolated.sh dev
```

也可以显式指定两个目录：

```bash
HERMES_SOURCE_HERMES_HOME="$HOME/.hermes-source-home-a" \
HERMES_SOURCE_USER_DATA="$HOME/.hermes-source-user-data-a" \
/Users/wulu/Documents/GitHub/hermes-agent/wulutech/run-hermes-desktop-isolated.sh dev
```

## 10. 每次运行前的安全检查

```bash
test "$HERMES_HOME" != "$HOME/.hermes"
test "$HERMES_DESKTOP_USER_DATA_DIR" != "$HOME/Library/Application Support/Hermes"
test "$HERMES_DESKTOP_HERMES_ROOT" = "/Users/wulu/Documents/GitHub/hermes-agent"
```

如果使用脚本，先执行：

```bash
/Users/wulu/Documents/GitHub/hermes-agent/wulutech/run-hermes-desktop-isolated.sh print-env
```

确认以下条件后再启动：

- 源码版 `HERMES_HOME` 与官方版不同；
- Electron `userData` 与官方版不同；
- 没有把官方 `.env` 复制到源码目录；
- 使用的是源码 checkout；
- 没有把源码 DMG 安装到官方应用位置；
- 没有让源码版注册官方 `hermes://` 协议。

## 11. 推荐日常流程

```bash
cd /Users/wulu/Documents/GitHub/hermes-agent
git status --short

# 1. 检查隔离路径
wulutech/run-hermes-desktop-isolated.sh print-env

# 2. 开发运行
wulutech/run-hermes-desktop-isolated.sh dev

# 3. 关闭应用后做代码检查
cd apps/desktop
npm run typecheck
npm run lint
npm run test:ui

# 4. 回到仓库根目录检查 Python 相关改动
cd ../..
scripts/run_tests.sh tests/agent/ tests/tools/ -k '<focused-test>'

# 5. 需要打包验收时只生成 unpacked app
wulutech/run-hermes-desktop-isolated.sh pack
```

这套流程的核心原则是：**源码版永远使用专属 `HERMES_HOME`、专属 Electron userData、
专属显示名称；开发阶段不安装到系统应用目录；安装版测试必须使用独立 appId 和协议。**
