"""Render key frames of the prototype's actions (side + three-quarter) for review. blender -b -P meshy_anim_sheet.py -- <repo_root> <action> <frame,frame,...> <out.png-prefix>"""
import bpy, math, os, sys
from mathutils import Vector
root, action, frames, out = sys.argv[sys.argv.index("--") + 1:][:4]
frames = [int(x) for x in frames.split(",")]
base = os.path.join(root, "creatures/humans/sarah_meshy")
bpy.ops.wm.open_mainfile(filepath=os.path.join(base, "game_ready/sarah_meshy_proto.blend"))
sc = bpy.context.scene
w = bpy.data.worlds.new("w"); w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (.2, .21, .24, 1); sc.world = w
for rot, en in (((50, 0, -35), 3.0), ((70, 0, 140), 1.0), ((100, 0, 200), 0.8)):
    bpy.ops.object.light_add(type='SUN'); L = bpy.context.object
    L.rotation_euler = [math.radians(x) for x in rot]; L.data.energy = en
sc.render.engine = 'BLENDER_EEVEE'; sc.view_settings.view_transform = 'Standard'
sc.render.resolution_x, sc.render.resolution_y = 420, 700
cam = bpy.data.cameras.new("c"); cam.type = 'ORTHO'; cam.ortho_scale = 1.95
co = bpy.data.objects.new("c", cam); sc.collection.objects.link(co); sc.camera = co
rig = bpy.data.objects["Sarah_Meshy_Rig"]
rig.animation_data.action = bpy.data.actions[action]
for az, tag in ((90 + 180, "side"), (35 + 180, "three")):
    t = math.radians(az)
    co.location = (8 * math.sin(t), -8 * math.cos(t), 0.85)
    co.rotation_euler = (math.pi / 2, 0, t)
    for f in frames:
        sc.frame_set(f)
        sc.render.filepath = os.path.join(base, "work/anim", "%s_%s_%s_%03d.png" % (out, action, tag, f))
        os.makedirs(os.path.dirname(sc.render.filepath), exist_ok=True)
        bpy.ops.render.render(write_still=True)
