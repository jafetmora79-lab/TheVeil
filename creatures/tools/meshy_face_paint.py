"""Stage B of the face expressions (system Python, Pillow + numpy): paint expression decal patches from the flat face capture.
Every patch is a CROP of Sarah's own face texels with the feature edited (lids closed, brows moved / tilted, mouth shapes), so where
nothing changes the decal is identical to the base face and the patch edge is invisible. Patches are reduced with nearest-neighbour
(PSX) and packed into one small atlas.
   python meshy_face_paint.py <repo_root>"""
import sys, os, json, math
import numpy as np
from PIL import Image, ImageDraw

root = sys.argv[1]
d = os.path.join(root, "creatures/humans/sarah_meshy/work/face")
F = np.array(Image.open(os.path.join(d, "face_flat.png")).convert("RGB"))
H, W, _ = F.shape
K = 10                                         # flat pixels per atlas texel


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


# ---- feature boxes in flat pixels (x0, y0, x1, y1)
EYE = {"L": (240, 538, 440, 650), "R": (560, 538, 780, 650)}        # eye + lids, without the brow
BROW = {"L": (270, 480, 450, 565), "R": (550, 480, 830, 565)}
MOUTH = (350, 840, 660, 995)
LIPS_C = (505, 918)


def paste_img(base, patch, x, y):
    ph, pw = patch.shape[:2]
    x0, y0 = max(0, x), max(0, y)
    x1, y1 = min(W, x + pw), min(H, y + ph)
    if x1 > x0 and y1 > y0:
        base[y0:y1, x0:x1] = patch[y0 - y:y1 - y, x0 - x:x1 - x]


def paste_masked(base, patch, mask, x, y):
    ph, pw = patch.shape[:2]
    x0, y0 = max(0, x), max(0, y)
    x1, y1 = min(W, x + pw), min(H, y + ph)
    if x1 > x0 and y1 > y0:
        sub = base[y0:y1, x0:x1]
        m = mask[y0 - y:y1 - y, x0 - x:x1 - x]
        sub[m] = patch[y0 - y:y1 - y, x0 - x:x1 - x][m]


def fill_skin(img, box, top_color=None, bottom_color=None):
    x0, y0, x1, y1 = box
    cs = skin_near(box)
    t = cs if top_color is None else top_color
    b = cs if bottom_color is None else bottom_color
    ys = np.linspace(0, 1, y1 - y0)[:, None, None]
    img[y0:y1, x0:x1] = (t * (1 - ys) + b * ys).astype(np.uint8)


def clone_fill(img, box, row_a, row_b=None):
    """Fill a box by copying, per column, the real texels of row_a (and blending toward row_b): keeps the chunky skin look."""
    x0, y0, x1, y1 = box
    a = F[row_a, x0:x1].astype(np.float32)
    b = a if row_b is None else F[row_b, x0:x1].astype(np.float32)
    t = np.linspace(0, 1, y1 - y0)[:, None, None]
    img[y0:y1, x0:x1] = (a[None] * (1 - t) + b[None] * t).astype(np.uint8)


