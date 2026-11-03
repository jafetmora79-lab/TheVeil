"""Pack 06 pixel-art painter: one 256x256 atlas per character, Pack 01 palette rules.

Every pixel comes from the Greyhaven master ramps (Pack 01) or the small CHR_RAMPS set below (skin, hair,
lips, eye whites, reflective tape - hue-shifted dark->light like the rest of the palette). Light comes from
the top-left; shading steps along ramps; detail is hand-placed clusters (seams, folds, pockets, faces).
"""
import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "Source_Scripts"))
from veil_texgen.palettes import RAMPS  # noqa: E402
from veil_texgen.core import Pal, rng_for  # noqa: E402

from chr_body import REG  # noqa: E402

CHR_RAMPS = {
    "skin_fair":   ["#4a2f2a", "#6e463a", "#93624f", "#b47f66", "#cfa184", "#e2bea0"],
    "skin_old":    ["#4d3634", "#6f5049", "#926e62", "#b28f7f", "#ccae9b", "#dfc6b3"],
    "skin_tan":    ["#3d2620", "#5e3a2b", "#80553c", "#a07050", "#bb8d68", "#d1a985"],
    "skin_brown":  ["#241510", "#3a2318", "#553423", "#704831", "#8a5e42", "#a37857"],
    "skin_deep":   ["#170e0c", "#26170f", "#382117", "#4c2e20", "#62402d", "#7b553c"],
    "hair_black":  ["#0f0e12", "#1a181e", "#26222a", "#35303a", "#463f4a"],
    "hair_black_gray": ["#141316", "#232126", "#37343a", "#55525a", "#7a777d"],
    "hair_brown":  ["#1e140f", "#2e1f16", "#45301f", "#5e4329", "#785a38"],
    "hair_brown_dark": ["#16100d", "#221812", "#33241a", "#463224", "#5a4230"],
    "hair_brown_gray": ["#2a221d", "#3f342c", "#594c41", "#766a5e", "#958a7d"],
    "hair_auburn": ["#2e130d", "#4a1e12", "#6c2f19", "#8e4424", "#ab5d33"],
    "hair_gray":   ["#3a393c", "#58565a", "#79767a", "#9b9899", "#bdbab7", "#dad7d0"],
    "lip":         ["#4a2424", "#6a3431", "#874840", "#a05e52"],
    "eye_white":   ["#7d7871", "#a9a39a", "#cfc9bc"],
    "reflect":     ["#6e6c44", "#8c8a5a", "#b9b67a", "#d8d59a"],
}
ALL_RAMPS = dict(RAMPS)
ALL_RAMPS.update(CHR_RAMPS)
P = Pal(ALL_RAMPS)
W = 256

FONT = {  # 3x5 glyphs
    "A": ["010", "101", "111", "101", "101"], "C": ["011", "100", "100", "100", "011"], "D": ["110", "101", "101", "101", "110"],
    "E": ["111", "100", "110", "100", "111"], "I": ["111", "010", "010", "010", "111"], "L": ["100", "100", "100", "100", "111"],
    "M": ["101", "111", "111", "101", "101"], "O": ["010", "101", "101", "101", "010"], "P": ["110", "101", "110", "100", "100"],
    "R": ["110", "101", "110", "101", "101"], "S": ["011", "100", "010", "001", "110"], "T": ["111", "010", "010", "010", "010"],
    "U": ["101", "101", "101", "101", "111"], "Y": ["101", "101", "010", "010", "010"],
}


class Atlas:
    def __init__(self, name):
        self.a = np.full((W, W), P("ink", 0), np.int64)
        self.rng = rng_for("chr_" + name)

    def px(self, x, y, v):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < W and 0 <= y < W:
            self.a[y, x] = v

    def rect(self, x, y, w, h, v):
        x, y = int(round(x)), int(round(y))
        self.a[max(0, y):max(0, y + int(h)), max(0, x):max(0, x + int(w))] = v

    def shift_rect(self, x, y, w, h, d):
        x, y = int(round(x)), int(round(y))
        sl = self.a[max(0, y):max(0, y + int(h)), max(0, x):max(0, x + int(w))]
        sl[...] = P.shift(sl, d)

    def shift_px(self, x, y, d):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < W and 0 <= y < W:
            self.a[y, x] = P.shift(self.a[y, x], d)

    def text(self, s, x, y, v, wrap=None):
        for i, ch in enumerate(s):
            g = FONT.get(ch)
            if not g:
                continue
            for r, row in enumerate(g):
                for k, bit in enumerate(row):
                    if bit == "1":
                        xx = x + i * 4 + k
                        if wrap:
                            xx = wrap[0] + (xx - wrap[0]) % wrap[1]
                        self.px(xx, y + r, v)

    def image(self):
        from PIL import Image
        return Image.fromarray(P.rgb[self.a], "RGB")


