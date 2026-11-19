"""E. Furniture and household materials (small, prop-scale tiles)."""
import math

import numpy as np

from .core import (tri, P, Canvas, rng_for, vnoise, quant, despeckle, voronoi, jitter_points,
                   blob_mask, relief, crack_mask, apply_crack, outline)
from .shapes import wood_board


def wood_light():
    rng = rng_for("wood_light")
    cv = Canvas(64, 64, 0)
    wood_board(cv, 0, 0, 64, 64, "wood_light", 2, rng, spacing=4.0, knots=1, amp=3.0)
    for (x, y) in jitter_points(64, 64, 6, rng, prob=0.4):  # ray flecks
        cv.shift_px(x, y, 1)
        cv.shift_px(x + 1, y, 1)
    return cv


def wood_dark():
    rng = rng_for("wood_dark")
    cv = Canvas(64, 64, 0)
    wood_board(cv, 0, 0, 64, 64, "wood_dark", 3, rng, spacing=3.0, knots=0, amp=2.0,
               dash=0.2, contrast=2)
    tone = despeckle(quant(vnoise(64, 64, 16, rng, octaves=2, cell_y=8), 3, dither=0.4), 2)
    cv.shift(tone == 0, -1)
    cv.shift(tone == 2, 1)
    for (x, y) in jitter_points(64, 64, 4, rng, prob=0.5):  # open pores
        cv.set(x, y, P("wood_dark", 0))
        cv.set(x + 1, y, P("wood_dark", 1))
    return cv


def wood_painted():
    rng = rng_for("wood_painted")
    W = 64
    cv = Canvas(W, W, 0)
    cv.a = P.ramp("paint_mustard", despeckle(quant(vnoise(W, W, 16, rng, octaves=2), 2, dither=0.5), 2) + 2)
    for (x, y) in jitter_points(W, W, 4, rng, prob=0.8):  # brush strokes
        d = -1 if rng.random() < 0.6 else 1
        for i in range(int(rng.integers(6, 18))):
            cv.shift_px(x + i, y, d)
    wear = vnoise(W, W, 16, rng, octaves=2)
    chip = wear > 0.78
    cv.a[chip] = P.ramp("wood_light", quant(vnoise(W, W, 8, rng), 2)[chip] + 1)
    cv.paint(outline(chip) & (np.roll(chip, -1, 0)), P("paint_mustard", 4))
    return cv


def leather_worn():
    rng = rng_for("leather_worn")
    W = 64
    cid, d1, d2, vx, vy = voronoi(W, W, 4, rng)
    cv = Canvas(W, W, 0)
    s = np.where(vx + vy < -0.3, 1, np.where(vx + vy > 0.35, -1, 0))
    cv.a = P.ramp("leather", 2 + s)
    wear = vnoise(W, W, 16, rng, octaves=2)
    wq = tri(wear, 0.3, 0.72, dither=0.5)
    cv.shift(wq == 2, 2)
    cv.shift(wq == 1, 1)
    # creases with a lit edge
    for _ in range(5):
        m = crack_mask(W, W, rng, rng.integers(0, W), rng.integers(0, W), 18,
                       angle=rng.normal(0, 0.3) + (0 if rng.random() < 0.5 else math.pi), wiggle=0.15, branch=0)
        apply_crack(cv, m, P("leather", 0))
    # fine craquelure in the most worn patches
    cid2, a1, a2, _, _ = voronoi(W, W, 8, rng)
    cv.paint(((a2 - a1) < 0.06) & (wq == 2), P("leather", 1))
    return cv


