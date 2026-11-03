# THE VEIL — Asset Pack 01: Master Pixel-Art Texture Library

Status: **complete, awaiting art-direction approval.** No 3D models have been made yet.

## Contents

```
THE_VEIL_ASSETS_V2/
  00_Art_Direction/   ART_DIRECTION.md, GREYHAVEN_PALETTE.gpl (GIMP/Aseprite/Krita), GREYHAVEN_PALETTE.json
  01_Textures/        72 PNGs + 2 atlases (lossless, each with a Godot .import file)
    Architecture/ Roads/ Ground/ Interiors/ Furniture/ Commercial/ Horror/ Atlases/
  Materials_Godot/    72 StandardMaterial3D .tres (one per texture), 3 atlas materials,
                      _Presets/ 20 texture-less preset templates (P_VEIL_*.tres)
  Source_Scripts/     build_library.py, validate_library.py, veil_texgen/ (generator package)
  Documentation/      this README, TEXTURE_MANIFEST (.json/.csv/.md), VALIDATION_REPORT.md
```

| Category | Count | Resolutions |
|---|---|---|
| A. Architecture | 12 | 11 × 128², 1 × 64² (trim); glass pane 64² RGBA |
| B. Roads | 11 | 4 × 256², 4 × 128², 3 × 64² (curb, 2 markings RGBA) |
| C. Ground & vegetation | 10 | 9 × 128², 1 × 64² (moss) |
| D. Interiors | 10 | 10 × 128² |
| E. Furniture | 11 | 9 × 64², 2 × 32² |
| F. Commercial | 10 | 1 × 256², 6 × 128², 2 × 64², 1 × 64×128 (door) |
| G. Horror | 8 | 4 × 128², 4 × 64² (3 RGBA decals/cutouts, 1 sign) |
| Atlases | 2 | 256² opaque props (14 cells + 2 reserved), 128² RGBA horror decals (4 cells) |

All 72 textures are seamless in U and V except the six 0..1 textures: window pane, door, stain, residue, dead-foliage card, and warning sign.

## Installing in Godot 4

1. Copy the whole `THE_VEIL_ASSETS_V2/` folder into your Godot project root, so the materials resolve to `res://THE_VEIL_ASSETS_V2/...`.
   If you put it somewhere else, regenerate with the new root (see *Regenerating*).
2. Open the project. Godot imports the PNGs using the supplied `.import` settings:
   **Lossless** compression, **mipmaps on**, *Detect 3D* disabled. That last one matters: it stops Godot silently switching the textures to blurry VRAM compression.
   If you ever reimport by hand, keep those three settings.
3. `Source_Scripts/` contains a `.gdignore`, so Godot skips the Python sources.

### Applying a material

* **Mesh in the editor:** select the `MeshInstance3D` → *Surface Material Override* → drag in `Materials_Godot/<Category>/M_<Name>.tres`.
* **In code:** `mesh_instance.set_surface_override_material(0, load("res://THE_VEIL_ASSETS_V2/Materials_Godot/Architecture/M_Arch_SidingWhite.tres"))`.
* **Imported .glb/.blend models:** in the import dock, use *Materials → Use External* and point each slot at a library `.tres`. That keeps every house sharing the same material resources.

### UVs and scale (the one rule to remember)

**Tiling materials expect meter-UVs: 1 UV unit = 1 metre.** Their `uv1_scale` is already set to
`64 / texture_size`, so a 128 px wall texture shows 2 m of siding per repeat at exactly 64 px/m.
* Model in metres and unwrap tiling surfaces at 1 UV/m (in Blender, *Cube Projection* at size 1, or *World-scale UV* addons).
* Godot `BoxMesh`/`PlaneMesh` primitives use 0..1 UVs per face. For those, either set the material's `uv1_scale` to the face size × the default scale, or enable `uv1_triplanar` with `uv1_world_triplanar` for quick greyboxing. Triplanar costs a little more, so prefer real UVs for shipping meshes.
* Non-tiling materials (door, window pane, sign, decals, foliage card) use 0..1 UVs and `uv1_scale = 1`.

### Transparency, decals and cutouts (Compatibility renderer)

