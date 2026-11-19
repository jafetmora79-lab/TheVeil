"""Prepare an NPC's face textures from the aligned expression cells (face_tex/face_<name>.png from npc_face_sheet_slice.py):
 - colour-match each expression to the base face over unchanged skin, keep only what really changed (difference matte, so the global colour
   drift of the generated image never shows) -> game/prototypes/npc_meshy/face/<slug>/face_<name>.png (512 px)
 - find the face region (skin hull) and the two eye centres in the flat 1000 px capture -> creatures/humans/npcs/<slug>/face_tex/face_info.json
   and face_mask.png (used by npc_face_tex_build.py to pick the face triangles and the eye normals)
   python npc_face_tex_prepare.py <repo_root> <slug>"""
import sys, os, json
import numpy as np
from PIL import Image, ImageFilter, ImageDraw

root, slug = sys.argv[1], sys.argv[2]
base_dir = os.path.join(root, "creatures/humans/npcs", slug)
tex_dir = os.path.join(base_dir, "face_tex")
out_dir = os.path.join(root, "game/prototypes/npc_meshy/face", slug)
os.makedirs(out_dir, exist_ok=True)
NAMES = ["blink", "talk_small", "talk_wide", "scared", "angry", "worried"]
B = np.array(Image.open(os.path.join(tex_dir, "face_neutral.png")).convert("RGB")).astype(np.float32)        # 512 px base
F1000 = np.array(Image.open(os.path.join(base_dir, "work/face/face_flat.png")).convert("RGB")).astype(np.float32)


def lum(a):
    return a @ np.array([0.299, 0.587, 0.114], np.float32)


# ---- skin hull on the 512 base (cheeks give the skin colour)
cheeks = np.concatenate([B[270:350, 120:200].reshape(-1, 3), B[270:350, 320:400].reshape(-1, 3)])
skin_col = np.median(cheeks, axis=0)
dist = np.linalg.norm(B - skin_col, axis=2)
skin = dist < 55
region = np.zeros(skin.shape, bool)
region[70:500, 90:430] = True
skin &= region
m = Image.fromarray((skin * 255).astype(np.uint8))
m = m.filter(ImageFilter.MaxFilter(25)).filter(ImageFilter.MinFilter(25))          # close the eyes, brows and mouth into the hull
bg = Image.fromarray(np.where(np.array(m) > 0, 255, 0).astype(np.uint8))
inv = bg.point(lambda v: 255 - v)
ImageDraw.floodfill(inv, (2, 2), 128)                                                # background reachable from the corner
holes = np.array(inv) == 255                                                         # not reachable = holes inside the hull
hull = (np.array(bg) > 0) | holes
hull &= region
hull_img = Image.fromarray((hull * 255).astype(np.uint8))

# ---- the eyes: the white of the eye (bright, unsaturated) left and right of the face centre, in the 512 frame
w = (lum(B) > 190) & ((B.max(2) - B.min(2)) < 60)
box = np.zeros(w.shape, bool)
box[130:320, 120:400] = True
w &= box & hull


def blob_centre(mask, x0, x1):
    ys, xs = np.nonzero(mask[:, x0:x1])
    return (float(xs.mean()) + x0, float(ys.mean())) if len(xs) > 8 else None


cx0 = 256.0
L = blob_centre(w, 100, 256)
R = blob_centre(w, 256, 420)
if L is None or R is None:
    # fall back to the dark pupils
    d = (lum(B) < 45) & box & hull
    L = L or blob_centre(d, 100, 256)
    R = R or blob_centre(d, 256, 420)
print("EYES", slug, L, R)
info = {"res512": 512, "skin": [float(c) for c in skin_col], "eyes512": [L, R], "eyes1000": [[L[0] * 1000 / 512, L[1] * 1000 / 512], [R[0] * 1000 / 512, R[1] * 1000 / 512]]}
json.dump(info, open(os.path.join(tex_dir, "face_info.json"), "w"), indent=1)
hull_img.resize((1000, 1000), Image.NEAREST).save(os.path.join(tex_dir, "face_mask.png"))

# ---- expression textures
mask_skin = skin & (np.linalg.norm(B - skin_col, axis=2) < 40)
Image.fromarray(B.astype(np.uint8)).save(os.path.join(out_dir, "face_neutral.png"))
for name in NAMES:
    A = np.array(Image.open(os.path.join(tex_dir, "face_%s.png" % name)).convert("RGB")).astype(np.float32)
    ref = mask_skin & (np.linalg.norm(A - skin_col, axis=2) < 70)
    off = np.clip((B[ref] - A[ref]).mean(0), -30, 30) if ref.sum() > 200 else np.zeros(3, np.float32)
    A2 = np.clip(A + off, 0, 255)
    d = np.abs(A2 - B).sum(2)
    d = np.array(Image.fromarray(np.clip(d, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(2))).astype(np.float32)
    al = np.clip((d - 40.0) / 40.0, 0, 1)
    al = np.array(Image.fromarray((al * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.GaussianBlur(3))).astype(np.float32)[..., None] / 255.0
    al = al * (np.array(hull_img.filter(ImageFilter.MinFilter(15))).astype(np.float32)[..., None] / 255.0)             # only inside the face
    out = B * (1 - al) + A2 * al
    Image.fromarray(out.astype(np.uint8)).save(os.path.join(out_dir, "face_%s.png" % name))
    print("TEX", slug, name, "offset", off.round(1), "changed pixels %.1f%%" % (100 * float((al[..., 0] > 0.3).mean())))