def fabric_upholstery():
    rng = rng_for("fabric_upholstery")
    W = 64
    Y, X = np.mgrid[0:W, 0:W]
    twill = (((X + Y) // 2) % 2)
    tone = despeckle(quant(vnoise(W, W, 16, rng, octaves=2), 2, dither=0.5))
    cv = Canvas(W, W, 0)
    cv.a = P.ramp("upholstery", 1 + twill + tone)
    for (x, y) in jitter_points(W, W, 4, rng, prob=0.35):  # tweed slubs
        col = P("upholstery", 4) if rng.random() < 0.6 else P("rust", 3)
        cv.set(x, y, col)
        cv.set(x + 1, y, col)
    pill = vnoise(W, W, 16, rng, octaves=2) > 0.7
    cv.shift(pill, 1)
    return cv


def denim():
    rng = rng_for("denim")
    W = 64
    Y, X = np.mgrid[0:W, 0:W]
    warp = ((X - Y) % 4) < 2
    cv = Canvas(W, W, 0)
    cv.a = P.ramp("denim", np.where(warp, 2, 3))
    slub = vnoise(W, W, 4, rng, cell_y=32) > 0.72
    cv.shift(slub & warp, 1)
    fade = vnoise(W, W, 32, rng, octaves=2)
    fq = tri(fade, 0.2, 0.72, dither=0.6)
    cv.shift(fq == 2, 1)
    cv.shift((fq == 2) & ~warp, 1)
    cv.shift(fq == 0, -1)
    return cv


def plastic_dirty():
    rng = rng_for("plastic_dirty")
    W = 32
    cv = Canvas(W, W, 0)
    cv.a = P.ramp("plastic", despeckle(quant(vnoise(W, W, 8, rng, octaves=2), 2, dither=0.5)) + 2)
    r = relief(vnoise(W, W, 4, rng), 0.3)
    cv.shift(r != 0, r)
    dirt = vnoise(W, W, 8, rng, octaves=2) < 0.3
    cv.shift(dirt, -1)
    for (x, y) in jitter_points(W, W, 10, rng, prob=0.6):
        for i in range(int(rng.integers(3, 7))):
            cv.shift_px(x + i, y + i // 2, 1)
    return cv


def metal_brushed():
    rng = rng_for("metal_brushed")
    W = 64
    cv = Canvas(W, W, P("metal", 3))
    for y in range(W):
        x = int(rng.integers(0, W))
        while x < W * 2:
            L = int(rng.integers(5, 30))
            lv = int(rng.choice([2, 3, 3, 4]))
            cv.rect(x, y, L, 1, P("metal", lv))
            x += L
    band = np.sin(np.arange(W) / W * 2 * math.pi)[:, None].repeat(W, 1)
    cv.shift(band > 0.75, 1)
    cv.shift(band < -0.8, -1)
    for (x, y) in jitter_points(W, W, 16, rng, prob=0.6):
        for i in range(int(rng.integers(4, 10))):
            cv.set(x + i, y - i, P("metal", 5))
    return cv


def metal_rusted():
    rng = rng_for("metal_rusted")
    W = 64
    cv = Canvas(W, W, 0)
    cv.a = P.ramp("metal", despeckle(quant(vnoise(W, W, 16, rng), 2, dither=0.5)) + 1)
    cover = vnoise(W, W, 16, rng, octaves=3)
    rust = cover > 0.42
    rl = quant(vnoise(W, W, 8, rng, octaves=2), 4, dither=0.5) + 1
    cv.a[rust] = P.ramp("rust", rl[rust])
    cv.paint(outline(rust) & ~rust, P("rust", 0))
    for (x, y) in jitter_points(W, W, 4, rng, prob=0.5):
        if rust[y % W, x % W]:
            cv.set(x, y, P("rust", 0))
            cv.shift_px(x + 1, y + 1, 1)
    for (x, y) in jitter_points(W, W, 10, rng, prob=0.6):  # rust runs
        if rust[y % W, x % W]:
            for k in range(int(rng.integers(4, 14))):
                cv.set(x, y + k, P("rust", 2 if k % 3 else 3))
    return cv


def rubber():
    rng = rng_for("rubber")
    W = 32
    Y, X = np.mgrid[0:W, 0:W]
    d = np.abs((X % 8) - 4) + np.abs((Y % 8) - 4)
    cv = Canvas(W, W, P("rubber", 1))
    cv.paint(d <= 2, P("rubber", 2))
    cv.paint((d <= 2) & ((X % 8) < 4) & ((Y % 8) < 4), P("rubber", 3))
    cv.paint(d == 3, P("rubber", 0))
    scuff = vnoise(W, W, 8, rng, octaves=2) > 0.7
    cv.shift(scuff, 1)
    return cv


def cardboard():
    rng = rng_for("cardboard")
    W = 64
    cv = Canvas(W, W, 0)
    cv.a = P.ramp("cardboard", despeckle(quant(vnoise(W, W, 16, rng, octaves=2), 2, dither=0.5)) + 2)
    corr = (np.arange(W) % 4 == 0)[None, :].repeat(W, 0) & (vnoise(W, W, 4, rng, cell_y=16) > 0.4)
    cv.shift(corr, -1)
    for (x, y) in jitter_points(W, W, 3, rng, prob=0.4):  # fibres
        d = 1 if rng.random() < 0.5 else -1
        cv.shift_px(x, y, d)
        cv.shift_px(x + 1, y, d)
    cv.shift_rect(0, 40, W, 1, -2)  # fold crease
    cv.shift_rect(0, 41, W, 1, 1)
    m = blob_mask(W, W, 20, 18, 9, rng, rough=0.3)
    ring = outline(m)
    cv.shift(m, -1)
    cv.shift(ring, -2)
    return cv
