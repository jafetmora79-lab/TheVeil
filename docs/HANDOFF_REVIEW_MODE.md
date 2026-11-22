# Review mode ("sticky notes") - how the owner catches bugs now, and how to work through them

Written 2026-11-21 on branch `story/noah-rescue`. This is the owner's bug-catching loop. Read it before you touch anything the owner reports.

## What it is

In the game (also in the exported exe) **F2 turns REVIEW MODE on**. The owner aims the crosshair at the thing, clicks, picks **BUG / 3D ASSET / OTHER**, types a line, and presses SAVE NOTE.
They then play on. When they say "I left notes", you read the notes file and fix them one by one.

- Code: `game/review/review_mode.gd` (class `VeilReviewMode`, a CanvasLayer added to the world by `world.gd` as `ReviewMode`).
- Tests: `game/tests/review_mode_test.gd`, `review_mode_ui_test.gd` (windowed).
- The notes file: `%APPDATA%\Godot\app_userdata\THE VEIL\veil_notes.json`. Screenshots: `...\review\note_NNN.png`.
- Each note has: `id`, `status` (open / fixed / wontfix), `type`, `text`, `chapter`, `objective`, the story `flags`, camera position / rotation / fov, player position,
  the screenshot, and `target` = what the crosshair hit: node path, class, script, the instanced scene / `.glb` it comes from, mesh and material names, hit position, and
  `candidates` (every mesh that contains the point, smallest first = the most specific thing there). Saved notes show in the world as numbered markers in review mode.

## The loop (what to do, in this order)

```powershell
python game/tools/review_notes.py list            # the open notes (id, type, chapter, text, what was pointed at)
python game/tools/review_notes.py show 12         # one note in full; open the screenshot PNG it names with the Read tool
# ... fix it ...
python game/tools/review_notes.py done 12 "what was changed" <commit>     # or: wontfix 12 "why"   /  reopen 12
```

Rules the owner set (they apply here too):
1. One note at a time, a commit per fix (or per coherent batch), pushed. **Never merge into the default branch.**
2. **Run the tests before you commit and only commit when they pass.** (`opening_test` needs `-- skip_reload` on an 8 GB machine.)
3. **Do not make renders unasked** - but a render of the NOTE'S OWN VIEW to check your fix is the way to know you fixed it. Use `game/tests/review_shots.gd` (below) and
   say which fixes still *need the owner's visual test*.
4. Reuse existing assets and NPCs. New models are made in Blender with the scripts in `game/tools/blender/` (no hand-made character models).

## Getting to the place in a note

- `game/tests/review_shots.gd` re-takes the camera view of a note after your fix:
  `godot --path . --resolution 960x540 --script res://game/tests/review_shots.gd -- ids=12,13 dir=<folder> [flags=a,b] [cam=x,y,z,rx,ry,rz]`.
  `flags=stockroom` sets up the game shop's stock-room seats; `kill=Path:surface` / `paint=Path:surface` leave a mesh surface out / colour it by area (finds which surface makes a visual fault).
- The chapter and flags are in the note; `Main Menu > Chapters` starts at a chapter.
- Probes written while fixing (kept as examples): `home_probe.gd`, `band_probe.gd`, `market_probe.gd`, `shop_probe*.gd`, `story_rooms_shots.gd`.
- Pack scenes (a whole supermarket in one merged mesh) are fixed **on the instance**: cut triangles by region and put a Blender model in their place -
  see `game/world/market_fixes.gd` (supermarket fridges / freezers / produce, game-shop case) and `game/world/home_fixes.gd` (the player's house).

## Gotchas learned

- A `Container` (CenterContainer, VBox...) resets its child's `scale` - a "scale to fit" on a container child does nothing. The inventory panel is now a plain Control for that reason.
- Godot front is **+Z**; Blender's front is **-Y**. In `make_*_props.py` scripts the box helper takes Godot-style centres only through the `g()` helper in `make_car_parts.py`.
- `Acc` (in `make_market_props.py`) builds one mesh per fixture; textured front plates use the `front=` UV argument.
- Mesh triangles in a merged pack mesh can be identified by their connected components + material surface (see the component dump idea in `docs` history: a probe that unions shared vertices).
- `safe_point()` in `living_town.gd` used to pick spots inside shops; use `outdoors_only=true` for scenes that must stay on the street.
- The notes file is the owner's: never edit it by hand, use `review_notes.py`.

## State of the notes (2026-11-21, end of the session)

Done (marked `done` in the notes file with the commit): #1-#25, #27-#41 except where noted below, #42-#45, #48. The fixes, by area:
- **Supermarket / game shop:** food models + labels, take-anything shelf picker (`store_merch.gd`), rebuilt fridges / freezers / produce / display case (`market_fixes.gd`, `make_market_props.py`),
  paper shopping-list item (inventory "READ", trashed at the till), one-of-each errand kinds, shelf highlight, no pickups after the shopping.
- **Creatures:** `hound_ai.gd` `shot()` (hound bolts after 1 hit, skitter after 2, crab only stung) and `investigate(at, linger, hunt_after)` (noise -> search -> hunt after 20 s: gunshots, thrown things, alarms);
  the tentacle attack is now an octopus-arm coil / unravel / grip / release (`tentacle_ai.gd` + `tentacle_grab.gd`); the garage jumpscare is ONE big writhing tentacle; faster skitter lunge (`chapter7.gd::_lunge`);
  the Hound leaps in (`chapter6.gd::_hound_entrance`) and the group runs for the store (`_group_flees`).
- **Props / world:** relay + relay box (Blender, `make_car_parts.py`), battery pull follows the clicks + tray (`car_quest.gd`), furniture clearance audit (`game/tests/furniture_audit.gd`, run with `-- fix` to move
  pieces and rewrite `scavenge_houses.json`; door swings capped at 90 degrees), gas station + clothing stores furnished and lootable (`store_interiors.gd`, `make_store_props.py`).
- **UI:** inventory panel fits the window (a Container resets scale: it is a plain Control now), the quick slots hide behind it, the flashlight is always in a quick slot and infinite.
- **Story flow:** chapter 5 diamonds on the next step, music stays until both exits are secured, Ruth hands over the gun at the end of the voices chapter (`sidearm.presenter_override`).

STILL OPEN (the owner has these in the notes file):
- **#26** the Colossus / monster "appearing out of nowhere" in chapter 3: the pre-raised mist curtains were added (`world.gd::_pre_mist_start`) but the owner still saw it pop in; needs a visual session on `_tripod_encounter`.
- **#47** the kitchen: door swings are capped and the audit moves blockers, but the fridge interiors / the toilet bowl are not re-modelled (the pack's fridge already has a hollow body with porcelain shelves).
- **#46** the lag after a long play: a probe showed no growth from drawers / saves in a fresh world; the one measured hitch was my own shelf picker scanning every product (now a 1 m grid); if it comes back, record
  `Performance` monitors during a long chapter 7 session.
- **Pre-existing test failures** (not from these changes; `git stash` baseline runs gave the same): `car_quest_test` (struggle_won_recover, fit_once), `house_loot_test` (3), `expedition_test` (5), `chapter7_test` (early walks),
  `monsters_meshy_test` (hound_clips), `house_audit_test` (2 door checks), `chapter6_test` c6_rs_talk_camera.
