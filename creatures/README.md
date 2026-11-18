# THE VEIL creature remaster (branch claude/veil-visual-refinement)

Originals stay untouched in `THE_VEIL_ASSETS_V2/07_Creatures/` (recoverable backups). New game assets live in `game/creatures/<name>/` as `CRT_<Name>_v2.glb/.tscn`
(same rig, same clip names, same collision/markers/metadata as the library scenes); the scripts point to the v2 scenes.
Blender sources: `creatures/source/*.blend`. Reproducible builds: `creatures/tools/build_<name>_v2.py`
(`blender -b -P creatures/tools/build_hound_v2.py -- out.glb out.blend`). Previews: `creatures/previews/*_old_vs_new.mp4` (same camera, light, playback speed and ground speed).
`creatures/` is .gdignore'd: Godot only sees `game/creatures/`.

| Creature | New clips | Mesh | Game integration | Tests run |
|---|---|---|---|---|
| Hound | Idle, Walk (stalk), Trot (new), Run (rotary gallop, spinal gather/extension), Alert, Attack_Bite (coil-lunge-snap-shake), Hit_React, Death | haunches, chest, neck, fangs, grime | chapters 10-15, trailer; `hound_ai.gd` plays Trot between stalk and gallop | trailer_test pass; chapter11/12 failures identical to baseline |
| Skitter | Idle_Twitch, Crawl, Scuttle_Fast, Alert (rear-up hiss), Attack_Lunge (coil, leap, landing), Hit_React, Death | dorsal thorns, knee spurs, grime | all spawn sites + roof encounter; native speeds 0.472 / 2.588 unchanged | roof_skitter_handoff_test (26), frank_skitter_test, trailer_test pass |
| Colossus | Idle_Breathe, Walk_Heavy, Walk_Fast (new), Tentacles_Sway, Alert, Attack_TentacleStrike (impact 1.05 s), Attack_Heavy, Hit_React, Death_Collapse; baked at 90 fps | grime | intro cinematic, chapter 15, death sequence, trailer. **The first street encounter in `world.gd` keeps the original model and clip** | opening, trailer, intro_trailer, chapter15 tests pass |
| Shellcrawler | Idle, Crawl_Sideways, Crawl_Forward, Defend, Attack_Grasp, Hit_React, Death | shell spines, knee spurs, grime | expedition, chapters 13, 14 | chapter13, chapter14 tests pass |

## Known limitations
- Mesh changes are additions (thorns, spurs, fangs, spines, vertex-colour grime) and proportion tweaks on the Hound; no creature was re-sculpted.
- Not watched in a live playthrough; only rendered previews and headless tests.
- Colossus in `world.gd` (first street encounter): its foot-touchdown detection needs the claw tips flat to ~1 cm during stance; the new 30/90 fps clip
  does not meet that, so that one scene keeps the original clip (see commit message). Fixing it means either a flatter stance or relaxing `_swing_end`.
- `cinematics/cinematic.gd` (menu "Watch Preview") loads the old Hound/Skitter/Colossus GLBs directly.
- Shellcrawler travel direction (sideways = toward the body's left) was inferred from the game's `face_offset`, not verified in play.

## Colossus v3 - a new creature modelled from scratch (supersedes the v2 mesh)
`creatures/tools/build_colossus_new.py` models it in Blender (primitives -> voxel-remeshed organic mass + separate bone/tentacle/claw parts, three 128 px pixel textures + a sparse
crack emission map, weights by nearest bone segment) on the ORIGINAL skeleton, so every clip, cinematic and collider still fits; `build_colossus_v2.py` (with `COLOSSUS_SRC` /
`COLOSSUS_NO_GRIME`) then bakes the same clips onto it. Game: `game/creatures/colossus/CRT_Colossus_v3.tscn` (intro cinematic, chapter 15, death sequence, trailer; world.gd's first street
encounter still uses the original). Preview: `creatures/previews/colossus_v2_vs_v3.mp4`, `creatures/colossus_v3_turnaround.png`.
Honest notes: ~10.7k tris (was 8.5k); thin tentacles can look flat at some frames (nearest-bone skinning); the game's Colossus shader hides everything above ~10-17 m world height in the street
scenes, so in those shots only the legs and claws show - the new body reads in the cinematics that reveal it.
