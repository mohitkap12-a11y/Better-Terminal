---
title: Command history and search
group: Find
order: 1
---
# Command history and search

## What is recorded

For zsh, bash and fish, Better Terminal records every command you run, per tab:

- the command text,
- the folder it ran in,
- the exit status (success or failed),
- the start time and how long it took.

Only **commands** are stored, never their output. History is kept in `~/Library/Application Support/BetterTerminal/history/`, one file per tab, and survives quitting and rebooting. See [Shell integration](shell-integration.html) for how it is captured.

## History of the current tab

Click the clock button on a pane, or press ⇧⌘H.

| Key | Action |
| --- | --- |
| Type | Search the tab's history. |
| ↑ ↓, Page Up/Down | Move through results while the search field keeps focus. |
| ⏎ | Put the command at the prompt, without running it. |
| ⌘⏎ | Run it. |
| Click | Put it at the prompt. |
| Double-click | Run it. |

The red-circle toggle shows only commands that failed. Right-click a command for **Run again**, **Insert at prompt**, **Save Command**, **Copy command** or **Copy directory**. The star at the end of a row (or ⌘S) saves the command; see [Saved commands](#saved).

Inserting replaces what is currently typed at the prompt. Multi-line commands are inserted safely: they are pasted as one block and never run until you press return.

## The command palette {#palette}

Press ⌘K. The palette has three tabs, shown under the search field: Actions, Commands and Saved. → and ← move between them.

### Actions

Open by default. It lists the actions: new tab and workspace, split, find, broadcast, copy last output, quick terminal, templates, workspaces, layouts, themes and appearance. Type to filter the actions.

### Commands

Press **→** (or click the tab) to switch. It lists the **last 30 commands from every terminal in every workspace**, each with its workspace and tab. Type to search all history, not just recent items. A star marks commands you have saved. Press **←** to go back.

| Key | Action |
| --- | --- |
| ↑ ↓ | Move. Going up from the first item wraps to the last, and down from the last wraps to the first. |
| ⏎ | Open that command's tab and put the command at its prompt. |
| ⌘⏎ | Open the tab and run the command. |
| ⌘S | Save the command (or remove it from Saved). |
| → / ← | Next / previous tab. |
| esc, or a click anywhere outside | Close. |

### Saved {#saved}

Press **→** from Commands. It lists the commands you saved, in your order. Saved commands belong to you, not to a tab: picking one puts it in **the terminal that has focus**, whichever workspace or tab that is. Type to search by name or command.

| Key | Action |
| --- | --- |
| ⏎ | Put the command at the focused terminal's prompt. |
| ⌘⏎ | Run it in the focused terminal. |
| ⌘S | Remove it from Saved. |

Ways to save a command:

- the star on a row of a tab's history (⇧⌘H), or ⌘S on the highlighted row, or right-click ▸ **Save Command**;
- ⌘S on a command in ⌘K ▸ Commands;
- Settings ▸ Saved commands ▸ **Add Command**.

Settings ▸ Saved commands is where you give a command a name (for example "Deploy staging" for `./deploy.sh --env=staging`; the palette then shows the name with the command beside it), edit it, reorder it or delete it. Saved commands are kept with the app's settings, so closing a tab or deleting a workspace does not remove them.

## Tips

- Ran something in another workspace and can't remember where? Search for it on the Commands tab and press ⏎: you land in the right tab.
- History is separate per tab on purpose, so a build tab and a database tab do not mix. The Commands tab is where you look across tabs.
- Closing a tab deletes its history, and deleting a workspace deletes the history of its tabs.
