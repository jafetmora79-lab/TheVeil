"""THE VEIL - game-ready rig of a Meshy NPC (Blender 5.x, headless). Same body as the protagonist: the same 51-bone rig, weights and clips.
Reads the untouched Meshy OBJ, puts the character upright at game scale facing +Y (the convention of the existing
Sarah: it exports as glTF -Z, Godot's forward), welds the vertices, flat-shades it (PSX look), assigns ONE material with
the 512 nearest-neighbour texture, builds a basic humanoid armature (Godot humanoid bone names), skins it, makes three
temporary animations (idle, walk, head_turn) and exports a GLB. Optional debug renders (rig overlay, deformation tests).
   blender -b -P build_npc_meshy.py -- <repo_root> <slug> <height_m> [debug]   (source: creatures/humans/npcs/source/<slug>.glb)
Writes only under creatures/humans/npcs/<slug>/ and game/prototypes/npc_meshy/."""
import bpy, bmesh, sys, os, math, json
import numpy as np
from mathutils import Vector, Matrix, Euler

args = sys.argv[sys.argv.index("--") + 1:]
root = args[0]
SLUG = args[1]
debug = len(args) > 3 and args[3] == "debug"
base = os.path.join(root, "creatures/humans/npcs", SLUG)
BASE_DIR = base                                  # (the name `base` is reused by the finger code below)
out_dir = os.path.join(base, "game_ready")
glb_dir = os.path.join(root, "game/prototypes/npc_meshy")
os.makedirs(out_dir, exist_ok=True)
os.makedirs(glb_dir, exist_ok=True)
HEIGHT = float(args[2])                         # metres
RAW_H = 0.95                                   # the Meshy model's own height
S = HEIGHT / RAW_H

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.join(root, "creatures/humans/npcs/source", SLUG + ".glb"))
src = [o for o in bpy.context.scene.objects if o.type == 'MESH'][0]
src.parent = None
src.matrix_world = Matrix.Identity(4)
bpy.context.view_layer.update()
me = src.data
# the GLB arrives facing -Y with its origin at the middle of the body (X = his left, Z up). Turn him to face +Y (the game's -Z after export), feet on Z = 0
co = np.empty(len(me.vertices) * 3)
me.vertices.foreach_get("co", co)
co = co.reshape(-1, 3)
feet = co[:, 2].min()
new = np.stack([-co[:, 0] * S, -co[:, 1] * S, (co[:, 2] - feet) * S], axis=1)
me.vertices.foreach_set("co", new.reshape(-1))
me.update()

# ---- clean: weld, flat shade
bm = bmesh.new()
bm.from_mesh(me)
before = len(bm.verts)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
bm.to_mesh(me)
bm.free()
print("WELD", before, "->", len(me.vertices))
for p in me.polygons:
    p.use_smooth = False
src.name = "NPC_Meshy_Body"
me.name = "NPC_Meshy_Body"
src.name = "NPC_Meshy_Body"
me.name = "NPC_Meshy_Body"
mat = me.materials[0]                        # the Meshy material and its 2048 texture, untouched; only the sampling is made nearest-neighbour
for nd in mat.node_tree.nodes:
    if nd.type == 'TEX_IMAGE':
        nd.interpolation = "Closest"
bpy.context.view_layer.update()
v = np.empty(len(me.vertices) * 3)
me.vertices.foreach_get("co", v)
v = v.reshape(-1, 3)
print("FINAL bbox", v.min(0).round(3), v.max(0).round(3))

# centre X/Y on the body (the feet are on Z=0 already)
cx = (v[:, 0].min() + v[:, 0].max()) / 2
v[:, 0] -= cx
me.vertices.foreach_set("co", v.reshape(-1))
me.update()


# ---- armature (landmarks in RAW glb coordinates: side +x is his left, up = z, front = -y)
def P(x, y, z=0.0):
    return Vector((-x * S, z * S, (y - feet) * S))


LM = {
    "Hips": (P(0, -0.03), P(0, 0.06)),
    "Spine": (P(0, 0.06), P(0, 0.18)),
    "Chest": (P(0, 0.18), P(0, 0.285)),
    "Neck": (P(0, 0.285), P(0, 0.335)),
    "Head": (P(0, 0.335), P(0, 0.475)),
}
WRIST = (0.232, 0.095)
PALM = (0.250, 0.035)
TIPS = (0.256, -0.008)
for side, sx in (("Left", 1), ("Right", -1)):
    LM[side + "Shoulder"] = (P(sx * 0.020, 0.285), P(sx * 0.105, 0.285))
    LM[side + "UpperArm"] = (P(sx * 0.105, 0.285), P(sx * 0.172, 0.165))
    LM[side + "LowerArm"] = (P(sx * 0.172, 0.165), P(sx * WRIST[0], WRIST[1]))
    LM[side + "Hand"] = (P(sx * WRIST[0], WRIST[1]), P(sx * PALM[0], PALM[1]))
    LM[side + "UpperLeg"] = (P(sx * 0.055, -0.03), P(sx * 0.066, -0.25))
    LM[side + "LowerLeg"] = (P(sx * 0.066, -0.25), P(sx * 0.079, -0.430))
    LM[side + "Foot"] = (P(sx * 0.079, -0.430), P(sx * 0.079, -0.468, 0.065))
    LM[side + "Toes"] = (P(sx * 0.079, -0.468, 0.065), P(sx * 0.079, -0.472, 0.110))