# ================================================================= eyes
def eye_variant(kind):
    img = F.copy()
    for side, box in EYE.items():
        x0, y0, x1, y1 = box
        cx, cy = (x0 + x1) // 2, 590
        if kind == "closed":
            clone_fill(img, (x0 + 20, 550, x1 - 20, 632), 650)
            # lash line: a slightly drooping curve
            for x in range(x0 + 30, x1 - 30):
                t = (x - cx) / max(1, (x1 - x0) / 2 - 30)
                y = int(596 + 10 * (1 - t * t))
                img[y - 7:y + 7, x] = (78, 40, 30)
        elif kind == "wide":
            eye = F[548:632, x0 + 10:x1 - 10].copy()
            sc = 1.32
            im = Image.fromarray(eye).resize((int(eye.shape[1] * sc), int(eye.shape[0] * sc)), Image.NEAREST)
            e2 = np.array(im)
            paste_img(img, e2, cx - e2.shape[1] // 2, cy - e2.shape[0] // 2 - 6)
        elif kind == "narrow":
            cs = skin_near(box, 50)
            top = img[548:600, x0 + 10:x1 - 10]
            clone_fill(img, (x0 + 14, 552, x1 - 14, 578), 650)                       # the upper lid comes down
            clone_fill(img, (x0 + 14, 606, x1 - 14, 632), 650)                       # the cheek comes up
            for x in range(x0 + 20, x1 - 20):
                img[574:586, x] = (70, 38, 28)
    return img


# ================================================================= brows
def brow_variant(kind):
    """Angry: a heavy slanted stroke laid over each brow (inner end down, outer end up). Scared uses the wide eyes instead of moving the
    brows: the left brow is crossed by a hair strand, and moving it would drag the strand along."""
    img = F.copy()
    pim = Image.fromarray(img)
    dr = ImageDraw.Draw(pim)
    col = (58, 30, 20)
    # image-left brow: outer end left, inner end right; image-right brow: inner end left, outer end right
    dr.polygon([(278, 500), (278, 526), (448, 566), (448, 540)], fill=col)
    dr.polygon([(572, 566), (572, 540), (815, 498), (815, 524)], fill=col)
    return np.array(pim)


# ================================================================= mouth
def mouth_variant(kind):
    img = F.copy()
    x0, y0, x1, y1 = MOUTH
    clone_fill(img, (x0, y0, x1, y1), 845, 990)
    lips = F[870:965, 385:625]
    red = lips[(lips[..., 0] > 100) & (lips[..., 1] < 70)]
    red = np.median(red, axis=0) if len(red) else np.array([140, 35, 28])
    dark = (52, 10, 12)
    teeth = (226, 214, 200)
    pim = Image.fromarray(img)
    dr = ImageDraw.Draw(pim)
    cx, cy = LIPS_C

    def ell(rx, ry, col, dy=0):
        dr.ellipse((cx - rx, cy + dy - ry, cx + rx, cy + dy + ry), fill=tuple(int(c) for c in col))

    if kind == "talk_small":
        ell(104, 36, red)
        ell(66, 20, dark)
    elif kind == "talk_wide":
        ell(112, 56, red, 6)
        ell(84, 38, dark, 6)
        dr.rectangle((cx - 60, cy - 28 + 6, cx + 60, cy - 14 + 6), fill=teeth)
    elif kind == "scared":
        ell(74, 62, red, 8)
        ell(48, 42, dark, 8)
        dr.rectangle((cx - 34, cy - 30 + 8, cx + 34, cy - 18 + 8), fill=teeth)
    elif kind == "angry":
        ell(112, 24, red, 2)
        dr.rectangle((cx - 92, cy - 8, cx + 92, cy + 10), fill=teeth)             # clenched teeth
        dr.line((cx - 92, cy + 1, cx + 92, cy + 1), fill=dark, width=5)
        dr.polygon([(cx - 120, cy - 14), (cx - 96, cy - 6), (cx - 110, cy + 24)], fill=tuple(int(c) for c in red * .8))   # corners pulled down
        dr.polygon([(cx + 120, cy - 14), (cx + 96, cy - 6), (cx + 110, cy + 24)], fill=tuple(int(c) for c in red * .8))
    return np.array(pim)


VARIANTS = []
for kind in ("closed", "wide", "narrow"):
    VARIANTS.append(("eyes_" + kind, eye_variant(kind), list(EYE.values())))
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
    crop = Image.fromarray(im[470:1000, 200:850]).resize((cw, int(cw * 0.75)), Image.NEAREST)
    sheet.paste(crop, ((i % 4) * cw, (i // 4) * int(cw * 0.75)))
    dd.text(((i % 4) * cw + 4, (i // 4) * int(cw * 0.75) + 4), n, fill=(255, 255, 255))
sheet.save(os.path.join(d, "face_variants_flat.png"))
print("ATLAS", AW, AH, len(patches), "patches")
