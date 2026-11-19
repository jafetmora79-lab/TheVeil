"""Stage B of the face expressions (system Python, Pillow + numpy): paint expression decal patches from the flat face capture.
Every patch is a CROP of his own face texels with the feature edited (lids closed, brows moved / tilted, mouth shapes), so where
nothing changes the decal is identical to the base face and the patch edge is invisible. Patches are reduced with nearest-neighbour
(PSX) and packed into one small atlas.
   python meshy_face_paint.py <repo_root>"""
import sys, os, json, math
import numpy as np
from PIL import Image, ImageDraw

root = sys.argv[1]
d = os.path.join(root, "creatures/humans/protagonist/work/face")
F = np.array(Image.open(os.path.join(d, "face_flat.png")).convert("RGB"))
H, W, _ = F.shape
K = 6                                         # flat pixels per atlas texel


def lum(a):
    return a[..., 0] * .299 + a[..., 1] * .587 + a[..., 2] * .114


def skin_mask(a):
    r, g, b = a[..., 0].astype(int), a[..., 1].astype(int), a[..., 2].astype(int)
    return (r > 170) & (r > g + 25) & (g > b) & (b > 80) & (lum(a) > 140)


def skin_near(box, grow=70):
    x0, y0, x1, y1 = box
    X0, Y0, X1, Y1 = max(0, x0 - grow), max(0, y0 - grow), min(W, x1 + grow), min(H, y1 + grow)
    reg = F[Y0:Y1, X0:X1]
    m = skin_mask(reg)
    return np.median(reg[m], axis=0) if m.any() else np.array([215, 150, 120])


# ---- feature boxes in flat pixels (x0, y0, x1, y1) (protagonist capture: 1000 px, face centre ~ (500, 560))
EYE = {"L": (268, 372, 458, 496), "R": (538, 372, 722, 496)}
BROW = {"L": (255, 268, 470, 408), "R": (525, 268, 745, 408)}
MOUTH = (355, 655, 645, 795)
LIPS_C = (500, 716)
SKIN_ROW = 486                                  # clean skin just under the eyes
LIP = (178, 104, 86)
DARK = (58, 22, 22)
TEETH = (232, 222, 210)
LASH = (56, 34, 28)


def paste_img(base, patch, x, y):
    ph, pw = patch.shape[:2]
    x0, y0 = max(0, x), max(0, y)
    x1, y1 = min(W, x + pw), min(H, y + ph)
    if x1 > x0 and y1 > y0:
        base[y0:y1, x0:x1] = patch[y0 - y:y1 - y, x0 - x:x1 - x]


def clone_fill(img, box, row_a, row_b=None):
    """Fill a box by copying, per column, the real texels of row_a (blending toward row_b): keeps his own skin look."""
    x0, y0, x1, y1 = box
    a = F[row_a, x0:x1].astype(np.float32)
    b = a if row_b is None else F[row_b, x0:x1].astype(np.float32)
    t = np.linspace(0, 1, y1 - y0)[:, None, None]
    img[y0:y1, x0:x1] = (a[None] * (1 - t) + b[None] * t).astype(np.uint8)


