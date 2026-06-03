#!/bin/bash
# Build a distributable DMG installer for ClaudeUsageBar.
# Requires the .app bundle to exist first:  ./make_app.sh
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="ClaudeUsageBar"
APP="${APP_NAME}.app"
VERSION=$(defaults read "$(pwd)/${APP}/Contents/Info" CFBundleShortVersionString 2>/dev/null || echo "1.0")
TMP_DMG="${APP_NAME}-tmp.dmg"
FINAL_DMG="${APP_NAME}-${VERSION}.dmg"
VOLUME="${APP_NAME} ${VERSION}"

if [ ! -d "$APP" ]; then
    echo "❌ ${APP} not found — run ./make_app.sh first"
    exit 1
fi

echo "▶ Staging DMG contents…"
STAGING=$(mktemp -d)
trap "rm -rf '$STAGING' '$TMP_DMG' '/tmp/dmg_mount_$$' 2>/dev/null; true" EXIT

cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

echo "▶ Creating writable DMG…"
hdiutil create \
    -volname "$VOLUME" \
    -srcfolder "$STAGING" \
    -ov -format UDRW \
    "$TMP_DMG" > /dev/null

echo "▶ Mounting to set Finder layout…"
MOUNT="/tmp/dmg_mount_$$"
mkdir -p "$MOUNT"
hdiutil attach -readwrite -noverify -mountpoint "$MOUNT" "$TMP_DMG" > /dev/null

osascript <<APPLESCRIPT 2>/dev/null || true
tell application "Finder"
    tell disk "${VOLUME}"
        open
        delay 1
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {200, 120, 680, 400}
        set arrangement of icon view options of container window to not arranged
        set position of item "${APP_NAME}.app" of container window to {120, 150}
        set position of item "Applications" of container window to {360, 150}
        update without registering applications
        delay 1
        close
    end tell
end tell
APPLESCRIPT

# Set volume icon from the app's icns (best-effort)
if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "${MOUNT}/.VolumeIcon.icns"
    SetFile -a C "$MOUNT" 2>/dev/null || true
fi

hdiutil detach "$MOUNT" > /dev/null

echo "▶ Compressing to final DMG…"
rm -f "$FINAL_DMG"
hdiutil convert "$TMP_DMG" -format UDZO -o "$FINAL_DMG" > /dev/null

echo "✅ ${FINAL_DMG} ready"
echo "   Install: open ${FINAL_DMG}, then drag ${APP_NAME} → Applications"
