"""THE VEIL - Pack 07 / Creature 04: THE SKITTER (insectoid dimensional predator).

Insect-inspired, but neither beetle nor spider:
  * SIX zig-zag legs, far too long for the body: each leaves the thorax, drops to a LOW knee under the body line,
    climbs to a HIGH joint above it, then stabs down on a long needle tarsus - the legs read as "W" shapes and the
    body hangs low between them; the front-right leg is the longest and carries an extra spur;
  * a small segmented THORAX under uneven, overlapping chitin plates (a lopsided pronotum shield);
  * a two-segment ABDOMEN that curls up and to the right, with a pale luminous sac hanging underneath;
  * a tiny HEAD that is mostly a sensory cluster: seven pale bead eyes set asymmetrically, two long crossing
    pincer mandibles, four twitching palps;
  * two long whip ANTENNAE (the left one longer and forked near its tip).
About 0.65 m tall at the high joints, 2.1 m across the legs, 1.6 m from antenna tips to abdomen.
One material (M_Crt_Skitter, 256 px atlas, faint emission on the eyes and the sac).
"""
import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import cr_core as C  # noqa: E402
import cr_geo as G  # noqa: E402
import cr_tex as X  # noqa: E402
import cr_build as B  # noqa: E402
import cr_scenes as S  # noqa: E402

NAME = "CRT_Skitter"
FPS = 30
MAT = "M_Crt_Skitter"
LEGS = {  # parent, hip, low knee, high joint, needle contact, radii (hip, knee, high)
    "L1": ((-0.13, 0.30, 0.22), (-0.36, 0.10, 0.40), (-0.62, 0.58, 0.66), (-0.80, 0.0, 0.86), (0.045, 0.034, 0.03)),
    "R1": ((0.13, 0.30, 0.21), (0.38, 0.11, 0.38), (0.66, 0.62, 0.62), (0.84, 0.0, 0.80), (0.05, 0.036, 0.032)),
    "L2": ((-0.15, 0.30, 0.02), (-0.42, 0.08, 0.04), (-0.74, 0.60, 0.07), (-1.00, 0.0, 0.10), (0.045, 0.034, 0.03)),
    "R2": ((0.15, 0.30, 0.00), (0.40, 0.09, 0.00), (0.72, 0.56, 0.02), (0.96, 0.0, 0.04), (0.045, 0.034, 0.03)),
    "L3": ((-0.13, 0.30, -0.16), (-0.36, 0.09, -0.34), (-0.62, 0.56, -0.62), (-0.80, 0.0, -0.84), (0.042, 0.032, 0.028)),
    "R3": ((0.13, 0.30, -0.18), (0.34, 0.10, -0.34), (0.58, 0.52, -0.60), (0.74, 0.0, -0.80), (0.042, 0.032, 0.028)),
}
TRIPOD = {"L1": 0.0, "R2": 0.0, "L3": 0.0, "R1": 0.5, "L2": 0.5, "R3": 0.5}


