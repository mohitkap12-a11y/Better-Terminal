# Releasing

Needs an Apple Developer account ($99/yr) and a "Developer ID Application" certificate.

1. Local: `TEAM_ID=… NOTARY_PROFILE=bt-notary scripts/release.sh 0.1.0` -> notarized DMG + sha256.
2. CI: add secrets `CERT_P12_BASE64`, `CERT_PASSWORD`, `APPLE_ID`, `APPLE_APP_PASSWORD`, `TEAM_ID`, then `git tag v0.1.0 && git push --tags`.
3. Homebrew: update `version` and `sha256` in `Casks/better-terminal.rb`; publish it in a tap repo named `homebrew-tap`
   (`brew install --cask <user>/tap/better-terminal`).

Untested: these scripts were written without access to a Mac; expect small fixes on first run.
