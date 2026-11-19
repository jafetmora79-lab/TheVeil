"""Pack 04 pixel-art atlas: T_Com4_Atlas.png (512x512), shared by every commercial fixture, prop and sign.

* swatches (16x16): fixture finishes - enamel shelving, laminate, counter wood, chrome, cooler interior, frost, produce ...
* product facing strips (64x24 = four 16x24 facings): fictional groceries, drinks, frozen food, household, health care,
  snacks, motor oil - mapped onto one block per run of products, so a fully stocked shelf stays cheap
* game cases / console boxes / binders / bankers boxes strips
* signs and decals: store names, aisle signs, staff / exit / service signs, fuel prices, registers, conveyor belts,
  pump faces, posters (fictional games), window banners
Every pixel is taken from the Greyhaven palette (Pack 01 ramps + Pack 06 character ramps).
All brands, game titles and signs are original / fictional.
"""
import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
V2 = os.path.normpath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(V2, "06_Characters", "Source_Scripts"))
sys.path.insert(0, os.path.join(V2, "Source_Scripts"))
from chr_tex import ALL_RAMPS, P, rng_for  # noqa: E402

W = 512
FONT = {
    "A": "010101111101101", "B": "110101110101110", "C": "011100100100011", "D": "110101101101110", "E": "111100110100111",
    "F": "111100110100100", "G": "011100101101011", "H": "101101111101101", "I": "111010010010111", "J": "001001001101010",
    "K": "101110100110101", "L": "100100100100111", "M": "101111111101101", "N": "110101101101101", "O": "010101101101010",
    "P": "110101110100100", "Q": "010101101110011", "R": "110101110101101", "S": "011100010001110", "T": "111010010010010",
    "U": "101101101101111", "V": "101101101101010", "W": "101101111111101", "X": "101101010101101", "Y": "101101010010010",
    "Z": "111001010100111", "0": "111101101101111", "1": "010110010010111", "2": "110001010100111", "3": "110001010001110",
    "4": "101101111001001", "5": "111100110001110", "6": "011100111101111", "7": "111001010010010", "8": "111101111101111",
    "9": "111101111001110", "-": "000000111000000", ".": "000000000000010", "/": "001001010100100", "!": "010010010000010",
    "&": "010101010101011", "$": "011110010011110", "'": "010010000000000", "+": "000010111010000", ":": "000010000010000",
}


def C(ramp, k):
    return P(ramp, int(max(0, min(len(ALL_RAMPS[ramp]) - 1, k))))


