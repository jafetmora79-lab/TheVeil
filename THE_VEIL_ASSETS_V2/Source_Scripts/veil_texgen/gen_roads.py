"""B. Streets and sidewalks."""
import math

import numpy as np

from .core import (P, Canvas, rng_for, vnoise, quant, despeckle, crack_mask, apply_crack,
                   jitter_points, voronoi, blob_mask, rim_masks, relief, bresenham)
from .shapes import stones

STONE_SHAPES = [[(0, 0)], [(0, 0), (1, 0)], [(0, 0), (0, 1)],
                [(0, 0), (1, 0), (0, 1), (1, 1)], [(0, 0), (1, 0), (1, 1)], [(0, 0), (1, 0), (2, 0)]]


def _aggregate(cv, rng, step, prob, field=None, lift=(1, 2), pit=0.12):
    """Small aggregate stones: lit top-left pixel, body one step lighter."""
    for (x, y) in jitter_points(cv.w, cv.h, step, rng, prob=prob):
        if field is not None and rng.random() > field[y % cv.h, x % cv.w] + 0.25:
            continue
        if rng.random() < pit:
            cv.shift_px(x, y, -2)
            continue
        shape = STONE_SHAPES[int(rng.integers(0, len(STONE_SHAPES)))]
        for k, (i, j) in enumerate(shape):
            cv.shift_px(x + i, y + j, lift[1] if k == 0 else lift[0])


def _asphalt_base(name, W, levels=(1, 2, 3), cell=64, prob=0.55, ramp="asphalt"):
    rng = rng_for(name)
    f = vnoise(W, W, cell, rng, octaves=3)
    cv = Canvas(W, W, 0)
    q = despeckle(quant(f, len(levels), dither=0.55), 2)
    cv.a = P.ramp(ramp, np.array(levels)[q])
    wear = vnoise(W, W, 32, rng, octaves=2)
    _aggregate(cv, rng, 4, prob, field=wear)
    return cv, rng, f


def asphalt():
    cv, rng, f = _asphalt_base("asphalt", 256)
    # a few faint tar spots
    for _ in range(5):
        m = blob_mask(256, 256, rng.integers(0, 256), rng.integers(0, 256), rng.uniform(3, 7), rng)
        cv.shift(m, -1)
    return cv


def asphalt_cracked():
    cv, rng, f = _asphalt_base("asphalt_cracked", 256, levels=(1, 2, 3, 4))
    W = 256
    # alligator cracking in worn zones
    region = vnoise(W, W, 64, rng, octaves=2) > 0.58
    cid, d1, d2, vx, vy = voronoi(W, W, 16, rng, jitter=0.9)
    piece = (rng.random(cid.max() + 1) < 0.3)[cid] & region
    cv.shift(piece, -1)
    m = ((d2 - d1) < 0.07) & region
    for _ in range(4):
        m |= crack_mask(W, W, rng, rng.integers(0, W), rng.integers(0, W), 120, wiggle=0.25, branch=0.04)
    apply_crack(cv, m, P("ink", 0))
    # small pothole with exposed aggregate rim
    hole = blob_mask(W, W, 180, 70, 7, rng, rough=0.4)
    tl, br = rim_masks(hole)
    cv.paint(hole, P("asphalt", 0))
    cv.paint(tl, P("ink", 0))
    cv.paint(br, P("asphalt", 4))
    ring = blob_mask(W, W, 180, 70, 10, rng, rough=0.3) & ~hole
    for (x, y) in jitter_points(W, W, 2, rng, prob=0.4):
        if ring[y % W, x % W]:
            cv.set(x, y, P("stone_warm", 2))
    return cv


def parking_lot_asphalt():
    cv, rng, f = _asphalt_base("parking_lot_asphalt", 256, levels=(3, 4, 4, 5), prob=0.45)
    W = 256
    # sealcoat patches: darker, crisp-edged
    seal = vnoise(W, W, 64, rng, octaves=2) > 0.62
    cv.shift(seal, -2)
    # oil stains where cars park
    for _ in range(4):
        cx, cy, r = rng.integers(0, W), rng.integers(0, W), rng.uniform(8, 14)
        outer = blob_mask(W, W, cx, cy, r, rng, rough=0.45)
        inner = blob_mask(W, W, cx, cy, r * 0.55, rng, rough=0.45)
        cv.shift(outer, -1)
        cv.shift(inner, -1)
    for _ in range(2):
        m = crack_mask(W, W, rng, rng.integers(0, W), rng.integers(0, W), 70, wiggle=0.3, branch=0.03)
        apply_crack(cv, m, P("asphalt", 0))
    return cv


