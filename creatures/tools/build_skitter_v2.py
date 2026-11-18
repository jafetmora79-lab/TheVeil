"""THE VEIL - Skitter remaster (Blender 5.x).
   blender -b -P creatures/tools/build_skitter_v2.py -- <out.glb> <out.blend>
Starts from the original CRT_Skitter.glb (untouched in THE_VEIL_ASSETS_V2). Mesh: dorsal thorns, knee spurs, grime vertex colours.
Rig: the existing 33-bone skeleton. Six legs = three-joint zigzag in a vertical plane each; a 3D solver swings the plane to the foot target
(azimuth about Z), then 2-bone IK in the plane. Tripod gaits with planted feet, alert/hiss rear-up, windup-leap, hit, death, twitchy idle."""
import bpy, sys, os, math, random
from mathutils import Matrix, Vector

OUT_GLB, OUT_BLEND = sys.argv[sys.argv.index("--") + 1], sys.argv[sys.argv.index("--") + 2]
SRC = "THE_VEIL_ASSETS_V2/07_Creatures/Skitter/CRT_Skitter.glb"
random.seed(5)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.abspath(SRC))
arm = bpy.data.objects["CRT_Skitter"]
mesh = bpy.data.objects["CRT_Skitter_Mesh"]
for o in list(bpy.data.objects):
    if o.name.startswith("Icosphere"):
        bpy.data.objects.remove(o)
if arm.animation_data:
    for t in list(arm.animation_data.nla_tracks):
        arm.animation_data.nla_tracks.remove(t)
    arm.animation_data.action = None
for act in list(bpy.data.actions):
    bpy.data.actions.remove(act)

# ------------------------------------------------------------------------------------------------ mesh
vg = {g.index: g.name for g in mesh.vertex_groups}
me = mesh.data


def wt(v, name):
    for g in v.groups:
        if vg[g.group] == name:
            return g.weight
    return 0.0


import bmesh
bm = bmesh.new()
groups = []


def cone(pos, length, rad, direction, grp, seg=5):
    r = bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=rad, radius2=0.0, depth=length)
    v = r["verts"]
    bmesh.ops.translate(bm, vec=(0, 0, length / 2), verts=v)
    d = Vector(direction).normalized()
    q = Vector((0, 0, 1)).rotation_difference(d)
    bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=q.to_matrix(), verts=v)
    bmesh.ops.translate(bm, vec=pos, verts=v)
    groups.append((v, grp))


# dorsal thorns on the thorax / abdomen: top of the shell sampled from the mesh
for grp, y0, y1, n in (("Body", -0.30, 0.15, 3), ("Abdomen_01", 0.25, 0.55, 3), ("Abdomen_02", 0.58, 0.8, 2)):
    for i in range(n):
        y = y0 + (y1 - y0) * (i + .5) / n
        vs = [v for v in me.vertices if abs(v.co.y - y) < .06 and abs(v.co.x) < .1 and wt(v, grp) > .3]
        if vs:
            top = max(vs, key=lambda v: v.co.z)
            cone((top.co.x, top.co.y, top.co.z - .01), .16 - i * .02, .03, (0, .35, 1), grp)
# knee spurs: a hooked spike at every low joint (Lower head) and a longer one on the front pair
for leg in ("L1", "L2", "L3", "R1", "R2", "R3"):
    b = arm.data.bones[f"Leg_{leg}_Lower"]
    h = b.head_local
    sx = -1 if leg[0] == "L" else 1
    cone((h.x, h.y, h.z), .16 if leg[1] == "1" else .1, .028, (sx * .6, 0, -.6) if leg[1] != "1" else (sx * .4, -.5, -.3), f"Leg_{leg}_Lower")
fm = bpy.data.meshes.new("Thorns")
bm.to_mesh(fm)
fobj = bpy.data.objects.new("Thorns", fm)
bpy.context.scene.collection.objects.link(fobj)
for verts, grp in groups:
    if grp not in fobj.vertex_groups:
        fobj.vertex_groups.new(name=grp)
    fobj.vertex_groups[grp].add([v.index for v in verts], 1.0, 'REPLACE')
bm.free()
bone_mat = bpy.data.materials.new("M_Skitter_Bone")
bone_mat.use_nodes = True
bone_mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (.30, .27, .22, 1)
bone_mat.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = .9
fobj.data.materials.append(bone_mat)
bpy.ops.object.select_all(action='DESELECT')
mesh.select_set(True)
fobj.select_set(True)
bpy.context.view_layer.objects.active = mesh
bpy.ops.object.join()
mesh = bpy.context.view_layer.objects.active
me = mesh.data
col = me.color_attributes.new("Col", 'BYTE_COLOR', 'POINT')
for i, v in enumerate(me.vertices):
    g = .86 + .14 * random.random()
    if v.co.z < .12:
        g *= .72                              # dirt on the tarsi
    if abs(v.co.x) < .18 and v.co.z < .42:
        g *= .85
    col.data[i].color = (g, g, g, 1)
