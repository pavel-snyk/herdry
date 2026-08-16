#!/bin/bash

set -euo pipefail

APP_NAME="Herdry"
APP_DIR="dist/${APP_NAME}.app"
ICON_SOURCE="Sources/Herdry/Resources/herdry-app-icon.png"
ICONSET="$APP_DIR/Contents/Resources/Herdry.iconset"

echo "Building ${APP_NAME}..."

swift build -c release --product "$APP_NAME"

BIN_DIR="$(swift build -c release --show-bin-path)"

rm -rf "$APP_DIR"

mkdir -p "$APP_DIR/Contents/MacOS"

cp "$BIN_DIR/$APP_NAME" \
   "$APP_DIR/Contents/MacOS/$APP_NAME"

cp "App/Info.plist" \
   "$APP_DIR/Contents/Info.plist"

mkdir -p "$APP_DIR/Contents/Resources"
cp -R "$BIN_DIR/${APP_NAME}_${APP_NAME}.bundle" \
   "$APP_DIR/Contents/Resources/${APP_NAME}_${APP_NAME}.bundle"

mkdir -p "$ICONSET"
sips -z 16 16     "$ICON_SOURCE" --out "$ICONSET/icon_16x16.png" >/dev/null
sips -z 32 32     "$ICON_SOURCE" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
sips -z 32 32     "$ICON_SOURCE" --out "$ICONSET/icon_32x32.png" >/dev/null
sips -z 64 64     "$ICON_SOURCE" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
sips -z 128 128   "$ICON_SOURCE" --out "$ICONSET/icon_128x128.png" >/dev/null
sips -z 256 256   "$ICON_SOURCE" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256   "$ICON_SOURCE" --out "$ICONSET/icon_256x256.png" >/dev/null
sips -z 512 512   "$ICON_SOURCE" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512   "$ICON_SOURCE" --out "$ICONSET/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$ICON_SOURCE" --out "$ICONSET/icon_512x512@2x.png" >/dev/null

iconutil \
  --convert icns \
  "$ICONSET" \
  --output "$APP_DIR/Contents/Resources/Herdry.icns"

rm -rf "$ICONSET"

codesign \
    --force \
    --sign - \
    "$APP_DIR"

echo "Built ${APP_DIR}"