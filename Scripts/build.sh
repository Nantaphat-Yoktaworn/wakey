#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$DIR/build/LidSleepManager.app"

echo "==> Building LidSleepManager.app..."
rm -rf "$DIR/build"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Compile Swift code
echo "==> Compiling Swift sources..."
swiftc -O -framework Cocoa -framework IOKit \
    -o "$APP_DIR/Contents/MacOS/LidSleepManager" \
    "$DIR/App/main.swift"

# Copy Info.plist
cp "$DIR/App/Info.plist" "$APP_DIR/Contents/Info.plist"

echo "==> Build successful: $APP_DIR"
