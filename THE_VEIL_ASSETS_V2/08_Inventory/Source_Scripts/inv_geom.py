"""Small-object geometry helpers for Pack 08 (on top of the Pack 02 veil_mesh MB container).

Every surface maps into a rect of the shared atlas (inv_atlas.R(name)), so an item is ONE material / draw call.
Shapes: oriented boxes, smooth lathes/cylinders (bottles, handles, grips), outline extrusions (keys, blades,
wrench heads, cards), hollow rings (tape, key rings), swept tubes (rope, handles, wire), decal quads.
Convention: metres, +Y up, item rests on y = 0, long / working axis along -Z (Godot forward).
"""
import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
V2 = os.path.normpath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(V2, "02_Town", "Source_Scripts"))
from veil_mesh.mesh import MB, triangulate  # noqa: E402
from veil_mesh.gltf import COL_KEY  # noqa: E402

from inv_atlas import R  # noqa: E402

MAT = "M_Inv_Atlas"


def nrm(v):
    v = np.asarray(v, float)
    n = np.linalg.norm(v)
    return v / n if n > 1e-12 else v


def basis(axis, up=(0, 1, 0)):
    """(a, b, d): d along axis, a/b perpendicular"""
    d = nrm(axis)
    u = np.asarray(up, float)
    if abs(np.dot(u, d)) > 0.95:
        u = np.array([1.0, 0, 0]) if abs(d[0]) < 0.9 else np.array([0, 0, 1.0])
    a = nrm(np.cross(u, d))
    b = np.cross(d, a)
    return a, b, d


def rot(yaw=0.0, pitch=0.0, roll=0.0):
    a, b, c = (math.radians(x) for x in (yaw, pitch, roll))
    Ry = np.array([[math.cos(a), 0, math.sin(a)], [0, 1, 0], [-math.sin(a), 0, math.cos(a)]])
    Rx = np.array([[1, 0, 0], [0, math.cos(b), -math.sin(b)], [0, math.sin(b), math.cos(b)]])
    Rz = np.array([[math.cos(c), -math.sin(c), 0], [math.sin(c), math.cos(c), 0], [0, 0, 1]])
    return Ry @ Rx @ Rz


