"""THE VEIL - the Hound (the Meshy hound), properly animated (Blender 5.x, headless). Replaces the generic hound rig of rig_monster.py.
Four legs of two bones each, posed by analytic two-bone IK in the side plane (foot targets), so a foot is planted while it is on the ground:
Walk = trot (diagonal pairs), Run = gallop (hind pair, then fore pair). Bones: Body (root), Neck, Head, Tail1, Tail2, Leg<n>_<L|R>_Up/_Lo.
   blender -b -P rig_hound.py -- <repo_root> [measure]
Source creatures/monsters/source/hound.glb -> game/prototypes/monsters_meshy/MON_hound.glb (+ hound.json). The model faces +Y in Blender (-Z in Godot);
MON_hound.tscn turns it half a turn so the scene faces +Z like the old CRT_Hound. Clips (same names as the old Hound):
Idle, Walk, Run, Alert, Attack_Bite, Hit_React, Death.  `measure` prints ground penetration per clip and the number of out-of-reach IK targets."""
import bpy, bmesh, sys, os, math, json
import numpy as np
from mathutils import Vector, Matrix, Quaternion

args = sys.argv[sys.argv.index("--") + 1:]
root = args[0]
measure = "measure" in args
SIZE = 2.0
FPS = 24
work = os.path.join(root, "creatures/monsters/hound")
glb_dir = os.path.join(root, "game/prototypes/monsters_meshy")
os.makedirs(work, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.join(root, "creatures/monsters/source/hound.glb"))
src = [o for o in bpy.context.scene.objects if o.type == 'MESH'][0]
src.parent = None
src.matrix_world = Matrix.Identity(4)
bpy.context.view_layer.update()
me = src.data
co = np.empty(len(me.vertices) * 3)
me.vertices.foreach_get("co", co)
co = co.reshape(-1, 3)
co[:, 0] *= -1                                         # a half turn about Z: the face now looks toward +Y
co[:, 1] *= -1
mn, mx = co.min(0), co.max(0)
S = SIZE / float((mx - mn).max())
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
src.name = "Monster_Body"
V = np.array([v.co[:] for v in me.vertices])
H = float(V[:, 2].max())
ymax, ymin = float(V[:, 1].max()), float(V[:, 1].min())
print("HOUND size", (V.max(0) - V.min(0)).round(2), "H", round(H, 3), "verts", len(V))

# ------------------------------------------------------------------ landmarks
low = V[V[:, 2] < 0.12 * H]
cl = []
for p in low[:, :2]:
    for c in cl:
        if np.linalg.norm(c[0] - p) < 0.2:
            c[1].append(p)
            break
    else:
        cl.append([p, [p]])
cl.sort(key=lambda c: -len(c[1]))
feet2 = [np.array(c[1]).mean(0) for c in cl[:4]]
assert len(feet2) == 4, "expected four paws"
body_pts = V[V[:, 2] > 0.5 * H]
cy = float(np.mean([f[1] for f in feet2]))
cx = float(np.mean([f[0] for f in feet2]))
LEGS = []
for f in feet2:
    front = f[1] > cy
    side = "L" if f[0] < cx else "R"
    foot = Vector((f[0], f[1], 0.0))
    hz = (0.64 if front else 0.66) * H
    hip = Vector((f[0], f[1] + (-0.05 if front else 0.0), hz))
    knee = (hip + foot) * 0.5 + Vector((0, -0.05 if front else 0.07, 0.03))      # elbow behind, stifle in front (a dog's legs)
    LEGS.append({"front": front, "side": side, "hip": hip, "knee": knee, "foot": foot})
LEGS.sort(key=lambda L: (0 if L["front"] else 1, L["side"]))
for i, L in enumerate(LEGS):
    L["name"] = "Leg%d_%s" % (i, L["side"])

zc = 0.66 * H
head_y = ymax - 0.30
bones = [("Body", Vector((cx, cy, zc)), Vector((cx, cy + 0.25, zc + 0.03)), None),
         ("Neck", Vector((cx, cy + 0.35, zc + 0.04)), Vector((cx, head_y, 0.86 * H)), "Body"),
         ("Head", Vector((cx, head_y, 0.86 * H)), Vector((cx, ymax, 0.66 * H)), "Neck"),
         ("Tail1", Vector((cx, ymin + 0.55, zc)), Vector((cx, ymin + 0.28, zc - 0.06)), "Body"),
         ("Tail2", Vector((cx, ymin + 0.28, zc - 0.06)), Vector((cx, ymin, zc - 0.1)), "Tail1")]
