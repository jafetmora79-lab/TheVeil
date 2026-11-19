"""Sarah head v8 (geometry only, grey review): a NEW construction, not a reshaped V7.
The head is lofted ring by ring (non-uniform rings and a front-weighted segment spread, so the face gets more polygons than the back of the skull)
from real female proportions: eyes at the head midline, brow and nose base at the facial thirds, mouth a third of the way down from nose to chin.
The face is then modelled with anatomical landmarks (eye sockets, brow, nose bridge / tip / alae / nostrils, lips, chin, cheeks, temples).
Ears are separate anatomical patches (helix, antihelix, concha) sitting on the skull. The neck continues from the jaw into the torso.
   blender -b -P build_sarah_head_v8.py -- <out.blend>"""
import bpy, bmesh, sys, os, math
import numpy as np
from mathutils import Vector

OUT = os.path.abspath(sys.argv[sys.argv.index("--") + 1])
bpy.ops.wm.read_factory_settings(use_empty=True)

# ---- profiles: z, half width, front depth, back depth  (head 0.222 m: crown 1.66, chin ~1.44)
P = np.array([
    # z      hw    front  back
    [1.660, .000, .000, .000],
    [1.652, .036, .034, .042],
    [1.640, .054, .056, .066],
    [1.622, .067, .076, .083],
    [1.602, .0735, .088, .090],
    [1.584, .0765, .092, .093],
    [1.568, .0775, .093, .094],
    [1.546, .0765, .092, .093],
    [1.526, .0745, .090, .091],
    [1.508, .0715, .087, .088],
    [1.492, .0675, .084, .083],
    [1.476, .0615, .081, .077],
    [1.460, .0545, .078, .070],
    [1.446, .0460, .074, .062],
    [1.432, .0420, .060, .056],
    [1.418, .0410, .048, .054],
    [1.402, .0420, .041, .052],
    [1.385, .0450, .043, .055],
    [1.368, .0490, .047, .058],
])
ZR = P[:, 0]
ANG = [0, 8, 16, 25, 35, 46, 58, 72, 88, 105, 125, 150, 180]            # degrees from the front, mirrored left/right
NSEG = len(ANG) * 2 - 2


def prof(z):
    return [float(np.interp(z, ZR[::-1], P[::-1, i])) for i in (1, 2, 3)]


def exponent(z):
    return 2.0 + .55 * max(0.0, min(1.0, (z - 1.43) / .12))                 # rounder at the neck, squarer skull


def ring_point(z, a_deg):
    hw, f, b = prof(z)
    n = exponent(z)
    t = math.radians(a_deg)
    s, c = math.sin(t), math.cos(t)
    d = f if c >= 0 else b
    if hw < 1e-6:
        return Vector((0, 0, z))
    r = 1.0 / ((abs(s) / hw) ** n + (abs(c) / d) ** n) ** (1.0 / n)
    return Vector((r * s, -r * c, z))


def gauss(x, c, s):
    return math.exp(-((x - c) / s) ** 2)


def nose_profile(z):
    zs = [1.560, 1.546, 1.534, 1.522, 1.512, 1.503, 1.496, 1.490]
    ps = [0.0, .0050, .0105, .0165, .0225, .0165, .0055, 0.0]
    return float(np.interp(z, zs[::-1], ps[::-1]))


def nose_width(z):
    zs = [1.560, 1.546, 1.534, 1.522, 1.512, 1.503, 1.496]
    ws = [.0085, .0075, .0075, .0095, .0145, .0200, .0200]
    return float(np.interp(z, zs[::-1], ws[::-1]))


def face_disp(x, z):
    """outward (toward the viewer, i.e. -y) displacement of the face surface at (x, z)"""
    ax = abs(x)
    d = 0.0
    d += .0045 * gauss(ax, 0, .040) * gauss(z, 1.567, .0070)                 # soft brow ridge
    d -= .0062 * gauss(ax, .0315, .0150) * gauss(z, 1.547, .0085)           # eye sockets (shallow, painted over)
    d -= .0016 * gauss(ax, .0315, .0180) * gauss(z, 1.560, .0060)           # upper lid fold
    d -= .0022 * gauss(ax, .074, .012) * gauss(z, 1.572, .016)              # temples
    d += .0042 * gauss(ax, .050, .016) * gauss(z, 1.505, .014)              # cheeks
    d += .0016 * gauss(ax, .064, .012) * gauss(z, 1.527, .008)              # cheekbone, kept subtle
    # nose: bridge, tip and wings
    npz = nose_profile(z)
    if npz > 0:
        d += npz * math.exp(-(ax / nose_width(z)) ** 2.2)
    d += .0075 * gauss(ax, .0165, .0055) * gauss(z, 1.506, .0050)           # alae
    d -= .0028 * gauss(ax, .0085, .0045) * gauss(z, 1.500, .0035)           # nostrils
    d -= .0012 * gauss(ax, .020, .008) * gauss(z, 1.513, .006)               # nasolabial fold hint
    # mouth
    d += .0062 * gauss(ax, 0, .0170) * gauss(z, 1.4855, .0042)              # upper lip
    d += .0058 * gauss(ax, 0, .0180) * gauss(z, 1.4685, .0048)              # lower lip
    d -= .0030 * gauss(ax, 0, .0200) * gauss(z, 1.4765, .0020)              # mouth line
    d -= .0018 * gauss(ax, 0, .0170) * gauss(z, 1.4560, .0035)              # mentolabial groove
    d += .0070 * gauss(ax, 0, .0180) * gauss(z, 1.4455, .0075)              # chin
    d -= .0010 * gauss(ax, 0, .0060) * gauss(z, 1.497, .0040)               # philtrum
    return d