def textures():
    at = X.Canvas(256, 256, seed="skitter")
    X.paint_hide(at.region(0, 0, 256, 256), "skitter_bg", base="crt_moss", accent="crt_violet", cracks=2, glow_cracks=0, scale=2)
    rg = {"plate": at.region(0, 0, 64, 64), "plate2": at.region(64, 0, 64, 64), "body": at.region(128, 0, 64, 64),
          "leg": at.region(192, 0, 32, 128), "needle": at.region(224, 0, 32, 64), "eye": at.region(224, 64, 32, 32),
          "sac": at.region(224, 96, 32, 32), "membrane": at.region(0, 64, 64, 32), "pincer": at.region(64, 64, 32, 64),
          "antenna": at.region(96, 64, 32, 128), "abdomen": at.region(128, 64, 64, 64)}
    X.paint_plate(rg["plate"], "skitter_plate", "crt_char", "crt_abyss", rings=6, seam_glow=0.12)
    X.paint_plate(rg["plate2"], "skitter_plate2", "crt_moss", "crt_char", rings=4)
    X.paint_hide(rg["body"], "skitter_body", base="crt_char", accent="crt_moss", cracks=2, glow_cracks=0, scale=2)
    X.paint_claw(rg["leg"], "skitter_leg", ramp="crt_moss")
    X.paint_claw(rg["needle"], "skitter_needle", ramp="crt_bone")
    X.paint_orb(rg["eye"], "skitter_eye", slit=False)
    X.paint_core(rg["sac"], "skitter_sac")
    X.paint_maw(rg["membrane"], "skitter_membrane", teeth_rows=0)
    X.paint_claw(rg["pincer"], "skitter_pincer", ramp="crt_bone")
    X.paint_tentacle(rg["antenna"], "skitter_antenna", base="crt_moss", back="crt_char", ridge_step=3, nodes=False)
    X.paint_plate(rg["abdomen"], "skitter_abdomen", "crt_violet", "crt_char", rings=7)
    out = (os.path.join(B.TEX, "T_Crt_Skitter.png"), os.path.join(B.TEX, "T_Crt_Skitter_Emit.png"))
    at.save(*out)
    return out, {k: r.uv() for k, r in rg.items()}


def build_rig():
    rig = C.Rig(NAME)
    rig.add("Root", None, (0, 0, 0))
    rig.add("Body", "Root", (0, 0.31, 0.02))
    rig.add("Head", "Body", (0, 0.31, 0.38), tip=(0, 0.28, 0.56))
    rig.add("Mandible_L", "Head", (-0.04, 0.27, 0.50), tip=(0.03, 0.21, 0.70))
    rig.add("Mandible_R", "Head", (0.04, 0.27, 0.50), tip=(-0.02, 0.23, 0.69))
    rig.chain(["Antenna_L_01", "Antenna_L_02", "Antenna_L_03"], "Head",
              [(-0.04, 0.36, 0.48), (-0.12, 0.50, 0.66), (-0.24, 0.58, 0.92), (-0.34, 0.50, 1.22)])
    rig.chain(["Antenna_R_01", "Antenna_R_02", "Antenna_R_03"], "Head",
              [(0.04, 0.36, 0.48), (0.11, 0.48, 0.62), (0.20, 0.53, 0.84), (0.26, 0.46, 1.04)])
    rig.chain(["Abdomen_01", "Abdomen_02"], "Body", [(0, 0.33, -0.20), (0.04, 0.36, -0.52), (0.16, 0.42, -0.80)])
    legs = {}
    for k, (h, kn, hi, c, _) in LEGS.items():
        b = [f"Leg_{k}_Upper", f"Leg_{k}_Lower", f"Leg_{k}_Foot"]
        rig.chain(b, "Body", [h, kn, hi, c])
        legs[k] = b
    return rig, legs


