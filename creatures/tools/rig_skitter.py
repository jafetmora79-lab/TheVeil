"""THE VEIL - the Skitter (the Meshy spider), properly animated (Blender 5.x, headless). Replaces the generic spider rig for the Skitter:
joints are measured from each leg's own geometry, legs are posed by inverse kinematics (foot targets) so a foot is planted while it is on the ground,
the gait is an alternating tetrapod (the way a spider walks), and the head has its own bone (it scans, nods, sniffs, bites).
   blender -b -P rig_skitter.py -- <repo_root> [preview]
Source creatures/monsters/source/spider.glb -> game/prototypes/monsters_meshy/MON_skitter.glb (+ skitter.json). Same interface as the old Skitter:
faces +Z in Godot, bones Body, Head, Leg<n>_<L|R>_Up/_Lo/_Foot, clips Idle_Twitch, Crawl, Scuttle_Fast, Alert, Attack_Lunge, Hit_React, Death."""
import bpy, bmesh, sys, os, math, json
import numpy as np
from mathutils import Vector, Matrix, Quaternion

args = sys.argv[sys.argv.index("--") + 1:]
root = args[0]
preview = "preview" in args
SIZE = 1.9
FPS = 24
work = os.path.join(root, "creatures/monsters/spider")
glb_dir = os.path.join(root, "game/prototypes/monsters_meshy")
os.makedirs(work, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.join(root, "creatures/monsters/source/spider.glb"))
src = [o for o in bpy.context.scene.objects if o.type == 'MESH'][0]
src.parent = None
src.matrix_world = Matrix.Identity(4)
bpy.context.view_layer.update()
me = src.data
co = np.empty(len(me.vertices) * 3)
me.vertices.foreach_get("co", co)
co = co.reshape(-1, 3)
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
FW = Vector((0, -1, 0))                               # forward is -Y here (the glTF keeps +Z in Godot)
print("SKITTER size", (V.max(0) - V.min(0)).round(2), "H", round(H, 3), "verts", len(V))


def kmeans(P, k, iters=25):
    idx = [int(np.argmax(P[:, 0]))]
    for _ in range(k - 1):
        d = np.min([np.linalg.norm(P - P[i], axis=1) for i in idx], axis=0)
        idx.append(int(np.argmax(d)))
    C = P[idx].copy()
    for _ in range(iters):
        lab = np.argmin(np.linalg.norm(P[:, None, :] - C[None], axis=2), axis=1)
        for j in range(k):
            if (lab == j).any():
                C[j] = P[lab == j].mean(0)
    return C


# ------------------------------------------------------------------ landmarks, measured from the legs themselves
low = V[V[:, 2] < 0.2]
lab = -np.ones(len(low), int)
ncl = 0
for i in range(len(low)):                              # the claw tips: connected groups of low vertices (the Meshy spider has six legs on the ground)
    if lab[i] >= 0:
        continue
    st = [i]
    lab[i] = ncl
    while st:
        a_ = st.pop()
        idx = np.where((lab < 0) & (np.linalg.norm(low[:, :2] - low[a_, :2], axis=1) < 0.10))[0]
        lab[idx] = ncl
        st += list(idx)
    ncl += 1
feet2 = np.array([low[lab == k][:, :2].mean(0) for k in range(ncl) if (lab == k).sum() >= 10])
print("FEET", len(feet2))
bodyp = V[V[:, 2] > 0.35 * H]
C = np.array([bodyp[:, 0].mean(), bodyp[:, 1].mean(), bodyp[:, 2].mean()])
RB = 0.19 * SIZE                                       # the body's half width, roughly
legs = []
for f2 in feet2:
    tip = np.array([f2[0], f2[1], 0.0])
    d = tip[:2] - C[:2]
    d /= max(np.linalg.norm(d), 1e-6)
    hip_est = np.array([C[0] + d[0] * RB, C[1] + d[1] * RB, 0.8 * H])
    legs.append({"tip": tip, "hip_est": hip_est, "d": d})


