# oneMenu

> [English](README_EN.md)

一款 macOS 菜单栏工具，一站式管理 Codex/GPT、Claude Code 的运行监控、硬件状态、天气预报、倒计时等。

---

## 功能概览

- **AI 活跃检测**：独立状态灯展示 GPT/Codex 和 Claude 是否正在处理任务，图标样式互不混淆。
- **会话悬浮窗**：鼠标悬浮时展示各 AI 的活跃/闲置会话数量及标题。
- **结束通知**：AI 会话从活跃变为闲置时弹出桌面通知。
- **全部结束邮件**：所有 AI 会话都空闲时自动发送一封邮件通知。
- **保持 Mac 活跃**：一键开启防休眠，阻止系统和显示器因空闲进入睡眠。
- **天气预报**：使用 macOS 定位获取当前位置，通过 Open-Meteo 拉取当前天气、未来 8 小时和 7 天预报。
- **硬件状态**：CPU 使用率、内存、电池、电源来源、热状态，以及 SMC 温度传感器、风扇转速和 GPU 信息；状态栏可选展示 CPU、内存、电池等指标。
- **倒计时**：按秒或分钟设置倒计时，状态栏实时显示剩余时间，可暂停/继续/重置。
- **目标时间倒计**：设置每日目标时间（如下班时间），状态栏显示剩余分钟；过点后可显示 0 或滚动到明天。
- **系统提醒**：指定时间触发 macOS 系统通知，支持单次提醒或每日重复。
- **外观模式**：浅色、深色和跟随 macOS 系统亮暗色。
- **设置窗口**：iStat Menus 风格，左侧功能分组，右侧二级配置页。
- **本地优先**：只解析本机文件的状态和会话标题，不传输会话内容。

## 检测来源

oneMenu 只读取本机文件，不依赖远程账号：

- **GPT/Codex**：读取 `~/.codex/sessions` 的 `task_started` / `task_complete` 事件，以及 `~/.codex/session_index.jsonl` 获取会话标题。
- **Claude Code**：读取 `~/.claude/projects` 的 JSONL 事件；最近一次循环未出现 `assistant:end_turn` 时视为运行中。
- **天气**：首次启用时请求 macOS 定位权限，只把经纬度发送给 Open-Meteo API。
- **硬件**：通过 macOS IOKit 和 SMC 读取传感器数据（部分 Apple Silicon / 无风扇机型不暴露温度传感器和风扇转速）。

## 本地运行

```bash
swift run oneMenu
```

要求 macOS 13+。

## 打包成 App

```bash
swift build --configuration release
mkdir -p oneMenu.app/Contents/MacOS oneMenu.app/Contents/Resources
cp .build/release/oneMenu oneMenu.app/Contents/MacOS/
cp Resources/Info.plist oneMenu.app/Contents/Resources/
cp Resources/AppIcon.icns oneMenu.app/Contents/Resources/
cp Sources/oneMenu/Resources/*.svg oneMenu.app/Contents/Resources/
open oneMenu.app
```

默认使用 ad-hoc 签名，适合本机使用。

若需 Developer ID 签名：

```bash
Scripts/build-app.sh
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" Scripts/build-app.sh
```

## 打包 DMG

```bash
Scripts/build-dmg.sh
```

生成文件：
- `dist/oneMenu-0.1.2.dmg`
- `dist/oneMenu-0.1.2.dmg.sha256`

公开分发建议使用 Developer ID 签名并公证：

```bash
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
NOTARY_PROFILE="your-notarytool-profile" \
Scripts/build-dmg.sh
```

## 邮件通知配置

邮件默认关闭；创建 `~/.onemenu/email.json` 后启用。当所有 AI 会话从活跃变为空闲时发送一封邮件。

```bash
mkdir -p ~/.onemenu && chmod 700 ~/.onemenu
```

推荐将 SMTP 授权码存入 Keychain：

```bash
security add-generic-password \
  -U \
  -s onemenu-email \
  -a sender@example.com \
  -w 'your-smtp-app-password'
```

