# Cinematics pass (branch `cinematics/ledger-pilot`)

- `SHOT_LEDGER.md` / `data/shots.json` - the ledger (116 rows incl. chapters 6-16 beat by beat and the three endings; every cited function/flag verified by `tools/build_ledger.py`, 141 checks).
- `blender/sequences_all.blend` (+ `build_sequences.py`, `data/sequence_timelines.json`) - one Blender scene per sequence: collections, camera lens keyed per shot, a timeline marker per shot. Timing and lens only (paths are first-person and player-driven). `animatic/index.html` - the timeline view of all of them.
- `blender/pilot_c03_02b.py` + `C03_02b_pilot.blend` - Blender 5.2 pilot: collections (Site/Cast/Creature/FX/Cameras), tripod GLB at 85 m, camera replay of `world.gd:_tripod_encounter` (428 frames @24), contact markers, round-trip check.
- `data/C03_02b_camera.json` - transferable camera/creature-path/marker data in Godot axes. `data/hookup_manifest.json` - entry points and the pilot's hookup.
- `animatic/C03_02b.html` - schematic top-down animatic (not a render). `audio/cue_sheet.csv` - cues per sequence.
- Rebuild: `python docs/cinematics/tools/build_ledger.py`; `blender -b -P docs/cinematics/blender/pilot_c03_02b.py -- <repo_root>`.
- Rules kept: no renders/videos (CLAUDE.md), nothing merged, visual checks are the owner's.
