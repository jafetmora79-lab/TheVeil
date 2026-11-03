"""F. Commercial buildings."""
import math

import numpy as np

from .core import (P, Canvas, rng_for, vnoise, quant, despeckle, jitter_points, blob_mask,
                   relief, crack_mask, apply_crack, outline, bresenham)
from .shapes import brickwork


def supermarket_floor_tiles():
    rng = rng_for("supermarket_floor_tiles")
    W, T = 128, 32
    cv = Canvas(W, W, 0)
    for ty in range(W // T):
        for tx in range(W // T):
            base = 4 if (tx + ty) % 2 == 0 else 3
            f = quant(vnoise(T, T, 8, rng), 2, dither=0.4)
            cv.a[ty * T:(ty + 1) * T, tx * T:(tx + 1) * T] = P.ramp("tile_cream", base + f - 1)
            # VCT chips: short contrasting flecks on a jittered grid
            for (x, y) in jitter_points(T, T, 4, rng, prob=0.6):
                d = int(rng.choice([-2, -1, 1]))
                cv.shift_px(tx * T + x, ty * T + y, d)
                cv.shift_px(tx * T + x + 1, ty * T + y, d)
    cv.shift((np.arange(W) % T == 0)[None, :].repeat(W, 0), -2)
    cv.shift((np.arange(W) % T == 0)[:, None].repeat(W, 1), -2)
    for (x, y) in jitter_points(W, W, 32, rng, prob=0.6):  # scuffs
        a0 = rng.random() * 6.28
        for k in range(int(rng.integers(4, 9))):
            cv.set(x + math.cos(a0) * k, y + math.sin(a0) * k * 0.4, P("rubber", 4))
    shine = vnoise(W, W, 32, rng, octaves=2) > 0.7
    cv.shift(shine, 1)
    return cv


def storefront_brick():
    rng = rng_for("storefront_brick")
    return brickwork(128, 128, rng, "brick_buff", "mortar", course=8, uniform=[21, 21, 22, 21, 21, 22],
                     weather=0.04, clinker=0.0, mortar_lvl=1, base_levels=(2, 2, 3))


def storefront_concrete():
    rng = rng_for("storefront_concrete")
    W = 128
    cv = Canvas(W, W, 0)
    cv.a = P.ramp("concrete", despeckle(quant(vnoise(W, W, 32, rng, octaves=2), 2, dither=0.6), 2) + 4)
    r = relief(vnoise(W, W, 4, rng), 0.3)
    cv.shift(r != 0, r)
    # reveal joints
    # reveal joints sit mid-tile (x=64, y=64) so panel edges never land on the UV wrap
    cv.rect(0, 64, W, 2, P("concrete", 1))
    cv.rect(64, 0, 2, W, P("concrete", 1))
    cv.rect(0, 66, W, 1, P("concrete", 6))
    cv.rect(66, 0, 1, W, P("concrete", 6))
    # drip stains below the horizontal reveal
    for x in range(3, W, 2):
        if rng.random() < 0.45:
            L = int(rng.integers(6, 40))
            for k in range(L):
                if k < L * 0.7 or k % 2 == 0:
                    cv.shift_px(x, 67 + k, -1)
    for (bx, by) in ((80, 80), (48, 80), (80, 48), (48, 48)):
        cv.rect(bx - 1, by - 1, 3, 3, P("concrete", 3))
        cv.set(bx - 1, by - 1, P("concrete", 5))
        cv.set(bx + 1, by + 1, P("concrete", 2))
    return cv


def ceiling_tiles():
    rng = rng_for("ceiling_tiles")
    W, T = 128, 64
    cv = Canvas(W, W, P("ceiling", 3))
    for ty in range(2):
        for tx in range(2):
            b = int(rng.choice([3, 3, 2]))
            cv.rect(tx * T, ty * T, T, T, P("ceiling", b))
    # fissured acoustic pattern
    for (x, y) in jitter_points(W, W, 4, rng, prob=0.7):
        ang = rng.random() * 6.28
        for k in range(int(rng.integers(2, 5))):
            ang += rng.normal(0, 0.8)
            cv.shift_px(x + math.cos(ang) * k, y + math.sin(ang) * k, -1)
    for (x, y) in jitter_points(W, W, 3, rng, prob=0.3):
        cv.shift_px(x, y, -2)
    # recessed edge shadow + T-bar grid
    for k in (0, T):
        cv.shift_rect(k + 2, 0, 1, W, -1)
        cv.shift_rect(0, k + 2, W, 1, -1)
        cv.rect(k, 0, 2, W, P("paint_white", 3))
        cv.rect(0, k, W, 2, P("paint_white", 3))
        cv.rect(k, 0, 1, W, P("paint_white", 4))
        cv.rect(0, k, W, 1, P("paint_white", 4))
    return cv


def metal_shelving():
    rng = rng_for("metal_shelving")
    W = 64
    cv = Canvas(W, W, 0)
    cv.a = P.ramp("shelf_paint", despeckle(quant(vnoise(W, W, 16, rng, octaves=2), 2, dither=0.5)) + 2)
    for y in range(4, W, 8):
        for x in range(4, W, 8):
            cv.rect(x, y, 2, 2, P("ink", 1))
            cv.set(x + 2, y + 1, P("shelf_paint", 4))
            cv.set(x + 1, y + 2, P("shelf_paint", 4))
            cv.set(x - 1, y, P("shelf_paint", 1))
    for (x, y) in jitter_points(W, W, 12, rng, prob=0.6):
        for i in range(int(rng.integers(3, 9))):
            cv.set(x + i, y, P("metal", 2))
    return cv


def metal_door_painted():
    rng = rng_for("metal_door_painted")
    W, H = 64, 128
    cv = Canvas(W, H, 0)
    cv.a = P.ramp("door_green", despeckle(quant(vnoise(W, H, 16, rng, octaves=2), 2, dither=0.5), 2) + 2)
    # outer bevel
    cv.rect(0, 0, W, 1, P("door_green", 4))
    cv.rect(0, 0, 1, H, P("door_green", 4))
    cv.rect(0, H - 1, W, 1, P("door_green", 0))
    cv.rect(W - 1, 0, 1, H, P("door_green", 0))
    # recessed panels: shadow top/left, light bottom/right
    for (x0, y0, x1, y1) in ((9, 10, 55, 56), (9, 70, 55, 116)):
        cv.shift_rect(x0, y0, x1 - x0, y1 - y0, -1)
        cv.rect(x0, y0, x1 - x0, 1, P("door_green", 0))
        cv.rect(x0, y0, 1, y1 - y0, P("door_green", 0))
        cv.rect(x0, y1 - 1, x1 - x0, 1, P("door_green", 4))
        cv.rect(x1 - 1, y0, 1, y1 - y0, P("door_green", 4))
        cv.rect(x0 - 2, y0 - 2, x1 - x0 + 4, 1, P("door_green", 3))
    # hand-worn zone at the latch
    hz = blob_mask(W, H, 54, 63, 5, rng, rough=0.4)
    cv.shift(hz, 1)
    cv.paint(blob_mask(W, H, 54, 63, 3, rng, rough=0.3), P("metal", 2))
    # kick scuffs
    for (x, y) in jitter_points(W, 14, 5, rng, prob=0.7):
        col = P("rubber", 2) if rng.random() < 0.5 else P("metal", 3)
        for i in range(int(rng.integers(2, 7))):
            cv.set(x + i, 112 + y, col)
    # rust creeping up from the bottom edge
    rn = vnoise(W, H, 8, rng, octaves=2)
    Y = np.mgrid[0:H, 0:W][0]
    rust = (H - 1 - Y) < (2 + rn * 7)
    cv.a[rust] = P.ramp("rust", quant(rn, 3)[rust] + 1)
    cv.paint(outline(rust) & ~rust & (Y > H // 2), P("rust", 0))
    return cv


def gas_station_pavement():
    rng = rng_for("gas_station_pavement")
    W = 256
    cv = Canvas(W, W, 0)
    f = vnoise(W, W, 64, rng, octaves=3)
    cv.a = P.ramp("concrete", despeckle(quant(f, 3, dither=0.5), 2) + 2)
    r = relief(vnoise(W, W, 4, rng), 0.3)
    cv.shift(r != 0, r)
    for k in (0, 128):  # sealed joints
        cv.rect(k, 0, 2, W, P("tar", 1))
        cv.rect(0, k, W, 2, P("tar", 1))
        cv.rect(k + 2, 0, 1, W, P("concrete", 5))
        cv.rect(0, k + 2, W, 1, P("concrete", 5))
    for _ in range(6):  # oil stains
        cx, cy, rr = rng.integers(0, W), rng.integers(0, W), rng.uniform(9, 18)
        for s, d in ((1.0, -1), (0.65, -1), (0.35, -1)):
            cv.shift(blob_mask(W, W, cx, cy, rr * s, rng, rough=0.45), d)
    for _ in range(3):  # tyre marks
        cx, cy, rr = rng.integers(0, W), rng.integers(0, W), rng.uniform(40, 90)
        a0 = rng.random() * 6.28
        for k in range(int(rr)):
            a = a0 + k / rr
            for o in (0, 5):
                cv.set(cx + math.cos(a) * (rr + o), cy + math.sin(a) * (rr + o), P("concrete", 1))
    return cv


def signage_backing():
    rng = rng_for("signage_backing")
    W = 64
    cv = Canvas(W, W, 0)
    cv.a = P.ramp("sign_backing", despeckle(quant(vnoise(W, W, 16, rng, octaves=2), 3, dither=0.6), 2) + 1)
    chalk = vnoise(W, W, 8, rng, octaves=2) > 0.68
    cv.shift(chalk, 1)
    cv.rect(0, 31, W, 1, P("sign_backing", 0))
    cv.rect(0, 32, W, 1, P("sign_backing", 4))
    for x in range(4, W, 8):
        for y in (28, 35):
            cv.set(x, y, P("metal", 5))
            cv.set(x + 1, y + 1, P("metal", 1))
            if rng.random() < 0.35:
                for k in range(2, int(rng.integers(4, 9))):
                    cv.set(x, y + k, P("rust", 2))
    for (x, y) in jitter_points(W, W, 16, rng, prob=0.6):
        for i in range(int(rng.integers(3, 8))):
            cv.set(x + i, y + i // 2, P("metal", 4))
    return cv


def storage_concrete():
    """Painted concrete-block (CMU) wall."""
    rng = rng_for("storage_concrete")
    W = 128
    cv = Canvas(W, W, P("mortar", 2))
    tone = vnoise(W, W, 32, rng, octaves=2)
    for row in range(W // 16):
        off = 16 * (row % 2)
        for col in range(W // 32):
            x0, y0 = col * 32 + off, row * 16
            b = int(rng.choice([4, 4, 5, 3]))
            cv.rect(x0, y0, 31, 15, P("concrete", b))
            cv.rect(x0, y0, 31, 1, P("concrete", b + 1))
            cv.rect(x0, y0 + 14, 31, 1, P("concrete", b - 1))
            cv.rect(x0 + 31, y0, 1, 16, P("mortar", 1))
            cv.rect(x0, y0 + 15, 32, 1, P("mortar", 1))
    cv.shift(tone < 0.3, -1)
    for (x, y) in jitter_points(W, W, 3, rng, prob=0.4):  # block pores
        if (y % 16) not in (0, 14, 15):
            cv.shift_px(x, y, -2)
    return cv


def industrial_wall_dirty():
    """Corrugated metal cladding with grime and rust streaks."""
    rng = rng_for("industrial_wall_dirty")
    W = 128
    prof = [1, 1, 2, 3, 4, 4, 3, 3, 2, 2, 2, 1, 1, 0, 0, 1]
    cv = Canvas(W, W, 0)
    cv.a = P.ramp("metal", np.array([prof[x % 16] for x in range(W)])[None, :].repeat(W, 0))
    streak = vnoise(W, W, 4, rng, octaves=2, cell_y=64)
    cv.shift(streak < 0.32, -1)
    cv.shift(streak < 0.2, -1)
    rs = (streak > 0.78)
    cv.a[rs] = P.ramp("rust", P.level(cv.a[rs]) + 1)
    cv.rect(0, 64, W, 1, P("ink", 1))  # end lap seam (mid-tile, off the UV wrap)
    cv.rect(0, 65, W, 1, P("metal", 5))
    for x in range(4, W, 16):
        cv.set(x, 68, P("metal", 5))
        cv.set(x + 1, 69, P("ink", 1))
        for k in range(70, 70 + int(rng.integers(2, 14))):
            cv.set(x, k, P("rust", 2))
    grime = vnoise(W, W, 32, rng, octaves=2) < 0.3
    cv.shift(grime, -1)
    return cv
