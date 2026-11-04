"""Pack 09 pixel-art textures (palette-locked to the Greyhaven ramps; alpha quantised in steps, no smooth gradients).

Low resolution on purpose (8-128 px): mist noise and fog cards are tiny and tile/scroll in the shader; overlays
are read at a distance. Noise only decides *where* (quantised into 3-6 bands), shapes are drawn explicitly.
"""
import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
V2 = os.path.normpath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(V2, "06_Characters", "Source_Scripts"))
sys.path.insert(0, os.path.join(V2, "Source_Scripts"))
from chr_tex import P  # noqa: E402
from veil_texgen.core import rng_for  # noqa: E402


class Tex:
    def __init__(self, name, w, h, alpha=True, fill=("ink", 0)):
        self.name, self.w, self.h, self.alpha = name, w, h, alpha
        self.a = np.full((h, w), P(*fill), np.int64)
        self.al = np.zeros((h, w), np.uint8) if alpha else None
        self.rng = rng_for("veil09_" + name)

    def px(self, x, y, v, al=None, wrap=False):
        x, y = int(round(x)), int(round(y))
        if wrap:
            x, y = x % self.w, y % self.h
        if 0 <= x < self.w and 0 <= y < self.h:
            self.a[y, x] = v
            if al is not None and self.alpha:
                self.al[y, x] = max(self.al[y, x], al)

    def image(self):
        from PIL import Image
        rgb = P.rgb[self.a]
        if self.alpha:
            return Image.fromarray(np.dstack([rgb, self.al]), "RGBA")
        return Image.fromarray(rgb, "RGB")


def tile_noise(w, h, rng, cells=(4, 8), weights=(0.6, 0.4)):
    """tileable value noise in [0,1] (wrapping lattice, smooth-step interpolation)"""
    out = np.zeros((h, w))
    for c, wt in zip(cells, weights):
        g = rng.random((c, c))
        ys, xs = np.mgrid[0:h, 0:w]
        fx, fy = xs / w * c, ys / h * c
        x0, y0 = np.floor(fx).astype(int) % c, np.floor(fy).astype(int) % c
        x1, y1 = (x0 + 1) % c, (y0 + 1) % c
        tx, ty = fx - np.floor(fx), fy - np.floor(fy)
        tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
        a = g[y0, x0] * (1 - tx) + g[y0, x1] * tx
        b = g[y1, x0] * (1 - tx) + g[y1, x1] * tx
        out += wt * (a * (1 - ty) + b * ty)
    out -= out.min()
    return out / max(out.max(), 1e-9)


def q(v, steps):
    return np.floor(np.clip(v, 0, 0.9999) * steps) / steps


ALPHA_LV = [0, 60, 110, 160, 210, 255]


def qa(v):
    """quantise alpha 0..1 into 6 hard steps"""
    return np.array(ALPHA_LV, np.uint8)[np.clip((v * 5.999).astype(int), 0, 5)]


# ------------------------------------------------------------------ textures
def mist_noise():
    t = Tex("T_Veil_MistNoise", 64, 64, alpha=False)
    n = q(tile_noise(64, 64, t.rng, (4, 8, 16), (0.55, 0.3, 0.15)), 6)
    t.a = P.ramp("ash", (n * 4.999).astype(int))
    return t


def fog_card():
    t = Tex("T_Veil_FogCard", 64, 64, fill=("ash", 4))
    n = tile_noise(64, 64, t.rng, (4, 8), (0.6, 0.4))
    ys, xs = np.mgrid[0:64, 0:64]
    r = np.hypot((xs - 31.5) / 30, (ys - 31.5) / 26)
    a = np.clip(1.0 - r, 0, 1) ** 0.8 * (0.45 + 0.55 * n)
    t.al = qa(a * 0.9)
    t.a = np.where(n > 0.55, P("ash", 4), P("ash", 3))
    return t


