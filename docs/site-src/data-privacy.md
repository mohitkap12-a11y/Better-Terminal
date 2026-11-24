---
title: Your data and privacy
group: Under the hood
order: 2
---
# Your data and privacy

Better Terminal has no account, no analytics and no telemetry. The only network request it makes is the update check, which goes to GitHub.

## Where things are stored

Everything lives under `~/Library/Application Support/BetterTerminal`:

| Path | Contents |
| --- | --- |
| `state.json` | Workspaces, tabs, layouts, templates, imported themes and settings. |
| `history/<tab>.jsonl` | The commands of each tab (command, folder, exit status, time, duration). No output. |
| `snapshots/<tab>.txt` | The text of each terminal, for [resume](resume.html). Can contain anything you printed. |
| `shell-integration/` | The hook scripts for [shell integration](shell-integration.html). |
| `events/` | Temporary per-tab event files, removed when a tab closes. |

Logs are in `~/Library/Logs/BetterTerminal`:

| File | Contents |
| --- | --- |
| `app.log` | Launches, errors and a few events (for example, whether the quick terminal key registered). Rotated at 1 MB. |
| `crash.log` | A note when the app crashes on a fatal signal. |

The logs never contain commands or terminal text.

## Controls

- Turn off **Resume on relaunch** to stop saving terminal text (turning it off also deletes the saved text).
- **Saved terminal text ▸ Clear** deletes snapshots at any time.
- Closing a tab deletes its history and text; deleting a workspace deletes those of all its tabs.
- To remove everything, quit the app and delete the two folders above.

## What leaves your Mac

Only the update check: a request for the appcast file on GitHub, which includes the app version. Downloads of new versions come from GitHub Releases. Notifications for long commands are local. Nothing in the app sends your commands, output or folders anywhere.
