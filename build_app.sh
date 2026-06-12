#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="MacCleanerPro"
BUILD_ARCH="${BUILD_ARCH:-arm64}"
BUILD_CONFIGURATION="release"

# FLAVOR=appstore (default) builds the App Store-safe variant (advanced/system
# tools disabled). FLAVOR=full builds the direct-distribution variant with all
# features enabled. See Versions/AppStore/build.sh and Versions/Full/build.sh.
FLAVOR="${FLAVOR:-appstore}"
if [ "$FLAVOR" = "full" ]; then
  export MCP_FULL_VERSION=1
else
  unset MCP_FULL_VERSION || true
fi

OUT_DIR="$ROOT_DIR/dist/$FLAVOR"
APP_DIR="$OUT_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
PKG_ROOT="$OUT_DIR/pkgroot"
PKG_PATH="$OUT_DIR/$APP_NAME.pkg"

printf 'Building Swift package (%s) for macOS %s...\n' "$FLAVOR" "$BUILD_ARCH"
swift build \
  -c "$BUILD_CONFIGURATION" \
  --arch "$BUILD_ARCH" \
  --package-path "$ROOT_DIR"
BIN_DIR="$(swift build \
  -c "$BUILD_CONFIGURATION" \
  --arch "$BUILD_ARCH" \
  --package-path "$ROOT_DIR" \
  --show-bin-path)"

rm -rf "$APP_DIR" "$PKG_ROOT" "$PKG_PATH"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BIN_DIR/$APP_NAME" "$MACOS_DIR/$APP_NAME"
cp "$ROOT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"

if [ "$FLAVOR" = "full" ] && command -v /usr/libexec/PlistBuddy >/dev/null 2>&1; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleName MacCleanerPro Full" "$CONTENTS_DIR/Info.plist" >/dev/null 2>&1 || true
fi

RESOURCE_BUNDLE="$BIN_DIR/${APP_NAME}_${APP_NAME}.bundle"
if [ -d "$RESOURCE_BUNDLE" ]; then
  cp -R "$RESOURCE_BUNDLE" "$RESOURCES_DIR/"
fi

if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$APP_DIR" >/dev/null 2>&1 || true
fi

mkdir -p "$PKG_ROOT/Applications"
cp -R "$APP_DIR" "$PKG_ROOT/Applications/"
pkgbuild \
  --root "$PKG_ROOT" \
  --identifier "com.mertsert.maccleanerpro" \
  --version "1.1.1" \
  --install-location "/" \
  "$PKG_PATH" >/dev/null

printf 'App bundle: %s\n' "$APP_DIR"
printf 'Installer package: %s\n' "$PKG_PATH"
