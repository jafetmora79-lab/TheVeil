"""THE VEIL - Shellcrawler remaster (Blender 5.x).
   blender -b -P creatures/tools/build_shellcrawler_v2.py -- <out.glb> <out.blend>
Original CRT_Shellcrawler.glb stays untouched. Rig: the existing skeleton (8 three-joint legs, a grasping claw arm with 3 fingers, a sickle arm,
shell, sensor). Eight planted legs on a tetrapod gait (A: LA LC RB RD / B: LB LD RA RC) travelling sideways (left) or forward at the clips'
native speeds (0.536 / 0.363 m/s), a defensive crouch with crossed arms, a windup-lunge-grab attack, hit, death curl, twitching idle.
Mesh: shell spines and knee spurs, grime vertex colours."""
import bpy, sys, os, math, random
from mathutils import Matrix, Vector

OUT_GLB, OUT_BLEND = sys.argv[sys.argv.index("--") + 1], sys.argv[sys.argv.index("--") + 2]
SRC = "THE_VEIL_ASSETS_V2/07_Creatures/Shellcrawler/CRT_Shellcrawler.glb"
random.seed(9)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.abspath(SRC))
arm = bpy.data.objects["CRT_Shellcrawler"]
mesh = bpy.data.objects["CRT_Shellcrawler_Mesh"]
for o in list(bpy.data.objects):
    if o.name.startswith("Icosphere"):
        bpy.data.objects.remove(o)
if arm.animation_data:
    for t in list(arm.animation_data.nla_tracks):
        arm.animation_data.nla_tracks.remove(t)
    arm.animation_data.action = None
for act in list(bpy.data.actions):
    bpy.data.actions.remove(act)
vg = {g.index: g.name for g in mesh.vertex_groups}
me = mesh.data
LEGS = ["LA", "LB", "LC", "LD", "RA", "RB", "RC", "RD"]


def wt(v, name):
    for g in v.groups:
        if vg[g.group] == name:
            return g.weight
    return 0.0


# tips = the lowest vertex of each foot segment
TIP = {}
for l in LEGS:
    vs = [v for v in me.vertices if wt(v, f"Leg_{l}_Foot") > .5]
    low = min(vs, key=lambda v: v.co.z)
    TIP[l] = Vector((low.co.x, low.co.y, 0.0))
print("TIPS", {k: tuple(round(c, 2) for c in v) for k, v in TIP.items()})

# ---- mesh: shell spines + knee spurs, grime
import bmesh
bm = bmesh.new()
groups = []


def cone(pos, length, rad, direction, grp, seg=5):
    r = bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=rad, radius2=0.0, depth=length)
    v = r["verts"]
    bmesh.ops.translate(bm, vec=(0, 0, length / 2), verts=v)
    q = Vector((0, 0, 1)).rotation_difference(Vector(direction).normalized())
    bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=q.to_matrix(), verts=v)
    bmesh.ops.translate(bm, vec=pos, verts=v)
    groups.append((v, grp))


shell_vs = [v for v in me.vertices if wt(v, "Shell") > .5]
zmax = max(v.co.z for v in shell_vs)
for i, y in enumerate((-.35, -.1, .15, .4)):
    vs = [v for v in shell_vs if abs(v.co.y - y) < .08 and abs(v.co.x) < .12]
    if vs:
        top = max(vs, key=lambda v: v.co.z)
        cone((top.co.x, top.co.y, top.co.z - .02), .2 - i * .015, .045, (0, .25, 1), "Shell")
for side, sx in (("L", -1), ("R", 1)):
    for i, y in enumerate((-.25, .1, .38)):
        vs = [v for v in shell_vs if (v.co.x * sx) > .35 and abs(v.co.y - y) < .1]
        if vs:
            top = max(vs, key=lambda v: v.co.z)
            cone((top.co.x, top.co.y, top.co.z - .03), .15, .04, (sx * .8, 0, .6), "Shell")
for l in LEGS:
    h = arm.data.bones[f"Leg_{l}_Lower"].head_local
    sx = -1 if l[0] == "L" else 1
    cone((h.x, h.y, h.z), .12, .025, (sx * .5, 0, .8), f"Leg_{l}_Lower")
