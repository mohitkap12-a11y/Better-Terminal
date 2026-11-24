---
title: Troubleshooting
group: Reference
order: 3
---
# Troubleshooting

## Look at the log

Settings ▸ About ▸ **Open Logs Folder** opens `~/Library/Logs/BetterTerminal`. When you report a problem, attach `app.log` (and `crash.log` if the app crashed). They do not contain your commands or output.

## The quick terminal key does nothing

1. Make sure Settings ▸ Terminal ▸ Quick terminal is on.
2. Read the status line under **Quick terminal key**. If it says the key could not be registered, choose another key.
3. Click **Show now**. If the terminal appears, the app is fine and the key is probably taken by another app or a system shortcut.
4. Check `app.log` for "quick terminal hotkey" lines.

## History is empty or not recording

History needs zsh, bash or fish. Check which shell the tab uses (`echo $SHELL`). If you changed `PROMPT_COMMAND` (bash) or removed zsh hooks in your dotfiles, the app's hooks may have been dropped: extend those variables instead of replacing them. See [Shell integration](shell-integration.html#limits).

## A template's startup command did not run

It is typed after the first prompt appears. If your shell never reaches a prompt within 15 seconds, or the shell is not zsh, bash or fish, the command is skipped, and `app.log` says so. Commands run once, so a relaunch does not repeat one that already ran.

## Notifications do not appear

Allow Better Terminal in System Settings ▸ Notifications. Notifications only appear for commands of 10 seconds or more that finish in a tab you are not looking at, and the switch in Settings ▸ Terminal must be on.

## The window is dark but my Mac is light (or the other way round)

You are using an imported theme. Imported themes are a single look, so the window follows the theme, not the Mode setting. Select a built-in theme to go back to System, Light or Dark. See [Themes](themes.html#imported-themes-and-light-or-dark-mode).

## The Xcode build fails with "Build input files cannot be found"

The Xcode project is generated. Run `xcodegen generate` after pulling changes that add or remove files.

## Restored text shows something I do not want to keep

Settings ▸ Terminal ▸ **Saved terminal text ▸ Clear**, and turn **Resume on relaunch** off if you work with secrets.

## Report a bug

[Open an issue](https://github.com/mohitkap12-a11y/Better-Terminal/issues/new) with the app version (Settings ▸ Updates), your macOS version, what you did, what you expected, and `app.log`.
