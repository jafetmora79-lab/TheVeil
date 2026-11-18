"""THE VEIL - Colossus remaster (Blender 5.x).
   blender -b -P creatures/tools/build_colossus_v2.py -- <out.glb> <out.blend>
Original CRT_Colossus.glb stays untouched in THE_VEIL_ASSETS_V2. New clips on the existing 62-bone rig:
 - four legs with a generic 3D two-bone IK (hip bar fixed, knee on a pole, planted stance feet that slide back at exactly 1 m/s per clip
   second - the figure every cinematic already uses - crouched stalk so the legs never over-reach);
 - body weight: crouch/rise at each footfall, roll over the planted side, chest and head lag;
 - tentacles: FK chains with travelling-wave delay (follow-through), a stronger wind-up and whip for the strike (impact at 1.05 s).
Clip names and durations are unchanged (+ Walk_Fast)."""
import bpy, sys, os, math, random
from mathutils import Matrix, Vector, Quaternion

OUT_GLB, OUT_BLEND = sys.argv[sys.argv.index("--") + 1], sys.argv[sys.argv.index("--") + 2]
SRC = os.environ.get("COLOSSUS_SRC", "THE_VEIL_ASSETS_V2/07_Creatures/Colossus/CRT_Colossus.glb")
random.seed(3)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.abspath(SRC))
arm = bpy.data.objects["CRT_Colossus"]
mesh = bpy.data.objects["CRT_Colossus_Mesh"]
for o in list(bpy.data.objects):
    if o.name.startswith("Icosphere"):
        bpy.data.objects.remove(o)
if arm.animation_data:
    for t in list(arm.animation_data.nla_tracks):
        arm.animation_data.nla_tracks.remove(t)
    arm.animation_data.action = None
for act in list(bpy.data.actions):
    bpy.data.actions.remove(act)

# ---- surface: grime / wear as vertex colour (dark under the belly and at the toes, paler horn and claw tips)
if not os.environ.get("COLOSSUS_NO_GRIME"):
    me = mesh.data
    col = me.color_attributes.new("Col", 'BYTE_COLOR', 'POINT')
    for i, v in enumerate(me.vertices):
        g = .84 + .16 * random.random()
        if v.co.z < 2.5:
            g *= .7 + .3 * (v.co.z / 2.5)
        if v.co.z < 8.0 and abs(v.co.x) < 2.2:
            g *= .82
        col.data[i].color = (g, g, g, 1)
    for mat in me.materials:
        if not mat or not mat.use_nodes:
            continue
        nt = mat.node_tree
        bsdf = nt.nodes.get("Principled BSDF")
        if not bsdf:
            continue
        link = bsdf.inputs["Base Color"].links[0] if bsdf.inputs["Base Color"].links else None
        ca = nt.nodes.new("ShaderNodeVertexColor")
        ca.layer_name = "Col"
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type = 'RGBA'
        mix.blend_type = 'MULTIPLY'
        mix.inputs[0].default_value = 1.0
        if link:
            nt.links.new(link.from_socket, mix.inputs[6])
        nt.links.new(ca.outputs["Color"], mix.inputs[7])
        nt.links.new(mix.outputs[2], bsdf.inputs["Base Color"])

# ---- rig data
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode='POSE')
bones = list(arm.data.bones)


def depth(b):
    d = 0
    while b.parent:
        b = b.parent
        d += 1
    return d


order = [b.name for b in sorted(bones, key=depth)]
rest = {b.name: b.matrix_local.copy() for b in bones}
head = {b.name: b.head_local.copy() for b in bones}
FPS = 90                      # baked at 90 fps: the stance claws must stay flat to a few mm after Godot interpolates the keys
TIP = {"FL": Vector((-6.7, -7.1, 0)), "FR": Vector((6.4, -6.7, 0)), "HL": Vector((-5.0, 3.1, 0)), "HR": Vector((3.6, 3.4, 0))}
LEGPAR = {"FL": "Chest", "FR": "Chest", "HL": "Rear", "HR": "Rear"}
GROUPS = {"DorsalL": [f"T_DorsalL_0{i}" for i in range(1, 9)], "DorsalR": [f"T_DorsalR_0{i}" for i in range(1, 8)],
          "FlankL": [f"T_FlankL_0{i}" for i in range(1, 7)], "FlankR": [f"T_FlankR_0{i}" for i in range(1, 7)],
          "VentA": [f"T_VentA_0{i}" for i in range(1, 7)], "VentB": [f"T_VentB_0{i}" for i in range(1, 6)]}