# ---- fingers: no separate fingers were modelled (a Meshy hand is a mitten-like shape), so they are laid out on the hand from its proportions
FINGERS = ["Thumb", "Index", "Middle", "Ring", "Little"]
GODOT_NAMES = {"Thumb": ("Metacarpal", "Proximal", "Distal"), "Index": ("Proximal", "Intermediate", "Distal"), "Middle": ("Proximal", "Intermediate", "Distal"),
               "Ring": ("Proximal", "Intermediate", "Distal"), "Little": ("Proximal", "Intermediate", "Distal")}
FRONT_OFF = {"Index": 0.012, "Middle": 0.0, "Ring": -0.012, "Little": -0.022}
LEN_K = {"Index": 0.95, "Middle": 1.0, "Ring": 0.95, "Little": 0.8}
HANDINFO = {}
for side, sx in (("Left", 1), ("Right", -1)):
    wrist = LM[side + "Hand"][0]
    palm_end = LM[side + "Hand"][1]
    tip_dir = (P(sx * TIPS[0], TIPS[1]) - palm_end)
    flen = tip_dir.length
    tip_dir.normalize()
    chains = {}
    for f in FINGERS:
        if f == "Thumb":
            base = wrist.lerp(palm_end, 0.35) + Vector((0, 0.022 * S, 0))
            td = (tip_dir + Vector((0, 0.6, 0))).normalized()
            tip = base + td * flen * 0.85
        else:
            base = palm_end + Vector((0, FRONT_OFF[f] * S, 0))
            tip = base + tip_dir * flen * LEN_K[f]
        j2 = base + 0.45 * (tip - base)
        j3 = base + 0.75 * (tip - base)
        chains[f] = [(base, j2), (j2, j3), (j3, tip)]
    HANDINFO[side] = (wrist, palm_end, chains)
    for f in FINGERS:
        for i, (a_, b_) in enumerate(chains[f]):
            LM["%s%s%s" % (side, f, GODOT_NAMES[f][i])] = (Vector(a_), Vector(b_))
print("HANDINFO left wrist", HANDINFO["Left"][0], "palm end", HANDINFO["Left"][1])
PARENT = {"Hips": None, "Spine": "Hips", "Chest": "Spine", "Neck": "Chest", "Head": "Neck"}
for side in ("Left", "Right"):
    PARENT.update({side + "Shoulder": "Chest", side + "UpperArm": side + "Shoulder", side + "LowerArm": side + "UpperArm", side + "Hand": side + "LowerArm",
                   side + "UpperLeg": "Hips", side + "LowerLeg": side + "UpperLeg", side + "Foot": side + "LowerLeg", side + "Toes": side + "Foot"})
ORDER = ["Hips", "Spine", "Chest", "Neck", "Head"] + [s + n for s in ("Left", "Right") for n in ("Shoulder", "UpperArm", "LowerArm", "Hand", "UpperLeg", "LowerLeg", "Foot", "Toes")]
FINGER_BONES = {}
for side in ("Left", "Right"):
    for f in FINGERS:
        prev = side + "Hand"
        for i in range(3):
            n_ = "%s%s%s" % (side, f, GODOT_NAMES[f][i])
            PARENT[n_] = prev
            prev = n_
            ORDER.append(n_)
            FINGER_BONES.setdefault(side + f, []).append(n_)

arm_data = bpy.data.armatures.new("NPC_Meshy_Rig")
rig = bpy.data.objects.new("NPC_Meshy_Rig", arm_data)
bpy.context.scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='EDIT')
for n in ORDER:
    h, t = LM[n]
    eb = arm_data.edit_bones.new(n)
    eb.head, eb.tail = h, t
    d = (t - h).normalized()
    xa = Vector((0, 1, 0)) if (n.endswith('Hand') or any(k in n for k in FINGERS)) else Vector((1, 0, 0))
    xa = xa - d * xa.dot(d)
    if xa.length < 1e-4:
        xa = Vector((1, 0, 0)) - d * d.x
    xa.normalize()
    za = xa.cross(d).normalized()
    # local axes: X = world side axis (swing about it), Y = along the bone, Z = X x Y
    mtx = Matrix(((xa.x, d.x, za.x, h.x), (xa.y, d.y, za.y, h.y), (xa.z, d.z, za.z, h.z), (0, 0, 0, 1)))
    eb.matrix = mtx
    eb.length = (t - h).length