* The `Decal` node is **not supported** in the Compatibility renderer. Use the decal textures on small quads placed ~1 cm in front of a surface, with `M_Hor_StainOrganicDark` / `M_Hor_ResidueStrange` (alpha blend, `texture_repeat` off).
* `M_Hor_GrimeAbandoned` is a tileable RGBA overlay. Assign it as the **`next_pass`** of any wall material to make that wall look abandoned, without touching the base material.
* Road markings (`M_Road_Marking*`) are alpha-blended. Lay thin quads 1–2 cm above the asphalt.
* `M_Hor_FoliageDead` and `M_Hor_WarningSignWeathered` use **alpha scissor** (cheap, sorts correctly). The foliage card is double-sided.
* `M_Arch_WindowGlassDirty` is alpha-blended and double-sided, so it reads from inside the house too.

### Filtering

Materials set `texture_filter` per surface:
* `2` = Nearest + mipmaps: walls, props, decals.
* `4` = Nearest + mipmaps + anisotropic: roads, ground, floors, roofs, i.e. surfaces seen at grazing angles where shimmer is worst.
  If your target hardware lacks anisotropic filtering, Godot falls back to `2` automatically.
To change all of them at once, set *Project Settings → Rendering → Textures → Default Filters* and switch the materials to "Parent Node" filtering. The per-material values are explicit so the library behaves the same in any project.

### Presets for future packs

`Materials_Godot/_Presets/P_VEIL_*.tres` are texture-less templates: Painted, Wood, Masonry, Roof, Ground,
Floor, Ceramic, Fabric, Leather, Plastic, Rubber, Metal_Bare/Painted/Rusted, Glass, Decal_Blend, Overlay_Blend,
Marking, Cutout, Sign. To make a new material, *duplicate* a preset, assign `albedo_texture`, and set `uv1_scale = 64 / size` for a tiling texture.
The values live in `Source_Scripts/veil_texgen/registry.py → PRESETS`; edit there and rebuild to change the whole library.

### Atlases

* `T_ATLAS_Props_Opaque` (256², 4×4 grid of 64 px cells) holds the furniture materials plus shelving, signage backing and trim. The 32 px textures are tiled 2×2 inside their cell, so density stays at 64 px/m. Cells 14–15 are reserved (neutral grey).
* `T_ATLAS_Horror_Decals` (128², 2×2) holds the stain, residue, dead foliage and warning sign. It has two materials: `_Blend` and `_Cutout`.
* Cells are power-of-two aligned, so mipmaps never bleed between cells and no gutters are needed. Atlas UVs cannot repeat: keep each face's UVs inside its cell. The pixel and UV rects for every cell are listed in `TEXTURE_MANIFEST.md` and `.json`.
* Use atlases for small props that should share one draw call. Use the individual materials for anything that tiles.

## Regenerating / editing

Requires Python 3.9+, `numpy` and `Pillow` (`pip install -r Source_Scripts/requirements.txt`).

```
python3 Source_Scripts/build_library.py            # rebuild everything (deterministic)
python3 Source_Scripts/build_library.py --res-root res://art/THE_VEIL_ASSETS_V2   # different project location
python3 Source_Scripts/validate_library.py         # automated checks -> Documentation/VALIDATION_REPORT.md
```

* **Palette:** `veil_texgen/palettes.py`. Change a ramp and every texture that uses it updates.
* **One texture:** each has its own function in `veil_texgen/gen_<category>.py`, and its spec is one line in `registry.py`.
  Seeds come from the texture name, so changing one texture never changes the others.
* Hand edits in Aseprite or another editor are fine. Load `GREYHAVEN_PALETTE.gpl` first, and note that a rebuild overwrites the PNG, so either stop regenerating that texture (remove it from `registry.py` and keep the file) or port the change into its generator.

## Validation: what was and was not verified

`validate_library.py` checks that:
* every registered texture exists and is a readable PNG at its specified resolution;
* RGB/RGBA matches the transparency mode, alpha is actually used, and decal borders are clear;
* every colour belongs to the master palette;
* no texture is flat, a placeholder, or a duplicate;
* tiled axes have no gross wrap seam;
* `.import` settings are lossless with mipmaps;
* every material exists, resolves to the right texture, and has consistent transparency, filter and UV scale;
* the manifest is complete;
* every atlas cell is pixel-identical to its source texture.

Current result: **72/72 pass, 0 failures, 0 warnings.**

Limits:
* The seam test catches gross wrap breaks only. In a calibration run it flagged about a third of deliberately broken random crops, mostly the obvious ones. Seamlessness is really guaranteed by construction: every drawing operation wraps and all noise is periodic.
* **Visual quality has not been verified.** No renders, screenshots or previews were made, as requested. The only structural spot-checks were text dumps of a few small regions (brick, siding, wallpaper, grass, leaves, sign). How good the textures look must be judged in Godot.
