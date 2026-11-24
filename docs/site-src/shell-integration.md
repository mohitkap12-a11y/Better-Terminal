---
title: Shell integration
group: Under the hood
order: 1
---
# Shell integration

Command history, tab status, notifications, "busy tab" confirmation, startup commands and Copy Last Output all depend on knowing when a command starts and ends. Better Terminal gets that from small hook scripts that it loads into your shell. There is nothing to install or configure.

## Supported shells

| Shell | How it is loaded |
| --- | --- |
| zsh | Through a private `ZDOTDIR` that sources your own startup files first, then adds `preexec` and `precmd` hooks. |
| bash | Started with `--rcfile`; your `~/.bash_profile` (or `~/.bashrc` if there is no profile) is sourced, then hooks are added using `PROMPT_COMMAND` and a `DEBUG` trap. |
| fish | Started with `--init-command` that sources the hook script. |
| anything else | Runs normally, without history capture, badges or notifications. |

Your own dotfiles are always read. For zsh, `ZDOTDIR` is restored for your startup files, and the original value is available as `BT_USER_ZDOTDIR`. zsh starts as a login shell (`-l`), like other macOS terminals.

The hook scripts are written to `~/Library/Application Support/BetterTerminal/shell-integration/` when the app starts.

## What the hooks report

Each tab has a small event file. The shell appends one line per event:

| Event | When | Content |
| --- | --- | --- |
| Command started | Just before a command runs | The command text (base64). |
| Command finished | When the prompt returns | The exit status. |
| Folder | At every prompt | The current folder (base64). |

The app watches that file and turns the events into history entries and status. The environment variable `BT_EVENT_FILE` holds the file's path inside the shell. The files are deleted when the tab closes.

Nothing about a command's output is reported. Only the command text, exit status, folder and timing are used.

## What depends on it

- [Command history](history-search.html)
- [Tab status and notifications](notifications.html)
- Closing a [busy tab](workspaces-tabs.html#closing-a-tab-that-is-busy) with confirmation
- [Template](templates.html) startup commands: they wait for the first folder event, which means the shell reached its prompt.
- [Copy last output](terminal.html#last-output)

## Limits

- Commands you start inside another program (SSH sessions, `docker exec`, REPLs) are one command from your shell's point of view.
- If you replace `PROMPT_COMMAND` or the zsh hook arrays after startup, the hooks can be removed. Add to them instead of overwriting.
- Multi-line pastes are sent to the shell with bracketed paste when the shell supports it (zsh and fish do), so they are edited, not run line by line. Bash 3.2, the macOS default, does not enable bracketed paste, so lines are joined with `;` when you insert history entries.
