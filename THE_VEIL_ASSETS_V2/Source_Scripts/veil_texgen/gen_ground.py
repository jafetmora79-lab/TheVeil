"""C. Ground and vegetation."""
import math

import numpy as np

from .core import (P, Canvas, rng_for, vnoise, quant, despeckle, jitter_points, voronoi,
                   blob_mask, rim_masks, relief, bresenham)
from .shapes import blades, leaf_sprite, stones


def grass_short():
    rng = rng_for("grass_short")
    W = 128
    clump = vnoise(W, W, 32, rng, octaves=2)
    cv = Canvas(W, W, 0)
    cv.a = P.ramp("grass", despeckle(quant(clump, 2, dither=0.5)) + 1)
    lvl = quant(vnoise(W, W, 16, rng, octaves=2), 3) + 2
    tint = vnoise(W, W, 32, rng, octaves=2)
    blades(cv, rng, "grass", 3, 2, 4, lvl, lean=0.35, alt_ramp="grass_dry",
           alt_field=tint, alt_thresh=0.78)
    return cv


def grass_overgrown():
    rng = rng_for("grass_overgrown")
    W = 128
    cv = Canvas(W, W, P("grass", 0))
    lvl = quant(vnoise(W, W, 16, rng, octaves=2), 4) + 1
    blades(cv, rng, "grass", 2, 5, 9, lvl, lean=0.3, curve=0.06)
    # a few weed flowers
    for (x, y) in jitter_points(W, W, 40, rng, prob=0.6):
        col = P("paint_white", 4) if rng.random() < 0.5 else P("grass_dry", 4)
        for i, j in [(0, -1), (-1, 0), (1, 0), (0, 1)]:
            cv.set(x + i, y + j, col)
        cv.set(x, y, P("leaf_ochre", 2))
    return cv


def grass_dry():
    rng = rng_for("grass_dry")
    W = 128
    bare = vnoise(W, W, 32, rng, octaves=2)
    cv = Canvas(W, W, 0)
    cv.a = P.ramp("soil", despeckle(quant(bare, 2, dither=0.5)) + 2)
    lvl = quant(vnoise(W, W, 16, rng, octaves=2), 3) + 1
    green = vnoise(W, W, 16, rng)
    pts_field = bare.copy()
    tmp = Canvas(W, W, -1)
    blades(cv, rng, "grass_dry", 3, 3, 6, lvl, lean=0.6, curve=0.05, alt_ramp="grass",
           alt_field=green, alt_thresh=0.82)
    # bare earth patches show through
    patch = bare < 0.22
    cv.a[patch] = P.ramp("soil", quant(vnoise(W, W, 8, rng), 2)[patch] + 2)
    return cv


def mud():
    rng = rng_for("mud")
    W = 128
    f = vnoise(W, W, 32, rng, octaves=3)
    cv = Canvas(W, W, 0)
    cv.a = P.ramp("mud", despeckle(quant(f, 3, dither=0.5), 2) + 1)
    r = relief(vnoise(W, W, 8, rng, octaves=2), 0.06)
    cv.shift(r != 0, r)
    # standing water with sky glints
    water = f < 0.3
    cv.paint(water, P("mud", 0))
    tl, br = rim_masks(water)
    cv.paint(tl, P("mud", 4))
    for (x, y) in jitter_points(W, W, 5, rng, prob=0.35):
        if water[y % W, x % W]:
            cv.set(x, y, P("glass", 2))
            cv.set(x + 1, y, P("glass", 1))
    for (x, y) in jitter_points(W, W, 6, rng, prob=0.25):
        if not water[y % W, x % W]:
            cv.set(x, y, P("mud", 5))
    return cv


def soil():
    rng = rng_for("soil")
    W = 128
    cv = Canvas(W, W, P("soil", 0))
    stones(cv, rng, 8, ["soil"], P("soil", 0), levels=(2, 2, 3), gap=0.1)
    r = relief(vnoise(W, W, 4, rng), 0.25)
    cv.shift(r != 0, r)
    for (x, y) in jitter_points(W, W, 12, rng, prob=0.4):
        cv.set(x, y, P("stone_warm", 3))
        cv.set(x + 1, y, P("stone_warm", 2))
        cv.set(x + 1, y + 1, P("soil", 0))
    # root fibres
    for _ in range(6):
        x, y = rng.integers(0, W), rng.integers(0, W)
        ang = rng.random() * 2 * math.pi
        for k in range(int(rng.integers(6, 14))):
            ang += rng.normal(0, 0.4)
            x, y = x + math.cos(ang), y + math.sin(ang)
            cv.set(round(x), round(y), P("leaf_brown", 3))
    return cv


