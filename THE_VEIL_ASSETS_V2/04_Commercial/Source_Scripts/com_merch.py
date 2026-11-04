"""THE VEIL - Pack 04 merchandise: reusable low-poly products + store layouts (deterministic).

* One pixel-art label atlas (`Merchandise/T_Com4_Merch.png`, palette-locked to the project palette) and one material.
* One mesh per product *variant* in `Merchandise/COM_Merch_Library.glb`. Variants of a family share the geometry
  and differ only by their atlas cell (labels, liquid / cap / case colours), so the game draws each variant with one
  MultiMesh per store.
* `Merchandise/MERCH_LAYOUT.json`: per store, product transforms computed from the *final* (wall-snapped) fixture
  positions of build_commercial.instances(), plus "pick groups": the only products the player can take one of.

Fictional brands and titles only. Products are separate instances, never baked into the shelves.
Front of every product = +Z, origin = centre of its footprint on the shelf (y = 0 is the bottom).
Layout records are [x, y, z, yaw, pitch] in the store's local frame; basis = Ry(yaw) * Rx(pitch).
"""
import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
V2 = os.path.normpath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(V2, "02_Town", "Source_Scripts"))

import com_atlas as CA  # noqa: E402
from veil_mesh.mesh import MB  # noqa: E402
from veil_mesh.materials import _reg  # noqa: E402

C = CA.C
MERCH = "M_Com4_Merch"
FOLDER = os.path.join(V2, "04_Commercial", "Merchandise")
PNG = os.path.join(FOLDER, "T_Com4_Merch.png")
W = CA.W


def register_material():
    _reg(MERCH, tres="04_Commercial/Materials/M_Com4_Merch.tres", png=PNG, uv=(1.0, 1.0), repeat=False, metal=0.0, pack="04",
         alpha="OPAQUE", double=False, rough=0.75)


register_material()

