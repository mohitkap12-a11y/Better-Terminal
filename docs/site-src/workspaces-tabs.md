---
title: Workspaces and tabs
group: Organise
order: 1
---
# Workspaces and tabs

A **workspace** is a named group of tabs with its own layout. Use one per project: a workspace for the website, one for the API, one for ops.

A **tab** is one shell. Every tab is also a pane: the tabs of a workspace are shown side by side according to the [layout](panes-layouts.html).

## The sidebar

The sidebar lists your workspaces, each with its tabs underneath.

- Click a workspace to open it, or click any tab to jump straight to it, even in another workspace.
- Switch workspaces from the keyboard with ⌃⌘1 to ⌃⌘9.
- Collapse the sidebar to a narrow rail with the chevron at the top. It starts collapsed on a fresh install.
- Fold the whole list from the **WORKSPACES** heading, or fold one workspace's tabs with the chevron on its row (or **Hide Tabs** in its menu). The sidebar remembers what you folded.

## Workspace menu

Right-click a workspace for:

| Item | What it does |
| --- | --- |
| New Terminal | Adds a tab to that workspace and opens it. |
| Save as Template | Saves its layout and folders as a [template](templates.html). |
| Rename… | Renames the workspace. |
| Color | Changes its colour badge. |
| Hide Tabs / Show Tabs | Folds its tab list in the sidebar. |
| Delete… | Deletes the workspace, its tabs and their history. You always keep at least one workspace. |

Drag workspaces in the sidebar to reorder them.

## Tabs

- **New tab**: ⌘T, the **+** button, or the command palette. New tabs open in the folder of the previous tab and follow the workspace layout.
- **Rename**: double-click the tab, or right-click ▸ Rename…. Leave the name empty to go back to the title the shell sets.
- **Reorder**: drag a tab in the tab bar.
- **Move to another workspace**: drag it onto a workspace in the sidebar, or right-click ▸ Move to Workspace. Its shell, history and saved text move with it. Dropping it on **New Workspace** creates a workspace for it.
- **Close**: ⌘W, the ✕ on the tab, middle-click, or right-click ▸ Close Tab. A workspace always keeps at least one tab.

### Closing a tab that is busy

If a command is still running in the tab, Better Terminal asks before closing it, because closing stops the command. The alert has a **Don't ask me again** checkbox. You can turn the question back on in Settings ▸ Terminal ▸ **Confirm before closing a busy tab**.

"Busy" means a command started and has not finished, which the [shell integration](shell-integration.html) reports. A tab sitting at an empty prompt closes without asking.

## Tab titles

Tabs show the title your shell sets (usually the folder or the running command). Once you rename a tab, that name stays until you clear it.
