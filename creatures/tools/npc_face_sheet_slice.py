"""Cut a returned six-up expression sheet (ChatGPT) into six aligned 512 px face images and measure how well they line up.
   python npc_face_sheet_slice.py <repo_root> <slug> <returned_sheet_image>
Cells (3 x 2): 1 blink, 2 talk_small, 3 talk_wide, 4 scared, 5 angry, 6 worried. Each cell is registered to the base face (flat capture,
512 px) by a translation + scale search on the silhouette, then written to creatures/humans/npcs/<slug>/face_tex/face_<name>.png (and the base as face_neutral.png)."""
import sys, os, json
import numpy as np
from PIL import Image

root, slug, sheet = sys.argv[1], sys.argv[2], sys.argv[3]
base_dir = os.path.join(root, "creatures/humans/npcs", slug)
out = os.path.join(base_dir, "face_tex")
os.makedirs(out, exist_ok=True)
NAMES = ["blink", "talk_small", "talk_wide", "scared", "angry", "worried"]
B = Image.open(os.path.join(base_dir, "work/face/face_flat.png")).convert("RGB").resize((512, 512), Image.LANCZOS)
Bn = np.array(B).astype(np.float32)
S = Image.open(sheet).convert("RGB")
if S.size != (1536, 1024):
    print("NOTE sheet size", S.size, "-> resized to 1536x1024")
    S = S.resize((1536, 1024), Image.LANCZOS)


def sil(a):
    """registration image: the gradient magnitude of the luminance inside the central face region (nose, jaw, brow edges), windowed. The
    silhouette of the hair is not used: ChatGPT redraws hair shapes slightly differently, the facial landmarks are what must line up."""
    lum = a[..., 0] * 0.299 + a[..., 1] * 0.587 + a[..., 2] * 0.114
    gy, gx = np.gradient(lum)
    g = np.hypot(gx, gy)
    win = np.zeros((512, 512), np.float32)
    win[90:470, 110:410] = 1.0
    ys, xs = np.mgrid[0:512, 0:512]
    taper = np.exp(-(((xs - 260) / 170.0) ** 2 + ((ys - 280) / 190.0) ** 2))
    return g * win * taper


def phase_shift(a, b):
    """translation (dx, dy) that moves b onto a, by phase correlation"""
    fa, fb = np.fft.fft2(a), np.fft.fft2(b)
    r = fa * np.conj(fb)
    r /= np.abs(r) + 1e-9
    c = np.real(np.fft.ifft2(r))
    iy, ix = np.unravel_index(np.argmax(c), c.shape)
    h, w = a.shape
    dy = iy if iy <= h // 2 else iy - h
    dx = ix if ix <= w // 2 else ix - w
    return dx, dy, float(c.max())


def scaled(img, s):
    n = int(round(512 * s))
    im = img.resize((n, n), Image.LANCZOS)
    canvas = Image.new("RGB", (512, 512), (0, 0, 0))
    canvas.paste(im, ((512 - n) // 2, (512 - n) // 2))
    return canvas


Bs = sil(Bn)
Image.fromarray(Bn.astype(np.uint8)).save(os.path.join(out, "face_neutral.png"))
report = {}
cells = {}
fits = []
for k, name in enumerate(NAMES):
    cell = S.crop(((k % 3) * 512, (k // 3) * 512, (k % 3) * 512 + 512, (k // 3) * 512 + 512))
    cells[name] = cell
    best = None
    for s in np.arange(0.94, 1.0601, 0.01):
        c2 = scaled(cell, float(s))
        dx, dy, peak = phase_shift(Bs, sil(np.array(c2).astype(np.float32)))
        if best is None or peak > best[0]:
            best = (peak, float(s), dx, dy)
    fits.append(best)
# the six cells of one sheet were drawn in one pass, so they share one placement: use the median fit (a cell with an expression edit can fool its own fit)
S_MED = float(np.median([f[1] for f in fits]))
DX_MED = int(np.median([f[2] for f in fits]))
DY_MED = int(np.median([f[3] for f in fits]))
print("SLICE", slug, "sheet placement: scale %.2f dx %d dy %d" % (S_MED, DX_MED, DY_MED))
for k, name in enumerate(NAMES):
    c2 = scaled(cells[name], S_MED)
    arr = np.roll(np.roll(np.array(c2), DY_MED, axis=0), DX_MED, axis=1)
    Image.fromarray(arr).save(os.path.join(out, "face_%s.png" % name))
    report[name] = {"scale": round(S_MED, 3), "dx": DX_MED, "dy": DY_MED, "own_fit": [round(fits[k][1], 3), int(fits[k][2]), int(fits[k][3])]}
json.dump(report, open(os.path.join(out, "alignment.json"), "w"), indent=1)
