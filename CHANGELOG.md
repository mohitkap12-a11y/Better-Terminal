# Changelog

All notable changes. Release notes shown in the update window live in `docs/release-notes/`.

## [Unreleased]
### Fixed
- Right-clicking a terminal now selects that pane first (active pane and keyboard), so Paste and ⌘V go to the pane you right-clicked and not the one you were in before.

### Added
- The collapsed sidebar opens while the pointer is over it (so you can switch workspace or tab) and closes when it leaves. It floats over the terminals, so they do not resize.

### Changed
- Sidebar redesign: a soft accent wash, glowing icon and sliding indicator on the selected row; an input-style Search field with the ⌘K key cap; workspace rows show a count pill while tabs run and a dot when a command failed; a footer with the version and what is running; a collapse button that glows on hover; the whole sidebar and its labels animate with one easing. Search, Shortcuts and Settings stay at the bottom. Every option is unchanged.
- README and website screenshots show the new sidebar.

### Fixed
- Broadcast input now repeats typing in the other panes (it needs the key events, which the terminal engine does not hand to the app).
- Dragging a tab in the tab bar no longer moves the window: the tab strip is its own non-draggable host, and only the empty part of it moves the window.
- Imported dark themes no longer give an unreadable window when the Mac or the Mode setting is light: an imported theme now decides light or dark, and the Mode control is dimmed with an explanation.
- Removing an imported theme updates Settings immediately.

### Changed
- The quick terminal is now a small 580 × 340 window in the bottom-right corner (it used to cover the top of the screen). Esc hides it, and it opens in the folder of the Finder window or tab you came from (Finder access needs a one-time permission).

### Added
- Quick terminal key choice (⌃`, ⌥Space, ⌃⌥Space, F12), a status line saying whether the key registered, and a "Show now" button.
- Command palette: Actions and Commands tabs (→ / ←), your last three commands on top, the last 30 commands from every terminal on the Commands tab, and wrap-around arrow keys.
- Right-click menu in terminals (copy, paste, select all, open link, find, split, copy last output, clear). Links underline on hover. Setting "Right-click copies selected text" keeps the old behaviour.
- All shortcuts listed in Settings, grouped, plus a searchable Shortcuts popup (⌘/, or the Shortcuts button below Search in the sidebar; Settings has a button for it too).
- Walkthrough covers the new features.
- Documentation site (`/docs`), built from `docs/site-src`, and updated website and README with new screenshots.

### Added
- Drag to reorder workspaces and tabs; drag a tab onto a workspace in the sidebar to move it there.
- Right-click a tab (in the tab bar or the sidebar) to rename it, move it to another workspace or a new one, or close it. Double-click a tab to rename.
- Workspaces and their tabs are listed in the sidebar and fold away: fold the whole WORKSPACES list from its heading, or one workspace's tabs from the chevron on its row (remembered between launches). Click any tab to jump to it, even in another workspace.
- Support: Settings → Support (sponsor, donate, star, report an issue), a support page on the website, and the Sponsor button on the repository.
- Middle-click a tab (tab bar, sidebar or pane header) to close it, like a browser.
- Right-click a workspace → New Terminal.
- Closing a tab that is still running a command asks first, with "Don't ask me again". Turn it back on in Settings → Terminal.

- Split panes: ⌘D splits right, ⇧⌘D splits down (a new pane next to the current one, same folder).
- Find in terminal (⌘F, ⌘G / ⇧⌘G) with highlighted matches.
- Tab status: a spinner while a command runs, a red dot when one failed in a tab you have not looked at; notifications when commands that took 10 s or more finish in another tab (Settings → Terminal).
- Workspace templates: save a workspace (layout and folders), add startup commands, open it again in one click (Settings, sidebar menu, palette).
- Palette search covers command history from every tab and workspace.
- Broadcast input: type once, send to every pane of a workspace (⌥⌘I).
- Quick terminal: ⌃` drops a terminal from the top of the screen (Settings → Terminal).
- Import themes (.itermcolors, Ghostty, kitty) and choose any monospaced font.
- Drag a pane's header onto another pane to swap them; right-click the folder in a pane header to reveal it in Finder or open it in VS Code.
- Copy last command output (⌥⌘C).
- Diagnostics: a log file and crash notes in ~/Library/Logs/BetterTerminal (Settings → About → Open Logs Folder); CI now also launches the app and runs a command.

### Changed
- Pane layouts shrink to fit: a 1×6 layout with 5 tabs shows 1×5, with 2 tabs 1×2, and grows back as you add tabs. Your chosen layout is unchanged.

### Fixed
- Dragging a tab in the tab bar to reorder it no longer moves the whole window.
- Switching tabs from the sidebar or tab bar is instant (single clicks no longer wait for a possible double-click), and terminals no longer redraw on every selection change.

## [0.1.0]
First release. See [docs/release-notes/v0.1.0.md](docs/release-notes/v0.1.0.md).
