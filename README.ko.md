# tmux-hub

**tmux 창 목록 사이드바 + 재부팅해도 살아남는 세션 — WSL + Windows Terminal 용.**
[English](README.md)

AI 코딩 에이전트, 개발 서버, SSH 같은 오래 도는 터미널 세션을 tmux 서버 하나에 모아 두고, 편집기의 파일
트리처럼 **옆 사이드바에서 골라 전환**합니다. 터미널을 닫아도, VS Code를 재시작해도, Windows를 재부팅해도
창들이 돌아오고 Windows Terminal이 탭을 다시 엽니다.

```
┌──────────────────────────────────────────┬──────────────────────────────┐
│                                          │  tmux 창 목록                │
│   (선택한 창 — 보통의 tmux 창,            │  ↑↓·클릭 이동  타이핑 필터   │
│    안에서 무엇이든 실행)                  │  ^N 새 창  ^X 닫기  ^R 갱신  │
│                                          │  Alt+←→ 패널  Alt+B 너비     │
│                                          │ ─────────────────────────────│
│                                          │ ▶ ✳ api server [@1]          │
│                                          │   ✳ frontend [@2]            │
│                                          │   claude: 인증 리팩터 [@3]    │
│                                          │   ssh prod [@4]              │
└──────────────────────────────────────────┴──────────────────────────────┘
```

## 제공하는 것
- **사이드바**(오른쪽): 창 목록 실시간 표시, 퍼지 필터, 클릭/방향키 한 번으로 전환, `^N` 새 창,
  `^X` 닫기(확인 필수, 실행 중인 프로그램이 있으면 경고)
- **영속화**: tmux-resurrect가 5분마다 저장(systemd 사용자 타이머), 부팅 시 창·작업 폴더·등록된 프로그램
  복원. Windows Terminal은 탭 구성을 복원
- **Claude Code 연동(선택, 자동 감지)**: 세션을 고정 ID로 시작해 재부팅 후 각 창이 `claude --resume <id>`로
  돌아옴 — 같은 대화, 같은 이름
- 창 이름은 실행 중인 앱의 터미널 제목(예: Claude 세션 이름)을 따라감

## 요구 사항
- Windows 10/11 + **WSL2**(Ubuntu 22.04/24.04 검증) + **systemd 활성**
  (`/etc/wsl.conf` → `[boot]` `systemd=true` 후 `wsl --shutdown`)
- **Windows Terminal**(설치 후 1회 이상 실행)
- WSL 안: `tmux >= 3.1`, `git`, `curl`, `python3` (`sudo apt install tmux git curl python3`)

## 설치
```bash
git clone https://github.com/DragonBall2/tmux-hub.git
cd tmux-hub
bash install.sh -d ~/work -s work        # -d: 새 창 시작 폴더, -s: tmux 세션 이름
```
그 다음 Windows Terminal을 **새로** 열면 `tmux-hub` 프로필이 기본으로 뜹니다.
`install.sh`는 다시 실행해도 안전합니다. `--without-claude`/`--with-claude`로 자동 감지를 덮어쓰고,
`--no-wt`로 Windows Terminal 설정을 건드리지 않게 할 수 있습니다. 머신별 값은 `~/.config/tmux-hub/env`.

설치 중 *WSL interop* ⚠가 보이면 안내된 `sudo` 한 줄을 실행하세요(WSL에서 `wt.exe`/`clip.exe`를 실행하게
해 주는 binfmt 항목을 재등록합니다. systemd를 켜면 가끔 사라집니다).