for L in LEGS:
    bones.append((L["name"] + "_Up", L["hip"], L["knee"], "Body"))
    bones.append((L["name"] + "_Lo", L["knee"], L["foot"], L["name"] + "_Up"))

arm_data = bpy.data.armatures.new("Monster_Rig")
rig = bpy.data.objects.new("Monster_Rig", arm_data)
bpy.context.scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='EDIT')
for name, h, t, par in bones:
    eb = arm_data.edit_bones.new(name)
    if (t - h).length < 1e-4:
        t = h + Vector((0, 0, 0.01))
    eb.head, eb.tail = h, t
for name, h, t, par in bones:
    if par:
        arm_data.edit_bones[name].parent = arm_data.edit_bones[par]
bpy.ops.object.mode_set(mode='OBJECT')

# ------------------------------------------------------------------ skin
bpy.ops.object.select_all(action='DESELECT')
src.select_set(True)
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.parent_set(type='ARMATURE_AUTO')
unw = [vx.index for vx in me.vertices if not any(g.weight > 1e-4 for g in vx.groups)]
if unw:
    print("HOUND unweighted", len(unw), "-> nearest bone")
    for i in unw:
        pt = Vector(V[i])
        best, bd = None, 1e9
        for name, h, t, par in bones:
            ab = t - h
            tt = max(0.0, min(1.0, (pt - h).dot(ab) / max(ab.dot(ab), 1e-9)))
            d = (pt - (h + ab * tt)).length
            if d < bd:
                best, bd = name, d
        (src.vertex_groups.get(best) or src.vertex_groups.new(name=best)).add([i], 1.0, 'REPLACE')
bpy.ops.object.select_all(action='DESELECT')
src.select_set(True)
bpy.context.view_layer.objects.active = src
bpy.ops.object.vertex_group_limit_total(group_select_mode='BONE_DEFORM', limit=4)
bpy.ops.object.vertex_group_normalize_all(group_select_mode='BONE_DEFORM', lock_active=False)

# ------------------------------------------------------------------ helpers
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='POSE')
for pb in rig.pose.bones:
    pb.rotation_mode = 'QUATERNION'
REST = {b.name: b.matrix_local.to_3x3() for b in rig.data.bones}
X, Y, Z = (1, 0, 0), (0, 1, 0), (0, 0, 1)


def key(name, frame, quat=None, loc=None):
    pb = rig.pose.bones[name]
    if quat is not None:
        pb.rotation_quaternion = quat
        pb.keyframe_insert("rotation_quaternion", frame=frame - 1)
    if loc is not None:
        pb.location = loc
        pb.keyframe_insert("location", frame=frame - 1)


def wrot(name, axis, ang):
    """a rotation about a WORLD axis, as the bone's own local quaternion"""
    W = Matrix.Rotation(ang, 3, Vector(axis))
    M = REST[name]
    return (M.inverted() @ W @ M).to_quaternion()


def world_loc(name, v):
    return REST[name].inverted() @ Vector(v)


def new_action(nm, length):
    for pb in rig.pose.bones:
        pb.rotation_quaternion = Quaternion((1, 0, 0, 0))
        pb.location = (0, 0, 0)
    act = bpy.data.actions.new(nm)
    act.use_fake_user = True
    rig.animation_data_create()
    rig.animation_data.action = act
    bpy.context.scene.frame_start = 0
    bpy.context.scene.frame_end = length - 1
    return act


CLAMPS = [0]


