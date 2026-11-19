"""THE VEIL - rig a Meshy monster (Blender 5.x, headless): turns it to face +Y (Godot -Z), scales it, flat-shades it (PSX look), builds a bone
chain per leg / tentacle, skins it and keys simple procedural clips, then exports a GLB.
   blender -b -P rig_monster.py -- <repo_root> <slug> <kind> <size_m> [preview]
 kind: hound (4 legs, head, tail) | spider (8 legs) | crab (legs, radial) | tentacle (a chain along its curve).  size_m: longest dimension in metres.
 Clips: legged -> idle-loop, walk-loop;  tentacle -> idle-loop, strike (one shot), retract (one shot).
Writes creatures/monsters/<slug>/ (blend, preview renders) and game/prototypes/monsters_meshy/MON_<slug>.glb (+ <slug>.json)."""
import bpy, bmesh, sys, os, math, json
import numpy as np
from mathutils import Vector, Matrix, Euler, Quaternion

root, slug, kind, size_m = sys.argv[sys.argv.index("--") + 1:][:4]
preview = "preview" in sys.argv
size_m = float(size_m)
base = os.path.join(root, "creatures/monsters")
work = os.path.join(base, slug)
glb_dir = os.path.join(root, "game/prototypes/monsters_meshy")
os.makedirs(work, exist_ok=True)
os.makedirs(glb_dir, exist_ok=True)
FPS = 24

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.join(base, "source", slug + ".glb"))
src = [o for o in bpy.context.scene.objects if o.type == 'MESH'][0]
src.parent = None
src.matrix_world = Matrix.Identity(4)
bpy.context.view_layer.update()
me = src.data
co = np.empty(len(me.vertices) * 3)
me.vertices.foreach_get("co", co)
co = co.reshape(-1, 3)
if kind != "tentacle":
    co[:, 0] *= -1                                   # a half turn about Z: the face (at -Y in the GLB) now looks toward +Y, the game's forward
    co[:, 1] *= -1
mn, mx = co.min(0), co.max(0)
S = size_m / float((mx - mn).max())
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
print("MONSTER", slug, kind, "size", (V.max(0) - V.min(0)).round(2), "verts", len(V))

# ------------------------------------------------------------------ landmarks -> bones: list of (name, head, tail, parent)
bones = []


def add(name, head, tail, parent=None):
    bones.append((name, Vector(head), Vector(tail), parent))


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
    return C, lab


LEGS = []                                            # (name, hip, knee, foot, side_dir)
if kind == "tentacle":
    N = 9
    zs = np.linspace(0, H, N + 1)
    pts = []
    for i in range(N + 1):
        m = (V[:, 2] >= zs[i] - 0.5 * H / N) & (V[:, 2] <= zs[i] + 0.5 * H / N)
        pts.append(V[m][:, :2].mean(0).tolist() + [zs[i]] if m.any() else [0, 0, zs[i]])
    pts = [Vector(p) for p in pts]
    pts[0] = Vector((pts[0].x, pts[0].y, 0.0))
    for i in range(N):
        add("T%d" % i, pts[i], pts[i + 1], "T%d" % (i - 1) if i else None)
else:
    low = V[V[:, 2] < 0.14 * H]
    K = {"hound": 4, "spider": 8, "crab": 10}[kind]
    feet, _ = kmeans(low[:, :2], K)
    body_pts = V[V[:, 2] > 0.35 * H]
    C = Vector((float(body_pts[:, 0].mean()), float(body_pts[:, 1].mean()), float(body_pts[:, 2].mean())))
    if kind == "hound":
        # trunk, neck/head toward +Y, tail toward -Y
        ymax, ymin = float(V[:, 1].max()), float(V[:, 1].min())
        add("Body", (C.x, C.y - 0.1, C.z), (C.x, C.y + 0.2, C.z), None)
        add("Neck", (C.x, C.y + 0.2, C.z + 0.05), (C.x, ymax - 0.3 * (ymax - ymin) * 0.35, C.z + 0.12), "Body")
        add("Head", (C.x, ymax - 0.3 * (ymax - ymin) * 0.35, C.z + 0.12), (C.x, ymax, C.z + 0.08), "Neck")
        add("Tail1", (C.x, C.y - 0.1, C.z), (C.x, (C.y + ymin) / 2, C.z), "Body")
        add("Tail2", (C.x, (C.y + ymin) / 2, C.z), (C.x, ymin, C.z - 0.05), "Tail1")
    else:
        add("Body", (C.x, C.y, C.z * 0.9), (C.x, C.y + 0.05, C.z), None)
    order = sorted(range(K), key=lambda i: (math.atan2(feet[i][0] - C.x, feet[i][1] - C.y)))
    for n_, i in enumerate(order):
        f2 = Vector((feet[i][0], feet[i][1], 0.0))
        out = Vector((f2.x - C.x, f2.y - C.y, 0.0))
        d = out.normalized() if out.length > 1e-4 else Vector((1, 0, 0))
        side = "L" if f2.x < C.x else "R"
        # the foot is the lowest, outermost vertex of this cluster
        cl = low[np.linalg.norm(low[:, :2] - feet[i], axis=1) < 0.12 * size_m]
        foot = Vector((float(cl[:, 0].mean()), float(cl[:, 1].mean()), 0.0)) if len(cl) else f2
        rb = 0.32 * float(max(V[:, 0].max() - V[:, 0].min(), 0.2)) if kind != "hound" else 0.0
        hip = Vector((C.x + d.x * rb, C.y + d.y * rb, 0.78 * H)) if kind != "hound" else Vector((foot.x, foot.y, 0.62 * H))
        mid = (hip + foot) * 0.5
        knee = mid + d * (0.06 * size_m) + Vector((0, 0, (0.20 if kind != "hound" else 0.0) * H + (0.05 if kind == "hound" else 0.0) * H))
        add("Leg%d_%s_Up" % (n_, side), hip, knee, "Body")
        add("Leg%d_%s_Lo" % (n_, side), knee, foot, "Leg%d_%s_Up" % (n_, side))
        LEGS.append(("Leg%d_%s" % (n_, side), hip, knee, foot, d))

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

