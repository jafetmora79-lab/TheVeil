"""A. Exterior house materials."""
import numpy as np

from .core import (tri, P, Canvas, rng_for, vnoise, quant, despeckle, crack_mask, apply_crack,
                   jitter_points, partition, wrap_delta, relief, bresenham)
from .shapes import wood_board, brickwork, shingles


def _siding(name, ramp):
    rng = rng_for(name)
    W = H = 128
    board = 16
    cv = Canvas(W, H, P(ramp, 3))
    fade = vnoise(W, H, 32, rng, octaves=2)
    fade_q = tri(fade, 0.25, 0.8, dither=0.6)
    profile = [0, 1, 2, 2, 2, 3, 3, 3, 3, 3, 3, 3, 3, 4, 4, 1]
    prev_j = []
    for b in range(H // board):
        y0 = b * board
        for r, lv in enumerate(profile):
            row = np.full(W, lv)
            if 2 <= r <= 12:
                row = row - (fade_q[y0 + r] == 0)
                row = row + ((fade_q[y0 + r] == 2) & (r >= 5))
            cv.a[y0 + r] = P.ramp(ramp, row)
        # faint raised grain under the paint
        for _ in range(int(rng.integers(3, 6))):
            gx, gy = int(rng.integers(0, W)), y0 + int(rng.integers(4, 12))
            for i in range(int(rng.integers(6, 26))):
                cv.shift_px(gx + i, gy, -1)
        # butt joints, staggered away from the board above
        for _ in range(int(rng.integers(0, 2)) + (1 if rng.random() < 0.6 else 0)):
            for _try in range(10):
                jx = int(rng.integers(0, W))
                if all(abs(wrap_delta(jx, p, W)) > 12 for p in prev_j):
                    break
            prev_j = [jx]
            for r in range(board):
                cv.set(jx, y0 + r, P(ramp, 0 if r < 2 else 1))
                if 2 <= r <= 14:
                    cv.shift_px(jx + 1, y0 + r, 1)
            cv.set(jx - 2, y0 + 11, P("ink", 1))
            cv.set(jx + 3, y0 + 11, P("ink", 1))
    # paint chips revealing grey wood, mostly in the faded patches
    for (x, y) in jitter_points(W, H, 9, rng, prob=0.22):
        r = y % board
        if 3 <= r <= 12 and fade[y, x] < 0.55:
            shape = [(0, 0), (1, 0), (0, 1), (2, 0), (1, 1), (-1, 0)][: int(rng.integers(2, 6))]
            for i, j in shape:
                cv.set(x + i, y + j, P("wood_gray", 2))
            cv.set(x, y - 1, P(ramp, 1))
    return cv


def siding_white():
    return _siding("siding_white", "paint_white")


def siding_blue():
    return _siding("siding_blue", "paint_blue")


def siding_green():
    return _siding("siding_green", "paint_green")


def wood_planks_aged():
    rng = rng_for("wood_planks_aged")
    W = H = 128
    cv = Canvas(W, H, P("ink", 1))
    heights = [14, 18, 16, 16, 14, 18, 16, 16]
    rng.shuffle(heights)
    y = 0
    for bh in heights:
        segs = partition(W, 36, 92, rng)
        x = int(rng.integers(0, W))
        for sl in segs:
            base = int(rng.choice([1, 2, 2, 3]))
            wood_board(cv, x, y + 1, sl - 1, bh - 1, "wood_gray", base, rng,
                       spacing=3.2, knots=int(rng.integers(0, 2)), amp=2.5)
            # board edges
            cv.shift_rect(x, y + 1, sl - 1, 1, 1)
            cv.shift_rect(x, y + bh - 1, sl - 1, 1, -1)
            # end gap + nails
            cv.rect(x + sl - 1, y, 1, bh, P("ink", 0))
            for nx in (x + 2, x + sl - 4):
                cv.set(nx, y + 3, P("rust", 1))
                cv.set(nx, y + bh - 4, P("rust", 1))
                cv.set(nx + 1, y + 4, P("wood_gray", base + 1))
            # occasional split along the grain
            if rng.random() < 0.35:
                sx, sy = x + int(rng.integers(3, max(4, sl - 20))), y + int(rng.integers(4, bh - 3))
                for i in range(int(rng.integers(8, 18))):
                    cv.set(sx + i, sy + (1 if i > 9 else 0), P("ink", 0))
            x += sl
        cv.rect(0, y, W, 1, P("ink", 0))
        y += bh
    return cv


def brick_red():
    rng = rng_for("brick_red")
    return brickwork(128, 128, rng, "brick_red", "mortar", course=8, wlo=18, whi=24,
                     weather=0.12, clinker=0.07, mortar_lvl=3)


def brick_weathered_brown():
    rng = rng_for("brick_weathered_brown")
    cv = brickwork(128, 128, rng, "brick_brown", "mortar", course=8, wlo=17, whi=25,
                   weather=0.45, clinker=0.1, mortar_lvl=2)
    # efflorescence bloom in a few mortar-rich areas
    salt = vnoise(128, 128, 16, rng, octaves=2) > 0.74
    m = salt & np.isin(cv.a, [P("mortar", k) for k in range(5)])
    cv.a[m] = P("mortar", 4)
    return cv


def concrete_foundation():
    rng = rng_for("concrete_foundation")
    W = H = 128
    f = vnoise(W, H, 32, rng, octaves=3)
    cv = Canvas(W, H, 0)
    cv.a = P.ramp("concrete", despeckle(quant(f, 3, dither=0.5), 2) + 2)
    rel = relief(vnoise(W, H, 4, rng, octaves=1), 0.22)
    cv.shift(rel != 0, rel)
    # board-form seams
    for sy in (0, 32, 64, 96):
        dn = vnoise(W, 8, 8, rng)[0]
        cv.shift_rect(0, sy, W, 1, -2)
        for x in range(W):
            if dn[x] > 0.4:
                cv.shift_px(x, sy + 1, 1)
    # form tie holes
    for ty in (16, 48, 80, 112):
        for tx in range(16 if (ty // 32) % 2 else 0, W, 32):
            cv.rect(tx, ty, 2, 2, P("ink", 1))
            cv.shift_px(tx + 2, ty + 1, 1)
            cv.shift_px(tx + 1, ty + 2, 1)
    # pits clustered in rougher areas
    for (x, y) in jitter_points(W, H, 6, rng, prob=0.4):
        if f[y % H, x % W] < 0.45:
            cv.set(x, y, P("concrete", 1))
            cv.shift_px(x + 1, y + 1, 1)
    for _ in range(2):
        m = crack_mask(W, H, rng, rng.integers(0, W), rng.integers(0, H), 40, wiggle=0.4, branch=0.05)
        apply_crack(cv, m, P("ink", 2))
    return cv


def roof_shingles_darkgray():
    return shingles(128, 128, rng_for("roof_shingles_darkgray"), "shingle_gray", course=16, tab=32)


def roof_shingles_brown():
    return shingles(128, 128, rng_for("roof_shingles_brown"), "shingle_brown", course=16,
                    dimensional=True)


def roof_tiles_weathered():
    rng = rng_for("roof_tiles_weathered")
    W = H = 128
    cv = Canvas(W, H, P("terracotta", 2))
    across = [0, 1, 2, 3, 3, 4, 4, 3, 3, 3, 2, 2, 2, 1, 1, 0]
    lich = vnoise(W, H, 16, rng, octaves=2)
    grime = vnoise(W, H, 32, rng, octaves=2)
    for cy in range(8):
        for cx in range(8):
            x0, y0 = cx * 16, cy * 16
            base = int(rng.choice([-1, 0, 0, 0, 1]))
            for j in range(16):
                for i in range(16):
                    lv = across[i] + base
                    if j == 0:
                        lv -= 2
                    elif j == 1:
                        lv -= 1
                    elif j == 13:
                        lv += 1
                    elif j >= 14:
                        lv -= 1
                    gx, gy = x0 + i, y0 + j
                    if grime[gy, gx] < 0.3 and j > 8:
                        lv -= 1
                    cv.a[gy, gx] = P("terracotta", lv)
            if rng.random() < 0.12:  # cracked tile
                m = crack_mask(W, H, rng, x0 + 8, y0 + 3, 10, angle=np.pi / 2, wiggle=0.5, branch=0.0)
                apply_crack(cv, m, P("ink", 1))
            if rng.random() < 0.15:  # chipped lip
                cv.rect(x0 + int(rng.integers(3, 11)), y0 + 14, 3, 2, P("ink", 1))
    # lichen colonies
    m = lich > 0.72
    lv = quant(np.clip((lich - 0.72) / 0.28, 0, 1), 4)
    cv.a[m] = P.ramp("lichen", lv[m])
    for (x, y) in jitter_points(W, H, 7, rng, prob=0.25):
        if lich[y % H, x % W] > 0.6:
            cv.set(x, y, P("lichen", 3))
    return cv


def trim_painted():
    rng = rng_for("trim_painted")
    W = H = 64
    cv = Canvas(W, H, P("paint_white", 3))
    f = despeckle(quant(vnoise(W, H, 16, rng, octaves=2), 3, dither=0.4), 2)
    cv.a = P.ramp("paint_white", f + 2)
    # long brush/grain streaks along U
    for (x, y) in jitter_points(W, H, 8, rng, prob=0.8):
        L = int(rng.integers(8, 28))
        d = -1 if rng.random() < 0.7 else 1
        for i in range(L):
            cv.shift_px(x + i, y, d)
    # dirt collecting in the paint and a few chips
    dirt = vnoise(W, H, 16, rng, octaves=2) < 0.25
    cv.shift(dirt, -1)
    for (x, y) in jitter_points(W, H, 16, rng, prob=0.5):
        for i, j in [(0, 0), (1, 0), (1, 1), (2, 1)][: int(rng.integers(2, 5))]:
            cv.set(x + i, y + j, P("wood_gray", 2))
        cv.set(x, y - 1, P("paint_white", 1))
    return cv


def window_glass_dirty():
    rng = rng_for("window_glass_dirty")
    W = H = 64
    cv = Canvas(W, H, P("glass", 2), alpha=True)
    cv.alpha[:, :] = 105
    tone = quant(vnoise(W, H, 16, rng, octaves=2), 2, dither=0.5)
    cv.a = P.ramp("glass", tone + 1)
    Y, X = np.mgrid[0:H, 0:W]
    # chunky reflection bands
    for off, wdt in ((10, 6), (24, 2), (40, 3)):
        band = np.abs((X + Y) - (W - off) - 20) < wdt / 2 + 0.5
        cv.paint(band, P("glass", 4))
        cv.alpha[band] = 140
    # grime creeping in from the frame edges (heavier at the bottom)
    edge = np.minimum.reduce([X, Y * 1.6, (W - 1 - X), (H - 1 - Y) * 0.55])
    n = vnoise(W, H, 8, rng, octaves=2)
    dirt = edge < 2 + n * 9
    heavy = edge < 1 + n * 4
    cv.paint(dirt, P("soil", 3))
    cv.alpha[dirt] = 175
    cv.paint(heavy, P("soil", 2))
    cv.alpha[heavy] = 215
    # rain drip streaks
    for _ in range(9):
        x = int(rng.integers(3, W - 3))
        y = int(rng.integers(0, 10))
        L = int(rng.integers(10, 40))
        for k in range(L):
            cv.set(x, y + k, P("soil", 4 if k % 7 else 3), 150)
        cv.set(x, y + L, P("soil", 2), 200)
    # dust specks
    for (x, y) in jitter_points(W, H, 6, rng, prob=0.35):
        cv.set(x, y, P("soil", 4), 190)
    return cv
