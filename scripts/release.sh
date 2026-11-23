#!/usr/bin/env bash
# Build, sign (Developer ID), notarize and package Better Terminal as a DMG.
# Usage: TEAM_ID=ABCDE12345 NOTARY_PROFILE=bt-notary scripts/release.sh 0.1.0
# One-time: xcrun notarytool store-credentials bt-notary --apple-id <id> --team-id <TEAM> --password <app-specific-pw>
set -euo pipefail
VERSION="${1:?usage: release.sh <version>}"
: "${TEAM_ID:?set TEAM_ID}"; : "${NOTARY_PROFILE:?set NOTARY_PROFILE}"
APP="Better Terminal"
OUT=build; ARCHIVE="$OUT/BetterTerminal.xcarchive"; DMG="$OUT/BetterTerminal-$VERSION.dmg"
rm -rf "$OUT"; mkdir -p "$OUT"

xcodegen generate
xcodebuild archive -project BetterTerminal.xcodeproj -scheme BetterTerminal -configuration Release \
  -archivePath "$ARCHIVE" MARKETING_VERSION="$VERSION" \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="Developer ID Application" DEVELOPMENT_TEAM="$TEAM_ID" \
  OTHER_CODE_SIGN_FLAGS="--timestamp --options runtime"

cp -R "$ARCHIVE/Products/Applications/$APP.app" "$OUT/"
codesign --verify --deep --strict --verbose=2 "$OUT/$APP.app"

# DMG with Applications shortcut
STAGE="$OUT/dmg"; mkdir -p "$STAGE"; cp -R "$OUT/$APP.app" "$STAGE/"; ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "$APP" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
codesign --sign "Developer ID Application" --timestamp "$DMG"

xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"
spctl --assess --type open --context context:primary-signature -v "$DMG"

echo "DMG: $DMG"
echo "sha256: $(shasum -a 256 "$DMG" | cut -d' ' -f1)"
