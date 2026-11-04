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
| 03 Residential | `03_Residential/` | Done. 23 house variants, all enterable. Player home staged for the opening. 85 furniture GLBs. Reusable **building kit** (`house.py`, `arch.py`, `plans.py`) and **walk checker** (`navcheck.py`). `Residential_Scenes/Greyhaven_Town_With_Houses.tscn`. |
| 04 Commercial | `04_Commercial/` | Done (P1/P2/P3). The locations: supermarket, video game store, gas station + canopy, pharmacy, municipal archive. Storefronts A–D are **generic explorable shells, tenants unassigned**; `COMMERCIAL_SPARE` is still empty, because the bible names no business for these. 49 shared fixtures. Each location has a scene in `Godot_Scenes/` and is placed via `Greyhaven_Commercial.tscn`. `Greyhaven_Town_Complete.tscn` = town + houses + commercial. |
| 05 Vehicles | `05_Vehicles/` | Done. Protagonist sedan (full interior, movable doors / hood / trunk / wheels / steering wheel, seat + camera markers, `Godot_Scenes/Protagonist_Sedan.tscn`). Also a police cruiser, pickup, delivery van, 2 traffic variants, 5 abandoned variants and roadside props. No driving physics (by request). |
| 06 Characters | `06_Characters/` | **Approved** (see section 4). Facial expressions + talking are done (`Facial/`). |
| 07 Creatures / enemies | - | **Not started.** It was postponed; ask the owner before starting. |
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

* **Pack 07** (supernatural creatures / enemies): not started. Ask the owner for direction. It should match the
  approved character style and the Pack 09 Veil states.
* **Storefronts A–D and `COMMERCIAL_SPARE`:** they need tenants or story assignments before fitting them out.
* **Characters:** optional extras if the owner wants them: a skirt for Ruth, short sleeves for Frank, a different
  silhouette for the women, or more face variety.
* **Gameplay systems:** none exist yet. Driving, door logic, dialogue, quests and NPC AI were all explicitly out of
  scope for the asset packs. The scenes carry markers and metadata ready for them.
* **The opening sequence:** stop order and timing (supermarket vs. game shop, mist arrival) is still open in the bible
  (section 2.2 and the open questions).
