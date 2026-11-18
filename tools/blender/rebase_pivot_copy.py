"""THE VEIL - move a static prop's origin to the centre of its base. Writes a COPY; never overwrites the source.

    blender -b --python tools/blender/rebase_pivot_copy.py -- <in.glb> <out.glb>

Refuses to run when: out == in, the file has an armature (rigged assets are repaired by hand), or it has more than one
root mesh object (do those manually). Keeps materials / UVs; exports GLB with +Y up. NOT RUN in the cloud session that
created it: verify on one prop (compare tools/blender/inspect_asset.py before and after) before using it on a batch.
"""
import os
import sys
import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
if len(argv) != 2:
    sys.exit("usage: blender -b --python rebase_pivot_copy.py -- <in.glb> <out.glb>")
src, dst = (os.path.abspath(p) for p in argv)
if src == dst:
    sys.exit("refusing to overwrite the source asset")

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
if any(o.type == "ARMATURE" for o in bpy.context.scene.objects):
    sys.exit("rigged asset: repair by hand, not with this script")
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH" and "-convcolonly" not in o.name]
roots = [o for o in meshes if o.parent is None or o.parent.type == "EMPTY"]
if len(roots) != 1:
    sys.exit("expected exactly one root mesh, found %d: %s" % (len(roots), [o.name for o in roots]))

lo = Vector((1e9,) * 3)
hi = Vector((-1e9,) * 3)
for o in meshes:
    for c in o.bound_box:
        p = o.matrix_world @ Vector(c)
        lo = Vector((min(lo[i], p[i]) for i in range(3)))
        hi = Vector((max(hi[i], p[i]) for i in range(3)))
base_centre = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
bpy.context.scene.cursor.location = base_centre
bpy.ops.object.select_all(action="DESELECT")
for o in bpy.context.scene.objects:           # visual meshes and the -convcolonly collision hull move together
    if o.type == "MESH":
        o.select_set(True)
bpy.context.view_layer.objects.active = roots[0]
bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", export_yup=True, export_apply=False)
print("wrote", dst, "origin moved to base centre", tuple(round(v, 3) for v in base_centre))
