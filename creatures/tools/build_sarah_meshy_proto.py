"""THE VEIL - game-ready prototype of the Meshy Sarah (Blender 5.x, headless).
Reads the untouched Meshy OBJ, puts the character upright at game scale facing +Y (the convention of the existing
Sarah: it exports as glTF -Z, Godot's forward), welds the vertices, flat-shades it (PSX look), assigns ONE material with
the 512 nearest-neighbour texture, builds a basic humanoid armature (Godot humanoid bone names), skins it, makes three
temporary animations (idle, walk, head_turn) and exports a GLB. Optional debug renders (rig overlay, deformation tests).
   blender -b -P build_sarah_meshy_proto.py -- <repo_root> [debug]
Writes only under creatures/humans/sarah_meshy/game_ready/ and game/prototypes/sarah_meshy/."""
import bpy, bmesh, sys, os, math, json
import numpy as np
from mathutils import Vector, Matrix, Euler

args = sys.argv[sys.argv.index("--") + 1:]
root = args[0]
debug = len(args) > 1 and args[1] == "debug"
base = os.path.join(root, "creatures/humans/sarah_meshy")
out_dir = os.path.join(base, "game_ready")
glb_dir = os.path.join(root, "game/prototypes/sarah_meshy")
os.makedirs(out_dir, exist_ok=True)
os.makedirs(glb_dir, exist_ok=True)
TEX = os.path.join(base, "work/textures/material_0_diffuse_512_nearest.png")
HEIGHT = 1.66                                   # metres, the existing Sarah's size
RAW_H = 0.951                                   # the Meshy model's own height
S = HEIGHT / RAW_H

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.wm.obj_import(filepath=os.path.join(base, "source/original/mara_vale_lowpoly.obj"))
src = [o for o in bpy.context.scene.objects if o.type == 'MESH'][0]
src.rotation_euler = (0, 0, 0)                  # the importer leaves a 90 degree axis rotation on the object: the vertices below are in file coordinates
src.scale = (1, 1, 1)
src.location = (0, 0, 0)
bpy.context.view_layer.update()
me = src.data
# the OBJ arrives as file coordinates (x = her left, y up, z = front). -> Blender: X = -x, Y = z (front +Y), Z = y (up), scaled, feet on Z = 0
co = np.empty(len(me.vertices) * 3)
me.vertices.foreach_get("co", co)
co = co.reshape(-1, 3)
feet = co[:, 1].min()
new = np.stack([-co[:, 0] * S, co[:, 2] * S, (co[:, 1] - feet) * S], axis=1)
me.vertices.foreach_set("co", new.reshape(-1))
me.update()
# flip normals/winding is not needed (a proper rotation); the face sits at +Y

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
src.name = "Sarah_Meshy_Body"
me.name = "Sarah_Meshy_Body"
mat = bpy.data.materials.new("Sarah_Meshy_Mat")
mat.use_nodes = True
nt = mat.node_tree
b = nt.nodes["Principled BSDF"]
b.inputs["Roughness"].default_value = 1.0
try:
    b.inputs["Specular IOR Level"].default_value = 0.0
except Exception:
    pass
tn = nt.nodes.new("ShaderNodeTexImage")
tn.image = bpy.data.images.load(TEX)
tn.image.name = "sarah_meshy_512_nearest"
tn.interpolation = "Closest"
nt.links.new(tn.outputs["Color"], b.inputs["Base Color"])
me.materials.clear()
me.materials.append(mat)
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


# ---- armature (landmarks in RAW file coordinates; side +x is her left)
def P(x, y, z=0.0):
    return Vector((-x * S, z * S, (y - feet) * S))


