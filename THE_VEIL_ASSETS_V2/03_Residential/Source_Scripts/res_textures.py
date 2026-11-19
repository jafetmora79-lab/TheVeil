"""Pack 03 supplementary pixel textures (residential interiors & exteriors).

Only what Packs 01/02 cannot cover. Built with the Pack 01 toolkit, the
Greyhaven master palette, top-left lighting and 64 px/m density (the detail
atlas is the usual small-print exception, like Pack 02's sign atlas).
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "Source_Scripts"))
sys.path.insert(0, os.path.join(HERE, "..", "..", "02_Town", "Source_Scripts"))

import numpy as np  # noqa: E402

from veil_texgen.core import (P, Canvas, rng_for, vnoise, quant, despeckle, tri, voronoi,  # noqa: E402
                              jitter_points, blob_mask, outline, relief)
from town_textures import draw_text, text_centered, text_width  # noqa: E402  (Pack 02 5x7 pixel font)


def plaid():
    """Warm 70s sofa plaid: woven checks + twill."""
    rng = rng_for("res_plaid")
    W = 64
    Y, X = np.mgrid[0:W, 0:W]
    band_x = ((X // 8) % 4)
    band_y = ((Y // 8) % 4)
    lv = np.where((band_x == 0) | (band_y == 0), 1, 3)
    lv = np.where((band_x == 0) & (band_y == 0), 0, lv)
    cv = Canvas(W, W, 0)
    cv.a = P.ramp("leaf_rust", np.clip(lv, 0, 3))
    stripe = ((X % 16) == 12) | ((Y % 16) == 12)
    cv.paint(stripe, P("leaf_ochre", 3))
    twill = ((X + Y) % 4) == 0
    cv.shift(twill, -1)
    wear = vnoise(W, W, 16, rng, octaves=2) > 0.72
    cv.shift(wear, 1)
    return cv


def quilt():
    """Patchwork bedspread: 16 px squares of muted calicos with stitch lines."""
    rng = rng_for("res_quilt")
    W = 64
    cv = Canvas(W, W, 0)
    ramps = [("wallpaper_rose", 3), ("paint_blue", 3), ("leaf_ochre", 2), ("paint_green", 3), ("tile_cream", 3),
             ("flower", 2)]
    for by in range(4):
        for bx in range(4):
            r, base = ramps[int(rng.integers(0, len(ramps)))]
            cv.rect(bx * 16, by * 16, 16, 16, P(r, base))
            for (x, y) in jitter_points(16, 16, 4, rng, prob=0.7):  # calico dots
                cv.set(bx * 16 + x, by * 16 + y, P(r, base + (1 if rng.random() < 0.5 else -1)))
            if rng.random() < 0.4:  # half-square triangle
                for j in range(16):
                    for i in range(16 - j):
                        cv.shift_px(bx * 16 + i, by * 16 + j, -1)
    for k in range(0, W, 16):
        for t in range(0, W, 2):  # running stitch along the seams
            cv.set(k, t, P("tile_cream", 5))
            cv.set(t, k, P("tile_cream", 5))
    return cv


def gingham():
    W = 64
    Y, X = np.mgrid[0:W, 0:W]
    a, b = ((X // 4) % 2), ((Y // 4) % 2)
    cv = Canvas(W, W, 0)
    cv.a = np.where(a & b, P("paint_red", 3), np.where(a | b, P("wallpaper_rose", 4), P("tile_cream", 5)))
    fold = (X % 16) == 15
    cv.shift(fold, -1)
    return cv


def formica():
    rng = rng_for("res_formica")
    W = 64
    cv = Canvas(W, W, P("tile_cream", 3))
    for (x, y) in jitter_points(W, W, 3, rng, prob=0.8):  # boomerang flecks
        c = [P("tile_teal", 3), P("leaf_ochre", 2), P("tile_cream", 1), P("paint_white", 4)][int(rng.integers(0, 4))]
        cv.set(x, y, c)
        if rng.random() < 0.4:
            cv.set(x + 1, y + (1 if rng.random() < 0.5 else -1), c)
    sheen = vnoise(W, W, 32, rng, octaves=2) > 0.7
    cv.shift(sheen, 1)
    return cv


def porcelain():
    rng = rng_for("res_porcelain")
    W = 32
    cv = Canvas(W, W, 0)
    cv.a = P.ramp("bath_tile", tri(vnoise(W, W, 8, rng, octaves=2), 0.2, 0.8, dither=0.5) + 3)
    for (x, y) in jitter_points(W, W, 16, rng, prob=0.5):
        cv.set(x, y, P("bath_tile", 5))
        cv.set(x + 1, y, P("bath_tile", 5))
    return cv


def mirror():
    rng = rng_for("res_mirror")
    W = 64
    Y, X = np.mgrid[0:W, 0:W]
    cv = Canvas(W, W, 0)
    cv.a = P.ramp("glass", 3 - ((X + Y) // 22) % 2)
    band = np.abs((X + Y) - 70) < 4
    cv.paint(band, P("glass", 4))
    edge = (X < 2) | (Y < 2) | (X > W - 3) | (Y > W - 3)
    cv.paint(edge, P("metal", 4))
    spots = vnoise(W, W, 8, rng, octaves=2) > 0.82   # desilvering spots
    cv.paint(spots & ~edge, P("glass", 1))
    return cv


def enamel_harvest():
    rng = rng_for("res_enamel")
    W = 32
    cv = Canvas(W, W, 0)
    cv.a = P.ramp("leaf_ochre", tri(vnoise(W, W, 8, rng, octaves=2), 0.2, 0.8, dither=0.5) + 1)
    for (x, y) in jitter_points(W, W, 8, rng, prob=0.4):
        cv.set(x, y, P("leaf_ochre", 3))
    return cv


def wood_panel():
    """70s grooved wood paneling (den / basement), vertical grooves every 25 cm."""
    rng = rng_for("res_woodpanel")
    W = 64
    cv = Canvas(W, W, 0)
    g = vnoise(W, W, 4, rng, octaves=2, cell_y=32)
    cv.a = P.ramp("wood_warm", quant(g, 3, dither=0.4) + 1)
    X = np.arange(W)[None, :].repeat(W, 0)
    cv.paint((X % 16) == 0, P("wood_dark", 0))
    cv.paint((X % 16) == 1, P("wood_warm", 4))
    for (x, y) in jitter_points(W, W, 10, rng, prob=0.5):  # faux grain flecks
        for k in range(int(rng.integers(3, 9))):
            cv.set(x, y + k, P("wood_warm", 0))
    return cv


def insulation():
    rng = rng_for("res_insulation")
    W = 64
    cv = Canvas(W, W, P("flower", 3))
    cid, d1, d2, vx, vy = voronoi(W, W, 8, rng)
    s = np.where(vx + vy < -0.2, 1, np.where(vx + vy > 0.3, -1, 0))
    base = rng.choice([2, 3, 3], cid.max() + 1)[cid]
    cv.a = P.ramp("flower", base + s)
    X = np.arange(W)[None, :].repeat(W, 0)
    cv.paint((X % 32) < 3, P("wood_light", 2))   # joists every 0.5 m
    cv.paint((X % 32) == 0, P("wood_light", 3))
    return cv


def pegboard():
    W = 32
    cv = Canvas(W, W, P("cardboard", 2))
    for y in range(2, W, 4):
        for x in range(2, W, 4):
            cv.set(x, y, P("ink", 1))
            cv.set(x + 1, y + 1, P("cardboard", 4))
    return cv


def lattice():
    W = 32
    cv = Canvas(W, W, P("paint_white", 3), alpha=True)
    for y in range(W):
        for x in range(W):
            a, b = (x + y) % 16, (x - y) % 16
            if a < 3 or b < 3:
                cv.set(x, y, P("paint_white", 3 if a < 3 else 2), 255)
                if a == 0 or b == 0:
                    cv.set(x, y, P("paint_white", 4), 255)
    return cv


def garage_door():
    """Sectional garage door: 4 sections x 2 raised panels per 1 m, tiles in U."""
    rng = rng_for("res_garagedoor")
    W, H = 64, 128
    cv = Canvas(W, H, P("paint_white", 3))
    for s in range(4):
        y0 = s * 32
        cv.rect(0, y0, W, 1, P("paint_white", 0))
        cv.rect(0, y0 + 1, W, 1, P("paint_white", 4))
        for p in range(2):
            x0 = p * 32 + 3
            cv.rect(x0, y0 + 5, 26, 22, P("paint_white", 2))
            cv.rect(x0, y0 + 5, 26, 1, P("paint_white", 1))
            cv.rect(x0, y0 + 5, 1, 22, P("paint_white", 1))
            cv.rect(x0, y0 + 26, 26, 1, P("paint_white", 4))
            cv.rect(x0 + 25, y0 + 5, 1, 22, P("paint_white", 4))
    dirt = vnoise(W, H, 16, rng, octaves=2) < 0.18
    cv.shift(dirt, -1)
    Y = np.mgrid[0:H, 0:W][0]
    cv.shift((Y > H - 10) & (vnoise(W, H, 8, rng) > 0.4), -1)
    return cv


def shutter():
    W, H = 32, 64
    cv = Canvas(W, H, P("paint_green", 2))
    for y in range(3, H - 3):
        cv.rect(3, y, W - 6, 1, P("paint_green", [3, 2, 1][y % 3]))
    cv.rect(0, 0, W, 3, P("paint_green", 3))
    cv.rect(0, H - 3, W, 3, P("paint_green", 1))
    cv.rect(0, 0, 3, H, P("paint_green", 3))
    cv.rect(W - 3, 0, 3, H, P("paint_green", 1))
    cv.rect(0, 30, W, 4, P("paint_green", 2))
    return cv


def rug_braided():
    W = 64
    Y, X = np.mgrid[0:W, 0:W].astype(float) + 0.5
    r = np.sqrt(((X - 32) / 32) ** 2 + ((Y - 32) / 32) ** 2) * 16
    ring = np.floor(r).astype(int)
    cols = [P("leaf_rust", 2), P("tile_cream", 3), P("paint_blue", 2), P("leaf_ochre", 2), P("carpet", 3),
            P("paint_green", 2)]
    cv = Canvas(W, W, 0)
    cv.a = np.array(cols)[ring % len(cols)]
    braid = (((X + Y).astype(int) // 2) % 2 == 0) & ((r % 1) < 0.5)
    cv.shift(braid, -1)
    return cv


def lampshade():
    rng = rng_for("res_lampshade")
    W = 32
    X = np.arange(W)[None, :].repeat(W, 0)
    cv = Canvas(W, W, 0)
    cv.a = np.where((X % 4) == 0, P("glow", 1), P("glow", 2))
    cv.shift(vnoise(W, W, 8, rng) > 0.75, 1)
    return cv


# ----------------------------------------------------------------------------
# Detail atlas (256 x 256) - small printed / screen details, 0..1 mapped cells
# ----------------------------------------------------------------------------
DETAIL_RECTS = {
    "crt_screen": (0, 0, 64, 48), "crt_screen_off": (64, 0, 64, 48), "clock_face": (128, 0, 32, 32),
    "alarm_digits": (160, 0, 48, 16), "calendar": (208, 0, 48, 48), "book_spines": (0, 48, 64, 32),
    "book_spines_b": (64, 48, 64, 32), "photo_family": (128, 32, 32, 40), "photo_landscape": (160, 16, 48, 32),
    "painting_barn": (160, 48, 48, 32), "microwave_panel": (208, 48, 48, 32), "stove_top": (0, 80, 64, 64),
    "breaker_panel": (64, 80, 48, 64), "fridge_notes": (112, 80, 48, 48), "washer_panel": (160, 80, 64, 16),
    "cereal_box": (224, 80, 32, 48), "vinyl_records": (160, 96, 64, 32), "light_switch": (112, 128, 16, 32),
    "poster_band": (0, 144, 48, 64), "map_greyhaven": (48, 144, 64, 64), "keypad_radio": (112, 160, 64, 32),
    "dartboard": (176, 128, 48, 48), "tv_guide": (224, 128, 32, 48), "newspaper": (128, 192, 64, 64),
    "game_cartridges": (192, 176, 64, 32), "pc_screen": (192, 208, 64, 48),
}


def detail_atlas():
    rng = rng_for("res_detail")
    W = 256
    cv = Canvas(W, W, P("paint_black", 1))
    ink, white, cream = P("paint_black", 1), P("road_white", 3), P("tile_cream", 4)

    def R(k):
        return DETAIL_RECTS[k]
    # CRT on: evening news glow with scanlines
    x0, y0, w, h = R("crt_screen")
    for j in range(h):
        for i in range(w):
            d = ((i - w / 2) / (w / 2)) ** 2 + ((j - h / 2) / (h / 2)) ** 2
            lv = 3 if d < 0.5 else 2 if d < 0.9 else 1
            cv.set(x0 + i, y0 + j, P("glass", lv if j % 2 else max(0, lv - 1)))
    cv.rect(x0 + 6, y0 + 30, w - 12, 8, P("paint_navy", 3))
    draw_text(cv, x0 + 8, y0 + 31, "NEWS 6", white)
    cv.rect(x0 + 20, y0 + 8, 22, 18, P("glass", 4))
    x0, y0, w, h = R("crt_screen_off")
    for j in range(h):
        for i in range(w):
            cv.set(x0 + i, y0 + j, P("glass", 1 if (i + j) % 7 else 2))
    cv.rect(x0 + 6, y0 + 6, 10, 4, P("glass", 2))
    # clock face
    x0, y0, w, h = R("clock_face")
    Y, X = np.mgrid[0:h, 0:w].astype(float) + 0.5
    rr = np.sqrt((X - 16) ** 2 + (Y - 16) ** 2)
    sub = np.where(rr < 13, cream, np.where(rr < 16, P("wood_dark", 2), ink))
    cv.a[y0:y0 + h, x0:x0 + w] = sub
    for k in range(12):
        a = k * math.pi / 6
        cv.set(x0 + 16 + 11 * math.cos(a), y0 + 16 + 11 * math.sin(a), ink)
    for t in range(9):  # hour hand ~6 o'clock-ish... 6:45
        cv.set(x0 + 16 - t * 0.2, y0 + 16 + t * 0.85, ink)
    for t in range(11):
        cv.set(x0 + 16 - t, y0 + 16, ink)
    # alarm clock digits: 6:47 PM (Friday evening)
    x0, y0, w, h = R("alarm_digits")
    cv.rect(x0, y0, w, h, P("paint_black", 0))
    draw_text(cv, x0 + 6, y0 + 4, "6-47", P("paint_red", 4))
    cv.set(x0 + 17, y0 + 6, P("paint_red", 4))
    cv.set(x0 + 17, y0 + 9, P("paint_red", 4))
    draw_text(cv, x0 + 32, y0 + 4, "P", P("paint_red", 2))
    # wall calendar on FRIDAY
    x0, y0, w, h = R("calendar")
    cv.rect(x0, y0, w, h, cream)
    cv.rect(x0, y0, w, 10, P("paint_red", 3))
    text_centered(cv, x0, w, y0 + 2, "OCT", white)
    for r in range(5):
        for c in range(7):
            cv.rect(x0 + 2 + c * 6 + 1, y0 + 13 + r * 7, 4, 4, P("tile_cream", 2))
    cv.rect(x0 + 2 + 5 * 6, y0 + 13 + 3 * 7 - 1, 6, 6, P("paint_red", 3))   # circled Friday
    # book spines (two variants)
    for key, seed in (("book_spines", 1), ("book_spines_b", 2)):
        x0, y0, w, h = R(key)
        x = x0
        r2 = rng_for("books%d" % seed)
        while x < x0 + w:
            bw = int(r2.integers(3, 7))
            ramp = ["leaf_rust", "paint_navy", "paint_green", "leaf_ochre", "wallpaper_rose", "carpet"][int(r2.integers(0, 6))]
            top = int(r2.integers(2, 9))
            cv.rect(x, y0 + top, bw, h - top, P(ramp, 2))
            cv.rect(x, y0 + top, 1, h - top, P(ramp, 3))
            cv.rect(x, y0 + top + 4, bw, 1, P("leaf_ochre", 3))
            x += bw
    # photos / paintings
    x0, y0, w, h = R("photo_family")
    cv.rect(x0, y0, w, h, P("wood_light", 3))
    cv.rect(x0 + 3, y0 + 3, w - 6, h - 6, P("paint_blue", 4))
    cv.rect(x0 + 3, y0 + 26, w - 6, h - 29, P("grass", 3))
    for k, (px, ph) in enumerate(((8, 14), (15, 16), (22, 11))):
        cv.rect(x0 + px, y0 + 34 - ph, 4, ph - 6, [P("paint_red", 3), P("paint_navy", 3), P("leaf_ochre", 3)][k])
        cv.rect(x0 + px, y0 + 34 - ph - 4, 4, 4, P("wallpaper_rose", 4))
    x0, y0, w, h = R("photo_landscape")
    cv.rect(x0, y0, w, h, P("wood_dark", 2))
    cv.rect(x0 + 3, y0 + 3, w - 6, h - 6, P("paint_blue", 4))
    for i in range(w - 6):
        hh = int(6 + 4 * math.sin(i * 0.3))
        cv.rect(x0 + 3 + i, y0 + h - 3 - hh, 1, hh, P("pine", 3))
    x0, y0, w, h = R("painting_barn")
    cv.rect(x0, y0, w, h, P("leaf_ochre", 2))
    cv.rect(x0 + 3, y0 + 3, w - 6, h - 6, P("wallpaper_rose", 4))
    cv.rect(x0 + 3, y0 + 20, w - 6, h - 23, P("grass_dry", 3))
    cv.rect(x0 + 16, y0 + 11, 14, 10, P("brick_red", 3))
    for k in range(7):
        cv.rect(x0 + 16 + k, y0 + 11 - k // 2, 14 - 2 * k, 1, P("brick_red", 2))
    # appliances
    x0, y0, w, h = R("microwave_panel")
    cv.rect(x0, y0, w, h, P("metal", 2))
    cv.rect(x0 + 4, y0 + 4, w - 8, 8, P("paint_black", 0))
    draw_text(cv, x0 + 8, y0 + 5, "12-00", P("tile_teal", 4))
    for r in range(3):
        for c in range(4):
            cv.rect(x0 + 6 + c * 10, y0 + 15 + r * 5, 7, 3, P("metal", 4))
    x0, y0, w, h = R("stove_top")
    cv.rect(x0, y0, w, h, P("paint_white", 3))
    for (cx, cy, rad) in ((16, 16, 11), (48, 16, 8), (16, 48, 8), (48, 48, 11)):
        Y, X = np.mgrid[0:h, 0:w].astype(float) + 0.5
        rr = np.sqrt((X - cx) ** 2 + (Y - cy) ** 2)
        coil = (rr < rad) & ((np.floor(rr) % 3) == 0)
        cv.a[y0:y0 + h, x0:x0 + w][coil] = P("paint_black", 2)
        cv.a[y0:y0 + h, x0:x0 + w][(rr < rad + 2) & (rr >= rad)] = P("metal", 4)
    x0, y0, w, h = R("breaker_panel")
    cv.rect(x0, y0, w, h, P("metal", 3))
    for r in range(10):
        for c in range(2):
            cv.rect(x0 + 8 + c * 18, y0 + 6 + r * 5, 14, 3, P("paint_black", 2))
            cv.rect(x0 + 8 + c * 18 + (9 if (r + c) % 3 else 2), y0 + 6 + r * 5, 3, 3, P("paint_white", 4))
    x0, y0, w, h = R("fridge_notes")
    cv.rect(x0, y0, w, h, P("paint_white", 3))
    for (nx, ny, c) in ((4, 4, "road_yellow"), (24, 8, "tile_teal"), (10, 26, "wallpaper_rose"), (30, 30, "paint_white")):
        cv.rect(x0 + nx, y0 + ny, 14, 14, P(c, 3))
        for k in range(3):
            cv.rect(x0 + nx + 2, y0 + ny + 3 + k * 3, 9, 1, P("paint_black", 2))
        cv.rect(x0 + nx + 5, y0 + ny - 1, 3, 3, P("paint_red", 3))   # magnet
    x0, y0, w, h = R("washer_panel")
    cv.rect(x0, y0, w, h, P("paint_white", 4))
    for c in range(4):
        cv.rect(x0 + 6 + c * 14, y0 + 4, 8, 8, P("metal", 3))
        cv.set(x0 + 10 + c * 14, y0 + 5, P("paint_black", 1))
    x0, y0, w, h = R("cereal_box")
    cv.rect(x0, y0, w, h, P("leaf_ochre", 3))
    cv.rect(x0 + 2, y0 + 3, w - 4, 10, P("paint_red", 3))
    draw_text(cv, x0 + 4, y0 + 4, "OAT", white)
    cv.rect(x0 + 8, y0 + 20, 16, 16, cream)
    x0, y0, w, h = R("vinyl_records")
    x = x0
    while x < x0 + w - 3:
        cv.rect(x, y0, 3, h, [P("paint_black", 2), P("leaf_rust", 2), P("paint_navy", 2), P("tile_cream", 2)][(x // 3) % 4])
        x += 3
    x0, y0, w, h = R("light_switch")
    cv.rect(x0, y0, w, h, P("tile_cream", 4))
    cv.rect(x0 + 6, y0 + 10, 4, 12, P("tile_cream", 2))
    x0, y0, w, h = R("poster_band")
    cv.rect(x0, y0, w, h, P("paint_navy", 1))
    cv.rect(x0 + 4, y0 + 18, w - 8, 28, P("paint_red", 3))
    text_centered(cv, x0, w, y0 + 6, "TOUR", P("road_yellow", 3))
    text_centered(cv, x0, w, y0 + 50, "1997", white)
    x0, y0, w, h = R("map_greyhaven")
    cv.rect(x0, y0, w, h, cream)
    for k in range(0, w, 12):
        cv.rect(x0 + k, y0, 2, h, P("tile_cream", 2))
    cv.rect(x0, y0 + 30, w, 3, P("paint_red", 3))
    cv.rect(x0 + 30, y0, 3, h, P("paint_black", 3))
    cv.rect(x0 + 44, y0 + 8, 8, 8, P("paint_red", 3))
    x0, y0, w, h = R("keypad_radio")
    cv.rect(x0, y0, w, h, P("wood_dark", 2))
    cv.rect(x0 + 4, y0 + 4, 30, 24, P("cardboard", 1))
    for j in range(4, 28, 3):
        cv.rect(x0 + 4, y0 + j, 30, 1, P("wood_dark", 1))
    cv.rect(x0 + 38, y0 + 6, 22, 6, P("glow", 2))
    x0, y0, w, h = R("dartboard")
    Y, X = np.mgrid[0:h, 0:w].astype(float) + 0.5
    rr = np.sqrt((X - 24) ** 2 + (Y - 24) ** 2)
    ang = (np.floor((np.arctan2(Y - 24, X - 24) + math.pi) / (math.pi / 10)) % 2).astype(int)
    sub = np.where(rr > 22, P("paint_black", 1), np.where(ang == 0, P("tile_cream", 4), P("paint_black", 2)))
    sub = np.where((rr > 13) & (rr < 15), P("paint_red", 3), sub)
    sub = np.where(rr < 3, P("paint_red", 3), sub)
    cv.a[y0:y0 + h, x0:x0 + w] = sub
    x0, y0, w, h = R("tv_guide")
    cv.rect(x0, y0, w, h, P("paint_white", 4))
    cv.rect(x0, y0, w, 10, P("paint_red", 3))
    draw_text(cv, x0 + 3, y0 + 2, "TV", white)
    for j in range(14, h - 2, 4):
        cv.rect(x0 + 3, y0 + j, w - 6, 1, P("paint_black", 3))
    x0, y0, w, h = R("newspaper")
    cv.rect(x0, y0, w, h, P("tile_cream", 4))
    text_centered(cv, x0, w, y0 + 3, "GAZETTE", ink)
    cv.rect(x0 + 2, y0 + 12, w - 4, 1, ink)
    for j in range(16, h - 3, 3):
        for c in range(3):
            cv.rect(x0 + 3 + c * 20, y0 + j, 17, 1, P("tile_cream", 1))
    cv.rect(x0 + 24, y0 + 16, 36, 20, P("tile_cream", 2))
    x0, y0, w, h = R("game_cartridges")
    x = x0
    while x < x0 + w - 7:
        cv.rect(x + 1, y0 + 2, 6, h - 4, P("metal", 1))
        cv.rect(x + 2, y0 + 6, 4, 10, [P("paint_red", 3), P("paint_blue", 4), P("leaf_ochre", 3), P("tile_teal", 3)][(x // 8) % 4])
        x += 8
    x0, y0, w, h = R("pc_screen")
    cv.rect(x0, y0, w, h, P("paint_navy", 2))
    cv.rect(x0, y0, w, 6, P("paint_white", 2))
    draw_text(cv, x0 + 4, y0 + 10, "C-", P("paint_white", 4))
    for j in range(20, h - 4, 4):
        cv.rect(x0 + 4, y0 + j, int(rng.integers(12, w - 8)), 2, P("paint_white", 3))
    return cv


TEXTURES = {
    "FabricPlaid": (plaid, (64, 64), False, "Warm 70s sofa plaid."),
    "Quilt": (quilt, (64, 64), False, "Patchwork quilt / bedspread."),
    "Gingham": (gingham, (64, 64), False, "Red gingham curtains / tablecloth."),
    "Formica": (formica, (64, 64), False, "Speckled boomerang-style laminate countertop."),
    "Porcelain": (porcelain, (32, 32), False, "Glazed white porcelain (toilet, tub, sink)."),
    "Mirror": (mirror, (64, 64), False, "Opaque stylised mirror with desilvered spots (0..1 UV)."),
    "EnamelHarvest": (enamel_harvest, (32, 32), False, "Harvest-gold appliance enamel."),
    "WoodPanel": (wood_panel, (64, 64), False, "Grooved 70s wood wall paneling."),
    "Insulation": (insulation, (64, 64), False, "Pink attic insulation between joists."),
    "Pegboard": (pegboard, (32, 32), False, "Brown hardboard pegboard."),
    "Lattice": (lattice, (32, 32), True, "White porch-skirt lattice, alpha cutout."),
    "GarageDoor": (garage_door, (64, 128), False, "Sectional garage door panels (1 m x 2 m tile)."),
    "Shutter": (shutter, (32, 64), False, "Louvred window shutter (0..1 UV)."),
    "RugBraided": (rug_braided, (64, 64), False, "Oval braided rag rug (0..1 UV)."),
    "Lampshade": (lampshade, (32, 32), False, "Pleated warm lampshade fabric (emissive-friendly)."),
    "DetailAtlas": (detail_atlas, (256, 256), False, "Small details: CRT, clocks, books, photos, appliance panels, calendar, posters."),
}
