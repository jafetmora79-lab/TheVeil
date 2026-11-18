"""Front / side / 3-4 / back views of the visible meshes of the open .blend. blender -b file.blend -P render_blend_views.py -- out.png [name-substring-to-keep ...]"""
import bpy, sys, math, os
from mathutils import Vector
a = sys.argv[sys.argv.index("--") + 1:]
out = a[0]; keep = a[1:]
for o in list(bpy.data.objects):
    if o.type == 'CAMERA' or o.type == 'LIGHT': bpy.data.objects.remove(o)
    elif keep and o.type == 'MESH':
        o.hide_render = not any(k in o.name for k in keep); o.hide_viewport = o.hide_render
for o in bpy.data.objects:
    if o.type == 'MESH':
        for m in o.modifiers:
            if m.type == 'SUBSURF': m.show_render = False; m.show_viewport = False
for o in bpy.data.objects:
    o.visible_camera = True; o.display_type = "TEXTURED" if o.type == "MESH" else o.display_type
ms = [o for o in bpy.data.objects if o.type == 'MESH' and not o.hide_render]
pts = [o.matrix_world @ Vector(c) for o in ms for c in o.bound_box]
lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts))); hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
ctr = (lo + hi) / 2; H = hi.z - lo.z
print("DBG meshes", [o.name for o in ms], "lo", tuple(lo), "hi", tuple(hi))
w = bpy.data.worlds.new("w"); w.use_nodes = True; w.node_tree.nodes["Background"].inputs[0].default_value = (.22, .24, .3, 1); bpy.context.scene.world = w
for rot, e in (((0.9, 0, 0.6), 3.5), ((1.1, 0, 3.7), 1.2)):
    bpy.ops.object.light_add(type='SUN'); L = bpy.context.object; L.rotation_euler = rot; L.data.energy = e
sc = bpy.context.scene; sc.render.engine = 'BLENDER_EEVEE'; sc.render.resolution_x = 360; sc.render.resolution_y = 540
cam = bpy.data.cameras.new("c"); cam.type = 'ORTHO'; cam.ortho_scale = H * 1.12
co = bpy.data.objects.new("c", cam); sc.collection.objects.link(co); sc.camera = co
tiles = []
for name, az in (("front", 0), ("three", 40), ("side", 90), ("back", 180)):
    t = math.radians(az)
    co.location = (ctr.x + 20 * math.sin(t), ctr.y - 20 * math.cos(t), ctr.z); co.rotation_euler = (math.pi / 2, 0, t)
    p = out.replace(".png", "_" + name + ".png"); sc.render.filepath = os.path.abspath(p); bpy.ops.render.render(write_still=True); tiles.append(os.path.abspath(p))
import numpy as np
ims = [bpy.data.images.load(p) for p in tiles]
W, Hh = 360, 540
arr = np.concatenate([np.array(i.pixels[:], dtype=np.float32).reshape(Hh, W, 4) for i in ims], axis=1)
sheet = bpy.data.images.new("s", W * len(ims), Hh); sheet.pixels[:] = arr.reshape(-1); sheet.filepath_raw = os.path.abspath(out); sheet.file_format = 'PNG'; sheet.save()
for p in tiles: os.remove(p)
