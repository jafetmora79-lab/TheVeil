"""THE VEIL - Pack 07 pixel textures: the dimensional-creature palette and painters.

Palette: the Greyhaven master ramps (Pack 01) + the Pack 06 character ramps (chr_tex.ALL_RAMPS) + the CRT_RAMPS
below. Every albedo pixel is a palette entry (validators check this). Emission masks are black except for pixels
taken from the pale "crt_glow" ramp, and they are kept sparse: the creatures are dark, with a little unnatural light.

Ramps are dark -> light and hue-shifted like the rest of the game: shadows lean blue-violet, lights lean
sickly grey-green / bone.
"""
import math

import numpy as np
from PIL import Image

import cr_core  # noqa: F401  (sets sys.path)
from chr_tex import ALL_RAMPS
from veil_texgen.core import Pal, rng_for, vnoise, voronoi, crack_mask, bayer, norm01  # noqa: F401

CRT_RAMPS = {
    "crt_char":   ["#0b0a0f", "#131118", "#1c1922", "#26222d", "#322d39", "#3f3947"],   # charcoal
    "crt_violet": ["#140f19", "#1e1625", "#2a1f33", "#382a42", "#493753", "#5c4766"],   # desaturated purple
    "crt_moss":   ["#0e1311", "#151c19", "#1e2722", "#28332d", "#34413a", "#435149"],   # dark grey-green
    "crt_bone":   ["#2b2721", "#3d372e", "#524a3d", "#6a604f", "#837764", "#9c8f79"],   # muted bone
    "crt_abyss":  ["#05060a", "#090b12", "#0e121c", "#141a28", "#1c2436"],              # deep blue-black
    "crt_flesh":  ["#1a0f14", "#28161d", "#381e27", "#4a2833", "#5d3540"],              # wet inner tissue
    "crt_glow":   ["#3c4a52", "#5f7680", "#8aa6ac", "#b7d3d2", "#dcefe9"],              # unnatural pale light
}
RAMPS = dict(ALL_RAMPS)
RAMPS.update(CRT_RAMPS)
P = Pal(RAMPS)
BLACK = np.array([0, 0, 0], np.uint8)


def palette_rgb():
    return {tuple(int(x) for x in c) for c in P.rgb}


def glow_rgb():
    return {tuple(int(x) for x in P.rgb[P("crt_glow", k)]) for k in range(len(CRT_RAMPS["crt_glow"]))}


class Canvas:
    """Indexed albedo canvas + emission canvas (None = black)."""

    def __init__(self, w, h, fill=("crt_char", 1), seed="crt"):
        self.w, self.h = w, h
        self.a = np.full((h, w), P(*fill), np.int64)
        self.e = np.full((h, w), -1, np.int64)
        self.rng = rng_for(seed)

    def region(self, x, y, w, h):
        return Region(self, x, y, w, h)

    def save(self, albedo_path, emit_path=None):
        Image.fromarray(P.rgb[self.a]).save(albedo_path, optimize=True)
        if emit_path:
            em = np.zeros((self.h, self.w, 3), np.uint8)
            m = self.e >= 0
            em[m] = P.rgb[self.e[m]]
            Image.fromarray(em).save(emit_path, optimize=True)
        with open(albedo_path, "rb") as f:
            alb = f.read()
        emit = None
        if emit_path:
            with open(emit_path, "rb") as f:
                emit = f.read()
        return alb, emit


class Region:
    def __init__(self, cv, x, y, w, h):
        self.cv, self.x, self.y, self.w, self.h = cv, x, y, w, h

    @property
    def a(self):
        return self.cv.a[self.y:self.y + self.h, self.x:self.x + self.w]

    @property
    def e(self):
        return self.cv.e[self.y:self.y + self.h, self.x:self.x + self.w]

    def uv(self, pad=0.5):
        """Atlas rect (u0, v0, u1, v1) of this region, inset by pad pixels (no bleeding with nearest filtering)."""
        W, H = self.cv.w, self.cv.h
        return ((self.x + pad) / W, (self.y + pad) / H, (self.x + self.w - pad) / W, (self.y + self.h - pad) / H)


# ------------------------------------------------------------------ helpers
def ramp_fill(field, ramp, lo=0, hi=None, dither=0.6):
    """Map a 0..1 field onto ramp levels lo..hi with ordered dither (pixel-art banding)."""
    n = len(RAMPS[ramp])
    hi = n - 1 if hi is None else hi
    h, w = field.shape
    lv = lo + field * (hi - lo + 1) + (bayer(h, w) - 0.5) * dither
    return P.ramp(ramp, np.clip(np.floor(lv), lo, hi).astype(int))


