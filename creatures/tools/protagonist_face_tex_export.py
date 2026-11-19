"""Export the protagonist (face-texture material + smooth eye normals) (second material slot) as a GLB for the Godot check.
   blender -b -P protagonist_face_tex_export.py -- <repo_root>"""
import bpy, sys, os
root = sys.argv[sys.argv.index("--") + 1]
base = os.path.join(root, "creatures/humans/protagonist/face_geo")
bpy.ops.wm.open_mainfile(filepath=os.path.join(base, "protagonist_face_texture_swap.blend"))
body = bpy.data.objects["Protagonist_Meshy_Body"]
rig = bpy.data.objects["Protagonist_Meshy_Rig"]
mat = body.data.materials[1]
for nd in mat.node_tree.nodes:
    if nd.type == 'TEX_IMAGE':
        nd.image = bpy.data.images.load(os.path.join(root, "game/prototypes/protagonist_meshy/face/tex/face_neutral.png"))
        nd.interpolation = "Closest"
import json, math
from mathutils import Vector
cap = json.load(open(os.path.join(root, "creatures/humans/protagonist/work/face/face_capture.json")))
RES, CX, CZ, SIZE = cap["res"], cap["cx"], cap["cz"], cap["size"]
M = SIZE / RES
EYES = [(355, 435), (637, 432)]
me = body.data


def px(p):
    return ((CX - p[0]) / M + RES / 2, RES / 2 - (p[2] - CZ) / M)


# ---- eye normals (fix for the grey lines; see EYE_ARTIFACT_DIAGNOSTIC.md): smooth, face-aligned normals on the loops around the eyes
polys = [(p, Vector(p.center)) for p in me.polygons if p.normal.y > 0.0]
loop_normals = [Vector(l.normal) if hasattr(l, "normal") else Vector((0, 1, 0)) for l in me.loops]
me.calc_loop_triangles()
n_changed = 0
for poly in me.polygons:
    for li in poly.loop_indices:
        loop_normals[li] = Vector(poly.normal)
for poly in me.polygons:
    if poly.normal.y <= 0.0:
        continue
    for li in poly.loop_indices:
        v = me.vertices[me.loops[li].vertex_index].co
        u, w = px(v)
        w_ = 0.0
        for (cx, cy) in EYES:
            d = math.hypot((u - cx) / 95, (w - cy) / 62)
            w_ = max(w_, 1.0 - min(1.0, max(0.0, (d - 1.0) / 0.8)))
        if w_ <= 0.0:
            continue
        # a smooth face-aligned normal: the average of the face normals of all front triangles within 3.5 cm, ignoring the strongest outliers
        acc = Vector((0, 0, 0))
        for q, qc in polys:
            if (qc - v).length < 0.035:
                acc += q.normal * q.area
        if acc.length < 1e-6:
            continue
        acc.normalize()
        loop_normals[li] = (Vector(poly.normal) * (1 - w_) + acc * w_).normalized()
        n_changed += 1
me.normals_split_custom_set(loop_normals)
print("PROPOSAL loop normals changed", n_changed)

bpy.ops.object.select_all(action='DESELECT')
body.select_set(True)
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.export_scene.gltf(filepath=os.path.join(root, "game/prototypes/protagonist_meshy/face/CHR_Protagonist_FaceTex.glb"), export_format='GLB', use_selection=True, export_animations=True,
                          export_animation_mode='ACTIONS', export_skins=True, export_yup=True, export_apply=False)
print("EXPORTED", os.path.getsize(os.path.join(root, "game/prototypes/protagonist_meshy/face/CHR_Protagonist_FaceTex.glb")))