class G:
    def __init__(self):
        self.mb = MB()
        self.g = self.mb._g(MAT)

    def _v(self, p, n, uv):
        g = self.g
        g["p"].append([float(x) for x in p])
        g["n"].append([float(x) for x in nrm(n)])
        g["uv"].append([float(uv[0]), float(uv[1])])
        return len(g["p"]) - 1

    def tri(self, ps, ns, uvs):
        n_face = np.cross(np.asarray(ps[1]) - ps[0], np.asarray(ps[2]) - ps[0])
        if np.linalg.norm(n_face) < 1e-14:
            return
        ids = [self._v(p, n, uv) for p, n, uv in zip(ps, ns, uvs)]
        if np.dot(n_face, np.sum([nrm(n) for n in ns], axis=0)) < 0:
            ids = [ids[0], ids[2], ids[1]]
        self.g["i"] += ids

    def quad(self, ps, rect, n=None, uvs=None):
        ps = [np.asarray(p, float) for p in ps]
        if n is None:
            n = nrm(np.cross(ps[1] - ps[0], ps[2] - ps[0]))
        u0, v0, u1, v1 = rect
        uv = uvs or [(u0, v1), (u1, v1), (u1, v0), (u0, v0)]
        self.tri([ps[0], ps[1], ps[2]], [n] * 3, [uv[0], uv[1], uv[2]])
        self.tri([ps[0], ps[2], ps[3]], [n] * 3, [uv[0], uv[2], uv[3]])

    # ------------------------------------------------------------ solids
    def box(self, c, size, rect, Rm=None, faces=None, skip=(), taper=(1.0, 1.0)):
        """oriented box; rect = default atlas rect name/uv; faces = {'+z': rectname, ...}"""
        Rm = np.eye(3) if Rm is None else np.asarray(Rm, float)
        c = np.asarray(c, float)
        hx, hy, hz = (s / 2 for s in size)
        tx, tz = taper

        def P(x, y, z):
            s = (tx, tz) if y > 0 else (1.0, 1.0)
            return c + Rm @ np.array([x * hx * s[0], y * hy, z * hz * s[1]])
        F = {"+z": [P(-1, -1, 1), P(1, -1, 1), P(1, 1, 1), P(-1, 1, 1)], "-z": [P(1, -1, -1), P(-1, -1, -1), P(-1, 1, -1), P(1, 1, -1)],
             "+x": [P(1, -1, 1), P(1, -1, -1), P(1, 1, -1), P(1, 1, 1)], "-x": [P(-1, -1, -1), P(-1, -1, 1), P(-1, 1, 1), P(-1, 1, -1)],
             "+y": [P(-1, 1, 1), P(1, 1, 1), P(1, 1, -1), P(-1, 1, -1)], "-y": [P(-1, -1, -1), P(1, -1, -1), P(1, -1, 1), P(-1, -1, 1)]}
        for k, ps in F.items():
            if k in skip:
                continue
            r = (faces or {}).get(k, rect)
            self.quad(ps, R(r) if isinstance(r, str) else r)

    def lathe(self, p0, axis, prof, rect, seg=10, smooth=True, caps=(True, True), cap_rect=None, phase=0.0, squash=1.0, rects=None):
        """surface of revolution: prof = [(t along axis in m, radius)], rect per band via rects (list) or one rect"""
        a, b, d = basis(axis)
        p0 = np.asarray(p0, float)
        rings, nrms = [], []
        for k, (t, r) in enumerate(prof):
            ring = []
            for j in range(seg + 1):
                th = phase + 2 * math.pi * j / seg
                ring.append(p0 + d * t + (a * math.cos(th) + b * math.sin(th) * squash) * r)
            rings.append(ring)
        for k in range(len(prof) - 1):
            rr = R(rects[k] if rects else rect)
            u0, v0, u1, v1 = rr
            (t0, r0), (t1, r1) = prof[k], prof[k + 1]
            slope = (r0 - r1) / max(abs(t1 - t0), 1e-9) * (1 if t1 > t0 else -1)
            for j in range(seg):
                th0, th1 = phase + 2 * math.pi * j / seg, phase + 2 * math.pi * (j + 1) / seg
                def N(th):
                    radial = a * math.cos(th) + b * math.sin(th) * squash
                    return nrm(radial + d * slope)
                ps = [rings[k][j], rings[k][j + 1], rings[k + 1][j + 1], rings[k + 1][j]]
                uv = [(u0 + (u1 - u0) * j / seg, v1), (u0 + (u1 - u0) * (j + 1) / seg, v1), (u0 + (u1 - u0) * (j + 1) / seg, v0),
                      (u0 + (u1 - u0) * j / seg, v0)]
                if smooth:
                    ns = [N(th0), N(th1), N(th1), N(th0)]
                else:
                    fnm = (N(th0) + N(th1))
                    ns = [fnm] * 4
                # outward winding for a profile running +t
                if t1 > t0:
                    self.tri([ps[0], ps[3], ps[2]], [ns[0], ns[3], ns[2]], [uv[0], uv[3], uv[2]])
                    self.tri([ps[0], ps[2], ps[1]], [ns[0], ns[2], ns[1]], [uv[0], uv[2], uv[1]])
                else:
                    self.tri([ps[0], ps[1], ps[2]], [ns[0], ns[1], ns[2]], [uv[0], uv[1], uv[2]])
                    self.tri([ps[0], ps[2], ps[3]], [ns[0], ns[2], ns[3]], [uv[0], uv[2], uv[3]])
        cr = R(cap_rect or rect)
        cu, cv = (cr[0] + cr[2]) / 2, (cr[1] + cr[3]) / 2
        hu, hv = (cr[2] - cr[0]) / 2, (cr[3] - cr[1]) / 2
        for which, (k, sgn) in zip(caps, ((0, -1), (len(prof) - 1, 1))):
            if not which or prof[k][1] <= 1e-6:
                continue
            t, r = prof[k]
            c = p0 + d * t
            n = d * sgn * (1 if prof[-1][0] > prof[0][0] else -1)
            for j in range(seg):
                th0, th1 = phase + 2 * math.pi * j / seg, phase + 2 * math.pi * (j + 1) / seg
                q0, q1 = rings[k][j], rings[k][j + 1]
                self.tri([c, q0, q1], [n] * 3, [(cu, cv), (cu + hu * math.cos(th0), cv + hv * math.sin(th0)), (cu + hu * math.cos(th1), cv + hv * math.sin(th1))])

    def cyl(self, p0, p1, r0, r1, rect, seg=10, caps=(True, True), cap_rect=None, smooth=True, squash=1.0, phase=0.0):
        p0, p1 = np.asarray(p0, float), np.asarray(p1, float)
        L = np.linalg.norm(p1 - p0)
        self.lathe(p0, p1 - p0, [(0.0, r0), (L, r1)], rect, seg=seg, caps=caps, cap_rect=cap_rect, smooth=smooth, squash=squash, phase=phase)

    def extrude(self, outline, z0, z1, origin, Rm, face_rect, side_rect, back_rect=None):
        """extrude a CCW (x, y) outline between local z0 and z1; Rm columns = local x, y, z in world"""
        o = np.asarray(origin, float)
        Rm = np.asarray(Rm, float)
        pts = [np.array([x, y]) for x, y in outline]
        xs, ys = [p[0] for p in pts], [p[1] for p in pts]
        bx0, bx1, by0, by1 = min(xs), max(xs), min(ys), max(ys)
        W = lambda x, y, z: o + Rm @ np.array([x, y, z])
        for zf, rect_name, sgn in ((z1, face_rect, 1), (z0, back_rect or face_rect, -1)):
            u0, v0, u1, v1 = R(rect_name)
            n = Rm @ np.array([0, 0, sgn])
            for (i, j, k) in triangulate([tuple(p) for p in pts]):
                tri = [pts[i], pts[j], pts[k]]
                if sgn < 0:
                    tri = tri[::-1]
                ps = [W(p[0], p[1], zf) for p in tri]
                uvs = [(u0 + (u1 - u0) * ((p[0] - bx0) / max(bx1 - bx0, 1e-9) if sgn > 0 else (bx1 - p[0]) / max(bx1 - bx0, 1e-9)),
                        v1 - (v1 - v0) * (p[1] - by0) / max(by1 - by0, 1e-9)) for p in tri]
                self.tri(ps, [n] * 3, uvs)
        sr = R(side_rect)
        m = len(pts)
        per = sum(np.linalg.norm(pts[(i + 1) % m] - pts[i]) for i in range(m))
        acc = 0.0
        for i in range(m):
            a, b = pts[i], pts[(i + 1) % m]
            e = b - a
            ln = np.linalg.norm(e)
            n2 = np.array([e[1], -e[0]]) / max(ln, 1e-12)
            n = Rm @ np.array([n2[0], n2[1], 0])
            uA, uB = sr[0] + (sr[2] - sr[0]) * acc / per, sr[0] + (sr[2] - sr[0]) * (acc + ln) / per
            acc += ln
            self.quad([W(a[0], a[1], z0), W(b[0], b[1], z0), W(b[0], b[1], z1), W(a[0], a[1], z1)], sr, n=n,
                      uvs=[(uA, sr[3]), (uB, sr[3]), (uB, sr[1]), (uA, sr[1])])

    def ring(self, c, axis, r_in, r_out, h, rect_side, rect_top=None, seg=14, inner_rect=None):
        """hollow cylinder (tape roll, key ring flat, battery contacts...)"""
        a, b, d = basis(axis)
        c = np.asarray(c, float)
        self.lathe(c, d, [(0.0, r_out), (h, r_out)], rect_side, seg=seg, caps=(False, False))
        ir = R(inner_rect or rect_side)
        for j in range(seg):                       # inner wall faces the axis
            th0, th1 = 2 * math.pi * j / seg, 2 * math.pi * (j + 1) / seg
            q = lambda th, t: c + d * t + (a * math.cos(th) + b * math.sin(th)) * r_in
            nin = -nrm(a * math.cos((th0 + th1) / 2) + b * math.sin((th0 + th1) / 2))
            self.quad([q(th0, 0), q(th1, 0), q(th1, h), q(th0, h)], ir, n=nin)
        tr = R(rect_top or rect_side)
        for t, sgn in ((0.0, -1), (h, 1)):
            for j in range(seg):
                th0, th1 = 2 * math.pi * j / seg, 2 * math.pi * (j + 1) / seg
                P = lambda r, th: c + d * t + (a * math.cos(th) + b * math.sin(th)) * r
                ps = [P(r_in, th0), P(r_out, th0), P(r_out, th1), P(r_in, th1)]
                if sgn < 0:
                    ps = ps[::-1]
                self.quad(ps, tr, n=d * sgn)

    def sweep(self, pts, r, rect, seg=6, caps=True, squash=1.0):
        pts = [np.asarray(p, float) for p in pts]
        m = len(pts)
        rings = []
        for i, p in enumerate(pts):
            t = nrm(pts[min(i + 1, m - 1)] - pts[max(i - 1, 0)])
            a, b, _ = basis(t, up=(0, 1, 0))
            rr = r[i] if hasattr(r, "__len__") else r
            rings.append([(p + (a * math.cos(2 * math.pi * k / seg) + b * math.sin(2 * math.pi * k / seg) * squash) * rr,
                           nrm(a * math.cos(2 * math.pi * k / seg) + b * math.sin(2 * math.pi * k / seg) * squash)) for k in range(seg + 1)])
        u0, v0, u1, v1 = R(rect)
        for i in range(m - 1):
            for k in range(seg):
                (pa, na), (pb, nb) = rings[i][k], rings[i][k + 1]
                (pc, nc), (pd, nd) = rings[i + 1][k + 1], rings[i + 1][k]
                ua, ub = u0 + (u1 - u0) * k / seg, u0 + (u1 - u0) * (k + 1) / seg
                va, vb = v1 - (v1 - v0) * i / (m - 1), v1 - (v1 - v0) * (i + 1) / (m - 1)
                self.tri([pa, pd, pc], [na, nd, nc], [(ua, va), (ua, vb), (ub, vb)])
                self.tri([pa, pc, pb], [na, nc, nb], [(ua, va), (ub, vb), (ub, va)])
        if caps:
            for i, sgn in ((0, -1), (m - 1, 1)):
                t = nrm(pts[min(i + 1, m - 1)] - pts[max(i - 1, 0)]) * sgn
                for k in range(seg):
                    self.tri([pts[i], rings[i][k][0], rings[i][k + 1][0]], [t] * 3, [((u0 + u1) / 2, (v0 + v1) / 2)] * 3)

    def decal(self, c, w, h, normal, up, rect, lift=0.0006):
        n = nrm(normal)
        u = nrm(np.asarray(up, float) - np.dot(up, n) * n)
        rgt = np.cross(u, n)
        c = np.asarray(c, float) + n * lift
        ps = [c - rgt * w / 2 - u * h / 2, c + rgt * w / 2 - u * h / 2, c + rgt * w / 2 + u * h / 2, c - rgt * w / 2 + u * h / 2]
        self.quad(ps, R(rect), n=n)


