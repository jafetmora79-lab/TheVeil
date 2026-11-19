"""EXPERIMENT: expressions as a swapped FACE TEXTURE, using the aligned ChatGPT images (no decal meshes, no new geometry).
The front-facing skin triangles of the face get a second material whose UVs are a plain front projection, so its texture is exactly the flat
face capture (1000x1000) and any aligned expression image can be dropped in. Same triangles, same shading as the rest of the head: no pasted look.
   blender -b -P protagonist_face_texture_swap.py -- <repo_root>"""
import bpy, sys, os, json, math
import numpy as np

root = sys.argv[sys.argv.index("--") + 1]
base = os.path.join(root, "creatures/humans/protagonist")
out = os.path.join(base, "face_geo")
bpy.ops.wm.open_mainfile(filepath=os.path.join(base, "game_ready/protagonist_meshy.blend"))
for o in list(bpy.data.objects):
    if o.name.startswith("Face_"):
        bpy.data.objects.remove(o, do_unlink=True)
body = bpy.data.objects["Protagonist_Meshy_Body"]
me = body.data
cap = json.load(open(os.path.join(base, "work/face/face_capture.json")))
RES, CX, CZ, SIZE = cap["res"], cap["cx"], cap["cz"], cap["size"]
M = SIZE / RES


def px(p):
    return ((CX - p[0]) / M + RES / 2, RES / 2 - (p[2] - CZ) / M)


# ---- which triangles: front-facing skin of the face (not the hair in front of it)
sel = []
for poly in me.polygons:
    pts = [me.vertices[v].co for v in poly.vertices]
    if poly.normal.y < 0.25 or any(p.y > 0.085 for p in pts):
        continue
    c = [px(p) for p in pts]
    if all(235 <= u <= 770 and 215 <= v <= 905 for u, v in c):
        sel.append(poly.index)
print("FACE triangles", len(sel), "of", len(me.polygons))

# ---- second material: the face image
kit = os.path.join(base, "chatgpt_kit")
FACE_IMGS = {"neutral": os.path.join(base, "work/face/face_flat.png"),
             "blink": os.path.join(kit, "returned/eyes_closed_a.png"),
             "talk_small": os.path.join(kit, "returned/talk_small.png"),
             "talk_wide": os.path.join(kit, "returned/talk_wide.png"),
             "scared": os.path.join(kit, "returned/scared_open.png")}
mat = bpy.data.materials.new("Protagonist_Face_Expr")
mat.use_nodes = True
nt = mat.node_tree
b = nt.nodes["Principled BSDF"]
b.inputs["Roughness"].default_value = 1.0
try:
    b.inputs["Specular IOR Level"].default_value = 0.0
except Exception:
    pass
tn = nt.nodes.new("ShaderNodeTexImage")
tn.interpolation = "Closest"
nt.links.new(tn.outputs["Color"], b.inputs["Base Color"])
me.materials.append(mat)
slot = len(me.materials) - 1
uvl = me.uv_layers.active
for pi in sel:
    poly = me.polygons[pi]
    poly.material_index = slot
    for li in poly.loop_indices:
        u, v = px(me.vertices[me.loops[li].vertex_index].co)
        uvl.data[li].uv = (u / RES, 1.0 - v / RES)

# ---- renders: same camera and lighting as the other close-ups
rig = bpy.data.objects.get("Protagonist_Meshy_Rig")
rig.animation_data.action = None
for pb in rig.pose.bones:
    pb.rotation_euler = (0, 0, 0)
    pb.location = (0, 0, 0)
sc = bpy.context.scene
sc.render.engine = 'BLENDER_EEVEE'
sc.view_settings.view_transform = 'Standard'
w_ = bpy.data.worlds.new("w")
w_.use_nodes = True
w_.node_tree.nodes["Background"].inputs[0].default_value = (0.20, 0.21, 0.24, 1)
sc.world = w_
for rot_, en in (((55, 0, 180 - 25), 3.0), ((70, 0, 140), 1.0)):
    bpy.ops.object.light_add(type='SUN')
    L = bpy.context.object
    L.rotation_euler = [math.radians(x) for x in rot_]
    L.data.energy = en
cam = bpy.data.cameras.new("c")
cam.type = 'ORTHO'
cam.ortho_scale = 0.22
co_ = bpy.data.objects.new("c", cam)
sc.collection.objects.link(co_)
sc.camera = co_
co_.location = (0, 5.0, 1.59)
co_.rotation_euler = (math.pi / 2, 0, math.pi)
sc.render.resolution_x = sc.render.resolution_y = 560
for name, path in FACE_IMGS.items():
    img = bpy.data.images.load(path, check_existing=False)
    tn.image = img
    sc.render.filepath = os.path.join(out, "swap_%s.png" % name)
    bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, "protagonist_face_texture_swap.blend"))
print("DONE")