# ====================================================================== product data
# bottles: (brand, liquid, cap, label bg, label ink, scale)
BOTTLES = {
    "bottle_water": ("BROOK", ("glass", 3), ("paint_blue", 3), ("paint_white", 4), ("paint_blue", 2), 1.3),
    "bottle_cola": ("KOLA", ("wood_dark", 0), ("paint_red", 2), ("paint_red", 2), ("paint_white", 4), 1.0),
    "bottle_orange": ("SUNNY", ("paint_orange", 3), ("paint_orange", 1), ("sign_yellow", 3), ("paint_orange", 1), 1.0),
    "bottle_lime": ("ZESTY", ("paint_green", 4), ("paint_green", 1), ("paint_green", 2), ("sign_yellow", 4), 1.0),
    "bottle_tea": ("MAPLE", ("wood_warm", 2), ("paint_white", 3), ("tile_cream", 4), ("wood_dark", 1), 1.0),
    "bottle_sport": ("BOLT", ("tile_teal", 3), ("paint_navy", 1), ("paint_navy", 1), ("tile_teal", 4), 1.15),
    "bottle_berry": ("BERRY", ("wallpaper_rose", 4), ("paint_white", 4), ("paint_white", 4), ("wallpaper_rose", 2), 1.0),
    "bottle_volt": ("VOLT", ("sign_yellow", 3), ("paint_black", 0), ("paint_black", 0), ("sign_yellow", 3), 0.9),
}
# cans: (name, body, ink)
CANS = {
    "can_soup": ("SOUP", ("paint_red", 2), ("paint_white", 4)), "can_beans": ("BEANS", ("paint_green", 2), ("sign_yellow", 3)),
    "can_tomato": ("TOMATO", ("paint_red", 3), ("paint_green", 2)), "can_corn": ("CORN", ("sign_yellow", 3), ("paint_green", 1)),
    "can_tuna": ("TUNA", ("paint_blue", 3), ("paint_white", 4)), "can_peach": ("PEACH", ("paint_orange", 3), ("paint_white", 4)),
}
# bags: (family, name, colour, accent, (w, h, d))
BAGS = {
    "bag_chips_a": ("chips", "CRUNCH", ("sign_yellow", 3), ("paint_red", 2), (0.20, 0.28, 0.08)),
    "bag_chips_b": ("chips", "WAVY", ("paint_blue", 3), ("paint_white", 4), (0.20, 0.28, 0.08)),
    "bag_chips_c": ("chips", "BBQ", ("paint_red", 1), ("sign_yellow", 3), (0.20, 0.28, 0.08)),
    "bag_chips_d": ("chips", "SALTED", ("paint_white", 4), ("paint_blue", 2), (0.20, 0.28, 0.08)),
    "bag_tortilla_a": ("tortilla", "TACO", ("paint_orange", 2), ("paint_green", 2), (0.22, 0.30, 0.09)),
    "bag_tortilla_b": ("tortilla", "NACHO", ("sign_yellow", 2), ("paint_red", 2), (0.22, 0.30, 0.09)),
    "bag_tortilla_c": ("tortilla", "LIME", ("paint_green", 2), ("paint_white", 4), (0.22, 0.30, 0.09)),
    "bag_rice_a": ("rice", "RICE", ("paint_white", 4), ("paint_red", 2), (0.18, 0.26, 0.07)),
    "bag_rice_b": ("rice", "JASMIN", ("paint_white", 3), ("paint_blue", 2), (0.18, 0.26, 0.07)),
    "bag_rice_c": ("rice", "BROWN", ("cardboard", 3), ("wood_dark", 1), (0.18, 0.26, 0.07)),
    "bag_beans_a": ("beans", "PINTO", ("cardboard", 2), ("paint_red", 2), (0.15, 0.20, 0.06)),
    "bag_beans_b": ("beans", "BLACK", ("paint_black", 1), ("paint_white", 4), (0.15, 0.20, 0.06)),
    "bag_beans_c": ("beans", "LENTIL", ("paint_orange", 2), ("paint_white", 4), (0.15, 0.20, 0.06)),
}
# boxes: (family, name, colour, accent, (w, h, d), art)
BOXES = {
    "box_cereal_a": ("cereal", "OATY", ("paint_red", 2), ("sign_yellow", 3), (0.20, 0.30, 0.07), "bowl"),
    "box_cereal_b": ("cereal", "CORNY", ("paint_blue", 2), ("sign_yellow", 3), (0.20, 0.30, 0.07), "sun"),
    "box_cereal_c": ("cereal", "CHOCO", ("wood_dark", 1), ("wood_warm", 4), (0.20, 0.30, 0.07), "bowl"),
    "box_cereal_d": ("cereal", "FRUITY", ("paint_green", 3), ("paint_red", 3), (0.20, 0.30, 0.07), "dots"),
    "box_pasta_a": ("pasta", "PENNE", ("paint_navy", 2), ("sign_yellow", 3), (0.16, 0.22, 0.06), "window"),
    "box_pasta_b": ("pasta", "SPAG", ("paint_blue", 3), ("paint_white", 4), (0.16, 0.22, 0.06), "window"),
    "box_pasta_c": ("pasta", "SHELLS", ("paint_red", 2), ("paint_white", 4), (0.16, 0.22, 0.06), "window"),
    "box_crackers_a": ("crackers", "SALTY", ("paint_red", 2), ("sign_yellow", 4), (0.22, 0.17, 0.06), "dots"),
    "box_crackers_b": ("crackers", "WHEAT", ("wood_warm", 3), ("wood_dark", 1), (0.22, 0.17, 0.06), "dots"),
    "box_crackers_c": ("crackers", "CRISP", ("paint_orange", 2), ("paint_white", 4), (0.22, 0.17, 0.06), "dots"),
    "box_snack_a": ("snack", "GRANOLA", ("paint_green", 2), ("sign_yellow", 3), (0.17, 0.20, 0.05), "bars"),
    "box_snack_b": ("snack", "NUTTY", ("wood_warm", 2), ("paint_white", 4), (0.17, 0.20, 0.05), "bars"),
    "box_snack_c": ("snack", "TOASTY", ("paint_orange", 3), ("paint_navy", 1), (0.17, 0.20, 0.05), "bars"),
    "box_cookies_a": ("cookies", "COOKIE", ("paint_navy", 2), ("wood_warm", 4), (0.20, 0.10, 0.07), "dots"),
    "box_cookies_b": ("cookies", "OATIES", ("paint_white", 4), ("wood_dark", 1), (0.20, 0.10, 0.07), "dots"),
    "box_cookies_c": ("cookies", "FUDGE", ("wood_dark", 1), ("paint_red", 3), (0.20, 0.10, 0.07), "dots"),
}
# candy (lying flat): (name, wrapper, ink, (w, h, d))
CANDY = {
    "candy_bar_a": ("ZAP", ("paint_red", 2), ("sign_yellow", 3), (0.13, 0.025, 0.035)),
    "candy_bar_b": ("NUTS", ("wood_warm", 2), ("paint_white", 4), (0.13, 0.025, 0.035)),
    "candy_bar_c": ("CHEWY", ("paint_blue", 3), ("paint_white", 4), (0.13, 0.025, 0.035)),
    "candy_bar_d": ("GOOP", ("paint_green", 3), ("paint_red", 2), (0.13, 0.025, 0.035)),
    "choc_a": ("COCOA", ("wood_dark", 0), ("sign_yellow", 3), (0.16, 0.014, 0.075)),
    "choc_b": ("MILKY", ("paint_white", 4), ("wood_dark", 1), (0.16, 0.014, 0.075)),
    "choc_c": ("DARK", ("paint_black", 0), ("paint_red", 3), (0.16, 0.014, 0.075)),
}
# game cases (shared geometry): (title line 1, line 2, genre, bg, ink)
GAMES = {
    "game_starforge": ("STAR", "FORGE", "scifi", ("paint_navy", 1), ("sign_yellow", 3)),
    "game_duskrider": ("DUSK", "RIDER", "racing", ("paint_orange", 2), ("paint_black", 0)),
    "game_kartrally": ("KART", "RALLY", "racing", ("paint_red", 2), ("paint_white", 4)),
    "game_skyknight": ("SKY", "KNIGHT", "fantasy", ("paint_blue", 2), ("paint_white", 4)),
    "game_monstermaze": ("MONSTR", "MAZE", "puzzle", ("paint_green", 2), ("sign_yellow", 3)),
    "game_puckblast": ("PUCK", "BLAST", "action", ("tile_teal", 2), ("paint_white", 4)),
    "game_robofist": ("ROBO", "FIST", "action", ("concrete", 2), ("paint_red", 3)),
    "game_deepreef": ("DEEP", "REEF", "adventure", ("paint_blue", 1), ("paint_green", 4)),
    "game_ninjarun": ("NINJA", "RUN", "action", ("paint_black", 1), ("sign_yellow", 3)),
    "game_farmdays": ("FARM", "DAYS", "adventure", ("grass", 3), ("paint_red", 2)),
    "game_zerolap": ("ZERO", "LAP", "racing", ("paint_red", 1), ("paint_black", 0)),
    "game_pixelpilot": ("PIXEL", "PILOT", "retro", ("paint_black", 0), ("tile_teal", 4)),
    "game_gravehour": ("GRAVE", "HOUR", "horror", ("ash", 1), ("paint_red", 3)),
    "game_blockbay": ("BLOCK", "BAY", "puzzle", ("paint_mustard", 3), ("paint_navy", 1)),
}
MOVIES = {
    "movie_nighttide": ("NIGHT", "TIDE", "horror", ("paint_black", 0), ("paint_red", 3)),
    "movie_redattic": ("RED", "ATTIC", "horror", ("paint_red", 0), ("paint_white", 4)),
    "movie_orbit9": ("ORBIT", "9", "scifi", ("paint_navy", 0), ("tile_teal", 4)),
    "movie_starwake": ("STAR", "WAKE", "scifi", ("paint_blue", 1), ("sign_yellow", 3)),
    "movie_hardbrake": ("HARD", "BRAKE", "action", ("paint_orange", 1), ("paint_white", 4)),
    "movie_irondock": ("IRON", "DOCK", "action", ("concrete", 2), ("paint_orange", 3)),
    "movie_summerdad": ("SUMMER", "DAD", "comedy", ("sign_yellow", 3), ("paint_blue", 1)),
    "movie_twins": ("TWINS", "", "comedy", ("paint_green", 3), ("paint_red", 2)),
    "movie_lastclue": ("LAST", "CLUE", "mystery", ("moss", 1), ("sign_yellow", 3)),
    "movie_fogharbor": ("FOG", "HARBOR", "mystery", ("ash", 2), ("paint_white", 4)),
}
HERO = "game_hollowhill"          # the protagonist's horror game (title from the Pack 04 game strips; not canon yet)

