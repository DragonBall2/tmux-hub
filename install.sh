#!/usr/bin/env bash
# tmux-hub installer — tmux session persistence + window-list sidebar for WSL + Windows Terminal
#
#   bash install.sh [-d <base dir>] [-s <session name>] [--with-claude|--without-claude] [--no-wt]
#     -d               directory the base tmux session starts in   (default: current dir)
#     -s               base tmux session name                      (default: basename of -d)
#     --with-claude    install Claude Code integration (ccr wrapper, session-id aware restore)
#     --without-claude skip it                                     (default: auto-detect `claude`)
#     --no-wt          do not touch Windows Terminal settings
#
# Installs: ~/.local/bin/{thub,tside,twin,twt-all,twork,tmux-restore-if-empty[,ccr]}, fzf, TPM + resurrect +
#   continuum, a block in ~/.tmux.conf, ~/.tmux-hub.conf, systemd user timer/services,
#   ~/.config/tmux-hub/env, [alias claude=ccr], Windows Terminal profiles (tmux-hub as default).
# Re-running is safe (idempotent).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$PWD"; SESSION=""; DO_WT=1; CLAUDE=auto
while [ $# -gt 0 ]; do case "$1" in
  -d) BASE_DIR="$(cd "$2" && pwd)"; shift 2;; -s) SESSION="$2"; shift 2;;
  --with-claude) CLAUDE=1; shift;; --without-claude) CLAUDE=0; shift;; --no-wt) DO_WT=0; shift;;
  -h|--help) sed -n 2,15p "$0"; exit 0;; *) echo "unknown option: $1"; exit 1;; esac; done
SESSION="${SESSION:-$(basename "$BASE_DIR")}"
[ "$CLAUDE" = auto ] && { command -v claude >/dev/null 2>&1 && CLAUDE=1 || CLAUDE=0; }
say(){ printf '\n\033[1;34m▶ %s\033[0m\n' "$*"; }

say "Preflight"
command -v tmux >/dev/null || { echo "tmux not found: sudo apt install tmux"; exit 1; }
for c in curl git python3; do command -v $c >/dev/null || { echo "$c not found: sudo apt install $c"; exit 1; }; done
tmux -V | grep -qE 'tmux (3\.[1-9]|[4-9])' || echo "  ⚠ tmux >= 3.1 recommended ($(tmux -V))"
if [ -z "${WSL_DISTRO_NAME:-}" ]; then echo "  not inside WSL — skipping the Windows Terminal step"; DO_WT=0; fi
echo "  session=$SESSION  dir=$BASE_DIR  claude=$([ "$CLAUDE" = 1 ] && echo on || echo off)"

say "Scripts → ~/.local/bin"
mkdir -p ~/.local/bin ~/.config/tmux-hub ~/.local/state/tmux-hub
for f in thub tside twin twt-all twork tmux-restore-if-empty; do install -m755 "$HERE/bin/$f" ~/.local/bin/; done
[ "$CLAUDE" = 1 ] && install -m755 "$HERE/bin/ccr" ~/.local/bin/
grep -q 'HOME/.local/bin' ~/.profile 2>/dev/null || echo 'PATH="$HOME/.local/bin:$PATH"' >> ~/.profile
ENVF=~/.config/tmux-hub/env
if [ -f "$ENVF" ]; then   # keep user edits (language, width...); refresh only session/dir
  sed -i "s|^TMUX_BASE_SESSION=.*|TMUX_BASE_SESSION=\"$SESSION\"|; s|^TMUX_BASE_DIR=.*|TMUX_BASE_DIR=\"$BASE_DIR\"|; s|^NEW_WINDOW_DIR=.*|NEW_WINDOW_DIR=\"$BASE_DIR\"|" "$ENVF"
else
cat > "$ENVF" <<ENV
# tmux-hub per-machine settings (written by install.sh; edit freely)
TMUX_BASE_SESSION="$SESSION"
TMUX_BASE_DIR="$BASE_DIR"
SIDEBAR_WIDTH=34
NEW_WINDOW_DIR="$BASE_DIR"
# TMUX_HUB_LANG=en   # sidebar language: ko | en (default: from \$LANG)
# TWORK_ROOT=        # where twork puts worktrees (default: <parent of repo>/<repo>-wt)
ENV
fi
# tmux-hub per-machine settings (written by install.sh; edit freely)
TMUX_BASE_SESSION="$SESSION"
TMUX_BASE_DIR="$BASE_DIR"
SIDEBAR_WIDTH=34
NEW_WINDOW_DIR="$BASE_DIR"
# TMUX_HUB_LANG=en   # sidebar language: ko | en (default: from \$LANG)
ENV