LM = {
    "Hips": (P(0, -0.03), P(0, 0.06)),
    "Spine": (P(0, 0.06), P(0, 0.18)),
    "Chest": (P(0, 0.18), P(0, 0.30)),
    "Neck": (P(0, 0.30), P(0, 0.365)),
    "Head": (P(0, 0.365), P(0, 0.475)),
}
for side, sx in (("Left", 1), ("Right", -1)):
    LM[side + "Shoulder"] = (P(sx * 0.015, 0.29), P(sx * 0.085, 0.295))
    LM[side + "UpperArm"] = (P(sx * 0.085, 0.295), P(sx * 0.165, 0.150))
    LM[side + "LowerArm"] = (P(sx * 0.165, 0.150), P(sx * 0.215, 0.035))
    LM[side + "Hand"] = (P(sx * 0.215, 0.035), P(sx * 0.248, -0.012))
    LM[side + "UpperLeg"] = (P(sx * 0.055, -0.03), P(sx * 0.058, -0.245))
    LM[side + "LowerLeg"] = (P(sx * 0.058, -0.245), P(sx * 0.055, -0.428))
    LM[side + "Foot"] = (P(sx * 0.055, -0.428, -0.005), P(sx * 0.055, -0.468, 0.055))
    LM[side + "Toes"] = (P(sx * 0.055, -0.468, 0.055), P(sx * 0.055, -0.472, 0.088))
# ---- fingers: placed from the actual hand vertices (the hands are symmetric: 5 separate fingers hanging down, thumb to the front)
FINGERS = ["Thumb", "Index", "Middle", "Ring", "Little"]
GODOT_NAMES = {"Thumb": ("Metacarpal", "Proximal", "Distal"), "Index": ("Proximal", "Intermediate", "Distal"), "Middle": ("Proximal", "Intermediate", "Distal"),
               "Ring": ("Proximal", "Intermediate", "Distal"), "Little": ("Proximal", "Intermediate", "Distal")}
BANDS = {"Index": (0.012, 0.040), "Middle": (-0.014, 0.012), "Ring": (-0.036, -0.014), "Little": (-0.07, -0.036)}
vw = np.empty(len(me.vertices) * 3)
me.vertices.foreach_get("co", vw)
vw = vw.reshape(-1, 3)
HANDINFO = {}
for side, sg in (("Left", -1), ("Right", 1)):
    H = vw[(sg * vw[:, 0] > 0.30) & (vw[:, 2] < 0.95)]
    wrist = H[(H[:, 2] >= 0.93)].mean(0)
    wrist[2] = 0.935
    chains = {}
    palm = H[(H[:, 2] >= 0.868) & (H[:, 2] < 0.886)]
    for f in FINGERS:
        if f == "Thumb":
            band = H[(H[:, 1] > 0.040) & (H[:, 2] < 0.915)]
            tip = band[np.argsort(band[:, 2])[:3]].mean(0)
            base = np.array([wrist[0] - sg * 0.025 * -1 * 0 + sg * 0.0, 0.040, 0.905])
            base[0] = band[:, 0].mean() if len(band) else wrist[0]
            base = np.array([base[0], 0.040, 0.905])
        else:
            lo, hi = BANDS[f]
            band = H[(H[:, 1] >= lo) & (H[:, 1] < hi) & (H[:, 2] < 0.886)]
            tip = band[np.argsort(band[:, 2])[:3]].mean(0)
            pb = palm[(palm[:, 1] >= lo) & (palm[:, 1] < hi)]
            bx = pb[:, 0].mean() if len(pb) else band[:, 0].mean()
            base = np.array([bx, (lo + hi) / 2 if f != "Little" else -0.043, 0.877])
        j2 = base + 0.45 * (tip - base)
        j3 = base + 0.75 * (tip - base)
        chains[f] = [(base, j2), (j2, j3), (j3, tip)]
    palm_end = np.mean([chains[f][0][0] for f in ("Index", "Middle", "Ring", "Little")], axis=0)
    HANDINFO[side] = (wrist, palm_end, chains)
    LM[side + "Hand"] = (Vector(wrist), Vector(palm_end))
    LM[side + "LowerArm"] = (LM[side + "LowerArm"][0], Vector(wrist))
    for f in FINGERS:
        for i, (a_, b_) in enumerate(chains[f]):
            LM["%s%s%s" % (side, f, GODOT_NAMES[f][i])] = (Vector(a_), Vector(b_))
