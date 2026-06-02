#!/usr/bin/env bash
# Package .build/AskFox.app into a zipped DMG for distribution.
# Output: .build/AskFox-<version>.dmg

set -euo pipefail

cd "$(dirname "$0")/.."
PKG_DIR="$(pwd)"
APP_PATH="${PKG_DIR}/.build/AskFox.app"
VERSION="0.2.0"

if [[ ! -d "$APP_PATH" ]]; then
  echo "❌ ${APP_PATH} not found. Run Scripts/build-app.sh first."
  exit 1
fi

STAGE_DIR="${PKG_DIR}/.build/dmg-stage"
DMG_PATH="${PKG_DIR}/.build/AskFox-${VERSION}.dmg"

echo "→ Staging DMG contents…"
rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR"
cp -R "$APP_PATH" "$STAGE_DIR/AskFox.app"

# A symlink to /Applications makes drag-to-install obvious.
ln -s /Applications "$STAGE_DIR/Applications"

echo "→ Creating DMG…"
rm -f "$DMG_PATH"
hdiutil create \
  -volname "AskFox ${VERSION}" \
  -srcfolder "$STAGE_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

rm -rf "$STAGE_DIR"

echo ""
echo "✅ DMG: ${DMG_PATH}"
echo "   Size: $(du -h "$DMG_PATH" | cut -f1)"