def seg_t_dist(P, a, b):
    ab = b - a
    t = np.clip(((P - a) @ ab) / max(float(ab @ ab), 1e-9), 0, 1)
    return t, np.linalg.norm(P - (a + t[:, None] * ab), axis=1)


def xy_seg(P, a, b):                                   # distance in the ground plane to the line from the body to the claw tip
    t, d = seg_t_dist(P[:, :2], a[:2], b[:2])
    return t, d


TD = [xy_seg(V, np.array([C[0] + L["d"][0] * 0.8 * RB, C[1] + L["d"][1] * 0.8 * RB, 0.0]), L["tip"]) for L in legs]
dist = np.stack([t[1] for t in TD], axis=1)
which = np.argmin(dist, axis=1)
dmin = dist[np.arange(len(V)), which]
radial = np.linalg.norm(V[:, :2] - C[:2], axis=1)
is_leg = (dmin < 0.14) & (radial > 0.8 * RB)
for i, L in enumerate(legs):
    m = is_leg & (which == i)
    P = V[m]
    t = TD[i][0][m]
    L["n"] = int(m.sum())
    if len(P) < 20:
        L["hip"], L["knee"], L["ankle"] = L["hip_est"], (L["hip_est"] + L["tip"]) / 2 + np.array([0, 0, 0.2]), L["hip_est"] * 0.3 + L["tip"] * 0.7
        continue
    L["hip"] = P[t < 0.12].mean(0) if (t < 0.12).any() else L["hip_est"]
    sk_ = P[(t > 0.38) & (t < 0.52)]
    L["knee"] = sk_.mean(0) if len(sk_) else (L["hip"] + L["tip"]) / 2 + np.array([0, 0, 0.15])
    sl = P[(t > 0.78) & (t < 0.9)]
    L["ankle"] = sl.mean(0) if len(sl) else (L["knee"] + L["tip"]) / 2
    L["hip"][2] = max(L["hip"][2], L["knee"][2] * 0.55)
# sides and ranks: L = x < centre; rank 0 = front-most
for side, sel in (("L", [i for i, L in enumerate(legs) if L["tip"][0] < C[0]]), ("R", [i for i, L in enumerate(legs) if L["tip"][0] >= C[0]])):
    sel.sort(key=lambda i: legs[i]["tip"][1])           # -Y is the front
    for r, i in enumerate(sel):
        legs[i]["side"], legs[i]["rank"] = side, r
for i, L in enumerate(legs):
    L["name"] = "Leg%d_%s" % (L["rank"] * 2 + (0 if L["side"] == "L" else 1), L["side"])
    L["group"] = 0 if (L["rank"] % 2 == 0) == (L["side"] == "L") else 1       # alternating tetrapod: L1 R2 L3 R4 | R1 L2 R3 L4
    print("LEG", L["name"], "grp", L["group"], "pts", L["n"], "hip", L["hip"].round(2), "knee", L["knee"].round(2), "ankle", L["ankle"].round(2), "tip", L["tip"].round(2))
fy = float(V[:, 1].min())
HEAD_Y = C[1] - 0.17 * SIZE                              # the head starts about here (towards -Y)

# ------------------------------------------------------------------ bones
bones = [("Body", Vector((C[0], C[1], 0.72 * H)), Vector((C[0], C[1] + 0.12, 0.78 * H)), None),
         ("Head", Vector((C[0], C[1] - 0.1, 0.72 * H)), Vector((C[0], fy, 0.62 * H)), "Body")]
for L in legs:
    hp, kn, an, tp = Vector(L["hip"]), Vector(L["knee"]), Vector(L["ankle"]), Vector(L["tip"])
    bones.append((L["name"] + "_Up", hp, kn, "Body"))
    bones.append((L["name"] + "_Lo", kn, an, L["name"] + "_Up"))
    bones.append((L["name"] + "_Foot", an, tp, L["name"] + "_Lo"))

