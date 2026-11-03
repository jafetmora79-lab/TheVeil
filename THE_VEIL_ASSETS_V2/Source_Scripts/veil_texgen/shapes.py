"""Reusable pixel-art construction routines (boards, bricks, shingles,
blades, leaves, stones). Each routine draws explicit, recognisable shapes
onto a wrapping Canvas."""
import math

import numpy as np

from .core import (P, Canvas, vnoise, quant, despeckle, voronoi, periodic_wobble,
                   partition, jitter_points, bresenham, wrap_delta)


# ----------------------------------------------------------------------------
# Wood
# ----------------------------------------------------------------------------
def wood_board(cv, x0, y0, bw, bh, ramp, base, rng, spacing=3.5, knots=0,
               amp=2.0, dash=0.35, contrast=1, highlight=True):
    """Fill a horizontal board with flowing grain lines and optional knots.
    Grain wobble is periodic over the canvas width so boards that wrap
    across the tile edge stay continuous."""
    W = cv.w
    wob = periodic_wobble(W, rng, amp=amp, k=(1, 2, 4))
    phase = rng.random() * spacing
    xs = (np.arange(x0, x0 + bw)) % W
    vs = np.arange(bh)
    U, V = np.meshgrid(xs, vs)
    off = wob[U] + phase
    knot_cores = []
    for _ in range(knots):
        ku = x0 + rng.uniform(4, max(5, bw - 4))
        kv = rng.uniform(bh * 0.3, bh * 0.7)
        du = wrap_delta(U.astype(float), ku, W)
        dv = V - kv
        off = off + 2.6 * np.exp(-(du * du / 18.0 + dv * dv / 5.0)) * np.sign(dv + 1e-3)
        knot_cores.append((ku, kv))
    t = (V + off) / spacing
    g = t % 1.0
    line_id = np.floor(t).astype(int) % 97
    strong = rng.random(97) < 0.35
    lit = rng.random(97) < 0.3
    dn = vnoise(W, max(4, cv.h), 8, rng, octaves=1)[(y0 + V) % cv.h, U]
    lvl = np.full(U.shape, base)
    lvl = np.where((g < 0.28) & (dn > dash), base - contrast, lvl)
    lvl = np.where((g < 0.28) & strong[line_id], base - contrast, lvl)
    if highlight:
        lvl = np.where((g > 0.55) & (g < 0.72) & lit[line_id] & (dn > 0.45), base + 1, lvl)
    ys = (y0 + vs) % cv.h
    cv.a[np.ix_(ys, xs)] = P.ramp(ramp, lvl)
    for ku, kv in knot_cores:
        for j in range(-2, 3):
            for i in range(-3, 4):
                e = (i * i) / 7.0 + (j * j) / 2.2
                y = y0 + int(round(kv)) + j
                if not (y0 <= y < y0 + bh):
                    continue
                if e <= 0.6:
                    cv.set(ku + i, y, P(ramp, base - 2))
                elif e <= 1.3:
                    cv.set(ku + i, y, P(ramp, base - 1))


