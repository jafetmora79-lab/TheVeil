"""Prepare the expression textures: colour-match every returned (ChatGPT) image to the base face over skin areas that do not change
(forehead and cheeks), keep the changed features, and write 512 px PNGs.   python protagonist_face_tex_prepare.py <repo_root>"""
import sys, os
import numpy as np
from PIL import Image
root = sys.argv[1]
base = os.path.join(root, "creatures/humans/protagonist")
out = os.path.join(base, "face_geo/tex")
F = np.array(Image.open(os.path.join(base, "work/face/face_flat.png")).convert("RGB")).astype(np.float32)
SRC = {"neutral": None, "blink": "eyes_closed_a", "talk_small": "talk_small", "talk_wide": "talk_wide", "scared": "scared_open"}
REF = [(330, 250, 680, 320), (300, 520, 400, 690), (600, 520, 700, 690)]          # forehead and both cheeks: skin that does not change
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
    Image.fromarray(A.astype(np.uint8)).resize((512, 512), Image.LANCZOS).save(os.path.join(out, "face_%s.png" % name))
print("DONE")
