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


## Update 2026-11-22 (notes #26 - #86)

- **Chapter 15 (`chapter14.gd`, "The Last Shelter"):** barricaded doors cannot be opened; the group is made visible / placed when the chapter is entered from the menu (`_ensure_present`); bracing the window and saving the survivor
  at the door are now press-fast struggles with a visible count (`_mash`, E / click); the Hound mauls the survivor if you fail; everyone is put on their own spot before the way out (`_spread`); the survivor caught at the fence is first
  SEEN surrounded (`_surround`), and leaving them is the tragic scene (`_tragedy`: you turn and run, a wall closes behind you). The window look has lit eyes in the street. The house is NOT enlarged (it is the shared mill-worker
  house of chapters 10-15: scaling it breaks every `hl()` coordinate): if it is wanted, use a bigger pack house and re-measure the constants at the top of `chapter14.gd`.
- **Chapter 16 (`chapter15.gd`, `chapter13.gd`, `chapter12.gd`):** soft round mist (no square "blocks"), the door symbol travels with the door slab, floor z-fight lowered, boxes overlap a hair (no seams: `chapter12._box`), a solid
  block inside the sealed structure, the Colossus flickers in / out (`_materialize`) and walks off WEST, its light is on while it looks and being seen is the end (dragged up the beam), the passage mouth takes you in (no E), the rubble is a
  half-collapsed wall with a low hole you crouch through (`Player.force_crouch`), levers move -> runes light -> the chamber reacts, and after the choice a marker / hint always says what to do (`_guide`).
- **Words baked into pictures:** `game/tools/blender/make_chapter16_signs.py` draws every sign / stencil / the map from one text table with an `en` and an `es` column; `VeilLoc.tex(name)` (game/world/loc.gd) picks the file for
  `Game.language`. Anything new with letters on it goes into that table.
- **Still open:** #26 (the Colossus popping in before the Veil in chapter 3: needs a play session), #46 (the lag: not reproduced headless; the shelf picker scan was one real cause and is fixed).

## Update 2026-11-22 (late): notes #87 and the Chapter 15 start

- **#87** the entrances are SHUT when Chapter 15 starts (`_start_shut`) and a door is shut before it is barricaded (`_shut_door` in `_place_defense`), so a barricade never stands in front of an open door.
- **Chapter 15 from the menu:** the player starts on clear floor (`_clear_floor_near`), the group's standing spots are inside the room's real walls (`_in_room`), the player walks THROUGH the survivors in this chapter
  (their collision layer is taken off the player's mask: they walled off the kitchen so the back door could not be barricaded), and the stairs are closed with an invisible block at their foot (a climb over the TV left the
  player stuck upstairs). The house itself is still the shared mill-worker house (NOT scaled: see the chapter-15 notes above).
- **#26** extra: soft fog banks (`world.gd::_pre_mist_banks`) rise down the street ahead of the Colossus over ~25 s, so it walks out of a veil that was already there. Needs a play session to judge.
- **#46** not reproducible headless; the picker scan (the one measured hitch) is fixed. If the lag returns, capture `Performance` monitors during a long chapter 7 session.
- `chapter14_test` keeps its pre-existing failures (11 before any of this work); `chapter15_test`, `opening_test` (229/0) and the rest of the suite pass.

## Update 2026-11-22 (night): notes #88 - #96

- **#94 / #96 / #95** Chapter 8's backpack: the stuck objective was a pause bug (the note-view timer in `chapter7.gd::_note_tick` never ran while the inventory was open). The backpack now has an **OPEN THE BACKPACK** action in
  the inventory (`inventory_panel.gd::_open_backpack`), which shows Noah's note and sets `ch7_note_read`; closing the panel runs `_after_note`. The detail row is never squeezed by the weight line (`body.custom_minimum_size`, a gap before the foot). Test: `backpack_open_test.gd`.