# ------------------------------------------------------------------ skin: automatic weights, nearest bone for anything left out
bpy.ops.object.select_all(action='DESELECT')
src.select_set(True)
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.parent_set(type='ARMATURE_AUTO')
unw = [vx.index for vx in me.vertices if not any(g.weight > 1e-4 for g in vx.groups)]
if unw:
    print("MONSTER unweighted", len(unw), "-> nearest bone")
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

# ------------------------------------------------------------------ animation helpers
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
    """a rotation about a WORLD axis (through the bone head), as the bone's own local quaternion"""
    W = Matrix.Rotation(ang, 3, Vector(axis))
    M = REST[name]
    return (M.inverted() @ W @ M).to_quaternion()


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
info = {"kind": kind, "size_m": size_m, "height_m": H}
if kind == "tentacle":
    new_action("idle-loop", 72)
    for f in range(1, 74):
        t = (f - 1) / 72.0
        for i in range(N):
            a = math.radians(5 + 2.5 * i) * math.sin(2 * math.pi * t - i * 0.55)
            b = math.radians(3 + 1.5 * i) * math.sin(2 * math.pi * t * 2 - i * 0.4 + 1.0)
            key("T%d" % i, f, wrot("T%d" % i, (1, 0, 0), a) @ wrot("T%d" % i, (0, 1, 0), b))
    # strike: it coils back, then whips forward (+Y) and the tip snaps; retract: back to the rest pose
    new_action("strike", 30)
    for f in range(1, 31):
        u = (f - 1) / 29.0
        wind = min(u / 0.35, 1.0)
        whip = max(0.0, (u - 0.35) / 0.65)
        for i in range(N):
            k = (i + 1) / N
            ang = -math.radians(28) * k * wind * (1 - whip) + math.radians(46) * k * math.sin(min(whip * 1.4, 1.0) * math.pi / 2) * (1 - 0.35 * whip)
            key("T%d" % i, f, wrot("T%d" % i, (1, 0, 0), ang))
    new_action("retract", 24)
    for f in range(1, 25):
        u = (f - 1) / 23.0
        for i in range(N):
            k = (i + 1) / N
            key("T%d" % i, f, wrot("T%d" % i, (1, 0, 0), math.radians(40) * k * (1 - u) ** 2))