def build_mesh(rig, legs, uv):
    sm = C.SkinMesh()
    # thorax: three fused segments with constrictions
    Ct = G.resample([(0, 0.31, -0.22), (0, 0.31, -0.05), (0, 0.32, 0.15), (0, 0.31, 0.34)], 12)

    def tprof(i, s, th):
        seg = 1.0 - 0.16 * math.exp(-((s - 0.36) / 0.05) ** 2) - 0.14 * math.exp(-((s - 0.7) / 0.05) ** 2)
        return seg * (1.0 - 0.25 * max(0.0, -math.cos(th)) ** 2)
    G.sweep(sm, Ct, [(0.09, 0.13), (0.11, 0.15), (0.12, 0.16), (0.12, 0.16), (0.11, 0.15), (0.12, 0.17), (0.12, 0.17),
                     (0.11, 0.15), (0.12, 0.15), (0.11, 0.14), (0.09, 0.11), (0.06, 0.08)],
            lambda p, s: {"Body": 1.0}, uv["body"], n=10, prof=tprof, base_cap=True, tip=0.03, front=(0, -1, 0))
    # chitin plates (lopsided pronotum + segment plates)
    for c, sz, key, nv in (((0.02, 0.43, 0.22), (0.30, 0.04, 0.22), "plate", (0.15, 1, 0.1)),
                           ((-0.03, 0.44, 0.02), (0.26, 0.04, 0.2), "plate", (-0.1, 1, 0)),
                           ((0.0, 0.42, -0.16), (0.22, 0.04, 0.14), "plate2", (0, 1, -0.2)),
                           ((-0.11, 0.38, 0.12), (0.1, 0.03, 0.18), "plate2", (-0.8, 1, 0)),
                           ((0.12, 0.39, -0.02), (0.08, 0.03, 0.14), "plate2", (0.9, 1, 0))):
        G.plate(sm, c, sz, {"Body": 1.0}, uv[key], normal=nv, along=(0, 0.05, 1), taper=(0.75, 0.7))
    # abdomen: two segments curling up and to the right, with a hanging sac
    ab = [rig.J["Abdomen_01"], rig.J["Abdomen_02"], rig.tips["Abdomen_02"]]
    Ca = G.resample([np.array((0, 0.32, -0.12))] + ab, 12)
    Sa, _ = G.arclen(Ca)
    wa = G.chain_w([(0.0, "Body"), (0.12, "Abdomen_01"), (0.55, "Abdomen_02")], blend=0.08)
    ra = [0.1 + 0.07 * math.sin(math.pi * min(1.0, s * 1.3)) for s in Sa]

    def aprof(i, s, th):
        rings_ = 1.0 - 0.12 * max(0.0, math.cos(s * 9 * math.pi)) ** 6
        return rings_ * (1.0 - 0.2 * max(0.0, -math.cos(th)) ** 2)
    G.sweep(sm, Ca, [(r * 0.9, r * 1.05) for r in ra], wa, uv["abdomen"], n=10, prof=aprof, tip=0.05, front=(0, -1, 0))
    G.orb(sm, (0.03, 0.2, -0.5), 0.075, {"Abdomen_02": 0.7, "Abdomen_01": 0.3}, uv["sac"], n=7, m=4, axis=(0, -1, 0.3),
          squash=(1.0, 0.8, 1.3))
    # head: small sensory cluster
    Ch = G.resample([(0, 0.31, 0.32), (0, 0.32, 0.42), (0, 0.30, 0.50), (0, 0.28, 0.56)], 6)
    G.sweep(sm, Ch, [(0.06, 0.07), (0.07, 0.075), (0.065, 0.07), (0.055, 0.06), (0.04, 0.045), (0.02, 0.025)],
            lambda p, s: {"Head": 1.0}, uv["membrane"], n=8, tip=0.015, front=(0, -1, 0))
    for c, r in (((-0.045, 0.35, 0.47), 0.016), ((-0.06, 0.33, 0.43), 0.011), ((-0.03, 0.375, 0.42), 0.01), ((0.04, 0.36, 0.46), 0.019),
                 ((0.058, 0.335, 0.41), 0.01), ((0.02, 0.38, 0.49), 0.009), ((0.065, 0.31, 0.47), 0.008)):
        G.orb(sm, c, r, {"Head": 1.0}, uv["eye"], n=5, m=3, axis=C.nrm(np.array(c) - np.array((0, 0.31, 0.42))))
    for bn in ("Mandible_L", "Mandible_R"):
        h, tp = rig.J[bn], rig.tips[bn]
        side = -1 if bn.endswith("L") else 1
        mid = (h + tp) / 2 + np.array([side * 0.035, -0.01, 0])
        G.sweep(sm, G.resample([h, mid, tp], 6), [0.016, 0.015, 0.013, 0.01, 0.006, 0.003], lambda p, s, bn=bn: {bn: 1.0},
                uv["pincer"], n=4, tip=0.015, front=(0, -1, 0))
    for q, (dx, dz, ln) in enumerate(((-0.03, 0.0, 0.09), (-0.012, 0.02, 0.07), (0.015, 0.02, 0.08), (0.035, -0.01, 0.06))):
        p0 = np.array([dx, 0.25, 0.46 + dz])
        G.sweep(sm, G.resample([p0, p0 + np.array([dx * 0.4, -0.04, ln * 0.6]), p0 + np.array([dx * 0.8, -0.07, ln])], 4),
                [0.008, 0.007, 0.005, 0.003], lambda p, s: {"Head": 1.0}, uv["leg"], n=4, tip=0.01)
    # antennae (left one forked)
    for pre in ("Antenna_L", "Antenna_R"):
        bones = [f"{pre}_01", f"{pre}_02", f"{pre}_03"]
        pts = [rig.J[b] for b in bones] + [rig.tips[bones[-1]]]
        Cd = G.resample(pts, 14)
        B.tentacle_mesh(sm, Cd, bones, pts, 0.012, 0.003, uv["antenna"], n=4, ridge=0.25, parent="Head", ridges=18, flat=1.0)
        if pre == "Antenna_L":
            j = rig.J[bones[2]]
            fork = [j, j + np.array([-0.12, 0.06, 0.12]), j + np.array([-0.2, 0.0, 0.22])]
            G.sweep(sm, G.resample(fork, 6), [0.006, 0.005, 0.004, 0.003, 0.002, 0.0015], lambda p, s: {bones[2]: 1.0},
                    uv["antenna"], n=4, tip=0.01)
    # legs: zig-zag tubes, chitin knobs at the joints, needle tarsus
    for k, (h, kn, hi, c, (rh, rk, rhi)) in LEGS.items():
        b = legs[k]
        h, kn, hi, c = (np.array(v, float) for v in (h, kn, hi, c))
        inside = h - C.nrm(kn - h) * 0.06
        pts = [inside, h, kn, hi, hi + (c - hi) * 0.2]
        Cl = G.resample(G.round_corners(pts, [0, 0, rk * 1.8, rhi * 1.8, 0]), 16)
        St, _ = G.arclen(Cl)
        stops = G.stops_from_joints(Cl, [inside, h, kn, hi], ["Body", b[0], b[1], b[2]])
        wf = G.chain_w(stops, blend=0.1)
        sk, shi = stops[2][0], stops[3][0]

        def radius(sv, rh=rh, rk=rk, rhi=rhi, sk=sk, shi=shi):
            if sv < sk:
                return rh + (rk - rh) * sv / sk + 0.2 * rh * math.sin(math.pi * sv / sk)
            if sv < shi:
                q = (sv - sk) / (shi - sk)
                return rk + (rhi - rk) * q + 0.25 * rk * math.sin(math.pi * q)
            return rhi * 0.8
        G.sweep(sm, Cl, [radius(v) for v in St], wf, uv["leg"], n=6, prof=lambda i, sv, th: 1.0 + 0.12 * math.cos(2 * th),
                front=(0, 1, 0))
        G.orb(sm, kn + np.array([0, -0.005, 0]), rk * 1.25, {b[0]: 0.5, b[1]: 0.5}, uv["plate"], n=6, m=3)
        G.orb(sm, hi, rhi * 1.3, {b[1]: 0.5, b[2]: 0.5}, uv["plate"], n=6, m=3)
        needle = [hi, hi + (c - hi) * 0.5, c + np.array([0, 0.012, 0])]
        G.sweep(sm, G.resample(needle, 6), [rhi * 0.8, rhi * 0.7, rhi * 0.55, rhi * 0.4, rhi * 0.25, rhi * 0.12],
                lambda p, sv, bb=b[2]: {bb: 1.0}, uv["needle"], n=5, tip=0.01, front=(0, 0, 1))
        if k == "R1":
            sp = [hi, hi + np.array([0.04, 0.09, 0.03]), hi + np.array([0.05, 0.16, -0.02])]
            G.sweep(sm, G.resample(sp, 4), [0.016, 0.012, 0.007, 0.003], lambda p, sv, bb=b[2]: {bb: 1.0}, uv["needle"], n=4,
                    tip=0.02)
    return {MAT: sm}


