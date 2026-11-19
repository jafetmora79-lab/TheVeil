#!/usr/bin/env python3
"""THE VEIL - Pack 06 style pass: build Marcus from the hand-made Eddie reference (same construction and texture manner).

    python3 06_Characters/Source_Scripts/chr_style_from_eddie.py

The reference `Commercial_NPCs/CHR_Eddie.glb` is the art-direction model for every character, made in Blender by the
project owner. It defines the construction (layered clothing body, separate head, hair and shoes; 22-bone Godot humanoid
rig with head / back / hand sockets; A-pose), the texture manner (one tiny 32-128 px texture per material, 2-20 colours,
tiling cloth, nearest filtering) and the budget (~2.7k triangles).

Marcus is derived from it, not re-modelled from scratch, so he shares that construction exactly:
* geometry: every vertex is moved by a blend of per-bone deformations weighted by its own skin weights (seams stay
  joined): broader torso and shoulders, slight gut, thicker neck / arms / legs, heavier jaw, hood folded down into a
  jacket collar, hair cut short, drawstrings removed, 1.76 m tall; joints and inverse bind matrices are recomputed;
  normals follow the deformation (inverse-transpose of its numerical Jacobian)
* textures: all new, same sizes and UV layouts, painted in the reference manner (weathered canvas work jacket,
  corduroy cuffs, flannel shirt, olive work pants, brown work boots, salt-and-pepper hair, worried tired face)
Deterministic. Writes Marcus/CHR_Marcus_v4.glb (+ .import) and Documentation/MARCUS_V4_REPORT.json.
"""
import io
import json
import os
import struct
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
CHR = os.path.normpath(os.path.join(HERE, ".."))
V2 = os.path.dirname(CHR)
REF = os.path.join(CHR, "Commercial_NPCs", "CHR_Eddie.glb")
OUT = os.path.join(CHR, "Marcus", "CHR_Marcus.glb")              # approved: the official Marcus
HEIGHT = 1.76


# ====================================================================== glTF in / out
class GLB:
    def __init__(self, path):
        b = open(path, "rb").read()
        jl = struct.unpack_from("<I", b, 12)[0]
        self.js = json.loads(b[20:20 + jl])
        o = 20 + jl
        bl = struct.unpack_from("<I", b, o)[0]
        self.bin = b[o + 8:o + 8 + bl]
        self.data = {}                     # accessor index -> numpy array (overrides)

    def acc(self, i):
        if i in self.data:
            return self.data[i]
        A = self.js["accessors"][i]
        bv = self.js["bufferViews"][A["bufferView"]]
        n = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}[A["type"]]
        dt = {5126: np.float32, 5123: np.uint16, 5125: np.uint32, 5121: np.uint8}[A["componentType"]]
        stride = bv.get("byteStride")
        start = bv.get("byteOffset", 0) + A.get("byteOffset", 0)
        if stride and stride != n * np.dtype(dt).itemsize:
            raw = np.frombuffer(self.bin, np.uint8, A["count"] * stride, start).reshape(A["count"], stride)
            arr = raw[:, :n * np.dtype(dt).itemsize].copy().view(dt).reshape(A["count"], n)
        else:
            arr = np.frombuffer(self.bin, dt, A["count"] * n, start).reshape(A["count"], n).copy()
        return arr

    def image(self, i):
        bv = self.js["bufferViews"][self.js["images"][i]["bufferView"]]
        o = bv.get("byteOffset", 0)
        return self.bin[o:o + bv["byteLength"]]

    def write(self, path, images):
        """repack: one buffer view per accessor (current data), then images"""
        js = self.js
        out = bytearray()
        views = []

        def add(raw, target=None):
            while len(out) % 4:
                out.append(0)
            v = {"buffer": 0, "byteOffset": len(out), "byteLength": len(raw)}
            if target:
                v["target"] = target
            out.extend(raw)
            views.append(v)
            return len(views) - 1
        used = set()
        for m in js["meshes"]:
            for p in m["primitives"]:
                used |= set(p["attributes"].values()) | {p["indices"]}
        for k, A in enumerate(js["accessors"]):
            arr = self.acc(k)
            A["count"] = int(arr.shape[0])
            A.pop("byteOffset", None)
            if A["type"] == "VEC3" and A["componentType"] == 5126 and "min" in A:
                A["min"] = [float(v) for v in arr.min(0)]
                A["max"] = [float(v) for v in arr.max(0)]
            target = 34963 if A["type"] == "SCALAR" and k in used else (34962 if k in used else None)
            A["bufferView"] = add(np.ascontiguousarray(arr).tobytes(), target)
        for i, img in enumerate(js["images"]):
            img["bufferView"] = add(images[i])
            img["mimeType"] = "image/png"
        js["bufferViews"] = views
        js["buffers"] = [{"byteLength": len(out)}]
        jb = json.dumps(js, separators=(",", ":")).encode()
        jb += b" " * ((4 - len(jb) % 4) % 4)
        while len(out) % 4:
            out.append(0)
        blob = struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(jb) + 8 + len(out)) + struct.pack("<II", len(jb), 0x4E4F534A) + jb + \
            struct.pack("<II", len(out), 0x004E4942) + bytes(out)
        open(path, "wb").write(blob)