fm = bpy.data.meshes.new("Spines")
bm.to_mesh(fm)
fobj = bpy.data.objects.new("Spines", fm)
bpy.context.scene.collection.objects.link(fobj)
for verts, grp in groups:
    if grp not in fobj.vertex_groups:
        fobj.vertex_groups.new(name=grp)
    fobj.vertex_groups[grp].add([v.index for v in verts], 1.0, 'REPLACE')
bm.free()
bone_mat = bpy.data.materials.new("M_Shellcrawler_Bone")
bone_mat.use_nodes = True
bone_mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (.36, .31, .24, 1)
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
    if v.co.z < .15:
        g *= .7
    if v.co.z < .45 and abs(v.co.x) < .5:
        g *= .85
    col.data[i].color = (g, g, g, 1)
nt = me.materials[0].node_tree
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

# ---- rig
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
    D = {"Root": Matrix.Identity(4)}
    dx, dy, dz, bp, br, byw = P["body"]
    h = head["Body"]
    D["Body"] = Matrix.Translation((dx, dy, dz)) @ rot_axis(h, 'Z', byw) @ rot_axis(h, 'Y', br) @ rot_axis(h, 'X', bp)
    Db = D["Body"]
    D["Shell"] = Db @ rot_axis(head["Shell"], 'X', P["shell"])
    D["Sensor"] = Db @ rot_axis(head["Sensor"], 'Z', P["sensor"][1]) @ rot_axis(head["Sensor"], 'X', P["sensor"][0])
    # grasping claw arm (left): upper pitch/yaw, lower pitch, hand pitch, fingers curl
    aL = P["armL"]
    D["GraspL_Upper"] = Db @ rot_axis(head["GraspL_Upper"], 'Z', aL[1]) @ rot_axis(head["GraspL_Upper"], 'X', aL[0])
    D["GraspL_Lower"] = D["GraspL_Upper"] @ rot_axis(head["GraspL_Lower"], 'X', aL[2])
    D["GraspL_Hand"] = D["GraspL_Lower"] @ rot_axis(head["GraspL_Hand"], 'X', aL[3])
    for i, fn in enumerate(("F1", "F2", "F3")):
        D[f"GraspL_{fn}"] = D["GraspL_Hand"] @ rot_axis(head[f"GraspL_{fn}"], 'X', aL[4]) @ rot_axis(head[f"GraspL_{fn}"], 'Z', (i - 1) * .15 * aL[4])
    aR = P["armR"]
    D["GraspR_Upper"] = Db @ rot_axis(head["GraspR_Upper"], 'Z', aR[1]) @ rot_axis(head["GraspR_Upper"], 'X', aR[0])
    D["GraspR_Lower"] = D["GraspR_Upper"] @ rot_axis(head["GraspR_Lower"], 'X', aR[2])
    D["GraspR_Sickle"] = D["GraspR_Lower"] @ rot_axis(head["GraspR_Sickle"], 'Z', aR[3]) @ rot_axis(head["GraspR_Sickle"], 'X', aR[4])
    Dbi = Db.inverted()
    for leg in LEGS:
        up, lo, ft = (f"Leg_{leg}_{s}" for s in ("Upper", "Lower", "Foot"))
        A, B, C, T = head[up], head[lo], head[ft], TIP[leg]
        Pl = Dbi @ Vector(P["tips"][leg])
        phi_r = math.atan2(T.y - A.y, T.x - A.x)
        phi_p = math.atan2(Pl.y - A.y, Pl.x - A.x)
        dphi = (phi_p - phi_r + math.pi) % (2 * math.pi) - math.pi
        Bp = A + Matrix.Rotation(dphi, 3, 'Z') @ (B - A)
        u = Vector((math.cos(phi_p), math.sin(phi_p), 0))
        rB, zB = (Bp - A).dot(u), Bp.z
        rP, zP = (Pl - A).dot(u), Pl.z
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
        ax_rest = Vector((math.sin(phi_r), -math.cos(phi_r), 0))
        D[up] = Db @ rot_vec(A, (0, 0, 1), dphi)
        th2 = a2 - a2r
        D[lo] = D[up] @ rot_vec(B, ax_rest, th2)
        D[ft] = D[lo] @ rot_vec(C, ax_rest, (a3 - a3r) - th2)
    return D


