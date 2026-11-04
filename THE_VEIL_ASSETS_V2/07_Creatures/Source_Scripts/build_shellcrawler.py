"""THE VEIL - Pack 07 / Creature 05: THE SHELLCRAWLER (armoured crustacean-like dimensional entity).

Crustacean-inspired, but not a crab:
  * a broad, low, ASYMMETRIC faceted shell (wider and heavier on the left) built from overlapping irregular plates
    with faint luminous seams; a cluster of angular crystalline SHARDS juts from the rear-left - geometry that does
    not look grown;
  * three OPENINGS in the shell top look down into a dim, pale internal cavity;
  * EIGHT walking legs of unequal size (three heavy + one small on the left, four medium on the right) emerge from
    under the rim; their knees stay below the shell line, they end in single bone points and work sideways or
    forwards;
  * two unlike GRASPING appendages: a long left arm ending in a three-fingered hooked hand, and a small right arm
    ending in a single sickle;
  * a recessed front SENSORY FACE under the shell lip: a vertical stack of five pale ring organs of different sizes,
    set off-centre, fringed by short feelers. No eyes on stalks, no mouthparts of a crab.
About 2.2 m wide, 1.2 m tall at the shell crest, 3.6 m across the legs. One material (M_Crt_Shellcrawler, 256 px atlas,
faint emission on the seams, the ring organs and the cavity).
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

NAME = "CRT_Shellcrawler"
FPS = 30
MAT = "M_Crt_Shellcrawler"
LEGS = {  # hip, knee, ankle, contact, radii (hip, knee, ankle)
    "LA": ((-0.75, 0.45, 0.38), (-1.25, 0.62, 0.62), (-1.55, 0.25, 0.75), (-1.62, 0.0, 0.80), (0.085, 0.065, 0.045)),
    "LB": ((-0.90, 0.45, 0.12), (-1.45, 0.66, 0.20), (-1.80, 0.24, 0.25), (-1.88, 0.0, 0.27), (0.09, 0.07, 0.048)),
    "LC": ((-0.85, 0.45, -0.18), (-1.38, 0.64, -0.30), (-1.72, 0.22, -0.42), (-1.80, 0.0, -0.45), (0.085, 0.065, 0.045)),
    "LD": ((-0.60, 0.45, -0.45), (-0.95, 0.50, -0.75), (-1.15, 0.18, -0.90), (-1.20, 0.0, -0.95), (0.06, 0.045, 0.032)),
    "RA": ((0.70, 0.45, 0.36), (1.10, 0.60, 0.60), (1.38, 0.22, 0.70), (1.44, 0.0, 0.74), (0.07, 0.055, 0.04)),
    "RB": ((0.82, 0.45, 0.10), (1.30, 0.62, 0.16), (1.62, 0.22, 0.20), (1.70, 0.0, 0.22), (0.075, 0.058, 0.04)),
    "RC": ((0.80, 0.45, -0.18), (1.28, 0.60, -0.30), (1.58, 0.22, -0.38), (1.65, 0.0, -0.41), (0.075, 0.058, 0.04)),
    "RD": ((0.62, 0.45, -0.45), (1.00, 0.58, -0.70), (1.28, 0.20, -0.86), (1.34, 0.0, -0.90), (0.07, 0.055, 0.04)),
}
PHASE = {"LA": 0.0, "LC": 0.0, "RB": 0.0, "RD": 0.0, "LB": 0.5, "LD": 0.5, "RA": 0.5, "RC": 0.5}
FINGERS = {"GraspL_F1": ((-0.50, 0.30, 1.42), (-0.62, 0.19, 1.57)), "GraspL_F2": ((-0.42, 0.30, 1.45), (-0.42, 0.18, 1.64)),
           "GraspL_F3": ((-0.33, 0.31, 1.42), (-0.22, 0.20, 1.56))}


def textures():
    at = X.Canvas(256, 256, seed="shell")
    X.paint_hide(at.region(0, 0, 256, 256), "shell_bg", base="crt_char", accent="crt_violet", cracks=3, glow_cracks=0, scale=2)
    rg = {"shell": at.region(0, 0, 128, 64), "plate": at.region(128, 0, 64, 64), "plate2": at.region(192, 0, 64, 64),
          "under": at.region(0, 64, 64, 64), "leg": at.region(64, 64, 32, 128), "point": at.region(96, 64, 32, 64),
          "bone": at.region(96, 128, 32, 64), "ring": at.region(128, 64, 32, 32), "ring_dim": at.region(160, 64, 32, 32),
          "core": at.region(192, 64, 64, 64), "shard": at.region(128, 128, 64, 64), "feeler": at.region(192, 128, 32, 64),
          "hole": at.region(0, 128, 64, 32)}
    X.paint_hide(rg["shell"], "shell_top", base="crt_char", accent="crt_abyss", cracks=4, glow_cracks=1, scale=2)
    X.paint_plate(rg["plate"], "shell_plate", "crt_char", "crt_abyss", rings=6, seam_glow=0.3)
    X.paint_plate(rg["plate2"], "shell_plate2", "crt_violet", "crt_char", rings=5, seam_glow=0.15)
    X.paint_maw(rg["under"], "shell_under", teeth_rows=0)
    X.paint_claw(rg["leg"], "shell_leg", ramp="crt_char")
    X.paint_claw(rg["point"], "shell_point", ramp="crt_bone")
    X.paint_claw(rg["bone"], "shell_bone", ramp="crt_bone")
    X.paint_orb(rg["ring"], "shell_ring", slit=False)
    X.paint_orb(rg["ring_dim"], "shell_ring_dim", iris="crt_violet", glow=False, slit=True)
    X.paint_core(rg["core"], "shell_core")
    X.paint_plate(rg["shard"], "shell_shard", "crt_bone", "crt_violet", rings=2, seam_glow=0.2)
    X.paint_tentacle(rg["feeler"], "shell_feeler", base="crt_flesh", back="crt_violet", ridge_step=3, nodes=False)
    X.paint_maw(rg["hole"], "shell_hole", teeth_rows=1)
    out = (os.path.join(B.TEX, "T_Crt_Shellcrawler.png"), os.path.join(B.TEX, "T_Crt_Shellcrawler_Emit.png"))
    at.save(*out)
    return out, {k: r.uv() for k, r in rg.items()}


def build_rig():
    rig = C.Rig(NAME)
    rig.add("Root", None, (0, 0, 0))
    rig.add("Body", "Root", (0, 0.6, 0))
    rig.add("Shell", "Body", (0, 0.85, -0.05))
    rig.add("Sensor", "Body", (0, 0.55, 0.72), tip=(0, 0.5, 0.86))
    rig.chain(["GraspL_Upper", "GraspL_Lower", "GraspL_Hand"], "Body",
              [(-0.35, 0.45, 0.62), (-0.62, 0.62, 1.05), (-0.42, 0.38, 1.35), (-0.42, 0.30, 1.45)])
    for f, (a, b) in FINGERS.items():
        rig.add(f, "GraspL_Hand", a, tip=b)
    rig.chain(["GraspR_Upper", "GraspR_Lower", "GraspR_Sickle"], "Body",
              [(0.32, 0.42, 0.60), (0.50, 0.52, 0.90), (0.36, 0.32, 1.10), (0.18, 0.18, 1.22)])
    legs = {}
    for k, (h, kn, an, c, _) in LEGS.items():
        b = [f"Leg_{k}_Upper", f"Leg_{k}_Lower", f"Leg_{k}_Foot"]
        rig.chain(b, "Body", [h, kn, an, c])
        legs[k] = b
    return rig, legs


def shell_w(p, s=None):
    t = C.smooth((p[1] - 0.62) / 0.35)
    return {"Body": 1 - t, "Shell": t} if t > 0 else {"Body": 1.0}


def build_mesh(rig, legs, uv):
    sm = C.SkinMesh()
    # shell: swept across the body (x), faceted, flattened underneath, heavier on the left
    Cx = G.resample([(-1.12, 0.6, -0.04), (-0.7, 0.64, 0.0), (0.0, 0.64, 0.02), (0.6, 0.62, 0.0), (1.02, 0.58, -0.03)], 14)
    Rx = G.resample([np.array(r) for r in [(0.14, 0.34), (0.45, 0.72), (0.54, 0.8), (0.44, 0.7), (0.12, 0.3)]], 14)

    def sprof(i, s, th):
        under = 1.0 - 0.45 * max(0.0, -math.cos(th)) ** 1.2
        facet = 1.0 + 0.09 * abs(math.sin(3 * th + s * 4.0)) - 0.05 * abs(math.sin(5 * th - s * 7.0))
        lip = 1.0 + 0.12 * math.exp(-((th - math.pi / 2) / 0.35) ** 2)          # overhanging front lip
        return under * facet * lip
    rings = G.sweep(sm, Cx, [tuple(r) for r in Rx], shell_w, uv["shell"], n=12, prof=sprof, tip=0.05, base_cap=True,
                    front=(0, -1, 0))
    # underside plate (soft belly, darker)
    G.orb(sm, (0, 0.38, 0.0), 0.62, {"Body": 1.0}, uv["under"], n=10, m=4, axis=(0, 1, 0), squash=(1.45, 1.0, 0.18))
    # overlapping irregular plates with luminous seams
    rng = np.random.default_rng(7)
    picks = [(2, 1), (3, 0), (3, 11), (4, 2), (5, 1), (5, 11), (6, 0), (6, 2), (7, 11), (8, 1), (8, 10), (9, 0), (9, 2),
             (10, 1), (11, 11), (4, 10), (7, 3), (10, 3)]
    for q, (i, j) in enumerate(picks):
        p = rings[i][j]
        nv = C.nrm(p - rings[i].mean(0))
        sz = (0.3 + 0.25 * rng.random(), 0.05, 0.28 + 0.2 * rng.random())
        G.plate(sm, p + nv * 0.02, sz, shell_w(p), uv["plate" if q % 3 else "plate2"], normal=nv,
                along=(rng.uniform(-0.4, 0.4), 0, 1), taper=(0.55 + 0.2 * rng.random(), 0.6))
    # crystalline shards (rear-left)
    for q, (x, z, h, lean) in enumerate(((-0.55, -0.35, 0.42, 0.25), (-0.42, -0.42, 0.3, -0.1), (-0.7, -0.22, 0.26, 0.4),
                                         (-0.32, -0.28, 0.2, 0.1), (-0.62, -0.5, 0.18, -0.3))):
        base = np.array([x, 1.0 - 0.1 * abs(x + 0.5), z])
        up = C.nrm(np.array([lean * 0.4 - 0.15, 1.0, -0.25]))
        M = G.basis((0, 0, 1), up)              # box y axis ~ shard axis
        sm.box(base + M[:, 1] * h / 2, (0.07 + 0.02 * (q % 2), h, 0.06), {"Shell": 1.0}, uv["shard"], M=M, taper=(0.25, 0.35))
    # openings into the internal cavity: dark rims + a dim pale core seen through them
    for c, r, ang in (((0.25, 1.12, 0.05), 0.11, 0.2), ((0.45, 1.06, -0.18), 0.08, -0.5), ((0.05, 1.12, -0.25), 0.07, 0.9)):
        G.orb(sm, c, r, {"Shell": 1.0}, uv["hole"], n=8, m=3, axis=(0.1, 1, 0.05), squash=(1.0, 0.55, 0.25))
        G.orb(sm, np.array(c) - np.array([0, 0.03, 0]), r * 0.62, {"Shell": 1.0}, uv["core"], n=6, m=3, axis=(0, 1, 0),
              squash=(1.0, 0.6, 0.35))
    # sensory face: recessed dark plate + vertical stack of ring organs + fringe feelers
    G.orb(sm, (0.03, 0.55, 0.74), 0.2, {"Sensor": 1.0}, uv["under"], n=8, m=4, axis=(0, 0, 1), squash=(1.1, 1.3, 0.35))
    for q, (dx, y, r) in enumerate(((0.06, 0.70, 0.04), (0.03, 0.63, 0.055), (0.07, 0.55, 0.035), (0.02, 0.48, 0.045),
                                    (0.08, 0.42, 0.025))):
        G.orb(sm, (dx, y, 0.81), r, {"Sensor": 1.0}, uv["ring" if q % 2 == 0 else "ring_dim"], n=6, m=3, axis=(0, 0, 1),
              squash=(1.0, 1.0, 0.6))
    for q, (dx, y) in enumerate(((-0.12, 0.47), (-0.08, 0.40), (0.13, 0.45), (0.17, 0.52))):
        p0 = np.array([dx, y, 0.8])
        G.sweep(sm, G.resample([p0, p0 + np.array([dx * 0.3, -0.06, 0.08]), p0 + np.array([dx * 0.5, -0.14, 0.1])], 4),
                [0.014, 0.011, 0.007, 0.003], lambda p, s: {"Sensor": 1.0}, uv["feeler"], n=4, tip=0.02)
    # grasping appendages
    for pre, rads in (("GraspL", (0.085, 0.07, 0.05)), ("GraspR", (0.06, 0.045, 0.032))):
        bones = [f"{pre}_Upper", f"{pre}_Lower", f"{pre}_Hand" if pre == "GraspL" else f"{pre}_Sickle"]
        pts = [rig.J[b] for b in bones] + [rig.tips[bones[-1]]]
        inside = pts[0] - C.nrm(pts[1] - pts[0]) * 0.08
        path = [inside] + pts if pre == "GraspL" else [inside] + pts[:3]
        Cl = G.resample(G.round_corners(path, [0, 0, rads[1] * 1.6, rads[2] * 1.4] + [0] * (len(path) - 4)), 14)
        St, _ = G.arclen(Cl)
        stops = G.stops_from_joints(Cl, [inside] + pts[:3], ["Body"] + bones)
        wf = G.chain_w(stops, blend=0.1)
        rr = [rads[0] * (1 - s) + rads[2] * s + 0.25 * rads[0] * math.sin(math.pi * min(1, s * 2)) for s in St]
        G.sweep(sm, Cl, rr, wf, uv["leg"], n=7, prof=lambda i, s, th: 1.0 + 0.1 * math.cos(3 * th), front=(0, 1, 0))
        G.orb(sm, pts[1], rads[1] * 1.3, {bones[0]: 0.5, bones[1]: 0.5}, uv["plate"], n=6, m=3)
        if pre == "GraspR":
            sk = [pts[2], pts[2] + (pts[3] - pts[2]) * 0.5 + np.array([0.03, 0.04, 0.03]), pts[3]]
            G.sweep(sm, G.resample(sk, 6), [0.035, 0.03, 0.024, 0.017, 0.01, 0.004], lambda p, s: {"GraspR_Sickle": 1.0},
                    uv["bone"], n=5, tip=0.04, front=(0, 1, 0))
    for f, (a, b) in FINGERS.items():
        a, b = np.array(a), np.array(b)
        hook = [a, (a + b) / 2 + np.array([0, 0.02, 0.04]), b]
        G.sweep(sm, G.resample(hook, 5), [0.028, 0.024, 0.018, 0.011, 0.005], lambda p, s, f=f: {f: 1.0}, uv["bone"], n=5,
                tip=0.03, front=(0, -1, 0))
    # legs
    for k, (h, kn, an, c, (rh, rk, ra)) in LEGS.items():
        b = legs[k]
        h, kn, an, c = (np.array(v, float) for v in (h, kn, an, c))
        inside = h - C.nrm(kn - h) * 0.1
        pts = [inside, h, kn, an, an + (c - an) * 0.35]
        Cl = G.resample(G.round_corners(pts, [0, 0, rk * 1.7, ra * 1.6, 0]), 14)
        St, _ = G.arclen(Cl)
        stops = G.stops_from_joints(Cl, [inside, h, kn, an], ["Body", b[0], b[1], b[2]])
        wf = G.chain_w(stops, blend=0.1)
        sk, sa = stops[2][0], stops[3][0]

        def radius(sv, rh=rh, rk=rk, ra=ra, sk=sk, sa=sa):
            if sv < sk:
                return rh + (rk - rh) * sv / sk + 0.15 * rh * math.sin(math.pi * sv / sk)
            if sv < sa:
                return rk + (ra - rk) * (sv - sk) / (sa - sk)
            return ra
        G.sweep(sm, Cl, [radius(v) for v in St], wf, uv["leg"], n=6, prof=lambda i, sv, th: 1.0 + 0.14 * abs(math.cos(1.5 * th)),
                front=(0, 1, 0))
        G.plate(sm, kn + np.array([0, rk * 0.8, 0]), (rk * 2.4, rk * 0.5, rk * 3.0), {b[0]: 0.5, b[1]: 0.5}, uv["plate"],
                normal=(0, 1, 0), along=C.nrm(an - h), taper=(0.6, 0.6))
        point = [an, an + (c - an) * 0.55, c + np.array([0, 0.012, 0])]
        G.sweep(sm, G.resample(point, 5), [ra * 1.05, ra * 0.85, ra * 0.6, ra * 0.35, ra * 0.12], lambda p, sv, bb=b[2]: {bb: 1.0},
                uv["point"], n=5, tip=0.01, front=(0, 0, 1))
    return {MAT: sm}


def pose_factory(rig, legs):
    contact = {k: rig.tips[legs[k][2]] for k in legs}
    fingers = list(FINGERS)

    def guard(local, trans, floor=0.04):
        for ch in (["GraspL_Upper", "GraspL_Lower", "GraspL_Hand"], ["GraspR_Upper", "GraspR_Lower", "GraspR_Sickle"]):
            local = B.floor_clamp(rig, local, trans, ch, floor, step=2.0, rad=[0.08, 0.06, 0.05, 0.05])
        for fn in fingers:
            local = B.floor_clamp(rig, local, trans, [fn], floor, step=3.0, rad=[0.03, 0.03])
        return local

    def arms(local, grip=0.0, fold=0.0, t=0.0, period=None, idle_amt=1.0):
        f = B.cyc(0.5, period)
        sway = idle_amt * math.sin(2 * math.pi * f * t)
        local["GraspL_Upper"] = local.get("GraspL_Upper", C.I3) @ C.R((0, 1, 0), 4 * sway - 25 * fold) @ C.R((1, 0, 0), -20 * fold)
        local["GraspL_Lower"] = local.get("GraspL_Lower", C.I3) @ C.R((1, 0, 0), -35 * fold + 3 * sway)
        local["GraspR_Upper"] = local.get("GraspR_Upper", C.I3) @ C.R((0, 1, 0), -3 * sway + 25 * fold) @ C.R((1, 0, 0), -18 * fold)
        local["GraspR_Lower"] = local.get("GraspR_Lower", C.I3) @ C.R((1, 0, 0), -30 * fold)
        local["GraspR_Sickle"] = local.get("GraspR_Sickle", C.I3) @ C.R((1, 0, 0), 8 * sway * idle_amt + 20 * grip)
        for q, fn in enumerate(fingers):
            local[fn] = local.get(fn, C.I3) @ C.R((1, 0, 0), 30 * grip + 6 * idle_amt * math.sin(2 * math.pi * f * t + q))
        return local

    def idle(t):
        T = 3.0
        ph = 2 * math.pi * t / T
        local, trans = {}, {}
        trans["Body"] = (0, 0.012 * math.sin(ph), 0)
        local["Shell"] = C.R((0, 0, 1), 1.2 * math.sin(ph + 0.5)) @ C.R((1, 0, 0), 0.8 * math.sin(ph))
        local["Sensor"] = C.R((0, 1, 0), 5 * math.sin(ph * 2)) @ C.R((1, 0, 0), 3 * math.sin(ph + 1))
        arms(local, grip=0.15 + 0.15 * math.sin(ph), t=t, period=T)
        B.legs_ik(rig, legs, local, trans, {})
        return guard(local, trans), trans

    def crawl(t, T, SL, duty, direction, lift):
        ph = 2 * math.pi * t / T
        local, trans = {}, {}
        side = abs(direction[0]) > 0.5
        trans["Body"] = (0.015 * math.sin(2 * ph) if not side else 0.0, 0.014 * math.cos(2 * ph), 0.0 if not side else 0.012 * math.sin(2 * ph))
        local["Body"] = C.R((0, 0, 1), (3.0 if side else 1.5) * math.sin(ph)) @ C.R((1, 0, 0), (1.0 if side else 2.5) * math.sin(ph + 0.7))
        local["Shell"] = C.R((0, 0, 1), -1.5 * math.sin(ph - 0.6))
        local["Sensor"] = C.R((0, 1, 0), 6 * math.sin(ph))
        arms(local, grip=0.2, t=t, period=T, idle_amt=0.6)
        tg, fr = B.gait_targets(contact, t, T, SL, duty, PHASE, lift, pitch=0.0, direction=direction)
        B.legs_ik(rig, legs, local, trans, tg, fr)
        return guard(local, trans), trans

    SIDE = dict(T=1.4, SL=0.45, duty=0.6, direction=(1.0, 0.0, 0.0), lift=0.14)
    FWD = dict(T=1.6, SL=0.36, duty=0.62, direction=(0.0, 0.0, 1.0), lift=0.12)

    def side(t):
        return crawl(t, **SIDE)

    def fwd(t):
        return crawl(t, **FWD)

    def defend(t):
        d = C.ease(t, 0.0, 0.5)
        local, trans = {}, {}
        trans["Body"] = (0, -0.18 * d, -0.04 * d)
        local["Body"] = C.R((1, 0, 0), 6 * d)
        local["Shell"] = C.R((1, 0, 0), 7 * d) @ C.R((0, 0, 1), 1.5 * math.sin(t * 3) * d)
        local["Sensor"] = C.R((1, 0, 0), -8 * d)
        arms(local, grip=0.9 * d, fold=d, t=t, idle_amt=0.2)
        tg = {k: contact[k] * np.array([1.0 + 0.08 * d, 1, 1.0 + 0.05 * d]) for k in legs}
        B.legs_ik(rig, legs, local, trans, tg)
        return guard(local, trans), trans

    def grasp(t):
        reach = C.pulse(t, 0.15, 0.55, 0.8, 1.35)
        opn = C.pulse(t, 0.1, 0.45, 0.62, 0.72)
        close = C.ease(t, 0.62, 0.74) * (1 - C.ease(t, 1.2, 1.6))
        local, trans = {}, {}
        trans["Body"] = (0, -0.04 * reach, 0.12 * reach)
        local["Body"] = C.R((1, 0, 0), 7 * reach) @ C.R((0, 1, 0), -6 * reach)
        local["Sensor"] = C.R((1, 0, 0), -10 * reach)
        local["GraspL_Upper"] = C.R((0, 1, 0), 18 * reach) @ C.R((1, 0, 0), 22 * reach - 10 * close)
        local["GraspL_Lower"] = C.R((1, 0, 0), 34 * reach - 20 * close)
        local["GraspL_Hand"] = C.R((1, 0, 0), -20 * opn + 15 * close)
        for q, fn in enumerate(fingers):
            local[fn] = C.R((1, 0, 0), -35 * opn + 55 * close) @ C.R((0, 1, 0), (q - 1) * 14 * opn)
        local["GraspR_Upper"] = C.R((0, 1, 0), -12 * reach)
        local["GraspR_Lower"] = C.R((1, 0, 0), 22 * reach)
        local["GraspR_Sickle"] = C.R((1, 0, 0), -20 * opn + 40 * close)
        tg = {k: contact[k] + np.array([0, 0, 0.08 * reach]) for k in ("LA", "RA")}
        B.legs_ik(rig, legs, local, trans, tg)
        return guard(local, trans, 0.05), trans

    def hit(t):
        j = C.pulse(t, 0.0, 0.06, 0.1, 0.65)
        sh = math.sin(t * 2 * math.pi * 8) * math.exp(-t * 6)
        local, trans = {}, {}
        trans["Body"] = (-0.06 * j, -0.07 * j, -0.05 * j)
        local["Body"] = C.R((0, 0, 1), 6 * j + 2 * sh) @ C.R((1, 0, 0), -4 * j)
        local["Shell"] = C.R((0, 0, 1), -4 * j + 3 * sh)
        local["Sensor"] = C.R((0, 1, 0), 14 * j)
        arms(local, grip=0.8 * j, fold=0.5 * j, t=t, idle_amt=0.3)
        B.legs_ik(rig, legs, local, trans, {})
        return guard(local, trans), trans

    def death(t):
        st = C.pulse(t, 0.0, 0.2, 0.3, 0.6)
        dn = C.ease(t, 0.3, 1.3)
        local, trans = {}, {}
        trans["Body"] = (0.05 * st, -0.24 * dn, 0)
        local["Body"] = C.R((0, 0, 1), 4 * st - 7 * dn) @ C.R((1, 0, 0), -3 * dn)
        local["Shell"] = C.R((0, 0, 1), -3 * dn)
        local["Sensor"] = C.R((1, 0, 0), -6 * dn)
        arms(local, grip=0.6 * st + 0.3 * dn, t=t, idle_amt=1 - dn)
        local["GraspL_Upper"] = local["GraspL_Upper"] @ C.R((1, 0, 0), 20 * dn)
        local["GraspR_Upper"] = local["GraspR_Upper"] @ C.R((1, 0, 0), 20 * dn)
        tg = {k: contact[k] * np.array([1.0 + 0.24 * dn, 1, 1.0 + 0.12 * dn]) for k in legs}
        B.legs_ik(rig, legs, local, trans, tg)
        return guard(local, trans), trans

    clips = [("Idle", idle, 3.0, True), ("Crawl_Sideways", side, SIDE["T"], True), ("Crawl_Forward", fwd, FWD["T"], True),
             ("Defend", defend, 1.6, False), ("Attack_Grasp", grasp, 1.6, False), ("Hit_React", hit, 0.8, False),
             ("Death", death, 2.2, False)]
    loco = {"sideways_speed_mps": round(SIDE["SL"] / (SIDE["T"] * SIDE["duty"]), 3),
            "forward_speed_mps": round(FWD["SL"] / (FWD["T"] * FWD["duty"]), 3)}
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
    mats = {MAT: dict(albedo=png[0], emit=png[1], emit_factor=(0.6, 0.66, 0.7), emit_energy=0.7, repeat=False, rough=0.75)}
    sockets = [("Socket_Sensor", "Sensor", (0.03, 0.56, 0.84)), ("Socket_GraspL", "GraspL_Hand", (-0.42, 0.22, 1.5))]
    extras = {"veil_creature": "Shellcrawler", "faces": "+Z", "units": "m", "locomotion": loco, "legs": legs}
    glb, tris = B.export(NAME, "Shellcrawler", rig, meshes, mats, sockets, clips, extras)
    scene = os.path.join(C.CR, "Godot_Scenes", "CRT_Shellcrawler.tscn")
    S.creature_scene(scene, "Shellcrawler", glb,
                     shapes=[("ShellShape", "BoxShape3D", {"size": (2.1, 0.8, 1.55)}, (-0.05, 0.75, 0.0)),
                             ("LegSpan", "BoxShape3D", {"size": (3.4, 0.6, 1.9)}, (-0.1, 0.33, -0.05)),
                             ("ArmsShape", "BoxShape3D", {"size": (1.1, 0.6, 0.8)}, (-0.12, 0.42, 1.15))],
                     markers=[("LookTarget", (0.03, 0.56, 0.86)), ("GraspReach", (-0.45, 0.3, 1.9))],
                     meta={"veil_creature": "Shellcrawler", "faces": "+Z", "animation_player": "Model/AnimationPlayer",
                           "animations": [c.name for c in clips], "sideways_speed_mps": loco["sideways_speed_mps"],
                           "forward_speed_mps": loco["forward_speed_mps"]})
    return dict(name=NAME, glb=glb, tris=tris, rig=rig, legs=legs, clips=clips, frames=frames, meshes=meshes, mats=mats,
                sockets=sockets, feet=[v[2] for v in legs.values()], edge_floor=0.03, probe="GraspL_F2",
                scene=os.path.relpath(scene, C.V2).replace(os.sep, "/"),
                limits={"max_stretch": 2.0, "max_stretch_death": 2.2, "p999_stretch": 1.6, "p999_stretch_death": 1.75,
                        "min_y": -0.03})


if __name__ == "__main__":
    r = build()
    print(r["glb"], r["tris"])
