---
title: Quick terminal
group: Find
order: 4
---
# Quick terminal

The quick terminal is a terminal that drops down from the top of your screen when you press a key, from any app, and hides again when you press it again. It is for the one-off command you do not want a tab for.

## Turn it on

Settings ▸ Terminal ▸ **Quick terminal**. It is off by default.

## The key

When it is on, **Quick terminal key** appears. Choose one of:

| Key | Notes |
| --- | --- |
| ⌃` (control + backtick) | The default. |
| ⌥Space | |
| ⌃⌥Space | |
| F12 | |

Under the picker, a status line says whether the key was registered, for example *Listening for ⌃`*, or tells you if macOS refused it so you can pick another. If a key does not seem to work, another app may be using it: choose a different one.

**Show now** opens the quick terminal without the key, which is a good way to check that everything else works.

## How it behaves

- It slides down over the top 42% of the screen the key was pressed on, across the full width, and floats above other windows on every Space.
- It has its own shell. It is not one of your workspaces, so its commands do not appear in any tab's history and it is not saved or restored.
- The shell stays alive while the app runs, so the next press shows what you left. If you `exit` the shell, the next press starts a fresh one.
- It uses your current theme and font size.
- Turning the setting off releases the key and ends its shell.

The app must be running for the key to work. Better Terminal does not add itself to your login items.
