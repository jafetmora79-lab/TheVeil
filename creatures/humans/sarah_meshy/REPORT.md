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
