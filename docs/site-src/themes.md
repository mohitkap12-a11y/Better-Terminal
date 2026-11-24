---
title: Themes and fonts
group: Look
order: 1
---
# Themes and fonts

## Appearance mode

Settings ▸ Appearance ▸ **Mode**:

| Mode | Behaviour |
| --- | --- |
| System | Follows the macOS light or dark setting, and changes with it. |
| Light | Always light. |
| Dark | Always dark. |

## Built-in themes

Eight palettes, each with a light and a dark variant: **Default**, **Mist**, **Sage**, **Rose**, **Lavender**, **Sand**, **Nord** and **Black**. They are deliberately soft: low contrast surfaces and a single accent colour. A theme sets the window, the sidebar, the terminal background and text, and the accent.

Pick one in Settings, or from the command palette (type `theme`).

## Import a theme {#import}

Settings ▸ Appearance ▸ **Import…** accepts:

- iTerm2 colour presets (`.itermcolors`),
- Ghostty theme files and kitty-style theme text (lines such as `background = #1e1e2e`, `foreground = #cdd6f4`, `palette = 4=#89b4fa`, or `color4 #89b4fa`).

You can select several files at once. An imported theme sets:

- the terminal background and text colour,
- the 16 ANSI colours when the file defines all of them (otherwise the default palette is kept),
- the accent colour (ANSI blue when available),
- the window and sidebar, derived from the background colour.

Remove an imported theme by right-clicking it in the grid and choosing **Remove Theme**.

### Imported themes and light or dark mode

An imported theme is a single look: it is either dark or light, decided by the brightness of its background. While one is selected, the window uses the matching macOS appearance regardless of the Mode setting, so text stays readable, and the Mode control is dimmed with a note. Select a built-in theme to use System, Light and Dark again.

## Fonts

Settings ▸ Terminal ▸ **Font** lists every monospaced font installed on your Mac. **System Mono** is the default. **Font size** is 9 to 32 pt and also follows ⌘+ and ⌘−.

Ligatures are not supported by the terminal engine (SwiftTerm), so fonts with programming ligatures are shown without them.
