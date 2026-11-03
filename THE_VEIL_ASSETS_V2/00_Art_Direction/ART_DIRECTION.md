# THE VEIL — Art Direction Bible (Pack 01 foundation)

Greyhaven is a small American town that looks lived-in and slightly cosy until the mist arrives.
Every asset should read as an **intentionally stylised, pixel-textured, low-poly horror game**.
It should never look like a low-resolution photograph.

## 1. Pillars

| Do | Don't |
|---|---|
| Low-poly, chunky, slightly exaggerated silhouettes (thick trim, deep roof overhangs, oversized door handles) | Photoreal proportions or dense geometry |
| Hand-placed pixel clusters: boards, bricks, blades, stones, cracks | Random per-pixel static, photo downsamples |
| Muted, hue-shifted palette with a few "interesting" accents (mustard, teal, rust) | Saturated toy colours (Roblox) or monochrome mud |
| Nearest-neighbour textures at one shared density | Blurry bilinear magnification, mixed densities |
| Horror through lighting, fog and *rare* corrupted materials | Gore and corruption everywhere before the story beat |
| Mild vertex snapping at most, if any | Heavy PS1 wobble or affine warping |

## 2. Texel density: 64 px per metre (mandatory)

* **1 texel ≈ 1.56 cm.** This applies to every surface in every pack: houses, roads, furniture, characters' clothing.
* Tiling materials assume **meter-UVs** (1 UV unit = 1 m). Their `uv1_scale` is `64 / texture_size`
  (0.25 for 256 px, 0.5 for 128 px, 1.0 for 64 px, 2.0 for 32 px). Model in metres, unwrap at 1 UV/m, and density stays consistent automatically.
* Non-tiling textures (door, window pane, sign, decals) map 0..1 across the object. They are already authored at 64 px/m for their real size (for example, the door is 64×128 for a 1×2 m door).
* Choose resolution by **how much world area a tile must cover before repetition shows**, not by "bigger is better":
  * 32 px: tiny uniform props (rubber, plastic)
  * 64 px: furniture, trims, moss, decals, signage
  * 128 px: walls, roofs, interiors, most ground
  * 256 px: large repeating ground planes (asphalt, parking lot, dirt road, forecourt)

## 3. Pixel-art construction rules

1. **One master palette** (`GREYHAVEN_PALETTE.gpl` / `.json`): 64 ramps (326 colours), 3–7 colours per ramp, dark→light.
   Every pixel in Pack 01 is from this palette (the validator enforces it).
2. **Hue-shifted ramps.** Shadows drift cool/violet, highlights drift warm/yellow. Shading means stepping along a ramp, never multiplying RGB.
3. **Light comes from the top-left.** Stones, bricks, tiles, cracks and holes are lit on the top-left and shadowed on the bottom-right.
4. **Clusters, not noise.** Low-frequency noise only decides *where* wear, fading or damp goes. It is then quantised to 2–3 ramp steps and cleaned of orphan pixels. Detail comes from explicit shapes:
   * wood: boards, seams, flowing grain that bends around knots, nails
   * brick: individual bricks with varied widths, staggered joints, recessed mortar
   * asphalt: 1–4 px aggregate stones on a jittered grid, not static
   * fabric: real weave patterns (twill, loop pile, basket) with slubs
5. **Restraint.** Most textures use 5–15 colours. Wear and fading touch only the outer ~20% of a surface.
6. **Seamless by construction.** All drawing wraps around the tile, and noise is periodic.
   Joints that land on a tile edge always have an interior twin, so tiling never shows a "double line".

## 4. Colour moods

* **Daytime Greyhaven:** faded whites, dusty blues and sages, warm brick, olive lawns, cream trim.
* **Interiors:** rose and green wallpapers, warm floorboards, teal/cream ceramics, mustard paint, olive tweed. It should feel nostalgic, a little shabby, and cosy.
* **Commercial:** buff brick, pale concrete, cream VCT and grey-beige steel, a slightly sterile contrast to the homes.
* **Mist / horror:** ash grey, purple-black (`corrupt`), sickly residue green, near-black `stain`.
  Use these only on story-specific materials (the `Horror/` folder), never on default town materials.

## 5. Lighting and rendering assumptions (Godot 4, Compatibility renderer)

* Textures are lossless, nearest-filtered, with mipmaps enabled (`NEAREST_WITH_MIPMAPS`).
  Large ground and floor planes use the anisotropic variant to reduce shimmer at grazing angles.
* Materials are plain `StandardMaterial3D` with no custom shaders. Roughness and metallic come from the material presets. Albedo is the only map; the pixel art carries the shading detail.
* Atmosphere comes from scene setup (fog, low ambient light, warm practical lights, cold moonlight), not from the textures. Keep albedo values mid-range so lighting can push them either way.

## 6. Future packs checklist

- [ ] Uses only Greyhaven palette ramps (add new ramps to `palettes.py` if truly needed)
- [ ] 64 px/m density; meter-UVs on tiling surfaces
- [ ] Applies a `P_VEIL_*` preset material
- [ ] Top-left light in baked pixel shading
- [ ] Recognisable shapes at gameplay distance; no static noise
- [ ] Horror materials only where the story calls for them
