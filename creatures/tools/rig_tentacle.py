"""THE VEIL - a Meshy tentacle rigged to the OLD Mist Tentacle interface (Blender 5.x, headless).
   blender -b -P rig_tentacle.py -- <repo_root> <source_slug> <length_m> <out_name>
Bones Root, T_01..T_10 (a chain up the centre line; the tip bone is T_10, which tentacle_ai.gd measures). Clips: Emerge (rises out of the mist, one shot),
Search (loop: a slow scanning sway), Coil (draws back), Reach (leans out), Strike (winds up, whips forward; the AI measures its contact frame), Retract (sinks into the mist).
The creature stands on z = 0 (the mist surface); Root dips below it in Emerge / Retract (the mist fade shader dithers it away). Forward is +Y in Blender (-Z in Godot)."""
import bpy, bmesh, sys, os, math, json
import numpy as np
from mathutils import Vector, Matrix, Quaternion

root, slug, length, outname = sys.argv[sys.argv.index("--") + 1:][:4]
LEN = float(length)
FPS = 24
N = 10
glb_dir = os.path.join(root, "game/prototypes/monsters_meshy")
work = os.path.join(root, "creatures/monsters", slug)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.join(root, "creatures/monsters/source", slug + ".glb"))
src = [o for o in bpy.context.scene.objects if o.type == 'MESH'][0]
src.parent = None
src.matrix_world = Matrix.Identity(4)
bpy.context.view_layer.update()
me = src.data
co = np.empty(len(me.vertices) * 3)
me.vertices.foreach_get("co", co)
co = co.reshape(-1, 3)
mn, mx = co.min(0), co.max(0)
S = LEN / float((mx - mn)[2])                           # the length is the height of the stalk
co = (co - np.array([(mn[0] + mx[0]) / 2, (mn[1] + mx[1]) / 2, mn[2]])) * S
me.vertices.foreach_set("co", co.reshape(-1))
me.update()
bm = bmesh.new()
bm.from_mesh(me)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
bm.to_mesh(me)
bm.free()
for p in me.polygons:
    p.use_smooth = False
for nd in me.materials[0].node_tree.nodes:
    if nd.type == 'TEX_IMAGE':
        nd.interpolation = "Closest"
src.name = "Tentacle"
V = np.array([v.co[:] for v in me.vertices])
H = float(V[:, 2].max())
zs = np.linspace(0, H, N + 1)
pts = []
for i in range(N + 1):
    m = (V[:, 2] >= zs[i] - 0.5 * H / N) & (V[:, 2] <= zs[i] + 0.5 * H / N)
    pts.append(V[m][:, :2].mean(0).tolist() + [zs[i]] if m.any() else [0, 0, zs[i]])
pts = [Vector(p) for p in pts]
pts[0] = Vector((pts[0].x, pts[0].y, 0.0))
bones = [("Root", Vector((pts[0].x, pts[0].y, 0.0)), Vector((pts[0].x, pts[0].y, 0.05 * H / N)), None)]
for i in range(N):
    bones.append(("T_%02d" % (i + 1), pts[i], pts[i + 1], "T_%02d" % i if i else "Root"))
arm = bpy.data.armatures.new("Tentacle_Rig")
rig = bpy.data.objects.new("Tentacle_Rig", arm)
bpy.context.scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='EDIT')
for n_, h, t, par in bones:
    eb = arm.edit_bones.new(n_)
    eb.head, eb.tail = h, t
for n_, h, t, par in bones:
    if par:
        arm.edit_bones[n_].parent = arm.edit_bones[par]
bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.object.select_all(action='DESELECT')
src.select_set(True)
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.parent_set(type='ARMATURE_AUTO')
unw = [vx.index for vx in me.vertices if not any(g.weight > 1e-4 for g in vx.groups)]
for i in unw:
    zi = min(N - 1, int(V[i][2] / H * N))
    nm = "T_%02d" % (zi + 1)
    (src.vertex_groups.get(nm) or src.vertex_groups.new(name=nm)).add([i], 1.0, 'REPLACE')
bpy.ops.object.select_all(action='DESELECT')
src.select_set(True)
bpy.context.view_layer.objects.active = src
bpy.ops.object.vertex_group_limit_total(group_select_mode='BONE_DEFORM', limit=4)
bpy.ops.object.vertex_group_normalize_all(group_select_mode='BONE_DEFORM', lock_active=False)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='POSE')
for pb in rig.pose.bones:
    pb.rotation_mode = 'QUATERNION'
REST = {b.name: b.matrix_local.to_3x3() for b in rig.data.bones}
NAMES = ["T_%02d" % (i + 1) for i in range(N)]


def key(name, frame, quat=None, loc=None):
    pb = rig.pose.bones[name]
    if quat is not None:
        pb.rotation_quaternion = quat
        pb.keyframe_insert("rotation_quaternion", frame=frame - 1)
    if loc is not None:
        pb.location = loc
        pb.keyframe_insert("location", frame=frame - 1)


def wrot(name, axis, ang):
    W = Matrix.Rotation(ang, 3, Vector(axis))
    M = REST[name]
    return (M.inverted() @ W @ M).to_quaternion()


def wl(name, v):
    """a world-space translation as the bone's local location"""
    return REST[name].inverted() @ Vector(v)


def new_action(nm, length_f):
    for pb in rig.pose.bones:
        pb.rotation_quaternion = Quaternion((1, 0, 0, 0))
        pb.location = (0, 0, 0)
    act = bpy.data.actions.new(nm)
    act.use_fake_user = True
    rig.animation_data_create()
    rig.animation_data.action = act
    bpy.context.scene.frame_start = 0
    bpy.context.scene.frame_end = length_f - 1
    return act