def leg_ik(L, target, dz_body=0.0):
    """Angles about +X of the Up and Lo bones that put the foot at target (world y, z); the hip rides the body (dz_body).
    Returns (up_delta, lo_local_delta). The knee keeps the side it has in the rest pose."""
    hip = (L["hip"].y, L["hip"].z + dz_body)
    h0, k0, f0 = (L["hip"].y, L["hip"].z), (L["knee"].y, L["knee"].z), (L["foot"].y, L["foot"].z)
    l1 = math.hypot(k0[0] - h0[0], k0[1] - h0[1])
    l2 = math.hypot(f0[0] - k0[0], f0[1] - k0[1])
    th1_rest = math.atan2(k0[1] - h0[1], k0[0] - h0[0])
    th2_rest = math.atan2(f0[1] - k0[1], f0[0] - k0[0])
    tx, tz = target[0] - hip[0], target[1] - hip[1]
    d0 = math.hypot(tx, tz)
    d = min(max(d0, abs(l1 - l2) + 1e-3), l1 + l2 - 1e-3)
    if d0 > l1 + l2 - 1e-3:
        CLAMPS[0] += 1
    base = math.atan2(tz, tx)
    A = math.acos(max(-1.0, min(1.0, (l1 * l1 + d * d - l2 * l2) / (2 * l1 * d))))
    cross_rest = (k0[0] - h0[0]) * (f0[1] - h0[1]) - (k0[1] - h0[1]) * (f0[0] - h0[0])
    th1 = base + (A if cross_rest >= 0 else -A) * -1.0
    kn = (hip[0] + l1 * math.cos(th1), hip[1] + l1 * math.sin(th1))
    cross1 = (kn[0] - hip[0]) * (target[1] - hip[1]) - (kn[1] - hip[1]) * (target[0] - hip[0])
    if cross1 * cross_rest < 0:
        th1 = base + (A if cross_rest >= 0 else -A)
        kn = (hip[0] + l1 * math.cos(th1), hip[1] + l1 * math.sin(th1))
    th2 = math.atan2(target[1] - kn[1], target[0] - kn[0]) if d0 < l1 + l2 - 1e-3 else th1
    up = th1 - th1_rest
    return up, (th2 - th2_rest) - up


def pose_leg(f, L, target, dz=0.0):
    up, lo = leg_ik(L, target, dz)
    key(L["name"] + "_Up", f, wrot(L["name"] + "_Up", X, up))
    key(L["name"] + "_Lo", f, wrot(L["name"] + "_Lo", X, lo))


def smooth(u):
    return u * u * (3 - 2 * u)


bpy.context.scene.render.fps = FPS
info = {"kind": "hound", "size_m": SIZE, "height_m": H, "facing": "-Z in the GLB (the scene turns it to +Z)"}
FOOT_Z = 0.025


def gait(name, T, duty, stride, phases, lift_h, bob, pitch_deg, spine_deg, head_nod, speed_key, body_roll=0.0, crouch=0.0, neck_bias=0.0, head_bias=0.0, neck_gain=0.9, fore_comp=0.0):
    """stride = the foot's travel along the body while planted; the body speed that matches it is stride / (duty * T / FPS)."""
    new_action(name, T + 1)
    info[speed_key] = round(stride / (duty * T / FPS), 3)
    info[name.lower() + "_cycle_s"] = T / FPS
    gal = name == "Run"
    for f in range(1, T + 2):
        ph0 = ((f - 1) % T) / T
        bz = -crouch + bob * math.sin(2 * math.pi * ph0 * (1 if gal else 2) + (0.8 if gal else 0.0))
        pit = math.radians(pitch_deg) * math.sin(2 * math.pi * ph0 + (2.2 if gal else 0.0))
        key("Body", f, wrot("Body", X, -pit) @ wrot("Body", Z, math.radians(2.5) * math.sin(2 * math.pi * ph0)) @ wrot("Body", Y, math.radians(body_roll) * math.sin(2 * math.pi * ph0)),
            loc=world_loc("Body", (0, 0, bz)))
        key("Neck", f, wrot("Neck", X, pit * neck_gain + math.radians(neck_bias) + math.radians(spine_deg) * math.sin(2 * math.pi * ph0 + 1.0)))
        key("Head", f, wrot("Head", X, math.radians(head_bias) + math.radians(head_nod) * math.sin(2 * math.pi * ph0 * (1 if gal else 2) + 0.7)))
        key("Tail1", f, wrot("Tail1", Z, math.radians(16) * math.sin(2 * math.pi * ph0 + 1.0)) @ wrot("Tail1", X, math.radians(8 if gal else 0)))
        key("Tail2", f, wrot("Tail2", Z, math.radians(18) * math.sin(2 * math.pi * ph0 + 1.6)))
        for L in LEGS:
            ph = (ph0 + phases[L["name"]]) % 1.0
            fy0 = L["foot"].y
            if ph < duty:                                # stance: the foot slides back along the body at body speed
                fy, fz = fy0 + stride * (0.5 - ph / duty), FOOT_Z
            else:                                        # swing: back to front, lifted
                u = (ph - duty) / (1 - duty)
                fy, fz = fy0 - stride * 0.5 + stride * smooth(u), FOOT_Z + lift_h * math.sin(math.pi * u) ** 0.8
            comp = 0.0
            if fore_comp and L["front"] and ph < duty * 0.35:             # the shoulder compresses as the forepaw takes the weight
                comp = -fore_comp * math.sin(math.pi * ph / (duty * 0.35))
            pose_leg(f, L, (fy, fz), bz + math.sin(-pit) * (L["hip"].y - cy) + comp)


