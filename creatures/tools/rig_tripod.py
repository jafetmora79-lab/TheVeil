"""THE VEIL - the Meshy 'tripod bonecage' creature (Blender 5.x, headless): joins its floating third leg to the body with a bridging limb, rigs it
(Body + three legs of Up/Lo/Foot), keys idle and a slow tripod walk, and exports a GLB that faces Godot -Z (the game's forward).
   blender -b -P rig_tripod.py -- <repo_root> <height_m> [preview]
Source: creatures/monsters/source/tripod.glb.  Writes game/prototypes/monsters_meshy/MON_tripod.glb (+ tripod.json) and creatures/monsters/tripod/.
The bridge is plain geometry using the leg's own texture patch (no repainting); skinning is per-vertex nearest-bone with a short blend at the joints."""
import bpy, bmesh, sys, os, math, json
import numpy as np
from mathutils import Vector, Matrix, Quaternion

args = sys.argv[sys.argv.index("--") + 1:]
root, height_m = args[0], float(args[1])
preview = "preview" in args
NOBRIDGE = "gap" not in args                         # the fixed model (leg already joined) needs no bridge; pass `gap` for the original Meshy file
FPS = 24
glb_dir = os.path.join(root, "game/prototypes/monsters_meshy")
work = os.path.join(root, "creatures/monsters/tripod")
os.makedirs(work, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.join(root, "creatures/monsters/source/tripod.glb"))
src = [o for o in bpy.context.scene.objects if o.type == 'MESH'][0]
src.parent = None
src.matrix_world = Matrix.Identity(4)
bpy.context.view_layer.update()
me = src.data


def verts():
    return np.array([v.co[:] for v in me.vertices])


V = verts()
# ------------------------------------------------------------------ 1. the third leg: find it (rear, y > 0.14) and where the body's back is
rear = V[V[:, 1] > 0.14]
top_z = float(rear[:, 2].max())
A = rear[rear[:, 2] > top_z - 0.035].mean(0)                     # the top of the loose leg
bodyback = V[(V[:, 1] < -0.04) & (V[:, 2] > 0.06) & (V[:, 2] < 0.24) & (np.abs(V[:, 0]) < 0.16)]
ymax_body = float(bodyback[:, 1].max())
Bp = bodyback[bodyback[:, 1] > ymax_body - 0.025].mean(0)         # the rear-most part of the torso at about hip height
B = np.array([Bp[0] * 0.7, Bp[1] - 0.012, Bp[2]])               # meets the back of the torso
print("BRIDGE leg top", A.round(3), "body back", Bp.round(3), "-> B", B.round(3))

# UV of the leg's own texture near its top: the bridge uses that patch
uvl = me.uv_layers.active
vuv = np.zeros((len(me.vertices), 2))
cnt = np.zeros(len(me.vertices))
for lp in me.loops:
    vuv[lp.vertex_index] += np.array(uvl.data[lp.index].uv)
    cnt[lp.vertex_index] += 1
vuv /= np.maximum(cnt, 1)[:, None]
near_top = np.where((V[:, 1] > 0.14) & (V[:, 2] > top_z - 0.12))[0]
img = [nd.image for nd in me.materials[0].node_tree.nodes if nd.type == 'TEX_IMAGE'][0]
IW, IH = img.size
PX = np.array(img.pixels[:]).reshape(IH, IW, 4)


def texel(uv):
    return PX[min(IH - 1, max(0, int(uv[1] * IH))), min(IW - 1, max(0, int(uv[0] * IW)))][:3]


cols = np.array([texel(vuv[i]) for i in near_top])
lum = cols.mean(1)
bone_uv = vuv[near_top[int(np.argsort(lum)[int(len(lum) * 0.8)])]]      # a light bone-coloured patch of the leg's own texture
flesh_uv = vuv[near_top[int(np.argsort(lum)[int(len(lum) * 0.1)])]]     # a dark sinew-coloured one
print("BRIDGE uv bone", bone_uv.round(3), texel(bone_uv).round(2), "flesh", flesh_uv.round(3), texel(flesh_uv).round(2))
uv_c = bone_uv

