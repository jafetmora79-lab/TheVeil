#!/usr/bin/env python3
"""THE VEIL - Pack 06 facial expressions, eye states and visemes for the approved characters (texture-swap method).

    python3 06_Characters/Source_Scripts/chr_faces.py

The approved heads (CHR_Eddie = hand-made reference, CHR_Marcus, and the style-rev-4 cast) are low-poly with every
facial feature painted into one 128x64 head texture in a shared layout. No blend shapes, no facial bones. So faces are
animated by swapping two small pixel windows of that texture at runtime (Godot shader, Facial/veil_face.gdshader):

    UPPER window  x 44..85, y 17..35  (brows + eyes)   cell = (expression, eye action)    10 x 8 cells
    MOUTH window  x 52..77, y 41..51  (lips)            cell = (expression, viseme)        10 x 5 cells

Each cell is built from the character's OWN approved pixels: the feature pixels (brows, eye lids / whites / irises,
lip line) are lifted off the approved texture, the gap is refilled from the surrounding skin / stubble pattern
(same-row, same-parity fill, so dithers stay intact), and the features are re-placed with small, readable changes
(brows raised / lowered / tilted / uneven, lids lowered / raised, irises shifted, mouth corners and opening).
Static overlays (glasses, moustaches, freckles, folds, age spots) always stay on top, unchanged.
The (neutral, none) and (neutral, rest) cells are exact copies of the approved texture - validated pixel-for-pixel.
The approved GLBs are not modified.

Writes Facial/Faces/T_Face_<Name>.png (+ .import) and Documentation/FACE_ATLAS_REPORT.json.
"""
import io
import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from chr_style_from_eddie import GLB, hexc  # noqa: E402

CHR = os.path.normpath(os.path.join(HERE, ".."))
V2 = os.path.dirname(CHR)
OUT = os.path.join(CHR, "Facial", "Faces")

UP = (44, 17, 42, 19)          # x, y, w, h  (brows + eyes)
MO = (52, 41, 26, 11)          # mouth
EXPRESSIONS = ["neutral", "happy", "angry", "scared", "shocked", "sad", "suspicious", "confused", "determined", "pain"]
EYE_ACTIONS = ["none", "blink", "look_left", "look_right", "look_up", "look_down", "widen", "narrow"]
VISEMES = ["rest", "slight", "wide", "round", "teeth"]
ATLAS = (512, 256)
MOUTH_ORIGIN = (0, UP[3] * len(EYE_ACTIONS))           # mouth grid below the upper grid

# brows: (dy_imgL, dy_imgR, tilt_imgL, tilt_imgR); tilt > 0 = inner end lower (frown), < 0 = inner end higher (worry)
# eyes : open / half (lid lowered) / narrow (lowered + clipped corners) / wide (lid raised) / squint (nearly shut)
# mouth: corners (imgL, imgR) dy (-1 = up), widen (px each side), open rows, round, teeth
EXPR = {
    "neutral":    dict(brows=(0, 0, 0, 0), eyes="open", mouth=dict(c=(0, 0), w=0, n=0)),
    "happy":      dict(brows=(-1, -1, 0, 0), eyes="open", mouth=dict(c=(-1, -1), w=1, n=0)),
    "angry":      dict(brows=(1, 1, 2, 2), eyes="narrow", mouth=dict(c=(0, 0), w=-2, n=0)),
    "scared":     dict(brows=(-2, -2, -1, -1), eyes="wide", mouth=dict(c=(0, 0), w=-2, n=1)),
    "shocked":    dict(brows=(-2, -2, 0, 0), eyes="wide", mouth=dict(c=(0, 0), w=-3, n=2, round=True)),
    "sad":        dict(brows=(1, 1, -2, -2), eyes="half", mouth=dict(c=(1, 1), w=-1, n=0)),
    "suspicious": dict(brows=(-2, 1, 0, 1), eyes="narrow", mouth=dict(c=(-1, 1), w=-1, n=0)),
    "confused":   dict(brows=(-2, 0, -1, 1), eyes="open", mouth=dict(c=(1, -1), w=-1, n=0)),
    "determined": dict(brows=(1, 1, 1, 1), eyes="half", mouth=dict(c=(0, 0), w=-1, n=0)),
    "pain":       dict(brows=(0, 0, -2, -2), eyes="squint", mouth=dict(c=(1, 1), w=0, n=1, teeth=True)),
}
VIS = {"rest": dict(n=0), "slight": dict(n=1), "wide": dict(n=2), "round": dict(n=2, round=True), "teeth": dict(n=1, teeth=True)}

