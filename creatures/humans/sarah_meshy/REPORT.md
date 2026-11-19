# Sarah (Meshy "mara_vale_lowpoly") - import validation and PSX texture test

Branch `art/sarah-meshy-integration`. Nothing in the game, the playable Sarah or any story scene is touched.
The untouched Meshy files are in `source/original/` (plus the original ZIP). Everything else is a copy.

## Validation (Blender 5.2, `creatures/tools/meshy_validate_render.py`, numbers in `work/validation_report.json`)
- 5,143 triangles, 4,570 vertices (OBJ vertices are not welded; 2,576 after welding at 1e-5). All triangles, no quads or n-gons.
- One mesh (`geometry_0`), one material (`material_0`), one 2048x2048 RGBA diffuse texture. No normal, roughness or other maps in the package.
- UVs: one layer, 0..1, nothing outside the unit square.
- Orientation: arrives lying with the tall axis on Y, standing after a 90 degree turn; the face looks toward the front camera. A-pose.
- Scale: 0.951 m tall (0.482 m wide, 0.167 m deep), origin at the middle of the body. Needs about x1.75 to match Sarah's ~1.66 m and the feet moved to the origin.
- Welded, the mesh is ONE connected body (head, hair, jacket, tee, jeans, boots all fused) plus one tiny 12-vertex piece. There are
  no separate clothing or hair meshes: a rig means weight painting on a single mesh. Hands have separate fingers; the fingers are thin.
- Non-manifold edges: 3,415 as imported (seams of the unwelded vertices), 3 after welding.

## PSX test (texture copies in `work/textures/`, renders in `work/renders/`)
- `material_0_diffuse_256_nearest.png` and `..._512_nearest.png`: the original reduced with nearest-neighbour resampling.
- Same mesh and same cameras / lights. Original: linear filtering, smooth shading, a little gloss. PSX: nearest filtering, flat shading, no gloss.
- Sheets: `work/comparison_body.png`, `work/comparison_head.png`, `work/comparison_vs_reference.png` (against the supplied reference sheet).

