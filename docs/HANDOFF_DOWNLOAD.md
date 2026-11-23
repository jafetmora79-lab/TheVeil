# Getting THE VEIL's Windows zip onto another device (handoff for any AI or person)

Written 2026-11-23. Read this when you are asked to "get the game zip" onto a new machine.

## What "the zip" is

`TheVeil_Windows.zip`, 260,810,322 bytes, SHA-256
`07ce354f7fcf279040baa135036eb5d4de6d00fac04ea54f62e7e63c0c23cf3d` (built 2026-11-23 08:51 local time from commit
`79763c80`, the head of the default branch; the `.exe`, `.bat` files and changelog are carried over from the 2026-11-21 zip).
The previous zip (251,730,501 bytes, SHA-256 `c346d611905997a9cb1b60c970afe4b0b293d29686f06cce6aed878e6f968889`)
is kept on the owner's PC as `C:\Users\Themo\Documents\TheVeil-builds\TheVeil_Windows_2026-11-21.zip`.
It holds one folder, `TheVeil/`:

| File | Size | What |
|---|---|---|
| `TheVeil.exe` | 84,214,784 | The stock Godot 4.3 Windows release template, renamed. Unchanged between builds. |
| `TheVeil.pck` | 246,703,664 | The game (the only part that changes with the code). |
| `TheVeil_TrailerMode.bat`, `Unlock_All_Chapters.bat`, `CHANGELOG.txt` | small | Launch helpers and the changelog. |

Run `TheVeil.exe` on Windows (nothing to install). The `.pck` must sit next to the exe.

**The zip is not in git.** It is 251 MB (GitHub refuses files over 100 MB) and `.gitignore` excludes
`docs/download/*.zip`. A copy lives on the owner's PC at
`C:\Users\Themo\Documents\TheVeil-meshy\docs\download\TheVeil_Windows.zip` (also in `...\TheVeil-builds\`). It is current as of
commit `79763c80`; if the code has moved on since, rebuild (below).

## Way 1: download it (needs one step from the owner, once)

The repo `https://github.com/jafetmora79-lab/TheVeil` is public. A GitHub **Release** accepts files up to 2 GB, so the
zip can be hosted there. The owner (or any session with `gh` and a login) does this once:

1. GitHub > the repo > Releases > Draft a new release; tag e.g. `windows-build-2026-11-23`.
2. Drag `TheVeil_Windows.zip` into the assets box and publish. (CLI: `gh release create windows-build-2026-11-23 docs/download/TheVeil_Windows.zip --repo jafetmora79-lab/TheVeil`.)

Then anyone, on any device, downloads it with:

```powershell
Invoke-WebRequest https://github.com/jafetmora79-lab/TheVeil/releases/download/windows-build-2026-11-23/TheVeil_Windows.zip -OutFile TheVeil_Windows.zip
Get-FileHash TheVeil_Windows.zip -Algorithm SHA256   # must match the hash above
Expand-Archive TheVeil_Windows.zip -DestinationPath .
```

(Linux/macOS: `curl -L -O <same URL>`, `sha256sum`, `unzip`.) **Nobody has published this release yet**: if the URL
404s, use Way 2, or ask the owner to do the two steps above. Do not try to upload with credentials you found lying
around; ask.

Other ways to move the existing file without any hosting: copy it with a USB drive or a cloud drive, or on the same
network run `python -m http.server 8000 --directory docs/download` on the PC and open `http://<pc-ip>:8000/TheVeil_Windows.zip`.

## Way 2: rebuild the current game from source on any machine (about 10 minutes)

Needs: git, Godot **4.3 stable** (not 4.4+), and the 4.3 export templates. No Windows required for building.

```bash
git clone https://github.com/jafetmora79-lab/TheVeil.git && cd TheVeil          # default branch: claude/practical-cray-hi2y54
# Godot 4.3 editor + templates (Linux example; pick the right file for your OS):
wget https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_linux.x86_64.zip
wget https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_export_templates.tpz
unzip Godot_v4.3-stable_linux.x86_64.zip
mkdir -p out/TheVeil && unzip -j Godot_v4.3-stable_export_templates.tpz templates/windows_release_x86_64.exe -d out
mv out/windows_release_x86_64.exe out/TheVeil/TheVeil.exe                        # the stock template IS the exe
./Godot_v4.3-stable_linux.x86_64 --headless --path . --import                    # once (imports assets)
./Godot_v4.3-stable_linux.x86_64 --headless --path . --export-pack "Windows Desktop" out/TheVeil/TheVeil.pck
cd out && zip -r TheVeil_Windows.zip TheVeil
```

Notes:
- The export preset is `Windows Desktop` in `export_presets.cfg`. The pack filter already skips `game/tools/*`
  (so `game/tools/audio_synth/` and its rendered review WAVs are not shipped) and `game/tests/*`.
- The two `.bat` helpers and `CHANGELOG.txt` are not stored in git. Take them from the old zip if you have it, or
  recreate: `TheVeil_TrailerMode.bat` runs `TheVeil.exe --trailer`; `Unlock_All_Chapters.bat` writes
  `{"all_chapters": true}` to `%APPDATA%\Godot\app_userdata\THE VEIL\veil_chapters.json`. The game runs without them.
- A `.pck` rebuilt later will not be byte-identical to this one if the code has changed. `TheVeil.exe` is always
  `84,214,784` bytes (the unchanged 4.3 template). The build above used `Godot_v4.3-stable_win64_console.exe`.
- Windows owners can build natively too: same commands with `Godot_v4.3-stable_win64.exe`, and `Compress-Archive` for the zip.
- Check a pack contains something you need: `grep -a "res://game/chapters/setups/dev_chapter5.gd" TheVeil.pck`.

## Where the code is

`https://github.com/jafetmora79-lab/TheVeil`, branch `claude/practical-cray-hi2y54` (the default; it holds the
latest work as of 2026-11-23, fast-forwarded from `story/noah-rescue`). Start from `CLAUDE.md`, the working guide
for everything else (tests, owner rules, layout).
