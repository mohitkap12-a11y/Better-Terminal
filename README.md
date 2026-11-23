# Better-Terminal

## Build (macOS 14+, Xcode 15+)
```bash
brew install xcodegen
xcodegen generate
open BetterTerminal.xcodeproj   # or: xcodebuild -scheme BetterTerminal build
swift test                      # core logic tests
```

## Features
Workspaces, pane layouts (1×2, 2×1, 2×2 …), per-tab command history that survives restarts, command palette (⌘K), soft colour themes, in-app updates (Sparkle). Right-click on selected text copies it.

## Releasing
See [docs/release.md](docs/release.md).