mat0 = me.materials[0]
nt = mat0.node_tree
bsdf = nt.nodes["Principled BSDF"]
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

# ------------------------------------------------------------------------------------------------ rig maths
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
FPS = 30
TIP = {"L1": Vector((-.80, -.86, 0)), "L2": Vector((-1.0, -.10, 0)), "L3": Vector((-.80, .84, 0)),
       "R1": Vector((.84, -.80, 0)), "R2": Vector((.96, -.04, 0)), "R3": Vector((.74, .80, 0))}
LEGN = list(TIP)


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


def rot_axis(h, axis, th):
    return Matrix.Translation(h) @ Matrix.Rotation(th, 4, axis) @ Matrix.Translation(-h)


def rot_vec(h, axis_vec, th):
    return Matrix.Translation(h) @ Matrix.Rotation(th, 4, Vector(axis_vec)) @ Matrix.Translation(-h)


def solve(P):
    """P: body=(dx,dy,dz, pitch(x), roll(y), yaw(z)), head=(pitch,yaw), mand=spread, ant=[pitch],[yaw], abd=[p1,p2,yaw], tips={leg:(x,y,z) world target}
    World = armature space. Returns {bone: deformation D}."""
    D = {"Root": Matrix.Identity(4)}
    dx, dy, dz, bp, br, byw = P["body"]
    h = head["Body"]
    D["Body"] = Matrix.Translation((dx, dy, dz)) @ rot_axis(h, 'Z', byw) @ rot_axis(h, 'Y', br) @ rot_axis(h, 'X', bp)
    Db = D["Body"]

    def child(name, parent, axis, th):
        D[name] = D[parent] @ rot_axis(head[name], axis, th)
    D["Head"] = D["Body"] @ rot_axis(head["Head"], 'Z', P["head"][1]) @ rot_axis(head["Head"], 'X', P["head"][0])
    D["Mandible_L"] = D["Head"] @ rot_axis(head["Mandible_L"], 'Z', P["mand"])
    D["Mandible_R"] = D["Head"] @ rot_axis(head["Mandible_R"], 'Z', -P["mand"])
    for s, sg in (("L", 1), ("R", -1)):
        prev = "Head"
        for i in (1, 2, 3):
            n = f"Antenna_{s}_0{i}"
            D[n] = D[prev] @ rot_axis(head[n], 'X', P["ant"][i - 1][0]) @ rot_axis(head[n], 'Z', P["ant"][i - 1][1] * sg)
            prev = n
    D["Abdomen_01"] = D["Body"] @ rot_axis(head["Abdomen_01"], 'Z', P["abd"][2]) @ rot_axis(head["Abdomen_01"], 'X', P["abd"][0])
    D["Abdomen_02"] = D["Abdomen_01"] @ rot_axis(head["Abdomen_02"], 'Z', P["abd"][2] * .6) @ rot_axis(head["Abdomen_02"], 'X', P["abd"][1])
    Dbi = Db.inverted()
    for leg in LEGN:
        up, lo, ft = (f"Leg_{leg}_{s}" for s in ("Upper", "Lower", "Foot"))
        A, B, C, T = head[up], head[lo], head[ft], TIP[leg]
        Pw = Vector(P["tips"][leg])
        Pl = Dbi @ Pw                                     # target in the body's rest frame
        phi_r = math.atan2(T.y - A.y, T.x - A.x)
        phi_p = math.atan2(Pl.y - A.y, Pl.x - A.x)
        dphi = (phi_p - phi_r + math.pi) % (2 * math.pi) - math.pi
        Rz = Matrix.Rotation(dphi, 3, 'Z')
        Bp = A + Rz @ (B - A)
        u = Vector((math.cos(phi_p), math.sin(phi_p), 0))
        rB, zB = (Bp - A).dot(u), Bp.z
        rP, zP = (Pl - A).dot(u), Pl.z
        # segment lengths and rest in-plane angles
        d2, d3 = C - B, T - C
        L2, L3 = d2.length, d3.length
        a2r = math.atan2(d2.z, math.hypot(d2.x, d2.y))
        a3r = math.atan2(d3.z, math.hypot(d3.x, d3.y))
        v = Vector((rP - rB, zP - zB))
        dist = max(abs(L2 - L3) + .02, min(L2 + L3 - .005, v.length))
        beta = math.atan2(v.y, v.x)
        gam = math.acos(max(-1, min(1, (L2 * L2 + dist * dist - L3 * L3) / (2 * L2 * dist))))
        best = None
        for sg in (1, -1):
            a2 = beta + sg * gam
            Cz = zB + L2 * math.sin(a2)
            if best is None or Cz > best[1]:
                best = (a2, Cz)
        a2 = best[0]
        Cp = Vector((rB + L2 * math.cos(a2), zB + L2 * math.sin(a2)))
        k = dist / max(v.length, 1e-6)
        Tt = Vector((rB + (rP - rB) * k, zB + (zP - zB) * k))
        a3 = math.atan2(Tt.y - Cp.y, Tt.x - Cp.x)
        ax_rest = Vector((math.sin(phi_r), -math.cos(phi_r), 0))      # rotation axis that lifts the plane's r towards +Z
        D[up] = Db @ rot_vec(A, (0, 0, 1), dphi)
        th2 = a2 - a2r
        D[lo] = D[up] @ rot_vec(B, ax_rest, th2)
        th3 = (a3 - a3r) - th2
        D[ft] = D[lo] @ rot_vec(C, ax_rest, th3)
    return D


