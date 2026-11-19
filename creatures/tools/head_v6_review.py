"""Review render of the painted head (keeps the head/cap/ponytail materials, adds grey body neck/shoulders, same four cameras/lights as the grey views).
   blender -b head_v6.blend -P head_v6_review.py -- <out.png>"""
import bpy, sys, os, math, bmesh
import numpy as np
from mathutils import Vector

out = sys.argv[sys.argv.index("--") + 1]
grey = bpy.data.materials.new("grey")
grey.use_nodes = True
grey.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (.27, .29, .36, 1)
grey.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 1.0
path = os.path.abspath("creatures/humans/sarah/CHR_Sarah_v3.blend")
with bpy.data.libraries.load(path, link=False) as (src, dst):
    dst.objects = ["Sarah_Body"]
for ob in dst.objects:
    bpy.context.scene.collection.objects.link(ob)
    ob.parent = None
    for md in list(ob.modifiers):
        ob.modifiers.remove(md)
    ob.data.materials.clear()
    ob.data.materials.append(grey)
    b = bmesh.new()
    b.from_mesh(ob.data)
    bmesh.ops.delete(b, geom=[f for f in b.faces if max(v.co.z for v in f.verts) < 1.12], context='FACES')
    b.to_mesh(ob.data)
    b.free()
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
cam.ortho_scale = .42
co = bpy.data.objects.new("c", cam)
sc.collection.objects.link(co)
sc.camera = co
ctr = Vector((0, -.02, 1.52))
tiles = []
for name, az in (("front", 0), ("three", 38), ("side", 90), ("back", 180)):
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
