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


NBASE, NMID = 3, 4                                       # the chain in three jobs: T_01-03 (load and direction), T_04-07 (the broad bends), T_08-10 (the precise tip)


def seg_bend(f, bf=0.0, mf=0.0, tf=0.0, bs=0.0, ms=0.0, ts=0.0, hook=0.0, ripple=0.0, ph=0.0, tip_ripple=0.0):
    """a forward bend (+X tilts toward +Y) and a sideways bend (about Y) for each of the three segments, spread evenly over its bones; `hook` curls the last
    three bones further forward-up; a small travelling ripple on the middle, a finer one on the tip."""
    for i, nm in enumerate(NAMES):
        if i < NBASE:
            a, b = bf / NBASE, bs / NBASE
            r = 0.0
        elif i < NBASE + NMID:
            a, b = mf / NMID, ms / NMID
            r = ripple
        else:
            n_tip = N - NBASE - NMID
            a, b = (tf + hook) / n_tip, ts / n_tip
            r = tip_ripple
        a += r * math.sin(ph - i * 0.6)
        b += r * 0.6 * math.sin(ph * 0.8 - i * 0.5 + 1.0)
        key(nm, f, wrot(nm, (1, 0, 0), a) @ wrot(nm, (0, 1, 0), b))


def wp(t, pts):
    """smooth, periodic, uneven motion through (time, value) waypoints; equal neighbouring values are the listening pauses"""
    t = t % 1.0
    for i in range(len(pts) - 1):
        t0, v0 = pts[i]
        t1, v1 = pts[i + 1]
        if t0 <= t <= t1:
            return v0 + (v1 - v0) * smooth((t - t0) / (t1 - t0))
    return pts[-1][1]


bpy.context.scene.render.fps = FPS
info = {"kind": "tentacle", "length_m": LEN, "tip_bone": "T_10"}
rad = math.radians
# per size: how it moves. thin: fast narrow feeler movements, long pauses. medium: wider sweeps, a clear whole-chain recoil. large: slow base movement, a deep loaded bend,
# a sudden hooked strike and a heavier recovery.
PROFILE = {"thin": dict(reps=2, side=0.8, tip=1.5, load=0.7, hook=14.0, heavy=0.6, recoil=0.7),
           "medium": dict(reps=1, side=1.0, tip=1.0, load=1.0, hook=24.0, heavy=1.0, recoil=1.2),
           "large": dict(reps=1, side=1.25, tip=0.7, load=1.45, hook=40.0, heavy=1.6, recoil=1.0)}
REACH_K = 0.73
PR = PROFILE["thin" if "thin" in outname else ("large" if "large" in outname else "medium")]
SEARCH_WP = [(0.0, 0.0), (0.16, 1.0), (0.36, 1.0), (0.54, -0.75), (0.74, -0.75), (0.88, 0.35), (1.0, 0.0)]

# Emerge (one shot, 2 s): in stages. The tip appears first and hesitates, listening; then the middle is fed out behind it while the base bends back against the
# opening (the street / doorway edge); the last bend settles after the tip has stopped.
new_action("Emerge", 49)
for f in range(1, 50):
    u = (f - 1) / 48.0
    if u < 0.22:
        rise = 0.16 * smooth(u / 0.22)
    elif u < 0.42:
        rise = 0.16
    else:
        rise = 0.16 + 0.84 * smooth((u - 0.42) / 0.58)
    feed = smooth(min(max((u - 0.42) / 0.58, 0.0), 1.0))
    hes = 1.0 if 0.14 <= u < 0.46 else 0.0
    key("Root", f, loc=wl("Root", (0, 0, -H * (1 - rise) * 1.02)))
    seg_bend(f, bf=rad(-16) * (1 - feed), mf=rad(10) * math.sin(feed * 3.0) , tf=rad(-10) * (1 - feed), bs=rad(5) * math.sin(u * 4), ms=rad(12) * math.sin(u * 5) * feed,
             ts=rad(9) * hes * math.sin(u * 38) * PR["tip"] * (1 - 0.6 * smooth(min(max((u - 0.4) / 0.2, 0.0), 1.0))), ripple=rad(4) * feed, ph=u * 9, tip_ripple=rad(2) * (1 - feed))

# Search (loop, 4 s): uneven arcs with brief listening pauses. The base moves least and slowest, the middle follows, the tip leads and is the most precise; the last bend
# trails the tip, so it settles after the tip stops. In the pauses the tip makes tiny listening motions.
new_action("Search", 97)
for f in range(1, 98):
    t = (f - 1) / 96.0
    tt = t * PR["reps"]
    sw_b = wp(tt - 0.00, SEARCH_WP)
    sw_m = wp(tt - 0.03, SEARCH_WP)
    sw_t = wp(tt - 0.07, SEARCH_WP)
    moving = abs(wp(tt + 0.01, SEARCH_WP) - wp(tt - 0.01, SEARCH_WP)) * 40.0
    pause = max(0.0, 1.0 - moving)
    listen = math.sin(2 * math.pi * t * 9 * PR["reps"]) * pause
    key("Root", f, loc=(0, 0, 0))
    seg_bend(f, bf=rad(6) + rad(2) * sw_b, mf=rad(8) + rad(7) * sw_m, tf=rad(10) + rad(8) * PR["tip"] * sw_t + rad(3) * listen,
             bs=rad(10) * PR["side"] * sw_b, ms=rad(20) * PR["side"] * sw_m, ts=rad(26) * PR["side"] * PR["tip"] * sw_t + rad(4) * listen, ripple=rad(2), ph=2 * math.pi * t * 2, tip_ripple=rad(1.5) * pause)