def basis_for(name, D):
    b = arm.data.bones[name]
    Dp = D[b.parent.name] if b.parent else Matrix.Identity(4)
    return rest[name].inverted() @ Dp.inverted() @ D[name] @ rest[name]


def rest_params():
    return {"body": (0, 0, 0, 0, 0, 0), "head": (0, 0), "mand": 0, "ant": [(0, 0)] * 3, "abd": [0, 0, 0],
            "tips": {l: tuple(TIP[l]) for l in LEGN}}


test = solve(rest_params())
err = 0
for n in test:
    m = basis_for(n, test)
    err = max(err, max(abs(c - (1.0 if i == j else 0.0)) for i, r in enumerate(m) for j, c in enumerate(r)))
print("REST SELFTEST max basis error", round(err, 5), "bones", len(test), "of", len(bones))

TRIPOD_A = ("L1", "R2", "L3")


def step(leg, phase, duty, stride, lift, yoff=0.0):
    """tip target for one leg: stance slides backward (+Y) by `stride`, swing arcs forward"""
    t = TIP[leg]
    p = phase % 1.0
    if p < duty:
        y = t.y - stride / 2 + stride * (p / duty)
        z = 0.0
    else:
        q = (p - duty) / (1 - duty)
        y = t.y + stride / 2 - stride * smooth(q)
        z = lift * math.sin(math.pi * q) ** .8
    return (t.x, y + yoff, z)


def new_clip(name, nframes, fn):
    act = bpy.data.actions.new(name)
    arm.animation_data_create()
    arm.animation_data.action = act
    for f in range(nframes):
        D = solve(fn(f))
        for n in order:
            pb = arm.pose.bones[n]
            pb.rotation_mode = 'QUATERNION'
            m = basis_for(n, D) if n in D else Matrix.Identity(4)
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
    print("CLIP", name, nframes)


TAU = 2 * math.pi


def gait(f, N, T, speed, duty, lift, gate=None, amp=1.0):
    p = f / N
    P = rest_params()
    stride = speed * T * duty
    tips = {}
    for leg in LEGN:
        ph = p if leg in TRIPOD_A else p + .5
        tips[leg] = step(leg, ph, duty, stride * amp, lift)
    P["tips"] = tips
    return P, p


# ---------- IDLE_TWITCH (3 s loop): breathing abdomen, antennae flicks, mandible clicks, a tapping leg, one head snap
def idle(f):
    p = f / 90
    P = rest_params()
    br = math.sin(TAU * 3 * p)
    snap = math.exp(-((p - .62) / .02) ** 2)
    P["body"] = (0, 0, -.012 + .006 * br, .01 * br, .01 * math.sin(TAU * p), .03 * snap)
    P["head"] = (.05 * snap - .03 * math.sin(TAU * p), .35 * snap + .08 * math.sin(TAU * 2 * p))
    P["mand"] = .08 + .1 * max(0, math.sin(TAU * 5 * p)) ** 6 * 1.0 + .25 * snap
    P["ant"] = [(.1 * math.sin(TAU * 2 * p + i), .18 * math.sin(TAU * 3 * p + i * .7) + .3 * snap) for i in range(3)]
    P["abd"] = [.04 * br, .06 * br, .05 * math.sin(TAU * p)]
    tips = {l: tuple(TIP[l]) for l in LEGN}
    tap = K(f * 1.0, [(18, 0), (21, 1), (24, 0), (27, 1), (30, 0), (500, 0)]) if f < 31 else 0
    x, y, z = TIP["L2"]
    tips["L2"] = (x + .06 * tap, y - .04 * tap, .16 * tap)
    tap2 = K(f, [(55, 0), (58, 1), (61, 0), (64, 1), (67, 0), (500, 0)]) if 54 < f < 68 else 0
    x, y, z = TIP["R3"]
    tips["R3"] = (x - .05 * tap2, y - .05 * tap2, .14 * tap2)
    P["tips"] = tips
    return P