def pose_factory(rig, legs):
    contact = {k: rig.tips[legs[k][2]] for k in legs}
    ant = {"L": ["Antenna_L_01", "Antenna_L_02", "Antenna_L_03"], "R": ["Antenna_R_01", "Antenna_R_02", "Antenna_R_03"]}
    abd = ["Abdomen_01", "Abdomen_02"]

    def tw(t, t0, d=0.08):
        """abrupt twitch: snaps in over 1-2 frames, decays fast"""
        if t < t0:
            return 0.0
        x = (t - t0) / d
        return math.exp(-x) * min(1.0, x * 4) if x < 8 else 0.0

    def head_bits(local, t, ant_amt=1.0, mand=0.0, period=None):
        f = B.cyc(0.9, period)
        for side, bones in ant.items():
            sg = -1 if side == "L" else 1
            for q, b in enumerate(bones):
                local[b] = local.get(b, C.I3) @ C.R((1, 0, 0), ant_amt * 7 * math.sin(2 * math.pi * f * t + q + (sg > 0)))
        local["Mandible_L"] = C.R((0, 1, 0), -mand)
        local["Mandible_R"] = C.R((0, 1, 0), mand)
        return local

    def idle(t):
        T = 3.0
        local, trans = {}, {}
        twitches = [(0.4, "Head", (0, 1, 0), 9), (0.9, "Antenna_L_01", (1, 0, 0), -24), (1.35, "Antenna_R_02", (0, 1, 0), 20),
                    (1.9, "Body", (0, 0, 1), 4), (2.3, "Head", (1, 0, 0), -10), (2.55, "Antenna_L_02", (0, 1, 0), -18)]
        head_bits(local, t, ant_amt=0.4, mand=4 + 10 * tw(t, 1.1) + 8 * tw(t, 2.0), period=T)
        for t0, b, ax, deg in twitches:
            local[b] = local.get(b, C.I3) @ C.R(ax, deg * tw(t, t0))
        trans["Body"] = (0, 0.008 * math.sin(2 * math.pi * t / T), 0)
        local["Abdomen_01"] = C.R((1, 0, 0), 2.0 * math.sin(2 * math.pi * t / T))
        tg = {k: contact[k].copy() for k in legs}
        for t0, k in ((0.6, "R1"), (1.6, "L2"), (2.1, "L1")):
            e = tw(t, t0, 0.06)
            tg[k][1] += 0.06 * e
        B.legs_ik(rig, legs, local, trans, tg)
        return local, trans

    def gait(t, T, SL, duty, lift, jitter=0.0, bob=0.012):
        local, trans = {}, {}
        ph = 2 * math.pi * t / T
        trans["Body"] = (0.008 * math.sin(ph), bob * math.cos(2 * ph), 0)
        local["Body"] = C.R((0, 1, 0), 2.5 * math.sin(ph) + jitter * math.sin(3 * ph + 1)) @ C.R((0, 0, 1), 2 * math.sin(ph))
        local["Abdomen_01"] = C.R((0, 1, 0), -4 * math.sin(ph - 0.5))
        local["Abdomen_02"] = C.R((0, 1, 0), -5 * math.sin(ph - 1.0))
        local["Head"] = C.R((0, 1, 0), -2 * math.sin(ph) + jitter * 1.5 * math.sin(5 * ph))
        head_bits(local, t, ant_amt=1.0, mand=3, period=T)
        tg, fr = B.gait_targets(contact, t, T, SL, duty, TRIPOD, lift, pitch=0.0)
        B.legs_ik(rig, legs, local, trans, tg, fr)
        return local, trans

    CRAWL = dict(T=1.2, SL=0.34, duty=0.6, lift=0.09)
    SCUTTLE = dict(T=0.34, SL=0.44, duty=0.5, lift=0.07, jitter=5.0, bob=0.006)

    def crawl(t):
        return gait(t, **CRAWL)

    def scuttle(t):
        return gait(t, **SCUTTLE)

    def alert(t):
        a = C.ease(t, 0.0, 0.14)
        local, trans = {}, {}
        trans["Body"] = (0, 0.05 * a, -0.03 * a)
        local["Body"] = C.R((1, 0, 0), -14 * a)
        local["Head"] = C.R((1, 0, 0), 6 * a) @ C.R((0, 1, 0), 10 * tw(t, 0.5) - 12 * tw(t, 0.85))
        head_bits(local, t, ant_amt=0.3, mand=4 + 16 * a)
        for side, bones in ant.items():
            sg = -1 if side == "L" else 1
            local[bones[0]] = local[bones[0]] @ C.R((0, 1, 0), -sg * 14 * a) @ C.R((1, 0, 0), -14 * a)
        local["Abdomen_01"] = C.R((1, 0, 0), -12 * a)
        tg = {k: contact[k].copy() for k in legs}
        for k in ("L1", "R1"):
            tg[k] += np.array([0.03 * (1 if k[0] == "R" else -1), 0.22 * a, 0.06 * a])
        B.legs_ik(rig, legs, local, trans, tg, {k: C.R((1, 0, 0), -30 * a) for k in ("L1", "R1")})
        return local, trans

    def lunge(t):
        cr = C.pulse(t, 0.0, 0.18, 0.2, 0.28)
        lg = C.pulse(t, 0.22, 0.34, 0.5, 0.95)
        stab = C.pulse(t, 0.24, 0.36, 0.45, 0.7)
        local, trans = {}, {}
        trans["Body"] = (0, -0.06 * cr + 0.04 * lg, -0.04 * cr + 0.42 * lg)
        local["Body"] = C.R((1, 0, 0), 4 * cr - 10 * lg)
        local["Abdomen_01"] = C.R((1, 0, 0), -14 * lg)
        head_bits(local, t, ant_amt=0.3, mand=4 + 24 * C.pulse(t, 0.15, 0.3, 0.38, 0.42))
        tg = {k: contact[k].copy() for k in legs}
        for k in legs:
            if k in ("L1", "R1"):
                tg[k] += np.array([0, 0.18 * stab, 0.48 * lg + 0.12 * stab])
            elif k in ("L2", "R2"):
                tg[k] += np.array([0, 0.05 * math.sin(math.pi * C.ease(t, 0.3, 0.5)), 0.38 * C.ease(t, 0.3, 0.5) * (1 - C.ease(t, 0.6, 0.95))])
            else:
                tg[k] += np.array([0, 0.05 * math.sin(math.pi * C.ease(t, 0.4, 0.6)), 0.3 * C.ease(t, 0.4, 0.6) * (1 - C.ease(t, 0.65, 0.95))])
        B.legs_ik(rig, legs, local, trans, tg, {k: C.R((1, 0, 0), -45 * stab) for k in ("L1", "R1")})
        return local, trans

    def hit(t):
        j = C.pulse(t, 0.0, 0.04, 0.08, 0.5)
        sh = math.sin(t * 2 * math.pi * 11) * math.exp(-t * 9)
        local, trans = {}, {}
        trans["Body"] = (0.07 * j, -0.03 * j, -0.03 * j)
        local["Body"] = C.R((0, 0, 1), -9 * j + 3 * sh) @ C.R((0, 1, 0), 12 * j)
        local["Head"] = C.R((0, 1, 0), -18 * j) @ C.R((1, 0, 0), -10 * j)
        head_bits(local, t, ant_amt=0.2, mand=20 * j)
        for side, bones in ant.items():
            B.curl(rig, local, bones, [25 * j] * 3)
        tg = {k: contact[k] * np.array([1.0 + 0.12 * j, 1, 1.0 + 0.05 * j]) for k in legs}
        B.legs_ik(rig, legs, local, trans, tg)
        return local, trans

    def death(t):
        sp = C.pulse(t, 0.0, 0.08, 0.15, 0.4)
        dn = C.ease(t, 0.2, 0.7)
        cu = C.ease(t, 0.35, 1.3)
        local, trans = {}, {}
        trans["Body"] = (0.03 * sp, -0.13 * dn, 0)
        local["Body"] = C.R((0, 0, 1), 7 * sp + 5 * dn)
        local["Head"] = C.R((1, 0, 0), 18 * dn)
        local["Abdomen_01"] = C.R((1, 0, 0), 10 * dn)
        head_bits(local, t * (1 - cu), ant_amt=1 - cu, mand=22 * sp + 8 * cu)
        for side, bones in ant.items():
            B.curl(rig, local, bones, [-6 * cu, 12 * cu, 18 * cu])
        tg = {k: contact[k] * np.array([1.0 + 0.1 * dn, 1, 1.0 + 0.06 * dn]) for k in legs}
        B.legs_ik(rig, legs, local, trans, tg)
        # legs curl in toward the body (the dead-insect fold), released from the ground
        for k, b in legs.items():
            B.curl(rig, local, b, [22 * cu, 34 * cu, 55 * cu])
            local = B.floor_clamp(rig, local, trans, b, 0.03, step=3.0, rad=[0.04, 0.035, 0.03, 0.005])
        for side, bones in ant.items():
            local = B.floor_clamp(rig, local, trans, bones, 0.02, step=3.0, rad=[0.01] * 4)
        return local, trans

    clips = [("Idle_Twitch", idle, 3.0, True), ("Crawl", crawl, CRAWL["T"], True), ("Scuttle_Fast", scuttle, SCUTTLE["T"], True),
             ("Alert", alert, 1.2, False), ("Attack_Lunge", lunge, 1.0, False), ("Hit_React", hit, 0.6, False),
             ("Death", death, 1.6, False)]
    loco = {"crawl_speed_mps": round(CRAWL["SL"] / (CRAWL["T"] * CRAWL["duty"]), 3),
            "scuttle_speed_mps": round(SCUTTLE["SL"] / (SCUTTLE["T"] * SCUTTLE["duty"]), 3)}
    return clips, loco


