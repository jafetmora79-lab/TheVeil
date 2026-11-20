"""Registers ChatGPT expression tiles onto the base crop with a shift and a separate x / y scale (they redraw the face a little taller or narrower), by overlapping the head/neck/clothes
silhouette and the skin region. usage: python register_aniso.py <sheet> <base_1000.png> <out_dir> [chin_row=700]
Writes face_<name>.png (1000x1000, aligned), face_neutral.png, face_mask.png (the base's face skin above chin_row)."""
import sys, os
import numpy as np
from PIL import Image
NAMES = ['blink', 'talk_small', 'talk_wide', 'scared', 'angry', 'worried']
R = 256


def feats(im):
    a = np.asarray(im.convert('RGB').resize((R, R), Image.BILINEAR)).astype(np.float32) / 255.0
    sil = (a.sum(axis=2) > 0.15).astype(np.float32)
    lum = a @ np.array([0.3, 0.59, 0.11], dtype=np.float32)
    skin = ((a[..., 0] > a[..., 1] * 1.15) & (a[..., 1] > a[..., 2] * 1.1) & (lum > 0.35)).astype(np.float32)
    return sil, skin


def blur(a, n=2):
    for _ in range(n):
        a = (a + np.roll(a, 1, 0) + np.roll(a, -1, 0) + np.roll(a, 1, 1) + np.roll(a, -1, 1)) / 5.0
    return a


def corr(a, b):
    n = a.shape[0] * 2
    c = np.fft.irfft2(np.fft.rfft2(a, s=(n, n)) * np.conj(np.fft.rfft2(b, s=(n, n))), s=(n, n))
    return c


def warp(arr, sx, sy):
    """scale about the centre"""
    img = Image.fromarray((arr * 255).astype(np.uint8))
    w = int(round(R * sx)); h = int(round(R * sy))
    img = img.resize((w, h), Image.BILINEAR)
    c = Image.new('L', (R, R))
    c.paste(img, ((R - w) // 2, (R - h) // 2))
    return np.asarray(c).astype(np.float32) / 255.0


def register(base_f, tile_f):
    bs, bk = base_f
    best = None
    B = blur(bs) + 1.5 * blur(bk)
    for sx in np.arange(0.84, 1.16, 0.02):
        for sy in np.arange(0.84, 1.16, 0.02):
            T = blur(warp(tile_f[0], sx, sy)) + 1.5 * blur(warp(tile_f[1], sx, sy))
            c = corr(B, T)
            i = np.unravel_index(np.argmax(c), c.shape)
            v = c[i] / (np.sqrt((B ** 2).sum() * (T ** 2).sum()) + 1e-6)
            dy, dx = i
            if dy > R: dy -= 2 * R
            if dx > R: dx -= 2 * R
            if best is None or v > best[0]:
                best = (v, sx, sy, dx, dy)
    return best


def apply(tile1000, sx, sy, dx, dy):
    k = 1000.0 / R
    w = int(round(1000 * sx)); h = int(round(1000 * sy))
    t = tile1000.resize((w, h), Image.BICUBIC)
    c = Image.new('RGB', (1000, 1000))
    c.paste(t, ((1000 - w) // 2 + int(round(dx * k)), (1000 - h) // 2 + int(round(dy * k))))
    return c


if __name__ == '__main__':
    sheet_p, base_p, out = sys.argv[1:4]
    chin = int(sys.argv[4]) if len(sys.argv) > 4 else 700
    os.makedirs(out, exist_ok=True)
    base = Image.open(base_p).convert('RGB')
    bf = feats(base)
    base.save(os.path.join(out, 'face_neutral.png'))
    sheet = Image.open(sheet_p).convert('RGB')
    tw, th = sheet.size[0] // 3, sheet.size[1] // 2
    for i, name in enumerate(NAMES):
        tile = sheet.crop(((i % 3) * tw, (i // 3) * th, (i % 3) * tw + tw, (i // 3) * th + th)).resize((1000, 1000), Image.BICUBIC)
        v, sx, sy, dx, dy = register(bf, feats(tile))
        reg = apply(tile, sx, sy, dx, dy)
        # match the tile's skin tone to the base's (cheek patch): ChatGPT drifts the overall brightness / hue a little
        ba = np.asarray(base).astype(np.float32); ra = np.asarray(reg).astype(np.float32)
        box = (slice(560, 640), slice(340, 440))
        gain = ba[box].reshape(-1, 3).mean(axis=0) / np.maximum(ra[box].reshape(-1, 3).mean(axis=0), 1.0)
        reg = Image.fromarray(np.clip(ra * np.where(ra.sum(axis=2, keepdims=True) > 30, gain, 1.0), 0, 255).astype(np.uint8))
        reg.save(os.path.join(out, 'face_%s.png' % name))
        print('   skin gain', np.round(gain, 3))
        print('%-10s score %.3f scale x %.2f y %.2f shift %+d %+d' % (name, v, sx, sy, dx, dy))
    _, bk = bf
    m = np.asarray(base.convert('RGB')).astype(np.float32) / 255.0
    lum = m @ np.array([0.3, 0.59, 0.11], dtype=np.float32)
    skin = ((m[..., 0] > m[..., 1] * 1.15) & (m[..., 1] > m[..., 2] * 1.1) & (lum > 0.30))
    skin[chin:, :] = False
    skin[:372, :] = False
    filled = np.zeros_like(skin)
    for y in range(372, chin):
        xs = np.nonzero(skin[y, 200:800])[0]
        if len(xs) > 20:
            filled[y, 200 + xs.min():200 + xs.max() + 1] = True
    skin = filled
    Image.fromarray((skin * 255).astype(np.uint8)).save(os.path.join(out, 'face_mask.png'))