arm = bpy.data.armatures.new("Monster_Rig")
rig = bpy.data.objects.new("Monster_Rig", arm)
bpy.context.scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='EDIT')
for name, h, t, par in bones:
    eb = arm.edit_bones.new(name)
    if (t - h).length < 1e-4:
        t = h + Vector((0, 0, 0.01))
    eb.head, eb.tail = h, t
for name, h, t, par in bones:
    if par:
        arm.edit_bones[name].parent = arm.edit_bones[par]
bpy.ops.object.mode_set(mode='OBJECT')

# ------------------------------------------------------------------ skin weights (computed here)
names = [b[0] for b in bones]
W = np.zeros((len(V), len(bones)))
jb, jh = names.index("Body"), names.index("Head")
head_k = np.clip((HEAD_Y - V[:, 1]) / 0.10 + 0.5, 0.0, 1.0)         # 0 body .. 1 head, a short blend
for vi in range(len(V)):
    if is_leg[vi]:
        i = int(which[vi])
        L = legs[i]
        ks = [seg_t_dist(V[vi:vi + 1], np.array(bones[names.index(L["name"] + s)][1]), np.array(bones[names.index(L["name"] + s)][2]))[1][0] for s in ("_Up", "_Lo", "_Foot")]
        ws = np.exp(-(np.array(ks) - min(ks)) / 0.012)
        ws /= ws.sum()
        t = TD[i][0][vi]
        root_k = float(np.clip(1.0 - t / 0.15, 0.0, 1.0)) ** 2                 # near the hip the body holds the skin
        for s, w in zip(("_Up", "_Lo", "_Foot"), ws):
            W[vi, names.index(L["name"] + s)] = w * (1 - root_k)
        W[vi, jb] = root_k
    else:
        W[vi, jh] = head_k[vi]
        W[vi, jb] = 1.0 - head_k[vi]
for j, name in enumerate(names):
    vg = src.vertex_groups.new(name=name)
    for vi in np.where(W[:, j] > 1e-4)[0]:
        vg.add([int(vi)], float(W[vi, j]), 'REPLACE')
src.parent = rig
mod = src.modifiers.new("Armature", 'ARMATURE')
mod.object = rig

# ------------------------------------------------------------------ animation tools
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='POSE')
for pb in rig.pose.bones:
    pb.rotation_mode = 'QUATERNION'
REST = {b.name: b.matrix_local.to_3x3() for b in rig.data.bones}
bpy.context.scene.render.fps = FPS
info = {"kind": "spider", "size_m": SIZE, "height_m": H, "facing": "+Z"}


def key(name, frame, quat=None, loc=None):
    pb = rig.pose.bones[name]
    if quat is not None:
        pb.rotation_quaternion = quat
        pb.keyframe_insert("rotation_quaternion", frame=frame - 1)
    if loc is not None:
        pb.location = loc
        pb.keyframe_insert("location", frame=frame - 1)


def wrot(name, axis, ang):
    Wm = Matrix.Rotation(ang, 3, Vector(axis))
    M = REST[name]
    return (M.inverted() @ Wm @ M).to_quaternion()


def wloc(name, v):
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


LG = []
for L in legs:
    LG.append({"name": L["name"], "H": Vector(L["hip"]), "K": Vector(L["knee"]), "A": Vector(L["ankle"]), "T": Vector(L["tip"]), "grp": L["group"],
               "rank": L["rank"], "side": L["side"], "out": Vector((L["d"][0], L["d"][1], 0.0))})
LEG_BY = {g["name"]: g for g in LG}


