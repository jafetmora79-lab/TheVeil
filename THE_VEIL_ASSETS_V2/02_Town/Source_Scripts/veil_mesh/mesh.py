"""Procedural low-poly mesh builder for THE VEIL town kit.

Conventions (shared with Pack 01):
  * Y-up, metres, -Z is "forward" (Godot convention).
  * Tiling materials get **meter-UVs** (1 UV unit = 1 m). Pack 01 materials
    already carry uv1_scale = 64 / texture_size, so density is 64 px/m.
  * glTF/Godot UV origin is top-left: on vertical faces v = -y so textures
    stand upright.
  * Every primitive takes an explicit outward normal and fixes its own
    winding, so faces are never inside-out.
"""
import math

import numpy as np


def nrm(v):
    v = np.asarray(v, float)
    l = np.linalg.norm(v)
    return v / l if l > 1e-12 else v


# ----------------------------------------------------------------------------
# Matrices
# ----------------------------------------------------------------------------
def T(x=0, y=0, z=0):
    m = np.eye(4)
    m[:3, 3] = (x, y, z)
    return m


def S(x=1, y=None, z=None):
    y = x if y is None else y
    z = x if z is None else z
    return np.diag([x, y, z, 1.0])


def Ry(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, 0, s, 0], [0, 1, 0, 0], [-s, 0, c, 0], [0, 0, 0, 1.0]])


def Rx(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[1, 0, 0, 0], [0, c, -s, 0], [0, s, c, 0], [0, 0, 0, 1.0]])


def Rz(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, -s, 0, 0], [s, c, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1.0]])


def chain(*ms):
    out = np.eye(4)
    for m in ms:
        out = out @ m
    return out


# ----------------------------------------------------------------------------
# UV projections
# ----------------------------------------------------------------------------
def uv_meter(p, n, off=(0.0, 0.0), scale=1.0):
    """Planar meter projection chosen by the dominant normal axis."""
    ax = int(np.argmax(np.abs(n)))
    if ax == 1:
        u, v = p[0], (p[2] if n[1] > 0 else -p[2])
    elif ax == 0:
        u, v = (-p[2] if n[0] > 0 else p[2]), -p[1]
    else:
        u, v = (p[0] if n[2] > 0 else -p[0]), -p[1]
    return (u * scale + off[0], v * scale + off[1])


def uv_rect_fn(bounds2d, rect, flip_u=False):
    """Map a face's local 2-D bounds onto an atlas rect (u0, v0, u1, v1)."""
    (x0, y0, x1, y1) = bounds2d
    u0, v0, u1, v1 = rect

    def f(q):
        tx = (q[0] - x0) / (x1 - x0 + 1e-12)
        ty = (q[1] - y0) / (y1 - y0 + 1e-12)
        if flip_u:
            tx = 1 - tx
        return (u0 + (u1 - u0) * tx, v1 - (v1 - v0) * ty)
    return f


# ----------------------------------------------------------------------------
# 2-D polygon triangulation (ear clipping)
# ----------------------------------------------------------------------------
def _area2(poly):
    a = 0.0
    for i in range(len(poly)):
        x0, y0 = poly[i]
        x1, y1 = poly[(i + 1) % len(poly)]
        a += x0 * y1 - x1 * y0
    return a / 2


def _pt_in_tri(p, a, b, c):
    def s(p1, p2, p3):
        return (p1[0] - p3[0]) * (p2[1] - p3[1]) - (p2[0] - p3[0]) * (p1[1] - p3[1])
    d1, d2, d3 = s(p, a, b), s(p, b, c), s(p, c, a)
    neg = (d1 < -1e-12) or (d2 < -1e-12) or (d3 < -1e-12)
    pos = (d1 > 1e-12) or (d2 > 1e-12) or (d3 > 1e-12)
    return not (neg and pos)