say "fzf"
if ! command -v fzf >/dev/null || ! fzf --version | awk '{split($1,v,"."); exit !(v[1]>0 || v[2]>=44)}'; then
  ver=$(curl -fsSL https://api.github.com/repos/junegunn/fzf/releases/latest | grep -o '"tag_name": *"v[^"]*"' | grep -o '[0-9.]*')
  case "$(uname -m)" in x86_64) a=amd64;; aarch64) a=arm64;; *) a=$(uname -m);; esac
  curl -fsSL "https://github.com/junegunn/fzf/releases/download/v${ver}/fzf-${ver}-linux_${a}.tar.gz" | tar xz -C ~/.local/bin fzf
fi; echo "  fzf $(~/.local/bin/fzf --version 2>/dev/null || fzf --version)"

say "tmux plugins (TPM, resurrect, continuum)"
for r in tpm tmux-resurrect tmux-continuum; do [ -d ~/.tmux/plugins/$r ] || git clone -q https://github.com/tmux-plugins/$r ~/.tmux/plugins/$r; done

say "~/.tmux.conf block, ~/.tmux-hub.conf"
[ -f ~/.tmux.conf ] || cp "$HERE/tmux.conf.base" ~/.tmux.conf
if [ "$CLAUDE" = 1 ]; then RP="set -g @resurrect-processes '\"~claude->ccr *\"'"; else RP="# set -g @resurrect-processes '...'   # programs to relaunch on restore (see tmux-resurrect docs)"; fi
SNIP="$(sed "s|@@RESURRECT_PROCESSES@@|$RP|" "$HERE/tmux.conf.snippet.in")"
python3 - "$SNIP" <<'PY'
import re,sys,os; p=os.path.expanduser('~/.tmux.conf'); s=open(p).read(); new=sys.argv[1].rstrip('\n')+'\n'
if '# >>> tmux-hub' in s: s=re.sub(r'# >>> tmux-hub.*?# <<< tmux-hub <<<\n', lambda m: new, s, flags=re.S)
else: s=s.rstrip('\n')+'\n\n'+new
open(p,'w').write(s)
PY
install -m644 "$HERE/tmux-hub.conf" ~/.tmux-hub.conf
tmux ls >/dev/null 2>&1 && tmux source-file ~/.tmux.conf || true

say "systemd user services (save every 5 min / restore at boot)"
if systemctl --user status >/dev/null 2>&1; then
  mkdir -p ~/.config/systemd/user; install -m644 "$HERE"/systemd/* ~/.config/systemd/user/
  systemctl --user daemon-reload
  systemctl --user enable --now tmux-resurrect-save.timer >/dev/null
  systemctl --user enable tmux-resurrect-restore.service >/dev/null
  loginctl enable-linger "$USER" 2>/dev/null || true
  echo "  enabled: tmux-resurrect-save.timer, tmux-resurrect-restore.service (linger on)"
else
  echo "  ⚠ systemd --user is not available. In WSL: add '[boot]\\nsystemd=true' to /etc/wsl.conf, run 'wsl --shutdown', then re-run."
fi

if [ "$CLAUDE" = 1 ]; then
  say "Claude Code: alias claude=ccr"
  grep -q "alias claude='ccr'" ~/.bashrc 2>/dev/null || printf "\n# Claude Code via the ccr wrapper (keeps the session id so tmux-resurrect can --resume it)\nalias claude='ccr'\n" >> ~/.bashrc
fi

if [ -n "${WSL_DISTRO_NAME:-}" ]; then
  say "WSL interop (binfmt) check"
  if [ ! -e /proc/sys/fs/binfmt_misc/WSLInterop ]; then
    echo "  ⚠ Windows executables cannot be launched from WSL (wt.exe/clip.exe). Run:"
    echo "    sudo sh -c 'echo \":WSLInterop:M::MZ::/init:PF\" > /proc/sys/fs/binfmt_misc/register; printf \":WSLInterop:M::MZ::/init:PF\\n\" > /usr/lib/binfmt.d/WSLInterop.conf'"
  else echo "  OK"; fi
fi

if [ "$DO_WT" = 1 ]; then
  say "Windows Terminal profiles"
  python3 "$HERE/wt-settings.py" "$WSL_DISTRO_NAME" || echo "  ⚠ could not update Windows Terminal settings (is it installed and launched once?)"
fi

say "Done"
cat <<MSG
  - Open a new Windows Terminal window: the 'tmux-hub' tab (body + window sidebar) appears.
  - Sidebar: ↑↓/click switch · ^N new window · ^X close · ^R refresh.  Body: plain tmux (prefix Ctrl+a).
  - After a reboot: tmux windows are restored automatically and Windows Terminal reopens the tab.
$([ "$CLAUDE" = 1 ] && echo "  - Claude Code: start sessions with 'claude' (=ccr) so they come back with --resume after a reboot.")
  - Per-machine settings: ~/.config/tmux-hub/env
MSG
