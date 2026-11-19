"""Pack 08 pixel-art atlas: T_Inv_Atlas.png (256x256), shared by every inventory item (one material, one draw call).

Rows 0-63   : 64 material swatches (16x16): metals, plastics, woods, rubber, fabrics, paper, glass ... each
              painted as a small hand-made texture (brushed streaks, grain, weave), lit from the top-left.
Rows 64-255 : decals / printed surfaces - all ORIGINAL artwork (no real brands): the Greyhaven town map
              (drawn from the Pack 02 road network), newspaper, missing-person poster, labels for food,
              water, medicine, batteries, tapes, the access card, photographs, notes, emblem relief ...
Every pixel comes from the Greyhaven palette (Pack 01 ramps + the Pack 06 character ramps).
"""
import json
import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
V2 = os.path.normpath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(V2, "06_Characters", "Source_Scripts"))
sys.path.insert(0, os.path.join(V2, "Source_Scripts"))
from chr_tex import Atlas, P  # noqa: E402

W = 256
SW = [  # swatch name: (ramp, base level, style)
    ("plastic_black", "paint_black", 2, "plastic"), ("plastic_gray", "concrete", 3, "plastic"), ("plastic_red", "paint_red", 2, "plastic"),
    ("plastic_yellow", "sign_yellow", 3, "plastic"), ("plastic_green", "paint_green", 2, "plastic"), ("plastic_blue", "paint_blue", 2, "plastic"),
    ("plastic_orange", "paint_orange", 2, "plastic"), ("plastic_white", "paint_white", 3, "plastic"), ("steel", "metal", 3, "brushed"),
    ("steel_dark", "metal", 1, "brushed"), ("chrome", "metal", 4, "chrome"), ("brass", "sign_yellow", 2, "brushed"), ("rust", "rust", 2, "rust"),
    ("copper", "terracotta", 3, "brushed"), ("gunmetal", "paint_black", 3, "brushed"), ("aluminum", "concrete", 5, "brushed"),
    ("wood_light", "wood_light", 2, "grain"), ("wood_dark", "wood_dark", 2, "grain"), ("wood_handle", "wood_warm", 3, "grain"),
    ("rubber", "rubber", 2, "plastic"), ("rubber_grip", "rubber", 2, "knurl"), ("leather_brown", "leather", 3, "leather"),
    ("leather_black", "paint_black", 1, "leather"), ("canvas_olive", "upholstery", 2, "weave"), ("canvas_red", "paint_red", 2, "weave"),
    ("canvas_navy", "paint_navy", 2, "weave"), ("fabric_white", "paint_white", 3, "weave"), ("paper_white", "road_white", 2, "paper"),
    ("paper_yellow", "tile_cream", 3, "paper"), ("paper_old", "lino", 2, "paper"), ("cardboard", "cardboard", 2, "paper"),
    ("glass_lens", "glass", 3, "glass"), ("glass_clear", "glass", 4, "glass"), ("lcd", "paint_green", 3, "lcd"), ("gold", "sign_yellow", 3, "chrome"),
    ("rope", "cardboard", 3, "rope"), ("tape_gray", "concrete", 4, "tape"), ("bandage", "tile_cream", 4, "weave"), ("foam", "paint_navy", 1, "plastic"),
    ("axe_red", "paint_red", 3, "worn"), ("ink_blue", "paint_navy", 3, "plastic"), ("cork", "cardboard", 3, "rust"), ("felt_red", "paint_red", 1, "weave"),
    ("plastic_dark_green", "door_green", 2, "plastic"), ("bulb", "glow", 2, "glass"), ("steel_worn", "metal", 2, "worn"),
    ("metal_strange", "corrupt", 3, "brushed"), ("stone_dark", "ash", 1, "rust"), ("teal_plastic", "tile_teal", 2, "plastic"),
    ("purple_cover", "carpet", 2, "leather"), ("denim", "denim", 3, "weave"), ("cream_plastic", "tile_cream", 3, "plastic"),
]
SWATCH = {}
for k, (n, *_r) in enumerate(SW):
    SWATCH[n] = (16 * (k % 16), 16 * (k // 16), 16, 16)

DECAL = {   # name: (x, y, w, h)
    "map": (0, 64, 64, 64), "newspaper": (64, 64, 48, 64), "poster": (112, 64, 40, 56), "note": (152, 64, 32, 32),
    "notebook_cover": (184, 64, 24, 32), "diary_cover": (208, 64, 24, 32), "page_edge": (232, 64, 24, 16), "envelope": (232, 80, 24, 32),
    "photo": (152, 96, 28, 24), "photo_torn": (180, 96, 28, 24), "can_label": (0, 128, 64, 24), "can_label2": (0, 152, 64, 24),
    "water_label": (64, 128, 48, 16), "med_label": (64, 144, 32, 16), "pill_box": (96, 144, 32, 24), "snack": (112, 120, 48, 16),
    "battery": (160, 120, 32, 16), "battery9": (160, 200, 16, 16), "cassette": (208, 112, 32, 16), "vhs": (64, 168, 48, 16),
    "card": (120, 200, 32, 20), "firstaid": (144, 136, 16, 16), "radio_face": (160, 136, 24, 24), "grille": (184, 136, 16, 16),
    "watch_face": (200, 136, 16, 16), "ammo_label": (216, 128, 40, 16), "tape_side": (216, 144, 16, 16), "fuse": (232, 144, 24, 16),
    "switch": (176, 200, 24, 24), "emblem": (136, 160, 32, 32), "artifact": (168, 160, 32, 32), "padlock": (200, 160, 16, 16),
    "lantern_face": (216, 160, 24, 24), "bag_patch": (240, 160, 16, 16), "keytag": (0, 176, 24, 16), "fob": (24, 176, 16, 16),
    "flash_lens": (40, 176, 16, 16), "knife_side": (112, 184, 24, 8), "bandage_end": (0, 192, 16, 16), "wallet_inside": (16, 192, 32, 16),
    "stamp": (48, 192, 16, 16), "tape_reel": (64, 184, 16, 16), "evidence_label": (80, 184, 32, 16),
}

FONT = {
    "A": "010101111101101", "B": "110101110101110", "C": "011100100100011", "D": "110101101101110", "E": "111100110100111",
    "F": "111100110100100", "G": "011100101101011", "H": "101101111101101", "I": "111010010010111", "K": "101110100110101",
    "L": "100100100100111", "M": "101111111101101", "N": "110101101101101", "O": "010101101101010", "P": "110101110100100",
    "R": "110101110101101", "S": "011100010001110", "T": "111010010010010", "U": "101101101101111", "V": "101101101101010",
    "W": "101101111111101", "X": "101101010101101", "Y": "101101010010010", "Z": "111001010100111", "0": "111101101101111", "1": "010110010010111",
    "2": "110001010100111", "3": "110001010001110", "4": "101101111001001", "5": "111100110001110", "6": "011100111101111",
    "7": "111001010010010", "8": "111101111101111", "9": "111101111001110", "-": "000000111000000", ".": "000000000000010",
    "+": "000010111010000", "/": "001001010100100", "!": "010010010000010", "?": "110001010000010",
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
                    for a in range(scale):
                        for c in range(scale):
                            at.px(cx + (k % 3) * scale + a, y + (k // 3) * scale + c, v)
        cx += 4 * scale
    return cx


def bevel(at, rect, ramp, k):
    x, y, w, h = rect
    at.rect(x, y, w, 1, P(ramp, k + 1))
    at.rect(x, y, 1, h, P(ramp, k + 1))
    at.rect(x, y + h - 1, w, 1, P(ramp, max(k - 1, 0)))
    at.rect(x + w - 1, y, 1, h, P(ramp, max(k - 1, 0)))


def swatch(at, name, ramp, k, style):
    x, y, w, h = SWATCH[name]
    rng = at.rng
    at.rect(x, y, w, h, P(ramp, k))
    if style == "brushed":
        for j in range(h):
            if rng.random() < 0.45:
                L = rng.integers(3, 10)
                s = rng.integers(0, w)
                for i in range(L):
                    at.px(x + (s + i) % w, y + j, P(ramp, k + (1 if j % 3 else -1)))
    elif style == "chrome":
        for j in range(h):
            at.rect(x, y + j, w, 1, P(ramp, k + (1 if j < h // 3 else 0 if j < 2 * h // 3 else -1)))
        at.rect(x + 2, y + 2, w - 8, 1, P(ramp, k + 2))
    elif style == "grain":
        for j in range(h):
            off = int(2 * math.sin(j * 0.7 + rng.random()))
            for i in range(w):
                if (i + off) % 5 == 0:
                    at.px(x + i, y + j, P(ramp, k - 1))
        at.rect(x + rng.integers(2, w - 4), y + rng.integers(2, h - 4), 2, 2, P(ramp, k - 1))
    elif style == "rust":
        for _ in range(34):
            at.rect(x + rng.integers(0, w - 1), y + rng.integers(0, h - 1), rng.integers(1, 3), rng.integers(1, 3),
                    P(ramp, k + int(rng.choice([-1, -1, 1]))))
    elif style == "knurl":
        for j in range(h):
            for i in range(w):
                if (i + j) % 4 == 0 or (i - j) % 4 == 0:
                    at.px(x + i, y + j, P(ramp, k + 1))
    elif style == "leather":
        for _ in range(26):
            at.px(x + rng.integers(0, w), y + rng.integers(0, h), P(ramp, k - 1))
        for i in range(0, w, 2):
            at.px(x + i, y + 2, P(ramp, k + 2))
            at.px(x + i, y + h - 3, P(ramp, k + 2))
    elif style == "weave":
        for j in range(h):
            for i in range(w):
                if (i % 2 == 0) != (j % 2 == 0):
                    at.px(x + i, y + j, P(ramp, k - 1 if (i // 2 + j) % 3 else k))
    elif style == "paper":
        for _ in range(10):
            at.px(x + rng.integers(0, w), y + rng.integers(0, h), P(ramp, k - 1))
    elif style == "glass":
        at.rect(x + 2, y + 2, 5, 2, P(ramp, min(k + 2, 4)))
        at.rect(x + 2, y + 4, 2, 3, P(ramp, min(k + 2, 4)))
        at.rect(x, y + h - 3, w, 3, P(ramp, k - 1))
    elif style == "lcd":
        at.rect(x + 1, y + 1, w - 2, h - 2, P(ramp, k + 1))
        for i in range(3, w - 3, 3):
            at.rect(x + i, y + 5, 2, 5, P(ramp, k - 2))
    elif style == "rope":
        for j in range(h):
            for i in range(w):
                if (i + j * 2) % 6 < 2:
                    at.px(x + i, y + j, P(ramp, k - 1))
                elif (i + j * 2) % 6 == 3:
                    at.px(x + i, y + j, P(ramp, k + 1))
    elif style == "tape":
        for j in range(h):
            for i in range(w):
                if i % 3 == 0 and j % 2 == 0:
                    at.px(x + i, y + j, P(ramp, k - 1))
    elif style == "worn":
        for _ in range(16):
            at.rect(x + rng.integers(0, w - 2), y + rng.integers(0, h - 1), rng.integers(1, 4), 1, P("metal", 3))
    else:  # plastic: soft highlight + a few scuffs
        at.rect(x + 1, y + 1, w - 4, 2, P(ramp, k + 1))
        for _ in range(4):
            at.px(x + rng.integers(0, w), y + rng.integers(0, h), P(ramp, k - 1))
    bevel(at, SWATCH[name], ramp, k)


# ------------------------------------------------------------------ decals
def town_map(at):
    x0, y0, w, h = DECAL["map"]
    at.rect(x0, y0, w, h, P("tile_cream", 4))
    for i in range(0, w, 16):                      # fold creases
        at.rect(x0 + i, y0, 1, h, P("tile_cream", 2))
    at.rect(x0, y0 + h // 2, w, 1, P("tile_cream", 2))
    lay = json.load(open(os.path.join(V2, "02_Town", "Town_Layout", "greyhaven_layout.json")))
    bx0, bz0, bx1, bz1 = lay["bounds"]
    sx = lambda x: x0 + 3 + (x - bx0) / (bx1 - bx0) * (w - 7)
    sz = lambda z: y0 + 3 + (z - bz0) / (bz1 - bz0) * (h - 12)
    for z in lay["zones"]:                          # zones as small blocks
        r = z["rect"]
        col = P("paint_red", 3) if z["id"] == "PLAYER_HOME" else P("sign_green", 2) if z["type"].startswith("residential") else P("concrete", 3)
        at.rect(sx(r[0]), sz(r[1]), max(1, sx(r[2]) - sx(r[0])), max(1, sz(r[3]) - sz(r[1])), col)
    N = lay["nodes"]
    for e in lay["edges"]:
        a, b = N[e[1]], N[e[2]]
        n = 40
        for t in range(n + 1):
            xx = a[0] + (b[0] - a[0]) * t / n
            zz = a[1] + (b[1] - a[1]) * t / n
            at.px(sx(xx), sz(zz), P("paint_black", 2))
    for r in lay["rural"]:
        a = N[r[1]]
        d = {"W": (-1, 0), "E": (1, 0), "N": (0, -1), "S": (0, 1)}.get(r[2], (0, 0))
        for t in range(14):
            at.px(sx(a[0]) + d[0] * t, sz(a[1]) + d[1] * t, P("paint_black", 1))
    at.rect(x0, y0 + h - 8, w, 8, P("paint_navy", 2))
    text(at, "GREYHAVEN", x0 + 2, y0 + h - 7, P("road_white", 3))
    at.px(x0 + w - 6, y0 + 5, P("paint_red", 4))   # "you are here" style mark (generic)
    bevel(at, DECAL["map"], "tile_cream", 3)


def paper(at, name, ramp="road_white", k=3, lines=True, step=3):
    x0, y0, w, h = DECAL[name]
    at.rect(x0, y0, w, h, P(ramp, k))
    if lines:
        rng = at.rng
        for j in range(y0 + 4, y0 + h - 3, step):
            L = rng.integers(w // 2, w - 4)
            for i in range(x0 + 3, x0 + L):
                if rng.random() < 0.8:
                    at.px(i, j, P("paint_navy", 2))
    bevel(at, DECAL[name], ramp, k)


def decals(at):
    town_map(at)
    rng = at.rng
    # newspaper: masthead, columns, a photo box
    x0, y0, w, h = DECAL["newspaper"]
    at.rect(x0, y0, w, h, P("road_white", 2))
    text(at, "GAZETTE", x0 + 10, y0 + 2, P("ink", 0))
    at.rect(x0 + 2, y0 + 9, w - 4, 1, P("ink", 1))
    at.rect(x0 + 3, y0 + 12, 20, 14, P("concrete", 2))
    at.rect(x0 + 6, y0 + 15, 8, 6, P("concrete", 4))
    for col in (x0 + 26, x0 + 3, x0 + 26):
        pass
    for j in range(y0 + 12, y0 + h - 3, 2):
        for c0, c1 in ((x0 + 25, x0 + w - 3), (x0 + 3, x0 + 23)):
            if c0 == x0 + 3 and j < y0 + 28:
                continue
            for i in range(c0, c1):
                if rng.random() < 0.7:
                    at.px(i, j, P("concrete", 1))
    # missing person poster
    x0, y0, w, h = DECAL["poster"]
    at.rect(x0, y0, w, h, P("tile_cream", 4))
    text(at, "MISSING", x0 + 6, y0 + 2, P("paint_red", 2))
    at.rect(x0 + 8, y0 + 10, 24, 22, P("concrete", 3))
    at.rect(x0 + 15, y0 + 13, 10, 10, P("concrete", 5))          # face silhouette (generic, no identity)
    at.rect(x0 + 12, y0 + 23, 16, 9, P("concrete", 5))
    for j in range(y0 + 36, y0 + h - 8, 3):
        for i in range(x0 + 4, x0 + w - 4):
            if rng.random() < 0.75:
                at.px(i, j, P("ink", 1))
    text(at, "CALL", x0 + 12, y0 + h - 7, P("ink", 0))
    bevel(at, DECAL["poster"], "tile_cream", 3)
    paper(at, "note", "tile_cream", 4)
    for j in range(DECAL["note"][1] + 1, DECAL["note"][1] + 31, 6):      # fold lines
        pass
    at.rect(DECAL["note"][0], DECAL["note"][1] + 15, 32, 1, P("tile_cream", 2))
    # notebook / diary covers
    x0, y0, w, h = DECAL["notebook_cover"]
    at.rect(x0, y0, w, h, P("paint_blue", 2))
    at.rect(x0, y0, 3, h, P("paint_blue", 1))
    at.rect(x0 + 7, y0 + 6, 13, 7, P("road_white", 3))
    at.rect(x0 + 9, y0 + 9, 9, 1, P("concrete", 2))
    bevel(at, DECAL["notebook_cover"], "paint_blue", 2)
    x0, y0, w, h = DECAL["diary_cover"]
    at.rect(x0, y0, w, h, P("carpet", 2))
    for i in range(x0 + 2, x0 + w - 2):
        at.px(i, y0 + 2, P("sign_yellow", 2))
        at.px(i, y0 + h - 3, P("sign_yellow", 2))
    at.rect(x0 + 8, y0 + 10, 8, 10, P("sign_yellow", 3))
    at.rect(x0 + 10, y0 + 13, 4, 4, P("carpet", 1))
    bevel(at, DECAL["diary_cover"], "carpet", 2)
    x0, y0, w, h = DECAL["page_edge"]
    for j in range(h):
        at.rect(x0, y0 + j, w, 1, P("road_white", 3 if j % 2 else 2))
    # envelope
    x0, y0, w, h = DECAL["envelope"]
    at.rect(x0, y0, w, h, P("cardboard", 3))
    for i in range(w // 2):
        at.px(x0 + i, y0 + i // 2, P("cardboard", 2))
        at.px(x0 + w - 1 - i, y0 + i // 2, P("cardboard", 2))
    at.rect(x0 + 3, y0 + 14, w - 6, 9, P("road_white", 3))
    text(at, "EV", x0 + 7, y0 + 16, P("paint_red", 2))
    at.rect(x0 + w // 2 - 2, y0 + 5, 4, 3, P("paint_red", 2))     # wax/tape seal
    # photographs (generic street + house scene, no people)
    for nm in ("photo", "photo_torn"):
        x0, y0, w, h = DECAL[nm]
        at.rect(x0, y0, w, h, P("road_white", 3))
        at.rect(x0 + 2, y0 + 2, w - 4, h - 6, P("paint_blue", 3))
        at.rect(x0 + 2, y0 + 13, w - 4, h - 17, P("sign_green", 2))
        at.rect(x0 + 8, y0 + 7, 10, 7, P("paint_white", 3))
        at.rect(x0 + 7, y0 + 5, 12, 2, P("brick_red", 2))
        at.rect(x0 + 12, y0 + 10, 2, 4, P("wood_dark", 2))
        if nm == "photo_torn":
            for j in range(h):
                cut = x0 + w - 4 - int(3 * abs(math.sin(j * 1.3)))
                at.rect(cut, y0 + j, x0 + w - cut, 1, P("ink", 0))
    # cans: two original labels
    for nm, ramp, word in (("can_label", "paint_red", "BEANS"), ("can_label2", "sign_green", "SOUP")):
        x0, y0, w, h = DECAL[nm]
        at.rect(x0, y0, w, h, P(ramp, 2))
        at.rect(x0, y0 + 2, w, 1, P("sign_yellow", 3))
        at.rect(x0, y0 + h - 3, w, 1, P("sign_yellow", 3))
        for rep in (0, 32):
            text(at, word, x0 + rep + 6, y0 + 6, P("paint_white", 4))
            at.rect(x0 + rep + 10, y0 + 13, 10, 5, P("road_white", 3))
            at.rect(x0 + rep + 12, y0 + 14, 6, 3, P(ramp, 1))
    x0, y0, w, h = DECAL["water_label"]
    at.rect(x0, y0, w, h, P("paint_blue", 3))
    text(at, "SPRING", x0 + 10, y0 + 2, P("paint_white", 4))
    for i in range(w):
        at.px(x0 + i, y0 + 10 + int(1.5 * math.sin(i * 0.5)), P("paint_white", 3))
    x0, y0, w, h = DECAL["med_label"]
    at.rect(x0, y0, w, h, P("paint_white", 4))
    at.rect(x0, y0, 6, h, P("paint_orange", 3))
    text(at, "RX", x0 + 9, y0 + 2, P("ink", 0))
    for j in (y0 + 9, y0 + 12):
        at.rect(x0 + 9, j, 18, 1, P("concrete", 2))
    x0, y0, w, h = DECAL["pill_box"]
    at.rect(x0, y0, w, h, P("paint_white", 4))
    at.rect(x0, y0, w, 7, P("paint_navy", 3))
    text(at, "PAIN", x0 + 8, y0 + 1, P("paint_white", 4))
    at.rect(x0 + 3, y0 + 11, 7, 7, P("paint_red", 3))
    at.rect(x0 + 5, y0 + 12, 3, 5, P("paint_white", 4))
    at.rect(x0 + 4, y0 + 13, 5, 3, P("paint_white", 4))
    at.rect(x0 + 13, y0 + 12, 15, 1, P("concrete", 2))
    at.rect(x0 + 13, y0 + 15, 12, 1, P("concrete", 2))
    x0, y0, w, h = DECAL["snack"]
    at.rect(x0, y0, w, h, P("paint_orange", 3))
    for i in range(0, w, 3):
        at.px(x0 + i, y0, P("paint_orange", 1))
        at.px(x0 + i, y0 + h - 1, P("paint_orange", 1))
    text(at, "OAT+", x0 + 10, y0 + 5, P("wood_dark", 1))
    x0, y0, w, h = DECAL["battery"]
    at.rect(x0, y0, w, h, P("paint_black", 2))
    at.rect(x0 + w - 8, y0, 8, h, P("sign_yellow", 3))
    text(at, "1.5V", x0 + 3, y0 + 5, P("sign_yellow", 3))
    x0, y0, w, h = DECAL["battery9"]
    at.rect(x0, y0, w, h, P("paint_navy", 2))
    text(at, "9V", x0 + 4, y0 + 5, P("paint_white", 4))
    # cassette & VHS labels
    x0, y0, w, h = DECAL["cassette"]
    at.rect(x0, y0, w, h, P("tile_cream", 4))
    at.rect(x0, y0 + 2, w, 2, P("paint_orange", 3))
    for j in (y0 + 7, y0 + 10):
        for i in range(x0 + 3, x0 + w - 3):
            if rng.random() < 0.7:
                at.px(i, j, P("paint_navy", 3))
    x0, y0, w, h = DECAL["vhs"]
    at.rect(x0, y0, w, h, P("road_white", 3))
    at.rect(x0, y0, w, 3, P("paint_red", 2))
    for j in (y0 + 7, y0 + 11):
        for i in range(x0 + 4, x0 + w - 6):
            if rng.random() < 0.8:
                at.px(i, j, P("ink", 1))
    # access card
    x0, y0, w, h = DECAL["card"]
    at.rect(x0, y0, w, h, P("paint_white", 4))
    at.rect(x0, y0, w, 5, P("tile_teal", 2))
    text(at, "ACCESS", x0 + 4, y0 + 7, P("ink", 0))
    at.rect(x0 + 3, y0 + 13, 6, 5, P("concrete", 3))
    at.rect(x0 + 12, y0 + 14, 16, 1, P("concrete", 2))
    at.rect(x0 + 12, y0 + 16, 12, 1, P("concrete", 2))
    at.rect(x0 + w - 7, y0 + 7, 5, 4, P("sign_yellow", 3))
    # first-aid cross, radio face, grille, watch face
    x0, y0, w, h = DECAL["firstaid"]
    at.rect(x0, y0, w, h, P("paint_white", 4))
    at.rect(x0 + 6, y0 + 2, 4, 12, P("paint_red", 3))
    at.rect(x0 + 2, y0 + 6, 12, 4, P("paint_red", 3))
    x0, y0, w, h = DECAL["radio_face"]
    at.rect(x0, y0, w, h, P("paint_black", 2))
    at.rect(x0 + 2, y0 + 2, w - 4, 7, P("paint_green", 3))
    text(at, "16", x0 + 4, y0 + 3, P("paint_green", 1))
    for i in range(3):
        for j in range(2):
            at.rect(x0 + 3 + i * 7, y0 + 12 + j * 6, 5, 4, P("concrete", 3))
            at.px(x0 + 3 + i * 7, y0 + 12 + j * 6, P("concrete", 5))
    x0, y0, w, h = DECAL["grille"]
    at.rect(x0, y0, w, h, P("paint_black", 1))
    for j in range(1, h, 3):
        at.rect(x0 + 1, y0 + j, w - 2, 1, P("paint_black", 3))
    x0, y0, w, h = DECAL["watch_face"]
    at.rect(x0, y0, w, h, P("road_white", 3))
    for a in range(12):
        t = a / 12 * 2 * math.pi
        at.px(x0 + 8 + 6 * math.sin(t), y0 + 8 - 6 * math.cos(t), P("ink", 1))
    for t in range(5):                                  # hands at 6:42 (bible: the protagonist wakes at 6:42 PM)
        at.px(x0 + 8 + t * math.sin(math.radians(252 + 21)) * 0.9, y0 + 8 - t * math.cos(math.radians(252 + 21)) * 0.9, P("ink", 0))
    for t in range(4):
        at.px(x0 + 8 + t * math.sin(math.radians(201)) * 0.8, y0 + 8 - t * math.cos(math.radians(201)) * 0.8, P("ink", 0))
    # ammo box label, tape side, fuse, switch, padlock, lantern, patch, key tag, fob, lens
    x0, y0, w, h = DECAL["ammo_label"]
    at.rect(x0, y0, w, h, P("paint_green", 2))
    at.rect(x0, y0, w, 3, P("sign_yellow", 3))
    text(at, "AMMO", x0 + 12, y0 + 6, P("sign_yellow", 3))
    x0, y0, w, h = DECAL["tape_side"]
    at.rect(x0, y0, w, h, P("concrete", 4))
    for r_ in (7, 5):
        for a in range(24):
            t = a / 24 * 2 * math.pi
            at.px(x0 + 8 + r_ * math.cos(t), y0 + 8 + r_ * math.sin(t), P("concrete", 2))
    at.rect(x0 + 5, y0 + 5, 6, 6, P("cardboard", 3))
    x0, y0, w, h = DECAL["fuse"]
    at.rect(x0, y0, w, h, P("glass", 4))
    at.rect(x0, y0, 4, h, P("metal", 4))
    at.rect(x0 + w - 4, y0, 4, h, P("metal", 4))
    at.rect(x0 + 4, y0 + 7, w - 8, 1, P("metal", 2))
    text(at, "30A", x0 + 7, y0 + 1, P("ink", 1))
    x0, y0, w, h = DECAL["switch"]
    at.rect(x0, y0, w, h, P("paint_white", 3))
    at.rect(x0 + 8, y0 + 4, 8, 16, P("paint_white", 4))
    at.rect(x0 + 10, y0 + 6, 4, 6, P("paint_white", 2))
    text(at, "ON", x0 + 7, y0 + 0, P("concrete", 2))
    x0, y0, w, h = DECAL["padlock"]
    at.rect(x0, y0, w, h, P("sign_yellow", 2))
    at.rect(x0 + 6, y0 + 5, 4, 6, P("ink", 0))
    at.rect(x0 + 7, y0 + 10, 2, 3, P("ink", 0))
    x0, y0, w, h = DECAL["lantern_face"]
    at.rect(x0, y0, w, h, P("glow", 2))
    at.rect(x0 + 6, y0 + 4, 12, 16, P("glow", 3))
    at.rect(x0 + 9, y0 + 7, 6, 10, P("glow", 3))
    x0, y0, w, h = DECAL["bag_patch"]
    at.rect(x0, y0, w, h, P("sign_yellow", 3))
    at.rect(x0 + 3, y0 + 3, 10, 10, P("paint_navy", 2))
    at.rect(x0 + 6, y0 + 5, 4, 6, P("sign_yellow", 3))
    x0, y0, w, h = DECAL["keytag"]
    at.rect(x0, y0, w, h, P("paint_red", 3))
    at.rect(x0 + 3, y0 + 4, w - 8, 8, P("road_white", 3))
    text(at, "HOME", x0 + 3, y0 + 5, P("ink", 1))
    x0, y0, w, h = DECAL["fob"]
    at.rect(x0, y0, w, h, P("paint_black", 1))
    at.rect(x0 + 4, y0 + 3, 8, 4, P("paint_black", 3))
    at.rect(x0 + 4, y0 + 9, 8, 4, P("paint_black", 3))
    at.px(x0 + 7, y0 + 5, P("paint_red", 3))
    x0, y0, w, h = DECAL["flash_lens"]
    at.rect(x0, y0, w, h, P("glow", 1))
    for r_ in (7, 5, 3):
        for a in range(28):
            t = a / 28 * 2 * math.pi
            at.px(x0 + 8 + r_ * math.cos(t), y0 + 8 + r_ * math.sin(t), P("glow", 3 - r_ // 4))
    at.rect(x0 + 7, y0 + 7, 2, 2, P("glow", 3))
    x0, y0, w, h = DECAL["knife_side"]
    at.rect(x0, y0, w, h, P("metal", 4))
    at.rect(x0, y0 + h - 2, w, 2, P("metal", 5))
    x0, y0, w, h = DECAL["bandage_end"]
    at.rect(x0, y0, w, h, P("tile_cream", 4))
    for r_ in range(1, 8, 2):
        for a in range(30):
            t = a / 30 * 2 * math.pi
            at.px(x0 + 8 + r_ * math.cos(t), y0 + 8 + r_ * math.sin(t), P("tile_cream", 2))
    x0, y0, w, h = DECAL["wallet_inside"]
    at.rect(x0, y0, w, h, P("leather", 2))
    at.rect(x0 + 2, y0 + 3, 12, 9, P("paint_blue", 3))
    at.rect(x0 + 17, y0 + 3, 12, 9, P("paint_green", 2))
    x0, y0, w, h = DECAL["stamp"]
    at.rect(x0, y0, w, h, P("road_white", 3))
    at.rect(x0 + 2, y0 + 2, 12, 12, P("paint_red", 2))
    at.rect(x0 + 4, y0 + 4, 8, 8, P("road_white", 3))
    x0, y0, w, h = DECAL["tape_reel"]
    at.rect(x0, y0, w, h, P("paint_black", 1))
    at.rect(x0 + 5, y0 + 5, 6, 6, P("road_white", 3))
    for k in range(6):
        t = k / 6 * 2 * math.pi
        at.px(x0 + 8 + 2 * math.cos(t), y0 + 8 + 2 * math.sin(t), P("paint_black", 1))
    x0, y0, w, h = DECAL["evidence_label"]
    at.rect(x0, y0, w, h, P("road_white", 3))
    at.rect(x0, y0, w, 4, P("paint_red", 2))
    text(at, "EVIDENCE", x0 + 0, y0 + 6, P("ink", 0))
    # emblem / artifact reliefs: abstract concentric geometry only (no lore, no symbols with meaning)
    for nm, ramp in (("emblem", "metal"), ("artifact", "corrupt")):
        x0, y0, w, h = DECAL[nm]
        at.rect(x0, y0, w, h, P(ramp, 2))
        c = 16
        for j in range(h):
            for i in range(w):
                d = math.hypot(i - c + 0.5, j - c + 0.5)
                ang = math.atan2(j - c, i - c)
                if abs(d - 12) < 1.2 or abs(d - 7) < 1.0:
                    at.px(x0 + i, y0 + j, P(ramp, 4))
                elif abs(d - 12) < 2.2 or abs(d - 7) < 2.0:
                    at.px(x0 + i, y0 + j, P(ramp, 1))
                if nm == "artifact" and d < 10 and abs(math.sin(ang * 3 + d * 0.6)) < 0.18:
                    at.px(x0 + i, y0 + j, P(ramp, 0))
        at.rect(x0 + 14, y0 + 14, 4, 4, P(ramp, 4))


def build(path):
    at = Atlas("inventory_atlas")
    for n, ramp, k, st in SW:
        swatch(at, n, ramp, k, st)
    decals(at)
    img = at.image()
    img.save(path, format="PNG", optimize=True)
    return img
