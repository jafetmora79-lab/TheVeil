"""THE VEIL - Sarah rebuilt as an early-PS2 horror character from the CC0 DaemonBase female basemesh (DaemonOutcast, OpenGameArt).
   blender -b creatures/humans/pack_daemonbase/extracted/fem.blend -P creatures/tools/build_sarah_ps2.py -- <out.glb> <out.blend>
Starting geometry: the basemesh body (1024 tris) and its faceted head (746 tris: brow, nose, lips, ears, eye openings). Scaled to a 1.66 m paramedic, eyeballs decimated,
the uniform CUT OUT OF THE BODY SURFACE (loop-cut hems, shirt+sleeves, trousers, boots) and inflated, then collar, belt, pouch, radio holster, pockets, knee pads,
hair cap (cut from the head surface), ponytail and side locks added by editing that geometry. Low-resolution textures are painted by rasterising every face into its
UV space (face features, fabric weave, creases, wear). Skeleton: the VEIL humanoid bone names, A-pose rest, weights from the body shape."""
import bpy, bmesh, sys, os, math, random
import numpy as np
from mathutils import Vector, Matrix
from collections import Counter

OUT_GLB, OUT_BLEND = sys.argv[sys.argv.index("--") + 1], sys.argv[sys.argv.index("--") + 2]
HEIGHT = 1.66
HEAD_RATIO = float(os.environ.get("HEAD_RATIO", "0.30"))
random.seed(4)
rng = np.random.default_rng(4)

# ================================================================================================================ prep
body = bpy.data.objects["FemmeBody"]
head = bpy.data.objects["femmehead"]
eyes = bpy.data.objects["eyes"]
lash = bpy.data.objects["lash"]
for o in (head, eyes, lash):
    mw = o.matrix_world.copy()
    o.parent = None
    o.matrix_world = mw
bpy.data.objects.remove(lash)
for o in list(bpy.data.objects):
    if o.type != 'MESH':
        bpy.data.objects.remove(o)
S = HEIGHT / 2.006
for o in (body, head, eyes):
    for m in list(o.modifiers):
        o.modifiers.remove(m)
    o.data.materials.clear()
    o.data.transform(o.matrix_world)
    o.matrix_world = Matrix.Identity(4)
    o.data.transform(Matrix.Scale(S, 4))
    o.data.update()
bpy.context.view_layer.objects.active = eyes
dm = eyes.modifiers.new("d", 'DECIMATE')
dm.ratio = .28
bpy.ops.object.modifier_apply(modifier="d")



# ===== FACIAL ART DIRECTION CORRECTION: a 3D head with a PAINTED face. Sculpted lips/lids/eyeballs are dropped; the silhouette stays in the geometry.
eyeb0 = np.array([v.co[:] for v in eyes.data.vertices])
EL = Vector(eyeb0[eyeb0[:, 0] < 0].mean(0))
ER = Vector(eyeb0[eyeb0[:, 0] > 0].mean(0))
bpy.data.objects.remove(eyes)                                    # simple painted eyes: no eyeball meshes
head_orig = head.copy()
head_orig.data = head.data.copy()
head_orig.name = "Sarah_Head_ORIGINAL"
bpy.context.scene.collection.objects.link(head_orig)
head_orig.hide_render = True
head_orig.hide_viewport = True
bmh = bmesh.new()
bmh.from_mesh(head.data)
bmesh.ops.dissolve_limit(bmh, angle_limit=math.radians(14), verts=list(bmh.verts), edges=list(bmh.edges), delimit={'MATERIAL'})
bmesh.ops.holes_fill(bmh, edges=[e for e in bmh.edges if e.is_boundary], sides=12)
bmh.to_mesh(head.data)
bmh.free()
head.data.update()
bpy.context.view_layer.objects.active = head
dm2 = head.modifiers.new("simplify", 'DECIMATE')
dm2.decimate_type = 'COLLAPSE'
dm2.ratio = HEAD_RATIO
dm2.use_symmetry = True
dm2.symmetry_axis = 'X'
bpy.ops.object.modifier_apply(modifier="simplify")
_hv = head.data.vertices
_ymin = min(v.co.y for v in _hv)
_nz = (EL.z + ER.z) / 2 - .040
_best = min(_hv, key=lambda v: (v.co.x - (EL.x + ER.x) / 2) ** 2 + (v.co.y - _ymin) ** 2 * .25 + (v.co.z - _nz) ** 2)
_best.co.y -= .014
for _v in _hv:
    if _v != _best and (_v.co - _best.co).length < .022:
        _v.co.y -= .005
print("HEAD simplified tris", sum(len(p.vertices) - 2 for p in head.data.polygons), "from", sum(len(p.vertices) - 2 for p in head_orig.data.polygons))