# per character: approved GLB, brow colours, static overlay colours (never moved), small personality touches
CAST = {
    "Eddie": dict(glb="Commercial_NPCs/CHR_Eddie.glb", brows=["#34221a", "#463024", "#271210"], static=[], smirk=1),
    "Marcus": dict(glb="Marcus/CHR_Marcus.glb", brows=["#241a16"], static=["#6e5040", "#7d5c49", "#9d6352"]),
    "Protagonist": dict(glb="Protagonist/CHR_Protagonist.glb", brows=["#1f1712"], static=["#ad705f"]),
    "Ruth": dict(glb="Civilians/CHR_Ruth.glb", brows=["#8f8a84"], static=["#5a4a42", "#c79a84", "#a8786a"]),
    "Sarah": dict(glb="Civilians/CHR_Sarah.glb", brows=["#6a3620"], static=["#c58a6c"]),
    "Frank": dict(glb="Commercial_NPCs/CHR_Frank.glb", brows=["#3a302a"], static=["#4a3e36", "#946450"]),
    "Lena": dict(glb="Civilians/CHR_Lena.glb", brows=["#120e0c"], static=[]),
    "Police_Officer": dict(glb="Police/CHR_Police_Officer.glb", brows=["#100c0b"], static=[]),
}


def lum(c):
    return 0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2]


def head_texture(path):
    g = GLB(path)
    for i, im in enumerate(g.js["images"]):
        if im["name"].endswith("_Head"):
            return np.asarray(Image.open(io.BytesIO(g.image(i))).convert("RGB")).copy(), im["name"]
    raise KeyError("head texture")