for n in ORDER:
    if PARENT[n]:
        arm_data.edit_bones[n].parent = arm_data.edit_bones[PARENT[n]]
        arm_data.edit_bones[n].use_connect = (arm_data.edit_bones[n].head - arm_data.edit_bones[PARENT[n]].tail).length < 1e-4
bpy.ops.object.mode_set(mode='OBJECT')

# ---- skin: automatic weights, then check and repair
bpy.ops.object.select_all(action='DESELECT')
src.select_set(True)
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.parent_set(type='ARMATURE_AUTO')
vg = {g.index: g.name for g in src.vertex_groups}
unw = 0
for vx in me.vertices:
    if not any(g.weight > 1e-4 for g in vx.groups):
        unw += 1
print("SKIN vertex groups", len(src.vertex_groups), "unweighted vertices", unw, "of", len(me.vertices))
if unw > 0:
    # automatic weights leave detached pieces (a shoulder bag, a belt with gear, a strap) with no weight: give just those vertices
    # distance-based weights to the nearest bones, keeping the automatic weights everywhere else
    print("AUTOWEIGHT left", unw, "vertices unweighted: weighting them by distance to the bones")
    groups = {n: src.vertex_groups[n] if n in src.vertex_groups else src.vertex_groups.new(name=n) for n in ORDER}
    segs = {n: LM[n] for n in ORDER}
    names = list(segs)
    pts_all = np.array([(src.matrix_world @ vx.co)[:] for vx in me.vertices])
    todo = [vx.index for vx in me.vertices if not any(g.weight > 1e-4 for g in vx.groups)]
    for i in todo:
        pt = pts_all[i]
        W = np.zeros(len(names))
        for j, n in enumerate(names):
            a_, bb = np.array(segs[n][0][:]), np.array(segs[n][1][:])
            ab = bb - a_
            tt = np.clip(((pt - a_) @ ab) / (ab @ ab), 0, 1)
            d = np.linalg.norm(pt - (a_ + tt * ab))
            W[j] = 1.0 / (d + 0.02) ** 3
        W /= W.sum()
        for j in np.argsort(-W)[:3]:
            if W[j] > 0.03:
                groups[names[j]].add([i], float(W[j]), 'REPLACE')

# smooth the weights a little (shoulder seam, hips)
bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.object.select_all(action='DESELECT')
src.select_set(True)
bpy.context.view_layer.objects.active = src
try:
    bpy.ops.object.mode_set(mode='WEIGHT_PAINT')
    bpy.ops.object.vertex_group_smooth(group_select_mode='BONE_DEFORM', factor=0.3, repeat=1, expand=0.0)
    bpy.ops.object.mode_set(mode='OBJECT')
except Exception as e_:
    print("SMOOTH skipped", e_)
    try:
        bpy.ops.object.mode_set(mode='OBJECT')
    except Exception:
        pass
bpy.ops.object.vertex_group_normalize_all(group_select_mode='BONE_DEFORM', lock_active=False)
bpy.ops.object.vertex_group_limit_total(group_select_mode='BONE_DEFORM', limit=4)

# ---- loose parts (a shoulder bag and its strap, a holster, a belt with gear) move rigidly with the body bone nearest to them, so they
# never stretch or flap when an arm is raised
_bm = bmesh.new()
_bm.from_mesh(me)
_bm.verts.ensure_lookup_table()
_seen = set()
_comps = []
for _v in _bm.verts:
    if _v.index in _seen:
        continue
    _stack = [_v]
    _comp = []
    _seen.add(_v.index)
    while _stack:
        _c = _stack.pop()
        _comp.append(_c.index)
        for _e in _c.link_edges:
            _o = _e.other_vert(_c)
            if _o.index not in _seen:
                _seen.add(_o.index)
                _stack.append(_o)
    _comps.append(_comp)
_bm.free()
_comps.sort(key=len, reverse=True)
print("COMPONENTS", [len(c) for c in _comps][:8])
_trunk_map = {"Hips": "Hips", "Spine": "Spine", "Chest": "Chest", "LeftUpperLeg": "Hips", "RightUpperLeg": "Hips"}


def _seg_dist(pt, n):
    a_, b_ = np.array(LM[n][0][:]), np.array(LM[n][1][:])
    ab = b_ - a_
    t_ = np.clip(((pt - a_) @ ab) / (ab @ ab), 0, 1)
    return float(np.linalg.norm(pt - (a_ + t_ * ab)))


for _comp in _comps[1:]:
    if len(_comp) > 0.2 * len(me.vertices):
        continue
    _cen = np.mean([(src.matrix_world @ me.vertices[i].co)[:] for i in _comp], axis=0)
    _near = min((n for n in ORDER if "Toes" not in n), key=lambda n: _seg_dist(_cen, n))
    if _near not in _trunk_map:
        continue                                   # a hand, a boot, a sleeve or hair: it belongs to a limb or the head and keeps its weights
    _best = _trunk_map[_near]
    for _g in list(src.vertex_groups):
        _g.remove(_comp)
    src.vertex_groups[_best].add(_comp, 1.0, 'REPLACE')
    print("LOOSE part of", len(_comp), "vertices (nearest bone", _near, ") ->", _best)

