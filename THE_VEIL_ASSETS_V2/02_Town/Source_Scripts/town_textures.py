"""Pack 02 supplementary textures.

Only surfaces Pack 01 cannot cover: sign faces with lettering, painted
street-furniture colours, chain-link, pine needles, grass/ivy cutouts,
covers/grates, rock, lamp glow. Built with the *same* Pack 01 toolkit
(veil_texgen), palette, top-left lighting and 64 px/m density.
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "Source_Scripts"))

import numpy as np  # noqa: E402

from veil_texgen.core import (P, Canvas, rng_for, vnoise, quant, despeckle, tri, voronoi,  # noqa: E402
                              jitter_points, blob_mask, outline, crack_mask, apply_crack, relief)
from veil_texgen.shapes import leaf_sprite, stones  # noqa: E402

# ----------------------------------------------------------------------------
# 5x7 pixel font (hand-authored)
# ----------------------------------------------------------------------------
FONT = {
    "A": [" ### ", "#   #", "#   #", "#####", "#   #", "#   #", "#   #"],
    "B": ["#### ", "#   #", "#   #", "#### ", "#   #", "#   #", "#### "],
    "C": [" ### ", "#   #", "#    ", "#    ", "#    ", "#   #", " ### "],
    "D": ["#### ", "#   #", "#   #", "#   #", "#   #", "#   #", "#### "],
    "E": ["#####", "#    ", "#    ", "#### ", "#    ", "#    ", "#####"],
    "F": ["#####", "#    ", "#    ", "#### ", "#    ", "#    ", "#    "],
    "G": [" ### ", "#   #", "#    ", "# ###", "#   #", "#   #", " ####"],
    "H": ["#   #", "#   #", "#   #", "#####", "#   #", "#   #", "#   #"],
    "I": [" ### ", "  #  ", "  #  ", "  #  ", "  #  ", "  #  ", " ### "],
    "K": ["#   #", "#  # ", "# #  ", "##   ", "# #  ", "#  # ", "#   #"],
    "L": ["#    ", "#    ", "#    ", "#    ", "#    ", "#    ", "#####"],
    "M": ["#   #", "## ##", "# # #", "# # #", "#   #", "#   #", "#   #"],
    "N": ["#   #", "##  #", "# # #", "#  ##", "#   #", "#   #", "#   #"],
    "O": [" ### ", "#   #", "#   #", "#   #", "#   #", "#   #", " ### "],
    "P": ["#### ", "#   #", "#   #", "#### ", "#    ", "#    ", "#    "],
    "Q": [" ### ", "#   #", "#   #", "#   #", "# # #", "#  # ", " ## #"],
    "R": ["#### ", "#   #", "#   #", "#### ", "# #  ", "#  # ", "#   #"],
    "S": [" ####", "#    ", "#    ", " ### ", "    #", "    #", "#### "],
    "T": ["#####", "  #  ", "  #  ", "  #  ", "  #  ", "  #  ", "  #  "],
    "U": ["#   #", "#   #", "#   #", "#   #", "#   #", "#   #", " ### "],
    "V": ["#   #", "#   #", "#   #", "#   #", "#   #", " # # ", "  #  "],
    "W": ["#   #", "#   #", "#   #", "# # #", "# # #", "## ##", "#   #"],
    "Y": ["#   #", "#   #", " # # ", "  #  ", "  #  ", "  #  ", "  #  "],
    "Z": ["#####", "    #", "   # ", "  #  ", " #   ", "#    ", "#####"],
    "0": [" ### ", "#   #", "#  ##", "# # #", "##  #", "#   #", " ### "],
    "1": ["  #  ", " ##  ", "  #  ", "  #  ", "  #  ", "  #  ", " ### "],
    "2": [" ### ", "#   #", "    #", "   # ", "  #  ", " #   ", "#####"],
    "3": ["#####", "   # ", "  #  ", "   # ", "    #", "#   #", " ### "],
    "4": ["   # ", "  ## ", " # # ", "#  # ", "#####", "   # ", "   # "],
    "5": ["#####", "#    ", "#### ", "    #", "    #", "#   #", " ### "],
    "6": ["  ## ", " #   ", "#    ", "#### ", "#   #", "#   #", " ### "],
    "7": ["#####", "    #", "   # ", "  #  ", " #   ", " #   ", " #   "],
    "8": [" ### ", "#   #", "#   #", " ### ", "#   #", "#   #", " ### "],
    "9": [" ### ", "#   #", "#   #", " ####", "    #", "   # ", " ##  "],
    " ": ["     "] * 7,
    ".": ["     "] * 6 + ["  #  "],
    "-": ["     "] * 3 + [" ### "] + ["     "] * 3,
}


def text_width(s, scale=1):
    return (len(s) * 6 - 1) * scale


def draw_text(cv, x, y, s, col, scale=1):
    cx = x
    for ch in s:
        g = FONT[ch]
        for j, row in enumerate(g):
            for i, c in enumerate(row):
                if c == "#":
                    cv.rect(cx + i * scale, y + j * scale, scale, scale, col)
        cx += 6 * scale


def text_centered(cv, x0, w, y, s, col, scale=1):
    draw_text(cv, x0 + (w - text_width(s, scale)) // 2, y, s, col, scale)


def weather(cv, rng, x0, y0, w, h, strength=0.2):
    """Light fading + dirt on a sign face region."""
    f = vnoise(w, h, 8, rng, octaves=2) if (w % 8 == 0 and h % 8 == 0) else vnoise(w, h, 4, rng)
    t = tri(f, strength, 1 - strength, dither=0.5)
    sub = cv.a[y0:y0 + h, x0:x0 + w]
    sub[t == 0] = P.shift(sub[t == 0], -1)
    sub[t == 2] = P.shift(sub[t == 2], 1)


# ----------------------------------------------------------------------------
# Painted metal (tileable 32 px = 0.5 m)
# ----------------------------------------------------------------------------
def _paint(name, ramp, base=2):
    rng = rng_for("town_" + name)
    W = 32
    cv = Canvas(W, W, 0)
    t = tri(vnoise(W, W, 8, rng, octaves=2), 0.25, 0.78, dither=0.5)
    cv.a = P.ramp(ramp, base + t - 1)
    for (x, y) in jitter_points(W, W, 8, rng, prob=0.6):  # scratches
        for i in range(int(rng.integers(2, 6))):
            cv.shift_px(x + i, y + (i // 3), 1)
    for (x, y) in jitter_points(W, W, 16, rng, prob=0.7):  # chips to bare metal
        cv.set(x, y, P("metal", 2))
        cv.set(x + 1, y, P("metal", 3))
        cv.set(x, y + 1, P(ramp, 0))
    dirt = vnoise(W, W, 8, rng, octaves=2) < 0.16
    cv.shift(dirt, -1)
    return cv


def hazard_stripe():
    rng = rng_for("town_hazard")
    W = 64
    Y, X = np.mgrid[0:W, 0:W]
    band = ((X + Y) // 16) % 2 == 0
    cv = Canvas(W, W, 0)
    cv.a = np.where(band, P("sign_yellow", 3), P("paint_black", 2))
    weather(cv, rng, 0, 0, W, W, 0.2)
    for (x, y) in jitter_points(W, W, 8, rng, prob=0.4):
        cv.set(x, y, P("metal", 3))
    return cv


def chain_link():
    W = 32
    cv = Canvas(W, W, P("metal", 3), alpha=True)
    for y in range(W):
        for x in range(W):
            a, b = (x + y) % 16, (x - y) % 16
            if a == 0 or b == 0:
                lv = 4 if a == 0 else 2
                cv.set(x, y, P("metal", lv), 255)
            elif a == 1 or b == 15:
                cv.set(x, y, P("metal", 1), 255)
    return cv


def puddle():
    rng = rng_for("town_puddle")
    W = 64
    cv = Canvas(W, W, P("mud", 1), alpha=True)
    Y, X = np.mgrid[0:W, 0:W].astype(float)
    d = np.sqrt(((X - 32) / 28) ** 2 + ((Y - 32) / 20) ** 2)
    n = vnoise(W, W, 8, rng, octaves=2)
    f = d + (n - 0.5) * 0.6
    water = f < 0.85
    rim = (f < 1.0) & ~water
    cv.paint(rim, P("asphalt", 1), 150)
    cv.paint(water, P("glass", 1), 215)
    refl = water & (vnoise(W, W, 16, rng) > 0.6)
    cv.paint(refl, P("glass", 2), 215)
    for (x, y) in jitter_points(W, W, 6, rng, prob=0.25):
        if water[y, x]:
            cv.set(x, y, P("glass", 4), 230)
    cv.paint(outline(water) & rim, P("tar", 0), 190)
    cv.alpha[:1, :] = 0
    cv.alpha[-1:, :] = 0
    cv.alpha[:, :1] = 0
    cv.alpha[:, -1:] = 0
    return cv


def manhole_cover():
    rng = rng_for("town_manhole")
    W = 64
    Y, X = np.mgrid[0:W, 0:W].astype(float) + 0.5
    r = np.sqrt((X - 32) ** 2 + (Y - 32) ** 2)
    cv = Canvas(W, W, P("metal", 1))
    # raised grid of lugs
    lug = ((X.astype(int) % 6) < 4) & ((Y.astype(int) % 6) < 4)
    cv.paint(lug, P("metal", 2))
    cv.paint(lug & ((X.astype(int) % 6) == 0), P("metal", 3))
    cv.paint((r > 22) & (r < 26), P("metal", 2))
    cv.paint((r > 24.5) & (r < 26), P("metal", 3))
    cv.paint((r >= 29.5), P("asphalt", 1))
    cv.paint((r > 26) & (r < 29.5), P("metal", 0))
    draw_text(cv, 32 - text_width("SEWER") // 2, 28, "SEWER", P("metal", 3))
    for (hx, hy) in ((16, 32), (48, 32)):
        cv.rect(hx - 1, hy - 1, 2, 2, P("ink", 0))
    rust = (vnoise(W, W, 8, rng, octaves=2) > 0.74)
    cv.a[rust] = P.ramp("rust", 1 + (vnoise(W, W, 4, rng)[rust] > 0.5))
    return cv


def drain_grate():
    rng = rng_for("town_grate")
    W = 64
    cv = Canvas(W, W, P("metal", 2))
    cv.rect(0, 0, W, 4, P("metal", 1))
    cv.rect(0, W - 4, W, 4, P("metal", 1))
    cv.rect(0, 0, 4, W, P("metal", 1))
    cv.rect(W - 4, 0, 4, W, P("metal", 1))
    for x in range(7, W - 6, 6):
        cv.rect(x, 7, 3, W - 14, P("ink", 0))
        cv.rect(x + 3, 7, 1, W - 14, P("metal", 3))
    cv.rect(4, 31, W - 8, 2, P("metal", 2))
    rust = (vnoise(W, W, 8, rng, octaves=2) > 0.7)
    cv.a[rust & (cv.a != P("ink", 0))] = P("rust", 2)
    return cv


def utility_cover():
    rng = rng_for("town_utilcover")
    W = 64
    Y, X = np.mgrid[0:W, 0:W]
    cv = Canvas(W, W, P("metal", 2))
    dia = ((X + 2 * Y) % 8 == 0) & ((X // 4 + Y // 4) % 2 == 0)
    dia2 = ((X - 2 * Y) % 8 == 0) & ((X // 4 + Y // 4) % 2 == 1)
    cv.paint(dia | dia2, P("metal", 4))
    cv.paint(np.roll(dia | dia2, 1, 0), P("metal", 1))
    for k in (0, 1, 2):
        cv.rect(k, k, W - 2 * k, 1, P("metal", 3 - k))
        cv.rect(k, W - 1 - k, W - 2 * k, 1, P("metal", 1))
        cv.rect(k, k, 1, W - 2 * k, P("metal", 3 - k))
        cv.rect(W - 1 - k, k, 1, W - 2 * k, P("metal", 1))
    cv.rect(18, 26, 28, 11, P("metal", 1))
    text_centered(cv, 0, W, 28, "ELEC", P("metal", 4))
    for (hx, hy) in ((8, 8), (54, 54)):
        cv.rect(hx, hy, 3, 2, P("ink", 0))
    rust = (vnoise(W, W, 8, rng, octaves=2) > 0.75)
    cv.a[rust] = P("rust", 2)
    return cv


def pine_needles():
    rng = rng_for("town_pine")
    W = 128
    cv = Canvas(W, W, P("pine", 0))
    for layer, (step, lv) in enumerate(((3, 1), (3, 2), (4, 3), (5, 4))):
        for (x, y) in jitter_points(W, W, step, rng, prob=0.9):
            v = lv + (1 if rng.random() < 0.12 else 0)
            # needle tuft: a short downward-angled fan of strokes
            for k, (dx, dy) in enumerate(((-2, 1), (-1, 1), (0, 1), (1, 1), (2, 1))):
                for s in range(1, 3):
                    cv.set(x + dx * s // 2 + (dx > 0) * s // 2, y + s, P("pine", v if s == 1 else v - 1))
            cv.set(x, y, P("pine", min(5, v + 1)))
    for _ in range(10):
        x, y = rng.integers(0, W), rng.integers(0, W)
        for k in range(int(rng.integers(3, 7))):
            if P.level(cv.get(x + k, y + k // 2)) <= 1:
                cv.set(x + k, y + k // 2, P("bark", 1))
    return cv


def grass_cards():
    """Two 64x64 cutout cells: tall grass (left) and weeds (right)."""
    rng = rng_for("town_grasscards")
    W, H = 128, 64
    cv = Canvas(W, H, P("grass", 1), alpha=True)
    # tall grass: curved blades rising from the bottom
    for i in range(34):
        x = 4 + rng.uniform(0, 56)
        L = rng.uniform(26, 58)
        lean = rng.normal(0, 0.18)
        lv = int(rng.integers(2, 6))
        r = "grass" if rng.random() < 0.8 else "grass_dry"
        for s in range(int(L)):
            t = s / L
            px = x + lean * s + lean * 18 * t * t
            col = P(r, max(0, lv - 1) if s < 6 else (min(lv + 1, P.size[r] - 1) if s > L - 4 else lv))
            cv.set(int(px), H - 1 - s, col, 255)
            if s < L * 0.4:
                cv.set(int(px) + 1, H - 1 - s, P(r, max(0, lv - 1)), 255)
    # weeds: stalks with broad leaves and seed heads
    for i in range(7):
        x = 68 + rng.uniform(0, 52)
        L = int(rng.uniform(30, 56))
        for s in range(L):
            px = int(x + math.sin(s * 0.08 + i) * 1.5)
            cv.set(px, H - 1 - s, P("grass", 2), 255)
            if s % 9 == 4 and s < L - 6:
                side = 1 if (s // 9) % 2 else -1
                for k in range(1, 6):
                    cv.set(px + side * k, H - 1 - s - k // 2, P("grass", 3 if k < 4 else 4), 255)
                    cv.set(px + side * k, H - 1 - s - k // 2 + 1, P("grass", 1), 255)
        top = H - 1 - L
        cv.rect(int(x) - 1, top - 3, 3, 4, P("grass_dry", 3), 255)
        cv.set(int(x), top - 4, P("grass_dry", 4), 255)
    cv.alpha[:, 63:65] = 0
    cv.alpha[0, :] = 0
    return cv


def flower_bed():
    rng = rng_for("town_flowers")
    W = 64
    cv = Canvas(W, W, 0)
    cv.a = P.ramp("soil", quant(vnoise(W, W, 16, rng), 2) + 1)
    for (x, y) in jitter_points(W, W, 4, rng, prob=0.85):
        leaf_sprite(cv, x, y, 4, 3, rng.random() * 6.28, "grass", int(rng.integers(2, 4)),
                    shadow=P("soil", 0))
    cols = [("flower", 2), ("paint_white", 4), ("road_yellow", 3), ("flower", 3), ("paint_red", 4)]
    for (x, y) in jitter_points(W, W, 6, rng, prob=0.8):
        r, k = cols[int(rng.integers(0, len(cols)))]
        cv.rect(x, y, 2, 2, P(r, k))
        cv.set(x, y, P(r, min(k + 1, P.size[r] - 1)))
        cv.set(x + 1, y + 1, P(r, k - 1))
    return cv


def ivy():
    rng = rng_for("town_ivy")
    W = 64
    cv = Canvas(W, W, P("hedge", 1), alpha=True)
    for _ in range(5):  # vines
        x, y = rng.integers(0, W), 0
        for s in range(W):
            x = x + int(rng.integers(-1, 2))
            cv.set(x, s, P("bark", 2), 255)
    for (x, y) in jitter_points(W, W, 5, rng, prob=0.85):
        lv = int(rng.integers(2, 5))
        for (i, j) in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, 1), (0, 2)):
            cv.set(x + i, y + j, P("hedge", lv), 255)
        cv.set(x - 1, y - 1, P("hedge", lv + 1), 255)
        cv.set(x + 1, y + 2, P("hedge", lv - 1), 255)
    return cv


def rock():
    rng = rng_for("town_rock")
    W = 64
    cv = Canvas(W, W, P("stone_warm", 1))
    stones(cv, rng, 16, ["stone_warm", "concrete"], P("stone_warm", 0), levels=(2, 3), gap=0.05)
    r = relief(vnoise(W, W, 4, rng), 0.25)
    cv.shift(r != 0, r)
    lich = vnoise(W, W, 16, rng, octaves=2) > 0.8
    cv.a[lich] = P("lichen", 2)
    return cv


def pole_wood():
    rng = rng_for("town_polewood")
    W = 64
    cv = Canvas(W, W, 0)
    g = vnoise(W, W, 4, rng, octaves=2, cell_y=32)
    cv.a = P.ramp("wood_dark", quant(g, 3, dither=0.4) + 2)
    for (x, y) in jitter_points(W, W, 16, rng, prob=0.6):  # drying checks
        for k in range(int(rng.integers(6, 18))):
            cv.set(x, y + k, P("wood_dark", 0))
            cv.shift_px(x + 1, y + k, 1)
    for (x, y) in jitter_points(W, W, 16, rng, prob=0.35):  # staples / nails
        cv.set(x, y, P("metal", 4))
        cv.set(x + 1, y, P("metal", 2))
    return cv


def stump_top():
    rng = rng_for("town_stump")
    W = 64
    Y, X = np.mgrid[0:W, 0:W].astype(float) + 0.5
    n = vnoise(W, W, 8, rng)
    r = np.sqrt((X - 32) ** 2 + (Y - 32) ** 2) + n * 2
    cv = Canvas(W, W, 0)
    rings = (np.floor(r / 2.6) % 2).astype(int)
    cv.a = P.ramp("wood_light", 2 + rings - (r > 22))
    cv.paint(r > 27, P("bark", 2))
    cv.paint(r > 30, P("bark", 1))
    cv.paint(r < 2, P("wood_light", 0))
    for a in (0.7, 2.6, 4.4):
        for k in range(4, 24):
            cv.set(32 + math.cos(a) * k, 32 + math.sin(a) * k, P("wood_dark", 1))
    return cv


def vent_grille():
    W = 32
    cv = Canvas(W, W, P("sign_backing", 2))
    for y in range(W):
        lv = [4, 3, 1, 0][y % 4]
        cv.rect(0, y, W, 1, P("sign_backing", lv) if lv > 0 else P("ink", 1))
    return cv


def lamp_glow():
    rng = rng_for("town_glow")
    W = 32
    cv = Canvas(W, W, 0)
    cv.a = P.ramp("glow", quant(vnoise(W, W, 8, rng), 2, dither=0.5) + 2)
    return cv


# ----------------------------------------------------------------------------
# Sign atlas (256 x 256). Signage is the only intentional density exception
# (~85 px/m) so that lettering stays readable.
# ----------------------------------------------------------------------------
SIGN_RECTS = {
    "stop": (0, 0, 64, 64),
    "yield": (64, 0, 64, 64),
    "speed25": (128, 0, 52, 64),
    "parking": (180, 0, 48, 64),
    "bus": (0, 64, 48, 64),
    "deadend": (48, 64, 64, 64),
    "phone": (112, 64, 64, 16),
    "gazette": (112, 80, 64, 16),
    "noparking": (176, 64, 48, 64),
    "oneway": (112, 96, 64, 24),
}
STREET_NAMES = ["ELM ST", "MAPLE AVE", "OAK ST", "BIRCH LN", "CEDAR ST", "MAIN ST",
                "QUARRY RD", "MILL RD", "ROUTE 9", "PINE ST"]
for i, nm in enumerate(STREET_NAMES):
    SIGN_RECTS["blade_" + nm.replace(" ", "_")] = ((i % 2) * 128, 128 + (i // 2) * 16, 128, 16)


def sign_atlas():
    rng = rng_for("town_signs")
    W = 256
    cv = Canvas(W, W, P("sign_backing", 2))
    white, black, red = P("road_white", 3), P("paint_black", 1), P("paint_red", 3)
    # STOP: octagon fill handled by geometry; face is red with white border ring
    x0, y0, w, h = SIGN_RECTS["stop"]
    Y, X = np.mgrid[0:h, 0:w].astype(float) + 0.5
    oct_d = np.maximum(np.maximum(abs(X - 32), abs(Y - 32)), (abs(X - 32) + abs(Y - 32)) / 1.414)
    face = np.where(oct_d > 27, white, red)
    face = np.where(oct_d > 30, P("sign_backing", 2), face)
    cv.a[y0:y0 + h, x0:x0 + w] = face
    text_centered(cv, x0, w, 25, "STOP", white, 2)
    weather(cv, rng, x0, y0, w, h, 0.18)
    # YIELD: downward triangle - white centre, red border
    x0, y0, w, h = SIGN_RECTS["yield"]
    for j in range(h):
        half = (h - j) * 0.55
        for i in range(w):
            d = abs(i + 0.5 - 32)
            if d < half - 9 and j > 6:
                c = white
            elif d < half:
                c = red
            else:
                c = P("sign_backing", 2)
            cv.a[y0 + j, x0 + i] = c
    text_centered(cv, x0, w, 14, "YIELD", red)
    weather(cv, rng, x0, y0, w, h, 0.18)
    # SPEED LIMIT 25
    x0, y0, w, h = SIGN_RECTS["speed25"]
    cv.rect(x0, y0, w, h, white)
    for k in (2, 3):
        cv.rect(x0 + k, y0 + k, w - 2 * k, 1, black)
        cv.rect(x0 + k, y0 + h - 1 - k, w - 2 * k, 1, black)
        cv.rect(x0 + k, y0 + k, 1, h - 2 * k, black)
        cv.rect(x0 + w - 1 - k, y0 + k, 1, h - 2 * k, black)
    text_centered(cv, x0, w, y0 + 7, "SPEED", black)
    text_centered(cv, x0, w, y0 + 16, "LIMIT", black)
    text_centered(cv, x0, w, y0 + 30, "25", black, 3)
    weather(cv, rng, x0, y0, w, h, 0.2)
    # PARKING
    x0, y0, w, h = SIGN_RECTS["parking"]
    cv.rect(x0, y0, w, h, white)
    cv.rect(x0 + 2, y0 + 2, w - 4, 1, P("sign_green", 2))
    cv.rect(x0 + 2, y0 + h - 3, w - 4, 1, P("sign_green", 2))
    text_centered(cv, x0, w, y0 + 6, "P", P("sign_green", 2), 4)
    text_centered(cv, x0, w, y0 + 38, "2 HR", P("sign_green", 2))
    text_centered(cv, x0, w, y0 + 48, "8-6", P("sign_green", 2))
    weather(cv, rng, x0, y0, w, h, 0.2)
    # NO PARKING
    x0, y0, w, h = SIGN_RECTS["noparking"]
    cv.rect(x0, y0, w, h, white)
    text_centered(cv, x0, w, y0 + 6, "NO", red)
    text_centered(cv, x0, w, y0 + 16, "PARKING", red) if text_width("PARKING") <= w else None
    Yy, Xx = np.mgrid[0:24, 0:24].astype(float) + 0.5
    rr = np.sqrt((Xx - 12) ** 2 + (Yy - 12) ** 2)
    ring = (rr > 9) & (rr < 12)
    slash = (abs(Xx - Yy) < 2) & (rr < 11)
    sub = cv.a[y0 + 32:y0 + 56, x0 + 12:x0 + 36]
    sub[ring | slash] = red
    draw_text(cv, x0 + 22, y0 + 40, "P", black) if False else None
    weather(cv, rng, x0, y0, w, h, 0.2)
    # BUS STOP
    x0, y0, w, h = SIGN_RECTS["bus"]
    cv.rect(x0, y0, w, h, P("paint_navy", 3))
    cv.rect(x0 + 2, y0 + 2, w - 4, h - 4, white)
    cv.rect(x0 + 4, y0 + 4, w - 8, h - 8, P("paint_navy", 3))
    text_centered(cv, x0, w, y0 + 10, "BUS", white, 2)
    text_centered(cv, x0, w, y0 + 30, "STOP", white)
    # little bus pictogram
    cv.rect(x0 + 14, y0 + 42, 20, 10, white)
    cv.rect(x0 + 16, y0 + 44, 4, 3, P("paint_navy", 3))
    cv.rect(x0 + 22, y0 + 44, 4, 3, P("paint_navy", 3))
    cv.rect(x0 + 28, y0 + 44, 4, 3, P("paint_navy", 3))
    cv.rect(x0 + 16, y0 + 52, 3, 2, black)
    cv.rect(x0 + 29, y0 + 52, 3, 2, black)
    weather(cv, rng, x0, y0, w, h, 0.2)
    # DEAD END (yellow diamond face)
    x0, y0, w, h = SIGN_RECTS["deadend"]
    Y, X = np.mgrid[0:h, 0:w].astype(float) + 0.5
    dd = abs(X - 32) + abs(Y - 32)
    cv.a[y0:y0 + h, x0:x0 + w] = np.where(dd < 28, P("sign_yellow", 3),
                                          np.where(dd < 31, black, P("sign_backing", 2)))
    text_centered(cv, x0, w, y0 + 22, "DEAD", black)
    text_centered(cv, x0, w, y0 + 34, "END", black)
    weather(cv, rng, x0, y0, w, h, 0.2)
    # PHONE header / GAZETTE label / ONE WAY
    x0, y0, w, h = SIGN_RECTS["phone"]
    cv.rect(x0, y0, w, h, P("paint_navy", 2))
    text_centered(cv, x0, w, y0 + 4, "PHONE", white)
    x0, y0, w, h = SIGN_RECTS["gazette"]
    cv.rect(x0, y0, w, h, white)
    text_centered(cv, x0, w, y0 + 4, "GAZETTE", P("paint_navy", 2))
    x0, y0, w, h = SIGN_RECTS["oneway"]
    cv.rect(x0, y0, w, h, black)
    cv.rect(x0 + 3, y0 + 6, w - 12, 12, white)
    for k in range(8):
        cv.rect(x0 + w - 10 + k, y0 + 2 + k, 1, 20 - 2 * k, white)
    text_centered(cv, x0, w - 8, y0 + 9, "ONE WAY", black)
    # street-name blades: green, white border, white caps
    for nm in STREET_NAMES:
        x0, y0, w, h = SIGN_RECTS["blade_" + nm.replace(" ", "_")]
        cv.rect(x0, y0, w, h, P("sign_green", 2))
        cv.rect(x0 + 1, y0 + 1, w - 2, 1, white)
        cv.rect(x0 + 1, y0 + h - 2, w - 2, 1, white)
        text_centered(cv, x0, w, y0 + 4, nm, white)
        weather(cv, rng, x0, y0, w, h, 0.22)
    return cv


TEXTURES = {
    # name: (generator, size, alpha, description)
    "SignAtlas": (sign_atlas, (256, 256), False, "Sign faces: stop, yield, speed limit, parking, bus stop, dead end, labels, 10 street-name blades."),
    "PaintRed": (lambda: _paint("red", "paint_red"), (32, 32), False, "Hydrant / mailbox-flag red paint on metal."),
    "PaintOrange": (lambda: _paint("orange", "paint_orange"), (32, 32), False, "Traffic-cone / barrier orange."),
    "PaintNavy": (lambda: _paint("navy", "paint_navy"), (32, 32), False, "Navy blue painted metal (newspaper box, phone)."),
    "PaintBlack": (lambda: _paint("black", "paint_black"), (32, 32), False, "Black painted metal (lamp posts, railings, signal backplates)."),
    "PaintYellow": (lambda: _paint("yellow", "sign_yellow", 3), (32, 32), False, "Safety yellow paint (signal heads, bollards)."),
    "PaintGreen": (lambda: _paint("green", "door_green", 2), (32, 32), False, "Dark green municipal paint (dumpster, bins)."),
    "PaintWhite": (lambda: _paint("white", "paint_white", 3), (32, 32), False, "White painted metal (cone bands, poles)."),
    "HazardStripe": (hazard_stripe, (64, 64), False, "Yellow/black diagonal hazard stripes (barriers)."),
    "ChainLink": (chain_link, (32, 32), True, "Chain-link wire diamonds, alpha cutout, 25 cm stylised mesh."),
    "Puddle": (puddle, (64, 64), True, "Puddle decal with sky reflection and wet rim."),
    "ManholeCover": (manhole_cover, (64, 64), False, "Round sewer cover (0..1 UV over a 1 m disc)."),
    "DrainGrate": (drain_grate, (64, 64), False, "Rectangular slotted drain grate (0..1 UV)."),
    "UtilityCover": (utility_cover, (64, 64), False, "Square diamond-plate utility access cover (0..1 UV)."),
    "PineNeedles": (pine_needles, (128, 128), False, "Layered pine needle tufts for conifer canopies."),
    "GrassCards": (grass_cards, (128, 64), True, "Two cutout cells: tall grass (left), weeds (right)."),
    "FlowerBed": (flower_bed, (64, 64), False, "Soil with leafy clumps and muted flowers."),
    "Ivy": (ivy, (64, 64), True, "Tileable ivy cutout with vines."),
    "Rock": (rock, (64, 64), False, "Weathered rock plates with lichen."),
    "PoleWood": (pole_wood, (64, 64), False, "Creosoted utility-pole wood, vertical checks and staples."),
    "StumpTop": (stump_top, (64, 64), False, "Tree-stump cut face with growth rings (0..1 UV)."),
    "VentGrille": (vent_grille, (32, 32), False, "Louvred metal grille (AC units, vents, cabinets)."),
    "LampGlow": (lamp_glow, (32, 32), False, "Warm frosted lamp glass (used with emission)."),
}