def build_head():
    bm = bmesh.new()
    rings = []
    for zi, z in enumerate(ZR):
        row = []
        angs = [-a for a in ANG[:0:-1]] + ANG[:-1] if False else None
        pts = []
        full = ANG + [-a for a in ANG[-2:0:-1]]                                # 0..180 then back through -150..-8
        for a_deg in full:
            p = ring_point(z, a_deg if a_deg >= 0 else a_deg)
            if a_deg < 0:
                p = ring_point(z, -a_deg)
                p.x = -p.x
            pts.append(p)
        rings.append(pts)
    verts = []
    for zi, pts in enumerate(rings):
        row = []
        for ai, p in enumerate(pts):
            q = p.copy()
            if q.y < -.01 and abs(math.degrees(math.atan2(abs(q.x), -q.y))) < 75:
                w = 1.0
                ang = math.degrees(math.atan2(abs(q.x), -q.y))
                w = 1.0 if ang < 48 else max(0.0, 1.0 - (ang - 48) / 27.0)
                q.y -= face_disp(q.x, q.z) * w
            row.append(bm.verts.new(q))
        verts.append(row)
    n = len(verts[0])
    for zi in range(len(verts) - 1):
        for ai in range(n):
            a2 = (ai + 1) % n
            if zi == 0:
                bm.faces.new((verts[0][0], verts[1][a2], verts[1][ai]))
            else:
                bm.faces.new((verts[zi][ai], verts[zi][a2], verts[zi + 1][a2], verts[zi + 1][ai]))
    return bm


def surface_x(y, z):
    hw, f, b = prof(z)
    d = f if y < 0 else b
    n = exponent(z)
    t = min(abs(y) / d, .999)
    return hw * (1 - t ** n) ** (1.0 / n)


def add_ear(bm, sx):
    cy, cz = .013, 1.548
    ry, rz = .0165, .0335
    tilt = math.radians(16)                                                   # top of the ear leans back
    segs = 14
    prof_x = [(0.00, .0035), (.28, .0055), (.55, .0150), (.80, .0105), (1.00, .0010)]   # concha, antihelix, helix rim, edge
    rings = []
    for rr, off in prof_x:
        row = []
        for k in range(segs if rr > 0 else 1):
            t = 2 * math.pi * k / segs
            ly, lz = math.cos(t) * ry * rr, math.sin(t) * rz * rr
            y = cy + ly * math.cos(tilt) + lz * math.sin(tilt) * -1 * -1
            z = cz + lz * math.cos(tilt) - ly * math.sin(tilt) * -1 * -1 * 0
            y = cy + ly * math.cos(tilt) + (lz * math.sin(tilt))
            z = cz + lz * math.cos(tilt) - (ly * math.sin(tilt))
            # lobe is fuller at the bottom, helix narrower at the top
            extra = .003 if (lz < -.012 and rr > .5) else 0.0
            x0 = surface_x(y, z)
            x = sx * (x0 + off + extra * (1 - abs(rr - .75)))
            row.append(bm.verts.new((x, y, z)))
        rings.append(row)
    c = rings[0][0]
    for k in range(segs):
        f = (c, rings[1][k], rings[1][(k + 1) % segs]) if sx > 0 else (c, rings[1][(k + 1) % segs], rings[1][k])
        bm.faces.new(f)
    for r in range(1, len(rings) - 1):
        for k in range(segs):
            k2 = (k + 1) % segs
            q = (rings[r][k], rings[r][k2], rings[r + 1][k2], rings[r + 1][k]) if sx > 0 else (rings[r][k2], rings[r][k], rings[r + 1][k], rings[r + 1][k2])
            bm.faces.new(q)


bm = build_head()
for sx in (-1, 1):
    add_ear(bm, sx)
bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
me = bpy.data.meshes.new("Sarah_Head_v8")
bm.to_mesh(me)
bm.free()
head = bpy.data.objects.new("Sarah_Head_v8", me)
bpy.context.scene.collection.objects.link(head)
for p in me.polygons:
    p.use_smooth = False
tris = sum(len(p.vertices) - 2 for p in me.polygons)
print("HEAD tris", tris, "verts", len(me.vertices))
V = np.array([v.co[:] for v in me.vertices])
print("HEAD bbox", V.min(0).round(3), V.max(0).round(3))
bpy.ops.wm.save_as_mainfile(filepath=OUT)