def lname(front, side):
    return [L["name"] for L in LEGS if L["front"] == front and L["side"] == side][0]


FRONT_L, FRONT_R, HIND_L, HIND_R = lname(True, "L"), lname(True, "R"), lname(False, "L"), lname(False, "R")

def env(t, c, w):
    """a periodic bump of width w centred on c (t in 0..1, wraps)"""
    d = ((t - c + 0.5) % 1.0) - 0.5
    return math.exp(-(d / w) ** 2)


new_action("Idle", 97)
for f in range(1, 98):
    t = (f - 1) / 96.0
    key("Body", f, wrot("Body", X, math.radians(0.8) * math.sin(2 * math.pi * t)), loc=world_loc("Body", (0, 0, 0.006 * math.sin(2 * math.pi * t))))
    key("Neck", f, wrot("Neck", Z, math.radians(7) * math.sin(2 * math.pi * t)) @ wrot("Neck", X, math.radians(3) * math.sin(2 * math.pi * t * 2)))
    key("Head", f, wrot("Head", Z, math.radians(9) * math.sin(2 * math.pi * t * 2 + 0.6)))
    key("Tail1", f, wrot("Tail1", Z, math.radians(12) * math.sin(2 * math.pi * t * 2)))
    key("Tail2", f, wrot("Tail2", Z, math.radians(14) * math.sin(2 * math.pi * t * 2 + 0.8)))
    for L in LEGS:
        pose_leg(f, L, (L["foot"].y, FOOT_Z), 0.006 * math.sin(2 * math.pi * t))

# PATROL: a four-beat walk (hind-left, fore-left, hind-right, fore-right): one paw lands at a time, the head carried low, the shoulders rolling over the planted forepaw.
# The stride is chosen so the body speed stays what it was (0.587 m/s): stride / (duty * cycle seconds).
WALK_DUTY = 0.72
gait("Walk", 30, WALK_DUTY, 0.587 * WALK_DUTY * 30 / FPS, {HIND_L: 0.0, FRONT_L: 0.25, HIND_R: 0.5, FRONT_R: 0.75}, 0.10, 0.010, 1.2, 2.5, 2.0, "walk_speed_mps",
     body_roll=2.5, crouch=0.03, neck_bias=-19.0, head_bias=-6.0)
# CHASE: the head stays aimed (the neck cancels the body's pitch), the shoulders compress as each forepaw lands, the hind legs come forward under the folding spine.
gait("Run", 12, 0.38, 0.62, {HIND_L: 0.0, HIND_R: 0.08, FRONT_R: 0.42, FRONT_L: 0.5}, 0.22, 0.03, 7.0, 4.0, 2.5, "run_speed_mps", body_roll=1.5, crouch=0.055,
     neck_bias=-4.0, neck_gain=1.08, fore_comp=0.03)

# SEARCH: the paws stay planted; three short bursts of sniffing (the nose dips and snuffles), a slow turn of the head between them, a forepaw lifted once,
# the tail drooping and settling last. A 3 s loop (the clip ends exactly where it starts).
new_action("Sniff", 73)
for f in range(1, 74):
    t = (f - 1) / 72.0
    burst = max(env(t, 0.14, 0.07), env(t, 0.47, 0.07), env(t, 0.80, 0.07))
    snuf = math.sin(2 * math.pi * t * 13) * burst
    look = math.sin(2 * math.pi * t) + 0.35 * math.sin(4 * math.pi * t + 0.5)
    sh = math.sin(2 * math.pi * t)
    key("Body", f, wrot("Body", X, math.radians(-3.0 - 1.0 * burst)) @ wrot("Body", Y, math.radians(1.6) * sh), loc=world_loc("Body", (0, 0, -0.04 - 0.008 * burst)))
    key("Neck", f, wrot("Neck", X, math.radians(-30.0 + 4.0 * snuf)) @ wrot("Neck", Z, math.radians(15.0) * look))
    key("Head", f, wrot("Head", X, math.radians(-10.0 + 8.0 * snuf)) @ wrot("Head", Z, math.radians(6.0) * look))
    key("Tail1", f, wrot("Tail1", X, math.radians(-7.0)) @ wrot("Tail1", Z, math.radians(5.0) * math.sin(2 * math.pi * t)))
    key("Tail2", f, wrot("Tail2", Z, math.radians(10.0) * math.sin(2 * math.pi * t + 0.9) * (1.0 - 0.5 * burst)))      # the tip settles last
    for L in LEGS:
        fz = FOOT_Z
        if L["name"] == FRONT_L:
            fz += 0.045 * env(t, 0.62, 0.035)                                          # one forepaw lifts and is set down in the same place
        pose_leg(f, L, (L["foot"].y, fz), -0.04 - 0.008 * burst)