def road_patch():
    rng = rng_for("road_patch")
    W = 128
    f = vnoise(W, W, 32, rng, octaves=2)
    cv = Canvas(W, W, 0)
    cv.a = P.ramp("asphalt", despeckle(quant(f, 2, dither=0.4), 2) + 1)
    _aggregate(cv, rng, 5, 0.3, lift=(1, 1))
    # "tar snakes": glossy crack sealant lines
    for _ in range(3):
        m = crack_mask(W, W, rng, rng.integers(0, W), rng.integers(0, W), 110, wiggle=0.22, branch=0.03)
        thick = m | np.roll(m, 1, 1) | np.roll(m, 1, 0)
        cv.paint(thick, P("tar", 1))
        top = thick & ~np.roll(thick, 1, 0)
        cv.paint(top, P("tar", 3))
        cv.paint(np.roll(thick, 1, 0) & ~thick, P("tar", 0))
    return cv


def _marking(name, ramp):
    rng = rng_for(name)
    W = 64
    cv = Canvas(W, W, P(ramp, 2), alpha=True)
    tone = despeckle(quant(vnoise(W, W, 16, rng, octaves=2), 3, dither=0.5), 1)
    cv.a = P.ramp(ramp, tone + 1)
    cv.alpha[:, :] = 245
    wear = vnoise(W, W, 16, rng, octaves=3)
    thin = wear < 0.38
    gone = wear < 0.28
    cv.shift(thin, -1)
    cv.alpha[thin] = 150
    cv.alpha[gone] = 0
    for (x, y) in jitter_points(W, W, 4, rng, prob=0.3):
        if cv.alpha[y % W, x % W] > 0:
            cv.set(x, y, P("asphalt", 3), 210)
    return cv


def road_marking_yellow():
    return _marking("road_marking_yellow", "road_yellow")


def road_marking_white():
    return _marking("road_marking_white", "road_white")


def _slab_concrete(cv, rng, slab, levels=(3, 4)):
    W, H = cv.w, cv.h
    f = vnoise(W, H, 16, rng, octaves=2)
    for sy in range(0, H, slab):
        for sx in range(0, W, slab):
            base = int(rng.choice(levels))
            q = quant(f[sy:sy + slab, sx:sx + slab], 2, dither=0.5) - 0
            cv.a[sy:sy + slab, sx:sx + slab] = P.ramp("concrete", base + q - 1 + 1)
            # trowelled margin
            cv.shift_rect(sx + 2, sy + 2, slab - 4, 2, 1)
            cv.shift_rect(sx + 2, sy + 2, 2, slab - 4, 1)
            # broom finish streaks
            for (x, y) in jitter_points(slab - 10, slab - 10, 3, rng, prob=0.55):
                L = int(rng.integers(3, 12))
                d = -1 if rng.random() < 0.6 else 1
                for i in range(L):
                    cv.shift_px(sx + 6 + x + i, sy + 6 + y, d)
    # tooled joints
    for k in range(0, W, slab):
        cv.rect(k, 0, 1, H, P("concrete", 0))
        cv.shift_rect(k + 1, 0, 1, H, -1)
    for k in range(0, H, slab):
        cv.rect(0, k, W, 1, P("concrete", 0))
        cv.shift_rect(0, k + 1, W, 1, -1)


def sidewalk_concrete():
    rng = rng_for("sidewalk_concrete")
    cv = Canvas(128, 128, P("concrete", 4))
    _slab_concrete(cv, rng, 64)
    # old gum spots and leaf stains
    for (x, y) in jitter_points(128, 128, 20, rng, prob=0.3):
        cv.rect(x, y, 2, 2, P("concrete", 2))
        cv.set(x + 1, y + 1, P("concrete", 1))
    return cv


