"""THE VEIL cinematics - pilot C03.02b (street Colossus reveal, Meshy tripod variant) in Blender 5.x, headless. NO RENDERS.
   blender -b -P docs/cinematics/blender/pilot_c03_02b.py -- <repo_root>
Does five things:
 1. Checks the Blender version and the Godot<->Blender axis round trip with a camera, a rig action and a contact marker.
 2. Builds modular collections (Site, Cast, Creature, FX, Cameras) and imports the tripod GLB at the encounter scale (COLOSSUS_H 85 m).
 3. Replays the encounter's camera logic (world.gd _tripod_encounter) frame by frame at 60 Hz and keys the result at 24 fps on one camera.
 4. Measures the tripod's eye height and the foot contact frames from the real Walk_Heavy action, and drops contact markers.
 5. Exports transferable data (camera + creature path + markers, in GODOT axes) to docs/cinematics/data/C03_02b_camera.json and saves the .blend.
Frame: the player stands at the origin (eye 1.62 m), the store front direction n = Godot -Z, side = +X. Blender (x, y, z) = Godot (x, -z, y)."""
import bpy, sys, os, math, json
from mathutils import Vector, Quaternion, Matrix

root = sys.argv[sys.argv.index("--") + 1]
FPS = 24
H = 85.0                      # world.gd COLOSSUS_H
BASE_H = 12.0                 # VeilTripodColossus.BASE_H
BASE_SPEED, CYCLE_S = 0.45, 8.0
SPEED_SCALE = 0.45
GROUND = ground_speed = BASE_SPEED * (H / BASE_H) * SPEED_SCALE
STEP_INTERVAL = CYCLE_S / 3.0 / SPEED_SCALE
EYE = 1.62


def g2b(v):  # godot (x, y, z) -> blender
    return Vector((v[0], -v[2], v[1]))


def b2g(v):
    return (v.x, v.z, -v.y)


bpy.ops.wm.read_factory_settings(use_empty=True)
print("BLENDER", bpy.app.version_string)
scene = bpy.context.scene
scene.render.fps = FPS
scene.unit_settings.system = 'METRIC'


def coll(name):
    c = bpy.data.collections.new(name)
    scene.collection.children.link(c)
    return c


C_SITE, C_CAST, C_CRE, C_FX, C_CAM = coll("Site"), coll("Cast"), coll("Creature"), coll("FX"), coll("Cameras")

# ---- 1. site reference: the road, a lamp and the shop edge as simple proxies (the Godot reference scene owns the real geometry)
road = bpy.data.objects.new("Road_Ref", None)
road.empty_display_type = 'PLAIN_AXES'
road.empty_display_size = 2.0
C_SITE.objects.link(road)
for nm, p in (("Lamp_Ref", (-2.0, 0.0, -16.0)), ("ShopEdge_Ref", (3.0, 0.0, -1.0))):
    e = bpy.data.objects.new(nm, None)
    e.empty_display_type = 'CUBE'
    e.empty_display_size = 0.5
    e.location = g2b(p)
    C_SITE.objects.link(e)
player = bpy.data.objects.new("Player_Eye", None)
player.empty_display_type = 'SPHERE'
player.empty_display_size = 0.2
player.location = g2b((0, EYE, 0))
C_CAST.objects.link(player)

# ---- 2. the creature, imported and scaled like VeilTripodColossus.build()
bpy.ops.import_scene.gltf(filepath=os.path.join(root, "game/prototypes/monsters_meshy/MON_tripod.glb"))
imported = list(bpy.context.selected_objects)
arm = next(o for o in imported if o.type == 'ARMATURE')
holder = bpy.data.objects.new("Colossus_Root", None)
C_CRE.objects.link(holder)
for o in imported:
    for c in list(o.users_collection):
        c.objects.unlink(o)
    C_CRE.objects.link(o)
    if o.parent is None:
        o.parent = holder
holder.scale = (H / BASE_H,) * 3
bpy.context.view_layer.update()
acts = [a.name for a in bpy.data.actions]
print("ACTIONS", acts)
walk = next(a for a in bpy.data.actions if "Walk" in a.name)
arm.animation_data_create()
arm.animation_data.action = walk
fr0, fr1 = int(walk.frame_range[0]), int(walk.frame_range[1])
bones = [b.name for b in arm.pose.bones]
print("BONES", bones)

# ---- 4. measure: the eye's height and each foot's contact frames across the walk cycle
eye_b = arm.pose.bones.get("Eye")
feet = [b for b in bones if b.lower().endswith("foot") or "foot" in b.lower()]
low = {}
eye_h = None
for fr in range(fr0, fr1 + 1):
    scene.frame_set(fr)
    for fb in feet:
        wz = (arm.matrix_world @ arm.pose.bones[fb].tail).z
        low.setdefault(fb, []).append((fr, wz))
    if eye_b is not None and fr == fr0:
        eye_h = (arm.matrix_world @ eye_b.head).z
