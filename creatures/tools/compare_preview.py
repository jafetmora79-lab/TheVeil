"""Side-by-side old/new creature animation preview (same camera, light, playback speed, ground).
blender -b -P creatures/tools/compare_preview.py -- <old.glb> <new.glb> <out.mp4> <segments-json> [flip]
segments: [["Walk", ground_speed_m_s, old_clip, new_clip, old_time_scale, seconds], ...]  (ground_speed 0 = in place)"""
import bpy, sys, os, math, json, numpy as np
from mathutils import Vector

a = sys.argv[sys.argv.index("--") + 1:]
OLD, NEW, OUT = a[0], a[1], a[2]
SEGS = json.loads(a[3])
FPS = 30
W, H = 560, 316
bpy.ops.wm.read_factory_settings(use_empty=True)


def load(path):
    before = set(bpy.data.objects)
    acts_before = set(bpy.data.actions)
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(path))
    objs = [o for o in bpy.data.objects if o not in before]
    arm = next(o for o in objs if o.type == 'ARMATURE')
    acts = {act.name.split(".")[0]: act for act in bpy.data.actions if act not in acts_before}
    for o in objs:
        if o.name.startswith("Icosphere"):
            o.hide_render = True
            o.hide_viewport = True
    return arm, objs, acts


old_arm, old_objs, old_acts = load(OLD)
new_arm, new_objs, new_acts = load(NEW)
sc = bpy.context.scene
sc.render.fps = FPS
sc.render.engine = 'BLENDER_EEVEE'
sc.render.resolution_x, sc.render.resolution_y = W, H
w = bpy.data.worlds.new("w")
w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (.10, .115, .15, 1)
sc.world = w
for rot, e in (((0.8, 0.2, 0.6), 3.5), ((1.2, 0, 3.7), 1.0)):
    bpy.ops.object.light_add(type='SUN')
    L = bpy.context.object
    L.rotation_euler = rot
    L.data.energy = e
# checker ground so foot sliding is visible
bpy.ops.mesh.primitive_plane_add(size=400, location=(0, 0, 0))
g = bpy.context.object
gm = bpy.data.materials.new("g")
gm.use_nodes = True
nt = gm.node_tree
chk = nt.nodes.new("ShaderNodeTexChecker")
chk.inputs["Scale"].default_value = 160
chk.inputs["Color1"].default_value = (.17, .19, .17, 1)
chk.inputs["Color2"].default_value = (.09, .10, .09, 1)
nt.links.new(chk.outputs["Color"], nt.nodes["Principled BSDF"].inputs["Base Color"])
nt.nodes["Principled BSDF"].inputs["Roughness"].default_value = 1
g.data.materials.append(gm)
cam = bpy.data.cameras.new("c")
cam.type = 'ORTHO'
cam.ortho_scale = float(a[4]) if len(a) > 4 else 4.2
CAMZ = float(a[5]) if len(a) > 5 else 0.85
co = bpy.data.objects.new("c", cam)
sc.collection.objects.link(co)
sc.camera = co
co.rotation_euler = (math.pi / 2, 0, math.pi / 2)        # looks along -X; model forward (-Y) points to image left


def set_vis(objs, vis):
    for o in objs:
        if o.name.startswith("Icosphere"):
            continue
        o.hide_render = not vis
        o.hide_viewport = not vis


def pose(arm, acts, clip, t, scale):
    """evaluate clip at time t seconds (looping clips wrap, one-shots hold the last frame)"""
    act = acts[clip]
    arm.animation_data_create()
    arm.animation_data.action = act
    f0, f1 = act.frame_range
    n = f1 - f0
    loop = clip in ("Idle", "Walk", "Trot", "Run", "Idle_Twitch", "Crawl", "Scuttle_Fast")
    fr = t * FPS * scale
    fr = (fr % (n + (1 if loop and arm is new_arm else 0))) if loop else min(fr, n)
    f = f0 + fr
    sc.frame_set(int(math.floor(f)), subframe=f - math.floor(f))


frames = []
tot = 0
for name, speed, oclip, nclip, oscale, secs in SEGS:
    n = int(secs * FPS)
    for i in range(n):
        frames.append((name, speed, oclip, nclip, oscale, i / FPS))
print("FRAMES", len(frames))
tmp = os.path.abspath(os.path.dirname(OUT) + "/_frames")
os.makedirs(tmp, exist_ok=True)
for idx, (name, speed, oclip, nclip, oscale, t) in enumerate(frames):
    y = -speed * t
    row = []
    for tag, arm, objs, acts, clip, scl in (("old", old_arm, old_objs, old_acts, oclip, oscale), ("new", new_arm, new_objs, new_acts, nclip, 1.0)):
        set_vis(old_objs, tag == "old")
        set_vis(new_objs, tag == "new")
        arm.location = (0, y, 0)
        if clip:
            pose(arm, acts, clip, t, scl)
        co.location = (60 if len(a) > 4 else 12, y - 0.1, CAMZ)
        p = os.path.join(tmp, "f.png")
        sc.render.filepath = p
        bpy.ops.render.render(write_still=True)
        im = bpy.data.images.load(p)
        row.append(np.array(im.pixels[:], dtype=np.float32).reshape(H, W, 4))
        bpy.data.images.remove(im)
    both = np.concatenate(row, axis=1)
    both[:, W - 1:W + 1, :3] = 1.0
    img = bpy.data.images.new("o%d" % idx, W * 2, H, alpha=False)
    img.pixels[:] = both.reshape(-1)
    img.filepath_raw = os.path.join(tmp, "%05d.png" % idx)
    img.file_format = 'PNG'
    img.save()
    bpy.data.images.remove(img)
print("RENDERED")
# encode with the sequencer
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sc.render.resolution_x, sc.render.resolution_y = W * 2, H
sc.render.fps = FPS
sc.sequence_editor_create()
files = [{"name": "%05d.png" % i} for i in range(len(frames))]
strip = sc.sequence_editor.sequences.new_image("seq", os.path.join(tmp, "00000.png"), 1, 1) if hasattr(sc.sequence_editor, "sequences") else sc.sequence_editor.strips.new_image("seq", os.path.join(tmp, "00000.png"), 1, 1)
for i in range(1, len(frames)):
    strip.elements.append("%05d.png" % i)
sc.frame_start, sc.frame_end = 1, len(frames)
try:
    sc.render.image_settings.media_type = 'VIDEO'
except Exception as e:
    print('NOMEDIA', e)
sc.render.image_settings.file_format = 'FFMPEG'
sc.render.ffmpeg.format = 'MPEG4'
sc.render.ffmpeg.codec = 'H264'
sc.render.ffmpeg.constant_rate_factor = 'MEDIUM'
sc.render.filepath = os.path.abspath(OUT)
bpy.ops.render.render(animation=True)
print("VIDEO", OUT)
