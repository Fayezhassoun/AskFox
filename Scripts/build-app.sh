#!/usr/bin/env bash
# Build a release binary, wrap it as a proper .app bundle.
# Output: .build/AskFox.app

set -euo pipefail

cd "$(dirname "$0")/.."
PKG_DIR="$(pwd)"
APP_NAME="AskFox"
BUNDLE_ID="com.fox.askfox"
VERSION="0.2.0"
BUILD_NUMBER="2"

echo "→ Building release binary…"
swift build -c release

BIN_PATH="$(swift build -c release --show-bin-path)/${APP_NAME}"
if [[ ! -x "$BIN_PATH" ]]; then
  echo "❌ Binary not found at $BIN_PATH"
  exit 1
fi

APP_DIR="${PKG_DIR}/.build/${APP_NAME}.app"
echo "→ Assembling .app bundle at ${APP_DIR}…"
rm -rf "$APP_DIR"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

cp "$BIN_PATH" "${APP_DIR}/Contents/MacOS/${APP_NAME}"
chmod +x "${APP_DIR}/Contents/MacOS/${APP_NAME}"

cat > "${APP_DIR}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundleDisplayName</key>
  <string>AskFox</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>
  <key>CFBundleVersion</key>
  <string>${BUILD_NUMBER}</string>
  <key>CFBundleShortVersionString</key>
  <string>${VERSION}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleExecutable</key>
  <string>${APP_NAME}</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>LSUIElement</key>
  <true/>
  <key>NSAppleEventsUsageDescription</key>
  <string>AskFox needs to open notes in Obsidian when you click a source citation.</string>
  <key>CFBundleDocumentTypes</key>
  <array/>
</dict>
</plist>
PLIST

cat > "${APP_DIR}/Contents/PkgInfo" <<<"APPL????"

# Ad-hoc sign so Gatekeeper allows local launch. Replace with a real Developer ID
# identity for distribution outside this machine.
echo "→ Ad-hoc signing…"
codesign --force --deep --sign - "${APP_DIR}"

echo ""
echo "✅ Built: ${APP_DIR}"
echo "   Launch: open \"${APP_DIR}\""
echo "   Or copy to /Applications: cp -R \"${APP_DIR}\" /Applications/"
