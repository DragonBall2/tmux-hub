# tmux-hub

**A window-list sidebar for tmux, with sessions that survive reboots — built for WSL + Windows Terminal.**
[한국어](README.ko.md)

Run many long-lived terminal sessions (AI coding agents, dev servers, SSH) in one tmux server and switch
between them from a sidebar — like an editor's file tree, but for terminals. Close the terminal app, restart
VS Code, even reboot Windows: the windows come back, and Windows Terminal reopens the tab.

```
┌──────────────────────────────────────────┬──────────────────────────────┐
│                                          │  tmux windows                │
│   (the selected window — a normal tmux   │  ↑↓/click: switch type:filter│
│    window with whatever runs inside)     │  ^N new ^X close ^R refresh  │
│                                          │  Alt+←→ pane  Alt+B width    │
│                                          │ ─────────────────────────────│
│                                          │ ▶ ✳ api server [@1]          │
│                                          │   ✳ frontend [@2]            │
│                                          │   claude: refactor auth [@3] │
│                                          │   ssh prod [@4]              │
└──────────────────────────────────────────┴──────────────────────────────┘
```

## What you get
- **Sidebar** (right pane): live list of tmux windows, fuzzy filter, single-click/arrow switching,
  `^N` new window, `^X` close (with confirmation and a warning if something is running).
- **Persistence**: tmux-resurrect saves every 5 min (systemd user timer); at boot the windows, working
  directories and whitelisted programs are restored. Windows Terminal restores the tab layout.
- **Claude Code integration (optional, auto-detected)**: sessions are started with a fixed session id, so
  after a reboot each window comes back with `claude --resume <id>` — same conversation, same name.
- Window names follow the running app's terminal title (e.g. the Claude session name).

## Requirements
- Windows 10/11 + **WSL2** (Ubuntu 22.04/24.04 tested) with **systemd enabled**
  (`/etc/wsl.conf` → `[boot]` `systemd=true`, then `wsl --shutdown`)
- **Windows Terminal** (installed and launched at least once)
- Inside WSL: `tmux >= 3.1`, `git`, `curl`, `python3` (`sudo apt install tmux git curl python3`)

## Install
```bash
git clone https://github.com/DragonBall2/tmux-hub.git
cd tmux-hub
bash install.sh -d ~/work -s work        # -d: where new windows start, -s: tmux session name
```
Then open a **new** Windows Terminal window — the `tmux-hub` profile is now the default.
Re-running `install.sh` is safe; use `--without-claude` / `--with-claude` to override auto-detection,
`--no-wt` to leave Windows Terminal settings alone. Per-machine values live in `~/.config/tmux-hub/env`.

If the installer prints a ⚠ about *WSL interop*, run the `sudo` one-liner it shows (it re-registers the
binfmt entry that lets WSL launch `wt.exe`/`clip.exe`; this entry is sometimes lost when systemd is on).

## Use
| Where | Keys | Action |
|---|---|---|
| Sidebar | `↑` `↓` · click · `Enter` | switch the body to that window (typing filters the list) |
| Sidebar | `Ctrl+n` / `Ctrl+x` / `Ctrl+r` | new window / close window (asks `y`) / refresh |
| Sidebar | `Alt+↑` `Alt+↓` | move the selected window up/down (reorders tmux window indexes) |
| Anywhere | `Alt+←` `Alt+→` | move focus between panes |
| Anywhere | `Alt+[` `Alt+]` · `Alt+b` | sidebar smaller / larger (4 cols, or 2 rows in the top layout) · reset. Size is remembered per hub name (`thub phone` keeps its own) |
| Body | `Ctrl+a c` · `Ctrl+a &` · `Ctrl+a w` | plain tmux: new window · kill window · tree |
| Shell | `claude` (alias of `ccr`) | start Claude Code with a persistent session id |
| Shell | `twin [@N\|new]`, `twt-all` | open windows as separate Windows Terminal tabs instead |

**Narrow screens (phones over SSH):** when the terminal is narrower than 90 columns, `thub` puts the sidebar as a
strip **above** the body with a one-line header instead of a right-hand column. Force it with `thub phone top` / `thub phone right`
(or `SIDEBAR_POS=top`). `Alt+←/→` toggles between the two panes in either layout.

Closing the Windows Terminal tab only detaches; nothing inside tmux stops.
Drag the pane border to resize the sidebar — the width is remembered.

## How it works
- The **base tmux server** (default socket) holds the real windows.
- `thub` starts an **outer tmux server** on socket `hub` with two panes: a nested `tmux attach` to a
  *grouped* session of the base server (so each tab has its own current window), and `tside`, an
  `fzf --listen` loop that reloads the window list every 2 s without losing the cursor.
- The outer server has no prefix and no status bar, so every key reaches the inner tmux.
- Save/restore: `tmux-resurrect` + a systemd user timer (`tmux-resurrect-save.timer`) and a boot-time
  restore service. continuum's built-in timer and auto-restore are **not** used: its timer only ticks while
  a status bar is rendered, and its auto-restore bails out when it sees a second tmux server (the hub).

## Pitfalls we hit (so you don't have to)
- Windows Terminal profile: `startingDirectory: //wsl$/...`, non-ASCII profile names and emoji icons make
  the tab silently fail to open. The installer avoids all three.
- `wt.exe`/`clip.exe` → `Exec format error` / `MZ: command not found`: the `WSLInterop` binfmt entry is
  missing (see Install).
- A periodic save that runs before restore can overwrite a good save with an empty one — the save service
  skips when only one window exists. If it ever happens: pick the last big file in
  `~/.local/share/tmux/resurrect/`, point the `last` symlink at it, run `.../tmux-resurrect/scripts/restore.sh`.
- tmux 3.2a draws wide (CJK) characters at a pane edge into the neighbouring pane's first column — that is
  why the sidebar sits on the right.
- If you script window clean-up, do not match `pane_current_command == bash`: windows started as
  `bash -lc 'claude …'` look like bash. Diff window ids before/after instead.
- VS Code's tmux-integrated extension kills the window when you close its tab; Windows Terminal tabs only detach.

## Uninstall
```bash
systemctl --user disable --now tmux-resurrect-save.timer tmux-resurrect-restore.service
rm -f ~/.local/bin/{thub,tside,twin,twt-all,tmux-restore-if-empty,ccr} ~/.tmux-hub.conf
# remove the "# >>> tmux-hub" … "# <<< tmux-hub" block from ~/.tmux.conf and the claude alias from ~/.bashrc
# Windows Terminal: delete the tmux-* profiles or restore settings.json.bak-*
```

## License
MIT