def build():
    png, uv = textures()
    rig, legs = build_rig()
    meshes = build_mesh(rig, legs, uv)
    clip_defs, loco = pose_factory(rig, legs)
    clips, frames = [], {}
    for nm, fn, dur, loop in clip_defs:
        c, fr = C.bake(rig, nm, fn, dur, FPS, loop)
        clips.append(c)
        frames[nm] = fr
    mats = {MAT: dict(albedo=png[0], emit=png[1], emit_factor=(0.6, 0.66, 0.7), emit_energy=0.7, repeat=False, rough=0.6)}
    sockets = [("Socket_Head", "Head", (0, 0.33, 0.5)), ("Socket_Sac", "Abdomen_02", (0.03, 0.2, -0.5))]
    extras = {"veil_creature": "Skitter", "faces": "+Z", "units": "m", "locomotion": loco, "legs": legs}
    glb, tris = B.export(NAME, "Skitter", rig, meshes, mats, sockets, clips, extras)
    scene = os.path.join(C.CR, "Godot_Scenes", "CRT_Skitter.tscn")
    S.creature_scene(scene, "Skitter", glb,
                     shapes=[("BodyShape", "BoxShape3D", {"size": (0.42, 0.3, 1.25)}, (0, 0.32, -0.15)),
                             ("LegSpan", "BoxShape3D", {"size": (1.9, 0.45, 1.6)}, (0.0, 0.32, 0.02))],
                     markers=[("LookTarget", (0, 0.34, 0.5)), ("LungeReach", (0, 0.3, 1.25))],
                     meta={"veil_creature": "Skitter", "faces": "+Z", "animation_player": "Model/AnimationPlayer",
                           "animations": [c.name for c in clips], "crawl_speed_mps": loco["crawl_speed_mps"],
                           "scuttle_speed_mps": loco["scuttle_speed_mps"]})
    return dict(name=NAME, glb=glb, tris=tris, rig=rig, legs=legs, clips=clips, frames=frames, meshes=meshes, mats=mats,
                sockets=sockets, feet=[v[2] for v in legs.values()], edge_floor=0.015, probe="Leg_R1_Foot",
                scene=os.path.relpath(scene, C.V2).replace(os.sep, "/"),
                limits={"max_stretch": 2.0, "max_stretch_death": 2.2, "p999_stretch": 1.6, "p999_stretch_death": 1.75,
                        "min_y": -0.03})


if __name__ == "__main__":
    r = build()
    print(r["glb"], r["tris"])