# ---- the head moves as one piece: automatic weights split the chin, jaw and hair between Neck and Head, so a head turn tore the face.
# Everything from the middle of the neck upward is blended to 100% Head (full at the top of the neck), whatever the hair or jaw does.
HEAD_Z0 = P(0, 0.300).z                         # blend starts inside the neck
HEAD_Z1 = P(0, 0.322).z                         # fully Head from here up (below the chin)
vg_head = src.vertex_groups["Head"]
others = [g for g in src.vertex_groups if g.name != "Head"]
n_fixed = 0
for vx in me.vertices:
    z_ = (src.matrix_world @ vx.co).z
    if z_ <= HEAD_Z0:
        continue
    t_ = min(1.0, (z_ - HEAD_Z0) / (HEAD_Z1 - HEAD_Z0))
    t_ = t_ * t_ * (3 - 2 * t_)
    ws = {src.vertex_groups[g.group].name: g.weight for g in vx.groups}
    keep = 1.0 - t_
    new = {n_: w_ * keep for n_, w_ in ws.items() if n_ != "Head"}
    new["Head"] = ws.get("Head", 0.0) * keep + t_
    tot = sum(new.values())
    for g in others:
        if g.name in new and new[g.name] / tot > 0.002:
            g.add([vx.index], new[g.name] / tot, 'REPLACE')
        else:
            try:
                g.remove([vx.index])
            except RuntimeError:
                pass
    vg_head.add([vx.index], new["Head"] / tot, 'REPLACE')
    n_fixed += 1
print("HEADFIX vertices re-weighted", n_fixed)
# the head fix can leave a vertex with a fifth influence: keep every vertex to 4 bones (Godot then uses the lightweight 4-weight skinning)
bpy.ops.object.select_all(action='DESELECT')
src.select_set(True)
bpy.context.view_layer.objects.active = src
bpy.ops.object.vertex_group_limit_total(group_select_mode='BONE_DEFORM', limit=4)
bpy.ops.object.vertex_group_normalize_all(group_select_mode='BONE_DEFORM', lock_active=False)

if debug:
    from collections import Counter
    cnt = Counter()
    for vx in me.vertices:
        if vx.co.x < -0.12 and 0.9 < vx.co.z < 1.45:
            g = max(vx.groups, key=lambda g: g.weight)
            cnt[src.vertex_groups[g.group].name] += 1
    print('ARMREGION dominant bone counts', dict(cnt))
    dg = bpy.context.evaluated_depsgraph_get()
    ev = src.evaluated_get(dg)
    ee = np.array([(ev.matrix_world @ vv.co)[:] for vv in ev.data.vertices])
    print('EVALBBOX rest', ee.min(0).round(3), ee.max(0).round(3), 'frame', bpy.context.scene.frame_current)
    print('BONE0', [(b.name, [round(x, 3) for x in b.head_local], [round(x, 3) for x in b.tail_local]) for b in arm_data.bones][:3])

decal_objs = []
# ---- temporary animations. Proportions studied from the clip statistics of the reference game's Mixamo-rig clips (reference only,
# nothing copied): idles are LONG (6-10 s) and very quiet (body < 2 degrees, head 2-7, arms 6-11); the walk is ~1.5 s with hips 16-23,
# spine 5-10, thigh 36-52, knee 53-62, foot 21, arm swing 31-49, forearm 29-37, wrist 23-50 and only thumb / index moving ~15 degrees.
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='POSE')
for pb in rig.pose.bones:
    pb.rotation_mode = 'XYZ'
FLEX = {"Left": -1.0, "Right": 1.0}                 # finger flexion about the world front-back axis: toward the body, mirrored per hand


def rot(name, frame, x=0.0, y=0.0, z=0.0):
    pb = rig.pose.bones[name]
    pb.rotation_euler = Euler((math.radians(x), math.radians(y), math.radians(z)), 'XYZ')
    pb.keyframe_insert("rotation_euler", frame=frame - 1)


def move(name, frame, loc):
    pb = rig.pose.bones[name]
    pb.location = loc
    pb.keyframe_insert("location", frame=frame - 1)


def reset_pose():
    for pb in rig.pose.bones:
        pb.rotation_euler = (0, 0, 0)
        pb.location = (0, 0, 0)


def new_action(name, length):
    reset_pose()
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    rig.animation_data_create()
    rig.animation_data.action = act
    bpy.context.scene.frame_start = 0                      # keys are written at frame - 1: the first key is frame 0, so the export has no held first frame
    bpy.context.scene.frame_end = length - 1
    return act


