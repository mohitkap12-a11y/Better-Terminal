---
title: Tab status and notifications
group: Find
order: 3
---
# Tab status and notifications

Better Terminal watches your commands (through the [shell integration](shell-integration.html)) so it can tell you what is going on in tabs you are not looking at.

## Status badges

| Badge | Meaning | Where |
| --- | --- | --- |
| Spinner | A command is running. | Tab chip, sidebar tab row, pane header. |
| Red dot | The last command in that tab failed (non-zero exit) while you were looking elsewhere. | Same places. |

The red dot disappears as soon as you open the tab. A tab you are looking at never shows it.

## Notifications for long commands

When a command that ran **10 seconds or longer** finishes in a tab you are not looking at, macOS shows a notification with the tab name, the command, whether it succeeded and how long it took. Clicking it opens the tab.

"Not looking at" means the app is in the background, or the tab is not the one on screen, or Settings is open.

The first time, macOS asks for permission to send notifications. If you decline, you can allow them later in System Settings ▸ Notifications ▸ Better Terminal.

Turn the feature off in Settings ▸ Terminal ▸ **Notify when long commands finish**.

## Limits

- Commands are detected by the shell integration, which supports zsh, bash and fish. Other shells show no badges.
- A command typed into another program (for example inside an SSH session or a REPL) counts as one running command from the point of view of your shell.
