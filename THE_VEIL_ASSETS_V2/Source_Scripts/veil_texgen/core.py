"""Core pixel-art toolkit for THE VEIL texture generator.

Design rules baked into this module:
  * Every canvas stores *palette indices*, never free RGB. A texture can only
    contain colours from the Greyhaven master palette (palettes.py).
  * Shading is done by stepping up/down a colour ramp (Pal.shift), which is
    how a pixel artist shades - not by multiplying RGB values.
  * Every drawing operation wraps around the canvas edges, so textures tile
    seamlessly by construction.
  * Noise is only ever used as *low-frequency structure* (blobs, patches,
    wear maps) which is then quantised into a few ramp steps and cleaned of
    orphan pixels. Fine detail comes from explicit shapes: boards, bricks,
    stones, blades, cracks, leaves, sprites.
"""
import math
import zlib

import numpy as np
from PIL import Image

from .palettes import RAMPS


# ----------------------------------------------------------------------------
# Palette
# ----------------------------------------------------------------------------
def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


class Pal:
    """Global indexed palette made of named ramps (dark -> light)."""

    def __init__(self, ramps):
        self.start, self.size = {}, {}
        cols, pos, rstart, rlen = [], [], [], []
        for name, ramp in ramps.items():
            s = len(cols)
            self.start[name], self.size[name] = s, len(ramp)
            for k, c in enumerate(ramp):
                cols.append(hex_rgb(c))
                pos.append(k)
                rstart.append(s)
                rlen.append(len(ramp))
        self.rgb = np.array(cols, np.uint8)
        self._pos = np.array(pos)
        self._rstart = np.array(rstart)
        self._rlen = np.array(rlen)

    def __call__(self, name, k=0):
        n = self.size[name]
        if k < 0:
            k += n
        return self.start[name] + max(0, min(n - 1, int(k)))

    def ramp(self, name, levels):
        """Map an int array of levels onto a ramp (clamped)."""
        return self.start[name] + np.clip(np.asarray(levels), 0, self.size[name] - 1)

    def shift(self, idx, d):
        """Step indices up (+) or down (-) inside their own ramp."""
        idx = np.asarray(idx)
        p = np.clip(self._pos[idx] + d, 0, self._rlen[idx] - 1)
        return self._rstart[idx] + p

    def level(self, idx):
        return self._pos[np.asarray(idx)]


P = Pal(RAMPS)


def rng_for(name):
    return np.random.default_rng(zlib.crc32(name.encode("utf-8")))


# ----------------------------------------------------------------------------
# Canvas
# ----------------------------------------------------------------------------
class Canvas:
    def __init__(self, w, h, fill, alpha=False):
        self.w, self.h = w, h
        self.a = np.full((h, w), fill, np.int64)
        self.alpha = np.zeros((h, w), np.uint8) if alpha else None

    # -- pixel ops (wrapping) --
    def set(self, x, y, v, al=None):
        x, y = int(x) % self.w, int(y) % self.h
        self.a[y, x] = v
        if al is not None and self.alpha is not None:
            self.alpha[y, x] = al

    def get(self, x, y):
        return self.a[int(y) % self.h, int(x) % self.w]

    def shift_px(self, x, y, d):
        x, y = int(x) % self.w, int(y) % self.h
        self.a[y, x] = P.shift(self.a[y, x], d)

    def _ix(self, x, y, w, h):
        ys = np.arange(int(y), int(y) + int(h)) % self.h
        xs = np.arange(int(x), int(x) + int(w)) % self.w
        return np.ix_(ys, xs)

    def rect(self, x, y, w, h, v, al=None):
        ix = self._ix(x, y, w, h)
        self.a[ix] = v
        if al is not None and self.alpha is not None:
            self.alpha[ix] = al

    def shift_rect(self, x, y, w, h, d):
        ix = self._ix(x, y, w, h)
        self.a[ix] = P.shift(self.a[ix], d)

    def paint(self, mask, v, al=None):
        if np.ndim(v) == 0:
            self.a[mask] = v
        else:
            self.a[mask] = np.asarray(v)[mask]
        if al is not None and self.alpha is not None:
            self.alpha[mask] = al

    def shift(self, mask, d):
        if np.isscalar(d):
            self.a[mask] = P.shift(self.a[mask], d)
        else:
            self.a[mask] = P.shift(self.a[mask], np.asarray(d)[mask])

    def line(self, x0, y0, x1, y1, v=None, d=None, al=None):
        for x, y in bresenham(x0, y0, x1, y1):
            if d is not None:
                self.shift_px(x, y, d)
            else:
                self.set(x, y, v, al)

    def sprite(self, x, y, rows, mapping, al=None):
        """Stamp an ASCII sprite. mapping: char -> palette index or
        ('shift', d). '.' is skipped."""
        for j, row in enumerate(rows):
            for i, ch in enumerate(row):
                if ch == "." or ch == " " or ch not in mapping:
                    continue
                m = mapping[ch]
                if isinstance(m, tuple) and m[0] == "shift":
                    self.shift_px(x + i, y + j, m[1])
                    if al is not None and self.alpha is not None:
                        self.alpha[(y + j) % self.h, (x + i) % self.w] = al
                else:
                    self.set(x + i, y + j, m, al)

    def to_image(self):
        rgb = P.rgb[self.a]
        if self.alpha is not None:
            rgba = np.dstack([rgb, self.alpha])
            return Image.fromarray(rgba.astype(np.uint8), "RGBA")
        return Image.fromarray(rgb.astype(np.uint8), "RGB")