# hand poses: per finger (knuckle, middle joint, tip joint) flexion in degrees; spread is the sideways fan at the knuckle
POSES = {
    "relaxed": {"Thumb": (6, 8, 6), "Index": (10, 14, 8), "Middle": (14, 18, 10), "Ring": (18, 20, 12), "Little": (22, 22, 14)},
    "open": {"Thumb": (0, 0, 0), "Index": (0, 0, 0), "Middle": (0, 0, 0), "Ring": (0, 0, 0), "Little": (0, 0, 0)},
    "fist": {"Thumb": (14, 22, 14), "Index": (68, 84, 46), "Middle": (72, 88, 46), "Ring": (72, 88, 46), "Little": (70, 84, 44)},
    "grip": {"Thumb": (12, 10, 6), "Index": (22, 18, 8), "Middle": (50, 62, 36), "Ring": (54, 66, 38), "Little": (56, 66, 38)},
    "point": {"Thumb": (12, 16, 10), "Index": (0, 0, 0), "Middle": (72, 88, 46), "Ring": (72, 88, 46), "Little": (70, 84, 44)},
}


def hand_pose(side, pose, frame, k=1.0):
    for f in FINGERS:
        for i, n_ in enumerate(FINGER_BONES[side + f]):
            ang = POSES[pose][f][i] * k * FLEX[side]
            rot(n_, frame, x=ang)


FPS = 24
bpy.context.scene.render.fps = FPS
# -- one-frame hand pose actions (a game can blend these on top of any body animation)
for pose in POSES:
    new_action("hand_" + pose, 1)
    for side in ("Left", "Right"):
        hand_pose(side, pose, 1)
# -- idle: 6 s, very quiet; relaxed fingers with a slow drift of thumb and index
act = new_action("idle-loop", 144)
for f, br in ((1, 0.0), (49, 1.0), (97, 0.35), (145, 0.0)):
    rot("Chest", f, x=-1.0 * br)
    rot("Spine", f, x=0.5 * br)
    rot("Head", f, x=0.7 * br)
    for s_, sg in (("Left", 1), ("Right", -1)):
        rot(s_ + "UpperArm", f, x=1.5 * br, z=sg * 1.2 * br)
        rot(s_ + "LowerArm", f, x=(5 + 3 * br))
        rot(s_ + "Shoulder", f, z=sg * 0.8 * br)
        rot(s_ + "Hand", f, z=-2 * br)
for f, yw, pt in ((1, 0.0, 0.0), (37, 3.0, 0.5), (73, -2.5, -0.5), (109, 4.0, 0.8), (145, 0.0, 0.0)):
    rot("Neck", f, y=yw)
for side in ("Left", "Right"):
    for f, k in ((1, 1.0), (49, 1.15), (97, 0.9), (145, 1.0)):
        hand_pose(side, "relaxed", f, k)
# -- walk: 1.5 s cycle (36 frames). The legs come from two-bone IK on planted feet: the stance foot moves back at a constant speed
# (zero slide when the body moves at WALK_SPEED), the swing foot lifts and carries forward. Arms, spine and head keep the studied swing.
LEGS = {}
for side in ("Left", "Right"):
    Hh, Kk, Aa = LM[side + "UpperLeg"][0], LM[side + "UpperLeg"][1], LM[side + "LowerLeg"][1]
    LEGS[side] = (Hh, (Kk - Hh).length, (Aa - Kk).length, Aa.z)
L1, L2, ANK = LEGS["Left"][1], LEGS["Left"][2], LEGS["Left"][3]
HIP0 = LEGS["Left"][0].z
STRIDE, STANCE, T36 = 0.46 * HEIGHT / 1.66, 0.60, 36
HIP_H = HIP0 - 0.045
WALK_SPEED = STRIDE / (STANCE * T36 / FPS)              # metres per second the body must move for the planted foot not to slide
print("WALK speed", round(WALK_SPEED, 3), "leg", round(L1, 3), round(L2, 3), "ankle", round(ANK, 3))


def smooth(u):
    u = max(0.0, min(1.0, u))
    return u * u * (3 - 2 * u)


def foot_target(phi):
    """ankle (forward y, height z) and sole pitch psi (degrees, + = toes up) for a leg at gait phase phi (0..1)"""
    if phi < STANCE:
        y = STRIDE / 2 - STRIDE * (phi / STANCE)
        z = ANK + 0.035 * smooth((phi - 0.42) / 0.18)                  # heel comes up before toe-off
        if phi < 0.12:
            psi = 8.0 * (1 - phi / 0.12)
        elif phi < 0.42:
            psi = 0.0
        else:
            psi = -22.0 * smooth((phi - 0.42) / 0.18)
    else:
        u = (phi - STANCE) / (1 - STANCE)
        y = -STRIDE / 2 + STRIDE * (u - math.sin(2 * math.pi * u) / (2 * math.pi))
        z = ANK + 0.035 * (1 - u) + 0.075 * math.sin(math.pi * u) ** 1.2
        psi = -22.0 + 30.0 * smooth(u)
    return y, z, psi