def basis_for(name, D):
    b = arm.data.bones[name]
    Dp = D[b.parent.name] if b.parent else Matrix.Identity(4)
    return rest[name].inverted() @ Dp.inverted() @ D[name] @ rest[name]


def rest_params():
    return {"body": (0, 0, 0, 0, 0, 0), "shell": 0, "sensor": (0, 0), "armL": [0, 0, 0, 0, 0], "armR": [0, 0, 0, 0, 0],
            "tips": {l: tuple(TIP[l]) for l in LEGS}}


test = solve(rest_params())
err = 0
for n in test:
    m = basis_for(n, test)
    err = max(err, max(abs(c - (1.0 if i == j else 0.0)) for i, r in enumerate(m) for j, c in enumerate(r)))
print("REST SELFTEST max basis error", round(err, 5), "bones", len(test), "of", len(bones))


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
GROUP_A = ("LA", "LC", "RB", "RD")


def step(leg, phase, duty, stride, lift, d):
    """body travels along unit vector d: a planted foot slides -d relative to the body, a swinging foot arcs forward (+d)"""
    t = TIP[leg]
    p = phase % 1.0
    if p < duty:
        off = stride / 2 - stride * (p / duty)
        z = 0.0
    else:
        q = (p - duty) / (1 - duty)
        off = -stride / 2 + stride * smooth(q)
        z = lift * math.sin(math.pi * q) ** .8
    return (t.x + d.x * off, t.y + d.y * off, z)


def crawl(f, N, T, speed, d, duty=.55, lift=.12):
    p = f / N
    P = rest_params()
    stride = speed * T * duty
    P["tips"] = {l: step(l, p if l in GROUP_A else p + .5, duty, stride, lift, d) for l in LEGS}
    P["body"] = (0, 0, -.02 + .012 * math.cos(2 * TAU * p), .015 * math.sin(2 * TAU * p), .035 * math.sin(TAU * p), .03 * math.sin(TAU * p))
    P["shell"] = .02 * math.sin(2 * TAU * p + .5)
    P["sensor"] = (.1 * math.sin(2 * TAU * p), .35 * math.sin(TAU * p))
    P["armL"] = [-.12 + .05 * math.sin(TAU * p), .15, .1 * math.sin(TAU * p + 1), 0, .5 + .35 * math.sin(2 * TAU * p)]
    P["armR"] = [-.1 + .05 * math.sin(TAU * p + 1), -.1, .08 * math.sin(TAU * p), .15 * math.sin(TAU * p), 0]
    return P


def crawl_side(f):
    return crawl(f, 34, 34 / 30, .536, Vector((-1, 0, 0)))


def crawl_fwd(f):
    return crawl(f, 38, 38 / 30, .363, Vector((0, -1, 0)), lift=.1)


def idle(f):
    p = f / 72
    br = math.sin(TAU * 2 * p)
    P = rest_params()
    snap = math.exp(-((p - .6) / .03) ** 2)
    P["body"] = (0, 0, -.015 + .008 * br, .008 * br, .01 * math.sin(TAU * p), .03 * snap)
    P["shell"] = .02 * br
    P["sensor"] = (.12 * math.sin(TAU * 3 * p) + .2 * snap, .4 * math.sin(TAU * p) + .5 * snap)
    P["armL"] = [-.1, .15 + .05 * math.sin(TAU * p), .05, 0, .45 + .4 * max(0, math.sin(TAU * 3 * p))]
    P["armR"] = [-.1, -.1, .04, .1 * math.sin(TAU * 2 * p), 0]
    tips = {l: tuple(TIP[l]) for l in LEGS}
    tap = K(f, [(14, 0), (17, 1), (20, 0), (23, 1), (26, 0), (200, 0)]) if f < 27 else 0
    x, y, z = TIP["LB"]
    tips["LB"] = (x - .1 * tap, y, .12 * tap)
    tap2 = K(f, [(44, 0), (47, 1), (50, 0), (200, 0)]) if 43 < f < 51 else 0
    x, y, z = TIP["RC"]
    tips["RC"] = (x + .08 * tap2, y + .06 * tap2, .1 * tap2)
    P["tips"] = tips
    return P


