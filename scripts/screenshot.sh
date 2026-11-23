#!/usr/bin/env bash
# Captures the real Better Terminal window for the website and README. Run on your Mac with the app open.
#   scripts/screenshot.sh dark     -> site/assets/screenshots/app-dark.png   (and docs/images/app-dark.png)
#   scripts/screenshot.sh light    -> site/assets/screenshots/app-light.png
# Tips: set Appearance in Settings first, use a 2x2 layout with a few tabs, hide personal paths.
# The first run asks for Screen Recording permission for your terminal app (System Settings > Privacy & Security).
set -euo pipefail
cd "$(dirname "$0")/.."
NAME="${1:?usage: screenshot.sh dark|light}"
OUT="site/assets/screenshots/app-${NAME}.png"
mkdir -p site/assets/screenshots docs/images

WID="$(swift -e '
import CoreGraphics
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
for w in list {
  let owner = w[kCGWindowOwnerName as String] as? String ?? ""
  let layer = w[kCGWindowLayer as String] as? Int ?? 1
  if owner == "Better Terminal" && layer == 0, let id = w[kCGWindowNumber as String] as? Int { print(id); break }
}')"
[[ -n "$WID" ]] || { echo "error: open the Better Terminal window first" >&2; exit 1; }
screencapture -l"$WID" -o "$OUT"          # -o: no window shadow
cp "$OUT" "docs/images/app-${NAME}.png"
echo "Saved $OUT (the website uses it automatically, replacing the illustration)"