def leg_ik(hip_z, y, z, psi):
    dy, dz = y, hip_z - z                                               # hip above the ankle
    d = min(math.hypot(dy, dz), (L1 + L2) * 0.999)
    alpha = math.atan2(dy, dz)                                          # from straight down, forward positive
    cos_phi = (L1 * L1 + L2 * L2 - d * d) / (2 * L1 * L2)
    knee = math.pi - math.acos(max(-1.0, min(1.0, cos_phi)))           # knee flexion
    delta = math.acos(max(-1.0, min(1.0, (L1 * L1 + d * d - L2 * L2) / (2 * L1 * d))))
    th = alpha + delta                                                  # thigh angle (knee forward of the hip-ankle line)
    ts = th - knee                                                      # shin angle
    return math.degrees(th), math.degrees(knee), psi - math.degrees(ts)


act = new_action("walk-loop", 37)
for f in range(1, 38):
    ph = ((f - 1) % T36) / T36
    a = math.sin(ph * 2 * math.pi)
    c = math.cos(ph * 2 * math.pi)
    hip_z = HIP_H + 0.008 * math.cos(2 * math.pi * 2 * (ph - 0.3))
    for s_, sg, off in (("Left", 1, 0.0), ("Right", -1, 0.5)):
        y, z, psi = foot_target((ph + off) % 1.0)
        th, knee, ft = leg_ik(hip_z, y, z, psi)
        rot(s_ + "UpperLeg", f, x=th)
        rot(s_ + "LowerLeg", f, x=-knee)
        rot(s_ + "Foot", f, x=ft)
        armf = -math.cos(2 * math.pi * ((ph + off) % 1.0))               # +1 = this arm forward (it opposes the leg on its side)
        rot(s_ + "UpperArm", f, x=31 * armf, z=sg * 3)
        rot(s_ + "LowerArm", f, x=8 + 22 * max(0.0, armf))
        rot(s_ + "Hand", f, z=-(4 + 5 * armf))
        rot(s_ + "Shoulder", f, z=sg * 2 * armf)
        for fn in ("Thumb", "Index"):
            for i, n_ in enumerate(FINGER_BONES[s_ + fn]):
                rot(n_, f, x=(POSES["relaxed"][fn][i] + 8 * armf * (1 if i == 0 else 0.5)) * FLEX[s_])
        for fn in ("Middle", "Ring", "Little"):
            for i, n_ in enumerate(FINGER_BONES[s_ + fn]):
                rot(n_, f, x=POSES["relaxed"][fn][i] * FLEX[s_])
    rot("Hips", f, y=4 * a, z=1.5 * c)                                  # pelvis twist about the vertical, a little roll
    rot("Spine", f, y=-3 * a, x=1.0)
    rot("Chest", f, y=-3 * a)
    rot("Head", f, y=1.5 * a, z=-0.8 * c)
    move("Hips", f, (0, hip_z - HIP0, 0))                               # the pelvis bone's own Y is the vertical
# -- head turn: look left, look right, back (3 s)
act = new_action("head_turn", 72)
for f, yw in ((1, 0), (19, 55), (37, 0), (55, -55), (72, 0)):
    rot("Head", f, y=yw * 0.7)
    rot("Neck", f, y=yw * 0.3)
for side in ("Left", "Right"):
    hand_pose(side, "relaxed", 1)
    hand_pose(side, "relaxed", 72)
# -- nervous idle (6 s loop): quick small glances, weight shifts, hands fidgeting low in front of the body
act = new_action("nervous_idle-loop", 144)
for f, yw, pt in ((1, 0, 0), (21, 20, 2), (33, 22, 2), (49, 0, 0), (69, -16, -1), (81, -18, -1), (97, 4, 0), (121, 12, 3), (133, 0, 0), (145, 0, 0)):
    rot("Head", f, y=yw * 0.75, x=pt)
    rot("Neck", f, y=yw * 0.25)
for f, sh in ((1, 0.0), (49, 1.0), (73, 1.0), (97, -1.0), (121, -1.0), (145, 0.0)):                   # weight shifts side to side
    rot("Hips", f, y=3 * sh, z=2.5 * sh)
    rot("Spine", f, z=-2 * sh, x=1.5)
    rot("Chest", f, y=-2 * sh, z=-1.0 * sh)
    move("Hips", f, (0.0, -0.006 * abs(sh), 0.0))
    rot("LeftFoot", f, x=2.5 * max(0.0, sh))
    rot("RightFoot", f, x=2.5 * max(0.0, -sh))
for f, br in ((1, 0.0), (37, 1.0), (73, 0.2), (109, 1.0), (145, 0.0)):                               # quick shallow breaths
    rot("Chest", f, x=-1.4 * br)
