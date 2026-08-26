#!/usr/bin/env python3
"""Add tmux profiles (tmux-hub / tmux-win / tmux-new) to Windows Terminal settings.json and make tmux-hub the default.
Usage: python3 wt-settings.py <WSL distro name>   (run inside WSL; edits the file via /mnt/c)"""
import glob, json, shutil, sys, time
distro = sys.argv[1]
paths = glob.glob('/mnt/c/Users/*/AppData/Local/Packages/Microsoft.WindowsTerminal_*/LocalState/settings.json')
if not paths: sys.exit('Windows Terminal settings.json not found (install Windows Terminal and launch it once)')
p = paths[0]; shutil.copy(p, p + '.bak-' + time.strftime('%Y%m%d-%H%M%S'))
d = json.load(open(p, encoding='utf-8-sig')); lst = d['profiles']['list']
# ⚠ do NOT add startingDirectory (//wsl$/...), non-ASCII names or emoji icons: the tab silently fails to open
profiles = [
 ("{a1b2c3d4-0003-4000-8000-74d4d7580003}", "tmux-hub", "bash -lc thub"),
 ("{a1b2c3d4-0001-4000-8000-74d4d7580001}", "tmux-win", "bash -lc twin"),
 ("{a1b2c3d4-0002-4000-8000-74d4d7580002}", "tmux-new", 'bash -lc "twin new"'),
]
for guid, name, cmd in profiles:
    prof = {"guid": guid, "name": name, "hidden": False, "suppressApplicationTitle": False,
            # altGrAliasing False: the Korean 한/영 key arrives as Right-Alt; with AltGr aliasing on,
            # Windows Terminal swallows it and the IME toggle intermittently stops working
            "altGrAliasing": False,
            "commandline": f"wsl.exe -d {distro} --cd ~ -- {cmd}"}
    for i, x in enumerate(lst):
        if x.get('guid') == guid or x.get('name') == name: lst[i] = prof; break
    else: lst.insert(0, prof)
d['defaultProfile'] = profiles[0][0]
d['tabWidthMode'] = 'titleLength'; d['showTabsInTitlebar'] = False
d['firstWindowPreference'] = 'persistedWindowLayout'
json.dump(d, open(p, 'w', encoding='utf-8'), ensure_ascii=False, indent=4)
print('OK:', p)
