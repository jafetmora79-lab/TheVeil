"""Generator v2 features (art-direction correction, Pack 06 rev 2).

Switched on per character by parameters, so v1 characters regenerate byte-identically:
  face.v2         sculpted head: 16 segments packed toward the face (2x face texels), cheeks/jaw/chin/brow/
                  forehead/nape controls, geometric eyebrows (style + asymmetry), stick-out ears with lobes,
                  optional moustache
  body.arm_profile shoulders, biceps, elbows, forearms and wrists (no pipes); optional sleeve cuff volume
  body.fingers    chunky stylised hands: palm, four two-segment fingers of different lengths, two-segment thumb
  body.pants      trouser silhouettes (baggy/slim/straight) with a hem that has thickness
  body.chunky     big soled shoes / boots, toes turned out
  acc shell       jackets / hoodies with real volume: an open (or closed) shell over the torso, flared hem,
                  closed shoulders and a raised collar
"""
import math

import numpy as np

from chr_core import ring, tube_frame, frame, nrm, v3, blend, rot

WARP = 0.45


def warp_u(u, a=WARP):
    """head ring parameter -> fraction of the circle (dense at the front, u = 0.5)"""
    return u + a * math.sin(2 * math.pi * u) / (2 * math.pi)


def head_theta(u, a=WARP):
    return math.pi + 2 * math.pi * warp_u(u, a)


def u_of_theta(th, a=WARP):
    """inverse of head_theta (th measured from the front, 0 = front)"""
    target = ((th + math.pi) % (2 * math.pi)) / (2 * math.pi)       # fraction from the back
    us = np.linspace(0, 1, 2001)
    gs = us + a * np.sin(2 * np.pi * us) / (2 * np.pi)
    return float(np.interp(target, gs, us))


def _M(x, z):
    """basis with x along x, z ~ z (orthogonalised), right-handed"""
    x = nrm(x)
    z = nrm(z - np.dot(z, x) * x)
    y = np.cross(z, x)
    return np.column_stack([x, y, z])