if NOBRIDGE:
    B = np.array([0.03, -0.07, -0.02])
    A = B
else:
    bm = bmesh.new()
    bm.from_mesh(me)
    uvb = bm.loops.layers.uv.active
    SEG, SIDES = 6, 8
    a0 = Vector(A) + Vector((0, 0, -0.035))                          # starts inside the leg
    b0 = Vector(B)
    axis = (b0 - a0).normalized()
    side_a = axis.cross(Vector((1, 0, 0))).normalized()
    side_b = axis.cross(side_a).normalized()
    rings = []
    for i in range(SEG + 1):
        t = i / SEG
        c = a0.lerp(b0, t) + Vector((0, 0.025 * math.sin(math.pi * t), 0))     # a slight outward bow, like a knee
        r = 0.022 + 0.012 * t + 0.005 * math.sin(math.pi * t)
        ring = []
        for k in range(SIDES):
            ang = 2 * math.pi * k / SIDES
            ring.append(bm.verts.new(c + (side_a * math.cos(ang) + side_b * math.sin(ang)) * r))
        rings.append(ring)
    for i in range(SEG):
        for k in range(SIDES):
            f = bm.faces.new((rings[i][k], rings[i][(k + 1) % SIDES], rings[i + 1][(k + 1) % SIDES], rings[i + 1][k]))
            pick = flesh_uv if (k * 3 + i * 5) % 7 in (0,) else bone_uv        # sinew and bone patches, a flat colour per face
            for lp in f.loops:
                lp[uvb].uv = (pick[0], pick[1])
    bm.to_mesh(me)
    bm.free()
    me.update()
V = verts()
print("BRIDGE", "none (leg already joined)" if NOBRIDGE else "added")

# ------------------------------------------------------------------ 2. landmarks (still in the GLB's own coordinates: front is -Y, legs end at z = -0.476)
low = V[V[:, 2] < -0.43][:, :2]


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


feet = kmeans(low, 3)
ri = int(np.argmax(feet[:, 1]))
fr = sorted([i for i in range(3) if i != ri], key=lambda i: feet[i][0])
leg_defs = {"Leg_L": feet[fr[0]], "Leg_R": feet[fr[1]], "Leg_B": feet[ri]}      # final names: left / right / back (x is mirrored below)
print("FEET", {k: v.round(3) for k, v in leg_defs.items()})


def seg_dist(P, a, b):
    ab = b - a
    t = np.clip(((P - a) @ ab) / max(float(ab @ ab), 1e-9), 0, 1)
    return np.linalg.norm(P - (a + t[:, None] * ab), axis=1)


def centroid_at(P, z, half=0.03):
    m = P[(P[:, 2] > z - half) & (P[:, 2] < z + half)]
    return m.mean(0) if len(m) else None


bones = []                                           # (name, head, tail, parent) in the GLB's coordinates
bones.append(("Body", np.array([0, -0.10, -0.05]), np.array([0, -0.10, 0.46]), None))
LEGS = []
for name, fx in leg_defs.items():
    if name == "Leg_B":
        hip = B
    else:
        hip = np.array([fx[0] * 0.4, -0.12, -0.03])
    top = A if name == "Leg_B" else hip
    mask = (V[:, 2] < -0.05) & (np.linalg.norm(V[:, :2] - fx, axis=1) < 0.20)
    seg_d = seg_dist(V, top, np.array([fx[0], fx[1], -0.476]))
    mask = (seg_d < 0.075) & (V[:, 2] < -0.04)
    P = V[mask]
    knee = centroid_at(P, -0.26) if centroid_at(P, -0.26) is not None else (top + np.array([fx[0], fx[1], -0.476])) / 2
    ankle = centroid_at(P, -0.42, 0.04)
    ankle = ankle if ankle is not None else np.array([fx[0], fx[1], -0.42])
    knee[2], ankle[2] = -0.26, -0.42
    toe = np.array([ankle[0], ankle[1] - 0.045, -0.476])
    bones.append((name + "_Up", hip, knee, "Body"))
    bones.append((name + "_Lo", knee, ankle, name + "_Up"))
    bones.append((name + "_Foot", ankle, toe, name + "_Lo"))
    LEGS.append((name, hip, knee, ankle, toe))
    print("LEG", name, "hip", np.round(hip, 3), "knee", np.round(knee, 3), "ankle", np.round(ankle, 3), "pts", int(mask.sum()))

