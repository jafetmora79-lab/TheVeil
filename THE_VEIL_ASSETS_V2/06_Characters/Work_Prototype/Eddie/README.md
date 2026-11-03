# Eddie — independent character design study

Experimental art proposal for THE VEIL. Eddie is the game-shop clerk, age 34 in the working story, sarcastic and loyal. This is a visual proposal, not new story canon. Based on `docs/THE_VEIL_MASTER_CONTEXT.md` and inspection of existing Pack 06 source and Eddie v3 mesh. The two screenshots mentioned in the request were not attached in this session.

## Design

A compact, approachable adult silhouette: broad cheek planes, shallow short nose, gently raised brow, half-smile, rounded acetate glasses, and a swept chestnut fringe. Teal rolled-sleeve overshirt, cream original cartridge-emblem tee, dark straight jeans, small rust accents and ordinary sneakers. The reassuring expression can become watchful under harsh shop lighting. No existing character design or third-party logo was copied.

Mesh contours were authored directly as vertex loops and local facial/accessory surfaces. No old cast geometry, signed-distance blending, voxel extraction, mannequin builder, or existing textures were reused. Clothing openings, rolled cuffs, cheek widths, hairstyle sweeps and hand contours are specified explicitly. This remains a scripted polygon modelling workflow, rather than a manual Blender sculpt.

## Files

- `Eddie_Prototype.glb`: actual full three-dimensional mesh, embedded atlas, UVs, normals, nearest sampler. 3,209 vertices / 5,974 triangles; one mesh, one material; approximately 138 KiB.
- `Eddie_Atlas.png`: original 256 × 256 atlas; deliberate pixel marks, seams, graphic and palette tiles; no noise or photographic material.
- `Eddie_Editable.obj` and `.mtl`: editable named surface components with UVs; import into Blender at scale 1. OBJ is Y-up, so choose Y as up and Z as forward in an importer that offers those settings.
- `build_eddie.py`: complete reproducible source. Requires Python 3, NumPy and Pillow. Run `python build_eddie.py` in this folder. It recreates the GLB, OBJ, MTL, atlas, report and a single inspection sheet.
- `validate_eddie.py`: independent binary/accessor/texture/geometry checks.
- `inspection.png`: front, three-quarter and profile mesh inspection, not a substitute for the GLB. A simple software preview; it is not a Godot lighting test.
- `preview.html`: separate orbit viewer using the same model-viewer component as the existing gallery. Serve this directory with `python -m http.server 8000`, then open `http://localhost:8000/preview.html`. Requires internet for the viewer component.

## View without changing the live gallery

Download `Eddie_Prototype.glb` from this branch. Open https://jafetmora79-lab.github.io/TheVeil/ and click **Open local GLB**, then select the downloaded file. Texture is embedded; no external texture requests are needed. The gallery source, hosting settings and development branch have not been edited.

## Godot 4 handoff and limitations

Metres, Y up, +Z character-facing direction; feet at Y = 0.012 m, height 1.699 m. Identity node transforms. Rotate the character's parent 180 degrees around Y if your controller expects -Z forward. Nonmetallic, rough material; no extensions required. Embedded image and UVs survive transport as one GLB. Override texture filtering to Nearest on the Godot material if the importer does not preserve the glTF sampler. Double-sided material accommodates intentionally thin collars, pockets and graphic surfaces.

**Godot import was NOT executed:** no Godot executable is available in this environment. Blender is also unavailable; no `.blend` file is claimed. Structural checks are not evidence of an engine import. Drag the GLB into a Godot 4 test project, open its imported scene, and verify scale, nearest filtering, normals and appearance in the intended renderer before integration.

Unrigged and unanimated. No skeleton, skin weights, facial morphs, collision or gameplay integration. The mesh is a static design study with independent surfaces at garment seams, eyes, fingers and hair. It is not a single watertight deformation-ready character; a rigging pass should weld or weight suitable intersections, refine joint loops and test shoulder/hand deformation. Some planar clothing details intentionally use two-sided geometry. No claim of final artistic approval or production integration is made.

All additions are confined to `06_Characters/Work_Prototype/Eddie/` on `work/character-redesign`. No merges or production gallery changes.