def defend(f):
    P = rest_params()
    e = K(f, [(0, 0), (8, 1), (30, 1), (37, .95)])
    P["body"] = (0, .1 * e, -.2 * e, .1 * e, 0, 0)
    P["shell"] = -.25 * e
    P["sensor"] = (.3 * e, 0)
    P["armL"] = [-.9 * e, -.35 * e, .9 * e, .2, 1.1 * e]
    P["armR"] = [-.85 * e, .4 * e, .8 * e, -.4 * e, .3 * e]
    tips = {}
    for l in LEGS:
        x, y, z = TIP[l]
        tips[l] = (x * (1 + .12 * e), y, 0.0)
    P["tips"] = tips
    return P


def grasp(f):
    P = rest_params()
    wind = K(f, [(0, 0), (9, 1), (11, 1), (13, 0), (38, 0)])
    strike = K(f, [(9, 0), (14, 1), (19, 1), (28, 0)])
    P["body"] = (0, .16 * wind - .42 * strike, -.04 * wind - .02 * strike, -.06 * wind + .08 * strike, 0, .05 * strike)
    P["shell"] = .1 * wind
    P["sensor"] = (-.2 * strike, 0)
    close = K(f, [(0, 0), (9, 0), (15, 0), (18, 1.2), (24, 1.2), (30, .3), (38, 0)])
    P["armL"] = [-.1 + .5 * wind - 1.0 * strike, .5 * wind - .1 * strike, .3 * wind - .5 * strike, 0, close]
    P["armR"] = [-.1 + .4 * wind - .9 * strike, -.45 * wind + .5 * strike, .3 * wind - .4 * strike, -.6 * strike, .4 * strike]
    tips = {l: list(TIP[l]) for l in LEGS}
    for l in LEGS:
        tips[l][1] += .0
    P["tips"] = {l: tuple(v) for l, v in tips.items()}
    return P


def hit(f):
    P = rest_params()
    k = K(f, [(0, 0), (3, 1), (18, 0)])
    P["body"] = (0, .16 * k, -.06 * k, -.12 * k, .08 * k, .1 * k)
    P["shell"] = .2 * k
    P["sensor"] = (-.3 * k, .5 * k)
    P["armL"] = [.3 * k, .3 * k, .2 * k, 0, .9 * k]
    P["armR"] = [.2 * k, -.3 * k, .2 * k, .3 * k, 0]
    tips = {l: list(TIP[l]) for l in LEGS}
    for l in LEGS:
        sx = -1 if l[0] == "L" else 1
        tips[l][0] += sx * .1 * k
    P["tips"] = {l: tuple(v) for l, v in tips.items()}
    return P


def death(f):
    P = rest_params()
    c = K(f, [(0, 0), (14, .6), (30, 1), (52, 1)])
    P["body"] = (0, 0, -.3 * c, .18 * c, .12 * c, 0)
    P["shell"] = .3 * c
    P["sensor"] = (.5 * c, .6 * c)
    P["armL"] = [.5 * c, .6 * c, .5 * c, 0, .2 * c]
    P["armR"] = [.4 * c, -.6 * c, .4 * c, .5 * c, 0]
    sp = math.sin((f - 36) * 2.4) * K(f, [(35, 0), (37, 1), (44, 0), (52, 0)]) if 35 <= f <= 45 else 0
    tips = {}
    for l in LEGS:
        sx = -1 if l[0] == "L" else 1
        x, y, z = TIP[l]
        tips[l] = (x + (sx * .55 - x) * c, y * (1 - .4 * c), .45 * c + .05 * sp)
    P["tips"] = tips
    return P


for name, n, fn in (("Idle", 72, idle), ("Crawl_Sideways", 34, crawl_side), ("Crawl_Forward", 38, crawl_fwd), ("Defend", 38, defend),
                    ("Attack_Grasp", 38, grasp), ("Hit_React", 19, hit), ("Death", 53, death)):
    new_clip(name, n, fn)
bpy.ops.object.mode_set(mode='OBJECT')
bpy.context.scene.render.fps = FPS
bpy.ops.export_scene.gltf(filepath=os.path.abspath(OUT_GLB), export_format='GLB', export_animations=True, export_animation_mode='NLA_TRACKS',
                          export_force_sampling=True, export_yup=True, export_apply=False, export_skins=True, export_vertex_color='ACTIVE')
bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(OUT_BLEND))
print("DONE", [a.name for a in bpy.data.actions])