print("HANDINFO left wrist", HANDINFO["Left"][0].round(3), "palm end", HANDINFO["Left"][1].round(3))
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

arm_data = bpy.data.armatures.new("Sarah_Meshy_Rig")
rig = bpy.data.objects.new("Sarah_Meshy_Rig", arm_data)
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
if unw > 0 or len(src.vertex_groups) < len(ORDER) - 4:
    print("AUTOWEIGHT incomplete: falling back to distance weights")
    src.vertex_groups.clear()
    segs = {n: (LM[n][0], LM[n][1]) for n in ORDER if n not in ("Toes",)}
    segs["Toes"] = LM["Toes"]
    groups = {n: src.vertex_groups.new(name=n) for n in ORDER}
    pts = np.array([(src.matrix_world @ vx.co)[:] for vx in me.vertices])
    names = list(segs)
    W = np.zeros((len(pts), len(names)))
    for j, n in enumerate(names):
        a, bb = np.array(segs[n][0][:]), np.array(segs[n][1][:])
        ab = bb - a
        tt = np.clip(((pts - a) @ ab) / (ab @ ab), 0, 1)
        d = np.linalg.norm(pts - (a + tt[:, None] * ab), axis=1)
        W[:, j] = 1.0 / (d + 0.02) ** 3
    W /= W.sum(1, keepdims=True)
    for i in range(len(pts)):
        for j in np.argsort(-W[i])[:4]:
            if W[i, j] > 0.02:
                groups[names[j]].add([i], float(W[i, j]), 'REPLACE')

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
    pb.keyframe_insert("rotation_euler", frame=frame)


def move(name, frame, loc):
    pb = rig.pose.bones[name]
    pb.location = loc
    pb.keyframe_insert("location", frame=frame)


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
    bpy.context.scene.frame_start = 1
    bpy.context.scene.frame_end = length
    return act


