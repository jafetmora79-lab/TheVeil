"""THE VEIL - Pack 07 / Creature 03: THE HOUND (fast supernatural predator).

Canine-inspired, but wrong:
  * low predatory stance with the head carried below the shoulders; powerful, uneven shoulders (the right one is
    heavier) over a gaunt waist and a deep keeled rib cage;
  * an unnatural spine: a double hump with a row of hooked vertebral spikes that grow toward the shoulders;
  * a long, narrow, EYELESS head - rows of pale sensory pits run down the snout (3 left, 4 right), two swept-back
    bone spines on the skull;
  * a distinctive SPLIT JAW: the lower jaw is two separate hinged halves (Jaw_L / Jaw_R) that drop and spread
    sideways around a ridged maw, with hooked fangs at each tip;
  * four digitigrade legs with backward elbow spurs, thin shanks and three long claws per foot;
  * a thin whip tail with spikes.
About 1.0 m at the shoulder, 3.3 m nose to tail tip. One material (M_Crt_Hound, 256 px atlas + faint emission on the
sensory pits and spine seams).
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

NAME = "CRT_Hound"
FPS = 30
MAT = "M_Crt_Hound"

LEGS = {  # parent, shoulder/hip, elbow/knee, wrist/hock, contact, radii (top, joint, low), kind
    "FL": ("Chest", (-0.25, 0.92, 0.42), (-0.30, 0.55, 0.30), (-0.28, 0.15, 0.50), (-0.29, 0.0, 0.64), (0.12, 0.06, 0.04), "fore"),
    "FR": ("Chest", (0.27, 0.93, 0.44), (0.31, 0.56, 0.33), (0.29, 0.15, 0.52), (0.30, 0.0, 0.66), (0.135, 0.065, 0.042), "fore"),
    "HL": ("Hips", (-0.19, 0.80, -0.55), (-0.24, 0.48, -0.30), (-0.23, 0.19, -0.72), (-0.23, 0.0, -0.60), (0.13, 0.07, 0.04), "hind"),
    "HR": ("Hips", (0.19, 0.79, -0.57), (0.24, 0.47, -0.32), (0.23, 0.19, -0.74), (0.23, 0.0, -0.62), (0.125, 0.068, 0.04), "hind"),
}


def textures():
    at = X.Canvas(256, 256, seed="hound")
    X.paint_hide(at.region(0, 0, 256, 256), "hound_bg", base="crt_char", accent="crt_violet", cracks=4, glow_cracks=0, scale=2)
    rg = {"hide": at.region(0, 0, 128, 128), "leg": at.region(128, 0, 64, 128), "skull": at.region(192, 0, 64, 64),
          "claw": at.region(192, 64, 32, 64), "pit": at.region(224, 64, 32, 32), "pit_dim": at.region(224, 96, 32, 32),
          "spine": at.region(0, 128, 64, 64), "jaw": at.region(64, 128, 64, 64), "maw": at.region(128, 128, 64, 32),
          "flesh": at.region(128, 160, 64, 32), "tail": at.region(192, 128, 64, 128)}
    X.paint_hide(rg["hide"], "hound_hide", base="crt_char", accent="crt_violet", cracks=5, glow_cracks=1, scale=2)
    X.paint_hide(rg["leg"], "hound_leg", base="crt_char", accent="crt_moss", cracks=3, glow_cracks=0, scale=2)
    X.paint_plate(rg["skull"], "hound_skull", "crt_bone", "crt_char", rings=6)
    X.paint_claw(rg["claw"], "hound_claw")
    X.paint_orb(rg["pit"], "hound_pit", slit=False)
    X.paint_orb(rg["pit_dim"], "hound_pit_dim", iris="crt_violet", glow=False, slit=False)
    X.paint_plate(rg["spine"], "hound_spine", "crt_bone", "crt_abyss", rings=3, seam_glow=0.2)
    X.paint_plate(rg["jaw"], "hound_jaw", "crt_char", "crt_abyss", rings=5)
    X.paint_maw(rg["maw"], "hound_maw", teeth_rows=2)
    X.paint_maw(rg["flesh"], "hound_flesh", teeth_rows=0)
    X.paint_tentacle(rg["tail"], "hound_tail", base="crt_char", back="crt_abyss", ridge_step=5, nodes=False)
    out = (os.path.join(B.TEX, "T_Crt_Hound.png"), os.path.join(B.TEX, "T_Crt_Hound_Emit.png"))
    at.save(*out)
    return out, {k: r.uv() for k, r in rg.items()}


def build_rig():
    rig = C.Rig(NAME)
    rig.add("Root", None, (0, 0, 0))
    rig.add("Hips", "Root", (0, 0.80, -0.55))
    rig.add("Spine1", "Hips", (0, 0.86, -0.22))
    rig.add("Spine2", "Spine1", (0, 0.97, 0.12))
    rig.add("Chest", "Spine2", (0, 1.02, 0.42))
    rig.add("Neck", "Chest", (0, 0.96, 0.70))
    rig.add("Head", "Neck", (0, 0.88, 0.95), tip=(0, 0.66, 1.55))
    rig.add("Jaw_L", "Head", (-0.06, 0.80, 1.02), tip=(-0.08, 0.64, 1.47))
    rig.add("Jaw_R", "Head", (0.06, 0.80, 1.02), tip=(0.08, 0.64, 1.47))
    rig.chain(["Tail_01", "Tail_02", "Tail_03"], "Hips", [(0, 0.84, -0.82), (0, 0.78, -1.12), (0.03, 0.66, -1.40), (0.06, 0.50, -1.64)])
    legs = {}
    for k, (par, s, e, w, c, _, _) in LEGS.items():
        b = [f"Leg_{k}_Upper", f"Leg_{k}_Lower", f"Leg_{k}_Foot"]
        rig.chain(b, par, [s, e, w, c])
        legs[k] = b
    return rig, legs


def zweight(keys):
    def f(p, s=None):
        z = p[2]
        if z <= keys[0][0]:
            return {keys[0][1]: 1.0}
        if z >= keys[-1][0]:
            return {keys[-1][1]: 1.0}
        for (z0, b0), (z1, b1) in zip(keys, keys[1:]):
            if z0 <= z <= z1:
                t = C.smooth((z - z0) / (z1 - z0))
                return {b0: 1 - t, b1: t} if b0 != b1 else {b0: 1.0}
        return {keys[-1][1]: 1.0}
    return f


TORSO_W = zweight([(-0.86, "Tail_01"), (-0.66, "Hips"), (-0.36, "Hips"), (-0.14, "Spine1"), (0.04, "Spine1"), (0.22, "Spine2"),
                   (0.30, "Spine2"), (0.46, "Chest")])


def build_mesh(rig, legs, uv):
    sm = C.SkinMesh()
    # torso
    path = [(0, 0.84, -0.86), (0, 0.84, -0.58), (0, 0.87, -0.26), (0, 0.96, 0.08), (0, 1.01, 0.40), (0, 0.98, 0.62)]
    Ct = G.resample(path, 16)
    Rt = G.resample([np.array(r) for r in [(0.09, 0.08), (0.16, 0.15), (0.14, 0.11), (0.21, 0.15), (0.25, 0.23), (0.19, 0.18)]], 16)

    def tprof(i, s, th):
        keel = 1.0 + 0.22 * max(0.0, -math.cos(th)) ** 2 * math.exp(-((s - 0.62) / 0.16) ** 2)
        ridge = 1.0 + 0.10 * math.exp(-(min(th, 2 * math.pi - th) / 0.3) ** 2)
        ribs = 1.0 + 0.05 * max(0.0, math.sin(s * 70)) * abs(math.sin(th)) * (0.45 < s < 0.85)
        sh_r = 0.12 * math.exp(-((th - 4.6) / 0.6) ** 2 - ((s - 0.88) / 0.1) ** 2)
        scar = -0.06 * math.exp(-((th - 1.7) / 0.25) ** 2 - ((s - 0.4) / 0.06) ** 2)
        return keel * ridge * ribs + sh_r + scar
    _, Lt = G.arclen(Ct)
    rings = G.sweep(sm, Ct, [tuple(r) for r in Rt], lambda p, s: TORSO_W(p), uv["hide"], n=12, prof=tprof, base_cap=True,
                    front=(0, -1, 0))
    # neck + head
    neck = G.resample([(0, 0.99, 0.55), (0, 0.97, 0.72), (0, 0.92, 0.88), (0, 0.89, 0.98)], 7)
    G.sweep(sm, neck, [(0.17, 0.16), (0.15, 0.14), (0.13, 0.12), (0.12, 0.11), (0.11, 0.105), (0.11, 0.1), (0.105, 0.1)],
            G.chain_w([(0.0, "Chest"), (0.3, "Neck"), (0.85, "Head")], blend=0.15), uv["hide"], n=10, front=(0, -1, 0))
    head = G.resample([(0, 0.90, 0.92), (0, 0.87, 1.10), (0, 0.80, 1.32), (0, 0.69, 1.53)], 9)

    def hprof(i, s, th):
        flat = 1.0 - 0.3 * max(0.0, -math.cos(th)) ** 2
        brow = 1.0 + 0.12 * math.exp(-(min(th, 2 * math.pi - th) / 0.5) ** 2) * math.exp(-((s - 0.25) / 0.15) ** 2)
        return flat * brow
    G.sweep(sm, head, [(0.115, 0.1), (0.11, 0.095), (0.1, 0.085), (0.09, 0.075), (0.078, 0.065), (0.065, 0.055),
                       (0.05, 0.045), (0.038, 0.034), (0.026, 0.024)], lambda p, s: {"Head": 1.0}, uv["skull"], n=10,
            prof=hprof, tip=0.03, front=(0, -1, 0))
    for side, ln, z in ((-1, 0.30, 0.98), (1, 0.22, 0.99)):
        b0 = np.array([side * 0.06, 0.97, z])
        sp = [b0, b0 + np.array([side * 0.05, 0.06, -0.12]), b0 + np.array([side * 0.09, 0.08, -ln])]
        G.sweep(sm, G.resample(sp, 5), [0.03, 0.025, 0.018, 0.012, 0.006], lambda p, s: {"Head": 1.0}, uv["claw"], n=5,
                tip=0.04, front=(0, 1, 0))
    for side, zs in ((-1, (1.12, 1.24, 1.36)), (1, (1.08, 1.18, 1.28, 1.40))):
        for q, z in enumerate(zs):
            y = 0.86 - (z - 1.0) * 0.45 + 0.01 * q
            r = 0.085 - (z - 1.0) * 0.12
            G.orb(sm, (side * r * 0.95, y, z), 0.016 + 0.004 * (q % 2), {"Head": 1.0}, uv["pit" if q % 2 == 0 else "pit_dim"], n=5,
                  m=3, axis=(side, 0.3, 0.2))
    # split jaw
    for side, bn in ((-1, "Jaw_L"), (1, "Jaw_R")):
        h = rig.J[bn]
        tp = rig.tips[bn]
        jaw = [h, h + (tp - h) * 0.5 + np.array([side * 0.025, -0.02, 0]), tp]
        G.sweep(sm, G.resample(jaw, 7), [(0.035, 0.03), (0.04, 0.032), (0.04, 0.03), (0.035, 0.026), (0.03, 0.022), (0.022, 0.018),
                                         (0.015, 0.012)], lambda p, s, bn=bn: {bn: 1.0}, uv["jaw"], n=6, tip=0.02, front=(side, 0, 0))
        gum = [h + np.array([-side * 0.012, 0.03, 0.06]), tp + np.array([-side * 0.012, 0.035, -0.04])]
        G.sweep(sm, G.resample(gum, 5), [0.014] * 5, lambda p, s, bn=bn: {bn: 1.0}, uv["maw"], n=4, front=(0, 1, 0))
        for q, f in enumerate((0.92, 0.7)):
            fb = h + (tp - h) * f + np.array([-side * 0.008, 0.025, 0])
            fang = [fb, fb + np.array([-side * 0.012, 0.035, 0.008]), fb + np.array([-side * 0.03, 0.06, 0.0])]
            G.sweep(sm, G.resample(fang, 4), [0.011, 0.009, 0.006, 0.003], lambda p, s, bn=bn: {bn: 1.0}, uv["claw"], n=4,
                    tip=0.012, front=(0, 0, 1))
    G.orb(sm, (0, 0.76, 1.2), 0.07, {"Head": 1.0}, uv["flesh"], n=6, m=4, axis=(0, 0.3, 1), squash=(0.7, 0.6, 2.4))
    # vertebral spikes
    S_, _ = G.arclen(Ct)
    T_, A_, B_ = G.frames(Ct, (0, -1, 0))
    for q, s in enumerate(np.linspace(0.12, 0.92, 10)):
        i = int(np.clip(np.searchsorted(S_, s), 1, len(S_) - 1))
        top = rings[i][0]
        ht = 0.035 + 0.07 * s
        off = (0.012 if q % 2 else -0.01)
        base = top + np.array([off, -0.01, 0])
        sp = [base, base + np.array([0, ht * 0.6, -ht * 0.2]), base + np.array([off, ht, -ht * 0.7])]
        G.sweep(sm, G.resample(sp, 4), [0.026, 0.02, 0.012, 0.005], lambda p, ss, w=TORSO_W(top): w, uv["spine"], n=4,
                tip=0.02, front=(0, 0, 1))
    # tail
    tb = ["Tail_01", "Tail_02", "Tail_03"]
    tp = [rig.J[b] for b in tb] + [rig.tips["Tail_03"]]
    Cd = G.resample(tp, 10)
    B.tentacle_mesh(sm, Cd, tb, tp, 0.07, 0.012, uv["tail"], n=6, ridge=0.12, parent="Hips", ridges=7, flat=0.9)
    # legs
    for k, (par, s, e, w, c, (rt, rj, rw), kind) in LEGS.items():
        b = legs[k]
        s, e, w, c = (np.array(v, float) for v in (s, e, w, c))
        inside = s - C.nrm(e - s) * 0.13 + np.array([-s[0] * 0.15, 0, 0])   # root continues the leg line into the body
        pts = [inside, s, s + (e - s) * 0.45 + np.array([0, 0, 0.03 if kind == "fore" else -0.03]), e, e + (w - e) * 0.5, w,
               w + (c - w) * 0.6]
        Cl = G.resample(G.round_corners(pts, [0, 0, 0, rj * 1.6, 0, rw * 1.5, 0]), 18)
        St, _ = G.arclen(Cl)
        stops = G.stops_from_joints(Cl, [inside, s, e, w], [par, b[0], b[1], b[2]])
        wf = G.chain_w(stops, blend=0.12)
        se, sw_ = stops[2][0], stops[3][0]

        def radius(sv, rt=rt, rj=rj, rw=rw, se=se, sw_=sw_):
            if sv < se:
                return rt + (rj - rt) * (sv / se) ** 1.3 + 0.25 * rt * math.sin(math.pi * sv / se) ** 2
            if sv < sw_:
                q = (sv - se) / (sw_ - se)
                return rj + (rw - rj) * q
            return rw * 1.15
        G.sweep(sm, Cl, [radius(v) for v in St], wf, uv["leg"], n=8,
                prof=lambda i, sv, th: 1.0 + 0.08 * math.cos(3 * th), front=(0, 0, 1))
        spur = (0, 0.5, -1) if kind == "fore" else (0, 0.3, 1)
        sd = C.nrm(np.array(spur, float))
        sp = [e, e + sd * 0.07, e + sd * 0.13 + np.array([0, 0.03, 0])]
        G.sweep(sm, G.resample(sp, 4), [0.025, 0.018, 0.01, 0.004], lambda p, sv, bb=b[0]: {bb: 1.0}, uv["claw"], n=4, tip=0.03,
                front=(0, 1, 0))
        base = w + (c - w) * 0.75
        for dl, dz in ((-0.035, 0.0), (0.0, 0.015), (0.035, 0.0)):
            tipp = np.array([c[0] + dl * 1.3, 0.008, c[2] + 0.11 + dz])
            mid = (base + tipp) / 2 + np.array([dl * 0.3, 0.03, 0.02])
            G.sweep(sm, G.resample([base + np.array([dl, 0, 0]), mid, tipp], 5), [0.02, 0.017, 0.012, 0.008, 0.004],
                    lambda p, sv, bb=b[2]: {bb: 1.0}, uv["claw"], n=4, tip=0.015, front=(0, -1, 0))
    return {MAT: sm}


def pose_factory(rig, legs):
    contact = {k: rig.tips[legs[k][2]] for k in legs}
    tail = ["Tail_01", "Tail_02", "Tail_03"]

    def head_safe(local, trans, floor=0.05):
        """lift the head (in 2-degree steps) until snout and jaw tips clear the ground"""
        for _ in range(40):
            Rw, Pw = rig.fk(local, trans)
            ys = [(Pw[b] + Rw[b] @ (rig.tips[b] - rig.J[b]))[1] for b in ("Head", "Jaw_L", "Jaw_R")]
            if min(ys) >= floor:
                break
            local["Neck"] = C.R((1, 0, 0), -2.0) @ local.get("Neck", C.I3)
        return local

    def base(local, t, T, breath=1.0, sniff=1.0, jaw=0.0, tail_amp=1.0):
        f = B.cyc(1.0, T)
        local["Spine2"] = local.get("Spine2", C.I3) @ C.R((1, 0, 0), 1.5 * breath * math.sin(2 * math.pi * f * t))
        local["Neck"] = local.get("Neck", C.I3) @ C.R((1, 0, 0), 4 * sniff * math.sin(2 * math.pi * B.cyc(0.5, T) * t + 1))
        local["Head"] = local.get("Head", C.I3) @ C.R((0, 1, 0), 6 * sniff * math.sin(2 * math.pi * B.cyc(0.33, T) * t))
        local["Jaw_L"] = C.R((0, 0, 1), -jaw * 0.35) @ C.R((1, 0, 0), jaw)
        local["Jaw_R"] = C.R((0, 0, 1), jaw * 0.35) @ C.R((1, 0, 0), jaw)
        B.wave(rig, local, tail, t, amp=6 * tail_amp, amp2=10 * tail_amp, freq=0.7, lag=0.8, period=T)
        return local

    def idle(t):
        T = 3.0
        local, trans = {}, {}
        trans["Hips"] = (0, 0.012 * math.sin(2 * math.pi * t / T), 0)
        twitch = 4.0 * max(0.0, math.sin(2 * math.pi * 2 * t / T)) ** 8
        base(local, t, T, jaw=2 + twitch)
        B.legs_ik(rig, legs, local, trans, {})
        return head_safe(local, trans), trans

    def locomotion(t, T, SL, duty, phases, lift, flex, bob, run=False):
        local, trans = {}, {}
        ph = 2 * math.pi * t / T
        trans["Hips"] = (0.01 * math.sin(ph), bob * math.cos(2 * ph if not run else ph) - (0.05 if run else 0.0), 0.0)
        local["Hips"] = C.R((0, 0, 1), 2.0 * math.sin(ph)) @ C.R((1, 0, 0), flex * 0.5 * math.sin(ph + 0.6))
        local["Spine1"] = C.R((1, 0, 0), flex * math.sin(ph)) @ C.R((0, 1, 0), 3 * math.sin(ph + 0.3))
        local["Spine2"] = C.R((1, 0, 0), -flex * 0.8 * math.sin(ph + 0.4))
        local["Chest"] = C.R((0, 0, 1), -2.5 * math.sin(ph + 0.5)) @ C.R((1, 0, 0), -flex * 0.4 * math.sin(ph))
        local["Neck"] = C.R((1, 0, 0), (6 if run else 2) + flex * 0.3 * math.sin(ph + 1.2))
        local["Head"] = C.R((1, 0, 0), -(4 if run else 0) - flex * 0.4 * math.sin(ph + 1.5))
        local["Jaw_L"] = C.R((1, 0, 0), 6 if run else 2)
        local["Jaw_R"] = C.R((1, 0, 0), 6 if run else 2)
        B.wave(rig, local, tail, t, amp=8 if run else 5, amp2=12 if run else 9, freq=1.0 / T, lag=0.7, period=T)
        tg, fr = B.gait_targets(contact, t, T, SL, duty, phases, lift, pitch=40 if run else 30)
        B.legs_ik(rig, legs, local, trans, tg, fr)
        return head_safe(local, trans), trans

    WALK = dict(T=1.2, SL=0.7, duty=0.65, phases={"HL": 0.0, "FL": 0.25, "HR": 0.5, "FR": 0.75},
                lift={"FL": 0.13, "FR": 0.13, "HL": 0.11, "HR": 0.11}, flex=3.0, bob=0.02)
    RUN = dict(T=0.45, SL=0.9, duty=0.4, phases={"FL": 0.0, "FR": 0.11, "HL": 0.52, "HR": 0.63},
               lift={"FL": 0.19, "FR": 0.19, "HL": 0.17, "HR": 0.17}, flex=10.0, bob=0.04)

    def walk(t):
        return locomotion(t, **WALK)

    def run(t):
        return locomotion(t, **RUN, run=True)

    def alert(t):
        a = C.ease(t, 0.0, 0.45)
        local, trans = {}, {}
        trans["Hips"] = (0, -0.07 * a, -0.04 * a)
        local["Spine1"] = C.R((1, 0, 0), -7 * a)
        local["Spine2"] = C.R((1, 0, 0), -4 * a)
        local["Chest"] = C.R((1, 0, 0), 6 * a)
        local["Neck"] = C.R((1, 0, 0), -22 * a) @ C.R((0, 1, 0), 18 * a * math.sin(min(t, 1.0) * 3.2))
        local["Head"] = C.R((1, 0, 0), -6 * a) @ C.R((0, 0, 1), 6 * a * math.sin(t * 9) * (1 - C.ease(t, 0.4, 1.2)))
        jaw = 6 * a + 3 * math.sin(t * 20) * a * (1 - C.ease(t, 0.5, 1.4))
        local["Jaw_L"] = C.R((0, 0, 1), -jaw * 0.4) @ C.R((1, 0, 0), jaw)
        local["Jaw_R"] = C.R((0, 0, 1), jaw * 0.4) @ C.R((1, 0, 0), jaw)
        B.curl(rig, local, tail, [-14 * a, -8 * a, -4 * a])
        B.legs_ik(rig, legs, local, trans, {})
        return head_safe(local, trans), trans

    def attack(t):
        crouch = C.pulse(t, 0.0, 0.3, 0.32, 0.45)
        lunge = C.pulse(t, 0.36, 0.55, 0.8, 1.3)
        open_ = C.pulse(t, 0.25, 0.5, 0.62, 0.7)
        snap = C.ease(t, 0.62, 0.7) * (1 - C.ease(t, 0.9, 1.3))
        local, trans = {}, {}
        trans["Hips"] = (0, -0.1 * crouch - 0.03 * lunge, -0.05 * crouch + 0.32 * lunge)
        local["Spine1"] = C.R((1, 0, 0), 8 * crouch - 6 * lunge)
        local["Spine2"] = C.R((1, 0, 0), 4 * crouch - 6 * lunge)
        local["Chest"] = C.R((1, 0, 0), -6 * crouch + 5 * lunge)
        local["Neck"] = C.R((1, 0, 0), -10 * crouch - 6 * lunge)
        local["Head"] = C.R((1, 0, 0), -14 * open_ + 4 * snap)
        jaw = 42 * open_
        local["Jaw_L"] = C.R((0, 0, 1), -jaw * 0.45) @ C.R((1, 0, 0), jaw)
        local["Jaw_R"] = C.R((0, 0, 1), jaw * 0.45) @ C.R((1, 0, 0), jaw)
        B.curl(rig, local, tail, [-10 * crouch + 8 * lunge] * 3)
        tg = {k: contact[k] + np.array([0, 0.12 * math.sin(math.pi * C.ease(t, 0.36, 0.62)), 0.38 * C.ease(t, 0.36, 0.62)
                                        * (1 - C.ease(t, 0.9, 1.3))]) for k in ("FL", "FR")}
        B.legs_ik(rig, legs, local, trans, tg)
        return head_safe(local, trans), trans

    def hit(t):
        j = C.pulse(t, 0.0, 0.07, 0.12, 0.75)
        sh = math.sin(t * 2 * math.pi * 7) * math.exp(-t * 6)
        local, trans = {}, {}
        base(local, t, 3.0, jaw=4 + 18 * j)
        trans["Hips"] = (-0.06 * j, -0.05 * j, -0.05 * j)
        local["Spine1"] = local.get("Spine1", C.I3) @ C.R((0, 1, 0), 8 * j + 3 * sh)
        local["Spine2"] = local.get("Spine2", C.I3) @ C.R((0, 0, 1), -6 * j)
        local["Neck"] = C.R((0, 1, 0), -16 * j) @ C.R((1, 0, 0), -12 * j + 4 * sh)
        B.legs_ik(rig, legs, local, trans, {})
        return head_safe(local, trans), trans

    def death(t):
        st = C.pulse(t, 0.0, 0.15, 0.25, 0.5)
        dn = C.ease(t, 0.3, 1.2)
        local, trans = {}, {}
        trans["Hips"] = (0.08 * st + 0.06 * dn, -0.31 * dn, 0.0)
        local["Hips"] = C.R((0, 0, 1), 18 * dn)
        local["Spine1"] = C.R((0, 0, 1), 6 * dn) @ C.R((0, 1, 0), 6 * st)
        local["Spine2"] = C.R((0, 0, 1), 6 * dn)
        local["Chest"] = C.R((1, 0, 0), 8 * dn)
        local["Neck"] = C.R((1, 0, 0), -10 * st + 20 * dn) @ C.R((0, 1, 0), 18 * dn)
        local["Head"] = C.R((0, 0, 1), 20 * dn)
        jaw = 8 * st + 22 * dn
        local["Jaw_L"] = C.R((1, 0, 0), jaw)
        local["Jaw_R"] = C.R((1, 0, 0), jaw * 0.8) @ C.R((0, 0, 1), 10 * dn)
        tg = {}
        for k in legs:
            c = contact[k].copy()
            c[0] *= 1.0 + 0.9 * dn
            c[0] += 0.22 * dn
            c[2] += (0.14 if k[0] == "F" else -0.34) * dn
            tg[k] = c
        B.legs_ik(rig, legs, local, trans, tg)
        B.curl(rig, local, tail, [10 * dn] * 3)
        local = B.floor_clamp(rig, local, trans, tail, 0.02, step=3.0, rad=[0.06, 0.05, 0.03, 0.01])
        return head_safe(local, trans, 0.04), trans

    clips = [("Idle", idle, 3.0, True), ("Walk", walk, WALK["T"], True), ("Run", run, RUN["T"], True), ("Alert", alert, 1.4, False),
             ("Attack_Bite", attack, 1.3, False), ("Hit_React", hit, 0.8, False), ("Death", death, 1.8, False)]
    loco = {"walk_speed_mps": round(WALK["SL"] / (WALK["T"] * WALK["duty"]), 3),
            "run_speed_mps": round(RUN["SL"] / (RUN["T"] * RUN["duty"]), 3)}
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
    mats = {MAT: dict(albedo=png[0], emit=png[1], emit_factor=(0.6, 0.66, 0.7), emit_energy=0.7, repeat=False, rough=0.85)}
    sockets = [("Socket_Mouth", "Head", (0, 0.72, 1.40)), ("Socket_Chest", "Chest", (0, 0.92, 0.45))]
    extras = {"veil_creature": "Hound", "faces": "+Z", "units": "m", "locomotion": loco, "legs": legs}
    glb, tris = B.export(NAME, "Hounds", rig, meshes, mats, sockets, clips, extras)
    scene = os.path.join(C.CR, "Godot_Scenes", "CRT_Hound.tscn")
    S.creature_scene(scene, "Hound", glb,
                     shapes=[("BodyShape", "BoxShape3D", {"size": (0.62, 0.62, 1.55)}, (0, 0.72, -0.05)),
                             ("HeadShape", "BoxShape3D", {"size": (0.26, 0.32, 0.7)}, (0, 0.78, 1.18))],
                     markers=[("LookTarget", (0, 0.86, 1.2)), ("BiteReach", (0, 0.7, 1.95))],
                     meta={"veil_creature": "Hound", "faces": "+Z", "animation_player": "Model/AnimationPlayer",
                           "animations": [c.name for c in clips], "walk_speed_mps": loco["walk_speed_mps"],
                           "run_speed_mps": loco["run_speed_mps"]})
    return dict(name=NAME, glb=glb, tris=tris, rig=rig, legs=legs, clips=clips, frames=frames, meshes=meshes, mats=mats,
                sockets=sockets, feet=[v[2] for v in legs.values()], edge_floor=0.02, probe="Jaw_L",
                scene=os.path.relpath(scene, C.V2).replace(os.sep, "/"),
                limits={"max_stretch": 2.0, "max_stretch_death": 2.2, "p999_stretch": 1.75, "p999_stretch_death": 1.75,
                        "min_y": -0.03})


if __name__ == "__main__":
    r = build()
    print(r["glb"], r["tris"])
