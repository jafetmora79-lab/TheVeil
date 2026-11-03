"""Rev 3 sculpt assembly: volumes + skeleton -> skinned, unwrapped mesh + chart table for the painter."""
import math

import numpy as np

import chr_sculpt as S
from chr_core import BONES, nrm, v3


def tube(points, radii, nseg=6, closed=False, squash=1.0, up=(0, 0, 1)):
    """Explicit swept tube (accessories: glasses rims, brow strips). Returns (P, faces) with outward winding."""
    pts = [np.asarray(p, float) for p in points]
    m = len(pts)
    P, F = [], []
    for i, p in enumerate(pts):
        if closed:
            t = nrm(pts[(i + 1) % m] - pts[i - 1])
        else:
            t = nrm(pts[min(i + 1, m - 1)] - pts[max(i - 1, 0)])
        u = np.asarray(up, float)
        a = nrm(np.cross(t, u)) if np.linalg.norm(np.cross(t, u)) > 1e-6 else nrm(np.cross(t, v3(1, 0, 0)))
        b = np.cross(a, t)
        for k in range(nseg):
            th = 2 * math.pi * k / nseg
            P.append(p + radii[i] * (a * math.cos(th) + b * math.sin(th) * squash))
    rings = m if closed else m - 1
    for i in range(rings):
        i2 = (i + 1) % m
        for k in range(nseg):
            a0, a1 = i * nseg + k, i * nseg + (k + 1) % nseg
            b0, b1 = i2 * nseg + k, i2 * nseg + (k + 1) % nseg
            F += [(a0, b0, b1), (a0, b1, a1)]
    P = np.array(P)
    if not closed:
        for end, ring_i in ((0, 0), (1, m - 1)):
            c = len(P)
            P = np.vstack([P, pts[ring_i]])
            for k in range(nseg):
                a0, a1 = ring_i * nseg + k, ring_i * nseg + (k + 1) % nseg
                F.append((c, a1, a0) if end == 0 else (c, a0, a1))
    F = np.array(F)
    # make winding outward (per face, relative to local tube axis point)
    out = []
    for f in F:
        a, b, c = P[f]
        n = np.cross(b - a, c - a)
        ctr = (a + b + c) / 3
        # nearest path point
        q = pts[int(np.argmin([np.linalg.norm(ctr - x) for x in pts]))]
        out.append(f if np.dot(n, ctr - q) >= 0 else f[::-1])
    return P, np.array(out)