def solve_knee(g, Tn):
    H_, K0, T0 = g["H"], g["K"], g["T"]
    L1, L2 = (K0 - H_).length, (T0 - K0).length
    v = Tn - H_
    d = min(max(v.length, abs(L1 - L2) + 1e-4), L1 + L2 - 1e-4)
    u = v.normalized()
    a = (L1 * L1 - L2 * L2 + d * d) / (2 * d)
    h = math.sqrt(max(L1 * L1 - a * a, 0.0))
    u0 = (T0 - H_).normalized()
    pole0 = (K0 - H_) - u0 * (K0 - H_).dot(u0)
    pole0.normalize()
    pole = u0.rotation_difference(u) @ pole0
    return H_ + u * a + pole * h


def pose_leg(f, g, Tn):
    """key the leg so its claw tip is at Tn (body frame)"""
    Kn = solve_knee(g, Tn)
    Dup = (g["K"] - g["H"]).rotation_difference(Kn - g["H"])
    Dlo = (g["T"] - g["K"]).rotation_difference(Tn - Kn)
    n = g["name"]
    Mu, Ml, Mf = REST[n + "_Up"], REST[n + "_Lo"], REST[n + "_Foot"]
    Du, Dl = Dup.to_matrix(), Dlo.to_matrix()
    key(n + "_Up", f, (Mu.inverted() @ Du @ Mu).to_quaternion())
    key(n + "_Lo", f, (Ml.inverted() @ Du.inverted() @ Dl @ Ml).to_quaternion())
    key(n + "_Foot", f, (Mf.inverted() @ Dl.inverted() @ Dl @ Mf).to_quaternion())


def plant_all(f, offs=None, bodyoff=Vector((0, 0, 0))):
    for g in LG:
        Tn = g["T"] - bodyoff
        if offs and g["name"] in offs:
            Tn = Tn + offs[g["name"]]
        pose_leg(f, g, Tn)


def head_pose(f, yaw=0.0, pitch=0.0, roll=0.0):
    """yaw about world Z, pitch about X (positive = down at the front), roll about Y"""
    q = wrot("Head", (0, 0, 1), yaw) @ wrot("Head", (1, 0, 0), pitch) @ wrot("Head", (0, 1, 0), roll)
    key("Head", f, q)


def body_pose(f, pitch=0.0, yaw=0.0, roll=0.0, loc=(0, 0, 0)):
    q = wrot("Body", (0, 0, 1), yaw) @ wrot("Body", (1, 0, 0), pitch) @ wrot("Body", (0, 1, 0), roll)
    key("Body", f, q, loc=wloc("Body", loc))


def env(t, c, w):
    """a periodic bump of width w centred on c (t in 0..1, wraps)"""
    d = ((t - c + 0.5) % 1.0) - 0.5
    return math.exp(-(d / w) ** 2)


def gait(name, T, speed_mps, duty, lift, body_low, head_amp, cycles=1, probe=0.0):
    """Alternating tripods (L1 R2 L3 | R1 L2 R3): one group stands (its feet slide back at body speed, so they stay planted) while the other lifts and reaches.
    T = frames per step cycle; `cycles` step cycles per clip (so the clip can vary from step to step); `probe` = extra reach of the longer front-right leg
    on every second step (it reaches out and feels for the ground before it lands in the normal place)."""
    N = T * cycles
    new_action(name, N + 1)
    s = speed_mps * duty * T / FPS                    # how far a foot is carried back while it stands
    for f in range(1, N + 2):
        tt = ((f - 1) % N) / float(T)                 # time in step cycles
        p0 = tt % 1.0
        offs = {}
        for g in LG:
            fi = tt + 0.5 * g["grp"]
            k = int(math.floor(fi)) % cycles
            p = fi % 1.0
            if p < duty:
                u = p / duty
                off, lf = s * 0.5 * (1 - 2 * u), 0.0
                extra = Vector((0, 0, 0))
            else:
                u = (p - duty) / (1 - duty)
                off, lf = -s * 0.5 + s * u, lift * math.sin(math.pi * u)
                extra = Vector((0, 0, 0))
                if probe and k == (cycles - 1) and g["rank"] == 0 and g["side"] == "R":
                    pr = math.sin(math.pi * u) ** 1.5
                    extra = FW * (probe * pr) + Vector((0, 0, 0.35 * probe * pr))
            offs[g["name"]] = FW * off + Vector((0, 0, lf)) + g["out"] * (0.35 * lf) + extra
        bob = 0.012 * math.sin(4 * math.pi * p0)
        bo = Vector((0, 0, -body_low + bob))
        plant_all(f, offs, bo)
        body_pose(f, pitch=math.radians(1.2) * math.sin(4 * math.pi * p0), yaw=math.radians(3.0) * math.sin(2 * math.pi * p0),
                  roll=math.radians(2.5) * math.sin(2 * math.pi * p0 + 1.0), loc=(0, 0, bo.z))
        head_pose(f, yaw=math.radians(head_amp) * math.sin(2 * math.pi * p0 + 0.6), pitch=math.radians(5 + 4 * math.sin(4 * math.pi * p0)))
    info["crawl_speed_mps" if name == "Crawl" else "scuttle_speed_mps"] = round(speed_mps, 3)


