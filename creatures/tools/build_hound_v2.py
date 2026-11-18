"""THE VEIL - Hound remaster (Blender 5.x).
   blender -b -P creatures/tools/build_hound_v2.py -- <out.glb> <out.blend>
Starts from the original CRT_Hound.glb (left untouched in THE_VEIL_ASSETS_V2), refines the mesh (haunch, chest, fangs, grime vertex colours)
and authors NEW skeletal clips on the existing 24-bone rig: planar FK/IK gaits (feet planted in stance, stride = speed x time x duty),
spinal gather/extension, uneven trot, stalking walk, windup-lunge bite, alert, hit, death. Same clip names as before (+ Trot)."""
import bpy, sys, os, math, random
from mathutils import Matrix, Vector

OUT_GLB, OUT_BLEND = sys.argv[sys.argv.index("--") + 1], sys.argv[sys.argv.index("--") + 2]
SRC = "THE_VEIL_ASSETS_V2/07_Creatures/Hounds/CRT_Hound.glb"
random.seed(11)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.abspath(SRC))
arm = bpy.data.objects["CRT_Hound"]
mesh = bpy.data.objects["CRT_Hound_Mesh"]
for o in list(bpy.data.objects):
    if o.name.startswith("Icosphere"):
        bpy.data.objects.remove(o)
if arm.animation_data:
    for t in list(arm.animation_data.nla_tracks):
        arm.animation_data.nla_tracks.remove(t)
    arm.animation_data.action = None
for act in list(bpy.data.actions):
    bpy.data.actions.remove(act)

# ----------------------------------------------------------------------------------------------------------- mesh
vg = {g.index: g.name for g in mesh.vertex_groups}
me = mesh.data


def wt(v, name):
    for g in v.groups:
        if vg[g.group] == name:
            return g.weight
    return 0.0


def wsum(v, names):
    return sum(wt(v, n) for n in names)


# haunches: heavier hind thighs (about each thigh's own centroid), chest deeper and a touch wider
for side in ("HL", "HR"):
    vs = [v for v in me.vertices if wt(v, f"Leg_{side}_Upper") > 0.55]
    if vs:
        c = sum((v.co for v in vs), Vector()) / len(vs)
        for v in vs:
            w = min(1.0, wt(v, f"Leg_{side}_Upper") * 1.3)
            d = v.co - c
            v.co = c + Vector((d.x * (1 + .22 * w), d.y * (1 + .18 * w), d.z * (1 + .04 * w)))
vs = [v for v in me.vertices if wsum(v, ("Chest", "Spine2")) > 0.5]
cz = sum(v.co.z for v in vs) / len(vs)
for v in vs:
    w = wsum(v, ("Chest", "Spine2"))
    v.co.z = cz + (v.co.z - cz) * (1 + .12 * w)
    v.co.x *= 1 + .08 * w
# neck thicker so the head sits on a throat, not on a pole
for v in me.vertices:
    w = wt(v, "Neck")
    if w > 0.4:
        v.co.x *= 1 + .16 * w
        v.co.z += .0

# fangs and a lower tusk row along the jaws
jv = [v for v in me.vertices if wsum(v, ("Jaw_L", "Jaw_R")) > 0.5]
ymin = min(v.co.y for v in jv)
zj = sum(v.co.z for v in jv) / len(jv)
xw = max(abs(v.co.x) for v in jv)
print("JAW ymin", round(ymin, 3), "z", round(zj, 3), "halfwidth", round(xw, 3), "verts", len(jv))
import bmesh
bm = bmesh.new()
fang_groups = []


def fang(x, y, z, length, rad, up, grp):
    r = bmesh.ops.create_cone(bm, cap_ends=True, segments=5, radius1=rad, radius2=0.0, depth=length)
    verts = r["verts"]
    bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=Matrix.Rotation(0 if up else math.pi, 3, 'X'), verts=verts)
    lean = (x / max(xw, .01)) * -.25
    bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=Matrix.Rotation(lean, 3, 'Y'), verts=verts)
    bmesh.ops.translate(bm, vec=(x, y, z + (length / 2 if up else -length / 2)), verts=verts)
    fang_groups.append((verts, grp))


