<p align="center">
  <img src="site/assets/icon-512.png" width="128" alt="Better Terminal icon">
</p>

<h1 align="center">Better Terminal</h1>

<p align="center">
  A fast, native macOS terminal with workspaces, pane layouts and per-tab history,<br>
  that remembers where you left off.
</p>

<p align="center">
  <a href="https://github.com/mohitkap12-a11y/Better-Terminal/releases/latest/download/BetterTerminal.dmg"><b>Download for macOS</b></a> ·
  <a href="https://mohitkap12-a11y.github.io/Better-Terminal/">Website</a> ·
  <a href="https://github.com/mohitkap12-a11y/Better-Terminal/releases">Releases</a>
</p>

<p align="center">
  <a href="https://github.com/mohitkap12-a11y/Better-Terminal/actions/workflows/ci.yml"><img src="https://github.com/mohitkap12-a11y/Better-Terminal/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-lightgrey" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Swift-5.9-orange" alt="Swift 5.9">
</p>

<p align="center">
  <img src="docs/images/app-dark.png" alt="Better Terminal: sidebar with workspaces, tabs and four terminal panes (illustration)" width="860">
</p>

## Features

- **Workspaces.** One per project, each with its own tabs, layout and folders. Switch from the sidebar or with `⌃⌘1–9`.
- **Pane layouts.** Tabs fill a grid: 1×2, 2×1, 2×2 or any custom rows × columns. New tabs follow the layout.
- **History for every tab.** Click the clock (or `⇧⌘H`), type to search, `↑↓` to move, `⏎` to insert, `⌘⏎` to run. Right-click a command to copy it or run it again.
- **Move between panes.** `⌘` + arrow keys jump to the neighbouring terminal; the pane you land on pulses.
- **Resume on relaunch.** Quit and reopen: workspaces, tabs, layouts, folders, history and the text on screen come back. A fresh shell starts below it (running programs can't be revived). Switch it off in Settings if you handle secrets.
- **Command palette.** `⌘K` for workspaces, layouts, themes, settings and past commands.
- **Soft colour themes.** Default, Mist, Sage, Rose, Lavender, Sand, Nord, Black, in light and dark. System follows macOS.
- **Right-click copies** selected text.
- **Updates built in** ([Sparkle](https://sparkle-project.org)), Stable by default or Beta in Settings.
- **Private.** No account and no telemetry; the only network call is the update check.

## Install

1. Download the DMG from the [latest release](https://github.com/mohitkap12-a11y/Better-Terminal/releases/latest).
2. Drag **Better Terminal** to Applications.

Requires macOS 14 Sonoma or later. Apple silicon and Intel.

## Keyboard shortcuts

| Action | Keys |
| --- | --- |
| New tab / close tab | `⌘T` / `⌘W` |
| Move between panes | `⌘←` `⌘→` `⌘↑` `⌘↓` |
| Command palette | `⌘K` |
| Command history | `⇧⌘H` |
| Pane layout | `⌥⌘L` |
| New workspace | `⇧⌘N` |
| Switch workspace | `⌃⌘1`–`⌃⌘9` |
| Bigger / smaller text | `⌘+` / `⌘−` |
| Settings | `⌘,` |

## Your data

Everything lives in `~/Library/Application Support/BetterTerminal`: `state.json` (workspaces, tabs, layouts, settings), `history/` (commands per tab), `snapshots/` (terminal text for resume). Settings → Terminal has a switch for resume and a Clear button.

## Build from source

Needs macOS 14+, Xcode 15+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
git clone https://github.com/mohitkap12-a11y/Better-Terminal.git
cd Better-Terminal
xcodegen generate
open BetterTerminal.xcodeproj      # run the BetterTerminal scheme
swift test                         # tests for the core logic
```

The terminal view is [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm), behind a small protocol so another engine (libghostty) can replace it. See [ARCHITECTURE.md](ARCHITECTURE.md) for how the pieces fit and [DESIGN.md](DESIGN.md) for the UI rules.

## Releasing

Tag-driven: `v1.2.3` is a stable release, `v1.2.3-beta.1` goes to the Beta channel, `v1.2.3-rc1` is a dry run. Signing, notarization, the DMG and the Sparkle feed are automated. See [docs/release.md](docs/release.md).

## Website

The site in [`site/`](site) is plain HTML and CSS, deployed to GitHub Pages by `.github/workflows/pages.yml`. To show real screenshots instead of the illustration, run `scripts/screenshot.sh dark` (and `light`) on a Mac with the app open.

## License

Open source. See the repository for the license file.
