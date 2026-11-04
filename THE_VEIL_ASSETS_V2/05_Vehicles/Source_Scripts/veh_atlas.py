"""Pack 05 pixel-art vehicle atlas: T_Veh_Atlas.png (256x256) + T_Veh_Atlas_Weathered.png (same layout, dusty/rusty).

Rows 0-47  : 48 swatches (16x16): car paints (muted, subtle wear), trim, chrome, steel, glass, rubber, tread, fabrics,
             carpet, headliner, dash plastic, bedliner, plywood, cargo wall, lenses ...
Rows 48-255: decals - headlight / taillight units, grille, licence plates, instrument cluster, centre stack, door card,
             hubcap, steel rim, Greyhaven Police markings, Harlow Bakery van livery (fictional), engine bay, cracked glass.
Every pixel comes from the Greyhaven palette (Pack 01 ramps + Pack 06 character ramps), like Packs 08 and 09.
"""
import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
V2 = os.path.normpath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(V2, "06_Characters", "Source_Scripts"))
sys.path.insert(0, os.path.join(V2, "Source_Scripts"))
from chr_tex import ALL_RAMPS, Atlas, P  # noqa: E402

W = 256


def C(ramp, k):
    """palette index, level clamped to the ramp"""
    return P(ramp, int(max(0, min(len(ALL_RAMPS[ramp]) - 1, k))))


