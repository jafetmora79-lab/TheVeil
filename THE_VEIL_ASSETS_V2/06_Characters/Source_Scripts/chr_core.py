"""THE VEIL - Pack 06 character core: shared humanoid skeleton, skinned mesh builder, GLB writer.

Conventions (all characters)
  * metres, +Y up, character faces +Z (glTF / Godot humanoid convention), origin between the feet
  * rest pose = relaxed A-pose (arms ~50 deg below horizontal); every bone rest rotation is identity
  * bone names follow Godot's SkeletonProfileHumanoid, so Godot's retargeting maps them automatically
  * one material + one 256x256 pixel-art atlas per character (embedded in the GLB for browsers and
    mapped to an external .tres for Godot)
  * up to 4 influences per vertex, weights normalised
"""
import json
import math
import struct

import numpy as np

# name: parent
BONES = [
    ("Root", None), ("Hips", "Root"), ("Spine", "Hips"), ("Chest", "Spine"), ("UpperChest", "Chest"),
    ("Neck", "UpperChest"), ("Head", "Neck"),
    ("LeftShoulder", "UpperChest"), ("LeftUpperArm", "LeftShoulder"), ("LeftLowerArm", "LeftUpperArm"), ("LeftHand", "LeftLowerArm"),
    ("RightShoulder", "UpperChest"), ("RightUpperArm", "RightShoulder"), ("RightLowerArm", "RightUpperArm"), ("RightHand", "RightLowerArm"),
    ("LeftUpperLeg", "Hips"), ("LeftLowerLeg", "LeftUpperLeg"), ("LeftFoot", "LeftLowerLeg"), ("LeftToes", "LeftFoot"),
    ("RightUpperLeg", "Hips"), ("RightLowerLeg", "RightUpperLeg"), ("RightFoot", "RightLowerLeg"), ("RightToes", "RightFoot"),
]
FP_BONES = [
    ("Root", None),
    ("LeftShoulder", "Root"), ("LeftUpperArm", "LeftShoulder"), ("LeftLowerArm", "LeftUpperArm"), ("LeftHand", "LeftLowerArm"),
    ("RightShoulder", "Root"), ("RightUpperArm", "RightShoulder"), ("RightLowerArm", "RightUpperArm"), ("RightHand", "RightLowerArm"),
]


def v3(*a):
    return np.array(a, float)


def nrm(v):
    n = np.linalg.norm(v)
    return v / n if n > 1e-12 else v


def frame(d):
    """Orthonormal (a, b, d) basis around direction d."""
    d = nrm(np.asarray(d, float))
    up = v3(0, 1, 0) if abs(d[1]) < 0.9 else v3(1, 0, 0)
    a = nrm(np.cross(up, d))
    b = np.cross(d, a)
    return a, b, d