def eye_variant(kind):
    img = F.copy()
    for side, box in EYE.items():
        x0, y0, x1, y1 = box
        cx, cy = (x0 + x1) // 2, 438
        if kind == "closed":
            clone_fill(img, (x0 + 22, 404, x1 - 22, 476), SKIN_ROW)
            img[404:476, x0 + 22:x1 - 22] = (img[404:476, x0 + 22:x1 - 22].astype(np.float32) * 0.93).astype(np.uint8)
            for x in range(x0 + 30, x1 - 30):
                t = (x - cx) / max(1, (x1 - x0) / 2 - 30)
                y = int(436 + 9 * (1 - t * t))
                img[y - 4:y + 4, x] = LASH
        elif kind == "wide":
            eye = F[402:476, x0 + 22:x1 - 22].copy()
            sc = 1.62
            e2 = np.array(Image.fromarray(eye).resize((int(eye.shape[1] * sc), int(eye.shape[0] * sc)), Image.NEAREST))
            paste_img(img, e2, cx - e2.shape[1] // 2, cy - e2.shape[0] // 2 - 14)
        elif kind == "narrow":
            clone_fill(img, (x0 + 22, 402, x1 - 22, 424), SKIN_ROW)                    # the upper lid comes down
            clone_fill(img, (x0 + 22, 456, x1 - 22, 478), SKIN_ROW)                    # the cheek comes up
            for x in range(x0 + 28, x1 - 28):
                img[420:430, x] = LASH
    return img


def brow_variant(kind):
    """Angry: a heavy slanted stroke over each brow (inner end down, outer end up). The scared face uses the wide eyes instead of
    raised brows: a hair strand crosses his right brow and would be dragged along."""
    pim = Image.fromarray(F.copy())
    dr = ImageDraw.Draw(pim)
    col = (40, 26, 20)
    dr.polygon([(266, 330), (266, 362), (462, 412), (462, 380)], fill=col)
    dr.polygon([(535, 412), (535, 380), (732, 330), (732, 362)], fill=col)
    return np.array(pim)


def brows_scared():
    """Raised, arched brows (inner ends high, outer ends lower): the old brows are painted out with his forehead skin, new ones drawn higher."""
    img = F.copy()
    skin = 0.5 * np.median(F[225:300, 330:500].reshape(-1, 3), axis=0) + 0.5 * np.median(F[484:490, 330:500].reshape(-1, 3), axis=0)
    from PIL import ImageFilter
    dark = (lum(F) < 95)
    m = np.zeros(dark.shape, bool)
    for (x0, y0, x1, y1) in ((262, 325, 462, 408), (535, 325, 735, 408)):
        m[y0:y1, x0:x1] = dark[y0:y1, x0:x1]
    m = np.array(Image.fromarray((m * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(13))) > 0
    for (x0, y0, x1, y1) in ((262, 325, 462, 408), (535, 325, 735, 408)):
        sub = np.zeros(m.shape, bool)
        sub[y0:y1, x0:x1] = m[y0:y1, x0:x1]
        a_ = np.array(Image.fromarray((sub * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(7))).astype(np.float32)[..., None] / 255.0
        img[:] = (img.astype(np.float32) * (1 - a_) + skin * a_).astype(np.uint8)
    pim = Image.fromarray(img)
    dr = ImageDraw.Draw(pim)
    col = (40, 26, 20)
    # image-left brow: outer end left/low, inner end right/high; image-right brow mirrored
    dr.polygon([(262, 352), (300, 318), (380, 296), (462, 304), (462, 334), (380, 328), (312, 352), (270, 384)], fill=col)
    dr.polygon([(735, 352), (697, 318), (617, 296), (535, 304), (535, 334), (617, 328), (685, 352), (727, 384)], fill=col)
    return np.array(pim)


def mouth_variant(kind):
    img = F.copy()
    x0, y0, x1, y1 = MOUTH
    clone_fill(img, (x0, y0, x1, y1), 660, 790)
    pim = Image.fromarray(img)
    dr = ImageDraw.Draw(pim)
    cx, cy = LIPS_C

    def ell(rx, ry, col, dy=0):
        dr.ellipse((cx - rx, cy + dy - ry, cx + rx, cy + dy + ry), fill=tuple(int(c) for c in col))

    if kind == "talk_small":
        ell(66, 24, LIP)
        ell(42, 13, DARK)
    elif kind == "talk_wide":
        ell(76, 40, LIP, 4)
        ell(56, 27, DARK, 4)
        dr.rectangle((cx - 40, cy - 19 + 4, cx + 40, cy - 9 + 4), fill=TEETH)
    elif kind == "scared":
        ell(60, 58, LIP, 8)
        ell(40, 42, DARK, 8)
        dr.rectangle((cx - 28, cy - 28 + 8, cx + 28, cy - 18 + 8), fill=TEETH)
    elif kind == "angry":
        ell(92, 22, LIP, 2)
        dr.rectangle((cx - 74, cy - 9, cx + 74, cy + 10), fill=TEETH)
        dr.line((cx - 74, cy + 1, cx + 74, cy + 1), fill=DARK, width=5)
        dr.polygon([(cx - 84, cy - 10), (cx - 66, cy - 4), (cx - 76, cy + 18)], fill=tuple(int(c * .8) for c in LIP))
        dr.polygon([(cx + 84, cy - 10), (cx + 66, cy - 4), (cx + 76, cy + 18)], fill=tuple(int(c * .8) for c in LIP))
    return np.array(pim)


def feather(img, boxes, n=16):
    """Blend each edited box into the original over n px at its edges, so the patch edge is invisible (the decal equals the base face there)."""
    out = F.astype(np.float32).copy()
    for (x0, y0, x1, y1) in boxes:
        ys = np.arange(y0, y1)
        xs = np.arange(x0, x1)
        ay = np.minimum(1.0, np.minimum(ys - y0, y1 - 1 - ys) / n + 0.0)[:, None]
        ax = np.minimum(1.0, np.minimum(xs - x0, x1 - 1 - xs) / n + 0.0)[None, :]
        a = np.clip(np.minimum(ay, ax), 0, 1)[..., None]
        out[y0:y1, x0:x1] = F[y0:y1, x0:x1] * (1 - a) + img[y0:y1, x0:x1] * a
    return out.astype(np.uint8)


VARIANTS = []
for kind in ("closed", "wide", "narrow"):
    VARIANTS.append(("eyes_" + kind, feather(eye_variant(kind), list(EYE.values()), 26), list(EYE.values())))
VARIANTS.append(("brows_scared", feather(brows_scared(), list(BROW.values()), 10), list(BROW.values())))
VARIANTS.append(("brows_angry", brow_variant("angry"), list(BROW.values())))
for kind in ("talk_small", "talk_wide", "scared", "angry"):
    VARIANTS.append(("mouth_" + kind, mouth_variant(kind), [MOUTH]))

# ---- pack: every patch reduced by K (nearest) into one atlas
patches = []
for name, img, boxes in VARIANTS:
    for i, (x0, y0, x1, y1) in enumerate(boxes):
        # align the box to the texel grid
        x0, y0 = (x0 // K) * K, (y0 // K) * K
        x1, y1 = -(-x1 // K) * K, -(-y1 // K) * K
        crop = img[y0:y1, x0:x1]
        small = Image.fromarray(crop).resize(((x1 - x0) // K, (y1 - y0) // K), Image.NEAREST)
        patches.append({"name": name, "idx": i, "box": [x0, y0, x1, y1], "img": small})
AW = 256
x = y = row_h = 0
for p in patches:
    w, h = p["img"].size
    if x + w > AW:
        x, y, row_h = 0, y + row_h + 1, 0
    p["atlas"] = [x, y, w, h]
    x += w + 1
    row_h = max(row_h, h)
AH = 1
while AH < y + row_h:
    AH *= 2
atlas = Image.new("RGB", (AW, AH), (0, 0, 0))
for p in patches:
    atlas.paste(p["img"], (p["atlas"][0], p["atlas"][1]))
atlas.save(os.path.join(d, "face_atlas.png"))
json.dump({"atlas": [AW, AH], "K": K, "patches": [{k: v for k, v in p.items() if k != "img"} for p in patches]}, open(os.path.join(d, "face_atlas.json"), "w"), indent=1)
# a review sheet: base face + each variant over the face (flat capture), cropped
sheet_items = [("neutral", F)] + [(n, im) for n, im, _ in VARIANTS]
cw = 330
sheet = Image.new("RGB", (cw * 4, int(cw * 0.75) * 3), (20, 20, 22))
dd = ImageDraw.Draw(sheet)
for i, (n, im) in enumerate(sheet_items):
    crop = Image.fromarray(im[240:770, 200:850]).resize((cw, int(cw * 0.75)), Image.NEAREST)
    sheet.paste(crop, ((i % 4) * cw, (i // 4) * int(cw * 0.75)))
    dd.text(((i % 4) * cw + 4, (i // 4) * int(cw * 0.75) + 4), n, fill=(255, 255, 255))
sheet.save(os.path.join(d, "face_variants_flat.png"))
print("ATLAS", AW, AH, len(patches), "patches")
