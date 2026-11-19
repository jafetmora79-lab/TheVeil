"""Prepare the expression textures: colour-match every returned (ChatGPT) image to the base face over skin areas that do not change
(forehead and cheeks), keep the changed features, and write 512 px PNGs.   python protagonist_face_tex_prepare.py <repo_root>"""
import sys, os
import numpy as np
from PIL import Image
root = sys.argv[1]
base = os.path.join(root, "creatures/humans/protagonist")
out = os.path.join(root, "game/prototypes/protagonist_meshy/face/tex")
F = np.array(Image.open(os.path.join(base, "work/face/face_flat.png")).convert("RGB")).astype(np.float32)
SRC = {"neutral": None, "blink": "eyes_closed_a", "talk_small": "talk_small", "talk_wide": "talk_wide", "scared": "scared_open"}
REF = [(330, 250, 680, 320), (300, 520, 400, 690), (600, 520, 700, 690)]          # forehead and both cheeks: skin that does not change
from PIL import ImageFilter
EYEB = [(268, 372, 458, 496), (538, 372, 722, 496)]


def clean_eyes(A):
    """Remove the hard grey facets and outlines around the eyes: the light (white / grey) pixels are smoothed, warmed a little and blended in
    softly; the dark pupil and lashes are left alone."""
    out = A.copy()
    for (x0, y0, x1, y1) in EYEB:
        sub = A[y0:y1, x0:x1]
        lum = sub @ np.array([0.299, 0.587, 0.114], np.float32)
        sat = sub.max(2) - sub.min(2)
        mask = ((lum > 105) & (sat < 70)).astype(np.float32)
        mask = np.array(Image.fromarray((mask * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.GaussianBlur(4))).astype(np.float32)[..., None] / 255.0
        smooth = np.array(Image.fromarray(sub.astype(np.uint8)).filter(ImageFilter.GaussianBlur(5))).astype(np.float32)
        warm = smooth * np.array([1.0, 0.95, 0.88], np.float32)
        warm = np.minimum(warm, 208.0)
        # keep the dark pupil crisp: where the original is dark, use it
        keep = np.clip((95.0 - lum) / 45.0, 0, 1)[..., None]
        newsub = sub * (1 - mask) + (warm * (1 - keep) + sub * keep) * mask
        out[y0:y1, x0:x1] = newsub
    return out


for name, src in SRC.items():
    if src is None:
        A = F.copy()
    else:
        A = np.array(Image.open(os.path.join(base, "chatgpt_kit/returned/%s.png" % src)).convert("RGB")).astype(np.float32)
        gain = []
        for (x0, y0, x1, y1) in REF:
            gain.append(F[y0:y1, x0:x1].reshape(-1, 3).mean(0) - A[y0:y1, x0:x1].reshape(-1, 3).mean(0))
        off = np.mean(gain, axis=0)
        print(name, "colour offset", off.round(1))
        A = np.clip(A + off, 0, 255)
    # (the eye smoothing, clean_eyes, is no longer applied: the grey lines were a lighting / normals problem, see EYE_ARTIFACT_DIAGNOSTIC.md)
    Image.fromarray(A.astype(np.uint8)).resize((512, 512), Image.LANCZOS).save(os.path.join(out, "face_%s.png" % name))
print("DONE")
