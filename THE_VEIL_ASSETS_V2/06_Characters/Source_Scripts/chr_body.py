"""Shared parametric body builder: one generator, many people.

A character definition (chr_roster.py) supplies proportions, head/face shape, hair style, clothing silhouette
and accessories; this module turns it into a skinned SkinMesh plus rest joints and texture-row metadata that
the painter (chr_tex.py) uses to place seams, hems, belts and faces exactly where the geometry puts them.
"""
import math

import numpy as np

from chr_core import SkinMesh, ring, tube_frame, frame, nrm, v3, blend, rot

ATLAS = 256


def R(x, y, w, h):
    """Atlas pixel rect -> uv rect (u0, v0, u1, v1), v down (glTF)."""
    return (x / ATLAS, y / ATLAS, (x + w) / ATLAS, (y + h) / ATLAS)


# shared atlas layout (pixels): every character's texture uses the same regions
REG = {
    "head": (0, 0, 128, 64), "hair": (128, 0, 64, 64), "hat": (192, 0, 64, 32), "brim": (192, 32, 32, 16),
    "nose": (224, 32, 16, 16), "ear": (240, 32, 16, 16), "glasses": (224, 48, 16, 16), "skin": (240, 48, 16, 16),
    "torso": (0, 64, 128, 64), "leg_l": (128, 64, 64, 64), "leg_r": (192, 64, 64, 64),
    "arm_l": (0, 128, 64, 64), "arm_r": (64, 128, 64, 64), "skirt": (128, 128, 64, 64),
    "hand": (192, 128, 32, 32), "shoe": (224, 128, 32, 32), "sole": (192, 160, 32, 16), "boot": (224, 160, 32, 32),
    "belt": (128, 192, 64, 16), "gear": (128, 208, 32, 32), "metal": (160, 208, 32, 16), "patch": (160, 224, 32, 16),
    "fabric2": (0, 192, 64, 64), "fabric3": (64, 192, 64, 64), "bag": (192, 192, 64, 32), "strap": (192, 224, 64, 16),
    "badge": (192, 240, 16, 16), "plastic": (208, 240, 16, 16), "paper": (224, 240, 32, 16), "tooth": (192, 176, 32, 16),
}


def rr(name):
    return R(*REG[name])


def lerp(a, b, t):
    return a + (b - a) * t


def interp(table, t):
    """table: list of (t, values...) -> interpolated tuple of values."""
    for i in range(len(table) - 1):
        t0, t1 = table[i][0], table[i + 1][0]
        if t <= t1 or i == len(table) - 2:
            k = 0 if t1 == t0 else min(1.0, max(0.0, (t - t0) / (t1 - t0)))
            return tuple(lerp(a, b, k) for a, b in zip(table[i][1:], table[i + 1][1:]))
    return tuple(table[-1][1:])


def se(c, p):
    """superellipse helper: signed |c|^p"""
    return math.copysign(abs(c) ** p, c)


