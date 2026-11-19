"""Textured review of head v5 (head + hair cap + ponytail + body neck/shoulders in grey).
   blender -b head_v5.blend -P head_v5_textured_views.py -- <tex.png> <out.png>"""
import bpy, sys, os, math
import numpy as np
from mathutils import Vector
a = sys.argv[sys.argv.index("--") + 1:]
tex, out = os.path.abspath(a[0]), a[1]
img = bpy.data.images.load(tex)
mat = bpy.data.materials.new("face")
mat.use_nodes = True
nt = mat.node_tree
for n in list(nt.nodes):
    nt.nodes.remove(n)
t = nt.nodes.new("ShaderNodeTexImage"); t.image = img; t.interpolation = 'Closest'
e = nt.nodes.new("ShaderNodeEmission"); e.inputs[1].default_value = 1.0
o = nt.nodes.new("ShaderNodeOutputMaterial")
nt.links.new(t.outputs[0], e.inputs[0]); nt.links.new(e.outputs[0], o.inputs[0])
grey = bpy.data.materials.new("grey"); grey.use_nodes = True
grey.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (.3, .3, .34, 1)
for ob in bpy.data.objects:
    if ob.type != 'MESH':
        continue
    ob.data.materials.clear()
    ob.data.materials.append(mat if ob.name in ("Sarah_Head", "Sarah_HairCap") else grey)
path = os.path.abspath("creatures/humans/sarah/CHR_Sarah_v3.blend")
with bpy.data.libraries.load(path, link=False) as (src, dst):
    dst.objects = ["Sarah_Body"]
import bmesh
for ob in dst.objects:
    bpy.context.scene.collection.objects.link(ob)
    ob.parent = None
    for md in list(ob.modifiers):
        ob.modifiers.remove(md)
    ob.data.materials.clear(); ob.data.materials.append(grey)
    b = bmesh.new(); b.from_mesh(ob.data)
    bmesh.ops.delete(b, geom=[f for f in b.faces if max(v.co.z for v in f.verts) < 1.12], context='FACES')
    b.to_mesh(ob.data); b.free()
w = bpy.data.worlds.new("w"); w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (.18, .19, .22, 1); bpy.context.scene.world = w
sc = bpy.context.scene
sc.render.engine = 'BLENDER_EEVEE'; sc.view_settings.view_transform = 'Standard'
sc.render.resolution_x = sc.render.resolution_y = 520
cam = bpy.data.cameras.new("c"); cam.type = 'ORTHO'; cam.ortho_scale = .42
co = bpy.data.objects.new("c", cam); sc.collection.objects.link(co); sc.camera = co
ctr = Vector((0, -.02, 1.52)); tiles = []
for name, az in (("front", 0), ("three", 38), ("side", 90), ("back", 180)):
    tt = math.radians(az)
    co.location = (ctr.x + 6 * math.sin(tt), ctr.y - 6 * math.cos(tt), ctr.z); co.rotation_euler = (math.pi / 2, 0, tt)
    p = os.path.abspath(out.replace(".png", "_" + name + ".png")); sc.render.filepath = p
    bpy.ops.render.render(write_still=True); tiles.append(p)
ims = [bpy.data.images.load(p) for p in tiles]
arr = np.concatenate([np.array(i.pixels[:], dtype=np.float32).reshape(520, 520, 4) for i in ims], axis=1)
sh = bpy.data.images.new("s", 520 * len(ims), 520); sh.pixels[:] = arr.reshape(-1)
sh.filepath_raw = os.path.abspath(out); sh.file_format = 'PNG'; sh.save()
for p in tiles:
    os.remove(p)
