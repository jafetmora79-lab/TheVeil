"""Registers ChatGPT expression tiles onto the base face render they were made from (shift + scale found on the parts that never change: hair outline, clothes).
usage: python register_expression_sheets.py <sheet.webp> <base_1000.png> <out_dir>
The sheet is 3 x 2 tiles: blink, talk_small, talk_wide / scared, angry, worried. Writes <out_dir>/face_<name>.png (1000x1000) and face_neutral.png (the base), prints the residual."""
import sys, os
import numpy as np
from PIL import Image

NAMES = ['blink', 'talk_small', 'talk_wide', 'scared', 'angry', 'worried']


def gray(im):
    a = np.asarray(im.convert('RGB'), dtype=np.float32) / 255.0
    return a @ np.array([0.3, 0.59, 0.11], dtype=np.float32)


def edges(g):
    gx = np.zeros_like(g); gy = np.zeros_like(g)
    gx[:, 1:-1] = g[:, 2:] - g[:, :-2]
    gy[1:-1, :] = g[2:, :] - g[:-2, :]
    return np.hypot(gx, gy)


def fft_corr(a, b):
    n = a.shape[0] * 2
    fa = np.fft.rfft2(a, s=(n, n)); fb = np.fft.rfft2(b, s=(n, n))
    c = np.fft.irfft2(fa * np.conj(fb), s=(n, n))
    return c


def blur(a, k=5):
    out = a.copy()
    for _ in range(k):
        out = (out + np.roll(out, 1, 0) + np.roll(out, -1, 0) + np.roll(out, 1, 1) + np.roll(out, -1, 1)) / 5.0
    return out


def register(base, tile, bands=None):
    """Silhouette registration: the head/hair/shoulder outline is the same in every expression. base, tile: PIL RGB 512.
    Returns (score, scale, dx, dy): the tile, scaled about its centre by `scale` and shifted by (dx, dy) 512-px, best overlaps the base's silhouette."""
    mb = (np.asarray(base.convert('RGB')).sum(axis=2) > 30).astype(np.float32)
    Eb = blur(mb, 2)
    best = None
    for s in np.arange(0.90, 1.12, 0.004):
        n = int(round(512 * s))
        t = tile.resize((n, n), Image.BICUBIC)
        canvas = Image.new('RGB', (512, 512))
        canvas.paste(t, ((512 - n) // 2, (512 - n) // 2))
        mt = (np.asarray(canvas).sum(axis=2) > 30).astype(np.float32)
        Et = blur(mt, 2)
        c = fft_corr(Eb, Et)
        idx = np.unravel_index(np.argmax(c), c.shape)
        # overlap score: intersection over union of the two masks at that shift
        dy, dx = idx
        if dy > 512: dy -= 1024
        if dx > 512: dx -= 1024
        sh = np.roll(np.roll(mt, dy, 0), dx, 1)
        inter = (sh * mb).sum(); union = ((sh + mb) > 0).sum()
        iou = inter / max(union, 1)
        if best is None or iou > best[0]:
            best = (iou, s, dx, dy)
    return best


def eye_centres(img, spacing_px):
    """The two eye centres (pupils, or the lash lines of a blink) of a 1000 px face crop, found as the dark pixels inside a window around where the eyes sit."""
    g = gray(img)
    out = []
    for sx in (-1, 1):
        cx = 500 + sx * spacing_px / 2.0
        cy = 460
        x0, x1, y0, y1 = int(cx - 55), int(cx + 55), int(cy - 40), int(cy + 40)
        w = g[y0:y1, x0:x1] < 0.12
        ys, xs = np.nonzero(w)
        if len(xs) < 20:
            return None
        out.append((x0 + xs.mean(), y0 + ys.mean()))
    return out


def apply_similarity(tile1000, src_eyes, dst_eyes, size=1000):
    """scale + shift (no rotation) taking the tile's eye pair onto the base's."""
    sd = np.hypot(dst_eyes[1][0] - dst_eyes[0][0], dst_eyes[1][1] - dst_eyes[0][1])
    ss = np.hypot(src_eyes[1][0] - src_eyes[0][0], src_eyes[1][1] - src_eyes[0][1])
    k = sd / ss
    smx, smy = (src_eyes[0][0] + src_eyes[1][0]) / 2, (src_eyes[0][1] + src_eyes[1][1]) / 2
    dmx, dmy = (dst_eyes[0][0] + dst_eyes[1][0]) / 2, (dst_eyes[0][1] + dst_eyes[1][1]) / 2
    # out(x,y) = tile((x - dmx)/k + smx, (y - dmy)/k + smy)
    return tile1000.transform((size, size), Image.AFFINE, (1 / k, 0, smx - dmx / k, 0, 1 / k, smy - dmy / k), resample=Image.BICUBIC), k


def apply(tile, s, dx, dy, size=1000):
    """tile 512 -> 1000x1000 aligned to the base."""
    k = size / 512.0
    big = tile.resize((int(512 * k), int(512 * k)), Image.BICUBIC)
    n = int(round(size * s))
    big = big.resize((n, n), Image.BICUBIC)
    canvas = Image.new('RGB', (size, size))
    canvas.paste(big, ((size - n) // 2 + int(round(dx * k)), (size - n) // 2 + int(round(dy * k))))
    return canvas


if __name__ == '__main__':
    sheet_p, base_p, out = sys.argv[1:4]
    os.makedirs(out, exist_ok=True)
    sheet = Image.open(sheet_p).convert('RGB')
    base1000 = Image.open(base_p).convert('RGB')
    base = base1000.resize((512, 512), Image.LANCZOS)
    base1000.save(os.path.join(out, 'face_neutral.png'))
    Bg = gray(base1000)
    spacing = float(sys.argv[4]) if len(sys.argv) > 4 else 203.0
    base_eyes = eye_centres(base1000, spacing)
    print('base eyes', base_eyes)
    for i, name in enumerate(NAMES):
        tile = sheet.crop(((i % 3) * 512, (i // 3) * 512, (i % 3) * 512 + 512, (i // 3) * 512 + 512))
        val, s, dx, dy = register(base, tile)
        reg = apply(tile, s, dx, dy)            # silhouette first (puts the eyes in the search window)
        te = eye_centres(reg, spacing)
        if te is not None and base_eyes is not None:
            reg, k = apply_similarity(reg, te, base_eyes)
            print('   eyes refined: scale %.3f' % k, 'tile eyes', [tuple(round(v) for v in e) for e in te])
        else:
            print('   eyes not found: silhouette only')
        reg.save(os.path.join(out, 'face_%s.png' % name))
        Rg = gray(reg)
        band = np.zeros_like(Bg, dtype=bool); band[:300, :] = True
        res = np.abs(Rg - Bg)[band].mean()
        print('%-10s iou %.3f scale %.3f dx %+.1f dy %+.1f (512 px)  hair-band residual %.4f' % (name, val, s, dx, dy, res))
