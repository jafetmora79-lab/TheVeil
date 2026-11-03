# THE VEIL — Asset Pack 02: Greyhaven Town, Roads & Outdoor Environment

Status: **complete, awaiting approval.** No houses (Pack 03) or commercial buildings (Pack 04) are included.
Those locations are reserved as building-placement zones.

## 1. What's here

```
02_Town/
  Roads/          27 GLB   road modules, lots, driveway, alley, rural road, curves, patches, puddles, markings
  Sidewalks/      12 GLB   straight/cracked sidewalks, driveway apron, curb ramp, storm drain, curb, gutter,
                           rounded corner, parking-lot edge, crosswalk
  Street_Props/   38 GLB   lighting (4), traffic (11 incl. extra sign types), town details (13),
                           + 10 street-name sign variants used by the layout
  Utilities/      14 GLB   utility pole, pole/pad transformers, power lines (20/25/30 m), telephone lines
                           (25/30 m), junction box, electrical cabinet, water meter, AC unit, rooftop vent,
                           access cover
  Vegetation/     19 GLB   5 trees, 7 plants, 7 ground details
  Fences/         12 GLB   picket, privacy, chain-link, metal railing, brick wall, retaining wall, privacy
                           gate, garden gate, hedge boundary, 3 end/corner posts
  */OBJ/                   OBJ + MTL copy of every kit model (ignored by Godot via .gdignore)
  Textures/       23 PNG   only what Pack 01 could not cover (see section 7)
  Materials/      31 .tres Pack 02 materials (same presets/filters as Pack 01) + 3 optional world-UV asphalt
  Town_Layout/             TOWN_Ground, TOWN_GasForecourt, TOWN_BuildingZones, 32 TOWN_Woods_* chunks,
                           greyhaven_layout.json (every placement, zone, route)
  Godot_Scenes/            Greyhaven_Town.tscn   <-- the town layout scene
  Source_Scripts/          generators (Python 3 + numpy + Pillow), validator
  Documentation/           this file, MODEL_MANIFEST.md/.json, VALIDATION_REPORT.md, PACK02_TEXTURES.json
```

**122 kit models**: the 112 requested assets plus 10 street-name sign variants. There are also 35 layout GLBs, generated specifically for Greyhaven.
Every GLB has a Godot `.glb.import` that maps its materials to the **existing Pack 01 `.tres` files**. Pack 01 materials are used directly, not copied, so changing a Pack 01 material restyles the whole town.

## 2. Install / open

1. Copy all of `THE_VEIL_ASSETS_V2/` (Pack 01 + 02) into the Godot project root. Everything resolves to `res://THE_VEIL_ASSETS_V2/...`.
2. Let Godot import (Godot 4.3 was used for validation; Compatibility renderer).
3. Open **`res://THE_VEIL_ASSETS_V2/02_Town/Godot_Scenes/Greyhaven_Town.tscn`**. It's self-contained, with no game code, and it doesn't touch the player, inventory, combat or story systems.
4. Drop your player into the scene, or instance the scene in your own main scene. The `Journey` markers show the opening route.

## 3. Dimension standard (all modules)

| Element | Value |
|---|---|
| Two-lane asphalt | 7.0 m (y = 0) |
| Concrete gutter | 0.25 m each side → road module 7.5 m |
| Curb | 0.15 m high, 0.20 m curb-top band |
| Sidewalk module | 2.25 m → street right-of-way **12 m** |
| Lots, driveways, parking, alley, terrain | y = 0.15 (flush with sidewalks) |
| Straight modules | 10 m |
| Intersections / sharp corner / dead end | 12 × 12 m, centred on origin |
| Gentle curves (rural) | 90°, 24 m centreline radius, 30 × 30 m footprint incl. ground fill |
| Fence sections | 2.5 m (gates 1.25 m) |
| Texel density | 64 px/m via meter-UVs (signage atlas ≈ 85 px/m for legible lettering) |

**Snap grid:** module origins and ports land on 0.25 m (all used ports are on whole metres).