class SkinMesh:
    """Triangles with per-vertex position, normal, uv and bone weights (dict bone->w)."""

    def __init__(self):
        self.P, self.N, self.UV, self.W, self.I = [], [], [], [], []

    def vert(self, p, n, uv, w):
        self.P.append(np.asarray(p, float))
        self.N.append(nrm(np.asarray(n, float)))
        self.UV.append((float(uv[0]), float(uv[1])))
        self.W.append(dict(w))
        return len(self.P) - 1

    def tri(self, a, b, c):
        self.I += [a, b, c]

    def tri_count(self):
        return len(self.I) // 3

    # --- flat-shaded quad / poly with its own uvs ----------------------------------
    def quad(self, pts, uvs, w, flip=False):
        pts = [np.asarray(p, float) for p in pts]
        n = nrm(np.cross(pts[1] - pts[0], pts[2] - pts[0]))
        if np.linalg.norm(n) < 1e-9:
            n = nrm(np.cross(pts[2] - pts[0], pts[3] - pts[0]))
        ws = w if isinstance(w, list) else [w] * 4
        ids = [self.vert(p, n, uv, ww) for p, uv, ww in zip(pts, uvs, ws)]
        self.tri(ids[0], ids[1], ids[2])
        self.tri(ids[0], ids[2], ids[3])

    def box(self, c, size, w, rect, M=None, skip=(), taper=(1.0, 1.0), bevel=0.0):
        """Oriented box. c centre, size (sx, sy, sz), M 3x3 basis (columns x, y, z). rect = atlas rect (u0,v0,u1,v1)
        each face maps onto. taper scales the top face (x, z). Faces wound outward (CCW)."""
        M = np.eye(3) if M is None else np.asarray(M, float)
        hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
        tx, tz = taper

        def P(x, y, z):
            s = (tx if y > 0 else 1.0, tz if y > 0 else 1.0)
            return np.asarray(c, float) + M @ v3(x * hx * s[0], y * hy, z * hz * s[1])
        u0, v0, u1, v1 = rect
        uv = [(u0, v1), (u1, v1), (u1, v0), (u0, v0)]
        faces = {
            "+z": [P(-1, -1, 1), P(1, -1, 1), P(1, 1, 1), P(-1, 1, 1)],
            "-z": [P(1, -1, -1), P(-1, -1, -1), P(-1, 1, -1), P(1, 1, -1)],
            "+x": [P(1, -1, 1), P(1, -1, -1), P(1, 1, -1), P(1, 1, 1)],
            "-x": [P(-1, -1, -1), P(-1, -1, 1), P(-1, 1, 1), P(-1, 1, -1)],
            "+y": [P(-1, 1, 1), P(1, 1, 1), P(1, 1, -1), P(-1, 1, -1)],
            "-y": [P(-1, -1, -1), P(1, -1, -1), P(1, -1, 1), P(-1, -1, 1)],
        }
        for k, pts in faces.items():
            if k in skip:
                continue
            self.quad(pts, uv, w)

    # --- smooth loft of rings ---------------------------------------------------------
    def loft(self, rings, weights, rect, u_wrap=True, cap_top=None, cap_bot=None, v_range=(0.0, 1.0), closed=True):
        """rings: list of arrays (n, 3) sharing segment count n (closed loops, CCW seen from the +axis end).
        weights: list (per ring) of either a dict or a list of n dicts. Smooth normals across the loft; a seam
        column is duplicated for the uv wrap. rect: (u0, v0, u1, v1) atlas rect; u runs around, v along rings.
        cap_*: (centre point, weight dict, uv) closes the end with a fan."""
        R = [np.asarray(r, float) for r in rings]
        n = len(R[0])
        m = len(R)
        u0, v0, u1, v1 = rect
        # normals: average of adjacent face normals (grid)
        Nn = np.zeros((m, n, 3))
        segs = n if closed else n - 1
        for i in range(m - 1):
            for j in range(segs):
                a, b = R[i][j], R[i][(j + 1) % n]
                c, d = R[i + 1][(j + 1) % n], R[i + 1][j]
                fn = np.cross(c - a, d - b)
                for (ii, jj) in ((i, j), (i, (j + 1) % n), (i + 1, (j + 1) % n), (i + 1, j)):
                    Nn[ii, jj] += fn
        # along-length v: cumulative ring-centre distance
        cen = [r.mean(0) for r in R]
        L = [0.0]
        for i in range(1, m):
            L.append(L[-1] + np.linalg.norm(cen[i] - cen[i - 1]) + 1e-6)
        L = np.array(L) / L[-1]
        vr0, vr1 = v_range
        cols = n + 1 if closed else n
        ids = np.zeros((m, cols), int)
        for i in range(m):
            wi = weights[i]
            for j in range(cols):
                jj = j % n
                w = wi[jj] if isinstance(wi, list) else wi
                u = u0 + (u1 - u0) * (j / (n if closed else n - 1))
                v = v1 - (v1 - v0) * (vr0 + (vr1 - vr0) * L[i])
                ids[i, j] = self.vert(R[i][jj], Nn[i, jj], (u, v), w)
        for i in range(m - 1):
            for j in range(segs):
                a, b, c, d = ids[i, j], ids[i, j + 1], ids[i + 1, j + 1], ids[i + 1, j]
                self.tri(a, b, c)
                self.tri(a, c, d)
        for cap, ring, top in ((cap_top, m - 1, True), (cap_bot, 0, False)):
            if cap is None:
                continue
            cp, cw, cuv = cap
            r = R[ring]
            fn = nrm(np.cross(r[1] - r[0], r[2] - r[0]))
            if not top:
                fn = -fn
            # direction check: cap normal points away from loft interior
            ctr = r.mean(0)
            other = R[ring - 1].mean(0) if top else R[1].mean(0)
            if np.dot(fn, ctr - other) < 0:
                fn = -fn
            ci = self.vert(cp, fn, cuv, cw)
            wr = weights[ring]
            rid = []
            for j in range(n):
                w = wr[j] if isinstance(wr, list) else wr
                rid.append(self.vert(r[j], fn, cuv, w))
            for j in range(n):
                a, b = rid[j], rid[(j + 1) % n]
                tri = (ci, a, b)
                pa, pb = self.P[a], self.P[b]
                if np.dot(np.cross(pa - cp, pb - cp), fn) < 0:
                    tri = (ci, b, a)
                self.tri(*tri)
        return L

    def finish(self, bone_index):
        """Arrays for GLB: positions, normals, uvs, joints (u16 x4), weights (f32 x4), indices."""
        P = np.array(self.P, np.float32)
        N = np.array(self.N, np.float32)
        UV = np.array(self.UV, np.float32)
        J = np.zeros((len(P), 4), np.uint16)
        Wt = np.zeros((len(P), 4), np.float32)
        for k, w in enumerate(self.W):
            items = sorted(((b, x) for b, x in w.items() if x > 1e-4), key=lambda t: -t[1])[:4]
            s = sum(x for _, x in items)
            for q, (b, x) in enumerate(items):
                J[k, q] = bone_index[b]
                Wt[k, q] = x / s
        # make the 4 weights sum to exactly 1 in float32
        Wt[:, 0] += 1.0 - Wt.sum(1)
        return P, N, UV, J, Wt, np.array(self.I, np.uint32)