`~/.onemenu/email.json` 示例：

```json
{
  "smtpURL": "smtps://smtp.example.com:465",
  "username": "sender@example.com",
  "passwordCommand": "security find-generic-password -s onemenu-email -a sender@example.com -w",
  "from": "sender@example.com",
  "to": ["you@example.com"],
  "subject": "oneMenu: All AI tasks completed",
  "requiresTLS": true
}
```

环境变量：
- `ONEMENU_EMAIL_CONFIG`：自定义配置文件路径
- `ONEMENU_EMAIL_PASSWORD`：SMTP 密码
- `ONEMENU_EMAIL_PASSWORD_COMMAND`：获取密码的命令

## 菜单栏交互

- **单击**：显示对应模块的信息悬浮窗
- **双击/双指点按**：打开对应模块的设置页
- **右键单击**：显示完整菜单（设置、刷新、防休眠、退出等）
- **悬浮**：展示 AI 会话详情、硬件详情

各模块可独立配置是否在状态栏显示。

## 落地页

[![Pages](https://img.shields.io/badge/GitHub%20Pages-ssdwgg.github.io%2FoneMenu-7ee0c3?logo=github)](https://ssdwgg.github.io/oneMenu/)

宣传页托管在 GitHub Pages，拟态玻璃风格，支持鼠标跟随滚动交互。

预览：

```bash
python3 -m http.server 4173 --directory docs
open http://127.0.0.1:4173/
```

## 部署

```bash
cp .env.deploy.example .env.deploy.local
```

编辑 `.env.deploy.local` 填写服务器信息：

```dotenv
DEPLOY_SSH_HOST=your-server-ip
DEPLOY_SSH_USER=root
DEPLOY_SSH_PORT=22
DEPLOY_SSH_KEY=~/.ssh/your-key.pem
DEPLOY_REMOTE_DIR=/www/wwwroot/your-project/onemenu/
```

同步到服务器：

```bash
set -a && source .env.deploy.local && set +a

ssh -i "$DEPLOY_SSH_KEY" -p "$DEPLOY_SSH_PORT" \
  -o StrictHostKeyChecking=accept-new -o IdentitiesOnly=yes \
  "$DEPLOY_SSH_USER@$DEPLOY_SSH_HOST" "mkdir -p '$DEPLOY_REMOTE_DIR'"

rsync -avz --chmod=Du=rwx,Dgo=rx,Fu=rw,Fgo=r \
  -e "ssh -i '$DEPLOY_SSH_KEY' -p '$DEPLOY_SSH_PORT' -o StrictHostKeyChecking=accept-new -o IdentitiesOnly=yes" \
  docs/ "$DEPLOY_SSH_USER@$DEPLOY_SSH_HOST:$DEPLOY_REMOTE_DIR"
```

## 验证

运行测试：

```bash
swift test
```

校验 DMG：

```bash
Scripts/build-dmg.sh
cd dist
shasum -a 256 -c oneMenu-0.1.2.dmg.sha256
```

## 项目结构

```text
.
├── Package.swift
├── Resources/
│   ├── AppIcon.icns
│   ├── AppIcon.png
│   ├── Info.plist
│   └── InstallGuide.html
├── Scripts/
│   ├── build-app.sh
│   ├── build-dmg.sh
│   └── generate-icon.py
├── Sources/
│   ├── oneMenu/
│   │   ├── AiStatusApp.swift
│   │   ├── AppAppearancePreferences.swift
│   │   ├── EmailConfigWindowController.swift
│   │   ├── HardwareStatusMonitor.swift
│   │   ├── SettingsWindowController.swift
│   │   ├── WeatherForecastService.swift
│   │   └── Resources/
│   └── CodexStatusCore/
├── Tests/
│   └── CodexStatusCoreTests/
└── docs/
    ├── assets/
    ├── downloads/
    ├── index.html
    ├── script.js
    └── styles.css
```