class Face:
    def __init__(self, tex, cfg):
        self.t = tex
        self.cfg = cfg
        T = tex
        sample = np.concatenate([T[18:41, 44:49].reshape(-1, 3), T[18:41, 81:86].reshape(-1, 3), T[51:59, 44:86].reshape(-1, 3),
                                 T[36:41, 49:58].reshape(-1, 3), T[36:41, 71:80].reshape(-1, 3)])
        vals, cnt = np.unique(sample, axis=0, return_counts=True)
        self.bg = {tuple(v) for v, c in zip(vals, cnt) if c >= 3}
        self.skin = tuple(vals[np.argmax(cnt)])
        self.static = {hexc(c) for c in cfg["static"]}
        self.brow_cols = {hexc(c) for c in cfg["brows"]}
        sl = lum(self.skin)
        self.static_px = {}
        self.brow = {}           # (x, y) -> colour, split by side
        self.eye = {}
        self.mouth = {}
        for y in range(17, 36):
            for x in range(44, 86):
                c = tuple(T[y, x])
                if c in self.static:
                    self.static_px[(x, y)] = c
                elif c in self.brow_cols and y <= 26 and 48 <= x <= 81:
                    self.brow[(x, y)] = c
                elif c not in self.bg and 49 <= x <= 79 and 24 <= y <= 34 and not (59 <= x <= 69 and y >= 29):
                    L = lum(c)
                    if L < 0.6 * sl or (L > 1.05 * sl and max(c) - min(c) < 60):
                        self.eye[(x, y)] = c
        for y in range(41, 52):
            for x in range(52, 78):
                c = tuple(T[y, x])
                if c in self.static:
                    self.static_px[(x, y)] = c
                elif c not in self.bg and 44 <= y <= 50 and 53 <= x <= 76 and lum(c) < 0.8 * sl:
                    self.mouth[(x, y)] = c
        self.plate = self.clean(set(self.brow) | set(self.eye) | set(self.mouth) | set(self.static_px))
        self._eye_model()
        self._mouth_model()

    # ---------------------------------------------------------------- background refill
    def clean(self, holes):
        P = self.t.copy()
        for (x, y) in sorted(holes):
            for k in range(1, 20):
                done = False
                for xx in (x - 2 * k, x + 2 * k):
                    if 0 <= xx < 128 and (xx, y) not in holes:
                        P[y, x] = self.t[y, xx]
                        done = True
                        break
                if done:
                    break
        return P

    # ---------------------------------------------------------------- eyes
    def _eye_model(self):
        sl = lum(self.skin)
        self.eyes = []
        for side, (x0, x1) in (("L", (49, 63)), ("R", (65, 80))):
            px = {p: c for p, c in self.eye.items() if x0 <= p[0] <= x1}
            white = {p: c for p, c in px.items() if lum(c) > 1.05 * sl}
            rows = sorted({p[1] for p in white})
            wrows = [r for r in rows if sum(1 for p in white if p[1] == r) >= 3]
            if not wrows:
                raise ValueError("no eye whites found")
            lid_row = wrows[0] - 1
            lid = {p: c for p, c in px.items() if p[1] == lid_row}
            lid_col = max(set(lid.values()), key=list(lid.values()).count) if lid else (40, 30, 30)
            xs = [p[0] for p in white]
            self.eyes.append(dict(side=side, px=px, wrows=wrows, lid_row=lid_row, lid_col=lid_col, x0=min(xs), x1=max(xs),
                                  lid_x0=min([p[0] for p in lid] or [min(xs)]), lid_x1=max([p[0] for p in lid] or [max(xs)]),
                                  white_col={r: max((c for p, c in white.items() if p[1] == r), key=lum) for r in wrows}))
        self.teeth = max((c for e in self.eyes for c in e["white_col"].values()), key=lum)

    def eye_pixels(self, e, state, action):
        px = dict(e["px"])
        wr, lr, lc = e["wrows"], e["lid_row"], e["lid_col"]
        white = lambda x, r: e["white_col"][r]  # noqa: E731
        iris = {p: c for p, c in px.items() if p[1] in wr and lum(c) < lum(self.skin) * 0.9}
        if action == "blink" or state == "closed":
            out = {p: c for p, c in px.items() if p[1] < lr}
            yl = lr + 1 if len(wr) > 1 else lr
            for x in range(e["lid_x0"], e["lid_x1"] + 1):
                out[(x, yl)] = lc
            return out
        # iris direction (character's left = image right)
        dx = {"look_left": 1, "look_right": -1}.get(action, 0)
        if dx:
            for p in iris:
                px[p] = white(p[0], p[1])
            for (x, y), c in iris.items():
                nx = min(max(x + dx, e["x0"] + 1), e["x1"] - 1)
                px[(nx, y)] = c
        if action in ("look_up", "look_down") and len(wr) > 1:
            src, dst = (wr[-1], wr[0]) if action == "look_up" else (wr[0], wr[-1])
            for (x, y), c in iris.items():
                if y == src:
                    px[(x, y)] = white(x, y)
                    px[(x, dst)] = c
        st = state
        if action == "widen":
            st = "wide"
        elif action == "narrow":
            st = {"open": "narrow", "wide": "open", "half": "squint", "narrow": "squint"}.get(state, "squint")
        elif action == "look_down" and st == "open":
            st = "half"
        if st in ("half", "narrow", "squint"):
            # a lowered lid: the lash line moves down one row (two for squint on tall eyes); where it was becomes eyelid skin
            drop = 2 if (st == "squint" and len(wr) > 2) else 1
            lid_px = [x for x in range(e["lid_x0"], e["lid_x1"] + 1) if (x, lr) in px]
            for x in lid_px:
                px.pop((x, lr), None)                      # -> plate (skin) shows through
                for k in range(1, drop):
                    px.pop((x, lr + k), None)
                if len(wr) > drop - (0 if len(wr) > 1 else 1):
                    px[(x, lr + drop)] = lc
            if len(wr) == 1:                               # single-row eyes: clip the corners instead
                for x in (e["x0"], e["x1"]):
                    px[(x, wr[0])] = lc
            if st in ("narrow", "squint"):
                for r in wr[drop:]:
                    for x in (e["x0"], e["x1"]):
                        if (x, r) in px:
                            px[(x, r)] = lc
        elif st == "wide":
            for x in range(e["lid_x0"], e["lid_x1"] + 1):
                if (x, lr) in px:
                    below = px.get((x, wr[0]), white(x, wr[0]))
                    px[(x, lr)] = below if e["x0"] <= x <= e["x1"] else lc
                px[(x, lr - 1)] = lc
        return px

    # ---------------------------------------------------------------- brows
    def brow_pixels(self, spec):
        dyL, dyR, tL, tR = spec
        out = {}
        for side, dy, tilt, (x0, x1) in (("L", dyL, tL, (44, 63)), ("R", dyR, tR, (65, 86))):
            pts = {p: c for p, c in self.brow.items() if x0 <= p[0] <= x1}
            if not pts:
                continue
            xs = [p[0] for p in pts]
            a, b = min(xs), max(xs)
            inner, outer = (b, a) if side == "L" else (a, b)
            for (x, y), c in pts.items():
                t = abs(x - outer) / max(abs(inner - outer), 1)
                out[(x, y + dy + int(round(tilt * t)))] = c
        return out

    # ---------------------------------------------------------------- mouth
    def _mouth_model(self):
        if not self.mouth:
            raise ValueError("no mouth found")
        rows = {}
        for (x, y), c in self.mouth.items():
            rows.setdefault(y, []).append((x, c))
        dark = min(self.mouth.values(), key=lum)
        ym = max(rows, key=lambda r: (len(rows[r]), -min(lum(c) for _, c in rows[r])))
        xs = [x for x, _ in rows[ym]]
        self.ym, self.w0, self.w1 = ym, min(xs), max(xs)
        cols = [c for _, c in rows[ym]]
        self.lip = max(set(cols), key=cols.count)
        below = [c for (x, y), c in self.mouth.items() if y == ym + 1]
        self.lip_lo = max(set(below), key=below.count) if below else self.lip
        self.interior = tuple(int(v * 0.45) for v in dark)

    def mouth_pixels(self, ex, vis):
        m = dict(EXPR[ex]["mouth"])
        v = VIS[vis]
        n = max(m.get("n", 0), v["n"]) if vis != "rest" else m.get("n", 0)
        rnd = m.get("round") or v.get("round")
        teeth = (m.get("teeth") or v.get("teeth")) and n > 0
        w0, w1 = self.w0 - m.get("w", 0), self.w1 + m.get("w", 0)
        if rnd:
            c = (w0 + w1) // 2
            half = max(2, (w1 - w0) // 4)
            w0, w1 = c - half, c + half
        cl, cr = m.get("c", (0, 0))
        smirk = self.cfg.get("smirk", 0)
        if smirk and ex in ("neutral", "happy", "confused", "suspicious"):
            cr -= smirk
        out = {}
        y = self.ym
        for x in range(w0, w1 + 1):
            out[(x, y)] = self.lip
        out[(w0 - 1, y + cl)] = self.lip
        out[(w1 + 1, y + cr)] = self.lip
        if n:
            for k in range(1, n + 1):
                inset = 1 if (k == 1 or not rnd) else 0
                for x in range(w0 + inset, w1 - inset + 1):
                    out[(x, y + k)] = self.teeth if (teeth and k == 1 and w0 + 1 < x < w1 - 1) else self.interior
            for x in range(w0 + 1, w1):
                out[(x, y + n + 1)] = self.lip_lo
        else:
            for x in range(w0 + 2, w1 - 1):
                if ex not in ("angry", "determined"):          # tight mouths drop the lower-lip shade
                    out[(x, y + 1)] = self.lip_lo
        return out

    # ---------------------------------------------------------------- cells
    def upper_cell(self, ex, action):
        if ex == "neutral" and action == "none":
            return self.t[UP[1]:UP[1] + UP[3], UP[0]:UP[0] + UP[2]].copy()
        img = self.plate.copy()
        for p, c in self.brow_pixels(EXPR[ex]["brows"]).items():
            img[p[1], p[0]] = c
        for e in self.eyes:
            for p, c in self.eye_pixels(e, EXPR[ex]["eyes"], action).items():
                img[p[1], p[0]] = c
        for p, c in self.static_px.items():
            if UP[1] <= p[1] < UP[1] + UP[3]:
                img[p[1], p[0]] = c
        return img[UP[1]:UP[1] + UP[3], UP[0]:UP[0] + UP[2]]

    def mouth_cell(self, ex, vis):
        if ex == "neutral" and vis == "rest":
            return self.t[MO[1]:MO[1] + MO[3], MO[0]:MO[0] + MO[2]].copy()
        img = self.plate.copy()
        for p, c in self.mouth_pixels(ex, vis).items():
            img[p[1], p[0]] = c
        for p, c in self.static_px.items():
            if MO[1] <= p[1] < MO[1] + MO[3]:
                img[p[1], p[0]] = c
        return img[MO[1]:MO[1] + MO[3], MO[0]:MO[0] + MO[2]]


def build(name, cfg):
    tex, tex_name = head_texture(os.path.join(CHR, cfg["glb"]))
    f = Face(tex, cfg)
    atlas = np.zeros((ATLAS[1], ATLAS[0], 3), np.uint8)
    for i, ex in enumerate(EXPRESSIONS):
        for j, ac in enumerate(EYE_ACTIONS):
            atlas[j * UP[3]:(j + 1) * UP[3], i * UP[2]:(i + 1) * UP[2]] = f.upper_cell(ex, ac)
        for j, vi in enumerate(VISEMES):
            y0 = MOUTH_ORIGIN[1] + j * MO[3]
            atlas[y0:y0 + MO[3], i * MO[2]:(i + 1) * MO[2]] = f.mouth_cell(ex, vi)
    os.makedirs(OUT, exist_ok=True)
    p = os.path.join(OUT, f"T_Face_{name}.png")
    Image.fromarray(atlas, "RGB").save(p, format="PNG", optimize=True)
    # validation: neutral composite == approved texture, pixel for pixel
    comp = tex.copy()
    comp[UP[1]:UP[1] + UP[3], UP[0]:UP[0] + UP[2]] = atlas[0:UP[3], 0:UP[2]]
    comp[MO[1]:MO[1] + MO[3], MO[0]:MO[0] + MO[2]] = atlas[MOUTH_ORIGIN[1]:MOUTH_ORIGIN[1] + MO[3], 0:MO[2]]
    changed = {}
    for i, ex in enumerate(EXPRESSIONS):
        u = (atlas[0:UP[3], i * UP[2]:(i + 1) * UP[2]] != atlas[0:UP[3], 0:UP[2]]).any(-1).sum()
        mth = (atlas[MOUTH_ORIGIN[1]:MOUTH_ORIGIN[1] + MO[3], i * MO[2]:(i + 1) * MO[2]] != atlas[MOUTH_ORIGIN[1]:MOUTH_ORIGIN[1] + MO[3], 0:MO[2]]).any(-1).sum()
        changed[ex] = [int(u), int(mth)]
    return dict(name=name, glb=cfg["glb"], head_texture=tex_name, atlas=os.path.relpath(p, V2), neutral_identical=bool((comp == tex).all()),
                eyes=[dict(side=e["side"], white_rows=e["wrows"], lid_row=e["lid_row"], x=[e["x0"], e["x1"]]) for e in f.eyes],
                mouth=dict(row=f.ym, x=[f.w0, f.w1]), brow_pixels=len(f.brow), static_pixels=len(f.static_px), changed_pixels_vs_neutral=changed)


def main():
    sys.path.insert(0, os.path.join(V2, "02_Town", "Source_Scripts"))
    sys.path.insert(0, os.path.join(V2, "Source_Scripts"))
    from build_library import write_import
    from veil_mesh.materials import RES_ROOT
    rep = []
    for name, cfg in CAST.items():
        r = build(name, cfg)
        write_import(os.path.join(V2, r["atlas"]), RES_ROOT + "/" + r["atlas"])
        ip = os.path.join(V2, r["atlas"]) + ".import"          # the shader reads mip 0 with texelFetch: no mipmaps needed
        open(ip, "w", newline="\n").write(open(ip).read().replace("mipmaps/generate=true", "mipmaps/generate=false"))
        rep.append(r)
        print(name, "neutral identical:", r["neutral_identical"], "eyes", [(e["side"], e["white_rows"]) for e in r["eyes"]], "mouth", r["mouth"])
    layout = dict(upper_rect=list(UP), mouth_rect=list(MO), mouth_origin=list(MOUTH_ORIGIN), atlas_size=list(ATLAS), expressions=EXPRESSIONS,
                  eye_actions=EYE_ACTIONS, visemes=VISEMES, expression_specs=EXPR)
    json.dump(dict(layout=layout, characters=rep), open(os.path.join(CHR, "Documentation", "FACE_ATLAS_REPORT.json"), "w", newline="\n"), indent=1)


if __name__ == "__main__":
    main()
