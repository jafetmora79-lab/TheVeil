"""Rev 3 sculpt designs: Eddie and Marcus (docs/THE_VEIL_MASTER_CONTEXT.md, section 4).

Each design is a skeleton plus hand-placed organic volumes, written the way a modeller blocks out a character:
big readable masses first (head, torso, pelvis, limbs), then the secondary forms that carry personality
(jaw, cheeks, brow, nose, ears, hair clumps, hood, collar, cuffs, pockets, soles), then carved details
(eye sockets, mouth line, jacket opening). Facial features are placed by ray-casting onto the sculpted head,
so they sit on the surface exactly.
"""
import math

import numpy as np

from chr_core import nrm, v3
from chr_sculpt import rotm
from chr_sculpt_build import Sculpt, tube


def mx(p):
    return v3(-p[0], p[1], p[2])


def axis_R(d, up=(0, 0, 1)):
    """rotation whose local Y axis runs along d (for limb-aligned ellipsoids)"""
    d = nrm(np.asarray(d, float))
    a = nrm(np.cross(d, np.asarray(up, float)))
    b = np.cross(a, d)
    return np.column_stack([a, d, b])


def brow_strip(sc, pts_xy, z0=0.4, lift=0.004, r=0.0065, squash=0.55):
    pts = []
    for (x, y) in pts_xy:
        h = sc.hit(v3(x, y, z0), v3(0, 0, -1), labels={"skin"})
        pts.append(h + v3(0, 0, lift))
    P, F = tube(pts, [r * 0.85] + [r] * (len(pts) - 2) + [r * 0.75], nseg=6, squash=squash, up=(0, 0, 1))
    sc.accessory(P, F, "brow", "head")


def glasses(sc, eye_l, eye_r, w=0.052, h=0.042, r=0.0048, fwd=0.016, ear_y=None):
    for e, sx in ((eye_l, 1), (eye_r, -1)):
        c = e + v3(0, 0.002, fwd)
        path = []
        for k in range(16):
            t = 2 * math.pi * k / 16
            ca, sa = math.cos(t), math.sin(t)
            # rounded rectangle (superellipse)
            px = math.copysign(abs(ca) ** 0.55, ca) * w / 2
            py = math.copysign(abs(sa) ** 0.55, sa) * h / 2
            path.append(c + v3(px, py, -0.004 * (px * sx > 0) * abs(ca)))
        P, F = tube(path, [r] * 16, nseg=5, closed=True, up=(0, 0, 1))
        sc.accessory(P, F, "glasses", "head")
        # temple arm back to the ear
        outer = c + v3(sx * w / 2, h * 0.25, -0.004)
        ear = v3(sx * (abs(outer[0]) + 0.02), (ear_y if ear_y else outer[1]) + 0.004, outer[2] - 0.13)
        P, F = tube([outer, outer + v3(sx * 0.012, 0, -0.02), ear], [r * 0.9] * 3, nseg=4, up=(0, 1, 0))
        sc.accessory(P, F, "glasses", "head")
    a = eye_l + v3(-w / 2, 0.008, fwd + 0.004)
    b = eye_r + v3(w / 2, 0.008, fwd + 0.004)
    m = (a + b) / 2 + v3(0, 0.006, 0.006)
    P, F = tube([a, m, b], [r * 0.9] * 3, nseg=4, up=(0, 1, 0))
    sc.accessory(P, F, "glasses", "head")


