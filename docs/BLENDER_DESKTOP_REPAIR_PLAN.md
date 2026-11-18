# THE VEIL — Blender desktop repair plan

Written during the full-game audit (branch `audit/full-game-review-2026`, source `claude/practical-cray-hi2y54` @ `1f9d5b8`).

**Read this first.** The cloud session that wrote this had **no Blender, no Windows PC and no GPU**. Nothing here was seen on screen.
Every "defect" below is labelled with how it was established:

- **MEASURED** — read directly from the GLB / scripts / tests; reproducible without looking at the game.
- **REPORTED** — the owner saw it in play (screenshot or message) and it is not re-verified here.
- **SUSPECTED** — a hypothesis from the data; confirm on the desktop before changing anything.

Rules for the desktop session: work on a branch, one asset per commit, never overwrite an original (the helper scripts
write copies), re-import in Godot 4.3 and run the verification listed for the task. Don't regenerate a whole character or
monster when a targeted correction does the job. Every asset is built by a Python script in
`THE_VEIL_ASSETS_V2/<pack>/Source_Scripts/` — prefer fixing the generator (then re-running it) over hand-editing a GLB,
unless the task says "by hand" (rigged assets).

## Helper scripts (this branch, `tools/blender/`)

| Script | What it does | Status |
|---|---|---|
| `inspect_asset.py` | Read-only: triangles, bounds, origin height, bones, every action's frame range and the **lowest bone point per action** (floating/sinking feet), materials without textures. `blender -b --python tools/blender/inspect_asset.py -- a.glb b.glb` | Syntax-checked only. Run it on one known asset first and compare with the numbers below. |
| `rebase_pivot_copy.py` | Moves a static prop's origin to the centre of its base and writes a **copy**. Refuses armatures, multi-root files and `out == in`. | Syntax-checked only. Verify on one prop before any batch. |

## Godot import requirements (all tasks)

- Export **glTF Binary (.glb)**, +Y up, "Apply Modifiers" on, **no** Draco, tangents off.
- Keep node names exactly: collision hulls end in `-convcolonly`; interactive parts are named `INT_*`
  (the game finds doors, drawers and handles by these names).
- Keep bone names exactly (humanoid: Hips, Spine, Chest, UpperChest, Neck, Head, Left/Right Shoulder, UpperArm, LowerArm,
  Hand, UpperLeg, LowerLeg, Foot, Toes, plus the `Socket_*` bones). Rename = broken animator.
- Textures stay embedded, **nearest** sampler (PSX look). Do not add normal/roughness maps.
- Existing clip names must not change; add new clips.
- After export: `godot --headless --path . --import`, then run the task's test.

---

## B1 — First-person arms: hand and finger poses  ·  Priority HIGH  ·  Complexity M

- **Asset:** `THE_VEIL_ASSETS_V2/06_Characters/Protagonist/CHR_Protagonist_FP_Arms.glb` (and `..._v1.glb`, unused).
- **Defect (MEASURED + REPORTED):** one T-pose rig, **no animation clips**. All first-person hand motion is code
  (`game/world/home_bathroom.gd`: two-bone reach + `_aim_hand`). When the hands come together to cup water the fingers fan
  out flat at the camera (owner screenshot, session of 2026-11-04; not stored in the repo).
- **Expected:** believable hands for the moments the game already stages: cupped palms (handwash), a closed grip on the
  flashlight, an open reach, a push, a grab (tentacle/skitter struggle), relaxed idle.
- **Blender work:**
  1. Keep the mesh and skeleton. Author **pose clips** (single or two-frame actions) on the hand and finger bones:
     `FP_Relaxed`, `FP_Cup` (fingers together and slightly curled, thumbs side by side), `FP_Fist`,
     `FP_FlashlightGrip`, `FP_ReachOpen`, `FP_Push`.
  2. Check arm length: shoulder-to-wrist should be ≈ 0.60-0.65 m at the model's scale so the two-bone reach in code does
     not need to stretch (`la`, `lb` in `_pose_arms`).
  3. Do not add a walk cycle; the camera bob is code.
- **Rig / mesh / UV:** no mesh or UV change. Finger bones only. Keep `Socket_LeftHand` / `Socket_RightHand`.
- **Export:** as above, actions pushed to NLA tracks so they export as clips.
- **Godot side after export:** `home_bathroom.gd` `_pose_arms` should blend the pose clip onto the fingers instead of
  leaving them at rest (small code change; do it in the same commit). Remove the fan-out workaround.
- **Verify:** `godot --path . --script res://game/tests/handwash_test.gd` (logic) **and** play the first-day wash:
  palms should be a cup, not a fan. Needs a visual check on Windows.