def install(Body):
    import chr_body as CB
    R, REG, rr = CB.R, CB.REG, CB.rr

    def head_table_v2(self):
        f = self.c["face"]
        jaw, chin, chw, chk = f.get("jaw", 1.0), f.get("chin", 1.0), f.get("chin_w", 1.0), f.get("cheek", 1.0)
        cran, brow, fh, nape = f.get("cranium", 1.0), f.get("brow", 0.0), f.get("forehead", 0.0), f.get("nape", 0.0)
        return [  # (t, rx [head widths], rz [head depths], cz)
            (0.00, 0.16 * chw, 0.13, 0.30 * chin),
            (0.07, 0.28 * (0.5 * chw + 0.5 * jaw), 0.30, 0.25 * chin),
            (0.17, 0.43 * jaw, 0.44, 0.14 + 0.03 * (chin - 1)),
            (0.30, 0.50 * chk, 0.53, 0.08),
            (0.42, 0.50 * (0.6 * chk + 0.4), 0.57, 0.05),
            (0.53, 0.50, 0.58, 0.03),
            (0.62, 0.50, 0.60 + brow, 0.02 + brow * 0.5),
            (0.74, 0.50 * cran, 0.57 - fh, -0.02 - fh * 0.5),
            (0.86, 0.46 * cran, 0.52 + nape * 0.4, -0.05 - nape),
            (0.95, 0.32 * cran, 0.37, -0.06 - nape * 0.6),
            (1.00, 0.10, 0.12, -0.06),
        ]

    def head_v2(self, n=16):
        tab = self.head_table()
        rings = [np.array([self.head_pt(t, head_theta(k / n)) for k in range(n)]) for (t, *_) in tab]
        top = self.head_pt(1.0, 0) * v3(0, 1, 0) + v3(0, 0.004, self.head_pt(1.0, math.pi / 2)[2])
        bot = self.head_pt(0.0, 0) * v3(0, 1, 0) + v3(0, -0.004, self.head_pt(0.0, math.pi / 2)[2])
        L = self.m.loft(rings, [{"Head": 1.0}] * len(rings), rr("head"),
                        cap_top=(top, {"Head": 1.0}, ((REG["head"][0] + 64) / 256, REG["head"][1] / 256 + 0.5 / 256)),
                        cap_bot=(bot, {"Head": 1.0}, ((REG["head"][0] + 64) / 256, (REG["head"][1] + 63.5) / 256)))
        self.meta["rows"]["head"] = {round(t, 2): REG["head"][1] + (1 - L[k]) * 63 for k, (t, *_) in enumerate(tab)}
        self.meta["head_t"] = [t for (t, *_) in tab]
        self.meta["warp"] = WARP
        f = self.c["face"]
        w = {"Head": 1.0}
        # nose
        nz = f.get("nose", {})
        nl, nw, nh, tn = nz.get("len", 0.05), nz.get("w", 0.036), nz.get("h", 0.07), nz.get("t", 0.40)
        base = self.head_pt(tn, nz.get("th", 0.0))
        hook = math.radians(nz.get("hook", 0.0))
        M = np.column_stack([v3(1, 0, 0), nrm(v3(0, math.cos(hook), -math.sin(hook))), nrm(v3(0, math.sin(hook), math.cos(hook)))])
        self.m.box(base + v3(nz.get("x", 0.0), 0, nl / 2 - 0.014), (nw, nh, nl), w, rr("nose"), M=M,
                   taper=(nz.get("bridge", 0.55), nz.get("bridge_d", 0.55)), skip=("-z",))
        if nz.get("bulb"):
            bs = nz["bulb"]
            self.m.box(base + v3(nz.get("x", 0.0), -nh * 0.34, nl - 0.010), (nw * 1.15 * bs, nh * 0.36 * bs, 0.03 * bs), w, rr("nose"),
                       taper=(0.8, 0.8))
        # ears: stick-out angle, size, asymmetric height, lobe
        es = f.get("ear", 1.0)
        for sx in (1, -1):
            dy = f.get("ear_asym", 0.0) * sx
            p = self.head_pt(0.47 + dy, sx * math.pi / 2 * 0.97)
            out = math.radians(f.get("ear_out", 12.0) + (f.get("ear_out_asym", 0.0) * sx))
            Mx = np.column_stack([v3(math.cos(out), 0, -sx * math.sin(out)), v3(0, 1, 0), v3(sx * math.sin(out), 0, math.cos(out))])
            if np.linalg.det(Mx) < 0:
                Mx[:, 0] *= -1
            c = p + v3(sx * 0.010, 0.004, -0.012)
            self.m.box(c, (0.022, 0.072 * es, 0.050 * es), w, rr("ear"), M=Mx, taper=(0.85, 0.75))
            self.m.box(c + v3(sx * 0.002, -0.044 * es, 0.004), (0.018, 0.022 * es, 0.028 * es), w, rr("ear"), M=Mx)
        if f.get("brow_ridge"):
            p = self.head_pt(0.615, 0.0)
            self.m.box(p + v3(0, 0, 0.002), (self.head_dims()[0] * 0.66, 0.018, 0.02), w, rr("skin"), skip=("-z",))
        # geometric eyebrows
        br = f.get("brows", {})
        bt, gap, span = br.get("t", 0.615), br.get("gap", 0.10), br.get("span", 0.42)
        thick, depth = br.get("thick", 0.014), br.get("depth", 0.013)
        for sx in (1, -1):
            side = "l" if sx > 0 else "r"
            din, dmid, dout = br.get(side, br.get("both", (0.0, 0.01, 0.0)))
            pts = [self.head_pt(bt + din, sx * gap, 0.005), self.head_pt(bt + dmid, sx * (gap + span / 2), 0.006),
                   self.head_pt(bt + dout, sx * (gap + span), 0.004)]
            for a, b in zip(pts[:-1], pts[1:]):
                mid = (a + b) / 2
                out = mid - v3(0, mid[1], self.head_z)
                Mb = _M(b - a, out)
                self.m.box(mid, (np.linalg.norm(b - a) + 0.006, thick * br.get("scale_" + side, 1.0), depth), w, rr("brow"), M=Mb,
                           taper=(0.9, 1.0))
        # moustache
        mu = f.get("mustache")
        if mu:
            p = self.head_pt(mu.get("t", 0.27), 0.0, 0.010)
            mw, mh, droop = mu.get("w", 0.06), mu.get("h", 0.016), mu.get("droop", 0.012)
            self.m.box(p, (mw * 0.55, mh, 0.018), w, rr("hair"), taper=(1.1, 1.0))
            for sx in (1, -1):
                q = self.head_pt(mu.get("t", 0.27) - 0.02, sx * 0.20, 0.009) + v3(0, -droop / 2, 0)
                Mm = _M(nrm(v3(sx, -droop / (mw * 0.4), 0)), v3(sx * 0.3, 0, 1))
                self.m.box(q, (mw * 0.42, mh * 0.9, 0.016), w, rr("hair"), M=Mm, taper=(0.6, 1.0))
        self.meta["eye"] = self.head_pt(f.get("eye_t", 0.53), 0.0)

    def arm_v2(self, side, J, front=(0, 0, 1)):
        g = self.g
        S, E, Wr = J[side + "UpperArm"], J[side + "LowerArm"], J[side + "Hand"]
        d, df = nrm(E - S), nrm(Wr - E)
        Lu, Lf = np.linalg.norm(E - S), np.linalg.norm(Wr - E)
        ru, re, rf, rw = g.get("arm_r", 0.05), g.get("elbow_r", 0.042), g.get("forearm_r", 0.043), g.get("wrist_r", 0.033)
        U, Lo = side + "UpperArm", side + "LowerArm"
        spec = [  # (point, radius, dir, weights, name)
            (S - d * 0.035, ru * 0.95, d, blend((U, 0.6), (side + "Shoulder", 0.4)), "shoulder"),
            (S + d * 0.14 * Lu, ru * g.get("deltoid", 1.2), d, {U: 1.0}, "deltoid"),
            (S + d * 0.50 * Lu, ru * 1.0, d, {U: 1.0}, "upper"),
            (S + d * 0.82 * Lu, ru * 0.86, d, {U: 1.0}, "above_elbow"),
            (E, re, nrm(d + df), blend((U, 0.5), (Lo, 0.5)), "elbow"),
            (E + df * 0.28 * Lf, rf * g.get("forearm_bulge", 1.12), df, {Lo: 1.0}, "fore"),
            (E + df * 0.72 * Lf, rf * 0.86, df, {Lo: 1.0}, "lower_fore"),
        ]
        cuff = g.get("cuff")
        if cuff:   # sleeve end with volume: flare out, then step in to the wrist (inside the sleeve)
            spec += [(Wr - df * 0.045, rw * cuff, df, {Lo: 1.0}, "cuff"), (Wr - df * 0.012, rw * cuff, df, blend((Lo, 0.85), (side + "Hand", 0.15)), "cuff_end"),
                     (Wr - df * 0.010, rw * 0.92, df, blend((Lo, 0.8), (side + "Hand", 0.2)), "wrist")]
        else:
            spec += [(Wr, rw, df, blend((Lo, 0.8), (side + "Hand", 0.2)), "wrist")]
        rings = []
        for p, r_, dd, _, _ in spec:
            a, b = tube_frame(dd, front=front)
            rings.append(ring(p, a, b, r_ * 0.92, r_, 8, squash=0.9))
        reg = "arm_l" if side == "Left" else "arm_r"
        wr = spec[-1]
        L = self.m.loft(rings, [s_[3] for s_ in spec], rr(reg),
                        cap_top=(wr[0] + df * 0.004, wr[3], ((REG[reg][0] + 32) / 256, (REG[reg][1] + 1) / 256)))
        rows = {s_[4]: REG[reg][1] + (1 - L[i]) * (REG[reg][3] - 1) for i, s_ in enumerate(spec)}
        rows.setdefault("fore", rows["fore"])
        self.meta["rows"][reg] = rows
        self.hand(side, Wr, df, J)

    def hand_v2(self, side, Wr, hd, fp=False):
        g = self.g
        s = g.get("hand_s", 1.3)
        sx = 1 if Wr[0] > 0 else -1
        pn = nrm(v3(-sx, 0, 0.2) - np.dot(v3(-sx, 0, 0.2), hd) * hd)
        wa = nrm(np.cross(hd, pn))
        M = np.column_stack([wa, hd, pn])
        if np.linalg.det(M) < 0:
            wa = -wa
            M = np.column_stack([wa, hd, pn])
        w = {side + "Hand": 1.0}
        rect = rr("hand")
        pl, pw, pt = 0.080 * s, 0.086 * s, 0.040 * s
        pc = Wr + hd * (pl / 2 + 0.002)
        self.m.box(pc, (pw, pl, pt), w, rect, M=M, taper=(1.06, 0.92))
        curl = math.radians(g.get("hand_curl", 28.0))
        lens = g.get("finger_len", (0.92, 1.0, 0.95, 0.76))
        fl = 0.050 * s
        fwd = pw / 4 * 0.86
        spread = g.get("finger_spread", 4.0)
        for k, ln in enumerate(lens):
            off = (k - 1.5) / 4 * pw * 0.98
            # index finger sits on the thumb side
            base = pc + hd * pl / 2 + wa * off * sx          # index finger on the thumb (front) side
            ang = math.radians(spread * (k - 1.5))
            dir0 = nrm(rot(pn, math.degrees(ang)) @ hd)
            pos = base
            for seg, frac in ((0, 0.55), (1, 0.45)):
                dirv = nrm(rot(wa, math.degrees(curl) * (0.55 if seg == 0 else 1.15)) @ dir0)
                L_ = fl * ln * frac * 2
                n2 = pn - np.dot(pn, dirv) * dirv
                Mf = np.column_stack([nrm(np.cross(dirv, n2)), dirv, nrm(n2)])
                if np.linalg.det(Mf) < 0:
                    Mf[:, 0] *= -1
                self.m.box(pos + dirv * L_ / 2, (fwd * (1.0 - 0.08 * seg), L_ + 0.004, pt * (0.72 - 0.08 * seg)), w, rect, M=Mf,
                           skip=("-y",) if seg else ())
                pos = pos + dirv * L_
        # thumb: two segments from the palm side near the wrist
        thumb_side = wa * (-sx)
        tdir = nrm(hd * 0.55 + thumb_side * 0.6 + pn * 0.5)
        pos = Wr + hd * 0.022 * s + thumb_side * pw * 0.40 + pn * pt * 0.25
        for seg, ln in ((0, 0.036 * s), (1, 0.032 * s)):
            dd = nrm(tdir + (hd * 0.35 + pn * 0.25) * seg)
            n2 = pn - np.dot(pn, dd) * dd
            Mt = np.column_stack([nrm(np.cross(dd, n2)), dd, nrm(n2)])
            if np.linalg.det(Mt) < 0:
                Mt[:, 0] *= -1
            self.m.box(pos + dd * ln / 2, (0.030 * s * (1 - 0.1 * seg), ln + 0.004, 0.028 * s), w, rect, M=Mt, skip=("-y",) if seg else ())
            pos = pos + dd * ln
        sock = pc + pn * (pt / 2 + 0.024) + hd * 0.012
        self.extra_nodes.append((side + "Hand_ItemSocket", side + "Hand", sock))

    def leg_v2(self, side, J):
        g = self.g
        pants = g["pants"]
        Hp, K, A = J[side + "UpperLeg"], J[side + "LowerLeg"], J[side + "Foot"]
        rt, rk, rc, ra = g.get("thigh_r", 0.085), g.get("knee_r", 0.062), g.get("calf_r", 0.063), g.get("ankle_r", 0.046)
        sh = g.get("shoe_h", 0.1)
        bot = v3(A[0], sh - 0.004, A[2] + 0.005)
        sc = pants.get("scale", (1.0, 1.0, 1.0, 1.0, 1.0, 1.0))
        U, Lo = side + "UpperLeg", side + "LowerLeg"
        spec = [
            (Hp + v3(0, 0.05, 0), rt * 1.04 * sc[0], blend(("Hips", 0.5), (U, 0.5)), "top"),
            (Hp + (K - Hp) * 0.22, rt * sc[1], {U: 1.0}, "thigh"),
            (Hp + (K - Hp) * 0.62, rt * 0.86 * sc[2], {U: 1.0}, "mid"),
            (K, rk * sc[3], blend((U, 0.5), (Lo, 0.5)), "knee"),
            (K + (bot - K) * 0.33, rc * sc[4], {Lo: 1.0}, "calf"),
            (K + (bot - K) * 0.80, ra * sc[5], {Lo: 1.0}, "ankle"),
        ]
        hem = pants.get("hem", 1.0)
        spec += [(bot + v3(0, 0.012, 0), ra * sc[5] * hem, blend((Lo, 0.85), (side + "Foot", 0.15)), "hem"),
                 (bot + v3(0, 0.010, 0), ra * 0.8, blend((Lo, 0.8), (side + "Foot", 0.2)), "hem_in")]
        rings = []
        for k, (p, r_, _, _) in enumerate(spec):
            dd = nrm(spec[min(k + 1, len(spec) - 1)][0] - spec[max(k - 1, 0)][0]) if k < len(spec) - 2 else v3(0, -1, 0)
            a, b = tube_frame(dd)
            rings.append(ring(p, a, b, r_ * 0.95, r_ * 0.88, 8, squash=0.9))
        reg = "leg_l" if side == "Left" else "leg_r"
        L = self.m.loft(rings, [s_[2] for s_ in spec], rr(reg))
        self.meta["rows"][reg] = {s_[3]: REG[reg][1] + (1 - L[i]) * 63 for i, s_ in enumerate(spec)}
        self.shoe(side, J)

    def shoe_v2(self, side, J):
        g = self.g
        A = J[side + "Foot"]
        sl, sw, sh = g.get("shoe_len", 0.30), g.get("shoe_w", 0.12), g.get("shoe_h", 0.10)
        sole = g.get("sole_h", 0.032)
        boot = g.get("boots", 0.0)
        sx = 1 if side == "Left" else -1
        yaw = math.radians(g.get("toe_out", 8.0)) * sx
        Ry = np.array([[math.cos(yaw), 0, math.sin(yaw)], [0, 1, 0], [-math.sin(yaw), 0, math.cos(yaw)]])
        piv = v3(A[0], 0, A[2])
        z0 = -0.07
        rear = sl * 0.56

        def P(local):
            return piv + Ry @ np.asarray(local, float)
        F, Tz = {side + "Foot": 1.0}, blend((side + "Toes", 0.8), (side + "Foot", 0.2))
        # sole slab (slightly bigger than the upper, two parts so the toe can bend)
        self.m.box(P((0.004 * sx, sole / 2, z0 + rear / 2 - 0.006)), (sw * 1.12, sole, rear + 0.012), F, rr("sole"), M=Ry)
        self.m.box(P((0.004 * sx, sole / 2 * 0.95, z0 + rear + (sl - rear) / 2 + 0.01)), (sw * 1.12, sole * 0.95, sl - rear + 0.02), Tz,
                   rr("sole"), M=Ry, taper=(0.92, 0.85))
        rect = rr("boot") if boot else rr("shoe")
        bh = sh - sole + boot
        self.m.box(P((0.0, sole + bh / 2, z0 + rear / 2)), (sw, bh, rear), F, rect, M=Ry, taper=(0.88, 0.86), skip=("-y",))
        self.m.box(P((0.0, sole + (sh - sole) * 0.38, z0 + rear + (sl - rear) / 2 - 0.004)), (sw * 1.0, (sh - sole) * 0.76, sl - rear + 0.01),
                   Tz, rect, M=Ry, taper=(0.86, 0.55), skip=("-y", "-z"))
        self.m.box(P((0.0, sole + (sh - sole) * 0.22, z0 + sl - 0.012)), (sw * 0.78, (sh - sole) * 0.44, 0.03), Tz, rect, M=Ry,
                   taper=(0.8, 0.7), skip=("-y", "-z"))

    def torso_ring_weight(self, nm, p, rx):
        side = "Left" if p[0] > 0 else "Right"
        lat = min(1.0, abs(p[0]) / max(rx, 1e-6))
        if nm == "crotch":
            return blend(("Hips", 0.55), (side + "UpperLeg", 0.45 * lat + 0.0001))
        if nm == "hip":
            return {"Hips": 1.0}
        if nm == "waist":
            return blend(("Hips", 0.5), ("Spine", 0.5))
        if nm == "belly":
            return {"Spine": 1.0}
        if nm == "chest":
            return blend(("Spine", 0.3), ("Chest", 0.7))
        if nm == "upper":
            return blend(("Chest", 0.3), ("UpperChest", 0.7 - 0.25 * lat ** 2), (side + "Shoulder", 0.25 * lat ** 2 + 0.0001))
        if nm == "shoulder":
            return blend(("UpperChest", 1.0 - 0.45 * lat ** 2), (side + "Shoulder", 0.45 * lat ** 2 + 0.0001))
        return blend(("UpperChest", 0.6), ("Neck", 0.4))

    def shell_jacket(self, gap=30.0, thick=0.022, hem=0.50, flare=0.03, collar=0.05, n=15, closed=False, region=None):
        """Jacket/hoodie volume over the torso. gap = front opening (deg); hem = reference-height fraction."""
        names = ["crotch", "hip", "waist", "belly", "chest", "upper", "shoulder", "neckbase"]
        tab = self.torso_table()
        g = math.radians(gap)
        ths = [g / 2 + (2 * math.pi - g) * j / (n - 1) for j in range(n)] if not closed else \
            [math.pi + 2 * math.pi * j / n for j in range(n)]
        hem_y = self.Y(hem)
        levels = [(hem_y, None)] + [(y, nm) for (y, *_), nm in zip(tab, names) if hem_y + 0.02 < y and nm not in ("crotch", "neckbase")]
        rings, ws = [], []
        # inner lip under the hem so the jacket edge shows thickness
        def ring_at(y, off_extra, nm):
            rx, rz, zc = self.torso_at(y)
            pts, wl = [], []
            for th in ths:
                p = self.torso_pt(y, th, thick + off_extra)
                pts.append(p)
                if nm is None:
                    # between named rings: weight like the nearest one
                    ys = [q[0] for q in tab]
                    k = int(np.argmin([abs(y - q) for q in ys]))
                    wl.append(self.torso_ring_weight(names[k], p, rx))
                else:
                    wl.append(self.torso_ring_weight(nm, p, rx))
            return np.array(pts), wl
        for k, (y, nm) in enumerate(levels):
            fl = flare * max(0.0, 1 - k / 2.5)
            if k == 0:
                r0, w0 = ring_at(y + 0.004, -thick + 0.004, nm)
                rings.append(r0)
                ws.append(w0)
            r_, w_ = ring_at(y, fl, nm)
            rings.append(r_)
            ws.append(w_)
        # close over the shoulders onto the neck, then a raised collar
        nr = self.g["neck_r"]
        J = self.J
        for (dy, rad, wt) in ((0.0, nr * 1.75, blend(("UpperChest", 0.75), ("Neck", 0.25))),
                              (collar, nr * 2.05, blend(("UpperChest", 0.55), ("Neck", 0.45)))):
            y = J["Neck"][1] + 0.004 + dy
            zc = J["Neck"][2] - 0.01
            pts = [v3(rad * math.sin(th), y, zc + rad * 1.05 * math.cos(th)) for th in ths]
            rings.append(np.array(pts))
            ws.append([wt] * len(ths))
        reg = region or ("fabric3" if self.c.get("skirt") else "jacket")
        L = self.m.loft(rings, ws, rr(reg), closed=closed)
        lv = ["lip"] + [nm or "hem" for _, nm in levels] + ["neck", "collar"]
        self.meta["rows"]["shell"] = {k: REG[reg][1] + (1 - L[i]) * (REG[reg][3] - 1) for i, k in enumerate(lv)}
        self.meta["shell"] = dict(gap=gap, closed=closed, region=reg)

    Body.head_table_v2 = head_table_v2
    Body.head_v2 = head_v2
    Body.arm_v2 = arm_v2
    Body.hand_v2 = hand_v2
    Body.leg_v2 = leg_v2
    Body.shoe_v2 = shoe_v2
    Body.torso_ring_weight = torso_ring_weight
    Body.shell_jacket = shell_jacket
