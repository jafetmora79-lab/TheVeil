#!/usr/bin/env python3
"""THE VEIL - Pack 06 style cast: every remaining story character built from the hand-made Eddie reference,
exactly like Marcus (chr_style_from_eddie.py, approved) - same construction, rig, sockets, texture manner and budget.

    python3 06_Characters/Source_Scripts/chr_style_cast.py

Per character: a shape profile (per-bone deformation blended by the vertex's own skin weights: shoulders, torso, waist,
hips, bust, gut, limbs, neck, jaw, height), a hair cut (crop / keep) plus optional hair extras (bun, ponytail), the hood
folded into a collar, optional removal of drawstrings / badge, small rigid gear meshes skinned to one bone (belts,
radios, pouches, cap, bag...), and new tiny textures painted in the reference manner for every material.
The protagonist also gets first-person arms (the sleeve + hand triangles of his own body, same rig).
Deterministic. Writes <folder>/CHR_<Name>.glb (+ .import) and Documentation/STYLE_CAST_REPORT.json.
"""
import io
import json
import math
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import chr_style_from_eddie as M  # noqa: E402  (approved Marcus pipeline: glTF i/o, deformer, texture helpers)
from chr_style_from_eddie import GLB, node_globals, smooth, hexc, canvas, put, rect, blob, png  # noqa: E402

CHR, V2, REF = M.CHR, M.V2, M.REF


# ====================================================================== shape
class Shape(M.Deformer):
    def __init__(self, js, G, s):
        super().__init__(js, G)
        self.s = s
        self.arm_dx = {k: self.P[f"{k}UpperArm"][0] * (s["shoulder"] - 1.0) for k in ("Left", "Right")}
        self.leg_dx = {k: np.sign(self.P[f"{k}UpperLeg"][0]) * s.get("leg_dx", 0.0) for k in ("Left", "Right")}

    def bone(self, name, p):
        s, P = self.s, self.P
        x, y, z = p
        if name in ("Hips", "Spine", "Chest", "UpperChest", "LeftShoulder", "RightShoulder"):
            front = z < 0.0
            belly = smooth((y - 0.86) / 0.08) * smooth((1.22 - y) / 0.1)
            waist = smooth((y - 0.92) / 0.06) * smooth((1.16 - y) / 0.08)            # narrowest around y 1.02
            hips = smooth((1.0 - y) / 0.08)
            sx = s["torso"] * (1 - s.get("waist", 0.0) * waist) * (1 + s.get("hips", 0.0) * hips)
            if name in ("LeftShoulder", "RightShoulder", "UpperChest"):
                sx *= s["shoulder"] / s["torso"] if y > 1.30 else 1.0
            sz = ((s.get("front", 1.04) + s.get("belly", 0.0) * belly) if front else s.get("back", 1.03)) * (1 - 0.5 * s.get("waist", 0.0) * waist)
            nz = z * sz
            if s.get("bust") and front:
                for cx in (-0.078, 0.078):
                    nz -= s["bust"] * math.exp(-((x - cx) / 0.055) ** 2 - ((y - 1.285) / 0.055) ** 2)
            return np.array([x * sx, y, nz])
        if name == "Neck":
            c = P["Neck"]
            k = s.get("neck", 1.0)
            return np.array([c[0] + (x - c[0]) * k, y, c[2] + (z - c[2]) * k])
        if name == "Head":
            return np.array([x * s.get("head_x", 1.0), y, z])
        for sd in ("Left", "Right"):
            if name.startswith(sd) and any(k in name for k in ("UpperArm", "LowerArm", "Hand")):
                dx = np.array([self.arm_dx[sd], 0, 0])
                if "UpperArm" in name:
                    q = self.seg(P[f"{sd}UpperArm"], P[f"{sd}LowerArm"], p, s.get("arm", 1.0))
                elif "LowerArm" in name:
                    q = self.seg(P[f"{sd}LowerArm"], P[f"{sd}Hand"], p, s.get("forearm", 1.0))
                else:
                    q = self.seg(P[f"{sd}Hand"], P[f"{sd}Hand"] + (P[f"{sd}Hand"] - P[f"{sd}LowerArm"]) * 0.35, p, s.get("hand", 1.0))
                return q + dx
            if name.startswith(sd) and any(k in name for k in ("UpperLeg", "LowerLeg", "Foot", "Toes")):
                dx = np.array([self.leg_dx[sd], 0, 0])
                if "UpperLeg" in name:
                    q = self.seg(P[f"{sd}UpperLeg"], P[f"{sd}LowerLeg"], p, s.get("thigh", 1.0))
                elif "LowerLeg" in name:
                    q = self.seg(P[f"{sd}LowerLeg"], P[f"{sd}Foot"], p, s.get("calf", 1.0))
                else:
                    c = P[f"{sd}Foot"]
                    q = np.array([c[0] + (x - c[0]) * s.get("foot", 1.0), y, z])
                return q + dx
        return np.array(p, float)

    def joint_targets(self):
        P = {k: v.copy() for k, v in self.P.items()}
        for sd in ("Left", "Right"):
            for k in ("UpperArm", "LowerArm", "Hand"):
                P[f"{sd}{k}"][0] += self.arm_dx[sd]
            for k in ("UpperLeg", "LowerLeg", "Foot", "Toes"):
                P[f"{sd}{k}"][0] += self.leg_dx[sd]
            P[f"{sd}Shoulder"][0] *= self.s["shoulder"]
        return P


def hair_fn(head_c, cut):
    kind = cut[0]

    def f(p):
        x, y, z = p
        if kind == "crop":
            _, ycut, keep, bulk = cut
            if y < ycut:
                y = ycut - (ycut - y) * keep
            d = np.array([x, y, z]) - head_c
            return head_c + d * np.array([bulk, 0.985, bulk * 0.97 + 0.03])
        _, flare, bulk = cut                                  # keep length (bob): flare the ends outward
        d = np.array([x, y, z]) - head_c
        t = smooth((1.60 - y) / 0.12)
        return head_c + d * np.array([bulk + flare * t, 1.0, bulk + flare * t * 0.6])
    return f


def jaw_fn(k):
    def f(p):
        x, y, z = p
        t = smooth((1.60 - y) / 0.10)
        return np.array([x * (1 + (k - 1) * t), y, z])
    return f


# ====================================================================== small rigid meshes (gear, hair extras)
def m_box(c, size, R=np.eye(3)):
    hx, hy, hz = (v / 2 for v in size)
    corners = np.array([[sx * hx, sy * hy, sz * hz] for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)])
    faces = [(0, 1, 3, 2, (-1, 0, 0)), (4, 6, 7, 5, (1, 0, 0)), (0, 4, 5, 1, (0, -1, 0)), (2, 3, 7, 6, (0, 1, 0)), (0, 2, 6, 4, (0, 0, -1)), (1, 5, 7, 3, (0, 0, 1))]
    P, N, I = [], [], []
    for a, b, cc, d, n in faces:
        base = len(P)
        for k in (a, b, cc, d):
            P.append(c + R @ corners[k])
            N.append(R @ np.array(n, float))
        I += [base, base + 1, base + 2, base, base + 2, base + 3]
    return np.array(P), np.array(N), np.array(I)


