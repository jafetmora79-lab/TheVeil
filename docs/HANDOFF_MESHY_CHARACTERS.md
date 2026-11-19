# THE VEIL - Meshy characters: handoff (read this first)

Written so another Claude Code session can continue this work exactly the way it has been done. **Branches (after the 2026-11-19 clean-up): `art/npc-meshy-trial-eddie-clerk` holds ALL of this work (it contains the older `art/sarah-meshy-integration`, `art/protagonist-face-geometry` and `art/npc-meshy-rigs`, which were removed because contained; their tip commits are in `docs/DELETED_BRANCHES.md`), and `playtest/meshy-trial` is the lean zip-able copy.** Everything here is committed and pushed to
`https://github.com/jafetmora79-lab/TheVeil` on the branches listed below. The branches are linear: each contains the one before it, so
**`art/npc-meshy-rigs` has everything.** No PR has been opened for any of them and none must be until the user approves.

## Where things are
- Working checkout used so far: `C:\Users\Themo\Documents\TheVeil-meshy` (a git worktree of the repo, remote `origin` = the GitHub repo above).
- Branches (tips at the time of writing): `art/sarah-meshy-integration` (Sarah + protagonist rig) -> `art/protagonist-face-geometry` (protagonist face experiments, test scenes) -> `art/npc-meshy-rigs` (nine rigged NPCs, this document).
- Engine: Godot 4.3, Compatibility renderer, PSX look (nearest-neighbour textures). `C:\Users\Themo\AppData\Local\Temp\Godot_v4.3-stable_win64_console.exe` (console build for headless runs). Blender 5.2: `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe`. Python with Pillow/numpy on the system path.
- Default branch of the game is `claude/practical-cray-hi2y54` (earlier gameplay PRs #6-#8 are merged there).

## Rules the user set (keep following them)
- Do NOT open a PR, and do NOT put any Meshy character in the playable game or change existing game scenes, until the user approves. Everything lives in `game/prototypes/...` and test scenes.
- Never modify the playable Sarah. Do not repaint / recreate faces, clothing or hairstyles. Textures stay as Meshy made them (the user approved nearest-neighbour; the Sarah texture was reduced to 512 px at the user's request, the others keep 2048).
- No unnecessary screenshots; show results as close-ups / sheets / GIFs (send files with SendUserFile; the remote viewer limit is 30 MB).
- Report plainly what is verified and what is not. Commit and push to the cloud regularly (the user wants backups off their PC).
- Ask before anything hard to reverse. Style of work: small steps, a picture for each result, wait for approval at the stated checkpoints.

## The shared rig (all characters)
51 bones with Godot humanoid names: Hips, Spine, Chest, Neck, Head, Left/Right Shoulder, UpperArm, LowerArm, Hand, UpperLeg, LowerLeg, Foot, Toes, and 30 finger bones (Thumb Metacarpal/Proximal/Distal, Index/Middle/Ring/Little Proximal/Intermediate/Distal). No UpperChest.
Bone local axes (Blender): X = world side axis for body bones, X = world front-back axis for Hand and finger bones, Y along the bone. Signs that cost a lot of time once: positive X rotation swings an arm/thigh FORWARD and bends an elbow forward; knee flexion = negative X on LowerLeg; spine/chest +X leans BACK (negative = hunch forward); finger curl uses `FLEX` (Left -1, Right +1). Arms bending backwards was a real bug (fixed, regression-tested).
Clips (Godot strips the "-loop" suffix): `idle`, `walk` (planted-foot two-bone IK, 1.5 s, no foot slide), `nervous_idle`, `injured_idle`, `head_turn`, `scared_reaction` (one shot), one-frame `hand_relaxed/open/fist/grip/point`. The walk's ground speed is in each character's `.json` (`walk_ground_speed`).
Character facing: Blender +Y = Godot -Z (forward). Characters face -Z in Godot. Left side = Blender -X.
Skinning: automatic weights then light smoothing; **every vertex at most 4 bones** (so Godot uses 4-weight skinning); **head, hair and jaw 100% on the Head bone** with a short blend through the neck (otherwise a head turn tears the face); neck/head pivot at the character's real neck centre and the blend follows each character's own neck level (`NECK_Z`, `NECK_FRONT` in `build_npc_meshy.py`).
Loose pieces: bag/strap/belt/holster are weighted rigidly to the nearest trunk bone; hands, boots, sleeves and hair keep normal weights. Detached pieces the automatic weights cannot skin get distance weights.

## Characters and files
| Character | Source | Output | Height (m) |
|---|---|---|---|
| Sarah (Meshy "mara_vale") | `creatures/humans/sarah_meshy/source/original/` | `game/prototypes/sarah_meshy/` | 1.66 |
| Protagonist | `creatures/humans/protagonist/source/protagonist_meshy.glb` | `game/prototypes/protagonist_meshy/CHR_Protagonist_Meshy.glb` | 1.78 |
| 9 NPCs: eddie, plaid_shirt, police_officer, teen_blue_jacket, bearded_man, police_cap, elderly_woman, police_redhair, store_clerk | `creatures/humans/npcs/source/<slug>.glb` | `game/prototypes/npc_meshy/CHR_<slug>_Meshy.glb` | assumed 1.76 / 1.66 / 1.82 / 1.62 / 1.80 / 1.78 / 1.58 / 1.68 / 1.70 |
**NPC heights are ASSUMED**: Meshy normalises every model to the same size (0.95 raw), so the real heights were guessed. They are one parameter per character (`HEIGHTS` in `game/prototypes/npc_meshy/npc_meshy.gd` and the argument to the build script). Ask the user for the real ones and rebuild.

## How to (re)build
- Sarah: `blender -b -P creatures/tools/build_sarah_meshy_proto.py -- <root> [debug]`; also `meshy_face_capture.py`, `meshy_face_paint.py` (decal faces), tests `game/tests/sarah_meshy_*_test.gd`, preview scripts, clerk test scene `game/prototypes/sarah_meshy/ClerkTest.tscn` (Sarah as the supermarket clerk, with `sarah_look_assist.gd`: body turns at 30 degrees, torso twist, head range ~100 degrees; `-- lookcheck` measures it).
- Protagonist: `blender -b -P creatures/tools/build_protagonist_meshy.py -- <root> [debug]`; test `game/tests/protagonist_meshy_test.gd`; test scene `game/prototypes/protagonist_meshy/ProtagonistTest.tscn` (`-- chapter 7`, `-- shots <dir>`, `-- faces <dir>`, `-- facetex` for the face-texture model).
- NPCs: `blender -b -P creatures/tools/build_npc_meshy.py -- <root> <slug> <height_m> [debug]` then `python creatures/tools/npc_pose_sheet.py <root> <slug>`; test `game/tests/npc_meshy_test.gd` (all nine pass); line-up/walking preview `game/tests/npc_meshy_lineup.gd`. After building, run `godot --headless --path . --import` once before running tests (new class names / GLBs).
- Godot test pattern: `godot --headless --path . --fixed-fps 60 --script res://game/tests/<test>.gd` (SceneTree scripts that print `RESULT PASS` and exit non-zero on failure). Scripts referencing the `Game` autoload cannot compile under `--script` (use the shader directly in preview tools).

## Faces (what works and what does not)
- Decal patches (Sarah's approach, `VeilSarahFace`): fine for Sarah, but on the protagonist they read as pasted (flat-shaded squares over a differently faceted surface). Do not refine painted patches further (the user rejected it).
- **Current best approach for the protagonist: a swapped FACE TEXTURE.** The front skin triangles of the face (240 triangles) get a second material with plain front-projection UVs, so the texture is exactly a 1000 px flat face image; expressions are aligned images (made by the user in ChatGPT from `creatures/humans/protagonist/chatgpt_kit/protagonist_face_base_1000.png` + `PROMPT.txt`; returned images in `chatgpt_kit/returned/`). Scripts: `protagonist_face_texture_swap.py` (experiment/renders), `protagonist_face_tex_prepare.py` (colour match, 512 px), `protagonist_face_tex_export.py` (GLB `creatures/humans/protagonist/face_geo/CHR_Protagonist_FaceTex.glb`), controller `game/prototypes/protagonist_meshy/protagonist_face_tex.gd` (`VeilProtagonistFaceTex`: neutral, blink, talk small/wide, scared; auto-blink), adapter `face_tex_adapter.gd`, test `game/tests/protagonist_face_tex_test.gd`. Missing: angry and worried (need more images from the user).
- **Grey lines around the eyes** were diagnosed (`face_geo/EYE_ARTIFACT_DIAGNOSTIC.md`): lighting on rough flat-shaded eye geometry, not the texture. Fixed with smooth custom normals around the eyes (baked into the GLB by the export script). Known leftover: a tiny bright dot on the nose bridge under the flashlight (user said it is fine).
- Geometric experiment (`face_geo/FACE_GEOMETRY_REPORT.md`): a shape-key blink on the existing vertices works; a mouth cannot open without cutting the skin along the mouth line and adding a small cavity (not done, not approved).
- **NPC faces (one six-up sheet per character):** the user cannot make 6 images per NPC, so each NPC gets ONE ChatGPT sheet (1536x1024, 3x2 cells: 1 blink, 2 talk small, 3 talk wide, 4 scared, 5 angry, 6 worried). Kit: `creatures/humans/npcs/chatgpt_kit/` (`<slug>_template.png` = the face repeated 6 times, `PROMPT_SHEET.txt`; the templates come from `creatures/tools/npc_face_capture.py`). Pipeline per NPC, once the user returns the sheet (save it as `chatgpt_kit/returned/<slug>.png`):
  1. `python creatures/tools/npc_face_sheet_slice.py <root> <slug> <sheet>` cuts and aligns the cells (one median placement per sheet; checks `face_tex/alignment.json`),
  2. `python creatures/tools/npc_face_tex_prepare.py <root> <slug>` colour-matches, keeps only what changed (difference matte), finds the face hull and the eye centres, writes `game/prototypes/npc_meshy/face/<slug>/face_*.png`,
  3. `blender -b -P creatures/tools/npc_face_tex_build.py -- <root> <slug>` builds the second face material + eye normals and exports `game/prototypes/npc_meshy/CHR_<slug>_FaceTex.glb`,
  4. controller `game/prototypes/npc_meshy/npc_face_tex.gd` (`VeilNpcFaceTex.instantiate(slug)`: neutral/scared/angry/worried, talking, blink, auto-blink); add the slug to `SLUGS` in `game/tests/npc_face_tex_test.gd`; preview with `game/tests/npc_face_tex_preview.gd -- <out> <slug>...`.
  Done: ALL NINE NPCs have face expressions (neutral, blink, talk small/wide, scared, angry, worried): `creatures/humans/npcs/work/npc_faces_in_godot_all9.png`. Placement of each sheet is measured on the face skin hull (`npc_face_sheet_slice.py`); a fit checked by eye and found wrong can be overridden with `face_tex/placement_override.json` (the teen needs it: scale 1.0, dx 0, dy 0). Expression edits are limited to boxes around the eyes/brows and the mouth, away from the hull edge (an edit near the hair edge showed up as an outline). Known small flaws: a faint tone seam on one cheek of eddie, thin dark lines at the brows of the teen and police_cap, eddie's scared/worried brow is blocky, a few faint lines near the elderly woman's ear. Tested in close-ups only, not yet in the supermarket scene.

## NPC supermarket test scene
`game/prototypes/npc_meshy/NpcSupermarketTest.tscn` (F6, or `-- shots <dir> chapter 7`): all nine NPCs with face-texture expressions stand in the real chapter 7 supermarket (mist, flashlight, film grain), animated by the game's NpcAnimator. Keys: 1-9 pick an NPC, T talk, B blink, S scared (body + face), A angry, W worried, N neutral. Screenshots: `creatures/humans/npcs/work/npcs_supermarket_sheet.png`. Verified in stills only (no walking test in the shop yet).

## Replacing the old characters (branch `art/npc-meshy-trial-eddie-clerk`): the Meshy characters are now the default
- Every NPC in the game is created by `world._spawn_npc(scene, face_tex, parent, pos, yaw, speaker)` (VeilSurvivorBody + NpcAnimator + the old `VeilFace`). A guarded hook in it asks `VeilMeshyNpcs.model_for(speaker)` (`game/npc/meshy_npcs.gd`); if the speaker has a Meshy model it is used (with `VeilMeshyNpcFace`, `game/npc/meshy_npc_face.gd`, answering the old VeilFace calls and mapping the ten old expressions onto neutral/scared/angry/worried; Sarah's decal face and the protagonist's texture face know fewer expressions, the missing ones become neutral).
- **ON by default.** `-- old_npcs` (or env VEIL_OLD_NPCS=1) plays with the old characters. `MAP` (in meshy_npcs.gd) says who plays whom: Protagonist/Trailer_Driver = protagonist, Eddie = eddie, Marcus = bearded_man, Noah = teen_blue_jacket, Ruth = elderly_woman, Sarah = Meshy Sarah, Lena = plaid_shirt, Frank = police_cap, Officer = police_officer, Cashier/Survivor/Civilian_A/LT_* = store_clerk, Civilian_B = police_redhair. **These assignments are my choices (the user did not map them): ask and change MAP if wrong.**
- The protagonist's face-texture model now lives in `game/prototypes/protagonist_meshy/face/` (moved from creatures/.../face_geo so the game is self-contained).
- Checks: `game/prototypes/npc_meshy/MeshyTrialCheck.tscn` (real world, headless; run with and without `-- old_npcs`), and the existing chapter tests run with and without `-- old_npcs` (results recorded in the commit message of the switch-over).
- Still open: Marcus's run / scared-run clips (the NpcAnimator does running procedurally), the survivor body capsule (fixed 1.76 m) against the assumed NPC heights, first-person arms (home_bathroom.gd, unchanged), the real NPC heights, and a look in the actual game flow (only stills and the test runs so far).

## Gameplay-side facts learned earlier (merged to the default branch, for context)
NpcAnimator (`game/npc/npc_animator.gd`) animates NPCs procedurally by bone name (idle, look-at with 0.4/0.6 neck/head split, talk gestures, scared mood); the test scenes replace the world's cashier model with a Meshy character and keep the game's animator. The save file is backed up and restored by the test scenes.

## Pending / ideas (nothing here is approved yet)
1. Real heights for the nine NPCs. 2. Face expressions for the NPCs (and angry/worried for the protagonist). 3. A flag-guarded swap of the Meshy characters into the real NPC pipeline (e.g. chapter6.gd `SARAH_PATH`) - only after approval. 4. Known rig limits: automatic weights are light (a raised-shoulder pinch at some jacket seams), fingers curl as blocks, walk arms are a stiff A-pose, no UpperChest bone, GIFs are large.

## Repository slimming (branch `art/npc-meshy-trial-eddie-clerk` and later)
The working tree was cut from 1.1 GB to about 0.74 GB by removing regenerable files (all still in the git history of the earlier commits, e.g. `git checkout 1722e17 -- <path>`):
- debug renders (`work/rig_debug/`, `work/before_neck_pivot/`) and raw screenshot folders (`work/supermarket|trial|faces|facetex_scene|scene/`): regenerate with `build_*_meshy.py ... debug` and the preview/test-scene scripts (`-- shots <dir>`); the summary sheets and reports were kept;
- the NPC Blender working copies and exported textures (`creatures/humans/npcs/<slug>/game_ready/`) and the protagonist face experiment blends/renders: regenerate the NPC blend with `build_npc_meshy.py -- <root> <slug> <height>` before running `npc_face_capture.py` or `npc_face_tex_build.py` again (Sarah's and the protagonist's `game_ready` blends were kept);
- all GIFs (regenerate with the preview scripts) and `.blend1` backups;
- the plain `CHR_<slug>_Meshy.glb` NPC models: `npc_meshy.gd` (`VeilNpcMeshy`) now loads `CHR_<slug>_FaceTex.glb`, which has the same rig, clips and body.
Kept: every original Meshy source file, all scripts, the final GLBs and face textures, the ChatGPT kit and returned sheets, and the reports/overview sheets. Not touched: the older project content (docs/ builds, audio, art).

## Practical gotchas
- Windows + Git Bash: write multi-line scripts with the Write tool or Python, avoid heredocs with apostrophes; avoid `cd ../..` chains (a wrong `cd` once ran scripts from the wrong folder).
- In the Blender build scripts the variable `base` is overwritten by the finger code: use `BASE_DIR`/`root` for paths later in the script.
- Blender `Bone.select` no longer exists in 5.2; the glTF exporter adds a held first frame unless keys are written at `frame-1` (already handled).
- Godot imports glTF animations with "-loop" stripped and loop set; it ignores glTF sampler filters (the code sets nearest filtering in `psx_look`).
- Browser-based GitHub PR creation needed the user to sign in manually each time (no `gh`); not needed for these branches (no PRs).
