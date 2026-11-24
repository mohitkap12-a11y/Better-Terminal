---
title: Install and update
group: Start
order: 2
---
# Install and update

## Requirements

- macOS 14 (Sonoma) or later.
- Apple silicon or Intel.

## Install

1. Download the DMG from the [latest release](https://github.com/mohitkap12-a11y/Better-Terminal/releases/latest).
2. Open it and drag **Better Terminal** to Applications.
3. Open the app. The first launch shows a short walkthrough, which you can replay from Settings ▸ About or the command palette.

The app is signed with a Developer ID and notarized by Apple, so Gatekeeper opens it without warnings.

## Build from source

You need macOS 14+, Xcode 15+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
git clone https://github.com/mohitkap12-a11y/Better-Terminal.git
cd Better-Terminal
xcodegen generate
open BetterTerminal.xcodeproj
```

Run `xcodegen generate` again after pulling changes that add or remove files, because the Xcode project is generated and not committed.

## Updates {#updates}

Better Terminal uses [Sparkle](https://sparkle-project.org). It checks for updates in the background; you can also choose **Better Terminal ▸ Check for Updates…** at any time.

In Settings ▸ Updates:

| Setting | What it does |
| --- | --- |
| Check automatically | Look for updates in the background. |
| Download automatically | Download updates when they are found. |
| Update channel | **Stable** (default) gets tagged releases. **Beta** also gets pre-releases. |

Updates are verified with an EdDSA signature before they are installed. The only network request the app makes is the update check, to GitHub.

## Uninstall

Drag the app to the Trash. To remove your data too, delete `~/Library/Application Support/BetterTerminal` and `~/Library/Logs/BetterTerminal`.
