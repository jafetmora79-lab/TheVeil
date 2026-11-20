"""Step 1 of the baked-expression pipeline (2D, checkable by eye). For one character: takes the base face crop (the model's own face, rendered flat) and the registered ChatGPT tiles
(register_aniso.py), and for each expression builds
    expr_<name>.png   the base face with ONLY the eyes+brows band and the mouth band replaced by the tile's, each band aligned to the base's own features and tone-matched
    alpha_<name>.png  the feathered mask of those two bands
so nothing outside the bands changes (head, hair, nose, cheeks, jaw stay the model's own) and the two bands blend into the base without a visible edge.
usage: python compose_expressions.py <reg_dir> <out_dir> [cx=500 eye_y=455 mouth_y=640]"""
import sys, os
import numpy as np
from PIL import Image

NAMES = ['blink', 'talk_small', 'talk_wide', 'scared', 'angry', 'worried']


def lum(a):
    return a @ np.array([0.3, 0.59, 0.11], dtype=np.float32)


def load(p):
    return np.asarray(Image.open(p).convert('RGB')).astype(np.float32) / 255.0


def blob_centre(a, cx, cy, hw=55, hh=38, thr=0.10):
    g = lum(a)[int(cy - hh):int(cy + hh), int(cx - hw):int(cx + hw)] < thr
    ys, xs = np.nonzero(g)
    if len(xs) < 25:
        return None
    return (cx - hw + xs.mean(), cy - hh + ys.mean())


def shift(a, dx, dy):
    """translate by (dx, dy) pixels (subpixel, bilinear), edge = black"""
    img = Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8))
    out = img.transform(img.size, Image.AFFINE, (1, 0, -dx, 0, 1, -dy), resample=Image.BILINEAR)
    return np.asarray(out).astype(np.float32) / 255.0


def soft_box(h, w, x0, y0, x1, y1, f):
    """1 inside the box, falling to 0 over f px outside (smoothstep)"""
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    dx = np.maximum(np.maximum(x0 - xs, xs - x1), 0)
    dy = np.maximum(np.maximum(y0 - ys, ys - y1), 0)
    d = np.hypot(dx, dy) / f
    t = np.clip(1 - d, 0, 1)
    return t * t * (3 - 2 * t)


def skin_like(a, ref):
    return (np.linalg.norm(a - ref, axis=2) < 0.14) & (lum(a) > 0.3)


def gauss(a, sigma):
    """separable gaussian blur (numpy, via FFT-free cumulative kernel) for an HxW or HxWxC float array"""
    r = int(sigma * 3)
    k = np.exp(-0.5 * (np.arange(-r, r + 1) / sigma) ** 2); k /= k.sum()
    def conv(x, axis):
        pad = [(0, 0)] * x.ndim; pad[axis] = (r, r)
        xp = np.pad(x, pad, mode='edge')
        out = np.zeros_like(x)
        for i, kv in enumerate(k):
            sl = [slice(None)] * x.ndim; sl[axis] = slice(i, i + x.shape[axis])
            out += kv * xp[tuple(sl)]
        return out
    return conv(conv(a, 0), 1)


def tone_field(base, tile, ref, sigma=28):
    """A smooth per-channel OFFSET (base - tile) measured only on skin pixels both images agree are skin, spread by a normalised blur: it removes the tone difference between the two
    images without touching eyes, brows or mouth."""
    ok = (skin_like(base, ref) & skin_like(tile, ref)).astype(np.float32)
    d = (base - tile) * ok[..., None]
    num = gauss(d, sigma); den = gauss(ok, sigma)
    fld = num / np.maximum(den[..., None], 1e-3)
    glob = (d.sum(axis=(0, 1)) / max(ok.sum(), 1.0))
    wgt = np.clip(den / 0.15, 0, 1)[..., None]
    return fld * wgt + glob * (1 - wgt)


def tone_gain(base, tile, mask):
    ref = np.median(base[mask & (lum(base) > 0.3)], axis=0)
    sb = skin_like(base, ref) & mask
    st = skin_like(tile, ref) & mask
    if sb.sum() < 200 or st.sum() < 200:
        return np.ones(3, dtype=np.float32)
    return base[sb].mean(axis=0) / np.maximum(tile[st].mean(axis=0), 0.01)