else:
    # idle: a slow breath of the body; legs still
    new_action("idle-loop", 96)
    for f in range(1, 98):
        t = (f - 1) / 96.0
        key("Body", f, wrot("Body", (1, 0, 0), math.radians(1.2) * math.sin(2 * math.pi * t)))
        if kind == "hound":
            key("Head", f, wrot("Head", (0, 0, 1), math.radians(5) * math.sin(2 * math.pi * t * 2)))
            key("Tail1", f, wrot("Tail1", (0, 0, 1), math.radians(8) * math.sin(2 * math.pi * t * 2)))
    # walk: diagonal pairs (hound) / alternating legs (spider, crab). Each leg: the foot is planted and pushed back along the body, then lifted and swung forward.
    T = 36 if kind == "hound" else 30
    new_action("walk-loop", T + 1)
    n = len(LEGS)
    stride = 0.22 * size_m if kind == "hound" else 0.2 * size_m
    for f in range(1, T + 2):
        ph0 = ((f - 1) % T) / T
        for li, (nm, hip, knee, foot, d) in enumerate(LEGS):
            if kind == "hound":
                grp = {0: 0.0, 1: 0.5, 2: 0.5, 3: 0.0}.get(li, 0.0)       # front-left + hind-right, front-right + hind-left (order is by angle: approximate)
            else:
                grp = (li % 2) * 0.5
            ph = (ph0 + grp) % 1.0
            reach = math.atan2(stride * 0.5, max(0.1, (hip - foot).length))
            if ph < 0.55:                                  # stance: the foot goes back
                s = 1.0 - 2.0 * ph / 0.55
                lift = 0.0
            else:                                          # swing: lifted, forward
                u = (ph - 0.55) / 0.45
                s = -1.0 + 2.0 * u
                lift = math.sin(math.pi * u)
            swing = reach * s
            if kind == "hound":
                axis_swing, axis_lift = (1, 0, 0), (1, 0, 0)
                up_rot = wrot(nm + "_Up", axis_swing, -swing * 1.4)
                lo_rot = wrot(nm + "_Lo", axis_lift, math.radians(55) * lift + swing * 0.5)
            else:
                swing_q = wrot(nm + "_Up", (0, 0, 1), swing * (-1.0 if d.x < 0 else 1.0) * 2.4)
                tvec = Vector((0, 0, 1)).cross(d)
                up_rot = swing_q @ wrot(nm + "_Up", (tvec.x, tvec.y, tvec.z), -math.radians(40) * lift)
                lo_rot = wrot(nm + "_Lo", (tvec.x, tvec.y, tvec.z), math.radians(50) * lift)
            key(nm + "_Up", f, up_rot)
            key(nm + "_Lo", f, lo_rot)
        body_bob = math.sin(4 * math.pi * ph0) * 0.012 * size_m
        key("Body", f, wrot("Body", (0, 0, 1), math.radians(2.5) * math.sin(2 * math.pi * ph0)), loc=(0, 0, body_bob))
        if kind == "hound":
            key("Head", f, wrot("Head", (0, 0, 1), math.radians(-4) * math.sin(2 * math.pi * ph0)))
            key("Tail1", f, wrot("Tail1", (0, 0, 1), math.radians(14) * math.sin(2 * math.pi * ph0 + 1.0)))
    info["walk_ground_speed"] = round(stride * 1.0 / (0.55 * T / FPS), 3)
    info["walk_cycle_s"] = T / FPS
bpy.ops.object.mode_set(mode='OBJECT')
rig.animation_data.action = bpy.data.actions["idle-loop"]

json.dump(info, open(os.path.join(glb_dir, slug + ".json"), "w"), indent=1)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(work, "monster_rig.blend"))

# ------------------------------------------------------------------ optional preview: three frames of each clip
if preview:
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_EEVEE'
    w_ = bpy.data.worlds.new("w")
    w_.use_nodes = True
    w_.node_tree.nodes["Background"].inputs[0].default_value = (0.5, 0.52, 0.56, 1)
    w_.node_tree.nodes["Background"].inputs[1].default_value = 1.0
    sc.world = w_
    cam = bpy.data.cameras.new("c")
    cam.type = 'ORTHO'
    cam.ortho_scale = size_m * 1.5
    cobj = bpy.data.objects.new("c", cam)
    sc.collection.objects.link(cobj)
    sc.camera = cobj
    sc.render.resolution_x = sc.render.resolution_y = 300
    clip_list = ["walk-loop"] if kind != "tentacle" else ["strike"]
    shots = []
    for clip in clip_list:
        rig.animation_data.action = bpy.data.actions[clip]
        L = int(bpy.data.actions[clip].frame_range[1])
        for fr in (0, L // 3, 2 * L // 3):
            sc.frame_set(fr)
            for view, (loc, rot) in {"side": ((size_m * 6, 0, size_m * 0.4), (math.pi / 2, 0, math.pi / 2)), "top": ((0, 0, size_m * 6), (0, 0, 0))}.items():
                cobj.location = loc
                cobj.rotation_euler = rot
                sc.render.filepath = os.path.join(work, "prev_%s_%d_%s.png" % (clip, fr, view))
                bpy.ops.render.render(write_still=True)
                shots.append(sc.render.filepath)
    print("PREVIEW", len(shots))

# ------------------------------------------------------------------ export
bpy.ops.object.select_all(action='DESELECT')
src.select_set(True)
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
rig.animation_data.action = bpy.data.actions["idle-loop"]
glb = os.path.join(glb_dir, "MON_%s.glb" % slug)
bpy.ops.export_scene.gltf(filepath=glb, export_format='GLB', use_selection=True, export_animations=True, export_animation_mode='ACTIONS',
                          export_skins=True, export_yup=True, export_normals=True, export_apply=False)
print("GLB", glb, os.path.getsize(glb))