contacts = {}
for fb, series in low.items():
    zmin = min(z for _, z in series)
    planted = [fr for fr, z in series if z < zmin + 0.05 * H / 12.0 * 4]
    # first frame of the longest planted run = the contact frame
    runs, cur = [], []
    for fr in range(fr0, fr1 + 1):
        if fr in planted:
            cur.append(fr)
        elif cur:
            runs.append(cur)
            cur = []
    if cur:
        runs.append(cur)
    best = max(runs, key=len) if runs else [fr0]
    contacts[fb] = {"contact_frame": best[0], "planted_frames": len(best), "ground_z_m": zmin}
print("EYE_HEIGHT_M", eye_h, "CONTACTS", contacts)
eye_h = eye_h if eye_h else 0.5 * H

# ---- 3. the camera: replay world.gd _tripod_encounter at 60 Hz
A = Vector((-14.0, 0.0, -104.0))                       # P + n*104 - side*14   (godot x, y, z)
B = Vector((-3.0, 0.0, -86.0))
wd = (B - A)
wd.y = 0
wd.normalize()
P = Vector((0.0, EYE, 0.0))
WALK_END, FIND, LOCK_HOLD, ZOOM, LENS_HOLD, RETURN = 13.0, 1.6, 0.55, 0.8, 0.9, 0.35
LOCK_T = WALK_END + 2.2
FOV0, FOV_ZOOM = 72.0, 7.0


def look_q(frm, to):
    d = (to - frm).normalized()
    # godot looking_at: -Z toward target, up = +Y
    z = -d
    x = Vector((0, 1, 0)).cross(z).normalized()
    y = z.cross(x)
    m = Matrix(((x.x, y.x, z.x), (x.y, y.y, z.y), (x.z, y.z, z.z)))
    return m.to_quaternion()


def smooth(k):
    return k * k * (3 - 2 * k)


def creature_pos(t):
    return A + wd * GROUND * min(t, WALK_END)


def eye_pos(t):
    c = creature_pos(t)
    return Vector((c.x, eye_h, c.z))


cam_q = look_q(P, creature_pos(0) + Vector((0, H * 0.5, 0)))
aim = creature_pos(0) + Vector((0, H * 0.5, 0))
samples = []                                           # (t, pos, quat, fov)
dt = 1.0 / 60.0
t = 0.0
total = LOCK_T + LOCK_HOLD + ZOOM + LENS_HOLD + RETURN
fov = FOV0
zoom_q0 = None
yaw_pitch_end = look_q(P, P + Vector((0, 0.38, -1.0)))   # player.set_yaw_pitch(.., 22 deg) roughly: forward, tilted up
while t < total:
    t += dt
    if t < LOCK_T:
        if t < WALK_END:
            aim = creature_pos(t) + Vector((0, H * 0.5, 0))
        else:
            k2 = max(0.0, min((t - WALK_END) / FIND, 1.0))
            aim = aim.lerp(eye_pos(t), max(0.0, min(k2 * 1.5, 1.0)))
        want = look_q(P, aim)
        cam_q = cam_q.slerp(want, 1.0 - math.exp(-1.6 * dt))
        fov = FOV0
    elif t < LOCK_T + LOCK_HOLD:
        pass                                            # beam on his face, eye brightening
    elif t < LOCK_T + LOCK_HOLD + ZOOM:
        k = (t - LOCK_T - LOCK_HOLD) / ZOOM
        if zoom_q0 is None:
            zoom_q0 = cam_q.copy()
        e = k ** 6 if k < 1 else 1.0                    # EXPO ease-in (approx)
        fov = FOV0 + (FOV_ZOOM - FOV0) * e
        cam_q = zoom_q0.slerp(look_q(P, eye_pos(WALK_END)), min(k / 0.625, 1.0))
    elif t < LOCK_T + LOCK_HOLD + ZOOM + LENS_HOLD:
        fov = FOV_ZOOM
    else:
        k = (t - (total - RETURN)) / RETURN
        e = smooth(max(0.0, min(k, 1.0)))
        cam_q = look_q(P, eye_pos(WALK_END)).slerp(yaw_pitch_end, e) if k < 1.0 else yaw_pitch_end
        fov = FOV_ZOOM + (FOV0 - FOV_ZOOM) * e
    samples.append((t, cam_q.copy(), fov))

cam_data = bpy.data.cameras.new("EncounterCam")
cam_data.sensor_fit = 'VERTICAL'                        # Godot's fov is vertical
cam_data.sensor_height = 24.0
cam = bpy.data.objects.new("EncounterCam", cam_data)
C_CAM.objects.link(cam)
cam.rotation_mode = 'QUATERNION'
cam.location = g2b((0, EYE, 0))
scene.frame_start = 0
frames = int(math.ceil(total * FPS))
scene.frame_end = frames
export_cam = []
C_FIX = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))     # godot -> blender basis change
for f in range(frames + 1):
    tt = f / FPS
    i = min(int(tt * 60), len(samples) - 1)
    _, q, fv = samples[i]
    bm = C_FIX @ q.to_matrix()                          # both cameras look down their local -Z with +Y up: only the world side changes axes
    cam.rotation_quaternion = bm.to_quaternion()
    cam_data.lens_unit = 'FOV'
    cam_data.angle_y = math.radians(fv)
    cam.keyframe_insert("rotation_quaternion", frame=f)
    cam_data.keyframe_insert("lens", frame=f)
    export_cam.append({"frame": f, "t": round(tt, 4), "fov_deg": round(fv, 3),
                       "quat_godot_xyzw": [round(q.x, 6), round(q.y, 6), round(q.z, 6), round(q.w, 6)]})
