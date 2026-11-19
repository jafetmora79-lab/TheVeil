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