GAME_DIM = (0.135, 0.17, 0.014)
MOVIE_DIM = (0.135, 0.19, 0.014)


# ====================================================================== atlas
class MA(CA.Atlas):
    pass


def _uv(r):
    x, y, w, h = r
    return (x / W, y / W, (x + w) / W, (y + h) / W)


def _art(at, x, y, w, h, art, ink, acc):
    """small cover / box illustrations (ink / acc are palette values)"""
    if art == "bowl":
        at.rect(x + w // 2 - 6, y + h - 12, 12, 4, ink)
        at.rect(x + w // 2 - 4, y + h - 8, 8, 2, ink)
        for i in range(4):
            at.px(x + w // 2 - 4 + i * 3, y + h - 13, acc)
    elif art == "sun":
        at.disc(x + w // 2, y + h - 10, 4, ink)
    elif art == "dots":
        for i in range(5):
            at.disc(x + 4 + (i * 7) % (w - 6), y + h - 8 - (i % 2) * 5, 2, ink)
    elif art == "window":
        at.rect(x + 4, y + h - 13, w - 8, 8, C("paint_white", 4))
        for i in range(4):
            at.rect(x + 6 + i * 3, y + h - 11, 2, 4, C("sign_yellow", 3))
    elif art == "bars":
        for i in range(3):
            at.rect(x + 4, y + h - 14 + i * 4, w - 8, 3, ink)


def _cover(at, x, y, w, h, l1, l2, genre, bg, ink):
    b, k = C(*bg), C(*ink)
    at.rect(x, y, w, h, b)
    dark, white, red = C("paint_black", 0), C("paint_white", 4), C("paint_red", 2)
    cx, gy = x + w // 2, y + h - 1
    if genre == "horror":
        at.disc(cx + 5, y + 14, 3, C("paint_white", 3))                         # pale moon
        for i in range(w):                                                       # hill
            hh = int(6 + 4 * math.sin(i * 0.35))
            at.rect(x + i, gy - hh, 1, hh, dark)
        at.rect(cx - 2, gy - 12, 4, 5, dark)
        at.px(cx, gy - 10, red)                                                  # lit window
    elif genre == "scifi":
        at.disc(cx, y + h - 11, 6, k)
        at.rect(x + 2, y + h - 11, w - 4, 1, white)
        for i in range(6):
            at.px(x + (i * 11) % w, y + 13 + (i * 5) % 8, white)
    elif genre == "racing":
        for i in range(0, w, 4):
            at.rect(x + i, gy - 3, 2, 2, white)
        at.rect(cx - 5, gy - 9, 10, 4, k)
        at.rect(cx - 3, gy - 12, 6, 3, k)
    elif genre == "fantasy":
        at.rect(cx - 1, y + 13, 2, 12, white)
        at.rect(cx - 4, y + 21, 8, 2, k)
        at.rect(x + 2, gy - 6, w - 4, 6, C("paint_black", 1))
        at.rect(x + 4, gy - 10, 3, 4, C("paint_black", 1))
        at.rect(x + w - 7, gy - 10, 3, 4, C("paint_black", 1))
    elif genre == "puzzle":
        for i in range(3):
            for j in range(2):
                at.rect(x + 4 + i * 6, gy - 13 + j * 6, 5, 5, k if (i + j) % 2 else white)
    elif genre == "action":
        at.disc(cx, gy - 9, 7, C("paint_orange", 3))
        at.disc(cx, gy - 9, 4, C("sign_yellow", 4))
    elif genre == "adventure":
        for i in range(w):
            hh = max(0, 12 - abs(i - w // 2))
            at.rect(x + i, gy - hh, 1, hh, C("paint_black", 1))
        at.disc(x + 5, y + 15, 2, C("sign_yellow", 4))
    elif genre == "retro":
        at.rect(cx - 3, gy - 10, 6, 3, k)
        at.rect(cx - 1, gy - 13, 2, 3, k)
        for i in range(4):
            at.px(x + 3 + i * 5, y + 15 + (i % 2) * 3, white)
    elif genre == "comedy":
        at.disc(cx, gy - 10, 6, C("sign_yellow", 4))
        at.px(cx - 2, gy - 12, dark)
        at.px(cx + 2, gy - 12, dark)
        at.rect(cx - 2, gy - 8, 5, 1, dark)
    elif genre == "mystery":
        at.disc(cx - 2, gy - 11, 4, white)
        at.disc(cx - 2, gy - 11, 2, b)
        at.rect(cx + 1, gy - 8, 2, 5, white)
    at.ctext(l1, (x, y, w, h), k, 1, dy=2)
    if l2:
        at.ctext(l2, (x, y, w, h), k, 1, dy=8)
    at.frame(x, y, w, h, C("paint_black", 0))


def build_atlas():
    at = MA()
    R = {}
    for n, (brand, liq, cap, lbg, lin, s) in BOTTLES.items():
        r = at.alloc(n, 32, 32)
        x, y = r[0], r[1]
        at.rect(x, y, 32, 32, C(*liq))
        at.rect(x, y + 2, 32, 1, C(liq[0], min(liq[1] + 1, 4)))               # highlight band
        at.rect(x, y + 9, 32, 15, C(*lbg))
        at.rect(x, y + 9, 32, 1, C(*lin))
        at.rect(x, y + 23, 32, 1, C(*lin))
        at.ctext(brand, (x, y + 9, 32, 15), C(*lin), 1, dy=3)
        at.rect(x + 12, y + 19, 8, 2, C(*lin))
        R[n] = _uv(r)
        rc = at.alloc(n + "_cap", 4, 4)
        at.rect(rc[0], rc[1], 4, 4, C(*cap))
        R[n + "_cap"] = _uv(rc)
    for n, (txt, body, ink) in CANS.items():
        r = at.alloc(n, 24, 12)
        at.rect(r[0], r[1], 24, 12, C(*body))
        at.rect(r[0], r[1], 24, 1, C("metal", 3))
        at.rect(r[0], r[1] + 11, 24, 1, C("metal", 2))
        at.ctext(txt, (r[0], r[1], 24, 12), C(*ink), 1)
        R[n] = _uv(r)
    rt = at.alloc("can_top", 4, 4)
    at.rect(rt[0], rt[1], 4, 4, C("metal", 3))
    R["can_top"] = _uv(rt)
    for n, (fam, txt, col, acc, dim) in BAGS.items():
        r = at.alloc(n, 24, 32)
        x, y = r[0], r[1]
        at.rect(x, y, 24, 32, C(*col))
        at.rect(x, y, 24, 3, C("metal", 3))
        at.rect(x, y + 29, 24, 3, C("metal", 3))
        at.rect(x + 2, y + 6, 20, 9, C(*acc))
        at.ctext(txt, (x, y + 6, 24, 9), C(*col), 1)
        if fam in ("chips", "tortilla"):
            for i in range(4):
                at.disc(x + 5 + i * 5, y + 21 + (i % 2) * 3, 2, C("sign_yellow", 4) if fam == "chips" else C("paint_orange", 3))
        else:
            at.rect(x + 5, y + 18, 14, 8, C("paint_white", 4))
            for i in range(6):
                at.px(x + 7 + i * 2, y + 20 + (i % 3) * 2, C(*acc))
        R[n] = _uv(r)
        rs = at.alloc(n + "_side", 4, 32)
        at.rect(rs[0], rs[1], 4, 32, C(*col))
        R[n + "_side"] = _uv(rs)
    for n, (fam, txt, col, acc, dim, art) in BOXES.items():
        r = at.alloc(n, 24, 32)
        x, y = r[0], r[1]
        at.rect(x, y, 24, 32, C(*col))
        at.rect(x, y + 2, 24, 9, C(*acc))
        at.ctext(txt, (x, y + 2, 24, 9), C(*col), 1)
        _art(at, x, y, 24, 32, art, C(*acc), C("paint_white", 4))
        at.frame(x, y, 24, 32, C(col[0], max(col[1] - 1, 0)))
        R[n] = _uv(r)
        rs = at.alloc(n + "_side", 4, 32)
        at.rect(rs[0], rs[1], 4, 32, C(*col))
        at.rect(rs[0], rs[1] + 2, 4, 9, C(*acc))
        R[n + "_side"] = _uv(rs)
    for n, (txt, wrap, ink, dim) in CANDY.items():
        r = at.alloc(n, 24, 8)
        at.rect(r[0], r[1], 24, 8, C(*wrap))
        at.rect(r[0], r[1], 2, 8, C("metal", 3))
        at.rect(r[0] + 22, r[1], 2, 8, C("metal", 3))
        at.ctext(txt, (r[0], r[1], 24, 8), C(*ink), 1)
        R[n] = _uv(r)
    for coll, dim_h in ((GAMES, 32), (MOVIES, 36)):
        for n, (l1, l2, genre, bg, ink) in coll.items():
            r = at.alloc(n, 24, dim_h)
            _cover(at, r[0], r[1], 24, dim_h, l1, l2, genre, bg, ink)
            R[n] = _uv(r)
            rs = at.alloc(n + "_spine", 4, dim_h)
            at.rect(rs[0], rs[1], 4, dim_h, C(*bg))
            at.rect(rs[0] + 1, rs[1] + 3, 2, dim_h - 10, C(*ink))
            at.rect(rs[0], rs[1] + dim_h - 5, 4, 4, C("paint_white", 4) if coll is GAMES else C("paint_black", 0))
            R[n + "_spine"] = _uv(rs)
    for n, (dh, case) in (("game_back", (32, "paint_black")), ("movie_back", (36, "paint_white"))):
        r = at.alloc(n, 24, dh)
        x, y = r[0], r[1]
        at.rect(x, y, 24, dh, C(case, 1 if case == "paint_black" else 3))
        for i in range(3):
            at.rect(x + 2 + i * 7, y + 4, 6, 5, C("paint_blue", 2 + i % 2))
        for j in range(5):
            at.rect(x + 2, y + 12 + j * 3, 20 - (j % 2) * 6, 1, C("concrete", 4))
        at.rect(x + 2, y + dh - 6, 5, 4, C("paint_white", 4))
        R[n] = _uv(r)
    rc = at.alloc("case_edge", 4, 4)
    at.rect(rc[0], rc[1], 4, 4, C("paint_white", 3))
    R["case_edge"] = _uv(rc)
    # the hero case: bigger cells (front 32x40, back 32x40, spine 6x40)
    r = at.alloc(HERO, 32, 40)
    x, y = r[0], r[1]
    at.rect(x, y, 32, 40, C("paint_black", 0))
    at.rect(x, y + 24, 32, 6, C("ash", 1))                                        # fog band
    for i in range(32):
        hh = int(7 + 5 * math.sin(i * 0.23 + 1.0))
        at.rect(x + i, y + 40 - hh, 1, hh, C("paint_black", 1))
    at.rect(x + 13, y + 28, 6, 5, C("paint_black", 0))                           # lone house
    at.rect(x + 12, y + 27, 8, 1, C("paint_black", 0))
    at.px(x + 15, y + 30, C("sign_yellow", 4))
    at.disc(x + 24, y + 16, 3, C("paint_red", 2))                                # red moon
    at.ctext("HOLLOW", (x, y, 32, 40), C("paint_red", 3), 1, dy=3)
    at.ctext("HILL", (x, y, 32, 40), C("paint_red", 3), 1, dy=9)
    at.rect(x + 2, y + 35, 5, 3, C("paint_white", 4))                            # rating box
    at.frame(x, y, 32, 40, C("paint_red", 1))
    R[HERO] = _uv(r)
    r = at.alloc(HERO + "_back", 32, 40)
    x, y = r[0], r[1]
    at.rect(x, y, 32, 40, C("paint_black", 1))
    for i in range(2):
        at.rect(x + 3 + i * 14, y + 4, 12, 9, C("ash", 1))
        at.rect(x + 5 + i * 14, y + 9, 3, 3, C("paint_red", 2))
    for j in range(6):
        at.rect(x + 3, y + 17 + j * 3, 26 - (j % 3) * 5, 1, C("concrete", 3))
    at.ctext("SURVIVE", (x, y + 33, 32, 7), C("paint_red", 3), 1)
    R[HERO + "_back"] = _uv(r)
    r = at.alloc(HERO + "_spine", 6, 40)
    at.rect(r[0], r[1], 6, 40, C("paint_black", 0))
    at.rect(r[0] + 2, r[1] + 4, 2, 26, C("paint_red", 3))
    at.rect(r[0] + 1, r[1] + 33, 4, 4, C("paint_white", 4))
    R[HERO + "_spine"] = _uv(r)
    os.makedirs(FOLDER, exist_ok=True)
    at.image().save(PNG, format="PNG", optimize=True)
    return R


# ====================================================================== meshes
def _q(mb, a, b, c, d, uv, n):
    mb.quad(MERCH, a, b, c, d, n=n, uv=uv)


def _rect_uv(r):
    u0, v0, u1, v1 = r
    return [(u0, v1), (u1, v1), (u1, v0), (u0, v0)]


def box_mesh(w, h, d, front, side, top=None, back=None, top_front=False):
    """front (+z) / back (-z) = `front` cell, sides = `side`, top = top (or side). top_front: label on +y."""
    mb = MB()
    x0, x1, z0, z1 = -w / 2, w / 2, -d / 2, d / 2
    top = top or side
    back = back or front
    _q(mb, (x0, 0, z1), (x1, 0, z1), (x1, h, z1), (x0, h, z1), _rect_uv(front), (0, 0, 1))
    _q(mb, (x1, 0, z0), (x0, 0, z0), (x0, h, z0), (x1, h, z0), _rect_uv(back), (0, 0, -1))
    _q(mb, (x1, 0, z1), (x1, 0, z0), (x1, h, z0), (x1, h, z1), _rect_uv(side), (1, 0, 0))
    _q(mb, (x0, 0, z0), (x0, 0, z1), (x0, h, z1), (x0, h, z0), _rect_uv(side), (-1, 0, 0))
    _q(mb, (x0, h, z1), (x1, h, z1), (x1, h, z0), (x0, h, z0), _rect_uv(front if top_front else top), (0, 1, 0))
    return mb


def lathe_mesh(prof, body, cap, seg=8, cap_from=None):
    """profile [(y, r)] bottom->top; body cell wraps around (u), v follows y. Bands from index cap_from use `cap`."""
    mb = MB()
    u0, v0, u1, v1 = body
    ymax = prof[-1][0]
    cu, cv = (cap[0] + cap[2]) / 2, (cap[1] + cap[3]) / 2
    for k in range(len(prof) - 1):
        (ya, ra), (yb, rb) = prof[k], prof[k + 1]
        use_cap = cap_from is not None and k >= cap_from
        for i in range(seg):
            a0 = 2 * math.pi * i / seg - math.pi
            a1 = 2 * math.pi * (i + 1) / seg - math.pi
            p = lambda a, y, r: (math.sin(a) * r, y, math.cos(a) * r)
            if use_cap:
                uv = [(cu, cv)] * 4
            else:
                ua, ub = u0 + (u1 - u0) * i / seg, u0 + (u1 - u0) * (i + 1) / seg
                va, vb = v1 - (v1 - v0) * ya / ymax, v1 - (v1 - v0) * yb / ymax
                uv = [(ua, va), (ub, va), (ub, vb), (ua, vb)]
            am = (a0 + a1) / 2
            slope = (ra - rb) / max(yb - ya, 1e-6)
            n = (math.sin(am), slope * 0.5, math.cos(am))
            mb.quad(MERCH, p(a0, ya, ra), p(a1, ya, ra), p(a1, yb, rb), p(a0, yb, rb), n=n, uv=uv)
    yt, rt = prof[-1]
    for i in range(seg):
        a0 = 2 * math.pi * i / seg - math.pi
        a1 = 2 * math.pi * (i + 1) / seg - math.pi
        mb.tri(MERCH, (0, yt, 0), (math.sin(a0) * rt, yt, math.cos(a0) * rt), (math.sin(a1) * rt, yt, math.cos(a1) * rt), n=(0, 1, 0),
               uv=[(cu, cv)] * 3)
    return mb


def bag_mesh(w, h, d, front, side):
    """pillow bag: front / back bulge at the middle, crimped flat at the top"""
    mb = MB()
    u0, v0, u1, v1 = front
    rows = [(0.0, 0.55), (0.45, 1.0), (0.92, 0.25), (1.0, 0.08)]
    x0, x1 = -w / 2, w / 2
    su0, sv0, su1, sv1 = side
    for s in (1, -1):
        for k in range(len(rows) - 1):
            (fa, za), (fb, zb) = rows[k], rows[k + 1]
            ya, yb = fa * h, fb * h
            za, zb = s * za * d / 2, s * zb * d / 2
            va, vb = v1 - (v1 - v0) * fa, v1 - (v1 - v0) * fb
            if s > 0:
                _q(mb, (x0, ya, za), (x1, ya, za), (x1, yb, zb), (x0, yb, zb), [(u0, va), (u1, va), (u1, vb), (u0, vb)], (0, 0.3 * (za - zb), 1))
                svA, svB = sv1 - (sv1 - sv0) * fa, sv1 - (sv1 - sv0) * fb
                for sx in (x0, x1):
                    pts = [(sx, ya, -za), (sx, ya, za), (sx, yb, zb), (sx, yb, -zb)]
                    uvs = [(su0, svA), (su1, svA), (su1, svB), (su0, svB)]
                    if sx > 0:
                        _q(mb, pts[1], pts[0], pts[3], pts[2], uvs, (1, 0, 0))
                    else:
                        _q(mb, *pts, uvs, (-1, 0, 0))
            else:
                _q(mb, (x1, ya, za), (x0, ya, za), (x0, yb, zb), (x1, yb, zb), [(u0, va), (u1, va), (u1, vb), (u0, vb)], (0, 0.3 * (zb - za), -1))
    zt = rows[-1][1] * d / 2
    _q(mb, (x0, h, zt), (x1, h, zt), (x1, h, -zt), (x0, h, -zt), [(su0, sv0), (su1, sv0), (su1, sv0 + 0.001), (su0, sv0 + 0.001)], (0, 1, 0))
    return mb


def _case(w, h, d, front, back, spine, edge):
    mb = box_mesh(w, h, d, front, edge, back=back)
    sp = MB()                                         # spine on -x (left of the front cover)
    _q(sp, (-w / 2 - 0.0005, 0, -d / 2), (-w / 2 - 0.0005, 0, d / 2), (-w / 2 - 0.0005, h, d / 2), (-w / 2 - 0.0005, h, -d / 2),
       _rect_uv(spine), (-1, 0, 0))
    mb.merge(sp)
    return mb


def library(R):
    """variant name -> MB (front = +Z, base at y = 0)"""
    L = {}
    for n, (brand, liq, cap, lbg, lin, s) in BOTTLES.items():
        r = 0.032 * s ** 0.5
        prof = [(0.0, r * 0.92), (0.008 * s, r), (0.155 * s, r), (0.185 * s, r * 0.6), (0.205 * s, r * 0.36), (0.207 * s, r * 0.4),
                (0.228 * s, r * 0.4)]
        L[n] = lathe_mesh(prof, R[n], R[n + "_cap"], seg=8, cap_from=5)
    for n in CANS:
        prof = [(0.0, 0.034), (0.005, 0.0375), (0.105, 0.0375), (0.11, 0.034)]
        L[n] = lathe_mesh(prof, R[n], R["can_top"], seg=8)
    for n, (fam, txt, col, acc, (w, h, d)) in BAGS.items():
        L[n] = bag_mesh(w, h, d, R[n], R[n + "_side"])
    for n, (fam, txt, col, acc, (w, h, d), art) in BOXES.items():
        L[n] = box_mesh(w, h, d, R[n], R[n + "_side"])
    for n, (txt, wrap, ink, (w, h, d)) in CANDY.items():
        L[n] = box_mesh(w, h, d, R[n], R[n], top=R[n], top_front=True)
    for coll, (w, h, d), back in ((GAMES, GAME_DIM, "game_back"), (MOVIES, MOVIE_DIM, "movie_back")):
        for n in coll:
            L[n] = _case(w, h, d, R[n], R[back], R[n + "_spine"], R["case_edge"])
    w, h, d = GAME_DIM
    L[HERO] = _case(w, h, d, R[HERO], R[HERO + "_back"], R[HERO + "_spine"], R["case_edge"])
    return L


def dims(n):
    if n in BOTTLES:
        s = BOTTLES[n][5]
        return (0.064 * s ** 0.5, 0.228 * s, 0.064 * s ** 0.5)
    if n in CANS:
        return (0.075, 0.11, 0.075)
    if n in BAGS:
        return BAGS[n][4]
    if n in BOXES:
        return BOXES[n][4]
    if n in CANDY:
        return CANDY[n][3]
    if n in MOVIES:
        return MOVIE_DIM
    return GAME_DIM


# ====================================================================== layout
class Lay:
    def __init__(self, seed):
        self.rng = np.random.default_rng(seed)
        self.static = {}
        self.groups = []

    def put(self, variant, p, yaw, pitch=0.0, group=None):
        rec = [round(float(p[0]), 4), round(float(p[1]), 4), round(float(p[2]), 4), round(float(yaw), 4), round(float(pitch), 4)]
        if group is not None:
            group["inst"].append(rec)
        else:
            self.static.setdefault(variant, []).append(rec)


def _to_loc(inst, lx, ly, lz, lyaw):
    """fixture-local -> location-local (rotation about +Y by the fixture yaw)"""
    c, s = math.cos(inst["yaw"]), math.sin(inst["yaw"])
    return (inst["x"] + c * lx + s * lz, inst["y"] + ly, inst["z"] - s * lx + c * lz), inst["yaw"] + lyaw


def _run(lay, inst, variants, x0, x1, y, z_front, face, depth_rows, rows_step, gap=0.012, jitter=0.012, skip=0.04, group=None,
         group_take=0, block=4, spine_out=False):
    """fill a shelf run along fixture-local x with facings of `variants` (cycled in blocks), front at z_front facing
    +z (face=1) or -z (face=-1), `depth_rows` deep."""
    x = x0
    k = 0
    taken = 0
    while True:
        v = variants[(k // block) % len(variants)]
        w, h, d = dims(v)
        span = d if spine_out else w
        if x + span > x1:
            break
        if lay.rng.random() < skip and group is None:
            x += span + gap
            k += 1
            continue
        for r in range(depth_rows):
            dd = w if spine_out else d
            lz = z_front - face * (dd / 2 + r * rows_step)
            lyaw = (0.0 if face > 0 else math.pi) + (math.pi / 2 if spine_out else 0.0) + float(lay.rng.uniform(-0.05, 0.05))
            lx = x + span / 2 + float(lay.rng.uniform(-jitter, jitter)) * 0.4
            p, yaw = _to_loc(inst, lx, y, lz, lyaw)
            g = group if (group is not None and (group_take == 0 or taken < group_take)) else None
            lay.put(v, p, yaw, group=g)
            if g is not None:
                taken += 1
        x += span + gap
        k += 1


def _group(lay, gid, item, label, variant, inst, lx, ly, lz, size, normal_local):
    p, _ = _to_loc(inst, lx, ly, lz, 0.0)
    c, s = math.cos(inst["yaw"]), math.sin(inst["yaw"])
    nx, nz = normal_local
    g = dict(id=gid, item=item, label=label, variant=variant, inst=[], center=[round(v, 4) for v in p],
             size=[round(v, 4) for v in size], yaw=round(inst["yaw"], 5), normal=[round(c * nx + s * nz, 4), 0.0, round(-s * nx + c * nz, 4)])
    lay.groups.append(g)
    return g


GONDOLA_PLAN = {   # gondola index (x = -11.5 + 3k) -> {side: [level0, level1, level2, level3]} product families
    0: {-1: ["bag_rice", "box_pasta", "box_cereal", "box_cereal"], 1: ["bag_beans", "can_beans", "can_soup", "can_tomato"]},
    1: {-1: ["can_corn", "can_tuna", "can_soup", "can_peach"], 1: ["bag_rice", "box_pasta", "box_crackers", "box_crackers"]},
    2: {-1: ["bag_beans", "box_pasta", "box_cookies", "box_snack"], 1: ["box_cereal", "box_cereal", "box_snack", "box_cookies"]},
    3: {-1: ["box_cereal", "box_snack", "box_cereal", "box_snack"], 1: ["bag_tortilla", "bag_chips", "bag_chips", "bag_tortilla"]},
    4: {-1: ["bag_chips", "bag_tortilla", "bag_chips", "bag_chips"], 1: ["box_cookies", "box_crackers", "box_cookies", "box_snack"]},
    5: {-1: ["box_crackers", "box_cookies", "box_snack", "box_crackers"], 1: ["can_tomato", "can_beans", "can_corn", "can_soup"]},
    6: {-1: ["can_peach", "can_tuna", "can_soup", "can_beans"], 1: ["bag_rice", "bag_beans", "box_pasta", "box_pasta"]},
    7: {-1: ["bag_beans", "bag_rice", "box_pasta", "box_cereal"], 1: ["box_cereal", "box_snack", "box_crackers", "box_cookies"]},
}
FAM = {}
for _n in list(BAGS) + list(BOXES) + list(CANS):
    FAM.setdefault(_n.rsplit("_", 1)[0] if not _n.startswith("can_") else _n, []).append(_n)
GONDOLA_LEVELS = [0.12, 0.52, 0.92, 1.32]
CANDY_X = (-1.3, -0.8)           # checkout-lane-local candy rack (see com_fixtures.checkout_lane)
CANDY_Z = (0.42, 0.65)
CANDY_SHELVES = [0.42, 0.74, 1.06]
RACK_TIERS = [0.15 + k * 0.29 for k in range(4)]
WALL_LEVELS = [0.12 + 0.38 * k for k in range(5)]


def supermarket(inst):
    lay = Lay(4401)
    gondolas = sorted([i for i in inst if i["model"] == "COM_Gondola_Shelf"], key=lambda i: i["x"])
    L = 3.6
    for gi, g in enumerate(gondolas):
        for side, fams in GONDOLA_PLAN[gi].items():
            for lvl, fam in enumerate(fams):
                y = GONDOLA_LEVELS[lvl]
                vs = FAM[fam]
                zf = side * 0.47
                group = None
                if gi == 1 and side == -1 and lvl == 2:          # aisle 1, eye level: soup -> the grocery-list can
                    vs = ["can_soup"]
                    group = _group(lay, "canned_food", "canned_food", "Canned Soup", "can_soup", g, -1.2, y + 0.06, side * 0.47,
                                   (0.85, 0.16, 0.3), (0, side))
                rows_step = dims(vs[0])[2] + 0.01
                if group:
                    _run(lay, g, vs, -L / 2 + 0.06, -0.75, y, zf, side, 2, rows_step, group=group, skip=0)
                    _run(lay, g, vs + ["can_tomato"], -0.7, L / 2 - 0.06, y, zf, side, 2, rows_step)
                else:
                    _run(lay, g, vs, -L / 2 + 0.06, L / 2 - 0.06, y, zf, side, 2, rows_step)
        # end caps: power displays facing +-x
        for sx in (-1, 1):
            fam = ["bag_chips", "box_cookies", "box_cereal", "bag_tortilla", "box_snack", "box_crackers", "bag_chips", "box_cereal"][gi]
            for lvl, y in enumerate(GONDOLA_LEVELS[:3]):
                vs = FAM[fam]
                xc = sx * (L / 2 + 0.17)
                for zz in np.arange(-0.4, 0.4 - dims(vs[0])[0] + 0.001, dims(vs[0])[0] + 0.012):
                    v = vs[int((zz + 0.4) / 0.24) % len(vs)]
                    w, h, d = dims(v)
                    for r in range(2):
                        lx = xc + sx * (0.13 - d / 2 - r * (d + 0.01))
                        p, yaw = _to_loc(g, lx, y, zz + w / 2, sx * math.pi / 2 + float(lay.rng.uniform(-0.04, 0.04)))
                        lay.put(v, p, yaw)
    # beverage coolers (separately instanced, interactive glass doors): 3 doors x 4 shelves, bottles 2 deep
    coolers = sorted([i for i in inst if i["model"] == "COM_Cooler_Beverage"], key=lambda i: i["x"])
    door_w, cd = 0.78, 0.8
    lineup = [["bottle_water", "bottle_water", "bottle_berry", "bottle_sport"], ["bottle_cola", "bottle_orange", "bottle_lime", "bottle_cola"],
              ["bottle_tea", "bottle_sport", "bottle_volt", "bottle_tea"], ["bottle_water", "bottle_lime", "bottle_orange", "bottle_berry"]]
    for ci, cool in enumerate(coolers):
        Lc = 3 * door_w
        for di in range(3):
            x0 = -Lc / 2 + di * door_w + 0.075
            x1 = x0 + door_w - 0.15
            for lvl, y in enumerate([0.15, 0.55, 0.95, 1.35]):
                v = lineup[(ci + di) % 4][lvl]
                group = None
                if ci == 0 and di == 0 and lvl in (1, 2):
                    v = "bottle_water"
                    if lvl == 1:
                        group = _group(lay, "water_bottle", "water_bottle", "Water Bottle", v, cool, (x0 + x1) / 2, y + 0.12, cd / 2 - 0.2,
                                       (0.6, 0.26, 0.3), (0, 1))
                if ci == 1 and di == 1 and lvl == 2:
                    v = "bottle_cola"
                    group = _group(lay, "cola_bottle", "cola_bottle", "Cola", v, cool, (x0 + x1) / 2, y + 0.12, cd / 2 - 0.2,
                                   (0.6, 0.26, 0.3), (0, 1))
                w = dims(v)[0]
                _run(lay, cool, [v], x0, x1, y, cd / 2 - 0.13, 1, 2, w + 0.012, gap=0.01, jitter=0.006, skip=0.0 if group else 0.06,
                     group=group, block=99)
    # candy racks at the end of every checkout lane (customer side): candy bars + chocolate, lying flat
    lanes = sorted([i for i in inst if i["model"] == "COM_Checkout_Lane"], key=lambda i: i["x"])
    for li, lane in enumerate(lanes):
        for si, y in enumerate(CANDY_SHELVES):
            vs = [["candy_bar_a", "candy_bar_b"], ["candy_bar_c", "candy_bar_d", "candy_bar_a"], ["choc_a", "choc_b", "choc_c"]][si]
            group = None
            if li == len(lanes) - 1 and si == 1:                       # lane 4, middle shelf: the grocery-list snack bar
                vs = ["candy_bar_c"]
                group = _group(lay, "energy_snack", "energy_snack", "Snack Bar", "candy_bar_c", lane, CANDY_X[0] + 0.25, y + 0.05,
                               CANDY_Z[1] - 0.02, (0.55, 0.12, 0.3), (0, 1))
            if li == len(lanes) - 2 and si == 2:
                vs = ["choc_a"]
                group = _group(lay, "chocolate_bar", "chocolate_bar", "Chocolate", "choc_a", lane, CANDY_X[0] + 0.25, y + 0.05,
                               CANDY_Z[1] - 0.02, (0.55, 0.12, 0.3), (0, 1))
            col_w = (CANDY_X[1] - CANDY_X[0]) / 3
            for ci in range(3):
                v = vs[ci % len(vs)]
                w, h, d = dims(v)
                for r in range(3):
                    for st in range(2):
                        lx = CANDY_X[0] + col_w * (ci + 0.5)
                        lz = CANDY_Z[1] - 0.025 - d / 2 - r * (d + 0.006)
                        p, yaw = _to_loc(lane, lx, y + st * h, lz, float(lay.rng.uniform(-0.03, 0.03)))
                        lay.put(v, p, yaw, group=group)
    return lay


def _lying(inst, lx, y, lz, s, v, jy):
    """case lying face-up (pitch -90 deg about its x): the pivot is its bottom edge, so lift by half the thickness
    and shift by half the height to centre it on (lx, lz); s = position in the stack"""
    w, h, d = dims(v)
    c, sn = math.cos(jy), math.sin(jy)
    return _to_loc(inst, lx + sn * h / 2, y + d / 2 + s * d, lz + c * h / 2, jy)


def game_shop(inst):
    lay = Lay(4402)
    games = [g for g in GAMES]
    movies = [m for m in MOVIES]
    racks = sorted([i for i in inst if i["model"].startswith("COM_GameRack_Empty")], key=lambda i: i["z"])
    for ri, rack in enumerate(racks):
        Lr, dr = 1.8, 0.9
        for side in (1, -1):
            for k, y in enumerate(RACK_TIERS):
                z_out = side * (dr / 2 - 0.05 - 0.07 * k)
                x0, x1 = -Lr / 2 + 0.06, Lr / 2 - 0.06
                if ri == 0 and side == 1 and k == 3:                    # New Releases, top tier, aisle side: the hero game
                    group = _group(lay, "horror_game", "horror_game", "Horror Game (HOLLOW HILL)", HERO, rack, -0.55, y + 0.12,
                                   dr / 2 + 0.07, (0.62, 0.3, 0.2), (0, 1))
                    for j in range(4):
                        p, yaw = _to_loc(rack, -0.8 + j * 0.15 + 0.07, y, z_out - 0.035, 0.0)
                        lay.put(HERO, p, yaw, pitch=-0.14, group=group)
                    x0 = -0.15
                pool = games if ri == 0 else games[::-1]
                xx = x0
                j = (k * 5 + (side > 0) * 3 + ri * 7)
                while xx + 0.135 < x1:
                    if lay.rng.random() < 0.08:                         # an empty slot now and then
                        xx += 0.15
                        j += 1
                        continue
                    v = pool[j % len(pool)]
                    p, yaw = _to_loc(rack, xx + 0.0675, y, z_out - side * 0.035, (0.0 if side > 0 else math.pi) + float(lay.rng.uniform(-0.03, 0.03)))
                    lay.put(v, p, yaw, pitch=-0.14)
                    xx += 0.15
                    j += 1
    walls = sorted([i for i in inst if i["model"].startswith("COM_GameWallShelf_Empty") or i["model"] == "COM_GameWallShelf_Movies"],
                   key=lambda i: i["z"])
    for wi, wall in enumerate(walls):
        is_movies = wall["model"] == "COM_GameWallShelf_Movies"
        pool = movies if is_movies else games
        Lw, dw = 2.0, 0.35
        for k, y in enumerate(WALL_LEVELS):
            if k == len(WALL_LEVELS) - 1:                             # featured top shelf: face-out, leaning back
                for j in range(9):
                    if j in (3, 7):
                        continue
                    v = pool[(j + wi * 4) % len(pool)]
                    p, yaw = _to_loc(wall, -Lw / 2 + 0.16 + j * 0.21, y, -dw / 2 + 0.05, 0.0)
                    lay.put(v, p, yaw, pitch=-0.2)
                continue
            xx = -Lw / 2 + 0.05
            j = k * 7 + wi * 3
            while xx + 0.016 < Lw / 2 - 0.05:
                blk = int(lay.rng.integers(5, 11))
                v = pool[j % len(pool)]
                for b in range(blk):
                    if xx + 0.016 > Lw / 2 - 0.05:
                        break
                    w, h, d = dims(v)
                    p, yaw = _to_loc(wall, xx + d / 2, y, dw / 2 - 0.02 - w / 2, math.pi / 2 + float(lay.rng.uniform(-0.02, 0.02)))
                    lay.put(v, p, yaw)
                    xx += d + 0.002
                j += 1
                if lay.rng.random() < 0.18:                             # a gap, a lying stack in it
                    if lay.rng.random() < 0.5:
                        for s in range(3):
                            v2 = pool[(j + s) % len(pool)]
                            p, yaw = _lying(wall, xx + 0.085, y, 0.0, s, v2, float(lay.rng.uniform(-0.1, 0.1)))
                            lay.put(v2, p, yaw, pitch=-math.pi / 2)
                    xx += 0.17
    # counter: two small stacks by the register
    for i in inst:
        if i["model"] == "COM_RetailCounter":
            for s in range(4):
                v2 = games[(s * 3) % len(games)]
                p, yaw = _lying(i, -0.85, 1.0, 0.0, s, v2, float(lay.rng.uniform(-0.15, 0.15)))
                lay.put(v2, p, yaw, pitch=-math.pi / 2)
            for s in range(3):
                v2 = movies[(s * 2) % len(movies)]
                p, yaw = _lying(i, -0.55, 1.0, 0.05, s, v2, float(lay.rng.uniform(-0.15, 0.15)))
                lay.put(v2, p, yaw, pitch=-math.pi / 2)
    return lay


def layout_dict(lay):
    return dict(static=lay.static, groups=lay.groups,
                counts=dict(instances=sum(len(v) for v in lay.static.values()) + sum(len(g["inst"]) for g in lay.groups),
                            variants=len(set(lay.static) | {g["variant"] for g in lay.groups})))
