"""Build an NPC with swapped-face-texture expressions: the front skin triangles of the face get a second material with front-projection UVs (so a
face image is the texture), smooth normals around the eyes (no grey lines), exported as game/prototypes/npc_meshy/CHR_<slug>_FaceTex.glb.
   blender -b -P npc_face_tex_build.py -- <repo_root> <slug>
Needs: npc_meshy.blend (build_npc_meshy.py), work/face/face_capture.json (npc_face_capture.py), face_tex/face_info.json + face_mask.png (npc_face_tex_prepare.py)."""
import bpy, sys, os, json, math
import numpy as np
from mathutils import Vector

root, slug = sys.argv[sys.argv.index("--") + 1:][:2]
base = os.path.join(root, "creatures/humans/npcs", slug)
bpy.ops.wm.open_mainfile(filepath=os.path.join(base, "game_ready/npc_meshy.blend"))
body = bpy.data.objects["NPC_Meshy_Body"]
rig = bpy.data.objects["NPC_Meshy_Rig"]
me = body.data
cap = json.load(open(os.path.join(base, "work/face/face_capture.json")))
RES, CX, CZ, SIZE = cap["res"], cap["cx"], cap["cz"], cap["size"]
M = SIZE / RES
info = json.load(open(os.path.join(base, "face_tex/face_info.json")))
EYES = info["eyes1000"]
mimg = bpy.data.images.load(os.path.join(base, "face_tex/face_mask.png"))
mw, mh = mimg.size
mpix = np.array(mimg.pixels[:]).reshape(mh, mw, 4)[..., 0] > 0.5            # row 0 = bottom in Blender images


def px(p):
    return ((CX - p[0]) / M + RES / 2, RES / 2 - (p[2] - CZ) / M)


def in_mask(u, v):
    iu, iv = int(u * mw / RES), int(v * mh / RES)
    if not (0 <= iu < mw and 0 <= iv < mh):
        return False
    return bool(mpix[mh - 1 - iv, iu])


# ---- which triangles: front-facing skin inside the face hull (the capture shows hair in front of skin as hair, so those are left out)
sel = []
for poly in me.polygons:
    if poly.normal.y < 0.25:
        continue
    pts = [px(me.vertices[v].co) for v in poly.vertices]
    c = (sum(p[0] for p in pts) / len(pts), sum(p[1] for p in pts) / len(pts))
    if in_mask(*c) and all(in_mask(*p) or True for p in pts):
        sel.append(poly.index)
print("FACE triangles", len(sel), "of", len(me.polygons))

# ---- second material with front-projection UVs
tex_path = os.path.join(root, "game/prototypes/npc_meshy/face", slug, "face_neutral.png")
mat = bpy.data.materials.new("NPC_Face_Expr")
mat.use_nodes = True
nt = mat.node_tree
b = nt.nodes["Principled BSDF"]
b.inputs["Roughness"].default_value = 1.0
try:
    b.inputs["Specular IOR Level"].default_value = 0.0
except Exception:
    pass
tn = nt.nodes.new("ShaderNodeTexImage")
tn.image = bpy.data.images.load(tex_path)
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

# ---- smooth face-aligned normals around the eyes (the grey outlines were lighting on rough flat-shaded facets: see EYE_ARTIFACT_DIAGNOSTIC.md)
K = 0.24 / SIZE
RX, RY = 95 * K, 62 * K
front = [(p, Vector(p.center)) for p in me.polygons if p.normal.y > 0.0]
loop_normals = [Vector(me.polygons[l.polygon_index].normal) if hasattr(l, "polygon_index") else Vector((0, 1, 0)) for l in me.loops]
for poly in me.polygons:
    for li in poly.loop_indices:
        loop_normals[li] = Vector(poly.normal)
changed = 0
for poly in me.polygons:
    if poly.normal.y <= 0.0:
        continue
    for li in poly.loop_indices:
        v = me.vertices[me.loops[li].vertex_index].co
        u, w = px(v)
        w_ = 0.0
        for (cx, cy) in EYES:
            d = math.hypot((u - cx) / RX, (w - cy) / RY)
            w_ = max(w_, 1.0 - min(1.0, max(0.0, (d - 1.0) / 0.8)))
        if w_ <= 0.0:
            continue
        acc = Vector((0, 0, 0))
        for q, qc in front:
            if (qc - v).length < 0.035:
                acc += q.normal * q.area
        if acc.length < 1e-6:
            continue
        acc.normalize()
        loop_normals[li] = (Vector(poly.normal) * (1 - w_) + acc * w_).normalized()
        changed += 1
me.normals_split_custom_set(loop_normals)
print("EYE normals changed", changed)

glb_dir = os.path.join(root, "game/prototypes/npc_meshy")
bpy.ops.object.select_all(action='DESELECT')
body.select_set(True)
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
glb = os.path.join(glb_dir, "CHR_%s_FaceTex.glb" % slug)
bpy.ops.export_scene.gltf(filepath=glb, export_format='GLB', use_selection=True, export_animations=True, export_animation_mode='ACTIONS',
                          export_skins=True, export_yup=True, export_normals=True, export_apply=False)
print("EXPORTED", slug, os.path.getsize(glb))