* **Segment modules** (straight roads, composite streets, rural, transition, sidewalks) run along local **+Z from 0 to L**. Their ports are at z=0 (facing −Z) and z=L (facing +Z).
* **Node modules** are centred, with ports at ±6 m on each open side.
* **Sidewalk modules** sit on the road's local **+X** side: x=0 is the curb face, x=2.25 the property line. For the opposite side, rotate 180° and place at (−3.75, 0, L) in road space.
* **Gentle curves:** entry at the origin travelling +Z. `Right` exits at (−24, 0, 24) heading −X; `Left` exits at (24, 0, 24) heading +X.
  (Godot's frame: facing +Z, your right hand is −X.)
* Every module's ports and footprint are listed in `MODEL_MANIFEST.json`.

**Walkability:** visually the curbs are vertical 15 cm faces. In the collision meshes they're replaced by a ~17° chamfer, so a CharacterBody3D steps onto the sidewalk without step-up code. This was verified with a capsule in Godot (section 9).
Driveway aprons and curb ramps drop the curb to 2 cm / 0 cm.
*Vehicles:* the same chamfer lets cars mount curbs. If that matters later, put curb collision on its own physics layer.

## 4. Greyhaven layout (`Greyhaven_Town.tscn`)

```
                      N (−Z)
   Maple Ave  ●═════╦══════════╦══════════╗ (sharp corner)     utility poles + power/phone lines
   (dead end) lots  ║  lots    ║ lots  ★  ║                     ★ PLAYER_HOME (Maple Ave, south side)
              Birch ║          ║Oak St    ║ Cedar St
   Elm St     ══════╬══════════╬══════════╣                     residential blocks, 25 house zones
                    ║ ARCHIVE  ║SUPERMARKET (parking lot)
   Mill Rd ◄════════╩═Main St══╬══════════╩═══════════╦═► Route 9 → curve → ESCAPE_ROUTE_EAST
   (woods, trailhead)  PHARMACY║ GAME SHOP  STOREFRONTS ║ GAS STATION (NE corner lot)
                       alley ══╣ Oak St S (dead end)    ║
                                                        ╚═► Quarry Rd → curve → QUARRY_ENTRANCE, FARMHOUSE
```

* Map ≈ 380 × 240 m: a compact town core (~230 × 175 m) ringed by woods. It isn't an empty open world.
* **Opening sequence:** wake at `PLAYER_HOME` → sedan on its driveway → Maple Ave → Oak St → Main St → `SUPERMARKET` parking lot (≈200 m drive).
  `GAME_SHOP` is directly across Main St, **37 m on foot**, with crosswalks at Main & Oak (signalised) and a mid-block crossing.
  `PHARMACY` and `MUNICIPAL_ARCHIVE` are on the same street.
* **Outskirts:** Quarry Rd (rural, shoulders) leads to the gated `QUARRY_ENTRANCE` (the quarry itself isn't built) and the sparse `FARMHOUSE`. Route 9 leaves town to the east (`ESCAPE_ROUTE_EAST`). Mill Rd runs into the woods (`WOODS_TRAILHEAD`, sparse `MILL_HOUSE`).
* The atmosphere starts normal: warm evening sky, low orange sun, light warm fog, ordinary streetlights. There's no corruption anywhere in the town. Pack 01's horror materials are used only as dead-foliage cards and darkened dead-tree twigs.

### Scene organisation

```
Greyhaven_Town
├─ Environment        WorldEnvironment (evening sky + fog) + EveningSun
├─ Static
│  ├─ Terrain         TOWN_Ground (grass/woods floor at 0.15 m, collision)
│  ├─ Roads           95 road-network modules
│  ├─ Sidewalks       108 sidewalk modules
│  ├─ Lots            driveways, supermarket parking (4 modules + edges), alley (5), gas forecourt
│  ├─ Markings        crosswalks, manholes, grates, puddles, patches
│  ├─ StreetProps     lamps, signs, signals, hydrants, mailboxes, benches, meters, bus stop/shelter…
│  ├─ Utilities       poles, power & telephone lines, transformers, cabinets, AC units
│  ├─ Vegetation      yard trees/bushes + WoodsChunks (32 batched woods/undergrowth meshes)
│  └─ Fences          lot fences/hedges, archive brick wall/railing, gas-station + quarry fences
├─ Interactive        cones, barriers, public bins, newspaper boxes, phone booth, dumpsters, all gates
├─ Lights             OmniLight3D at selected lamps (Main St, home street, gas station, rural poles)
├─ BuildingZones      TOWN_BuildingZones (translucent boxes) + Markers/<ZONE_ID> (Marker3D + Label3D)
└─ Journey            1_WAKE_UP_HOME … 6_GAME_SHOP_ENTRANCE route markers
```

Every instance has `metadata/tag` set to its street, lot or zone.
Each zone marker carries `zone_id`, `zone_type`, `size`, `front` (the direction the facade should face), `access` (where it meets the drivable/walkable network) and `target_pack`. The hero zones (home, supermarket, game shop, pharmacy) are tinted blue.
**Zones:** PLAYER_HOME + 22 house lots (HOUSE_01–23; slot 14 is the player home), FARMHOUSE, MILL_HOUSE (Pack 03); SUPERMARKET, GAME_SHOP, PHARMACY, MUNICIPAL_ARCHIVE, STOREFRONT_A–D, COMMERCIAL_SPARE, GAS_STATION, GAS_PUMP_CANOPY (Pack 04); QUARRY_ENTRANCE, ESCAPE_ROUTE_EAST, WOODS_TRAILHEAD (future).

Interactive pieces have separate pivot nodes: `GateLeaf` on gates (hinge at the node origin), `Lid_L`/`Lid_R` on dumpsters, `Door` on the phone booth.
Light and attachment points are empty nodes: `LightPoint`, `Attach_Power_L/C/R`, `Attach_Tel`, `Signal_Arm_*`.

## 5. Using the kit by hand

* **Streets:** chain `RD_Straight_*` (road only) + `SW_*` on both sides, or the composite `RD_Street_Residential_10m` / `RD_Street_Commercial_10m` (road + both sidewalks). Join them with `RD_Intersection_*`, `RD_Corner_Sharp_12m` or `RD_DeadEnd_12m`.
* **Driveway:** swap one side's sidewalk for `SW_DrivewayTransition_10m` (apron centred at z=5) and put `RD_Driveway_3x8m` at the property line.
* **Town → countryside:** `RD_Transition_UrbanToRural_10m` → `RD_Shoulder_Rural_10m` → `RD_Curve_Gentle_*`.
* **Power lines:** place `UT_UtilityPole` at 20/25/30 m spacing, with pole and `UT_PowerLine_SpanXXm` / `UT_TelephoneLine_SpanXXm` sharing the same ±90° yaw. The wires start exactly on the insulators and end on the next pole.
* **Fences:** each section starts with its own post at x=0. Chain sections end-to-end, turn corners by rotating 90° at a post, and cap the run with `FN_Post_*`.
* **Decals:** the Compatibility renderer has no Decal node. Puddles, patches, manholes and grates are thin meshes sitting 4–12 mm above the surface.
* **Optional seamless asphalt:** Pack 01's 4 m asphalt tile doesn't divide the 10 m module, so modules can show faint texture seams where they meet. `02_Town/Materials/M_Town_*_WorldUV.tres` sample the same textures in world space (triplanar). Assign one as an override on the road modules if the seams bother you; it costs a little more per pixel.

## 6. Performance (Compatibility renderer, integrated GPU / Android)

* Props: 10–514 triangles. Trees: 181–612. Road modules: 2–234. The whole scene is ≈285 k visual triangles.
* No custom shaders. Lamp glass and signal lenses use standard emission. Glass, cutout cards and decals are standard alpha.
* Woods and undergrowth (1,141 items) are **statically batched into 32 chunk meshes** (64 × 64 m). Authored town pieces stay as individual instances so you can edit them.
  Estimated draw surfaces before culling are ≈2,140, and Godot frustum-culls per instance.
* OmniLights are limited to the key streets, with distance fade at 45–60 m and no shadows. All other lamps glow through their emissive material only. On Android you may want fewer lights: they're grouped under `Lights`.
* Ideas for later, if profiling demands it: batch fences per block, add `visibility_range` to small props, or convert the woods chunks to MultiMesh.

## 7. Pack 02 textures (new only where Pack 01 had no equivalent)

`SignAtlas` (stop, yield, speed limit 25, parking, no parking, bus stop, dead end, one way, phone/gazette labels, 10 street-name blades in a hand-authored 5×7 pixel font), 7 painted-metal colours (hydrant red, cone orange, navy, black, safety yellow, municipal green, white), `HazardStripe`, `ChainLink` (cutout), `Puddle`, `ManholeCover`, `DrainGrate`, `UtilityCover`, `PineNeedles`, `GrassCards` (cutout), `FlowerBed`, `Ivy` (cutout), `Rock`, `PoleWood`, `StumpTop`, `VentGrille`, `LampGlow`.
All of them use the Pack 01 generator, master palette and lighting rules. I appended eight ramps to the palette (`paint_red`, `paint_orange`, `paint_navy`, `paint_black`, `sign_green`, `pine`, `flower`, `glow`). Pack 01's PNGs rebuild byte-identical.
Everything else comes straight from Pack 01: asphalt, cracked asphalt, parking asphalt, sidewalk, curb, gravel, markings, road patch, grass, overgrown grass, leaves, soil, mud, bark, hedge foliage, dead vegetation, brick, concrete, planks, trim paint, glass, storefront concrete, gas-station pavement, signage backing, metals, rubber, wood, plastic, dead-foliage card, darkened wood.

## 8. Regenerate

```
pip install -r Source_Scripts/requirements.txt
python3 02_Town/Source_Scripts/build_town.py          # textures, materials, 122 models, layout, scene (≈5 s, deterministic)
python3 02_Town/Source_Scripts/validate_town.py \
    --gltf-validator <dir with node_modules/gltf-validator> \
    --godot <Godot 4.x binary>                         # both optional
```
Edit the layout in `town_layout.py` (`NODES`, `EDGES`, `RURAL`, the lots, `build_props`), or edit the `.tscn` in Godot directly. A rebuild overwrites the scene, so commit any hand edits first.

## 9. Validation (automated, no rendering)

Results are in `VALIDATION_REPORT.md`: **0 failures, 0 warnings**.
* All files are present. 157 GLBs pass the **Khronos glTF-Validator with 0 errors / 0 warnings**, plus the pack's own checks: index ranges, UVs on every visual primitive, unit normals that agree with winding, no degenerate triangles.
* Every material maps to an existing `.tres` whose texture exists. In Godot, **all 2,204 mesh surfaces resolve to Pack 01/02 `.tres` files** (0 embedded or null).
* Every surface module passes a 5 cm top-down coverage test: **0 holes, 0 overlapping surfaces**. Mesh bounds match the declared footprints, and ports are on the snap grid.
* The road network was rebuilt from the placed modules' ports: **95 modules, 1 connected component**. The only open ports are the 3 intended termini.
  Every required route from `PLAYER_HOME` exists: supermarket, game shop, pharmacy, archive, gas station, quarry, escape route, trailhead, farmhouse, mill house. All 39 zones are reachable.
* Godot 4.3 headless:
  * The project imports with 0 errors, and the scene instances with 882 collision shapes.
  * 54/54 raycasts along the opening route hit ground.
  * Curb collision ramps up 0 → 0.06 → 0.105 → 0.15 m.
  * A 0.35 m capsule walks from road onto sidewalk over full 15 cm curbs on Main St and in front of the player's home.
  * All 31 Pack 02 materials load.
  * Terrain and forecourt surfaces sit exactly at 0.15 m.

## 10. Limitations / not done

* **Visual quality is unverified.** No renders, screenshots or previews were made, as requested.
* **No `.blend` files:** Blender isn't available here. The editable sources are the Python generators. Every GLB and OBJ imports into Blender if you want to hand-edit one, but regenerating will overwrite it.
* No LODs. The models are already low-poly, and Godot's automatic LOD is disabled in the import files.
* `UT_RooftopVent` and `SP_Lamp_Wall` aren't placed in the town, because they need Pack 04 roofs and walls.
* The gas station has a forecourt, pump islands, fencing and a phone booth, but no building or canopy (Pack 04). The quarry is only a gated gravel apron.
* Asphalt texture seams can appear between modules with the default Pack 01 materials (see the optional WorldUV materials in section 5).
* The curb collision chamfer also lets vehicles mount curbs (see section 3).
* Terrain is flat at 0.15 m; there are no hills.
