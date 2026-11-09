# THE VEIL - start here

PSX-style survival horror in Godot. This file is the current working guide (updated 2026-11-09). The long history
is in `docs/HANDOFF.md`; story and art direction are in `docs/THE_VEIL_MASTER_CONTEXT.md` and
`docs/THE_VEIL_NARRATIVE_BIBLE.md`.

## Repository state

- **Default branch:** `claude/practical-cray-hi2y54`. As of 2026-11-09 it holds everything: every `claude/*`,
  `codex/*` and `cline/*` branch has been merged into it, via `merge/everything`.
  - Start new work from it, on a new branch: `claude/<topic>`.
  - Don't merge into it without the owner's say-so.
- **Engine:** Godot **4.3 stable**, Compatibility renderer (GL). The repository root is the project root.
- **Windows build:** `docs/download/TheVeil_Windows.zip` (it is also on the owner's PC).
  - Contents: `TheVeil.exe` (stock 4.3 template), `TheVeil.pck`, `TheVeil_TrailerMode.bat`,
    `Unlock_All_Chapters.bat`, `CHANGELOG.txt`.

## The owner's working rules

- Make focused changes, one branch per fix or feature. Commit and push. Never merge unless the owner asks.
- Run only short headless checks. **Never generate screenshots, renders or videos.** The owner does all visual testing
  on Windows. Anything visual you can't measure must be reported as *needs your visual test*, never as "fixed".
- Reuse existing assets and NPCs; don't make new models unless there's no other way. Be fast and economical.
- After a build-worthy change, rebuild the Windows ZIP (see *Building* below) and say where it is.

## Layout (game code)

| Path | What |
|---|---|
| `game/autoload/game_state.gd` | `Game`: flags, inventory, world_state, save/load (`user://veil_save.json`), objectives, chapter numbering |
| `game/data/` | `chapters.json` (displayed chapter numbers 1-16 and their start flags), `objectives.json`, `dialogue.json`, items, expedition config |
| `game/world/world.gd` | The town and the opening (Chapters 1-4). Save/restore. The chapter-start hook (`_chapter_start_hook`). Pay-before-you-leave (`_pay_guard`) |
| `game/world/phase4.gd` | Chapter 5 (the first night) |
| `game/world/chapterN.gd` | Displayed chapter **N+1** (internal ids keep the file number: `chapter9.gd` = Chapter 10) |
| `game/world/town_destruction.gd` | The town after the 2-hour skip. Spread over frames (`apply_spread`); rubble gets box collision |
| `game/world/expedition.gd`, `car_quest.gd` | Leaving the shelter, scavenging, repairing the car |
| `game/world/intro_cinematic.gd` | The new-game intro |
| `game/trailer/` | Trailer mode (`--trailer`: F1 help, F8 free camera, F11 jump menu, T or F12 plays the trailer) and the auto-trailer "The Change" (`trailer_director.gd`) |
| `game/chapters/chapter_select.gd` | Main menu > Chapters: start at any chapter (unlocked by an ending, or by `user://veil_chapters.json` `{"all_chapters": true}`) |
| `game/cinematics/` | Codex's menu "Watch Preview" cinematic |
| `game/tools/dev_chapterN.gd` | The state at the end of chapter N (used by chapter select for 6-16 and by the chapter tests). **Exported**: chapter select needs them |
| `game/tests/*.gd` | Headless tests (see below) |

## Running tests (headless)

```bash
godot --headless --path . --import          # once after pulling (imports assets)
godot --headless --path . --fixed-fps 60 --script res://game/tests/<name>.gd
```

The main tests and what passed on 2026-11-09:

| Test | Result |
|---|---|
| `opening_test` | 238 checks |
| `chapter_select_test` | 214 checks: all 16 chapter starts, plus the menu path; optional `-- 4 7` runs only those |
| `trailer_test` | 27 checks |
| `intro_trailer_test` | 20 checks |
| `trailer_menu_test` | run with `-- --trailer` |
| `pay_first_test`, `town_destruction_test`, `cinematic_test`, `roof_skitter_handoff_test`, `chapterN_test` | pass |

Notes:

- Tests print `TEST <name> PASS/FAIL` and finish with `RESULT`.
- These lines on stderr are headless noise: `Parameter "m" is null` (dummy renderer) and `Identifier not found: Game`
  at load. Ignore them.
- `chapter_select_test` can segfault *after* `RESULT` while the engine shuts down (many worlds loaded). That's a
  teardown quirk; the result line is what counts.
- Tests write to the same `user://` folder as the game. `chapter_select_test` backs up and restores the save; most
  chapter tests overwrite `user://veil_save.json`.
- On a Linux web sandbox, get Godot with:
  `wget https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_linux.x86_64.zip`.

## Building the Windows ZIP

1. Export the pack:
   ```bash
   godot --headless --path . --export-pack "Windows Desktop" <out>/TheVeil.pck
   ```
2. Put the `.pck` next to the existing `TheVeil.exe`, `TheVeil_TrailerMode.bat`, `Unlock_All_Chapters.bat` and
   `CHANGELOG.txt` (the exe is the unchanged 4.3 template; take it from the current ZIP).
3. Zip the `TheVeil/` folder and replace `docs/download/TheVeil_Windows.zip`.

The export filter skips `game/tools/build_*`, `game/tools/*.py` and `game/tests/*`. It keeps `game/tools/dev_chapter*.gd`.
- A new `class_name` needs an `--import` first, or it won't resolve. Loading scripts by path avoids that.

## Recent work (2026-11-08/09), and what still needs the owner's eyes

- **Trailer "The Change":**
  - Per-shot lenses, a camera clearance check, three-quarter framing, the Colossus walking at its legs' own pace.
  - The Hound snarls at the doors.
  - Fixed: the freeze after the bed scene (the trailer no longer sets off the town destruction).
  - *Needs visual test:* the framing of every shot, the Colossus shot, Eddie's head turn, the mist.
- **Intro:** the Colossus in the Veil now faces the camera and walks slowly. *Needs visual test.*
- **Pay before you leave** (before the Veil):
  - Walking out of the supermarket or game shop with unpaid items: the cashier or Eddie calls you back.
  - The till and Eddie take payment.
- **2-hour-skip crash:** fixed. The rubble's convex hulls took ~25 s in one frame; the longest frame is now 110 ms.
- **Chapter select:**
  - Each start is a complete state: flags, items, car keys, the car parked dead in the supermarket stall, the
    survivors, and earlier one-time scenes marked as seen.
  - Starting a chapter switches saving back on first. With saving left off (an interrupted trailer), the old save
    used to be loaded instead.
  - *Needs play-testing* of each chapter on Windows.
- **Merged on 2026-11-09:**
  - Codex: the "Watch Preview" menu button and `game/cinematics/`, the running-pose helper, gallery previews.
  - Cline: mostly Godot import output. Its code changes were already ported earlier, so the four conflicting
    scripts kept the ported versions.

## Gotchas

- The headless dummy renderer returns zero for `MultiMesh` instance transforms. Store shelf positions come from the
  layout data instead (`store_merch._layout()`; see `trailer_director.shelf_of`).
- GDScript lambdas capture locals by value. Look nodes up after waiting.
- `Game.no_save` is on while the trailer plays. Anything that saves and then loads must make sure it's off.
- A chapter's displayed number is not the file's number (see `game/data/chapters.json`).
- Don't commit `.import` churn from local Godot runs unless it's intended.