if __name__ == '__main__':
    reg, out = sys.argv[1:3]
    kw = dict(a.split('=') for a in sys.argv[3:])
    cx = float(kw.get('cx', 500)); eye_y = float(kw.get('eye_y', 455)); mouth_y = float(kw.get('mouth_y', 640))
    os.makedirs(out, exist_ok=True)
    base = load(os.path.join(reg, 'face_neutral.png'))
    h, w, _ = base.shape
    # base landmarks: the two pupils, the mouth line
    exp_l = (cx - 100, eye_y); exp_r = (cx + 100, eye_y)
    bl = blob_centre(base, *exp_l); br = blob_centre(base, *exp_r)
    print('base pupils', bl, br)
    eyes_box = (cx - 250, eye_y - 88, cx + 250, eye_y + 50)       # brows + eyes
    mouth_box = (cx - 150, mouth_y - 85, cx + 150, mouth_y + 95)
    F_EYE, F_MOUTH = 22, 18
    a_eyes = soft_box(h, w, *eyes_box, F_EYE)
    a_mouth = soft_box(h, w, *mouth_box, F_MOUTH)

    def mouth_line(a):
        g = lum(a)[int(mouth_y - 60):int(mouth_y + 60), int(cx - 90):int(cx + 90)]
        prof = g.mean(axis=1)
        y = int(np.argmin(prof))
        row = g[max(y - 2, 0):y + 3].mean(axis=0)
        xs = np.arange(len(row))
        wgt = np.maximum(row.max() - row, 0) ** 2
        xc = (xs * wgt).sum() / max(wgt.sum(), 1e-6)
        return (cx - 90 + xc, mouth_y - 60 + y)

    tiles = {n: load(os.path.join(reg, 'face_%s.png' % n)) for n in NAMES}
    bm = mouth_line(base)
    print('base mouth line', bm)
    eye_off = {}
    mouth_off = {}
    for n, t in tiles.items():
        tl = blob_centre(t, *exp_l, hw=70, hh=50); tr = blob_centre(t, *exp_r, hw=70, hh=50)
        if n != 'blink' and tl and tr and bl and br:
            eye_off[n] = (((bl[0] - tl[0]) + (br[0] - tr[0])) / 2, ((bl[1] - tl[1]) + (br[1] - tr[1])) / 2)
        if n in ('angry', 'worried', 'blink'):
            tm = mouth_line(t)
            mouth_off[n] = (bm[0] - tm[0], bm[1] - tm[1])
    mean_eye = tuple(np.median([v for v in eye_off.values()], axis=0)) if eye_off else (0, 0)
    mean_mouth = (0.0, 0.0)                  # the mouth line is not reliable to find: the registration is used as it is
    print('eye offsets', {k: tuple(round(x, 1) for x in v) for k, v in eye_off.items()}, 'mean', tuple(round(x, 1) for x in mean_eye))
    print('mouth offsets', {k: tuple(round(x, 1) for x in v) for k, v in mouth_off.items()}, 'mean', tuple(round(x, 1) for x in mean_mouth))
    refskin = np.median(base[(lum(base) > 0.3) & (np.arange(h)[:, None] > 540) & (np.arange(w)[None, :] > 400) & (np.arange(w)[None, :] < 600)], axis=0)
    hair_ref = np.median(base[60:200, 350:650].reshape(-1, 3), axis=0)
    print('skin ref', refskin.round(2), 'hair ref', hair_ref.round(2))
    brow_rows = slice(int(eye_y - 85), int(eye_y - 22))
    bb = base[brow_rows, int(cx - 200):int(cx + 200)]
    base_brow = bb[lum(bb) < 0.22].mean(axis=0) if (lum(bb) < 0.22).sum() > 100 else None
    print('base brow colour', None if base_brow is None else base_brow.round(3))
    mask_eyes = np.zeros((h, w), bool); mask_eyes[int(eyes_box[1]):int(eyes_box[3]), int(eyes_box[0]):int(eyes_box[2])] = True
    mask_mouth = np.zeros((h, w), bool); mask_mouth[int(mouth_box[1]):int(mouth_box[3]), int(mouth_box[0]):int(mouth_box[2])] = True
    def dilate(m, r):
        out = m.copy()
        for _ in range(r):
            out = out | np.roll(out, 1, 0) | np.roll(out, -1, 0) | np.roll(out, 1, 1) | np.roll(out, -1, 1)
        return out

    # 1. every tile: aligned (eyes part by the pupil offset, the rest as registered) and tone-corrected to the base with a smooth skin-only offset field
    wv = np.clip((540.0 - np.arange(h)) / 60.0, 0, 1)[:, None, None]          # 1 above y = 480 (eyes and brows), 0 below y = 540 (mouth)
    aligned = {}
    for n, t in tiles.items():
        t_eyes = shift(t, *mean_eye)
        t_mix = t_eyes * wv + t * (1 - wv)
        t_fix = np.clip(t_mix + tone_field(base, t_mix, refskin), 0, 1)
        if base_brow is not None:                            # ChatGPT draws the brows darker than the model's own: the dark brow pixels take the model's brow colour
            tb = t_fix[brow_rows, :]
            sel = (lum(tb) < 0.22) & (np.arange(w)[None, :] > cx - 230) & (np.arange(w)[None, :] < cx + 230)
            if sel.sum() > 100:
                wgt = np.clip((0.30 - lum(tb)) / 0.12, 0, 1)[..., None]
                t_fix[brow_rows, :] = np.clip(tb * (1 - wgt) + tb * (base_brow / np.maximum(tb[sel].mean(axis=0), 0.01)) * wgt, 0, 1)
        aligned[n] = t_fix
    # 2. where the six expressions differ from each other = where the features are (eyes, brows, mouth): a mask of exactly those places, grown a little
    stack = np.stack([aligned[n] for n in NAMES])
    var = stack.std(axis=0).max(axis=2)
    feat = gauss(var, 3) > 0.045
    yy = np.arange(h)[:, None]; xx = np.arange(w)[None, :]
    box_e = (yy > 392) & (yy < 510) & (xx > cx - 205) & (xx < cx + 205)          # brows + eyes
    box_m = (yy > 575) & (yy < 745) & (xx > cx - 118) & (xx < cx + 128)           # mouth
    feat &= (box_e | box_m)                                  # only inside the two feature boxes: nothing on the hair, the outline, the nose or the jaw
    feat = dilate(feat, 12) & (box_e | box_m)
    # the model's own painted brows and eyes must not survive under the expression's: they are found by colour in the base crop and filled with skin; the alpha covers them completely
    bmask = np.zeros((h, w), bool)
    rows_b = (yy > 380) & (yy < 450) & (xx > cx - 230) & (xx < cx + 230)
    if base_brow is not None:
        bmask |= (lum(base) < 0.60) & rows_b & (xx > cx - 205) & (xx < cx + 205)      # the brow bars with their whole anti-aliased edge (skin is about 0.65, hair stays out of the x range)
    for (px_, py_) in (bl, br):
        if px_ is not None:
            win = (np.abs(xx - px_) < 70) & (np.abs(yy - py_) < 38)
            bmask |= ((lum(base) > 0.78) | (lum(base) < 0.14)) & win
    bmask = dilate(bmask, 7)
    ok_skin = (~bmask).astype(np.float32)
    fill = gauss(base * ok_skin[..., None], 10) / np.maximum(gauss(ok_skin, 10)[..., None], 1e-3)
    base_clean = np.where(bmask[..., None], fill, base)
    pass                                                       # (the wiped base brows/eyes come from the clean texture at run time: no alpha needed for them)
    alpha = np.clip(gauss(feat.astype(np.float32), 7), 0, 1)
    alpha = np.clip(alpha * 1.6 - 0.2, 0, 1)
    Image.fromarray((alpha * 255).astype(np.uint8)).save(os.path.join(out, 'alpha_all.png'))
    for n in NAMES:
        comp = base_clean * (1 - alpha[..., None]) + aligned[n] * alpha[..., None]
        Image.fromarray((np.clip(comp, 0, 1) * 255).astype(np.uint8)).save(os.path.join(out, 'expr_%s.png' % n))
        Image.fromarray((alpha * 255).astype(np.uint8)).save(os.path.join(out, 'alpha_%s.png' % n))
    Image.fromarray((base * 255).astype(np.uint8)).save(os.path.join(out, 'expr_neutral.png'))