def shift(idx, d, mask):
    out = idx.copy()
    out[mask] = P.shift(idx[mask], d)
    return out


def tile_noise(w, h, cell, rng, octaves=2):
    return vnoise(w, h, cell, rng, octaves=octaves)


def lit_edges(mask):
    """Top-left lit rim and bottom-right shadow rim of a mask (pixel-art bevel)."""
    up = np.roll(mask, 1, 0)
    lf = np.roll(mask, 1, 1)
    dn = np.roll(mask, -1, 0)
    rt = np.roll(mask, -1, 1)
    lit = mask & (~up | ~lf)
    dark = mask & (~dn | ~rt)
    return lit & ~dark, dark


# ------------------------------------------------------------------ painters
def paint_hide(rg, seed, base="crt_moss", deep="crt_abyss", accent="crt_violet", cracks=6, glow_cracks=3, scale=1):
    """Tileable dimensional hide: warped fibrous striations, long folded creases (dark core, lit lip), sparse raised
    plaques, violet bruising, pore clusters and a few faint luminous cracks (emission). Every term is periodic, so
    the whole canvas tiles."""
    w, h = rg.w, rg.h
    rng = rng_for(seed)
    Y, Xg = np.mgrid[0:h, 0:w].astype(float)
    n1 = tile_noise(w, h, max(8, 32 // scale), rng, 3)
    warp = tile_noise(w, h, 16, rng, 2)
    fib = 0.5 + 0.5 * np.sin(2 * math.pi * (11 * Y / h + 2 * Xg / w) + warp * 5.0 + n1 * 3.0)
    f = norm01(0.55 * n1 + 0.30 * fib + 0.15 * warp)
    a = ramp_fill(f, base, 1, 4, dither=0.8)
    # bruising: large soft violet regions
    bru = tile_noise(w, h, 16, rng, 2)
    a = np.where(bru > 0.6, ramp_fill(f, accent, 1, 3), a)
    a = np.where((bru > 0.52) & (bru <= 0.6) & (X_checker(h, w)), ramp_fill(f, accent, 1, 3), a)
    # sparse raised plaques (only some voronoi cells)
    cid, d1, d2, vx, vy = voronoi(w, h, max(16, 32 // scale), rng, jitter=0.9)
    pick = (np.sin(cid * 12.9898) * 43758.5453 % 1.0) < 0.28
    plaque = pick & (d1 < 0.42)
    lit, dark = lit_edges(plaque)
    a = np.where(plaque, P.shift(a, 1), a)
    a = np.where(lit, P.shift(a, 1), a)
    a = np.where(dark, P(deep, 2), a)
    # pore clusters
    cl = tile_noise(w, h, 16, rng, 1) > 0.7
    pores = (rng.random((h, w)) < 0.05) & cl & ~plaque
    a = np.where(pores, P(deep, 0), a)
    a = np.where(np.roll(pores, 1, 0), P.shift(a, 1), a)
    rg.a[:] = a
    # long folded creases + luminous cracks
    for k in range(cracks + glow_cracks):
        m = crack_mask(w, h, rng, rng.integers(0, w), rng.integers(0, h), rng.integers(w // 3, w // 2 + 8),
                       angle=rng.uniform(-0.6, 0.6) + (math.pi / 2 if k % 2 else 0.0), wiggle=0.22, branch=0.03)
        if k < cracks:
            rg.a[m] = P(deep, 1)
            rg.a[np.roll(m, 1, 0) & ~m] = P(base, 5)
            rg.a[np.roll(m, -1, 0) & ~m] = P(deep, 2)
        else:
            rg.a[m] = P("crt_glow", 0)
            rg.e[m] = P("crt_glow", 1)
            core = m & (rng.random((h, w)) < 0.25)
            rg.e[core] = P("crt_glow", 2)


def X_checker(h, w):
    Y, Xg = np.mgrid[0:h, 0:w]
    return ((Y + Xg) % 2) == 0


def paint_tentacle(rg, seed, base="crt_violet", back="crt_char", ridge_step=6, nodes=True):
    """Tentacle skin, x = around (u), y = along (v). Back (x ~ 0 / w) dark charcoal with ring ridges; the
    underside band (x ~ w/2) paler violet with pale sensory pits (faint emission)."""
    w, h = rg.w, rg.h
    rng = rng_for(seed)
    X = (np.arange(w)[None, :] + 0.5) / w
    under = np.exp(-((X - 0.5) / 0.17) ** 2)                      # 1 on the underside band
    n = tile_noise(w, h, 16, rng, 2)
    ring_ph = (np.arange(h)[:, None] + n * 3.0) % ridge_step
    ridge = ring_ph < 1.0
    groove = (ring_ph >= ridge_step - 1.0)
    f = norm01(0.6 * n + 0.4 * (1 - np.abs(X - 0.5) * 2))
    a_back = ramp_fill(f, back, 1, 4)
    a_under = ramp_fill(f, base, 2, 4)
    a = np.where(under + (n - 0.5) * 0.4 > 0.45, a_under, a_back)
    a = np.where(ridge, P.shift(a, 1), a)
    a = np.where(groove, P("crt_abyss", 1), a)
    # long dorsal streaks
    streak = (np.abs(X - 0.0) < 0.06) | (np.abs(X - 1.0) < 0.06)
    a = np.where(streak & ~groove, P("crt_moss", 3), a)
    rg.a[:] = a
    if nodes:
        # pits on the underside between ridges, paired and staggered
        for y in range(2, h, ridge_step):
            for side in (-1, 1):
                x = int(w * (0.5 + side * (0.08 + 0.03 * rng.random())))
                yy = (y + (1 if side > 0 else 3)) % h
                rg.a[yy, x] = P("crt_abyss", 0)
                rg.a[(yy + 1) % h, x] = P("crt_glow", 1)
                if rng.random() < 0.5:
                    rg.e[(yy + 1) % h, x] = P("crt_glow", 1)


def paint_plate(rg, seed, ramp="crt_bone", dark="crt_char", rings=4, seam_glow=0.0):
    """Armour / growth plate: growth rings concentric to the lower edge, chipped rim, dark crust patches."""
    w, h = rg.w, rg.h
    rng = rng_for(seed)
    Y, X = np.mgrid[0:h, 0:w].astype(float)
    cx, cy = w * (0.4 + 0.2 * rng.random()), h * 1.1
    d = np.sqrt(((X - cx) / w) ** 2 + ((Y - cy) / h) ** 2)
    n = vnoise(w, h, 8, rng, 2)
    band = ((d * rings * 2 + n * 0.8) % 1.0)
    f = norm01(1.0 - Y / h * 0.6 + n * 0.5 - X / w * 0.2)
    a = ramp_fill(f, ramp, 1, 5)
    a = np.where(band < 0.18, P.shift(a, -2), a)
    crust = vnoise(w, h, 8, rng, 2) > 0.74
    a = np.where(crust, P.shift(a, -2), a)
    a = np.where(crust & (vnoise(w, h, 8, rng, 1) > 0.7), ramp_fill(f, dark, 2, 3), a)
    a[0, :] = P(ramp, 5)
    a[:, 0] = P.shift(a[:, 0], 1)
    a[-1, :] = P(dark, 0)
    a[:, -1] = P(dark, 1)
    rg.a[:] = a
    if seam_glow > 0:
        m = (band < 0.08) & (rng.random((h, w)) < seam_glow)
        rg.a[m] = P("crt_glow", 0)
        rg.e[m] = P("crt_glow", 1)


def paint_orb(rg, seed, iris="crt_glow", slit=True, glow=True, sclera="crt_violet"):
    """Sensory orb (u around, v pole to pole): wet dark rim, pale lens, a dark vertical slit; emissive lens."""
    w, h = rg.w, rg.h
    rng = rng_for(seed)
    Y, X = np.mgrid[0:h, 0:w].astype(float)
    fx = (X + 0.5) / w
    fy = (Y + 0.5) / h
    # front of the orb is u = 0.5 (tube_frame convention), centre of v
    d = np.sqrt(((fx - 0.5) * 2.2) ** 2 + ((fy - 0.5) * 1.6) ** 2)
    a = ramp_fill(norm01(1 - d + vnoise(w, h, 4, rng, 1) * 0.2), sclera, 0, 3)
    lens = d < 0.55
    a = np.where(lens, ramp_fill(norm01(1 - d / 0.55 - fy * 0.3), iris, 1, 4), a)
    if slit:
        sm = lens & (np.abs(fx - 0.5) < 0.07) & (np.abs(fy - 0.5) < 0.32)
        a = np.where(sm, P("crt_abyss", 0), a)
    hl = (np.abs(fx - 0.42) < 0.06) & (np.abs(fy - 0.36) < 0.08)
    a = np.where(hl & lens, P(iris, 4), a)
    rg.a[:] = a
    if glow:
        e = np.where(lens & (a != P("crt_abyss", 0)), P("crt_glow", 1), -1)
        e = np.where(lens & (d < 0.3) & (a != P("crt_abyss", 0)), P("crt_glow", 2), e)
        rg.e[:] = e


def paint_maw(rg, seed, teeth_rows=2):
    """Inner maw: wet violet-flesh gradient with rows of small bone hooks along u."""
    w, h = rg.w, rg.h
    rng = rng_for(seed)
    n = vnoise(w, h, 8, rng, 2)
    Y = (np.arange(h)[:, None] + 0.5) / h
    a = ramp_fill(norm01(n * 0.5 + (1 - np.abs(Y - 0.5) * 2) * 0.5), "crt_flesh", 0, 4)
    rg.a[:] = a
    for r in range(teeth_rows):
        y0 = int(h * (0.12 + 0.76 * r / max(1, teeth_rows - 1))) if teeth_rows > 1 else h // 2
        x = 0
        while x < w:
            tl = int(rng.integers(2, 5))
            for k in range(tl):
                yy = y0 + (k if r == 0 else -k)
                if 0 <= yy < h:
                    rg.a[yy, x] = P("crt_bone", 5 - k)
                    if x + 1 < w and k < tl - 1:
                        rg.a[yy, x + 1] = P("crt_bone", 3 - min(k, 2))
            x += int(rng.integers(3, 6))


def paint_claw(rg, seed, ramp="crt_bone"):
    """Claw / hook / leg tip: v along length (tip at v0), banded, darkening toward the tip."""
    w, h = rg.w, rg.h
    rng = rng_for(seed)
    Y = (np.arange(h)[:, None] + 0.5) / h
    X = (np.arange(w)[None, :] + 0.5) / w
    n = vnoise(w, h, 4, rng, 1)
    f = norm01(Y * 0.7 + (1 - np.abs(X - 0.5) * 2) * 0.4 + n * 0.2)
    a = ramp_fill(f, ramp, 0, 5)
    band = ((Y * 7 + n * 0.6) % 1.0) < 0.15
    a = np.where(band, P.shift(a, -2), a)
    tip = Y < 0.25
    a = np.where(tip, ramp_fill(f, "crt_char", 1, 3), a)
    rg.a[:] = a


def paint_collar(rg, seed):
    """Orifice lips around tentacle roots: puckered radial folds, dark wet inside (v0) to hide outside (v1)."""
    w, h = rg.w, rg.h
    rng = rng_for(seed)
    X = (np.arange(w)[None, :] + 0.5) / w
    Y = (np.arange(h)[:, None] + 0.5) / h
    folds = 0.5 + 0.5 * np.sin(X * 2 * math.pi * 9 + vnoise(w, h, 8, rng, 1) * 2)
    f = norm01(Y * 0.7 + folds * 0.4)
    a = ramp_fill(f, "crt_flesh", 0, 4)
    a = np.where(Y > 0.7, ramp_fill(f, "crt_moss", 1, 3), a)
    a = np.where((folds < 0.15) & (Y > 0.2), P("crt_abyss", 1), a)
    rg.a[:] = a
    m = (Y < 0.18) & (folds > 0.8) & (rng.random((h, w)) < 0.5)
    rg.e[m] = P("crt_glow", 0)


def paint_core(rg, seed):
    """Suspended inner core: dim pale swirl on violet; the brightest thing on the Colossus, still kept low."""
    w, h = rg.w, rg.h
    rng = rng_for(seed)
    Y, X = np.mgrid[0:h, 0:w].astype(float)
    ang = np.arctan2(Y - h / 2, X - w / 2)
    rr = np.sqrt((X - w / 2) ** 2 + (Y - h / 2) ** 2) / (w / 2)
    sw = 0.5 + 0.5 * np.sin(ang * 3 + rr * 9 + vnoise(w, h, 8, rng, 1) * 3)
    f = norm01(sw * 0.6 + (1 - rr) * 0.4)
    a = ramp_fill(f, "crt_violet", 1, 5)
    hot = f > 0.72
    a = np.where(hot, ramp_fill(f, "crt_glow", 0, 3), a)
    rg.a[:] = a
    rg.e[:] = np.where(hot, P("crt_glow", 2), np.where(f > 0.55, P("crt_glow", 0), -1))


def paint_flat(rg, seed, ramp, lo=1, hi=3, cell=8):
    w, h = rg.w, rg.h
    rng = rng_for(seed)
    rg.a[:] = ramp_fill(vnoise(w, h, cell, rng, 2), ramp, lo, hi)
