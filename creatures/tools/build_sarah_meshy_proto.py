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

# ---- the head moves as one piece: automatic weights split the chin, jaw and hair between Neck and Head, so a head turn tore the face.
# Everything from the middle of the neck upward is blended to 100% Head (full at the top of the neck), whatever the hair or jaw does.
HEAD_Z0 = P(0, 0.320).z                         # blend starts inside the neck
HEAD_Z1 = P(0, 0.338).z                         # fully Head from here up (below the chin)
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

# ---- face expression decals (stage C): small conforming patches, each a crop of her own face texels with one feature edited.
# Painted by meshy_face_paint.py from meshy_face_capture.py; here they are laid onto the real face surface (ray cast from the front,
# 1.8 mm off the skin), skinned 100% to the Head bone, and exported as separate meshes the game shows / hides (no extra weight, no rebuild).
FACE_DIR = os.path.join(root, "creatures/humans/sarah_meshy/work/face")
decal_objs = []
if os.path.exists(os.path.join(FACE_DIR, "face_atlas.json")):
    atl = json.load(open(os.path.join(FACE_DIR, "face_atlas.json")))
    cap = json.load(open(os.path.join(FACE_DIR, "face_capture.json")))
    RES_, CX_, CZ_, SIZE_ = cap["res"], cap["cx"], cap["cz"], cap["size"]
    AW_, AH_ = atl["atlas"]
    dmat = bpy.data.materials.new("Sarah_Face_Decals")
    dmat.use_nodes = True
    dn = dmat.node_tree
    db = dn.nodes["Principled BSDF"]
    db.inputs["Roughness"].default_value = 1.0
    try:
        db.inputs["Specular IOR Level"].default_value = 0.0
    except Exception:
        pass
    dt = dn.nodes.new("ShaderNodeTexImage")
    dt.image = bpy.data.images.load(os.path.join(FACE_DIR, "face_atlas.png"))
    dt.image.name = "sarah_face_atlas"
    dt.interpolation = "Closest"
    dn.links.new(dt.outputs["Color"], db.inputs["Base Color"])
    by_name = {}
    for pt in atl["patches"]:
        by_name.setdefault(pt["name"], []).append(pt)
    for name, plist in by_name.items():
        bmd = bmesh.new()
        uvl = bmd.loops.layers.uv.new("uv")
        for pt in plist:
            x0, y0, x1, y1 = pt["box"]
            ax, ay, aw, ah = pt["atlas"]
            NX, NY = 10, 6
            grid = []
            for j in range(NY + 1):
                row = []
                for i in range(NX + 1):
                    u = x0 + (x1 - x0) * i / NX
                    v = y0 + (y1 - y0) * j / NY
                    X = CX_ - (u - RES_ / 2) * SIZE_ / RES_
                    Z = CZ_ - (v - RES_ / 2) * SIZE_ / RES_
                    hit, loc, nor, idx = src.ray_cast(Vector((X, 2.0, Z)), Vector((0, -1, 0)))
                    pos = (loc + nor * 0.0018) if hit else Vector((X, 0.12, Z))
                    row.append((bmd.verts.new(pos), (ax + aw * i / NX) / AW_, 1.0 - (ay + ah * j / NY) / AH_))
                grid.append(row)
            for j in range(NY):
                for i in range(NX):
                    quad = (grid[j][i], grid[j + 1][i], grid[j + 1][i + 1], grid[j][i + 1])          # wound so the face looks toward +Y (the front)
                    try:
                        fc = bmd.faces.new([q[0] for q in quad])
                    except ValueError:
                        continue
                    for lp, q in zip(fc.loops, quad):
                        lp[uvl].uv = (q[1], q[2])
        dme = bpy.data.meshes.new("Face_" + name)
        bmd.to_mesh(dme)
        bmd.free()
        dob = bpy.data.objects.new("Face_" + name, dme)
        bpy.context.scene.collection.objects.link(dob)
        dme.materials.append(dmat)
        for p_ in dme.polygons:
            p_.use_smooth = False
        g_ = dob.vertex_groups.new(name="Head")
        g_.add(list(range(len(dme.vertices))), 1.0, 'REPLACE')
        md = dob.modifiers.new("Armature", 'ARMATURE')
        md.object = rig
        dob.parent = rig
        dob.hide_render = True                 # off in Blender renders; the game shows them through the face controller
        decal_objs.append(dob)
    print("DECALS", [o.name for o in decal_objs])

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
STRIDE, STANCE, T36 = 0.46, 0.60, 36
HIP_H = 0.735
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
    dbg = os.path.join(root, "creatures/humans/sarah_meshy/work/rig_debug")
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
json.dump({"walk_ground_speed": WALK_SPEED, "walk_cycle_s": T36 / FPS, "stride_m": STRIDE, "height_m": HEIGHT}, open(os.path.join(glb_dir, "sarah_meshy_proto.json"), "w"), indent=1)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out_dir, "sarah_meshy_proto.blend"))
bpy.ops.object.select_all(action='DESELECT')
src.select_set(True)
rig.select_set(True)
for o_ in decal_objs:
    o_.select_set(True)
bpy.context.view_layer.objects.active = rig
glb = os.path.join(glb_dir, "CHR_Sarah_Meshy_Proto.glb")
bpy.ops.export_scene.gltf(filepath=glb, export_format='GLB', use_selection=True, export_animations=True,
                          export_animation_mode='ACTIONS', export_skins=True, export_yup=True, export_image_format='AUTO',
                          export_normals=True, export_apply=False)
print("GLB", glb, os.path.getsize(glb))
