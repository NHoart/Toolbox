#!/usr/bin/env bash
#
# Stellt die veröffentlichten 3.1.0-Artefakte für
# scripts/test-release-sync-chain.js bereit:
#   - macOS-App aus Toolbox.dmg
#   - Windows-Client (app.asar) aus Toolbox-Setup.exe
#   - iOS-App aus dem Tag v3.1.0 für den Simulator
#
# Aufruf:
#   bash scripts/prepare-release-sync-test.sh
#
# Bereits vorhandene Artefakte werden wiederverwendet. Die Release-Dateien
# landen unter build/release-3.1.0; dieser Ordner ist von Git ignoriert.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REL="${TOOLBOX_RELEASE_TEST_DIR:-$ROOT/build/release-3.1.0}"
REPO="${TOOLBOX_RELEASE_REPO:-NHoart/Toolbox}"
TAG="${TOOLBOX_RELEASE_TAG:-v3.1.0}"
UDID="${TOOLBOX_SIMULATOR_UDID:-65C65642-D348-4211-9F48-16183C5199C6}"

MAC_APP="$REL/Toolbox.app"
IOS_SRC="$REL/src-v3.1.0"
IOS_APP="$REL/ios-derived/Build/Products/Debug-iphonesimulator/Toolbox.app"
WIN_ASAR="$REL/win-asar"
DOWNLOAD="$REL/download"
DMG="$DOWNLOAD/Toolbox.dmg"
SETUP="$DOWNLOAD/Toolbox-Setup.exe"

MOUNT_POINT=""

info() { printf '==> %s\n' "$*"; }
fail() { printf 'Fehler: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || fail "'$1' fehlt."; }

cleanup_mount() {
  if [ -n "$MOUNT_POINT" ] && mount | grep -Fq " on $MOUNT_POINT "; then
    diskutil eject "$MOUNT_POINT" >/dev/null 2>&1 \
      || hdiutil detach "$MOUNT_POINT" >/dev/null 2>&1 \
      || true
  fi
}
trap cleanup_mount EXIT

download_asset() {
  local name="$1"
  if [ -f "$DOWNLOAD/$name" ]; then
    info "Vorhanden: $DOWNLOAD/$name"
    return
  fi
  need curl
  mkdir -p "$DOWNLOAD"
  info "Lade $name von GitHub"
  curl -fL --retry 3 --connect-timeout 20 \
    -o "$DOWNLOAD/$name" \
    "https://github.com/$REPO/releases/download/$TAG/$name"
}

prepare_macos() {
  if [ -f "$MAC_APP/Contents/Info.plist" ]; then
    info "macOS-App vorhanden: $MAC_APP"
    return
  fi

  download_asset "Toolbox.dmg"
  need diskutil
  MOUNT_POINT="$REL/mnt-toolbox"
  rm -rf "$MOUNT_POINT"
  mkdir -p "$MOUNT_POINT"

  info "Hänge Toolbox.dmg ein"
  if ! diskutil image attach --mountOptions nobrowse --readOnly \
    --mountPoint "$MOUNT_POINT" "$DMG" >/dev/null 2>&1; then
    need hdiutil
    hdiutil attach -nobrowse -readonly -mountpoint "$MOUNT_POINT" "$DMG" >/dev/null
  fi

  [ -d "$MOUNT_POINT/Toolbox.app" ] || fail "Toolbox.app fehlt in Toolbox.dmg."
  info "Kopiere die Release-App"
  rm -rf "$MAC_APP"
  mkdir -p "$(dirname "$MAC_APP")"
  ditto "$MOUNT_POINT/Toolbox.app" "$MAC_APP"

  cleanup_mount
  trap - EXIT
  rmdir "$MOUNT_POINT" 2>/dev/null || true
  MOUNT_POINT=""
}

prepare_windows() {
  if [ -f "$WIN_ASAR/src/sync.js" ]; then
    info "Windows-Release-Client vorhanden: $WIN_ASAR"
    return
  fi

  download_asset "Toolbox-Setup.exe"
  need 7z
  need node

  info "Entpacke den NSIS-Installer"
  rm -rf "$REL/win-nsis" "$REL/win-app" "$WIN_ASAR"
  mkdir -p "$REL/win-nsis" "$REL/win-app"
  7z x -y -o"$REL/win-nsis" "$SETUP" >/dev/null

  local archive
  archive="$(find "$REL/win-nsis" -name 'app-64.7z' -print -quit)"
  [ -n "$archive" ] || fail "app-64.7z fehlt im Installer."
  7z x -y -o"$REL/win-app" "$archive" >/dev/null

  local asar="$REL/win-app/resources/app.asar"
  [ -f "$asar" ] || fail "resources/app.asar fehlt im Windows-Build."

  info "Entpacke app.asar"
  mkdir -p "$WIN_ASAR"
  local asar_bin="$ROOT/windows/node_modules/.bin/asar"
  if [ -x "$asar_bin" ]; then
    "$asar_bin" extract "$asar" "$WIN_ASAR" >/dev/null
  else
    (cd "$ROOT/windows" && npx --yes @electron/asar extract "$asar" "$WIN_ASAR" >/dev/null)
  fi
}

prepare_ios() {
  if [ -d "$IOS_APP" ]; then
    info "iOS-App vorhanden: $IOS_APP"
    return
  fi

  need git
  need xcodebuild
  need xcrun

  xcrun simctl list devices | grep -Fq "$UDID" \
    || fail "Simulator $UDID fehlt. TOOLBOX_SIMULATOR_UDID setzen."

  if [ ! -d "$IOS_SRC" ]; then
    info "Lege Worktree für $TAG an"
    git -C "$ROOT" worktree add --detach "$IOS_SRC" "$TAG"
  fi
  [ -d "$IOS_SRC/Toolbox.xcodeproj" ] || fail "Xcode-Projekt fehlt in $IOS_SRC."

  info "Baue die iOS-App aus $TAG für den Simulator"
  xcodebuild -quiet \
    -project "$IOS_SRC/Toolbox.xcodeproj" \
    -scheme Toolbox \
    -configuration Debug \
    -destination "platform=iOS Simulator,id=$UDID" \
    -derivedDataPath "$REL/ios-derived" \
    CODE_SIGNING_ALLOWED=NO \
    build

  [ -d "$IOS_APP" ] || fail "iOS-App wurde nicht gebaut: $IOS_APP"
}

verify() {
  need node
  local mac_version ios_version win_version
  mac_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' \
    "$MAC_APP/Contents/Info.plist")"
  ios_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' \
    "$IOS_APP/Info.plist")"
  win_version="$(node -p "require(process.argv[1]).version" "$WIN_ASAR/package.json")"

  [ "$mac_version" = "3.1.0" ] || fail "macOS-Version ist $mac_version, erwartet 3.1.0."
  [ "$ios_version" = "3.1.0" ] || fail "iOS-Version ist $ios_version, erwartet 3.1.0."
  [ "$win_version" = "3.1.0" ] || fail "Windows-Version ist $win_version, erwartet 3.1.0."

  mkdir -p "$REL/run"
  info "Bereit: macOS $mac_version, iOS $ios_version, Windows $win_version"
  info "Test starten: node scripts/test-release-sync-chain.js"
}

mkdir -p "$REL"
prepare_macos
prepare_windows
prepare_ios
verify