# ---------- CRAWL (1.2 s loop, 0.472 m/s): slow tripod creep, body swaying, antennae probing, deliberate pauses in the abdomen
def crawl(f):
    P, p = gait(f, 36, 1.2, .472, .62, .14)
    P["body"] = (.02 * math.sin(TAU * p), 0, -.03 + .012 * math.cos(2 * TAU * p), .02 * math.sin(2 * TAU * p), .04 * math.sin(TAU * p), .05 * math.sin(TAU * p))
    P["head"] = (.06 + .03 * math.sin(TAU * p + 1), .15 * math.sin(TAU * p + .5))
    P["mand"] = .1 + .06 * math.sin(TAU * 2 * p)
    P["ant"] = [(.12 * math.sin(TAU * p + i * .6), .2 * math.sin(TAU * p + i * .6 + 1.2)) for i in range(3)]
    P["abd"] = [.05 * math.sin(TAU * p), .08 * math.sin(TAU * p - .6), .06 * math.sin(TAU * p)]
    return P


# ---------- SCUTTLE_FAST (0.34 s loop, 2.588 m/s): tripod sprint, flat low body, abdomen raised, legs blurring
def scuttle(f):
    P, p = gait(f, 10, .34, 2.588, .5, .15)
    P["body"] = (.0, 0, -.07 + .012 * math.cos(2 * TAU * p), -.1, .05 * math.sin(TAU * p), .07 * math.sin(TAU * p))
    P["head"] = (.1, .12 * math.sin(TAU * p))
    P["mand"] = .3
    P["ant"] = [(-.35 - .05 * i, .3 + .1 * math.sin(TAU * 2 * p + i)) for i in range(3)]
    P["abd"] = [-.22, -.3, .1 * math.sin(TAU * p)]
    return P


# ---------- ALERT / HISS (1.2 s, once): rears on four hind legs, front pair thrown up and apart, mandibles wide, abdomen curled forward, trembling
def alert(f):
    P = rest_params()
    e = K(f, [(0, 0), (9, 1), (35, 1)])
    trem = math.sin(f * 2.3) * .015 * K(f, [(8, 0), (11, 1), (35, 1)])
    P["body"] = (0, .06 * e, -.02 + .10 * e, -.38 * e + trem, .03 * math.sin(f * .9) * e, .0)
    P["head"] = (.18 * e, .08 * math.sin(f * 1.3) * e)
    P["mand"] = .55 * e + .06 * math.sin(f * 2.5) * e
    P["ant"] = [(-.2 * e, .45 * e), (-.1 * e, .6 * e), (0, .5 * e)]
    P["abd"] = [.25 * e, .35 * e + trem * 2, .08 * math.sin(f * .7) * e]
    tips = {l: tuple(TIP[l]) for l in LEGN}
    for l, sx in (("L1", -1), ("R1", 1)):
        x, y, z = TIP[l]
        tips[l] = (x + sx * .18 * e, y - .30 * e, .95 * e + .05 * trem * 10)
    for l in ("L2", "R2"):
        x, y, z = TIP[l]
        tips[l] = (x, y + .04 * e, 0.0)
    P["tips"] = tips
    return P