def smooth(u):
    return u * u * (3 - 2 * u)


def bend(f, fwd_total, side_total=0.0, ripple=0.0, ph=0.0, weight=1.0):
    """spread a forward bend (+X rotation tilts it toward +Y) and a sideways bend (about Y) along the chain, heavier toward the tip, plus a travelling ripple"""
    wts = np.array([(i + 1) / N for i in range(N)]) ** 1.2
    wts = wts / wts.sum()
    for i, nm in enumerate(NAMES):
        a = fwd_total * wts[i] + ripple * math.sin(ph - i * 0.6) * weight
        b = side_total * wts[i] + ripple * 0.6 * math.sin(ph * 0.8 - i * 0.5 + 1.0) * weight
        key(nm, f, wrot(nm, (1, 0, 0), a) @ wrot(nm, (0, 1, 0), b))


bpy.context.scene.render.fps = FPS
info = {"kind": "tentacle", "length_m": LEN, "tip_bone": "T_10"}
rad = math.radians
# Emerge: rises out of the mist (Root from -H to 0) while it sways, one shot (2 s)
new_action("Emerge", 49)
for f in range(1, 50):
    u = (f - 1) / 48.0
    key("Root", f, loc=wl("Root", (0, 0, -H * (1 - smooth(u)) * 1.02)))
    bend(f, rad(-18) * (1 - smooth(u)), rad(12) * math.sin(u * 5), rad(5), u * 9, 1 - u * 0.5)
# Search: loops (4 s): a slow scan, the tip feeling the air
new_action("Search", 97)
for f in range(1, 98):
    t = (f - 1) / 96.0
    key("Root", f, loc=(0, 0, 0))
    bend(f, rad(8) + rad(10) * math.sin(2 * math.pi * t), rad(22) * math.sin(2 * math.pi * t + 1.0), rad(5), 2 * math.pi * t * 2)
# Coil: draws back and tightens, ready to strike (1.5 s, holds the last pose)
new_action("Coil", 37)
for f in range(1, 38):
    u = smooth(min((f - 1) / 24.0, 1.0))
    key("Root", f, loc=(0, 0, 0))
    bend(f, rad(-40) * u, rad(8) * u, rad(3) * u, (f - 1) / 6.0, u)
# Reach: leans out toward the target, the tip probing (1.5 s)
new_action("Reach", 37)
for f in range(1, 38):
    u = smooth(min((f - 1) / 20.0, 1.0))
    key("Root", f, loc=(0, 0, 0))
    bend(f, rad(55) * u, 0.0, rad(3), (f - 1) / 5.0, 0.6 * u)
# Strike: a short wind-up back, then a whip forward; the tip leads, snaps at ~60 %, recovers (1 s)
new_action("Strike", 25)
for f in range(1, 26):
    u = (f - 1) / 24.0
    wind = smooth(min(u / 0.3, 1.0)) * (1.0 if u < 0.3 else 0.0)
    whip = 0.0 if u < 0.3 else smooth(min((u - 0.3) / 0.3, 1.0)) * (1.0 - smooth(max((u - 0.62) / 0.38, 0.0)))
    key("Root", f, loc=(0, 0, 0))
    bend(f, rad(-30) * wind + rad(95) * whip, 0.0, rad(4) * whip, u * 14, whip)
# Retract: sinks back into the mist (1.5 s)
new_action("Retract", 37)
for f in range(1, 38):
    u = smooth((f - 1) / 36.0)
    key("Root", f, loc=wl("Root", (0, 0, -H * u * 1.02)))
    bend(f, rad(-25) * u, 0.0, rad(4) * (1 - u), (f - 1) / 5.0, 1 - u)
bpy.ops.object.mode_set(mode='OBJECT')
rig.animation_data.action = bpy.data.actions["Search"]
json.dump(info, open(os.path.join(glb_dir, outname + ".json"), "w"), indent=1)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(work, "tentacle_rig.blend"))
bpy.ops.object.select_all(action='DESELECT')
src.select_set(True)
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
glb = os.path.join(glb_dir, "MON_%s.glb" % outname)
bpy.ops.export_scene.gltf(filepath=glb, export_format='GLB', use_selection=True, export_animations=True, export_animation_mode='ACTIONS',
                          export_skins=True, export_yup=True, export_normals=True, export_apply=False)
# measure: the tip's horizontal reach at the strike contact, and the highest vertex when emerged / retracted
tip = rig.pose.bones["T_10"]
best = 0.0
rig.animation_data.action = bpy.data.actions["Strike"]
for fr in range(0, 25):
    bpy.context.scene.frame_set(fr)
    p = rig.matrix_world @ tip.tail
    best = max(best, math.hypot(p.x, p.y))
print("MEASURE strike tip reach %.2f m of %.2f m length" % (best, LEN))
for clip, frames in (("Emerge", (0, 48)), ("Retract", (0, 36))):
    rig.animation_data.action = bpy.data.actions[clip]
    for fr in frames:
        bpy.context.scene.frame_set(fr)
        ev = src.evaluated_get(bpy.context.evaluated_depsgraph_get())
        m = ev.to_mesh()
        print("MEASURE", clip, "frame", fr, "highest vertex z %.2f" % max(v.co[2] for v in m.vertices))
        ev.to_mesh_clear()
print("GLB", glb)
