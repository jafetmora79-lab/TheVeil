# Grey lines around the protagonist's eyes: diagnostic (nothing changed permanently)

Same camera, same lighting, Godot 4.3 Compatibility. Scripts: `game/tests/protagonist_eye_diag.gd` (the tests), `protagonist_eye_diag2.gd` (fix proposal), `creatures/tools/protagonist_eye_normals_proposal.py`.
Pictures: `eye_diag_grid.png` (diagnosis), `eye_fix_proposal_grid.png` (proposal).

| Test | Grey lines? |
|---|---|
| 1 original eye texture, unshaded, default filtering with mipmaps | no |
| 2 same, NEAREST, no mipmaps | no (identical to 1: filtering and mipmaps are not the cause) |
| 3 current Godot material + lighting | yes |
| 3b original (uncleaned) texture + lighting | yes (so the cleanup never touched the cause) |
| 4 geometry only, eye texture removed, lit | the eye area shows a bumpy ring of facets of different brightness |
| 4b geometry only, unshaded | flat colour, nothing |
| 5 original model (no expression work at all), lit | yes (it was always there) |
| 5b original model, unshaded | no |

## Cause: lighting on rough, flat-shaded geometry around the eyes (not the texture)
- Gone whenever the lighting is off (tests 1, 2, 4b, 5b): so it is NOT gray pixels in the texture, NOT filtering / mipmaps, NOT atlas or UV bleeding, and NOT depth fighting (unshaded depth is identical and shows nothing).
- Present in the original model too (test 5): not caused by the face-texture work.
- The face is flat shaded. Around each eye the 92 triangles face anywhere from 0 to 88 degrees away from straight ahead (mean 42), because the eye cluster vertices sit at uneven depths (5.6 to 7.1 cm): a shallow bumpy dimple. Each facet is lit differently, so the white of the eye, multiplied by those shadings, turns into the grey / blue-grey outlines (the ambient light is bluish).
- Layering: over the eyes a ray meets 2 to 4 front-facing skin surfaces (median gap 7 mm; 14 of 270 sample points are under 1 mm). So there is stacked, overlapping eye geometry, but it is hidden by the nearest surface and not what draws the lines.
- Bonus finding: in the ORIGINAL model unshaded (5b) the lower edge of the brows shows vertical stripes. That is a UV boundary problem of the original brow triangles; the face-texture UVs (front projection) already avoid it.

## Smallest fix proposed (not applied)
Give the loops of the ~470 face triangles around the eyes a smooth, face-aligned normal (custom normals, fading out to the normal flat shading). No vertex moves, no texture change, no new geometry; the rest of the face stays faceted (PSX look). Test: grey lines gone under two different lights (`eye_fix_proposal_grid.png`). Also revert the eye smoothing I did on the textures (it was not needed).