def m_lathe(c, axis, prof, seg=8, phase=0.0):
    """surface of revolution around `axis` through c; prof = [(t, r)], caps on both ends"""
    d = np.asarray(axis, float)
    d /= np.linalg.norm(d)
    u = np.array([1.0, 0, 0]) if abs(d[0]) < 0.9 else np.array([0, 0, 1.0])
    a = np.cross(d, u)
    a /= np.linalg.norm(a)
    b = np.cross(d, a)
    P, N, I = [], [], []
    rings = []
    for t, r in prof:
        ring = []
        for k in range(seg):
            th = phase + 2 * math.pi * k / seg
            ring.append(c + d * t + (a * math.cos(th) + b * math.sin(th)) * r)
        rings.append(ring)
    for i in range(len(prof) - 1):
        for k in range(seg):
            k2 = (k + 1) % seg
            q = [rings[i][k], rings[i][k2], rings[i + 1][k2], rings[i + 1][k]]
            n = np.cross(q[1] - q[0], q[3] - q[0]) + np.cross(q[3] - q[2], q[1] - q[2])
            if np.linalg.norm(n) < 1e-10:                  # pointed end: one ring collapsed; use the open edge pair
                n = np.cross(q[2] - q[0], q[3] - q[1]) if np.linalg.norm(q[1] - q[0]) < 1e-9 else np.cross(q[1] - q[0], q[2] - q[0])
            if np.linalg.norm(n) < 1e-12:
                continue
            if np.dot(n, (q[0] + q[2]) / 2 - (c + d * np.dot((q[0] + q[2]) / 2 - c, d))) < 0:
                q = q[::-1]
                n = -n
            n = n / (np.linalg.norm(n) + 1e-12)
            base = len(P)
            P += q
            N += [n] * 4
            I += [base, base + 1, base + 2, base, base + 2, base + 3]
    for i, sg in ((0, -1), (len(prof) - 1, 1)):
        if prof[i][1] < 1e-4:
            continue
        cc = c + d * prof[i][0]
        n = d * sg * (1 if prof[-1][0] > prof[0][0] else -1)
        base = len(P)
        P.append(cc)
        N.append(n)
        for k in range(seg):
            P.append(rings[i][k])
            N.append(n)
        for k in range(seg):
            a_, b_ = base + 1 + k, base + 1 + (k + 1) % seg
            tri = [base, a_, b_]
            if np.dot(np.cross(P[a_] - P[base], P[b_] - P[base]), n) < 0:
                tri = [base, b_, a_]
            I += tri
    return np.array(P), np.array(N), np.array(I)


def add_rigid(g, parts, joint_index, mat_index, uv_rect=None, uv_mode="rect"):
    """append one skinned primitive (all parts rigid to one joint) to a new mesh; returns (mesh index, tris)"""
    js = g.js
    P = np.concatenate([p[0] for p in parts])
    N = np.concatenate([p[1] for p in parts])
    I, off = [], 0
    for p in parts:
        I.append(p[2] + off)
        off += len(p[0])
    I = np.concatenate(I).astype(np.uint16)
    if uv_mode == "rect":
        u0, v0, u1, v1 = uv_rect
        UV = np.tile([(u0 + u1) / 2, (v0 + v1) / 2], (len(P), 1))
        UV += (np.random.default_rng(len(P)).random((len(P), 2)) - 0.5) * [(u1 - u0) * 0.6, (v1 - v0) * 0.6]
    else:                                              # cylindrical (hair extras)
        c = P.mean(0)
        UV = np.c_[(np.arctan2(P[:, 0] - c[0], P[:, 2] - c[2]) / (2 * math.pi) + 0.5), (P[:, 1] - P[:, 1].min()) / max(np.ptp(P[:, 1]), 1e-6)]
    J = np.tile(np.array([joint_index, 0, 0, 0], np.uint8), (len(P), 1))
    Wt = np.tile(np.array([1, 0, 0, 0], np.float32), (len(P), 1))
    idx = {}
    for key, arr, typ, ct in (("POSITION", P.astype(np.float32), "VEC3", 5126), ("NORMAL", N.astype(np.float32), "VEC3", 5126),
                              ("TEXCOORD_0", UV.astype(np.float32), "VEC2", 5126), ("JOINTS_0", J, "VEC4", 5121), ("WEIGHTS_0", Wt, "VEC4", 5126)):
        js["accessors"].append({"componentType": ct, "count": len(arr), "type": typ, **({"min": [0, 0, 0], "max": [0, 0, 0]} if key == "POSITION" else {})})
        idx[key] = len(js["accessors"]) - 1
        g.data[idx[key]] = arr
    js["accessors"].append({"componentType": 5123, "count": len(I), "type": "SCALAR"})
    ii = len(js["accessors"]) - 1
    g.data[ii] = I.reshape(-1, 1)
    return {"attributes": idx, "indices": ii, "material": mat_index}, len(I) // 3