def qmat(q):
    x, y, z, w = q
    return np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)], [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                     [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])


def node_globals(js):
    """node index -> 4x4 world matrix (bind pose) and parent map"""
    parent = {}
    for i, n in enumerate(js["nodes"]):
        for c in n.get("children", []):
            parent[c] = i
    G = {}

    def local(n):
        M = np.eye(4)
        if "rotation" in n:
            M[:3, :3] = qmat(n["rotation"])
        if "scale" in n:
            M[:3, :3] = M[:3, :3] @ np.diag(n["scale"])
        if "translation" in n:
            M[:3, 3] = n["translation"]
        return M

    def g(i):
        if i not in G:
            G[i] = (g(parent[i]) if i in parent else np.eye(4)) @ local(js["nodes"][i])
        return G[i]
    for i in range(len(js["nodes"])):
        g(i)
    return G, parent


# ====================================================================== deformation
def smooth(t):
    t = np.clip(t, 0.0, 1.0)
    return t * t * (3 - 2 * t)


class Deformer:
    def __init__(self, js, G):
        self.joints = [js["nodes"][j]["name"] for j in js["skins"][0]["joints"]]
        self.jidx = js["skins"][0]["joints"]
        self.P = {js["nodes"][j]["name"]: G[j][:3, 3].copy() for j in self.jidx}
        P = self.P
        self.arm_dx = {s: P[f"{s}UpperArm"][0] * 0.10 for s in ("Left", "Right")}    # shoulders 10 % wider
        self.leg_dx = {s: np.sign(P[f"{s}UpperLeg"][0]) * 0.014 for s in ("Left", "Right")}

    def seg(self, a, b, p, k):
        """radial thickening around the bone segment a-b"""
        d = b - a
        t = np.clip(np.dot(p - a, d) / np.dot(d, d), 0, 1)
        q = a + d * t
        return q + (p - q) * k

    def bone(self, name, p):
        P = self.P
        x, y, z = p
        if name in ("Hips", "Spine", "Chest", "UpperChest", "LeftShoulder", "RightShoulder"):
            front = z < 0.0
            belly = smooth((y - 0.86) / 0.08) * smooth((1.22 - y) / 0.1)        # a gut between hips and chest
            sz = (1.06 + 0.12 * belly) if front else 1.05
            sx = 1.10 if name != "Hips" else 1.08
            return np.array([x * sx, y, z * sz])
        if name == "Neck":
            c = P["Neck"]
            return np.array([c[0] + (x - c[0]) * 1.14, y, c[2] + (z - c[2]) * 1.12])
        if name == "Head":
            return np.array([x * 1.03, y, z])
        for s in ("Left", "Right"):
            if name.startswith(s) and any(k in name for k in ("UpperArm", "LowerArm", "Hand")):
                dx = np.array([self.arm_dx[s], 0, 0])
                if "UpperArm" in name:
                    q = self.seg(P[f"{s}UpperArm"], P[f"{s}LowerArm"], p, 1.12)
                elif "LowerArm" in name:
                    q = self.seg(P[f"{s}LowerArm"], P[f"{s}Hand"], p, 1.10)
                else:
                    q = self.seg(P[f"{s}Hand"], P[f"{s}Hand"] + (P[f"{s}Hand"] - P[f"{s}LowerArm"]) * 0.35, p, 1.06)
                return q + dx
            if name.startswith(s) and any(k in name for k in ("UpperLeg", "LowerLeg", "Foot", "Toes")):
                dx = np.array([self.leg_dx[s], 0, 0])
                if "UpperLeg" in name:
                    q = self.seg(P[f"{s}UpperLeg"], P[f"{s}LowerLeg"], p, 1.09)
                elif "LowerLeg" in name:
                    q = self.seg(P[f"{s}LowerLeg"], P[f"{s}Foot"], p, 1.07)
                else:
                    c = P[f"{s}Foot"]
                    q = np.array([c[0] + (x - c[0]) * 1.06, y, z])
                return q + dx
        return np.array(p, float)

    def apply(self, p, J, Wt, extra=None):
        out = np.zeros(3)
        for j, w in zip(J, Wt):
            if w > 0:
                out += w * self.bone(self.joints[j], p)
        s = Wt.sum()
        out = out / s if s > 0 else np.array(p, float)
        if extra:
            out = extra(out)
        return out

    def joint_targets(self):
        P = {k: v.copy() for k, v in self.P.items()}
        for s in ("Left", "Right"):
            for k in ("UpperArm", "LowerArm", "Hand"):
                P[f"{s}{k}"][0] += self.arm_dx[s]
            for k in ("UpperLeg", "LowerLeg", "Foot", "Toes"):
                P[f"{s}{k}"][0] += self.leg_dx[s]
            P[f"{s}Shoulder"][0] *= 1.10
        return P


