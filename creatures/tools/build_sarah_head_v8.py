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
    [1.652, .044, .040, .048],
    [1.640, .060, .060, .068],
    [1.622, .071, .078, .084],
    [1.602, .0775, .089, .090],
    [1.584, .0805, .093, .093],
    [1.568, .0815, .094, .094],
    [1.546, .0805, .093, .093],
    [1.526, .0825, .091, .091],
    [1.508, .0805, .089, .088],
    [1.492, .0775, .086, .083],
    [1.476, .0725, .083, .077],
    [1.460, .0665, .080, .070],
    [1.446, .0585, .077, .064],
    [1.432, .0525, .071, .059],
    [1.418, .0480, .060, .056],
    [1.402, .0455, .050, .054],
    [1.385, .0455, .045, .056],
    [1.368, .0490, .047, .058],
    [1.345, .0505, .049, .060],
    [1.318, .0530, .053, .064],
])
_extra = [1.557, 1.538, 1.484]
_rows = [[z] + [float(np.interp(z, P[::-1, 0], P[::-1, i])) for i in (1, 2, 3)] for z in _extra]
P = np.array(sorted([list(r) for r in P] + _rows, key=lambda r: -r[0]))
ZR = P[:, 0]
# lower-face compression (old z -> new z): the distance nose -> mouth -> chin gets visibly shorter, the eyes, skull and neck stay put
ZOLD = [1.300, 1.368, 1.385, 1.402, 1.418, 1.432, 1.446, 1.460, 1.476, 1.492, 1.508, 1.526, 1.546, 1.560, 1.700]
ZNEW = [1.300, 1.368, 1.385, 1.405, 1.428, 1.445, 1.458, 1.471, 1.485, 1.4975, 1.5105, 1.5265, 1.546, 1.560, 1.700]
ANG = [0, 6, 12, 18, 24, 30, 37, 45, 54, 66, 80, 96, 115, 140, 180]            # degrees from the front, mirrored left/right
NSEG = len(ANG) * 2 - 2


def prof(z):
    return [float(np.interp(z, ZR[::-1], P[::-1, i])) for i in (1, 2, 3)]


def exponent(z):
    return 2.0 + .75 * max(0.0, min(1.0, (z - 1.43) / .12))                 # rounder at the neck, squarer skull


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
    zs = [1.566, 1.552, 1.538, 1.526, 1.517, 1.510, 1.503, 1.497, 1.490]
    ps = [0.0, .0050, .0105, .0175, .0245, .0250, .0150, .0050, 0.0]
    return float(np.interp(z, zs[::-1], ps[::-1]))


def nose_width(z):
    zs = [1.566, 1.552, 1.538, 1.526, 1.517, 1.510, 1.503, 1.497]
    ws = [.0090, .0082, .0082, .0090, .0112, .0140, .0175, .0185]
    return float(np.interp(z, zs[::-1], ws[::-1]))


def face_disp(x, z):
    """outward (toward the viewer, i.e. -y) displacement of the face surface at (x, z)"""
    ax = abs(x)
    d = 0.0
    c8, s8 = math.cos(math.radians(9)), math.sin(math.radians(9))
    ex, ez = (ax - .0325) * c8 + (z - 1.5485) * s8, -(ax - .0325) * s8 + (z - 1.5485) * c8      # almond socket, outer corner slightly raised
    d -= .0046 * math.exp(-(ex / .0155) ** 2 - (ez / .0078) ** 2)
    bx, bz = (ax - .033) * c8 + (z - 1.5655) * s8, -(ax - .033) * s8 + (z - 1.5655) * c8
    d += .0038 * math.exp(-(bx / .030) ** 2 - (bz / .0062) ** 2)                            # arched brow ridge
    d += .0018 * math.exp(-((ax - .034) / .020) ** 2 - ((z - 1.5345) / .0050) ** 2)          # lower orbital rim
    d -= .0012 * gauss(ax, .0325, .017) * gauss(z, 1.5595, .0045)                            # lid fold
    d -= .0022 * gauss(ax, .074, .012) * gauss(z, 1.572, .016)              # temples
    d += .0042 * gauss(ax, .050, .016) * gauss(z, 1.505, .014)              # cheeks
    d += .0016 * gauss(ax, .064, .012) * gauss(z, 1.527, .008)              # cheekbone, kept subtle
    # nose: bridge, tip and wings
    npz = nose_profile(z)
    if npz > 0:
        d += npz * math.exp(-(ax / nose_width(z)) ** 2.4)
    d += .0075 * gauss(ax, .0185, .0060) * gauss(z, 1.5075, .0050)           # alae
    d -= .0042 * gauss(ax, .0105, .0040) * gauss(z, 1.5015, .0032)           # nostrils
    d += .0030 * gauss(ax, 0, .0075) * gauss(z, 1.511, .0050)               # rounded tip
    d -= .0012 * gauss(ax, .020, .008) * gauss(z, 1.513, .006)               # nasolabial fold hint
    # mouth
    d += .0062 * gauss(ax, 0, .0170) * gauss(z, 1.4855, .0042)              # upper lip
    d += .0058 * gauss(ax, 0, .0180) * gauss(z, 1.4685, .0048)              # lower lip
    d -= .0030 * gauss(ax, 0, .0200) * gauss(z, 1.4765, .0020)              # mouth line
    d -= .0018 * gauss(ax, 0, .0170) * gauss(z, 1.4560, .0035)              # mentolabial groove
    d += .0060 * gauss(ax, 0, .0300) * gauss(z, 1.4445, .0090)              # chin
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
            q.z = float(np.interp(q.z, ZOLD, ZNEW))
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
    cy, cz = .019, 1.5525
    rot = math.radians(-8)                                                    # slight backward lean
    outline = [(-.003, .029), (.006, .033), (.014, .029), (.018, .016), (.018, .002), (.015, -.012), (.009, -.024), (.002, -.029), (-.004, -.022), (-.005, -.008), (-.007, .006), (-.006, .020)]
    cen = (.006, .001)
    scales = [(1.00, .0008), (.86, .0085), (.64, .0038), (.43, .0072), (.22, .0016)]
    rings = []
    for sc_, off in scales:
        row = []
        for (oy, oz) in outline:
            ly, lz = cen[0] + (oy - cen[0]) * sc_, cen[1] + (oz - cen[1]) * sc_
            y = cy + ly * math.cos(rot) - lz * math.sin(rot)
            z = cz + lz * math.cos(rot) + ly * math.sin(rot)
            x = sx * (surface_x(y, z) + off - .0012)
            row.append(bm.verts.new((x, y, z)))
        rings.append(row)
    nO = len(outline)
    cvert = bm.verts.new((sx * (surface_x(cy + cen[0], cz + cen[1]) + .0010), cy + cen[0], cz + cen[1]))
    for k in range(nO):
        k2 = (k + 1) % nO
        tri = (cvert, rings[-1][k], rings[-1][k2]) if sx > 0 else (cvert, rings[-1][k2], rings[-1][k])
        bm.faces.new(tri)
    for r in range(len(rings) - 1):
        for k in range(nO):
            k2 = (k + 1) % nO
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