# =============================================================================================== EDDIE
def eddie():
    """Lanky, slouched game-shop clerk: tall egg head on a long thin neck, jutting chin, big droopy nose,
    stick-out ears (left one higher), one eyebrow cocked, chunky glasses, a rounded mop of hair that swoops to
    one side, an open oversized mustard hoodie with a hood and pocket halves, baggy jeans, huge sneakers
    pointing outwards."""
    sc = Sculpt("Eddie_v3", 1.80)
    J = {
        "Root": v3(0, 0, 0), "Hips": v3(0, 0.93, 0.0), "Spine": v3(0, 1.05, 0.006), "Chest": v3(0, 1.17, 0.004),
        "UpperChest": v3(0, 1.28, 0.0), "Neck": v3(0, 1.36, 0.02), "Head": v3(0, 1.47, 0.062),
        "LeftShoulder": v3(0.04, 1.31, -0.005), "LeftUpperArm": v3(0.165, 1.295, -0.005), "LeftLowerArm": v3(0.30, 1.062, 0.022),
        "LeftHand": v3(0.384, 0.848, 0.068),
        "RightShoulder": v3(-0.04, 1.30, -0.005), "RightUpperArm": v3(-0.162, 1.282, -0.005), "RightLowerArm": v3(-0.292, 1.050, 0.03),
        "RightHand": v3(-0.372, 0.836, 0.078),
        "LeftUpperLeg": v3(0.088, 0.90, 0.0), "LeftLowerLeg": v3(0.098, 0.505, 0.02), "LeftFoot": v3(0.106, 0.118, -0.01),
        "LeftToes": v3(0.142, 0.035, 0.14),
        "RightUpperLeg": v3(-0.088, 0.90, 0.0), "RightLowerLeg": v3(-0.098, 0.505, 0.02), "RightFoot": v3(-0.106, 0.118, -0.01),
        "RightToes": v3(-0.137, 0.035, 0.145),
    }
    sc.J = J
    sc.ends = {"Head": v3(0, 1.72, 0.06), "LeftToes": v3(0.17, 0.03, 0.23), "RightToes": v3(-0.165, 0.03, 0.235)}
    A = sc.add
    # ---- hoodie first, then carve its open front (so the shirt added later fills the gap) -------------
    A("cone", "hoodie", "torso", a=v3(0, 0.955, 0.0), b=v3(0, 1.15, 0.0), r1=0.172, r2=0.18, k=0.04)
    A("ell", "hoodie", "upper", c=v3(0, 1.19, -0.004), r=(0.172, 0.14, 0.150), k=0.05)
    A("cone", "hoodie", "upper", a=v3(0.162, 1.29, -0.006), b=v3(-0.16, 1.28, -0.006), r1=0.083, r2=0.080, k=0.05)
    A("ell", "hoodie", "torso", c=v3(0, 0.95, 0.0), r=(0.19, 0.03, 0.15), k=0.02)
    A("ell", "hoodie", "upper", c=v3(0, 1.335, -0.092), r=(0.13, 0.07, 0.072), R=rotm(pitch=-25), k=0.035)
    for sx in (1, -1):
        A("ell", "hoodie", "upper", c=v3(sx * 0.085, 1.352, 0.035), r=(0.045, 0.042, 0.07), k=0.03)
        A("ell", "hoodie", "torso", c=v3(sx * 0.098, 1.005, 0.163), r=(0.068, 0.055, 0.022), k=0.012)
    A("box", "hoodie", "torso", op="sub", c=v3(0, 1.11, 0.21), half=(0.06, 0.215, 0.11), rr=0.02, k=0.012)
    # ---- shirt (black tee) inside the opening ---------------------------------------------------------
    A("ell", "tee", "upper", c=v3(0, 1.19, 0.0), r=(0.142, 0.125, 0.112), k=0.03)
    A("ell", "tee", "torso", c=v3(0, 1.04, 0.03), r=(0.128, 0.10, 0.112), k=0.04)
    # ---- sleeves (baggy) + cuffs ------------------------------------------------------------------------
    for side, sx in (("Left", 1), ("Right", -1)):
        S_, E, W = J[side + "UpperArm"], J[side + "LowerArm"], J[side + "Hand"]
        d1, d2 = nrm(E - S_), nrm(W - E)
        sc.chain("hoodie", "arm_" + side, [S_ - d1 * 0.03, S_ + d1 * 0.06, (S_ + E) / 2, E, (E + W) / 2, W - d2 * 0.035],
                 [0.076, 0.072, 0.067, 0.063, 0.061, 0.057], k=0.018)
        A("ell", "hoodie", "arm_" + side, c=W - d2 * 0.03, r=(0.06, 0.024, 0.06), R=axis_R(d2), k=0.008)
    # ---- jeans (baggy) ----------------------------------------------------------------------------------
    A("ell", "jeans", "pelvis", c=v3(0, 0.915, 0.0), r=(0.152, 0.105, 0.115), k=0.03)
    for side, sx in (("Left", 1), ("Right", -1)):
        Hp, K, Af = J[side + "UpperLeg"], J[side + "LowerLeg"], J[side + "Foot"]
        sc.chain("jeans", "leg_" + side, [Hp + v3(0, 0.03, 0), (Hp * 0.45 + K * 0.55), K, (K * 0.5 + Af * 0.5) + v3(0, 0, -0.004), Af + v3(0, 0.035, 0.005)],
                 [0.094, 0.086, 0.077, 0.081, 0.089], k=0.03)
        A("ell", "jeans", "leg_" + side, c=Af + v3(0, 0.03, 0.005), r=(0.094, 0.02, 0.094), k=0.01)
    # ---- giant sneakers ---------------------------------------------------------------------------------
    for side, sx in (("Left", 1), ("Right", -1)):
        Af = J[side + "Foot"]
        R = rotm(yaw=15 * sx)
        g = "foot_" + side
        base = v3(Af[0] + sx * 0.006, 0, Af[2])
        A("box", "sole", g, c=base + R @ v3(0, 0.021, 0.07), half=(0.068, 0.021, 0.17), R=R, rr=0.018, k=0.004, bias=0.004)
        A("ell", "shoe_" + side, g, c=base + R @ v3(0, 0.068, 0.045), r=(0.066, 0.055, 0.135), R=R, k=0.02)
        A("ell", "shoe_" + side, g, c=base + R @ v3(0, 0.054, 0.175), r=(0.062, 0.043, 0.068), R=R, k=0.025)
        A("cone", "shoe_" + side, g, a=base + v3(0, 0.09, -0.02), b=base + v3(0, 0.145, -0.012), r1=0.063, r2=0.058, k=0.02)
    # ---- neck + head --------------------------------------------------------------------------------------
    A("cone", "skin", "neck", a=v3(0, 1.33, 0.005), b=v3(0, 1.50, 0.062), r1=0.041, r2=0.038, k=0.02)
    A("ell", "skin", "head", c=v3(0, 1.588, 0.064), r=(0.104, 0.122, 0.112), R=rotm(pitch=-8), k=0.03)
    A("cone", "skin", "head", a=v3(0, 1.53, 0.094), b=v3(0, 1.448, 0.160), r1=0.068, r2=0.034, k=0.045)
    for sx in (1, -1):
        A("ell", "skin", "head", c=v3(sx * 0.056, 1.533, 0.126), r=(0.040, 0.034, 0.038), k=0.03)
    A("ell", "skin", "head", c=v3(0, 1.618, 0.148), r=(0.082, 0.02, 0.032), k=0.03)
    # ears stick out (left a little higher), with a carved bowl
    for sx, dy in ((1, 0.010), (-1, 0.0)):
        c = v3(sx * 0.103, 1.585 + dy, 0.055)
        A("ell", "skin", "head", c=c, r=(0.016, 0.045, 0.030), R=rotm(yaw=28 * sx), k=0.008)
        A("ell", "skin", "head", op="sub", c=c + rotm(yaw=28 * sx) @ v3(sx * 0.012, 0, 0.004), r=(0.008, 0.026, 0.016), R=rotm(yaw=28 * sx), k=0.004)
    # eye sockets
    eyes = []
    for sx in (1, -1):
        h = sc.hit(v3(sx * 0.041, 1.589, 0.4), v3(0, 0, -1), labels={"skin"})
        eyes.append(h)
        A("ell", "skin", "head", op="sub", c=h + v3(0, 0, -0.003), r=(0.021, 0.015, 0.013), k=0.012)
    # big droopy nose
    br = sc.hit(v3(0, 1.603, 0.4), v3(0, 0, -1), labels={"skin"})
    A("cone", "skin", "head", a=br + v3(0, 0, -0.01), b=v3(0.002, 1.540, br[2] + 0.064), r1=0.013, r2=0.019, k=0.015)
    A("ell", "skin", "head", c=v3(0.004, 1.536, br[2] + 0.062), r=(0.027, 0.025, 0.024), k=0.012)
    for sx in (1, -1):
        A("ell", "skin", "head", c=v3(sx * 0.021 + 0.003, 1.528, br[2] + 0.045), r=(0.014, 0.012, 0.013), k=0.008)
    # smirking mouth line + pouty lower lip
    mh = sc.hit(v3(0.006, 1.497, 0.4), v3(0, 0, -1), labels={"skin"})
    A("ell", "skin", "head", op="sub", c=mh + v3(0, 0, -0.001), r=(0.031, 0.0045, 0.012), R=rotm(roll=9), k=0.005)
    lh = sc.hit(v3(0.004, 1.486, 0.4), v3(0, 0, -1), labels={"skin"})
    A("ell", "skin", "head", c=lh + v3(0, 0, -0.004), r=(0.021, 0.0075, 0.009), k=0.006)
    # ---- hair: rounded mop that swoops to his right, puffs over the ears, cowlick at the back -------------
    A("ell", "hair", "head", c=v3(0, 1.615, 0.056), r=(0.115, 0.118, 0.124), cut=((0, 1, -0.9), 1.50), k=0.01)
    A("ell", "hair", "head", c=v3(-0.03, 1.705, 0.122), r=(0.10, 0.042, 0.075), R=rotm(pitch=-12, roll=16), k=0.025)
    A("ell", "hair", "head", c=v3(0.02, 1.728, 0.03), r=(0.085, 0.05, 0.095), R=rotm(roll=-10), k=0.03)
    A("ell", "hair", "head", c=v3(0.0, 1.69, -0.068), r=(0.075, 0.055, 0.05), R=rotm(pitch=35), k=0.03)
    A("ell", "hair", "head", c=v3(0.098, 1.642, 0.026), r=(0.035, 0.055, 0.06), k=0.02)
    A("ell", "hair", "head", c=v3(-0.096, 1.628, 0.028), r=(0.03, 0.045, 0.055), k=0.02)
    A("cone", "hair", "head", a=v3(-0.055, 1.688, 0.163), b=v3(-0.026, 1.646, 0.19), r1=0.017, r2=0.011, k=0.01)
    A("ell", "hair", "head", c=v3(0.03, 1.765, -0.02), r=(0.03, 0.03, 0.028), R=rotm(roll=-30), k=0.015)
    # ---- hands (big, relaxed) ---------------------------------------------------------------------------
    for side, sx in (("Left", 1), ("Right", -1)):
        E, W = J[side + "LowerArm"], J[side + "Hand"]
        hd = nrm(W - E + v3(-sx * 0.03, 0, 0.02))
        sc.hand(side, "skin", W + hd * 0.004, hd, v3(-sx, 0, 0.25), s=1.28, curl=24, spread=5)
    # ---- explicit accessories: cocked eyebrows, chunky glasses ------------------------------------------
    el, er = eyes
    brow_strip(sc, [(0.016, 1.630), (0.036, 1.646), (0.058, 1.648), (0.078, 1.636)], r=0.0068)       # left: raised, arched
    brow_strip(sc, [(-0.018, 1.618), (-0.040, 1.621), (-0.062, 1.618), (-0.080, 1.610)], r=0.0068)   # right: flat, low
    glasses(sc, el, er, w=0.056, h=0.046, r=0.005, fwd=0.017, ear_y=1.585)
    sc.feat = dict(eyes=[el, er], eye_r=(0.0105, 0.009), pupils=(0.003, -0.002), mouth=(mh, 0.030, 9.0), nose=br,
                   brows="cocked", style="eddie")
    sc.params = dict(face_box=(0.0, 1.425, 1.70, 0.12), head_center=v3(0, 1.59, 0.06), opening=math.atan(0.06 / 0.18))
    sc.look = dict(skin="skin_tan", hair="hair_brown", top="hoodie", top_ramp="paint_mustard", top_lv=(0, 4),
                   inner="tee", inner_ramp="paint_black", inner_lv=(1, 3), pants="jeans", pants_ramp="denim", pants_lv=(1, 4),
                   shoes="sneakers")
    sc.title, sc.role = "Eddie - game-shop clerk (34) - rev 3 (sculpted)", "Sarcastic, witty, loyal clerk at Greyhaven's independent video game shop."
    sc.folder = "Commercial_NPCs"
    return sc