class Sculpt:
    def __init__(self, name, height):
        self.name, self.height = name, height
        self.vols = []
        self.J = {}
        self.ends = {}
        self.acc = []           # (P, faces, label, group)
        self.feat = {}          # named feature points for the painter (eyes, mouth ...)
        self.extra_nodes = []
        self.params = {}

    # -- authoring helpers --------------------------------------------------------
    def add(self, kind, label, group, **kw):
        self.vols.append(S.Vol(kind, label, group, **kw))
        return self.vols[-1]

    def chain(self, label, group, pts, radii, k=0.03, **kw):
        for (a, b), (r1, r2) in zip(zip(pts[:-1], pts[1:]), zip(radii[:-1], radii[1:])):
            self.add("cone", label, group, a=a, b=b, r1=r1, r2=r2, k=k, **kw)

    def field_at(self, p, labels=None):
        p = np.atleast_2d(np.asarray(p, float))
        F = np.full(len(p), 1.0)
        for v in self.vols:
            if labels is not None and v.label not in labels:
                continue
            d = v.sdf(p)
            F = S.smin(F, d, v.k) if v.op == "add" else S.smax(F, -d, v.k)
        return F

    def hit(self, origin, direction, labels=None, tmax=0.5):
        """sphere-trace the current sculpt from outside; returns the surface point"""
        o, d = np.asarray(origin, float), nrm(np.asarray(direction, float))
        t = 0.0
        for _ in range(200):
            f = self.field_at(o + d * t, labels)[0]
            if f < 0.0005:
                return o + d * t
            t += max(f * 0.8, 0.0008)
            if t > tmax:
                break
        return o + d * t

    def hand(self, side, label, wrist, hdir, palm_n, s=1.0, curl=30.0, spread=5.0, lens=(0.92, 1.0, 0.95, 0.78), fr=0.0115, k=0.006):
        """Chunky stylised hand: soft palm, four separated two-segment fingers, a two-segment thumb (front side)."""
        g = "hand_" + side
        hd, pn = nrm(np.asarray(hdir, float)), nrm(np.asarray(palm_n, float))
        pn = nrm(pn - np.dot(pn, hd) * hd)
        wa = nrm(np.cross(hd, pn))                 # across the knuckles
        if np.dot(wa, v3(0, 0, 1)) < 0:
            wa = -wa                               # +wa = thumb / index side (front in A-pose)
        pl, pw, pt = 0.085 * s, 0.092 * s, 0.040 * s
        pc = np.asarray(wrist, float) + hd * pl * 0.52
        R = np.column_stack([wa, hd, -pn])
        self.add("ell", label, g, c=pc, r=(pw * 0.52, pl * 0.58, pt * 0.62), R=R, k=0.02)
        self.add("ell", label, g, c=np.asarray(wrist, float) + hd * 0.006, r=(pw * 0.40, 0.03 * s, pt * 0.55), R=R, k=0.02)
        gap = fr * s * 2 + 0.009          # scaled finger diameter + a clear gap (> 1 voxel)
        for i, ln in enumerate(lens):
            off = (1.5 - i) * gap
            base = pc + hd * pl * 0.42 + wa * off
            dir0 = nrm(hd + wa * math.tan(math.radians(spread * (1.5 - i))))
            c1 = math.radians(curl * 0.6)
            d1 = nrm(dir0 * math.cos(c1) + pn * math.sin(c1))
            p1 = base + d1 * 0.040 * s * ln
            c2 = math.radians(curl * 1.5)
            d2 = nrm(dir0 * math.cos(c2) + pn * math.sin(c2))
            p2 = p1 + d2 * 0.034 * s * ln
            r0 = fr * s * (1.0 if i else 1.05)
            self.add("cone", label, g, a=base, b=p1, r1=r0, r2=r0 * 0.92, k=k)
            self.add("cone", label, g, a=p1, b=p2, r1=r0 * 0.92, r2=r0 * 0.82, k=0.004)
        tb = np.asarray(wrist, float) + hd * 0.025 * s + wa * pw * 0.42 + pn * pt * 0.15
        td = nrm(hd * 0.55 + wa * 0.55 + pn * 0.45)
        t1 = tb + td * 0.040 * s
        t2 = t1 + nrm(td + pn * 0.5 + hd * 0.2) * 0.032 * s
        self.add("cone", label, g, a=tb, b=t1, r1=fr * 1.25 * s, r2=fr * 1.05 * s, k=0.01)
        self.add("cone", label, g, a=t1, b=t2, r1=fr * 1.05 * s, r2=fr * 0.9 * s, k=0.004)
        self.ends[side + "Hand"] = pc + hd * pl * 0.9
        self.extra_nodes.append((side + "Hand_ItemSocket", side + "Hand", pc + pn * (pt * 0.5 + 0.012) + hd * 0.01))

    def accessory(self, P, F, label, group="head"):
        self.acc.append((np.asarray(P, float), np.asarray(F, np.int64), label, group))

    # -- build ----------------------------------------------------------------------
    def build(self, target_tris=3900):
        F, lab, lo, vox = S.build_field(self.vols)
        hc = self.params["head_center"]
        ybot = self.params["face_box"][1] - 0.03
        regions = [(lambda c, hc=hc, yb=ybot: (c[:, 1] > yb) & (np.linalg.norm(c - hc, axis=1) < 0.26), self.params.get("head_tris", 2300))]
        for sd in ("Left", "Right"):
            hcen = (self.J[sd + "Hand"] + self.ends[sd + "Hand"]) / 2
            regions.append((lambda c, h=hcen: np.linalg.norm(c - h, axis=1) < 0.11, self.params.get("hand_tris", 520)))
        P, I = S.extract(F, lo, vox, target_tris, regions)
        T = I.reshape(-1, 3)
        # orientation: outward if signed volume > 0
        vol = np.einsum("ij,ij->i", P[T[:, 0]], np.cross(P[T[:, 1]], P[T[:, 2]])).sum() / 6
        if vol < 0:
            T = T[:, ::-1].copy()
        Nv = S.vertex_normals(P, T.reshape(-1))
        vi = S.label_vertices(self.vols, lab, lo, vox, P, Nv)
        labels = [self.vols[i].label if i >= 0 else "skin" for i in vi]
        groups = [self.vols[i].group if i >= 0 else "torso" for i in vi]
        # explicit accessories
        allP, allT = [P], [T]
        n0 = len(P)
        for (Pa, Fa, la, ga) in self.acc:
            allP.append(Pa)
            allT.append(Fa + n0)
            labels += [la] * len(Pa)
            groups += [ga] * len(Pa)
            n0 += len(Pa)
        P = np.vstack(allP)
        T = np.vstack(allT)
        Nv = S.vertex_normals(P, T.reshape(-1))
        Jt, Wv = S.skin_weights(P, T.reshape(-1), groups, self.J, self.ends)
        self.mesh = dict(P=P, T=T, N=Nv, labels=labels, groups=groups, J=Jt, W=Wv)
        return self

    # -- charts + uv ------------------------------------------------------------------
    def unwrap(self, layout):
        """layout: {chart_key: (x, y, w, h)} in atlas pixels. Chart key per triangle = (part, segment)."""
        m = self.mesh
        P, T, N, labels, groups = m["P"], m["T"], m["N"], m["labels"], m["groups"]
        seg_of = lambda g: ("arm_L" if g.endswith("Left") and g.startswith(("arm", "hand")) else
                            "arm_R" if g.endswith("Right") and g.startswith(("arm", "hand")) else
                            "leg_L" if g.endswith("Left") and g.startswith(("leg", "foot")) else
                            "leg_R" if g.endswith("Right") and g.startswith(("leg", "foot")) else
                            "head" if g == "head" else "body")
        face = self.params["face_box"]          # (cx, y_bot, y_top, half_w)
        charts, tri_chart = {}, []
        for t in T:
            labs = [labels[i] for i in t]
            lab = max(set(labs), key=labs.count)
            gs = [groups[i] for i in t]
            seg = seg_of(max(set(gs), key=gs.count))
            n = N[t].mean(0)
            ctr = P[t].mean(0)
            key = (lab, seg)
            if lab == "skin":
                if seg == "head" and n[2] > 0.15 and abs(ctr[0] - face[0]) < face[3] and face[1] - 0.02 < ctr[1] < face[2]:
                    key = ("face", "head")
                else:
                    key = ("skin", "any")
            elif lab in ("brow", "glasses", "sole", "lens", "metal", "eye", "lip"):
                key = (lab, "any")
            elif lab == "hair":
                key = ("hair", "head")
            elif lab.startswith("shoe"):
                key = (lab, seg)
            if key not in layout:
                for alt in ((key[0], "body"), (key[0], "any"), ("skin", "any")):
                    if alt in layout:
                        key = alt
                        break
            tri_chart.append(key)
            charts.setdefault(key, []).append(len(tri_chart) - 1)
        J = self.J
        UVc = np.zeros((len(T), 3, 2))
        info = {}
        for key, tris in charts.items():
            x0, y0, w, h = layout[key]
            idx = T[tris]
            pts = P[idx]
            part, seg = key
            if key == ("face", "head"):
                cx, yb, yt, hw = face
                u = (pts[..., 0] - (cx - hw)) / (2 * hw)
                v = (yt - pts[..., 1]) / (yt - yb)
                info[key] = dict(kind="planar", box=face)
            elif part == "hair" or seg == "head":
                hc = self.params["head_center"]
                th = np.arctan2(pts[..., 0] - hc[0], pts[..., 2] - hc[2])
                u = (th + math.pi) / (2 * math.pi)
                ylo, yhi = pts[..., 1].min(), pts[..., 1].max()
                v = (yhi - pts[..., 1]) / max(yhi - ylo, 1e-6)
                info[key] = dict(kind="cyl", y=(ylo, yhi))
            elif part in ("skin", "brow", "glasses", "sole", "lens", "metal", "eye", "lip") or seg == "any":
                # swatch: tiny world-space projection inside the swatch (texel noise, no stretching)
                u = (pts[..., 0] * 7.3 + pts[..., 2] * 3.1) % 1.0
                v = (pts[..., 1] * 7.7 + pts[..., 2] * 2.3) % 1.0
                u = 0.15 + 0.7 * u
                v = 0.15 + 0.7 * v
                info[key] = dict(kind="swatch")
            elif part.startswith("shoe"):
                zlo, zhi = pts[..., 2].min(), pts[..., 2].max()
                ylo, yhi = pts[..., 1].min(), pts[..., 1].max()
                u = (pts[..., 2] - zlo) / max(zhi - zlo, 1e-6)
                v = (yhi - pts[..., 1]) / max(yhi - ylo, 1e-6)
                info[key] = dict(kind="side", y=(ylo, yhi), z=(zlo, zhi))
            elif seg in ("arm_L", "arm_R", "leg_L", "leg_R"):
                sd = "Left" if seg.endswith("L") else "Right"
                chain = [J[sd + "UpperArm"], J[sd + "LowerArm"], J[sd + "Hand"], self.ends[sd + "Hand"]] if seg.startswith("arm") else \
                    [J[sd + "UpperLeg"], J[sd + "LowerLeg"], J[sd + "Foot"], J[sd + "Toes"]]
                flat = pts.reshape(-1, 3)
                tt, ang = limb_coords(flat, chain)
                ttr = tt.reshape(pts.shape[:2])
                tlo, thi = ttr.min(), ttr.max()
                u = ((ang.reshape(pts.shape[:2]) + math.pi) / (2 * math.pi))
                v = (ttr - tlo) / max(thi - tlo, 1e-6)
                info[key] = dict(kind="limb", t=(tlo, thi), chain=[c.tolist() for c in chain])
            else:
                zc = float(pts[..., 2].mean())
                th = np.arctan2(pts[..., 0], pts[..., 2] - zc)
                u = (th + math.pi) / (2 * math.pi)
                ylo, yhi = pts[..., 1].min(), pts[..., 1].max()
                v = (yhi - pts[..., 1]) / max(yhi - ylo, 1e-6)
                info[key] = dict(kind="cyl", y=(ylo, yhi), zc=zc)
            if info[key]["kind"] in ("cyl", "limb"):          # seam at the back: keep each triangle on one side
                for r in range(len(u)):
                    if u[r].max() - u[r].min() > 0.5:
                        u[r] = np.where(u[r] < 0.5, u[r] + 1.0, u[r])
                        if u[r].max() > 1.0:
                            u[r] = np.minimum(u[r], 0.999)
            u = np.clip(u, 0.0, 1.0)
            v = np.clip(v, 0.0, 1.0)
            UVc[tris, :, 0] = (x0 + 0.5 + u * (w - 1)) / 256.0
            UVc[tris, :, 1] = (y0 + 0.5 + v * (h - 1)) / 256.0
            info[key]["rect"] = (x0, y0, w, h)
            info[key]["tris"] = len(tris)
        # de-index: one vertex per triangle corner (uv seams), normals/weights from the shared vertex.
        # Thin hard-edged accessories and the few creased triangles whose smooth normals disagree with the face
        # get the face normal (flat shading there reads as a deliberate crease, not a lighting glitch).
        idx = T.reshape(-1)
        Nc = m["N"][idx].reshape(-1, 3, 3).copy()
        fn = np.cross(P[T[:, 1]] - P[T[:, 0]], P[T[:, 2]] - P[T[:, 0]])
        fn /= np.maximum(np.linalg.norm(fn, axis=1, keepdims=True), 1e-12)
        flat_acc = np.array([labels[t[0]] in ("glasses", "brow") for t in T])
        disagree = np.einsum("ij,ij->i", Nc.sum(1), fn) <= 0.05
        bad_corner = np.einsum("ikj,ij->ik", Nc, fn) < 0.2
        for r in np.where(flat_acc | disagree)[0]:
            Nc[r] = fn[r]
        rr_, cc_ = np.where(bad_corner & ~(flat_acc | disagree)[:, None])
        Nc[rr_, cc_] = fn[rr_]
        Jc = m["J"][idx].copy()
        Wc = m["W"][idx].copy()
        Jc[Wc <= 0] = 0
        out = dict(P=P[idx].astype(np.float32), N=Nc.reshape(-1, 3).astype(np.float32), UV=UVc.reshape(-1, 2).astype(np.float32),
                   J=Jc, W=Wc, I=np.arange(len(idx), dtype=np.uint32))
        self.charts = info
        return out


def limb_coords(Pp, chain):
    """param along the limb polyline (metres from the root) and angle around it (0 = front)"""
    segs = list(zip(chain[:-1], chain[1:]))
    best_d = np.full(len(Pp), 1e9)
    tt = np.zeros(len(Pp))
    ang = np.zeros(len(Pp))
    acc = 0.0
    for a, b in segs:
        a, b = np.asarray(a, float), np.asarray(b, float)
        ab = b - a
        L = np.linalg.norm(ab)
        d = ab / L
        s = np.clip((Pp - a) @ d, 0, L)
        q = Pp - (a + s[:, None] * d)
        dist = np.linalg.norm(q, axis=1)
        ref = v3(0, 0, 1) - d[2] * d
        ref = nrm(ref) if np.linalg.norm(ref) > 1e-6 else v3(0, 1, 0)
        side = np.cross(d, ref)
        th = np.arctan2(q @ side, q @ ref)
        m = dist < best_d
        best_d = np.where(m, dist, best_d)
        tt = np.where(m, acc + s, tt)
        ang = np.where(m, th, ang)
        acc += L
    return tt, ang
