# Protagonist: geometric facial animation experiment (isolated branch `art/protagonist-face-geometry`)

Nothing here is in the game. The original model, textures and the earlier painted-patch work are untouched; the experiment works on a copy
(`protagonist_face_geo.blend`, `protagonist_face_geo.glb`) using Blender shape keys (they import into Godot 4.3 as blend shapes, checked with
`game/tests/protagonist_face_geo_test.gd`). Script: `creatures/tools/protagonist_face_shapekeys.py`. Topology measurement: `creatures/tools/protagonist_face_topology.py`, picture `face_wireframe.png`.

## What the existing face mesh really is
The whole mesh is 2,655 vertices; the front of the face (forehead to chin) is about 187 vertices and 362 triangles.
| Area | Vertices | What is there |
|---|---|---|
| each eye | 23-24 | an irregular ring of vertices around the eye and about 10 inside it. The eyeball, iris and pupil are texture on flat triangles. There is no eyeball and no lid fold. |
| each brow | 10-20 | the brow is dark texture on skin triangles; some of the right brow's vertices belong to the hair lock in front of it |
| mouth line | 11 | one chain of vertices along the dark mouth line. It is a painted line on one continuous skin surface: no slit, no lips, no inside. |
| chin | 5 | |
Also: the surface is rough. Neighbouring vertices around the eyes differ in depth by up to 14 mm (5.6 to 7.1 cm), and a hair lock hangs 3 cm in front of his right eye.

## Results
- **Neutral**: unchanged.
- **Blink (works, no topology change):** the vertices of the eye cluster collapse onto a lid line; the triangles above and below, whose texture is lid, lash and skin, stretch over the eye, so the eye is genuinely covered by skin and a dark lash line, not a pasted shape. A little of the brow is pulled down with it (looks like a real blink). 76 vertices move. The hair lock over his right eye is excluded.
- **Talking (does not work well with the existing topology):** the lower-lip and chin vertices drop (a jaw), but the mouth line is a painted line on closed skin, so the mouth never opens: the skin between the mouth line and the lower lip only stretches and the chin lengthens. See `close_talk_small.png` / `close_talk_wide.png`.

## Why the mouth cannot open as the mesh is
There is no opening to move. Making one needs two changes to the mesh, which I have NOT made:
1. cut the skin along the existing mouth-line vertex chain (duplicate those vertices so an upper and a lower lip exist, using the vertices already there, no new detail), and
2. add a tiny dark mouth cavity (about 8 triangles) behind the lips, so the gap shows depth and not the inside of the head (the head is hollow and back-faces are culled).
Lip texels at the cut would stretch slightly. The result would be a real opening connected to his own lips, lightweight (one extra tiny mesh, one more shape key).
Eyebrows (not started): the brow texture is carried by existing vertices, so subtle raising or lowering of the brow vertices is expected to work by the same method as the blink; the hair lock on his right brow needs care.

## Waiting for approval
1. Make the mouth cut and the cavity (in this experimental copy only)?
2. Then brows (fear / anger / worry) with the same vertex method?

## ChatGPT expression images (added)
The five returned images (`chatgpt_kit/returned/`, resized to 1000 px) line up with the base face to within 0-2 px (measured), so they can be used directly.
- As decal patches (`meshy_face_paint_chatgpt.py`, `comparison_gpt_patches.png`): the mouths look good, but the decals read as pasted again: they are flat-shaded squares laid over a differently faceted surface, so lit squares show around the patch. This is a limit of the decal method, not of the images.
- **As a swapped face texture (`protagonist_face_texture_swap.py`, `comparison_texture_swap.png`): clearly better.** The 240 front skin triangles of the face get a second material whose UVs are a plain front projection (the texture is exactly the 1000 px face image). Same triangles, same shading, nothing pasted on: the open mouths, closed eyes with lashes and the scared face all sit inside the face. Cost: one extra material (one draw call) and one small texture per expression (a 512 px version is enough).
Next, if approved: combine with the geometric blink and a jaw shape key, build the second material into the GLB, check in Godot 4.3 Compatibility.

## Face texture swap running in Godot 4.3 (Compatibility)
`CHR_Protagonist_FaceTex.glb` (body + rig + a second face material), `game/prototypes/protagonist_meshy/protagonist_face_tex.gd` (swaps the 512 px expression texture: neutral, blink, talk small/wide, scared; auto-blink, talking cycle), `game/tests/protagonist_face_tex_test.gd` (passes), preview `face_texture_in_godot.gif`. Textures colour-matched to the base face (`protagonist_face_tex_prepare.py`). Not wired into any game scene.
Missing: angry, worried (need aligned images), the mouth-interior image is not needed with this method.

## Supermarket test scene with the face-texture model
`ProtagonistTest.tscn -- facetex` (F6 in the editor with the argument, or the screenshots `-- shots <dir> chapter 7 facetex` / `-- faces <dir> chapter 7 facetex`): the real chapter 7 supermarket with mist, flashlight and film grain, driven by the game's NpcAnimator; the face-texture controller answers the world's face calls through `face_tex_adapter.gd` (angry maps to neutral for now). Sheets: `work/protagonist_facetex_scene_sheet.png`, `work/protagonist_facetex_faces_strip.png`.
Observation: under the flashlight a tiny bright dot shows on the bridge of the nose between the eyes in every expression (the eye-normal smoothing reaches the bridge, so one facet faces the light head-on). Candidate fix: shrink the smoothing on the inner side of the eyes.
