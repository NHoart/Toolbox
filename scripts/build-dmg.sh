#!/usr/bin/env bash
#
# Builds the macOS app (Release) and packages it as a DMG under dist/Toolbox.dmg.
# Aufruf: ./scripts/build-dmg.sh
#
# The app is ad-hoc signed ("-") because the repo holds no developer certificate
# in it. macOS therefore has to approve the app once on first launch.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Toolbox"
WIDGET_NAME="ToolboxWidget"
CONFIGURATION="${CONFIGURATION:-Release}"
BUILD_DIR="$ROOT/build/dmg"
DIST_DIR="$ROOT/dist"
DMG_PATH="$DIST_DIR/$APP_NAME.dmg"
APP_PATH="$BUILD_DIR/$APP_NAME.app"

echo "==> Building $APP_NAME ($CONFIGURATION, macOS)"
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
  echo "Error: $APP_PATH was not built." >&2
  exit 1
fi

echo "==> Signing ad-hoc"
# First the embedded extension, then the app itself.
if [ -d "$APP_PATH/Contents/PlugIns/$WIDGET_NAME.appex" ]; then
  codesign --force --sign - \
    --entitlements "$ROOT/ToolboxWidgetExtension.entitlements" \
    "$APP_PATH/Contents/PlugIns/$WIDGET_NAME.appex"
fi

codesign --force --sign - \
  --entitlements "$ROOT/Toolbox/Toolbox.entitlements" \
  "$APP_PATH"

codesign --verify --deep --strict "$APP_PATH"

echo "==> Creating DMG"
STAGING_DIR="$BUILD_DIR/dmg-staging"
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

# diskutil replaces hdiutil on macOS 27 but fails on CI runners
# occasionally with error 153. Hence several attempts and the fallback to
# hdiutil when diskutil is missing or keeps failing.
create_dmg() {
  if command -v diskutil >/dev/null 2>&1; then
    if diskutil image create from \
      --format UDZO \
      --volumeName "$APP_NAME" \
      "$STAGING_DIR" \
      "$DMG_PATH"; then
      return 0
    fi
    echo "Note: diskutil could not create the image, trying hdiutil." >&2
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
    echo "Error: the DMG could not be created." >&2
    exit 1
  fi
  echo "Retrying in 5 seconds ($attempt/3)." >&2
  sleep 5
done

echo "Done: $DMG_PATH"
