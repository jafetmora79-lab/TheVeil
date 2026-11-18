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