def triangulate(poly2d):
    """Ear-clip a simple polygon. Returns index triples (CCW)."""
    n = len(poly2d)
    idx = list(range(n))
    if _area2(poly2d) < 0:
        idx.reverse()
    out = []
    guard = 0
    while len(idx) > 3 and guard < 10000:
        guard += 1
        found = False
        for k in range(len(idx)):
            i0, i1, i2 = idx[k - 1], idx[k], idx[(k + 1) % len(idx)]
            a, b, c = poly2d[i0], poly2d[i1], poly2d[i2]
            cross = (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])
            if cross <= 1e-12:
                continue
            if any(_pt_in_tri(poly2d[j], a, b, c) for j in idx if j not in (i0, i1, i2)):
                continue
            out.append((i0, i1, i2))
            idx.pop(k)
            found = True
            break
        if not found:  # degenerate: fall back to a fan
            for k in range(1, len(idx) - 1):
                out.append((idx[0], idx[k], idx[k + 1]))
            return out
    if len(idx) == 3:
        out.append(tuple(idx))
    return out


# ----------------------------------------------------------------------------
# Mesh builder
# ----------------------------------------------------------------------------
class MB:
    def __init__(self):
        self.parts = {}

    def _g(self, mat):
        return self.parts.setdefault(mat, {"p": [], "n": [], "uv": [], "i": []})

    # -- raw -----------------------------------------------------------------
    def tri_raw(self, mat, pts, nrms, uvs):
        g = self._g(mat)
        base = len(g["p"])
        g["p"].extend([tuple(map(float, p)) for p in pts])
        g["n"].extend([tuple(map(float, nrm(n))) for n in nrms])
        g["uv"].extend([tuple(map(float, u)) for u in uvs])
        g["i"].extend([base, base + 1, base + 2])

    def tri_oriented(self, mat, pts, nrms, uvs):
        """Smooth-shaded triangle; winding fixed to agree with the vertex normals."""
        a, b, c = (np.asarray(x, float) for x in pts)
        fn = np.cross(b - a, c - a)
        if np.dot(fn, np.sum(np.asarray(nrms, float), axis=0)) < 0:
            pts = [pts[0], pts[2], pts[1]]
            nrms = [nrms[0], nrms[2], nrms[1]]
            uvs = [uvs[0], uvs[2], uvs[1]]
        self.tri_raw(mat, pts, nrms, uvs)

    def tri(self, mat, a, b, c, n=None, uv=None, uvoff=(0, 0), uvscale=1.0):
        a, b, c = (np.asarray(x, float) for x in (a, b, c))
        fn = np.cross(b - a, c - a)
        if np.linalg.norm(fn) < 1e-10:
            return
        if n is not None and np.dot(fn, n) < 0:
            b, c = c, b
            if uv is not None:
                uv = [uv[0], uv[2], uv[1]]
            fn = -fn
        nn = nrm(n if n is not None else fn)
        if uv is None:
            uv = [uv_meter(p, nn, uvoff, uvscale) for p in (a, b, c)]
        self.tri_raw(mat, [a, b, c], [nn] * 3, uv)

    def quad(self, mat, a, b, c, d, n=None, uv=None, uvoff=(0, 0), uvscale=1.0):
        a, b, c, d = (np.asarray(x, float) for x in (a, b, c, d))
        if n is None:
            n = nrm(np.cross(b - a, c - a) + np.cross(c - a, d - a))
        if uv is None:
            uv = [uv_meter(p, nrm(n), uvoff, uvscale) for p in (a, b, c, d)]
        self.tri(mat, a, b, c, n, [uv[0], uv[1], uv[2]])
        self.tri(mat, a, c, d, n, [uv[0], uv[2], uv[3]])

    def poly(self, mat, pts3, n, uvf=None, uvoff=(0, 0), uvscale=1.0):
        """Planar polygon (any simple outline). uvf(point3) -> (u, v)."""
        pts3 = [np.asarray(p, float) for p in pts3]
        n = nrm(n)
        ax = int(np.argmax(np.abs(n)))
        keep = [k for k in range(3) if k != ax]
        p2 = [(p[keep[0]], p[keep[1]]) for p in pts3]
        for (i, j, k) in triangulate(p2):
            tri_pts = [pts3[i], pts3[j], pts3[k]]
            uv = [uvf(p) for p in tri_pts] if uvf else None
            self.tri(mat, *tri_pts, n=n, uv=uv, uvoff=uvoff, uvscale=uvscale)

    def ground_poly(self, mat, pts2, y=0.0, heights=None, uvoff=(0, 0)):
        """Horizontal polygon given as (x, z) points; optional per-vertex y."""
        hs = heights if heights is not None else [y] * len(pts2)
        for (i, j, k) in triangulate(list(pts2)):
            tri_pts = [np.array([pts2[q][0], hs[q], pts2[q][1]]) for q in (i, j, k)]
            fn = np.cross(tri_pts[1] - tri_pts[0], tri_pts[2] - tri_pts[0])
            if fn[1] < 0:
                fn = -fn
            uv = [(p[0] + uvoff[0], p[2] + uvoff[1]) for p in tri_pts]
            self.tri(mat, *tri_pts, n=nrm(fn), uv=uv)

    # -- solids ----------------------------------------------------------------
    def box(self, mat, mn, mx, skip=("-y",), uvoff=(0, 0), uvscale=1.0, mats=None, uvrect=None):
        """Axis-aligned box. skip: faces to omit ('+x','-x','+y','-y','+z','-z').
        mats: optional per-face material override dict. uvrect: per-face atlas rects."""
        x0, y0, z0 = mn
        x1, y1, z1 = mx
        faces = {
            "+y": ([x0, y1, z0], [x0, y1, z1], [x1, y1, z1], [x1, y1, z0], (0, 1, 0)),
            "-y": ([x0, y0, z0], [x1, y0, z0], [x1, y0, z1], [x0, y0, z1], (0, -1, 0)),
            "+x": ([x1, y0, z1], [x1, y0, z0], [x1, y1, z0], [x1, y1, z1], (1, 0, 0)),
            "-x": ([x0, y0, z0], [x0, y0, z1], [x0, y1, z1], [x0, y1, z0], (-1, 0, 0)),
            "+z": ([x0, y0, z1], [x1, y0, z1], [x1, y1, z1], [x0, y1, z1], (0, 0, 1)),
            "-z": ([x1, y0, z0], [x0, y0, z0], [x0, y1, z0], [x1, y1, z0], (0, 0, -1)),
        }
        for key, (a, b, c, d, n) in faces.items():
            if key in skip:
                continue
            m = (mats or {}).get(key, mat)
            uv = None
            if uvrect and key in uvrect:
                u0, v0, u1, v1 = uvrect[key]
                uv = [(u0, v1), (u1, v1), (u1, v0), (u0, v0)]
            self.quad(m, a, b, c, d, n=n, uv=uv, uvoff=uvoff, uvscale=uvscale)

    def cyl(self, mat, base, r, h, seg=8, r_top=None, caps=("top",), smooth=True,
            cap_mat=None, uvoff=(0, 0), a0=0.0):
        """Vertical cylinder / frustum. caps: subset of ('top', 'bottom')."""
        bx, by, bz = base
        rt = r if r_top is None else r_top
        angs = [a0 + 2 * math.pi * k / seg for k in range(seg + 1)]
        slope = (r - rt) / h if h else 0
        for k in range(seg):
            a, b = angs[k], angs[k + 1]
            pa = [bx + r * math.cos(a), by, bz + r * math.sin(a)]
            pb = [bx + r * math.cos(b), by, bz + r * math.sin(b)]
            qa = [bx + rt * math.cos(a), by + h, bz + rt * math.sin(a)]
            qb = [bx + rt * math.cos(b), by + h, bz + rt * math.sin(b)]
            circ = 2 * math.pi * max(r, rt)
            ua, ub = a / (2 * math.pi) * circ + uvoff[0], b / (2 * math.pi) * circ + uvoff[0]
            uv = [(ua, -by + uvoff[1]), (ub, -by + uvoff[1]), (ub, -(by + h) + uvoff[1]), (ua, -(by + h) + uvoff[1])]
            if smooth:
                na = nrm([math.cos(a), slope, math.sin(a)])
                nb = nrm([math.cos(b), slope, math.sin(b)])
                self.tri_oriented(mat, [pa, qa, qb], [na, na, nb], [uv[0], uv[3], uv[2]])
                self.tri_oriented(mat, [pa, qb, pb], [na, nb, nb], [uv[0], uv[2], uv[1]])
            else:
                mid = (a + b) / 2
                self.quad(mat, pa, pb, qb, qa, n=[math.cos(mid), slope, math.sin(mid)], uv=uv)
        cm = cap_mat or mat
        if "top" in caps and rt > 0:
            pts = [[bx + rt * math.cos(a), by + h, bz + rt * math.sin(a)] for a in angs[:-1]]
            self.poly(cm, pts, (0, 1, 0), uvoff=uvoff)
        if "bottom" in caps and r > 0:
            pts = [[bx + r * math.cos(a), by, bz + r * math.sin(a)] for a in angs[:-1]]
            self.poly(cm, pts, (0, -1, 0), uvoff=uvoff)

    def tube(self, mat, pts, r, sides=4, caps=False):
        """Sweep a small polygonal tube along a polyline (wires, pipes, rails)."""
        pts = [np.asarray(p, float) for p in pts]
        rings = []
        dist = [0.0]
        for i in range(1, len(pts)):
            dist.append(dist[-1] + np.linalg.norm(pts[i] - pts[i - 1]))
        for i, p in enumerate(pts):
            if i == 0:
                t = pts[1] - pts[0]
            elif i == len(pts) - 1:
                t = pts[-1] - pts[-2]
            else:
                t = pts[i + 1] - pts[i - 1]
            t = nrm(t)
            up = np.array([0, 1, 0]) if abs(t[1]) < 0.9 else np.array([1, 0, 0])
            s = nrm(np.cross(t, up))
            u = nrm(np.cross(s, t))
            ring = []
            for k in range(sides):
                a = 2 * math.pi * k / sides + math.pi / sides
                d = s * math.cos(a) + u * math.sin(a)
                ring.append((p + d * r, d))
            rings.append(ring)
        circ = 2 * math.pi * r
        for i in range(len(pts) - 1):
            for k in range(sides):
                k2 = (k + 1) % sides
                (p0, n0), (p1, n1) = rings[i][k], rings[i][k2]
                (q0, m0), (q1, m1) = rings[i + 1][k], rings[i + 1][k2]
                ua, ub = circ * k / sides, circ * (k + 1) / sides
                va, vb = -dist[i], -dist[i + 1]
                self.tri_oriented(mat, [p0, p1, q1], [n0, n1, m1], [(ua, va), (ub, va), (ub, vb)])
                self.tri_oriented(mat, [p0, q1, q0], [n0, m1, m0], [(ua, va), (ub, vb), (ua, vb)])
        if caps:
            for i, sgn in ((0, -1), (len(pts) - 1, 1)):
                t = nrm(pts[1] - pts[0]) if i == 0 else nrm(pts[-1] - pts[-2])
                self.poly(mat, [rp for rp, _ in rings[i]], t * sgn)

    def lump(self, mat, center, radii, rng, subdiv=1, jitter=0.18, flat=True, squash_bottom=True,
             uvoff=(0, 0)):
        """Jittered low-poly icosphere: canopies, bushes, rocks, mounds."""
        verts, faces = icosphere(subdiv)
        cache = {}
        out = []
        for i, v in enumerate(verts):
            j = 1.0 + rng.uniform(-jitter, jitter)
            p = np.array(v) * j * np.asarray(radii)
            if squash_bottom and p[1] < -radii[1] * 0.35:
                p[1] = -radii[1] * 0.35 + (p[1] + radii[1] * 0.35) * 0.25
            out.append(p + np.asarray(center))
        for (a, b, c) in faces:
            pa, pb, pc = out[a], out[b], out[c]
            n = np.cross(pb - pa, pc - pa)
            outward = (pa + pb + pc) / 3 - np.asarray(center)
            if np.dot(n, outward) < 0:
                pb, pc = pc, pb
                n = -n
            if flat:
                self.tri(mat, pa, pb, pc, n=nrm(n), uvoff=uvoff)
            else:
                ns = [nrm(p - np.asarray(center)) for p in (pa, pb, pc)]
                uv = [uv_meter(p, nrm(n), uvoff) for p in (pa, pb, pc)]
                self.tri_oriented(mat, [pa, pb, pc], ns, uv)

    def prism(self, mat, pts2, z0, z1, cap_mat=None, front_uvf=None, back_uvf=None, side_mat=None):
        """Extrude an XY outline between z0 (back) and z1 (front)."""
        cm = cap_mat or mat
        sm = side_mat or mat
        front = [[x, y, z1] for x, y in pts2]
        back = [[x, y, z0] for x, y in pts2]
        self.poly(cm, front, (0, 0, 1), uvf=front_uvf)
        self.poly(sm if back_uvf is None else cm, back, (0, 0, -1), uvf=back_uvf)
        n = len(pts2)
        ccw = _area2(pts2) > 0
        for i in range(n):
            a, b = pts2[i], pts2[(i + 1) % n]
            ex, ey = b[0] - a[0], b[1] - a[1]
            nn = (ey, -ex, 0) if ccw else (-ey, ex, 0)
            self.quad(sm, [a[0], a[1], z0], [b[0], b[1], z0], [b[0], b[1], z1], [a[0], a[1], z1], n=nn)

    # -- composition -------------------------------------------------------------
    def merge(self, other, M=None):
        M = np.eye(4) if M is None else M
        R = M[:3, :3]
        nmat = np.linalg.inv(R).T
        flip = np.linalg.det(R) < 0
        for mat, g in other.parts.items():
            d = self._g(mat)
            base = len(d["p"])
            P_ = np.asarray(g["p"]).reshape(-1, 3)
            N_ = np.asarray(g["n"]).reshape(-1, 3)
            Pw = (np.c_[P_, np.ones(len(P_))] @ M.T)[:, :3]
            Nw = N_ @ nmat.T
            Nw /= np.linalg.norm(Nw, axis=1, keepdims=True) + 1e-12
            d["p"].extend(map(tuple, Pw))
            d["n"].extend(map(tuple, Nw))
            d["uv"].extend(g["uv"])
            idx = list(g["i"])
            if flip:
                for t in range(0, len(idx), 3):
                    idx[t + 1], idx[t + 2] = idx[t + 2], idx[t + 1]
            d["i"].extend(i + base for i in idx)
        return self

    def tri_count(self):
        return sum(len(g["i"]) // 3 for g in self.parts.values())

    def bounds(self):
        allp = [p for g in self.parts.values() for p in g["p"]]
        if not allp:
            return np.zeros(3), np.zeros(3)
        a = np.asarray(allp)
        return a.min(0), a.max(0)


def icosphere(subdiv=1):
    t = (1 + 5 ** 0.5) / 2
    v = [(-1, t, 0), (1, t, 0), (-1, -t, 0), (1, -t, 0), (0, -1, t), (0, 1, t), (0, -1, -t), (0, 1, -t),
         (t, 0, -1), (t, 0, 1), (-t, 0, -1), (-t, 0, 1)]
    v = [tuple(nrm(p)) for p in v]
    f = [(0, 11, 5), (0, 5, 1), (0, 1, 7), (0, 7, 10), (0, 10, 11), (1, 5, 9), (5, 11, 4), (11, 10, 2),
         (10, 7, 6), (7, 1, 8), (3, 9, 4), (3, 4, 2), (3, 2, 6), (3, 6, 8), (3, 8, 9), (4, 9, 5), (2, 4, 11),
         (6, 2, 10), (8, 6, 7), (9, 8, 1)]
    for _ in range(subdiv):
        cache = {}

        def mid(a, b):
            key = (min(a, b), max(a, b))
            if key not in cache:
                cache[key] = len(v)
                v.append(tuple(nrm((np.array(v[a]) + np.array(v[b])) / 2)))
            return cache[key]
        nf = []
        for (a, b, c) in f:
            ab, bc, ca = mid(a, b), mid(b, c), mid(c, a)
            nf += [(a, ab, ca), (b, bc, ab), (c, ca, bc), (ab, bc, ca)]
        f = nf
    return v, f
