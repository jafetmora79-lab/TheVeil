"""Close-up of the head, side + 3/4. blender -b -P head_closeup.py -- <glb> <out.png> [yc zc scale]"""
import bpy, sys, os, math
a = sys.argv[sys.argv.index("--") + 1:]
yc, zc, sc_ = (float(a[2]), float(a[3]), float(a[4])) if len(a) > 4 else (-1.25, .78, .9)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.abspath(a[0]))
for o in list(bpy.data.objects):
    if o.name.startswith("Icosphere"): bpy.data.objects.remove(o)
w = bpy.data.worlds.new("w"); w.use_nodes = True; w.node_tree.nodes["Background"].inputs[0].default_value = (.2, .22, .27, 1); bpy.context.scene.world = w
for rot, e in (((0.9, 0, 0.6), 4.0), ((1.1, 0, 3.6), 1.5)):
    bpy.ops.object.light_add(type='SUN'); L = bpy.context.object; L.rotation_euler = rot; L.data.energy = e
sc = bpy.context.scene; sc.render.engine = 'BLENDER_EEVEE'; sc.render.resolution_x = 600; sc.render.resolution_y = 450
cam = bpy.data.cameras.new("c"); cam.type = 'ORTHO'; cam.ortho_scale = sc_
co = bpy.data.objects.new("c", cam); sc.collection.objects.link(co); sc.camera = co
for i, (loc, rot) in enumerate((((20, yc, zc), (math.pi / 2, 0, math.pi / 2)), ((14, yc - 14, zc + 4), (math.radians(78), 0, math.radians(45))))):
    co.location = loc; co.rotation_euler = rot
    sc.render.filepath = os.path.abspath(a[1].replace(".png", "_%d.png" % i)); bpy.ops.render.render(write_still=True)
