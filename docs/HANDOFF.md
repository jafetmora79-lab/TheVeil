# THE VEIL - Asset Production Handoff

This is for the next Claude session (or person) continuing the asset packs. Read it together with
`docs/THE_VEIL_MASTER_CONTEXT.md`, the project bible, which has the story and art direction. Each pack's own
`Documentation/README.md` covers that pack in detail.

## 1. Repository

* **Repo and branch:** `jafetmora79-lab/TheVeil`. All work is on branch **`claude/practical-cray-hi2y54`**, which has
  not been merged. Keep developing there unless the owner says otherwise.
* **Asset root:** `THE_VEIL_ASSETS_V2/`. Godot paths use `res://THE_VEIL_ASSETS_V2/...`, so the repo root is meant to be
  (or sit inside) a Godot 4.x project root.
* **Engine:** Godot 4 (validated on **4.3 stable**), **Compatibility renderer** (OpenGL). Every pack must stay
  Compatibility-safe:
  * no volumetric fog, Decal nodes, GPUParticles, SDFGI, SSAO/SSR or GI probes;
  * no screen or depth texture reads.
* **Gallery:** a browser asset gallery on GitHub Pages. The files are `docs/index.html` (the `initialAssets` JSON
  list) and `docs/gallery.js` (one filter per pack). Do not redesign it. To add a pack:
  * append its `.glb/.png/.tres` paths to `initialAssets`;
  * add a `packNN=p=>p.startsWith(PREFIX+'NN_Folder/')` predicate;
  * add a matcher (`c==='packNN'&&packNN(p)&&model(p)||`);
  * add an `<Option>`.

  Copy how packs 04/05/06/08/09 were added.
* **Owner uploads:** files the owner uploads (e.g. `docs/Eerie_Customer_TPose.glb`) must not be modified.

## 2. Pack status

| Pack | Folder | Status |
|---|---|---|
| 01 Textures + materials | `01_Textures/`, `Materials_Godot/` | Done. Master pixel-art library; its palette ramps are reused everywhere. |
| 02 Town | `02_Town/` | Done. Greyhaven roads, sidewalks, street props, vegetation, utilities, and the **town layout** (`Town_Layout/greyhaven_layout.json`: zones, placements, journey). `Godot_Scenes/Greyhaven_Town.tscn`. |
| 03 Residential | `03_Residential/` | Done (furniture and house fixes in Phase 1, see section 9). 23 house variants, all enterable. Player home staged for the opening. 85 furniture GLBs. Reusable **building kit** (`house.py`, `arch.py`, `plans.py`) and **walk checker** (`navcheck.py`). `Residential_Scenes/Greyhaven_Town_With_Houses.tscn`. |
| 04 Commercial | `04_Commercial/` | Done (P1/P2/P3). The locations: supermarket, video game store, gas station + canopy, pharmacy, municipal archive. Storefronts A–D are **generic explorable shells, tenants unassigned**; `COMMERCIAL_SPARE` is still empty, because the bible names no business for these. 49 shared fixtures. Each location has a scene in `Godot_Scenes/` and is placed via `Greyhaven_Commercial.tscn`. `Greyhaven_Town_Complete.tscn` = town + houses + commercial. |
| 05 Vehicles | `05_Vehicles/` | Done. Protagonist sedan (full interior, movable doors / hood / trunk / wheels / steering wheel, seat + camera markers, `Godot_Scenes/Protagonist_Sedan.tscn`). Also a police cruiser, pickup, delivery van, 2 traffic variants, 5 abandoned variants and roadside props. No driving physics (by request). |
| 06 Characters | `06_Characters/` | **Approved** (see section 4). Facial expressions + talking are done (`Facial/`). |
| 07 Creatures | `07_Creatures/` | Done: Colossus, Mist Tentacles (3 variants), Hound, Skitter, Shellcrawler. Each is skinned and animated, with a scene and a validator. See `07_Creatures/Documentation/README.md`. No Wanderer, by the owner's request. |
| 08 Inventory | `08_Inventory/` | Done. 53 items on one atlas, with Grip / Inspect markers. |
| 09 Horror atmosphere | `09_Horror_Atmosphere/` | Done. Mist, corruption dressing, supernatural details, effects, lighting presets, and the Veil state system (`VeilAtmosphere`: NORMAL, UNEASY, VEIL_APPROACHING, VEIL_ACTIVE, CORRUPTED). |

## 3. How everything is generated

Every pack except the hand-made Eddie is built by **deterministic Python scripts** (numpy + Pillow) in
`<Pack>/Source_Scripts/`. Each `Source_Scripts/` folder has a `.gdignore` so Godot skips it, and a `.gitignore` for
`__pycache__`. Run them from `THE_VEIL_ASSETS_V2/`:

```bash
python3 04_Commercial/Source_Scripts/build_commercial.py
```

```bash
python3 04_Commercial/Source_Scripts/validate_commercial.py --gltf-validator <dir> --godot <Godot_4.3_binary> --godot-project <scratch_project>
```

Every pack has a `build_*.py` and a `validate_*.py` written the same way.

Shared building blocks, reused across packs:

* **Mesh kit:** `02_Town/Source_Scripts/veil_mesh/`.
  * `mesh.MB` is the mesh builder: box / quad / cyl / tube / ground_poly / merge.
  * `gltf.GLBWriter` and `write_glb_import` write the GLB and its Godot `.import` file. The import file remaps each GLB
    material to an external `.tres`.
  * `materials._reg`, `town_tres` and `m01()` register materials; `m01()` gives a Pack 01 material by id.
  * `validate_town.py` is the GLB structure checker that every validator imports.
* **Pack 01 tooling:** `Source_Scripts/build_library.write_import` writes PNG `.import` files. `veil_texgen` holds the
  palette ramps.
* **Palette:** `06_Characters/Source_Scripts/chr_tex.P`, the Pack 01 ramps plus the character ramps. All generated
  pixel textures are **palette-locked**, and the validators check this. The Pack 06 style characters are the exception
  (see below).
* **Small-object geometry:** `08_Inventory/Source_Scripts/inv_geom.G` (boxes, lathes, extrusions, sweeps, decals into
  atlas rects). Packs 05, 08 and 09 use it; Pack 05 patches `inv_geom.R` to point at its own atlas.
* **Embedding textures:** `08_Inventory/Source_Scripts/build_inventory.embed_images` puts the PNGs inside the GLB, so
  the browser gallery shows real textures.
* **Building kit (Pack 03):** `House(plan).build()` gives walls with real openings (hinged, sliding and garage doors;
  arches; windows), floors, ceilings, walk collision (`-colonly`) and room / door metadata. Pack 04 subclasses it
  (`ComBuilding`) and patches in a glass storefront door style; it never edits the Pack 03 files.
* **Zone frames:** `03_Residential/Source_Scripts/placement.zone_frame / to_world` map a Pack 02 layout zone to local
  coordinates. In that frame x runs across the frontage, z is the depth from the zone front line (the street is at -z),
  and y = 0 is lot level (world y 0.15).

