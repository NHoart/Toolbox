#!/usr/bin/env bash
#
# Reproducible localization fallback test for the Apple apps.
#
# Builds the real macOS and iOS app bundles, then runs a small probe as the
# bundle's main executable with a forced -AppleLanguages value. Because the
# probe's main bundle is the app bundle, Foundation resolves strings exactly
# as the app does at launch.
#
# Checked:
#   - English and regional English (en-GB)
#   - German, German (Austria), Spanish, French
#   - unsupported languages (it, ja, ru, pt-BR, zh-Hans) -> English
#   - every key of the app and widget String Catalogs
#   - InfoPlist.strings (NSLocalNetworkUsageDescription)
#   - a deliberately removed German key -> English for that key only
#
# Usage:
#   bash scripts/test-apple-localization.sh
#   SKIP_BUILD=1 bash scripts/test-apple-localization.sh   # reuse last build

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="$ROOT/build/localization"
CONFIGURATION="${CONFIGURATION:-Debug}"
PROBE="$BUILD/localization-fallback-probe"
MACOS_APP="$BUILD/macos/Toolbox.app"
IOS_APP="$BUILD/ios/Toolbox.app"
APP_CATALOG="$ROOT/Toolbox/Localizable.xcstrings"
WIDGET_CATALOG="$ROOT/ToolboxWidget/Localizable.xcstrings"
INFO_CATALOG="$ROOT/Toolbox/InfoPlist.xcstrings"
CHECKS=0
FAILURES=0

mkdir -p "$BUILD"

build_app() {
    local sdk="$1"
    local destination="$2"
    local output="$3"
    local log="$BUILD/build-$(basename "$output").log"

    echo "==> Building $(basename "$output") ($sdk, $CONFIGURATION)"
    rm -rf "$output"
    if ! xcodebuild -quiet \
        -project "$ROOT/Toolbox.xcodeproj" \
        -target Toolbox \
        -configuration "$CONFIGURATION" \
        -sdk "$sdk" \
        -destination "$destination" \
        CODE_SIGNING_ALLOWED=NO \
        CONFIGURATION_BUILD_DIR="$output" \
        build >"$log" 2>&1; then
        echo "Build failed, last lines of $log:" >&2
        tail -40 "$log" >&2
        exit 1
    fi
}

if [[ "${SKIP_BUILD:-0}" != "1" ]]; then
    build_app macosx "generic/platform=macOS" "$BUILD/macos"
    build_app iphonesimulator "generic/platform=iOS Simulator" "$BUILD/ios"
else
    echo "==> Reusing existing bundles (SKIP_BUILD=1)"
fi

[[ -d "$MACOS_APP" ]] || { echo "error: $MACOS_APP is missing" >&2; exit 1; }
[[ -d "$IOS_APP" ]] || { echo "error: $IOS_APP is missing" >&2; exit 1; }

echo "==> Compiling localization probe"
swiftc -O "$ROOT/scripts/localization-fallback-probe.swift" -o "$PROBE"

# Returns the executable path of a bundle, based on CFBundleExecutable.
bundle_executable() {
    local bundle="$1"
    local platform="$2"
    local plist name

    if [[ "$platform" == "macos" ]]; then
        plist="$bundle/Contents/Info.plist"
    else
        plist="$bundle/Info.plist"
    fi
    name="$(plutil -extract CFBundleExecutable raw -o - "$plist")"
    if [[ "$platform" == "macos" ]]; then
        echo "$bundle/Contents/MacOS/$name"
    else
        echo "$bundle/$name"
    fi
}

# Copies a bundle and replaces its main executable with the probe.
make_probe_bundle() {
    local source="$1"
    local destination="$2"
    local platform="$3"

    rm -rf "$destination"
    cp -R "$source" "$destination"
    cp "$PROBE" "$(bundle_executable "$destination" "$platform")"
}