def hood_to_collar(p):
    """fold the hood (behind / above the neck) down into a standing jacket collar"""
    x, y, z = p
    t = smooth((y - 1.36) / 0.06) * smooth((z - 0.03) / 0.05)
    if t <= 0:
        return p
    z2 = 0.05 + (z - 0.05) * 0.45
    y2 = 1.37 + (y - 1.37) * 0.72
    return np.array([x * (1 - 0.12 * t), y + (y2 - y) * t, z + (z2 - z) * t])


def hair_short(head_c):
    def f(p):
        x, y, z = p
        cut = 1.62
        if y < cut:
            y = cut - (cut - y) * 0.30                     # back / sides cropped
        d = np.array([x, y, z]) - head_c                   # hug the scalp, slight bulk so it clears the wider head
        return head_c + d * np.array([1.04, 0.985, 1.0])
    return f


def jaw_wider(p):
    x, y, z = p
    t = smooth((1.60 - y) / 0.10)
    return np.array([x * (1 + 0.06 * t), y, z])


# ====================================================================== textures (reference manner)
def hexc(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


def canvas(w, h, base):
    return np.tile(np.array(hexc(base), np.uint8), (h, w, 1))


def put(a, x, y, c):
    if 0 <= y < a.shape[0] and 0 <= x < a.shape[1]:
        a[y, x] = hexc(c)


def rect(a, x, y, w, h, c):
    a[max(0, y):y + h, max(0, x):x + w] = hexc(c)


def blob(a, cx, cy, r, c, rng):
    for j in range(-r, r + 1):
        for i in range(-r, r + 1):
            if i * i + j * j <= r * r + rng.integers(-r, r + 1):
                put(a, (cx + i) % a.shape[1], (cy + j) % a.shape[0], c)


def tex_jacket():
    """weathered brown canvas duck: vertical weave, faded wear patches, a few seam stitches (tiles)"""
    rng = np.random.default_rng(43)
    a = canvas(64, 64, "#76573a")
    for x in range(0, 64, 3):
        rect(a, x, 0, 1, 64, "#684b31")
    for _ in range(7):
        blob(a, rng.integers(0, 64), rng.integers(0, 64), int(rng.integers(3, 6)), "#866646", rng)
    for _ in range(2):
        blob(a, rng.integers(0, 64), rng.integers(0, 64), 2, "#5b412b", rng)
    for _ in range(4):
        x, y = int(rng.integers(4, 56)), int(rng.integers(4, 58))
        for k in range(0, 8, 2):
            put(a, x + k, y + (k // 3), "#a2855e")
    return a


def tex_cuff():
    a = canvas(32, 32, "#4e3828")
    for x in range(0, 32, 2):
        rect(a, x, 0, 1, 32, "#3e2b1f")
    for x in range(1, 32, 4):
        rect(a, x, 0, 1, 32, "#5c4430")
    return a


def tex_flannel():
    """red / charcoal flannel plaid"""
    a = canvas(64, 64, "#8a3b33")
    for k in range(0, 64, 16):
        rect(a, k, 0, 6, 64, "#5e2a29")
        rect(a, 0, k, 64, 6, "#5e2a29")
        rect(a, k + 10, 0, 1, 64, "#c7a27c")
        rect(a, 0, k + 10, 64, 1, "#c7a27c")
    for k in range(0, 64, 16):
        for j in range(0, 64, 16):
            rect(a, k, j, 6, 6, "#3b2326")
    for y in range(64):
        for x in range(64):
            if (x + y) % 4 == 0 and tuple(a[y, x]) == hexc("#8a3b33"):
                a[y, x] = hexc("#7d342f")
    rect(a, 31, 0, 2, 64, "#2c1d1d")          # placket
    for y in range(6, 64, 12):
        rect(a, 31, y, 2, 2, "#d8cbb4")       # buttons
    return a


def tex_pants():
    """olive drab work pants: twill diagonal, knee wear, seam"""
    rng = np.random.default_rng(7)
    a = canvas(64, 64, "#5d5a3c")
    for y in range(64):
        for x in range(64):
            if (x + y) % 4 == 0:
                a[y, x] = hexc("#524f35")
    for _ in range(4):
        blob(a, rng.integers(0, 64), rng.integers(0, 64), int(rng.integers(3, 6)), "#6b6846", rng)
    for _ in range(3):
        blob(a, rng.integers(0, 64), rng.integers(0, 64), 2, "#47442e", rng)
    return a


def tex_hem():
    a = canvas(32, 32, "#524f35")
    for y in range(0, 32, 6):
        rect(a, 0, y, 32, 1, "#45422d")
        rect(a, 0, y + 1, 32, 1, "#6b6846")
    return a


def tex_skin():
    a = canvas(32, 32, "#cf9b78")
    for y in range(5, 32, 8):
        for x in range(3, 32, 8):
            put(a, x, y, "#b88063")
    return a


def tex_sole():
    a = canvas(32, 32, "#2f2926")
    for y in range(4, 32, 6):
        rect(a, 0, y, 32, 1, "#3d3632")
    return a


def tex_pocket():
    """chest pocket flap: canvas, stitch line, snap button"""
    a = canvas(32, 16, "#6a4d33")
    rect(a, 0, 11, 32, 5, "#76573a")
    for x in range(2, 30, 2):
        put(a, x, 2, "#a2855e")
        put(a, x, 9, "#a2855e")
    rect(a, 15, 5, 3, 3, "#3b2b20")
    put(a, 16, 6, "#b9a37e")
    return a


def tex_hair():
    """short dark-brown hair going grey: vertical strand streaks, sparse salt-and-pepper"""
    rng = np.random.default_rng(3)
    a = canvas(64, 64, "#3b2d25")
    shades = ["#2e221c", "#463730", "#241a16"]
    for x in range(64):
        c = shades[int(rng.integers(0, 3))]
        y0, L = int(rng.integers(0, 64)), int(rng.integers(8, 30))
        for y in range(y0, y0 + L):
            put(a, x, y % 64, c)
    for _ in range(70):
        x, y = int(rng.integers(0, 64)), int(rng.integers(0, 64))
        put(a, x, y, "#7d746b")
        put(a, x, (y + 1) % 64, "#6a6159")
    return a


def tex_head(ref):
    """Marcus's face in the reference head layout (128x64): recoloured base, new features painted at the same anchors"""
    src = np.asarray(Image.open(io.BytesIO(ref)).convert("RGB")).copy()
    remap = {"#271210": "#241a16", "#371f19": "#352a24", "#c6856f": "#b98264", "#deac86": "#cf9b78", "#ad615b": "#9d6352", "#bf9881": "#a07a63"}
    out = src.copy()
    for k, v in remap.items():
        out[(src == hexc(k)).all(-1)] = hexc(v)
    SKIN, SHADE, LINE, DARK = "#cf9b78", "#b98264", "#9d6352", "#241a16"
    rect(out, 43, 18, 43, 33, SKIN)                     # clear the face, then paint Marcus
    rng = np.random.default_rng(11)
    for y in range(41, 59):                            # heavier stubble: the reference checker, on every row
        for x in range(38, 91):
            if (x + y) % 2 == 0:
                out[y, x] = hexc("#957058" if y < 52 else "#8a6551")
    for x in range(56, 73):                            # moustache
        if x % 2 == 0 or 59 <= x <= 69:
            put(out, x, 43, "#6e5040")
            put(out, x, 44, "#7d5c49")
    for x, y in ((51, 25), (52, 25), (53, 24), (54, 24), (55, 24), (56, 23), (57, 23), (58, 22), (59, 22), (60, 21)):   # worried brows
        put(out, x, y, DARK)
        put(out, x, y + 1, DARK)
        put(out, 129 - x, y, DARK)                     # mirrored right brow
        put(out, 129 - x, y + 1, DARK)
    for x in range(58, 71, 1):                         # forehead creases
        if x % 3:
            put(out, x, 18, SHADE)
            if x < 68:
                put(out, x + 1, 19, SHADE)
    put(out, 63, 22, LINE)
    put(out, 63, 23, LINE)
    put(out, 65, 22, LINE)
    put(out, 65, 23, LINE)
    for cx in (56, 72):                                # tired eyes: heavy lid line, whites, brown iris, two bag lines
        for x in range(cx - 4, cx + 5):
            put(out, x, 27, DARK)
        for x in range(cx - 3, cx + 4):
            put(out, x, 28, "#e6dccb")
            put(out, x, 29, "#d8ccb8")
        put(out, cx, 28, "#4a2e22")
        put(out, cx + 1, 28, "#4a2e22")
        put(out, cx, 29, "#2e1c16")
        put(out, cx + 1, 29, "#2e1c16")
        for x in range(cx - 3, cx + 4):
            put(out, x, 30, LINE)
        for x in range(cx - 3, cx + 3):
            put(out, x, 32, SHADE)
        for x in range(cx - 2, cx + 2):
            put(out, x, 33, SHADE)
    for y in range(29, 41):                            # broader nose
        put(out, 60, y, SHADE)
        put(out, 68, y, LINE)
    for x in range(61, 68):
        put(out, x, 40, SHADE)
    for x in (60, 61, 67, 68):
        put(out, x, 41, LINE)
    for k in range(6):                                 # nasolabial folds
        put(out, 58 - k // 2, 41 + k, LINE)
        put(out, 70 + k // 2, 41 + k, LINE)
    for x in range(59, 70):                            # mouth, corners turned down
        put(out, x, 46, "#7a4238")
    put(out, 58, 47, "#7a4238")
    put(out, 70, 47, "#7a4238")
    for x in range(61, 68):
        put(out, x, 47, "#b0705e")
    return out


def tex_boots(ref):
    """work boots in the reference shoe layout: leather upper, tan suede panels, laces, dark welt / sole"""
    src = np.asarray(Image.open(io.BytesIO(ref)).convert("RGB")).copy()
    remap = {"#be3a34": "#6e4a2e", "#e4e0d2": "#8a6a48", "#28282c": "#2a2420", "#a3212f": "#5a3a22", "#d4cdc2": "#2f2926",
             "#f4efe3": "#6e4a2e", "#c4bab2": "#c9b48a", "#3c3838": "#1f1a18", "#dc5046": "#3d3632"}
    out = src.copy()
    for k, v in remap.items():
        out[(src == hexc(k)).all(-1)] = hexc(v)
    for y in range(12, 22, 2):                          # laces over the tongue
        for x in range(14, 40, 4):
            put(out, x, y, "#c9b48a")
            put(out, x + 1, y, "#c9b48a")
    rng = np.random.default_rng(5)
    for _ in range(30):                                 # scuffs
        put(out, int(rng.integers(0, 42)), int(rng.integers(0, 54)), "#7d5a3a")
    return out


def png(a):
    b = io.BytesIO()
    Image.fromarray(a.astype(np.uint8), "RGB").save(b, format="PNG", optimize=True)
    return b.getvalue()


# ====================================================================== build
def main():
    g = GLB(REF)
    js = g.js
    G, parent = node_globals(js)
    D = Deformer(js, G)
    names = D.joints
    head_c = (D.P["Head"] + np.array([0, 0.11, 0.0]))
    report = {"source": "Commercial_NPCs/CHR_Eddie.glb (hand-made reference)", "removed_primitives": []}
    for m in js["meshes"]:
        keep = []
        for p in m["primitives"]:
            mat = js["materials"][p["material"]]["name"]
            mesh_name = next(n["name"] for n in js["nodes"] if n.get("mesh") == js["meshes"].index(m))
            if mesh_name == "Eddie_Body" and mat == "Eddie_Sole":          # hoodie drawstrings -> gone (jacket)
                report["removed_primitives"].append("Body/drawstrings")
                continue
            P = g.acc(p["attributes"]["POSITION"]).astype(np.float64)
            N = g.acc(p["attributes"]["NORMAL"]).astype(np.float64)
            J = g.acc(p["attributes"]["JOINTS_0"]).astype(int)
            Wt = g.acc(p["attributes"]["WEIGHTS_0"]).astype(np.float64)
            extra = None
            if mesh_name == "Eddie_Body" and mat in ("Eddie_Hoodie", "Eddie_HoodieRib"):
                extra = hood_to_collar
            elif mesh_name == "Eddie_Hair":
                extra = hair_short(head_c)
            elif mesh_name == "Eddie_Head":
                extra = jaw_wider
            NP, NN = np.zeros_like(P), np.zeros_like(N)
            e = 1e-3
            for i in range(len(P)):
                f = lambda q: D.apply(q, J[i], Wt[i], extra)  # noqa: E731
                NP[i] = f(P[i])
                Jm = np.stack([(f(P[i] + np.eye(3)[k] * e) - f(P[i] - np.eye(3)[k] * e)) / (2 * e) for k in range(3)], axis=1)
                n = np.linalg.solve(Jm.T, N[i]) if abs(np.linalg.det(Jm)) > 1e-9 else N[i]
                NN[i] = n / (np.linalg.norm(n) + 1e-12)
            g.data[p["attributes"]["POSITION"]] = NP.astype(np.float32)
            if mesh_name == "Eddie_Hair":                      # short hair rides on the head only (no neck stretch at the nape)
                hj = names.index("Head")
                g.data[p["attributes"]["JOINTS_0"]] = np.tile(np.array([hj, 0, 0, 0], g.acc(p["attributes"]["JOINTS_0"]).dtype), (len(P), 1))
                g.data[p["attributes"]["WEIGHTS_0"]] = np.tile(np.array([1, 0, 0, 0], np.float32), (len(P), 1))
            g.data[p["attributes"]["NORMAL"]] = NN.astype(np.float32)
            keep.append(p)
        m["primitives"] = keep
    # joints: new bind positions, uniform scale to Marcus's height, inverse bind matrices recomputed
    tgt = D.joint_targets()
    allp = np.concatenate([g.data[p["attributes"]["POSITION"]] for m in js["meshes"] for p in m["primitives"]])
    s = HEIGHT / float(allp[:, 1].max())
    for m in js["meshes"]:
        for p in m["primitives"]:
            g.data[p["attributes"]["POSITION"]] = (g.data[p["attributes"]["POSITION"]] * s).astype(np.float32)
    newG = {}
    for i, n in enumerate(js["nodes"]):
        M = G[i].copy()
        nm = n.get("name")
        if nm in tgt:
            M[:3, 3] = tgt[nm]
        newG[i] = M
    for i, n in enumerate(js["nodes"]):                 # sockets / helpers follow their parent joint
        nm = n.get("name", "")
        if nm not in tgt and i in parent and js["nodes"][parent[i]].get("name") in tgt:
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
    ibm = np.stack([np.linalg.inv(newG[j]).T.reshape(16) for j in sk["joints"]]).astype(np.float32)
    g.data[sk["inverseBindMatrices"]] = ibm
    # names + materials + textures
    for n in js["nodes"]:
        if n.get("name", "").startswith("Eddie_"):
            n["name"] = "Marcus_" + n["name"][6:]
    for m in js["meshes"]:
        if m.get("name", "").startswith("Eddie"):
            m["name"] = m["name"].replace("Eddie", "Marcus")
    sk["name"] = "Marcus_Rig"
    newtex = {"T_Eddie_Hoodie": ("T_Marcus_Jacket", tex_jacket()), "T_Eddie_HoodieRib": ("T_Marcus_JacketCuff", tex_cuff()),
              "T_Eddie_Shirt": ("T_Marcus_Flannel", tex_flannel()), "T_Eddie_Jeans": ("T_Marcus_WorkPants", tex_pants()),
              "T_Eddie_JeansCuff": ("T_Marcus_PantsHem", tex_hem()), "T_Eddie_Skin": ("T_Marcus_Skin", tex_skin()),
              "T_Eddie_Sole": ("T_Marcus_Sole", tex_sole()), "T_Eddie_Badge": ("T_Marcus_PocketFlap", tex_pocket()),
              "T_Eddie_Hair": ("T_Marcus_Hair", tex_hair())}
    images = []
    for i, img in enumerate(js["images"]):
        nm = img["name"]
        if nm == "T_Eddie_Head":
            a, new = tex_head(g.image(i)), "T_Marcus_Head"
        elif nm == "T_Eddie_Shoes":
            a, new = tex_boots(g.image(i)), "T_Marcus_Boots"
        else:
            new, a = newtex[nm]
        img["name"] = new
        images.append(png(a))
        report.setdefault("textures", {})[new] = [int(a.shape[1]), int(a.shape[0]), int(len(np.unique(a.reshape(-1, 3), axis=0)))]
    matmap = {"Hoodie": "Jacket", "HoodieRib": "JacketCuff", "Shirt": "Flannel", "Jeans": "WorkPants", "JeansCuff": "PantsHem",
              "Badge": "PocketFlap", "Shoes": "Boots"}
    for m in js["materials"]:
        base = m["name"].replace("Eddie_", "")
        m["name"] = "Marcus_" + matmap.get(base, base)
    js.setdefault("asset", {})["generator"] = "THE VEIL chr_style_from_eddie.py (from the hand-made Eddie reference)"
    js["asset"]["extras"] = {"veil_character": "Marcus", "title": "Marcus - Noah's father (43) - style rev 4", "height_m": HEIGHT}
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    g.write(OUT, images)
    sys.path.insert(0, os.path.join(V2, "02_Town", "Source_Scripts"))
    from veil_mesh.gltf import write_glb_import
    write_glb_import(OUT, [])
    # report
    g2 = GLB(OUT)
    tri = {}
    for n in g2.js["nodes"]:
        if "mesh" in n:
            tri[n["name"]] = int(sum(g2.js["accessors"][p["indices"]]["count"] // 3 for p in g2.js["meshes"][n["mesh"]]["primitives"]))
    P = np.concatenate([g2.acc(p["attributes"]["POSITION"]) for m in g2.js["meshes"] for p in m["primitives"]])
    report.update(triangles=sum(tri.values()), parts=tri, materials=sorted(m["name"] for m in g2.js["materials"]),
                  bones=[g2.js["nodes"][j]["name"] for j in g2.js["skins"][0]["joints"]], height_m=round(float(P[:, 1].max()), 3),
                  width_m=round(float(P[:, 0].max() - P[:, 0].min()), 3), glb=os.path.relpath(OUT, V2))
    json.dump(report, open(os.path.join(CHR, "Documentation", "MARCUS_V4_REPORT.json"), "w", newline="\n"), indent=1)
    print(json.dumps({k: report[k] for k in ("triangles", "parts", "height_m", "width_m", "removed_primitives")}))


if __name__ == "__main__":
    main()