# ------------------------------------------------------------------ 3. skin weights per vertex: nearest bone segments, short blend (computed here, in the GLB's frame)
SIGMA = 0.012
D = np.stack([seg_dist(V, b[1], b[2]) for b in bones], axis=1)       # (n verts, n bones)
Wt = np.exp(-(D - D.min(1, keepdims=True)) / SIGMA)
# keep the 3 strongest, normalise
order = np.argsort(-Wt, axis=1)
mask3 = np.zeros_like(Wt, dtype=bool)
np.put_along_axis(mask3, order[:, :3], True, axis=1)
Wt = np.where(mask3, Wt, 0.0)
Wt = np.where(Wt < 0.04 * Wt.max(1, keepdims=True), 0.0, Wt)
Wt /= Wt.sum(1, keepdims=True)

# ------------------------------------------------------------------ 4. orient (a half turn about Z so the front looks +Y = Godot -Z), scale, ground; flat-shade
Vf = V.copy()
Vf[:, 0] *= -1
Vf[:, 1] *= -1
mn, mx = Vf.min(0), Vf.max(0)
S = height_m / float(mx[2] - mn[2])
ctr = np.array([(mn[0] + mx[0]) / 2, (mn[1] + mx[1]) / 2, mn[2]])


def tf(p):
    q = np.array([-p[0], -p[1], p[2]], dtype=float)
    return Vector(((q - ctr) * S).tolist())


me.vertices.foreach_set("co", ((Vf - ctr) * S).reshape(-1))
me.update()
for p in me.polygons:
    p.use_smooth = False
for nd in me.materials[0].node_tree.nodes:
    if nd.type == 'TEX_IMAGE':
        nd.interpolation = "Closest"
src.name = "Tripod_Body"
VS = verts()
print("TRIPOD size", (VS.max(0) - VS.min(0)).round(2), "scale", round(S, 3))

arm = bpy.data.armatures.new("Tripod_Rig")
rig = bpy.data.objects.new("Tripod_Rig", arm)
bpy.context.scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='EDIT')
fbones = []
for name, h, t, par in bones:
    eb = arm.edit_bones.new(name)
    eb.head, eb.tail = tf(h), tf(t)
    fbones.append((name, tf(h), tf(t), par))
for name, h, t, par in bones:
    if par:
        arm.edit_bones[name].parent = arm.edit_bones[par]
bpy.ops.object.mode_set(mode='OBJECT')
for j, (name, *_r) in enumerate(bones):
    vg = src.vertex_groups.new(name=name)
    idx = np.where(Wt[:, j] > 0)[0]
    for i in idx:
        vg.add([int(i)], float(Wt[i, j]), 'REPLACE')
src.parent = rig
mod = src.modifiers.new("Armature", 'ARMATURE')
mod.object = rig

# ------------------------------------------------------------------ 5. animation
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='POSE')
for pb in rig.pose.bones:
    pb.rotation_mode = 'QUATERNION'
REST = {b.name: b.matrix_local.to_3x3() for b in rig.data.bones}


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


bpy.context.scene.render.fps = FPS
FL = {n: (h, k, a, t) for n, h, k, a, t in [(l[0], tf(l[1]), tf(l[2]), tf(l[3]), tf(l[4])) for l in LEGS]}
info = {"kind": "tripod", "height_m": height_m, "facing": "-Z"}

# idle: a slow breath; the body sways a little over its legs
new_action("Idle-loop", 120)
for f in range(1, 122):
    t = (f - 1) / 120.0
    key("Body", f, wrot("Body", (1, 0, 0), math.radians(1.1) * math.sin(2 * math.pi * t)) @ wrot("Body", (0, 1, 0), math.radians(0.8) * math.sin(2 * math.pi * t + 1.0)))

