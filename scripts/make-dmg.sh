#!/usr/bin/env bash
# Creates dist/BetterTerminal-<version>.dmg and its SHA-256 from "build/Better Terminal.app".
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="${1:?usage: make-dmg.sh <version>}"
APP="build/Better Terminal.app"
DMG="dist/BetterTerminal-${VERSION}.dmg"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

mkdir -p dist
ditto "$APP" "$STAGE/Better Terminal.app"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -volname "Better Terminal" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
if [[ -n "${SIGN_IDENTITY:-}" ]]; then codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG"; fi
(cd dist && shasum -a 256 "BetterTerminal-${VERSION}.dmg" > SHA256SUMS)
echo "Created $DMG"; cat dist/SHA256SUMS
