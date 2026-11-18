"""Read-only close-up (front + 3/4) of one GLB. blender -b -P preview_closeup.py -- <glb relative to THE_VEIL_ASSETS_V2> <out.png> [head|full]"""
import bpy, sys, os, math
from mathutils import Vector
glb, out = sys.argv[sys.argv.index("--") + 1], sys.argv[sys.argv.index("--") + 2]
mode = sys.argv[-1] if sys.argv[-1] in ("head", "full") else "full"
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.abspath("THE_VEIL_ASSETS_V2/" + glb))
ms = [o for o in bpy.data.objects if o.type == 'MESH']
pts = [o.matrix_world @ Vector(c) for o in ms for c in o.bound_box]
lo = Vector((min(v.x for v in pts), min(v.y for v in pts), min(v.z for v in pts))); hi = Vector((max(v.x for v in pts), max(v.y for v in pts), max(v.z for v in pts)))
H = hi.z - lo.z; cx = (lo.x + hi.x) / 2
bpy.ops.object.light_add(type='SUN'); bpy.context.object.data.energy = 3.5; bpy.context.object.rotation_euler = (0.8, 0.3, 0.6)
w = bpy.data.worlds.new("w"); w.use_nodes = True; w.node_tree.nodes["Background"].inputs[0].default_value = (0.4, 0.42, 0.5, 1); bpy.context.scene.world = w
cam = bpy.data.cameras.new("c"); cam.type = 'ORTHO'; sc = bpy.context.scene
tz = hi.z - 0.12 * H if mode == "head" else lo.z + H / 2
cam.ortho_scale = H * 0.28 if mode == "head" else H * 1.1
for i, ang in enumerate((0, 35)):
    co = bpy.data.objects.new("c%d" % i, cam); sc.collection.objects.link(co)
    d = 20; a = math.radians(ang)
    co.location = (cx + math.sin(a) * d, (lo.y + hi.y) / 2 - math.cos(a) * d * 1, tz)
    co.rotation_euler = (math.pi / 2, 0, a)
    sc.camera = co; sc.render.resolution_x = 700; sc.render.resolution_y = 700
    sc.render.filepath = os.path.abspath(out.replace(".png", "_%d.png" % i)); bpy.ops.render.render(write_still=True)
