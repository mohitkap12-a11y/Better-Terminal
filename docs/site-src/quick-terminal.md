---
title: Quick terminal
group: Find
order: 4
---
# Quick terminal

The quick terminal is a small terminal that pops up in the bottom-right corner of your screen when you press a key, from any app. It is for the one-off command you do not want a tab for.

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

- It appears as a rounded 580 × 340 window in the bottom-right corner of the screen the pointer is on, floats above other windows on every Space, and slides up from the edge.
- **Esc hides it.** The key you chose hides it too. If a command is running, Esc goes to that program instead (for example vim), so use the key to hide it then.
- It has its own shell. It is not one of your workspaces, so its commands do not appear in any tab's history and it is not saved or restored.
- The shell stays alive while the app runs, so the next press shows what you left. If you `exit` the shell, the next press starts a fresh one.
- It uses your current theme and font size.
- Turning the setting off releases the key and ends its shell.

## Which folder it opens in

- Pressed from **Finder**: the folder of the front Finder window (the Desktop if no window is open).
- Pressed inside **Better Terminal**: the folder of the tab you are looking at.
- Anywhere else: the shell's current folder (your home folder on the first use).

The first time you use it from Finder, macOS asks whether Better Terminal may control Finder. This is only used to read the open folder. If you decline, the quick terminal still works, it just does not follow Finder; you can allow it later in System Settings ▸ Privacy & Security ▸ Automation.

When the quick terminal already exists, a different folder is applied by typing `cd` into it, but only when it is idle at a prompt. If a command is running, the folder is left alone.

The app must be running for the key to work. Better Terminal does not add itself to your login items.