for fc in cam.animation_data.action.layers[0].strips[0].channelbags[0].fcurves if hasattr(cam.animation_data.action, "layers") and cam.animation_data.action.layers else cam.animation_data.action.fcurves:
    for kp in fc.keyframe_points:
        kp.interpolation = 'LINEAR'                      # sampled every frame already: linear keeps it exact

# ---- creature path (a motion path for the holder) and contact markers
holder.rotation_euler = (0, 0, 0)
yaw = math.atan2(-wd.x, -wd.z)                            # the model faces -Z in godot
holder.rotation_mode = 'XYZ'
holder.rotation_euler.z = yaw                              # blender z is up
export_path = []
for f in range(0, int(math.ceil(WALK_END * FPS)) + 1):
    tt = f / FPS
    holder.location = g2b(creature_pos(tt))
    holder.keyframe_insert("location", frame=f)
    export_path.append({"frame": f, "pos_godot": [round(c, 4) for c in b2g(holder.location)]})
holder.keyframe_insert("rotation_euler", frame=0)
step_frames = [round(STEP_INTERVAL * (i + 1) * FPS) for i in range(int(WALK_END // STEP_INTERVAL))]
markers = []
for i, sf in enumerate(step_frames):
    m = bpy.data.objects.new("Contact_%d" % (i + 1), None)
    m.empty_display_type = 'ARROWS'
    m.empty_display_size = 3.0
    m.location = g2b(creature_pos(sf / FPS))
    C_FX.objects.link(m)
    scene.timeline_markers.new("step_%d" % (i + 1), frame=sf)
    markers.append({"name": "Contact_%d" % (i + 1), "frame": sf, "pos_godot": [round(c, 3) for c in b2g(m.location)],
                    "sound": "colossus_step", "vol_db": 5.0 if i == 0 else 5.0, "pitch": 0.55})
for nm, fr in (("lock_on", int(LOCK_T * FPS)), ("jump_scare", int((LOCK_T + LOCK_HOLD) * FPS)), ("zoom_end", int((LOCK_T + LOCK_HOLD + ZOOM) * FPS)),
               ("control_return", frames)):
    scene.timeline_markers.new(nm, frame=fr)

# ---- 1b. round trip: a Godot-space point -> blender -> godot, and the camera's world forward vs the Godot look direction
probe = Vector((3.0, 5.0, -7.0))
rt = b2g(g2b(probe))
scene.frame_set(0)
fwd_b = cam.matrix_world.to_quaternion() @ Vector((0, 0, -1))
fwd_g = Vector(b2g(fwd_b))
want_g = (creature_pos(0) + Vector((0, H * 0.5, 0)) - P).normalized()
err_deg = math.degrees(fwd_g.angle(want_g))
rt_ok = max(abs(rt[i] - probe[i]) for i in range(3)) < 1e-6
print("ROUNDTRIP point_ok=%s camera_forward_error_deg=%.3f" % (rt_ok, err_deg))

out = {
    "sequence": "C03.02b", "variant": "tripod (Meshy), default; `-- old_colossus` plays C03.02a", "fps": FPS, "frames": frames,
    "frame_of_reference": "player at origin, eye 1.62 m; store front n = godot -Z, side = +X; godot axes (x, y, z)",
    "colossus": {"height_m": H, "ground_speed_mps": round(GROUND, 4), "step_interval_s": round(STEP_INTERVAL, 3), "start": [A.x, A.y, A.z],
                 "walk_dir": [round(wd.x, 5), 0.0, round(wd.z, 5)], "eye_height_m": round(eye_h, 3), "foot_contacts_in_clip": contacts},
    "timeline_s": {"walk": [0, WALK_END], "find_and_lock": [WALK_END, LOCK_T], "hold": [LOCK_T, LOCK_T + LOCK_HOLD],
                   "zoom": [LOCK_T + LOCK_HOLD, LOCK_T + LOCK_HOLD + ZOOM], "lens_hold": [LOCK_T + LOCK_HOLD + ZOOM, total - RETURN],
                   "return": [total - RETURN, total]},
    "round_trip": {"point_ok": rt_ok, "camera_forward_error_deg": round(err_deg, 4)},
    "markers": markers, "camera": export_cam, "colossus_path": export_path,
}
os.makedirs(os.path.join(root, "docs/cinematics/data"), exist_ok=True)
json.dump(out, open(os.path.join(root, "docs/cinematics/data/C03_02b_camera.json"), "w"), indent=1)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(root, "docs/cinematics/blender/C03_02b_pilot.blend"))
print("DONE frames", frames, "total_s", round(total, 2))