# measured from a side close-up of the original head: muzzle underside z(y) and mandible top z(y); fangs interlock like a trap
def z_upper(y): return .66 + (y + 1.415) * .42
def z_lower(y): return .60 + (y + 1.40) * .55
for i, y in enumerate((-1.43, -1.35, -1.27, -1.20)):
    for sgn, grp in ((-1, "Jaw_L"), (1, "Jaw_R")):
        fang(sgn * .075, y + .01, z_lower(y), .09 - i * .008 + (.03 if i == 1 else 0), .011, True, grp)           # lower row points up
        fang(sgn * .082, y - .01, z_upper(y) + .004, .04 - i * .004 + (.02 if i == 2 else 0), .010, False, "Head")  # upper row hangs down
fm = bpy.data.meshes.new("Fangs")
bm.to_mesh(fm)
fobj = bpy.data.objects.new("Fangs", fm)
bpy.context.scene.collection.objects.link(fobj)
off = 0
for verts, grp in fang_groups:
    idx = [v.index for v in verts]
    if grp not in fobj.vertex_groups:
        fobj.vertex_groups.new(name=grp)
    fobj.vertex_groups[grp].add(idx, 1.0, 'REPLACE')
bm.free()
bone_mat = bpy.data.materials.new("M_Hound_Bone")
bone_mat.use_nodes = True
bone_mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (.62, .55, .40, 1)
bone_mat.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = .9
fobj.data.materials.append(bone_mat)
bpy.ops.object.select_all(action='DESELECT')
mesh.select_set(True)
fobj.select_set(True)
bpy.context.view_layer.objects.active = mesh
bpy.ops.object.join()
mesh = bpy.context.view_layer.objects.active
me = mesh.data

# grime / wounds as vertex colour (multiplies the pixel texture): dark lower legs and belly, pale scar bands on the flanks
col = me.color_attributes.new("Col", 'BYTE_COLOR', 'POINT')
for i, v in enumerate(me.vertices):
    g = 1.0
    if v.co.z < .35:
        g *= .62 + .38 * (v.co.z / .35)                         # paws and pasterns dirty
    if v.co.z < .75 and abs(v.co.x) < .22 and -.5 < v.co.y < .6:
        g *= .78                                                  # belly shadow
    if abs(v.co.x) > .12 and .95 < v.co.z < 1.2 and -.6 < v.co.y < .5:
        band = math.sin(v.co.y * 11 + v.co.z * 4) + .5 * math.sin(v.co.y * 23)
        if band > .95:
            g = min(1.0, g * 1.35)                                # pale scar welts
        else:
            g *= .9
    g *= .88 + .12 * random.random()
    col.data[i].color = (g, g, g, 1.0)
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
me.update()

# ------------------------------------------------------------------------------------------------------ animation
arm.data.pose_position = 'POSE'
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode='POSE')
bones = list(arm.data.bones)
order = []
for b in bones:
    chain = []
    p = b
    while p:
        chain.append(p)
        p = p.parent
    order.append((len(chain), b.name))
order = [n for _, n in sorted(order)]
rest = {b.name: b.matrix_local.copy() for b in bones}
head = {b.name: b.head_local.copy() for b in bones}
FPS = 30


def smooth(x):
    x = max(0.0, min(1.0, x))
    return x * x * (3 - 2 * x)


def K(t, keys):
    """smoothstep-interpolated keyframes [(frame, value), ...]"""
    if t <= keys[0][0]:
        return keys[0][1]
    for (f0, v0), (f1, v1) in zip(keys, keys[1:]):
        if t <= f1:
            return v0 + (v1 - v0) * smooth((t - f0) / max(f1 - f0, 1e-6))
    return keys[-1][1]


def rot_about(h, th):
    return Matrix.Translation(h) @ Matrix.Rotation(th, 4, 'X') @ Matrix.Translation(-h)


