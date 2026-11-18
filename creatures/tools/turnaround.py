"""Turnaround sheet (side / front / 3-4 / head close-up) of a creature GLB.  blender -b -P turnaround.py -- <glb> <out.png> [headx headz scale]"""
import bpy, sys, os, math
from mathutils import Vector
a = sys.argv[sys.argv.index("--") + 1:]
glb, out = a[0], a[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.abspath(glb))
for o in list(bpy.data.objects):
    if o.name.startswith("Icosphere"): bpy.data.objects.remove(o)
ms = [o for o in bpy.data.objects if o.type == 'MESH']
pts = [o.matrix_world @ Vector(c) for o in ms for c in o.bound_box]
lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts))); hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
ctr = (lo + hi) / 2; size = max(hi.x - lo.x, hi.y - lo.y, hi.z - lo.z)
w = bpy.data.worlds.new("w"); w.use_nodes = True; w.node_tree.nodes["Background"].inputs[0].default_value = (.17, .19, .24, 1); bpy.context.scene.world = w
for rot, e in (((0.9, 0, 0.6), 4.0), ((1.1, 0, 3.6), 1.5)):
    bpy.ops.object.light_add(type='SUN'); L = bpy.context.object; L.rotation_euler = rot; L.data.energy = e
sc = bpy.context.scene
sc.render.engine = 'BLENDER_EEVEE'
sc.render.resolution_x = 520; sc.render.resolution_y = 390
views = [("side", (ctr.x + 30, ctr.y, ctr.z), (math.pi / 2, 0, math.pi / 2), size * 1.15),
         ("front", (ctr.x, ctr.y - 30, ctr.z), (math.pi / 2, 0, 0), size * 1.15),
         ("three", (ctr.x + 21, ctr.y - 21, ctr.z + 6), (math.radians(78), 0, math.radians(45)), size * 1.2)]
if len(a) >= 5:
    hx, hz, hs = float(a[2]), float(a[3]), float(a[4])
    views.append(("head", (ctr.x + 21, lo.y + hx + 0 - 21, hz + 4), (math.radians(80), 0, math.radians(45)), hs))
tiles = []
cam = bpy.data.cameras.new("c"); cam.type = 'ORTHO'; co = bpy.data.objects.new("c", cam); sc.collection.objects.link(co); sc.camera = co
for name, loc, rot, scl in views:
    co.location = loc; co.rotation_euler = rot; cam.ortho_scale = scl
    p = os.path.abspath(out.replace(".png", "_" + name + ".png")); sc.render.filepath = p; bpy.ops.render.render(write_still=True); tiles.append(p)
imgs = [bpy.data.images.load(p) for p in tiles]
W, H = 520, 390
sheet = bpy.data.images.new("sheet", W * len(imgs), H)
buf = [0.0] * (W * len(imgs) * H * 4)
for i, im in enumerate(imgs):
    px = list(im.pixels)
    for y in range(H):
        s = y * W * 4; d = (y * W * len(imgs) + i * W) * 4
        buf[d:d + W * 4] = px[s:s + W * 4]
sheet.pixels[:] = buf; sheet.filepath_raw = os.path.abspath(out); sheet.file_format = 'PNG'; sheet.save()
for p in tiles: os.remove(p)
