"""G. Special horror materials.

These are deliberately restrained: they are meant for specific story beats
(decals, overlays, post-mist swaps), never as the default town look."""
import math

import numpy as np

from .core import (P, Canvas, rng_for, vnoise, quant, despeckle, jitter_points, blob_mask,
                   relief, crack_mask, apply_crack, outline, rim_masks, partition, bresenham)
from .shapes import wood_board, blades, leaf_sprite

EXCLAIM_TRIANGLE = [
    "...........kk...........",
    "..........kyyk..........",
    ".........kyyyyk.........",
    ".........kyyyyk.........",
    "........kyyyyyyk........",
    "........kyykkyyk........",
    ".......kyyykkyyyk.......",
    ".......kyyykkyyyk.......",
    "......kyyyykkyyyyk......",
    "......kyyyykkyyyyk......",
    ".....kyyyyykkyyyyyk.....",
    ".....kyyyyykkyyyyyk.....",
    "....kyyyyyyyyyyyyyyk....",
    "....kyyyyyykkyyyyyyk....",
    "...kyyyyyyykkyyyyyyyk...",
    "...kyyyyyyyyyyyyyyyyk...",
    "..kkkkkkkkkkkkkkkkkkkk..",
]


def _clear_border(cv, n=1):
    cv.alpha[:n, :] = 0
    cv.alpha[-n:, :] = 0
    cv.alpha[:, :n] = 0
    cv.alpha[:, -n:] = 0


def stain_organic_dark():
    rng = rng_for("stain_organic_dark")
    W = 64
    cv = Canvas(W, W, P("stain", 2), alpha=True)
    Y, X = np.mgrid[0:W, 0:W].astype(float)
    d = np.sqrt((X - 32) ** 2 + (Y - 30) ** 2) / 20.0
    n = vnoise(W, W, 8, rng, octaves=3)
    f = d + (n - 0.5) * 0.9
    body = f < 1.0
    core = f < 0.55
    cv.paint(body, P("stain", 2), 205)
    cv.paint(core, P("stain", 1), 235)
    cv.paint(body & ~core & (n > 0.6), P("stain", 3), 190)
    rim = body & ~np.roll(body, 1, 0) | body & ~np.roll(body, -1, 1)
    cv.paint(rim, P("stain", 0), 230)
    halo = outline(body) & (n > 0.45)
    cv.paint(halo, P("stain", 3), 120)
    for _ in range(14):  # satellite droplets
        a, r = rng.random() * 6.28, rng.uniform(21, 28)
        x, y = 32 + math.cos(a) * r, 30 + math.sin(a) * r
        s = int(rng.integers(1, 3))
        cv.rect(x, y, s, s, P("stain", 1), 220)
    for x in (24, 31, 38):  # gravity runs
        L = int(rng.integers(8, 16))
        for k in range(L):
            cv.set(x, 46 + k, P("stain", 1), 210)
        cv.rect(x, 46 + L, 2, 2, P("stain", 0), 230)
    _clear_border(cv)
    return cv


def damp_wall():
    rng = rng_for("damp_wall")
    W = 128
    cv = Canvas(W, W, 0)
    cv.a = P.ramp("drywall", despeckle(quant(vnoise(W, W, 32, rng, octaves=2), 2, dither=0.6), 2) + 2)
    f = vnoise(W, W, 32, rng, octaves=3)
    wet = f < 0.42
    inner = quant(np.clip(f / 0.42, 0, 1), 3, dither=0.5) + 1
    cv.a[wet] = P.ramp("damp", inner[wet])
    cv.paint(outline(wet), P("damp", 1))  # tide line
    for (x, y) in jitter_points(W, W, 4, rng, prob=0.35):  # mildew
        if f[y % W, x % W] < 0.3:
            cv.set(x, y, P("stain", 2))
            if rng.random() < 0.5:
                cv.set(x + 1, y, P("stain", 3))
    for (x, y) in jitter_points(W, W, 16, rng, prob=0.5):  # paint blisters
        if f[y % W, x % W] < 0.5:
            cv.rect(x, y, 2, 2, P("drywall", 5))
            cv.rect(x, y + 2, 2, 1, P("damp", 0))
    return cv


