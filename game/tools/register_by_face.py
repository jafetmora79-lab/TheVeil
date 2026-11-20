"""Registers ChatGPT expression tiles onto the base face render the OLD way: by the face-skin hull (cheek to cheek, down to the chin), which no expression changes.
usage: python register_by_face.py <sheet.webp|png> <base_1000.png> <out_dir>      (sheet = 3 x 2 tiles: blink, talk_small, talk_wide / scared, angry, worried)
Writes <out_dir>/face_<name>.png (1000x1000, aligned to the base), face_neutral.png (the base) and face_mask.png (the base's skin hull, white = face)."""
import sys, os
import numpy as np
from PIL import Image

NAMES = ['blink', 'talk_small', 'talk_wide', 'scared', 'angry', 'worried']


def skin_mask(im, ref=None):
    a = np.asarray(im.convert('RGB')).astype(np.float32) / 255.0
    lum = a @ np.array([0.3, 0.59, 0.11], dtype=np.float32)
    # skin: warm (r > g > b), not dark, not the clothes: sample the colour from the lower-centre cheeks
    h, w, _ = a.shape
    cheek = a[int(h * 0.62):int(h * 0.68), int(w * 0.40):int(w * 0.60)].reshape(-1, 3)
    c = np.median(cheek, axis=0) if ref is None else ref
    d = np.linalg.norm(a - c, axis=2)
    return (d < 0.20) & (lum > 0.25), c


def hull(m):
    """cheek-to-cheek x range at the cheek line, chin y, and the face centre x, from the skin mask of the lower face."""
    h, w = m.shape
    rows = np.arange(h)
    lower = m[int(h * 0.45):int(h * 0.80), :]
    ys, xs = np.nonzero(lower)
    # the chin: the lowest row where the skin run is still wide (> 25 % of the cheek width)
    widths = lower.sum(axis=1)
    wmax = widths.max()
    wide = np.nonzero(widths > 0.30 * wmax)[0]
    chin = wide.max() + int(h * 0.45)
    # the cheek width: median width of the rows in the middle of the lower face
    cheek_rows = widths[(widths > 0.8 * wmax)]
    width = float(np.median(cheek_rows))
    cx = float(xs.mean())
    return width, chin, cx


def similarity(img, k, cx_src, chin_src, cx_dst, chin_dst, size=1000):
    return img.transform((size, size), Image.AFFINE, (1 / k, 0, cx_src - cx_dst / k, 0, 1 / k, chin_src - chin_dst / k), resample=Image.BICUBIC)


if __name__ == '__main__':
    sheet_p, base_p, out = sys.argv[1:4]
    os.makedirs(out, exist_ok=True)
    base = Image.open(base_p).convert('RGB')
    sm, c = skin_mask(base)
    bw, bchin, bcx = hull(sm)
    print('base hull width %.0f chin %d cx %.0f' % (bw, bchin, bcx))
    base.save(os.path.join(out, 'face_neutral.png'))
    # face mask = the base's skin hull, eroded a little, filled
    m = sm.copy()
    Image.fromarray((m * 255).astype(np.uint8)).save(os.path.join(out, 'face_mask.png'))
    sheet = Image.open(sheet_p).convert('RGB')
    tw = sheet.size[0] // 3
    th = sheet.size[1] // 2
    for i, name in enumerate(NAMES):
        tile = sheet.crop(((i % 3) * tw, (i // 3) * th, (i % 3) * tw + tw, (i // 3) * th + th)).resize((1000, 1000), Image.BICUBIC)
        tm, _ = skin_mask(tile, c)
        tw_, tchin, tcx = hull(tm)
        k = bw / tw_
        reg = similarity(tile, k, tcx, tchin, bcx, bchin)
        reg.save(os.path.join(out, 'face_%s.png' % name))
        print('%-10s hull width %.0f chin %d cx %.0f -> scale %.3f' % (name, tw_, tchin, tcx, k))