LEGS = {"FL": ("Chest", True), "FR": ("Chest", True), "HL": ("Hips", False), "HR": ("Hips", False)}
REST_ANKLE = {k: Vector((head[f"Leg_{k}_Foot"].y, head[f"Leg_{k}_Foot"].z)) for k in LEGS}


def solve(P):
    """P: hips=(dy,dz,pitch), spine=[3 pitches], neck, headp, jaw, tail=[3], legs={name:(y,z)} ankle targets in armature space.
    Returns {bone: armature-space matrix}. All motion is planar (about X); +pitch = nose down; forward = -Y."""
    D = {"Root": Matrix.Identity(4)}
    A = {"Root": 0.0}

    def node(name, parent, th, off=(0, 0, 0)):
        D[name] = D[parent] @ Matrix.Translation(off) @ rot_about(head[name], th)
        A[name] = A[parent] + th
    dy, dz, hp = P["hips"]
    node("Hips", "Root", hp, (0, dy, dz))
    node("Spine1", "Hips", P["spine"][0])
    node("Spine2", "Spine1", P["spine"][1])
    node("Chest", "Spine2", P["spine"][2])
    node("Neck", "Chest", P["neck"])
    node("Head", "Neck", P["headp"])
    node("Jaw_L", "Head", P["jaw"][0])
    node("Jaw_R", "Head", P["jaw"][1])
    node("Tail_01", "Hips", P["tail"][0])
    node("Tail_02", "Tail_01", P["tail"][1])
    node("Tail_03", "Tail_02", P["tail"][2])
    for leg, (par, front) in LEGS.items():
        up, lo, ft = (f"Leg_{leg}_{s}" for s in ("Upper", "Lower", "Foot"))
        S3 = D[par] @ head[up]
        S = Vector((S3.y, S3.z))
        h_up, h_lo, h_ft = (Vector((head[n].y, head[n].z)) for n in (up, lo, ft))
        d1, d2 = h_lo - h_up, h_ft - h_lo
        L1, L2 = d1.length, d2.length
        a1r, a2r = math.atan2(d1.y, d1.x), math.atan2(d2.y, d2.x)
        T = Vector(P["legs"][leg][:2])
        v = T - S
        dist = max(abs(L1 - L2) + 0.02, min(L1 + L2 - 0.005, v.length))
        beta = math.atan2(v.y, v.x)
        gam = math.acos(max(-1, min(1, (L1 * L1 + dist * dist - L2 * L2) / (2 * L1 * dist))))
        best = None
        for sg in (1, -1):
            a1 = beta + sg * gam
            Kp = S + Vector((math.cos(a1), math.sin(a1))) * L1
            mid_y = (S.x + T.x) / 2
            ok = (Kp.x > mid_y) if front else (Kp.x < mid_y)
            if ok and best is None:
                best = (a1, Kp)
        if best is None:
            a1 = beta + gam
            best = (a1, S + Vector((math.cos(a1), math.sin(a1))) * L1)
        a1, Kp = best
        Tt = S + (T - S).normalized() * dist if dist != v.length else T
        a2 = math.atan2(Tt.y - Kp.y, Tt.x - Kp.x)
        node(up, par, a1 - a1r - A[par])
        node(lo, up, (a2 - a2r) - A[up])
        node(ft, lo, P["legs"][leg][2] - A[lo] if len(P["legs"][leg]) > 2 else 0.0 - A[lo])
    return D


def rest_params():
    return {"hips": (0, 0, 0), "spine": [0, 0, 0], "neck": 0, "headp": 0, "jaw": (0, 0), "tail": [0, 0, 0],
            "legs": {k: (REST_ANKLE[k].x, REST_ANKLE[k].y, 0.0) for k in LEGS}}


# self test: the rest parameters must reproduce the rest pose
def basis_for(name, D):
    """matrix_basis of a pose bone from the armature-space deformation D (independent of Blender's evaluation order)."""
    b = arm.data.bones[name]
    Dp = D[b.parent.name] if b.parent else Matrix.Identity(4)
    return rest[name].inverted() @ Dp.inverted() @ D[name] @ rest[name]


