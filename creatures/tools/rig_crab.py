"""THE VEIL - the Meshy armored crab rigged to the OLD Shellcrawler interface (Blender 5.x, headless).
   blender -b -P rig_crab.py -- <repo_root> [measure]
Source creatures/monsters/source/crab.glb -> game/prototypes/monsters_meshy/MON_crab.glb (+ crab.json).
The model faces +Y in Blender (-Z in Godot); MON_crab.tscn turns it half a turn so the scene faces +Z (claws first) like the old CRT_Shellcrawler.
Bones: Body (root), Arm_L/R_Up/_Lo (the front claws), Leg<n>_<L|R>_Up/_Lo (eight walking legs, four a side). Legs and claws are posed by 3D two-bone IK to foot targets,
so a foot is planted while it is on the ground (alternating tetrapod gait). Clips (the old names): Idle, Crawl_Sideways (the old crab walks sideways: toward Blender +X, the
scene's -X), Crawl_Forward, Defend, Attack_Grasp (the claws are closed on the target at 55 % of the clip: the struggle freezes it there), Hit_React, Death."""
import bpy, bmesh, sys, os, math, json
import numpy as np
from mathutils import Vector, Matrix, Quaternion

args = sys.argv[sys.argv.index("--") + 1:]
root = args[0]
measure = "measure" in args
SIZE = 1.5
FPS = 24
work = os.path.join(root, "creatures/monsters/crab")
glb_dir = os.path.join(root, "game/prototypes/monsters_meshy")
os.makedirs(work, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.join(root, "creatures/monsters/source/crab.glb"))
src = [o for o in bpy.context.scene.objects if o.type == 'MESH'][0]
src.parent = None
src.matrix_world = Matrix.Identity(4)
bpy.context.view_layer.update()
me = src.data
co = np.empty(len(me.vertices) * 3)
me.vertices.foreach_get("co", co)
co = co.reshape(-1, 3)
co[:, 0] *= -1
co[:, 1] *= -1
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
cx = float((V[:, 0].min() + V[:, 0].max()) / 2)
print("CRAB size", (V.max(0) - V.min(0)).round(2), "verts", len(V))

# ------------------------------------------------------------------ legs: the vertices out beyond the shell on each side, four groups a side by y
SHELL_HALF = 0.40
LEGS = []
for side, sgn in (("L", -1.0), ("R", 1.0)):
    P = V[(sgn * (V[:, 0] - cx) > SHELL_HALF) & (V[:, 1] < 0.45)]
    ys = P[:, 1]
    edges = np.quantile(ys, [0.0, 0.25, 0.5, 0.75, 1.0])
    for r in range(4):
        G = P[(ys >= edges[r] - 1e-9) & (ys <= edges[r + 1] + 1e-9)]
        low = G[G[:, 2] < 0.10]
        foot = Vector((float(low[:, 0].mean()), float(low[:, 1].mean()), 0.0)) if len(low) else Vector((cx + sgn * 0.7, float(G[:, 1].mean()), 0.0))
        up = G[G[:, 2] > 0.18]
        top = up[np.argmax(up[:, 2])] if len(up) else G[np.argmax(G[:, 2])]
        knee = Vector((float(top[0]), float(top[1]), max(float(top[2]), 0.25)))
        hip = Vector((cx + sgn * 0.30, float(G[:, 1].mean()), 0.32))
        if (knee - hip).length < 0.06:
            knee = hip + Vector((sgn * 0.2, 0, 0.1))
        LEGS.append({"side": side, "sgn": sgn, "rank": r, "hip": hip, "knee": knee, "foot": foot, "arm": False})
# the claws: two arms at the front, hip on the shell's front edge, the tip near the front of the model
yf = float(V[:, 1].max())
for side, sgn in (("L", -1.0), ("R", 1.0)):
    P = V[(V[:, 1] > 0.42) & (sgn * (V[:, 0] - cx) > -0.1) & (V[:, 2] < 0.55)]
    tip = Vector((float(P[:, 0].mean()), yf - 0.05, float(P[:, 2].mean()))) if len(P) else Vector((cx + sgn * 0.25, yf - 0.05, 0.2))
    hip = Vector((cx + sgn * 0.22, 0.36, 0.34))
    knee = Vector((cx + sgn * 0.34, 0.50, max(0.3, tip.z + 0.1)))
    LEGS.append({"side": side, "sgn": sgn, "rank": 9, "hip": hip, "knee": knee, "foot": tip, "arm": True})