### Conventions

* **Units and axes:** metres, +Y up, **forward = -Z**, left = -X.
* **Fixture origin:** floor centre, with the customer-facing side to +Z. In Pack 04, wall units are auto-snapped 1 cm
  off the real wall face (exterior walls are 0.10 m half-thick, partitions 0.06 m).
* **Collision:** Godot's import suffixes. `-colonly` is a static trimesh; `-convcolonly` is a convex shape.
* **Filtering:** pixel textures use nearest filtering (`texture_filter = 2` in `.tres`).
* **Naming:** `T_*` = textures, `M_*` = materials. Prefixes per pack: `COM_*` = Pack 04, `VEH_*` / `TRN_*` = Pack 05,
  `CHR_*` = Pack 06, `INV_*` = Pack 08; Pack 09 uses `CORR_*`, `SUP_*`, `ABN_*`, `LGT_*` and others.
* **Interaction:** interactive door and part nodes carry `extras.veil_interact` (hinge / slide / ...), which Godot
  imports as metadata. Scenes carry `Marker3D` nodes under `Doorways/`, `Interaction/` and `NavTargets/`.

## 4. Pack 06 characters - read carefully

* **Art-direction reference:** `06_Characters/Commercial_NPCs/CHR_Eddie.glb` is **hand-made by the owner in Blender**.
  The source is in `Source_Blend/Eddie.blend` (ignored by Godot). Never regenerate or modify it.
* **Approved models** (the definitive look, do not redesign):

  | Model | File |
  |---|---|
  | Eddie (reference) | `CHR_Eddie` |
  | Marcus | `Marcus/CHR_Marcus.glb` |
  | Protagonist | `Protagonist/CHR_Protagonist.glb` |
  | Protagonist first-person arms | `Protagonist/CHR_Protagonist_FP_Arms.glb` |
  | Ruth | `Civilians/CHR_Ruth.glb` |
  | Sarah | `Civilians/CHR_Sarah.glb` |
  | Frank | `Commercial_NPCs/CHR_Frank.glb` |
  | Lena | `Civilians/CHR_Lena.glb` |
  | Police officer | `Police/CHR_Police_Officer.glb` |

  They are listed under `style_models` in `Documentation/CHARACTER_MANIFEST.json`.
