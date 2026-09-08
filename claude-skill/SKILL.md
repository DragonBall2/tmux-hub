---
name: setup-tmux-hub
description: tmux-hub(창 목록 사이드바 + 재부팅 복원 + Windows Terminal 연동, github.com/DragonBall2/tmux-hub)를 이 머신 또는 다른 머신(WSL)에 설치·재설치·검증한다. "tmux-hub 깔아줘", "회사 PC에 tmux 사이드바 설정", "tmux-hub 업데이트/재설치", 재부팅 후 복원이 안 될 때 사용. 정본은 저장소 — 스크립트 수정은 저장소에서 하고 이 스킬은 설치·검증 절차만 안내한다.
---

# tmux-hub 설치·검증

**정본**: https://github.com/DragonBall2/tmux-hub (공개). 동작 원리·함정 목록은 저장소 README(한국어: README.ko.md)가 최신이다. 이 스킬은 절차의 뼈대만 담는다 — 충돌하면 저장소가 이긴다.

## 0. 전제 확인
- Windows + **WSL2**(Ubuntu 22.04/24.04 검증) + systemd (`/etc/wsl.conf`에 `[boot] systemd=true`, 없으면 추가 후 `wsl --shutdown` 필요 — 사용자에게 맡길 것)
- `tmux git curl python3` (`sudo apt install -y tmux git curl python3`)
- Windows Terminal 설치·1회 실행됨
- Claude Code 연동(세션 자동 `--resume` 복원)은 `claude` 명령이 있으면 자동 활성

## 1. 설치 (멱등 — 재설치·업데이트도 같은 명령)
```bash
git clone https://github.com/DragonBall2/tmux-hub.git ~/tmux-hub 2>/dev/null || git -C ~/tmux-hub pull
cd ~/tmux-hub && bash install.sh -d <기본 작업 폴더> -s <세션 이름>
```
- 이 PC(집): `-d /mnt/d/My_Project -s My_Project`, 로컬 체크아웃은 `/mnt/d/Projects/tmux-hub` 사용
- `--no-wt`: Windows Terminal 설정을 건드리지 않음 / `--without-claude`: Claude 연동 제외
- 기존 `~/.config/tmux-hub/env`(언어·너비 등 사용자 편집)는 보존된다. 한국어 UI 강제: `TMUX_HUB_LANG=ko`

## 2. 설치 스크립트가 ⚠를 내면
- **WSL interop**(`wt.exe`/`clip.exe` `Exec format error`): 안내되는 sudo 한 줄 실행. 재부팅 유실 방지는 `/etc/wsl.conf`에
  `command = sh -c "echo :WSLInterop:M::MZ::/init:PF > /proc/sys/fs/binfmt_misc/register || true"` 추가(root 필요).
  `/usr/lib/binfmt.d/` 방식은 systemd 타이밍 때문에 재부팅에서 유실된 실측 있음 — 쓰지 말 것
- **systemd --user 불가**: wsl.conf에 systemd=true 추가 → `wsl --shutdown` → 재실행

## 3. 검증 (설치 후 반드시)
```bash
tmux -L hub ls                                   # thub 실행 후 hub-<이름> 세션 존재
systemctl --user list-timers | grep resurrect     # 5분 저장 타이머 활성
systemctl --user is-enabled tmux-resurrect-restore.service   # enabled
printf test | clip.exe && powershell.exe -NoProfile -c Get-Clipboard   # 복사 경로
```
- Windows Terminal 새 창 → `tmux-hub` 탭이 기본으로 뜨는지
- 재부팅 검증까지 요청받으면: 저장(`systemctl --user start tmux-resurrect-save.service`) 후 재부팅 →
  `~/.local/state/tmux-hub/restore-boot.log`에 `restored: N windows (rc=0)` 확인 →
  Claude 창들의 "Resume from summary" 프롬프트를 일괄 처리(`capture-pane`으로 감지, Down+Enter = full session)

## 4. 장애 시 (복원 실패)
1. `~/.local/state/tmux-hub/restore-boot.log` 확인 — 실패 지점이 타임스탬프로 남음
2. `last`가 빈 저장본으로 덮였으면 `~/.local/share/tmux/resurrect/`의 마지막 큰 파일로 심링크 복구
3. 수동 복원: `TMUX="/tmp/tmux-$(id -u)/default,0,0" ~/.tmux/plugins/tmux-resurrect/scripts/restore.sh`
   (resurrect는 $TMUX로 소켓을 정하므로 밖에서 돌릴 땐 반드시 지정)
4. 점검은 창 이름이 아니라 실제 프로세스로: 창마다 `ps --ppid <pane_pid>`에 claude가 있는지
5. ⚠ 창 정리 스크립트에서 `pane_current_command==bash` 매칭 금지(claude 창도 bash로 보임) — 생성 전후 창 ID diff로만

## 5. 원격 접속(선택, 요청 시)
WSL 안 Tailscale + `tailscale up --ssh` → 다른 기기에서 `ssh <user>@<호스트명>` 후 `thub phone`(좁은 화면은 자동으로 위쪽 띠 레이아웃). 상세는 이 프로젝트 메모리 `tmux-resurrect-setup` 참조.