def leaves_fallen():
    rng = rng_for("leaves_fallen")
    W = 128
    cv = Canvas(W, W, 0)
    cv.a = P.ramp("soil", quant(vnoise(W, W, 16, rng, octaves=2), 2) + 1)
    ramps = ["leaf_rust", "leaf_ochre", "leaf_brown", "leaf_brown", "leaf_rust"]
    for layer, step in ((0, 9), (1, 9), (2, 11)):
        for (x, y) in jitter_points(W, W, step, rng, prob=0.9):
            r = ramps[int(rng.integers(0, len(ramps)))] if layer else "leaf_brown"
            base = 1 if layer == 0 else int(rng.integers(1, 3))
            leaf_sprite(cv, x, y, rng.uniform(5, 8), rng.uniform(3, 4.5),
                        rng.random() * 2 * math.pi, r, base, shadow=P("soil", 0))
    return cv


def moss():
    rng = rng_for("moss")
    W = 64
    cv = Canvas(W, W, P("moss", 0))
    cid, d1, d2, vx, vy = voronoi(W, W, 4, rng)
    base = rng.choice([1, 2, 2, 3], cid.max() + 1)[cid]
    s = np.where(vx + vy < -0.2, 1, np.where(vx + vy > 0.35, -1, 0))
    cv.a = P.ramp("moss", base + s)
    cv.paint((d2 - d1) < 0.08, P("moss", 0))
    for (x, y) in jitter_points(W, W, 7, rng, prob=0.45):
        cv.set(x, y, P("moss", 3))
        cv.set(x, y - 1, P("leaf_ochre", 3))
    return cv


def tree_bark():
    rng = rng_for("tree_bark")
    W = 128
    cid, d1, d2, vx, vy = voronoi(W, W, 8, rng, jitter=0.9, cell_y=32)
    base = rng.choice([1, 2, 2, 3], cid.max() + 1)[cid]
    lit = np.where(vx < -0.15, 1, np.where(vx > 0.25, -1, 0))
    cv = Canvas(W, W, 0)
    cv.a = P.ramp("bark", base + lit)
    # vertical striations inside the plates
    st = vnoise(W, W, 4, rng, cell_y=32) > 0.7
    cv.shift(st, -1)
    fur = (d2 - d1) < 0.12
    cv.paint(fur, P("bark", 0))
    cv.paint(((d2 - d1) < 0.05), P("ink", 0))
    for (x, y) in jitter_points(W, W, 16, rng, prob=0.35):
        for i, j in [(0, 0), (1, 0), (0, 1), (1, 1), (2, 1)][: int(rng.integers(2, 5))]:
            cv.set(x + i, y + j, P("lichen", int(rng.integers(1, 3))))
    return cv


def hedge_foliage():
    rng = rng_for("hedge_foliage")
    W = 128
    cv = Canvas(W, W, P("hedge", 0))
    shapes = [[".x.", "xxx", ".x."], ["xx.", "xxx", ".xx"], [".xx", "xxx", "xx."],
              ["xxx", "xxx"], [".xx.", "xxxx", ".xx."]]
    for layer, (step, lv) in enumerate(((3, 1), (3, 2), (4, 3), (5, 4))):
        for (x, y) in jitter_points(W, W, step, rng, prob=0.85):
            sh = shapes[int(rng.integers(0, len(shapes)))]
            v = lv + (1 if rng.random() < 0.15 else 0)
            for j, row in enumerate(sh):
                for i, ch in enumerate(row):
                    if ch == "x":
                        cv.set(x + i, y + j, P("hedge", v))
            cv.set(x + 1, y, P("hedge", v + 1))
            cv.set(x + len(sh[-1]) - 1, y + len(sh), P("hedge", max(0, v - 2)))
    # twigs visible in the gaps
    for _ in range(8):
        x, y = rng.integers(0, W), rng.integers(0, W)
        for k in range(int(rng.integers(3, 6))):
            if P.level(cv.get(x + k, y + k // 2)) <= 1:
                cv.set(x + k, y + k // 2, P("bark", 2))
    return cv


def dead_vegetation():
    rng = rng_for("dead_vegetation")
    W = 128
    cv = Canvas(W, W, 0)
    cv.a = P.ramp("dead", quant(vnoise(W, W, 16, rng, octaves=2), 2, dither=0.5))
    for (x, y) in jitter_points(W, W, 3, rng, prob=0.9):
        ang = rng.normal(0, 0.5) + (math.pi if rng.random() < 0.5 else 0)
        L = rng.uniform(4, 10)
        lv = int(rng.integers(2, 5))
        x1, y1 = x + math.cos(ang) * L, y + math.sin(ang) * L
        pts = list(bresenham(x, y, x1, y1))
        for k, (px, py) in enumerate(pts):
            cv.set(px, py + 1, P("dead", 0))
        for k, (px, py) in enumerate(pts):
            cv.set(px, py, P("dead", lv if k < len(pts) - 1 else lv + 1))
    for _ in range(10):
        x, y = rng.integers(0, W), rng.integers(0, W)
        for k in range(int(rng.integers(6, 12))):
            cv.set(x + k, y + (k // 3), P("bark", 1))
    for (x, y) in jitter_points(W, W, 14, rng, prob=0.5):
        leaf_sprite(cv, x, y, 5, 3, rng.random() * 6.28, "leaf_brown", 1, shadow=P("dead", 0))
    return cv