* **How they are built:**
  * **Marcus:** `chr_style_from_eddie.py`. Don't change this script; it reproduces the approved Marcus byte for byte.
  * **The others:** `chr_style_cast.py`. Each starts from the Eddie reference: a per-bone reshape blended by skin
    weights, the hood folded into a collar, hair crop / keep plus bun or ponytail meshes, rigid low-poly gear, and new
    tiny textures in Eddie's manner.
  * Character textures use **their own palette** (Eddie's), not the Greyhaven palette.
* **Rig:** 22 Godot-humanoid bones plus `Socket_Head`, `Socket_Back` and `Socket_Left/RightHand`. **Godot imports the
  sockets as extra bones**, so the skeleton has 26 bones. The rest pose is an A-pose.
* **Backups:** older generations are kept as `_v1` (rev 1), `_v2` and `_v3`. The old generator (`build_characters.py`
  with `chr_roster.py`) now writes only the `_v1` names, so rebuilding it cannot overwrite the approved files.
* **Faces:**
  * The heads are texture-based (128x64 head texture, shared layout; no blend shapes or facial bones).
  * `chr_faces.py` builds `Facial/Faces/T_Face_<Name>.png`: 10 expressions x 8 eye actions for brows/eyes, and
    10 expressions x 5 visemes for the mouth. The neutral cells equal the approved pixels.
  * `Facial/veil_face.gdshader` composites the two pixel windows over the untouched head texture.
  * The controller is `Facial/veil_face.gd`, class `VeilFace`:
    * `set_expression`, `start_talking(style)`, `stop_talking`, `say`, `blink`, `look`, `widen_eyes`, `narrow_eyes`;
    * talking styles: idle / angry / scared / happy / whisper;
    * blinking runs automatically.
  * Demo: `Facial/Face_Demo.tscn`.
* **Known limitations:**
  * The folded collar stretches more than Eddie's hood in extreme poses.
  * Everyone is built on Eddie's body, so there are no skirts or short sleeves; those would need new geometry. Ruth
    wears slacks.
  * Eddie's closed eyes look slightly doubled, from his own lid shading.
  * Ruth's light-grey brows make her expressions subtle.
* **Noah** must not be modelled until the story defines him (bible rule). Officer Hayes is the "Police_Officer"
  candidate; the identity is still TBD.

## 5. Owner's working rules

These were repeated across requests; follow them unless the owner says otherwise.

* **No screenshots, renders, turntables, preview videos or concept art.** Never claim the look was visually verified;
  only file, structure and engine checks have been run. Looking at the generated texture PNGs themselves has been
  fine.
* **Reuse before creating.** Inspect the repo first and don't duplicate assets. Don't modify other packs: instance
  their scenes and read their scripts.
* **Ask for approval on designs that need it.** For characters, do one first and wait.
* **Work in priority order.** Finish Priority 1 before expanding. Credit-efficient: no repeated full-repo validation.
* **Fictional only.** All brands, logos, game titles and signage must be fictional; no real logos or artwork.
* **Git:**
  * commit and push to `claude/practical-cray-hi2y54`;
  * no pull request unless asked;
  * no model identifiers in commits;
  * before pushing: `git fetch origin claude/practical-cray-hi2y54 && git rebase origin/claude/practical-cray-hi2y54`,
    because the owner sometimes uploads files directly on GitHub.
* **Report format:** each request ends with a numbered report (what was created, reused, validated, limitations,
  exact paths), as the request asks.

## 6. Validation tooling

None of this is in the repo; set it up in a scratch folder.

* **Godot 4.3 stable:** download `Godot_v4.3-stable_linux.x86_64.zip` from the godotengine GitHub releases.
  * Headless import: `godot --headless --path <proj> --import`.
  * Real Compatibility-renderer run:
    ```bash
    xvfb-run -a -s "-screen 0 640x360x24" godot --path <proj> --rendering-driver opengl3 --script res://check.gd
    ```
  * An `ERR_CANT_OPEN` from ALSA/audio is harmless.
* **Scratch project:** a project whose `project.godot` sets `renderer/rendering_method="gl_compatibility"`, with the
  needed packs copied under `THE_VEIL_ASSETS_V2/`. Most scenes need 01 + `Materials_Godot` + 02 + 03, plus 05 / 08 /
  09 where they are instanced.
* **Khronos glTF-Validator:** `npm install gltf-validator`. The validators accept `--gltf-validator <dir containing
  node_modules>`.
* **Expected warnings:** `NODE_SKINNED_MESH_NON_ROOT` on skinned characters is a standard Blender-export warning, and
  the Eddie reference has it too.

## 7. Gotchas learned the hard way

* **Node references in `.tscn`:** exported Node references need `node_paths=PackedStringArray(...)` in the node header,
  or Godot leaves them null.
* **Test scripts:** in a `SceneTree` test script, nodes aren't in the tree during `_initialize()` until a frame has
  passed. Use `look_at_from_position` after `await process_frame`.
* **Comparing textures:** `Texture2D.get_image()` includes mipmaps. Call `clear_mipmaps()` before comparing pixels.
* **Validator coverage:** Pack 05 and Pack 04 caught real problems (blocked aisles, units in walls, gauges hidden behind
  the steering-wheel hub). Keep validators strict.
* **Removing files:** `rm -rf $VAR` is blocked by a safety check. Use Python `shutil.rmtree` on explicit paths, or
  `"${VAR:?}"`.

## 8. Open items / suggested next steps

The asset packs are finished. Development has moved to the **game**; see section 9. The next steps are listed in
section 9.6.

## 9. Phase 1 game: the playable opening (current work)

### 9.1 Status

The repository root is a **Godot 4.3 project** (`project.godot`, Compatibility renderer). The opening is playable
end to end:

1. Main menu.
2. Wake up at 6:42 PM; the player can move.
3. Open the fridge: it is nearly empty.
4. Take the car keys; they go into the inventory.
5. Open the front door and leave the house.
6. Get into the sedan.
7. Drive 1,069 m through Greyhaven (77-99 s measured).
8. Park at the supermarket.

There is no mist and there are no monsters, as the bible requires for the opening.

* **Browser build:** `docs/play/` → <https://jafetmora79-lab.github.io/TheVeil/play/>. Pages deploys this branch's
  `docs/`. The owner reported it does **not** run well in their browser and prefers the desktop Godot project. Treat
  the web build as secondary.
* **Owner's local test:** download the branch zip, unzip into a **fresh** folder, Import `project.godot` in Godot,
  press F5.
* **Full details** (architecture, controls, measurements): `game/README.md`.

### 9.2 Layout of the game code

| Path | Purpose |
|---|---|
| `game/autoload/` | `Game` (flags, objectives, inventory, save / load, settings, input map), `Dialogue` (subtitles; data in `game/data/dialogue.json`), `Sfx` (synthesised sounds; there are no audio files in the repo) |
| `game/player/player.gd` | first-person controller |
| `game/interaction/interactable.gd` | one component: hinge (with `hinge_axis`), slide, pickup, light toggle, observe, custom |
| `game/vehicles/player_sedan.gd` | arcade driving on the Pack 05 sedan |
| `game/world/world.gd` | wires the assets: Player_Home `veil_interactables` metadata, triggers, car entry / exit, parking, save / restore, distance culling, `_outward_deg` (furniture doors swing away from their body) |
| `game/scenes/MainMenu.tscn`, `World.tscn` | entry points |
| `game/tools/build_world.py` | **world generator** (see 9.3) |
| `game/tools/check_world.py` | top-down crack / coverage check of the whole map |
| `game/tests/opening_test.gd` | automated playthrough. Run before every push: `godot --headless --path . --fixed-fps 60 --script res://game/tests/opening_test.gd -- 50` must print `RESULT PASS` |
| `game/tests/render_smoke.gd` | real OpenGL3 run (xvfb) that prints draw calls |

### 9.3 Greyhaven was extended (important)

In the Pack 02 layout the house is only about 200 m from the supermarket, and the brief requires at least 60 s of
driving. `game/tools/build_world.py` therefore uses the Pack 02 `town_layout.py` and the Pack 03
`placement.py` / `build_residential` **as libraries** and writes into `game/world/`:

* Route 9 continues as a county road to a new subdivision: Harlow Ln, Aspen Ct, and Fern Ct.
* The **hero house was moved to Fern Ct** with identical lot geometry (the generator asserts this). The old Maple
  Ave lot now holds a Ranch B neighbour house.
* `Greyhaven_Core.tscn` is a game copy of the Pack 02 town scene, without the old ground / woods / zone labels and
  without 34 fence posts that Pack 02 placed inside driveways.
* The ground is regenerated with cut-outs for the new roads, plus a crack filler. The woods are MultiMesh
  (`scatter.json`, `scatter.gd`).
* After any Pack 02 or Pack 03 change, run `python3 game/tools/build_world.py`, then
  `python3 game/tools/check_world.py` (it must report 0 holes), then the playthrough test.

### 9.4 Asset fixes made during Phase 1 (Pack 03, regenerated by `build_residential.py`)

* **Furniture:**
  * `furniture.hollow()`: carcasses and drawers now have textured inner walls and a front rim. Before, they had an
    open hole: the background showed through and drawers were empty.
  * Raised parts keep their undersides (the `_FurnMB` wrapper).
  * The asphalt `Road_RoadPatch` stand-in material was replaced by proper furniture materials.
* **Houses:** `House.clip_gutters_inside()` removes gutter and downspout pieces that the roof builder placed inside
  rooms (there was a white post and beam in the player's bedroom). It applies to all 23 variants.
* **Validation:** `validate_residential.py` passes (0 failures, 6 pre-existing placement warnings).

### 9.4b Later commits from the owner's account (review first)

After `c96bb42`, the owner's account pushed two commits:

* `0e9b50f` "Restore safe sedan exit through the interact key"
* `9f3df14` "Repair sedan lid edges and residential furniture assemblies"

Read both before touching furniture or the sedan. Re-run `build_residential.py` / the Pack 03 validator and the
playthrough test to make sure everything still agrees.

### 9.5 Known issues / limits

* **Visual quality:** never verified by eye by Claude. The owner is the visual tester and reports problems with
  screenshots. The owner said "there are still a lot of things that don't look good": expect more furniture and
  building polish requests. **Ask the owner** whether private diagnostic screenshots are allowed for debugging. Until
  then, find defects with geometry checks (open-edge scan, room-volume tests) as was done for furniture and gutters.
* **Remaining open edges:** about 141 m of open mesh edges remain across all furniture. They are mostly harmless
  (flush overlay panels, buried cylinder ends, curtain sheets).
* **Draw calls:** about 2,300 draw calls / frame with the whole town loaded at once. This is acceptable on desktop
  and heavy for browsers. Possible next steps: merge static props per block, or stream chunks.
* **Driving model:** simple. Locomotion is flat-ground only, with no reversing camera or traffic. No NPCs appear in
  the opening yet.
* **Godot `.import` files:** opening the project creates `.import` files for a few Pack 09 PNGs and documentation
  CSVs that never had them. They were left uncommitted.
* **Web export filters:** the "all resources minus exclusions" filter in `export_presets.cfg` is deliberate.
  Class-name scripts and dynamically loaded models were missing with the "scenes" filter.

### 9.6 Suggested next steps (ask the owner which first)

1. **Visual polish pass** on what the owner reports (furniture, house interiors, exteriors), with the same root-cause
   approach: fix the generator, regenerate, validate, re-export.
2. ~~Phase 2: the supermarket~~ **done** - see 9.8.
3. **Performance:** batching and streaming. The web build only matters if the owner still wants it.
4. **Audio:** real recorded / licensed sounds if the owner provides them (currently synthesised).

### 9.7 Tooling notes

* Export templates can be fetched without the 1 GB download: read the `.tpz` central directory with HTTP range
  requests and pull only `templates/web_nothreads_release.zip` into `~/.local/share/godot/export_templates/4.3.stable/`.
* Test in a **synced scratch copy** of the repo, not the repo itself, so Godot cannot rewrite pack `.import` files.
* Web export:
  * needs the 4.3 export templates; only `web_nothreads_release.zip` is required;
  * export with `--export-release "Web" build/web/index.html`, then copy the result into `docs/play/`.
* Browser checks:
  * use Playwright Chromium with SwiftShader;
  * `play/index.html?autotest` runs the story interactions in the exported build;
  * the F10 key prints the game state to the console.

### 9.8 Phase 2: town errands (done)

* **Flow:** after parking, objectives `buy_groceries` -> `buy_game` -> `go_home` (`game/data/objectives.json`). Each
  step checks only its own flag (`groceries_done`, `game_bought`, `phase2_done`), so the errands work in either order.
* **Code:** `world.gd` `_setup_town()`:
  * supermarket auto doors: `Trigger_MarketDoors` slides `INT_AutoDoor_Entrance_L/R` 1.12 m apart;
  * three groceries (Pack 08 GLBs) on gondola shelves at supermarket-local spots in `GROCERIES`;
  * checkout on `Interaction/Register_45` turns them into one `groceries` item;
  * game shop `INT_Door_Entrance` is a hinge that swings inward (`_toward_deg`);
  * `NewReleasePick` on `Interaction/Browse_1`;
  * `CHR_Eddie` at `NavTargets/BehindCounter` with `VeilFace`, which talks on every "Eddie" dialogue line, and
    `_lower_arms()`.
* **Placeholders:** the Cashier speaker, the untitled game, and the `draft` dialogue lines.
* **Export:** `export_presets.cfg` now ships `CHR_Eddie`, his face atlas and the facial script/shader. The rest of
  `06_Characters` stays excluded.
* **Tests:** `opening_test.gd` adds about 30 Phase 2 checks:
  * door blocking and opening;
  * real walking through both entrances;
  * every pickup reachable through the actual player ray;
  * checkout refusal and checkout;
  * Eddie's lowered arms and talking;
  * the end card;
  * save/load of the errand state.

### 9.9 Visual polish pass: z-fighting (geometry-checked, not visually verified)

* **Tool:** `THE_VEIL_ASSETS_V2/Source_Scripts/zfight_scan.py`. It finds opaque faces that sit in the same plane, face
  the same way, overlap, and show different texels. It ignores hidden contact faces. These faces flicker in the
  Compatibility renderer.
* **Result:** visible coplanar overlap across Packs 02-05 and 09 fell from about 194 m² to about 99 m².
* **Fixed in the generators** (then regenerated):
  * Pack 03 (`arch.py`, `furniture.py`):
    * shutter front faces were doubled by their frame box;
    * stair treads ran flush with the stringers;
    * sofa bases were flush with the arms.
  * Pack 04 (`com_fixtures.py`, `com_plans.py`):
    * game-rack base vs first tier;
    * register cash drawer vs counter top;
    * cooler and produce-case plinth / header vs side and back panels;
    * chest-freezer kick plate;
    * fuel-pump nozzle holsters, which were inside the pump body and now stand proud of it;
    * gas-station curb top vs walk slab;
    * parapet wall ends at the corners (all Pack 04 buildings).
* **Stale outputs refreshed:** rebuilding also refreshed Pack 03 and Pack 04 outputs that were behind the current
  generators. These were the Pack 03 interactive drawer / cabinet units and the Pack 04 furnishings that embed
  Pack 03 furniture.
* **Validation:**
  * both packs pass full validation: glTF-Validator 0/0, Godot import and scene checks;
  * `check_world.py`: 0 failures;
  * `opening_test.gd`: RESULT PASS.
* **Still open:**
  * Pack 03 house shells, about 5-10 m² per house: the foundation band vs the siding where neighbouring rooms' walls
    are 2 cm apart, plus some porch / brick overlaps;
  * supermarket gondola tops at 1.8 m, above eye height.

### 9.10 Phase 3: the Veil arrives (WORKING DRAFT) and the owner's play-test fixes

* **Owner reports fixed:**
  * **The supermarket could not be entered.** The Pack 02 lot-edge curb (15 cm) runs along the whole store front,
    and the player had no step-up. `player.gd` `_step_up()` now climbs anything up to 0.35 m. The test walks from
    6 m out in the lot, over the curb and through the doors.
  * **No store clerk.** There is a new generic `CHR_Cashier` (`chr_style_cast.py` CAST entry, face atlas from
    `chr_faces.py`). Other cast GLBs came out byte-identical. She stands at lane 4 and takes the payment.
  * **Couldn't find what to buy:**
    * a HUD shopping list with aisle numbers;
    * pulsing rim glow on the items (`game/world/veil_highlight.gdshader` as `material_overlay`);
    * a glow on the cashier once the basket is full.
  * **Hard to tell which building is the store:** `focus_shot()` (view lock: slow turn and zoom, title, hand back)
    runs on parking, and `_beacon()` puts a pulsing light at the entrance.
* **Phase 3 flow** (`world.gd`, the `Phase 3` section; objectives `go_home` -> `mist_shop` -> `mist_market` ->
  `mist_doors`; dialogue `p3_*`, all draft):
  * outdoors with both errands done -> `VeilAtmosphere` (Pack 09) NORMAL -> VEIL_APPROACHING -> VEIL_ACTIVE;
  * the Colossus glimpse (Pack 07, scaled 2.2x, walking east at (70..118, -86), collisions off) with a focus shot;
  * 3 Medium mist tentacles beside the shop -> market line: a 1.8 m hazard knocks you back (no health system yet);
  * the dead sedan;
  * Eddie holds the shop door; Marcus is inside (`_spawn_npc`);
  * after the talk, Eddie and Marcus are moved into the supermarket while the player is outdoors;
  * the doors jam open, lights dim, "Pull the Doors Shut" -> end card "ACT I".
  * Saves restore the Phase 3 state (`_p3_restore`).
* **Export:** the Web and Windows presets now ship:
  * Marcus;
  * the cashier;
  * Pack 07 Colossus and tentacles (Hound, Skitter and Shellcrawler stay excluded);
  * the Pack 09 atmosphere.
* **Downloads:**
  * Windows: `docs/download/TheVeil_Windows.zip`, exported with the "Windows Desktop" preset;
  * browser: `docs/play/`.
* **Tests:** `opening_test.gd` runs through the end of Phase 3 (about 1 minute headless): RESULT PASS.
  * The in-car save/reload check now runs before the errands.
  * A final reload checks the Phase 3 state.
* **Expected output:** headless runs print `Parameter "m" is null` from the dummy renderer when the world is freed.
  It is harmless.

### 9.11 NPC procedural animation

* **What it is:** `game/npc/npc_animator.gd` (`NpcAnimator`). It covers rest pose, idle, look-at, body turn, talking
  gestures, scared mood and the walk cycle on the shared humanoid rig. See the "NPC animation" section of
  `game/README.md`. It replaced `_lower_arms()`.
* **Tests:**
  * arms within 25° of straight down;
  * Eddie and the cashier face the right way;
  * Eddie's gaze stays within 25° of the player;
  * forearm gestures above 30° while talking;
  * Eddie walks to the shop door, with a thigh swing above 20°.
* **Gotcha:** never name a script method `_set` (it overrides `Object._set`).
* **No IK:** feet can slide a little on turns. Real animation clips can replace this later.

### 9.12 Apartment refrigerator: the "orange wall" (fixed, geometry-verified)

* **Cause:** `furniture.py` `fridge()` built the body as **one solid rounded box** (`rbox`) in harvest-gold enamel,
  with no interior. Opening the door showed the body's flat front face: the orange wall. The can and water bottle
  that `world.gd` stocks were buried inside the solid.
  * Not the cause: the hinge, pivot, swing direction, normals or textures. The door swing was already tested as
    outward.
* **Fix:**
  * `_drop_front_faces()` removes the body's flat front face. The rounded enamel shell stays.
  * Added a front rim, a white liner (back, sides, top, floor), two wire shelves on rails, a crisper drawer, a light
    housing and a box of baking soda.
  * The door gets an inner liner, a rubber gasket and three door bins, one holding a mustard bottle.
  * The `RES_Fridge_TopFreezer` variant gets the same fix.
* **Game side:**
  * The can sits on the lower shelf (y 0.78) and the water on the upper shelf (y 1.18).
  * An interior OmniLight (`Fridge_Light`) is on only while the door is open.
  * A `Fridge_Opening` proxy interaction lets the player close the door while looking into the open fridge. The
    door's own box swings away with the door.
* **Verification** (no screenshots; geometry and logic only):
  * A ray grid from the first-person eye position (70 rays) with the door fully open:
    * before: 70/70 rays hit the orange front;
    * after: 0 hit it; they hit the liner, shelves, crisper and contents.
  * At 45°, the door correctly covers most of the view.
  * `opening_test.gd` covers the prompt when aiming, real E-key open, light on/off, items in the cavity, 3
    close/open cycles, and return to the exact rest transform. RESULT PASS.
  * Pack 03 validation passes (Khronos 0/0, Godot).

### 9.13 Gameplay / environment / cinematic pass

* **Merchandise (Pack 04):**
  * Generator: `com_merch.py`.
    * Atlas `Merchandise/T_Com4_Merch.png` and `COM_Merch_Library.glb` (one mesh per variant, shared geometry per
      family).
    * `MERCH_LAYOUT.json` is computed from the final fixture positions in `build_commercial.py`.
  * Empty fixtures: `COM_Gondola_Shelf`, `COM_GameRack_Empty_*`, `COM_GameWallShelf_Empty` / `_Movies`, and the
    checkout candy racks.
  * `COM_Cooler_Beverage` has hinged glass doors with their own collision. It is instanced under the store's `Props`
    via fit option `{"dyn": True}`.
  * Game side: `game/world/store_merch.gd`.
  * Geometry check of all 5,403 products: 0 floating, 0 clipping, 0 overlaps. The checker itself was proven by
    lifting and sinking every product.
* **Trees vanishing on the drive:**
  * Cause: every tree model was ONE whole-map MultiMesh at the world origin with a 260 m visibility range. Godot
    judges the range per instance, so all trees of a model culled at once. Under an origin-based measure that
    happens at 48 of 77 route points, from the house to (184, 184).
  * Fix: `scatter.gd` builds 96 m cells, with each node at its cell centre and a 420 m range.
  * `game/tests/tree_cull_check.gd` (data-based, works headless): 0 of 78,313 checks culled.
* **Night:**
  * `world.gd` `night_preset()` (`night` / `approach` / `active`) drives the Pack 09 controller; the pack's own
    presets are unchanged.
  * The old VEIL_ACTIVE preset's light-grey fog is what turned enemies flat grey. The active-mist preset now uses
    dark depth fog plus a ground layer.
  * The mist ceiling (`game/world/mist_ceiling.gdshader`, 4 noise layers at 9-20 m, following the camera) swallows
    anything taller than the houses.
* **Colossus encounter (`world.gd` `_colossus_encounter`):**
  * The creature is scaled 6x. The Walk_Heavy clip is sampled for the front-left foot's contact frame, and the root
    is placed so that foot lands on the target.
  * If the other feet would not land out over the street, the walk direction is mirrored.
  * Measured in the test:
    * foot error 0.05 m;
    * other feet at least 18 m out;
    * body 54 m up (ceiling from 9 m);
    * look-up 69 degrees.
  * The protagonist cut uses `CHR_Protagonist` + VeilFace + NpcAnimator (`max_pitch` raised).
* **Survival:**
  * `player.gd`: health, stamina, `damage()` (camera kick, push, 0.35 s stagger).
  * `hud.gd`: bars and damage flash.
  * `game/enemies/tentacle_ai.gd`: reach, strike direction and contact time are measured from the Strike clip's tip
    bone. Damage only at that frame, inside reach and inside a 40-degree cone. Wind-up 0.75 s.
* **Conversation camera:** `world.gd` `talk_shot()`. It moves at most 0.35 m (never through walls), FOV 52, and
  follows the current speaker (`Dialogue.line_started`).
* **Arrival shot:** `Trigger_ArrivalShot` on Main St; `sedan.speed_cap` gives a gentle slowdown with no stop.
* **Pixel font:** `game/tools/make_pixel_font.py` (fontTools) -> `game/ui/fonts/VeilPixel.ttf`. `VeilUI.style_text()`
  sets the font, white colour, black outline and snapped sizes (26 / 39 / 52).
* **Noah:** `CHR_Noah` (Civilians), a style-rev-4 DESIGN PROPOSAL (the bible leaves his age TBD; built as roughly
  10-12, height 1.42 m) with a face atlas. It is not placed in the game.
* **Hygiene gotcha:** after a Godot import in the repo, extracted `*_N.png` / `.translation` files appear. Stage your
  new source files BEFORE any `git clean`. One clean deleted an unstaged generator and it had to be rewritten.
* **Pack 04 / 06 builds rewrite `.import` files:** re-run `godot --headless --import` before tests, or preloads fail.

### Chapter 5 polish (branch `claude/chapter5-polish`)

* **Signs:** `com_plans.sign_3d` laid its letters out along +x, but the street-side reader has +x on their left, so
  every 3D sign was mirrored. Text now runs from +x. The flat decal signs were already correct.
* **Fridges:** the appliance-door hinge was authored as +100 deg, which swings a left-hinged leaf into the body. It
  is now -100 (Pack 03 and `scavenge_houses.json`). `world._outward_deg` also recognises `ScavengeFurniture`.
* **Front doors:** a front door whose colorway gives it a `Town_Paint*` texture (it read as concrete) now uses
  stained wood. The survivor house's proportions are standard (2.6 m ceilings, 1.0 x 2.15 m doors), so it was not
  reshaped.
* **Pickups:**
  * `pickup_highlight.gdshader` with `Interactable.set_focus`, and "TAKE <item name>" prompts from `items.json`.
  * `player._assist_pickup`: a 10-degree / 16 cm aim assist with line of sight, which ignores the loot's own
    container (`Interactable.container` / `los_ignore`).
* **Inventory:** `game/ui/inventory_panel.gd` (grid, 3D-model icons, details, quantity, weight, actions that
  exist). Weights and the 15 kg capacity are placeholders in `items.json` and are display only.
* **Guidance:**
  * `hud.set_marker()` puts one destination marker on screen; `chapter5._update_marker()` picks its target from
    the objective flags.
  * New objective step `c5_leave` (flag `c5_left_store`).
* **Radio:** `game/props/veil_radio.gd` (reusable; `play_broadcast(dialogue_id)`). `RES_Radio` is now a modelled
  radio with `Radio_Display` and `Radio_LED` nodes.
* **Companion:** `companion_follow.gd` opens hinge doors across the trail, steps aside when the player walks into
  it, and faces the player when idle.
* **Not on this branch:** the light-budget fix, window-glass colliders and conversation camera live on
  `claude/practical-cray-hi2y54`. Merging the two touches `world.gd`, `player.gd`, `hud.gd` and
  `interactable.gd`.
### 9.14 Cinematic repair, gameplay polish and Chapter 4 quality pass

None of this was observed in a renderer (no screenshots). All checks are data-based in
`game/tests/opening_test.gd`, which now also plays a second slice where the game is bought last, so the Veil
arrives inside the game shop (the owner's case).

* **Keys:**
  * The keys are their own mesh under `INT_Pickup_CarKeys` (Pack 03 `coat_rack()`), hanging from the rack's last
    hook.
  * The root cause of "the keys don't disappear": they were merged into the rack mesh.
  * Pickups get a faint highlight while looked at (`Interactable.set_focus`).
  * The car refuses entry with "I need my keys.".
* **Sedan see-through:**
  * Found with a ray scan of the closed car from the seats and from outside. The opaque wedge ahead of each front
    window and the C-pillar strip had no inside face; door inner panels left slits; the wheel arches showed
    back faces.
  * Fixes in `veh_models.py`: inner faces and jambs, a full-length door panel, `wheel_wells()` and tub end walls.
  * Leak rays dropped from about 1,000 to 4 single-ray seams.
* **Arrival and parking:**
  * `_arrival_ease()` follows a 1.4 m/s^2 curve to 5 km/h at the shot point.
  * `_auto_park()`:
    * pure-pursuit approach, steering while stationary, a 5 m reverse arc into the store-row stall two spaces
      east of the entrance, straighten, parking brake;
    * driven through `PlayerSedan.drive_script` (physics, no teleport);
    * flag `auto_parked`. Measured: 0.17 m and 0.5 degrees from the target.
* **Window glass:**
  * The panes had no collision above the sills, so cameras and sight checks went through them.
  * `game/tools/extract_glass.py` writes `game/data/glass_panes.json` (43 panes from the Pack 04 building GLBs);
    `_add_glass_colliders()` adds them.
  * Prop glass (coolers) is excluded so items behind it stay clickable.
* **Colossus:**
  * *Geometry:* the leg sweeps now run into the feet. The hind hoofs used to sit about 0.3 m (1.8 m at 6x) below
    the leg; the fore claws are rooted inside the leg, and the joint plates are sunk.
  * *Look:* `game/world/colossus_veil.gdshader`, used for the encounter only:
    * the creature's own textures with fixed dim moonlight (unshaded), so no scene light can blow it out to white;
    * contrast falls and the colour sinks into the mist from 3 to 13 m;
    * the leg dither-dissolves between 10 and 17 m.
  * *Fog cards:* the Pack 09 fog cards fade near the camera during the cinematic, so no billboard edge fills the
    frame.
  * *Contact:* the claw tips (`FL_TIPS`, from the build data) define contact, not the foot bone. They rest 2 cm
    above the road, the foot holds raised until the view arrives, and the animation freezes on contact to plant.
* **Staging (game shop):** A Eddie opens the door (the exterior is not framed before it is open); B first-person
  through the doorway; C foot; D up the leg (an anchor that sees the leg at 2 / 6 / 11 m); E face; F Eddie calls
  from the threshold (the protagonist is kept out of the sight line); G both walk in, Eddie shuts the door, Marcus
  joins, everyone faces each other; H the standard conversation. The doorway staging (supermarket) is unchanged
  apart from validated anchors.
* **Camera safety:**
  * `cam_point_ok`, `cam_path_ok` (sphere sweep), `sight_ok` and `pick_anchor`.
  * A per-frame watchdog counts frames where the camera is inside geometry or an NPC, or crossed a surface.
  * The test requires 0 violations in both stagings.
* **NPC conversations:**
  * `converse(ids, npcs)` refuses through walls, doors or glass, turns the NPCs to the player, and holds the talk
    camera until the last line.
  * `Dialogue.confirm_mode`: each line waits for E, click, Space or touch, with a "[E] >" cue.
  * Used for Eddie, the cashier, Marcus, the Phase 3 talks and Chapter 4 (choices stay inside the talk).
  * `Dialogue.auto_confirm` is for tests only.
* **Chapter 4 (`phase4.gd`, flags and objectives unchanged):**
  * The flashlight and batteries were 0.4 m behind the service counter in mid-air. They now sit on its top and are
    settled onto the collider below.
  * The breaker panel sat on the loading roll-up door. It moved to the back wall (Pack 04 `com_plans.py`); the
    interaction box is in front of the panel and generous, and is not reachable through the wall.
  * The barricades take three shoves, end flush with the doors, and hold the player during the push.
  * The hound physically strikes the rear exit: the Attack_Bite contact frame is measured from the rig, and the
    impact, leaf jolt, pallet jolt and flicker all happen on that frame.
* **Lighting root cause:**
  * There were 160 lights, and 87 omni lights had no distance fade, so 90-112 lights were in range anywhere in town
    against the Compatibility cap of 32 per frame and 8 per object. The excess was dropped in camera-dependent
    order.
  * Now every omni and spot light fades (`_light_budget`, also for lights spawned later), and the street lamps fade
    at 50 + 15 m.
  * `project.godot` sets 64 lights per frame and 16 per object. The worst spot has 51 in range.
  * Energies are unchanged (not brighter).
* **Pre-existing, not fixed:** `--script` runs print "Identifier not found: Game" for `interactable.gd` before the
  autoloads exist. The test still runs; it appears at the merged Phase 4 base (ae21bca).

### 9.15 Global NPC conversation camera and Chapter 8 (branch `claude/chapter8-something-at-the-doors`)
* **Why the talk zoom stopped working in later chapters:**
  * `converse()` refused when one sight line, eye to head, was blocked. A door frame or a counter edge was
    enough. The chapters then fell back to plain timed subtitles: no zoom, no continue prompt and no movement
    lock. Ruth and Sarah at their doorway and the Chapter 5 survivor hit this every time.
  * A second `converse()` during a talk cut the first one off.
* **The shared fix (`world.gd`; there is still only one dialogue system):**
  * `can_talk` checks the head, face and chest; one clear line is enough. Glass and walls still refuse.
  * The talk camera stays at the protagonist's eye. It only turns toward the speaker's face and upper body, with a
    10 % FOV zoom over about 0.4 s and a gentler re-aim when the speaker changes. Because it never moves, it cannot
    clip.
  * A speaker hidden from the eye (behind a wall beside a doorway, or behind another NPC) is never framed; the
    view stays on the last visible speaker.
  * Invisible "keep out" blockers (group `veil_talk_transparent`) do not block a talk.
  * Chapter 6: Ruth and Sarah now start talking once Ruth is actually in view, instead of at the yard fence. If the
    player never comes into view within 12 s, the plain lines play as before.
  * It eases back to the player's own view (~0.4 s), then restores FOV and control.
  * `end_conversation()` is for scripted interruptions. `talk_watchdog()` releases any left-over talk camera, and
    world `_ready` clears queued dialogue, so a load never resumes half-way through a talk.
  * Hold-E skip shows a progress bar (`SKIPPING [####------]`) and still stops at choices.
  * `converse()` only queues plain lines during exceptions: driving, encounters, cinematics and a hidden player.
* **Chapter 8 (`chapter8.gd`, started by sleeping after Chapter 7):**
  * Scenes in order:
    * Eddie;
    * inspect the damaged rear barricade, then Marcus;
    * boards (back corridor), duct tape (service counter) and a hammer (loading-bay pallets);
    * first-person repair;
    * the lights fail;
    * inspect and reseat at the Chapter 4 breaker panel, which restores partial power;
    * three impacts on the way back, and the barricade gives way;
    * the Hound kills the temporary survivor once (a cut to black, no gore) and Sarah is hurt;
    * push a pallet stack across the back doorway; the Hound withdraws;
    * help Sarah: painkillers or shelter medical stock, used once, or none (she stays seriously hurt);
    * the group talk, then "CHAPTER 8 COMPLETE".
  * Sleeping sets `ch8_rested` only. Chapter 9 is not started.
  * Ruth and Sarah (if not invited in Chapter 6) and the Chapter 5 survivor (if not helped) arrive at the
    shelter during the night before Chapter 8, so the approved script plays in every branch (`st().ruth_sarah_arrived`).
  * Dev entry: `game/tools/dev_chapter8.gd`. Test: `game/tests/chapter8_test.gd`.

### 9.16 Chapter numbering and Chapter 10 "The Fall of the Supermarket" (branch `claude/chapter9-supermarket-fall`)
* **Displayed chapter numbers** come from one place, `game/data/chapters.json`, via `Game.chapter_number()`,
  `chapter_label()` and `chapter_name()`.
  * The current chapter is the highest one with a set start flag, so existing saves get the right number with no
    migration.
  * Internal ids are unchanged: flags, objective ids and `chapterN.gd` file names keep their old numbers.

  | # | Title | Starts at | Code |
  |---|---|---|---|
  | 1 | An Ordinary Evening | waking at home | `world.gd` |
  | 2 | One Last Stop | the town arrival zoom (`arrival_shot`) | `world.gd` |
  | 3 | The Veil Arrives | `p3_mist` | `world.gd` Phase 3 |
  | 4 | The Last Open Door | leaving the game shop together (`p3_fled_together`) | `world.gd` Phase 3 |
  | 5 | Lock-In | `p3_doors_shut` | `phase4.gd` |
  | 6 | The First Search | `p4_slept` | `chapter5.gd` |
  | 7 | Voices in the Mist | `ch6_started` | `chapter6.gd` |
  | 8 | A Trace of Noah | `ch7_started` | `chapter7.gd` |
  | 9 | Something at the Doors | `ch8_started` | `chapter8.gd` |
  | 10 | The Fall of the Supermarket | `ch9_started` | `chapter9.gd` |
* **Where the numbers are shown:**
  * Start and completion cards use `hud.chapter_start(n)` / `hud.chapter_complete(n)`. They appear in the upper
    screen, clear of the arrival zoom's sign and the subtitles, and a start card shows once (flag `chapter_card_<n>`).
  * The pause menu shows the current chapter. The main menu's Continue button shows the saved chapter, and saves
    store `chapter` / `chapter_name` for display.
  * Objective completion texts use the corrected numbers.
* **Chapter 10 (`chapter9.gd`):**
  * Marcus's decision talk.
  * Preparation:
    * the shelter's medical stock becomes real painkiller items;
    * up to 2 food and 2 water units are packed, never more than exist (an empty stock still progresses, with a
      warning);
    * switching the flashlight on checks it;
    * a word with Eddie, Ruth and Sarah.
  * The warning: impacts, scraping, flicker, a shape beyond the glass, first person.
  * The fall: the doorway barricade gives way, a Hound breaks in and stalks the far end of the back aisle, another
    passes the front doors.
  * The escape on foot: the group follows through the staff door, the back corridor and the rear exit.
  * Marcus's moment:
    * a Hound pins him in the corridor;
    * trust from `p4_choice_noah` and `marcus_trust_search` gives the player 4 / 8 / 12 s to pull him free;
    * otherwise he is dragged away in a cut to black. The narrative bible: "Marcus may die during the supermarket
      evacuation", "his trust depends on actions and dialogue".
  * A look back, then a roll call that reflects the outcome.
  * The rendezvous in Ruth and Sarah's front yard, then "CHAPTER 10 COMPLETE".
  * The store is lost as a shelter: no rest, supplies closed, and the communal stock left behind is recorded as
    `abandoned_stock`.
  * The next chapter is not started.
  * Dev entry: `game/tools/dev_chapter9.gd`. Test: `game/tests/chapter9_test.gd` (also the numbering, save and menu
    labels).

### 9.17 Chapter 11 "No Safe Road" (branch `claude/chapter10-no-safe-road`; code `chapter10.gd`, flags `ch10_*`)
* **Numbering:** the owner's prompt called this "Chapter 10". With the corrected mapping it displays as
  **CHAPTER 11** (`game/data/chapters.json`, start flag `ch10_started`). It starts at the rendezvous right after
  "CHAPTER 10 COMPLETE"; there is no sleep in between, because the supermarket is gone.
* **The route** (all existing town geometry):
  * the street, the open lot and the main road;
  * the abandoned sedan (`VEH_Sedan_Dusty`) at (-28, 4): the driver's door, then the fuel gauge (empty), the glove
    compartment (1 battery) and the trunk (1 water), each once;
  * the roadblock at x -46: a broken-down van, a pickup and barriers between the roadside building (z -7) and the
    south wall (z 7);
  * the side route: through the gap at x -28, behind the building, through the gate in a chain-link fence at x -44,
    back to the road;
  * the follower: a Hound silhouette crosses the fog and goes behind the building block, first person, no fight;
  * Sarah's choice (`ch10_choice_help` / `ch10_choice_push`):
    * help: an hour passes and one water or food item is used, or `ch10_exposure` is set if there is none;
    * push: `ch10_sarah_exhausted`;
    * her line follows the Chapter 9 treatment (tired, or her wound);
  * the outskirts and the mill-worker house (`MILL_HOUSE`, -92, 14): front door, main room, the group gathers, the
    talk, rest (a few hours, +30 health), the window, a distant unexplained call, then "CHAPTER 11 COMPLETE".
* **Roster:** Marcus appears only if he was saved in the evacuation; his line becomes the protagonist's line
  otherwise.
* **Checkpoints:**
  * `world.save_checkpoint(name)` writes `user://checkpoints/<name>.json` (`chapter11_start`, `chapter11_end`),
    never `user://veil_save.json`. `Game.load_checkpoint(name)` reads one.
  * Note: the game's existing autosave on every story flag (`world._on_flag`, used by the death retry) still writes
    the main slot during normal play. That behaviour predates this chapter and is unchanged.
* **Dev entry and test:** `game/tools/dev_chapter10.gd`; `game/tests/chapter10_test.gd`.

### 9.18 Chapter 12 "The Farm Road" (branch `claude/chapter11-farm-road`; code `chapter11.gd`, flags `ch11_*`)
* **Numbering:** displayed as **CHAPTER 12** (the prompt's "Chapter 11" is No Safe Road under the corrected
  mapping). It starts in the mill-worker house right after "CHAPTER 11 COMPLETE".
* **Base:** branched from `claude/chapter10-no-safe-road`, with the integrated build
  (`claude/chapter7-trace-of-noah` 65ede7b) merged in.
  * That build's `world.npc_route` assigned an untyped conditional array to an `Array[RID]`, so every NPC route
    search failed with a script error. Fixed (typed array).
* **The farm road** (existing pieces in the open fields west of town):
  * an abandoned pickup, a picket fence with one panel down, a country bus shelter (an optional snack, taken once);
  * the camp at (-113, -55): bedroll, cold lantern, an empty can, a small jacket, tracks (each can be examined), and
    the note `campsite_note`, read in the inventory's inspect view like Noah's first note. Flags `ch11_note_read`,
    `noah_clue_campsite`.
* **The field:** the view is controlled (turn, then the FOV narrows 20 %) onto a Hound silhouette, which walks off
  into the fog. FOV and control are restored afterwards. Never replayed.
* **The farmhouse** is Greyhaven's `HOUSE_20` (Pack 03 `RES_House_Abandoned`, -77.9, -92), with hinge doors added
  for the front, kitchen and bedroom 1.
  * The group waits in the living room.
  * The search covers the living room, the kitchen, the back door (inspect) and bedroom 1 upstairs.
  * In bedroom 1 is `noahs_message`, read in the inventory. Flags `ch11_message_read`, `noah_clue_farmhouse`.
  * Regrouping plays the talk. The encounter follows: a shape passes the side window, a blow on the back door, the
    approved lines.
  * Then a Hound with the Chapter 7 `VeilHoundAI` (collisions, non-lethal bites, leash 26 m) chases while the group
    follows the player out of the front door to the field at (-104, -99).
* **The distant light:** an `OmniLight3D` inside `HOUSE_19` flickers, the view is drawn to it with a slight zoom, a
  dark shape passes behind it, then "CHAPTER 12 COMPLETE".
* **Checkpoints:** `chapter12_start` and `chapter12_after_encounter` (`user://checkpoints/`).
* **Without Marcus:** his lines go to the protagonist, Ruth or Sarah as written in the prompt.
* **Known:** the farmhouse stairs are narrow (0.95 m). Walking up their middle works; about 25 cm off-centre the
  player catches on the stringer. Same for the upstairs hall beside the stairwell rail.
* **Dev entry and test:** `game/tools/dev_chapter11.gd`; `game/tests/chapter11_test.gd`.

### 9.19 Audio, vehicle and survival integration (branch `claude/audio-vehicle-survival-integration`)
Written without running Godot: nothing below has been seen working yet.
* **Car:** parts are real finds (`game/data/expedition.json` `vehicle_parts`): battery by a wreck on the west road, fuel by a
  delivery van behind the store, fuse at the gas station. `expedition.car_leads()` feeds the town map, which feeds the
  yellow diamond. One fuel can is half a tank. Fuel and condition save in `Game.vehicle_state`, fitted parts in
  `world_state.expedition.car_parts`. Out of fuel or wrecked, the car cannot reverse; `exit_spot` tries eight spots.
* **Riders:** `survivors.board_car()` seats up to three (trip companion, then followers); after a load inside the car only
  the trip companion is reseated.
* **Creatures and the car:** while driving, `VeilHoundAI._tp()` is the car; bites go to `sedan.monster_hit()`.
* **Stairs:** `game/world/stair_assist.gd` adds solid convex collision per flight from `game/data/house_stairs.json`
  (from `plans.py`). Root cause: the houses' one-sided guard faced out of the stair. The GLBs were not rebuilt; `arch.py` has the
  corrected normal for any later rebuild. Regenerate the JSON if a plan's stairs change.
* **Audio:** selected library files in `game/audio/library`, listed by bank in `game/data/audio_banks.json`, played through
  `Sfx.bank()` / `Sfx.bank_at()`. Their `.import` files were written by hand (loops forward, music and ambience QOA);
  Godot imports them on the next editor open. `game/enemies/creature_voice.gd` is one creature's 3D voice and feet.
  Encounter music is the director at the end of `game/autoload/sfx.gd`. The approved `skitter_hiss.wav` is unchanged and still
  the leap screech. The old `game/audio/encounters` pack is no longer used by the struggles.
* **Struggles:** `game/encounters/struggle.gd` now turns the view to the creature instead of moving the creature in front of
  the view, and clears walls with a ray. No creature can be killed in the game, so no death sounds were imported.
* **Crab:** the scene's own wide boxes (`ShellShape`, `LegSpan`, `ArmsShape`) are off, a 0.95 m capsule stands in, stride clips use
  the real speeds from the scene metadata, it faces the player inside 4.5 m, and it looks ahead and turns round walls.
