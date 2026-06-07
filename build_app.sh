#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="MacCleanerPro"
BUILD_ARCH="${BUILD_ARCH:-arm64}"
BUILD_CONFIGURATION="release"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
PKG_ROOT="$ROOT_DIR/dist/pkgroot"
PKG_PATH="$ROOT_DIR/dist/$APP_NAME.pkg"

printf 'Building Swift package for macOS %s...\n' "$BUILD_ARCH"
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

if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$APP_DIR" >/dev/null 2>&1 || true
fi

mkdir -p "$PKG_ROOT/Applications"
cp -R "$APP_DIR" "$PKG_ROOT/Applications/"
pkgbuild \
  --root "$PKG_ROOT" \
  --identifier "com.mertsert.maccleanerpro" \
  --version "1.0.0" \
  --install-location "/" \
  "$PKG_PATH" >/dev/null

printf 'App bundle: %s\n' "$APP_DIR"
printf 'Installer package: %s\n' "$PKG_PATH"