"""Close views of the head and the upper body of the open .blend. blender -b file.blend -P head_torso_views.py -- out.png"""
import bpy, math, os, sys
import numpy as np
from mathutils import Vector
out = sys.argv[sys.argv.index("--") + 1]
for o in list(bpy.data.objects):
    if o.type in ('CAMERA', 'LIGHT'): bpy.data.objects.remove(o)
w = bpy.data.worlds.new("w"); w.use_nodes = True; w.node_tree.nodes["Background"].inputs[0].default_value = (.22, .24, .3, 1); bpy.context.scene.world = w
for rot, e in (((0.9, 0, 0.6), 2.6), ((1.1, 0, 3.7), .9)):
    bpy.ops.object.light_add(type='SUN'); L = bpy.context.object; L.rotation_euler = rot; L.data.energy = e
sc = bpy.context.scene; sc.render.engine = 'BLENDER_EEVEE'; sc.render.resolution_x = 480; sc.render.resolution_y = 480
cam = bpy.data.cameras.new("c"); cam.type = 'ORTHO'
co = bpy.data.objects.new("c", cam); sc.collection.objects.link(co); sc.camera = co
tiles = []
for name, ctr, scl, az in (("head_front", (0, -.03, 1.56), .26, 0), ("head_34", (0, -.03, 1.56), .26, 40), ("torso", (0, 0, 1.2), .95, 25), ("legs", (0, 0, .5), 1.1, 25)):
    t = math.radians(az)
    co.location = (ctr[0] + 6 * math.sin(t), ctr[1] - 6 * math.cos(t), ctr[2]); co.rotation_euler = (math.pi / 2, 0, t); cam.ortho_scale = scl
    p = os.path.abspath(out.replace(".png", "_" + name + ".png")); sc.render.filepath = p; bpy.ops.render.render(write_still=True); tiles.append(p)
ims = [bpy.data.images.load(p) for p in tiles]
arr = np.concatenate([np.array(i.pixels[:], dtype=np.float32).reshape(480, 480, 4) for i in ims], axis=1)
sh = bpy.data.images.new("s", 480 * len(ims), 480); sh.pixels[:] = arr.reshape(-1); sh.filepath_raw = os.path.abspath(out); sh.file_format = 'PNG'; sh.save()
for p in tiles: os.remove(p)