- **Depends on:** nothing. Unblocks any future first-person item use (flashlight hold, door handles, pickups).

## B2 — Skitter: ground contact and the struggle clips  ·  Priority HIGH  ·  Complexity M-L

- **Asset:** `THE_VEIL_ASSETS_V2/07_Creatures/Skitter/CRT_Skitter.glb` (+ `Godot_Scenes/CRT_Skitter.tscn`).
  Used by `game/encounters/roof_skitter.gd` (optional encounter at `EXT_HOUSE_12`) and the Chapter 5 night scene
  (`game/world/phase4.gd`).
- **Defect (REPORTED, documented by its author):** `docs/CLAUDE_SKITTER_HANDOFF.md` says the rooftop Skitter "still
  visibly floats" and that its automated tests do not prove the look. Not re-verified here.
- **MEASURED facts to start from:** clips = `Alert, Attack_Lunge, Crawl, Death, Hit_React, Idle_Twitch, Scuttle_Fast`;
  rest-pose lowest point is 0.0028 m above the origin; the rig faces **+Z**; the code uses a measured `feet_y` and a
  vertical ray to place it, so any clip whose feet leave that height will read as floating or sinking.
- **Blender work:**
  1. Run `inspect_asset.py` on the GLB: for **each clip** note "lowest bone point". The feet should touch 0 ± 0.01 m in
     the stance phase of `Crawl` and `Scuttle_Fast`. If a clip drifts, fix the root/hip offset in that clip.
  2. Make sure no clip contains root motion (the code moves the body; baked travel causes the sliding the author saw).
  3. Add clips the encounter currently fakes by looping `Attack_Lunge`: `Struggle_Bite` (loop, mandibles working, front
     legs reaching), `Thrown` (tumble, ~0.5 s), `Land_Recover` (settle onto six legs), `Threat_Hiss` (front legs raised -
     start from `Alert`). Keep each ≤ 1.2 s.
  4. Zigzag retreat is code (waypoints); only the gait speed must match: record the stride length of `Scuttle_Fast`
     (metres per cycle) in the clip metadata (`metadata/scuttle_speed_mps` exists in the .tscn: update it).
- **Export / import:** as above; keep the 33 bone names; keep the five existing metadata entries in `CRT_Skitter.tscn`.
- **Verify:** `roof_skitter_handoff_test.gd`, `accept_branch_test.gd`; **visual check required** on Windows (approach the
  house from the front; watch the crawl, leap and the retreat).
- **Depends on:** none (the Godot fixes for hover/route are separate and listed in `VERIFIED_BUGS.md`).

## B3 — Sidewalk dark marks  ·  Priority MEDIUM  ·  Complexity S-M  ·  SUSPECTED

- **Reported:** repeating dark V-shaped marks along every pavement (owner screenshot, 2026-11-04; the owner stopped the
  investigation to save credits, so it was **never diagnosed**).
- **Suspect:** the cracked sidewalk variant. `models_roads.py::sw_module(cracked=True)` paints a random third of the 1 m
  segments with `Road_ConcreteCracked` (`T_Road_ConcreteCracked.png`, 128 px: black branching crack lines on grey).
  Tiled per metre, the black lines would repeat as dark marks. Not confirmed; the owner described a larger solid shape.
- **Blender / script work:** (1) in a scratch scene place `SW_Straight_10m_Cracked.glb` next to `SW_Straight_10m.glb` and look
  at the UVs: one UV tile per 1 m segment? (2) If the marks are the crack texture, lower its contrast (crack lines
  dark grey, not black) and stop tiling it per metre (random UV offset/rotation per segment) in `models_roads.py`, then re-run
  `build_town.py` for the sidewalk pack. (3) If they are not, orbit the street in the game's free camera
  (`--trailer`, F8) over a mark and note which object/material owns it.
- **Verify:** same view before/after. Visual check required.
- **Dependencies:** none.

## B4 — Origin conventions for wall-mounted and bathroom furniture  ·  Priority LOW  ·  Complexity S

- **Assets:** `03_Residential/Furniture/RES_MedicineCabinet.glb`, `RES_TowelRack.glb`, `RES_BathSink_Pedestal.glb`,
  `RES_Bathtub.glb` (and `RES_Dryer.glb`).
- **MEASURED:** the cabinet's origin is at the **centre** of the mesh (±0.33 m in Y), the towel rack's is not at its wall
  side, while floor furniture has the origin on the base. `home_bathroom.gd` has to measure each piece's bounding box and
  nudge it flush to a wall (`_flush`, `_center_z`) instead of just placing it.
  `RES_Dryer.glb` has its lowest vertex 0.22 m **below** the origin; where it is placed in the world was not checked.
