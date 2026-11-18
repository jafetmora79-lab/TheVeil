"""Apply a hand/AI-painted face atlas (painted on UV_TEMPLATE v2) to the Sarah PS2 head. blender -b phase2.blend -P apply_painted_face.py -- <painted image> <out.blend> <out.glb> [size]
The head model, UVs and rig are unchanged: only the Sarah_Face material's image is replaced (nearest filtering)."""
import bpy, sys, os
a = sys.argv[sys.argv.index("--") + 1:]
src, out_blend, out_glb = os.path.abspath(a[0]), a[1], a[2]
size = int(a[3]) if len(a) > 3 else 512
img = bpy.data.images.load(src)
print("LOADED", img.name, tuple(img.size))
img.alpha_mode = "NONE"
img.file_format = "PNG"
img.scale(size, size)
# re-create it as a fresh generated image so it is packed/exported as a lossless PNG (a loaded .webp keeps its webp source format)
import numpy as _np
_px = _np.array(img.pixels[:], dtype=_np.float32)
img2 = bpy.data.images.new("T_Sarah_Face_Painted", size, size, alpha=False)
img2.pixels[:] = _px
img2.pack()
bpy.data.images.remove(img)
img = img2
mat = bpy.data.materials["Sarah_Face"]
node = next(n for n in mat.node_tree.nodes if n.type == 'TEX_IMAGE')
node.image = img
node.interpolation = 'Closest'
# the painted atlas already contains the hair on the head: drop the old flat hair-cap polygons (slot 0), keep the ponytail strands
import bmesh
hair = bpy.data.objects["Sarah_Hair"]
bmh = bmesh.new()
bmh.from_mesh(hair.data)
bmesh.ops.delete(bmh, geom=[f for f in bmh.faces if f.material_index == 0], context='FACES')       # the whole old hair cap goes: the hair is painted on the head
bmesh.ops.delete(bmh, geom=[v for v in bmh.verts if not v.link_faces], context='VERTS')
bmh.to_mesh(hair.data)
bmh.free()
# crown: the atlas has no hair on the top island, so the upward-facing head faces use the hair strand material
head = bpy.data.objects["Sarah_Head"]
head.data.materials.append(bpy.data.materials["Sarah_HairStrands"])
for poly in head.data.polygons:
    if poly.normal.z > .45:
        poly.material_index = 1
# hands / neck skin: the average of the painted cheek so the body matches the face
import numpy as np
px = np.array(img.pixels[:], dtype=np.float32).reshape(size, size, 4)
cheek = px[int(.40 * size):int(.48 * size), int(.20 * size):int(.27 * size), :3].reshape(-1, 3).mean(axis=0)
skin_img = bpy.data.images["T_Sarah_Skin"]
w, h = skin_img.size
arr = np.zeros((h, w, 4), dtype=np.float32)
arr[..., :3] = cheek * (.97 + .06 * np.random.default_rng(3).random((h, w, 1)))
arr[..., 3] = 1
skin_img.pixels[:] = arr.reshape(-1)
skin_img.pack()
print("SKIN tone", tuple(round(float(c), 3) for c in cheek))
# the untouched original head copy lives in the phase2 blend; it must not ship in the exported GLB (it z-fights with the simplified head)
if "Sarah_Head_ORIGINAL" in bpy.data.objects:
    bpy.data.objects.remove(bpy.data.objects["Sarah_Head_ORIGINAL"])
bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(out_blend))
bpy.ops.export_scene.gltf(filepath=os.path.abspath(out_glb), export_format="GLB", export_animations=False, export_skins=True, export_yup=True, export_apply=False)
print("APPLIED", size)
