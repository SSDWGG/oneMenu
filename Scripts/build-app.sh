#!/usr/bin/env bash
set -euo pipefail

APP_NAME="AiStatus"
CONFIGURATION="${1:-release}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"

cd "$ROOT_DIR"

BIN_DIR="$(swift build -c "$CONFIGURATION" --show-bin-path)"
swift build -c "$CONFIGURATION"

APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$BIN_DIR/$APP_NAME" "$APP_DIR/Contents/MacOS/$APP_NAME"
cp "$ROOT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$ROOT_DIR/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
for icon in openai.svg claude-color.svg; do
    if [[ -f "$ROOT_DIR/$icon" ]]; then
        cp "$ROOT_DIR/$icon" "$APP_DIR/Contents/Resources/$icon"
    fi
done
chmod +x "$APP_DIR/Contents/MacOS/$APP_NAME"

if [[ "${SKIP_CODESIGN:-0}" != "1" ]] && command -v codesign >/dev/null 2>&1; then
    if [[ "$SIGN_IDENTITY" == "-" ]]; then
        codesign --force --sign - "$APP_DIR" >/dev/null
    else
        codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP_DIR" >/dev/null
    fi
fi

echo "$APP_DIR"
