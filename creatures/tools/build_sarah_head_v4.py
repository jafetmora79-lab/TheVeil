"""Sarah head v4 (geometry only, neutral grey review). Starting point: the head+neck cage of the CC0 'Human Basemeshes' female (pistachio, OpenGameArt),
a properly proportioned, rounded human head. Scaled to Sarah's head size, cut at the neck, one Catmull-Clark level for a fuller jaw/skull, flat shaded.
   blender -b "creatures/humans/pack_human_basemeshes/extracted/Human Basemeshes.blend" -P creatures/tools/build_sarah_head_v4.py -- <out.blend> <grey.png> [subsurf_levels]"""
import bpy, bmesh, sys, os, math
import numpy as np
from mathutils import Vector, Matrix

a = sys.argv[sys.argv.index("--") + 1:]
OUT_BLEND, OUT_PNG = a[0], a[1]
LEVELS = int(a[2]) if len(a) > 2 else 1
DEC_RATIO = float(a[3]) if len(a) > 3 else .30
src = bpy.data.objects["basemesh_female"]
for m in list(src.modifiers):
    src.modifiers.remove(m)
me = src.data
M = np.array(src.matrix_world)
bm = bmesh.new()
bm.from_mesh(me)
bm.faces.ensure_lookup_table()
bm.transform(Matrix(M.tolist()))
bmesh.ops.delete(bm, geom=[f for f in bm.faces if min(v.co.z for v in f.verts) < 1.50], context='FACES')
bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
# head size and place: crown at 1.66 m, chin at ~1.44 m (the body and rig stay as they are)
S = .222 / .295
zt = 1.851
for v in bm.verts:
    v.co = Vector((v.co.x * S, (v.co.y + .03) * S - .03, 1.66 + (v.co.z - zt) * S))
nm = bpy.data.meshes.new("Sarah_Head_v4")
bm.to_mesh(nm)
bm.free()
head = bpy.data.objects.new("Sarah_Head_v4", nm)
bpy.context.scene.collection.objects.link(head)
for o in list(bpy.data.objects):
    if o is not head and o.type in ('MESH', 'ARMATURE', 'CAMERA'):
        bpy.data.objects.remove(o)
print("CAGE tris", sum(len(p.vertices) - 2 for p in nm.polygons), "verts", len(nm.vertices))
if LEVELS:
    md = head.modifiers.new("sub", 'SUBSURF')
    md.levels = LEVELS
    md.render_levels = LEVELS
    bpy.context.view_layer.objects.active = head
    bpy.ops.object.modifier_apply(modifier="sub")
# ---------------------------------------------------------------------------------------- reshape to a natural, fuller adult head
def sm(x):
    x = max(0.0, min(1.0, x))
    return x * x * (3 - 2 * x)


V = np.array([v.co[:] for v in head.data.vertices])
zmin, zmax = V[:, 2].min(), V[:, 2].max()
V[:, 2] = zmin + (V[:, 2] - zmin) * (1.66 - zmin) / (zmax - zmin)          # crown back to 1.66
zk = np.array([1.660, 1.645, 1.625, 1.600, 1.575, 1.550, 1.525, 1.500, 1.475, 1.455, 1.440, 1.425, 1.410])
hw_t = np.array([.022, .050, .068, .075, .077, .074, .069, .063, .055, .045, .037, .035, .037])          # fuller jaw, rounded chin
fy_t = np.array([-.020, -.062, -.095, -.108, -.110, -.106, -.104, -.103, -.098, -.090, -.078, -.060, -.045])
by_t = np.array([.040, .064, .080, .086, .086, .082, .076, .066, .052, .034, .024, .018, .016])
bins = np.linspace(V[:, 2].min(), V[:, 2].max(), 28)
hw_c, fy_c, by_c, zc = [], [], [], []
for i in range(len(bins) - 1):
    m = (V[:, 2] >= bins[i] - .004) & (V[:, 2] <= bins[i + 1] + .004)
    if m.sum() > 2:
        hw_c.append(np.abs(V[m, 0]).max()); fy_c.append(V[m, 1].min()); by_c.append(V[m, 1].max()); zc.append((bins[i] + bins[i + 1]) / 2)
