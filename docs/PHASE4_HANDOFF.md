# THE VEIL - Phase 4 handoff: the first night in the supermarket (Act I, WORKING DRAFT)

This is a brief for a second Claude session to build the **next story beat** while another session finishes the
apartment fridge fix and other polish.

**Read first, in this order:**

1. `docs/THE_VEIL_MASTER_CONTEXT.md`, the bible. Sections 2-5 and 11 matter most, plus the `UPDATE 2026-11-04`
   notes.
2. `THE_VEIL_ASSETS_V2/Documentation/STORY_CANON_DECISIONS.md` and `STORY_ACTS_AND_QUESTS.md`.
3. `game/README.md` and `docs/HANDOFF.md` sections 9.x (how the game, tests and builds work).

## 1. Where the story is now (end of Phase 3, playable)

1. Friday 6:42 PM. The protagonist wakes, finds an almost empty fridge, takes the keys and drives into town.
2. Errands in either order:
   * the supermarket: shopping list, a cashier at lane 4;
   * the game shop: Eddie sells a horror game.
3. Once outdoors with both errands done, the Veil rolls in:
   * the Pack 09 atmosphere moves to VEIL_ACTIVE, and the cashier vanishes;
   * the Colossus is glimpsed far off (view lock);
   * mist tentacles in Main St knock the player back;
   * the car is dead.
4. Eddie calls the player into the game shop. Marcus is there looking for his son Noah. All three agree to shelter in
   the supermarket.
5. The player crosses Main St. Eddie and Marcus are already inside, the power is out, and the player pulls the jammed
   automatic doors shut. The end card reads **"THE VEIL - ACT I"**.

All Phase 3 lines are `"draft": true` in `game/data/dialogue.json`. Flags run `p3_mist` -> `phase2_done` ->
`p3_in_shop` -> `p3_in_market` -> `p3_doors_shut`.

## 2. Proposed Phase 4 - "Lock-in" (WORKING DRAFT: confirm with the owner before locking anything)

The bible (Act I) says the supermarket is an early refuge and survival systems begin to matter: light, food/water,
health, inventory weight, locked routes. Keep the scope to **one contained night inside the supermarket**:

1. **Secure the store** (objective chain):
   * find the back-room breaker (`RES_ElectricalPanel` sits at supermarket-local (19.9, 1.2, 14.9) in BACK) to bring
     back emergency lighting;
   * check the loading door (`INT_GarageDoor_Loading`) and the back exit (`INT_Door_BackExit`); lock or barricade
     them. Pack 09 `ABN_EmptyBarricade.tscn` can be used.
2. **First survival tools** from shelves and the back room. Pack 08 already has flashlight-type items, batteries,
   first aid, food and water: check `08_Inventory/Documentation/INVENTORY_MANIFEST.md`.
   * A **flashlight** with battery drain is the key new system (bible 7: flashlight and limited visibility).
   * Keep all values configurable and marked placeholder.
3. **Survivor scene:** Eddie and Marcus disagree. Marcus wants to go back out for Noah; Eddie wants to wait for
   daylight. The player's dialogue choice is only recorded as a flag. `Dialogue` already supports `choices` (see
   `game/autoload/dialogue.gd`), but the HUD may need a choice UI.
4. **A scare without combat:** something tests the doors or the loading bay. Use a Hound silhouette (Pack 07 Hound,
   currently excluded from exports, see section 4) or tentacles pressing at the glass, plus sound and flickering
   lights (`Lighting/veil_flicker.gd`).
5. **Rest:** sleep in the back room / office to end the night. Title card "SATURDAY", then the end card for Phase 4.

**Do not invent permanent canon.** In particular, do not decide:

* Noah's age, appearance or fate;
* Officer Hayes or the other secondary cast;
* the mist's origin;
* which deaths are scripted;
* the Day 7 breach rules.

Mark every new line `"draft": true` and log the choices in `STORY_CANON_DECISIONS.md` under "Production choices
awaiting owner confirmation".

## 3. How to build it without colliding with the other session

* **Put the code in a new file**, e.g. `game/world/phase4.gd` (a Node added by `world.gd` once `p3_doors_shut` is set).
  Keep edits to `world.gd` minimal and outside the fridge code (`_stock_fridge` / `_on_fridge` / the Fridge
  sections), which the other session owns.
* **Don't touch** Pack 03 furniture (`furniture.py`, `RES_Fridge_*`) or regenerate Packs 03/04 without coordinating.
* **Reuse what exists:**
  * Objectives are data (`game/data/objectives.json`). Steps complete in list order; add a new goal, e.g. `act1_night`.
  * Dialogue and items are data too (`dialogue.json`, `items.json`).
  * `Interactable.attach(node, cfg)`: kinds hinge / slide / pickup / toggle / observe / custom (`game/interaction/`).
  * NPCs: `world._spawn_npc()` + `NpcAnimator` (`game/npc/npc_animator.gd`): `talk()`, `set_mood()`, `walk_to()`
    with waypoints, look-at. Eddie and Marcus are children of the supermarket node after Phase 3
    (`world.eddie`, `world.marcus`).
  * Atmosphere: `world._atmo().set_state(n)` (0 NORMAL ... 4 CORRUPTED) and `apply_preset()`. The presets include
    `LGT_Empty_Supermarket.tres`.
  * `world.focus_shot(target, fov, t_in, hold, title)` for view locks; `world._beacon(id, pos)` for markers;
    `world._glow(node, on)` for highlights.
  * Supermarket layout: rooms, doors, `Interaction/*` and `NavTargets/*` markers are in
    `04_Commercial/Godot_Scenes/Supermarket.tscn` (local coordinates). The node is rotated 180° in the world. Use
    `market.to_local()` / `market.global_transform`.
* **Saves:** add the new flags to a restore helper like `_p3_restore()` so that loading mid-Phase 4 works.
* **Test (required):** extend `game/tests/opening_test.gd` after the `p3_end` checks.
  * It runs the whole game headless in about 1 minute and must end with `RESULT PASS`:
    ```bash
    godot --headless --path . --fixed-fps 60 --script res://game/tests/opening_test.gd -- 50
    ```
  * After deleting Godot side-effect files, run `--import` first.
* **Exports:** Web (`docs/play/`) and Windows (`docs/download/TheVeil_Windows.zip`).
  * Presets are in `export_presets.cfg`. If you use the Hound or another Pack 07/06 asset, remove it from
    `exclude_filter` in both presets.
  * Windows template trick: see HANDOFF 9.7.
* **Hygiene:**
  * Godot rewrites `.import` files and extracts loose PNGs when the project is imported in the repo. Revert and
    clean them before committing:
    ```bash
    git checkout -- $(git diff --name-only -- '*.import')
    ```
    then `git clean` the untracked PNG / `.translation` files.
  * Fetch and rebase before pushing (the other session pushes to the same branch).
  * Use the commit footer from `docs/HANDOFF.md`.
  * No screenshots unless the owner allows them; never claim visual verification.

## 4. Open questions to ask the owner

1. Is "one night in the supermarket" the right next beat, or should Phase 4 follow Marcus out into the mist?
2. Is the flashlight + battery the first survival system? Hunger, thirst and health can wait.
3. Can the Hound appear yet, or only be heard?
4. Name and title for the horror game the protagonist bought (still a placeholder).
