"""DIAGNOSTIC + PROPOSAL (writes only face_geo/_proposal_eye_normals.glb; the character files are not changed):
 1. counts overlapping front-facing geometry layers over the eyes (ray casts from the front),
 2. builds a copy whose faces around the eyes get a smooth, face-aligned normal (custom normals; no vertex moves, no texture change).
   blender -b -P protagonist_eye_normals_proposal.py -- <repo_root>"""
import bpy, sys, os, json, math
import numpy as np
from mathutils import Vector

root = sys.argv[sys.argv.index("--") + 1]
base = os.path.join(root, "creatures/humans/protagonist")
out = os.path.join(base, "face_geo")
bpy.ops.wm.open_mainfile(filepath=os.path.join(out, "protagonist_face_texture_swap.blend"))
body = bpy.data.objects["Protagonist_Meshy_Body"]
me = body.data
cap = json.load(open(os.path.join(base, "work/face/face_capture.json")))
RES, CX, CZ, SIZE = cap["res"], cap["cx"], cap["cz"], cap["size"]
M = SIZE / RES


def px(p):
    return ((CX - p[0]) / M + RES / 2, RES / 2 - (p[2] - CZ) / M)


def to3(u, v):
    return Vector((CX - (u - RES / 2) * M, 0.0, CZ - (v - RES / 2) * M))


EYES = [(355, 435), (637, 432)]

# ---- 1. overlapping front-facing layers over the eyes
mx_layers = 0
for (cx, cy) in EYES:
    for du in range(-70, 71, 10):
        for dv in range(-40, 41, 10):
            o = to3(cx + du, cy + dv)
            o.y = 1.0
            d = Vector((0, -1, 0))
            layers = 0
            for _ in range(8):
                hit, loc, nor, idx = body.ray_cast(o, d)
                if not hit:
                    break
                if nor.y > 0:
                    layers += 1
                o = loc + d * 1e-4
            mx_layers = max(mx_layers, layers)
print("LAYERS max front-facing surfaces along a ray over the eyes:", mx_layers)

# ---- normal spread around the eyes (why the shading breaks up)
ang = []
for poly in me.polygons:
    pts = [px(me.vertices[v].co) for v in poly.vertices]
    c = (sum(p[0] for p in pts) / 3, sum(p[1] for p in pts) / 3)
    if any(math.hypot((c[0] - cx) / 90, (c[1] - cy) / 55) < 1 for cx, cy in EYES) and poly.normal.y > 0:
        ang.append(math.degrees(math.acos(max(-1, min(1, poly.normal.dot(Vector((0, 1, 0))))))))
print("NORMALS around the eyes: %d triangles, angle from straight-ahead min %.0f max %.0f mean %.0f degrees" % (len(ang), min(ang), max(ang), sum(ang) / len(ang)))

# ---- 2. proposal: smooth, face-aligned normals on the loops around the eyes
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

rig = bpy.data.objects["Protagonist_Meshy_Rig"]
bpy.ops.object.select_all(action='DESELECT')
body.select_set(True)
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.export_scene.gltf(filepath=os.path.join(out, "_proposal_eye_normals.glb"), export_format='GLB', use_selection=True, export_animations=False,
                          export_skins=True, export_yup=True, export_normals=True, export_apply=False)
print("PROPOSAL exported")