- **#91** `game/world/bird_snatch.gd` (`VeilBirdSnatch`): scavenging at danger level 2+, three Grimtalons dive out of the mist; crouch within 3 s or be scratched, the second miss (or low health) = taken by the shoulders into the mist = YOU DIED. Hooked in `expedition.gd` (`_next_birds`, cooldown `birds_cooldown_s`). Test: `bird_snatch_test.gd`. *Needs visual test* (timing, framing, the lift).
- **#90** `street_life.gd::_edge_check`: within 35 m of the ground's edge a warning, within 6 m the no-escape snatch (same scene). "More forest at the edge" is NOT done: needs a visual pass.
- **#92 / #93** `game/world/street_life.gd`: traffic lights cycle green/amber/red by switching the lens materials per light (blink amber after the Veil); street lamps stutter now and then. Test: `street_life_test.gd`. *Needs visual test.*
- **#88 / #89** the two floating `VG_IvyPatch` instances were removed from `Greyhaven_Core.tscn`.

## Update 2026-11-22 (night, 2): notes #97 - #114, #46 closed, #26

- **#46** closed by the owner (wontfix). **#26** monsters: `expedition.gd::find_spawn` now refuses any spot within 55 degrees of the camera's look direction (at any distance), takes at least 32 m, and tries the rear arc first (24 of 48 tries), so hunters come out of the fog behind / beside the player. Test: `hunt_end_test.gd` (`spawns_not_in_gaze`).
- **Scavenging hunt flow** (`expedition.gd`): the doors shut again on a hunt once nobody is at them (#102); coming back in after being 6 m+ away asks END THE SCAVENGING HUNT? (`_ask_end_hunt`, #105); yes = `secure()` (doors shut, companion sent home), then a summary of what was found and, when nothing more can be done today, an offer to sleep (`_trip_summary`, #104). One hunt per day is the existing `scavenge_available`. The hurt (injured / serious) cannot be taken along (`survivors.companion_options`, #110).
- **Items** (#106/#107): hammer goes with the tape and boards; Noah's backpack AND note are removed when the note is done (`chapter7.gd::_after_note`).
- **Chapter 8 (`chapter7.gd`):** the alarm is now a bottle thrown at the parked car from `THROW_POS` (30 m from the wreck: `_throw_bottle`), the skitters go off WEST (#97); halfway back to the supermarket the pack returns out of the fog behind the player, a short look-back cutscene, then a chase at 5.2 m/s (sprint is 4.3), they stop at the glass (`_pack_cinematic`, `_pack_run`, #98); the skitter lunge triggers at 7.5 m and runs 16 m/s (#103).
- **Chest** (#99): `game/ui/storage_panel.gd` (`VeilStoragePanel`): two 5x5 grids with item pictures and amounts (stored / carried), click or shift-click to move; `phase4._open_supplies` uses it (the old text menu stays behind `world.use_text_supplies` for tests). Test: `storage_panel_test.gd`.
- **Shops** (#100): the gas station and the two clothing stores get hinged doors (`store_interiors.gd::_hinge_doors`).
- **Gas station chase** (#101): `living_town.gd::_joan` is a cinematic (the view is taken, a camera on the forecourt follows Joan and the Hound, a fade back), the Hound starts on the forecourt instead of inside the wall.
- **Chapter 9 (`chapter8.gd`):** the breaker panel is animated properly (door, cable, lever, main switch, door; lever and switch are reset to tripped first, #108); the break-in has no cut to black: the Hound drags the temporary survivor out in plain sight, the others WALK to their next places, Sarah backs into the Hound's path on her feet, the player's moves are real runs (`_fp_move` is at least 3.2 m/s), the pallet stack is visible from the start (#109).
- **Car** (#111/#112): the fuse close-up hides the driver door while the camera is at the panel; the pouring can now tips about the right axis with its spout INTO the car, and the car has a fuel door (`car_quest.gd::_fuel_door`, built once, opens for the pour).
- **Poles** (#113/#114): two utility poles moved off the road (007 to x=-9, 008 to x=41 so the back entrance is clear) in `Greyhaven_Core.tscn`.
- *Needs the owner's visual test:* the thrown bottle and alarm, the returning pack and chase, the end-of-hunt question flow, the storage grids, the shop doors, Joan's camera, the breaker animation, the break-in scene without the cut, the fuse close-up (#111 is a guess: the cause of the "box" could not be rendered), the fuel door and the can, the moved poles. #26 needs a play session.
- Pre-existing failures unchanged: `expedition_test` (5), `chapter7_test` / `chapter8_test` start with walk failures in headless; `living_town_test` (5), `car_quest_test` (2).

## Update 2026-11-22 (night, 3): Chapter 9 cashier rescue branch (`chapter8.gd`)

- The break-in is now a choice with consequences. The Hound bites the cashier (slow-motion beat), then DRAGS her slowly (7 s) towards the breach while the player's hands are free ("SHE IS BEING DRAGGED OUT - RUN TO HER!"). Reaching her (2.3 m) pauses the drag and starts the click struggle
  (`Struggle.rescue`, 7 s). Outcomes:
  - **Saved** (`ch8_temp_survivor_saved`): the Hound recoils, the cashier limps to `TEMP_SAVED` (and sits among the group later), the Hound turns on Sarah (Sarah's bite stays canon: Ruth shouts "SARAH, NO"); survivors.json: morale +5, Ruth +3 / Eddie +2 trust.
  - **Tried and failed:** the drag resumes, she is gone (`ch8_temp_survivor_died`, morale -10, `c8_cashier_lost`).
  - **Never went to her** (`ch8_cashier_abandoned`, plus died): Ruth blames the player (`c8_cashier_abandoned`, morale -5, Ruth -4 / Eddie -2 trust, memory `blamed_you`).
- Everything that waited for "the cashier died" waits for `_resolved()` (died OR saved). The aftermath talk opens with an outcome line (`c8_after_saved / _lost / _abandoned`) then the usual `c8_aftermath`.
- Not covered by a headless test (the chapter 8 test fails on its walking steps; a dev set-up overwrites the owner's save): *needs the owner's play-through of all three outcomes.*

## Notes #115-#117 (2026-11-22) - Chapter 8 backpack, bottle, pack at the doors
- #115: the backpack interaction box is 2.6 x 1.8 x 2.6 (seat + 0.9 m outward), so aiming at the backpack or the open door is enough.
- #116: a bottle lies on the road at THROW_POS (`_bottle_prop`). E: Marcus turns, points out the sedan (`c7_throw`), the player turns to the car, picks the bottle up, winds up and throws it (spin, arc), glass on the car, alarm + four amber lights blinking 8 s (`_alarm_lights`).
- #117: when the pack chase starts Eddie walks to the doors and holds them open (`_eddie_holds_door`, `c7_pack_eddie`). Skitters can never cross the door line (`_pack_step`). Near the doors `_pack_door_cine`: first-person sprint through, turn, Eddie shuts the doors (`c7_pack_door`), three slams, they scatter and leave unseen.
- All need the owner's visual / play test (timing, Eddie's walk to the door, light blink look). chapter7_test fails from the first walking steps headless as before.

## Notes #118-#120 (2026-11-22)
- #118: the backpack interactable joins the `veil_pickup` group with the car's colliders in `los_ignore`, so the player's aim assist offers it through the cabin collision.
- #119: only the backpack is added on pickup; "OPEN THE BACKPACK" (inventory) adds Noah's note and shows it (`inventory_panel._open_backpack`).
- #120: `game/encounters/run_struggle.gd` = click-to-run along a SET PATH (no world collision): bar progress = distance along the path, chasers run the same path from behind; idle / slow = caught. Needs `Struggle.rescue_progress()` / `abort_rescue()`. Test `run_struggle_test.gd`.
  - Chapter 8 skitter pack (`chapter7.gd::_pack_run_struggle`): Eddie is placed inside the vestibule (left of the way in) holding the doors; path = road -> door -> vestibule opening (1.1,1.4) -> (1.5,3.0) -> hall. Win: `_pack_door_finish` (turn, Eddie shuts the doors, three slams, they run back WEST). Lose: `_pack_caught` (dragged into the mist, YOU DIED).
  - Chapter 7 Hound (`chapter6.gd::_hound_struggle`, only when `flee_enabled and scripted_chase`): after the entrance leap the same cinematic along CHASE_ROUTE; win = `_complete_encounter`, lose = pounce + the bad-bite `_checkpoint`.
- All need the owner's play test (path lines, timing: lead 34 m / 5 m/s for the pack, 10 s for the Hound, Eddie's spot). chapter6_test still has one failure (c6_rs_talk_camera, talk camera, not touched).

## Notes #121-#127 and the Chapter 9 / 10 rework (2026-11-22)
- #121-#126: bag hint (no pointer) + wider aim cone for pickups behind their container (`player._assist_pickup`: `los_ignore` pickups use ~20 degrees / 45 cm); no scavenging between the break-in and the next sleep (`expedition._after_attack`); Chapter 10: the supply bin (shelter supplies) emptied = food & water done (`chapter9._check_bin`), box stack hidden, no flashlight step, no checklist objective, tipped gondola removed.
- The aisle (Chapter 9, `chapter8.gd`): `game/world/gondola_aisle.gd` cuts the supermarket's gondola at (9.5, 0, 10) (next to the rear doorway) out of the baked furnishing mesh + its concave collision and lifts its products off the shelves (`StoreMerch.detach_region`); the prop (same gondola model, products as MultiMeshes, box collider) is `c8._secure_pallet`. `c8._shove_aisle(from_t, to_t, ...)` = click struggle (player + Eddie), used to shove it across the doorway (`_push_secure`) and to pull it clear in Chapter 10. Test `gondola_aisle_test.gd`.
- Poses: `NpcAnimator.set_downed("side" | "back" | "")` = lying hurt on the floor / dragged on the back (replaces the chair pose for Sarah, the cashier, the pinned Marcus). Test `downed_test.gd`.
- Music: the hound chase loop plays from the Chapter 9 break-in until the entrance holds, and from the Chapter 10 warning to the end of the run.
- #127 (Chapter 10, `chapter9.gd`): warning = three hounds at the FRONT glass (`_spawn_front_hounds`, `_assault_loop`) -> the player and Eddie pull the aisle off the back door (`_shove_aisle(1,0)`) -> the front doors burst, `_front_burst_and_run`: click-to-run along a set path to the back corridor with Eddie, Ruth, Sarah, Marcus and the clerk running beside; the clerk (named WALT in subtitles, `world.cashier`, flag `ch9_clerk_dead`) is taken by a hound at 45 % of the way (`_clerk_taken`); fail = dragged back, YOU DIED. `run_struggle.gd` got `events`, `min_time`, dead allies.
- All of it needs the owner's play test (headless tests only cover the pieces: run_struggle, gondola_aisle, downed). Chapter tests that walk still fail headless as before.

## Chapter 10 fall, redone as one scripted sequence (2026-11-22, owner feedback after note #127)
`chapter9.gd::_run_fall` (displayed Chapter 10): everything is a set path (no teleports) and each line is spoken while the people do what it says.
1. Sarah stands up (`NpcAnimator.set_downed("")`) and runs with a limp (`NpcAnimator.limp`); Eddie and Marcus walk to the east end of the aisle that blocks the back doorway, Ruth / Sarah / the clerk Walt to the doorway, the player runs a set path to the east end (`_player_walk`).
2. The ONLY click struggle (`_pull_aisle`): pull the aisle east off the doorway (`_aisle_set(0..1)`, `_end_spot`); Eddie and Marcus pull beside the player.
3. `_pass_through`: Ruth, then Sarah (limping) go through the doorway and out the back to wait in the lot (`_out_waiting`, they join in `_escaped` without snapping). `_front_burst`: the front doors burst, three hounds run in; the lead one takes Walt, who froze (`_run_to_walt`, flag `ch9_clerk_dead`); the other two ram the aisle.
4. `_push_back`: the player, Eddie and Marcus push the aisle back across the doorway; half way `_marcus_grabbed`: a hound drags Marcus to `MARCUS_DOWN` and pins him; the player has `pin_window()` seconds (trust based): [E] `_free_marcus` (he is hauled up, the hounds recoil, they finish the push together) or run (`_marcus_lost`: he is dragged off into the store, no black screen, Eddie finishes the push).
5. `_finish_aisle` -> `_after_aisle`: Eddie (and Marcus) follow the player out through the staff door; `_escape_tick` / `_escaped` as before.
Loads in the middle: `_apply_fall` rebuilds it (aisle across the doorway, Ruth and Sarah in the lot, Marcus back on the floor if undecided). Test: `scripts_compile_test.gd` (every story script compiles) and `downed_test.gd` (lying poses, limp). The old `chapter9_test.gd` still describes the previous flow and fails headless; the whole sequence needs the owner's play test.

### Chapter 10 fall, second rework (2026-11-22, same day) - supersedes the step list above
- The cinematic starts right after the last word with the crew (`_warning_later` holds the controls every frame until `_run_warning` has them): no wandering to the doors.
- Every walk is a computed route round the real furniture/doors (`_route` = `world.npc_route(market, from, to, null, true)`), for people, hounds and the player (`_player_run`); `fall_routes_test.gd` checks the legs exist in the real store.
- Pull struggle = Marcus + the player (Eddie takes Ruth and Sarah out through the doorway once it is open). Push back = Marcus + the player; half way a hound takes Marcus and the player gets "E - HELP MARCUS" (`pin_window() * 0.55` seconds, min 3.5). No help: Marcus dragged off, `_exit_cinematic(false)` (the player opens the staff door, runs the corridor, leaves by the rear exit and hauls the rear door shut). Help: second struggle `_help_marcus` (pull him free), finish the push, `_exit_cinematic(true)` (Marcus opens the staff door and goes first, the player follows and shuts it, then both out and the rear door is shut).
- `ch9_fall_started` is now set only at the end, just before `_escaped()` (a load in the middle replays the warning). Frantic music for the whole sequence: hound chase loop + skitter chase loop layered (`_frenzy`), back to the gameplay music at the end.

### Chapter 10 evacuation, rebuilt as one controller (2026-11-22, brief "Task: Rebuild displayed Chapter 10's supermarket evacuation") - supersedes the two sections above
- `game/world/evacuation.gd` (created lazily by `chapter9.gd::_evac()`; `chapter9.gd::_run_warning()` starts it, `_evac_resume()` on loads) owns the whole sequence. Phases (enum `Phase`, table `PHASES` = actors / doors / input / camera / advance): PREP, WARNING, APPROACH, PULL, EVACUATE_AND_WALT, RETURN_TO_PUSH, HALF_PUSH, MARCUS_ATTACK, CHOICE, SAVED / LOST, STAFF_EXIT, REAR_EXIT, REGROUP. The phase is saved in `st()["evac_phase"]`; safe checkpoints (`world.save()`) before PREP's first beat and after REGROUP; Walt (`ch9_clerk_dead`) and Marcus (`ch9_marcus_saved` / `_lost`, never both) are flagged the moment they happen; a load with an outcome resumes at the staff door, otherwise it replays from the warning.
- Control: `_own_player(true)` is called synchronously by the call that completes the preparation (`chapter9._check_prepared` -> `_run_warning`), `_process` re-forces `controls_enabled = false` every frame while running and is the ONLY writer of the camera (`_look(target)` with smoothing, route look-ahead). Inputs: the pull struggle, E in CHOICE, the optional rescue struggle.
- Movement: `_route` (grid search over the real colliders, string-pulled, per-actor radius: person / player 0.28, hound 0.4 at body height 0.7 so it steps over the kerb) returns `[]` when there is no way: NO straight-line fallback. `_move` sweeps every step against layer 1 (static world + the moving shelf and door leaves), waits / re-routes / fails and reports (`report["failures"]`); `_recover` places a failed actor only out of the camera's frustum. Doors: arrive -> open -> passable angle -> cross -> clear -> close (`_open_staff`, `_open_rear`, `_clear_of_staff`).
- Markers: the brief's, with two validated corrections - the staff doorway is only ~0.8 m wide at x 15.5 (leaf lies across x 14.8..15.2, z 14.4..15.4) so STAFF_APPROACH = (15.5, 13.4), STAFF_CLEAR = (15.6, 15.9); the rear doorway throat is at x ~8.1, so REAR_DOOR / REAR_INSIDE are x 8.1. The camera cannot see the pinned Marcus from the half-push position (the shelf end is in the way), so the player staggers back to RECOIL (13.1, 12.3) during the attack.
- Roles: hound A takes Walt (dragged along the open lane, validated legs), B rams the barricade end, C lurks and takes Marcus. Eddie leads Ruth and Sarah (limp 0.7, 1.0 and slower when `_injured()` is serious) out through the opening and never comes back; Walt is seen from VIEW_ROUTE.
- Audio: the hound chase loop + the skitter chase loop; `_say` queues lines one at a time (critical lines never overwrite each other, movement continues under subtitles) and the music dips while a line is on screen (`Sfx.trim_music`).
- Tests: `fall_routes_test.gd` (every marker free for its body size, every leg swept clear, the blocked doorway route must FAIL, the mover walks a real route and refuses the blocked doorway and reports it, camera lines of sight, door passable angles, the phase table), `scripts_compile_test.gd`. NOT done and NOT claimed: the two recorded runs the brief asked for (the owner's rule: no screenshots / renders / videos), reload-at-each-stage runs, chapter-select runs and all three trust levels end to end - they need the owner's play session.

### Displayed Chapter 11 ("No Safe Road", chapter10.gd) - directed moments (2026-11-22, brief "Repair displayed Chapter 11's staging...")
- One scene owner at a time (`Scene` enum, `_acquire` / `_release`, table of activation / actors / camera / input / completion / save-load in the comment above the enum). `_road_tick` starts at most ONE scene per update, each from its position AND its predecessor's completion flag: car -> roadblock -> (gate: the player's) -> hound reveal -> skitter -> Sarah -> outskirts -> refuge entry -> rest. Only the owner gives the controls back; `_process` re-forces them off while a scene owns the moment. Camera only through `_look(target)` (smoothed tracker in `_track_camera`).
- `game/world/scene_mover.gd`: world-space scripted walking with PROBED floors (steps and the raised house floor), actor-sized swept clearance, `[]` when there is no route (no straight fallback). Survivors walk the swept route with their own animator and the mover watches for stalls and reports them (`failures`); the player is walked manually with physics off.
- Car: the player is walked to DRIVER_STAND / TRUNK_STAND, the companions are parked at CAR_WAIT (not crowding), the camera stays outside the car, door sound with the door, gauge read with the line, pickup after the search; battery / water granted once (flags set with the item). Roadblock: the view takes in the van / pickup / barriers (`_see_prop`), then turns to the gap. Hound reveal waits until every companion MEASURABLY is past the gate (x < -45.8), is held through the short reveal, and is only flagged (`ch10_creature_seen`) at its END after the hound was really seen (fence ignored as see-through) and went behind the building block. Skitter crossing only after the reveal, never with Sarah's talk. Sarah: the group WALKS into a roadside pocket (SARAH_POCKET), Ruth faces Sarah, the choice is never answered by skipping; help = she lies down for the hour and the cost is paid once (`st().help_paid`); her limp / pace is recomputed from the previous chapter's record (`_apply_sarah_state`), a serious wound is never erased by rest.
- Refuge: the player checks the room, then the companions come in one at a time (Eddie, Ruth, Sarah, Marcus) through the open door, the next one starts when the last MEASURABLY crossed the door line (house-local z > 4.0); failures re-open the door and re-route and are reported (`report.entry_failures`); no timeout teleports. Rest: black-screen reposition to WAKE_POS, fade in, a slow walk to WINDOW_VIEW, the view through the window (`window_target`, line-of-sight checked), the call, a beat, the card, then chapter 12.
- Tests: `chapter10_staging_test.gd` (markers free with door, trunk, gate and house door open; routes over the real ground and the house steps; the roadblock must STOP a route and a walker; a walker really crosses the gate and the house door line; the van / pickup are visible; the hound is hidden at the end of its path; the window gives a view), `scripts_compile_test.gd`. The OLD `chapter10_test.gd` was NOT updated: it still describes the previous undirected flow and fails headless. Not done / not claimed: recorded runs (owner rule: no screenshots / videos), all save/load stages, marcus lost x sarah serious x choices end to end, slow / fast / backtracking players.

### Owner feedback round (2026-11-22, "wrong store clerk", floating runners, clunky hounds, rendezvous the wrong way round, GOLDEN RULE)
- **GOLDEN RULE: never fix an NPC's position unless it is a safe zone, and even there they WALK to their set coordinates from wherever they are.** In the live sequences nothing is placed any more: `evacuation.gd::_recover` re-walks and REPORTS instead of placing, `resume()` replays from the checkpoint (outcome flags cleared) instead of teleporting actors into a later stage, the rendezvous arrival walks the group in. Placement remains only for loads / chapter select (`_place_rendezvous`, `_place_inside`, `_apply_*`), which are restorations, not live play.
- **David, not the cashier**: the character who dies in the supermarket is the Chapter 5 survivor (green apron, orange hair, speaker "Survivor" = DAVID), and only when the player pulled him free in Chapter 9 (`ch8_temp_survivor_saved`). Otherwise there is no such scene: the next beat is Marcus's. `evacuation.gd::_david()`, `_david_attack()`, flag `ch9_clerk_dead` (kept name). The cashier is not used.
- **Marcus is a CHOICE** now (`p4.choice.ask`: "Go back for Marcus" / "Keep running - leave him"): no E prompt, no timer.
- **Running**: survivors walk their routes with their own animator through `scene_mover.gd` (real run cycle at a real speed: `RUN_PERSON` 4.6, the player 4.3), the doors open as the first runner comes within reach (`_door_watch`), the mover waits up to 1.2 s for a leaf that is still swinging before calling a route impossible. **Hounds** never stand still: `_hound_laps` runs loops of real routes with a crouch (Alert) and a lunge every other stop (A closes on David, B attacks the barricade end, C circles the south until Marcus's moment).
- **Rendezvous**: a house on the way the group goes NEXT: `chapter9.RV_HOUSE = "HOUSE_04"` (porch faces the back lots, 22 m west of the store's rear lot; the old Ruth and Sarah house is east, the wrong way). The hall places are found on the real floor (`_rv_spots`), the companions walk in one at a time over the door line (`_rendezvous`), chapter 11 starts there with `_route_i = 2`. Test `rendezvous_house_test.gd`.

- Rendezvous house corrected: HOUSE_04 was too small (about 45 reachable floor cells); `chapter9.RV_HOUSE` is now HOUSE_05 (the big Chapter 5 survivor house, about 200 reachable / 90 roomy cells, 19 m from the store rear lot). Everybody now runs in together (0.35 s stagger, they pass each other, never a wall) in the rendezvous and in the Chapter 11 refuge; no queueing at the door.

- Rendezvous arrival: the player now WALKS on into the living room first (`_rv_spots()["Player"]`: the most open deep cell), turns to the door, then the companions run in together and the last one in shuts the door behind them (only once nobody is in its swing). `scene_mover.route()` bans edges that a real sweep refuses (thin rails) and re-searches; a climbing leg is swept level at its goal floor so steps are not walls for the manual (player) walk.

### Audio overhaul + notes #128-#133 (2026-11-22)
- `game/audio/veil_score.gd` (child "Score" of the Sfx autoload; `Sfx.jumpscare(kind)`, `Sfx.play_stream_at`): synthesised on a thread at start-up (about 8 s, silent until then): three seamless dark drone layers (14 / 17 / 19 s: sub + beating minor second, diminished-cluster pad, inharmonic low metal), a heartbeat that rises with the nearest hunter / a struggle, ambient events every 9-24 s under the Veil (distant hound, Colossus, roof, metal, house creaks and knocks indoors), and the jumpscare: hush -> sub boom + the creature's own stinger + screech -> FOV punch + flash -> muffled world (Master low-pass) -> thundering heartbeat. Master bus now has an EQ that cuts the top end, a touch of room and a limiter. The interaction sounds (pickup, door open / close) were redone low and soft (peaks 60-900 Hz instead of 1.4-2.2 kHz). Hooks: struggle start, chapter 7 hound leap (`chapter6.gd`), Chapter 9 bite, bird snatch, skitter pack appearing, evacuation door burst + Marcus taken. Test `audio_score_test.gd`. NOT verified by ear: levels and taste need the owner's ears; the sounds are synthesised, real recorded assets (or an audio-generation tool / sound packs) would lift it further.
- #128 `game/world/car_lost.gd` (+ `world.enter_car` refuses after `ch9_supermarket_lost`: line `car_lost`): three skitters circle the car whenever the player is near it outdoors, none inside a house. #129 fence / gate are placed on the ground (`chapter10._prop_ground`). #130 the road progress can no longer dead-end (a skipped hound reveal is flagged, not waited for). #132 the stock-room chair turned round; the officer now jogs to his spot (3.4 m/s, 5 s cap). #133 `game/world/mailboxes.gd` (63 street mailboxes, each decided once by position, saved in `world_state.mailboxes`). #131 is too general (which sequences?): left open, asked the owner. Test `mailbox_carlost_test.gd`.