# The held pose of a hound that has noticed something: the chest sunk between the forelegs, the hind paws tucked under the hips, the tail stiff, the head aimed and still.
A_Z = -0.075
A_PITCH = math.radians(-6.0)


def alert_pose(f, t, micro=1.0):
    br = math.sin(2 * math.pi * t)
    key("Body", f, wrot("Body", X, A_PITCH + math.radians(0.35) * br * micro), loc=world_loc("Body", (0, 0, A_Z + 0.003 * br * micro)))
    key("Neck", f, wrot("Neck", X, math.radians(-8.0) + math.radians(0.8) * br * micro))
    key("Head", f, wrot("Head", X, math.radians(2.0)) @ wrot("Head", Z, math.radians(1.1) * math.sin(2 * math.pi * t * 2 + 0.6) * micro))
    key("Tail1", f, wrot("Tail1", X, math.radians(10.0)))
    key("Tail2", f, wrot("Tail2", X, math.radians(4.0)) @ wrot("Tail2", Z, math.radians(0.8) * math.sin(2 * math.pi * t * 3) * micro))
    for L in LEGS:
        pose_leg(f, L, (L["foot"].y + (0.05 if L["front"] else 0.075), FOOT_Z), A_Z + math.sin(A_PITCH) * (L["hip"].y - cy))


new_action("Alert", 49)
for f in range(1, 50):
    alert_pose(f, (f - 1) / 48.0)

# DETECT (one shot, 0.7 s): the sniff stops mid-motion, the head snaps to the target and holds, the chest sinks, the hind paws tuck, the tail stiffens,
# and one last small twitch of the jaw (the head rolls) before the launch. It ends on the Alert pose.
new_action("Detect", 17)
for f in range(1, 18):
    u = (f - 1) / 16.0
    snap = smooth(min(u / 0.18, 1.0))
    sink = smooth(min(max((u - 0.08) / 0.55, 0.0), 1.0))
    tw = math.sin(min(max((u - 0.72) / 0.22, 0.0), 1.0) * math.pi * 3) * (1.0 - smooth(min(max((u - 0.94) / 0.06, 0.0), 1.0)))
    key("Body", f, wrot("Body", X, A_PITCH * sink - math.radians(2.0) * (1 - sink)), loc=world_loc("Body", (0, 0, A_Z * sink - 0.04 * (1 - sink))))
    key("Neck", f, wrot("Neck", X, math.radians(-30.0) * (1 - snap) + math.radians(-8.0) * snap))
    key("Head", f, wrot("Head", X, math.radians(-10.0) * (1 - snap) + math.radians(2.0) * snap) @ wrot("Head", Y, math.radians(7.0) * tw))
    key("Tail1", f, wrot("Tail1", X, math.radians(-7.0) * (1 - sink) + math.radians(10.0) * sink))
    key("Tail2", f, wrot("Tail2", X, math.radians(4.0) * sink))
    for L in LEGS:
        tgt = (L["foot"].y + (0.05 if L["front"] else 0.075) * sink, FOOT_Z)
        pose_leg(f, L, tgt, (A_Z + math.sin(A_PITCH) * (L["hip"].y - cy)) * sink + (-0.04) * (1 - sink))

