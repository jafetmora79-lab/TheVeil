"""Rev 3 painter: pixel-art atlas for sculpted characters (charts from chr_sculpt_build.unwrap).

Same palette rules as Pack 01/06 (every pixel from the Greyhaven ramps + CHR_RAMPS), light from the top-left,
clusters not noise. Facial features are painted exactly where the sculpt put them (feature points projected
through the face chart), so eyes sit in the carved sockets and the mouth follows the carved line.
"""
import math

import numpy as np

from chr_tex import Atlas, P, pattern, folds

LAYOUT_SLOTS = {   # role -> rect (x, y, w, h)
    "face": (0, 0, 64, 64), "hair": (64, 0, 64, 64), "top_body": (128, 0, 128, 64),
    "top_arm_L": (128, 64, 64, 32), "top_arm_R": (192, 64, 64, 32), "inner_body": (0, 64, 64, 32), "pants_body": (64, 64, 64, 32),
    "pants_leg_L": (0, 128, 64, 64), "pants_leg_R": (64, 128, 64, 64), "shoe_L": (128, 128, 32, 32), "shoe_R": (160, 128, 32, 32),
    "skin": (192, 128, 16, 16), "brow": (208, 128, 16, 16), "glasses": (224, 128, 16, 16), "sole": (240, 128, 16, 16),
    "spare": (0, 96, 128, 32),
}


def layout_for(look):
    t, i, p = look["top"], look["inner"], look["pants"]
    L = LAYOUT_SLOTS
    return {("face", "head"): L["face"], ("hair", "head"): L["hair"],
            (t, "body"): L["top_body"], (t, "arm_L"): L["top_arm_L"], (t, "arm_R"): L["top_arm_R"],
            (i, "body"): L["inner_body"], (p, "body"): L["pants_body"], (p, "leg_L"): L["pants_leg_L"], (p, "leg_R"): L["pants_leg_R"],
            ("shoe_Left", "leg_L"): L["shoe_L"], ("shoe_Right", "leg_R"): L["shoe_R"],
            ("skin", "any"): L["skin"], ("brow", "any"): L["brow"], ("glasses", "any"): L["glasses"], ("sole", "any"): L["sole"]}


def shade_cyl(at, rect, ramp, lv, kind="cyl"):
    x0, y0, w, h = rect
    Lv = np.array([-0.45, 0.55, 0.70])
    Lv /= np.linalg.norm(Lv)
    lo, hi = lv
    for i in range(w):
        u = (i + 0.5) / w
        th = 2 * math.pi * u - math.pi          # 0 = front
        n = np.array([math.sin(th), 0.0, math.cos(th)])
        lam = max(0.0, float(n @ Lv))
        for j in range(h):
            vy = 1 - j / max(h - 1, 1)
            f = 0.30 + 0.62 * lam + 0.10 * (vy - 0.5)
            at.a[y0 + j, x0 + i] = P(ramp, lo + int(round((hi - lo) * min(1.0, max(0.0, f)))))


def flat(at, rect, ramp, k, noise=0):
    x0, y0, w, h = rect
    at.rect(x0, y0, w, h, P(ramp, k))
    for _ in range(noise):
        at.shift_px(x0 + at.rng.integers(0, w), y0 + at.rng.integers(0, h), int(at.rng.choice([-1, 1])))


def pat(at, rect, kind):
    """chr_tex.pattern operates on named regions; run it on an ad-hoc rect"""
    import chr_tex
    chr_tex.REG["_tmp"] = rect
    pattern(at, "_tmp", kind)
    del chr_tex.REG["_tmp"]


def fold_rows(at, rect, row, n=5, spread=5):
    import chr_tex
    chr_tex.REG["_tmp"] = rect
    folds(at, "_tmp", int(row), n=n, spread=spread)
    del chr_tex.REG["_tmp"]


def row_of(info, y):
    x0, y0, w, h = info["rect"]
    lo, hi = info["y"]
    return y0 + (hi - y) / max(hi - lo, 1e-6) * (h - 1)


def col_of(info, th):
    """column for an angle around the body axis (0 = front, + = character's left)"""
    x0, y0, w, h = info["rect"]
    return x0 + ((th + math.pi) / (2 * math.pi)) % 1.0 * (w - 1)


def face_px(sc, p):
    cx, yb, yt, hw = sc.params["face_box"]
    x0, y0, w, h = LAYOUT_SLOTS["face"]
    return x0 + (p[0] - (cx - hw)) / (2 * hw) * (w - 1), y0 + (yt - p[1]) / (yt - yb) * (h - 1)


