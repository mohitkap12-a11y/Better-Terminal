#!/usr/bin/env bash
# Builds "build/Better Terminal.app" (universal, Sparkle embedded). Usage: scripts/build-app.sh [version]
# Set SIGN_IDENTITY to a "Developer ID Application: ..." identity to sign with hardened runtime;
# otherwise the bundle is ad-hoc signed (fine for local use, NOT for distribution).
# SPARKLE_PUBLIC_ED_KEY is the EdDSA public key that update archives are verified against (required for signed
# builds; without it the app runs with in-app updates switched off).
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="${1:-0.1.0}"

# CFBundleVersion (what Sparkle compares) must not contain a hyphen: Sparkle ignores everything after the first "-".
# 0.4.0-beta.1 -> 0.4.0b1; any other suffix loses its "-" and "." (0.4.0-rc1 -> 0.4.0rc1).
bundle_version() {
  local v="$1" base suffix
  [[ "$v" == *-* ]] || { echo "$v"; return; }
  base="${v%%-*}"; suffix="${v#*-}"
  if [[ "$suffix" =~ ^beta\.([0-9]+)$ ]]; then echo "${base}b${BASH_REMATCH[1]}"; else echo "${base}${suffix//[-.]/}"; fi
}
BUNDLE_VERSION="$(bundle_version "$VERSION")"
APP="build/Better Terminal.app"

if [[ -n "${SIGN_IDENTITY:-}" && -z "${SPARKLE_PUBLIC_ED_KEY:-}" ]]; then
  echo "error: SPARKLE_PUBLIC_ED_KEY is required for a signed/release build (see docs/release.md, Sparkle setup)" >&2
  exit 1
fi

command -v xcodegen >/dev/null || { echo "error: xcodegen not found (brew install xcodegen)" >&2; exit 1; }
xcodegen generate

rm -rf build/DerivedData "$APP"
xcodebuild -project BetterTerminal.xcodeproj -scheme BetterTerminal -configuration Release \
  -derivedDataPath build/DerivedData -destination 'generic/platform=macOS' \
  ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="" \
  MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$BUNDLE_VERSION" \
  SPARKLE_PUBLIC_ED_KEY="${SPARKLE_PUBLIC_ED_KEY:-}" \
  -skipPackagePluginValidation -skipMacroValidation build

BUILT="$(find build/DerivedData/Build/Products/Release -maxdepth 1 -name '*.app' | head -1)"
[[ -n "$BUILT" ]] || { echo "error: built app not found" >&2; exit 1; }
mkdir -p build
ditto "$BUILT" "$APP"

FW="$APP/Contents/Frameworks/Sparkle.framework"
[[ -d "$FW" ]] || { echo "error: Sparkle.framework is not embedded in the app" >&2; exit 1; }
# Better Terminal is not sandboxed, so Sparkle's sandbox-only XPC helpers are not needed.
rm -rf "$FW/Versions/B/XPCServices" "$FW/XPCServices"

if [[ -n "${SIGN_IDENTITY:-}" ]]; then
  # Sign inside-out (helpers, then the framework, then the app) so notarization accepts every nested binary.
  AUTOUPDATE="$(find "$FW" -type f -name Autoupdate | head -1)"
  UPDATER_APP="$(find "$FW" -type d -name Updater.app | head -1)"
  [[ -n "$AUTOUPDATE" && -n "$UPDATER_APP" ]] || { echo "error: Sparkle's Autoupdate/Updater.app not found in $FW" >&2; exit 1; }
  codesign --force --timestamp --options runtime --sign "$SIGN_IDENTITY" "$AUTOUPDATE"
  codesign --force --timestamp --options runtime --sign "$SIGN_IDENTITY" "$UPDATER_APP"
  codesign --force --timestamp --options runtime --sign "$SIGN_IDENTITY" "$FW"
  codesign --force --timestamp --options runtime --entitlements Resources/BetterTerminal.entitlements --sign "$SIGN_IDENTITY" "$APP"
else
  echo "warning: SIGN_IDENTITY not set — ad-hoc signing (not distributable)" >&2
  codesign --force --sign - --deep "$APP"
fi
codesign --verify --deep --strict --verbose=2 "$APP"
echo "Built $APP ($VERSION, build $BUNDLE_VERSION)"
