---
title: Resume on relaunch
group: Organise
order: 4
---
# Resume on relaunch

Quit the app, restart your Mac, come back a week later: Better Terminal opens where you left off.

## What comes back

- Workspaces, their colours and names.
- Tabs, their titles and the order of tabs.
- Each workspace's layout and which tab was active.
- Each tab's folder. The new shell starts there.
- The **command history** of every tab.
- The **text that was on screen** (and in the scrollback), shown above a dim "restored from previous session" line, with a fresh shell below it.
- Window-level settings: theme, mode, font and so on.

## What does not

Running programs cannot be revived. A server, an editor or an SSH session that was running when you quit is gone; its last output is visible in the restored text, and you start it again.

## When it is saved

- Continuously: state changes are written a moment after they happen.
- Terminal text: every 30 seconds and when you quit. A crash or force-quit therefore loses at most the last 30 seconds of text.
- When a shell exits and a new one starts, the text is kept.

## Privacy

Restored text is whatever was printed on screen, so it can contain secrets (a token you echoed, a `.env` you printed). It is stored on your Mac in `~/Library/Application Support/BetterTerminal/snapshots/`. Two settings control it, in Settings ▸ Terminal:

- **Resume on relaunch**: turn it off to stop saving terminal text. Turning it off also deletes the saved text.
- **Saved terminal text ▸ Clear**: deletes the saved text now. Text that was on screen at that moment is not saved again; only newer output is.

History (commands only) is separate and is kept either way.

## Reset everything

Quit the app and delete `~/Library/Application Support/BetterTerminal`.
