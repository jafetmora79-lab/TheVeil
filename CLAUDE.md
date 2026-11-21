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

## Meshy characters (2026-11-19) - READ `docs/HANDOFF_MESHY_CHARACTERS.md` BEFORE TOUCHING NPCs, FACES OR CHARACTER MODELS

Branch `art/npc-meshy-trial-eddie-clerk` (not merged into the default branch yet; merge only when the owner says so). On it, **every NPC in the game is a new
Meshy model by default** (the old models are still in the repo; launch with `-- old_npcs` to see them):
- Who plays whom is one list, `MAP` in `game/npc/meshy_npcs.gd`; the swap is a guarded hook in `world._spawn_npc` (all NPCs, including the protagonist in cutscenes,
  are created there). Faces answer the old VeilFace calls through `game/npc/meshy_npc_face.gd` and follow the NpcAnimator's scared mood.
- Models, rigs, face textures and tools: `game/prototypes/npc_meshy/`, `game/prototypes/protagonist_meshy/`, `game/prototypes/sarah_meshy/`, `creatures/` (sources + Blender scripts).
  Do not make new character models or faces by hand: use the pipeline in the handoff document.
- Also on that branch: Eddie now leaves the supermarket through the doors before following (`chapter5.gd`, `_eddie_exit_route`), with a regression test.
- Merge notes: it merges cleanly into the default branch (code changes are only `world.gd` (3 lines), `chapter5.gd`, two new files in `game/npc/`); against `claude/tentacle-beast`
  the only conflicts are 22 identical `game/audio/encounters/*.wav.import` add/add files (take either side).
- The lean download copy for testing is branch `playtest/meshy-trial` (no docs or character sources).

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
| `game/chapters/setups/dev_chapterN.gd` | The state at the end of chapter N (used by chapter select for 6-16 and by the chapter tests). **Exported**: chapter select needs them |
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

The export filter skips `game/tools/build_*`, `game/tools/*.py` and `game/tests/*`. It keeps `game/chapters/setups/dev_chapter*.gd`.
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

- **`game/tools/` has a `.gdignore`**: Godot skips it entirely, so nothing in it is exported, but headless tests on
  the source tree still see it. Anything the game itself needs must live elsewhere. The chapter set-ups moved to
  `game/chapters/setups/` for this reason: in the build they were missing, and chapter select loaded the old save.
  `chapter_select_test` checks this (`setups_exported`). To be sure a build has a file, grep the `.pck` for its path.
- Most `chapterN_test.gd` (and other tests built on the chapter set-ups) **overwrite `user://veil_save.json`**,
  which is the owner's real save on their PC. Back it up first, or run only on a machine without a real save.

- The headless dummy renderer returns zero for `MultiMesh` instance transforms. Store shelf positions come from the
  layout data instead (`store_merch._layout()`; see `trailer_director.shelf_of`).
- GDScript lambdas capture locals by value. Look nodes up after waiting.
- `Game.no_save` is on while the trailer plays. Anything that saves and then loads must make sure it's off.
- A chapter's displayed number is not the file's number (see `game/data/chapters.json`).
- Don't commit `.import` churn from local Godot runs unless it's intended.

## Mixamo-rigged NPCs (2026-11-20) - on branch `story/noah-rescue`
- Eleven NPC models come from Meshy as Mixamo-rigged GLBs with their own clips (`game/prototypes/npc_meshy/CHR_<slug>_Mixamo.glb`: bomber, woman_red_plaid, tan_jacket, eddie, bearded_man, police_officer,
  police_redhair, teen_blue_jacket, store_clerk, police_cap, elderly_woman). They are listed in `MIXAMO` / `PLAIN` in `game/npc/meshy_npcs.gd`. `NpcAnimator` "native mode" plays their Walking / Running / Jump /
  Chair_Sit_Idle_M clips while they move, jump or sit and poses everything else (idle, talk, scared, look-at) through bone aliases. Test: `game/tests/native_clip_test.gd`.
- Their faces are the painted neutral face only (`VeilPlainFace`): the expression work (face textures, movable brows, baked patches) was tried and removed; it is in git history (commits of 2026-11-20 up to 8eeb2075)
  if it is resumed. The older non-Mixamo NPCs (Protagonist, Sarah, Lena, the cashier, plaid man) use the procedural gait blended with the retargeted Mixamo walk/run (`game/animation/mixamo_gait.gd`).
- Known: `gait_test` reports foot slip for those retargeted gaits; `chapter5_test` fails (also with the Mixamo swaps turned off: not caused by them, not investigated).

## Wildlife, wind, intro camera (2026-11-21) - on branch `story/noah-rescue`
- `game/animals/veil_animal.gd` (deer, rabbit: the clips that came with the Meshy models; raven: no clips came with it, its wing beat / leg tuck is posed in code) and
  `game/animals/wildlife.gd` (added by `world.gd`): a few animals near the player in the woods before the Veil, and ONE deer that bursts across the road on the drive into town
  (flag `deer_scare_done`, timed to pass about 0.4 s ahead of the car; it has no collision). Test: `game/tests/wildlife_test.gd`. Sizes, run speeds and foot slip need a visual test.
- Trees and grass sway in the wind: `game/world/tree_sway.gdshader` replaces the StandardMaterial3D of the scattered vegetation (`scatter.gd::_make_sway`); the global `veil_wind` is 1 before the Veil, 2.4 after.
- The intro's last shot starts on the player's roof (not in the car); lamp posts / signs in front of the supermarket arrival shot are hidden for its length (`world.gd::_hide_poles_in_view`).
- Each Mixamo NPC has its own AnimationLibrary (the imported one is shared by every instance and a native crash followed when one copy replaced a clip another was playing).

## Grimtalons, deer cinematic, stock-room retreat (2026-11-21) - on branch `story/noah-rescue`
- `game/animals/grimtalon.gd` (VeilGrimtalon): the bat-owl Meshy model (`game/prototypes/animals/MON_grimtalon.glb`, rigged, no clips: wings / legs / tail are posed in code). `flock()` makes swarms,
  `abduct(victim, exit_dir, cb, approach)` swoops, grabs a person by the shoulders and climbs away. Used by: `wildlife.gd` (two flocks over the town once the Veil is up), `world.gd::_tripod_encounter`
  (a swarm round the Colossus), `intro_cinematic.gd` (a swarm round the intro's Colossus), `living_town.gd::_frank_taken_by_grimtalon` (replaces the Skitter dragging Frank; `-- old_monsters` keeps the Skitter).
  Preview GIF: `docs/grimtalon_preview.gif` (made by `game/tests/grimtalon_gif.gd`, windowed). Test: `game/tests/grimtalon_test.gd`. Sizes, colours and the look through the mist need a visual test.
- The deer on the drive is a cinematic (`wildlife.gd::_cine`): only on a straight stretch, hard brake, deer stops ~1.7 m ahead of the bumper, freezes, bolts, two lines, the drive resumes. `opening_test` sets the flag
  `deer_scare_done` so its autopilot drive is not stopped.
- Game-shop retreat (`world.gd::_shop_seated_talk`): Eddie runs ahead and opens the stock-room door, the protagonist and Marcus go in, Marcus closes it. Seats: `_seat` edge 0 (on top of the boxes).
- Tentacles: the back-gate trio is slimmed (`garage_tentacle.gd::THIN`, thickness only, length unchanged); the street tentacle's mound is scaled to its girth (`tentacle_escape_shot.gd::MOUND_SCALE`).
  Both need a visual test.
