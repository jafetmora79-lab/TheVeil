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

## State of the notes at the time of writing (2026-11-21)

Fixed and marked done: #1-#21 (see `review_notes.py list --all` / `show N` for the commit each names).
Fixed in the working branch this session (marked done with the commit): see the commit "Review notes #22-#48 batch".
Still open at the time of writing (need real work, not a quick fix): see the list printed by `review_notes.py list` - the big ones are the tentacle re-animation (#27, #29),
the monster emerging from the Veil instead of popping in (#26), the skitter / dog / crab reaction to shots and noise (#37, #39, #40, #45), lootable interiors for the gas station
and the storefronts (#42, #43), the battery-lift animation (#44), furniture clearance in the houses (#47, #48), the interaction lag after long play (#46), the paper shopping-list item (#25).