class Body:
    """Builds one character. c = character definition dict (see chr_roster)."""

    def __init__(self, c):
        self.c = c
        self.m = SkinMesh()
        self.meta = {"rows": {}}
        H = c["height"]
        self.H = H
        g = c["body"]
        self.g = g
        self.stoop = math.radians(g.get("stoop", 0.0))
        self.J = {}
        self.extra_nodes = []

    # ------------------------------------------------------------------ skeleton
    def zoff(self, y):
        """forward lean of the upper body (stoop) as a function of height"""
        y0 = 0.60 * self.H
        return math.tan(self.stoop) * max(0.0, y - y0) * 0.9

    def skeleton(self):
        H, g = self.H, self.g
        J = self.J
        J["Root"] = v3(0, 0, 0)
        J["Hips"] = v3(0, 0.53 * H, 0)
        J["Spine"] = v3(0, 0.60 * H, self.zoff(0.60 * H))
        J["Chest"] = v3(0, 0.68 * H, self.zoff(0.68 * H))
        J["UpperChest"] = v3(0, 0.755 * H, self.zoff(0.755 * H))
        J["Neck"] = v3(0, 0.835 * H, self.zoff(0.835 * H) + g.get("neck_fwd", 0.0))
        self.head_base = 0.872 * H
        self.head_z = self.zoff(0.872 * H) + g.get("neck_fwd", 0.0) * 1.6
        J["Head"] = v3(0, self.head_base, self.head_z)
        tilt = math.radians(g.get("shoulder_tilt", 0.0))
        sw = g["shoulder_w"]
        alpha = math.radians(g.get("arm_angle", 50.0))
        Lu, Lf = g.get("upper_arm", 0.175) * H, g.get("forearm", 0.155) * H
        for side, sx in (("Left", 1), ("Right", -1)):
            ys = 0.805 * H + sx * math.sin(tilt) * sw
            zs = self.zoff(ys) - 0.005
            J[side + "Shoulder"] = v3(sx * 0.035, ys - 0.01, zs)
            S = v3(sx * sw, ys, zs)
            J[side + "UpperArm"] = S
            d = nrm(v3(sx * math.cos(alpha), -math.sin(alpha), 0.06))
            E = S + d * Lu
            J[side + "LowerArm"] = E
            df = nrm(d + v3(0, 0, 0.18) + v3(-sx * 0.05, 0, 0))
            Wr = E + df * Lf
            J[side + "Hand"] = Wr
            hx = g.get("leg_spread", 0.095)
            Hp = v3(sx * hx, 0.50 * H, 0.0)
            K = v3(sx * hx * 0.94, 0.275 * H, 0.012)
            A = v3(sx * hx * 0.88, 0.05 * H, -0.012)
            J[side + "UpperLeg"], J[side + "LowerLeg"], J[side + "Foot"] = Hp, K, A
            sl = g.get("shoe_len", 0.28)
            J[side + "Toes"] = v3(A[0], 0.025, A[2] - 0.06 + sl * 0.62)
        return J

    # ------------------------------------------------------------------ torso
    def torso_table(self):
        g, H = self.g, self.H
        b = g.get("belly", 0.0)
        sw = g["shoulder_w"]
        return [  # (y, rx, rz, zc)
            (0.465 * H, g["hip_w"] * 0.62, g["hip_d"] * 0.70, -0.005),
            (0.52 * H, g["hip_w"], g["hip_d"], 0.0),
            (0.60 * H, g["waist_w"], g["waist_d"] + b * 0.6, b * 0.35),
            (0.655 * H, (g["waist_w"] + g["chest_w"]) / 2 + b * 0.25, (g["waist_d"] + g["chest_d"]) / 2 + b, b * 0.6),
            (0.725 * H, g["chest_w"], g["chest_d"] + b * 0.35, 0.012 + b * 0.25 + g.get("bust", 0.0) * 0.5),
            (0.78 * H, sw * 0.93, g["chest_d"] * 0.88, 0.006),
            (0.818 * H, sw * 0.80, g["chest_d"] * 0.62, -0.004),
            (0.842 * H, g["neck_r"] * 1.55, g["neck_r"] * 1.35, -0.01),
        ]

    def torso_at(self, y):
        t = self.torso_table()
        ys = [q[0] for q in t]
        y = min(max(y, ys[0]), ys[-1])
        rx, rz, zc = interp([(q[0], q[1], q[2], q[3]) for q in t], y)
        return rx, rz, zc + self.zoff(y)

    def torso_pt(self, y, th, off=0.0):
        """Surface point at height y, angle th (0 = front +Z, +pi/2 = character's left +X)."""
        rx, rz, zc = self.torso_at(y)
        sq = self.c.get("torso_squash", 0.78)
        return v3((rx + off) * se(math.sin(th), sq), y, zc + (rz + off) * se(math.cos(th), sq))

    def torso(self, n=12):
        H = self.H
        sq = self.c.get("torso_squash", 0.78)
        a, b = tube_frame(v3(0, 1, 0))
        rings, ws = [], []
        names = ["crotch", "hip", "waist", "belly", "chest", "upper", "shoulder", "neckbase"]
        tab = self.torso_table()
        for k, (y, rx, rz, zc) in enumerate(tab):
            c = v3(0, y, zc + self.zoff(y))
            rg = ring(c, a, b, rz, rx, n, squash=sq)        # a = back(-z), b = side: rz along a, rx along b
            rings.append(rg)
            nm = names[k]
            wl = []
            for p in rg:
                side = "Left" if p[0] > 0 else "Right"
                lat = min(1.0, abs(p[0]) / max(rx, 1e-6))
                if nm == "crotch":
                    w = blend(("Hips", 0.55), (side + "UpperLeg", 0.45 * lat + 0.0001))
                elif nm == "hip":
                    w = {"Hips": 1.0}
                elif nm == "waist":
                    w = blend(("Hips", 0.5), ("Spine", 0.5))
                elif nm == "belly":
                    w = {"Spine": 1.0}
                elif nm == "chest":
                    w = blend(("Spine", 0.3), ("Chest", 0.7))
                elif nm == "upper":
                    w = blend(("Chest", 0.3), ("UpperChest", 0.7 - 0.25 * lat ** 2), (side + "Shoulder", 0.25 * lat ** 2 + 0.0001))
                elif nm == "shoulder":
                    w = blend(("UpperChest", 1.0 - 0.45 * lat ** 2), (side + "Shoulder", 0.45 * lat ** 2 + 0.0001))
                else:
                    w = blend(("UpperChest", 0.6), ("Neck", 0.4))
                wl.append(w)
            ws.append(wl)
        if self.c.get("skirt"):
            # under a skirt the crotch ring stays (closes the torso), legs start below the hem
            pass
        L = self.m.loft(rings, ws, rr("torso"), cap_bot=(rings[0].mean(0) + v3(0, -0.01, 0), {"Hips": 1.0},
                                                          ((REG["torso"][0] + 64) / ATLAS, (REG["torso"][1] + 63) / ATLAS)))
        self.meta["rows"]["torso"] = {nm: REG["torso"][1] + (1 - L[k]) * (REG["torso"][3] - 1) for k, nm in enumerate(names)}
        # neck
        J = self.J
        nr = self.g["neck_r"]
        y0, y1 = 0.832 * H, self.head_base + 0.03
        a, b = tube_frame(v3(0, 1, 0))
        rings = [ring(v3(0, y, self.zoff(y) + self.g.get("neck_fwd", 0) * (y - y0) / (y1 - y0) * 1.6), a, b, nr * s, nr * s * 1.02, 8)
                 for y, s in ((y0, 1.05), ((y0 + y1) / 2, 0.97), (y1, 0.95))]
        self.m.loft(rings, [blend(("UpperChest", 0.5), ("Neck", 0.5)), {"Neck": 1.0}, blend(("Neck", 0.4), ("Head", 0.6))],
                    R(240, 48, 16, 16))

    # ------------------------------------------------------------------ head
    def head_table(self):
        f = self.c["face"]
        jaw, cran, chin = f.get("jaw", 1.0), f.get("cranium", 1.0), f.get("chin", 1.0)
        return [  # (t, rx, rz, cz) rx in head widths, rz/cz in head depths
            (0.00, 0.17 * f.get("chin_w", 1.0), 0.15, 0.30 * chin),
            (0.10, 0.36 * jaw, 0.34, 0.17 * chin),
            (0.28, 0.46 * (0.5 + 0.5 * jaw), 0.50, 0.07),
            (0.50, 0.50 * f.get("cheek", 1.0), 0.56, 0.02),
            (0.70, 0.51 * cran, 0.58, -0.02),
            (0.86, 0.45 * cran, 0.52, -0.04),
            (0.96, 0.30 * cran, 0.36, -0.05),
            (1.00, 0.10, 0.12, -0.05),
        ]

    def head_dims(self):
        f = self.c["face"]
        W = f.get("head_w", 0.165)
        Hh = f.get("head_h", 0.25)
        D = W * 1.2 * f.get("head_d", 1.0)
        return W, Hh, D

    def head_pt(self, t, th, off=0.0):
        W, Hh, D = self.head_dims()
        rx, rz, cz = interp(self.head_table(), t)
        y = self.head_base - 0.045 + t * Hh
        z = self.head_z + cz * D
        sq = 0.85
        return v3((rx * W + off) * se(math.sin(th), sq), y, z + (rz * D + off) * se(math.cos(th), sq))

    def head(self, n=12):
        tab = self.head_table()
        a, b = tube_frame(v3(0, 1, 0))
        rings = []
        for (t, *_ ) in tab:
            rings.append(np.array([self.head_pt(t, math.pi + 2 * math.pi * k / n) for k in range(n)]))
        # ring() ordering must match tube_frame: k=0 at back (th = pi), increasing toward the character's right?
        # tube_frame: a = back, b = cross(+y, back) = +x... check: cross((0,1,0),(0,0,-1)) = (-1,0,0) -> right side.
        # head_pt: th = pi + 2pi k/n -> sin < 0 first -> x < 0 -> right side. Consistent.
        L = self.m.loft(rings, [{"Head": 1.0}] * len(rings), rr("head"),
                        cap_top=(self.head_pt(1.0, 0) * v3(0, 1, 0) + v3(0, 0.004, self.head_pt(1.0, math.pi / 2)[2]), {"Head": 1.0},
                                 ((REG["head"][0] + 64) / ATLAS, REG["head"][1] / ATLAS + 0.5 / ATLAS)),
                        cap_bot=(self.head_pt(0.0, 0) * v3(0, 1, 0) + v3(0, -0.004, self.head_pt(0.0, math.pi / 2)[2]), {"Head": 1.0},
                                 ((REG["head"][0] + 64) / ATLAS, (REG["head"][1] + 63.5) / ATLAS)))
        self.meta["rows"]["head"] = {round(t, 2): REG["head"][1] + (1 - L[k]) * (REG["head"][3] - 1) for k, (t, *_) in enumerate(tab)}
        self.meta["head_t"] = [t for (t, *_ ) in tab]
        self.meta["head_L"] = list(L)
        f = self.c["face"]
        # nose
        nz = f.get("nose", {})
        nl, nw, nh = nz.get("len", 0.045), nz.get("w", 0.034), nz.get("h", 0.065)
        tn = nz.get("t", 0.40)
        base = self.head_pt(tn, 0.0)
        hook = math.radians(nz.get("hook", 0.0))
        M = np.column_stack([v3(1, 0, 0), nrm(v3(0, math.cos(hook), -math.sin(hook))), nrm(v3(0, math.sin(hook), math.cos(hook)))])
        self.m.box(base + v3(nz.get("x", 0.0), 0, nl / 2 - 0.012), (nw, nh, nl), {"Head": 1.0}, rr("nose"), M=M,
                   taper=(nz.get("bridge", 0.55), nz.get("bridge_d", 0.55)), skip=("-z",))
        if nz.get("bulb"):
            bs = nz["bulb"]
            self.m.box(base + v3(nz.get("x", 0.0), -nh * 0.36, nl - 0.006), (nw * 1.1 * bs, nh * 0.32 * bs, 0.026 * bs), {"Head": 1.0}, rr("nose"))
        # ears
        es = f.get("ear", 1.0)
        for sx in (1, -1):
            dy = f.get("ear_asym", 0.0) * sx
            p = self.head_pt(0.47 + dy, sx * math.pi / 2 * 0.98)
            self.m.box(p + v3(sx * 0.006, 0, -0.008), (0.020, 0.062 * es, 0.042 * es), {"Head": 1.0}, rr("ear"),
                       M=np.column_stack([v3(1, 0, 0), v3(0, 1, 0), v3(0, 0, 1)]) if sx > 0 else None, taper=(0.8, 0.8))
        if f.get("brow_ridge"):
            p = self.head_pt(0.57, 0.0)
            self.m.box(p + v3(0, 0, 0.004), (self.head_dims()[0] * 0.62, 0.016, 0.02), {"Head": 1.0}, rr("skin"), skip=("-z",))
        self.meta["eye"] = self.head_pt(0.50, 0.0)

    # ------------------------------------------------------------------ hair & hats
    def shell(self, edge, thick, rect, n=12, K=4, flare=0.0, top=0.985, weight=None):
        """Hair cap: from edge(th) (head t) to the crown, offset outward by thick (+flare at the edge)."""
        rings, ws = [], []
        w = weight or {"Head": 1.0}
        # inner lip (on the skin) then outward rings
        for k in range(-1, K + 1):
            pts = []
            for j in range(n):
                th = math.pi + 2 * math.pi * j / n
                e = edge(th)
                if k < 0:
                    pts.append(self.head_pt(e, th, 0.001))
                    continue
                tt = e + (top - e) * (k / K) ** 0.85
                off = thick * (1.0 - 0.25 * k / K) + flare * (1 - k / K) ** 2
                pts.append(self.head_pt(tt, th, off))
            rings.append(np.array(pts))
            ws.append(w)
        crown = self.head_pt(1.0, 0.0) * v3(0, 1, 0) + v3(0, thick * 0.8, self.head_pt(1.0, math.pi / 2)[2])
        self.m.loft(rings, ws, rect, cap_top=(crown, w, ((rect[0] + rect[2]) / 2, rect[1] + 0.002)))

    def hair(self):
        h = self.c.get("hair", {})
        st = h.get("style", "short")
        thick = h.get("thick", 0.012)
        rect = rr("hair")
        fr, bk = h.get("front_t", 0.80), h.get("back_t", 0.38)

        def edge_soft(th):
            k = ((1 + math.cos(th)) / 2) ** h.get("edge_p", 1.6)
            return bk + (fr - bk) * k
        if st == "bob":
            def edge(th):
                a = abs(math.atan2(math.sin(th), math.cos(th)))
                if a < math.radians(48):
                    return fr
                k = min(1.0, (a - math.radians(48)) / math.radians(30))
                return fr + (bk - fr) * k
            self.shell(edge, thick, rect, n=14, K=5, flare=h.get("flare", 0.02))
        elif st != "bald":
            self.shell(edge_soft, thick, rect, K=4, flare=h.get("flare", 0.0))
        W, Hh, D = self.head_dims()
        rngs = np.random.default_rng(len(self.c["name"]) * 7 + 3)
        for (t, th, ln, wd, tilt) in h.get("tufts", []):
            p = self.head_pt(t, th, thick * 0.6)
            out = nrm(p - v3(0, self.head_base + 0.5 * Hh, self.head_z))
            dirv = nrm(out + v3(0, tilt, 0))
            a, b2, d = frame(dirv)
            M = np.column_stack([a, d, b2])
            if np.linalg.det(M) < 0:
                M[:, 0] *= -1
            self.m.box(p + dirv * ln * 0.35, (wd, ln, wd * 0.8), {"Head": 1.0}, rect, M=M, taper=(0.25, 0.3), skip=("-y",))
        if st == "bun" or h.get("bun"):
            bt = h.get("bun_t", 0.80)
            c = self.head_pt(bt, math.pi, thick + 0.03)
            r0 = h.get("bun_r", 0.045)
            a, b2 = tube_frame(v3(0, 0, -1), front=(0, 1, 0))
            rings = [ring(c + v3(0, 0, -r0 * z), a, b2, r0 * s, r0 * s, 8) for z, s in ((-0.6, 0.55), (-0.1, 1.0), (0.5, 0.85), (0.95, 0.35))]
            self.m.loft(rings, [{"Head": 1.0}] * 4, rect, cap_top=(c + v3(0, 0, -r0 * 1.1), {"Head": 1.0}, (rect[0] + 0.01, rect[1] + 0.01)))
        if st == "ponytail" or h.get("ponytail"):
            top = self.head_pt(h.get("tail_t", 0.62), math.pi, thick + 0.01)
            pts = [top, top + v3(0, -0.05, -0.045), top + v3(0, -0.13, -0.05), top + v3(0, -0.21, -0.035)]
            rads = [0.032, 0.036, 0.030, 0.012]
            ws = [{"Head": 1.0}, {"Head": 1.0}, blend(("Head", 0.6), ("Neck", 0.4)), blend(("Head", 0.4), ("Neck", 0.6))]
            rings = []
            for k, p in enumerate(pts):
                dd = nrm(pts[min(k + 1, 3)] - pts[max(k - 1, 0)])
                a, b2 = tube_frame(dd, front=(0, 0, -1))
                rings.append(ring(p, a, b2, rads[k], rads[k] * 0.85, 7))
            self.m.loft(rings, ws, rect, cap_top=(pts[-1] + v3(0, -0.02, 0.005), ws[-1], (rect[0] + 0.01, rect[3] - 0.01)))
            # hair tie
            self.m.box(pts[0] + v3(0, -0.012, -0.012), (0.05, 0.016, 0.03), {"Head": 1.0}, rr("plastic"))
        hat = self.c.get("hat")
        if hat == "police_cap":
            self.police_cap()

    def police_cap(self):
        W, Hh, D = self.head_dims()
        n = 12
        rings, ws = [], []
        for t, s, dy in ((0.70, 1.035, 0.0), (0.80, 1.08, 0.01), (0.93, 1.30, 0.035), (0.97, 1.30, 0.045)):
            pts = []
            for j in range(n):
                th = math.pi + 2 * math.pi * j / n
                p0 = self.head_pt(min(t, 0.86), th, 0.0)
                c = v3(0, p0[1], self.head_z)
                q = c + (p0 - c) * v3(s, 1, s)
                q[1] = self.head_base - 0.045 + t * Hh + dy + 0.012 * math.cos(th)
                pts.append(q)
            rings.append(np.array(pts))
            ws.append({"Head": 1.0})
        top_c = rings[-1].mean(0) + v3(0, 0.004, 0)
        self.m.loft(rings, ws, rr("hat"), cap_top=(top_c, {"Head": 1.0}, ((REG["hat"][0] + 32) / ATLAS, (REG["hat"][1] + 4) / ATLAS)))
        # brim (visor) and cap badge
        front = self.head_pt(0.72, 0.0, 0.01)
        M = np.column_stack([v3(1, 0, 0), nrm(v3(0, 1, 0.25)), nrm(v3(0, -0.25, 1))])
        self.m.box(front + v3(0, -0.004, 0.035), (W * 0.78, 0.008, 0.075), {"Head": 1.0}, rr("brim"), M=M, taper=(0.9, 0.9))
        self.m.box(self.head_pt(0.84, 0.0, 0.025), (0.03, 0.03, 0.008), {"Head": 1.0}, rr("badge"), skip=("-z",))

    # ------------------------------------------------------------------ limbs
    def arm(self, side, J, fp=False, front=(0, 0, 1)):
        g, H = self.g, self.H
        S, E, Wr = J[side + "UpperArm"], J[side + "LowerArm"], J[side + "Hand"]
        d, df = nrm(E - S), nrm(Wr - E)
        ru, re, rf, rw = g.get("arm_r", 0.05), g.get("elbow_r", 0.042), g.get("forearm_r", 0.043), g.get("wrist_r", 0.033)
        pts = [S - d * 0.03, S + d * 0.32 * np.linalg.norm(E - S), E, E + df * 0.42 * np.linalg.norm(Wr - E), Wr]
        rad = [ru * 1.05, ru, re, rf, rw]
        dirs = [d, d, nrm(d + df), df, df]
        wts = [blend((side + "UpperArm", 0.6), (side + "Shoulder", 0.4)), {side + "UpperArm": 1.0},
               blend((side + "UpperArm", 0.5), (side + "LowerArm", 0.5)), {side + "LowerArm": 1.0},
               blend((side + "LowerArm", 0.8), (side + "Hand", 0.2))]
        if fp:
            wts[0] = {side + "UpperArm": 1.0}
        rings = []
        for p, r_, dd in zip(pts, rad, dirs):
            a, b = tube_frame(dd, front=front)
            rings.append(ring(p, a, b, r_ * 0.92, r_, 8, squash=0.9))
        reg = "arm_l" if side == "Left" else "arm_r"
        caps = dict(cap_top=(Wr + df * 0.004, wts[-1], ((REG[reg][0] + 32) / ATLAS, (REG[reg][1] + 1) / ATLAS)))
        if fp:
            caps["cap_bot"] = (pts[0] - d * 0.01, wts[0], ((REG[reg][0] + 32) / ATLAS, (REG[reg][1] + 62) / ATLAS))
        L = self.m.loft(rings, wts, rr(reg), **caps)
        self.meta["rows"][reg] = {k: REG[reg][1] + (1 - L[i]) * (REG[reg][3] - 1) for i, k in enumerate(["shoulder", "upper", "elbow", "fore", "wrist"])}
        self.hand(side, Wr, df, J, fp=fp)

    def hand(self, side, Wr, hd, J, fp=False):
        g = self.g
        s = g.get("hand_s", 1.15)
        sx = 1 if Wr[0] > 0 else -1          # palm faces the body centre-line (thigh / held object)
        if fp:
            pn = nrm(v3(-sx * 0.9, -0.5, 0.0) - np.dot(v3(-sx * 0.9, -0.5, 0.0), hd) * hd)
        else:
            pn = nrm(v3(-sx, 0, 0.15) - np.dot(v3(-sx, 0, 0.15), hd) * hd)     # palm faces the thigh
        wa = nrm(np.cross(hd, pn))
        M = np.column_stack([wa, hd, pn])
        if np.linalg.det(M) < 0:
            wa = -wa
            M = np.column_stack([wa, hd, pn])
        w = {side + "Hand": 1.0}
        rect = rr("hand")
        pl, pw, pt = 0.088 * s, 0.084 * s, 0.032 * s
        pc = Wr + hd * (pl / 2 + 0.004)
        self.m.box(pc, (pw, pl, pt), w, rect, M=M, taper=(1.05, 1.0))
        curl = math.radians(self.c.get("hand_curl", 25.0) if not fp else 62.0)
        # fingers: two segments curling toward the palm
        base = pc + hd * pl / 2
        dirv = hd
        for seg, ln in ((0, 0.046 * s), (1, 0.040 * s)):
            R_ = rot(wa, math.degrees(curl) * (0.5 if seg == 0 else 1.0))     # +angle about wa curls toward the palm
            dirv2 = nrm(R_ @ hd)
            n2 = nrm(np.cross(wa, dirv2))
            if np.dot(n2, pn) < 0:
                n2 = -n2
            M2 = np.column_stack([wa, dirv2, n2])
            if np.linalg.det(M2) < 0:
                M2 = np.column_stack([-wa, dirv2, n2])
            c2 = base + dirv2 * ln / 2
            self.m.box(c2, (pw * (0.97 - 0.06 * seg), ln, pt * (0.85 - 0.1 * seg)), w, rect, M=M2, skip=("-y",) if seg else ())
            base = base + dirv2 * ln
        # thumb
        tdir = nrm(hd * 0.6 + wa * 0.55 + pn * 0.45)
        tn = nrm(np.cross(wa, tdir))
        M3 = np.column_stack([nrm(np.cross(tdir, tn)), tdir, tn])
        if np.linalg.det(M3) < 0:
            M3[:, 0] *= -1
        self.m.box(Wr + hd * 0.03 * s + wa * pw * 0.42 + pn * pt * 0.4 + tdir * 0.026 * s, (0.026 * s, 0.058 * s, 0.026 * s), w, rect, M=M3)
        sock = pc + pn * (pt / 2 + 0.022) + hd * 0.01
        self.extra_nodes.append((side + "Hand_ItemSocket", side + "Hand", sock))

    def leg(self, side, J, start_y=None):
        g, H = self.g, self.H
        Hp, K, A = J[side + "UpperLeg"], J[side + "LowerLeg"], J[side + "Foot"]
        rt, rk, rc, ra = g.get("thigh_r", 0.085), g.get("knee_r", 0.062), g.get("calf_r", 0.063), g.get("ankle_r", 0.046)
        shoe_h = g.get("shoe_h", 0.085)
        bot = v3(A[0], shoe_h - 0.012, A[2] + 0.005)
        if start_y is None:
            pts = [Hp + v3(0, 0.045, 0), Hp + (K - Hp) * 0.22, Hp + (K - Hp) * 0.62, K, K + (bot - K) * 0.35, bot]
            rad = [rt * 1.04, rt, rt * 0.86, rk, rc, ra]
            wts = [blend(("Hips", 0.5), (side + "UpperLeg", 0.5)), {side + "UpperLeg": 1.0}, {side + "UpperLeg": 1.0},
                   blend((side + "UpperLeg", 0.5), (side + "LowerLeg", 0.5)), {side + "LowerLeg": 1.0},
                   blend((side + "LowerLeg", 0.85), (side + "Foot", 0.15))]
            names = ["top", "thigh", "mid", "knee", "calf", "ankle"]
        else:
            top = K + (Hp - K) * ((start_y - K[1]) / (Hp[1] - K[1])) if start_y > K[1] else K + (bot - K) * ((K[1] - start_y) / (K[1] - bot[1]))
            pts = [top, K, K + (bot - K) * 0.35, bot]
            rad = [rk * 1.05, rk, rc, ra]
            wts = [blend((side + "UpperLeg", 0.7), (side + "LowerLeg", 0.3)), blend((side + "UpperLeg", 0.5), (side + "LowerLeg", 0.5)),
                   {side + "LowerLeg": 1.0}, blend((side + "LowerLeg", 0.85), (side + "Foot", 0.15))]
            names = ["top", "knee", "calf", "ankle"]
        rings = []
        for k, (p, r_) in enumerate(zip(pts, rad)):
            dd = nrm(pts[min(k + 1, len(pts) - 1)] - pts[max(k - 1, 0)])
            a, b = tube_frame(dd)
            rings.append(ring(p, a, b, r_ * 0.95, r_ * 0.88, 8, squash=0.9))
        reg = "leg_l" if side == "Left" else "leg_r"
        L = self.m.loft(rings, wts, rr(reg))
        self.meta["rows"][reg] = {nm: REG[reg][1] + (1 - L[i]) * (REG[reg][3] - 1) for i, nm in enumerate(names)}
        self.shoe(side, J)

    def shoe(self, side, J):
        g = self.g
        A = J[side + "Foot"]
        sl, sw, sh = g.get("shoe_len", 0.28), g.get("shoe_w", 0.105), g.get("shoe_h", 0.085)
        boot = g.get("boots", 0.0)
        z0 = A[2] - 0.065
        rear = sl * 0.58
        sx = 1 if side == "Left" else -1
        out = sx * 0.006
        rect = rr("boot") if boot else rr("shoe")
        bh = sh + boot
        self.m.box(v3(A[0] + out, bh / 2, z0 + rear / 2), (sw, bh, rear), {side + "Foot": 1.0}, rect, taper=(0.92, 0.9), skip=())
        self.m.box(v3(A[0] + out * 1.4, sh * 0.42, z0 + rear + (sl - rear) / 2 - 0.004), (sw * 0.96, sh * 0.84, sl - rear + 0.01),
                   blend((side + "Toes", 0.8), (side + "Foot", 0.2)), rect, taper=(0.9, 0.7), skip=("-z",))

    def skirt(self):
        H = self.H
        sk = self.c["skirt"]
        n = 12
        a, b = tube_frame(v3(0, -1, 0))
        rings, ws = [], []
        top_y = 0.60 * H
        prof = [(top_y, 1.03), (0.52 * H, 1.06), (0.40 * H, 1.12), (sk["hem"] * H, sk.get("flare", 1.22))]
        for k, (y, s) in enumerate(prof):
            rx, rz, zc = self.torso_at(max(y, 0.52 * H))
            if y < 0.52 * H:
                rx, rz = self.g["hip_w"], self.g["hip_d"]
            pts = []
            wl = []
            for j in range(n):
                t = 2 * math.pi * j / n
                p = v3(0, y, zc) + a * rz * s * math.cos(t) + b * rx * s * math.sin(t)
                pts.append(p)
                lat = p[0] / max(rx * s, 1e-6)
                side = "Left" if lat > 0 else "Right"
                f = k / (len(prof) - 1)
                wl.append(blend(("Hips", 1.0 - 0.55 * f * abs(lat)), (side + "UpperLeg", 0.55 * f * abs(lat) + 0.0001)))
            rings.append(np.array(pts))
            ws.append(wl)
        L = self.m.loft(rings, ws, rr("skirt"))
        # inner hem lip so the open bottom shows a thickness, not a hole edge
        self.meta["rows"]["skirt"] = {k: REG["skirt"][1] + (1 - L[i]) * 63 for i, k in enumerate(["waist", "hip", "thigh", "hem"])}

    # ------------------------------------------------------------------ accessories
    def accessories(self):
        H = self.H
        for acc in self.c.get("acc", []):
            kind = acc[0]
            if kind == "belt":
                y, hgt = acc[1] * H, acc[2]
                n = 12
                a, b = tube_frame(v3(0, 1, 0))
                rings = []
                for yy in (y - hgt / 2, y + hgt / 2):
                    rx, rz, zc = self.torso_at(yy)
                    rings.append(ring(v3(0, yy, zc), a, b, rz + 0.012, rx + 0.012, n, squash=self.c.get("torso_squash", 0.78)))
                self.m.loft(rings, [{"Hips": 1.0}] * 2, rr("belt"))
                self.belt_y = y
            elif kind in ("pouch", "radio_belt", "flashlight", "cuffs", "keys"):
                th = acc[1]
                y = getattr(self, "belt_y", 0.53 * H)
                p = self.torso_pt(y, th, 0.012)
                out = nrm(v3(math.sin(th), 0, math.cos(th)))
                M = np.column_stack([nrm(np.cross(v3(0, 1, 0), out)), v3(0, 1, 0), out])
                size = {"pouch": (0.07, 0.08, 0.04), "radio_belt": (0.055, 0.11, 0.035), "flashlight": (0.035, 0.16, 0.035),
                        "cuffs": (0.07, 0.055, 0.035), "keys": (0.03, 0.05, 0.02)}[kind]
                drop = {"flashlight": -0.05, "radio_belt": -0.02, "keys": -0.04}.get(kind, -0.01)
                rect = rr("gear") if kind != "keys" else rr("metal")
                self.m.box(p + out * size[2] / 2 + v3(0, drop, 0), size, {"Hips": 1.0}, rect, M=M)
                if kind == "radio_belt":
                    self.m.box(p + out * 0.02 + v3(0, 0.05 + 0.045, 0), (0.008, 0.06, 0.008), {"Hips": 1.0}, rr("plastic"), M=M)
            elif kind == "radio_chest":
                th = acc[1]
                y = 0.745 * H
                p = self.torso_pt(y, th, 0.006)
                out = nrm(v3(math.sin(th), 0.15, math.cos(th)))
                M = np.column_stack([nrm(np.cross(v3(0, 1, 0), out)), v3(0, 1, 0), out])
                self.m.box(p + out * 0.016, (0.05, 0.085, 0.03), {"UpperChest": 1.0}, rr("gear"), M=M)
                self.m.box(p + out * 0.02 + v3(0, 0.07, 0), (0.008, 0.05, 0.008), {"UpperChest": 1.0}, rr("plastic"), M=M)
            elif kind == "badge":
                th = acc[1]
                p = self.torso_pt(0.745 * H, th, 0.004)
                out = nrm(v3(math.sin(th), 0.1, math.cos(th)))
                M = np.column_stack([nrm(np.cross(v3(0, 1, 0), out)), v3(0, 1, 0), out])
                self.m.box(p + out * 0.004, (0.04, 0.045, 0.008), {"UpperChest": 1.0}, rr("badge"), M=M, skip=("-z",))
            elif kind == "hood":
                y = 0.84 * H
                rx, rz, zc = self.torso_at(0.81 * H)
                self.m.box(v3(0, y, zc - rz * 0.85 - 0.035), (self.g["shoulder_w"] * 1.05, 0.10, 0.08), blend(("UpperChest", 0.7), ("Neck", 0.3)),
                           rr("fabric2"), taper=(0.75, 0.6))
            elif kind == "collar":
                for sx in (1, -1):
                    p = self.torso_pt(0.835 * H, sx * 0.9, 0.0)
                    out = nrm(v3(sx * 0.8, 0.5, 0.45))
                    a_, b_, d_ = frame(out)
                    M = np.column_stack([nrm(np.cross(v3(0, 1, 0), out)), v3(0, 1, 0), out])
                    self.m.box(p + v3(0, 0.02, 0.0), (0.075, 0.055, 0.022), blend(("UpperChest", 0.8), ("Neck", 0.2)), rr("fabric2"), M=M,
                               taper=(0.7, 1.0))
            elif kind == "front_pocket":
                y = acc[1] * H
                p = self.torso_pt(y, 0.0, 0.004)
                self.m.box(p + v3(0, 0, 0.008), (acc[2], acc[3], 0.016), {"Spine": 1.0}, rr("fabric2"), skip=("-z",))
            elif kind == "bag_hip":
                th = acc[1]
                p = self.torso_pt(0.50 * H, th, 0.02)
                out = nrm(v3(math.sin(th), 0, math.cos(th)))
                M = np.column_stack([nrm(np.cross(v3(0, 1, 0), out)), v3(0, 1, 0), out])
                self.m.box(p + out * 0.05 + v3(0, -0.03, 0), (0.30, 0.24, 0.085), {"Hips": 1.0}, rr("bag"), M=M)
                self.m.box(p + out * 0.095 + v3(0, 0.02, 0), (0.30, 0.13, 0.012), {"Hips": 1.0}, rr("fabric3"), M=M, skip=("-z",))
            elif kind == "glasses":
                self.glasses(acc[1] if len(acc) > 1 else 0.046)
            elif kind == "name_tag":
                pass   # painted

    def glasses(self, lens_w):
        W, Hh, D = self.head_dims()
        w = {"Head": 1.0}
        rect = rr("glasses")
        lh = 0.032
        bar = 0.006
        for sx in (1, -1):
            c = self.head_pt(0.50, sx * 0.36, 0.024)
            c[2] = max(c[2], self.head_pt(0.50, 0.0)[2] + 0.004)
            for (dx, dy, sw_, sh_) in ((0, lh / 2, lens_w, bar), (0, -lh / 2, lens_w, bar), (lens_w / 2, 0, bar, lh), (-lens_w / 2, 0, bar, lh)):
                self.m.box(c + v3(dx, dy, 0), (sw_, sh_, bar), w, rect)
            ear = self.head_pt(0.50, sx * math.pi / 2 * 0.95, 0.008)
            outer = c + v3(sx * lens_w / 2, lh / 2 - bar, 0)
            mid = (outer + ear) / 2
            ln = np.linalg.norm(ear - outer)
            dd = nrm(ear - outer)
            M = np.column_stack([nrm(np.cross(v3(0, 1, 0), dd)), v3(0, 1, 0), dd])
            if np.linalg.det(M) < 0:
                M[:, 0] *= -1
            self.m.box(mid, (bar, bar, ln), w, rect, M=M)
        self.m.box(self.head_pt(0.50, 0.0, 0.03) + v3(0, lh / 2 - bar, 0), (0.024, bar, bar), w, rect)

    # ------------------------------------------------------------------ build
    def build(self):
        J = self.skeleton()
        self.torso()
        self.head()
        self.hair()
        for side in ("Left", "Right"):
            self.arm(side, J)
            sk = self.c.get("skirt")
            self.leg(side, J, start_y=(sk["hem"] * self.H + 0.06) if sk else None)
        if self.c.get("skirt"):
            self.skirt()
        self.accessories()
        if self.c.get("eye_marker"):
            e = self.meta["eye"] + v3(0, 0, -0.07)
            self.extra_nodes.append(("Head_EyeLevel", "Head", e))
        return self


def fp_arms(c):
    """First-person arms in camera space: origin = camera, Godot Camera3D looks down -Z, +Y up.
    Same arm/hand generator and texture as the full body; rest pose = a relaxed 'ready' hold."""
    b = Body(c)
    J = {"Root": v3(0, 0, 0)}
    for side, sx in (("Left", -1), ("Right", 1)):     # camera right = +X
        J[side + "Shoulder"] = v3(sx * 0.10, -0.24, 0.16)
        J[side + "UpperArm"] = v3(sx * 0.20, -0.27, 0.13)
        J[side + "LowerArm"] = v3(sx * 0.255, -0.40, -0.14) if side == "Right" else v3(sx * 0.26, -0.42, -0.12)
        J[side + "Hand"] = v3(sx * 0.19, -0.31, -0.42) if side == "Right" else v3(sx * 0.21, -0.35, -0.36)
    b.J = J
    for side in ("Left", "Right"):
        # 'Left' in the body sense = character's left; in camera space that is -X. Hand helper uses sx = +1 for Left,
        # so mirror by swapping labels for the palm orientation only.
        b.arm(side, J, fp=True, front=(0, 1, 0))
    return b
