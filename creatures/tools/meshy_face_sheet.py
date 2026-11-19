"""Close-up renders of Sarah's expressions from the built Blender file (the decals toggled on and off).
   blender -b -P meshy_face_sheet.py -- <repo_root>"""
import bpy, math, os, sys
from mathutils import Vector
root = sys.argv[sys.argv.index("--") + 1]
base = os.path.join(root, "creatures/humans/sarah_meshy")
bpy.ops.wm.open_mainfile(filepath=os.path.join(base, "game_ready/sarah_meshy_proto.blend"))
sc = bpy.context.scene
w = bpy.data.worlds.new("w"); w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (.2, .21, .24, 1); sc.world = w
for rot, en in (((50, 0, -35), 3.0), ((70, 0, 140), 1.0), ((100, 0, 200), 0.8)):
    bpy.ops.object.light_add(type='SUN'); L = bpy.context.object
    L.rotation_euler = [math.radians(x) for x in rot]; L.data.energy = en
sc.render.engine = 'BLENDER_EEVEE'; sc.view_settings.view_transform = 'Standard'
sc.render.resolution_x = sc.render.resolution_y = 460
cam = bpy.data.cameras.new("c"); cam.type = 'ORTHO'; cam.ortho_scale = 0.27
co = bpy.data.objects.new("c", cam); sc.collection.objects.link(co); sc.camera = co
rig = bpy.data.objects["Sarah_Meshy_Rig"]; rig.animation_data.action = None
decals = {o.name[5:]: o for o in bpy.data.objects if o.name.startswith("Face_")}
EXPR = {"neutral": [], "blink": ["eyes_closed"], "talk_small": ["mouth_talk_small"], "talk_wide": ["mouth_talk_wide"],
        "scared": ["eyes_wide", "mouth_scared"], "angry": ["eyes_narrow", "brows_angry", "mouth_angry"]}
out = os.path.join(base, "work/face/expr")
os.makedirs(out, exist_ok=True)
for name, on in EXPR.items():
    for k, o in decals.items():
        o.hide_render = k not in on
    for az, tag in ((180, "front"), (215, "three")):
        t = math.radians(az)
        ctr = Vector((0, 0, 1.52))
        co.location = (ctr.x + 8 * math.sin(t), ctr.y - 8 * math.cos(t), ctr.z)
        co.rotation_euler = (math.pi / 2, 0, t)
        sc.render.filepath = os.path.join(out, "%s_%s.png" % (name, tag))
        bpy.ops.render.render(write_still=True)
