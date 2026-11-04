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