# idle: almost the whole body is still (it only breathes); three distinct, well spaced events: two quick taps of one foreleg, a quick flick of the head
# to the side and back, and two small dips of the head (the mandibles clicking: there are no jaw bones). The loop ends exactly where it starts.
new_action("Idle_Twitch", 97)
TAPPER = LEG_BY[next(L["name"] for L in legs if L["side"] == "L" and L["rank"] == 0)]
for f in range(1, 98):
    t = (f - 1) / 96.0
    tap = env(t, 0.20, 0.010) + env(t, 0.245, 0.010)
    flick = env(t, 0.58, 0.022)
    click = env(t, 0.86, 0.008) + env(t, 0.905, 0.008)
    offs = {TAPPER["name"]: Vector((0, 0, 0.075 * tap)) + FW * (0.03 * tap)}
    bo = Vector((0, 0, 0.004 * math.sin(2 * math.pi * t)))
    plant_all(f, offs, bo)
    body_pose(f, pitch=math.radians(0.5) * math.sin(2 * math.pi * t), roll=math.radians(0.3) * math.sin(2 * math.pi * t + 1), loc=(0, 0, bo.z))
    head_pose(f, yaw=math.radians(26) * flick + math.radians(1.5) * math.sin(2 * math.pi * t), pitch=math.radians(6 + 1.0 * math.sin(2 * math.pi * t)) + math.radians(6) * min(click, 1.0), roll=math.radians(4) * flick)

gait("Crawl", 29, 0.472, 0.55, 0.075, 0.03, 14, cycles=2, probe=0.06)
gait("Scuttle_Fast", 10, 2.588, 0.5, 0.13, 0.07, 4)

# alert: the front legs raised and feeling the air, the body tilted up, the head scanning
new_action("Alert", 49)
front = [g for g in LG if g["rank"] == 0]
for f in range(1, 50):
    t = (f - 1) / 48.0
    offs = {}
    for g in front:
        sg = 1.0 if g["side"] == "L" else -1.0
        offs[g["name"]] = FW * (0.22 + 0.04 * math.sin(2 * math.pi * t * 3 + sg)) + Vector((0, 0, 0.52 + 0.05 * math.sin(2 * math.pi * t * 4 + sg))) + g["out"] * 0.12
    bo = Vector((0, 0, 0.02))
    plant_all(f, offs, bo)
    body_pose(f, pitch=math.radians(-12) + math.radians(1.2) * math.sin(2 * math.pi * t * 6), loc=(0, 0, bo.z))
    head_pose(f, yaw=math.radians(34) * math.sin(2 * math.pi * t * 2), pitch=math.radians(-12 + 4 * math.sin(2 * math.pi * t * 4)))

