# Changelog

All notable changes. Release notes shown in the update window live in `docs/release-notes/`.

## [Unreleased]

## [0.3.0] - 2026-11-28
Saved commands, an MIT license and Homebrew install. Release notes shown in the update window: [docs/release-notes/v0.3.0.md](docs/release-notes/v0.3.0.md).

### Added
- **Saved commands.** Keep the commands you use often and run them in whichever terminal is focused. Save one with the star in a tab's history (⇧⌘H, or ⌘S there), or with ⌘S in ⌘K ▸ Commands. Use them from the new **Saved** tab in ⌘K (→ past Commands): ⏎ puts the command at the prompt, ⌘⏎ runs it, ⌘S removes it. Give them names, reorder, edit or add them in Settings ▸ Saved commands.
- MIT license (`LICENSE`) and a list of third-party components (`THIRD_PARTY_NOTICES.md`); the app's copyright line, README and website say so.
- **Homebrew.** `brew install --cask mohitkap12-a11y/better-terminal/better-terminal`; stable releases update the tap automatically.

## [0.2.0] - 2026-11-25
Split panes, a quick terminal, find, workspace templates and a redesigned sidebar. Release notes shown in the update window: [docs/release-notes/v0.2.0.md](docs/release-notes/v0.2.0.md).

### Added
- **Split panes.** ⌘D splits right, ⇧⌘D splits down (the new pane opens in the same folder). Drag a pane's header onto another pane to swap them.
- **Quick terminal.** A global key (⌃` by default; ⌥Space, ⌃⌥Space and F12 are the alternatives, Settings → Terminal) pops up a small 580 × 340 terminal in the bottom-right corner, in the folder of the front Finder window or of the tab you came from. Esc or the key hides it. A status line says whether the key registered, and "Show now" opens it without the key. (Reading the Finder folder needs a one-time permission.)
- **Find in terminal.** ⌘F, ⌘G / ⇧⌘G, with highlighted matches.
- **Workspace templates.** Save a workspace's layout and folders, add startup commands, open it again in one click (sidebar menu, Settings, palette). Commands run once, after the shell's first prompt.
- **Command palette (⌘K)** has Actions and Commands tabs (→ / ←). Commands lists the last 30 commands from every terminal in every workspace and searches all history; ⏎ puts one at that tab's prompt, ⌘⏎ runs it. Arrow keys wrap around.
- **Shortcuts popup (⌘/)**, also reachable from the sidebar and Settings: searchable, ↑↓ move the highlight, ⏎ (or a double-click) runs the shortcut. Gestures and key combinations that cannot be run are dimmed and explained. Settings → Shortcuts lists everything, grouped.
- **Tab status and notifications.** A spinner while a command runs, a red dot when one failed in a tab you have not looked at, and a notification when a command that took 10 s or more finishes elsewhere (Settings → Terminal).
- **Broadcast input.** ⌥⌘B repeats what you type (and paste) in every pane of the workspace.
- **Right-click menu in terminals:** copy, paste, select all, open link, find, split, copy last output, clear. Links underline on hover. "Right-click copies selected text" keeps the old behaviour.
- **Copy last command output** (⌥⌘C).
- **Themes and fonts.** Import iTerm2 (.itermcolors), Ghostty and kitty themes; choose any monospaced font.
- **Sidebar:** the collapsed sidebar opens while the pointer is over it; ⌃⌘S (View ▸ Toggle Sidebar) collapses or expands it.
- Drag to reorder workspaces and tabs in the sidebar and drop a tab onto a workspace to move it; right-click a tab or workspace to rename, move, add a terminal or save a template; fold the WORKSPACES list or a workspace's tabs (remembered).
- Middle-click a tab (tab bar, sidebar, pane header) to close it. Closing a tab that is running a command asks first, with "Don't ask me again" (Settings → Terminal turns it back on).
- Right-click the folder in a pane header to reveal it in Finder or open it in VS Code.
- Settings → Support (sponsor, donate, star, report an issue), a log folder and crash notes for bug reports (Settings → About → Open Logs Folder), and the Walkthrough covers the new features.
- A documentation site (`/docs`) and a refreshed website and README.

### Changed
- **Sidebar redesign:** a soft accent wash, glowing icon and sliding indicator on the selected row; a count pill on workspaces while tabs run and a dot when a command failed; a footer with the version and what is running; an edge button that glows on hover; one easing for every animation. Search, Shortcuts and Settings stay at the bottom; every option is unchanged.
- Pane layouts shrink to fit: a 1×6 layout with 5 tabs shows 1×5, with 2 tabs 1×2, and grows back as you add tabs. Your chosen layout is unchanged.
- The search palette (⌘K) and Shortcuts popup (⌘/) are a card over a dimmed backdrop: a click anywhere outside closes them, as does esc. The palette's list now uses the theme colours.
- Tabs in the top tab bar are no longer draggable (dragging one also moved the whole window); reorder and move tabs in the sidebar. The chips still accept a tab dropped from the sidebar.
- The broadcast shortcut is ⌥⌘B (Option+I is a dead key on a US keyboard and did not fire reliably).

### Fixed
- Typing always goes to the active terminal: after a new tab, split, workspace switch, returning from Settings or a restarted shell, the keyboard could stay in the previous pane.
- Right-clicking a pane selects it first, so Paste and ⌘V go to the pane you right-clicked.
- Switching tabs is instant: single clicks no longer wait for a double-click, and terminals no longer redraw on every selection change.
- Imported dark themes are readable when the Mac or Mode setting is light (an imported theme decides light or dark); removing an imported theme updates Settings at once.
- Reaching the pin button of a collapsed sidebar no longer opens it under the pointer, or closes it before you can click.
- ⌘⏎ in command history (⇧⌘H) and in the palette runs the highlighted command.
- Broadcast input repeats typing in the other panes.
- The running-command count ignores deleted tabs and ended shells.

## [0.1.0]
First release. See [docs/release-notes/v0.1.0.md](docs/release-notes/v0.1.0.md).
