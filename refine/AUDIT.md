# THE VEIL refinement - audit (branch claude/veil-visual-refinement, from claude/ch12-fixes)

Playable game: this repository (TheVeil, Godot 4.3 GL Compatibility). The Quarry-Days repo only holds a copy of the asset library.
Rules kept: nothing in `THE_VEIL_ASSETS_V2/` or any game script was changed; new work lives in `refine/`.
Note: `CLAUDE.md` says the owner does all visual testing and prefers no renders; the "before" previews here were requested explicitly for this assignment.

## Findings (from the files and the Blender previews in `refine/previews/`)
- Cast (9 models, ~2.8-3.2k tris each, shared Eddie humanoid rig, painted pixel textures, VeilFace texture-swap faces): readable stylised
  humans with collars, hoodies, hair clusters. They are NOT block/primitive characters. All are T-pose; body motion is procedural at
  runtime (`game/npc/npc_animator.gd`: idle, look-at, talk, scared, walk/run). Eddie is owner-made reference (do not modify); Marcus is approved.
- Creatures: Colossus (8.6k tris) already has a strong four-legged, tentacled silhouette. Hound, Skitter, Shellcrawler (~3-3.5k tris) have baked
  clip lists in `07_Creatures/Animations/*.json`. Scale check: Hound reads tiny next to the Colossus (expected), not yet judged in-game.
- Not yet judged (needs in-game view, not Blender): house geometry, doors/windows, fog zones, menu/HUD, first-person hands.
- Art bible says: mild vertex snapping at most, no heavy affine warp (agrees with the earlier PSX test in the Quarry-Days branch).

## Previews
- before_cast.png, before_creatures.png: lineups (read-only import of the library GLBs).
- before_sarah_head_*.png: close-up of an unapproved cast model.
Tools: `refine/tools/preview_lineup.py`, `preview_closeup.py` (Blender 5.2, `blender -b -P ... -- args`).

## Houses and doors - in-game check (Godot 4.3, the game's own Greyhaven_Houses.tscn)
- `refine/previews/houses_exterior.png` (survey of every house in the game scene) and `cut_twostorey_b.png` (cutaway of the two-storey B,
  the house in the owner's old audit pictures): fronts, roofs, shutters, doors, steps and interiors are intact; the upper hall shows
  no open floor hole; stairs sit inside a railed well. The owner's `House Audit pictures` (hole between floors, narrow stairs, ...)
  come from the older `greyhaven-residential-reconstruction` viewer branch and are not reproduced in the current game scene.
- Not reproduced here, still unchecked: Cottage B, the ranch window shelf, the fridge facing, basement-stair floors (all need a walk-through).
- Houses are single baked meshes inside THE_VEIL_ASSETS_V2 (must not change), so any fix would be a runtime patch in game/ like `VeilStairAssist`.
  No defect was found worth patching, so no house/door files were changed.

## Skitter / Hound / menu - checked in the real game
- `roof_skitter_handoff_test` (headless, real World scene, both win and lose outcomes): all 26 checks PASS, including feet_on_surfaces,
  crawls_on_visible_roof, fast_rush, hiss_faces_lens, clear_zigzag_left, ends_hidden_behind_house. Ground contact, a collision copy of the visible roof,
  hiss, leap and zigzag retreat already exist (`game/encounters/roof_skitter.gd`).
- Hound (`game/enemies/hound_ai.gd`): floor ray snap, smoothed turning, stride-matched clip speed, wall steering, wedge recovery already exist.
  Nothing measurable was broken, so no behaviour was changed. Not judged: how the Hound looks in motion (needs a play-through).
- Main menu (`before_menu.png`): already the Game Haven shop in rain and mist with a compact left menu and pixel title - what the brief asked for. Unchanged.