# ---------- ATTACK_LUNGE (1.0 s, once): 5-frame coil, launch, airborne with front legs hooked forward, landing compression, recovery
def lunge(f):
    P = rest_params()
    dz = K(f, [(0, 0), (5, -.13), (8, .10), (14, .16), (17, -.15), (21, -.04), (30, 0)])
    dy = K(f, [(0, 0), (5, .06), (8, -.12), (14, -.30), (17, -.12), (22, -.03), (30, 0)])
    pit = K(f, [(0, 0), (5, .10), (8, -.28), (14, -.12), (17, .10), (22, 0), (30, 0)])
    P["body"] = (0, dy, dz, pit, 0, 0)
    P["head"] = (K(f, [(0, 0), (8, -.15), (14, .2), (30, 0)]), 0)
    P["mand"] = K(f, [(0, .05), (5, .1), (11, .65), (15, .7), (17, .0), (22, .05), (30, .05)])
    P["ant"] = [(K(f, [(0, 0), (8, -.45), (20, 0)]), 0)] * 3
    P["abd"] = [K(f, [(0, 0), (5, .18), (10, -.2), (22, 0)]), K(f, [(0, 0), (6, .3), (11, -.3), (22, 0)]), 0]
    air = K(f, [(0, 0), (6, 0), (9, 1), (14, 1), (16.5, 0), (30, 0)])
    tips = {l: list(TIP[l]) for l in LEGN}
    for l in LEGN:
        x, y, z = TIP[l]
        sx = -1 if l[0] == "L" else 1
        if l[1] == "1":           # front pair: hooks forward and up
            tips[l] = [x + sx * (-.18) * air, y - .55 * air, .55 * air]
        else:                     # rear legs trail and tuck
            tips[l] = [x * (1 - .25 * air), y + .12 * air, .32 * air]
    P["tips"] = {l: tuple(v) for l, v in tips.items()}
    return P


# ---------- HIT_REACT (0.6 s): flung back, legs splay, hiss
def hit(f):
    P = rest_params()
    P["body"] = (0, K(f, [(0, 0), (3, .16), (17, 0)]), K(f, [(0, 0), (3, -.05), (17, 0)]), K(f, [(0, 0), (3, -.22), (10, -.05), (17, 0)]),
                 K(f, [(0, 0), (3, .12), (17, 0)]), K(f, [(0, 0), (3, .15), (17, 0)]))
    P["head"] = (K(f, [(0, 0), (3, -.2), (17, 0)]), K(f, [(0, 0), (3, .3), (17, 0)]))
    P["mand"] = K(f, [(0, .05), (3, .6), (17, .05)])
    P["ant"] = [(K(f, [(0, 0), (3, -.4), (17, 0)]), K(f, [(0, 0), (3, .5), (17, 0)]))] * 3
    P["abd"] = [K(f, [(0, 0), (3, .3), (17, 0)])] * 2 + [0]
    tips = {l: list(TIP[l]) for l in LEGN}
    for l in LEGN:
        sx = -1 if l[0] == "L" else 1
        tips[l][0] += sx * .12 * K(f, [(0, 0), (3, 1), (15, 0)])
        tips[l][1] += .1 * K(f, [(0, 0), (3, 1), (15, 0)])
    P["tips"] = {l: tuple(v) for l, v in tips.items()}
    return P


# ---------- DEATH (1.6 s): flips its balance, legs curl up over the body, shell drops, mandibles slack, last spasm
def death(f):
    P = rest_params()
    c = K(f, [(0, 0), (12, .55), (26, 1), (47, 1)])
    P["body"] = (0, 0, -.2 * c, K(f, [(0, 0), (10, -.12), (26, .06)]), K(f, [(0, 0), (8, .2), (26, .12)]), 0)
    P["head"] = (.25 * c, .3 * c)
    P["mand"] = .5 * c
    P["ant"] = [(-.3 * c, .4 * c)] * 3
    P["abd"] = [.3 * c, .4 * c, .1 * c]
    sp = math.sin((f - 32) * 2.4) * K(f, [(31, 0), (33, 1), (40, 0), (47, 0)]) if 31 <= f <= 41 else 0
    tips = {l: list(TIP[l]) for l in LEGN}
    for l in LEGN:
        sx = -1 if l[0] == "L" else 1
        x, y, z = TIP[l]
        yy = {"1": -.35, "2": 0, "3": .35}[l[1]]
        tips[l] = [x + (sx * .38 - x) * c, y + (yy - y) * c * .8, .55 * c + .06 * sp]
    P["tips"] = {l: tuple(v) for l, v in tips.items()}
    P["mand"] = .5 * c + .1 * abs(sp)
    return P


for name, n, fn in (("Idle_Twitch", 90, idle), ("Crawl", 36, crawl), ("Scuttle_Fast", 10, scuttle), ("Alert", 36, alert),
                    ("Attack_Lunge", 30, lunge), ("Hit_React", 18, hit), ("Death", 48, death)):
    new_clip(name, n, fn)
bpy.ops.object.mode_set(mode='OBJECT')
bpy.context.scene.render.fps = FPS
bpy.ops.export_scene.gltf(filepath=os.path.abspath(OUT_GLB), export_format='GLB', export_animations=True, export_animation_mode='NLA_TRACKS',
                          export_force_sampling=True, export_yup=True, export_apply=False, export_skins=True, export_vertex_color='ACTIVE')
bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(OUT_BLEND))
print("DONE", [a.name for a in bpy.data.actions])