run_check() {
    local label="$1"
    local bundle="$2"
    local platform="$3"
    local catalog="$4"
    local locale="$5"
    shift 5

    local executable
    executable="$(bundle_executable "$bundle" "$platform")"
    CHECKS=$((CHECKS + 1))
    if ! "$executable" \
        -AppleLanguages "($locale)" \
        -AppleLocale "$locale" \
        --catalog "$catalog" \
        --locale "$locale" \
        --expect-bundle "$bundle" \
        "$@"; then
        FAILURES=$((FAILURES + 1))
        echo "  ^ $label failed for $locale" >&2
    fi
}

APP_LOCALES=(en en-GB de de-AT es fr it ja ru pt-BR zh-Hans)
WIDGET_LOCALES=(en de es fr it ja)
INFO_LOCALES=(en de es fr it)

echo "==> Preparing probe bundles"
make_probe_bundle "$MACOS_APP" "$BUILD/probe-macos.app" macos
make_probe_bundle "$IOS_APP" "$BUILD/probe-ios.app" ios
make_probe_bundle "$MACOS_APP/Contents/PlugIns/ToolboxWidget.appex" \
    "$BUILD/probe-macos-widget.appex" macos
make_probe_bundle "$IOS_APP/PlugIns/ToolboxWidget.appex" \
    "$BUILD/probe-ios-widget.appex" ios

echo
echo "==> App String Catalog"
for locale in "${APP_LOCALES[@]}"; do
    run_check "macOS app" "$BUILD/probe-macos.app" macos "$APP_CATALOG" "$locale"
    run_check "iOS app" "$BUILD/probe-ios.app" ios "$APP_CATALOG" "$locale"
done

echo
echo "==> Widget String Catalog"
for locale in "${WIDGET_LOCALES[@]}"; do
    run_check "macOS widget" "$BUILD/probe-macos-widget.appex" macos "$WIDGET_CATALOG" "$locale"
    run_check "iOS widget" "$BUILD/probe-ios-widget.appex" ios "$WIDGET_CATALOG" "$locale"
done

echo
echo "==> Info.plist local network description"
for locale in "${INFO_LOCALES[@]}"; do
    run_check "macOS InfoPlist" "$BUILD/probe-macos.app" macos "$INFO_CATALOG" "$locale" \
        --info-plist-key NSLocalNetworkUsageDescription
    run_check "iOS InfoPlist" "$BUILD/probe-ios.app" ios "$INFO_CATALOG" "$locale" \
        --info-plist-key NSLocalNetworkUsageDescription
done

echo
echo "==> Missing translation fallback (one German key removed)"
for platform in macos ios; do
    bundle="$BUILD/probe-$platform-missing.app"
    if [[ "$platform" == "ios" ]]; then
        make_probe_bundle "$IOS_APP" "$bundle" ios
        strings="$bundle/de.lproj/Localizable.strings"
        info_strings="$bundle/de.lproj/InfoPlist.strings"
    else
        make_probe_bundle "$MACOS_APP" "$bundle" macos
        strings="$bundle/Contents/Resources/de.lproj/Localizable.strings"
        info_strings="$bundle/Contents/Resources/de.lproj/InfoPlist.strings"
    fi

    plutil -remove 'Today' "$strings"
    run_check "missing German key ($platform)" "$bundle" "$platform" "$APP_CATALOG" de \
        --missing-key Today

    plutil -remove NSLocalNetworkUsageDescription "$info_strings"
    run_check "missing German InfoPlist key ($platform)" "$bundle" "$platform" "$INFO_CATALOG" de \
        --info-plist-key NSLocalNetworkUsageDescription \
        --missing-key NSLocalNetworkUsageDescription
done

echo
if [[ "$FAILURES" -gt 0 ]]; then
    echo "FAILED: $FAILURES of $CHECKS checks"
    exit 1
fi
echo "PASS: $CHECKS checks, every key resolves as expected"