def cyl(at, reg, ramp, lv, light_bias=0.0, vert=True):
    """Cylindrically shaded fill of a wrap-around region: u=0 back, 0.5 front; light from top-left-front."""
    x0, y0, w, h = REG[reg]
    Lv = np.array([-0.45, 0.55, 0.70])
    Lv /= np.linalg.norm(Lv)
    lo, hi = lv
    for i in range(w):
        u = (i + 0.5) / w
        n = np.array([-math.sin(2 * math.pi * u), 0.0, -math.cos(2 * math.pi * u)])
        lam = max(0.0, float(n @ Lv))
        for j in range(h):
            vy = 1 - j / max(h - 1, 1)
            f = 0.25 + 0.75 * lam + light_bias + (0.12 * (vy - 0.5) if vert else 0)
            k = lo + int(round((hi - lo) * min(1.0, max(0.0, f))))
            at.a[y0 + j, x0 + i] = P(ramp, k)


def flat(at, reg, ramp, k, edge=True):
    x0, y0, w, h = REG[reg]
    at.rect(x0, y0, w, h, P(ramp, k))
    if edge:
        at.rect(x0, y0, w, 1, P(ramp, k + 1))
        at.rect(x0, y0, 1, h, P(ramp, k + 1))
        at.rect(x0, y0 + h - 1, w, 1, P(ramp, k - 1))
        at.rect(x0 + w - 1, y0, 1, h, P(ramp, k - 1))


def ux(reg, u):
    """pixel column of uv-u in a wrap-around region"""
    x0, y0, w, h = REG[reg]
    return x0 + (u % 1.0) * w


# ------------------------------------------------------------------ fabric patterns
def pattern(at, reg, kind, rows=None, ramp=None):
    x0, y0, w, h = REG[reg]
    r0, r1 = rows if rows else (y0, y0 + h)
    r0, r1 = int(r0), int(r1)
    rng = at.rng
    for y in range(r0, r1):
        for x in range(x0, x0 + w):
            if kind == "twill" and (x + y) % 4 == 0:
                at.shift_px(x, y, -1)
            elif kind == "twill" and (x + y) % 4 == 2 and rng.random() < 0.18:
                at.shift_px(x, y, 1)
            elif kind == "knit" and (x % 3 == 0 or ((x % 3 == 1) and y % 2 == 0)):
                at.shift_px(x, y, -1 if x % 3 == 0 else 0)
            elif kind == "canvas" and ((x % 2 == 0 and y % 2 == 0 and rng.random() < 0.35) or rng.random() < 0.03):
                at.shift_px(x, y, -1)
            elif kind == "tweed" and rng.random() < 0.22:
                at.shift_px(x, y, int(rng.choice([-1, 1, 1])))
    if kind == "plaid":
        for y in range(r0, r1):
            for x in range(x0, x0 + w):
                bx, by = (x - x0) % 12, (y - r0) % 12
                if bx in (0, 1) or by in (0, 1):
                    at.a[y, x] = P("paint_black", 2 if (bx + by) % 2 else 1)
                elif bx == 6 or by == 6:
                    at.a[y, x] = P("paint_mustard", 2)
                elif bx in (3, 9) and by % 2 == 0:
                    at.shift_px(x, y, -1)