## 사용
| 어디서 | 키 | 동작 |
|---|---|---|
| 사이드바 | `↑` `↓` · 클릭 · `Enter` | 본문을 그 창으로 전환(타이핑하면 목록 필터) |
| 사이드바 | `Ctrl+n` / `Ctrl+x` / `Ctrl+r` | 새 창 / 창 닫기(`y` 확인) / 갱신 |
| 사이드바 | `Alt+↑` `Alt+↓` | 선택한 창을 위/아래로 이동(tmux 창 번호 순서 변경) |
| 어디서나 | `Alt+←` `Alt+→` | 패널 포커스 이동 |
| 어디서나 | `Alt+[` `Alt+]` · `Alt+b` | 사이드바 작게 / 크게(4칸, 위쪽 레이아웃에선 2줄) · 리셋. 크기는 허브 이름별로 기억됨(`thub phone`은 따로) |
| 본문 | `Ctrl+a c` · `Ctrl+a &` · `Ctrl+a w` | 일반 tmux: 새 창 · 창 닫기 · 트리 |
| 셸 | `claude` (=`ccr`) | 세션 ID가 보존되는 Claude Code 실행 |
| 셸 | `twin [@N\|new]`, `twt-all` | 창을 Windows Terminal 개별 탭으로 |

**좁은 화면(SSH로 붙은 휴대폰 등):** 터미널 폭이 90칸 미만이면 `thub`가 사이드바를 오른쪽 열 대신 본문 **위쪽 띠**로 배치하고
헤더를 한 줄로 줄입니다. `thub phone top` / `thub phone right`(또는 `SIDEBAR_POS=top`)로 강제할 수 있고, `Alt+←/→`는 두 레이아웃 모두에서 패널을 오갑니다.

Windows Terminal 탭을 닫는 것은 detach일 뿐이라 tmux 안의 것은 아무것도 멈추지 않습니다.
패널 경계를 드래그하면 사이드바 너비가 바뀌고 기억됩니다.

## 동작 원리
- **기본 tmux 서버**(기본 소켓)가 실제 창들을 가짐
- `thub`가 소켓 `hub`에 **바깥 tmux 서버**를 띄우고 2패널 구성: 기본 서버의 *그룹 세션*에 중첩 `tmux attach`
  (탭마다 독립된 현재 창) + `tside`(`fzf --listen` 루프, 2초마다 커서 유지한 채 목록 갱신)
- 바깥 서버는 prefix·상태바가 없어 모든 키가 안쪽 tmux로 전달됨
- 저장/복원: `tmux-resurrect` + systemd 사용자 타이머(`tmux-resurrect-save.timer`) + 부팅 복원 서비스.
  continuum의 내장 타이머·자동 복원은 **쓰지 않음**: 타이머는 상태바가 그려질 때만 돌고, 자동 복원은
  두 번째 tmux 서버(hub)를 보면 포기함

## 겪은 함정
- Windows Terminal 프로필에 `startingDirectory: //wsl$/...`, 비ASCII 이름, emoji 아이콘을 넣으면 탭이 조용히
  안 뜸 — 설치 스크립트는 셋 다 피함
- `wt.exe`/`clip.exe` → `Exec format error` / `MZ: command not found`: `WSLInterop` binfmt 항목 유실(설치 절 참고)
- 복원 전에 도는 주기 저장이 정상 저장본을 빈 것으로 덮을 수 있음 → 저장 서비스는 창이 1개면 건너뜀.
  그래도 생기면 `~/.local/share/tmux/resurrect/`의 마지막 큰 파일로 `last` 심링크를 돌리고
  `.../tmux-resurrect/scripts/restore.sh`
- tmux 3.2a는 패널 경계의 전각(CJK) 문자를 옆 패널 첫 칸에 그림 — 사이드바가 오른쪽에 있는 이유
- 창 정리를 스크립트로 할 때 `pane_current_command == bash`로 고르지 말 것: `bash -lc 'claude …'`로 시작한
  창도 bash로 보임. 생성 전후 창 ID diff로 특정
- VS Code tmux-integrated 확장은 탭을 닫으면 창을 kill함. Windows Terminal 탭은 detach만

## 제거
```bash
systemctl --user disable --now tmux-resurrect-save.timer tmux-resurrect-restore.service
rm -f ~/.local/bin/{thub,tside,twin,twt-all,tmux-restore-if-empty,tmux-save-guarded,ccr} ~/.tmux-hub.conf
# ~/.tmux.conf 의 "# >>> tmux-hub" … "# <<< tmux-hub" 블록과 ~/.bashrc 의 claude alias 제거
# Windows Terminal: tmux-* 프로필 삭제 또는 settings.json.bak-* 로 복원
```

## 라이선스
MIT
