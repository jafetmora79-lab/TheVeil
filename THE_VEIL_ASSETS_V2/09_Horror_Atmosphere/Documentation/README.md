# THE VEIL - Pack 09 Horror Atmosphere

This pack handles presentation only. It adds no gameplay, lore, characters or monsters. Everything targets the Godot 4.3
**Compatibility** renderer:

* no volumetric fog, Decal nodes, GPUParticles, SDFGI, SSAO, SSR or GI probes;
* no screen or depth texture reads.

Rebuild it with `python3 09_Horror_Atmosphere/Source_Scripts/build_atmosphere.py` (deterministic). Validate it with
`validate_atmosphere.py`; the result is in `VALIDATION_REPORT.md`.

## Quick integration

1. Instance `Godot_Scenes/VeilAtmosphere.tscn` once in the level. It contains the WorldEnvironment, the Sun, the
   camera-following Mist (with Rain, Dust and Leaves) and the `Atmosphere` controller. Remove any other
   WorldEnvironment from the level.
2. From gameplay code, change the state:
   ```gdscript
   $VeilAtmosphere/Atmosphere.set_state(VeilAtmosphere.State.VEIL_APPROACHING)       # tweens over transition_time (6 s)
   $VeilAtmosphere/Atmosphere.set_state(VeilAtmosphere.State.NORMAL, true)            # instant
   $VeilAtmosphere/Atmosphere.apply_preset(load(".../LGT_Empty_Supermarket.tres"))   # any location preset
   ```
   The states are NORMAL, UNEASY, VEIL_APPROACHING, VEIL_ACTIVE and CORRUPTED. The controller only changes visuals; it
   never touches gameplay.
3. Corruption dressing:
   * Put corruption props, decals and the boundary curtain in the group `veil_corruption`.
   * Give each one the metadata `veil_level` (1-3). A node is shown when `veil_level` is at or below the preset's
     `corruption_level` (NORMAL/UNEASY = 0, APPROACHING = 1, ACTIVE = 2, CORRUPTED = 3).
4. Lights:
   * The controller attaches a `veil_flicker.gd` node to every Light3D whose name starts with `StreetLight_`. These are
     the Pack 02 town lamps; the Pack 02 files are not modified.
   * Add your own lights to the group `veil_streetlight` so the presets scale their energy.
   * For a single unstable light, add a `Lighting/veil_flicker.gd` child node to it (modes: STEADY, STREETLIGHT,
     FLUORESCENT, DYING, COLD_PULSE).
5. Weather groups: `veil_rain`, `veil_dust` and `veil_leaves` are switched on and off by each preset.

`Godot_Scenes/Greyhaven_Veil_Demo.tscn` puts it all together on the Pack 03 town, with dressing near the player's street.

## Contents

* **Fog/**
  * `VeilMist.tscn`: 3 stacked unshaded noise sheets plus up to 32 CPU fog cards. They follow the camera and fade
    near it.
  * `VeilFogPatch.tscn`: a local ground fog patch.
  * `VeilMistBoundary.tscn`: the cylindrical "wall" between normal and corrupted.
  * Shaders: `veil_mist_layer`, `veil_mist_boundary`.
* **Atmosphere_Presets/**
  * 5 `STATE_*.tres` and 8 `LGT_*.tres` presets (`VeilAtmospherePreset` resources).
  * `ENV_Veil_Base.tres`, the base Environment.
  * The controller `veil_atmosphere.gd`.
* **Lighting/**
  * Flicker, dim and fluorescent light scenes.
  * `LGT_FluorescentFixture.glb`.
* **Corruption/**: 15 GLB overlays and plants. These are wall stains and streaks, residue, ground blight, asphalt
  cracks, damaged and distorted road markings, window stains, organic growths, a dead shrub, corrupted vegetation and
  withered grass.
* **Supernatural_Details/**
  * Impossible shadows (wall and ground), abstract markings, a wrong-reflection pane (shader) and a cold light shaft.
  * `ColdLightLeak.tscn`.
* **Abandoned_Props/**
  * 5 new GLBs on the Pack 08 atlas: overturned cart, spilled groceries, papers, broken window panel, fallen bicycle.
  * 7 scenes that reuse Pack 02, 03 and 08 props: fallen sign, damaged streetlight, barricade, cones, broken electrical
    box, displaced furniture, personal belongings.
* **Environmental_Effects/**: CPUParticles3D scenes for dust, leaves, rain, dripping water, sparks, distant mist,
  window condensation and puddles with drips.
* **Textures/** (21, palette-locked pixel art) and **Materials/** (17 `.tres`).

## Performance notes

* All mist is a few alpha-blended planes and billboards. The layers fade out near the camera, so they never cover the
  full screen. That keeps overdraw low on the target hardware.
* Particle counts are small (rain 300; most effects 5-40). Everything uses CPUParticles3D, so the Compatibility
  renderer is supported.
* Overlay materials are unshaded or do not receive shadows. Textures use nearest filtering and are at most 128 px.
* For a smaller cost, lower `mist_cards` in the presets or the rain `amount`. You can also turn off `sun_shadows` in
  the night presets.

## Limitations

* Nothing has been checked visually. The validation is file, reference and engine-run checks only.
* The mist is a camera-following stack of sheets, not real volumetric fog. It reads best at street level, not from
  high viewpoints.
* The wrong reflection is a fake: a distorted texture on glass. It does not mirror the scene.
* The overlays are quads sitting slightly in front of surfaces, not projected decals. Place them on flat surfaces.
* The browser gallery shows only the static GLBs, textures and materials. Shaders, particles, flicker and state changes
  work only inside Godot.
