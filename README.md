# AiStatus

AiStatus 是一款 macOS 菜单栏状态灯，用来观察本机 Codex/GPT 和 Claude Code 是否正在处理任务。它面向长时间等待 AI 输出的本地工作流：一眼看见任务是否还在跑，需要时手动开启防休眠，并在会话结束时收到桌面通知。

## 功能概览

- **菜单栏状态灯**：默认蓝灯表示检测到 GPT 或 Claude 正在使用，默认绿灯表示两者都空闲。
- **会话标题列表**：菜单中展示 GPT/Claude 的活跃会话和闲置会话标题。
- **结束通知**：当 GPT/Claude 会话从活跃变为闲置时，桌面通知提示结束的是哪个会话。
- **全部结束邮件**：当最后一个活跃的 GPT/Claude 会话结束、两者都空闲时，可发送一封邮件通知。
- **颜色偏好**：可以分别配置运行时灯颜色和空闲时灯颜色。
- **保持 Mac 活跃**：菜单里可以开启“保持 Mac 活跃（防休眠）”，阻止系统和显示器因空闲进入睡眠。
- **本地天气预报**：使用 macOS 定位获取当前位置，通过 Open-Meteo 拉取当前天气、未来 8 小时和 7 天预报。
- **硬件状态**：查看 CPU 使用率、内存、电池、电源来源、热状态，以及可用时的 SMC 温度传感器、风扇转速和 GPU 信息；顶部状态栏可选择直接展示 CPU、内存、电池等指标。
- **倒计时**：支持按秒或分钟设置倒计时，在菜单栏实时显示剩余时间；可暂停、继续、重置，并在临近结束时切换状态栏提醒背景色。
- **目标时间分钟倒计**：设置每天的目标时间，例如 18:00 下班，状态栏显示当前距离目标还有多少分钟；过点后可显示 0 或滚到明天继续倒计，并可配置状态栏背景色、文字粗细和文字颜色。
- **系统提醒**：设置指定时间触发 macOS 系统通知，支持单次提醒或每日重复提醒，并可配置标题和内容。
- **设置窗口**：参考 iStat Menus 的偏好设置交互，左侧按功能分组，右侧进入二级配置页。
- **外观模式**：支持浅色、深色和跟随 macOS 系统亮暗色，设置后立即应用到设置窗、悬浮窗和辅助窗口。
- **状态栏显示开关**：Codex/GPT 活跃检测、Claude 活跃检测、天气预报、硬件状态、倒计时、目标时间分钟倒计、系统提醒、防休眠状态都可以在各自设置页独立配置是否显示在状态栏。
- **本地优先**：只解析运行状态和用于展示的会话标题，不复制完整会话正文。

## 检测来源

AiStatus 只读取本机文件，不依赖远程账号：

- GPT/Codex：读取 `~/.codex/sessions` 的 `task_started` / `task_complete` 事件。
- GPT/Codex 会话标题：读取 `~/.codex/session_index.jsonl`。
- Claude Code：读取 `~/.claude/projects` 的 Claude Code JSONL 事件；最近用户/工具循环未出现 `assistant:end_turn` 时视为运行中。
- 天气：首次启用时请求 macOS 定位权限，只把经纬度发送给 Open-Meteo Forecast API 获取预报数据。

## 菜单栏交互

状态栏里的每个模块都支持 iStat Menus 风格的独立入口：单击显示对应模块的信息悬浮窗，再次单击同一模块或点击其他地方会关闭悬浮窗；双击或触控板双指点按打开对应模块的设置页。设置窗口左侧按功能分组，右侧是每个功能的二级配置页：

