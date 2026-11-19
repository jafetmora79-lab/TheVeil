"""Reference render of the ORIGINAL in-game Sarah head (read-only import of THE_VEIL_ASSETS_V2 CHR_Sarah.glb, nothing is saved back).
Same ortho views as the grey head sheets, scaled so the head height matches (ortho = 1.89 x head height).
   blender -b -P render_original_sarah_head.py -- <out.png>"""
import bpy, sys, os, math
import numpy as np
from mathutils import Vector

out = sys.argv[sys.argv.index("--") + 1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.abspath("THE_VEIL_ASSETS_V2/06_Characters/Civilians/CHR_Sarah.glb"))
dg = bpy.context.evaluated_depsgraph_get()
keep = {}
for o in list(bpy.data.objects):
    if o.type == 'MESH' and o.name in ("Sarah_Head", "Sarah_Hair", "Sarah_HairExtras"):
        keep[o.name] = o
    elif o.type == 'MESH':
        o.hide_render = True
head = keep["Sarah_Head"]
e = head.evaluated_get(dg)
me = e.to_mesh()
pts = np.array([(e.matrix_world @ v.co)[:] for v in me.vertices])
lo, hi = pts.min(0), pts.max(0)
print("ORIG head bbox", lo.round(3), hi.round(3))
hh = hi[2] - lo[2]
ctr = Vector(((lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2 + .02, lo[2] + hh * .52))
w = bpy.data.worlds.new("w")
w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (.42, .43, .47, 1)
w.node_tree.nodes["Background"].inputs[1].default_value = 1.0
bpy.context.scene.world = w
for rot, en in (((55, 0, -30), 2.2), ((60, 0, 150), .7)):
    bpy.ops.object.light_add(type='SUN')
    L = bpy.context.object
    L.rotation_euler = [math.radians(x) for x in rot]
    L.data.energy = en
sc = bpy.context.scene
sc.render.engine = 'BLENDER_EEVEE'
sc.view_settings.view_transform = 'Standard'
sc.render.resolution_x = sc.render.resolution_y = 520
cam = bpy.data.cameras.new("c")
cam.type = 'ORTHO'
cam.ortho_scale = 1.89 * hh
co = bpy.data.objects.new("c", cam)
sc.collection.objects.link(co)
sc.camera = co
tiles = []
for name, az in (("front", 180), ("three", 218), ("side", 270)):
    t = math.radians(az)
    co.location = (ctr.x + 6 * math.sin(t), ctr.y - 6 * math.cos(t), ctr.z)
    co.rotation_euler = (math.pi / 2, 0, t)
    p = os.path.abspath(out.replace(".png", "_" + name + ".png"))
    sc.render.filepath = p
    bpy.ops.render.render(write_still=True)
    tiles.append(p)
ims = [bpy.data.images.load(p) for p in tiles]
arr = np.concatenate([np.array(i.pixels[:], dtype=np.float32).reshape(520, 520, 4) for i in ims], axis=1)
sh = bpy.data.images.new("s", 520 * len(ims), 520)
sh.pixels[:] = arr.reshape(-1)
sh.filepath_raw = os.path.abspath(out)
sh.file_format = 'PNG'
sh.save()
for p in tiles:
    os.remove(p)
