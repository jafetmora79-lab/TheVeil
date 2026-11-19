"""Neutral grey review of a head (no textures): front, three-quarter, side, with Sarah's current v3 body neck/shoulders appended for the neck transition.
   blender -b head.blend -P grey_head_views.py -- <out.png> [with_body 0/1]"""
import bpy, sys, os, math
import numpy as np
from mathutils import Vector

a = sys.argv[sys.argv.index("--") + 1:]
out = a[0]
with_body = (a[1] == "1") if len(a) > 1 else True
head = next(o for o in bpy.data.objects if o.name.startswith("Sarah_Head"))
for m in list(bpy.data.materials):
    bpy.data.materials.remove(m)
grey = bpy.data.materials.new("grey")
grey.use_nodes = True
grey.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (.62, .62, .62, 1)
grey.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 1.0
head.data.materials.clear()
head.data.materials.append(grey)
for _o in list(bpy.data.objects):
    if _o is head or _o.type != 'MESH':
        continue
    if _o.name.startswith("Sarah_Hair"):
        _o.data.materials.clear()
        _o.data.materials.append(grey)
        continue
    if _o.name.startswith("Sarah_Body") or _o.name.startswith("Skin_Body"):
        _o.data.materials.clear()
        _o.data.materials.append(grey)
        for _m in list(_o.modifiers):
            _o.modifiers.remove(_m)
        _o.parent = None
        import bmesh as _bm
        _b = _bm.new()
        _b.from_mesh(_o.data)
        _bm.ops.delete(_b, geom=[f for f in _b.faces if max(v.co.z for v in f.verts) < 1.12], context='FACES')
        _b.to_mesh(_o.data)
        _b.free()
    else:
        bpy.data.objects.remove(_o)
for _m in list(head.modifiers):
    head.modifiers.remove(_m)
head.parent = None
if with_body:
    path = os.path.abspath("creatures/humans/sarah/CHR_Sarah_v3.blend")
    with bpy.data.libraries.load(path, link=False) as (src, dst):
        dst.objects = ["Sarah_Body"]
    for ob in dst.objects:
        bpy.context.scene.collection.objects.link(ob)
        ob.data.materials.clear()
        ob.data.materials.append(grey)
        for md in list(ob.modifiers):
            ob.modifiers.remove(md)
        ob.parent = None
        # keep only the upper body (z > 1.1) for a clean neck/shoulder view
        import bmesh
        bmx = bmesh.new()
        bmx.from_mesh(ob.data)
        bmesh.ops.delete(bmx, geom=[f for f in bmx.faces if max(v.co.z for v in f.verts) < 1.12], context='FACES')
        bmx.to_mesh(ob.data)
        bmx.free()
w = bpy.data.worlds.new("w")
w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (.42, .43, .47, 1)
w.node_tree.nodes["Background"].inputs[1].default_value = 1.0
bpy.context.scene.world = w
bpy.ops.object.light_add(type='SUN')
L = bpy.context.object
L.rotation_euler = (math.radians(55), 0, math.radians(-30))
L.data.energy = 2.2
bpy.ops.object.light_add(type='SUN')
L2 = bpy.context.object
L2.rotation_euler = (math.radians(60), 0, math.radians(150))
L2.data.energy = .7
sc = bpy.context.scene
sc.render.engine = 'BLENDER_EEVEE'
sc.view_settings.view_transform = 'Standard'
sc.render.resolution_x, sc.render.resolution_y = 520, 520
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