# BITE: load low (the haunches and chest drop, the head draws back and rolls), push forward off the hind legs, snap at the impact frame (u 0.575, unchanged),
# then the forelegs catch the body and it settles. The head rolls one way into the strike and the other out of it (the jaws cannot open out of step: no jaw bones).
new_action("Attack_Bite", 21)
for f in range(1, 22):
    u = (f - 1) / 20.0
    coil = smooth(min(u / 0.3, 1.0)) * (1.0 if u < 0.3 else 0.0)
    drive = 0.0 if u < 0.3 else smooth(min((u - 0.3) / 0.3, 1.0))
    settle = 0.0 if u < 0.6 else smooth((u - 0.6) / 0.4)
    reach = drive * (1.0 - settle)
    snap = math.sin(min(max((u - 0.45) / 0.25, 0.0), 1.0) * math.pi) * (1.0 - settle)
    dyb, dzb = 0.55 * reach - 0.06 * coil, -0.065 * coil + 0.06 * reach
    key("Body", f, wrot("Body", X, math.radians(12) * coil - math.radians(7) * reach), loc=world_loc("Body", (0, dyb, dzb)))
    key("Neck", f, wrot("Neck", X, math.radians(-10) * coil + math.radians(22) * reach))
    key("Head", f, wrot("Head", X, math.radians(-16) * coil + math.radians(-28) * snap) @ wrot("Head", Y, math.radians(-9) * coil + math.radians(12) * snap))
    key("Tail1", f, wrot("Tail1", X, math.radians(12) * reach))
    for L in LEGS:
        fy = L["foot"].y
        tgt = (fy + 0.42 * reach + 0.06 * coil, FOOT_Z + 0.16 * reach * (1.0 - settle)) if L["front"] else (fy + 0.40 * reach - 0.07 * coil, FOOT_Z)
        pose_leg(f, L, tgt, dzb)

new_action("Hit_React", 13)
for f in range(1, 14):
    u = (f - 1) / 12.0
    sh = math.sin(u * math.pi * 3) * (1 - u)
    key("Body", f, wrot("Body", Z, math.radians(8) * sh) @ wrot("Body", X, math.radians(5) * (1 - u) * math.sin(u * math.pi)), loc=world_loc("Body", (0, -0.1 * math.sin(u * math.pi), -0.05 * math.sin(u * math.pi))))
    key("Neck", f, wrot("Neck", Z, math.radians(-14) * sh))
    key("Head", f, wrot("Head", Z, math.radians(-22) * sh))
    key("Tail1", f, wrot("Tail1", X, math.radians(-20) * math.sin(u * math.pi)))
    for L in LEGS:
        pose_leg(f, L, (L["foot"].y, FOOT_Z), -0.05 * math.sin(u * math.pi))

new_action("Death", 37)
for f in range(1, 38):
    u = (f - 1) / 36.0
    k = smooth(min(u / 0.7, 1.0))
    sag = smooth(min(u / 0.35, 1.0))
    key("Body", f, wrot("Body", Y, math.radians(84) * k) @ wrot("Body", X, math.radians(4) * sag), loc=world_loc("Body", (0, 0, -(zc - 0.29) * k)))
    key("Neck", f, wrot("Neck", Z, math.radians(-30) * k) @ wrot("Neck", X, math.radians(20) * k))
    key("Head", f, wrot("Head", X, math.radians(12) * k))
    key("Tail1", f, wrot("Tail1", Z, math.radians(25) * k))
    for L in LEGS:
        pose_leg(f, L, (L["foot"].y + (0.12 if L["front"] else -0.1) * k, 0.34 * k + FOOT_Z), -0.1 * sag)

bpy.ops.object.mode_set(mode='OBJECT')

if measure:
    print("MEASURE IK out-of-reach targets:", CLAMPS[0])
    for clip in ("Idle", "Walk", "Run", "Alert", "Sniff", "Detect", "Attack_Bite", "Hit_React", "Death"):
        act = bpy.data.actions[clip]
        rig.animation_data.action = act
        lowest = 0.0
        for fr in range(int(act.frame_range[0]), int(act.frame_range[1]) + 1):
            bpy.context.scene.frame_set(fr)
            ev = src.evaluated_get(bpy.context.evaluated_depsgraph_get())
            mesh = ev.to_mesh()
            lowest = min(lowest, min(v.co[2] for v in mesh.vertices))
            ev.to_mesh_clear()
        print("MEASURE", clip, "lowest vertex z %.3f" % lowest)

rig.animation_data.action = bpy.data.actions["Idle"]
json.dump(info, open(os.path.join(glb_dir, "hound.json"), "w"), indent=1)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(work, "hound_rig.blend"))
bpy.ops.object.select_all(action='DESELECT')
src.select_set(True)
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
glb = os.path.join(glb_dir, "MON_hound.glb")
bpy.ops.export_scene.gltf(filepath=glb, export_format='GLB', use_selection=True, export_animations=True, export_animation_mode='ACTIONS',
                          export_skins=True, export_yup=True, export_normals=True, export_apply=False)
print("GLB", glb, os.path.getsize(glb))
