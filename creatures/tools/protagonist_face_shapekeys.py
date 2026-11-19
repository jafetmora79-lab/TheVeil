"""EXPERIMENT (not in the game): geometric facial shape keys on the protagonist, using only his existing vertices.
   blink  - the eye cluster collapses to the lid line: the lid / lash texels of the ring vertices stretch over the eye
   talk_* - the lower lip and chin vertices drop (a jaw), nothing is cut or added
Writes face_geo/protagonist_face_geo.blend and close-up renders with one camera and one lighting setup.
   blender -b -P protagonist_face_shapekeys.py -- <repo_root>"""
import bpy, sys, os, json, math
import numpy as np
from mathutils import Vector

root = sys.argv[sys.argv.index("--") + 1]
base = os.path.join(root, "creatures/humans/protagonist")
out = os.path.join(base, "face_geo")
bpy.ops.wm.open_mainfile(filepath=os.path.join(base, "game_ready/protagonist_meshy.blend"))
for o in list(bpy.data.objects):
    if o.name.startswith("Face_"):
        bpy.data.objects.remove(o, do_unlink=True)
body = bpy.data.objects["Protagonist_Meshy_Body"]
me = body.data
cap = json.load(open(os.path.join(base, "work/face/face_capture.json")))
RES, CX, CZ, SIZE = cap["res"], cap["cx"], cap["cz"], cap["size"]
M = SIZE / RES                                          # metres per flat pixel


def px(p):
    return ((CX - p[0]) / M + RES / 2, RES / 2 - (p[2] - CZ) / M)


def smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


V = np.array([v.co[:] for v in me.vertices])
P = np.array([px(v) for v in V])
Y = V[:, 1]
body.shape_key_add(name="Basis", from_mix=False)

# ---------------------------------------------------------------- blink
EYES = {"L": (355, 435), "R": (637, 432)}
RX, RY = 92, 44
blink = body.shape_key_add(name="blink", from_mix=False)
moved = 0
for side, (cx, cy) in EYES.items():
    lid_y = cy + 12                                     # the closed lid line, a little below the eye centre
    for i in range(len(V)):
        if Y[i] < 0.0 or Y[i] > 0.09:                   # front of the head only; the hair lock hanging over his right eye (y > 9 cm) stays
            continue
        d = math.hypot((P[i][0] - cx) / RX, (P[i][1] - cy) / RY)
        w = 1.0 - smooth((d - 1.0) / 0.9)
        if w <= 0.0:
            continue
        ny = lid_y + (P[i][1] - lid_y) * (1.0 - w)       # toward the lid line
        blink.data[i].co.z = V[i][2] - (ny - P[i][1]) * M
        blink.data[i].co.y = V[i][1] + 0.0015 * w       # the lid sits slightly proud of the eyeball area
        moved += 1
print("BLINK vertices moved", moved)

# ---------------------------------------------------------------- talking (vertex-only jaw, to see what the existing topology gives)
MOUTH_Y = 712
for name, drop_mm in (("talk_small", 8.0), ("talk_wide", 16.0)):
    sk = body.shape_key_add(name=name, from_mix=False)
    n = 0
    for i in range(len(V)):
        if Y[i] < 0.0 or Y[i] > 0.09:
            continue
        py_, px_ = P[i][1], P[i][0]
        wy = smooth((py_ - (MOUTH_Y + 8)) / 55.0) * (1.0 - smooth((py_ - 860) / 60.0))
        wx = 1.0 - smooth((abs(px_ - 495) - 150) / 150.0)
        w = wy * wx
        if w <= 0.0:
            continue
        sk.data[i].co.z = V[i][2] - drop_mm / 1000.0 * w
        sk.data[i].co.y = V[i][1] - 0.25 * drop_mm / 1000.0 * w
        n += 1
    print(name, "vertices moved", n)

# ---------------------------------------------------------------- close-up renders: one camera, one lighting
rig = bpy.data.objects.get("Protagonist_Meshy_Rig")
if rig and rig.animation_data:
    rig.animation_data.action = None
for pb in (rig.pose.bones if rig else []):
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
co_.location = (0, 5.0, CZ - 0.01)
co_.rotation_euler = (math.pi / 2, 0, math.pi)
sc.render.resolution_x = sc.render.resolution_y = 560
os.makedirs(out, exist_ok=True)
for name, vals in (("neutral", {}), ("blink", {"blink": 1.0}), ("talk_small", {"talk_small": 1.0}), ("talk_wide", {"talk_wide": 1.0})):
    for sk in body.data.shape_keys.key_blocks:
        if sk.name != "Basis":
            sk.value = vals.get(sk.name, 0.0)
    sc.render.filepath = os.path.join(out, "close_%s.png" % name)
    bpy.ops.render.render(write_still=True)
for sk in body.data.shape_keys.key_blocks:
    if sk.name != "Basis":
        sk.value = 0.0
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, "protagonist_face_geo.blend"))
print("DONE")

# ---- export for a Godot check (blend shapes survive?)
bpy.ops.object.select_all(action='DESELECT')
body.select_set(True)
if rig:
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
bpy.ops.export_scene.gltf(filepath=os.path.join(out, "protagonist_face_geo.glb"), export_format='GLB', use_selection=True, export_animations=False,
                          export_skins=True, export_yup=True, export_morph=True, export_apply=False)
print("GLB EXPORTED")