# ----------------------------------------------------------------------------
# Masonry
# ----------------------------------------------------------------------------
def brickwork(W, H, rng, brick, mortar, course=8, wlo=18, whi=24, weather=0.0,
              clinker=0.08, uniform=None, mortar_lvl=2, base_levels=(1, 2, 2, 2, 3)):
    cv = Canvas(W, H, P(mortar, mortar_lvl))
    grime = vnoise(W, H, 32, rng, octaves=2)
    speck = quant(vnoise(W, H, 4, rng, octaves=1), 3)
    prev = []
    for c in range(H // course):
        y0 = c * course
        widths = list(uniform) if uniform is not None else partition(W, wlo, whi, rng)
        if uniform is not None:
            offset = (c % 2) * (widths[0] // 2)
        else:
            best, offset = -1, 0
            for _ in range(24):
                o = int(rng.integers(0, W))
                joints = np.cumsum([0] + widths[:-1]) + o
                if prev:
                    dmin = min(abs(wrap_delta(j, p, W)) for j in joints for p in prev)
                else:
                    dmin = 99
                if dmin > best:
                    best, offset = dmin, o
        joints = list((np.cumsum([0] + widths[:-1]) + offset) % W)
        prev = joints
        x = offset
        for bw in widths:
            base = int(rng.choice(base_levels))
            if rng.random() < clinker:
                base = 0
            bh = course - 1
            for j in range(bh):
                for i in range(bw - 1):
                    gx, gy = (x + i) % W, (y0 + j) % H
                    lv = base + (speck[gy, gx] - 1 if speck[gy, gx] == 0 else 0)
                    if grime[gy, gx] < 0.3:
                        lv -= 1
                    if j == 0:
                        lv += 1
                    elif j == bh - 1:
                        lv -= 1
                    cv.a[gy, gx] = P(brick, lv)
            # mortar under the brick sits in its shadow
            for i in range(bw):
                cv.set(x + i, y0 + course - 1, P(mortar, mortar_lvl - 1))
            cv.set(x + bw - 1, y0 + course - 1, P(mortar, mortar_lvl - 1))
            # weathering: chipped corners and spalls
            if weather > 0:
                if rng.random() < weather:
                    cx = x + (0 if rng.random() < 0.5 else bw - 2)
                    cy = y0 + (0 if rng.random() < 0.5 else bh - 1)
                    cv.set(cx, cy, P(mortar, mortar_lvl - 2))
                    cv.set(cx + 1, cy, P(mortar, mortar_lvl - 2))
                if rng.random() < weather * 0.6:
                    sx = x + int(rng.integers(2, max(3, bw - 4)))
                    sy = y0 + int(rng.integers(1, max(2, bh - 2)))
                    for (i, j) in [(0, 0), (1, 0), (0, 1), (2, 0), (1, 1)][: int(rng.integers(2, 6))]:
                        cv.set(sx + i, sy + j, P(brick, 0))
                    cv.set(sx, sy + 2, P(brick, base + 1))
            x += bw
    if weather > 0:
        er = (vnoise(W, H, 8, rng) > 0.72)
        m = er & np.isin(cv.a, [P(mortar, k) for k in range(P.size[mortar])])
        cv.a[m] = P("ink", 2)
    return cv


# ----------------------------------------------------------------------------
# Roofs
# ----------------------------------------------------------------------------
def shingles(W, H, rng, ramp, course=16, tab=32, dimensional=False):
    cv = Canvas(W, H, P(ramp, 2))
    grain = quant(vnoise(W, H, 4, rng, octaves=2), 3, dither=0.5) - 1
    for c in range(H // course):
        y0 = c * course
        if dimensional:
            widths = partition(W, 10, 26, rng)
            offset = int(rng.integers(0, W))
        else:
            widths = [tab] * (W // tab)
            offset = (c % 2) * (tab // 2) + int(rng.integers(-2, 3))
        x = offset
        for tw in widths:
            base = int(rng.choice([2, 2, 3, 3, 1, 4] if dimensional else [2, 3, 3, 2, 3]))
            two_tone = dimensional and rng.random() < 0.45
            for j in range(course):
                for i in range(tw):
                    gx, gy = (x + i) % W, (y0 + j) % H
                    lv = base + grain[gy, gx]
                    if two_tone and j > course * 0.55:
                        lv -= 1
                    if j == 0:
                        lv = 0
                    elif j == 1:
                        lv = min(lv, 1)
                    elif j == course - 1:
                        lv += 1
                    cv.a[gy, gx] = P(ramp, lv)
            # slot between tabs
            sw = 1 if dimensional else 2
            for j in range(course):
                for s in range(sw):
                    cv.set(x + s, y0 + j, P(ramp, 0))
                cv.set(x + sw, y0 + j, P(ramp, base + 1))
            x += tw
    # deliberate granule sparkle on a jittered grid (not static noise)
    for (px, py) in jitter_points(W, H, 5, rng, prob=0.35):
        if (py % course) > 2:
            cv.shift_px(px, py, 2)
    return cv


# ----------------------------------------------------------------------------
# Vegetation
# ----------------------------------------------------------------------------
def blades(cv, rng, ramp, step, lmin, lmax, lvl_field, lean=0.5, curve=0.0,
           alt_ramp=None, alt_field=None, alt_thresh=1.1):
    """Draw grass blades on a jittered grid, back-to-front (top to bottom)."""
    pts = jitter_points(cv.w, cv.h, step, rng, prob=1.0, jitter=1.0)
    pts.sort(key=lambda p: p[1])
    n = P.size[ramp]
    for (x, y) in pts:
        r = ramp
        if alt_ramp is not None and alt_field[y % cv.h, x % cv.w] > alt_thresh:
            r = alt_ramp
        base = int(lvl_field[y % cv.h, x % cv.w])
        L = int(rng.integers(lmin, lmax + 1))
        dx = rng.normal(0, lean)
        bend = rng.normal(0, curve)
        fx = float(x)
        for k in range(L):
            yy = y - k
            lv = base - 1 if k == 0 else (base + 1 if k >= L - 1 else base)
            cv.set(round(fx), yy, P(r, min(n - 1, lv)))
            fx += dx + bend * k


def leaf_sprite(cv, x, y, length, width, angle, ramp, base, shadow=None):
    """Pointed leaf with midrib and a lit side."""
    ca, sa = math.cos(angle), math.sin(angle)
    R = int(length) + 2
    pix = []
    for j in range(-R, R + 1):
        for i in range(-R, R + 1):
            u = (i * ca + j * sa) / (length / 2.0)
            v = (-i * sa + j * ca) / (width / 2.0)
            if abs(u) <= 1 and abs(v) <= (1 - u * u) ** 0.7:
                pix.append((i, j, u, v))
    if shadow is not None:
        for i, j, u, v in pix:
            cv.set(x + i + 1, y + j + 1, shadow)
    for i, j, u, v in pix:
        lv = base + (1 if v < -0.35 else 0)
        if abs(v) < 0.22 and abs(u) < 0.8:
            lv = base - 1
        cv.set(x + i, y + j, P(ramp, lv))
    # stem
    sx, sy = x - ca * (length / 2 + 1), y - sa * (length / 2 + 1)
    cv.set(round(sx), round(sy), P(ramp, base - 1))


def stones(cv, rng, cell, ramps, gap_color, levels=(1, 2, 3), gap=0.12, cell_y=None, mask=None):
    """Voronoi stones lit from the top-left with dark gaps."""
    cid, d1, d2, vx, vy = voronoi(cv.w, cv.h, cell, rng, jitter=0.9, cell_y=cell_y)
    ncell = cid.max() + 1
    rsel = rng.integers(0, len(ramps), ncell)
    base = rng.choice(levels, ncell)
    shade = np.where(vx + vy < -0.25, 1, np.where(vx + vy > 0.3, -1, 0))
    out = np.zeros(cid.shape, np.int64)
    for k, r in enumerate(ramps):
        m = rsel[cid] == k
        out[m] = P.ramp(r, base[cid][m] + shade[m])
    gapm = (d2 - d1) < gap
    out[gapm] = gap_color
    if mask is None:
        cv.a[:, :] = out
    else:
        cv.a[mask] = out[mask]
    return cid, gapm