for s_, sg in (("Left", 1), ("Right", -1)):
    for f, k in ((1, 0.0), (37, 1.0), (73, 0.3), (109, 0.9), (145, 0.0)):                           # forearms lifted, hands near the belt, fidgeting
        rot(s_ + "UpperArm", f, x=10 + 3 * k, z=-sg * 22)
        rot(s_ + "LowerArm", f, x=(34 + 7 * k))
        rot(s_ + "Hand", f, z=-(8 + 4 * k))
        rot(s_ + "Shoulder", f, z=sg * -1.5)
        for fn in FINGERS:
            for i, n_ in enumerate(FINGER_BONES[s_ + fn]):
                base_ = POSES["relaxed"][fn][i]
                wob = (10 if fn in ("Thumb", "Index") else 3) * k * (1 if (sg > 0) == (f < 80) else -1)
                rot(n_, f, x=(base_ + wob) * FLEX[s_])
# -- injured idle (5 s loop): hunched, weight on the right leg, her left hand pressed to her left ribs, slow shallow breathing
act = new_action("injured_idle-loop", 120)
for f, br in ((1, 0.0), (41, 1.0), (81, 0.3), (121, 0.0)):
    rot("Spine", f, x=-(11 + 1.2 * br), z=3, y=-2)
    rot("Chest", f, x=-(9 + 1.5 * br), z=2)
    rot("Neck", f, x=-7, y=4 * br - 2)
    rot("Head", f, x=-4 + 1 * br, z=-5)
    rot("Hips", f, z=4, y=3)
    move("Hips", f, (0.0, -0.02, 0.0))
    rot("LeftShoulder", f, z=-3, x=-4)
    rot("RightShoulder", f, z=3, x=-2)
    rot("LeftUpperArm", f, x=18, y=-45, z=-34 + 1.5 * br)                           # left hand on the left ribs (the upper arm turned in)
    rot("LeftLowerArm", f, x=(118 + 2 * br))
    rot("LeftHand", f, z=-8)
    rot("RightUpperArm", f, x=8, z=-3 * (1 - br * 0.3))                              # right arm hangs heavy, a little forward
    rot("RightLowerArm", f, x=(10 + 2 * br))
    rot("LeftUpperLeg", f, x=4)
    rot("LeftLowerLeg", f, x=-10)
    rot("LeftFoot", f, x=-3)
    rot("RightUpperLeg", f, x=-5)
    rot("RightLowerLeg", f, x=-3)
for f in (1, 41, 81, 121):
    hand_pose("Left", "grip", f, 0.7)
    hand_pose("Right", "relaxed", f, 1.1)
# -- scared reaction (1.6 s, one shot): a flinch - the head snaps toward the noise, the body recoils, the arms come up, hands spread,
# then it settles into a tense, braced posture (the held pose keeps a small recoil)
act = new_action("scared_reaction", 38)
KEY = (1, 4, 8, 16, 26, 38)
YAW = (0, 32, 28, 16, 12, 10)
RC = (0.0, 1.0, 0.85, 0.5, 0.35, 0.3)
OPEN = (0.0, 0.0, 0.1, 0.3, 0.55, 0.7)
for i_, f in enumerate(KEY):
    yw, rc, k_open = YAW[i_], RC[i_], OPEN[i_]
    rot("Head", f, y=yw * 0.7, x=7 * rc)
    rot("Neck", f, y=yw * 0.3, x=4 * rc)
    rot("Spine", f, x=9 * rc)
    rot("Chest", f, x=6 * rc)
    move("Hips", f, (0.0, -0.018 * rc, 0.07 * rc))                                   # back, and a little lower
    rot("Hips", f, y=-yw * 0.15)
    for s_, sg in (("Left", 1), ("Right", -1)):
        rot(s_ + "Shoulder", f, z=sg * 5 * rc, x=-3 * rc)
        rot(s_ + "UpperArm", f, x=38 * rc, z=sg * 8 * rc)
        rot(s_ + "LowerArm", f, x=(8 + 58 * rc))
        rot(s_ + "Hand", f, z=10 * rc)
        rot(s_ + "UpperLeg", f, x=(12 if sg > 0 else -6) * rc)
        rot(s_ + "LowerLeg", f, x=-(6 + 14 * rc))
        rot(s_ + "Foot", f, x=-6 * rc)
        for fn in FINGERS:
            for j_, n_ in enumerate(FINGER_BONES[s_ + fn]):
                rot(n_, f, x=POSES["relaxed"][fn][j_] * k_open * FLEX[s_])
bpy.ops.object.mode_set(mode='OBJECT')
rig.animation_data.action = bpy.data.actions["idle-loop"]

