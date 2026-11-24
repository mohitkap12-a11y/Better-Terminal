# Changelog

All notable changes. Release notes shown in the update window live in `docs/release-notes/`.

## [Unreleased]
### Added
- Drag to reorder workspaces and tabs; drag a tab onto a workspace in the sidebar to move it there.
- Right-click a tab (in the tab bar or the sidebar) to rename it, move it to another workspace or a new one, or close it. Double-click a tab to rename.
- Workspaces and their tabs are listed in the sidebar and fold away: fold the whole WORKSPACES list from its heading, or one workspace's tabs from the chevron on its row (remembered between launches). Click any tab to jump to it, even in another workspace.
- Support: Settings → Support (sponsor, donate, star, report an issue), a support page on the website, and the Sponsor button on the repository.
- Middle-click a tab (tab bar, sidebar or pane header) to close it, like a browser.
- Right-click a workspace → New Terminal.
- Closing a tab that is still running a command asks first, with "Don't ask me again". Turn it back on in Settings → Terminal.

### Changed
- Pane layouts shrink to fit: a 1×6 layout with 5 tabs shows 1×5, with 2 tabs 1×2, and grows back as you add tabs. Your chosen layout is unchanged.

### Fixed
- Dragging a tab in the tab bar to reorder it no longer moves the whole window.
- Switching tabs from the sidebar or tab bar is instant (single clicks no longer wait for a possible double-click), and terminals no longer redraw on every selection change.

## [0.1.0]
First release. See [docs/release-notes/v0.1.0.md](docs/release-notes/v0.1.0.md).