# attack: compress the middle and rear legs (the body drops, the haunches coil), spring off them (the contact moment stays at u 0.65, as before), reach with the
# foretips before the head strikes (the head follows the legs), the front tips land first, the body compresses against them and the abdomen swings forward (the body
# pitches down at the impact), then the whole creature recoils back. Rear legs stay planted where they stood in the world.
new_action("Attack_Lunge", 16)
rear = [g for g in LG if g["rank"] >= 2]
mid = [g for g in LG if g["rank"] == 1]
front2 = [g for g in LG if g["rank"] == 0]
for f in range(1, 17):
    u = (f - 1) / 15.0
    crouch = math.sin(min(u / 0.3, 1.0) * math.pi / 2) * (1.0 if u < 0.3 else max(0.0, 1.0 - (u - 0.3) / 0.07))
    spring = 0.0 if u < 0.3 else math.sin(min((u - 0.3) / 0.35, 1.0) * math.pi / 2) * (1.0 - max(0.0, (u - 0.75) / 0.25))
    recoil = math.sin(min(max((u - 0.68) / 0.32, 0.0), 1.0) * math.pi)
    comp = math.sin(min(max((u - 0.62) / 0.10, 0.0), 1.0) * math.pi)
    hs = smooth_ = min(max((u - 0.42) / 0.23, 0.0), 1.0)
    hs = hs * hs * (3 - 2 * hs)
    body_off = FW * (0.42 * spring - 0.07 * recoil) + Vector((0, 0, -0.10 * crouch + 0.05 * spring - 0.03 * comp))
    offs = {}
    for g in front2:
        offs[g["name"]] = FW * (0.26 * spring - 0.08 * crouch) + Vector((0, 0, 0.30 * spring + 0.04 * crouch)) + g["out"] * (0.1 * spring)
    for g in mid:
        offs[g["name"]] = FW * (0.10 * spring) + Vector((0, 0, 0.10 * spring * (1.0 - comp))) + g["out"] * (0.05 * spring)
    for g in rear:
        offs[g["name"]] = Vector((0, 0, 0))
    plant_all(f, {k: v for k, v in offs.items()}, Vector((0, 0, body_off.z)))
    for g in rear:
        pose_leg(f, g, g["T"] - body_off)
    for g in mid:
        pose_leg(f, g, g["T"] - body_off + offs[g["name"]])
    for g in front2:
        pose_leg(f, g, g["T"] - body_off + offs[g["name"]])
    body_pose(f, pitch=math.radians(10) * crouch - math.radians(14) * spring + math.radians(8) * comp - math.radians(6) * recoil, loc=tuple(body_off))
    head_pose(f, yaw=0.0, pitch=math.radians(-10) * crouch + math.radians(22) * hs + math.radians(6) * recoil)

new_action("Hit_React", 13)
for f in range(1, 14):
    u = (f - 1) / 12.0
    sh = math.sin(u * math.pi * 3) * (1 - u)
    bo = Vector((0, 0, -0.03 * (1 - u)))
    plant_all(f, None, bo)
    body_pose(f, pitch=math.radians(6) * (1 - u), yaw=math.radians(9) * sh, loc=tuple(bo))
    head_pose(f, yaw=math.radians(-24) * sh, pitch=math.radians(-12) * (1 - u))

# death: the legs fold up over the body, it sinks and rolls
new_action("Death", 37)
for f in range(1, 38):
    u = (f - 1) / 36.0
    k = min(u / 0.6, 1.0)
    k = k * k * (3 - 2 * k)
    bo = Vector((0, 0, -0.22 * H * k))
    for g in LG:
        curl = Vector((C[0], C[1], 0.0)) + Vector((g["out"].x * 0.14, g["out"].y * 0.14, 0.62 * H + 0.12 * g["rank"] * 0.3))
        Tn = (g["T"] - bo).lerp(curl - bo * 0.0, k * 0.85)
        pose_leg(f, g, Tn)
    body_pose(f, pitch=math.radians(8) * k, roll=math.radians(24) * k, loc=tuple(bo))
    head_pose(f, yaw=math.radians(16) * k, pitch=math.radians(24) * k)