- **Codex/GPT 活跃检测**：独立状态灯展示 GPT 是否正在处理任务，图标样式与 Claude 区分。
- **Claude 活跃检测**：独立状态灯展示 Claude 是否正在处理任务，双击直达 Claude 设置页。
- **会话悬浮窗**：鼠标悬浮在 Codex/GPT 或 Claude 状态栏图标上时，展示活跃和闲置会话数量，并列出对应会话标题。
- **天气预报**：状态栏显示当前温度和天气图标；设置页可刷新天气或打开定位隐私设置。
- **硬件状态**：状态栏可选择显示 CPU 使用率、内存、电池、温度、热状态或风扇转速；鼠标悬浮时展示 CPU、内存、电池、热状态、GPU、温度传感器和风扇转速。
- **倒计时**：状态栏显示剩余时间；设置页可选择秒/分钟并开始、暂停、继续、重置倒计时，也可以配置临近提醒时间和提醒背景色。
- **目标倒计**：状态栏显示目标名称和剩余分钟；设置页可配置目标名称、目标时间、状态栏背景色、文字粗细、文字颜色，以及过点后显示 0 或倒计到明天。
- **系统提醒**：状态栏显示下一次提醒时间；设置页可选择单次提醒或每日提醒，并配置提醒标题、内容和触发时间。
- **提醒诊断**：系统提醒设置页会显示通知注册状态，并提供测试提醒按钮，用于检查 macOS 通知权限和专注模式影响。
- **防休眠状态**：状态栏显示防休眠是否开启；设置页可切换“保持 Mac 活跃（防休眠）”。
- **外观**：可切换浅色、深色或跟随系统亮暗色。
- **通知**：配置会话结束桌面通知，并可进入邮件通知配置。

为避免隐藏所有入口，最后一个状态栏项目不能被关闭。若定位权限被拒绝，可在菜单里打开“定位隐私设置”后重新授权。风扇、CPU/GPU 温度依赖 AppleSMC 传感器；部分 Apple Silicon 或无风扇机型可能不会暴露这些数据。

## 本地运行

```bash
swift run AiStatus
```

项目要求 macOS 13+，Swift Package 配置见 `Package.swift`。

## 邮件通知配置

邮件功能默认关闭；创建 `~/.aistatus/email.json` 后启用。AiStatus 会在“上一次刷新仍有活跃会话，本次刷新 GPT/Claude 活跃会话数变成 0”时发送一封邮件，不会在每个单独会话结束时重复发送。

```bash
mkdir -p ~/.aistatus
chmod 700 ~/.aistatus
```

推荐把 SMTP 授权码存到 macOS Keychain，再通过 `passwordCommand` 读取：

```bash
security add-generic-password \
  -U \
  -s aistatus-email \
  -a sender@example.com \
  -w 'your-smtp-app-password'
```

`~/.aistatus/email.json` 示例：

```json
{
  "smtpURL": "smtps://smtp.example.com:465",
  "username": "sender@example.com",
  "passwordCommand": "security find-generic-password -s aistatus-email -a sender@example.com -w",
  "from": "sender@example.com",
  "to": ["you@example.com"],
  "subject": "AiStatus：所有 AI 工作已结束",
  "requiresTLS": true
}
```

字段说明：

- `smtpURL`：SMTP 地址，支持 `smtps://host:465` 或 `smtp://host:587`。
- `username`：SMTP 登录用户名；如服务端不需要认证可省略。
- `password` / `passwordCommand`：二选一。建议使用 `passwordCommand`，避免明文授权码落盘。
- `from`：发件邮箱地址。
- `to`：收件邮箱地址数组，也可以写成单个字符串。
- `subject`：邮件标题；不填时使用默认英文标题。
- `requiresTLS`：默认 `true`，适合大多数 SMTP 服务。

也可以用环境变量覆盖配置路径或密码：`AISTATUS_EMAIL_CONFIG`、`AISTATUS_EMAIL_PASSWORD`、`AISTATUS_EMAIL_PASSWORD_COMMAND`。如果通过 Finder 打开打包后的 App，shell 里的环境变量通常不会自动传入，优先使用 `~/.aistatus/email.json`。

## 打包成菜单栏 App

```bash
Scripts/build-app.sh
open dist/AiStatus.app
```

默认使用 ad-hoc 签名，适合本机使用或发给信任用户测试。若要使用 Developer ID 证书签名：

```bash
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" Scripts/build-app.sh
```

## 打包成 DMG

```bash
Scripts/build-dmg.sh
```

脚本会生成：

- `dist/AiStatus-0.1.1.dmg`
- `dist/AiStatus-0.1.1.dmg.sha256`

DMG 内包含 `Install Guide.html`。如果用户首次打开时看到“Apple 无法验证是否包含可能危害 Mac 的恶意软件”，安装说明会引导用户进入“系统设置 → 隐私与安全性 → 仍要打开”。

面向互联网公开下载时，建议使用 Developer ID 证书签名并公证：

```bash
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
NOTARY_PROFILE="your-notarytool-profile" \
Scripts/build-dmg.sh
```