def folds(at, reg, row, n=4, spread=10, d=-1, width=(3, 6)):
    x0, y0, w, h = REG[reg]
    rng = at.rng
    for k in range(n):
        x = x0 + rng.integers(0, w)
        y = row + rng.integers(-spread // 2, spread // 2 + 1)
        ln = rng.integers(*width)
        for q in range(ln):
            at.shift_px(x0 + (x - x0 + q) % w, y + (q // 3), d)
            if q % 2 == 0:
                at.shift_px(x0 + (x - x0 + q) % w, y + 1 + (q // 3), -d)


def seam(at, reg, u, rows, d=-1):
    x = ux(reg, u)
    for y in range(int(rows[0]), int(rows[1])):
        at.shift_px(x, y, d)


# ------------------------------------------------------------------ face
def head_row(meta, t):
    ts = meta["head_t"]
    rows = [meta["rows"]["head"][round(tt, 2)] for tt in ts]
    return float(np.interp(t, ts, rows))


def hair_edge(c, th):
    h = c.get("hair", {})
    fr, bk = h.get("front_t", 0.8), h.get("back_t", 0.38)
    if h.get("style") == "bob":
        a = abs(math.atan2(math.sin(th), math.cos(th)))
        if a < math.radians(48):
            return fr
        return fr + (bk - fr) * min(1.0, (a - math.radians(48)) / math.radians(30))
    if h.get("style") == "bald":
        return 2.0
    k = ((1 + math.cos(th)) / 2) ** h.get("edge_p", 1.6)
    return bk + (fr - bk) * k


def paint_head(at, c, meta):
    L = c["look"]
    sk, hr = L["skin"], L["hair"]
    cyl(at, "head", sk, (1, 4))
    x0, y0, w, h = REG["head"]
    cx = x0 + w // 2
    R = lambda t: int(round(head_row(meta, t)))
    # scalp / hairline (painted under the hair shell so edges never show skin gaps)
    for i in range(w):
        u = (i + 0.5) / w
        th = 2 * math.pi * u - math.pi          # 0 = front
        e = hair_edge(c, th)
        if e > 1.5:
            continue
        ye = head_row(meta, e - 0.025)
        for j in range(0, int(ye) - y0 + 1):
            yy = y0 + j
            lv = 2 + (1 if (i + j) % 5 == 0 else 0) - (1 if j > ye - y0 - 2 else 0)
            at.a[yy, x0 + i] = P(hr, max(0, lv - (1 if abs(u - 0.5) > 0.3 else 0)))
    eyes, brows, mouth = L["eyes"], L["brows"], L["mouth"]
    er = R(0.50)
    br = R(0.585)
    mr = R(0.215)
    ex = 8 if c["face"].get("head_w", 0.16) > 0.155 else 7
    asym = 1 if "asym" in brows or eyes in ("smirk",) else 0
    dark = P(hr, 0)
    for s in (-1, 1):
        x = cx + s * ex
        yy = er + (asym if s > 0 else 0) * (1 if eyes == "smirk" else 0)
        hgt = {"narrow": 1, "stern": 1, "tired": 1, "smirk": 2 if s < 0 else 1, "wide": 3, "alert": 2}.get(eyes, 2)
        wd = 4 if eyes != "wide" else 5
        # socket shadow
        at.shift_rect(x - wd // 2 - 1, yy - 1, wd + 2, hgt + 2, -1)
        at.rect(x - wd // 2, yy, wd, hgt, P("eye_white", 1))
        at.rect(x - wd // 2 + wd - 1, yy, 1, hgt, P("eye_white", 0))
        pup_x = x - 1 + (1 if s < 0 else 0) * (0 if eyes != "smirk" else 1)
        at.rect(pup_x, yy, 2, hgt, P("ink", 0))
        if eyes in ("wide", "alert", "level"):
            at.px(pup_x, yy, P("eye_white", 2))
        # upper lid line
        at.rect(x - wd // 2 - (1 if s < 0 else 0), yy - 1, wd + 1, 1, P(sk, 0))
        if eyes in ("tired", "worried"):
            at.rect(x - wd // 2, yy, wd, 1, P(sk, 1))
        # lower lid / bags
        at.rect(x - wd // 2, yy + hgt, wd, 1, P(sk, 2))
        if "eye_bags" in L["extras"] or eyes in ("tired", "worried"):
            at.rect(x - wd // 2, yy + hgt + 1, wd, 1, P(sk, 1 if "eye_bags" in L["extras"] else 2))
        # brows
        bx0 = x - 3
        pts = []
        for k in range(6):
            dy = 0
            if brows == "worried":
                dy = -(k if s > 0 else 5 - k) // 2 + 1        # inner ends raised
            elif brows == "stern":
                dy = (k if s > 0 else 5 - k) // 2 - 1          # inner ends lowered
            elif brows == "raised_one" and s > 0:
                dy = -2 + (1 if k in (0, 5) else 0)
            elif brows == "skeptic" and s < 0:
                dy = (k // 3)
            elif brows == "arched":
                dy = -1 if k in (2, 3) else 0
            elif brows == "flat_asym" and s > 0:
                dy = -1
            pts.append((bx0 + k, br + dy))
        thick = 2 if brows in ("stern", "worried", "level", "flat_asym", "flat") else 1
        bcol = P(hr, 0 if brows != "thin" else 2)
        for (px_, py_) in pts:
            for q in range(thick):
                at.px(px_, py_ + q, bcol)
    # nose shadow under the nose, cheeks
    nr = R(c["face"].get("nose", {}).get("t", 0.4) - 0.07)
    at.shift_rect(cx - 2, nr, 4, 1, -1)
    for s in (-1, 1):
        at.shift_rect(cx + s * 13 - 1, er + 4, 3, 4, -1 if s > 0 else 0)
    # mouth
    mw = {"small": 4, "thin": 6, "smirk": 7}.get(mouth, 6)
    m0 = cx - mw // 2
    lipc = P("lip", 0)
    for k in range(mw):
        dy = 0
        if mouth == "smirk" and k >= mw - 2:
            dy = -1
        if mouth in ("frown", "frown_flat") and k in (0, mw - 1):
            dy = 1 if mouth == "frown" else 0
        at.px(m0 + k, mr + dy, lipc)
    if mouth not in ("thin",):
        at.rect(m0 + 1, mr + 1, mw - 2, 1, P("lip", 2))
    at.shift_rect(cx - 1, mr + 3, 3, 1, -1)       # chin dimple shadow
    ex_ = L["extras"]
    rng = at.rng
    if "stubble_light" in ex_ or "stubble_heavy" in ex_:
        heavy = "stubble_heavy" in ex_
        for y in range(R(0.30), R(0.02) + 1):
            for x in range(cx - 17, cx + 18):
                if (x + 2 * y) % (2 if heavy else 3) == 0 and rng.random() < (0.75 if heavy else 0.5):
                    if not (m0 - 1 <= x <= m0 + mw and mr - 1 <= y <= mr + 1):
                        at.a[y, x] = P(sk, 1) if not heavy else P(L["hair"], 2)
    if "mustache" in ex_:
        at.rect(cx - 5, mr - 2, 10, 2, P(L["hair"], 1))
        at.px(cx - 5, mr - 1 + 1, P(L["hair"], 1))
        at.px(cx + 4, mr - 1 + 1, P(L["hair"], 1))
    if "jowls" in ex_:
        for s in (-1, 1):
            for q in range(4):
                at.shift_px(cx + s * (5 + q // 2), mr - 3 + q, -1)
    if "wrinkles" in ex_:
        for q in range(2):
            y = R(0.66 + q * 0.05)
            for x in range(cx - 7, cx + 8):
                if (x + q) % 4 != 0:
                    at.shift_px(x, y, -1)
        for s in (-1, 1):
            at.shift_px(cx + s * (ex + 4), er + 1, -1)
            at.shift_px(cx + s * (ex + 4), er + 2, -1)
            for q in range(4):
                at.shift_px(cx + s * (4 + q // 2), mr - 4 + q, -1)
    if "age_spots" in ex_:
        for _ in range(5):
            at.shift_px(cx + rng.integers(-14, 15), R(0.75) + rng.integers(-2, 3), -1)
    if "freckles" in ex_:
        for _ in range(14):
            at.shift_px(cx + rng.integers(-12, 13), er + rng.integers(3, 8), -1)
    # sideburns / nape for short styles
    st = c.get("hair", {}).get("style")
    if st in ("short", "messy"):
        for s in (-1, 1):
            xs = ux("head", 0.5 + s * 0.2)
            at.rect(xs - 1, R(0.62), 3, R(0.40) - R(0.62), P(L["hair"], 1))


def paint_hair(at, c):
    L = c["look"]
    hr = L["hair"]
    x0, y0, w, h = REG["hair"]
    cyl(at, "hair", hr, (0, 3), vert=True)
    rng = at.rng
    for _ in range(140):
        x = x0 + rng.integers(0, w)
        y = y0 + rng.integers(0, h)
        ln = rng.integers(3, 8)
        d = int(rng.choice([-1, 1, 1]))
        for q in range(ln):
            at.shift_px(x + (q // 3) * (1 if d > 0 else 0), y + q, d)
    at.shift_rect(x0, y0 + h - 2, w, 2, -1)      # edge shadow
    gray = c["look"].get("hair") == "hair_black_gray"
    if gray:
        for _ in range(60):
            at.px(x0 + rng.integers(0, w), y0 + rng.integers(0, h), P(hr, 4))


def paint_torso(at, c, meta):
    L = c["look"]
    reg = "torso"
    x0, y0, w, h = REG[reg]
    rows = meta["rows"]["torso"]
    top, ir = L["top"], L["inner_ramp"]
    tr, tl = L["top_ramp"], L["top_lv"]
    cyl(at, reg, tr, tl)
    hip = int(rows["hip"])
    waist = int(rows["waist"])
    hem = {"jacket_open": hip + 2, "jacket_work": hip + 3, "hoodie_open": hip + 1, "cardigan": hip,
           "flannel_open": hip + 3, "uniform_ems": waist + 3, "uniform_security": waist + 3, "uniform_police": waist + 3}[top]
    cx = x0 + w // 2
    # lower torso: trousers / skirt top
    if c.get("skirt"):
        lower_r, lower_lv = L["skirt_ramp"], (1, 3)
        hem = waist + 1
    else:
        lower_r, lower_lv = L["leg_ramp"], L["leg_lv"]
    for y in range(hem, y0 + h):
        for x in range(x0, x0 + w):
            u = (x - x0 + 0.5) / w
            lam = max(0, -math.cos(2 * math.pi * u)) * 0.8 + 0.1
            at.a[y, x] = P(lower_r, lower_lv[0] + int(round((lower_lv[1] - lower_lv[0]) * lam)))
    if not c.get("skirt"):
        if L["legs"].startswith("jeans"):
            pattern(at, reg, "twill", rows=(hem, y0 + h))
        at.rect(cx, hem + 2, 1, y0 + h - hem - 2, P(lower_r, lower_lv[0]))     # fly seam
        if not any(a[0] == "belt" for a in c.get("acc", [])):
            at.rect(x0, hem, w, 2, P("leather", 1))
            at.rect(cx - 2, hem, 4, 2, P("metal", 4))
    # inner garment strip (open fronts) and fabric texture
    if top in ("jacket_open", "hoodie_open", "flannel_open"):
        half = {"jacket_open": 5, "hoodie_open": 7, "flannel_open": 6}[top]
        if top == "flannel_open":
            pattern(at, reg, "plaid", rows=(y0, hem))
        for y in range(y0, hem):
            k = (y - y0) / max(hem - y0, 1)
            hw = int(round(half * (0.5 + 0.7 * min(1.0, k * 2.5))))
            for x in range(cx - hw, cx + hw + 1):
                lam = 1 - abs(x - cx) / (hw + 1)
                at.a[y, x] = P(ir, L["inner_lv"][0] + int(round((L["inner_lv"][1] - L["inner_lv"][0]) * lam)))
            at.px(cx - hw - 1, y, P(tr, tl[0]))
            at.px(cx + hw + 1, y, P(tr, tl[0]))
            if "zipper" in L["details"]:
                at.px(cx - hw - 2, y, P("metal", 3 if y % 2 else 1))
                at.px(cx + hw + 2, y, P("metal", 3 if y % 2 else 1))
        if "tee_graphic" in L["details"]:
            gy = int(rows["chest"]) - 2
            ghost = ["0110", "1111", "1011", "1111", "1010"]
            for r_, row in enumerate(ghost):
                for k_, bit in enumerate(row):
                    if bit == "1":
                        at.px(cx - 2 + k_, gy + r_, P("paint_white", 3))
            at.px(cx - 1, gy + 1, P("ink", 0))
        if "drawstrings" in L["details"]:
            for s in (-1, 1):
                at.rect(cx + s * (half + 3), int(rows["upper"]), 1, 7, P("paint_white", 2))
    elif top == "cardigan":
        pattern(at, reg, "knit", rows=(y0, hem))
        vb = int(rows["chest"])
        for y in range(y0, vb):
            hw = int(round(6 * (1 - (y - y0) / max(vb - y0, 1))))
            for x in range(cx - hw, cx + hw + 1):
                at.a[y, x] = P(ir, 3)
        for y in range(vb, hem, 4):
            at.px(cx, y, P("plastic", 3))
            at.px(cx, y + 1, P("plastic", 1))
        at.rect(cx, vb, 1, hem - vb, P(tr, tl[0]))
        if "brooch" in L["details"]:
            at.rect(cx + 9, int(rows["upper"]) + 2, 2, 2, P("paint_mustard", 4))
    elif top == "jacket_work":
        pattern(at, reg, "canvas", rows=(y0, hem))
        at.rect(cx, y0, 1, hem - y0, P(tr, tl[0]))
        for y in range(y0 + 2, hem, 2):
            at.px(cx + 1, y, P("metal", 2))
        at.rect(x0, y0, w, 3, P(tr, tl[0] + 1))       # collar band
        for s in (-1, 1):
            px_ = cx + s * 14
            cr = int(rows["chest"]) - 3
            at.rect(px_ - 5, cr, 10, 7, P(tr, tl[0] + 1))
            at.rect(px_ - 5, cr, 10, 2, P(tr, tl[0]))
            at.px(px_, cr + 1, P("metal", 3))
        if "jacket_patch" in L["details"]:
            at.rect(ux(reg, 0.62) - 2, int(rows["upper"]) + 1, 5, 4, P("paint_green", 2))
            at.rect(ux(reg, 0.62) - 2, int(rows["upper"]) + 1, 5, 1, P("paint_green", 3))
        if "wear" in L["details"]:
            rng = at.rng
            for _ in range(50):
                x = x0 + rng.integers(0, w)
                y = y0 + rng.integers(0, hem - y0)
                at.shift_rect(x, y, 2, 1, 1)
    elif top.startswith("uniform"):
        pattern(at, reg, "canvas", rows=(y0, hem))
        at.rect(cx, y0 + 3, 1, hem - y0 - 3, P(tr, tl[0]))
        for y in range(y0 + 5, hem - 1, 5):
            at.px(cx + 1, y, P("plastic", 4 if top == "uniform_security" else 3))
        # collar
        at.rect(cx - 7, y0, 14, 3, P(tr, tl[0] + 1))
        at.rect(cx - 2, y0, 4, 3, P(ir, 1) if top != "uniform_police" else P("paint_black", 2))
        for s in (-1, 1):
            px_ = cx + s * 12
            cr = int(rows["chest"]) - 4
            at.rect(px_ - 5, cr, 10, 7, P(tr, tl[0] + 1))
            at.rect(px_ - 5, cr, 10, 2, P(tr, tl[0]))
            at.px(px_, cr + 1, P("plastic", 3))
        if top == "uniform_ems":
            for yy in (int(rows["chest"]) + 6, int(rows["belly"]) + 2):
                at.rect(x0, yy, w, 2, P("reflect", 3))
                at.rect(x0, yy + 2, w, 1, P("reflect", 1))
            at.text("EMS", x0 + w - 6, int(rows["upper"]), P("reflect", 3), wrap=(x0, w))
        if top == "uniform_security":
            at.text("SECURITY", x0 + w - 16, int(rows["upper"]) + 1, P("paint_black", 1), wrap=(x0, w))
            at.rect(cx + 7, int(rows["chest"]) - 6, 9, 3, P("paint_black", 2))
        if top == "uniform_police":
            at.text("POLICE", x0 + w - 12, int(rows["upper"]) + 1, P("paint_white", 3), wrap=(x0, w))
            if "name_bar" in L["details"]:
                at.rect(cx - 16, int(rows["chest"]) - 6, 8, 2, P("sign_yellow", 3))
            at.rect(cx - 1, y0 + 3, 2, int(rows["chest"]) - y0 - 1, P("paint_black", 2))   # tie
        if "epaulettes" in L["details"]:
            for u in (0.25, 0.75):
                at.rect(ux(reg, u) - 2, y0 + 1, 5, 4, P(tr, tl[0]))
    # common folds / seams / name tag / strap
    folds(at, reg, waist, n=6, spread=6)
    folds(at, reg, int(rows["chest"]), n=3, spread=4)
    for u in (0.25, 0.75):
        seam(at, reg, u, (y0, y0 + h))
    if "jacket_pockets" in L["details"]:
        for s in (-1, 1):
            at.rect(cx + s * 15 - 1, hem - 7, 1, 5, P(tr, tl[0]))
    if any(d.startswith("name_tag") for d in L["details"]):
        ty = int(rows["chest"]) - 3
        at.rect(cx + 9, ty, 8, 4, P("paint_white", 3))
        at.rect(cx + 9, ty, 8, 1, P("paint_red", 3))
        for k in range(5):
            at.px(cx + 10 + k + (k // 2), ty + 2, P("ink", 1))
    if "bag_strap" in L["details"]:
        # from left shoulder over the front to the right hip, and back up behind
        for y in range(y0, hip):
            f = (y - y0) / max(hip - y0, 1)
            for (u0_, u1_) in ((0.70, 0.30), (0.80, 1.20)):
                u = u0_ + (u1_ - u0_) * f
                x = ux(reg, u)
                for q in range(3):
                    at.px(x0 + (int(x) - x0 + q) % w, y, P("leather", 2 if q else 1))
    if c.get("skirt"):
        at.rect(x0, waist + 1, w, 1, P(tr, tl[0]))


def paint_arm(at, c, meta, side):
    L = c["look"]
    reg = "arm_l" if side == "Left" else "arm_r"
    x0, y0, w, h = REG[reg]
    rows = meta["rows"][reg]
    tr, tl = L["top_ramp"], L["top_lv"]
    cyl(at, reg, tr, tl)
    if L["top"] in ("jacket_work", "uniform_ems", "uniform_security", "uniform_police"):
        pattern(at, reg, "canvas")
    if L["top"] == "flannel_open":
        pattern(at, reg, "plaid")
    if L["top"] == "cardigan":
        pattern(at, reg, "knit")
    sl = L["sleeves"]
    wrist, elbow, fore, upper, sh = (int(rows[k]) for k in ("wrist", "elbow", "fore", "upper", "shoulder"))
    sk = L["skin"]
    # rows run wrist (top) -> shoulder (bottom)
    def skin_rows(r0, r1):
        for y in range(r0, r1):
            for x in range(x0, x0 + w):
                u = (x - x0 + 0.5) / w
                lam = 0.5 + 0.5 * math.cos(2 * math.pi * (u - 0.5))
                at.a[y, x] = P(sk, 2 + int(round(1.5 * lam)))
    if sl == "short":
        cut = int((upper + elbow) / 2)
        skin_rows(y0, cut)
        at.rect(x0, cut, w, 2, P(tr, tl[0] + 1))
    elif sl == "long_rolled":
        cut = int((fore + elbow) / 2)
        skin_rows(y0, cut)
        at.rect(x0, cut, w, 4, P(tr, tl[0] + 2))
        at.rect(x0, cut + 3, w, 1, P(tr, tl[0]))
    else:
        at.rect(x0, wrist - 1 if wrist > y0 else y0, w, 3, P(tr, tl[0]))      # cuff
    folds(at, reg, elbow, n=5, spread=4)
    if L["top"] == "uniform_ems":
        at.rect(x0, int((upper + elbow) / 2), w, 2, P("reflect", 3))
    patch_x = x0 + (16 if side == "Left" else 48)
    for d in L["details"]:
        if d.startswith("patch:"):
            py = int((sh + upper) / 2) - 3
            at.rect(patch_x - 4, py, 9, 7, P("paint_mustard", 1) if "POLICE" in d else P("paint_white", 1))
            at.rect(patch_x - 3, py + 1, 7, 5, P(tr, tl[0] + 1) if "SECURITY" not in d else P("paint_black", 2))
            at.px(patch_x, py + 3, P("sign_yellow", 3) if "POLICE" in d else P("paint_white", 3))
    if L["top"] in ("hoodie_open",):
        at.rect(x0, wrist - 2 if wrist > y0 + 1 else y0, w, 4, P(tr, tl[0]))
        for x in range(x0, x0 + w, 2):
            at.shift_px(x, wrist, -1)


def paint_leg(at, c, meta, side):
    L = c["look"]
    reg = "leg_l" if side == "Left" else "leg_r"
    x0, y0, w, h = REG[reg]
    rows = meta["rows"][reg]
    lr, ll = L["leg_ramp"], L["leg_lv"]
    cyl(at, reg, lr, ll)
    legs = L["legs"]
    knee = int(rows["knee"])
    ankle = int(rows["ankle"])
    if legs.startswith("jeans"):
        pattern(at, reg, "twill")
        for x in range(x0 + 26, x0 + 38):
            for y in range(knee - 3, knee + 4):
                if (x + y) % 3:
                    at.shift_px(x, y, 1)
        if legs == "jeans_rolled":
            at.rect(x0, ankle, w, 4, P(lr, ll[1]))
            at.rect(x0, ankle + 3, w, 1, P(lr, ll[0]))
    elif legs in ("work_pants", "cargo"):
        pattern(at, reg, "canvas")
        outer = 0.25 if side == "Left" else 0.75
        if legs == "cargo" or legs == "work_pants":
            thigh = int(rows.get("mid", knee - 10))
            at.rect(ux(reg, outer) - 5, thigh - 4, 10, 9, P(lr, ll[0] + 1))
            at.rect(ux(reg, outer) - 5, thigh - 4, 10, 2, P(lr, ll[0]))
        if legs == "work_pants":
            at.shift_rect(x0 + 24, knee - 4, 16, 8, -1)
    elif legs.startswith("slacks"):
        at.rect(x0 + 32, y0, 1, h, P(lr, ll[1]))
        if legs == "slacks_stripe":
            outer = 0.25 if side == "Left" else 0.75
            at.rect(ux(reg, outer) - 1, y0, 2, h, P("sign_yellow", 1))
    elif legs == "stockings":
        for y in range(y0, y0 + h):
            if y % 3 == 0:
                at.shift_rect(x0, y, w, 1, -1)
    for u in (0.25, 0.75):
        seam(at, reg, u, (y0, y0 + h))
    folds(at, reg, knee, n=5, spread=5)
    folds(at, reg, ankle + 2, n=4, spread=3)


def paint_misc(at, c):
    L = c["look"]
    sk = L["skin"]
    for r in ("nose", "ear", "skin"):
        flat(at, r, sk, 3)
    x0, y0, w, h = REG["ear"]
    at.rect(x0 + 5, y0 + 5, 6, 6, P(sk, 2))
    at.rect(x0 + 6, y0 + 6, 3, 4, P(sk, 1))
    x0, y0, w, h = REG["nose"]
    at.rect(x0, y0 + h - 4, w, 2, P(sk, 2))
    at.rect(x0 + 3, y0 + h - 3, 2, 1, P(sk, 0))
    at.rect(x0 + w - 5, y0 + h - 3, 2, 1, P(sk, 0))
    at.rect(x0 + 6, y0, 4, h - 5, P(sk, 4))
    # hands
    x0, y0, w, h = REG["hand"]
    flat(at, "hand", sk, 3)
    for k in (8, 16, 24):
        at.rect(x0 + k, y0 + 4, 1, h - 6, P(sk, 2))
    for k in (4, 12, 20, 28):
        at.px(x0 + k, y0 + 2, P(sk, 5))
        at.px(x0 + k + 1, y0 + 2, P(sk, 4))
    at.rect(x0, y0 + h - 3, w, 3, P(sk, 2))
    # shoes / boots
    shoes = L["shoes"]
    for reg in ("shoe", "boot"):
        x0, y0, w, h = REG[reg]
        if shoes == "sneakers":
            flat(at, reg, "plastic", 3)
            at.rect(x0 + 6, y0 + h - 12, w - 12, 3, P("paint_red", 2))
            at.rect(x0, y0 + h - 5, w, 5, P("plastic", 1))
        else:
            ramp = shoes.split(":")[1] if shoes.startswith("ramp:") else "leather"
            flat(at, reg, ramp, L["shoe_lv"][0] + 1)
            at.rect(x0, y0 + h - 5, w, 4, P("rubber", 1))
            at.rect(x0, y0 + h - 6, w, 1, P(ramp, L["shoe_lv"][1]))
        for k in range(4):         # laces
            yy = y0 + 4 + k * 4
            at.rect(x0 + w // 2 - 4, yy, 8, 1, P("paint_white", 1) if shoes == "sneakers" else P("leather", 4))
        at.rect(x0 + w // 2, y0 + 2, 1, 16, P("ink", 1))
    # skirt
    if c.get("skirt"):
        cyl(at, "skirt", L["skirt_ramp"], (1, 3))
        pattern(at, "skirt", "tweed")
        x0, y0, w, h = REG["skirt"]
        at.rect(x0, y0 + h - 3, w, 3, P(L["skirt_ramp"], 0))
        for x in range(x0, x0 + w, 7):
            at.rect(x, y0 + 8, 1, h - 12, P(L["skirt_ramp"], 1))
    # belt + gear + small swatches
    flat(at, "belt", "paint_black" if "uniform" in L["top"] else "leather", 1, edge=False)
    x0, y0, w, h = REG["belt"]
    at.rect(x0, y0, w, 1, P("paint_black", 3))
    at.rect(x0, y0 + h - 1, w, 1, P("ink", 0))
    at.rect(x0 + w // 2 - 3, y0 + 3, 6, h - 6, P("metal", 4))
    at.rect(x0 + w // 2 - 2, y0 + 5, 4, h - 10, P("metal", 1))
    for x in range(x0 + 2, x0 + w, 6):
        at.px(x, y0 + h // 2, P("paint_black", 3))
    flat(at, "gear", "rubber", 2)
    x0, y0, w, h = REG["gear"]
    at.rect(x0 + 3, y0 + 3, w - 6, 4, P("rubber", 4))
    at.rect(x0 + 8, y0 + 12, w - 16, 8, P("rubber", 1))
    at.px(x0 + 5, y0 + h - 6, P("paint_red", 4))
    flat(at, "metal", "metal", 3)
    flat(at, "plastic", "rubber", 1)
    flat(at, "badge", "sign_yellow", 3)
    x0, y0, w, h = REG["badge"]
    at.rect(x0 + 5, y0 + 5, 6, 6, P("sign_yellow", 4))
    at.rect(x0 + 7, y0 + 7, 2, 2, P("sign_yellow", 1))
    flat(at, "glasses", "metal", 1)
    flat(at, "patch", "paint_mustard", 2)
    flat(at, "paper", "paint_white", 3)
    flat(at, "tooth", "paint_white", 3)
    flat(at, "sole", "rubber", 1)
    # secondary fabrics: collar / hood / pocket, bag
    tr, tl = L["top_ramp"], L["top_lv"]
    flat(at, "fabric2", tr, tl[0] + 1)
    x0, y0, w, h = REG["fabric2"]
    if L["top"] == "flannel_open":
        pattern(at, "fabric2", "plaid")
    for k in range(0, w, 3):
        at.px(x0 + k, y0 + 2, P(tr, tl[0]))
        at.px(x0 + k, y0 + h - 3, P(tr, tl[0]))
    flat(at, "fabric3", "upholstery", 2)
    flat(at, "bag", "upholstery", 2)
    x0, y0, w, h = REG["bag"]
    for k in range(0, w, 3):
        at.px(x0 + k, y0 + 2, P("upholstery", 4))
    at.rect(x0 + w // 2 - 3, y0 + 10, 6, 4, P("metal", 3))
    flat(at, "strap", "leather", 2)
    # hats
    flat(at, "hat", "paint_navy", 1)
    x0, y0, w, h = REG["hat"]
    at.rect(x0, y0 + h - 8, w, 4, P("paint_black", 1))
    at.rect(x0, y0 + h - 7, w, 1, P("sign_yellow", 2))
    at.rect(x0, y0, w, 8, P("paint_navy", 2))
    flat(at, "brim", "paint_black", 1)
    x0, y0, w, h = REG["brim"]
    at.rect(x0 + 2, y0 + 2, w - 4, 2, P("paint_black", 3))


def paint(c, meta):
    at = Atlas(c["name"])
    paint_misc(at, c)
    paint_head(at, c, meta)
    paint_hair(at, c)
    paint_torso(at, c, meta)
    for side in ("Left", "Right"):
        paint_arm(at, c, meta, side)
        paint_leg(at, c, meta, side)
    return at