test = solve(rest_params())
print("REST SELFTEST max basis error", round(max(max(abs(c - (1.0 if i == j else 0.0)) for i, r in enumerate(basis_for(n, test)) for j, c in enumerate(r)) for n in test), 6))


def leg_target(phase, T, duty, stride, lift, yc, z0, front_dir=-1.0, floor=0.0):
    """ankle (y, z) for one leg. Forward = -Y. Stance: foot moves backward (+Y) at body speed; swing: arc forward."""
    p = phase % 1.0
    if p < duty:
        y = yc - front_dir * 0 - stride / 2 + stride * (p / duty)
        y = yc - stride / 2 + stride * (p / duty)
        z = z0
    else:
        q = (p - duty) / (1 - duty)
        y = yc + stride / 2 - stride * smooth(q) * 1.0
        z = z0 + lift * math.sin(math.pi * q) ** 0.8
    return (y, z)


def new_clip(name, nframes, fn, loop):
    act = bpy.data.actions.new(name)
    arm.animation_data_create()
    arm.animation_data.action = act
    for f in range(nframes):
        P = fn(f)
        D = solve(P)
        for n in order:
            pb = arm.pose.bones[n]
            pb.rotation_mode = 'QUATERNION'
            m = basis_for(n, D)
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
    print("CLIP", name, nframes, "frames", "loop" if loop else "once")


def base(P=None):
    return P or rest_params()


def legs_from(phases, T, duty, stride, lift, scale=None, extra=None):
    out = {}
    for k in LEGS:
        ph, sc = phases[k], (scale or {}).get(k, 1.0)
        yc, z0 = REST_ANKLE[k].x, REST_ANKLE[k].y
        y, z = leg_target(ph, T, duty, stride * sc, lift * (0.6 + .4 * sc), yc, z0)
        out[k] = (y, z, 0.0)
    return out


TAU = 2 * math.pi

# ---------- IDLE: breathing, a grin that trembles, a claw tapping, one sudden nod (3 s loop)
def idle(f):
    N, p = 90, f / 90
    P = rest_params()
    br = math.sin(TAU * 3 * p)
    P["hips"] = (0, -.025 + .006 * br, .01 * br)
    P["spine"] = [.012 * br, .012 * math.sin(TAU * 3 * p - .5), .018 * math.sin(TAU * 3 * p - 1.0)]
    twitch = math.exp(-((p - .55) / .018) ** 2)
    P["neck"] = .05 + .03 * math.sin(TAU * p) + .12 * twitch
    P["headp"] = .02 + .02 * math.sin(TAU * p + 1) + .14 * twitch
    jaw = .05 + .03 * math.sin(TAU * 7 * p) + .12 * twitch
    P["jaw"] = (jaw, jaw)
    P["tail"] = [.08 * math.sin(TAU * p), .12 * math.sin(TAU * p - .8), .16 * math.sin(TAU * p - 1.6)]
    P["hips"] = (P["hips"][0], P["hips"][1], P["hips"][2])
    legs = {k: (REST_ANKLE[k].x, REST_ANKLE[k].y, 0.0) for k in LEGS}
    tap = K(f, [(26, 0), (30, 1), (34, 0), (38, 1), (42, 0), (200, 0)]) * (1 if f < 44 else 0)
    legs["FL"] = (REST_ANKLE["FL"].x - .05 * tap, REST_ANKLE["FL"].y + .075 * tap, 0.0)
    P["legs"] = legs
    return P