# hand poses: per finger (knuckle, middle joint, tip joint) flexion in degrees; spread is the sideways fan at the knuckle
POSES = {
    "relaxed": {"Thumb": (6, 8, 6), "Index": (10, 14, 8), "Middle": (14, 18, 10), "Ring": (18, 20, 12), "Little": (22, 22, 14)},
    "open": {"Thumb": (0, 0, 0), "Index": (0, 0, 0), "Middle": (0, 0, 0), "Ring": (0, 0, 0), "Little": (0, 0, 0)},
    "fist": {"Thumb": (30, 40, 30), "Index": (80, 100, 65), "Middle": (85, 105, 65), "Ring": (85, 105, 65), "Little": (85, 100, 60)},
    "grip": {"Thumb": (25, 20, 12), "Index": (25, 20, 10), "Middle": (65, 80, 50), "Ring": (70, 85, 52), "Little": (72, 85, 52)},
    "point": {"Thumb": (25, 30, 20), "Index": (0, 0, 0), "Middle": (85, 105, 65), "Ring": (85, 105, 65), "Little": (85, 100, 60)},
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
        rot(s_ + "LowerArm", f, x=-(5 + 3 * br))
        rot(s_ + "Shoulder", f, z=sg * 0.8 * br)
        rot(s_ + "Hand", f, x=2 * br * FLEX[s_])
for f, yw, pt in ((1, 0.0, 0.0), (37, 3.0, 0.5), (73, -2.5, -0.5), (109, 4.0, 0.8), (145, 0.0, 0.0)):
    rot("Neck", f, y=yw)
for side in ("Left", "Right"):
    for f, k in ((1, 1.0), (49, 1.15), (97, 0.9), (145, 1.0)):
        hand_pose(side, "relaxed", f, k)
# -- walk: 1.5 s cycle (36 frames). Thigh +-36, knee up to 55, foot 20, arm swing +-31, forearm 8..30, wrist +-20, fingers relaxed with thumb/index flicker
act = new_action("walk-loop", 37)
N = 36
for f in range(1, 38, 3):
    ph = (f - 1) / N
    a = math.sin(ph * 2 * math.pi)
    c = math.cos(ph * 2 * math.pi)
    for s_, sg in (("Left", 1), ("Right", -1)):
        sw = a * sg                                       # +1 = this leg forward
        lift = max(0.0, math.sin((ph * sg + (0.0 if sg > 0 else 0.5) + 0.25) * 2 * math.pi)) if False else max(0.0, -c * sg)
        rot(s_ + "UpperLeg", f, x=36 * sw)
        rot(s_ + "LowerLeg", f, x=-(6 + 49 * lift))
        rot(s_ + "Foot", f, x=-20 * sw + 8 * lift)
        rot(s_ + "UpperArm", f, x=-31 * sw, z=sg * 3)
        rot(s_ + "LowerArm", f, x=-(8 + 22 * max(0.0, -sw)))
        rot(s_ + "Hand", f, x=-18 * sw * FLEX[s_] * -1)
        rot(s_ + "Shoulder", f, z=sg * 2 * sw)
        for fn, fk in (("Thumb", 1.0), ("Index", 1.0)):
            for i, n_ in enumerate(FINGER_BONES[s_ + fn]):
                rot(n_, f, x=(POSES["relaxed"][fn][i] + 8 * sw * (1 if i == 0 else 0.5)) * FLEX[s_])
        for fn in ("Middle", "Ring", "Little"):
            for i, n_ in enumerate(FINGER_BONES[s_ + fn]):
                rot(n_, f, x=POSES["relaxed"][fn][i] * FLEX[s_])
    rot("Hips", f, z=7 * a, y=0)
    rot("Spine", f, z=-5 * a, x=1.0)
    rot("Chest", f, z=-5 * a)
    rot("Head", f, z=4 * a)
    move("Hips", f, (0, 0, -0.025 * abs(c)))
# -- head turn: look left, look right, back (3 s)
act = new_action("head_turn", 72)
for f, yw in ((1, 0), (19, 55), (37, 0), (55, -55), (72, 0)):
    rot("Head", f, y=yw * 0.7)
    rot("Neck", f, y=yw * 0.3)
for side in ("Left", "Right"):
    hand_pose(side, "relaxed", 1)
    hand_pose(side, "relaxed", 72)
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
    dbg = os.path.join(base, "work/rig_debug")
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
        "pose_elbows": {"LeftLowerArm": (-95, 0, 0), "RightLowerArm": (-95, 0, 0)},
        "pose_shoulders": {"LeftUpperArm": (0, 0, 55), "RightUpperArm": (0, 0, -55), "LeftLowerArm": (-30, 0, 0), "RightLowerArm": (-30, 0, 0)},
        "pose_arms_forward": {"LeftUpperArm": (-85, 0, 0), "RightUpperArm": (-85, 0, 0)},
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
    bpy.ops.object.mode_set(mode='OBJECT')
    rig.hide_render = False
    for pb in rig.pose.bones:
        pb.rotation_euler = (0, 0, 0)
        pb.location = (0, 0, 0)
    rig.animation_data.action = bpy.data.actions["idle-loop"]

# ---- save the Blender source and export the GLB
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out_dir, "sarah_meshy_proto.blend"))
bpy.ops.object.select_all(action='DESELECT')
src.select_set(True)
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
glb = os.path.join(glb_dir, "CHR_Sarah_Meshy_Proto.glb")
bpy.ops.export_scene.gltf(filepath=glb, export_format='GLB', use_selection=True, export_animations=True,
                          export_animation_mode='ACTIONS', export_skins=True, export_yup=True, export_image_format='AUTO',
                          export_normals=True, export_apply=False)
print("GLB", glb, os.path.getsize(glb))