# ------------------------------------------------------------------ face
def paint_face(at, sc, look):
    sk = look["skin"]
    rect = LAYOUT_SLOTS["face"]
    x0, y0, w, h = rect
    # soft planar shading: brighter centre-left, darker at the rims and under the chin
    for i in range(w):
        for j in range(h):
            dx = (i - w * 0.45) / (w * 0.5)
            dy = (j - h * 0.42) / (h * 0.55)
            # light from the top-left: lighter upper-left of the face, a soft shadow along the jaw / right edge
            lit = -0.55 * dx - 0.45 * dy
            k = 4 if lit > -0.15 else 3
            if dy > 0.95 or dx > 0.92:
                k = 2
            at.a[y0 + j, x0 + i] = P(sk, k)
    f = sc.feat
    for idx, e in enumerate(f["eyes"]):
        ex, ey = face_px(sc, e)
        rx = f["eye_r"][0] / (2 * sc.params["face_box"][3]) * (w - 1)
        ry = f["eye_r"][1] / (sc.params["face_box"][2] - sc.params["face_box"][1]) * (h - 1)
        sx = 1 if idx == 0 else -1
        # socket shadow ring, white, iris/pupil, lid line
        for i in range(int(ex - rx - 2), int(ex + rx + 3)):
            for j in range(int(ey - ry - 2), int(ey + ry + 3)):
                q = ((i - ex) / (rx + 1.5)) ** 2 + ((j - ey) / (ry + 1.5)) ** 2
                if q <= 1.0:
                    at.shift_px(i, j, -1)
        for i in range(int(ex - rx - 1), int(ex + rx + 2)):
            for j in range(int(ey - ry - 1), int(ey + ry + 2)):
                q = ((i - ex) / max(rx, 0.6)) ** 2 + ((j - ey) / max(ry, 0.6)) ** 2
                if q <= 1.0:
                    at.px(i, j, P("eye_white", 1 if j >= ey else 2))
        px_ = ex + f["pupils"][0] * sx / 0.004 + (0.6 if sx > 0 else -0.2)
        py_ = ey + f["pupils"][1] / 0.004
        pr = max(1.0, min(rx, ry) * 0.75)
        for i in range(int(px_ - pr - 1), int(px_ + pr + 2)):
            for j in range(int(py_ - pr - 1), int(py_ + pr + 2)):
                if ((i - px_) ** 2 + (j - py_) ** 2) <= pr * pr and ((i - ex) / max(rx, 0.6)) ** 2 + ((j - ey) / max(ry, 0.6)) ** 2 <= 1.1:
                    at.px(i, j, P("ink", 0))
        at.px(int(px_) - 1 if pr > 1.2 else int(px_), int(py_) - (1 if pr > 1.2 else 0), P("eye_white", 2))     # catch-light
        for i in range(int(ex - rx - 1), int(ex + rx + 2)):            # upper lid
            j = int(round(ey - ry - 0.5 - (0.6 if abs(i - ex) < rx * 0.5 else 0)))
            at.px(i, j, P(sk, 0))
        if f["style"] == "marcus":                                     # heavy lids + bags
            for i in range(int(ex - rx), int(ex + rx + 1)):
                at.px(i, int(ey - ry + 0.5), P(sk, 1))
            for j_off, k in ((ry + 1.5, 1), (ry + 2.5, 2)):
                for i in range(int(ex - rx), int(ex + rx + 1)):
                    at.px(i, int(ey + j_off), P(sk, k))
        else:
            for i in range(int(ex - rx + 1), int(ex + rx)):
                at.px(i, int(ey + ry + 1.5), P(sk, 2))
    # nostrils + nose shadow
    nb = f["nose"]
    for sx in (1, -1):
        nx, ny = face_px(sc, nb + np.array([sx * 0.016 + 0.003, -0.074 if f["style"] == "eddie" else -0.058, 0]))
        at.px(nx, ny, P(sk, 0))
        at.px(nx + 1, ny, P(sk, 1))
    # mouth
    mh, half, roll = f["mouth"]
    mx_, my_ = face_px(sc, mh)
    hw_px = half / (2 * sc.params["face_box"][3]) * (w - 1)
    for k in range(-int(hw_px), int(hw_px) + 1):
        t = k / max(hw_px, 1)
        dy = -t * math.tan(math.radians(roll)) * hw_px * 0.5
        if f["style"] == "marcus":
            dy += 1.2 * t * t                                          # corners down
        at.px(mx_ + k, my_ + dy, P("lip", 0))
        if abs(t) < 0.75:
            at.px(mx_ + k, my_ + dy + 1, P("lip", 2))
            at.px(mx_ + k, my_ + dy + 2, P("lip", 1) if abs(t) < 0.5 else P(sk, 2))
    if f["style"] == "eddie":
        at.px(mx_ + hw_px - 2, my_ - 1, P("paint_white", 3))          # a tooth peeking out of the smirk
        at.px(mx_ + hw_px + 1, my_ - 2, P(sk, 1))                     # smirk crease
    else:
        # stubble: dark speckle clusters over jaw, chin and upper lip; furrow between the brows; forehead lines
        rng = at.rng
        nx, ny = face_px(sc, nb + np.array([0, -0.05, 0]))
        for j in range(int(ny) + 1, h - 1):
            for i in range(4, w - 4):
                if (i + 2 * j) % 2 == 0 and rng.random() < 0.55 and not (abs(i - mx_) < hw_px + 1 and abs(j - my_) < 2):
                    at.px(x0 + i, y0 + j, P("hair_black_gray", 2))
        bx, by = face_px(sc, np.array([0.0, 1.638, 0]))
        for dx in (-2, 2):
            for dj in range(3):
                at.px(bx + dx, by + dj, P(sk, 1))
        for q in range(2):
            fy = by - 5 - q * 3
            for i in range(int(bx - 10), int(bx + 11)):
                if (i + q) % 5:
                    at.px(i, fy + (1 if abs(i - bx) > 7 else 0), P(sk, 2))
    # cheek planes / blush for Eddie
    if f["style"] == "eddie":
        for sx in (1, -1):
            cx_, cy_ = face_px(sc, np.array([sx * 0.06, 1.53, 0]))
            for i in range(-2, 3):
                at.px(cx_ + i, cy_, P("lip", 3))