# ---------- WALK: low stalking creep (1.0 s loop), lateral sequence HL FL HR FR, shoulders rolling, head hunting low
def walk(f):
    p = f / 30
    P = rest_params()
    dur = .62
    ph = {"HL": 0.0, "FL": .25, "HR": .5, "FR": .75}
    P["legs"] = legs_from({k: p - v for k, v in ph.items()}, 1.0, dur, .80, .12)
    P["hips"] = (0, -.10 + .012 * math.cos(2 * TAU * p), -.05 + .012 * math.sin(TAU * p))
    P["spine"] = [.05, .05 + .02 * math.sin(TAU * p), .05 + .03 * math.sin(TAU * p + .8)]
    P["neck"] = .22 + .04 * math.sin(2 * TAU * p)
    P["headp"] = .08 + .03 * math.sin(TAU * p + 1.2)
    P["jaw"] = (.1 + .02 * math.sin(TAU * 3 * p), .1 + .02 * math.sin(TAU * 3 * p + 1))
    P["tail"] = [.06 * math.sin(TAU * p - .5), .1 * math.sin(TAU * p - 1.1), .14 * math.sin(TAU * p - 1.7)]
    return P


# ---------- TROT: uneven, trotting with a hitch - the right fore short, a hind foot dragged late in the second beat (36 frames = 2 strides)
def trot(f):
    N = 36
    c, p = divmod(f, 18)
    p = p / 18
    P = rest_params()
    hitch = 1 if c == 1 else 0
    ph = {"FL": 0.0, "HR": 0.0, "FR": .5, "HL": .5 + .05 + .06 * hitch}
    scale = {"FR": .8, "HL": 1.0 - .15 * hitch}
    P["legs"] = legs_from({k: p - v for k, v in ph.items()}, .6, .46, .72, .15, scale)
    P["hips"] = (0, -.07 + .03 * math.cos(2 * TAU * p), -.03 * math.sin(2 * TAU * p))
    P["spine"] = [.04 * math.sin(TAU * p), .05 * math.sin(TAU * p + .4), .05 * math.sin(TAU * p + .8)]
    P["neck"] = .1 + .06 * math.sin(2 * TAU * p + .6) + (.12 if hitch and .55 < p < .8 else 0)
    P["headp"] = .05 + .05 * math.sin(2 * TAU * p + 1.4)
    P["jaw"] = (.14, .12 + .05 * hitch)
    P["tail"] = [.12 * math.sin(TAU * p - .4), .18 * math.sin(TAU * p - 1.0), .22 * math.sin(TAU * p - 1.6)]
    return P


# ---------- GALLOP: rotary gallop with real suspension phases, spine gather/extension, two different strides per loop (30 frames)
def gallop(f):
    c, p = divmod(f, 15)
    p = p / 15
    amp = 1.0 if c == 0 else 1.14
    P = rest_params()
    ph = {"HL": 0.0, "HR": .10, "FL": .50, "FR": .60}
    P["legs"] = legs_from({k: p - v for k, v in ph.items()}, .5, .32, .66 * amp, .20)
    F = math.cos(TAU * (p - .46))                       # +1 gathered (hind under), -1 extended (flying)
    bob = -(.07 + .06 * math.cos(2 * TAU * (p - .21))) * amp
    P["hips"] = (-.03 * F * amp, bob + .02 * amp, -.11 * F * amp)
    P["spine"] = [.08 * F * amp, .08 * F * amp, .07 * F * amp]
    P["neck"] = -.05 * F + .06 + (.06 if c == 1 else 0)
    P["headp"] = -.12 * F * amp * .6 + .04 * math.sin(TAU * p + .5)
    j = .22 + .1 * math.sin(TAU * p + .3)
    P["jaw"] = (j, j * .9)
    P["tail"] = [.10 * math.sin(TAU * (p - .08)), .15 * math.sin(TAU * (p - .18)), .2 * math.sin(TAU * (p - .28))]
    return P