## 落地下载页

落地页位于 `site/`，采用玻璃拟态风格：深色流体背景、半透明毛玻璃面板、细高光边框、8px 圆角、鼠标跟随光标、阻尼弹簧反馈和可展开功能卡片。

页面内容包括：

- 首屏产品介绍和 DMG 下载按钮
- AiStatus 菜单栏状态面板预览
- 菜单栏状态灯、会话标题、防休眠、结束通知四个卖点
- 本地解析和隐私说明
- DMG 安装步骤
- 非 Apple 认证证书导致 Gatekeeper 拦截时的“系统设置 → 隐私与安全性 → 仍要打开”图文说明
- SHA-256 校验展示和复制按钮
- 中英文双语切换，用户选择会保存在浏览器本地
- 减少动态偏好或触屏设备下自动关闭鼠标跟随和弹簧位移动效

本地预览：

```bash
python3 -m http.server 4173 --directory site
open http://127.0.0.1:4173/
```

当前公开预览地址：

```text
http://aistatus.ssdwgg.site/
```

下载地址：

```text
http://aistatus.ssdwgg.site/downloads/AiStatus-0.1.1.dmg
```

> 注意：如果要正式公开推广，建议为 `aistatus.ssdwgg.site` 配置匹配的 HTTPS 证书，并使用 Developer ID 签名/公证后的 DMG。

## 部署落地页

复制部署配置示例：

```bash
cp .env.deploy.example .env.deploy.local
```

填写 `.env.deploy.local`：

```dotenv
DEPLOY_SSH_HOST=your-server-public-ip
DEPLOY_SSH_USER=root
DEPLOY_SSH_PORT=22
DEPLOY_SSH_KEY=~/.ssh/tencent-cloud.pem
DEPLOY_REMOTE_DIR=/www/wwwroot/ryw_yun_project/aistatus/
```

同步静态资源到服务器：

```bash
set -a
source .env.deploy.local
set +a

ssh -i "$DEPLOY_SSH_KEY" -p "$DEPLOY_SSH_PORT" \
  -o StrictHostKeyChecking=accept-new \
  -o IdentitiesOnly=yes \
  "$DEPLOY_SSH_USER@$DEPLOY_SSH_HOST" \
  "mkdir -p '$DEPLOY_REMOTE_DIR'"

rsync -avz --chmod=Du=rwx,Dgo=rx,Fu=rw,Fgo=r \
  -e "ssh -i '$DEPLOY_SSH_KEY' -p '$DEPLOY_SSH_PORT' -o StrictHostKeyChecking=accept-new -o IdentitiesOnly=yes" \
  site/ "$DEPLOY_SSH_USER@$DEPLOY_SSH_HOST:$DEPLOY_REMOTE_DIR"
```

`.env.deploy.local` 包含本机部署信息和私钥路径，已在 `.gitignore` 中忽略，不要提交。

## 验证

运行单元测试：

```bash
swift test
```

校验 DMG：

```bash
Scripts/build-dmg.sh
cd site/downloads
shasum -a 256 -c AiStatus-0.1.1.dmg.sha256
```

检查落地页本地资源引用：

```bash
python3 - <<'PY'
from html.parser import HTMLParser
from pathlib import Path

root = Path("site")

class Parser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.refs = []

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        for key in ("href", "src"):
            value = attrs.get(key)
            if value and not value.startswith(("http://", "https://", "#", "mailto:", "tel:")):
                self.refs.append(value)

parser = Parser()
parser.feed((root / "index.html").read_text())
missing = []

for ref in parser.refs:
    path = ref.split("#", 1)[0].split("?", 1)[0]
    if path and not (root / path).exists():
        missing.append(ref)

if missing:
    raise SystemExit("Missing refs: " + ", ".join(missing))

print("All local href/src references exist")
PY
```

## 项目结构

```text
.
├── Package.swift
├── Resources/
│   ├── AppIcon.icns
│   ├── AppIcon.png
│   └── Info.plist
├── Scripts/
│   ├── build-app.sh
│   ├── build-dmg.sh
│   └── generate-icon.py
├── Sources/
│   ├── AiStatus/
│   └── CodexStatusCore/
├── Tests/
│   └── CodexStatusCoreTests/
└── site/
    ├── assets/
    ├── downloads/
    ├── index.html
    ├── script.js
    └── styles.css
```