walkers = sorted([L for L in LEGS if not L["arm"]], key=lambda L: (L["side"], -L["foot"].y))
for i, L in enumerate(walkers):
    L["name"] = "Leg%d_%s" % (i, L["side"])
for L in LEGS:
    if L["arm"]:
        L["name"] = "Arm_%s" % L["side"]
    print("LIMB", L["name"], "hip", [round(v, 2) for v in L["hip"]], "knee", [round(v, 2) for v in L["knee"]], "foot", [round(v, 2) for v in L["foot"]])

zc = 0.34
bones = [("Body", Vector((cx, 0.0, zc)), Vector((cx, 0.3, zc)), None)]
for L in LEGS:
    bones.append((L["name"] + "_Up", L["hip"], L["knee"], "Body"))
    bones.append((L["name"] + "_Lo", L["knee"], L["foot"], L["name"] + "_Up"))
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
bpy.ops.object.select_all(action='DESELECT')
src.select_set(True)
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.parent_set(type='ARMATURE_AUTO')
unw = [vx.index for vx in me.vertices if not any(g.weight > 1e-4 for g in vx.groups)]
if unw:
    print("CRAB unweighted", len(unw), "-> nearest bone")
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

# ------------------------------------------------------------------ helpers
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='POSE')
for pb in rig.pose.bones:
    pb.rotation_mode = 'QUATERNION'
REST = {b.name: b.matrix_local.to_3x3() for b in rig.data.bones}
X, Y, Z = (1, 0, 0), (0, 1, 0), (0, 0, 1)


def key(name, frame, quat=None, loc=None):
    pb = rig.pose.bones[name]
    if quat is not None:
        pb.rotation_quaternion = quat
        pb.keyframe_insert("rotation_quaternion", frame=frame - 1)
    if loc is not None:
        pb.location = loc
        pb.keyframe_insert("location", frame=frame - 1)


def local_of(name, W):
    M = REST[name]
    return (M.inverted() @ W @ M).to_quaternion()


def wrot(name, axis, ang):
    return local_of(name, Matrix.Rotation(ang, 3, Vector(axis)))


def world_loc(name, v):
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


CLAMPS = [0]


def pose_limb(f, L, target, shift=Vector((0, 0, 0))):
    """3D two-bone IK: put the end of limb L at `target` (world) when its hip has moved by `shift`. The knee keeps the side it has in the rest pose."""
    H0, K0, F0 = L["hip"], L["knee"], L["foot"]
    hip = H0 + shift
    l1, l2 = (K0 - H0).length, (F0 - K0).length
    v = Vector(target) - hip
    d0 = v.length
    d = min(max(d0, abs(l1 - l2) + 1e-3), l1 + l2 - 1e-3)
    if d0 > l1 + l2 - 1e-3:
        CLAMPS[0] += 1
    u = v.normalized()
    uf = (F0 - H0).normalized()
    p0 = (K0 - H0) - uf * (K0 - H0).dot(uf)
    p = p0 - u * p0.dot(u)
    p = p.normalized() if p.length > 1e-6 else Vector((0, 0, 1))
    a = (l1 * l1 - l2 * l2 + d * d) / (2 * d)
    b = math.sqrt(max(l1 * l1 - a * a, 0.0))
    K = hip + u * a + p * b
    wup = (K0 - H0).normalized().rotation_difference((K - hip).normalized()).to_matrix()
    wtot = (F0 - K0).normalized().rotation_difference((Vector(target) - K).normalized() if d0 < l1 + l2 - 1e-3 else (K - hip).normalized()).to_matrix()
    key(L["name"] + "_Up", f, local_of(L["name"] + "_Up", wup))
    key(L["name"] + "_Lo", f, local_of(L["name"] + "_Lo", wup.inverted() @ wtot))


def smooth(u):
    return u * u * (3 - 2 * u)


FOOT_Z = 0.045
bpy.context.scene.render.fps = FPS
info = {"kind": "crab", "size_m": SIZE, "facing": "-Z in the GLB (the scene turns it to +Z)"}
WALK = [L for L in LEGS if not L["arm"]]
ARMS = [L for L in LEGS if L["arm"]]


