"""Close-ups of the decal expressions with the SAME camera and lighting as protagonist_face_shapekeys.py.
   blender -b -P protagonist_decal_closeups.py -- <repo_root> <out_prefix>"""
import bpy, sys, os, math
root = sys.argv[sys.argv.index("--") + 1]
prefix = sys.argv[sys.argv.index("--") + 2]
base = os.path.join(root, "creatures/humans/protagonist")
bpy.ops.wm.open_mainfile(filepath=os.path.join(base, "game_ready/protagonist_meshy.blend"))
rig = bpy.data.objects["Protagonist_Meshy_Rig"]
rig.animation_data.action = None
for pb in rig.pose.bones:
    pb.rotation_euler = (0, 0, 0)
    pb.location = (0, 0, 0)
sc = bpy.context.scene
sc.render.engine = 'BLENDER_EEVEE'
sc.view_settings.view_transform = 'Standard'
w_ = bpy.data.worlds.new("w")
w_.use_nodes = True
w_.node_tree.nodes["Background"].inputs[0].default_value = (0.20, 0.21, 0.24, 1)
sc.world = w_
for rot_, en in (((55, 0, 180 - 25), 3.0), ((70, 0, 140), 1.0)):
    bpy.ops.object.light_add(type='SUN')
    L = bpy.context.object
    L.rotation_euler = [math.radians(x) for x in rot_]
    L.data.energy = en
cam = bpy.data.cameras.new("c")
cam.type = 'ORTHO'
cam.ortho_scale = 0.22
co_ = bpy.data.objects.new("c", cam)
sc.collection.objects.link(co_)
sc.camera = co_
co_.location = (0, 5.0, 1.59)
co_.rotation_euler = (math.pi / 2, 0, math.pi)
sc.render.resolution_x = sc.render.resolution_y = 560
states = {"neutral": [], "blink": ["Face_eyes_closed"], "talk_small": ["Face_mouth_talk_small"], "talk_wide": ["Face_mouth_talk_wide"],
          "scared": ["Face_eyes_wide", "Face_brows_scared", "Face_mouth_scared"]}
for name, on in states.items():
    for o in bpy.data.objects:
        if o.name.startswith("Face_"):
            o.hide_render = o.name not in on
    sc.render.filepath = prefix + "_%s.png" % name
    bpy.ops.render.render(write_still=True)