def wall_streaks():
    t = Tex("T_Veil_WallStreaks", 64, 128, fill=("stain", 2))
    rng = t.rng
    for _ in range(14):                                   # runs from the top, tapering, with drip beads
        x = rng.integers(2, 62)
        L = rng.integers(40, 124)
        w = rng.integers(2, 5)
        for y in range(L):
            ww = max(1, int(w * (1 - y / L) + 0.5))
            for k in range(ww):
                al = 255 if y < L * 0.7 else 160
                t.px(x + k, y, P("stain", 1 if k == 0 else 2), al)
            if rng.random() < 0.05:
                x += int(rng.choice([-1, 1]))
        t.px(x, L, P("stain", 0), 255)
        t.px(x, L + 1, P("stain", 0), 200)
    n = tile_noise(64, 128, rng, (4, 8), (0.7, 0.3))
    top = (np.mgrid[0:128, 0:64][0] < 18) & (n > 0.4)
    t.al = np.where(top, np.maximum(t.al, 160), t.al)
    return t


def ground_blight():
    t = Tex("T_Veil_GroundBlight", 128, 128, fill=("corrupt", 2))
    n = tile_noise(128, 128, t.rng, (4, 8, 16), (0.5, 0.35, 0.15))
    ys, xs = np.mgrid[0:128, 0:128]
    r = np.hypot((xs - 63.5) / 62, (ys - 63.5) / 62)
    a = np.clip((1 - r) * 1.6, 0, 1) * np.clip((n - 0.25) * 1.6, 0, 1)
    t.al = qa(a * 0.85)
    lv = q(n, 4)
    t.a = np.where(lv > 0.6, P("ash", 1), np.where(lv > 0.3, P("corrupt", 2), P("corrupt", 1)))
    for _ in range(9):                                       # thin dark veins
        x, y = t.rng.integers(20, 108, 2)
        ang = t.rng.random() * 6.28
        for s in range(t.rng.integers(12, 34)):
            ang += t.rng.normal(0, 0.3)
            x += math.cos(ang)
            y += math.sin(ang)
            t.px(x, y, P("corrupt", 0), 210)
    return t


def asphalt_cracks(seed_name):
    t = Tex(seed_name, 128, 128, fill=("asphalt", 0))
    rng = t.rng
    def crack(x, y, ang, L, depth=0):
        for s in range(L):
            ang += rng.normal(0, 0.25)
            x += math.cos(ang)
            y += math.sin(ang)
            t.px(x, y, P("asphalt", 0), 255)
            t.px(x + 1, y + 1, P("asphalt", 4), 140)          # lit lip (top-left light)
            if depth < 2 and rng.random() < 0.04:
                crack(x, y, ang + rng.choice([-1, 1]) * 0.9, int(L * 0.4), depth + 1)
    for _ in range(5):
        crack(rng.integers(10, 118), rng.integers(10, 118), rng.random() * 6.28, rng.integers(40, 90))
    for _ in range(3):                                       # potholes
        cx, cy, r = rng.integers(20, 108), rng.integers(20, 108), rng.integers(4, 9)
        for y in range(-r, r + 1):
            for x in range(-r, r + 1):
                d = math.hypot(x, y * 1.3)
                if d < r:
                    t.px(cx + x, cy + y, P("asphalt", 1 if d < r - 1.5 else 3), 255 if d < r - 1 else 160)
    return t