def tube_frame(d, front=(0.0, 0.0, 1.0)):
    """Ring basis for a tube running along d: a = back direction (u = 0), b = a x ... with a x b = d,
    so u = 0.5 lands on the front (+Z) and lofted faces wind outward."""
    d = nrm(np.asarray(d, float))
    f = np.asarray(front, float)
    f = f - np.dot(f, d) * d
    if np.linalg.norm(f) < 1e-6:
        f = v3(0, 0, 1) - d[2] * d
    a = -nrm(f)
    b = np.cross(d, a)
    return a, b


def ring(center, a, b, rx, ry, n, phase=0.0, squash=None):
    """n-gon ring in the plane (a, b) around center; returns (n, 3). Ordered CCW about a x b."""
    out = []
    for k in range(n):
        t = phase + 2 * math.pi * k / n
        ca, sb = math.cos(t), math.sin(t)
        if squash:
            ca = math.copysign(abs(ca) ** squash, ca)
            sb = math.copysign(abs(sb) ** squash, sb)
        out.append(np.asarray(center) + a * rx * ca + b * ry * sb)
    return np.array(out)


def blend(*pairs):
    w = {}
    for b, x in pairs:
        w[b] = w.get(b, 0) + x
    return w


# ------------------------------------------------------------------ GLB
def _pad(b, ch=b"\x00"):
    return b + ch * ((4 - len(b) % 4) % 4)