def hold_arms(f, t, sway=0.0, shift=Vector((0, 0, 0))):
    for L in ARMS:
        tgt = L["foot"] + Vector((L["sgn"] * 0.02 * math.sin(2 * math.pi * t * 2), 0.03 * math.sin(2 * math.pi * t * 2 + L["sgn"]), 0.02 * math.sin(2 * math.pi * t * 3)))
        pose_limb(f, L, tgt, shift)


def plant_legs(f, shift=Vector((0, 0, 0)), pull=0.0, raise_z=0.0):
    for L in WALK:
        tgt = L["foot"] + Vector((-L["sgn"] * pull, 0, raise_z))
        tgt.z = max(tgt.z, FOOT_Z) if raise_z == 0.0 else tgt.z
        pose_limb(f, L, tgt, shift)


# idle: a slow breath, the claws drift, the legs planted
new_action("Idle", 97)
for f in range(1, 98):
    t = (f - 1) / 96.0
    br = 0.01 * math.sin(2 * math.pi * t)
    key("Body", f, wrot("Body", X, math.radians(0.8) * math.sin(2 * math.pi * t)), loc=world_loc("Body", (0, 0, br)))
    plant_legs(f, Vector((0, 0, br)))
    hold_arms(f, t, shift=Vector((0, 0, br)))


def crawl(name, direction, stride, T=24, duty=0.6):
    """the body moves along `direction` (a horizontal unit vector); each foot slides back at body speed while planted, then swings forward lifted"""
    new_action(name, T + 1)
    spd = stride / (duty * T / FPS)
    info[name.lower() + "_speed_mps"] = round(spd, 3)
    d = Vector(direction)
    for f in range(1, T + 2):
        ph0 = ((f - 1) % T) / T
        bob = 0.012 * math.sin(4 * math.pi * ph0)
        key("Body", f, wrot("Body", Z, math.radians(1.5) * math.sin(2 * math.pi * ph0)), loc=world_loc("Body", (0, 0, bob)))
        for L in WALK:
            grp = 0.0 if (L["rank"] % 2 == 0) == (L["side"] == "L") else 0.5          # alternating tetrapod
            ph = (ph0 + grp) % 1.0
            if ph < duty:
                off, lift = d * stride * (0.5 - ph / duty), 0.0
            else:
                u = (ph - duty) / (1 - duty)
                off, lift = d * stride * (-0.5 + smooth(u)), 0.09 * math.sin(math.pi * u)
            tgt = L["foot"] + off
            tgt.z = FOOT_Z + lift
            pose_limb(f, L, tgt, Vector((0, 0, bob)))
        hold_arms(f, ph0, shift=Vector((0, 0, bob)))


crawl("Crawl_Sideways", (1, 0, 0), 0.30)
crawl("Crawl_Forward", (0, 1, 0), 0.22)

# defend: it hunkers down, the claws cross in front of the face, the legs pull in
new_action("Defend", 37)
for f in range(1, 38):
    u = smooth(min((f - 1) / 12.0, 1.0))
    t = (f - 1) / 36.0
    dz = -0.035 * u
    key("Body", f, wrot("Body", X, math.radians(5) * u), loc=world_loc("Body", (0, 0.03 * u, dz)))
    plant_legs(f, Vector((0, 0.03 * u, dz)), pull=0.09 * u)
    for L in ARMS:
        goal = Vector((cx - L["sgn"] * 0.10, yf - 0.12, 0.40))                     # crossed in front, raised
        tgt = L["foot"].lerp(goal, u) + Vector((0, 0.015 * math.sin(2 * math.pi * t * 4), 0))
        pose_limb(f, L, tgt, Vector((0, 0.03 * u, dz)))

