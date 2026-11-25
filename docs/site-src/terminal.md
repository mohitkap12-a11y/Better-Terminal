---
title: Using the terminal
group: Find
order: 2
---
# Using the terminal

## Find in the terminal {#find}

Press ⌘F to open the find bar at the top right of the focused pane. Typing searches the whole scrollback and selects the first match, scrolling it into view.

| Key | Action |
| --- | --- |
| ⏎ or ⌘G | Next match. |
| ⇧⏎ or ⇧⌘G | Previous match. |
| esc | Close the bar and clear the highlights. |

"No matches" appears in red when nothing is found. The search is case-insensitive. The scrollback holds the last 5,000 lines of each terminal.

## The right-click menu {#menu}

Right-click inside a terminal:

| Item | What it does |
| --- | --- |
| Copy | Copies the selection. Disabled when nothing is selected. |
| Paste | Pastes the clipboard. |
| Select All | Selects the whole terminal text. |
| Open link | Appears when there is a URL on screen or in your selection. With one URL it shows its host; with several it opens a submenu. |
| Find… | Opens the find bar in this pane. |
| Split Right / Split Down | Splits this pane. |
| Copy Last Command Output | See below. |
| Clear Screen | Sends ⌃L to the shell. |

If you prefer the older behaviour, turn on Settings ▸ Terminal ▸ **Right-click copies selected text**: with text selected, right-click copies it immediately instead of showing the menu.

## Links {#links}

URLs in the terminal are underlined when you hover them. Click one to open it in your browser. A link you select can also be opened from the right-click menu. Only `http`, `https` and `file` links are recognised.

## Copy last output {#last-output}

⌥⌘C (or right-click ▸ Copy Last Command Output) copies what the previous command printed in the focused pane.

It is taken from the terminal text added since the command started, so it works for ordinary commands. It is best-effort: if the output scrolled out of the 5,000-line scrollback, or a full-screen program such as `vim` redrew the screen, the result can be incomplete or empty.

## Broadcast input {#broadcast}

Broadcast repeats what you type in the focused pane in every other pane of the same workspace. It is for jobs like running the same command on several servers.

- Turn it on with ⌥⌘B (Pane menu or command palette). An orange **Broadcast** button appears in the tab bar; click it, or press ⌥⌘B again, to stop.
- It is a per-workspace switch and other workspaces are not affected.
- Typed text, return, tab, delete, escape, arrow keys, home and end, and ⌃-letter combinations are repeated, and so are pastes. Shortcuts that use ⌘ are never repeated.
- Only the focused pane is the source. Click the pane you want to type in.
- Be careful: every pane receives every key, including ones that run commands.

## Selection and clipboard

Click and drag to select, double-click to select a word. Standard ⌘C and ⌘V work.

## Text size

⌘+ and ⌘− change the text size in every pane (9 to 32 pt). Settings ▸ Terminal ▸ Font size has the same control.
