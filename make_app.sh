#!/bin/bash
# Build a release binary and wrap it in a proper ClaudeUsageBar.app bundle.
# A real bundle is required for LSUIElement (menu-bar-only) and for
# UserNotifications to work.
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="ClaudeUsageBar"
BUILD_DIR=".build/release"
APP="${APP_NAME}.app"

echo "▶ Building release…"
swift build -c release

echo "▶ Assembling ${APP}…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
cp Info.plist "$APP/Contents/Info.plist"

# Ad-hoc codesign so the Keychain ACL + notifications behave consistently.
codesign --force --deep --sign - "$APP" 2>/dev/null || \
    echo "  (codesign skipped — ad-hoc signing unavailable)"

echo "✅ Built $APP"
echo "   Launch with:  open $APP"