# walk: a tripod gait. Each leg is in the air for a third of the cycle, the three take turns (L, back, R); a foot is planted while it is on the ground.
T = 120                                              # 5 s per cycle
STRIDE = 0.2 * height_m
new_action("Walk_Heavy-loop", T + 1)
PH = {"Leg_L": 0.0, "Leg_B": 1.0 / 3.0, "Leg_R": 2.0 / 3.0}
for f in range(1, T + 2):
    ph0 = ((f - 1) % T) / T
    for name, (hip, knee, ankle, toe) in FL.items():
        L = (hip - ankle).length
        reach = math.asin(min(0.9, STRIDE * 0.5 / L))
        ph = (ph0 - PH[name]) % 1.0
        if ph < 1.0 / 3.0:                           # swing: lifted and carried forward (+Y)
            u = ph * 3.0
            s, lift = -1.0 + 2.0 * u, math.sin(math.pi * u)
        else:                                        # stance: planted, the body moves over it
            u = (ph - 1.0 / 3.0) / (2.0 / 3.0)
            s, lift = 1.0 - 2.0 * u, 0.0
        a_up = reach * s + math.radians(22) * lift
        a_lo = -math.radians(55) * lift
        key(name + "_Up", f, wrot(name + "_Up", (1, 0, 0), a_up))
        key(name + "_Lo", f, wrot(name + "_Lo", (1, 0, 0), a_lo))
        key(name + "_Foot", f, wrot(name + "_Foot", (1, 0, 0), -(a_up + a_lo)))
    bob = math.sin(2 * math.pi * ph0 * 3.0) * 0.012 * height_m
    key("Body", f, wrot("Body", (0, 0, 1), math.radians(2.2) * math.sin(2 * math.pi * ph0))
        @ wrot("Body", (1, 0, 0), math.radians(1.2) * math.sin(2 * math.pi * ph0 * 3.0)), loc=wloc("Body", (0, 0, bob)))
info["walk_ground_speed"] = round(STRIDE / (T * 2.0 / 3.0 / FPS), 3)
info["walk_cycle_s"] = T / FPS
bpy.ops.object.mode_set(mode='OBJECT')
rig.animation_data.action = bpy.data.actions["Walk_Heavy-loop"]
json.dump(info, open(os.path.join(glb_dir, "tripod.json"), "w"), indent=1)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(work, "tripod_rig.blend"))

# ------------------------------------------------------------------ optional preview
if preview:
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_EEVEE'
    w_ = bpy.data.worlds.new("w")
    w_.use_nodes = True
    w_.node_tree.nodes["Background"].inputs[0].default_value = (0.62, 0.64, 0.68, 1)
    sc.world = w_
    cam = bpy.data.cameras.new("c")
    cam.type = 'ORTHO'
    cam.ortho_scale = height_m * 1.25
    cobj = bpy.data.objects.new("c", cam)
    sc.collection.objects.link(cobj)
    sc.camera = cobj
    sc.render.resolution_x = sc.render.resolution_y = 360
    rig.animation_data.action = bpy.data.actions["Walk_Heavy-loop"]
    for fr in (0, 20, 40, 60, 80, 100):
        sc.frame_set(fr)
        for view, (loc, rot) in {"side": ((height_m * 6, 0, height_m * 0.45), (math.pi / 2, 0, math.pi / 2)),
                                 "front": ((0, height_m * 6, height_m * 0.45), (math.pi / 2, 0, math.pi))}.items():
            cobj.location, cobj.rotation_euler = loc, rot
            sc.render.filepath = os.path.join(work, "prev_walk_%d_%s.png" % (fr, view))
            bpy.ops.render.render(write_still=True)

# ------------------------------------------------------------------ export
bpy.ops.object.select_all(action='DESELECT')
src.select_set(True)
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
glb = os.path.join(glb_dir, "MON_tripod.glb")
bpy.ops.export_scene.gltf(filepath=glb, export_format='GLB', use_selection=True, export_animations=True, export_animation_mode='ACTIONS',
                          export_skins=True, export_yup=True, export_normals=True, export_apply=False)
print("GLB", glb, os.path.getsize(glb))