PARENT_OF_GROUP = {"DorsalL": "Body", "DorsalR": "Rear", "FlankL": "Body", "FlankR": "Chest", "VentA": "Belly", "VentB": "Belly"}
TIDX = {g: i for i, g in enumerate(GROUPS)}


def smooth(x):
    x = max(0.0, min(1.0, x))
    return x * x * (3 - 2 * x)


def K(t, keys):
    if t <= keys[0][0]:
        return keys[0][1]
    for (f0, v0), (f1, v1) in zip(keys, keys[1:]):
        if t <= f1:
            return v0 + (v1 - v0) * smooth((t - f0) / max(f1 - f0, 1e-6))
    return keys[-1][1]


def rot_pivot(h, axis, th):
    return Matrix.Translation(h) @ Matrix.Rotation(th, 4, axis) @ Matrix.Translation(-h)


def arc(v_from, v_to):
    q = v_from.normalized().rotation_difference(v_to.normalized())
    return q.to_matrix().to_4x4()


def pivot_mat(p, R):
    return Matrix.Translation(p) @ R @ Matrix.Translation(-p)


def tent_axes(group, i):
    names = GROUPS[group]
    a = head[names[i]]
    b = head[names[i + 1]] if i + 1 < len(names) else head[names[i]] + (head[names[i]] - head[names[i - 1]])
    d = (b - a).normalized()
    a1 = d.cross(Vector((0, 0, 1)))
    if a1.length < .2:
        a1 = d.cross(Vector((1, 0, 0)))
    a1.normalize()
    a2 = d.cross(a1).normalized()
    return a1, a2


AX = {g: [tent_axes(g, i) for i in range(len(GROUPS[g]))] for g in GROUPS}