def tris(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


hb = np.array([v.co[:] for v in head.data.vertices])
z_top, z_head0 = hb[:, 2].max(), hb[:, 2].min()
head_h = z_top - z_head0
y_front, y_back = hb[:, 1].min(), hb[:, 1].max()
Z = lambda z: z * S
LM = {"boot": Z(.26), "hem": Z(.97), "wrist": Z(1.12), "shoulder": Z(1.46), "neck": Z(1.57), "chest": Z(1.30), "knee": Z(.52), "crotch": Z(.80), "waist": Z(1.12)}

# ================================================================================================= clothing cut from the body
bm0 = bmesh.new()
bm0.from_mesh(body.data)
for zc in (LM["boot"], LM["hem"], LM["wrist"]):
    bmesh.ops.bisect_plane(bm0, geom=list(bm0.verts) + list(bm0.edges) + list(bm0.faces), plane_co=(0, 0, zc), plane_no=(0, 0, 1), clear_inner=False, clear_outer=False)
bm0.to_mesh(body.data)
bm0.free()
body.data.update()


def classify(c):
    x, y, z = c
    ax = abs(x)
    if z > LM["neck"] and ax < Z(.09):
        return "neck"
    if ax > Z(.37) and z < LM["wrist"]:
        return "hand"
    if ax > Z(.205) and LM["wrist"] <= z < LM["shoulder"] + Z(.04):
        return "sleeve"
    if z >= LM["hem"]:
        return "shirt"
    if z < LM["boot"]:
        return "boot"
    return "trouser"


bm = bmesh.new()
bm.from_mesh(body.data)
bm.faces.ensure_lookup_table()
tags = [classify(f.calc_center_median()) for f in bm.faces]
bm.free()
print("FACE CLASSES", Counter(tags))


def extract(tagset, inflate, name):
    b2 = bmesh.new()
    b2.from_mesh(body.data)
    b2.faces.ensure_lookup_table()
    bmesh.ops.delete(b2, geom=[f for f, t in zip(b2.faces, tags) if t not in tagset], context='FACES')
    bmesh.ops.recalc_face_normals(b2, faces=b2.faces)
    b2.verts.ensure_lookup_table()
    for v in b2.verts:
        v.normal_update()
    for v in b2.verts:
        v.co += v.normal * inflate
    me = bpy.data.meshes.new(name)
    b2.to_mesh(me)
    b2.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


shirt = extract({"shirt", "sleeve"}, .007, "Shirt")
pants = extract({"trouser"}, .008, "Trousers")
boots = extract({"boot"}, .013, "Boots")
shirt_tags = [t for t in tags if t in ("shirt", "sleeve")]
bm = bmesh.new()
bm.from_mesh(body.data)
bm.faces.ensure_lookup_table()
bmesh.ops.delete(bm, geom=[f for f, t in zip(bm.faces, tags) if t not in ("hand", "neck")], context='FACES')
bm.to_mesh(body.data)
bm.free()
body.name = "Skin_Body"

shirt_pts = np.array([v.co[:] for v in shirt.data.vertices])
pants_pts = np.array([v.co[:] for v in pants.data.vertices])


def section(z, tol=None, pts=None):
    pts = shirt_pts if pts is None else pts
    tol = tol or Z(.16)
    s = pts[(abs(pts[:, 2] - z) < tol) & (abs(pts[:, 0]) < Z(.24))]
    return ((s[:, 0].min() + s[:, 0].max()) / 2, (s[:, 1].min() + s[:, 1].max()) / 2, (s[:, 0].max() - s[:, 0].min()) / 2, (s[:, 1].max() - s[:, 1].min()) / 2)


def box(b2, c, sz, rot=0.0):
    r = bmesh.ops.create_cube(b2, size=1.0)
    vs = r["verts"]
    bmesh.ops.scale(b2, vec=sz, verts=vs)
    bmesh.ops.rotate(b2, cent=(0, 0, 0), matrix=Matrix.Rotation(rot, 3, 'Z'), verts=vs)
    bmesh.ops.translate(b2, vec=c, verts=vs)
    return vs


def band(b2, z0, z1, g0, g1, seg=20):
    rings = []
    for z, g in ((z0, g0), (z1, g1)):
        cx, cy, rx, ry = section(z)
        rings.append([b2.verts.new((cx + (rx + g) * math.sin(2 * math.pi * k / seg), cy - (ry + g) * math.cos(2 * math.pi * k / seg), z)) for k in range(seg)])
    for k in range(seg):
        b2.faces.new((rings[0][k], rings[0][(k + 1) % seg], rings[1][(k + 1) % seg], rings[1][k]))


leather, cloth_g = bmesh.new(), bmesh.new()
zb = LM["waist"]
band(leather, zb, zb + Z(.045), .016, .014)
cx, cy, rx, ry = section(zb + Z(.02))
box(leather, (cx - (rx + .026), cy, zb - Z(.01)), (.04, .085, .10))
box(leather, (cx - (rx + .048), cy, zb - Z(.01) + .042), (.008, .088, .018))
box(leather, (cx + (rx + .022), cy - .01, zb - Z(.005)), (.03, .06, .08))
box(leather, (cx, cy - ry - .012, zb + Z(.02)), (.028, .012, .028))
cn = section(LM["neck"] - Z(.02), Z(.1))
rings = []
for z, g in ((LM["neck"] - Z(.012), .016), (LM["neck"] + Z(.04), .03)):
    rings.append([cloth_g.verts.new((cn[0] + (Z(.07) + g) * math.sin(2 * math.pi * (k + .5) / 14), cn[1] - (Z(.075) + g) * math.cos(2 * math.pi * (k + .5) / 14), z)) for k in range(14)])
for k in range(14):
    if k not in (6, 7):
        cloth_g.faces.new((rings[0][k], rings[0][(k + 1) % 14], rings[1][(k + 1) % 14], rings[1][k]))
for sx in (-1, 1):
    box(cloth_g, (cx + sx * Z(.085), cy - ry * .86 - .008, LM["chest"] - Z(.04)), (.06, .01, .055), sx * .05)
for sx in (-1, 1):
    for zc, sz in ((LM["knee"] + .02, (.06, .018, .055)),):
        sel = pants_pts[(abs(pants_pts[:, 2] - zc) < .07) & (pants_pts[:, 0] * sx > .02)]
        if len(sel):
            if sz[0] > .03:
                box(cloth_g, ((sel[:, 0].min() + sel[:, 0].max()) / 2, sel[:, 1].min() - sz[1] / 2 + .004, zc), sz)
            else:
                box(cloth_g, (sel[:, 0].max() + sz[0] / 2 - .004 if sx > 0 else sel[:, 0].min() - sz[0] / 2 + .004, (sel[:, 1].min() + sel[:, 1].max()) / 2, zc), sz)


def to_obj(b2, name):
    me = bpy.data.meshes.new(name)
    b2.to_mesh(me)
    b2.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


gear_l, gear_c = to_obj(leather, "GearLeather"), to_obj(cloth_g, "GearCloth")

# ------------------------------------------------------------------------------------------------------------------ hair
bh = bmesh.new()
bh.from_mesh(head.data)
bh.faces.ensure_lookup_table()
hf = []
for f in bh.faces:
    c = f.calc_center_median()
    up = (c.z - z_head0) / head_h
    back = (c.y - y_front) / (y_back - y_front)
    if (up > .78) or (up > .42 and back > .52) or (up > .30 and back > .78) or (up > .52 and abs(c.x - (hb[:, 0].min() + hb[:, 0].max()) / 2) > .052):
        hf.append(f)
dup = bmesh.ops.duplicate(bh, geom=hf)["geom"]
keepf = set(g for g in dup if isinstance(g, bmesh.types.BMFace))
for v in [g for g in dup if isinstance(g, bmesh.types.BMVert)]:
    v.normal_update()
for v in [g for g in dup if isinstance(g, bmesh.types.BMVert)]:
    v.co += v.normal * .011 + Vector((0, .004, .002))
bmesh.ops.delete(bh, geom=[f for f in bh.faces if f not in keepf], context='FACES')
bmesh.ops.delete(bh, geom=[v for v in bh.verts if not v.link_faces], context='VERTS')
bs = bmesh.new()
uvs = bs.loops.layers.uv.verify()


def tube(b2, pts, radii, sides=7, flat=1.0, cap_end=True):
    pts = [Vector(p) for p in pts]
    rings = []
    for i, (p, r) in enumerate(zip(pts, radii)):
        t = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        n = t.cross(Vector((1, 0, 0))) if abs(t.x) < .9 else t.cross(Vector((0, 1, 0)))
        n.normalize()
        bn = t.cross(n).normalized()
        rings.append([b2.verts.new(p + (n * math.cos(2 * math.pi * k / sides) + bn * math.sin(2 * math.pi * k / sides) * flat) * r) for k in range(sides)])
    for i in range(len(rings) - 1):
        for k in range(sides):
            f = b2.faces.new((rings[i][k], rings[i][(k + 1) % sides], rings[i + 1][(k + 1) % sides], rings[i + 1][k]))
            for lp, (u, v) in zip(f.loops, ((k, i), (k + 1, i), (k + 1, i + 1), (k, i + 1))):
                lp[uvs].uv = (u / sides * .9, v / (len(rings) - 1))
    if cap_end:
        c = b2.verts.new(pts[-1] + (pts[-1] - pts[-2]).normalized() * radii[-1] * .7)
        for k in range(sides):
            f = b2.faces.new((rings[-1][k], rings[-1][(k + 1) % sides], c))
            for lp in f.loops:
                lp[uvs].uv = (.95, 1.0)


cxh = (hb[:, 0].min() + hb[:, 0].max()) / 2
root = Vector((cxh, y_back - .03, z_top - head_h * .34))
tube(bs, [root, root + Vector((0, .05, -.03)), root + Vector((0, .085, -.12)), root + Vector((.005, .09, -.24)), root + Vector((0, .075, -.36)), root + Vector((-.012, .06, -.46))],
     [.03, .045, .048, .04, .028, .012], 7, .85)
tube(bs, [root + Vector((0, .035, -.01)), root + Vector((0, .04, -.025))], [.036, .036], 8, 1.0)
hair_cap, hair_str = to_obj(bh, "HairCap"), to_obj(bs, "HairStrands")
for v in head.data.vertices:
    v.co.x *= 1.0 - .03 * max(0.0, (z_head0 + head_h * .4 - v.co.z) / (head_h * .4))


def box_uv(ob, scale=6.0):
    me = ob.data
    uv = me.uv_layers.new(name="UVMap")
    for p in me.polygons:
        n = p.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        for li in p.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            u, v = ((co.y, co.z), (co.x, co.z), (co.x, co.y))[ax]
            uv.data[li].uv = ((u * scale) % 1.0 * .5, (v * scale) % 1.0 * .5)


box_uv(gear_l)
box_uv(gear_c)
print("TRIS skin", tris(body), "shirt", tris(shirt), "pants", tris(pants), "boots", tris(boots), "leather", tris(gear_l), "clothgear", tris(gear_c), "cap", tris(hair_cap), "strands", tris(hair_str), "head", tris(head))


# ================================================================================================================ textures
def hexs(h):
    return np.array([int(h[i:i + 2], 16) / 255 for i in (1, 3, 5)], dtype=np.float32)


def raster(ob, tex, fn, face_tags=None):
    """paint `tex` (H,W,3, v=0 at the bottom) by evaluating fn(pos, normal, tag) for every pixel inside every UV triangle"""
    me = ob.data
    uv = me.uv_layers.active.data
    Hh, Ww = tex.shape[:2]
    done = np.zeros((Hh, Ww), dtype=bool)
    for pi, poly in enumerate(me.polygons):
        tag = face_tags[pi] if face_tags else None
        li = poly.loop_indices
        for k in range(1, len(li) - 1):
            ls = (li[0], li[k], li[k + 1])
            uvs_ = np.array([[uv[l].uv[0] * Ww, uv[l].uv[1] * Hh] for l in ls])
            pos = np.array([me.vertices[me.loops[l].vertex_index].co[:] for l in ls])
            x0, x1 = int(max(0, math.floor(uvs_[:, 0].min() - 1))), int(min(Ww - 1, math.ceil(uvs_[:, 0].max() + 1)))
            y0, y1 = int(max(0, math.floor(uvs_[:, 1].min() - 1))), int(min(Hh - 1, math.ceil(uvs_[:, 1].max() + 1)))
            if x1 < x0 or y1 < y0:
                continue
            xs, ys = np.meshgrid(np.arange(x0, x1 + 1) + .5, np.arange(y0, y1 + 1) + .5)
            a, b, c = uvs_
            d = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
            if abs(d) < 1e-9:
                continue
            w0 = ((b[1] - c[1]) * (xs - c[0]) + (c[0] - b[0]) * (ys - c[1])) / d
            w1 = ((c[1] - a[1]) * (xs - c[0]) + (a[0] - c[0]) * (ys - c[1])) / d
            w2 = 1 - w0 - w1
            e = -.6 / max(1.0, abs(d) ** .5)
            inside = (w0 >= e) & (w1 >= e) & (w2 >= e)
            yy, xx = np.nonzero(inside)
            for iy, ix in zip(yy, xx):
                p = w0[iy, ix] * pos[0] + w1[iy, ix] * pos[1] + w2[iy, ix] * pos[2]
                tex[y0 + iy, x0 + ix] = fn(Vector(p), poly.normal, tag)
                done[y0 + iy, x0 + ix] = True
    for _ in range(3):
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            sh = np.roll(np.roll(tex, dy, 0), dx, 1)
            shd = np.roll(np.roll(done, dy, 0), dx, 1)
            m = (~done) & shd
            tex[m] = sh[m]
            done |= m
    return tex


def to_image(name, tex):
    h, w = tex.shape[:2]
    img = bpy.data.images.new(name, w, h, alpha=False)
    flat = np.ones((h, w, 4), dtype=np.float32)
    flat[..., :3] = np.clip(tex, 0, 1)
    img.pixels[:] = flat.reshape(-1)
    img.pack()
    return img


ez = (EL.z + ER.z) / 2
print("EYES (painted) at", tuple(round(c, 3) for c in EL), tuple(round(c, 3) for c in ER))
SKIN, HAIR_C = hexs("#cf8661"), hexs("#7b4a30")
SHADE = hexs("#7a3f2c")
# --- clean UVs: the front of the face is ONE orthographic projection filling the left 70 % of the 256x256 atlas; sides/back/underside share the right 30 %
hxmin, hxmax = hb[:, 0].min(), hb[:, 0].max()
hzmin, hzmax = hb[:, 2].min(), hb[:, 2].max()
hymin, hymax = hb[:, 1].min(), hb[:, 1].max()
huv = head.data.uv_layers.active if head.data.uv_layers else head.data.uv_layers.new(name="UVMap")
for poly in head.data.polygons:
    front = poly.normal.y < -.25
    for li in poly.loop_indices:
        co = head.data.vertices[head.data.loops[li].vertex_index].co
        if front:
            huv.data[li].uv = ((co.x - hxmin) / (hxmax - hxmin) * .70, (co.z - hzmin) / (hzmax - hzmin))
        else:
            huv.data[li].uv = (.72 + (co.y - hymin) / (hymax - hymin) * .26, (co.z - hzmin) / (hzmax - hzmin))


def sm(e0, e1, x):
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def ell(x, z, cx, cz, rx, rz):
    return ((x - cx) / rx) ** 2 + ((z - cz) / rz) ** 2


BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0


def dither(col, px, py, levels=11):
    q = (np.clip(col, 0, 1) * (levels - 1))
    f = q - np.floor(q)
    return (np.floor(q) + (f > BAYER[py % 4, px % 4] * .9)) / (levels - 1)


LIPC, LIPD = hexs("#8a4f4c"), hexs("#5a2c2e")
EYE_W, IRIS, BROW = hexs("#bdb6a4"), hexs("#1f1612"), hexs("#4a2a1c")
face_cx = (hxmin + hxmax) / 2


def face_fn(p, n, tag):
    up = (p.z - hzmin) / (hzmax - hzmin)
    back = (p.y - hymin) / (hymax - hymin)
    if up > .8 or (up > .45 and back > .5):
        return HAIR_C * (.78 + .22 * math.sin(p.x * 90 + p.z * 30))
    x, z = p.x - face_cx, p.z
    col = SKIN.copy()
    # painted light and shadow (light from the upper left), not sculpted relief
    col = col * (1.05 - .10 * sm(.0, .075, x) + .06 * sm(-.075, 0, -x)) + (SHADE - col) * .16 * sm(.0, .08, x)
    col = col * (1 - .22 * sm(.45, 0.0, up))
    col = col + (SHADE - col) * .38 * math.exp(-ell(abs(x), z, .050, ez - .032, .022, .022))
    col = col * (1 - .20 * sm(.060, .085, abs(x)))
    col = col * (1 - .16 * math.exp(-ell(x, z, 0, ez + .036, .05, .012)))
    col = col + hexs("#b8452a") * .30 * math.exp(-ell(abs(x), z, .040, ez - .030, .028, .022))       # flushed cheeks
    for ex in (EL.x - face_cx, ER.x - face_cx):
        dx, dz = x - ex, z - ez
        sgn = 1 if ex > 0 else -1
        socket = ell(dx, dz, 0, .004, .030, .016)
        if socket < 1:
            col = col + (SHADE - col) * .35 * (1 - sm(.1, 1.0, socket))
        under = ell(dx, dz, 0, -.014, .022, .006)
        if under < 1:
            col = col * (.86 + .14 * under)
        top = .0050 * (1 - (dx / .0150) ** 2) + .0004
        bot = -.0036 * (1 - (dx / .0150) ** 2)
        if abs(dx) < .0150 and bot < dz < top:
            col = EYE_W * (.82 + .18 * sm(bot, top, dz)) * (.75 + .25 * (1 - abs(dx) / .024))
            ir = ell(dx, dz, .001 * -sgn, .0004, .0050, .0050)
            if ir < 1:
                col = IRIS * (.8 + .3 * (dz < 0))
                if ir < .22:
                    col = hexs("#050505")
                if ell(dx, dz, -.0018, .0026, .0014, .0014) < 1:
                    col = hexs("#d8d2c4")
            if dz > top - .0042:
                col = col * .55
        if abs(dz - (top + .0008)) < .0018 and abs(dx) < .0170:
            col = hexs("#1b0f0c")
        if abs(dz - (bot - .001)) < .0008 and abs(dx) < .014:
            col = col * .55
        by = ez + .020 + .0045 * (1 - ((dx + .004 * sgn) / .036) ** 2) + .004 * (sgn * dx) / .036
        thick = .0058 * (1.0 - .5 * abs(dx) / .040)
        if abs(dx) < .040 and abs(x) > .010 and abs(z - by) < thick:
            col = BROW * (.8 + .4 * math.sin(p.x * 400))
    if ez - .052 < z < ez - .002:
        w = .005 + .012 * sm(ez - .002, ez - .045, z)
        if w * .6 < x < w * 1.9:
            col = col + (SHADE - col) * .55
        if abs(x + .002) < .0016 and z > ez - .040:
            col = col * 1.10
    if abs(abs(x) - .0085) < .0028 and abs(z - (ez - .046)) < .0016:
        col = hexs("#4a261a")
    if .006 < abs(x) < .018 and abs(z - (ez - .053)) < .0028:
        col = col * .75
    lz = ez - .072
    if abs(x) < .021 and abs(z - lz) < .0016 + .0012 * (1 - abs(x) / .021):
        col = hexs("#4a2218")                                                                    # the mouth is only a painted line
    if abs(x) < .016 and -.0075 < z - (lz - .0045) < .0012 and z < lz - .002:
        col = col * 1.06 + hexs("#6a2a20") * .08                                                 # a slightly warmer lower lip
    if abs(x) < .024 and abs(z - (lz - .014)) < .004:
        col = col + (SHADE - col) * .22                                                          # chin shadow
    if (int(p.x * 700) * 7 + int(p.z * 700) * 13) % 53 == 0 and abs(x) < .06 and ez - .05 < z < ez - .005:
        col = col * .86
    return col


face = raster(head, np.zeros((256, 256, 3), dtype=np.float32), face_fn)
for _ in range(2):                                           # soft, low-res painted look (the references are bilinear-soft)
    face = (face + np.roll(face, 1, 0) + np.roll(face, -1, 0) + np.roll(face, 1, 1) + np.roll(face, -1, 1)) / 5.0
skin_t = raster(body, np.tile(SKIN, (128, 128, 1)).astype(np.float32), lambda p, n, t: SKIN * (.92 + .08 * noise(p, 2)))
NAVY, NAVY_D, TROU, CREAM = hexs("#1d2a46"), hexs("#131b30"), hexs("#161b27"), hexs("#b9b49c")


def shirt_fn(p, n, tag):
    weave = 1.0 + .045 * (1 if (int(p.x * 190) + int(p.z * 190)) % 2 else -1)
    col = NAVY * weave
    if tag == "sleeve":
        col = col * (1.0 - .24 * math.exp(-((p.z - Z(1.27)) / .035) ** 2) * (.55 + .45 * math.sin(abs(p.x) * 160)))
        col = col * (1.0 - .18 * math.exp(-((p.z - Z(1.38)) / .03) ** 2))
        if p.z < LM["wrist"] + Z(.07):
            col = CREAM * (.9 + .1 * weave)
    else:
        col = col * (1 - .22 * math.exp(-((p.z - (zb - .02)) / .035) ** 2))
        col = col * (1 - .25 * math.exp(-(((abs(p.x) - Z(.13)) / .03) ** 2 + ((p.z - (LM["chest"] - Z(.02))) / .04) ** 2)))
        col = col * (1 - .16 * math.exp(-((p.z - (zb + Z(.07))) / .03) ** 2) * (.5 + .5 * math.sin(p.x * 120 + p.z * 40)))
        if p.z > LM["shoulder"] - Z(.02) and abs(abs(p.x) - Z(.17)) < .006:
            col = NAVY_D
        if n.y < -.3 and abs(p.x) < Z(.022):
            col = col * .78
        if n.y < -.3 and Z(.07) < p.x < Z(.135) and abs(p.z - (LM["chest"] - Z(.075))) < .011:
            col = hexs("#c2a95c")
        if p.z < LM["hem"] + Z(.025):
            col = col * .8
    return col


def pants_fn(p, n, tag):
    col = TROU * (1.0 + .05 * (1 if (int(p.x * 190) + int(p.z * 190)) % 2 else -1))
    if n.y < -.4 and abs(abs(p.x) - .095) < .005:
        col = col * 1.5
    col = col * (1 - .22 * math.exp(-((p.z - LM["knee"]) / .05) ** 2) * (.5 + .5 * math.sin(p.x * 140 + p.z * 90)))
    col = col * (1 - .2 * math.exp(-((p.z - LM["crotch"]) / .04) ** 2))
    return col


cloth_tex = np.zeros((128, 128, 3), dtype=np.float32)
raster(shirt, cloth_tex, shirt_fn, face_tags=shirt_tags)
raster(pants, cloth_tex, pants_fn)
for yy in range(16):
    for xx in range(16):
        cloth_tex[yy, xx] = NAVY * (1.0 + .05 * (1 if (xx + yy) % 2 else -1))
leather_t = np.zeros((64, 64, 3), dtype=np.float32)
for yy in range(64):
    for xx in range(64):
        leather_t[yy, xx] = hexs("#2b1d16") * (.85 + .3 * abs(math.sin(xx * .7 + yy * .3) * math.sin(yy * .9 - xx * .2)))


def boot_fn(p, n, tag):
    col = hexs("#2c1f18") * (.85 + .3 * abs(noise(p, 1.4)))
    if p.z < Z(.03):
        col = hexs("#120d0b")
    elif p.z < Z(.07):
        col = col * 1.25
    if abs(p.z - Z(.2)) < .006:
        col = hexs("#524033")
    return col


boot_t = raster(boots, np.zeros((64, 64, 3), dtype=np.float32), boot_fn)
hair_t = np.zeros((64, 64, 3), dtype=np.float32)
for yy in range(64):
    for xx in range(64):
        s_ = .55 + .35 * math.sin(xx * .9 + math.sin(yy * .25) * 2.0) * .5 + .2 * math.sin(xx * .31)
        hair_t[yy, xx] = HAIR_C * (.7 + .6 * s_) * (1.0 + .08 * math.sin(yy * .18))
hair_cap_t = raster(hair_cap, np.zeros((128, 128, 3), dtype=np.float32),
                    lambda p, n, t: HAIR_C * (.62 + .4 * (.5 + .5 * math.sin(p.x * 70 + math.sin(p.z * 25) * 2.5))) * (.85 + .3 * max(0, n.z)))


def mk(name, tex, rough=1.0, interp='Closest'):
    img = to_image("T_" + name, tex)
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = img
    t.interpolation = interp
    nt.links.new(t.outputs["Color"], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = rough
    return m


M_face, M_skin = mk("Sarah_Face", face, 1.0, "Linear"), mk("Sarah_Skin", skin_t)
M_cloth, M_leather, M_boot = mk("Sarah_Cloth", cloth_tex), mk("Sarah_Leather", leather_t), mk("Sarah_Boots", boot_t)
M_hair, M_hairs = mk("Sarah_Hair", hair_cap_t), mk("Sarah_HairStrands", hair_t)
for ob, m in ((head, M_face), (body, M_skin), (shirt, M_cloth), (pants, M_cloth), (gear_l, M_leather), (gear_c, M_cloth), (boots, M_boot), (hair_cap, M_hair), (hair_str, M_hairs)):
    ob.data.materials.clear()
    ob.data.materials.append(m)
    for p in ob.data.polygons:
        p.use_smooth = False
uvl = gear_c.data.uv_layers.active.data
for p in gear_c.data.polygons:
    for li in p.loop_indices:
        uvl[li].uv = (.01 + uvl[li].uv[0] * .1, .01 + uvl[li].uv[1] * .1)

# ================================================================================================================ rig + weights
bpy.ops.object.select_all(action='DESELECT')
for ob in (shirt, pants, boots, gear_l, gear_c, body):
    ob.select_set(True)
bpy.context.view_layer.objects.active = body
bpy.ops.object.join()
sbody = bpy.context.view_layer.objects.active
sbody.name = "Sarah_Body"
bpy.ops.object.select_all(action='DESELECT')
for ob in (hair_cap, hair_str):
    ob.select_set(True)
bpy.context.view_layer.objects.active = hair_cap
bpy.ops.object.join()
shair = bpy.context.view_layer.objects.active
shair.name = "Sarah_Hair"
head.name = "Sarah_Head"

hip_x = .085
J = {"Hips": Vector((0, -.01, Z(.86))), "Spine": Vector((0, -.01, Z(1.02))), "Chest": Vector((0, -.02, Z(1.20))), "UpperChest": Vector((0, -.02, Z(1.32))),
     "Neck": Vector((0, -.02, Z(1.52))), "Head": Vector((0, -.01, Z(1.70)))}
for side, sx in (("Left", -1), ("Right", 1)):
    J[side + "Shoulder"] = Vector((sx * .035, -.02, Z(1.455)))
    J[side + "UpperArm"] = Vector((sx * Z(.275), -.01, Z(1.42)))
    J[side + "LowerArm"] = Vector((sx * Z(.335), .0, Z(1.24)))
    J[side + "Hand"] = Vector((sx * Z(.40), .005, Z(1.10)))
    J[side + "UpperLeg"] = Vector((sx * hip_x, 0, Z(.84)))
    J[side + "LowerLeg"] = Vector((sx * (hip_x + .01), -.005, Z(.50)))
    J[side + "Foot"] = Vector((sx * (hip_x + .02), 0, Z(.075)))
    J[side + "Toes"] = Vector((sx * (hip_x + .025), -.115, Z(.03)))
TIP_HAND = {s: J[s + "Hand"] + Vector((sx * Z(.035), 0, -Z(.12))) for s, sx in (("Left", -1), ("Right", 1))}
CH = {"Hips": "Spine", "Spine": "Chest", "Chest": "UpperChest", "UpperChest": "Neck", "Neck": "Head"}
PARENT = {"Spine": "Hips", "Chest": "Spine", "UpperChest": "Chest", "Neck": "UpperChest", "Head": "Neck"}
for side in ("Left", "Right"):
    PARENT.update({side + "Shoulder": "UpperChest", side + "UpperArm": side + "Shoulder", side + "LowerArm": side + "UpperArm", side + "Hand": side + "LowerArm",
                   side + "UpperLeg": "Hips", side + "LowerLeg": side + "UpperLeg", side + "Foot": side + "LowerLeg", side + "Toes": side + "Foot"})
    CH.update({side + "Shoulder": side + "UpperArm", side + "UpperArm": side + "LowerArm", side + "LowerArm": side + "Hand", side + "UpperLeg": side + "LowerLeg",
               side + "LowerLeg": side + "Foot", side + "Foot": side + "Toes"})
arm_d = bpy.data.armatures.new("Sarah_Rig")
rig = bpy.data.objects.new("Sarah_Rig", arm_d)
bpy.context.scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='EDIT')
for name, h in J.items():
    eb = arm_d.edit_bones.new(name)
    eb.head = h
    if name in CH:
        eb.tail = J[CH[name]]
    elif name.endswith("Hand"):
        eb.tail = TIP_HAND[name[:-4]]
    elif name == "Head":
        eb.tail = h + Vector((0, 0, Z(.2)))
    else:
        eb.tail = h + Vector((0, -.08, 0))
    if (eb.tail - eb.head).length < .02:
        eb.tail = eb.head + Vector((0, 0, .03))
for name, par in PARENT.items():
    arm_d.edit_bones[name].parent = arm_d.edit_bones[par]
bpy.ops.object.mode_set(mode='OBJECT')

SEG = {}
for name in J:
    a = J[name]
    b = J[CH[name]] if name in CH else (TIP_HAND[name[:-4]] if name.endswith("Hand") else (a + Vector((0, 0, Z(.2))) if name == "Head" else a + Vector((0, -.1, 0))))
    SEG[name] = (np.array(a[:]), np.array(b[:]))


def d2seg(P, a, b):
    ab = b - a
    t = np.clip(((P - a) @ ab) / max(ab @ ab, 1e-9), 0, 1)
    return np.linalg.norm(P - (a + t[:, None] * ab), axis=1)


def weight_mesh(ob, exponent=3.0):
    P = np.array([v.co[:] for v in ob.data.vertices])
    names = list(SEG)
    D = np.stack([d2seg(P, *SEG[n]) for n in names], axis=1)
    order = np.argsort(D, axis=1)[:, :3]
    W = np.zeros_like(D)
    for i in range(len(P)):
        ds = D[i, order[i]]
        w = 1.0 / (ds ** exponent + 1e-4)
        W[i, order[i]] = w / w.sum()
    W[W < .05] = 0
    W /= W.sum(axis=1, keepdims=True)
    for n in names:
        ob.vertex_groups.new(name=n)
    for j, n in enumerate(names):
        vg = ob.vertex_groups[n]
        for i in np.nonzero(W[:, j] > 0)[0]:
            vg.add([int(i)], float(W[i, j]), 'REPLACE')


weight_mesh(sbody, 3.0)
for ob in (head, shair):
    for n in J:
        ob.vertex_groups.new(name=n)
    ob.vertex_groups["Head"].add(list(range(len(ob.data.vertices))), 1.0, 'REPLACE')
for ob in (sbody, head, shair):
    ob.parent = rig
    md = ob.modifiers.new("Armature", 'ARMATURE')
    md.object = rig
print("SKELETON bones", len(arm_d.bones), "tris total", sum(tris(o) for o in (sbody, head, shair)))
bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(OUT_BLEND))
print("PHASE2 saved")