def bresenham(x0, y0, x1, y1):
    x0, y0, x1, y1 = int(round(x0)), int(round(y0)), int(round(x1)), int(round(y1))
    dx, dy = abs(x1 - x0), -abs(y1 - y0)
    sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
    err = dx + dy
    while True:
        yield x0, y0
        if x0 == x1 and y0 == y1:
            return
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x0 += sx
        if e2 <= dx:
            err += dx
            y0 += sy


# ----------------------------------------------------------------------------
# Structured fields (tileable)
# ----------------------------------------------------------------------------
BAYER4 = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0


def bayer(h, w):
    return np.tile(BAYER4, (h // 4 + 1, w // 4 + 1))[:h, :w]


def vnoise(w, h, cell, rng, octaves=1, persistence=0.5, cell_y=None):
    """Tileable value noise. `cell` (and cell_y) must divide w (h)."""
    cx, cy = cell, (cell_y or cell)
    total = np.zeros((h, w))
    amp, norm = 1.0, 0.0
    for _ in range(octaves):
        nx, ny = max(1, w // cx), max(1, h // cy)
        g = rng.random((ny, nx))
        xs = np.arange(w) * nx / w
        ys = np.arange(h) * ny / h
        x0, y0 = np.floor(xs).astype(int), np.floor(ys).astype(int)
        fx, fy = xs - x0, ys - y0
        fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
        x0m, x1m, y0m, y1m = x0 % nx, (x0 + 1) % nx, y0 % ny, (y0 + 1) % ny
        a = g[np.ix_(y0m, x0m)]
        b = g[np.ix_(y0m, x1m)]
        c = g[np.ix_(y1m, x0m)]
        d = g[np.ix_(y1m, x1m)]
        FX, FY = fx[None, :], fy[:, None]
        v = (a * (1 - FX) + b * FX) * (1 - FY) + (c * (1 - FX) + d * FX) * FY
        total += amp * v
        norm += amp
        amp *= persistence
        cx, cy = max(1, cx // 2), max(1, cy // 2)
    return norm01(total / norm)


def norm01(f):
    lo, hi = f.min(), f.max()
    return (f - lo) / (hi - lo + 1e-9)


def quant(f, n, dither=0.0):
    """Quantise a 0..1 field into n bands, optional light ordered dither."""
    h, w = f.shape
    q = np.floor(f * n + (bayer(h, w) - 0.5) * dither).astype(int)
    return np.clip(q, 0, n - 1)


def tri(f, lo=0.22, hi=0.78, dither=0.0):
    """Three-band mask for subtle wear: 0 below lo, 2 above hi, else 1.
    Only the tails of the field are touched, so most of the surface keeps
    its base colour."""
    h, w = f.shape
    t = (bayer(h, w) - 0.5) * dither * 0.1
    out = np.ones(f.shape, int)
    out[f + t < lo] = 0
    out[f + t > hi] = 2
    return despeckle(out, 2)


def relief(f, thresh, step=1):
    """Emboss a smooth field: +1 where lit from top-left, -1 in shadow."""
    e = f - np.roll(np.roll(f, 1, 0), 1, 1)
    out = np.zeros(f.shape, int)
    out[e > thresh] = step
    out[e < -thresh] = -step
    return out


def despeckle(a, passes=1, lonely=True):
    """Remove orphan pixels so colours form deliberate clusters."""
    a = a.copy()
    for _ in range(passes):
        u, d = np.roll(a, 1, 0), np.roll(a, -1, 0)
        l, r = np.roll(a, 1, 1), np.roll(a, -1, 1)
        m = (u == d) & (d == l) & (l == r) & (u != a)
        a[m] = u[m]
        if lonely:
            alone = (u != a) & (d != a) & (l != a) & (r != a)
            # replace with the most common of up/left (cheap majority)
            rep = np.where(u == l, u, np.where(d == r, d, u))
            a[alone] = rep[alone]
    return a


def wrap_delta(a, b, period):
    return (a - b + period / 2.0) % period - period / 2.0


def voronoi(w, h, cell, rng, jitter=0.85, cell_y=None):
    """Tileable jittered-grid Voronoi.

    Returns (cell_id, d1, d2, vx, vy) where (vx, vy) is the vector from the
    nearest feature point to the pixel, normalised by cell size."""
    cx, cy = cell, (cell_y or cell)
    nx, ny = w // cx, h // cy
    px = (np.arange(nx)[None, :] + 0.5 + (rng.random((ny, nx)) - 0.5) * jitter) * cx
    py = (np.arange(ny)[:, None] + 0.5 + (rng.random((ny, nx)) - 0.5) * jitter) * cy
    Y, X = np.mgrid[0:h, 0:w].astype(float) + 0.5
    gx, gy = (X // cx).astype(int), (Y // cy).astype(int)
    d1 = np.full((h, w), np.inf)
    d2 = np.full((h, w), np.inf)
    cid = np.zeros((h, w), int)
    vx = np.zeros((h, w))
    vy = np.zeros((h, w))
    for oy in (-2, -1, 0, 1, 2):
        for ox in (-2, -1, 0, 1, 2):
            tx, ty = gx + ox, gy + oy
            mx, my = tx % nx, ty % ny
            fx = px[my, mx] + (tx // nx) * w
            fy = py[my, mx] + (ty // ny) * h
            ddx, ddy = (X - fx) / cx, (Y - fy) / cy
            d = np.sqrt(ddx * ddx + ddy * ddy)
            closer = d < d1
            d2 = np.where(closer, d1, np.minimum(d2, d))
            d1 = np.where(closer, d, d1)
            cid = np.where(closer, my * nx + mx, cid)
            vx = np.where(closer, ddx, vx)
            vy = np.where(closer, ddy, vy)
    return cid, d1, d2, vx, vy


def crack_mask(w, h, rng, x, y, length, angle=None, wiggle=0.35, branch=0.05, depth=0, mask=None):
    """Random-walk crack with direction persistence and branches."""
    if mask is None:
        mask = np.zeros((h, w), bool)
    ang = rng.random() * 2 * math.pi if angle is None else angle
    fx, fy = float(x), float(y)
    for i in range(int(length)):
        ang += rng.normal(0, wiggle)
        nx, ny = fx + math.cos(ang), fy + math.sin(ang)
        for px_, py_ in bresenham(fx, fy, nx, ny):
            mask[py_ % h, px_ % w] = True
        fx, fy = nx, ny
        if depth < 2 and rng.random() < branch:
            crack_mask(w, h, rng, fx, fy, length * rng.uniform(0.25, 0.5),
                       ang + rng.choice([-1, 1]) * rng.uniform(0.6, 1.2),
                       wiggle, branch * 0.6, depth + 1, mask)
    return mask


def apply_crack(cv, mask, dark, lip=1):
    """Draw a crack mask: dark core + lit lip on the bottom-right side."""
    lipm = np.roll(np.roll(mask, 1, 0), 1, 1) & ~mask
    cv.shift(lipm, lip)
    cv.paint(mask, dark)


def blob_mask(w, h, cx, cy, r, rng, rough=0.35, cell=8):
    """Irregular wrapped blob around (cx, cy)."""
    Y, X = np.mgrid[0:h, 0:w].astype(float)
    dx, dy = wrap_delta(X, cx, w), wrap_delta(Y, cy, h)
    d = np.sqrt(dx * dx + dy * dy) / r
    c = cell if (w % cell == 0 and h % cell == 0) else 4
    n = vnoise(w, h, c, rng, octaves=2)
    return d + (n - 0.5) * 2 * rough < 1.0


def rim_masks(mask):
    """For a *hole* mask: inner top-left rim (shadow), inner bottom-right
    rim (lit)."""
    tl = mask & ~np.roll(np.roll(mask, 1, 0), 1, 1)
    br = mask & ~np.roll(np.roll(mask, -1, 0), -1, 1)
    return tl, br


def outline(mask):
    """Pixels outside `mask` that touch it orthogonally."""
    n = (np.roll(mask, 1, 0) | np.roll(mask, -1, 0) | np.roll(mask, 1, 1) | np.roll(mask, -1, 1))
    return n & ~mask


def jitter_points(w, h, step, rng, prob=1.0, jitter=0.9):
    """Jittered grid of points - even, deliberate spacing (no clumped static)."""
    pts = []
    for gy in range(0, h, step):
        for gx in range(0, w, step):
            if rng.random() < prob:
                pts.append((int(gx + step / 2 + (rng.random() - 0.5) * step * jitter) % w,
                            int(gy + step / 2 + (rng.random() - 0.5) * step * jitter) % h))
    return pts


def partition(total, lo, hi, rng):
    """Random integer widths in [lo, hi] summing exactly to total."""
    for _ in range(200):
        ws = []
        while sum(ws) < total:
            ws.append(int(rng.integers(lo, hi + 1)))
        over = sum(ws) - total
        ws[-1] -= over
        if lo <= ws[-1] <= hi:
            return ws
        if ws[-1] < lo and len(ws) > 1:
            ws[-2] += ws[-1]
            ws.pop()
            if lo <= ws[-1] <= hi + 3:
                return ws
    n = max(1, round(total / ((lo + hi) / 2)))
    base = [total // n] * n
    for i in range(total - sum(base)):
        base[i] += 1
    return base


def periodic_wobble(length, rng, amp=2.0, k=(1, 2, 3)):
    """1-D periodic wobble over `length` samples (sum of integer-cycle sines)."""
    t = np.arange(length) / length * 2 * math.pi
    out = np.zeros(length)
    for kk in k:
        out += amp / kk * np.sin(kk * t + rng.random() * 2 * math.pi)
    return out