# ====================================================================== textures
def tile_weave(base, line, step=3, patches=(), stitches=None, seed=1, diag=False):
    rng = np.random.default_rng(seed)
    a = canvas(64, 64, base)
    for y in range(64):
        for x in range(64):
            if (diag and (x + y) % step == 0) or (not diag and x % step == 0):
                a[y, x] = hexc(line)
    for (col, n, rmin, rmax) in patches:
        for _ in range(n):
            blob(a, rng.integers(0, 64), rng.integers(0, 64), int(rng.integers(rmin, rmax + 1)), col, rng)
    if stitches:
        for _ in range(4):
            x, y = int(rng.integers(4, 56)), int(rng.integers(4, 58))
            for k in range(0, 8, 2):
                put(a, x + k, y + (k // 3), stitches)
    return a


def tile_knit(base, dark, light, seed=2):
    a = canvas(64, 64, base)
    for x in range(0, 64, 4):
        rect(a, x, 0, 1, 64, dark)
        for y in range(0, 64, 4):
            put(a, x + 2, y, light)
            put(a, x + 1, y + 2, light)
    return a


def tile_ribs(base, dark, light, n=32):
    a = canvas(32, 32, base)
    for x in range(0, 32, 2):
        rect(a, x, 0, 1, 32, dark)
    for x in range(1, 32, 4):
        rect(a, x, 0, 1, 32, light)
    return a


def tile_plaid(base, band, line, cross, seed=0):
    a = canvas(64, 64, base)
    for k in range(0, 64, 16):
        rect(a, k, 0, 6, 64, band)
        rect(a, 0, k, 64, 6, band)
        rect(a, k + 10, 0, 1, 64, line)
        rect(a, 0, k + 10, 64, 1, line)
        for j in range(0, 64, 16):
            rect(a, k, j, 6, 6, cross)
    for y in range(64):
        for x in range(64):
            if (x + y) % 4 == 0 and tuple(a[y, x]) == hexc(base):
                put(a, x, y, band)
    return a


FONT = {"A": "010101111101101", "C": "011100100100011", "D": "110101101101110", "E": "111100110100111", "G": "011100101101011",
        "I": "111010010010111", "L": "100100100100111", "M": "101111111101101", "O": "010101101101010", "P": "110101110100100",
        "R": "110101110101101", "S": "011100010001110", "T": "111010010010010", "U": "101101101101111", "Y": "101101010010010",
        "H": "101101111101101", "N": "110101101101101", "K": "101110100110101", "V": "101101101101010"}


def text(a, s, x, y, c):
    for ch in s:
        g = FONT.get(ch)
        if g:
            for k, bit in enumerate(g):
                if bit == "1":
                    put(a, x + k % 3, y + k // 3, c)
        x += 4


def panel(kind, p):
    """front shirt panel (64x64, clamped; the visible middle is x 16..48)"""
    a = canvas(64, 64, p["base"])
    if kind == "tee":
        rect(a, 16, 0, 32, 3, p["dark"])
        for y in range(6, 64, 5):
            for x in range(18, 46, 7):
                put(a, x + (y % 2), y, p["dark"])
        if p.get("print"):
            p["print"](a)
    elif kind == "placket_tie":
        for y in range(64):
            for x in range(16, 48):
                if (x + y) % 4 == 0:
                    put(a, x, y, p["dark"])
        rect(a, 29, 0, 6, 64, p["tie"])
        rect(a, 30, 0, 4, 3, p["knot"])
        for y in range(8, 64, 8):
            put(a, 31, y, p["tie_line"])
            put(a, 32, y + 1, p["tie_line"])
        if p.get("clip"):
            rect(a, 28, 30, 8, 2, p["clip"])
    elif kind == "blouse":
        rect(a, 31, 0, 2, 64, p["dark"])
        for y in range(6, 64, 9):
            rect(a, 31, y, 2, 2, p["button"])
        rect(a, 22, 0, 9, 3, p["dark"])
        rect(a, 33, 0, 9, 3, p["dark"])
    elif kind == "uniform_ems":
        for y in range(64):
            for x in range(16, 48):
                if (x + y) % 4 == 0:
                    put(a, x, y, p["dark"])
        rect(a, 31, 0, 2, 64, p["dark"])
        rect(a, 16, 30, 32, 4, p["stripe"])
        for x in range(16, 48, 3):
            put(a, x, 31, p["stripe_hi"])
    return a


def tex_patch(kind, p):
    """32x16 chest badge slot"""
    a = canvas(32, 16, p["base"])
    if kind == "text":
        rect(a, 0, 0, 32, 1, p["edge"])
        rect(a, 0, 15, 32, 1, p["edge"])
        if len(p["text"]) * 4 - 1 <= 28:
            rect(a, 0, 0, 1, 16, p["edge"])
            rect(a, 31, 0, 1, 16, p["edge"])
        w = len(p["text"]) * 4 - 1
        text(a, p["text"], (32 - w) // 2, 5, p["ink"])
    elif kind == "shield":
        for y in range(2, 15):
            half = 7 if y < 10 else 7 - (y - 9) * 1.4
            rect(a, int(16 - half), y, int(2 * half), 1, p["gold"])
        rect(a, 12, 5, 8, 4, p["gold_dk"])
        put(a, 16, 3, p["gold_hi"])
    elif kind == "brooch":
        for (dx, dy) in ((0, -3), (3, 0), (0, 3), (-3, 0)):
            rect(a, 15 + dx, 7 + dy, 3, 3, p["gold"])
        rect(a, 15, 7, 3, 3, p["stone"])
    elif kind == "pin":
        rect(a, 13, 5, 6, 6, p["pin"])
        rect(a, 14, 6, 4, 4, p["pin_hi"])
    return a


def tex_hair(base, shades, specks=None, speck_n=0, seed=3, curl=False):
    rng = np.random.default_rng(seed)
    a = canvas(64, 64, base)
    for x in range(64):
        c = shades[int(rng.integers(0, len(shades)))]
        y0, L = int(rng.integers(0, 64)), int(rng.integers(8, 30))
        for y in range(y0, y0 + L):
            put(a, (x + (y // 6 if curl else 0)) % 64, y % 64, c)
    for _ in range(speck_n):
        x, y = int(rng.integers(0, 64)), int(rng.integers(0, 64))
        put(a, x, y, specks)
        put(a, x, (y + 1) % 64, specks)
    return a


def tex_skin(base, dot):
    a = canvas(32, 32, base)
    for y in range(5, 32, 8):
        for x in range(3, 32, 8):
            put(a, x, y, dot)
    return a


def tex_gear(cols):
    """32x32 gear swatches (4x4 grid of 8x8); returns image + rect per colour name"""
    a = canvas(32, 32, "#202020")
    rects = {}
    for k, (nm, c) in enumerate(cols.items()):
        x, y = (k % 4) * 8, (k // 4) * 8
        rect(a, x, y, 8, 8, c)
        put(a, x + 1, y + 1, c)
        rects[nm] = ((x + 1) / 32, (y + 1) / 32, (x + 7) / 32, (y + 7) / 32)
    return a, rects


def tex_head(ref, f):
    """face in the reference layout; f = face spec"""
    src = np.asarray(Image.open(io.BytesIO(ref)).convert("RGB")).copy()
    sk, sd, ln = f["skin"], f["shade"], f["line"]
    remap = {"#271210": f["hair_dk"], "#371f19": f["hair"], "#c6856f": sd, "#deac86": sk, "#ad615b": ln, "#bf9881": f.get("stub", sd)}
    out = src.copy()
    for k, v in remap.items():
        out[(src == hexc(k)).all(-1)] = hexc(v)
    rect(out, 43, 18, 43, 33, sk)
    if f.get("stubble"):                               # 1 = light (reference rows), 2 = heavy (every row)
        for y in range(41, 59):
            for x in range(38, 91):
                if (x + y) % 2 == 0 and (f["stubble"] == 2 or y % 2 == 0):
                    out[y, x] = hexc(f["stub"])
    else:                                              # clean jaw: the reference stubble dither becomes plain face / jaw skin
        stub_px = (src == hexc("#bf9881")).all(-1)
        for y in range(41, 59):
            for x in range(38, 91):
                if stub_px[y, x]:                          # take the colour of the neighbouring (non-dither) pixel
                    out[y, x] = out[y, x - 1] if not stub_px[y, x - 1] else out[y, x + 1]
    B = f["brows"]
    bc = f.get("brow_col", f["hair_dk"])
    th = f.get("brow_t", 2)
    for x0, x1 in ((51, 61), ):
        for x in range(x0, x1):
            t = (x - x0) / (x1 - x0 - 1)
            y = round(B[0] + (B[1] - B[0]) * t + B[2] * math.sin(math.pi * t))
            for k in range(th):
                put(out, x, y + k, bc)
                put(out, 129 - x, y + k, bc)
    if f.get("worry"):
        put(out, 63, 22, ln)
        put(out, 65, 22, ln)
    if f.get("forehead"):
        for x in range(57, 72):
            if x % 3:
                put(out, x, 18, sd)
    if f.get("scowl"):
        for y in (22, 23):
            put(out, 63, y, ln)
            put(out, 65, y, ln)
    E = f["eyes"]
    for cx in (56, 72):
        for x in range(cx - 4, cx + 5):
            put(out, x, 27, f.get("lid", "#2a1c16"))
        if f.get("lashes"):
            put(out, cx + (5 if cx > 64 else -5), 26, f.get("lid", "#2a1c16"))     # outer-corner lash
        rows = (28, 29) if E.get("open", 2) == 2 else (28,)
        for y in rows:
            for x in range(cx - 3, cx + 4):
                put(out, x, y, "#e6dccb" if y == 28 else "#d8ccb8")
        for y in rows:
            put(out, cx, y, E["iris"])
            put(out, cx + 1, y, E["iris"])
        put(out, cx + 1, rows[-1], E.get("pupil", "#1e1410"))
        for x in range(cx - 3, cx + 4):
            put(out, x, rows[-1] + 1, ln if E.get("bags") else sd)
        if E.get("bags"):
            for x in range(cx - 3, cx + 3):
                put(out, x, rows[-1] + 3, sd)
        if f.get("crows"):
            o = 5 if cx > 64 else -5
            put(out, cx + o, 28, sd)
            put(out, cx + o + (1 if o > 0 else -1), 29, sd)
        if f.get("glasses"):
            gc = f["glasses"]
            for x in range(cx - 5, cx + 6):
                put(out, x, 25, gc)
                put(out, x, 32, gc)
            for y in range(25, 33):
                put(out, cx - 5, y, gc)
                put(out, cx + 5, y, gc)
    if f.get("glasses"):
        rect(out, 61, 27, 7, 1, f["glasses"])
    N = f.get("nose", "mid")
    nl, nr = (61, 67) if N == "narrow" else (60, 68)
    for y in range(29, 41):
        put(out, nl, y, sd)
        put(out, nr, y, ln)
    for x in range(nl + 1, nr):
        put(out, x, 40, sd)
    for x in (nl, nl + 1, nr - 1, nr):
        put(out, x, 41, ln)
    if f.get("folds"):
        for k in range(5):
            put(out, 58 - k // 2, 42 + k, ln)
            put(out, 70 + k // 2, 42 + k, ln)
    if f.get("mustache"):
        for x in range(56, 73):
            put(out, x, 43, f["mustache"])
            put(out, x, 44, f["mustache"])
        put(out, 55, 45, f["mustache"])
        put(out, 73, 45, f["mustache"])
    Mo = f["mouth"]
    lip = f.get("lip", "#8a4a40")
    w0, w1, curve = Mo
    for x in range(w0, w1 + 1):
        put(out, x, 46, lip)
    if curve < 0:
        put(out, w0 - 1, 47, lip)
        put(out, w1 + 1, 47, lip)
    elif curve > 0:
        put(out, w0 - 1, 45, lip)
        put(out, w1 + 1, 45, lip)
    for x in range(w0 + 2, w1 - 1):
        put(out, x, 47, f.get("lip_lo", sd))
    if f.get("freckles"):
        rng = np.random.default_rng(9)
        for _ in range(16):                             # light scatter across nose bridge and cheeks
            x = int(rng.integers(49, 80))
            y = int(rng.integers(32, 38))
            if not (61 <= x <= 67) or y < 34:
                put(out, x, y, f["freckles"])
    if f.get("wrinkles"):
        for y in (19, 21):
            for x in range(56, 73):
                if (x + y) % 3:
                    put(out, x, y, sd)
        for y in range(48, 52):
            put(out, 55, y, sd)
            put(out, 73, y, sd)
    if f.get("spots"):
        for (x, y) in ((48, 22), (79, 20), (82, 35)):
            put(out, x, y, f["spots"])
    if f.get("blush"):
        for (x0, y0) in ((47, 34), (77, 34)):
            for k in range(0, 6, 2):
                put(out, x0 + k, y0, f["blush"])
                put(out, x0 + k + 1, y0 + 1, f["blush"])
    return out


def tex_shoes(ref, cmap, laces=None, scuffs=None):
    src = np.asarray(Image.open(io.BytesIO(ref)).convert("RGB")).copy()
    base = {"#be3a34": "upper", "#e4e0d2": "panel", "#28282c": "eyelet", "#a3212f": "tongue", "#d4cdc2": "welt", "#f4efe3": "logo",
            "#c4bab2": "stitch", "#3c3838": "sole", "#dc5046": "stripe"}
    out = src.copy()
    for k, role in base.items():
        out[(src == hexc(k)).all(-1)] = hexc(cmap[role])
    if laces:
        for y in range(12, 22, 2):
            for x in range(14, 40, 4):
                put(out, x, y, laces)
                put(out, x + 1, y, laces)
    if scuffs:
        rng = np.random.default_rng(5)
        for _ in range(24):
            put(out, int(rng.integers(0, 42)), int(rng.integers(0, 54)), scuffs)
    return out


# ====================================================================== cast
def print_moth(a):
    """small fictional graphic for Lena's tee: a moth over a notebook line"""
    c = "#cfc8b8"
    for (x, y) in ((28, 18), (29, 17), (30, 18), (34, 18), (35, 17), (36, 18), (31, 19), (32, 19), (33, 19), (32, 20), (32, 21)):
        put(a, x, y, c)
    for (x, y) in ((27, 19), (28, 20), (29, 21), (37, 19), (36, 20), (35, 21)):
        put(a, x, y, "#a49d8f")
    rect(a, 24, 26, 17, 1, "#a49d8f")


CAST = {
    "Protagonist": dict(
        folder="Protagonist", height=1.78, title="The protagonist (player character, name TBD) - style rev 4",
        shape=dict(shoulder=1.03, torso=1.02, front=1.03, back=1.02, arm=1.02, forearm=1.02, hand=1.0, thigh=1.02, calf=1.0, neck=1.04, head_x=1.0),
        jaw=1.03, hair=("crop", 1.60, 0.38, 1.03), drop=["drawstrings", "badge"], fp_arms=True,
        tex=dict(top=lambda: tile_weave("#6e7072", "#62646a", 3, patches=[("#7a7c7e", 5, 3, 5), ("#5a5c60", 2, 2, 3)], seed=21),
                 cuff=lambda: tile_ribs("#55575b", "#484a4e", "#606266"),
                 shirt=lambda: panel("tee", dict(base="#3f5a45", dark="#344b39")),
                 pants=lambda: tile_weave("#34405a", "#2b354c", 4, patches=[("#3e4b66", 3, 3, 6)], seed=4, diag=True),
                 hem=lambda: tile_ribs("#2b354c", "#232c40", "#3e4b66"),
                 skin=lambda: tex_skin("#dcab88", "#c79373"), sole=lambda: canvas(32, 32, "#e2ddd2"),
                 hair=lambda: tex_hair("#2c211b", ["#231a15", "#36291f", "#1c1511"], seed=31),
                 shoes=dict(cmap=dict(upper="#5c5f66", panel="#e2ddd2", eyelet="#2a2a2e", tongue="#4e5158", welt="#d0cabe", logo="#5c5f66",
                                      stitch="#bdb6aa", sole="#3a3836", stripe="#4e5158"), laces="#d8d2c4")),
        face=dict(skin="#dcab88", shade="#c79373", line="#ad705f", hair="#2c211b", hair_dk="#1f1712", stub="#b88c72", stubble=1,
                  brows=(24, 23, -1), brow_t=2, eyes=dict(iris="#5a4632", bags=True), nose="mid", mouth=(59, 69, 0), lip="#9a5a4c")),
    "Ruth": dict(
        folder="Civilians", height=1.60, title="Ruth - retired librarian (68) - style rev 4",
        shape=dict(shoulder=0.90, torso=0.94, waist=0.08, hips=0.08, front=1.02, back=1.03, bust=0.020, arm=0.92, forearm=0.92, hand=0.92,
                   thigh=0.96, calf=0.92, neck=0.88, head_x=0.97, foot=0.94),
        jaw=0.93, hair=("crop", 1.64, 0.25, 1.02), extras=["bun"], drop=["drawstrings"],
        tex=dict(top=lambda: tile_knit("#8a5a62", "#7a4c55", "#9c6c72"), cuff=lambda: tile_ribs("#7a4c55", "#6a414a", "#8a5a62"),
                 shirt=lambda: panel("blouse", dict(base="#e8dfcc", dark="#d4c9b2", button="#b8a98c")),
                 pants=lambda: tile_weave("#6a6762", "#5e5b57", 3, patches=[("#74716b", 2, 3, 5)], seed=8, diag=True),
                 hem=lambda: tile_ribs("#5e5b57", "#524f4b", "#74716b"), skin=lambda: tex_skin("#e0b9a0", "#c9a08a"),
                 sole=lambda: canvas(32, 32, "#3a2c24"), badge=lambda: tex_patch("brooch", dict(base="#8a5a62", gold="#c9a54a", stone="#5a7a9a")),
                 hair=lambda: tex_hair("#b9b6b0", ["#a8a5a0", "#cbc8c2", "#99968f"], seed=41, curl=True),
                 shoes=dict(cmap=dict(upper="#3d2c22", panel="#4a3628", eyelet="#2a2420", tongue="#33251d", welt="#2a2420", logo="#3d2c22",
                                      stitch="#5a4636", sole="#1f1a18", stripe="#2a2420"))),
        face=dict(skin="#e0b9a0", shade="#c9a08a", line="#a8786a", hair="#b9b6b0", hair_dk="#9a968f", brows=(23, 23, -1), brow_t=1, brow_col="#8f8a84",
                  eyes=dict(iris="#4e6a7a", open=1), nose="narrow", mouth=(60, 68, -1), lip="#a06a62", wrinkles=True, crows=True, folds=True,
                  spots="#c79a84", glasses="#5a4a42")),
    "Sarah": dict(
        folder="Civilians", height=1.68, title="Sarah - paramedic - style rev 4",
        shape=dict(shoulder=0.95, torso=0.97, waist=0.07, hips=0.06, front=1.02, back=1.02, bust=0.016, arm=0.96, forearm=0.95, hand=0.94,
                   thigh=0.98, calf=0.96, neck=0.92, head_x=0.97),
        jaw=0.94, hair=("crop", 1.62, 0.30, 1.02), extras=["ponytail"], drop=["drawstrings"],
        gear=["belt", "radio_chest", "pouch_L", "pouch_R"],
        tex=dict(top=lambda: tile_weave("#2e3a56", "#26314a", 3, patches=[("#26314a", 3, 3, 5)], seed=51), cuff=lambda: tile_ribs("#26314a", "#1f2840", "#36446a"),
                 shirt=lambda: panel("uniform_ems", dict(base="#2e3a56", dark="#26314a", stripe="#c9c46a", stripe_hi="#e8e4a0")),
                 pants=lambda: tile_weave("#2a3450", "#222b42", 4, patches=[("#222b42", 2, 3, 5)], seed=52, diag=True),
                 hem=lambda: tile_ribs("#222b42", "#1b2236", "#323e5e"), skin=lambda: tex_skin("#e6b896", "#d09f80"),
                 sole=lambda: canvas(32, 32, "#1f1c1a"), badge=lambda: tex_patch("text", dict(base="#2e3a56", edge="#e8e4dc", ink="#e8e4dc", text="EMS")),
                 hair=lambda: tex_hair("#8a4a2c", ["#7a3f24", "#9a5634", "#6a3620"], seed=61),
                 shoes=dict(cmap=dict(upper="#26221f", panel="#302b27", eyelet="#151312", tongue="#211d1a", welt="#1b1816", logo="#26221f",
                                      stitch="#3a3430", sole="#121010", stripe="#1b1816"), laces="#3a3430", scuffs="#3a3430")),
        face=dict(skin="#e6b896", shade="#d09f80", line="#b07a64", hair="#8a4a2c", hair_dk="#6a3620", brows=(24, 22, 0), brow_t=1, brow_col="#6a3620",
                  eyes=dict(iris="#5a7a4a"), nose="narrow", mouth=(60, 68, 0), lip="#b0685e", freckles="#c58a6c", lashes=True)),
    "Frank": dict(
        folder="Commercial_NPCs", height=1.76, title="Frank - security guard - style rev 4",
        shape=dict(shoulder=1.12, torso=1.12, front=1.08, belly=0.16, back=1.06, arm=1.13, forearm=1.10, hand=1.08, thigh=1.10, calf=1.08,
                   neck=1.18, head_x=1.05, leg_dx=0.016, foot=1.06),
        jaw=1.09, hair=("crop", 1.66, 0.20, 1.015), drop=["drawstrings"], gear=["belt", "radio_belt", "flashlight", "keys"],
        tex=dict(top=lambda: tile_weave("#8aa2bf", "#7d94b0", 3, patches=[("#7d94b0", 3, 3, 5)], seed=71), cuff=lambda: tile_ribs("#7d94b0", "#6f86a2", "#96aecb"),
                 shirt=lambda: panel("placket_tie", dict(base="#8aa2bf", dark="#7d94b0", tie="#1f2230", knot="#2a2e40", tie_line="#2a2e40", clip="#b9b2a2")),
                 pants=lambda: tile_weave("#26272b", "#1f2024", 3, patches=[("#1f2024", 2, 3, 5)], seed=72, diag=True),
                 hem=lambda: tile_ribs("#1f2024", "#18191c", "#2e3034"), skin=lambda: tex_skin("#c89470", "#b07e5e"),
                 sole=lambda: canvas(32, 32, "#141414"), badge=lambda: tex_patch("text", dict(base="#2a2e40", edge="#c9a54a", ink="#e8e4dc", text="SECURITY")),
                 hair=lambda: tex_hair("#4a3e36", ["#3e342c", "#5a4e44"], specks="#8a8278", speck_n=60, seed=81),
                 shoes=dict(cmap=dict(upper="#1c1b1b", panel="#262424", eyelet="#101010", tongue="#181717", welt="#121212", logo="#1c1b1b",
                                      stitch="#2e2c2c", sole="#0e0e0e", stripe="#121212"), laces="#262424")),
        face=dict(skin="#c89470", shade="#b07e5e", line="#946450", hair="#4a3e36", hair_dk="#3a302a", stub="#a27a60", stubble=1,
                  brows=(22, 25, 0), brow_t=2, eyes=dict(iris="#3e3026", open=1), nose="mid", mouth=(59, 69, -1), lip="#8a5244", mustache="#4a3e36",
                  scowl=True, folds=True)),
    "Lena": dict(
        folder="Civilians", height=1.65, title="Lena - student investigator - style rev 4",
        shape=dict(shoulder=0.93, torso=0.95, waist=0.08, hips=0.05, front=1.01, back=1.02, bust=0.013, arm=0.93, forearm=0.93, hand=0.93,
                   thigh=0.95, calf=0.93, neck=0.90, head_x=0.97),
        jaw=0.93, hair=("keep", 0.10, 1.04), drop=["drawstrings"], gear=["bag", "strap"],
        tex=dict(top=lambda: tile_plaid("#2f6b6a", "#1f4c4c", "#c9c2a8", "#173a3a"), cuff=lambda: tile_ribs("#1f4c4c", "#173a3a", "#2f6b6a"),
                 shirt=lambda: panel("tee", dict(base="#6e6e72", dark="#606064", print=print_moth)),
                 pants=lambda: tile_weave("#232327", "#1c1c20", 4, patches=[("#2c2c31", 3, 3, 6)], seed=92, diag=True),
                 hem=lambda: tile_ribs("#3a3a40", "#2c2c31", "#48484e"), skin=lambda: tex_skin("#8a5a3e", "#744a32"),
                 sole=lambda: canvas(32, 32, "#2a2420"), badge=lambda: tex_patch("pin", dict(base="#2f6b6a", pin="#c9a54a", pin_hi="#e2c46a")),
                 hair=lambda: tex_hair("#1c1614", ["#141010", "#241c18", "#0e0b0a"], seed=95),
                 shoes=dict(cmap=dict(upper="#5a3a24", panel="#6a4a30", eyelet="#2a2018", tongue="#4e321e", welt="#2a2018", logo="#5a3a24",
                                      stitch="#7a5a3c", sole="#1e1815", stripe="#2a2018"), laces="#c9b48a")),
        face=dict(skin="#8a5a3e", shade="#744a32", line="#5e3a28", hair="#1c1614", hair_dk="#120e0c", brows=(24, 23, -2), brow_t=1, brow_col="#120e0c",
                  eyes=dict(iris="#3a2618", pupil="#120c08"), nose="narrow", mouth=(61, 67, 0), lip="#6e3a30", lip_lo="#7a4636", lashes=True)),
    "Police_Officer": dict(
        folder="Police", height=1.72, title="Greyhaven police officer (Officer Hayes candidate - identity TBD) - style rev 4",
        shape=dict(shoulder=0.98, torso=0.99, waist=0.05, hips=0.04, front=1.02, back=1.02, bust=0.012, arm=0.98, forearm=0.97, hand=0.96,
                   thigh=1.0, calf=0.98, neck=0.95, head_x=0.98),
        jaw=0.97, hair=("crop", 1.63, 0.28, 1.02), extras=["bun_small"], drop=["drawstrings"],
        gear=["belt", "radio_belt", "cuff_case", "flashlight", "radio_chest", "cap"],
        tex=dict(top=lambda: tile_weave("#26304a", "#1f283e", 3, patches=[("#1f283e", 2, 3, 5)], seed=101), cuff=lambda: tile_ribs("#1f283e", "#192034", "#2e3a58"),
                 shirt=lambda: panel("placket_tie", dict(base="#26304a", dark="#1f283e", tie="#121520", knot="#1a1e2c", tie_line="#1a1e2c", clip="#c9a54a")),
                 pants=lambda: tile_weave("#222a40", "#1c2336", 3, patches=[("#1c2336", 2, 3, 5)], seed=102, diag=True),
                 hem=lambda: tile_ribs("#1c2336", "#161c2c", "#2a3350"), skin=lambda: tex_skin("#9a6a4a", "#845a3e"),
                 sole=lambda: canvas(32, 32, "#101010"), badge=lambda: tex_patch("shield", dict(base="#26304a", gold="#c9a54a", gold_dk="#9a7c34", gold_hi="#eed27a")),
                 hair=lambda: tex_hair("#1a1513", ["#120f0e", "#221c19"], seed=111),
                 shoes=dict(cmap=dict(upper="#151414", panel="#1d1b1b", eyelet="#0c0c0c", tongue="#121111", welt="#0e0e0e", logo="#151414",
                                      stitch="#262424", sole="#0a0a0a", stripe="#0e0e0e"), laces="#1d1b1b")),
        face=dict(skin="#9a6a4a", shade="#845a3e", line="#6a4430", hair="#1a1513", hair_dk="#100c0b", brows=(23, 23, 0), brow_t=2, brow_col="#100c0b",
                  eyes=dict(iris="#2e1e14"), nose="mid", mouth=(60, 68, 0), lip="#6e4034")),
    "Cashier": dict(
        folder="Commercial_NPCs", height=1.70, title="Supermarket cashier - generic placeholder (not a bible character) - style rev 4",
        shape=dict(shoulder=0.97, torso=1.0, front=1.02, belly=0.06, back=1.02, arm=0.98, forearm=0.97, hand=0.97, thigh=1.0, calf=0.98,
                   neck=0.98, head_x=0.99),
        jaw=0.98, hair=("crop", 1.62, 0.30, 1.025), drop=["drawstrings"],
        tex=dict(top=lambda: tile_weave("#3d6b4a", "#33593e", 3, patches=[("#467856", 3, 3, 5)], seed=121),
                 cuff=lambda: tile_ribs("#33593e", "#2a4a33", "#467856"),
                 shirt=lambda: panel("tee", dict(base="#3d6b4a", dark="#33593e")),
                 pants=lambda: tile_weave("#3a3936", "#302f2c", 3, patches=[("#43423e", 2, 3, 5)], seed=122, diag=True),
                 hem=lambda: tile_ribs("#302f2c", "#272624", "#43423e"), skin=lambda: tex_skin("#d6a47e", "#c08e6a"),
                 sole=lambda: canvas(32, 32, "#2a2622"), badge=lambda: tex_patch("text", dict(base="#e8e4dc", edge="#33593e", ink="#33593e", text="MARKET")),
                 hair=lambda: tex_hair("#6a4a30", ["#5a3e28", "#7a5638", "#4e3622"], seed=131),
                 shoes=dict(cmap=dict(upper="#2c2a28", panel="#363330", eyelet="#151413", tongue="#26241f", welt="#1e1c1a", logo="#2c2a28",
                                      stitch="#45413c", sole="#141312", stripe="#1e1c1a"), laces="#45413c")),
        face=dict(skin="#d6a47e", shade="#c08e6a", line="#a6745e", hair="#6a4a30", hair_dk="#4e3622", brows=(23, 23, 0), brow_t=1, brow_col="#4e3622",
                  eyes=dict(iris="#4a5a3a"), nose="mid", mouth=(60, 68, 1), lip="#a2625a")),
}
GEAR_COLS = {"black": "#1e1e20", "dark": "#2e2e32", "leather": "#4a3324", "olive": "#4e5238", "navy": "#1f283e", "metal": "#8f8f94",
             "gold": "#c9a54a", "orange": "#c8742c", "canvas": "#7a6a4e", "red": "#8a2a26", "white": "#d8d4c8", "brass": "#a88c4a",
             "cap": "#1c2236", "cap_band": "#101010", "brim": "#0c0c0c", "silver": "#b9bcc2"}


# ====================================================================== build one
def ring_at(Pall, y, pad):
    """body cross-section ellipse (radii in x / z) at height y from the deformed body vertices"""
    band = Pall[(np.abs(Pall[:, 1] - y) < 0.03) & (np.abs(Pall[:, 0]) < 0.26)]        # torso only (A-pose hands hang at hip height)
    cx = 0.0
    cz = (band[:, 2].min() + band[:, 2].max()) / 2
    return cx, cz, (band[:, 0].max() - band[:, 0].min()) / 2 + pad, (band[:, 2].max() - band[:, 2].min()) / 2 + pad


def build(name, C):
    g = GLB(REF)
    js = g.js
    G, parent = node_globals(js)
    D = Shape(js, G, C["shape"])
    names = D.joints
    head_c = D.P["Head"] + np.array([0, 0.11, 0.0])
    rep = {"name": name, "source": "Commercial_NPCs/CHR_Eddie.glb (hand-made reference)", "removed": []}
    body_mesh = None
    for mi, m in enumerate(js["meshes"]):
        mesh_name = next(n["name"] for n in js["nodes"] if n.get("mesh") == mi)
        keep = []
        for p in m["primitives"]:
            mat = js["materials"][p["material"]]["name"]
            if mesh_name == "Eddie_Body" and mat == "Eddie_Sole" and "drawstrings" in C.get("drop", []):
                rep["removed"].append("drawstrings")
                continue
            if mesh_name == "Eddie_Body" and mat == "Eddie_Badge" and "badge" in C.get("drop", []):
                rep["removed"].append("badge")
                continue
            P = g.acc(p["attributes"]["POSITION"]).astype(np.float64)
            N = g.acc(p["attributes"]["NORMAL"]).astype(np.float64)
            J = g.acc(p["attributes"]["JOINTS_0"]).astype(int)
            Wt = g.acc(p["attributes"]["WEIGHTS_0"]).astype(np.float64)
            extra = None
            if mesh_name == "Eddie_Body" and mat in ("Eddie_Hoodie", "Eddie_HoodieRib"):
                extra = M.hood_to_collar
            elif mesh_name == "Eddie_Hair":
                extra = hair_fn(head_c, C["hair"])
            elif mesh_name == "Eddie_Head":
                extra = jaw_fn(C.get("jaw", 1.0))
            NP, NN = np.zeros_like(P), np.zeros_like(N)
            e = 1e-3
            for i in range(len(P)):
                f = lambda q: D.apply(q, J[i], Wt[i], extra)  # noqa: E731
                NP[i] = f(P[i])
                Jm = np.stack([(f(P[i] + np.eye(3)[k] * e) - f(P[i] - np.eye(3)[k] * e)) / (2 * e) for k in range(3)], axis=1)
                n = np.linalg.solve(Jm.T, N[i]) if abs(np.linalg.det(Jm)) > 1e-9 else N[i]
                NN[i] = n / (np.linalg.norm(n) + 1e-12)
            g.data[p["attributes"]["POSITION"]] = NP.astype(np.float32)
            g.data[p["attributes"]["NORMAL"]] = NN.astype(np.float32)
            if mesh_name == "Eddie_Hair" and C["hair"][0] == "crop":
                hj = names.index("Head")
                g.data[p["attributes"]["JOINTS_0"]] = np.tile(np.array([hj, 0, 0, 0], np.uint8), (len(P), 1))
                g.data[p["attributes"]["WEIGHTS_0"]] = np.tile(np.array([1, 0, 0, 0], np.float32), (len(P), 1))
            keep.append(p)
        m["primitives"] = keep
        if mesh_name == "Eddie_Body":
            body_mesh = mi
    # joints, height, inverse bind matrices (identical procedure to Marcus)
    tgt = D.joint_targets()
    allp = np.concatenate([g.data[p["attributes"]["POSITION"]] for m in js["meshes"] for p in m["primitives"]])
    s = C["height"] / float(allp[:, 1].max())
    for m in js["meshes"]:
        for p in m["primitives"]:
            g.data[p["attributes"]["POSITION"]] = (g.data[p["attributes"]["POSITION"]] * s).astype(np.float32)
    newG = {}
    for i, n in enumerate(js["nodes"]):
        Mx = G[i].copy()
        if n.get("name") in tgt:
            Mx[:3, 3] = tgt[n["name"]]
        newG[i] = Mx
    for i, n in enumerate(js["nodes"]):
        if n.get("name", "") not in tgt and i in parent and js["nodes"][parent[i]].get("name") in tgt:
            newG[i] = newG[parent[i]] @ (np.linalg.inv(G[parent[i]]) @ G[i])
    for i in newG:
        newG[i] = newG[i].copy()
        newG[i][:3, 3] *= s
    for i, n in enumerate(js["nodes"]):
        if "mesh" in n or n.get("name") == "Eddie_Rig":
            continue
        L = (np.linalg.inv(newG[parent[i]]) @ newG[i]) if i in parent else newG[i]
        n["translation"] = [float(v) for v in L[:3, 3]]
    sk = js["skins"][0]
    g.data[sk["inverseBindMatrices"]] = np.stack([np.linalg.inv(newG[j]).T.reshape(16) for j in sk["joints"]]).astype(np.float32)
    jpos = {js["nodes"][j]["name"]: newG[j][:3, 3] for j in sk["joints"]}
    jidx = {js["nodes"][j]["name"]: k for k, j in enumerate(sk["joints"])}
    # ---------------- extras: hair pieces + gear (rigid, one bone each)
    body_P = np.concatenate([g.data[p["attributes"]["POSITION"]] for p in js["meshes"][body_mesh]["primitives"]])
    hair_mi = next(n["mesh"] for n in js["nodes"] if n.get("name") == "Eddie_Hair")
    hair_P = np.concatenate([g.data[p["attributes"]["POSITION"]] for p in js["meshes"][hair_mi]["primitives"]])
    hair_mat = next(i for i, m_ in enumerate(js["materials"]) if m_["name"] == "Eddie_Hair")
    hc = np.array([0.0, (hair_P[:, 1].min() + hair_P[:, 1].max()) / 2, (hair_P[:, 2].min() + hair_P[:, 2].max()) / 2])
    back_z = hair_P[:, 2].max()
    extra_prims, extra_tris = [], 0
    for ex in C.get("extras", []):
        if ex in ("bun", "bun_small"):
            r = 0.055 * s if ex == "bun" else 0.042 * s
            c = np.array([0.0, hc[1] - 0.005, back_z + r * 0.55])
            prof = [(-r, 0.0), (-r * 0.7, r * 0.72), (0, r), (r * 0.7, r * 0.72), (r, 0.0)]
            part = m_lathe(c, (0, 0, 1), prof, seg=8)
        else:                                            # ponytail: from the back of the crown down past the neck
            c = np.array([0.0, hc[1] + 0.005, back_z - 0.01])
            prof = [(0.0, 0.035 * s), (0.05, 0.04 * s), (0.14, 0.03 * s), (0.22, 0.012 * s)]
            part = m_lathe(c, (0, -1, 0.32), prof, seg=7)
        pr, t = add_rigid(g, [part], jidx["Head"], hair_mat, uv_mode="cyl")
        extra_prims.append(("Hair", pr))
        extra_tris += t
    gear = C.get("gear", [])
    if gear:
        img_g, grect = tex_gear(GEAR_COLS)
        js["images"].append({"name": f"T_{name}_Gear"})
        js["textures"].append({"sampler": 1, "source": len(js["images"]) - 1})
        js["materials"].append({"name": f"{name}_Gear", "doubleSided": True, "pbrMetallicRoughness": {"baseColorTexture": {"index": len(js["textures"]) - 1},
                                "metallicFactor": 0, "roughnessFactor": 0.8}})
        gmat = len(js["materials"]) - 1
        hips_y = jpos["Hips"][1]
        bx, bz, brx, brz = ring_at(body_P, hips_y + 0.03 * s, 0.012)
        chest_y = jpos["UpperChest"][1] - 0.02
        front_z = body_P[(np.abs(body_P[:, 1] - chest_y) < 0.03) & (np.abs(body_P[:, 0]) < 0.15)][:, 2].min()
        by_bone = {}
        for gitem in gear:
            if gitem == "belt":
                part = []
                for k in range(12):
                    a0, a1 = 2 * math.pi * k / 12, 2 * math.pi * (k + 1) / 12
                    p0 = np.array([bx + brx * math.sin(a0), hips_y + 0.03 * s, bz + brz * math.cos(a0)])
                    p1 = np.array([bx + brx * math.sin(a1), hips_y + 0.03 * s, bz + brz * math.cos(a1)])
                    mid = (p0 + p1) / 2
                    d = p1 - p0
                    yaw = math.atan2(d[0], d[2])
                    Rm = np.array([[math.cos(yaw), 0, math.sin(yaw)], [0, 1, 0], [-math.sin(yaw), 0, math.cos(yaw)]])
                    part.append(m_box(mid, (0.012, 0.045 * s, np.linalg.norm(d) + 0.004), Rm))
                part.append(m_box(np.array([bx, hips_y + 0.03 * s, bz - brz - 0.006]), (0.05, 0.04, 0.012)))     # buckle (front = -z)
                by_bone.setdefault(("Hips", "black"), []).extend(part[:-1])
                by_bone.setdefault(("Hips", "metal"), []).append(part[-1])
            elif gitem in ("radio_belt", "pouch_L", "pouch_R", "cuff_case", "flashlight", "keys", "bag"):
                side = {"radio_belt": 1, "pouch_L": -1, "pouch_R": 1, "cuff_case": -1, "flashlight": -1, "keys": 1, "bag": 1}[gitem]
                ang = {"radio_belt": 1.45, "pouch_L": 1.25, "pouch_R": 1.25, "cuff_case": 2.2, "flashlight": 1.55, "keys": 2.0, "bag": 1.7}[gitem]
                y = hips_y + 0.03 * s
                px, pz = bx + side * (brx + 0.01) * math.sin(ang), bz - (brz + 0.01) * math.cos(ang)
                Rm = np.array([[math.cos(side * ang), 0, math.sin(side * ang)], [0, 1, 0], [-math.sin(side * ang), 0, math.cos(side * ang)]])
                if gitem == "radio_belt":
                    by_bone.setdefault(("Hips", "black"), []).append(m_box(np.array([px, y - 0.01, pz]), (0.055, 0.1, 0.03), Rm))
                    by_bone.setdefault(("Hips", "dark"), []).append(m_box(np.array([px, y + 0.06, pz]), (0.008, 0.06, 0.008), Rm))
                elif gitem in ("pouch_L", "pouch_R"):
                    by_bone.setdefault(("Hips", "olive" if name != "Police_Officer" else "black"), []).append(m_box(np.array([px, y - 0.01, pz]), (0.07, 0.07, 0.035), Rm))
                elif gitem == "cuff_case":
                    by_bone.setdefault(("Hips", "black"), []).append(m_box(np.array([px, y - 0.005, pz]), (0.06, 0.05, 0.03), Rm))
                elif gitem == "flashlight":
                    by_bone.setdefault(("Hips", "dark"), []).append(m_lathe(np.array([px, y + 0.03, pz]), (0, -1, 0), [(0, 0.018), (0.06, 0.016), (0.17, 0.014)], seg=6))
                elif gitem == "keys":
                    by_bone.setdefault(("Hips", "silver"), []).append(m_box(np.array([px, y - 0.04, pz]), (0.03, 0.05, 0.012), Rm))
                elif gitem == "bag":
                    by_bone.setdefault(("Hips", "canvas"), []).append(m_box(np.array([px + side * 0.03, y - 0.09, pz]), (0.28, 0.22, 0.07), Rm))
                    by_bone.setdefault(("Hips", "leather"), []).append(m_box(np.array([px + side * 0.03, y - 0.02, pz - 0.0]), (0.29, 0.07, 0.075), Rm))
            elif gitem == "radio_chest":
                sx_ = 1 if name != "Police_Officer" else -1
                by_bone.setdefault(("UpperChest", "black"), []).append(m_box(np.array([sx_ * 0.1 * s, chest_y + 0.02, front_z - 0.018]), (0.045, 0.075, 0.03)))
            elif gitem == "strap":
                a = np.array([-0.11 * s, jpos["UpperChest"][1] + 0.06, front_z + 0.02])
                b = np.array([0.12 * s, hips_y + 0.05, front_z + 0.06])
                d = b - a
                L = np.linalg.norm(d)
                zax = d / L
                xax = np.cross(np.array([0, 0, -1.0]), zax)
                xax /= np.linalg.norm(xax)
                yax = np.cross(zax, xax)
                Rm = np.stack([xax, yax, zax], axis=1)
                mid = (a + b) / 2 + np.array([0, 0, -0.012])
                by_bone.setdefault(("Chest", "leather"), []).append(m_box(mid, (0.04, 0.006, L), Rm))
            elif gitem == "cap":
                hy = hair_P[:, 1].max()
                c = np.array([0.0, hy - 0.035, hc[2] - 0.005])
                by_bone.setdefault(("Head", "cap"), []).append(m_lathe(c, (0, 1, 0), [(0, 0.118 * s), (0.05, 0.12 * s), (0.075, 0.125 * s), (0.08, 0.0)], seg=10))
                by_bone.setdefault(("Head", "cap_band"), []).append(m_lathe(c + np.array([0, -0.004, 0]), (0, 1, 0), [(0, 0.121 * s), (0.02, 0.122 * s)], seg=10))
                brim = m_box(c + np.array([0, -0.004, -0.13 * s]), (0.17 * s, 0.01, 0.07 * s), np.array([[1, 0, 0], [0, math.cos(0.2), -math.sin(0.2)], [0, math.sin(0.2), math.cos(0.2)]]))
                by_bone.setdefault(("Head", "brim"), []).append(brim)
                by_bone.setdefault(("Head", "gold"), []).append(m_box(c + np.array([0, 0.04, -0.124 * s]), (0.03, 0.03, 0.008)))
        for (bone, col), parts in by_bone.items():
            pr, t = add_rigid(g, parts, jidx[bone], gmat, uv_rect=grect[col])
            extra_prims.append(("Gear", pr))
            extra_tris += t
        gear_png = png(img_g)
    else:
        gear_png = None
    if extra_prims:
        rig = next(i for i, n in enumerate(js["nodes"]) if n.get("name") == "Eddie_Rig")
        for kind in ("Hair", "Gear"):
            prims = [p for k, p in extra_prims if k == kind]
            if not prims:
                continue
            js["meshes"].append({"name": f"{name}_{kind}Extras", "primitives": prims})
            js["nodes"].append({"name": f"Eddie_{kind}Extras", "mesh": len(js["meshes"]) - 1, "skin": 0})
            js["nodes"][rig].setdefault("children", []).append(len(js["nodes"]) - 1)
    # ---------------- names, materials, textures
    for n in js["nodes"]:
        if n.get("name", "").startswith("Eddie_"):
            n["name"] = name + "_" + n["name"][6:]
    for m in js["meshes"]:
        if m.get("name", "").startswith("Eddie"):
            m["name"] = m["name"].replace("Eddie", name)
    sk["name"] = f"{name}_Rig"
    T = C["tex"]
    roles = {"T_Eddie_Hoodie": ("Top", T["top"]), "T_Eddie_HoodieRib": ("TopCuff", T["cuff"]), "T_Eddie_Shirt": ("Shirt", T["shirt"]),
             "T_Eddie_Jeans": ("Pants", T["pants"]), "T_Eddie_JeansCuff": ("PantsHem", T["hem"]), "T_Eddie_Skin": ("Skin", T["skin"]),
             "T_Eddie_Sole": ("Sole", T["sole"]), "T_Eddie_Badge": ("Badge", T.get("badge", lambda: canvas(32, 16, "#202020"))),
             "T_Eddie_Hair": ("Hair", T["hair"])}
    images = []
    for i, img in enumerate(js["images"]):
        nm = img["name"]
        if nm == "T_Eddie_Head":
            a, role = tex_head(g.image(i), C["face"]), "Head"
        elif nm == "T_Eddie_Shoes":
            sh = T["shoes"]
            a, role = tex_shoes(g.image(i), sh["cmap"], sh.get("laces"), sh.get("scuffs")), "Shoes"
        elif nm in roles:
            role, fn = roles[nm]
            a = fn()
        else:
            a, role = img_g, "Gear"
            images.append(gear_png)
            img["name"] = f"T_{name}_Gear"
            rep.setdefault("textures", {})[img["name"]] = [int(a.shape[1]), int(a.shape[0]), int(len(np.unique(a.reshape(-1, 3), axis=0)))]
            continue
        img["name"] = f"T_{name}_{role}"
        images.append(png(a))
        rep.setdefault("textures", {})[img["name"]] = [int(a.shape[1]), int(a.shape[0]), int(len(np.unique(a.reshape(-1, 3), axis=0)))]
    rolemap = {"Hoodie": "Top", "HoodieRib": "TopCuff", "Jeans": "Pants", "JeansCuff": "PantsHem"}
    for m in js["materials"]:
        if m["name"].startswith("Eddie_"):
            b = m["name"][6:]
            m["name"] = f"{name}_{rolemap.get(b, b)}"
    js["asset"]["generator"] = "THE VEIL chr_style_cast.py (from the hand-made Eddie reference)"
    js["asset"]["extras"] = {"veil_character": name, "title": C["title"], "height_m": C["height"]}
    out = os.path.join(CHR, C["folder"], f"CHR_{name}.glb")
    g.write(out, images)
    rep["glb"] = os.path.relpath(out, V2)
    if C.get("fp_arms"):
        rep["fp_arms"] = fp_arms(out, name, C)
    return out, rep


def fp_arms(full_glb, name, C):
    """first-person arms: the sleeve, cuff and hand triangles of the full model (dominant bone in an arm chain), same rig"""
    g = GLB(full_glb)
    js = g.js
    names = [js["nodes"][j]["name"] for j in js["skins"][0]["joints"]]
    arm = {i for i, n in enumerate(names) if any(k in n for k in ("UpperArm", "LowerArm", "Hand"))}
    keep_meshes = []
    for mi, m in enumerate(js["meshes"]):
        prims = []
        for p in m["primitives"]:
            J = g.acc(p["attributes"]["JOINTS_0"]).astype(int)
            Wt = g.acc(p["attributes"]["WEIGHTS_0"])
            I = g.acc(p["indices"]).reshape(-1, 3)
            dom = J[np.arange(len(J)), np.argmax(Wt, axis=1)]
            ok = np.isin(dom, list(arm))
            tri = I[ok[I].all(1)]
            if len(tri):
                g.data[p["indices"]] = tri.reshape(-1, 1).astype(g.acc(p["indices"]).dtype)
                prims.append(p)
        m["primitives"] = prims
        if prims:
            keep_meshes.append(mi)
    remap = {old: new for new, old in enumerate(keep_meshes)}        # drop meshes left empty; reindex
    js["meshes"] = [js["meshes"][i] for i in keep_meshes]
    for n in js["nodes"]:
        if "mesh" in n:
            if n["mesh"] in remap:
                n["mesh"] = remap[n["mesh"]]
            else:
                n.pop("mesh")
                n.pop("skin", None)
    js["asset"]["extras"] = {"veil_character": name, "kind": "first_person_arms", "title": C["title"] + " - first-person arms"}
    out = full_glb.replace(".glb", "_FP_Arms.glb")
    # drop now-unused images? keep all (tiny) so material indices stay valid
    imgs = [g.image(i) for i in range(len(js["images"]))]
    g.write(out, imgs)
    return os.path.relpath(out, V2)


def main():
    sys.path.insert(0, os.path.join(V2, "02_Town", "Source_Scripts"))
    from veil_mesh.gltf import write_glb_import
    report = []
    for name, C in CAST.items():
        out, rep = build(name, C)
        write_glb_import(out, [])
        if rep.get("fp_arms"):
            write_glb_import(os.path.join(V2, rep["fp_arms"]), [])
        g2 = GLB(out)
        tri = {n["name"]: int(sum(g2.js["accessors"][p["indices"]]["count"] // 3 for p in g2.js["meshes"][n["mesh"]]["primitives"]))
               for n in g2.js["nodes"] if "mesh" in n}
        P = np.concatenate([g2.acc(p["attributes"]["POSITION"]) for m in g2.js["meshes"] for p in m["primitives"]])
        rep.update(triangles=sum(tri.values()), parts=tri, materials=len(g2.js["materials"]), height_m=round(float(P[:, 1].max()), 3),
                   width_m=round(float(np.ptp(P[:, 0])), 3))
        report.append(rep)
        print(name, rep["triangles"], rep["height_m"], rep["removed"], rep.get("fp_arms", ""))
    json.dump(report, open(os.path.join(CHR, "Documentation", "STYLE_CAST_REPORT.json"), "w", newline="\n"), indent=1)


if __name__ == "__main__":
    main()