# Coil (1.5 s, holds the last pose): the tip points at the target first, then the middle settles into a shallow S while the base leans back, loaded.
new_action("Coil", 37)
LOAD_B, LOAD_M, LOAD_T = -28.0 * PR["load"], 18.0 * PR["load"], 35.0
for f in range(1, 38):
    u = (f - 1) / 36.0
    tip_in = smooth(min(u / 0.35, 1.0))
    s2 = smooth(min(max((u - 0.18) / 0.6, 0.0), 1.0))
    key("Root", f, loc=(0, 0, 0))
    seg_bend(f, bf=rad(LOAD_B) * s2, mf=rad(LOAD_M) * s2, tf=rad(LOAD_T) * tip_in, bs=rad(5) * s2, ts=rad(-4) * tip_in, ripple=rad(1.2) * s2, ph=(f - 1) / 5.0, tip_ripple=rad(0.8) * s2)

# Reach (1.5 s): leans out toward the target, the tip probing.
new_action("Reach", 37)
for f in range(1, 38):
    u = smooth(min((f - 1) / 20.0, 1.0))
    key("Root", f, loc=(0, 0, 0))
    seg_bend(f, bf=rad(18) * u, mf=rad(24) * u, tf=rad(14) * u, ripple=rad(2.5), ph=(f - 1) / 5.0, tip_ripple=rad(2) * u * PR["tip"])

# Strike (1 s): starts on the Coil's loaded pose. The base releases first, then the middle, then the tip - fastest, and last - so the hit travels down the limb to the tip
# (the contact is at u ~ 0.55, as before: the AI measures it from this clip), where the last bones hook up. After the impact the tip recoils first, then the middle, and
# the base settles last (a larger tentacle recovers more slowly).
new_action("Strike", 25)
FIN_B, FIN_M, FIN_T = 6.0, 8.0, 10.0
for f in range(1, 26):
    u = (f - 1) / 24.0
    rb = smooth(min(max((u - 0.30) / 0.14, 0.0), 1.0))               # base release 0.30-0.44
    rm = smooth(min(max((u - 0.34) / 0.16, 0.0), 1.0))               # middle release 0.34-0.50
    rt = smooth(min(max((u - 0.40) / 0.15, 0.0), 1.0))               # tip release 0.40-0.55 (the whip)
    ob = smooth(min(max((u - 0.62) / (0.38 * PR["heavy"] + 0.0001), 0.0), 1.0))   # base settles last
    om = smooth(min(max((u - 0.60) / (0.30 * PR["heavy"] + 0.0001), 0.0), 1.0))
    ot = smooth(min(max((u - 0.58) / 0.14, 0.0), 1.0))               # the tip recoils first
    hook_k = smooth(min(max((u - 0.50) / 0.10, 0.0), 1.0)) * (1.0 - ot)
    b = rad(LOAD_B) * (1 - rb) + rad(30.0 * REACH_K) * rb
    b = b * (1 - ob) + rad(FIN_B) * ob
    m = rad(LOAD_M) * (1 - rm) + rad(40.0 * REACH_K) * rm
    m = m * (1 - om) + rad(FIN_M) * om
    t_ = rad(LOAD_T) * (1 - rt) + rad(25.0 * REACH_K) * rt
    t_ = t_ * (1 - ot) + rad(-18.0 * PR["recoil"]) * ot * (1 - 0.0)
    t_ = t_ * (1 - smooth(min(max((u - 0.78) / 0.22, 0.0), 1.0))) + rad(FIN_T) * smooth(min(max((u - 0.78) / 0.22, 0.0), 1.0))
    key("Root", f, loc=(0, 0, 0))
    seg_bend(f, bf=b, mf=m, tf=t_, hook=rad(PR["hook"]) * hook_k, ripple=rad(3) * (rm - om), ph=u * 14, tip_ripple=rad(2) * rt * (1 - ot))

# Retract (1.5 s): the tip pulls back first, then the middle and base fold, then it sinks into the mist.
new_action("Retract", 37)
for f in range(1, 38):
    u = (f - 1) / 36.0
    tipk = smooth(min(u / 0.28, 1.0))
    foldk = smooth(min(max((u - 0.12) / 0.5, 0.0), 1.0))
    sink = smooth(min(max((u - 0.25) / 0.75, 0.0), 1.0))
    key("Root", f, loc=wl("Root", (0, 0, -H * sink * 1.02)))
    seg_bend(f, bf=rad(-14) * foldk, mf=rad(-8) * foldk, tf=rad(-22) * tipk, ripple=rad(4) * (1 - sink), ph=(f - 1) / 5.0, tip_ripple=rad(2.5) * (1 - tipk))
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