def concrete_cracked():
    rng = rng_for("concrete_cracked")
    W = 128
    f = vnoise(W, W, 32, rng, octaves=3)
    cv = Canvas(W, W, 0)
    cv.a = P.ramp("concrete", despeckle(quant(f, 3, dither=0.5), 2) + 2)
    rel = relief(vnoise(W, W, 4, rng), 0.25)
    cv.shift(rel != 0, rel)
    stain = vnoise(W, W, 32, rng, octaves=2) < 0.28
    cv.shift(stain, -1)
    # spalled patches exposing aggregate
    for _ in range(3):
        hole = blob_mask(W, W, rng.integers(0, W), rng.integers(0, W), rng.uniform(5, 9), rng, rough=0.45)
        tmp = Canvas(W, W, 0)
        stones(tmp, rng, 4, ["stone_warm", "concrete"], P("concrete", 1), levels=(1, 2))
        cv.a[hole] = tmp.a[hole]
        tl, br = rim_masks(hole)
        cv.paint(tl, P("ink", 2))
        cv.paint(br, P("concrete", 5))
    m = np.zeros((W, W), bool)
    for _ in range(4):
        m |= crack_mask(W, W, rng, rng.integers(0, W), rng.integers(0, W), 70, wiggle=0.35, branch=0.07)
    apply_crack(cv, m, P("ink", 1))
    return cv


def curb_concrete():
    rng = rng_for("curb_concrete")
    W = 64
    f = vnoise(W, W, 16, rng, octaves=2)
    cv = Canvas(W, W, 0)
    cv.a = P.ramp("concrete", despeckle(quant(f, 2, dither=0.4), 2) + 4)
    rel = relief(vnoise(W, W, 4, rng), 0.3)
    cv.shift(rel != 0, rel)
    # contraction joint every metre
    cv.rect(32, 0, 1, W, P("concrete", 1))
    cv.shift_rect(33, 0, 1, W, 1)
    # tyre scuffs and edge chips
    for (x, y) in jitter_points(W, W, 16, rng, prob=0.5):
        for i in range(int(rng.integers(3, 9))):
            cv.set(x + i, y + (i // 4), P("rubber", 3))
    for (x, y) in jitter_points(W, W, 12, rng, prob=0.4):
        cv.set(x, y, P("concrete", 2))
        cv.set(x + 1, y, P("concrete", 2))
        cv.shift_px(x + 1, y + 1, 1)
    return cv


def gravel():
    rng = rng_for("gravel")
    W = 128
    cv = Canvas(W, W, P("soil", 1))
    stones(cv, rng, 4, ["concrete", "stone_warm", "stone_warm"], P("soil", 0),
           levels=(2, 3, 3, 4), gap=0.16)
    hollow = vnoise(W, W, 32, rng, octaves=2) < 0.3
    cv.shift(hollow, -1)
    return cv


def dirt_road():
    rng = rng_for("dirt_road")
    W = 256
    f = vnoise(W, W, 64, rng, octaves=3)
    cv = Canvas(W, W, 0)
    cv.a = P.ramp("soil", despeckle(quant(f, 3, dither=0.5), 2) + 2)
    dry = vnoise(W, W, 32, rng, octaves=2) > 0.6
    dq = quant(vnoise(W, W, 16, rng), 2) + 2
    cv.a[dry] = P.ramp("grass_dry", dq[dry] - 1)
    # dry-mud cracking in the dusty zones
    cid, d1, d2, vx, vy = voronoi(W, W, 16, rng)
    cr = ((d2 - d1) < 0.06) & dry
    cv.shift(cr, -1)
    # puddle depressions
    for _ in range(3):
        m = blob_mask(W, W, rng.integers(0, W), rng.integers(0, W), rng.uniform(6, 12), rng, rough=0.4)
        cv.paint(m, P("mud", 2))
        tl, br = rim_masks(m)
        cv.paint(br, P("mud", 4))
        cv.paint(tl, P("mud", 1))
    # pebbles
    for (x, y) in jitter_points(W, W, 8, rng, prob=0.35):
        sh = [(0, 0), (1, 0), (0, 1), (1, 1)][: int(rng.integers(1, 5))]
        for i, j in sh:
            cv.set(x + i, y + j, P("stone_warm", 2))
        cv.set(x, y, P("stone_warm", 3))
        cv.set(x + 1, y + 2, P("soil", 0))
    return cv