# ---- debug renders: rig overlay and deformation tests
if debug:
    w = bpy.data.worlds.new("w")
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (.20, .21, .24, 1)
    bpy.context.scene.world = w
    for rot_, en in (((50, 0, -35), 3.0), ((70, 0, 140), 1.0), ((100, 0, 200), 0.8)):
        bpy.ops.object.light_add(type='SUN')
        L = bpy.context.object
        L.rotation_euler = [math.radians(x) for x in rot_]
        L.data.energy = en
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_EEVEE'
    sc.view_settings.view_transform = 'Standard'
    cam = bpy.data.cameras.new("c")
    cam.type = 'ORTHO'
    co_ = bpy.data.objects.new("c", cam)
    sc.collection.objects.link(co_)
    sc.camera = co_
    dbg = os.path.join(BASE_DIR, "work/rig_debug")
    os.makedirs(dbg, exist_ok=True)
    rig.show_in_front = True
    arm_data.display_type = 'STICK'

    def shot(name, az=0, zc=0.83, scale=1.9, rx=520, ry=860):
        t = math.radians(az + 180)                 # she faces +Y: the camera starts in front of her
        cam.ortho_scale = scale
        sc.render.resolution_x, sc.render.resolution_y = rx, ry
        co_.location = (8 * math.sin(t), -8 * math.cos(t), zc)
        co_.rotation_euler = (math.pi / 2, 0, t)
        sc.render.filepath = os.path.join(dbg, name + ".png")
        bpy.ops.render.render(write_still=True)

    # the rig over the mesh (bones drawn in front)
    shot("rig_front")
    shot("rig_side", az=90)
    rig.hide_render = True
    rig.animation_data.action = None                 # the idle action would override the keyed bones during the tests
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode='POSE')
    tests = {
        "pose_rest": {},
        "pose_elbows": {"LeftLowerArm": (95, 0, 0), "RightLowerArm": (95, 0, 0)},
        "pose_shoulders": {"LeftUpperArm": (0, 0, 55), "RightUpperArm": (0, 0, -55), "LeftLowerArm": (30, 0, 0), "RightLowerArm": (30, 0, 0)},
        "pose_arms_forward": {"LeftUpperArm": (85, 0, 0), "RightUpperArm": (85, 0, 0)},
        "pose_knees": {"LeftUpperLeg": (50, 0, 0), "LeftLowerLeg": (-80, 0, 0), "RightUpperLeg": (-15, 0, 0), "RightLowerLeg": (-10, 0, 0)},
        "pose_hips_sit": {"LeftUpperLeg": (85, 0, 0), "RightUpperLeg": (85, 0, 0), "LeftLowerLeg": (-85, 0, 0), "RightLowerLeg": (-85, 0, 0), "Spine": (-8, 0, 0)},
        "pose_head": {"Head": (0, 0, 0), "Neck": (0, 0, 0)},
    }
    tests["pose_head"] = {"Head": (0, 55, 0), "Neck": (0, 15, 0)}
    for name, pose in tests.items():
        for pb in rig.pose.bones:
            pb.rotation_euler = (0, 0, 0)
            pb.location = (0, 0, 0)
        for bn, (x, y, z) in pose.items():
            rig.pose.bones[bn].rotation_euler = Euler((math.radians(x), math.radians(y), math.radians(z)), 'XYZ')
        bpy.context.view_layer.update()
        shot(name + "_three", az=35, scale=1.9, rx=520, ry=860)
        shot(name + "_side", az=90, scale=1.9, rx=520, ry=860)
        if name == "pose_head":
            shot("pose_head_close_three", az=35, zc=1.5, scale=0.55, rx=520, ry=520)
            shot("pose_head_close_side", az=90, zc=1.5, scale=0.55, rx=520, ry=520)
            shot("pose_head_close_front", az=0, zc=1.5, scale=0.55, rx=520, ry=520)
    bpy.ops.object.mode_set(mode='OBJECT')
    rig.hide_render = False
    for pb in rig.pose.bones:
        pb.rotation_euler = (0, 0, 0)
        pb.location = (0, 0, 0)
    rig.animation_data.action = bpy.data.actions["idle-loop"]

# ---- save the Blender source and export the GLB
json.dump({"walk_ground_speed": WALK_SPEED, "walk_cycle_s": T36 / FPS, "stride_m": STRIDE, "height_m": HEIGHT}, open(os.path.join(glb_dir, "%s.json" % SLUG), "w"), indent=1)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out_dir, "npc_meshy.blend"))
bpy.ops.object.select_all(action='DESELECT')
src.select_set(True)
rig.select_set(True)
for o_ in decal_objs:
    o_.select_set(True)
bpy.context.view_layer.objects.active = rig
glb = os.path.join(glb_dir, "CHR_%s_Meshy.glb" % SLUG)
bpy.ops.export_scene.gltf(filepath=glb, export_format='GLB', use_selection=True, export_animations=True,
                          export_animation_mode='ACTIONS', export_skins=True, export_yup=True, export_image_format='AUTO',
                          export_normals=True, export_apply=False)
print("GLB", glb, os.path.getsize(glb))
