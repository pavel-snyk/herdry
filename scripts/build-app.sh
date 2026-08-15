#!/bin/bash

set -euo pipefail

APP_NAME="Herdry"
APP_DIR="dist/${APP_NAME}.app"

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

codesign \
    --force \
    --sign - \
    "$APP_DIR"

echo "Built ${APP_DIR}"