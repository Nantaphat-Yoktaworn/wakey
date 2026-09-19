#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$DIR/build"
DMG_STAGING="$BUILD_DIR/dmg_staging"
DMG_OUTPUT="$BUILD_DIR/Wakey.dmg"

echo "==> Ensuring Wakey.app is built..."
"$DIR/Scripts/build.sh"

echo "==> Preparing DMG staging area..."
rm -rf "$DMG_STAGING" "$DMG_OUTPUT"
mkdir -p "$DMG_STAGING"

# Copy the app bundle
cp -R "$BUILD_DIR/Wakey.app" "$DMG_STAGING/"

# Create symlink to /Applications for easy drag-and-drop
ln -s /Applications "$DMG_STAGING/Applications"

echo "==> Generating disk image (DMG)..."
hdiutil create \
    -volname "Wakey" \
    -srcfolder "$DMG_STAGING" \
    -ov \
    -format UDZO \
    "$DMG_OUTPUT"

# Clean up staging directory
rm -rf "$DMG_STAGING"

echo ""
echo "=========================================================="
echo " DMG created successfully!"
echo " Location: $DMG_OUTPUT"
echo "=========================================================="
