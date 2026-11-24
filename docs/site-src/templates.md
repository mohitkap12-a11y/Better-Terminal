---
title: Workspace templates
group: Organise
order: 3
---
# Workspace templates

A template is a saved workspace setup: the layout and, for each tab, a title, a folder and an optional command to run when it opens. Opening a template creates a new workspace with those tabs.

## Create a template

- Right-click a workspace in the sidebar ▸ **Save as Template**, or
- Settings ▸ Workspace templates ▸ **Save as Template** (saves the current workspace), or
- the command palette ▸ **Save Workspace as Template**.

This captures the layout and each tab's folder and title. Commands are added in the editor.

## Edit a template

Settings ▸ Workspace templates ▸ **Edit**.

| Field | Meaning |
| --- | --- |
| Name | Shown in Settings and the palette. |
| Layout | The grid the new workspace starts with. |
| Title | The tab's name. Leave it as `Terminal` for the default behaviour. |
| Folder | Where the tab's shell starts. |
| Startup command | Typed into the shell once, when the tab first opens. Optional. |

Add or remove tabs with **Add Tab** and the minus button.

## Open a template

Settings ▸ Workspace templates ▸ **Open**, or the command palette ▸ **New Workspace from "name"**.

## Startup commands

A startup command is typed after the shell has finished its start-up files and shown its first prompt, so slow or interactive `.zshrc` files do not swallow it. It runs **once**: it is cleared as soon as it has run, so reopening the app never repeats it. If the shell never reports a prompt within 15 seconds (for example a shell without integration), the command is skipped rather than typed blindly, and a note goes to the log.

## Ideas

- A dev setup: a 1×3 layout with `npm run dev`, `npm test -- --watch` and an empty tab.
- Servers: one tab per host with `ssh` commands, plus [broadcast](terminal.html#broadcast) for shared commands.
- Docs writing: a preview server and an editor folder.