zc, hw_c, fy_c, by_c = map(np.array, (zc, hw_c, fy_c, by_c))
zi = np.argsort(zc)
zc, hw_c, fy_c, by_c = zc[zi], hw_c[zi], fy_c[zi], by_c[zi]
for i, v in enumerate(V):
    z = v[2]
    if z < 1.405:
        continue
    w = sm((z - 1.405) / .03)
    hc, fc, bc = np.interp(z, zc, hw_c), np.interp(z, zc, fy_c), np.interp(z, zc, by_c)
    ht, ft, bt = np.interp(z, zk[::-1], hw_t[::-1]), np.interp(z, zk[::-1], fy_t[::-1]), np.interp(z, zk[::-1], by_t[::-1])
    nx = v[0] / max(hc, 1e-5)
    ny = (v[1] - fc) / max(bc - fc, 1e-5)
    V[i, 0] = v[0] * (1 - w) + (nx * ht) * w
    V[i, 1] = v[1] * (1 - w) + (ft + ny * (bt - ft)) * w
for i, v in enumerate(V):
    if v[2] < 1.50:
        V[i, 2] = 1.50 - (1.50 - v[2]) * .90
EZ = 1.553                                                                                          # eye line
for i, v in enumerate(V):
    x, y, z = v
    front = y < -.04
    if not front:
        continue
    d = 0.0
    d += .0015 * math.exp(-(((abs(x)) / .055) ** 2) - ((z - 1.585) / .014) ** 2)                    # brow ridge, subtle
    d -= .0022 * math.exp(-(((abs(x) - .034) / .014) ** 2) - ((z - EZ) / .010) ** 2)                # eye sockets
    nz = z - 1.50
    bridge = .006 * math.exp(-((x / .008) ** 2) - ((z - 1.565) / .018) ** 2)
    tip = .011 * math.exp(-((x / .012) ** 2) - ((z - 1.527) / .009) ** 2)
    base = .008 * math.exp(-((x / .017) ** 2) - ((z - 1.517) / .007) ** 2)
    d += bridge + tip + base                                                                       # a low-poly nose volume
    d += 0.0       # keep the cheekbone soft
    d += .0015 * math.exp(-((x / .025) ** 2) - ((z - 1.490) / .008) ** 2)                           # mouth area barely proud
    d += .002 * math.exp(-((x / .022) ** 2) - ((z - 1.455) / .008) ** 2)                           # round chin
    V[i, 1] -= d
for i, v in enumerate(head.data.vertices):
    v.co = Vector(V[i])
# reduce the refined (subdivided + sculpted) head back to a low-poly budget, keeping the shapes
bpy.context.view_layer.objects.active = head
head.data.update()
dmod = head.modifiers.new("lowpoly", 'DECIMATE')
dmod.decimate_type = 'COLLAPSE'
dmod.ratio = DEC_RATIO
dmod.use_symmetry = True
dmod.symmetry_axis = 'X'
bpy.ops.object.modifier_apply(modifier="lowpoly")
bme = bmesh.new()
bme.from_mesh(head.data)
# take the head down below the jaw: the body's own neck rises into it (softer, shorter jaw-to-neck blend)
bmesh.ops.delete(bme, geom=[f for f in bme.faces if max(v.co.z for v in f.verts) < 1.425], context='FACES')
bmesh.ops.delete(bme, geom=[v for v in bme.verts if not v.link_faces], context='VERTS')
# ears grown out of the side of the skull: inset + extrude the existing side faces, tilted back and tapered
bme.faces.ensure_lookup_table()
for sx in (-1, 1):
    sel = [f for f in bme.faces if sx * f.calc_center_median().x > .062 and -.012 < f.calc_center_median().y < .040 and 1.532 < f.calc_center_median().z < 1.588]
    print("EAR faces", sx, len(sel))
    if not sel:
        continue
    ex = bmesh.ops.extrude_face_region(bme, geom=sel)
    vv = [e for e in ex['geom'] if isinstance(e, bmesh.types.BMVert)]
    cz = sum(v.co.z for v in vv) / len(vv); cy = sum(v.co.y for v in vv) / len(vv)
    for v in vv:
        v.co.x += sx * .011
        v.co.y = cy + (v.co.y - cy) * .80 + .006
        v.co.z = cz + (v.co.z - cz) * .80
bmesh.ops.recalc_face_normals(bme, faces=list(bme.faces))
bme.to_mesh(head.data)
bme.free()
head.data.update()
for p in head.data.polygons:
    p.use_smooth = False
print("HEAD tris", sum(len(p.vertices) - 2 for p in head.data.polygons))
vs = np.array([v.co[:] for v in head.data.vertices])
print("HEAD bbox", vs.min(0).round(3), vs.max(0).round(3))
bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(OUT_BLEND))