def residue_strange():
    rng = rng_for("residue_strange")
    W = 64
    cv = Canvas(W, W, P("residue", 2), alpha=True)
    smear = blob_mask(W, W, 32, 12, 14, rng, rough=0.4)
    Y, X = np.mgrid[0:W, 0:W]
    smear &= (Y < 22)
    cv.paint(smear, P("residue", 2), 150)
    cv.paint(smear & (vnoise(W, W, 8, rng) > 0.55), P("residue", 3), 175)
    for _ in range(6):
        x = int(rng.integers(20, 44))
        L = int(rng.integers(16, 38))
        w = int(rng.integers(2, 4))
        for k in range(L):
            ww = max(1, w - k // 14)
            for i in range(ww):
                lv = 3 if i == 0 else (1 if i == ww - 1 else 2)
                cv.set(x + i, 14 + k, P("residue", lv), 200)
        by = 14 + L
        cv.rect(x - 1, by, 3, 3, P("residue", 2), 215)
        cv.set(x - 1, by, P("residue", 4), 230)
        cv.set(x + 1, by + 2, P("residue", 0), 220)
    _clear_border(cv)
    return cv


def foliage_dead():
    rng = rng_for("foliage_dead")
    W = 64
    cv = Canvas(W, W, P("bark", 1), alpha=True)
    tips = []

    def branch(x, y, ang, length, thick, depth):
        x1, y1 = x + math.cos(ang) * length, y + math.sin(ang) * length
        for (px, py) in bresenham(x, y, x1, y1):
            for t in range(thick):
                cv.set(px + t, py, P("bark", 1 if t else 3), 255)
        if depth >= 4 or length < 4:
            tips.append((x1, y1))
            return
        for s in (-1, 1):
            branch(x1, y1, ang + s * rng.uniform(0.3, 0.8), length * rng.uniform(0.55, 0.75),
                   max(1, thick - 1), depth + 1)
        if rng.random() < 0.4:
            tips.append((x1, y1))

    branch(32, 62, -math.pi / 2 + rng.normal(0, 0.1), 20, 3, 0)
    branch(30, 62, -math.pi / 2 - 0.5, 14, 2, 1)
    branch(34, 62, -math.pi / 2 + 0.5, 14, 2, 1)
    for (x, y) in tips:
        for _ in range(int(rng.integers(2, 4))):
            r = "dead" if rng.random() < 0.5 else "leaf_brown"
            leaf_sprite(cv, x + rng.integers(-3, 4), y + rng.integers(0, 5), rng.uniform(5, 8),
                        rng.uniform(3, 4.5), math.pi / 2 + rng.normal(0, 0.6), r, 2)
    # leaf_sprite does not set alpha: make every painted pixel opaque
    painted = cv.a != P("bark", 1)
    cv.alpha[painted] = 255
    _clear_border(cv)
    return cv


def warning_sign_weathered():
    rng = rng_for("warning_sign_weathered")
    W = 64
    cv = Canvas(W, W, P("sign_yellow", 3), alpha=True)
    cv.alpha[:, :] = 255
    f = vnoise(W, W, 16, rng, octaves=2)
    q = despeckle(quant(f, 3, dither=0.5), 2)
    cv.a = P.ramp("sign_yellow", q + 2)
    # rounded corners
    for (cx, cy) in ((0, 0), (W - 1, 0), (0, W - 1), (W - 1, W - 1)):
        for j in range(4):
            for i in range(4 - j):
                x = cx + (i if cx == 0 else -i)
                y = cy + (j if cy == 0 else -j)
                cv.alpha[y, x] = 0
    # border
    for k in (3, 4):
        cv.rect(k, k, W - 2 * k, 1, P("ink", 1))
        cv.rect(k, W - 1 - k, W - 2 * k, 1, P("ink", 1))
        cv.rect(k, k, 1, W - 2 * k, P("ink", 1))
        cv.rect(W - 1 - k, k, 1, W - 2 * k, P("ink", 1))
    cv.sprite(20, 9, EXCLAIM_TRIANGLE, {"k": P("ink", 1), "y": P("sign_yellow", 4)})
    # unreadable lettering bars
    for row_y in (32, 38, 45):
        widths = partition(40, 3, 7, rng)
        x = 12
        for w in widths:
            if rng.random() < 0.85:
                cv.rect(x, row_y, w - 1, 3 if row_y < 44 else 2, P("ink", 1))
            x += w
    # bolt holes
    for by in (6, 56):
        cv.rect(31, by, 2, 2, P("ink", 0), 0)
        cv.paint(blob_mask(W, W, 32, by + 1, 3.2, rng, rough=0.3) & (cv.alpha > 0), P("rust", 2))
        cv.rect(31, by, 2, 2, P("ink", 0), 0)
    # weathering: fading, rust blooms, scratches, a dent
    cv.shift(f > 0.72, 1)
    rust = (vnoise(W, W, 8, rng, octaves=2) > 0.77) & (cv.alpha > 0)
    cv.a[rust] = P.ramp("rust", quant(f, 3)[rust] + 1)
    for (x, y) in jitter_points(W, W, 14, rng, prob=0.5):
        for i in range(int(rng.integers(3, 7))):
            if cv.alpha[y % W, (x + i) % W]:
                cv.set(x + i, y + i // 3, P("metal", 4))
    cv.set(46, 50, P("sign_yellow", 0))
    cv.set(47, 51, P("sign_yellow", 4))
    return cv


def ground_mist_corrupted():
    rng = rng_for("ground_mist_corrupted")
    W = 128
    cv = Canvas(W, W, 0)
    bare = vnoise(W, W, 32, rng, octaves=2)
    cv.a = P.ramp("ash", despeckle(quant(bare, 2, dither=0.5)) + 1)
    lvl = quant(vnoise(W, W, 16, rng, octaves=2), 3) + 1
    blades(cv, rng, "ash", 3, 2, 4, lvl, lean=0.4, alt_ramp="dead",
           alt_field=vnoise(W, W, 16, rng), alt_thresh=0.6)
    patch = bare < 0.25
    cv.a[patch] = P.ramp("ash", quant(vnoise(W, W, 8, rng), 2)[patch] + 3)
    veins = np.zeros((W, W), bool)
    for _ in range(4):
        veins |= crack_mask(W, W, rng, rng.integers(0, W), rng.integers(0, W), 70, wiggle=0.3, branch=0.08)
    halo = outline(veins) & (vnoise(W, W, 4, rng) > 0.45)
    cv.paint(halo, P("corrupt", 3))
    cv.paint(veins, P("corrupt", 1))
    for (x, y) in jitter_points(W, W, 9, rng, prob=0.3):  # cold dew
        cv.set(x, y, P("glass", 4))
    return cv


def wood_darkened():
    rng = rng_for("wood_darkened")
    W = 128
    cv = Canvas(W, W, P("ink", 0))
    y = 0
    for bh in (16, 16, 16, 16, 16, 16, 16, 16):
        x = int(rng.integers(0, W))
        for sl in partition(W, 40, 90, rng):
            wood_board(cv, x, y + 1, sl - 1, bh - 1, "wood_charred", int(rng.choice([2, 3])), rng,
                       spacing=2.8, knots=int(rng.random() < 0.3), amp=2.5, contrast=1)
            cv.rect(x + sl - 1, y, 1, bh, P("ink", 0))
            x += sl
        cv.rect(0, y, W, 1, P("ink", 0))
        y += bh
    rot = vnoise(W, W, 16, rng, octaves=2)
    r = relief(vnoise(W, W, 4, rng, cell_y=8), 0.2)
    cv.shift((rot > 0.6) & (r != 0), r)
    for (x, y) in jitter_points(W, W, 8, rng, prob=0.4):  # damp sheen
        if y % 16 > 2:
            for i in range(int(rng.integers(2, 5))):
                cv.set(x + i, y, P("wood_charred", 4))
    for (x, y) in jitter_points(W, W, 24, rng, prob=0.4):  # fungal spots
        cv.set(x, y, P("residue", 2))
        cv.set(x + 1, y, P("residue", 1))
    return cv


def grime_abandoned():
    rng = rng_for("grime_abandoned")
    W = 128
    cv = Canvas(W, W, P("soil", 1), alpha=True)
    blot = vnoise(W, W, 32, rng, octaves=3)
    streak = vnoise(W, W, 4, rng, octaves=2, cell_y=64)
    a = np.zeros((W, W))
    a += np.where(blot < 0.38, 1, 0) + np.where(blot < 0.28, 1, 0)
    a += np.where(streak < 0.3, 1, 0)
    lv = np.clip(a, 0, 3).astype(int)
    steps = np.array([0, 70, 120, 170], np.uint8)
    cv.alpha[:, :] = steps[lv]
    tone = quant(vnoise(W, W, 8, rng, octaves=2), 2, dither=0.5)
    cv.a = np.where(lv == 3, P.ramp("mud", tone), np.where(lv == 2, P.ramp("mud", tone + 1),
                    P.ramp("soil", tone + 2)))
    for (x, y) in jitter_points(W, W, 6, rng, prob=0.35):  # splatter specks
        cv.set(x, y, P("mud", 0), 200)
    return cv