# attack grasp (one shot, 1.1 s): the claws open and rise, then snap in and forward; at 55 % of the clip they are closed on the target and the struggle freezes it there
new_action("Attack_Grasp", 27)
for f in range(1, 28):
    u = (f - 1) / 26.0
    wind = smooth(min(u / 0.25, 1.0)) * (1.0 if u < 0.3 else 1.0 - smooth(min((u - 0.3) / 0.25, 1.0)))
    strike = 0.0 if u < 0.28 else smooth(min((u - 0.28) / 0.27, 1.0))
    back = 0.0 if u < 0.75 else smooth((u - 0.75) / 0.25)
    close = strike * (1.0 - back)
    lunge = 0.25 * close
    key("Body", f, wrot("Body", X, math.radians(-8) * close + math.radians(6) * wind), loc=world_loc("Body", (0, lunge - 0.04 * wind, -0.015 * wind)))
    shift = Vector((0, lunge - 0.04 * wind, -0.015 * wind))
    for L in WALK:
        pose_limb(f, L, L["foot"] + Vector((0, 0.25 * close * 0.8, 0)) + Vector((0, 0, 0.0)), shift)
    for L in ARMS:
        open_pose = L["foot"] + Vector((L["sgn"] * 0.22, -0.02, 0.28))
        shut_pose = Vector((cx - L["sgn"] * 0.04, yf + 0.38, 0.22))                # forward and together
        tgt = L["foot"].lerp(open_pose, wind)
        tgt = tgt.lerp(shut_pose, close)
        pose_limb(f, L, tgt, shift)

# hit react: a flinch, the claws jerk up
new_action("Hit_React", 13)
for f in range(1, 14):
    u = (f - 1) / 12.0
    sh = math.sin(u * math.pi * 3) * (1 - u)
    key("Body", f, wrot("Body", Z, math.radians(7) * sh) @ wrot("Body", X, math.radians(4) * math.sin(u * math.pi)), loc=world_loc("Body", (0, -0.06 * math.sin(u * math.pi), -0.015 * math.sin(u * math.pi))))
    plant_legs(f, Vector((0, -0.06 * math.sin(u * math.pi), -0.015 * math.sin(u * math.pi))))
    for L in ARMS:
        pose_limb(f, L, L["foot"] + Vector((0, 0, 0.14 * math.sin(u * math.pi))), Vector((0, -0.06 * math.sin(u * math.pi), -0.015 * math.sin(u * math.pi))))

# death: it sags, the legs curl in under the shell, the claws drop
new_action("Death", 49)
for f in range(1, 50):
    u = (f - 1) / 48.0
    k = smooth(min(u / 0.6, 1.0))
    dz = -0.12 * k
    key("Body", f, wrot("Body", Y, math.radians(8) * k) @ wrot("Body", X, math.radians(6) * k), loc=world_loc("Body", (0, 0, dz)))
    for L in WALK:
        tgt = L["foot"] + Vector((-L["sgn"] * 0.18 * k, 0, 0.10 * k))
        tgt.z = max(tgt.z, FOOT_Z)
        pose_limb(f, L, tgt, Vector((0, 0, dz)))
    for L in ARMS:
        tgt = L["foot"] + Vector((L["sgn"] * 0.18 * k, -0.05 * k, -0.18 * k))
        tgt.z = max(tgt.z, FOOT_Z)
        pose_limb(f, L, tgt, Vector((0, 0, dz)))

bpy.ops.object.mode_set(mode='OBJECT')
if measure:
    print("MEASURE IK out-of-reach targets:", CLAMPS[0])
    for clip in ("Idle", "Crawl_Sideways", "Crawl_Forward", "Defend", "Attack_Grasp", "Hit_React", "Death"):
        act = bpy.data.actions[clip]
        rig.animation_data.action = act
        lowest = 0.0
        for fr in range(int(act.frame_range[0]), int(act.frame_range[1]) + 1):
            bpy.context.scene.frame_set(fr)
            ev = src.evaluated_get(bpy.context.evaluated_depsgraph_get())
            m = ev.to_mesh()
            lowest = min(lowest, min(v.co[2] for v in m.vertices))
            ev.to_mesh_clear()
        print("MEASURE", clip, "lowest vertex z %.3f" % lowest)
rig.animation_data.action = bpy.data.actions["Idle"]
json.dump(info, open(os.path.join(glb_dir, "crab.json"), "w"), indent=1)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(work, "crab_rig.blend"))
bpy.ops.object.select_all(action='DESELECT')
src.select_set(True)
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
glb = os.path.join(glb_dir, "MON_crab.glb")
bpy.ops.export_scene.gltf(filepath=glb, export_format='GLB', use_selection=True, export_animations=True, export_animation_mode='ACTIONS',
                          export_skins=True, export_yup=True, export_normals=True, export_apply=False)
print("GLB", glb, os.path.getsize(glb))