def write_glb(path, name, bones, joints, mesh_arrays, png_bytes, material_name, extra_nodes=(), extras=None):
    """bones: [(name, parent)], joints: {name: world rest position}. extra_nodes: [(name, parent_bone, world_pos)]
    -> plain child nodes of joints (Godot: BoneAttachment3D) for sockets / eye markers."""
    P, N, UV, J, Wt, I = mesh_arrays
    binb = bytearray()
    views, accs = [], []

    def view(data, target=None):
        off = len(binb)
        binb.extend(_pad(bytes(data)))
        v = {"buffer": 0, "byteOffset": off, "byteLength": len(data)}
        if target:
            v["target"] = target
        views.append(v)
        return len(views) - 1

    def acc(arr, comp, typ, target=None, minmax=False):
        arr = np.ascontiguousarray(arr)
        a = {"bufferView": view(arr.tobytes(), target), "componentType": comp, "count": int(arr.shape[0]), "type": typ}
        if minmax:
            a["min"] = [float(x) for x in arr.min(0)]
            a["max"] = [float(x) for x in arr.max(0)]
        accs.append(a)
        return len(accs) - 1
    pos = acc(P, 5126, "VEC3", 34962, True)
    nor = acc(N, 5126, "VEC3", 34962)
    tex = acc(UV, 5126, "VEC2", 34962)
    jnt = acc(J, 5123, "VEC4", 34962)
    wgt = acc(Wt, 5126, "VEC4", 34962)
    ind = acc(I, 5125, "SCALAR", 34963)
    names = [b for b, _ in bones]
    bidx = {b: k for k, b in enumerate(names)}
    # nodes: 0 = scene root, 1..n = joints, then mesh, then extra nodes
    nodes = [{"name": name, "children": []}]
    jnode = {}
    for b, p in bones:
        jnode[b] = len(nodes)
        par_pos = joints[p] if p else v3(0, 0, 0)
        nodes.append({"name": b, "translation": [float(x) for x in (joints[b] - par_pos)]})
    for b, p in bones:
        if p:
            nodes[jnode[p]].setdefault("children", []).append(jnode[b])
        else:
            nodes[0]["children"].append(jnode[b])
    for (en, pb, wp) in extra_nodes:
        nodes.append({"name": en, "translation": [float(x) for x in (np.asarray(wp) - joints[pb])]})
        nodes[jnode[pb]].setdefault("children", []).append(len(nodes) - 1)
    ibm = np.zeros((len(bones), 16), np.float32)
    for k, (b, _) in enumerate(bones):
        M = np.eye(4)
        M[:3, 3] = -joints[b]
        ibm[k] = M.T.reshape(-1)          # column-major
    ibm_acc = acc(ibm, 5126, "MAT4")
    img_view = view(png_bytes)
    mesh_node = len(nodes)
    nodes.append({"name": name + "_Mesh", "mesh": 0, "skin": 0})
    # skinned mesh at the scene root (glTF best practice: its own transform is ignored by skinning)
    if extras:
        nodes[0]["extras"] = extras
    j = {
        "asset": {"version": "2.0", "generator": "THE VEIL chr_core (Pack 06)"},
        "scene": 0, "scenes": [{"nodes": [0, mesh_node]}], "nodes": nodes,
        "meshes": [{"name": name + "_Mesh", "primitives": [{"attributes": {"POSITION": pos, "NORMAL": nor, "TEXCOORD_0": tex,
                                                                           "JOINTS_0": jnt, "WEIGHTS_0": wgt},
                                                            "indices": ind, "material": 0, "mode": 4}]}],
        "skins": [{"name": name + "_Skin", "joints": [jnode[b] for b in names], "skeleton": jnode[names[0]],
                   "inverseBindMatrices": ibm_acc}],
        "materials": [{"name": material_name, "pbrMetallicRoughness": {"baseColorTexture": {"index": 0}, "metallicFactor": 0.0,
                                                                        "roughnessFactor": 1.0}}],
        "textures": [{"sampler": 0, "source": 0}],
        "samplers": [{"magFilter": 9728, "minFilter": 9984, "wrapS": 33071, "wrapT": 33071}],
        "images": [{"name": material_name.replace("M_", "T_"), "bufferView": img_view, "mimeType": "image/png"}],
        "accessors": accs, "bufferViews": views, "buffers": [{"byteLength": len(binb)}],
    }
    js = _pad(json.dumps(j, separators=(",", ":")).encode(), b" ")
    out = struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(binb))
    out += struct.pack("<II", len(js), 0x4E4F534A) + js + struct.pack("<II", len(binb), 0x004E4942) + bytes(binb)
    with open(path, "wb") as f:
        f.write(out)
    return bidx


def lbs(P, J, Wt, bones, joints, rots):
    """Linear blend skinning test helper. rots: {bone: 3x3 local rotation}. Returns deformed positions."""
    names = [b for b, _ in bones]
    parent = dict(bones)
    G = {}
    for b in names:
        p = parent[b]
        R = rots.get(b, np.eye(3))
        L = np.eye(4)
        L[:3, :3] = R
        L[:3, 3] = joints[b] - (joints[p] if p else 0)
        G[b] = (G[p] @ L) if p else L
    S = []
    for b in names:
        IB = np.eye(4)
        IB[:3, 3] = -joints[b]
        S.append(G[b] @ IB)
    S = np.array(S)
    Ph = np.c_[P, np.ones(len(P))]
    out = np.zeros((len(P), 3))
    for q in range(4):
        M = S[J[:, q]]
        out += Wt[:, q:q + 1] * np.einsum("nij,nj->ni", M, Ph)[:, :3]
    return out


def rot(axis, deg):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    x, y, z = nrm(np.asarray(axis, float))
    return np.array([[c + x * x * (1 - c), x * y * (1 - c) - z * s, x * z * (1 - c) + y * s],
                     [y * x * (1 - c) + z * s, c + y * y * (1 - c), y * z * (1 - c) - x * s],
                     [z * x * (1 - c) - y * s, z * y * (1 - c) + x * s, c + z * z * (1 - c)]])