SW = [  # name, ramp, level, style
    ("paint_sedan", "paint_blue", 2, "paint"), ("paint_green", "paint_green", 2, "paint"), ("paint_beige", "stone_warm", 3, "paint"),
    ("paint_black", "paint_black", 2, "paint"), ("paint_white", "paint_white", 3, "paint"), ("paint_pickup", "paint_red", 1, "paint"),
    ("paint_van", "paint_white", 4, "paint"), ("trim_black", "paint_black", 1, "plastic"), ("trim_gray", "concrete", 2, "plastic"),
    ("chrome", "metal", 4, "chrome"), ("steel", "metal", 3, "brushed"), ("steel_dark", "metal", 1, "brushed"),
    ("underside", "metal", 0, "rust"), ("rust", "rust", 2, "rust"), ("glass", "glass", 3, "glass"), ("mirror", "reflect", 2, "glass"),
    ("rubber", "rubber", 1, "plastic"), ("tread", "rubber", 1, "tread"), ("sidewall", "rubber", 1, "sidewall"), ("rim_steel", "metal", 2, "brushed"),
    ("fabric_seat", "upholstery", 2, "weave"), ("fabric_gray", "concrete", 2, "weave"), ("vinyl_black", "paint_black", 1, "leather"),
    ("carpet", "asphalt", 2, "weave"), ("headliner", "drywall", 3, "paper"), ("dash", "plastic", 1, "plastic"), ("bedliner", "paint_black", 2, "knurl"),
    ("plywood", "wood_light", 2, "grain"), ("cargo_wall", "concrete", 3, "brushed"), ("engine", "metal", 1, "rust"), ("wheelwell", "ink", 1, "flat"),
    ("reflector_red", "paint_red", 3, "plastic"), ("gascan_red", "paint_red", 2, "plastic"), ("amber", "sign_yellow", 3, "plastic"),
    ("lens_white", "glow", 2, "lens"), ("lens_red", "paint_red", 3, "lens"), ("lens_blue", "paint_blue", 4, "lens"), ("lens_amber", "road_yellow", 3, "lens"),
    ("pedal", "rubber", 2, "knurl"), ("dust", "soil", 3, "rust"), ("bulb_dark", "paint_black", 3, "lens"), ("paint_black_flat", "paint_black", 1, "flat"),
]
SWATCH = {n: (16 * (k % 16), 16 * (k // 16), 16, 16) for k, (n, *_r) in enumerate(SW)}
PAINTS = [n for n, _r, _k, st in SW if st == "paint"]

DECAL = {   # name: (x, y, w, h)
    "headlight": (0, 48, 24, 12), "taillight": (24, 48, 24, 12), "grille": (48, 48, 40, 12), "plate": (88, 48, 32, 16),
    "plate_police": (120, 48, 32, 16), "cluster": (152, 48, 40, 16), "stack": (192, 48, 16, 24), "doorpanel": (208, 48, 32, 32),
    "vent": (240, 48, 16, 8), "shifter": (240, 56, 16, 8), "hubcap": (0, 64, 16, 16), "rim_face": (16, 64, 16, 16),
    "police_door": (32, 64, 64, 16), "police_small": (96, 64, 56, 8), "police_roof": (152, 72, 24, 16), "lightbar": (96, 72, 48, 8),
    "van_brand": (0, 80, 96, 32), "van_rear": (96, 80, 56, 16), "engine": (152, 88, 32, 32), "crack": (184, 80, 32, 32),
    "gascan_label": (216, 80, 24, 16), "seat": (64, 112, 16, 16), "bench": (80, 112, 32, 16), "taillight_tall": (112, 112, 8, 24),
    "tailgate": (0, 128, 64, 16), "badge": (64, 128, 24, 8), "glovebox": (88, 128, 24, 12),
}

FONT = {  # 3x5 glyphs (Pack 08 font + J, Q)
    "A": "010101111101101", "B": "110101110101110", "C": "011100100100011", "D": "110101101101110", "E": "111100110100111",
    "F": "111100110100100", "G": "011100101101011", "H": "101101111101101", "I": "111010010010111", "J": "001001001101010",
    "K": "101110100110101", "L": "100100100100111", "M": "101111111101101", "N": "110101101101101", "O": "010101101101010",
    "P": "110101110100100", "Q": "010101101110011", "R": "110101110101101", "S": "011100010001110", "T": "111010010010010",
    "U": "101101101101111", "V": "101101101101010", "W": "101101111111101", "X": "101101010101101", "Y": "101101010010010",
    "Z": "111001010100111", "0": "111101101101111", "1": "010110010010111", "2": "110001010100111", "3": "110001010001110",
    "4": "101101111001001", "5": "111100110001110", "6": "011100111101111", "7": "111001010010010", "8": "111101111101111",
    "9": "111101111001110", "-": "000000111000000", ".": "000000000000010", "/": "001001010100100",
}


def R(name):
    x, y, w, h = SWATCH.get(name) or DECAL[name]
    return (x / W, y / W, (x + w) / W, (y + h) / W)


def text(at, s, x, y, v, scale=1):
    cx = x
    for ch in s.upper():
        g = FONT.get(ch)
        if g:
            for k, b in enumerate(g):
                if b == "1":
                    at.rect(cx + (k % 3) * scale, y + (k // 3) * scale, scale, scale, v)
        cx += 4 * scale
    return cx


def text_w(s, scale=1):
    return len(s) * 4 * scale - scale


def swatch(at, name, ramp, k, style):
    x, y, w, h = SWATCH[name]
    rng = at.rng
    at.rect(x, y, w, h, C(ramp, k))
    if style == "paint":            # smooth automotive paint: soft top highlight, faint orange-peel, 2 tiny scratches
        at.rect(x, y + 2, w, 2, C(ramp, k + 1))
        at.rect(x, y + h - 3, w, 3, C(ramp, k - 1))
        for _ in range(6):
            at.px(x + rng.integers(0, w), y + rng.integers(4, h - 3), C(ramp, k + int(rng.choice([-1, 1]))))
        for _ in range(2):
            sx, sy = rng.integers(1, w - 5), rng.integers(5, h - 4)
            for i in range(rng.integers(2, 5)):
                at.px(x + sx + i, y + sy + (i // 2), C(ramp, k + 1))
        return
    if style == "brushed":
        for j in range(h):
            if rng.random() < 0.45:
                L, s0 = rng.integers(3, 10), rng.integers(0, w)
                for i in range(L):
                    at.px(x + (s0 + i) % w, y + j, C(ramp, k + (1 if j % 3 else -1)))
    elif style == "chrome":
        for j in range(h):
            at.rect(x, y + j, w, 1, C(ramp, k + (1 if j < h // 3 else 0 if j < 2 * h // 3 else -2)))
        at.rect(x + 2, y + 2, w - 6, 1, C(ramp, k + 2))
    elif style == "grain":
        for j in range(h):
            off = int(2 * math.sin(j * 0.7 + rng.random()))
            for i in range(w):
                if (i + off) % 5 == 0:
                    at.px(x + i, y + j, C(ramp, k - 1))
    elif style == "rust":
        for _ in range(34):
            at.rect(x + rng.integers(0, w - 1), y + rng.integers(0, h - 1), rng.integers(1, 3), rng.integers(1, 3),
                    C(ramp, k + int(rng.choice([-1, 1, 1]))))
    elif style == "knurl":
        for j in range(h):
            for i in range(w):
                if (i + j) % 4 == 0 or (i - j) % 4 == 0:
                    at.px(x + i, y + j, C(ramp, k + 1))
    elif style == "leather":
        for _ in range(26):
            at.px(x + rng.integers(0, w), y + rng.integers(0, h), C(ramp, k - 1))
        for i in range(0, w, 2):
            at.px(x + i, y + 3, C(ramp, k + 2))
    elif style == "weave":
        for j in range(h):
            for i in range(w):
                if (i % 2 == 0) != (j % 2 == 0):
                    at.px(x + i, y + j, C(ramp, k - 1 if (i // 2 + j) % 3 else k))
    elif style == "paper":
        for _ in range(10):
            at.px(x + rng.integers(0, w), y + rng.integers(0, h), C(ramp, k - 1))
    elif style == "glass":
        for j in range(h):              # sky-to-ground gradient + diagonal glint
            at.rect(x, y + j, w, 1, C(ramp, k + (1 if j < 5 else 0 if j < 11 else -1)))
        for i in range(5):
            at.px(x + 3 + i, y + 9 - i, C(ramp, k + 2))
            at.px(x + 4 + i, y + 9 - i, C(ramp, k + 2))
    elif style == "lens":
        for j in range(h):
            for i in range(w):
                if (i // 3 + j // 3) % 2 == 0:
                    at.px(x + i, y + j, C(ramp, k - 1))
        at.rect(x + 2, y + 2, 4, 2, C(ramp, k + 1))
    elif style == "tread":             # chevron blocks along the circumference (u)
        for j in range(h):
            for i in range(w):
                if (i + abs(j - h // 2)) % 6 < 2:
                    at.px(x + i, y + j, C(ramp, k - 1))
        at.rect(x, y, w, 1, C(ramp, k + 1))
        at.rect(x, y + h - 1, w, 1, C(ramp, k + 1))
    elif style == "sidewall":
        at.rect(x, y + 3, w, 1, C(ramp, k + 1))
        for i in range(0, w, 4):
            at.px(x + i, y + 7, C(ramp, k + 2))
    elif style == "plastic":
        at.rect(x + 1, y + 1, w - 4, 2, C(ramp, k + 1))
        for _ in range(4):
            at.px(x + rng.integers(0, w), y + rng.integers(0, h), C(ramp, k - 1))
    # 'flat' = solid


def frame(at, rect, v):
    x, y, w, h = rect
    at.rect(x, y, w, 1, v)
    at.rect(x, y + h - 1, w, 1, v)
    at.rect(x, y, 1, h, v)
    at.rect(x + w - 1, y, 1, h, v)


def disc(at, cx, cy, r, v):
    for j in range(int(cy - r), int(cy + r) + 1):
        for i in range(int(cx - r), int(cx + r) + 1):
            if (i - cx + 0.5) ** 2 + (j - cy + 0.5) ** 2 <= r * r:
                at.px(i, j, v)


def decals(at):
    D = DECAL
    # headlight unit: chrome bezel, white lens, inner reflector bowls, amber corner
    x, y, w, h = D["headlight"]
    at.rect(x, y, w, h, C("metal", 3))
    at.rect(x + 1, y + 1, w - 2, h - 2, C("glow", 3))
    disc(at, x + 7, y + 6, 3.6, C("glow", 1))
    disc(at, x + 7, y + 6, 1.6, C("glow", 3))
    disc(at, x + 15, y + 6, 2.6, C("glow", 1))
    at.rect(x + 19, y + 2, 4, h - 4, C("road_yellow", 3))
    at.rect(x + 2, y + 2, 8, 1, C("paint_white", 4))
    # taillight: red with an amber turn strip and white reverse lens
    x, y, w, h = D["taillight"]
    at.rect(x, y, w, h, C("paint_black", 1))
    at.rect(x + 1, y + 1, 14, h - 2, C("paint_red", 3))
    at.rect(x + 15, y + 1, 4, h - 2, C("road_yellow", 3))
    at.rect(x + 19, y + 1, 4, h - 2, C("glow", 3))
    for i in range(x + 2, x + 15, 3):
        at.rect(i, y + 2, 1, h - 4, C("paint_red", 2))
    # grille: dark slats, chrome surround, small round emblem
    x, y, w, h = D["grille"]
    at.rect(x, y, w, h, C("metal", 4))
    at.rect(x + 1, y + 1, w - 2, h - 2, C("paint_black", 0))
    for j in range(y + 2, y + h - 1, 2):
        at.rect(x + 2, j, w - 4, 1, C("paint_black", 2))
    disc(at, x + w / 2, y + h / 2, 2.6, C("metal", 4))
    # licence plates (fictional): white, blue border, Greyhaven state stripe
    for nm, s in (("plate", "4KJ-219"), ("plate_police", "GHPD-07")):
        x, y, w, h = D[nm]
        at.rect(x, y, w, h, C("paint_white", 4))
        frame(at, D[nm], C("paint_navy", 2))
        at.rect(x + 2, y + 2, w - 4, 2, C("paint_navy", 2) if nm == "plate" else C("paint_red", 2))
        text(at, s, x + (w - text_w(s)) // 2, y + 7, C("paint_navy", 1))
    # instrument cluster: speedo + tach dials, fuel / temp bars, needles
    x, y, w, h = D["cluster"]
    at.rect(x, y, w, h, C("paint_black", 0))
    for cx, r in ((x + 12, 6.5), (x + 28, 6.5)):
        disc(at, cx, y + 8, r, C("paint_black", 2))
        for a in range(0, 360, 30):
            if 30 <= a <= 330:
                at.px(cx + r * 0.8 * math.sin(math.radians(a + 180)), y + 8 - r * 0.8 * math.cos(math.radians(a + 180)) * -1, C("glow", 3))
        for t in range(1, 6):
            at.px(cx - t * 0.7, y + 8 - t * 0.5, C("paint_orange", 3))
    at.rect(x + 19, y + 3, 2, 10, C("paint_black", 2))
    at.rect(x + 19, y + 8, 2, 5, C("paint_green", 3))
    at.rect(x + 36, y + 3, 2, 10, C("paint_black", 2))
    at.rect(x + 36, y + 6, 2, 7, C("glow", 2))
    # centre stack: vents, radio with display, climate knobs
    x, y, w, h = D["stack"]
    at.rect(x, y, w, h, C("plastic", 1))
    for j in range(y + 1, y + 6, 2):
        at.rect(x + 2, j, 12, 1, C("paint_black", 0))
    at.rect(x + 2, y + 8, 12, 6, C("paint_black", 1))
    at.rect(x + 4, y + 9, 8, 2, C("paint_green", 3))
    for i in (x + 3, x + 7, x + 11):
        at.rect(i, y + 12, 2, 1, C("plastic", 3))
    for cx in (x + 4, x + 8, x + 12):
        disc(at, cx, y + 19, 1.6, C("plastic", 3))
    # door card: upholstered upper panel, armrest, pull handle, window crank, speaker grille, map pocket
    x, y, w, h = D["doorpanel"]
    at.rect(x, y, w, h, C("plastic", 1))
    at.rect(x + 1, y + 1, w - 2, 10, C("upholstery", 2))
    for i in range(x + 2, x + w - 2, 2):
        at.px(i, y + 6, C("upholstery", 1))
    at.rect(x, y + 12, w, 3, C("plastic", 2))
    at.rect(x + 20, y + 4, 6, 3, C("metal", 4))
    disc(at, x + 8, y + 20, 2.5, C("plastic", 3))
    at.rect(x + 8, y + 19, 5, 2, C("plastic", 3))
    disc(at, x + 22, y + 23, 4, C("paint_black", 1))
    for j in range(-3, 4, 2):
        at.rect(x + 19, y + 23 + j, 7, 1, C("paint_black", 0))
    at.rect(x + 2, y + h - 4, w - 4, 3, C("plastic", 0))
    # vent, shifter (PRNDL)
    x, y, w, h = D["vent"]
    at.rect(x, y, w, h, C("plastic", 2))
    for i in range(x + 1, x + w - 1, 2):
        at.rect(i, y + 1, 1, h - 2, C("paint_black", 0))
    x, y, w, h = D["shifter"]
    at.rect(x, y, w, h, C("paint_black", 1))
    for k, ch in enumerate("PRNDL"):
        at.px(x + 2 + k * 3, y + 3, C("glow", 3 if ch == "P" else 1))
    # hubcap: silver disc, 8 slots, centre badge; outside the circle = tyre rubber
    x, y, w, h = D["hubcap"]
    at.rect(x, y, w, h, C("rubber", 1))
    disc(at, x + 8, y + 8, 7.4, C("metal", 3))
    disc(at, x + 8, y + 8, 6.0, C("metal", 4))
    for a in range(0, 360, 45):
        for t in (3.2, 4.0, 4.8):
            at.px(x + 8 + t * math.cos(math.radians(a)) - 0.5, y + 8 + t * math.sin(math.radians(a)) - 0.5, C("metal", 1))
    disc(at, x + 8, y + 8, 1.8, C("metal", 2))
    # bare steel rim: painted black wheel with lug holes
    x, y, w, h = D["rim_face"]
    at.rect(x, y, w, h, C("rubber", 1))
    disc(at, x + 8, y + 8, 7.4, C("metal", 1))
    disc(at, x + 8, y + 8, 4.6, C("metal", 2))
    for a in range(0, 360, 72):
        at.px(x + 8 + 3.2 * math.cos(math.radians(a)) - 0.5, y + 8 + 3.2 * math.sin(math.radians(a)) - 0.5, C("paint_black", 0))
    for a in range(0, 360, 60):
        at.rect(x + 8 + 5.8 * math.cos(math.radians(a)) - 1, y + 8 + 5.8 * math.sin(math.radians(a)) - 1, 2, 2, C("paint_black", 1))
    disc(at, x + 8, y + 8, 1.3, C("metal", 4))
    # Greyhaven Police markings (fictional): big POLICE + gold stripe; small GREYHAVEN PD; roof number
    x, y, w, h = D["police_door"]
    at.rect(x, y, w, h, C("paint_white", 3))
    at.rect(x, y + 1, w, 1, C("sign_yellow", 3))
    at.rect(x, y + h - 2, w, 1, C("sign_yellow", 3))
    text(at, "POLICE", x + (w - text_w("POLICE", 2)) // 2, y + 3, C("paint_navy", 1), 2)
    x, y, w, h = D["police_small"]
    at.rect(x, y, w, h, C("paint_white", 3))
    text(at, "GREYHAVEN PD", x + (w - text_w("GREYHAVEN PD")) // 2, y + 2, C("paint_navy", 1))
    x, y, w, h = D["police_roof"]
    at.rect(x, y, w, h, C("paint_white", 3))
    text(at, "07", x + (w - text_w("07", 2)) // 2, y + 3, C("paint_black", 0), 2)
    x, y, w, h = D["lightbar"]
    at.rect(x, y, w, h, C("paint_black", 1))
    at.rect(x + 1, y + 1, 21, h - 2, C("paint_red", 3))
    at.rect(x + 22, y + 1, 4, h - 2, C("glow", 3))
    at.rect(x + 26, y + 1, 21, h - 2, C("paint_blue", 4))
    for i in range(x + 3, x + 46, 5):
        at.rect(i, y + 2, 1, h - 4, C("paint_black", 2))
    # Harlow Bakery livery (fictional local business)
    x, y, w, h = D["van_brand"]
    at.rect(x, y, w, h, C("paint_white", 4))
    at.rect(x, y + h - 6, w, 3, C("paint_red", 2))
    at.rect(x, y + h - 3, w, 2, C("sign_yellow", 3))
    text(at, "HARLOW", x + 24, y + 3, C("paint_red", 1), 3)
    text(at, "BAKERY", x + 24 + (text_w("HARLOW", 3) - text_w("BAKERY", 2)) // 2, y + 20, C("paint_navy", 1), 1 + 1)
    disc(at, x + 11, y + 13, 8.5, C("wood_warm", 3))           # round loaf
    disc(at, x + 11, y + 11, 6.5, C("wood_warm", 4))
    for i in (-4, 0, 4):
        at.rect(x + 10 + i, y + 8, 1, 7, C("wood_warm", 2))
    x, y, w, h = D["van_rear"]
    at.rect(x, y, w, h, C("paint_white", 4))
    text(at, "HARLOW BAKERY", x + (w - text_w("HARLOW BAKERY")) // 2, y + 3, C("paint_red", 1))
    text(at, "FRESH DAILY", x + (w - text_w("FRESH DAILY")) // 2, y + 10, C("paint_navy", 1))
    # engine bay: block, valve cover, round air filter, battery, hoses
    x, y, w, h = D["engine"]
    at.rect(x, y, w, h, C("metal", 0))
    at.rect(x + 4, y + 6, 18, 20, C("metal", 2))
    at.rect(x + 6, y + 8, 14, 16, C("paint_red", 1))
    for j in range(y + 10, y + 23, 4):
        at.rect(x + 8, j, 10, 1, C("paint_red", 0))
    disc(at, x + 13, y + 16, 5, C("paint_black", 2))
    disc(at, x + 13, y + 16, 2, C("metal", 3))
    at.rect(x + 23, y + 3, 7, 9, C("paint_black", 2))
    at.rect(x + 24, y + 2, 2, 1, C("paint_red", 3))
    at.rect(x + 23, y + 18, 2, 10, C("rubber", 0))
    # cracked glass: glass base + spider-web cracks
    x, y, w, h = D["crack"]
    for j in range(h):
        at.rect(x, y + j, w, 1, C("glass", 4 if j < 10 else 3 if j < 22 else 2))
    cx, cy = x + 11, y + 13
    rng = at.rng
    for a in range(0, 360, 40):
        L = 6 + rng.integers(0, 12)
        for t in range(L):
            at.px(cx + t * math.cos(math.radians(a + rng.integers(-6, 7))), cy + t * math.sin(math.radians(a)), C("paint_white", 4))
    for r in (4, 8):
        for a in range(0, 360, 12):
            at.px(cx + r * math.cos(math.radians(a)), cy + r * math.sin(math.radians(a)), C("paint_white", 3))
    # gas can label, seat panels, bench, tall taillight, pickup tailgate, model badge, glovebox
    x, y, w, h = D["gascan_label"]
    at.rect(x, y, w, h, C("paint_red", 2))
    text(at, "GAS", x + (w - text_w("GAS", 1)) // 2, y + 3, C("sign_yellow", 3))
    at.rect(x + 2, y + 11, w - 4, 2, C("sign_yellow", 3))
    x, y, w, h = D["seat"]
    at.rect(x, y, w, h, C("upholstery", 2))
    for i in (x + 4, x + 11):
        at.rect(i, y, 1, h, C("upholstery", 1))
    frame(at, D["seat"], C("upholstery", 1))
    x, y, w, h = D["bench"]
    at.rect(x, y, w, h, C("concrete", 2))
    for i in range(x + 5, x + w, 6):
        at.rect(i, y, 1, h, C("concrete", 1))
    frame(at, D["bench"], C("concrete", 1))
    x, y, w, h = D["taillight_tall"]
    at.rect(x, y, w, h, C("paint_black", 1))
    at.rect(x + 1, y + 1, w - 2, 14, C("paint_red", 3))
    at.rect(x + 1, y + 15, w - 2, 4, C("road_yellow", 3))
    at.rect(x + 1, y + 19, w - 2, 4, C("glow", 3))
    x, y, w, h = D["tailgate"]
    at.rect(x, y, w, h, C("paint_red", 1))
    at.rect(x, y + 2, w, 2, C("paint_red", 2))
    text(at, "GRANGER", x + (w - text_w("GRANGER", 2)) // 2, y + 5, C("metal", 4), 2)
    x, y, w, h = D["badge"]
    at.rect(x, y, w, h, C("paint_blue", 2))
    text(at, "VALE", x + (w - text_w("VALE")) // 2, y + 2, C("metal", 4))
    x, y, w, h = D["glovebox"]
    at.rect(x, y, w, h, C("plastic", 1))
    frame(at, D["glovebox"], C("plastic", 0))
    at.rect(x + w // 2 - 3, y + 2, 6, 2, C("plastic", 3))


def weather(at):
    """dusty / rusty copy: dust settles towards the bottom of every swatch, rust blooms on paint, glass goes milky"""
    rng = np.random.default_rng(505)
    a = at.a
    out = a.copy()
    dust = [C("soil", 3), C("soil", 2), C("dead", 3), C("dead", 2)]
    for n, (x, y, w, h) in list(SWATCH.items()) + list(DECAL.items()):
        for j in range(h):
            p = 0.05 + 0.25 * (j / h)
            if n in ("glass", "crack", "mirror"):
                p += 0.25
            m = rng.random(w) < p
            for i in np.nonzero(m)[0]:
                out[y + j, x + i] = dust[rng.integers(0, len(dust))]
        if n in PAINTS or n in ("tailgate", "police_door", "van_brand", "van_rear"):
            for _ in range(3 if n in PAINTS else 2):
                cx, cy = x + rng.integers(1, w - 2), y + rng.integers(h // 2, h - 1)
                for _ in range(6):
                    xx, yy = cx + rng.integers(-2, 3), cy + rng.integers(-1, 2)
                    if x <= xx < x + w and y <= yy < y + h:
                        out[yy, xx] = C("rust", int(rng.integers(1, 4)))
    at.a = out


def build(path, weathered_path):
    at = Atlas("vehicle_atlas")
    for n, ramp, k, st in SW:
        swatch(at, n, ramp, k, st)
    decals(at)
    at.image().save(path, format="PNG", optimize=True)
    weather(at)
    at.image().save(weathered_path, format="PNG", optimize=True)