def marking_damaged():
    t = Tex("T_Veil_MarkingDamaged", 32, 128, fill=("road_yellow", 2))
    rng = t.rng
    for y in range(128):
        seg = (y // 20) % 2 == 0 or rng.random() < 0.02
        if not seg:
            continue
        for x in range(10, 22):
            t.px(x, y, P("road_yellow", 3 if x < 12 else 2), 255)
    for _ in range(16):                                      # worn-away chips: clustered, ragged edges
        cx, cy, r = rng.integers(9, 23), rng.integers(0, 128), rng.integers(2, 5)
        for y in range(cy - r, cy + r + 1):
            for x in range(cx - r, cx + r + 1):
                if 0 <= y < 128 and 0 <= x < 32 and math.hypot(x - cx, (y - cy) * 0.7) < r - rng.random() * 0.8:
                    t.al[y, x] = 0
    for y in range(128):                                     # grime creeping into the remaining paint
        for x in range(10, 22):
            if t.al[y, x] and (x + y * 3) % 13 == 0:
                t.a[y, x] = P("road_yellow", 1)
    return t


def marking_distorted():
    t = Tex("T_Veil_MarkingDistorted", 64, 128, fill=("road_white", 2))
    for y in range(128):
        for x in range(64):
            # an arrow whose shaft and head are pulled sideways in a slow S, as if smeared
            off = 9 * math.sin(y / 128 * math.pi * 1.6)
            xx = x - off
            shaft = 26 <= xx <= 37 and 40 <= y <= 124
            head = y < 44 and abs(xx - 31.5) <= (y - 2) * 0.62
            if shaft or head:
                t.px(x, y, P("road_white", 2 if (x + y) % 7 else 1), 255 if (x * 3 + y) % 11 else 120)
    return t


def window_stain():
    t = Tex("T_Veil_WindowStain", 64, 64, fill=("damp", 1))
    n = tile_noise(64, 64, t.rng, (4, 8), (0.6, 0.4))
    ys, _ = np.mgrid[0:64, 0:64]
    a = np.clip((ys / 63) ** 1.4 * 1.2 + (n - 0.5) * 0.6, 0, 1)
    t.al = qa(a * 0.8)
    t.a = np.where(n > 0.55, P("damp", 0), P("damp", 2))
    for k in range(3):                                       # tide lines
        y0 = 30 + k * 9
        for x in range(64):
            t.px(x, y0 + int(2 * math.sin(x * 0.3 + k)), P("damp", 3), 200)
    return t


def growth():
    t = Tex("T_Veil_Growth", 64, 64, alpha=False, fill=("corrupt", 2))
    n = tile_noise(64, 64, t.rng, (4, 8, 16), (0.5, 0.3, 0.2))
    t.a = P.ramp("corrupt", (q(n, 5) * 4.999).astype(int))
    for _ in range(40):
        x, y = t.rng.integers(0, 64, 2)
        t.px(x, y, P("damp", 3), wrap=True)
        t.px(x + 1, y, P("damp", 4), wrap=True)
    return t


def withered_grass():
    t = Tex("T_Veil_WitheredGrass", 64, 32, fill=("dead", 2))
    rng = t.rng
    for _ in range(26):
        x = rng.integers(1, 63)
        L = rng.integers(10, 31)
        lean = rng.normal(0, 0.35)
        for y in range(L):
            yy = 31 - y
            xx = x + lean * y + (0.08 * y * y / L if rng.random() < 0.5 else 0)    # some blades droop
            t.px(xx, yy, P("dead", 1 + (y > L * 0.6) + (rng.random() < 0.2)), 255)
    return t


def symbols():
    t = Tex("T_Veil_Symbols", 64, 64, fill=("stain", 1))
    # abstract marks only: broken concentric arcs and tally-like strokes (no letters, no meaning)
    for r, gap0 in ((24, 0.3), (17, 2.0), (9, 4.1)):
        for a in np.linspace(0, 2 * math.pi, int(r * 8)):
            if (a - gap0) % (2 * math.pi) < 0.9:
                continue
            for th in (0, 0.6):
                t.px(32 + (r + th) * math.cos(a), 32 + (r + th) * math.sin(a), P("stain", 0), 230)
    for k in range(5):
        x = 6 + k * 3
        for y in range(48, 60):
            t.px(x + (y - 48) * 0.15, y, P("stain", 0), 220)
    for y in range(30, 35):
        for x in range(30, 35):
            t.px(x, y, P("stain", 0), 255)
    return t


def shadow():
    t = Tex("T_Veil_Shadow", 64, 128, fill=("ink", 0))
    ys, xs = np.mgrid[0:128, 0:64]
    w = 14 + 9 * np.sin(ys / 128 * math.pi) + 3 * np.sin(ys * 0.21)
    d = np.abs(xs - 31.5 - 4 * np.sin(ys * 0.05)) / w
    a = np.clip(1.2 - d, 0, 1) * np.clip((127 - ys) / 30, 0, 1) * np.clip(ys / 18, 0, 1)
    t.al = qa(a * 0.9)
    return t


def condensation():
    t = Tex("T_Veil_Condensation", 64, 64, fill=("bath_tile", 4))
    n = tile_noise(64, 64, t.rng, (8, 16), (0.6, 0.4))
    t.al = qa(0.35 + 0.25 * n)
    rng = t.rng
    for _ in range(9):                                       # drips that cleared a line through the fog
        x = rng.integers(2, 62)
        y = rng.integers(0, 30)
        for k in range(rng.integers(10, 40)):
            if y + k < 64:
                t.al[y + k, x] = 30
                t.a[y + k, x] = P("glass", 4)
        if y + k + 1 < 64:
            t.px(x, y + k + 1, P("bath_tile", 5), 255)
    for _ in range(60):
        t.px(rng.integers(0, 64), rng.integers(0, 64), P("bath_tile", 5), 255)
    return t


def leaves():
    t = Tex("T_Veil_Leaves", 64, 16, fill=("leaf_rust", 1))
    for f, ramp in enumerate(("leaf_rust", "leaf_ochre", "leaf_brown", "dead")):
        cx = f * 16 + 8
        for y in range(16):
            for x in range(16):
                dx, dy = (x - 7.5) / 6.5, (y - 7.5) / 4.0
                if dx * dx + dy * dy < 1.0 and not (abs(dy) < 0.12 and dx > -0.8):
                    t.px(f * 16 + x, y, P(ramp, 1 + (y < 7)), 255)
                elif abs(dy) < 0.12 and abs(dx) < 1.1:
                    t.px(f * 16 + x, y, P(ramp, 0), 255)
    return t


def small(name, w, h, ramp, k, shape):
    t = Tex(name, w, h, fill=(ramp, k))
    for y in range(h):
        for x in range(w):
            a = shape(x, y)
            if a > 0:
                t.px(x, y, P(ramp, k + (1 if a > 0.8 else 0)), int(ALPHA_LV[int(min(a, 1) * 5)]))
    return t


def particles():
    return [
        small("T_Veil_Rain", 4, 32, "glass", 3, lambda x, y: (1.0 if x in (1, 2) else 0.0) * (0.4 + 0.6 * y / 31)),
        small("T_Veil_Spark", 8, 8, "glow", 2, lambda x, y: max(0.0, 1.0 - math.hypot(x - 3.5, y - 3.5) / 3.6)),
        small("T_Veil_Dust", 8, 8, "paint_white", 2, lambda x, y: max(0.0, 1.0 - math.hypot(x - 3.5, y - 3.5) / 3.2) * 0.7),
        small("T_Veil_Drip", 8, 8, "glass", 3, lambda x, y: 1.0 if math.hypot((x - 3.5) / 2.2, (y - 4.5) / 3.2) < 1 else 0.0),
        small("T_Veil_LightShaft", 16, 64, "bath_tile", 3,
              lambda x, y: (1 - abs(x - 7.5) / 8) * (1 - y / 64) * 0.75 if abs(x - 7.5) < 8 else 0.0),
        small("T_Veil_Fluorescent", 16, 16, "bath_tile", 4, lambda x, y: 1.0),
    ]


ALL = [mist_noise, fog_card, wall_streaks, ground_blight, lambda: asphalt_cracks("T_Veil_AsphaltCracks_A"),
       lambda: asphalt_cracks("T_Veil_AsphaltCracks_B"), marking_damaged, marking_distorted, window_stain, growth, withered_grass,
       symbols, shadow, condensation, leaves]


def build(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    made = []
    texs = [f() for f in ALL] + particles()
    for t in texs:
        p = os.path.join(out_dir, t.name + ".png")
        t.image().save(p, format="PNG", optimize=True)
        made.append((t.name, p, t.w, t.h, t.alpha))
    return made