def paint_hair(at, rect, ramp, style):
    shade_cyl(at, rect, ramp, (0, 3))
    x0, y0, w, h = rect
    rng = at.rng
    # clumps: short curved strands, light on top-left, dark under each clump
    for _ in range(160 if style == "eddie" else 110):
        x = x0 + rng.integers(0, w)
        y = y0 + rng.integers(0, h)
        ln = rng.integers(3, 7) if style == "eddie" else rng.integers(2, 4)
        bend = rng.choice([-1, 1])
        for q in range(ln):
            at.shift_px(x + (q * bend) // 3, y + q, -1 if q == ln - 1 else 1 if q == 0 else 0)
    for x in range(x0, x0 + w, 3):
        at.shift_px(x, y0 + h - 1, -1)
    if style == "marcus":
        for _ in range(70):
            at.px(x0 + rng.integers(0, w), y0 + rng.integers(0, h), P("hair_black_gray", 4))


# ------------------------------------------------------------------ garments
def paint_top(at, info, sc, look):
    kind = look["top"]
    rect = info["rect"]
    x0, y0, w, h = rect
    ramp, lv = look["top_ramp"], look["top_lv"]
    shade_cyl(at, rect, ramp, lv)
    pat(at, rect, "canvas")
    gap = sc.params["opening"]
    for s in (-1, 1):                                         # opening edges: zip teeth / piping
        c = col_of(info, s * gap)
        for y in range(y0, y0 + h):
            at.px(c, y, P(ramp, lv[0]))
            if kind == "jacket":
                at.px(c + (1 if s > 0 else -1), y, P("metal", 3 if y % 2 else 1))
    hem = int(row_of(info, info["y"][0] + 0.03))
    for x in range(x0, x0 + w):                               # hem band / ribbing
        for y in range(hem, y0 + h):
            at.a[y, x] = P(ramp, lv[0] + (1 if (x % 2 == 0 and kind == "hoodie") else 0))
    for u in (0.25, 0.75):
        c = x0 + u * (w - 1)
        for y in range(y0, hem):
            at.shift_px(c, y, -1)
    fold_rows(at, rect, row_of(info, 1.10 if kind == "hoodie" else 1.05), n=8, spread=6)
    if kind == "hoodie":
        top = int(row_of(info, 1.40))
        for s in (-1, 1):                                      # drawstrings
            c = col_of(info, s * (gap + 0.12))
            for y in range(top, top + 9):
                at.px(c, y, P("paint_white", 2))
            at.px(c, top + 9, P("plastic", 3))
        ty = int(row_of(info, 1.235))                          # name tag on his left chest
        c = col_of(info, gap + 0.34)
        at.rect(c - 4, ty, 9, 5, P("paint_white", 3))
        at.rect(c - 4, ty, 9, 1, P("paint_red", 3))
        for k in range(6):
            at.px(c - 3 + k + k // 3, ty + 3, P("ink", 1))
        for x in range(x0, x0 + w):                            # hood rim at the back
            if abs(((x - x0) / (w - 1)) - 0.0) < 0.12 or abs(((x - x0) / (w - 1)) - 1.0) < 0.12:
                at.shift_px(x, int(row_of(info, 1.36)), -1)
    else:
        coll = int(row_of(info, 1.40))                          # corduroy collar
        for y in range(y0, coll):
            for x in range(x0, x0 + w):
                at.a[y, x] = P(ramp, lv[0] + (0 if x % 2 else 1))
        for s in (-1, 1):                                       # pocket flaps + chest pocket stitching
            for (yy, ang) in ((0.99, 0.62), (1.23, 0.50)):
                c, r = col_of(info, s * ang), int(row_of(info, yy))
                for k in range(-6, 7):
                    at.px(c + k, r, P(ramp, lv[0]))
                    if k % 2 == 0:
                        at.px(c + k, r + 2, P(ramp, lv[1]))
        pc = col_of(info, 0.42)                                 # faded patch on his left chest
        pr = int(row_of(info, 1.30))
        at.rect(pc - 3, pr, 6, 5, P("paint_green", 2))
        at.rect(pc - 3, pr, 6, 1, P("paint_green", 3))
        rng = at.rng
        for _ in range(60):                                     # wear: rubbed light patches, stains
            at.shift_rect(x0 + rng.integers(0, w), y0 + rng.integers(0, h), 2, 1, 1)
        for _ in range(6):
            at.shift_rect(x0 + rng.integers(0, w - 3), y0 + rng.integers(0, h - 2), 3, 2, -1)


def paint_sleeve(at, info, look):
    rect = info["rect"]
    x0, y0, w, h = rect
    ramp, lv = look["top_ramp"], look["top_lv"]
    shade_cyl(at, rect, ramp, lv)
    pat(at, rect, "canvas")
    cuff = y0 + int(h * 0.86)
    for y in range(cuff, y0 + h):
        for x in range(x0, x0 + w):
            at.a[y, x] = P(ramp, lv[0] + (1 if x % 2 == 0 else 0))
    fold_rows(at, rect, y0 + h * 0.48, n=6, spread=4)
    fold_rows(at, rect, y0 + h * 0.75, n=4, spread=3)
    if look["top"] == "jacket":
        for _ in range(25):
            at.shift_rect(x0 + at.rng.integers(0, w), y0 + at.rng.integers(0, h), 2, 1, 1)


def paint_inner(at, info, sc, look):
    rect = info["rect"]
    x0, y0, w, h = rect
    ramp, lv = look["inner_ramp"], look["inner_lv"]
    shade_cyl(at, rect, ramp, lv)
    if look["inner"] == "flannel":
        pat(at, rect, "plaid")
        c = col_of(info, 0.0)
        for y in range(y0 + 2, y0 + h, 5):
            at.px(c, y, P("plastic", 3))
    else:
        # small original pixel ghost graphic on the tee
        c, r = int(col_of(info, 0.0)), int(row_of(info, 1.24))
        ghost = ["00111100", "01111110", "11011011", "11111111", "11111111", "11111111", "10110101"]
        for j, row in enumerate(ghost):
            for i, b in enumerate(row):
                if b == "1":
                    at.px(c - 4 + i, r + j, P("paint_white", 3))
        at.px(c - 2, r + 2, P("ink", 0))
        at.px(c + 1, r + 2, P("ink", 0))


def paint_pants(at, info, look, seg):
    rect = info["rect"]
    x0, y0, w, h = rect
    ramp, lv = look["pants_ramp"], look["pants_lv"]
    shade_cyl(at, rect, ramp, lv)
    jeans = look["pants"] == "jeans"
    pat(at, rect, "twill" if jeans else "canvas")
    for u in (0.25, 0.75):
        c = x0 + u * (w - 1)
        for y in range(y0, y0 + h):
            at.px(c, y, P(ramp, lv[0]))
            if jeans and y % 2 == 0:
                at.px(c + 1, y, P("paint_mustard", 3))      # orange-ish stitching
    if seg == "body":
        c = x0 + (w - 1) * 0.5
        for y in range(y0 + 2, y0 + h):
            at.px(c, y, P(ramp, lv[0]))
        for uc in (0.06, 0.94):                              # back pockets
            c = x0 + uc * (w - 1)
            at.rect(c - 4, y0 + 8, 8, 8, P(ramp, lv[0] + 1))
            at.rect(c - 4, y0 + 8, 8, 1, P(ramp, lv[0]))
    else:
        knee = y0 + int(h * 0.48)
        for x in range(x0 + int(w * 0.38), x0 + int(w * 0.62)):
            for y in range(knee - 4, knee + 5):
                if (x + y) % 3:
                    at.shift_px(x, y, 1 if jeans else -1)
        hem = y0 + int(h * 0.92)
        at.rect(x0, hem, w, h - (hem - y0), P(ramp, lv[0] + 1))
        at.rect(x0, hem, w, 1, P(ramp, lv[0]))
        fold_rows(at, rect, y0 + h * 0.82, n=7, spread=4)
        if not jeans:                                        # side cargo pocket
            for uc in (0.25, 0.75):
                c = x0 + uc * (w - 1)
                at.rect(c - 5, y0 + 10, 10, 10, P(ramp, lv[0] + 1))
                at.rect(c - 5, y0 + 10, 10, 2, P(ramp, lv[0]))


def paint_shoe(at, info, look):
    rect = info["rect"]
    x0, y0, w, h = rect
    if look["shoes"] == "sneakers":
        flat(at, rect, "plastic", 3, noise=20)
        for i in range(w):                                    # wavy side stripe (original design)
            y = y0 + int(h * 0.52 + 2.5 * math.sin(i / w * math.pi * 1.6))
            at.rect(x0 + i, y, 1, 3, P("paint_red", 3))
            at.px(x0 + i, y + 3, P("paint_red", 1))
        for k in range(5):                                    # laces at the front top
            at.rect(x0 + int(w * 0.55) + k * 2, y0 + 3 + k, 2, 1, P("paint_white", 1))
        at.rect(x0, y0 + h - 3, w, 3, P("plastic", 2))
        at.rect(x0 + int(w * 0.82), y0 + int(h * 0.3), int(w * 0.18), int(h * 0.5), P("plastic", 4))   # toe cap
    else:
        flat(at, rect, "leather", 2, noise=30)
        for k in range(6):
            at.rect(x0 + int(w * 0.5) + k * 2, y0 + 2 + k * 2, 3, 1, P("leather", 5))
        for i in range(0, w, 2):
            at.px(x0 + i, y0 + h - 4, P("leather", 4))         # welt stitching
        at.rect(x0 + int(w * 0.75), y0 + int(h * 0.35), int(w * 0.25), int(h * 0.45), P("leather", 1))
        for _ in range(8):
            at.shift_rect(x0 + at.rng.integers(0, w - 2), y0 + at.rng.integers(0, h - 2), 2, 1, 1)


def paint(sc, look):
    at = Atlas(sc.name)
    ch = sc.charts
    paint_face(at, sc, look)
    paint_hair(at, LAYOUT_SLOTS["hair"], look["hair"], sc.feat["style"])
    flat(at, LAYOUT_SLOTS["skin"], look["skin"], 3, noise=10)
    flat(at, LAYOUT_SLOTS["brow"], look["hair"], 0, noise=4)
    flat(at, LAYOUT_SLOTS["glasses"], "paint_black", 2, noise=3)
    flat(at, LAYOUT_SLOTS["sole"], "plastic" if look["shoes"] == "sneakers" else "rubber", 2 if look["shoes"] == "sneakers" else 1, noise=6)
    flat(at, LAYOUT_SLOTS["spare"], "ink", 0)
    for key, info in ch.items():
        part, seg = key
        if part == look["top"]:
            if seg == "body":
                paint_top(at, info, sc, look)
            else:
                paint_sleeve(at, info, look)
        elif part == look["inner"]:
            paint_inner(at, info, sc, look)
        elif part == look["pants"]:
            paint_pants(at, info, look, seg)
        elif part.startswith("shoe"):
            paint_shoe(at, info, look)
    return at