def solve(P):
    D = {"Root": Matrix.Identity(4)}
    dx, dy, dz, bp, br, byw = P["body"]
    hb = head["Body"]
    D["Body"] = Matrix.Translation((dx, dy, dz)) @ rot_pivot(hb, 'Z', byw) @ rot_pivot(hb, 'Y', br) @ rot_pivot(hb, 'X', bp)
    D["Chest"] = D["Body"] @ rot_pivot(head["Chest"], 'Z', P["chest"][1]) @ rot_pivot(head["Chest"], 'X', P["chest"][0])
    D["Rear"] = D["Body"] @ rot_pivot(head["Rear"], 'X', P["rear"])
    D["Belly"] = D["Body"] @ rot_pivot(head["Belly"], 'X', P["belly"])
    D["Head"] = D["Chest"] @ rot_pivot(head["Head"], 'Z', P["head"][1]) @ rot_pivot(head["Head"], 'X', P["head"][0])
    D["Maw_L"] = D["Head"] @ rot_pivot(head["Maw_L"], 'Z', P["maw"])
    D["Maw_R"] = D["Head"] @ rot_pivot(head["Maw_R"], 'Z', -P["maw"])
    for s in ("L", "R"):
        D[f"Stalk_{s}_01"] = D["Head"] @ rot_pivot(head[f"Stalk_{s}_01"], 'X', P["stalk"][0])
        D[f"Stalk_{s}_02"] = D[f"Stalk_{s}_01"] @ rot_pivot(head[f"Stalk_{s}_02"], 'X', P["stalk"][1])
    # legs: hip bar (Upper) fixed to its parent; knee by pole; two-bone IK to the tip
    for leg in TIP:
        up, lo, ft = f"Leg_{leg}_Upper", f"Leg_{leg}_Lower", f"Leg_{leg}_Foot"
        par = LEGPAR[leg]
        D[up] = D[par]
        B, C, T = head[lo], head[ft], TIP[leg]
        Bp = D[up] @ B
        L2, L3 = (C - B).length, (T - C).length
        Pw = Vector(P["tips"][leg])
        v = Pw - Bp
        dist = max(abs(L2 - L3) + .1, min(L2 + L3 - .02, v.length))
        u = v.normalized()
        uh = (T - B).normalized()
        p_rest = (C - B) - uh * (C - B).dot(uh)
        w = (D[up].to_3x3() @ p_rest)
        w = (w - u * w.dot(u))
        w = w.normalized() if w.length > 1e-6 else Vector((0, -1, 0)).cross(u).normalized()
        cosa = max(-1, min(1, (L2 * L2 + dist * dist - L3 * L3) / (2 * L2 * dist)))
        al = math.acos(cosa)
        Cp = Bp + (u * math.cos(al) + w * math.sin(al)) * L2
        v2 = (D[up] @ C) - Bp
        D[lo] = pivot_mat(Bp, arc(v2, Cp - Bp)) @ D[up]
        v3 = (D[lo] @ T) - (D[lo] @ C)
        Tt = Cp + (Pw - Cp).normalized() * min(L3, (Pw - Cp).length) if dist == v.length else Cp + (Pw - Cp).normalized() * L3
        D[ft] = pivot_mat(Cp, arc(v3, Tt - Cp)) @ D[lo]
    # tentacles
    TT = P["tent"]
    for g, names in GROUPS.items():
        prev = PARENT_OF_GROUP[g]
        for i, n in enumerate(names):
            a1, a2 = AX[g][i]
            w1 = TT["amp"] * (.04 + .035 * i) * math.sin(TT["w"] * TT["t"] - TT["lag"] * i + TIDX[g] * 1.3)
            w2 = TT["amp"] * (.03 + .03 * i) * math.cos(TT["w"] * 1.31 * TT["t"] - TT["lag"] * i * 1.2 + TIDX[g] * .8)
            b1, b2 = TT["bias"].get(g, (0.0, 0.0))
            th1 = w1 + b1 * (1.0 if i else .5)
            th2 = w2 + b2 * (1.0 if i else .5)
            if "bias_fn" in TT and TT["bias_fn"]:
                x1, x2 = TT["bias_fn"](g, i)
                th1 += x1
                th2 += x2
            D[n] = D[prev] @ pivot_mat(head[n], Quaternion(a1, th1).to_matrix().to_4x4() @ Quaternion(a2, th2).to_matrix().to_4x4(), ) if False else D[prev] @ (Matrix.Translation(head[n]) @ Quaternion(a1, th1).to_matrix().to_4x4() @ Quaternion(a2, th2).to_matrix().to_4x4() @ Matrix.Translation(-head[n]))
            prev = n
    return D


CLAW = [Vector((-6.1, -6.2, .06)), Vector((-5.55, -7.36, .06)), Vector((-6.15, -7.82, .06)), Vector((-6.7, -7.07, .06))]


def claw_low(leg, D):
    sx = -1 if TIP[leg].x < 0 else 1
    ref = TIP["FL"]
    zs = []
    for c in CLAW:
        rel = c - ref
        pt = TIP[leg] + Vector((rel.x * (-sx), rel.y, rel.z))
        zs.append((D[f"Leg_{leg}_Foot"] @ pt).z)
    return min(zs)


def solve_grounded(P):
    """keep the claw tips (what the game measures) from ever going under the road, and exactly on it while a foot is planted"""
    D = solve(P)
    for it in range(10):
        moved = False
        for l in TIP:
            x, y, z = P["tips"][l]
            w = 1.0 if z < .02 else 0.0
            corr = .06 - P.get("dip", {}).get(l, 0.0) - claw_low(l, D)
            if corr > .0004 or (corr < -.0004 and w > .01):
                P["tips"][l] = (x, y, z + (corr if corr > 0 else corr * w))
                moved = True
        if not moved:
            break
        D = solve(P)
    return D


def basis_for(name, D):
    b = arm.data.bones[name]
    Dp = D[b.parent.name] if b.parent else Matrix.Identity(4)
    return rest[name].inverted() @ Dp.inverted() @ D[name] @ rest[name]


def rest_params():
    return {"body": (0, 0, 0, 0, 0, 0), "chest": (0, 0), "rear": 0, "belly": 0, "head": (0, 0), "maw": 0, "stalk": (0, 0),
            "tips": {l: tuple(TIP[l]) for l in TIP}, "tent": {"amp": 0, "w": 0, "t": 0, "lag": 0, "bias": {}}}


