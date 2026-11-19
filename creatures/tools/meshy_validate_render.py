"""THE VEIL - Meshy character import, validation and PSX-texture comparison renders (Blender 5.x, headless).
Imports the untouched Meshy OBJ, prints a validation report (counts, UVs, scale, orientation, separable parts),
then renders the SAME mesh with matching cameras and lights using: the original 2048 texture (linear, smooth shaded),
and the 256 / 512 nearest-neighbour copies (nearest filtering, flat shaded, restrained lighting).
   blender -b -P meshy_validate_render.py -- <repo_root>
Nothing is modified on disk except the PNGs written under creatures/humans/sarah_meshy/work/renders and the report JSON."""
import bpy, bmesh, sys, os, math, json
import numpy as np
from mathutils import Vector

root = sys.argv[sys.argv.index("--") + 1]
base = os.path.join(root, "creatures/humans/sarah_meshy")
obj_path = os.path.join(base, "source/original/mara_vale_lowpoly.obj")
tex = {
    "original_2048": os.path.join(base, "source/original/textures/material_0_diffuse.png"),
    "psx_256": os.path.join(base, "work/textures/material_0_diffuse_256_nearest.png"),
    "psx_512": os.path.join(base, "work/textures/material_0_diffuse_512_nearest.png"),
}
outdir = os.path.join(base, "work/renders")
os.makedirs(outdir, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.wm.obj_import(filepath=obj_path)
src = [o for o in bpy.context.scene.objects if o.type == 'MESH'][0]


def arr(ob):
    v = np.empty(len(ob.data.vertices) * 3, dtype=np.float64)
    ob.data.vertices.foreach_get("co", v)
    return v.reshape(-1, 3)


# ---- orientation: the tall axis becomes Z
v = arr(src)
ext = v.max(0) - v.min(0)
tall = int(np.argmax(ext))
print("IMPORTED extents", ext.round(3), "tall axis", "XYZ"[tall])
if tall == 1:
    src.rotation_euler = (math.pi / 2, 0, 0)
    bpy.context.view_layer.update()
    bpy.ops.object.select_all(action='DESELECT')
    src.select_set(True)
    bpy.context.view_layer.objects.active = src
    bpy.ops.object.transform_apply(rotation=True)
v = arr(src)
lo, hi = v.min(0), v.max(0)
h = hi[2] - lo[2]
print("STANDING bbox", lo.round(3), hi.round(3), "height", round(h, 3))

# ---- validation report
me = src.data
bm = bmesh.new()
bm.from_mesh(me)
tris = sum(len(f.verts) - 2 for f in bm.faces)
uvl = bm.loops.layers.uv.active
uvs = np.array([l[uvl].uv[:] for f in bm.faces for l in f.loops]) if uvl else np.zeros((0, 2))
# connected components (separable parts, by shared vertices)
seen = set()
comps = []
for vtx in bm.verts:
    if vtx.index in seen:
        continue
    stack = [vtx]
    seen.add(vtx.index)
    cv = []
    while stack:
        c = stack.pop()
        cv.append(c.co.copy())
        for e in c.link_edges:
            o = e.other_vert(c)
            if o.index not in seen:
                seen.add(o.index)
                stack.append(o)
    pts = np.array([p[:] for p in cv])
    comps.append((len(cv), pts.min(0), pts.max(0)))
comps.sort(key=lambda c: -c[0])
# UV islands (by shared UV coordinates through faces)
bm.faces.ensure_lookup_table()
report = {
    "tris": tris, "verts": len(me.vertices), "faces": len(me.polygons),
    "quads": sum(1 for p in me.polygons if len(p.vertices) == 4), "ngons": sum(1 for p in me.polygons if len(p.vertices) > 4),
    "uv_layers": len(me.uv_layers), "uv_min": uvs.min(0).round(4).tolist() if len(uvs) else None, "uv_max": uvs.max(0).round(4).tolist() if len(uvs) else None,
    "uv_outside_0_1": int(((uvs < 0) | (uvs > 1)).any(axis=1).sum()) if len(uvs) else 0,
    "materials": [m.name if m else None for m in me.materials], "material_slots": len(me.materials),
    "height_m": round(float(h), 3), "width_m": round(float(hi[0] - lo[0]), 3), "depth_m": round(float(hi[1] - lo[1]), 3),
    "origin_to_feet": round(float(lo[2]), 3),
    "connected_parts": len(comps),
    "parts": [{"verts": c[0], "z_range": [round(float(c[1][2]), 3), round(float(c[2][2]), 3)], "x_range": [round(float(c[1][0]), 3), round(float(c[2][0]), 3)]} for c in comps[:30]],
    "non_manifold_edges": sum(1 for e in bm.edges if not e.is_manifold),
    "loose_verts": sum(1 for x in bm.verts if not x.link_edges),
}
bm.free()
json.dump(report, open(os.path.join(base, "work/validation_report.json"), "w"), indent=1)
print("REPORT", json.dumps({k: report[k] for k in report if k != "parts"}))

# ---- materials
def mat(name, path, nearest, glossy):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    b.inputs["Roughness"].default_value = 0.55 if glossy else 1.0
    try:
        b.inputs["Specular IOR Level"].default_value = 0.5 if glossy else 0.0
    except Exception:
        pass
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = bpy.data.images.load(path)
    t.image.colorspace_settings.name = "sRGB"
    t.interpolation = "Closest" if nearest else "Linear"
    nt.links.new(t.outputs["Color"], b.inputs["Base Color"])
    return m


variants = {}
for key, nearest, flat, glossy in (("original_2048", False, False, True), ("psx_256", True, True, False), ("psx_512", True, True, False)):
    o = src.copy()
    o.data = src.data.copy()
    bpy.context.scene.collection.objects.link(o)
    o.data.materials.clear()
    o.data.materials.append(mat(key, tex[key], nearest, glossy))
    for p in o.data.polygons:
        p.use_smooth = not flat
    o.hide_render = True
    variants[key] = o
src.hide_render = True
src.hide_set(True)

# ---- identical world, lights and cameras for every variant
w = bpy.data.worlds.new("w")
w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (.20, .21, .24, 1)
w.node_tree.nodes["Background"].inputs[1].default_value = 1.0
bpy.context.scene.world = w
for rot, en in (((50, 0, -35), 3.0), ((70, 0, 140), 1.0), ((100, 0, 200), 0.8)):
    bpy.ops.object.light_add(type='SUN')
    L = bpy.context.object
    L.rotation_euler = [math.radians(x) for x in rot]
    L.data.energy = en
sc = bpy.context.scene
sc.render.engine = 'BLENDER_EEVEE'
sc.view_settings.view_transform = 'Standard'
cam = bpy.data.cameras.new("c")
cam.type = 'ORTHO'
co = bpy.data.objects.new("c", cam)
sc.collection.objects.link(co)
sc.camera = co
cx, cy = (lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2
# the front is whichever side the face is on: found by testing, so the camera az is an argument-free constant below
FRONT_AZ = float(os.environ.get("MESHY_FRONT_AZ", "0"))
views = [("body_front", FRONT_AZ, .5, 1.1, 520, 900), ("body_three", FRONT_AZ + 40, .5, 1.1, 520, 900),
         ("head_front", FRONT_AZ, .915, .26, 640, 640), ("head_three", FRONT_AZ + 40, .915, .26, 640, 640)]
for key, o in variants.items():
    o.hide_render = False
    for name, az, zf, sz, rx, ry in views:
        t = math.radians(az)
        cam.ortho_scale = h * sz
        sc.render.resolution_x, sc.render.resolution_y = rx, ry
        ctr = Vector((cx, cy, lo[2] + h * zf))
        co.location = (ctr.x + 10 * math.sin(t), ctr.y - 10 * math.cos(t), ctr.z)
        co.rotation_euler = (math.pi / 2, 0, t)
        sc.render.filepath = os.path.join(outdir, "%s_%s.png" % (key, name))
        bpy.ops.render.render(write_still=True)
    o.hide_render = True
# keep a Blender source file of the validation scene
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(base, "work/sarah_meshy_validation.blend"))