# ---------- ATTACK_BITE: 3-frame coil, lunge and snap by frame ~8 (damage window unchanged), head shake, long recovery (31 frames)
def bite(f):
    P = rest_params()
    dy = K(f, [(0, 0), (3, .08), (6, -.34), (8, -.40), (12, -.36), (20, -.10), (30, 0)])
    dz = K(f, [(0, -.03), (3, -.15), (6, -.07), (9, -.08), (20, -.05), (30, -.03)])
    pit = K(f, [(0, 0), (3, -.14), (6, .12), (10, .10), (22, .02), (30, 0)])
    P["hips"] = (dy, dz, pit)
    F = K(f, [(0, 0), (3, 1.2), (6, -1.4), (10, -.8), (22, -.1), (30, 0)])
    P["spine"] = [.07 * F, .07 * F, .06 * F]
    shake = math.sin((f - 9) * 1.5) * .22 * K(f, [(9, 0), (11, 1), (17, 0), (30, 0)]) if 9 <= f <= 18 else 0
    P["neck"] = K(f, [(0, .05), (3, -.28), (6, .16), (9, .12), (22, .05), (30, .05)]) + shake
    P["headp"] = K(f, [(0, 0), (3, -.2), (6, .14), (10, .1), (22, 0), (30, 0)]) - shake * .8
    j = K(f, [(0, .06), (3, .18), (5, .62), (7.5, .70), (8.5, -.04), (12, .0), (22, .05), (30, .06)])
    P["jaw"] = (j, j)
    P["tail"] = [K(f, [(0, 0), (6, .35), (20, -.1), (30, 0)]), K(f, [(0, 0), (8, .4), (22, -.1), (30, 0)]), K(f, [(0, 0), (10, .5), (24, -.1), (30, 0)])]
    legs = {k: [REST_ANKLE[k].x, REST_ANKLE[k].y, 0.0] for k in LEGS}
    rake = K(f, [(0, 0), (3, 0), (5, 1), (8, .8), (14, 0), (30, 0)])
    for k in ("FL", "FR"):
        legs[k][0] += -.36 * rake
        legs[k][1] += .26 * rake - (.0)
    for k in ("HL", "HR"):
        legs[k][0] += K(f, [(0, 0), (3, .0), (30, 0)])
    P["legs"] = {k: tuple(v) for k, v in legs.items()}
    return P


# ---------- ALERT: freeze and lock on (34 frames, plays once)
def alert(f):
    P = rest_params()
    t = f
    P["hips"] = (K(t, [(0, 0), (8, .04), (33, .04)]), K(t, [(0, -.03), (8, -.13), (33, -.12)]), K(t, [(0, 0), (8, -.07), (33, -.06)]))
    P["spine"] = [K(t, [(0, 0), (8, -.05), (33, -.05)])] * 3
    trem = .012 * math.sin(f * 2.1) * K(t, [(6, 0), (10, 1), (33, 1)])
    P["spine"] = [P["spine"][0] + trem, P["spine"][1] - trem, P["spine"][2] + trem]
    P["neck"] = K(t, [(0, .05), (7, -.22), (12, -.16), (33, -.18)])
    P["headp"] = K(t, [(0, 0), (7, -.1), (12, -.04), (33, -.06)])
    j = K(t, [(0, .05), (7, .3), (33, .28)]) + .03 * math.sin(f * 1.9)
    P["jaw"] = (j, j * .85)
    P["tail"] = [K(t, [(0, 0), (8, .25), (33, .25)]), K(t, [(0, 0), (8, .2), (33, .2)]), K(t, [(0, 0), (8, .15), (33, .15)])]
    legs = {k: [REST_ANKLE[k].x, REST_ANKLE[k].y, 0.0] for k in LEGS}
    for k in ("FL", "FR"):
        legs[k][0] -= .08 * K(t, [(0, 0), (8, 1), (33, 1)])
    for k in ("HL", "HR"):
        legs[k][0] += .06 * K(t, [(0, 0), (8, 1), (33, 1)])
    P["legs"] = {k: tuple(v) for k, v in legs.items()}
    return P