test = solve(rest_params())
err = 0
for n in test:
    m = basis_for(n, test)
    err = max(err, max(abs(c - (1.0 if i == j else 0.0)) for i, r in enumerate(m) for j, c in enumerate(r)))
print("REST SELFTEST max basis error", round(err, 4), "bones", len(test), "of", len(bones))


def new_clip(name, seconds, fn):
    n = int(round(seconds * FPS))
    act = bpy.data.actions.new(name)
    arm.animation_data_create()
    arm.animation_data.action = act
    for f in range(n):
        PP = fn(f / FPS, f / n)
        D = solve_grounded(PP)
        for bn in order:
            pb = arm.pose.bones[bn]
            pb.rotation_mode = 'QUATERNION'
            m = basis_for(bn, D) if bn in D else Matrix.Identity(4)
            pb.location = m.to_translation()
            pb.rotation_quaternion = m.to_quaternion()
            pb.keyframe_insert("location", frame=f + 1)
            pb.keyframe_insert("rotation_quaternion", frame=f + 1)
    act.use_fake_user = True
    arm.animation_data.action = None
    tr = arm.animation_data.nla_tracks.new()
    tr.name = name
    st = tr.strips.new(name, 1, act)
    if len(act.slots):
        st.action_slot = act.slots[0]
    print("CLIP", name, n)


TAU = 2 * math.pi


def foot(leg, phase, duty, stride, lift, early=False):
    t = TIP[leg]
    p = phase % 1.0
    if p < duty:
        y = t.y - stride / 2 + stride * (p / duty)
        z = 0.0
    else:
        q = (p - duty) / (1 - duty)
        y = t.y + stride / 2 - stride * smooth(q)
        if early:                      # snaps up in the first fifth of the swing, then settles slowly onto the road (a heavy, deliberate step)
            u = (q - .2) / .8
            z = lift * (smooth(q / .2) if q < .2 else ((1 - u * u) if u < .975 else .0494 * (1 - (u - .975) / .025)))
        else:
            z = lift * math.sin(math.pi * q) ** .9
    return (t.x, y, z)


def stomp(p, ph):
    """0..1 pulse centred just after a foot lands (phase ph)"""
    d = ((p - ph - .04) % 1.0)
    return math.exp(-((min(d, 1 - d)) / .06) ** 2)


# ---------- IDLE_BREATHE (4 s loop): crouched breathing, weight shifting between the fore legs, tentacles drifting, stalks twitching
def idle(t, p):
    P = rest_params()
    br = math.sin(TAU * p)
    P["body"] = (0, 0, -.35 + .10 * br, .012 * br, .02 * math.sin(TAU * p + 1), .015 * math.sin(TAU * p))
    P["chest"] = (.015 * math.sin(TAU * p - .6), .03 * math.sin(TAU * p))
    P["head"] = (.04 * math.sin(TAU * p - 1.0), .12 * math.sin(TAU * p + .5))
    P["maw"] = .05 + .04 * math.sin(TAU * 2 * p)
    P["stalk"] = (.08 * math.sin(TAU * 3 * p), .12 * math.sin(TAU * 3 * p - .7))
    P["tent"] = {"amp": 1.0, "w": TAU / 4.0, "t": t, "lag": .55, "bias": {}}
    return P


# ---------- WALK_HEAVY (4 s loop): lateral-sequence quadruped, 1 m/s stance slide (cinematics measure this), crouch on every footfall
def walk(t, p, amp=1.0, speed=1.0, T=4.0, duty=.55, lift=3.2, early=True):
    P = rest_params()
    stride = speed * T * duty
    ph = {"HL": 0.0, "FL": .25, "HR": .5, "FR": .75}
    P["tips"] = {l: foot(l, p - ph[l], duty, stride, lift, early) for l in TIP}
    P["dip"] = {l: (.012 * math.exp(-(((p - ph[l]) % 1.0) / duty) / .05) if ((p - ph[l]) % 1.0) < duty else 0.0) for l in TIP}
    hit = sum(stomp(p, ph[l]) for l in TIP)
    sway = math.sin(TAU * p)
    P["body"] = (0, 0, -.85 + .16 * math.cos(2 * TAU * p) - .08 * hit, .015 * hit - .01, .05 * sway, .035 * math.sin(TAU * p + .6))
    P["chest"] = (-.02 * math.sin(2 * TAU * p + .5) + .02 * hit, -.06 * sway)
    P["rear"] = .02 * math.sin(2 * TAU * p)
    P["head"] = (.05 * math.sin(2 * TAU * p - .9) - .02 * hit, .15 * math.sin(TAU * p - 1.0))
    P["maw"] = .08 + .05 * math.sin(TAU * p * 2)
    P["stalk"] = (.1 * math.sin(2 * TAU * p + .4), .14 * math.sin(2 * TAU * p - .2))
    P["tent"] = {"amp": 1.2 + .5 * amp, "w": TAU / 4.0, "t": t, "lag": .5, "bias": {}}
    return P