info["facing"] = "+Z"
bpy.ops.object.mode_set(mode='OBJECT')
rig.animation_data.action = bpy.data.actions["Idle_Twitch"]
json.dump(info, open(os.path.join(glb_dir, "skitter.json"), "w"), indent=1)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(work, "skitter_rig.blend"))

if preview:
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_EEVEE'
    w_ = bpy.data.worlds.new("w")
    w_.use_nodes = True
    w_.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.57, 0.6, 1)
    sc.world = w_
    cam = bpy.data.cameras.new("c")
    cam.type = 'ORTHO'
    cam.ortho_scale = SIZE * 1.25
    cobj = bpy.data.objects.new("c", cam)
    sc.collection.objects.link(cobj)
    sc.camera = cobj
    sc.render.resolution_x = sc.render.resolution_y = 300
    for clip, frames in (("Idle_Twitch", (10, 30, 60)), ("Crawl", (0, 8, 15, 22)), ("Scuttle_Fast", (0, 3, 6, 8)), ("Alert", (0, 24)), ("Attack_Lunge", (3, 7, 10, 14)), ("Death", (36,))):
        rig.animation_data.action = bpy.data.actions[clip]
        for fr in frames:
            sc.frame_set(fr)
            for view, (loc, rot) in {"side": ((SIZE * 6, 0, SIZE * 0.2), (math.pi / 2, 0, math.pi / 2)), "top": ((0, 0, SIZE * 6), (0, 0, 0))}.items():
                cobj.location, cobj.rotation_euler = loc, rot
                sc.render.filepath = os.path.join(work, "sk_%s_%d_%s.png" % (clip, fr, view))
                bpy.ops.render.render(write_still=True)

if "gif" in args:                                       # every frame of the main clips, side + top, for a GIF
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_EEVEE'
    w_ = bpy.data.worlds.new("w2")
    w_.use_nodes = True
    w_.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.57, 0.6, 1)
    sc.world = w_
    cam = bpy.data.cameras.new("c2")
    cam.type = 'ORTHO'
    cam.ortho_scale = SIZE * 1.3
    cobj = bpy.data.objects.new("c2", cam)
    sc.collection.objects.link(cobj)
    sc.camera = cobj
    sc.render.resolution_x = sc.render.resolution_y = 260
    gd = os.path.join(work, "gif")
    os.makedirs(gd, exist_ok=True)
    for clip in ("Idle_Twitch", "Crawl", "Scuttle_Fast", "Alert", "Attack_Lunge"):
        rig.animation_data.action = bpy.data.actions[clip]
        L_ = int(bpy.data.actions[clip].frame_range[1])
        step = 3 if clip == "Idle_Twitch" else 1
        for fr in range(0, L_ + 1, step):
            sc.frame_set(fr)
            for view, (loc, rot) in {"side": ((SIZE * 6, 0, SIZE * 0.2), (math.pi / 2, 0, math.pi / 2)), "top": ((0, 0, SIZE * 6), (0, 0, 0))}.items():
                cobj.location, cobj.rotation_euler = loc, rot
                sc.render.filepath = os.path.join(gd, "%s_%03d_%s.png" % (clip, fr, view))
                bpy.ops.render.render(write_still=True)

bpy.ops.object.select_all(action='DESELECT')
src.select_set(True)
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
rig.animation_data.action = bpy.data.actions["Idle_Twitch"]
glb = os.path.join(glb_dir, "MON_skitter.glb")
bpy.ops.export_scene.gltf(filepath=glb, export_format='GLB', use_selection=True, export_animations=True, export_animation_mode='ACTIONS',
                          export_skins=True, export_yup=True, export_normals=True, export_apply=False)
print("GLB", glb, os.path.getsize(glb))
