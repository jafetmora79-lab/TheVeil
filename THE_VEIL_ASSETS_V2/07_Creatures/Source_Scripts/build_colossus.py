"""THE VEIL - Pack 07 / Creature 01: THE COLOSSUS (boss-scale dimensional entity).

Body plan (faces +Z, origin on the ground under the body; ~13 m to the top of the back, ~17 m to the top of the
dorsal tentacle arch):
  * a hunched DORSAL MASS, highest over the shoulders, ending in a heavy forward HOOD that hides the head;
  * under it an open RIB CAGE: uneven ribs (4 left, 3 + a broken stub right) hold a VENTRAL SAC suspended from a
    sinew stalk, with a dim pale CORE hanging in the hollow between the two masses;
  * the head is a lumpy SENSORY MASS under the hood: six pale orbs of different sizes, set asymmetrically, two
    drooping sensory stalks and a vertical MAW split between two hinged mandible plates (no face, no jaw);
  * exactly FOUR walking legs, each different: long sprawling forelegs (shoulder -> a high lateral elbow -> a long
    fluted stilt -> hooked three-digit foot), shorter hind legs with a forward knee and a backward hock ending in a
    split hoof plate; the left foreleg is the heaviest, the right hind leg the shortest;
  * SIX tentacles, each leaving the body through a puckered orifice: two dorsal (one arches over the back), two
    from the flanks of the rib cage, two hanging from the sac;
  * overlapping bone / charcoal plates on the back and joints, gill-like openings on the right flank, faint
    luminous cracks in the hide.
Materials: M_Crt_Colossus_Hide (tiling hide, 32 px/m), M_Crt_Tentacle (tiling, shared with the Mist Tentacles),
M_Crt_Colossus (256 px detail atlas). All three carry sparse emission masks.
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

NAME = "CRT_Colossus"
TILE_M = 4.0          # one hide / tentacle tile repeat = 4 m (128 px -> 32 px/m)
FPS = 20


# ================================================================== textures
def textures():
    os.makedirs(B.TEX, exist_ok=True)
    out = {}
    cv = X.Canvas(128, 128, seed="col_hide")
    X.paint_hide(cv.region(0, 0, 128, 128), "col_hide", cracks=7, glow_cracks=2)
    out["hide"] = (os.path.join(B.TEX, "T_Crt_Colossus_Hide.png"), os.path.join(B.TEX, "T_Crt_Colossus_Hide_Emit.png"))
    cv.save(*out["hide"])
    out["tent"] = B.shared_tentacle_texture()
    at = X.Canvas(256, 256, seed="col_atlas")
    X.paint_hide(at.region(0, 0, 256, 256), "col_atlas_bg", cracks=0, glow_cracks=0)
    rg = {}
    rg["plate_bone"] = at.region(0, 0, 64, 64)
    X.paint_plate(rg["plate_bone"], "col_plate_a", "crt_bone", "crt_char", rings=4)
    rg["plate_char"] = at.region(64, 0, 64, 64)
    X.paint_plate(rg["plate_char"], "col_plate_b", "crt_char", "crt_abyss", rings=5)
    rg["plate_glow"] = at.region(128, 0, 64, 64)
    X.paint_plate(rg["plate_glow"], "col_plate_c", "crt_bone", "crt_violet", rings=3, seam_glow=0.35)
    rg["core"] = at.region(192, 0, 64, 64)
    X.paint_core(rg["core"], "col_core")
    rg["orb_big"] = at.region(0, 64, 32, 32)
    X.paint_orb(rg["orb_big"], "col_orb_a")
    rg["orb_small"] = at.region(32, 64, 32, 32)
    X.paint_orb(rg["orb_small"], "col_orb_b", slit=False)
    rg["orb_dim"] = at.region(64, 64, 32, 32)
    X.paint_orb(rg["orb_dim"], "col_orb_c", iris="crt_violet", glow=False)
    rg["maw"] = at.region(96, 64, 64, 32)
    X.paint_maw(rg["maw"], "col_maw")
    rg["collar"] = at.region(160, 64, 64, 32)
    X.paint_collar(rg["collar"], "col_collar")
    rg["claw"] = at.region(224, 64, 32, 64)
    X.paint_claw(rg["claw"], "col_claw")
    rg["rib"] = at.region(0, 96, 32, 64)
    X.paint_claw(rg["rib"], "col_rib", ramp="crt_bone")
    rg["gill"] = at.region(32, 96, 64, 64)
    X.paint_maw(rg["gill"], "col_gill", teeth_rows=0)
    rg["hoof"] = at.region(96, 96, 64, 32)
    X.paint_plate(rg["hoof"], "col_hoof", "crt_char", "crt_abyss", rings=6)
    rg["sinew"] = at.region(96, 128, 64, 32)
    X.paint_tentacle(rg["sinew"], "col_sinew", base="crt_flesh", back="crt_violet", ridge_step=4, nodes=False)
    out["atlas"] = (os.path.join(B.TEX, "T_Crt_Colossus.png"), os.path.join(B.TEX, "T_Crt_Colossus_Emit.png"))
    at.save(*out["atlas"])
    return out, {k: r.uv() for k, r in rg.items()}


# ================================================================== rig + mesh
DORSAL = [(0, 9.4, -6.0), (0.1, 10.0, -4.2), (0, 10.4, -1.8), (-0.2, 10.6, 0.8), (0, 10.5, 3.0),
          (0.1, 9.9, 5.0), (0, 9.0, 6.6), (0, 8.2, 7.5)]
DORSAL_R = [(0.5, 0.6), (1.4, 1.9), (1.9, 2.6), (2.1, 2.9), (1.9, 2.6), (1.4, 1.9), (1.0, 1.3), (0.45, 0.7)]
SAC = [(0.3, 6.6, -2.9), (0.1, 6.5, -1.0), (-0.2, 6.6, 1.0), (0, 7.0, 2.4)]
SAC_R = [(0.45, 0.6), (1.05, 1.6), (1.0, 1.5), (0.4, 0.6)]

LEGS = {  # name: parent, shoulder/hip, elbow/knee, wrist/hock, ground contact, radii (top, joint, wrist), kind
    "FL": ("Chest", (-2.5, 10.2, 2.6), (-5.6, 10.6, 4.0), (-6.0, 2.4, 5.6), (-6.1, 0.0, 6.0), (1.15, 0.78, 0.36), "fore"),
    "FR": ("Chest", (2.6, 10.0, 2.4), (5.2, 9.9, 3.6), (5.7, 2.2, 5.2), (5.8, 0.0, 5.6), (0.98, 0.66, 0.30), "fore"),
    "HL": ("Rear", (-2.2, 9.6, -3.4), (-3.9, 6.4, -1.9), (-4.4, 2.6, -4.8), (-4.5, 0.0, -4.4), (1.05, 0.80, 0.40), "hind"),
    "HR": ("Rear", (2.3, 9.4, -3.6), (3.6, 6.0, -2.4), (4.0, 2.2, -5.0), (4.1, 0.0, -4.7), (1.00, 0.86, 0.38), "hind"),
}

TENTACLES = {  # name: parent, path, base radius, bones
    "T_DorsalL": ("Body", [(-1.0, 12.0, 0.4), (-1.5, 14.0, 0.0), (-2.0, 15.6, -1.4), (-2.2, 16.2, -3.4),
                           (-2.0, 15.6, -5.4), (-1.6, 14.2, -6.6), (-1.2, 12.6, -7.0)], 0.55, 8),
    "T_DorsalR": ("Rear", [(1.4, 11.4, -2.6), (2.2, 13.0, -2.4), (3.4, 14.0, -1.4), (4.6, 14.2, 0.2),
                           (5.6, 13.4, 1.4), (6.2, 12.2, 1.8)], 0.42, 7),
    "T_FlankL": ("Body", [(-2.5, 9.0, -0.8), (-3.4, 8.4, -1.2), (-4.0, 6.8, -1.0), (-4.1, 5.0, -0.2),
                          (-3.8, 3.6, 0.6), (-3.3, 2.6, 1.4)], 0.36, 6),
    "T_FlankR": ("Chest", [(2.5, 9.4, 1.2), (3.5, 9.0, 2.0), (4.0, 7.6, 3.4), (3.8, 6.0, 4.6),
                           (3.2, 4.8, 5.4), (2.5, 4.4, 5.6)], 0.32, 6),
    "T_VentA": ("Belly", [(-0.4, 5.7, -1.4), (-0.6, 4.2, -1.6), (-0.5, 2.8, -1.4), (-0.1, 1.7, -0.8),
                          (0.4, 1.1, 0.2), (0.9, 0.9, 1.2)], 0.30, 6),
    "T_VentB": ("Belly", [(0.6, 5.8, 1.0), (0.9, 4.6, 1.4), (1.0, 3.6, 1.2), (0.7, 2.8, 0.6), (0.3, 2.4, 0.4)], 0.22, 5),
}


def build_rig():
    rig = C.Rig(NAME)
    rig.add("Root", None, (0, 0, 0))
    rig.add("Body", "Root", (0, 9.4, -0.2))
    rig.add("Chest", "Body", (0, 10.1, 2.8))
    rig.add("Head", "Chest", (0, 9.2, 5.4))
    rig.add("Maw_L", "Head", (-0.3, 7.75, 7.15), tip=(-0.3, 6.85, 7.35))
    rig.add("Maw_R", "Head", (0.32, 7.75, 7.1), tip=(0.32, 6.85, 7.3))
    rig.chain(["Stalk_L_01", "Stalk_L_02"], "Head", [(-0.9, 8.3, 6.6), (-1.3, 7.3, 7.3), (-1.5, 6.3, 7.8)])
    rig.chain(["Stalk_R_01", "Stalk_R_02"], "Head", [(0.95, 8.1, 6.5), (1.25, 7.4, 7.0), (1.35, 6.9, 7.6)])
    rig.add("Rear", "Body", (0, 9.8, -3.4))
    rig.add("Belly", "Body", (0, 7.9, -0.2), tip=(0, 5.4, -0.2))
    legs = {}
    for k, (par, s, e, w, c, _, _) in LEGS.items():
        b = [f"Leg_{k}_Upper", f"Leg_{k}_Lower", f"Leg_{k}_Foot"]
        rig.chain(b, par, [s, e, w, c])
        legs[k] = b
    tents = {}
    for k, (par, path, r0, nb) in TENTACLES.items():
        tents[k] = B.tentacle_chain(rig, k, par, path, nb)
    return rig, legs, tents


def body_weight(p, s=None):
    z = p[2]
    keys = [(-4.6, "Rear"), (-2.0, "Rear"), (-0.6, "Body"), (1.6, "Body"), (3.0, "Chest"), (4.4, "Chest"), (5.8, "Head")]
    if z <= keys[0][0]:
        return {"Rear": 1.0}
    if z >= keys[-1][0]:
        return {"Head": 1.0}
    for (z0, b0), (z1, b1) in zip(keys, keys[1:]):
        if z0 <= z <= z1:
            t = C.smooth((z - z0) / (z1 - z0))
            return {b0: 1 - t, b1: t} if b0 != b1 else {b0: 1.0}
    return {"Body": 1.0}


def build_mesh(rig, legs, tents, uv):
    hide, tent, atl = C.SkinMesh(), C.SkinMesh(), C.SkinMesh()
    meshes = {"M_Crt_Colossus_Hide": hide, "M_Crt_Tentacle": tent, "M_Crt_Colossus": atl}

    # --- dorsal mass + hood ------------------------------------------------------
    Cd = G.resample(DORSAL, 20)
    Rd = G.resample([np.array(r) for r in DORSAL_R], 20)
    _, Ld = G.arclen(Cd)

    def dprof(i, s, th):
        under = 1.0 - 0.32 * max(0.0, -math.cos(th)) ** 1.5           # flattened underside (theta = pi)
        ridge = 1.0 + 0.07 * math.exp(-(th / 0.35) ** 2) + 0.07 * math.exp(-((th - 2 * math.pi) / 0.35) ** 2)
        lump = 1.0 + 0.06 * math.sin(3 * th + s * 13.0) + 0.04 * math.sin(5 * th - s * 21.0)
        shoulder_l = 0.20 * math.exp(-((th - 1.2) / 0.55) ** 2 - ((s - 0.62) / 0.12) ** 2)   # heavy left shoulder
        hump_r = 0.16 * math.exp(-((th - 4.9) / 0.5) ** 2 - ((s - 0.28) / 0.1) ** 2)        # right rear hump
        sunk = -0.10 * math.exp(-((th - 4.4) / 0.35) ** 2 - ((s - 0.5) / 0.08) ** 2)        # gill hollow
        return under * ridge * lump + shoulder_l + hump_r + sunk
    U = max(1, round(2 * math.pi * 2.4 / TILE_M))
    dorsal_rings = G.sweep(hide, Cd, [tuple(r) for r in Rd], lambda p, s: body_weight(p), (0, 0, U, Ld / TILE_M),
                           n=18, prof=dprof, tip=0.25, base_cap=True, front=(0, -1, 0))

    # --- head mass under the hood --------------------------------------------------
    Ch = G.resample([(0, 9.0, 4.9), (0.1, 8.15, 6.4), (-0.1, 7.55, 7.05), (0, 7.2, 7.35)], 8)

    def hprof(i, s, th):
        return 1.0 + 0.10 * math.sin(3 * th + 1.0) + 0.07 * math.sin(5 * th + s * 6)
    G.sweep(hide, Ch, [(0.95, 1.05), (0.9, 1.0), (0.8, 0.95), (0.7, 0.85), (0.6, 0.75), (0.5, 0.62), (0.36, 0.45), (0.2, 0.28)],
            lambda p, s: {"Head": 1.0}, (0, 0, 1, 0.8), n=12, prof=hprof, tip=0.1, front=(0, 0, 1))
    orbs = [((0.42, 8.15, 7.18), 0.30, "orb_big"), ((-0.38, 8.4, 6.98), 0.19, "orb_small"),
            ((-0.62, 7.85, 6.95), 0.15, "orb_small"), ((-0.18, 7.62, 7.32), 0.12, "orb_dim"),
            ((0.78, 7.62, 6.78), 0.12, "orb_small"), ((0.06, 8.7, 6.62), 0.10, "orb_dim")]
    for c, r, key in orbs:
        dirv = C.nrm(np.array(c) - np.array((0.0, 8.0, 6.2)))
        G.orb(atl, c, r, {"Head": 1.0}, uv[key], n=8, m=5, axis=dirv)
    # maw: dark split cavity + two hinged mandible plates
    G.orb(atl, (0.0, 7.35, 7.2), 0.32, {"Head": 1.0}, uv["maw"], n=8, m=4, axis=(0, 0, 1), squash=(0.6, 1.4, 0.5))
    for side, bn in ((-1, "Maw_L"), (1, "Maw_R")):
        top = rig.J[bn]
        bot = rig.tips[bn]
        c = (top + bot) / 2 + np.array([side * 0.06, 0, 0.08])
        G.plate(atl, c, (0.34, 0.09, 0.95), {bn: 1.0}, uv["plate_bone"], normal=(side * 0.8, 0, 0.6), along=bot - top,
                taper=(0.55, 0.8))
    # sensory stalks
    for pre in ("Stalk_L", "Stalk_R"):
        bones = [f"{pre}_01", f"{pre}_02"]
        pts = [rig.J[bones[0]], rig.J[bones[1]], rig.tips[bones[1]]]
        Cs = G.resample(pts, 9)
        B.tentacle_mesh(tent, Cs, bones, pts, 0.15, 0.04, (0, 0, 1, 1.0), n=6, ridge=0.1, parent="Head",
                        ridges=5, tile_m=TILE_M, seed=1.3 if pre == "Stalk_L" else 2.1)
        G.orb(atl, pts[-1], 0.09 if pre == "Stalk_L" else 0.07, {bones[1]: 1.0}, uv["orb_small"], n=6, m=4,
              axis=C.nrm(pts[-1] - pts[-2]))

    # --- ventral sac, sinew stalk, core, ribs ---------------------------------------
    Cs = G.resample(SAC, 10)
    Rs = G.resample([np.array(r) for r in SAC_R], 10)
    _, Ls = G.arclen(Cs)

    def sprof(i, s, th):
        sag = 1.0 + 0.18 * max(0.0, -math.cos(th)) ** 2
        return sag * (1.0 + 0.08 * math.sin(4 * th + s * 10) + 0.05 * math.sin(7 * th))
    G.sweep(hide, Cs, [tuple(r) for r in Rs], lambda p, s: {"Belly": 1.0}, (0, 0, 2, Ls / TILE_M), n=14, prof=sprof,
            tip=0.2, base_cap=True, front=(0, -1, 0))
    stalk = G.resample([(0.2, 9.3, -0.4), (0.35, 8.4, -0.3), (0.1, 7.4, -0.2)], 6)
    G.sweep(atl, stalk, [0.26, 0.22, 0.2, 0.2, 0.24, 0.3], lambda p, s: {"Body": 1 - s, "Belly": s}, uv["sinew"], n=6,
            front=(0, 0, 1))
    G.orb(atl, (0.3, 8.35, -0.3), 0.55, {"Body": 0.6, "Belly": 0.4}, uv["core"], n=10, m=6, axis=(0.2, 1, 0.1),
          squash=(1.0, 0.9, 1.15))
    ribs = [(-1, -2.3, 1.0), (-1, -1.0, 1.0), (-1, 0.3, 1.0), (-1, 1.6, 1.0), (1, -1.6, 1.0), (1, -0.1, 1.0),
            (1, 1.3, 1.0), (1, -2.7, 0.55)]
    for side, z, frac in ribs:
        pts = [(side * 2.05, 9.35, z), (side * 2.75, 8.6, z + 0.25), (side * 2.6, 7.4, z + 0.15), (side * 1.45, 6.75, z + 0.1)]
        Cr = G.resample(pts, 9)
        if frac < 1.0:
            Cr = Cr[:max(3, int(len(Cr) * frac))]
        S, _ = G.arclen(Cr)
        rr = [0.24 - 0.08 * math.sin(math.pi * s) for s in S]
        G.sweep(atl, Cr, rr, lambda p, s: {"Body": 1 - s * frac, "Belly": s * frac}, uv["rib"], n=6,
                tip=0.12 if frac < 1.0 else 0.0, front=(0, 0, 1))

    # --- legs ----------------------------------------------------------------------
    for k, (par, s, e, w, c, (rt, rj, rw), kind) in LEGS.items():
        b = legs[k]
        s, e, w, c = (np.array(v, float) for v in (s, e, w, c))
        inside = s + (np.array([0.0, 0.1, 0.0]) - np.array([s[0], 0, 0])) * 0.45
        # the sweep runs down into the foot (fore: under the claw roots; hind: onto the hoof plate) - ending it at
        # 0.55 left the hind hoofs ~0.3 m (1.8 m at encounter scale) below the leg and the fore claws detached
        end_f = 0.86 if kind == "hind" else 0.78
        pts = [inside, s, s + (e - s) * 0.5 + np.array([0, 0.35, 0]), e, e + (w - e) * 0.25, e + (w - e) * 0.62, w,
               w + (c - w) * 0.55, w + (c - w) * end_f]
        Cl = G.resample(pts, 22)
        S, Ll = G.arclen(Cl)
        stops = G.stops_from_joints(Cl, [inside, s, e, w], [par, b[0], b[1], b[2]])
        wf = G.chain_w(stops, blend=0.07)
        se = stops[2][0]
        sw_ = stops[3][0]

        def radius(sv, rt=rt, rj=rj, rw=rw, se=se, sw_=sw_):
            if sv < se:
                return rt + (rj - rt) * (sv / se) + 0.12 * rt * math.sin(math.pi * sv / se)
            if sv < sw_:
                q = (sv - se) / (sw_ - se)
                return rj * (1 - q) ** 1.4 + rw * (1 - (1 - q) ** 1.4) + 0.1 * rj * math.exp(-(q / 0.08) ** 2)
            return rw * (1.0 + 0.25 * (sv - sw_) / (1 - sw_))
        radii = [radius(sv) for sv in S]

        def lprof(i, sv, th, se=se, sw_=sw_):
            flute = 1.0 + (0.12 if se < sv < sw_ else 0.05) * math.cos(5 * th + 0.4)
            knob = 1.0 + 0.22 * math.exp(-((sv - se) / 0.035) ** 2) * (0.6 + 0.4 * math.cos(th))
            return flute * knob
        G.sweep(hide, Cl, radii, wf, (0, 0, 1, Ll / TILE_M), n=10, prof=lprof, front=(0, 0, 1) if kind == "fore" else (0, 0, -1))
        # joint plates around the elbow / knee + a backward spur
        dir_up = C.nrm(e - s)
        dir_dn = C.nrm(w - e)
        for q, (ang, sz) in enumerate([(0.3, 1.0), (1.9, 0.8), (3.6, 0.9)]):
            a_, b_ = C.tube_frame(C.nrm(dir_up + dir_dn), (0, 1, 0))
            nrmv = a_ * math.cos(ang) + b_ * math.sin(ang)
            G.plate(atl, e + nrmv * rj * 0.92, (0.9 * sz * rj * 1.6, 0.14, 1.0 * sz * rj * 1.7), {b[0]: 0.5, b[1]: 0.5},
                    uv["plate_glow" if (q == 1 and k in ("FL", "HR")) else "plate_char"], normal=nrmv, along=dir_dn)
        spur_dir = C.nrm(np.cross(dir_dn, np.cross(dir_up, dir_dn)) * -1 + np.array([0, 0.4, 0]))
        if kind == "hind":
            spur_dir = C.nrm(np.array([0, 0.5, 1.0]))
        else:
            spur_dir = C.nrm(np.array([0, 0.6, -1.0]))
        sp = [e, e + spur_dir * rj * 1.4, e + spur_dir * rj * 2.4 + np.array([0, 0.25, 0])]
        Csp = G.resample(sp, 5)
        G.sweep(atl, Csp, [rj * 0.45, rj * 0.32, rj * 0.2, rj * 0.12, rj * 0.06], lambda p, sv, bb=b[0]: {bb: 1.0},
                uv["claw"], n=5, tip=0.2, front=(0, 1, 0))
        # feet
        fwd = np.array([0.0, 0.0, 1.0])
        lat = np.array([1.0 if c[0] > 0 else -1.0, 0, 0])
        if kind == "fore":
            base = w + (c - w) * 0.64                # claw roots inside the foot end of the leg sweep
            for dlat, dfw, ln in ((-0.55, 0.85, 1.25), (0.05, 1.05, 1.45), (0.6, 0.7, 1.1)):
                tipp = np.array([c[0] + lat[0] * dlat, 0.11, c[2] + dfw * ln])
                mid = base + (tipp - base) * 0.5 + np.array([0, 0.35, 0]) + fwd * 0.15
                Cdg = G.resample([base, mid, tipp], 6)
                G.sweep(atl, Cdg, [0.22, 0.2, 0.17, 0.13, 0.09, 0.05], lambda p, sv, bb=b[2]: {bb: 1.0}, uv["claw"],
                        n=5, tip=0.12, front=(0, -1, 0))
        else:
            G.plate(atl, np.array([c[0], 0.2, c[2] + 0.25]), (1.1, 0.35, 1.5), {b[2]: 1.0}, uv["hoof"], normal=(0, 1, 0),
                    along=(lat[0] * 0.15, 0, 1), taper=(0.7, 0.75))
            for dlat in (-0.35, 0.4):
                base = np.array([c[0] + dlat, 0.3, c[2] + 0.62])     # rooted in the hoof plate
                tipp = base + np.array([dlat * 0.4, -0.24, 0.65])
                Cdg = G.resample([base, (base + tipp) / 2 + np.array([0, 0.12, 0]), tipp], 5)
                G.sweep(atl, Cdg, [0.18, 0.15, 0.11, 0.07, 0.04], lambda p, sv, bb=b[2]: {bb: 1.0}, uv["claw"], n=5,
                        tip=0.1, front=(0, -1, 0))

    # --- tentacles + orifices -----------------------------------------------------------
    for k, (par, path, r0, nb) in TENTACLES.items():
        bones, jp, Cd2 = tents[k]
        Lt = B.tentacle_mesh(tent, Cd2, bones, jp, r0, 0.05, (0, 0, 1, 1.0), n=8, parent=par,
                             seed=sum(map(ord, k)) % 7, ridges=10 + nb, tile_m=TILE_M)
        d0 = C.nrm(np.array(path[1]) - np.array(path[0]))
        base = np.array(path[0])
        Cc = G.resample([base - d0 * 0.45, base - d0 * 0.1, base + d0 * 0.2], 4)
        G.sweep(atl, Cc, [r0 * 2.1, r0 * 1.85, r0 * 1.45, r0 * 1.15], lambda p, s, pp=par: {pp: 1.0}, uv["collar"],
                n=10, prof=lambda i, s, th: 1.0 + 0.12 * math.sin(9 * th) * (1 - s), front=(0, 0, 1))

    # --- dorsal plates, gill openings ---------------------------------------------------
    rng = np.random.default_rng(707)
    R_ = dorsal_rings
    picks = [(4, 0), (5, 1), (6, 17), (7, 0), (8, 2), (9, 1), (10, 16), (11, 0), (12, 2), (12, 15), (13, 1), (14, 0),
             (15, 2), (15, 17), (16, 1), (11, 3), (10, 4), (13, 4), (9, 3), (14, 16)]
    for q, (i, j) in enumerate(picks):
        ring_ = R_[i]
        p = ring_[j]
        cen = ring_.mean(0)
        nv = C.nrm(p - cen)
        tang = C.nrm(Cd[min(i + 1, len(Cd) - 1)] - Cd[max(i - 1, 0)])
        sz = (0.9 + 0.7 * rng.random(), 0.16, 1.2 + 0.9 * rng.random())
        key = "plate_bone" if q % 3 == 0 else ("plate_glow" if q in (4, 11) else "plate_char")
        G.plate(atl, p + nv * 0.06, sz, body_weight(p), uv[key], normal=nv, along=tang + nv * 0.25, taper=(0.6, 0.7))
    for q in range(3):
        z = -0.6 + q * 0.75
        c = np.array([2.55 - 0.05 * q, 10.0 - 0.15 * q, z])
        G.orb(atl, c, 0.42, body_weight(c), uv["gill"], n=8, m=4, axis=(1, -0.1, 0.1), squash=(0.35, 1.3, 0.25))
    return meshes


# ================================================================== animation
def pose_factory(rig, legs, tents):
    contact = {k: rig.tips[legs[k][2]] for k in legs}
    tb = {k: v[0] for k, v in tents.items()}

    def legs_ik(local, trans, targets, foot_rots=None):
        Rw, Pw = rig.fk(local, trans)
        for k, b in legs.items():
            fr = (foot_rots or {}).get(k)
            C.ik_leg(rig, Rw, Pw, local, b[0], b[1], b[2], targets.get(k, contact[k]), foot_R=fr)
        return local

    def tent_layer(local, t, amp=1.0, freq=0.35, period=None):
        for q, (k, bones) in enumerate(tb.items()):
            a = amp * (5.0 if k.startswith("T_Vent") else 7.0)
            B.wave(rig, local, bones, t, amp=a, amp2=a * 0.8, freq=freq * (1 + 0.13 * q), lag=0.55, phase=q * 1.7,
                   period=period)
        return local

    def head_layer(local, t, nod=0.0, turn=0.0, maw=0.0, stalk=1.0, period=None):
        f1, f2 = B.cyc(0.4, period), B.cyc(0.55, period)
        local["Head"] = C.R((0, 1, 0), turn) @ C.R((1, 0, 0), nod)
        local["Maw_L"] = C.R((0, 0, 1), -maw)
        local["Maw_R"] = C.R((0, 0, 1), maw)
        for q, pre in enumerate(("Stalk_L", "Stalk_R")):
            local[f"{pre}_01"] = C.R((1, 0, 0), stalk * 8 * math.sin(2 * math.pi * f1 * t + q * 2))
            local[f"{pre}_02"] = C.R((0, 0, 1), stalk * 12 * math.sin(2 * math.pi * f2 * t + q))
        return local

    def guard(local, trans, floor=0.25):
        for k, bones in tb.items():
            rad = [0.5] * (len(bones) + 1)
            local = B.floor_clamp(rig, local, trans, bones, floor, rad=rad)
        return local

    # ---- clips -------------------------------------------------------------------
    def idle(t, T=4.0):
        ph = 2 * math.pi * t / T
        local, trans = {}, {}
        trans["Body"] = (0, 0.10 * math.sin(ph), 0)
        local["Body"] = C.R((1, 0, 0), 0.8 * math.sin(ph + 0.6))
        local["Belly"] = C.R((0, 0, 1), 2.2 * math.sin(ph * 0.5 * 2)) @ C.R((1, 0, 0), 1.5 * math.sin(ph + 1.2))
        local["Chest"] = C.R((1, 0, 0), -0.6 * math.sin(ph))
        head_layer(local, t, nod=2.0 * math.sin(ph + 0.4), turn=3.0 * math.sin(ph), maw=3.0 + 3.0 * math.sin(ph), period=T)
        legs_ik(local, trans, {})
        tent_layer(local, t, amp=0.6, freq=0.25, period=T)
        return guard(local, trans), trans

    SL, DUTY, WT = 3.0, 0.75, 4.0
    PHASE = {"HL": 0.0, "FL": 0.25, "HR": 0.5, "FR": 0.75}
    LIFT = {"FL": 1.3, "FR": 1.2, "HL": 0.95, "HR": 0.9}

    def gait(t, period=WT, sl=SL, lift_k=1.0):
        targets, frots = {}, {}
        for k in legs:
            u = ((t / period) + PHASE[k]) % 1.0
            c = contact[k].copy()
            if u < DUTY:
                dz = sl / 2 - sl * (u / DUTY)
                c[2] += dz
            else:
                q = (u - DUTY) / (1 - DUTY)
                c[2] += -sl / 2 + sl * C.smooth(q)
                c[1] += LIFT[k] * lift_k * math.sin(math.pi * q)
                c[0] += (-0.3 if c[0] > 0 else 0.3) * math.sin(math.pi * q)
                frots[k] = C.R((1, 0, 0), -28 * math.sin(math.pi * q))
            targets[k] = c
        return targets, frots

    def walk(t):
        ph = 2 * math.pi * t / WT
        local, trans = {}, {}
        trans["Body"] = (0.18 * math.sin(ph), -0.22 + 0.16 * math.cos(2 * ph), 0.08 * math.sin(2 * ph))
        local["Body"] = C.R((0, 0, 1), 2.4 * math.sin(ph)) @ C.R((0, 1, 0), 1.8 * math.sin(ph + 0.8)) @ C.R((1, 0, 0), 1.2 * math.cos(2 * ph))
        local["Rear"] = C.R((0, 0, 1), -1.6 * math.sin(ph + 0.5))
        local["Chest"] = C.R((0, 1, 0), -1.5 * math.sin(ph + 1.2))
        local["Belly"] = C.R((0, 0, 1), -4.0 * math.sin(ph - 0.6)) @ C.R((1, 0, 0), 2.5 * math.sin(2 * ph - 0.8))
        head_layer(local, t, nod=3.0 * math.sin(2 * ph + 1.0), turn=-3.0 * math.sin(ph + 1.4), maw=2.0, period=WT)
        tg, fr = gait(t)
        legs_ik(local, trans, tg, fr)
        tent_layer(local, t, amp=0.9, freq=0.5, period=WT)
        for k in ("T_DorsalL", "T_DorsalR"):
            B.curl(rig, local, tb[k][:3], [-3.0 * math.sin(ph)] * 3)
        return guard(local, trans), trans

    def sway(t):
        local, trans = idle(t, 6.0)
        tent_layer(local, t, amp=2.2, freq=0.33, period=6.0)
        for q, k in enumerate(tb):
            B.curl(rig, local, tb[k], 6.0 * math.sin(2 * math.pi * t / 6.0 + q * 1.1), axis="sweep")
        return guard(local, trans), trans

    def alert_pose(t, amt):
        local, trans = {}, {}
        ph = 2 * math.pi * t / 4.0
        trans["Body"] = (0, 0.55 * amt + 0.05 * math.sin(ph), -0.25 * amt)
        local["Body"] = C.R((1, 0, 0), -4.0 * amt)
        local["Chest"] = C.R((1, 0, 0), -3.0 * amt)
        tw = amt * math.sin(2 * math.pi * 3.0 * t) * (1 - amt) * 4
        head_layer(local, t, nod=-14 * amt + tw, turn=9 * amt * math.sin(min(t, 1.6) * 1.9), maw=3 + 16 * amt, stalk=1 + 2 * amt)
        legs_ik(local, trans, {})
        tent_layer(local, t, amp=0.8 + 0.6 * amt, freq=0.45)
        B.curl(rig, local, tb["T_DorsalL"][:4], [-10 * amt, -6 * amt, 4 * amt, 6 * amt])
        B.curl(rig, local, tb["T_DorsalR"][:4], [-12 * amt, -8 * amt, -4 * amt, 0])
        B.curl(rig, local, tb["T_FlankL"][:3], [-14 * amt, -8 * amt, -4 * amt])
        B.curl(rig, local, tb["T_FlankR"][:3], [-12 * amt, -6 * amt, -4 * amt])
        return guard(local, trans), trans

    def alert(t):
        return alert_pose(t, C.ease(t, 0.0, 1.4))

    def strike(t):
        # wind up (0-0.7), whip the arching dorsal tentacle forward over the hood (0.7-1.05), hold, recover
        local, trans = idle(t)
        wind = C.pulse(t, 0.0, 0.65, 0.7, 0.95)
        hit = C.pulse(t, 0.72, 1.02, 1.5, 2.3)
        trans["Body"] = (0, 0.1 * math.sin(t), -0.3 * wind + 0.45 * hit)
        local["Body"] = C.R((1, 0, 0), -3 * wind + 4 * hit)
        head_layer(local, t, nod=-8 * wind + 6 * hit, maw=4 + 14 * wind)
        local = legs_ik(local, trans, {})
        bones = tb["T_DorsalL"]
        B.curl(rig, local, bones, [-14 * wind + 40 * hit] + [-9 * wind + 21 * hit] * (len(bones) - 1))
        B.curl(rig, local, tb["T_DorsalR"], [-6 * wind - 3 * hit] * len(tb["T_DorsalR"]))
        B.curl(rig, local, tb["T_FlankR"], [-6 * wind + 8 * hit] * len(tb["T_FlankR"]))
        return guard(local, trans, floor=0.2), trans

    def heavy(t):
        # rear up on the hind legs (0-1.4), slam both forefeet down (1.4-1.75), shudder, recover (2.3-3.4)
        up = C.pulse(t, 0.0, 1.35, 1.4, 1.72)
        slam = C.pulse(t, 1.45, 1.75, 2.3, 3.3)
        local, trans = {}, {}
        trans["Body"] = (0, 0.9 * up - 0.55 * slam, -0.6 * up + 0.5 * slam)
        local["Body"] = C.R((1, 0, 0), -11 * up + 5 * slam)
        local["Chest"] = C.R((1, 0, 0), -5 * up + 3 * slam)
        local["Belly"] = C.R((1, 0, 0), 6 * up - 5 * slam)
        head_layer(local, t, nod=-12 * up + 16 * slam, maw=4 + 18 * up)
        tg = {}
        for k in ("FL", "FR"):
            c = contact[k].copy()
            c[1] += 3.2 * up
            c[2] += 0.9 * up + 1.3 * slam
            tg[k] = c
        fr = {k: C.R((1, 0, 0), -35 * up) for k in ("FL", "FR")}
        legs_ik(local, trans, tg, fr)
        tent_layer(local, t, amp=1.0 + 1.5 * slam, freq=0.6)
        for k in ("T_DorsalL", "T_DorsalR"):
            B.curl(rig, local, tb[k], [-5 * up + 7 * slam] * len(tb[k]))
        return guard(local, trans), trans

    def hit(t):
        j = C.pulse(t, 0.0, 0.1, 0.18, 1.1)
        sh = math.sin(t * 2 * math.pi * 6) * math.exp(-t * 4)
        local, trans = idle(t)
        trans["Body"] = (0.35 * j, 0.1 * math.sin(t) - 0.2 * j, -0.25 * j)
        local["Body"] = C.R((0, 0, 1), 5 * j + 1.5 * sh) @ C.R((1, 0, 0), -3 * j)
        local["Belly"] = C.R((0, 0, 1), -10 * j + 4 * sh)
        head_layer(local, t, nod=-12 * j + 3 * sh, turn=-10 * j, maw=4 + 14 * j)
        legs_ik(local, trans, {})
        for q, k in enumerate(tb):
            B.curl(rig, local, tb[k], [(-6 - 2 * q % 3) * j + 3 * sh] * len(tb[k]))
        return guard(local, trans), trans

    def death(t):
        st = C.pulse(t, 0.0, 0.35, 0.5, 1.0)
        dn = C.ease(t, 0.8, 3.4)
        local, trans = {}, {}
        trans["Body"] = (0.3 * st + 0.5 * dn, -3.9 * dn - 0.15 * st, 0.4 * dn)
        local["Body"] = C.R((0, 0, 1), 4 * st + 7 * dn) @ C.R((1, 0, 0), 5 * dn)
        local["Rear"] = C.R((0, 0, 1), -3 * dn)
        local["Chest"] = C.R((1, 0, 0), 6 * dn)
        local["Belly"] = C.R((1, 0, 0), -10 * dn) @ C.R((0, 0, 1), -6 * dn)
        head_layer(local, t * (1 - dn) + 0.1, nod=-8 * st + 26 * dn, turn=6 * dn, maw=4 + 12 * st + 8 * dn, stalk=1 - dn)
        tg = {}
        for k in legs:
            c = contact[k].copy()
            out = 1.0 + 0.34 * dn if k.startswith("F") else 1.0 + 0.42 * dn
            c[0] *= out
            c[2] += (1.4 if k.startswith("F") else -1.7) * dn
            tg[k] = c
        legs_ik(local, trans, tg)
        tent_layer(local, t, amp=(1 - dn) * 1.5 + 0.1, freq=0.7)
        for k in tb:
            B.curl(rig, local, tb[k], [10 * dn] * len(tb[k]))
        return guard(local, trans, floor=0.2), trans

    clips = [("Idle_Breathe", idle, 4.0, True), ("Walk_Heavy", walk, WT, True), ("Tentacles_Sway", sway, 6.0, True),
             ("Alert", alert, 2.4, False), ("Attack_TentacleStrike", strike, 2.4, False), ("Attack_Heavy", heavy, 3.4, False),
             ("Hit_React", hit, 1.2, False), ("Death_Collapse", death, 4.5, False)]
    return clips, {"walk_speed_mps": SL / (WT * DUTY), "stride_m": SL, "cycle_s": WT}


def build():
    tex, uv = textures()
    rig, legs, tents = build_rig()
    meshes = build_mesh(rig, legs, tents, uv)
    clip_defs, loco = pose_factory(rig, legs, tents)
    clips, frames = [], {}
    for nm, fn, dur, loop in clip_defs:
        c, fr = C.bake(rig, nm, fn, dur, FPS, loop)
        clips.append(c)
        frames[nm] = fr
    mats = {
        "M_Crt_Colossus_Hide": dict(albedo=tex["hide"][0], emit=tex["hide"][1], emit_factor=(0.55, 0.6, 0.62), emit_energy=0.55,
                                    repeat=True, rough=0.88),
        "M_Crt_Tentacle": dict(albedo=tex["tent"][0], emit=tex["tent"][1], emit_factor=(0.5, 0.55, 0.58), emit_energy=0.5,
                               repeat=True, rough=0.7),
        "M_Crt_Colossus": dict(albedo=tex["atlas"][0], emit=tex["atlas"][1], emit_factor=(0.7, 0.75, 0.78), emit_energy=0.8,
                               repeat=False, rough=0.85),
    }
    sockets = [("Socket_Head", "Head", (0.0, 8.0, 7.4)), ("Socket_Core", "Body", (0.3, 8.35, -0.3)),
               ("Socket_DorsalTip", tents["T_DorsalL"][0][-1], rig.tips[tents["T_DorsalL"][0][-1]])]
    extras = {"veil_creature": "Colossus", "faces": "+Z", "units": "m", "locomotion": loco,
              "legs": {k: v for k, v in legs.items()}, "tentacles": {k: v[0] for k, v in tents.items()}}
    glb, tris = B.export(NAME, "Colossus", rig, meshes, mats, sockets, clips, extras)
    # strike impact point = dorsal tentacle tip at the moment of impact (for future attack timing / VFX)
    hit_t = 1.05
    fr = frames["Attack_TentacleStrike"][int(round(hit_t * FPS))]
    tipb = tents["T_DorsalL"][0][-1]
    impact = B.chain_points(rig, fr[0], fr[1], tents["T_DorsalL"][0])[-1]
    S.creature_scene(
        os.path.join(C.CR, "Godot_Scenes", "CRT_Colossus.tscn"), "Colossus", glb,
        shapes=[("BodyShape", "BoxShape3D", {"size": (5.8, 4.2, 12.0)}, (0, 10.3, 0.3)),
                ("SacShape", "BoxShape3D", {"size": (3.2, 2.2, 5.6)}, (0, 6.6, -0.2)),
                ("HeadShape", "BoxShape3D", {"size": (2.2, 2.2, 2.6)}, (0, 8.0, 6.5)),
                ("LegShape_FL", "CylinderShape3D", {"height": 10.4, "radius": 0.6}, (-5.8, 5.2, 5.0)),
                ("LegShape_FR", "CylinderShape3D", {"height": 10.0, "radius": 0.55}, (5.5, 5.0, 4.6)),
                ("LegShape_HL", "CylinderShape3D", {"height": 9.2, "radius": 0.65}, (-4.2, 4.6, -3.5)),
                ("LegShape_HR", "CylinderShape3D", {"height": 9.0, "radius": 0.6}, (3.9, 4.5, -3.8))],
        markers=[("LookTarget", (0.0, 8.0, 7.4)), ("CoreTarget", (0.3, 8.35, -0.3)), ("StrikeImpact", impact)],
        meta={"veil_creature": "Colossus", "faces": "+Z", "animation_player": "Model/AnimationPlayer",
              "animations": [c.name for c in clips], "walk_speed_mps": round(loco["walk_speed_mps"], 3),
              "strike_impact_time_s": hit_t})
    return dict(name=NAME, glb=glb, tris=tris, rig=rig, legs=legs, tents=tents, clips=clips, frames=frames, meshes=meshes,
                mats=mats, sockets=sockets, feet=[v[2] for v in legs.values()], edge_floor=0.15, probe=tents["T_DorsalL"][0][-1],
                scene="07_Creatures/Godot_Scenes/CRT_Colossus.tscn",
                limits={"max_stretch": 2.0, "max_stretch_death": 2.5, "p999_stretch": 1.5, "p999_stretch_death": 1.9,
                        "min_y": -0.08})


if __name__ == "__main__":
    r = build()
    print(r["glb"], "tris", r["tris"], "bones", len(r["rig"].bones), "clips", [c.name for c in r["clips"]])