class Atlas:
    def __init__(self):
        self.a = np.full((W, W), C("ink", 0), np.int64)
        self.rng = rng_for("com4_atlas")
        self.rects = {}
        self._x = self._y = self._rowh = 0

    def alloc(self, name, w, h):
        """deterministic shelf packer"""
        assert name not in self.rects, name
        if self._x + w > W:
            self._x, self._y, self._rowh = 0, self._y + self._rowh, 0
        assert self._y + h <= W, ("atlas full", name)
        r = (self._x, self._y, w, h)
        self.rects[name] = r
        self._x += w
        self._rowh = max(self._rowh, h)
        return r

    def px(self, x, y, v):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < W and 0 <= y < W:
            self.a[y, x] = v

    def rect(self, x, y, w, h, v):
        x, y = int(round(x)), int(round(y))
        self.a[max(0, y):max(0, y + int(round(h))), max(0, x):max(0, x + int(round(w)))] = v

    def frame(self, x, y, w, h, v):
        self.rect(x, y, w, 1, v)
        self.rect(x, y + h - 1, w, 1, v)
        self.rect(x, y, 1, h, v)
        self.rect(x + w - 1, y, 1, h, v)

    def disc(self, cx, cy, r, v):
        for j in range(int(cy - r - 1), int(cy + r + 2)):
            for i in range(int(cx - r - 1), int(cx + r + 2)):
                if (i + 0.5 - cx) ** 2 + (j + 0.5 - cy) ** 2 <= r * r:
                    self.px(i, j, v)

    def text(self, s, x, y, v, k=1):
        cx = x
        for ch in s.upper():
            g = FONT.get(ch)
            if g:
                for i, b in enumerate(g):
                    if b == "1":
                        self.rect(cx + (i % 3) * k, y + (i // 3) * k, k, k, v)
            cx += 4 * k
        return cx

    def ctext(self, s, rect, v, k=1, dy=None):
        x, y, w, h = rect
        tw = len(s) * 4 * k - k
        self.text(s, x + (w - tw) // 2, y + ((h - 5 * k) // 2 if dy is None else dy), v, k)

    def image(self):
        from PIL import Image
        return Image.fromarray(P.rgb[self.a].astype(np.uint8), "RGB")


def tw(s, k=1):
    return len(s) * 4 * k - k


# ------------------------------------------------------------------ swatches
SW = [  # name, ramp, level, style
    ("enamel_white", "paint_white", 3, "plain"), ("enamel_gray", "concrete", 4, "plain"), ("shelf_edge", "metal", 3, "plain"),
    ("pegboard", "drywall", 2, "peg"), ("laminate_cream", "tile_cream", 3, "speck"), ("laminate_gray", "concrete", 3, "speck"),
    ("counter_wood", "wood_warm", 3, "grain"), ("wood_dark", "wood_dark", 2, "grain"), ("wood_light", "wood_light", 3, "grain"),
    ("chrome", "metal", 4, "chrome"), ("steel", "metal", 3, "brushed"), ("steel_dark", "metal", 1, "brushed"),
    ("cooler_in", "paint_white", 4, "plain"), ("frost", "glass", 4, "speck"), ("black_plastic", "paint_black", 1, "plain"),
    ("gray_plastic", "plastic", 2, "plain"), ("red_plastic", "paint_red", 2, "plain"), ("blue_paint", "paint_blue", 2, "plain"),
    ("green_paint", "paint_green", 2, "plain"), ("yellow_paint", "sign_yellow", 3, "plain"), ("orange_paint", "paint_orange", 2, "plain"),
    ("navy_paint", "paint_navy", 2, "plain"), ("rubber", "rubber", 1, "plain"), ("cardboard", "cardboard", 2, "speck"),
    ("crate_wood", "wood_light", 2, "slats"), ("concrete", "concrete", 3, "speck"), ("apples", "paint_red", 2, "fruit"),
    ("oranges", "paint_orange", 3, "fruit"), ("bananas", "sign_yellow", 3, "banana"), ("lettuce", "grass", 3, "leafy"),
    ("potatoes", "soil", 3, "fruit"), ("tomatoes", "paint_red", 3, "fruit"), ("glass_tint", "glass", 3, "glass"),
    ("light_panel", "glow", 3, "diffuser"), ("leather_black", "paint_black", 2, "speck"), ("fabric_blue", "paint_navy", 2, "weave"),
    ("fabric_green", "door_green", 2, "weave"), ("carpet_blue", "paint_navy", 1, "weave"), ("felt_green", "door_green", 1, "speck"),
    ("paper", "paint_white", 4, "speck"), ("brass", "sign_yellow", 2, "brushed"), ("file_olive", "door_green", 3, "plain"),
]


def swatch(at, name, ramp, k, style):
    x, y, w, h = at.alloc(name, 16, 16)
    rng = at.rng
    at.rect(x, y, w, h, C(ramp, k))
    if style == "peg":
        for j in range(y + 2, y + h, 4):
            for i in range(x + 2, x + w, 4):
                at.px(i, j, C(ramp, k - 2))
    elif style == "speck":
        for _ in range(14):
            at.px(x + rng.integers(0, w), y + rng.integers(0, h), C(ramp, k + int(rng.choice([-1, 1]))))
    elif style == "grain":
        for j in range(h):
            off = int(2 * math.sin(j * 0.7))
            for i in range(w):
                if (i + off) % 5 == 0:
                    at.px(x + i, y + j, C(ramp, k - 1))
    elif style == "chrome":
        for j in range(h):
            at.rect(x, y + j, w, 1, C(ramp, k + (1 if j < 5 else 0 if j < 11 else -2)))
    elif style == "brushed":
        for j in range(h):
            if rng.random() < 0.45:
                L, s = rng.integers(3, 10), rng.integers(0, w)
                for i in range(L):
                    at.px(x + (s + i) % w, y + j, C(ramp, k + (1 if j % 3 else -1)))
    elif style == "slats":
        for j in range(y + 4, y + h, 5):
            at.rect(x, j, w, 1, C(ramp, k - 2))
    elif style == "fruit":
        at.rect(x, y, w, h, C("paint_black", 0))
        for j in range(3):
            for i in range(3):
                cx, cy = x + 3 + i * 5 + (j % 2) * 2, y + 3 + j * 5
                at.disc(cx, cy, 2.4, C(ramp, k))
                at.px(cx - 1, cy - 1, C(ramp, k + 1))
    elif style == "banana":
        at.rect(x, y, w, h, C("wood_light", 1))
        for j in range(y + 1, y + h, 4):
            for i in range(x, x + w):
                at.px(i, j + int(1.5 * math.sin((i - x) * 0.5)), C(ramp, k))
                at.px(i, j + 1 + int(1.5 * math.sin((i - x) * 0.5)), C(ramp, k - 1))
    elif style == "leafy":
        for _ in range(40):
            at.rect(x + rng.integers(0, w - 1), y + rng.integers(0, h - 1), 2, 2, C(ramp, k + int(rng.choice([-1, 0, 1]))))
    elif style == "glass":
        at.rect(x + 2, y + 2, 5, 2, C(ramp, k + 1))
    elif style == "diffuser":
        for j in range(y + 1, y + h, 3):
            for i in range(x + 1, x + w, 3):
                at.px(i, j, C(ramp, k - 1))
    elif style == "weave":
        for j in range(h):
            for i in range(w):
                if (i % 2 == 0) != (j % 2 == 0):
                    at.px(x + i, y + j, C(ramp, k - 1))


# ------------------------------------------------------------------ product strips (4 facings of 16x24)
PRODUCTS = {  # name: (kind, base ramp/level, accent ramp/level, text)
    "cereal_a": ("box", ("paint_red", 2), ("sign_yellow", 3), "OAT"), "cereal_b": ("box", ("paint_blue", 2), ("paint_white", 4), "CRN"),
    "crackers": ("box", ("paint_orange", 2), ("paint_red", 1), "CRK"), "pasta": ("box", ("paint_navy", 2), ("sign_yellow", 3), "PST"),
    "rice": ("bag", ("paint_white", 4), ("paint_red", 2), "RCE"), "baking": ("bag", ("paint_white", 3), ("paint_blue", 2), "FLR"),
    "soup": ("can", ("paint_red", 2), ("paint_white", 4), "SP"), "beans": ("can", ("paint_green", 2), ("sign_yellow", 3), "BN"),
    "tomato": ("can", ("paint_red", 3), ("paint_green", 2), "TM"), "coffee": ("can", ("wood_dark", 2), ("sign_yellow", 3), "CF"),
    "soda": ("bottle", ("paint_green", 3), ("paint_red", 2), "PO"), "cola": ("bottle", ("wood_dark", 1), ("paint_red", 2), "KO"),
    "water": ("bottle", ("glass", 4), ("paint_blue", 3), "AQ"), "juice": ("jug", ("paint_orange", 3), ("paint_green", 3), "OJ"),
    "milk": ("jug", ("paint_white", 4), ("paint_blue", 3), "MK"), "yogurt": ("tub", ("paint_white", 4), ("paint_red", 2), "YG"),
    "icecream": ("box", ("tile_cream", 4), ("wood_dark", 2), "ICE"), "pizza": ("flat", ("paint_red", 2), ("sign_yellow", 3), "PZA"),
    "frozen_veg": ("bag", ("paint_green", 2), ("paint_white", 4), "VEG"), "chips": ("bag", ("sign_yellow", 3), ("paint_red", 2), "CHP"),
    "chips_b": ("bag", ("paint_blue", 3), ("paint_white", 4), "CRS"), "candy": ("box", ("paint_red", 3), ("wood_dark", 1), "CHC"),
    "cookies": ("box", ("paint_navy", 2), ("wood_warm", 4), "CKE"), "detergent": ("jug", ("paint_orange", 2), ("paint_blue", 3), "WSH"),
    "towels": ("roll", ("paint_white", 4), ("paint_blue", 3), "PT"), "petfood": ("bag", ("paint_green", 1), ("sign_yellow", 3), "PET"),
    "shampoo": ("bottle", ("tile_teal", 3), ("paint_white", 4), "SH"), "toothpaste": ("box", ("paint_white", 4), ("paint_red", 2), "TP"),
    "meds": ("box", ("paint_white", 4), ("paint_blue", 2), "RX"), "pain": ("box", ("paint_white", 4), ("paint_red", 2), "PR"),
    "vitamins": ("bottle", ("paint_orange", 3), ("paint_white", 4), "VT"), "bandage": ("box", ("tile_cream", 4), ("paint_red", 2), "BD"),
    "pillbottles": ("bottle", ("paint_orange", 2), ("paint_white", 4), "RX"), "motoroil": ("bottle", ("sign_yellow", 3), ("paint_black", 1), "OIL"),
    "jerky": ("bag", ("paint_red", 1), ("wood_warm", 3), "JKY"), "gum": ("box", ("paint_green", 3), ("paint_white", 4), "GM"),
    "eggs": ("flat", ("tile_cream", 4), ("cardboard", 2), "EGG"), "bread": ("bag", ("wood_warm", 3), ("paint_blue", 3), "BRD"),
}


def facing(at, x, y, kind, base, acc, txt, var):
    b, a = C(*base), C(*acc)
    dark = C("paint_black", 0)
    hi = C(base[0], base[1] + 1)
    lo = C(base[0], base[1] - 1)
    if kind == "box":
        at.rect(x, y, 16, 24, b)
        at.rect(x + 1, y + 1, 14, 6, a)
        at.text(txt, x + 2, y + 2, b)
        at.disc(x + 8, y + 15, 4, a)
        at.rect(x, y, 1, 24, hi)
        at.rect(x + 15, y, 1, 24, lo)
    elif kind == "flat":
        at.rect(x, y, 16, 24, dark)
        for k in range(3):
            yy = y + 2 + k * 7
            at.rect(x + 1, yy, 14, 6, b)
            at.rect(x + 2, yy + 1, 12, 2, a)
    elif kind == "bag":
        at.rect(x, y, 16, 24, dark)
        at.rect(x + 1, y + 2, 14, 22, b)
        at.rect(x + 2, y + 1, 12, 1, b)
        at.rect(x + 2, y + 8, 12, 7, a)
        at.text(txt, x + 2, y + 9, b)
        at.rect(x + 1, y + 2, 1, 22, hi)
    elif kind == "can":
        at.rect(x, y, 16, 24, dark)
        for k in range(2):
            yy = y + 1 + k * 12
            at.rect(x + 1, yy, 14, 11, b)
            at.rect(x + 1, yy + 3, 14, 5, a)
            at.text(txt[:2], x + 4, yy + 3, b)
            at.rect(x + 3, yy, 2, 11, hi)
            at.rect(x + 13, yy, 2, 11, lo)
            at.rect(x + 1, yy, 14, 1, C("metal", 4))
    elif kind in ("bottle", "jug"):
        at.rect(x, y, 16, 24, dark)
        nk = 4 if kind == "bottle" else 2
        cap = C("paint_white", 4) if kind == "bottle" else a
        at.rect(x + 2, y + 6, 12, 18, b)
        at.rect(x + 4, y + 2, 8, 4, b)
        at.rect(x + 5, y, 6, 2, cap)
        at.rect(x + 2, y + 12, 12, 6, a)
        at.text(txt[:3], x + 3, y + 13, b)
        at.rect(x + 3, y + 6, 1, 18, hi)
    elif kind == "tub":
        at.rect(x, y, 16, 24, dark)
        for k in range(2):
            yy = y + 2 + k * 11
            at.rect(x + 1, yy, 14, 9, b)
            at.rect(x + 1, yy, 14, 2, a)
    elif kind == "roll":
        at.rect(x, y, 16, 24, dark)
        at.rect(x + 1, y + 1, 14, 22, b)
        at.rect(x + 1, y + 9, 14, 6, a)
        at.text(txt[:2], x + 4, y + 10, b)
        at.rect(x + 7, y + 1, 1, 22, lo)


def strip(at, name, kind, base, acc, txt):
    x, y, w, h = at.alloc(name, 64, 24)
    for i in range(4):
        facing(at, x + 16 * i, y, kind, base, acc, txt, i)


# ------------------------------------------------------------------ games, consoles, documents
TITLES = [("STAR FORGE", "paint_navy", "sign_yellow"), ("DUSK RIDER", "paint_orange", "paint_black"), ("KART RALLY", "paint_red", "paint_white"),
          ("SKY KNIGHT", "paint_blue", "paint_white"), ("MONSTER MAZE", "paint_green", "sign_yellow"), ("HOLLOW HILL", "paint_black", "paint_red"),
          ("PUCK BLAST", "tile_teal", "paint_white"), ("ROBO FIST", "concrete", "paint_red"), ("DEEP REEF", "paint_blue", "paint_green"),
          ("NINJA RUN", "paint_black", "sign_yellow"), ("FARM DAYS", "grass", "paint_red"), ("ZERO LAP", "paint_red", "paint_black")]


def game_strip(at, name, offset, used=False):
    x, y, w, h = at.alloc(name, 64, 24)
    at.rect(x, y, w, h, C("paint_black", 0))
    for i in range(5):
        t, b, a = TITLES[(offset + i) % len(TITLES)]
        cx = x + 1 + i * 12 + (i > 2)
        at.rect(cx, y + 1, 11, 22, C("paint_black", 2))      # case
        at.rect(cx + 1, y + 2, 9, 20, C(b, 2))
        at.rect(cx + 1, y + 2, 9, 4, C(a, 3))
        at.disc(cx + 5.5, y + 13, 3.2, C(a, 2))
        at.rect(cx + 3, y + 18, 5, 2, C(a, 3))
        if used:
            at.rect(cx + 5, y + 3, 5, 3, C("sign_yellow", 3))


def console_strip(at, name):
    x, y, w, h = at.alloc(name, 64, 24)
    at.rect(x, y, w, h, C("paint_black", 0))
    cols = [("paint_white", "paint_blue"), ("paint_black", "paint_green"), ("concrete", "paint_red"), ("paint_navy", "sign_yellow")]
    for i, (b, a) in enumerate(cols):
        cx = x + i * 16
        at.rect(cx + 1, y + 1, 14, 22, C(b, 3))
        at.rect(cx + 1, y + 1, 14, 5, C(a, 3))
        at.rect(cx + 3, y + 10, 10, 6, C("paint_black", 1))
        at.rect(cx + 4, y + 11, 8, 2, C(a, 2))
        at.text("NOVA" if i % 2 == 0 else "ORB", cx + 1 + (i % 2) * 2, y + 18, C(a, 2))


def binder_strip(at, name):
    x, y, w, h = at.alloc(name, 64, 24)
    rng = at.rng
    cols = ["paint_navy", "paint_red", "door_green", "paint_black", "wood_dark", "concrete"]
    i = 0
    while i < w:
        bw = int(rng.integers(3, 6))
        c = cols[int(rng.integers(0, len(cols)))]
        at.rect(x + i, y, bw, h, C(c, 2))
        at.rect(x + i, y + 6, bw, 3, C("paint_white", 4))
        at.rect(x + i + bw - 1, y, 1, h, C(c, 1))
        i += bw


def bankers_strip(at, name):
    x, y, w, h = at.alloc(name, 64, 24)
    for i in range(4):
        cx = x + i * 16
        at.rect(cx, y, 16, 24, C("cardboard", 3))
        at.rect(cx, y, 1, 24, C("cardboard", 1))
        at.rect(cx + 4, y + 3, 8, 2, C("cardboard", 0))
        at.rect(cx + 3, y + 10, 10, 6, C("paint_white", 4))
        for j in range(y + 11, y + 15, 2):
            at.rect(cx + 4, j, 7, 1, C("paint_black", 2))


# ------------------------------------------------------------------ signs / decals
def sign(at, name, w, h, text, bg, fg, k=1, border=None, sub=None, subk=1, icon=None):
    r = at.alloc(name, w, h)
    x, y, _, _ = r
    at.rect(x, y, w, h, C(*bg))
    if border:
        at.frame(x, y, w, h, C(*border))
        at.frame(x + 1, y + 1, w - 2, h - 2, C(*border))
    if sub:
        at.ctext(text, (x, y, w, h), C(*fg), k, dy=max(2, (h - 5 * k - 5 * subk - 3) // 2))
        at.ctext(sub, (x, y, w, h), C(*fg), subk, dy=max(2, (h - 5 * k - 5 * subk - 3) // 2) + 5 * k + 3)
    else:
        at.ctext(text, (x, y, w, h), C(*fg), k)
    if icon:
        icon(at, x, y, w, h)
    return r


def icon_cart(at, x, y, w, h):
    c = C("paint_white", 4)
    at.rect(x + 4, y + 6, 10, 1, c)
    at.rect(x + 5, y + 7, 8, 4, c)
    at.px(x + 6, y + 13, c)
    at.px(x + 12, y + 13, c)
    at.rect(x + 2, y + 5, 2, 1, c)


def icon_pad(at, x, y, w, h):
    c = C("paint_white", 4)
    at.rect(x + 6, y + h // 2 - 3, 14, 7, c)
    at.rect(x + 8, y + h // 2 - 1, 3, 1, C("paint_red", 2))
    at.rect(x + 9, y + h // 2 - 2, 1, 3, C("paint_red", 2))
    at.disc(x + 17, y + h // 2, 1.3, C("paint_blue", 3))


def build_decals(at):
    D = {}
    D["sign_market"] = sign(at, "sign_market", 224, 28, "GREYHAVEN MARKET", ("paint_green", 1), ("paint_white", 4), 3, border=("sign_yellow", 3))
    D["sign_market_sub"] = sign(at, "sign_market_sub", 128, 12, "FRESH FOODS DAILY", ("paint_white", 4), ("paint_green", 1), 1)
    D["sign_games"] = sign(at, "sign_games", 192, 32, "GAME HAVEN", ("paint_navy", 1), ("sign_yellow", 3), 4, border=("paint_red", 2),
                           sub="NEW & USED VIDEO GAMES", icon=icon_pad)
    D["sign_drug"] = sign(at, "sign_drug", 192, 28, "HOLLIS DRUG", ("paint_white", 4), ("paint_red", 2), 3, border=("paint_red", 2), sub="PHARMACY")
    D["sign_fuel"] = sign(at, "sign_fuel", 160, 24, "QUARRY FUEL", ("paint_red", 2), ("paint_white", 4), 3, border=("sign_yellow", 3))
    D["sign_mart"] = sign(at, "sign_mart", 128, 20, "FOOD MART", ("paint_white", 4), ("paint_red", 2), 3)
    D["sign_archive"] = sign(at, "sign_archive", 128, 16, "MUNICIPAL ARCHIVE", ("stone_warm", 3), ("wood_dark", 1), 1, sub="GREYHAVEN", subk=1)
    for i, cat in enumerate(["CEREAL", "CANNED", "PASTA", "SNACKS", "DRINKS", "BAKING", "HOME"]):
        D[f"aisle_{i + 1}"] = sign(at, f"aisle_{i + 1}", 32, 24, str(i + 1), ("paint_green", 1), ("paint_white", 4), 2, sub=cat)
    D["aisle_produce"] = sign(at, "aisle_produce", 48, 12, "PRODUCE", ("paint_green", 1), ("paint_white", 4))
    D["aisle_frozen"] = sign(at, "aisle_frozen", 48, 12, "FROZEN", ("paint_blue", 2), ("paint_white", 4))
    D["aisle_dairy"] = sign(at, "aisle_dairy", 48, 12, "DAIRY", ("paint_blue", 3), ("paint_white", 4))
    D["service"] = sign(at, "service", 72, 12, "CUSTOMER SERVICE", ("paint_green", 1), ("paint_white", 4))
    D["staff"] = sign(at, "staff", 48, 10, "STAFF ONLY", ("paint_white", 4), ("paint_red", 2))
    D["exit"] = sign(at, "exit", 20, 10, "EXIT", ("paint_red", 2), ("paint_white", 4))
    D["restroom"] = sign(at, "restroom", 48, 10, "RESTROOM", ("paint_navy", 2), ("paint_white", 4))
    D["cart_return"] = sign(at, "cart_return", 48, 20, "CART", ("paint_green", 1), ("paint_white", 4), 1, sub="RETURN", icon=None)
    D["pharmacy"] = sign(at, "pharmacy", 64, 14, "PHARMACY", ("paint_red", 2), ("paint_white", 4), 1, sub="PICK UP")
    D["waiting"] = sign(at, "waiting", 40, 10, "WAITING", ("paint_white", 4), ("paint_navy", 2))
    D["new_rel"] = sign(at, "new_rel", 56, 12, "NEW RELEASES", ("paint_red", 2), ("paint_white", 4))
    D["used"] = sign(at, "used", 56, 12, "USED GAMES", ("sign_yellow", 3), ("paint_black", 0))
    D["consoles"] = sign(at, "consoles", 56, 12, "CONSOLES", ("paint_navy", 2), ("paint_white", 4))
    D["playnow"] = sign(at, "playnow", 40, 12, "PLAY NOW", ("paint_green", 2), ("paint_white", 4))
    D["open"] = sign(at, "open", 32, 14, "OPEN", ("paint_black", 0), ("paint_red", 3), 2)
    D["records"] = sign(at, "records", 40, 10, "RECORDS", ("wood_dark", 2), ("sign_yellow", 3))
    D["reading"] = sign(at, "reading", 48, 10, "READING ROOM", ("wood_dark", 2), ("sign_yellow", 3))
    D["info"] = sign(at, "info", 48, 10, "RECEPTION", ("wood_dark", 2), ("sign_yellow", 3))
    D["ice"] = sign(at, "ice", 32, 16, "ICE", ("paint_blue", 3), ("paint_white", 4), 2)
    D["air"] = sign(at, "air", 32, 12, "AIR", ("paint_red", 2), ("paint_white", 4), 2)
    D["coffee_sign"] = sign(at, "coffee_sign", 48, 12, "HOT COFFEE", ("wood_dark", 1), ("paint_white", 4))
    D["specials"] = sign(at, "specials", 64, 16, "WEEKLY", ("sign_yellow", 3), ("paint_red", 2), 1, sub="SPECIALS")
    D["produce_banner"] = sign(at, "produce_banner", 64, 16, "FRESH", ("paint_green", 2), ("paint_white", 4), 1, sub="PRODUCE")
    D["tradein"] = sign(at, "tradein", 32, 40, "TRADE", ("paint_red", 2), ("sign_yellow", 3), 1, sub="INS!")
    D["preorder"] = sign(at, "preorder", 32, 40, "PRE", ("paint_blue", 2), ("paint_white", 4), 2, sub="ORDER")
    # fuel price sign
    r = at.alloc("prices", 48, 48)
    x, y = r[0], r[1]
    at.rect(x, y, 48, 48, C("paint_white", 4))
    at.rect(x, y, 48, 12, C("paint_red", 2))
    at.ctext("QUARRY", (x, y, 48, 12), C("paint_white", 4))
    for i, (lab, pr) in enumerate((("REG", "1.59"), ("PLUS", "1.69"), ("PREM", "1.79"))):
        yy = y + 14 + i * 11
        at.rect(x + 2, yy, 44, 10, C("paint_black", 0))
        at.text(lab, x + 4, yy + 3, C("paint_white", 4))
        at.text(pr, x + 26, yy + 3, C("paint_red", 3))
    D["prices"] = r
    # register / pump / conveyor / price-tag strip / keypad / coffee machine / drawer / posters
    r = at.alloc("register", 32, 24)
    x, y = r[0], r[1]
    at.rect(x, y, 32, 24, C("plastic", 1))
    at.rect(x + 2, y + 2, 28, 7, C("paint_black", 0))
    at.text("$ 0.00", x + 4, y + 3, C("paint_green", 3))
    for j in range(3):
        for i in range(6):
            at.rect(x + 3 + i * 5, y + 11 + j * 4, 4, 3, C("plastic", 3) if i < 4 else C("paint_red", 2) if j == 2 else C("sign_yellow", 3))
    D["register"] = r
    r = at.alloc("pump_face", 32, 48)
    x, y = r[0], r[1]
    at.rect(x, y, 32, 48, C("paint_white", 4))
    at.rect(x, y, 32, 8, C("paint_red", 2))
    at.text("QUARRY", x + 4, y + 2, C("paint_white", 4))
    at.rect(x + 3, y + 11, 26, 12, C("paint_black", 0))
    at.text("08.42", x + 6, y + 12, C("paint_red", 3))
    at.text("13.39", x + 6, y + 17, C("paint_red", 3))
    for i, c in enumerate(("paint_green", "sign_yellow", "paint_red")):
        at.rect(x + 4 + i * 9, y + 27, 7, 5, C(c, 3))
    for j in range(3):
        for i in range(3):
            at.rect(x + 9 + i * 5, y + 35 + j * 4, 4, 3, C("concrete", 3))
    D["pump_face"] = r
    r = at.alloc("conveyor", 32, 16)
    x, y = r[0], r[1]
    at.rect(x, y, 32, 16, C("rubber", 0))
    for i in range(x, x + 32, 4):
        at.rect(i, y, 1, 16, C("rubber", 1))
    D["conveyor"] = r
    r = at.alloc("pricetags", 64, 8)
    x, y = r[0], r[1]
    at.rect(x, y, 64, 8, C("paint_white", 4))
    for i in range(0, 64, 16):
        at.rect(x + i + 2, y + 1, 9, 6, C("sign_yellow", 3))
        at.text("99", x + i + 3, y + 1, C("paint_black", 0))
    D["pricetags"] = r
    r = at.alloc("coffee_machine", 32, 32)
    x, y = r[0], r[1]
    at.rect(x, y, 32, 32, C("paint_black", 1))
    for i in range(2):
        at.rect(x + 2 + i * 15, y + 3, 13, 8, C("metal", 3))
        at.rect(x + 4 + i * 15, y + 20, 9, 8, C("glass", 3))
        at.rect(x + 5 + i * 15, y + 24, 7, 4, C("wood_dark", 1))
        at.rect(x + 7 + i * 15, y + 13, 3, 2, C("paint_red", 3))
    D["coffee_machine"] = r
    r = at.alloc("drawer4", 16, 32)
    x, y = r[0], r[1]
    at.rect(x, y, 16, 32, C("concrete", 4))
    for j in range(4):
        at.frame(x + 1, y + 1 + j * 8, 14, 7, C("concrete", 2))
        at.rect(x + 5, y + 3 + j * 8, 6, 1, C("metal", 4))
        at.rect(x + 6, y + 5 + j * 8, 4, 1, C("paint_white", 4))
    D["drawer4"] = r
    r = at.alloc("ice_door", 32, 32)
    x, y = r[0], r[1]
    at.rect(x, y, 32, 32, C("paint_white", 4))
    at.rect(x, y, 32, 10, C("paint_blue", 3))
    at.ctext("ICE", (x, y, 32, 10), C("paint_white", 4))
    for i in range(2):
        at.frame(x + 2 + i * 15, y + 12, 13, 18, C("concrete", 3))
        at.rect(x + 12 + i * 15, y + 18, 1, 5, C("metal", 4))
    D["ice_door"] = r
    r = at.alloc("airpump_face", 24, 32)
    x, y = r[0], r[1]
    at.rect(x, y, 24, 32, C("paint_red", 2))
    at.ctext("AIR", (x, y, 24, 10), C("paint_white", 4))
    at.rect(x + 4, y + 12, 16, 7, C("paint_black", 0))
    at.text("25C", x + 7, y + 13, C("paint_red", 3))
    at.disc(x + 12, y + 25, 3, C("concrete", 3))
    D["airpump_face"] = r
    for i, (t, b, a) in enumerate(TITLES[:6]):
        r = at.alloc(f"poster_{i}", 24, 32)
        x, y = r[0], r[1]
        at.rect(x, y, 24, 32, C(b, 2))
        at.rect(x, y + 22, 24, 10, C("paint_black", 0))
        words = t.split()
        at.text(words[0][:5], x + 2, y + 23, C(a, 3))
        if len(words) > 1:
            at.text(words[-1][:5], x + 2, y + 27, C(a, 2))
        at.disc(x + 12, y + 11, 6, C(a, 3))
        at.disc(x + 12, y + 11, 3, C(b, 1))
        at.rect(x + 3, y + 3, 4, 2, C("paint_white", 4))
        D[f"poster_{i}"] = r
    r = at.alloc("crt_screen", 24, 18)
    x, y = r[0], r[1]
    at.rect(x, y, 24, 18, C("paint_navy", 1))
    at.rect(x, y + 12, 24, 6, C("grass", 3))
    at.rect(x + 6, y + 8, 3, 4, C("paint_red", 3))
    at.rect(x + 15, y + 4, 4, 3, C("sign_yellow", 3))
    at.text("P1", x + 1, y + 1, C("paint_white", 4))
    D["crt_screen"] = r
    r = at.alloc("monitor", 16, 12)
    at.rect(r[0], r[1], 16, 12, C("paint_blue", 1))
    at.rect(r[0] + 1, r[1] + 1, 14, 2, C("paint_white", 4))
    D["monitor"] = r
    r = at.alloc("rx_board", 48, 24)
    x, y = r[0], r[1]
    at.rect(x, y, 48, 24, C("paint_white", 4))
    for j in range(4):
        for i in range(8):
            at.rect(x + 1 + i * 6, y + 1 + j * 6, 5, 5, C("paint_orange", 2) if (i + j) % 3 else C("paint_white", 3))
            at.rect(x + 1 + i * 6, y + 1 + j * 6, 5, 1, C("paint_white", 4))
    D["rx_board"] = r
    r = at.alloc("tile_band", 32, 8)
    at.rect(r[0], r[1], 32, 8, C("paint_green", 1))
    at.rect(r[0], r[1] + 3, 32, 2, C("sign_yellow", 3))
    D["tile_band"] = r
    r = at.alloc("candy_rack", 32, 24)
    x, y = r[0], r[1]
    at.rect(x, y, 32, 24, C("paint_black", 0))
    for j in range(3):
        for i in range(8):
            at.rect(x + i * 4, y + 1 + j * 8, 3, 6, C(["paint_red", "sign_yellow", "paint_blue", "paint_green", "paint_orange"][(i + j) % 5], 3))
    D["candy_rack"] = r
    r = at.alloc("noticeboard", 32, 24)
    x, y = r[0], r[1]
    at.rect(x, y, 32, 24, C("cardboard", 2))
    for k, (xx, yy, c) in enumerate(((2, 2, "paint_white"), (12, 3, "sign_yellow"), (22, 2, "paint_white"), (4, 13, "tile_cream"), (16, 12, "paint_white"))):
        at.rect(x + xx, y + yy, 8, 9, C(c, 4 if c != "sign_yellow" else 3))
        at.px(x + xx + 4, y + yy, C("paint_red", 2))
    D["noticeboard"] = r
    r = at.alloc("bell_papers", 16, 16)
    at.rect(r[0], r[1], 16, 16, C("paint_white", 4))
    for j in range(r[1] + 2, r[1] + 15, 2):
        at.rect(r[0] + 2, j, 11, 1, C("concrete", 2))
    D["bell_papers"] = r
    return D


def build(path):
    at = Atlas()
    for n, ramp, k, st in SW:
        swatch(at, n, ramp, k, st)
    at._x, at._y, at._rowh = 0, at._y + at._rowh, 0
    for n, (kind, base, acc, txt) in PRODUCTS.items():
        strip(at, n, kind, base, acc, txt)
    for i, nm in enumerate(("games_a", "games_b", "games_c", "games_d")):
        game_strip(at, nm, i * 3)
    game_strip(at, "games_used", 5, used=True)
    console_strip(at, "consoles_boxes")
    binder_strip(at, "binders")
    bankers_strip(at, "bankers")
    build_decals(at)
    sign(at, "movies", 48, 12, "MOVIES", ("paint_red", 1), ("paint_white", 4), 1)      # appended last: earlier rects unchanged
    at.image().save(path, format="PNG", optimize=True)
    global RECTS
    RECTS = dict(at.rects)
    return at.rects


RECTS = None


def rects():
    global RECTS
    if RECTS is None:
        import tempfile
        RECTS = build(os.path.join(tempfile.gettempdir(), "_com4_probe.png"))
    return RECTS


def R(name):
    x, y, w, h = rects()[name]
    return (x / W, y / W, (x + w) / W, (y + h) / W)
