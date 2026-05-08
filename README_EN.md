# oneMenu

> [中文](README.md)

A macOS menu bar utility that monitors Codex/GPT and Claude Code activity, hardware status, weather, countdown timers — all in one menu.

---

## Features

- **AI Activity Detection**: Separate status lights for GPT/Codex and Claude active/idle state with distinct brand icons.
- **Session Hover Panel**: Hover to see active and idle session counts and titles for each AI.
- **Session End Notifications**: Desktop notification when an AI session ends.
- **All-Done Email**: Automatically send an email when all AI sessions become idle.
- **Prevent Sleep**: One-click toggle to prevent system and display sleep during long AI runs.
- **Weather Forecast**: Location-based weather using Open-Meteo for current conditions, 8-hour and 7-day forecasts.
- **Hardware Status**: CPU, memory, battery, thermal state, SMC temperature sensors, fan speeds, and GPU info; selectable status bar metrics.
- **Countdown Timer**: Seconds or minutes countdown with real-time status bar display, pause/resume/reset.
- **Target Time Countdown**: Set a daily target time (e.g. end of workday), shows remaining minutes in the status bar.
- **System Reminders**: Schedule macOS system notifications with one-shot or daily repeat support.
- **Appearance**: Light, dark, or follow system appearance.
- **Settings Window**: iStat Menus-style settings with sidebar grouping and detail pages.
- **Local-First**: Only parses local runtime state and session titles — no session content leaves your machine.

## Detection Sources

oneMenu reads local files only, no remote accounts needed:

- **GPT/Codex**: Reads `task_started`/`task_complete` events from `~/.codex/sessions`, and session titles from `~/.codex/session_index.jsonl`.
- **Claude Code**: Reads JSONL events from `~/.claude/projects`; considered running when the most recent cycle lacks `assistant:end_turn`.
- **Weather**: Requests macOS location permission on first use; only sends coordinates to Open-Meteo API.
- **Hardware**: Reads sensors via macOS IOKit and SMC (some Apple Silicon / fanless models may not expose temperature sensors and fan speeds).

## Quick Start

```bash
swift run oneMenu
```

Requires macOS 13+.

## Build App Bundle

```bash
swift build --configuration release
mkdir -p oneMenu.app/Contents/MacOS oneMenu.app/Contents/Resources
cp .build/release/oneMenu oneMenu.app/Contents/MacOS/
cp Resources/Info.plist oneMenu.app/Contents/Resources/
cp Resources/AppIcon.icns oneMenu.app/Contents/Resources/
cp Sources/oneMenu/Resources/*.svg oneMenu.app/Contents/Resources/
open oneMenu.app
```

Default ad-hoc signing, suitable for local use.

For Developer ID signing:

```bash
Scripts/build-app.sh
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" Scripts/build-app.sh
```

## Build DMG

```bash
Scripts/build-dmg.sh
```

Output:
- `dist/oneMenu-0.1.2.dmg`
- `dist/oneMenu-0.1.2.dmg.sha256`

Recommended to sign and notarize for public distribution:

```bash
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
NOTARY_PROFILE="your-notarytool-profile" \
Scripts/build-dmg.sh
```

## Email Notification Config

Email is disabled by default; create `~/.onemenu/email.json` to enable. A single email is sent when all AI sessions become idle.

```bash
mkdir -p ~/.onemenu && chmod 700 ~/.onemenu
```

Recommended: store SMTP password in Keychain:

```bash
security add-generic-password \
  -U \
  -s onemenu-email \
  -a sender@example.com \
  -w 'your-smtp-app-password'
```

`~/.onemenu/email.json` example:

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

Environment variables:
- `ONEMENU_EMAIL_CONFIG`: custom config path
- `ONEMENU_EMAIL_PASSWORD`: SMTP password
- `ONEMENU_EMAIL_PASSWORD_COMMAND`: command to retrieve password

## Menu Bar Interaction

- **Single Click**: Show the module's info hover panel
- **Double Click / Two-Finger Tap**: Open the module's settings page
- **Right Click**: Show full menu (settings, refresh, prevent sleep, quit, etc.)
- **Hover**: Show AI session details, hardware details

Each module can be independently shown/hidden in the status bar.

## Landing Page

Local preview:

```bash
python3 -m http.server 4173 --directory site
open http://127.0.0.1:4173/
```

## Deploy

```bash
cp .env.deploy.example .env.deploy.local
```

Edit `.env.deploy.local` with your server details:

```dotenv
DEPLOY_SSH_HOST=your-server-ip
DEPLOY_SSH_USER=root
DEPLOY_SSH_PORT=22
DEPLOY_SSH_KEY=~/.ssh/your-key.pem
DEPLOY_REMOTE_DIR=/www/wwwroot/your-project/onemenu/
```

Sync to server:

```bash
set -a && source .env.deploy.local && set +a

ssh -i "$DEPLOY_SSH_KEY" -p "$DEPLOY_SSH_PORT" \
  -o StrictHostKeyChecking=accept-new -o IdentitiesOnly=yes \
  "$DEPLOY_SSH_USER@$DEPLOY_SSH_HOST" "mkdir -p '$DEPLOY_REMOTE_DIR'"

rsync -avz --chmod=Du=rwx,Dgo=rx,Fu=rw,Fgo=r \
  -e "ssh -i '$DEPLOY_SSH_KEY' -p '$DEPLOY_SSH_PORT' -o StrictHostKeyChecking=accept-new -o IdentitiesOnly=yes" \
  site/ "$DEPLOY_SSH_USER@$DEPLOY_SSH_HOST:$DEPLOY_REMOTE_DIR"
```

## Verification

Run tests:

```bash
swift test
```

Verify DMG checksum:

```bash
Scripts/build-dmg.sh
cd dist
shasum -a 256 -c oneMenu-0.1.2.dmg.sha256
```

## Project Structure

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
└── site/
    ├── assets/
    ├── downloads/
    ├── index.html
    ├── script.js
    └── styles.css
```