## Phase 4: game-ready prototype (approved; 512 px texture chosen)
Built by `creatures/tools/build_sarah_meshy_proto.py` (Blender source: `game_ready/sarah_meshy_proto.blend`).
- Export: `game/prototypes/sarah_meshy/CHR_Sarah_Meshy_Proto.glb` (1.17 MB). Used by nothing in the game; the playable Sarah and every scene are untouched.
- Mesh: vertices welded (4,570 -> 2,576; 5,143 triangles kept, no decimation), upright, 1.659 m tall, feet on the ground, facing +Y in Blender = -Z in Godot (the existing Sarah's convention), flat normals.
- Material: one, the 512 x 512 nearest-neighbour texture. Godot ignores glTF sampler filters, so `game/prototypes/sarah_meshy/sarah_meshy_proto.gd` sets nearest filtering, no gloss.
- Rig: 21 bones with Godot humanoid names (Hips, Spine, Chest, Neck, Head, Left/Right Shoulder, UpperArm, LowerArm, Hand, UpperLeg, LowerLeg, Foot, Toes).
  Blender automatic weights worked first time: every vertex weighted.
- Temporary animations: `idle` (2 s, loops), `walk` (1 s, loops), `head_turn` (3 s, one shot). Godot strips the "-loop" suffix from the Blender action names and sets looping.
- Godot 4.3 (Compatibility): `game/tests/sarah_meshy_proto_test.gd` (headless) passes: skeleton, 20 named bones, skinned mesh, size, faces -Z, nearest filter, animations present and really moving the bones.
  Screenshots: `work/godot_animation_check.png`. Blender deformation tests: `work/deformation_tests.png`.

### Rigging / deformation notes
- Shoulders raised to 55 degrees: a slight pinch at the jacket's shoulder seam; fine for a game, would need weight cleanup for close-ups.
- Elbows (95 degrees), knees (80 degrees), hips (85 degrees, a sitting pose) bend cleanly; the jeans do not collapse at the crotch.
- Hands are one rigid bone each: the thin separate fingers do not curl.
- The jacket, tee, jeans, hair and boots are one fused mesh, so there is no cloth or hair motion and no way to swap clothes without cutting the mesh.
- The rest pose is a wide A-pose; the temporary walk keeps the arms in that pose with a small swing. A real walk set would be better retargeted.
- In Godot the shading looks soft even though flat normals are exported; forcing the faceted PSX look needs a shader or a re-export, not done yet.
- The auto weights were not hand-edited: any final weight painting is still to do.

## Animation and hand study (from the reference game's extracted clips; reference only, nothing copied)
The reference game's characters use a Mixamo humanoid rig with finger chains, and a small library of long looping clips chosen per personality
(bored / normal / swaying / injured / drunk idles; confident / female / old man / sass / injured / drunk walks), with the mouth on its own animator.
Measured from the clip data (angles in degrees, largest swing from the first pose):
- Idles are 6-10 s and very quiet: hips/spine 0-1, head 1-7, arm 1-11, fingers almost still. "Injured" is the exception: head 28, fingers 28-68 (a clutching hand).
- Walks are 1.4-1.6 s at 30 fps: hips 16-23, spine 5-10, head 5-8, thigh 36-52, knee 53-62, foot 21, arm 31-49, forearm 29-37, wrist 23-50;
  of the fingers only the thumb and index move (about 15); the other fingers stay in a fixed relaxed curl.
Applied to our Sarah (own values, own clips):
- 30 finger bones added (thumb metacarpal/proximal/distal, index/middle/ring/little proximal/intermediate/distal, both hands), placed from the real
  finger geometry of the Meshy hands; 51 bones in all, every vertex weighted by Blender's automatic weights.
- Hand poses as one-frame actions: `hand_relaxed`, `hand_open`, `hand_fist`, `hand_grip` (a pistol / flashlight grip), `hand_point`.
- `idle` is now 6 s and quiet, with relaxed fingers drifting slightly; `walk` is 1.5 s with a 36 degree thigh swing, knee up to 55, arm swing 31, forearm 8-30, wrist 18 and thumb/index flicker; `head_turn` is unchanged.
- Images: `work/hand_poses.png` (Blender, both hands, five poses), `work/godot_hand_check.png`, `work/godot_animation_check.png`.
- Still to do: weight cleanup, the idle / walk variants the reference game uses per character (bored, injured, nervous...), and a mouth/face swap for talking.

## Second pass: animation polish, facial expressions, new clips (same branch, nothing integrated)
Build: `creatures/tools/build_sarah_meshy_proto.py` (rig, clips, decals, export). Face pipeline: `meshy_face_capture.py` (Blender: a flat,
unlit front capture of the 512 texture) -> `meshy_face_paint.py` (Python: paints the expression patches into one 256 x 64 atlas) -> the build
script (lays the patches on the face as skinned decal meshes). Godot side: `game/prototypes/sarah_meshy/` (`sarah_face.gd` controller,
`sarah_meshy_proto.gd` loader, `sarah_meshy_proto.json` = walk speed).

### Animation cleanup
- Fingers: fist / grip / point angles reduced so the tips stop short of the palm (`work/hand_poses.png`); weights lightly smoothed over the whole rig.
- Walk: legs rebuilt on planted-foot IK (the stance foot moves at a constant speed, the swing foot lifts and carries). The arm swing, spine, head and 1.5 s
  cycle are kept; the pelvis now twists about the vertical (it used to roll about the front axis by mistake) and bobs vertically (it used to move back and forth).
  Measured in Godot: planted-foot slide at most 3.1 mm per frame (a hitch of one held frame per loop was also removed by starting the keys at frame 0),
  provided the body moves at `walk_speed()` = 0.511 m/s; scale the animation speed for any other speed (speed_scale = speed / 0.511).
- Shoulder / elbow / hip / knee deformation: `work/deformation_tests.png`. Elbows (95), knees (80) and a 85 degree hip bend are clean. At 55 degrees the shoulder
  still pinches a little at the jacket seam (the arms are part of the jacket mesh).
- Idle and head_turn are unchanged.

### Facial expressions: neutral, talking, scared, angry, blinking
Her face has no eyelid or mouth geometry (eyes, brows and lips are painted into the skin texture) and only a few dozen vertices, so blend shapes would only
stretch the paint (an "open mouth" would show no inside). The lightweight alternative is the reference game's approach, texture decals: eight small Face_* meshes
(eyes closed / wide / narrowed, angry brows, four mouth shapes), each a crop of HER OWN face texels with one feature edited, skinned to the Head bone, shown or
hidden by `VeilSarahFace` (expression "neutral" | "scared" | "angry", `talking`, `blink()`, automatic blinks every 2-5 s with the odd double blink).
Neutral is the untouched face. Images: `work/face/face_expressions.png`, `work/face/face_variants_flat.png`.
Not done: raised brows for scared (the left brow is crossed by a hair strand, moving it would drag the strand), per-phoneme lip sync.

### New clips (24 fps, restrained)
`nervous_idle` (6 s loop: small glances both ways, weight shifts, hands low and fidgeting), `injured_idle` (5 s loop: hunched forward, head down, weight on the
right leg, left hand pressed to her left ribs, shallow breathing), `scared_reaction` (1.6 s one shot: the head snaps ~30 degrees in 0.125 s, the body recoils
7 cm back, arms come up with fingers spread, then it settles into a braced hold). Keyframes: `work/anim_keyframes2.png`.

### Godot 4.3 Compatibility validation
- `game/tests/sarah_meshy_face_anim_test.gd` and `sarah_meshy_proto_test.gd` pass (headless): foot slide, clips and their bones, face decals (8, nearest filter, facing the
  front so back-face culling shows them), every expression state, blinking and talking, and the body walking while the face blinks, talks and is scared.
- Body and face do not interfere: the AnimationPlayer drives only the skeleton, the controller only toggles decal visibility.
- Rendering: the previews use the Compatibility renderer, nearest-neighbour filtering, no MSAA, a little mist and the game's film-look shader (vignette, grain, bloom).
- Previews: `work/sarah_meshy_body_preview.gif` (walks, stops, glances, flinches) and `work/sarah_meshy_face_closeup.gif` (blinks, talks, scared, angry).
  Frames from `game/tests/sarah_meshy_preview.gd`.

### Known limits
Weight cleanup is still automatic + a light smooth; the walk's arms are stiff A-pose swings; decal edges are straight (a faint seam is possible under hard light);
fingers still rigid-bone based; she is not wired into any scene (waiting for your approval before the supermarket test scene).

### Correction: arm directions (reported by the user, fixed)
In the second pass every ARM rotation had the wrong sign: the elbows, hands and arm swings bent / swung BACKWARD. Cause: I treated negative X rotation as forward
for the arm bones, but like the legs, positive X swings an arm / bends an elbow forward. I also drove the wrists with a rotation about the front axis (a sideways
wag) instead of flexion, and the walk's arm swing was a quarter cycle out of step with the new IK legs. All arm values were flipped / re-phased and the wrists now flex
forward. Checked three ways: a Blender measurement over every key frame of every clip (`creatures/tools/meshy_arm_check.py`: elbow flexion is now +2..+5 degrees in the
idle, 5..24 in the walk, 31..38 in the nervous idle, 105..110 with the hand at the ribs in the injured idle, 5..55 in the scared reaction, all positive = forward), the
side-view key frames in `work/anim_keyframes3.png`, and a new Godot regression test (`elbows_never_bend_backwards_in_any_clip`, `wrists_stay_within_a_natural_range`).
The injured idle's hand now rests up at the left side of her chest / ribs. The GIF previews were re-rendered with the corrected clips.
