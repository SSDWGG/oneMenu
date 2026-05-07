#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

readonly SCRIPT_NAME="$(basename -- "$0")"
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly ROOT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
readonly APP_NAME="oneMenu"
readonly DIST_DIR="$ROOT_DIR/dist"
readonly INFO_PLIST="$ROOT_DIR/Resources/Info.plist"
readonly INSTALL_GUIDE="$ROOT_DIR/Resources/InstallGuide.html"

CONFIGURATION="release"
TMP_DIR=""

usage() {
    printf 'Usage: %s [release|debug]\n\n' "$SCRIPT_NAME"
    printf 'Environment:\n'
    printf '  SIGN_IDENTITY   codesign identity. Defaults to "-" for ad-hoc signing.\n'
    printf '  NOTARY_PROFILE  Optional notarytool keychain profile for notarization.\n'
    printf '  DMG_NAME        Optional DMG basename without .dmg.\n'
}

log() {
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

error() {
    printf '%s: %s\n' "$SCRIPT_NAME" "$*" >&2
    exit 1
}

cleanup() {
    if [[ -n "${TMP_DIR:-}" && -d "$TMP_DIR" ]]; then
        rm -rf -- "$TMP_DIR"
    fi
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || error "required command not found: $1"
}

parse_args() {
    while (($# > 0)); do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            release|debug)
                CONFIGURATION="$1"
                ;;
            *)
                error "unknown argument: $1"
                ;;
        esac
        shift
    done
}

read_app_version() {
    /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST"
}

build_app() {
    local build_output
    build_output="$("$SCRIPT_DIR/build-app.sh" "$CONFIGURATION")"
    printf '%s\n' "$build_output" >&2
    printf '%s\n' "$build_output" | tail -n 1
}

sign_dmg_if_requested() {
    local dmg_path="$1"
    local sign_identity="${SIGN_IDENTITY:--}"

    if [[ "$sign_identity" == "-" ]]; then
        return
    fi

    log "Signing DMG with identity: $sign_identity"
    codesign --force --timestamp --sign "$sign_identity" "$dmg_path" >/dev/null
}

notarize_if_requested() {
    local dmg_path="$1"
    local notary_profile="${NOTARY_PROFILE:-}"

    if [[ -z "$notary_profile" ]]; then
        return
    fi

    if [[ "${SIGN_IDENTITY:--}" == "-" ]]; then
        error "NOTARY_PROFILE requires SIGN_IDENTITY to be a Developer ID Application certificate"
    fi

    require_command xcrun
    log "Submitting DMG for notarization with profile: $notary_profile"
    xcrun notarytool submit "$dmg_path" --keychain-profile "$notary_profile" --wait
    log "Stapling notarization ticket"
    xcrun stapler staple "$dmg_path"
}

main() {
    parse_args "$@"

    [[ "$(uname -s)" == "Darwin" ]] || error "DMG packaging requires macOS"
    [[ -f "$INFO_PLIST" ]] || error "missing Info.plist: $INFO_PLIST"
    [[ -f "$INSTALL_GUIDE" ]] || error "missing install guide: $INSTALL_GUIDE"
    [[ -x "$SCRIPT_DIR/build-app.sh" ]] || error "build-app.sh is not executable"
    require_command hdiutil
    require_command ditto
    require_command shasum
    require_command tail
    require_command codesign

    local version
    local dmg_basename
    local dmg_path
    local checksum_path
    local app_path

    version="$(read_app_version)"
    dmg_basename="${DMG_NAME:-$APP_NAME-$version}"
    dmg_path="$DIST_DIR/$dmg_basename.dmg"
    checksum_path="$dmg_path.sha256"

    log "Building $APP_NAME.app ($CONFIGURATION)"
    app_path="$(build_app)"
    [[ -d "$app_path" ]] || error "build-app.sh did not produce an app bundle: $app_path"

    mkdir -p -- "$DIST_DIR"
    rm -f -- "$dmg_path" "$checksum_path"

    TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/${APP_NAME}.dmg.XXXXXX")"
    trap cleanup EXIT

    log "Preparing DMG contents"
    ditto "$app_path" "$TMP_DIR/$APP_NAME.app"
    cp "$INSTALL_GUIDE" "$TMP_DIR/Install Guide.html"
    ln -s /Applications "$TMP_DIR/Applications"

    log "Creating compressed DMG"
    hdiutil create \
        -volname "$APP_NAME" \
        -srcfolder "$TMP_DIR" \
        -ov \
        -format UDZO \
        "$dmg_path" >/dev/null

    sign_dmg_if_requested "$dmg_path"
    notarize_if_requested "$dmg_path"

    log "Verifying DMG"
    hdiutil verify "$dmg_path" >/dev/null

    (
        cd "$DIST_DIR"
        shasum -a 256 "$(basename -- "$dmg_path")"
    ) > "$checksum_path"

    printf 'DMG: %s\n' "$dmg_path"
    printf 'SHA-256: %s\n' "$checksum_path"
}

main "$@"