def finish(name, g, cat, desc, grip=None, extra_nodes=(), col=True, **meta):
    """spec for the GLB writer: mesh + convex collision box + Inspect/Grip marker nodes; origin bottom-centre"""
    P = np.array(g.g["p"])
    mn, mx = P.min(0), P.max(0)
    # put the origin at the bottom centre (world placement); Inspect marks the bounding-box centre
    off = np.array([-(mn[0] + mx[0]) / 2, -mn[1], -(mn[2] + mx[2]) / 2])
    for p in g.g["p"]:
        p[0] += off[0]
        p[1] += off[1]
        p[2] += off[2]
    mn, mx = mn + off, mx + off
    children = [{"name": name + "_Mesh", "mb": g.mb}]
    if col:
        c = MB()
        c.box(COL_KEY, tuple(mn), tuple(mx), skip=())
        children.append({"name": name + "_Col-convcolonly", "mb": c})
    children.append({"name": "Inspect_Center", "t": tuple(float(v) for v in (mn + mx) / 2)})
    if grip is not None:
        children.append({"name": "Grip", "t": tuple(float(v) for v in np.asarray(grip) + off)})
    for nm, p in extra_nodes:
        children.append({"name": nm, "t": tuple(float(v) for v in np.asarray(p) + off)})
    m = dict(kind="inventory", category=cat, desc=desc, size=[round(float(v), 3) for v in (mx - mn)], **meta)
    if grip is not None:
        m["grip"] = [round(float(v), 4) for v in np.asarray(grip) + off]
    return {"name": name, "children": children, "meta": m}
