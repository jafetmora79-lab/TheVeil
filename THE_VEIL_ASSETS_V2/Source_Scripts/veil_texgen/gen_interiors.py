"""D. Interior floors and walls."""
import math

import numpy as np

from .core import (tri, P, Canvas, rng_for, vnoise, quant, despeckle, crack_mask, apply_crack,
                   jitter_points, blob_mask, rim_masks, relief, partition, outline)
from .shapes import wood_board, brickwork

# Hand-authored wallpaper medallion (a = dark, b = mid, c = light).
DAMASK = [
    ".......a.......",
    "......aba......",
    ".....abcba.....",
    "......aba......",
    "...a...a...a...",
    "..aba..a..aba..",
    ".abcbaabaabcba.",
    "..abaabcbaaba..",
    "...a.abcba.a...",
    ".....abcba.....",
    "....abcccba....",
    "...abcbabcba...",
    "..abcba.abcba..",
    "...aba...aba...",
    "....a.....a....",
    ".......a.......",
    "......aba......",
    ".......a.......",
]

SPRIG = [".a.", "aba", ".a."]


def drywall_light():
    rng = rng_for("drywall_light")
    W = 128
    f = vnoise(W, W, 64, rng, octaves=2)
    cv = Canvas(W, W, 0)
    cv.a = P.ramp("drywall", despeckle(quant(f, 2, dither=0.7), 2) + 3)
    peel = relief(vnoise(W, W, 4, rng, octaves=1), 0.28)
    cv.shift(peel != 0, peel)
    for (x, y) in jitter_points(W, W, 32, rng, prob=0.4):  # faint scuffs
        for i in range(int(rng.integers(3, 7))):
            cv.shift_px(x + i, y + (i // 3), -1)
    return cv


def wallpaper_faded():
    rng = rng_for("wallpaper_faded")
    W = 128
    cv = Canvas(W, W, P("wallpaper_rose", 4))
    stripe = [3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 1, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 1]
    for x in range(W):
        cv.a[:, x] = P("wallpaper_rose", stripe[x % 32])
    for strip, dy in ((0, 0), (64, 2)):  # second strip hung slightly off-register
        for sx in range(strip, strip + 64, 32):
            for sy in range(0, W, 16):
                cv.sprite(sx + 20, sy + 6 + dy + (8 if (sx // 32) % 2 else 0), SPRIG,
                          {"a": P("wallpaper_rose", 2), "b": P("motif_ochre", 2)})
    fade = vnoise(W, W, 32, rng, octaves=2)
    fq = tri(fade, 0.2, 0.8, dither=0.6)
    cv.shift(fq == 2, 1)
    cv.shift(fq == 0, -1)
    for s in (0, 64):
        cv.shift_rect(s, 0, 1, W, -1)
    return cv


def wallpaper_patterned():
    rng = rng_for("wallpaper_patterned")
    W = 128
    cv = Canvas(W, W, P("wallpaper_green", 2))
    # fine vertical ribbing in the ground colour
    for x in range(0, W, 4):
        cv.shift_rect(x, 0, 1, W, -1)
    m = {"a": P("motif_ochre", 0), "b": P("motif_ochre", 1), "c": P("motif_ochre", 3)}
    for cx in range(0, W, 32):
        for cy in range(0, W, 32):
            dy = 16 if (cx // 32) % 2 else 0
            cv.sprite(cx + 9, cy + dy + 7, DAMASK, m)
            cv.sprite(cx + 25, cy + dy + 23, ["a.a", ".b.", "a.a"],
                      {"a": P("wallpaper_green", 1), "b": P("motif_ochre", 1)})
    age = vnoise(W, W, 32, rng, octaves=2)
    aq = tri(age, 0.2, 0.82, dither=0.6)
    cv.shift(aq == 0, -1)
    cv.shift(aq == 2, 1)
    for sx in (0, 64):  # paper strip seams, 1m strips
        cv.shift_rect(sx, 0, 1, W, -1)
    return cv


def floorboards_old():
    rng = rng_for("floorboards_old")
    W = 128
    cv = Canvas(W, W, P("ink", 0))
    widths = [12, 12, 12, 12, 20, 20, 20, 20]
    rng.shuffle(widths)
    y = 0
    for bh in widths:
        x = int(rng.integers(0, W))
        for sl in partition(W, 40, 90, rng):
            base = int(rng.choice([2, 2, 3, 1]))
            wood_board(cv, x, y, sl - 1, bh - 1, "wood_warm", base, rng, spacing=3.0,
                       knots=int(rng.random() < 0.4), amp=1.6)
            cv.shift_rect(x, y, sl - 1, 1, 1)
            cv.rect(x + sl - 1, y, 1, bh, P("ink", 0))
            for nx in (x + 2, x + sl - 4):
                cv.set(nx, y + 2, P("ink", 1))
                cv.set(nx, y + bh - 4, P("ink", 1))
            x += sl
        cv.rect(0, y + bh - 1, W, 1, P("ink", 0))
        y += bh
    wear = vnoise(W, W, 32, rng, octaves=2)
    wq = tri(wear, 0.2, 0.75, dither=0.6)
    gaps = np.isin(cv.a, [P("ink", 0), P("ink", 1)])
    cv.shift((wq == 2) & ~gaps, 1)
    for (x, y) in jitter_points(W, W, 20, rng, prob=0.5):  # scratches
        for i in range(int(rng.integers(4, 9))):
            if not gaps[(y) % W, (x + i) % W]:
                cv.shift_px(x + i, y - (i // 3), 1)
    return cv


def carpet_worn():
    rng = rng_for("carpet_worn")
    W = 128
    Y, X = np.mgrid[0:W, 0:W]
    loop = ((X // 2 + Y // 2) % 2)
    tone = despeckle(quant(vnoise(W, W, 8, rng, octaves=2), 2, dither=0.5))
    cv = Canvas(W, W, 0)
    cv.a = P.ramp("carpet", 1 + loop + tone)
    # faint 70s lattice woven into the pile
    lat = ((np.abs(((X + 16) % 32) - 16) + np.abs(((Y + 16) % 32) - 16)) == 12)
    cv.shift(lat, -1)
    wear = vnoise(W, W, 32, rng, octaves=2)
    worn = wear > 0.62
    cv.a[worn] = P.ramp("carpet", 3 + loop[worn] * 0 + (tone[worn] > 0))
    for _ in range(3):
        m = blob_mask(W, W, rng.integers(0, W), rng.integers(0, W), rng.uniform(4, 8), rng)
        cv.shift(m, -1)
    return cv


def _tile_grid(cv, rng, tw, th, ramp_a, ramp_b, base_a, base_b, grout, offset_rows=False,
               checker=True, spec=True, cracks=1, chips=4):
    W, H = cv.w, cv.h
    for ty in range(H // th):
        off = (tw // 2) * (ty % 2) if offset_rows else 0
        for tx in range(W // tw):
            x0, y0 = tx * tw + off, ty * th
            use_b = checker and ((tx + ty) % 2 == 1)
            ramp, base = (ramp_b, base_b) if use_b else (ramp_a, base_a)
            b = base + (int(rng.choice([-1, 0, 0, 0, 0, 0, 1])))
            cv.rect(x0, y0, tw - 1, th - 1, P(ramp, b))
            cv.rect(x0, y0, tw - 1, 1, P(ramp, b + 1))
            cv.rect(x0, y0, 1, th - 1, P(ramp, b + 1))
            cv.rect(x0, y0 + th - 2, tw - 1, 1, P(ramp, b - 1))
            cv.rect(x0 + tw - 2, y0, 1, th - 1, P(ramp, b - 1))
            if spec:
                cv.set(x0 + 2, y0 + 2, P(ramp, b + 2))
                cv.set(x0 + 3, y0 + 2, P(ramp, b + 2))
                cv.set(x0 + 2, y0 + 3, P(ramp, b + 2))
            cv.rect(x0 + tw - 1, y0, 1, th, grout)
            cv.rect(x0, y0 + th - 1, tw, 1, grout)
    for _ in range(chips):
        x, y = rng.integers(0, W // tw) * tw, rng.integers(0, H // th) * th
        cv.set(x + tw - 2, y + th - 2, P("grout", 0))
        cv.set(x + tw - 3, y + th - 2, P("grout", 1))
    for _ in range(cracks):
        x, y = rng.integers(0, W), rng.integers(0, H)
        m = crack_mask(W, H, rng, x, y, 10, wiggle=0.6, branch=0.1)
        cv.paint(m, P("grout", 1))


def tiles_kitchen():
    rng = rng_for("tiles_kitchen")
    cv = Canvas(128, 128, P("grout", 2))
    _tile_grid(cv, rng, 16, 16, "tile_cream", "tile_teal", 3, 2, P("grout", 2), cracks=2)
    grime = (vnoise(128, 128, 16, rng, octaves=2) < 0.35) & (cv.a == P("grout", 2))
    cv.paint(grime, P("grout", 0))
    return cv


def tiles_bathroom():
    rng = rng_for("tiles_bathroom")
    cv = Canvas(128, 128, P("grout", 3))
    _tile_grid(cv, rng, 16, 8, "bath_tile", "bath_tile", 3, 3, P("grout", 3),
               offset_rows=True, checker=False, cracks=1, chips=3)
    mildew = (vnoise(128, 128, 16, rng, octaves=2) < 0.3) & (cv.a == P("grout", 3))
    cv.paint(mildew, P("grout", 1))
    return cv


def linoleum():
    rng = rng_for("linoleum")
    W = 128
    Y, X = np.mgrid[0:W, 0:W].astype(float)
    n = vnoise(W, W, 16, rng, octaves=2)
    cv = Canvas(W, W, 0)
    sq = ((X // 32 + Y // 32) % 2).astype(bool)
    k1, k2 = 2 * math.pi * 7 / W, 2 * math.pi * 2 / W  # integer cycles -> seamless
    s1 = np.sin((X * k1 + Y * k2 + n * 6.0))
    s2 = np.sin((Y * k1 + X * k2 + n * 6.0))
    s = np.where(sq, s1, s2)
    lv = np.where(s > 0.75, 4, np.where(s < -0.8, 1, np.where(s < -0.2, 2, 3)))
    cv.a = P.ramp("lino", despeckle(lv))
    cv.shift((X % 32 == 0) | (Y % 32 == 0), -1)
    for (x, y) in jitter_points(W, W, 24, rng, prob=0.6):  # heel scuffs
        a0 = rng.random() * 6.28
        for k in range(int(rng.integers(4, 8))):
            cv.set(x + math.cos(a0 + k * 0.2) * k, y + math.sin(a0 + k * 0.2) * k * 0.5, P("rubber", 3))
    return cv


def basement_concrete():
    rng = rng_for("basement_concrete")
    W = 128
    f = vnoise(W, W, 32, rng, octaves=3)
    cv = Canvas(W, W, 0)
    cv.a = P.ramp("concrete", despeckle(quant(f, 3, dither=0.5), 2) + 1)
    # trowel swirl arcs
    for _ in range(14):
        cx, cy, r = rng.integers(0, W), rng.integers(0, W), rng.uniform(8, 26)
        a0 = rng.random() * 6.28
        for k in range(int(r * 1.4)):
            a = a0 + k / r
            cv.shift_px(cx + math.cos(a) * r, cy + math.sin(a) * r, 1)
    damp = vnoise(W, W, 32, rng, octaves=2)
    dm = damp < 0.3
    cv.shift(dm, -1)
    ring = outline(dm)
    cv.shift(ring, -1)
    for (x, y) in jitter_points(W, W, 4, rng, prob=0.5):
        if 0.3 <= damp[y % W, x % W] < 0.36:
            cv.set(x, y, P("concrete", 6))
    m = np.zeros((W, W), bool)
    for _ in range(2):
        m |= crack_mask(W, W, rng, rng.integers(0, W), rng.integers(0, W), 60, wiggle=0.3, branch=0.05)
    apply_crack(cv, m, P("ink", 1))
    return cv


def plaster_damaged():
    rng = rng_for("plaster_damaged")
    W = 128
    f = vnoise(W, W, 32, rng, octaves=2)
    cv = Canvas(W, W, 0)
    cv.a = P.ramp("drywall", despeckle(quant(f, 2, dither=0.6), 2) + 2)
    r = relief(vnoise(W, W, 8, rng, octaves=2), 0.05)
    cv.shift(r != 0, r)
    holes = np.zeros((W, W), bool)
    for _ in range(3):
        holes |= blob_mask(W, W, rng.integers(0, W), rng.integers(0, W), rng.uniform(8, 13), rng, rough=0.5)
    scratch = outline(holes) | outline(outline(holes) | holes)
    cv.paint(scratch & ~holes, P("concrete", 3))
    # wooden lath behind the plaster
    Y, X = np.mgrid[0:W, 0:W]
    lath = (Y % 5) < 3
    lath_col = np.where((Y % 5) == 0, P("wood_gray", 3), P("wood_gray", 2))
    cv.paint(holes & lath, lath_col)
    cv.paint(holes & ~lath, P("ink", 0))
    tl, br = rim_masks(holes)
    cv.paint(tl & ~lath, P("ink", 1))
    cv.paint(tl & lath, P("wood_gray", 1))
    m = np.zeros((W, W), bool)
    for _ in range(5):
        m |= crack_mask(W, W, rng, rng.integers(0, W), rng.integers(0, W), 35, wiggle=0.45, branch=0.08)
    apply_crack(cv, m & ~holes, P("drywall", 0))
    return cv
