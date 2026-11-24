---
title: Panes and layouts
group: Organise
order: 2
---
# Panes and layouts

Every tab of a workspace is shown as a pane in a grid. The grid is the workspace's **layout**: rows × columns.

## Choosing a layout

Click the layout button at the right of the tab bar (⌥⌘L), or use the command palette. Presets are 1×1, 1×2, 2×1, 1×3, 3×1, 2×2, 2×3, 3×2 and 3×3; you can set any rows × columns up to 6 × 6. New tabs follow the layout and fill it row by row.

If you have more tabs than slots, extra rows are added so no tab is hidden.

## The grid fits your tabs {#fit}

Your chosen layout never changes by itself, but what is drawn adapts to the number of tabs:

| Layout | Tabs | Shown as |
| --- | --- | --- |
| 1×6 | 6 | 1×6 |
| 1×6 | 5 | 1×5 |
| 1×6 | 2 | 1×2 |
| 6×1 | 3 | 3×1 |
| 3×3 | 4 | 2×3 |

Add a tab and the grid grows back toward your layout. The layout button still shows the layout you picked.

## Split panes {#split}

- **Split Right**: ⌘D. A new pane opens to the right of the current one, in the same folder.
- **Split Down**: ⇧⌘D. A new pane opens below.

Splitting inserts the new tab right after the current one and grows the layout along that direction (columns for right, rows for down) up to six. Splits are also in the **Pane** menu and the command palette.

## Moving between panes

Hold ⌘ and press an arrow key to jump to the neighbouring pane. The pane you land on pulses briefly. At the end of a row or column nothing happens. Moving down into a shorter last row lands on its last pane.

You can also click a pane or its header.

## Swapping panes

Drag a pane's header (the strip with the folder path) onto another pane. The two swap places and the target shows an accent outline while you drag. Swapping works within one workspace.

## Pane header

Each pane has a header with its folder, a status badge (spinner or red dot, see [Tab status](notifications.html)) and the history button. Right-click the folder for **Reveal in Finder**, **Open in VS Code** (when installed), **Copy Path** and **Copy Last Output**. Middle-click the header to close the pane's tab.

## Broadcast

Turn on [broadcast](terminal.html#broadcast) to type in every pane of the workspace at once.