def walk_heavy(t, p):
    return walk(t, p)


def walk_fast(t, p):                      # 2 s cycle, 3 m/s, lower and leaning in, tentacles streaming back
    P = walk(t, p, amp=1.6, speed=3.0, T=2.0, duty=.6, lift=3.0, early=False)
    P["body"] = (0, 0, P["body"][2] - .5, .07, P["body"][4] * 1.5, P["body"][5] * 1.5)
    P["head"] = (.15, P["head"][1])
    P["tent"]["bias"] = {g: (.35 if g.startswith(("Dorsal", "Flank")) else .1, 0) for g in GROUPS}
    P["tent"]["w"] = TAU / 2.0
    return P


# ---------- TENTACLES_SWAY (6 s loop): body still, every tentacle moving on its own delay
def sway(t, p):
    P = rest_params()
    P["body"] = (0, 0, -.35, 0, .01 * math.sin(TAU * p), 0)
    P["head"] = (.03, .08 * math.sin(TAU * p))
    P["maw"] = .1 * (.5 + .5 * math.sin(TAU * 2 * p))
    P["tent"] = {"amp": 1.9, "w": TAU / 6.0, "t": t, "lag": .8, "bias": {}}
    return P


# ---------- ALERT (2.4 s, once): it stops, rises, head swings to the target, stalks snap forward, maw opens, tentacles flare
def alert(t, p):
    f = t * 30.0
    P = rest_params()
    e = K(f, [(0, 0), (22, 1), (72, 1)])
    P["body"] = (0, -.3 * e, -.35 + .5 * e, -.05 * e, 0, 0)
    P["chest"] = (-.10 * e, .18 * math.sin(f * .09) * e)
    P["head"] = (-.18 * e, .45 * K(f, [(0, 0), (20, 1), (40, -.6), (60, .5), (72, 0)]))
    P["maw"] = .45 * e
    P["stalk"] = (-.35 * e, -.25 * e)
    flare = {g: (.45 * e, .2 * e) for g in GROUPS}
    P["tent"] = {"amp": 1.4, "w": TAU / 2.4, "t": t, "lag": .5, "bias": flare}
    return P


STRIKE_G = ("FlankL", "FlankR", "DorsalL", "DorsalR")


# ---------- ATTACK_TENTACLE_STRIKE (2.4 s; impact at 1.05 s): coil, whip, recover; the body leans into the strike
def strike(t, p):
    f = t * 30.0
    P = rest_params()
    coil = K(f, [(0, 0), (22, 1), (29, 1.1), (36, 0)])             # wind-up peak just before 1.05 s (frame 31)
    whip = K(f, [(28, 0), (33, 1), (42, .8), (62, 0)])
    P["body"] = (0, -.9 * whip + .4 * coil, -.35 - .25 * coil + .15 * whip, -.06 * whip + .04 * coil, 0, 0)
    P["chest"] = (-.06 * coil + .12 * whip, 0)
    P["head"] = (-.1 * coil + .1 * whip, .1 * whip)
    P["maw"] = .5 * whip
    P["stalk"] = (-.3 * whip, -.2 * whip)

    def fn(g, i):
        if g in STRIKE_G:
            s = 1.0 if g.startswith("Flank") else .6
            return (s * (-.9 * coil / (1 + i * .1) + 1.0 * whip * (1 + .08 * i)), s * (.5 * math.sin(i * .8) * whip))
        return (.15 * whip, 0)
    P["tent"] = {"amp": 1.0, "w": TAU / 2.4, "t": t, "lag": .5, "bias": {}, "bias_fn": fn}
    return P


