"""THE VEIL - read-only Blender inspector. Imports GLBs and prints what the next repair needs to know.

    blender -b --python tools/blender/inspect_asset.py -- <asset.glb> [<asset2.glb> ...]

For each file: objects, triangles, world-space bounds and origin height (is the origin on the base?), armature bones,
and every action with its frame range and the LOWEST point any bone reaches over the action (feet that float or sink
show up here). Writes nothing. NOT RUN in the cloud session that created it (no Blender there): verify on the desktop
with one known asset before trusting a report.
"""
import sys
import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
if not argv:
    sys.exit("usage: blender -b --python inspect_asset.py -- <asset.glb> ...")


def world_bounds(objs):
    lo, hi = Vector((1e9,) * 3), Vector((-1e9,) * 3)
    for o in objs:
        for corner in o.bound_box:
            p = o.matrix_world @ Vector(corner)
            lo = Vector((min(lo[i], p[i]) for i in range(3)))
            hi = Vector((max(hi[i], p[i]) for i in range(3)))
    return lo, hi


def lowest_bone_z(arm, action, step=2):
    """Lowest world Z of any bone head/tail over the action (Blender Z is up; the glTF importer converts from Y-up)."""
    prev = arm.animation_data.action if arm.animation_data else None
    if arm.animation_data is None:
        arm.animation_data_create()
    arm.animation_data.action = action
    lo = 1e9
    f0, f1 = int(action.frame_range[0]), int(action.frame_range[1])
    for f in range(f0, f1 + 1, step):
        bpy.context.scene.frame_set(f)
        for pb in arm.pose.bones:
            for p in (arm.matrix_world @ pb.head, arm.matrix_world @ pb.tail):
                lo = min(lo, p.z)
    arm.animation_data.action = prev
    return lo


for path in argv:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    arms = [o for o in bpy.context.scene.objects if o.type == "ARMATURE"]
    lo, hi = world_bounds(meshes) if meshes else (Vector(), Vector())
    tris = 0
    for o in meshes:
        o.data.calc_loop_triangles()
        tris += len(o.data.loop_triangles)
    print("=" * 72)
    print(path)
    print("  meshes %d  armatures %d  triangles %d" % (len(meshes), len(arms), tris))
    print("  bounds min (%.3f, %.3f, %.3f)  max (%.3f, %.3f, %.3f)" % (*lo, *hi))
    print("  size   (%.3f, %.3f, %.3f)   (Blender axes: X right, Y forward/back, Z up)" % tuple(hi - lo))
    print("  base of the mesh is %.3f m %s the origin" % (abs(lo.z), "below" if lo.z < 0 else "above"))
    for a in arms:
        print("  armature %s: %d bones" % (a.name, len(a.data.bones)))
    for act in bpy.data.actions:
        line = "  action %-24s frames %d-%d" % (act.name, act.frame_range[0], act.frame_range[1])
        if arms:
            line += "  lowest bone point %.3f m" % lowest_bone_z(arms[0], act)
        print(line)
    for m in bpy.data.materials:
        tex = [n.image.name for n in m.node_tree.nodes if n.type == "TEX_IMAGE" and n.image] if m.use_nodes else []
        print("  material %-28s textures %s" % (m.name, tex or "NONE"))