# =============================================================================================== MARCUS
def marcus():
    """Heavy, worried father: wide square head sunk on a thick short neck, slab jaw and wide chin, heavy brow
    with thick eyebrows pinched up in the middle, potato nose, small tired eyes, receding short hair; barrel
    chest and belly under a long open canvas work jacket with a raised collar and big hip pockets; flannel
    shirt in the opening; straight thick work trousers; heavy boots; big half-closed hands."""
    sc = Sculpt("Marcus_v3", 1.76)
    J = {
        "Root": v3(0, 0, 0), "Hips": v3(0, 0.90, 0.0), "Spine": v3(0, 1.03, 0.012), "Chest": v3(0, 1.17, 0.008),
        "UpperChest": v3(0, 1.31, -0.006), "Neck": v3(0, 1.43, 0.012), "Head": v3(0, 1.485, 0.035),
        "LeftShoulder": v3(0.05, 1.37, -0.01), "LeftUpperArm": v3(0.245, 1.36, -0.012), "LeftLowerArm": v3(0.432, 1.14, 0.012),
        "LeftHand": v3(0.556, 0.93, 0.05),
        "RightShoulder": v3(-0.05, 1.375, -0.01), "RightUpperArm": v3(-0.246, 1.368, -0.012), "RightLowerArm": v3(-0.43, 1.15, 0.01),
        "RightHand": v3(-0.552, 0.94, 0.045),
        "LeftUpperLeg": v3(0.115, 0.865, 0.0), "LeftLowerLeg": v3(0.125, 0.48, 0.02), "LeftFoot": v3(0.13, 0.125, -0.01),
        "LeftToes": v3(0.15, 0.04, 0.15),
        "RightUpperLeg": v3(-0.115, 0.865, 0.0), "RightLowerLeg": v3(-0.125, 0.48, 0.02), "RightFoot": v3(-0.13, 0.125, -0.01),
        "RightToes": v3(-0.148, 0.04, 0.15),
    }
    sc.J = J
    sc.ends = {"Head": v3(0, 1.74, 0.03), "LeftToes": v3(0.17, 0.035, 0.24), "RightToes": v3(-0.168, 0.035, 0.24)}
    A = sc.add
    # ---- work jacket (long, boxy, open) -------------------------------------------------------------------
    A("cone", "jacket", "torso", a=v3(0, 0.84, 0.01), b=v3(0, 1.10, 0.02), r1=0.225, r2=0.232, k=0.05)
    A("ell", "jacket", "upper", c=v3(0, 1.22, 0.006), r=(0.228, 0.19, 0.185), k=0.06)
    A("cone", "jacket", "upper", a=v3(0.24, 1.345, -0.014), b=v3(-0.24, 1.352, -0.014), r1=0.092, r2=0.092, k=0.06)
    A("ell", "jacket", "torso", c=v3(0, 0.84, 0.012), r=(0.235, 0.032, 0.19), k=0.02)
    for sx in (1, -1):        # big hip pockets with flaps
        A("box", "jacket", "torso", c=v3(sx * 0.13, 0.94, 0.205), half=(0.06, 0.055, 0.018), R=rotm(yaw=sx * 28), rr=0.012, k=0.01)
        A("box", "jacket", "torso", c=v3(sx * 0.13, 0.99, 0.215), half=(0.064, 0.012, 0.02), R=rotm(yaw=sx * 28), rr=0.006, k=0.006)
        A("box", "jacket", "upper", c=v3(sx * 0.11, 1.23, 0.186), half=(0.045, 0.04, 0.014), R=rotm(yaw=sx * 20), rr=0.008, k=0.008)
    A("box", "jacket", "torso", op="sub", c=v3(0, 1.08, 0.25), half=(0.055, 0.27, 0.10), rr=0.015, k=0.012)
    # ---- flannel shirt in the opening -----------------------------------------------------------------------
    A("ell", "flannel", "upper", c=v3(0, 1.21, 0.012), r=(0.20, 0.17, 0.162), k=0.04)
    A("ell", "flannel", "torso", c=v3(0, 1.04, 0.045), r=(0.19, 0.14, 0.165), k=0.05)
    # ---- sleeves ----------------------------------------------------------------------------------------------
    for side, sx in (("Left", 1), ("Right", -1)):
        S_, E, W = J[side + "UpperArm"], J[side + "LowerArm"], J[side + "Hand"]
        d1, d2 = nrm(E - S_), nrm(W - E)
        sc.chain("jacket", "arm_" + side, [S_ - d1 * 0.03, S_ + d1 * 0.07, (S_ + E) / 2, E, (E + W) / 2 + d2 * 0.01, W - d2 * 0.04],
                 [0.10, 0.095, 0.087, 0.078, 0.076, 0.07], k=0.02)
        A("ell", "jacket", "arm_" + side, c=W - d2 * 0.035, r=(0.074, 0.026, 0.074), R=axis_R(d2), k=0.008)
    # ---- work trousers + boots --------------------------------------------------------------------------------
    A("ell", "trousers", "pelvis", c=v3(0, 0.88, 0.005), r=(0.20, 0.11, 0.145), k=0.035)
    for side, sx in (("Left", 1), ("Right", -1)):
        Hp, K, Af = J[side + "UpperLeg"], J[side + "LowerLeg"], J[side + "Foot"]
        sc.chain("trousers", "leg_" + side, [Hp + v3(0, 0.03, 0), (Hp * 0.5 + K * 0.5), K, (K * 0.5 + Af * 0.5), Af + v3(0, 0.08, 0.004)],
                 [0.115, 0.104, 0.09, 0.088, 0.086], k=0.03)
        A("ell", "trousers", "leg_" + side, c=Af + v3(0, 0.085, 0.004), r=(0.09, 0.022, 0.09), k=0.01)
        R = rotm(yaw=9 * sx)
        g = "foot_" + side
        base = v3(Af[0] + sx * 0.004, 0, Af[2])
        A("box", "sole", g, c=base + R @ v3(0, 0.022, 0.065), half=(0.072, 0.022, 0.165), R=R, rr=0.012, k=0.004, bias=0.004)
        A("box", "shoe_" + side, g, c=base + R @ v3(0, 0.075, 0.02), half=(0.066, 0.05, 0.11), R=R, rr=0.04, k=0.02)
        A("ell", "shoe_" + side, g, c=base + R @ v3(0, 0.06, 0.16), r=(0.066, 0.046, 0.072), R=R, k=0.025)
        A("cone", "shoe_" + side, g, a=base + v3(0, 0.10, -0.012), b=base + v3(0, 0.19, -0.004), r1=0.075, r2=0.072, k=0.02)
    # ---- neck + head --------------------------------------------------------------------------------------------
    A("cone", "skin", "neck", a=v3(0, 1.40, 0.0), b=v3(0, 1.52, 0.03), r1=0.078, r2=0.074, k=0.03)
    A("ell", "skin", "head", c=v3(0, 1.615, 0.03), r=(0.118, 0.11, 0.118), k=0.03)
    A("box", "skin", "head", c=v3(0, 1.528, 0.065), half=(0.105, 0.058, 0.085), rr=0.045, k=0.05)
    A("box", "skin", "head", c=v3(0, 1.488, 0.112), half=(0.075, 0.03, 0.045), rr=0.026, k=0.035)    # wide chin
    for sx in (1, -1):
        A("ell", "skin", "head", c=v3(sx * 0.07, 1.555, 0.112), r=(0.048, 0.04, 0.042), k=0.035)
    A("cone", "skin", "head", a=v3(0.075, 1.628, 0.128), b=v3(-0.075, 1.628, 0.128), r1=0.024, r2=0.024, k=0.03)   # heavy brow
    for sx, dy in ((1, 0.0), (-1, -0.006)):
        c = v3(sx * 0.121, 1.585 + dy, 0.03)
        A("ell", "skin", "head", c=c, r=(0.015, 0.04, 0.027), R=rotm(yaw=12 * sx), k=0.01)
        A("ell", "skin", "head", op="sub", c=c + v3(sx * 0.01, 0, 0.003), r=(0.007, 0.023, 0.014), R=rotm(yaw=12 * sx), k=0.004)
    eyes = []
    for sx in (1, -1):
        h = sc.hit(v3(sx * 0.047, 1.596, 0.4), v3(0, 0, -1), labels={"skin"})
        eyes.append(h)
        A("ell", "skin", "head", op="sub", c=h + v3(0, 0.002, -0.006), r=(0.023, 0.016, 0.016), k=0.012)
    br = sc.hit(v3(0, 1.60, 0.4), v3(0, 0, -1), labels={"skin"})
    A("cone", "skin", "head", a=br + v3(0, 0, -0.012), b=v3(0, 1.555, br[2] + 0.04), r1=0.017, r2=0.024, k=0.02)
    A("ell", "skin", "head", c=v3(0, 1.548, br[2] + 0.042), r=(0.036, 0.031, 0.031), k=0.014)        # potato nose
    for sx in (1, -1):
        A("ell", "skin", "head", c=v3(sx * 0.029, 1.541, br[2] + 0.028), r=(0.017, 0.015, 0.016), k=0.01)
    mh = sc.hit(v3(0, 1.505, 0.4), v3(0, 0, -1), labels={"skin"})
    A("ell", "skin", "head", op="sub", c=mh + v3(0, 0, -0.001), r=(0.036, 0.0045, 0.012), k=0.005)
    # worried downturn at the mouth corners
    for sx in (1, -1):
        A("ell", "skin", "head", op="sub", c=mh + v3(sx * 0.035, -0.006, -0.004), r=(0.006, 0.008, 0.01), R=rotm(roll=-30 * sx), k=0.004)
    # raised collar: a thick roll around the back and sides of the neck, clear of the jaw so the head can turn
    for th in range(-100, 101, 25):
        t = math.radians(th + 180)
        A("ell", "jacket", "upper", c=v3(0.112 * math.sin(t), 1.405, -0.005 + 0.105 * math.cos(t)), r=(0.046, 0.042, 0.046), k=0.008)
    # ---- hair: short, a touch receding, one unruly clump at the front --------------------------------------------
    A("ell", "hair", "head", c=v3(0, 1.635, 0.024), r=(0.124, 0.103, 0.124), cut=((0, 1, -0.55), 1.60), k=0.008)
    A("ell", "hair", "head", c=v3(0.025, 1.722, 0.07), r=(0.05, 0.022, 0.045), R=rotm(roll=-12), k=0.012)
    A("ell", "hair", "head", c=v3(-0.03, 1.73, 0.02), r=(0.06, 0.022, 0.06), k=0.012)
    # ---- hands (big, half closed) ----------------------------------------------------------------------------------
    for side, sx in (("Left", 1), ("Right", -1)):
        E, W = J[side + "LowerArm"], J[side + "Hand"]
        hd = nrm(W - E + v3(-sx * 0.05, 0, 0.02))
        sc.hand(side, "skin", W + hd * 0.004, hd, v3(-sx, 0, 0.3), s=1.42, curl=44, spread=3, fr=0.0112)
    # ---- worried eyebrows: thick, inner ends pinched upward --------------------------------------------------------
    el, er = eyes
    brow_strip(sc, [(0.014, 1.652), (0.034, 1.645), (0.058, 1.636), (0.082, 1.628)], r=0.009, squash=0.6)
    brow_strip(sc, [(-0.014, 1.648), (-0.034, 1.641), (-0.058, 1.632), (-0.081, 1.622)], r=0.0095, squash=0.6)
    sc.feat = dict(eyes=[el, er], eye_r=(0.0085, 0.0055), pupils=(0.0, 0.0), mouth=(mh, 0.036, 0.0), nose=br,
                   brows="worried", style="marcus")
    sc.params = dict(face_box=(0.0, 1.44, 1.70, 0.125), head_center=v3(0, 1.60, 0.04), opening=math.atan(0.055 / 0.23))
    sc.look = dict(skin="skin_brown", hair="hair_black_gray", top="jacket", top_ramp="wood_warm", top_lv=(1, 4),
                   inner="flannel", inner_ramp="paint_navy", inner_lv=(1, 4), pants="trousers", pants_ramp="upholstery", pants_lv=(0, 3),
                   shoes="boots")
    sc.title, sc.role = "Marcus - Noah's father (43) - rev 3 (sculpted)", "Protective, impulsive father searching for his missing son Noah; exhausted and worried."
    sc.folder = "Marcus"
    return sc


CAST_V3 = [eddie, marcus]

CAST_V3_META = [dict(name="Eddie_v3", height=1.80), dict(name="Marcus_v3", height=1.76)]