# ---------- ATTACK_HEAVY (3.4 s): it rears onto the hind legs' weight and slams the fore legs down (the ground-pound)
def heavy(t, p):
    f = t * 30.0
    P = rest_params()
    rise = K(f, [(0, 0), (30, 1), (48, 1), (58, 0), (102, 0)])
    slam = K(f, [(46, 0), (56, 1), (70, .15), (102, 0)])
    P["body"] = (0, .6 * rise - .3 * slam, -.35 + 1.0 * rise - .9 * slam, -.22 * rise + .1 * slam, 0, 0)
    P["chest"] = (-.1 * rise + .12 * slam, 0)
    P["head"] = (-.2 * rise + .3 * slam, 0)
    P["maw"] = .5 * rise
    tips = {l: tuple(TIP[l]) for l in TIP}
    for l in ("FL", "FR"):
        x, y, z = TIP[l]
        lift = K(f, [(0, 0), (30, 1), (48, 1), (56, 0), (102, 0)])
        tips[l] = (x, y + .5 * lift - .2 * slam, 5.5 * lift)
    P["tips"] = tips
    P["tent"] = {"amp": 1.3, "w": TAU / 3.4, "t": t, "lag": .55, "bias": {g: (.5 * rise - .3 * slam, 0) for g in GROUPS}}
    return P


def hit(t, p):
    f = t * 30.0
    P = rest_params()
    k = K(f, [(0, 0), (5, 1), (36, 0)])
    P["body"] = (0, .8 * k, -.35 - .3 * k, .09 * k, .06 * k, .05 * k)
    P["chest"] = (.1 * k, -.2 * k)
    P["head"] = (-.15 * k, .35 * k)
    P["maw"] = .5 * k
    P["stalk"] = (-.3 * k, .2 * k)
    P["tent"] = {"amp": 1.5, "w": TAU / 1.2, "t": t, "lag": .5, "bias": {g: (.5 * k, .3 * k) for g in GROUPS}}
    return P


def death(t, p):
    f = t * 30.0
    P = rest_params()
    c = K(f, [(0, 0), (30, .5), (70, 1), (135, 1)])
    P["body"] = (0, .6 * c, -.35 - 8.2 * c, .12 * c, .15 * c, .1 * c)
    P["chest"] = (.3 * c, -.2 * c)
    P["head"] = (.4 * c, .5 * c)
    P["maw"] = .6 * c
    P["stalk"] = (.4 * c, .5 * c)
    tips = {}
    for l in TIP:
        x, y, z = TIP[l]
        sx = -1 if x < 0 else 1
        tips[l] = (x + sx * 2.0 * c, y + (-1.5 if l[0] == "F" else 1.0) * c, 0.0)
    P["tips"] = tips
    sp = math.sin(f * .45) * K(f, [(80, 0), (90, 1), (115, 0), (135, 0)])
    P["tent"] = {"amp": 1.0 * (1 - .5 * c) + .6 * abs(sp), "w": TAU / 4.5, "t": t, "lag": .5, "bias": {g: (.5 * c, .6 * c) for g in GROUPS}}
    return P


for name, secs, fn in (("Idle_Breathe", 4.0, idle), ("Walk_Heavy", 4.0, walk_heavy), ("Walk_Fast", 2.0, walk_fast), ("Tentacles_Sway", 6.0, sway),
                       ("Alert", 2.4, alert), ("Attack_TentacleStrike", 2.4, strike), ("Attack_Heavy", 3.4, heavy), ("Hit_React", 1.2, hit),
                       ("Death_Collapse", 4.5, death)):
    new_clip(name, secs, fn)
bpy.ops.object.mode_set(mode='OBJECT')
bpy.context.scene.render.fps = FPS
bpy.ops.export_scene.gltf(filepath=os.path.abspath(OUT_GLB), export_format='GLB', export_animations=True, export_animation_mode='NLA_TRACKS',
                          export_force_sampling=True, export_yup=True, export_apply=False, export_skins=True, export_vertex_color='ACTIVE')
bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(OUT_BLEND))
print("DONE", [a.name for a in bpy.data.actions])