# ---------- HIT_REACT: jolted back and up, forepaws skid (19 frames)
def hit(f):
    P = rest_params()
    P["hips"] = (K(f, [(0, 0), (3, .24), (9, .1), (18, 0)]), K(f, [(0, -.02), (3, -.06), (18, -.02)]), K(f, [(0, 0), (3, -.2), (10, -.05), (18, 0)]))
    P["spine"] = [K(f, [(0, 0), (3, -.12), (18, 0)])] * 3
    P["neck"] = K(f, [(0, .05), (3, -.3), (9, -.1), (18, .05)])
    P["headp"] = K(f, [(0, 0), (3, -.25), (18, 0)])
    j = K(f, [(0, .05), (3, .55), (10, .2), (18, .05)])
    P["jaw"] = (j, j)
    P["tail"] = [K(f, [(0, 0), (4, .3), (18, 0)]), K(f, [(0, 0), (5, .35), (18, 0)]), K(f, [(0, 0), (6, .4), (18, 0)])]
    legs = {k: [REST_ANKLE[k].x, REST_ANKLE[k].y, 0.0] for k in LEGS}
    for k in ("FL", "FR"):
        legs[k][0] += .14 * K(f, [(0, 0), (3, 1), (14, 0)])
        legs[k][1] += .05 * K(f, [(0, 0), (3, 1), (8, 0)])
    P["legs"] = {k: tuple(v) for k, v in legs.items()}
    return P


# ---------- DEATH: buckles, slumps onto its belly, jaw slack, tail drops, one last twitch (43 frames)
def death(f):
    P = rest_params()
    drop = K(f, [(0, -.03), (6, -.12), (14, -.50), (17, -.46), (24, -.52)])
    P["hips"] = (K(f, [(0, 0), (16, -.10), (24, -.12)]), drop, K(f, [(0, 0), (8, -.06), (18, .10), (24, .12)]))
    P["spine"] = [K(f, [(0, 0), (16, .12), (24, .18)])] * 3
    P["neck"] = K(f, [(0, .05), (8, -.1), (18, .34), (26, .42)])
    P["headp"] = K(f, [(0, 0), (18, .2), (26, .26)])
    j = K(f, [(0, .05), (8, .5), (20, .45), (26, .4)])
    P["jaw"] = (j, j * 1.1)
    P["tail"] = [K(f, [(0, 0), (10, .1), (24, -.15)]), K(f, [(0, 0), (12, .05), (26, -.2)]), K(f, [(0, 0), (14, 0), (28, -.25)])]
    legs = {k: [REST_ANKLE[k].x, REST_ANKLE[k].y, 0.0] for k in LEGS}
    legs["FL"][0] -= .26 * K(f, [(0, 0), (14, 1)])
    legs["FR"][0] -= .16 * K(f, [(2, 0), (16, 1)])
    legs["HL"][0] += .22 * K(f, [(0, 0), (14, 1)])
    legs["HR"][0] += .12 * K(f, [(2, 0), (16, 1)])
    tw = math.sin((f - 30) * 2.2) * K(f, [(29, 0), (31, 1), (36, 0), (42, 0)]) if 29 <= f <= 38 else 0
    legs["FL"][1] += .035 * abs(tw)
    P["jaw"] = (j + .04 * abs(tw), j * 1.1)
    P["legs"] = {k: tuple(v) for k, v in legs.items()}
    return P


for name, n, fn, loop in (("Idle", 90, idle, True), ("Walk", 30, walk, True), ("Trot", 36, trot, True), ("Run", 30, gallop, True),
                          ("Alert", 34, alert, False), ("Attack_Bite", 31, bite, False), ("Hit_React", 19, hit, False), ("Death", 43, death, False)):
    new_clip(name, n, fn, loop)
bpy.ops.object.mode_set(mode='OBJECT')
bpy.context.scene.render.fps = FPS
bpy.ops.export_scene.gltf(filepath=os.path.abspath(OUT_GLB), export_format='GLB', export_animations=True, export_animation_mode='NLA_TRACKS',
                          export_force_sampling=True, export_yup=True, export_apply=False, export_skins=True,
                          export_vertex_color='ACTIVE' if hasattr(bpy.types, "EXPORT_SCENE_OT_gltf") else 'MATERIAL')
bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(OUT_BLEND))
print("DONE tris", sum(len(p.vertices) - 2 for p in mesh.data.polygons), "actions", [a.name for a in bpy.data.actions])
