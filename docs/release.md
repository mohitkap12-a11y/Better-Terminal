# Release process

Better Terminal is distributed directly (Developer ID signed, notarized DMG) from GitHub Releases, with in-app updates
through Sparkle. Everything after tagging is automated by `.github/workflows/release.yml`. The setup is the same as
MacPeek's, and you can reuse the same Apple signing keys and Sparkle key pair.

## Quick reference

```bash
# 1. Add docs/release-notes/vX.Y.Z.md (shown in the update window), merge to main.

# Preview for opted-in Macs only (published to appcast-beta.xml, never to appcast.xml).
git tag v0.2.0-beta.1 && git push origin v0.2.0-beta.1

# Optional dry run (GitHub pre-release only; no feed touched).
git tag v0.1.0-rc1 && git push origin v0.1.0-rc1

# Real release.
git tag v0.1.0 && git push origin v0.1.0
```

- The tag **must** start with `v`. Never create the release by hand in the GitHub UI: the workflow attaches the DMG.
- `vX.Y.Z-beta.N` is a preview; any other hyphenated tag is a dry run. Both are pre-releases (never "latest").

## One-time setup

Reuse the values from the MacPeek repository: add these to **Better-Terminal → Settings → Secrets and variables → Actions**.

| Name | Kind | What |
| --- | --- | --- |
| `DEVELOPER_ID_CERT_P12_BASE64` | secret | Developer ID Application certificate, `.p12`, base64 |
| `DEVELOPER_ID_CERT_PASSWORD` | secret | password of that `.p12` |
| `DEVELOPER_ID_IDENTITY` | secret | e.g. `Developer ID Application: Your Name (TEAMID)` |
| `NOTARY_API_KEY_P8_BASE64` | secret | App Store Connect API key (`.p8`), base64 |
| `NOTARY_API_KEY_ID` | secret | its key id |
| `NOTARY_API_ISSUER_ID` | secret | its issuer id |
| `SPARKLE_ED_PRIVATE_KEY` | secret | Sparkle EdDSA private key (signs updates) |
| `SPARKLE_PUBLIC_ED_KEY` | **variable** | matching public key, baked into the app |

Base64 a file with `base64 -i file | pbcopy`.

### Sparkle

Reusing MacPeek's key pair means one key signs both apps. To make a separate pair for Better Terminal instead, run
Sparkle's `generate_keys` (inside the resolved Sparkle package under `build/DerivedData/SourcePackages/artifacts`),
store the private key as `SPARKLE_ED_PRIVATE_KEY` and the printed public key as `SPARKLE_PUBLIC_ED_KEY`.

The app reads `SUFeedURL` (`releases/latest/download/appcast.xml`), so the newest **stable** release is offered to every
Mac. Updates are verified against `SUPublicEDKey`, which `scripts/build-app.sh` passes to the build. Without the key (a
local Xcode build) the updater is off and Settings → Updates says so.

## What the workflow does

1. Picks the channel from the tag, checks the keys and the release notes exist.
2. `swift test`.
3. Imports the certificate, builds a universal app (`scripts/build-app.sh`), signs Sparkle and the app inside-out with
   the hardened runtime.
4. Creates the DMG (`scripts/make-dmg.sh`), notarizes and staples it.
5. Signs the DMG for Sparkle and writes `appcast.xml` / `appcast-beta.xml`.
6. Publishes the GitHub Release (`BetterTerminal-X.Y.Z.dmg`, `BetterTerminal.dmg`, `SHA256SUMS`, `appcast.xml`) and
   refreshes the `preview-feed` pre-release.

## Preview builds (beta)

```bash
defaults write com.better.terminal receivePreviewBuilds -bool YES     # opt in
defaults delete com.better.terminal receivePreviewBuilds              # back to stable
```

## Local build

```bash
brew install xcodegen
scripts/build-app.sh 0.1.0          # ad-hoc signed, for local use
scripts/make-dmg.sh 0.1.0
```

## Homebrew cask

After a stable release, update `version` and `sha256` (from `SHA256SUMS`) in `Casks/better-terminal.rb` and publish
it in a tap repository (`homebrew-tap`): `brew install --cask <user>/tap/better-terminal`.

## Troubleshooting

- *"SPARKLE_… not set"*: add the secret / variable above.
- *Notarization rejected*: run `xcrun notarytool log <id> --key … --key-id … --issuer …` for the reason.
- *Updates do nothing in a local build*: expected, there is no public key in it.
