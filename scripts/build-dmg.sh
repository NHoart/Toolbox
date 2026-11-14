#!/usr/bin/env bash
#
# Baut die macOS-App (Release) und verpackt sie als DMG unter dist/Toolbox.dmg.
# Aufruf: ./scripts/build-dmg.sh
#
# Die App wird ad-hoc signiert ("-"), weil im Repo kein Developer-Zertifikat
# liegt. Beim ersten Start muss macOS die App deshalb einmal freigeben.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Toolbox"
WIDGET_NAME="ToolboxWidget"
CONFIGURATION="${CONFIGURATION:-Release}"
BUILD_DIR="$ROOT/build/dmg"
DIST_DIR="$ROOT/dist"
DMG_PATH="$DIST_DIR/$APP_NAME.dmg"
APP_PATH="$BUILD_DIR/$APP_NAME.app"

echo "==> Baue $APP_NAME ($CONFIGURATION, macOS)"
rm -rf "$BUILD_DIR" "$DIST_DIR"
mkdir -p "$BUILD_DIR" "$DIST_DIR"

xcodebuild \
  -project "$ROOT/Toolbox.xcodeproj" \
  -target "$APP_NAME" \
  -configuration "$CONFIGURATION" \
  -sdk macosx \
  -destination 'generic/platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  CONFIGURATION_BUILD_DIR="$BUILD_DIR" \
  build

if [ ! -d "$APP_PATH" ]; then
  echo "Fehler: $APP_PATH wurde nicht gebaut." >&2
  exit 1
fi

echo "==> Signiere ad-hoc"
# Erst die embeddete Extension, dann die App selbst.
if [ -d "$APP_PATH/Contents/PlugIns/$WIDGET_NAME.appex" ]; then
  codesign --force --sign - \
    --entitlements "$ROOT/ToolboxWidgetExtension.entitlements" \
    "$APP_PATH/Contents/PlugIns/$WIDGET_NAME.appex"
fi

codesign --force --sign - \
  --entitlements "$ROOT/Toolbox/Toolbox.entitlements" \
  "$APP_PATH"

codesign --verify --deep --strict "$APP_PATH"

echo "==> Erstelle DMG"
STAGING_DIR="$BUILD_DIR/dmg-staging"
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

# diskutil ersetzt hdiutil unter macOS 27, scheitert auf CI-Runnern aber
# gelegentlich mit Fehler 153. Deshalb mehrere Versuche und der Rückfall auf
# hdiutil, falls diskutil nicht vorhanden ist oder weiter fehlschlägt.
create_dmg() {
  if command -v diskutil >/dev/null 2>&1; then
    if diskutil image create from \
      --format UDZO \
      --volumeName "$APP_NAME" \
      "$STAGING_DIR" \
      "$DMG_PATH"; then
      return 0
    fi
    echo "Hinweis: diskutil konnte das Image nicht erstellen, versuche hdiutil." >&2
    rm -f "$DMG_PATH"
  fi

  hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"
}

for attempt in 1 2 3; do
  if create_dmg; then
    break
  fi
  rm -f "$DMG_PATH"
  if [ "$attempt" -eq 3 ]; then
    echo "Fehler: DMG konnte nicht erstellt werden." >&2
    exit 1
  fi
  echo "Neuer Versuch in 5 Sekunden ($attempt/3)." >&2
  sleep 5
done

echo "Fertig: $DMG_PATH"