- **Expected:** one convention: floor items origin at base-centre; wall items origin at the back-centre of the mounting
  face. Then code can place by wall coordinates.
- **Blender work:** `rebase_pivot_copy.py` for floor items; wall items by hand (origin to back face). Keep `INT_*` children.
- **Verify:** after re-export, simplify `home_bathroom.gd` (delete the `_flush` calls) and check the pieces land on the same
  spots (probe: `home.get_node("Furniture/<piece>")` bounds vs wall x/z).
- **Dependencies:** do after B1 if both touch the bathroom visuals (no real dependency).

## B5 — Human characters: baked locomotion  ·  Priority MEDIUM  ·  Complexity L

- **Assets:** 24 skinned character GLBs in `06_Characters/` (Eddie, Marcus, Ruth, Sarah, Lena, Noah, Cashier, ...);
  **none has baked clips** (MEASURED). Motion is procedural (`game/npc/npc_animator.gd`).
- **Context:** the owner found the running animation poor (2026-11-04); the procedural run was improved (forward lean,
  arm pump, higher knees) but is not hand-authored. Codex added `CHR_Marcus_v4_Run.glb` / `_Scared_Run.glb` (one clip each, in
  the web gallery only - the game does not use them).
- **Blender work (only if procedural motion is judged insufficient after a visual check):** author `Idle`, `Walk`,
  `Run`, `Run_Scared`, `Sit_Idle` as 24-30 fps loops on the shared humanoid skeleton and export them with one character first
  (Marcus); then retarget. Loops must close (frame 0 = last frame), no root motion, feet planted ≤ 2 cm drift.
- **Godot side:** `npc_animator.gd` would need an `AnimationPlayer` path alongside `_pose()`; that is a **high-risk change**
  (see `FULL_GAME_AUDIT.md`, "Documented, not changed"). Do not start it without an owner decision.
- **Verify:** `anim_running_test.gd` + visual comparison of a chase.

## B6 — Garage tentacles: a horizontal "slide in" and a "grab leg" clip  ·  Priority MEDIUM  ·  Complexity M

- **Assets:** `07_Creatures/Mist_Tentacles/CRT_MistTentacle_{Thin,Medium,Large}.glb`.
- **MEASURED:** clips `Emerge, Search, Coil, Reach, Strike, Retract` are all authored for a tentacle that rises **upward out
  of mist**; the loading-door encounter (`game/world/garage_tentacle.gd`, three tentacles) tilts the whole mesh to ~20° and
  plays them, hiding the base behind the door.
- **Expected:** a clip that crawls **in** under a 0.9 m gap along the floor, and a `Grab_Leg` that wraps a point and
  pulls back along the same line (used by the failure sequence).
- **Blender work:** new clips on the existing rig (`Root`, `T_01..T_10`) - `SlideIn_Floor` (2.5 s), `Grab_Wrap` (0.6 s),
  `Drag_Back` (loop). Keep the dither fade shader's `MistRoot` marker.
- **Verify:** `loading_door_test.gd` (logic) + visual check of the three beats on Windows.

## B7 — Vehicle origin check  ·  Priority LOW  ·  Complexity S  ·  needs measurement

- **Assets:** `05_Vehicles/**/VEH_*.glb`.
- **MEASURED:** every vehicle mesh extends 0.34 m (van 0.81 m) **below its origin**. The wheel radius is 0.31 m, so the origin
  is probably the axle line or the models carry a node offset; the game places cars by marker and a ground ray.
  The audit did not establish whether the cars sit correctly (`chapter_select_test` reports `car_on_ground` passes).
- **Action:** run `inspect_asset.py` on `VEH_ProtagonistSedan.glb` and compare to the sedan in the world. If the origin is simply
  the axle, no change; document it in `VEHICLE_MANIFEST.json`. If it is a mistake, re-run `veh_models.py` with the offset fixed
  (**all vehicles together**, then re-test `car_quest_test.gd`).

---

## Not Blender tasks (found, handled in code or documented elsewhere)

- Skitter looks pale in some lighting: handled by `colossus_veil.gdshader` params; no mesh work.
- Town/house geometry: the structural audit found **no** missing normals, UVs, textures or non-nearest samplers across
  562 GLBs (see `FULL_GAME_AUDIT.md`), so no wholesale mesh rework is recommended.
- Eddie redesign study (`work/character-redesign`): an owner decision, not an audit finding.

## Suggested order

1. B1 (small, unblocks first-person quality) → 2. B2 (most visible defect) → 3. B3 (after one visual check) → 4. B6 → 5. B4 → 6. B7 → 7. B5 only if still wanted.
