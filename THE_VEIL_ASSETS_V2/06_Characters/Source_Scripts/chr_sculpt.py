"""Pack 06 rev 3 - sculpted character pipeline (replaces the primitive-assembly body builder).

A character is designed like clay: a skeleton plus a list of organic volumes (rounded cones, rotated ellipsoids,
rounded boxes, carved/cut regions) that are smoothly blended into ONE continuous surface - head, cheeks, jaw,
nose, neck, shoulders, arms, hands, torso, pelvis, legs, clothes, shoes and hair flow into each other with real
transitions (smooth union radius per volume). Clothing is volume on top of the body, so only the outer surface
exists (no hidden interior geometry).

Pipeline
  volumes -> signed distance field (6 mm voxels, evaluated per volume in its bounding box)
          -> surface extraction (marching cubes) -> quadric decimation to a low-poly budget
          -> part labels (which volume each surface point belongs to: skin / hoodie / jeans / hair ...)
          -> skin weights (inverse-distance to the bones a volume is allowed to follow, mesh-smoothed)
          -> charts + UVs (face: front projection, garments/limbs: cylinders around body/limb axes)
          -> pixel-art atlas painted per chart (chr_sculpt_tex) -> GLB (chr_core.write_glb)
Small hard-edged accessories (glasses frames, eyebrow strips) are explicit low-poly meshes merged in.
"""
import math

import numpy as np

from chr_core import BONES, nrm, v3

VOX = 0.006


# ------------------------------------------------------------------ signed distance primitives (vectorised)
def rotm(yaw=0.0, pitch=0.0, roll=0.0):
    """local->world rotation: yaw about Y, pitch about X, roll about Z (degrees)"""
    a, b, c = (math.radians(x) for x in (yaw, pitch, roll))
    Ry = np.array([[math.cos(a), 0, math.sin(a)], [0, 1, 0], [-math.sin(a), 0, math.cos(a)]])
    Rx = np.array([[1, 0, 0], [0, math.cos(b), -math.sin(b)], [0, math.sin(b), math.cos(b)]])
    Rz = np.array([[math.cos(c), -math.sin(c), 0], [math.sin(c), math.cos(c), 0], [0, 0, 1]])
    return Ry @ Rx @ Rz


def sd_ellipsoid(p, c, r, R=None):
    q = p - c
    if R is not None:
        q = q @ R          # world -> local (R columns = local axes)
    r = np.asarray(r, float)
    k0 = np.linalg.norm(q / r, axis=-1)
    k1 = np.linalg.norm(q / (r * r), axis=-1)
    return k0 * (k0 - 1.0) / np.maximum(k1, 1e-9)


def sd_round_cone(p, a, b, r1, r2):
    a, b = np.asarray(a, float), np.asarray(b, float)
    ba = b - a
    l2 = ba @ ba
    rr = r1 - r2
    a2 = l2 - rr * rr
    il2 = 1.0 / l2
    pa = p - a
    y = pa @ ba
    z = y - l2
    xv = pa * l2 - y[..., None] * ba
    x2 = np.einsum("...i,...i->...", xv, xv)
    y2 = y * y * l2
    z2 = z * z * l2
    k = np.sign(rr) * rr * rr * x2
    d = (np.sqrt(np.maximum(x2 * a2 * il2, 0)) + y * rr) * il2 - r1
    c1 = np.sign(z) * a2 * z2 > k
    c2 = np.sign(y) * a2 * y2 < k
    d = np.where(c2, np.sqrt(x2 + y2) * il2 - r1, d)
    d = np.where(c1, np.sqrt(x2 + z2) * il2 - r2, d)
    return d


def sd_rbox(p, c, half, R=None, rr=0.01):
    q = p - c
    if R is not None:
        q = q @ R
    q = np.abs(q) - (np.asarray(half, float) - rr)
    return np.linalg.norm(np.maximum(q, 0), axis=-1) + np.minimum(q.max(-1), 0) - rr


def smin(a, b, k):
    if k <= 0:
        return np.minimum(a, b)
    h = np.maximum(k - np.abs(a - b), 0) / k
    return np.minimum(a, b) - h * h * k * 0.25


def smax(a, b, k):
    return -smin(-a, -b, k)


class Vol:
    """One sculpt volume. kind: 'ell' (c, r, R), 'cone' (a, b, r1, r2), 'box' (c, half, R, rr).
    label: material/part; group: which bones may influence it; k: blend radius with what came before;
    op: 'add' | 'sub' (carve) | 'cut' (intersect this volume's own shape with a half-space: plane=(n, d))."""

    def __init__(self, kind, label, group, k=0.02, op="add", bias=0.0, cut=None, only=None, **geo):
        self.kind, self.label, self.group, self.k, self.op, self.bias, self.cut, self.only = kind, label, group, k, op, bias, cut, only
        self.geo = geo

    def sdf(self, p):
        g = self.geo
        if self.kind == "ell":
            d = sd_ellipsoid(p, np.asarray(g["c"], float), g["r"], g.get("R"))
        elif self.kind == "cone":
            d = sd_round_cone(p, g["a"], g["b"], g["r1"], g["r2"])
        else:
            d = sd_rbox(p, np.asarray(g["c"], float), g["half"], g.get("R"), g.get("rr", 0.01))
        if self.cut is not None:      # keep the side where n.p > d  (e.g. a hairline)
            n, off = self.cut
            n = np.asarray(n, float)
            d = smax(d, -(p @ n - off) / np.linalg.norm(n), 0.006)
        return d

    def bbox(self):
        g = self.geo
        if self.kind == "ell":
            r = max(g["r"])
            c = np.asarray(g["c"], float)
            return c - r, c + r
        if self.kind == "cone":
            a, b = np.asarray(g["a"], float), np.asarray(g["b"], float)
            r = max(g["r1"], g["r2"])
            return np.minimum(a, b) - r, np.maximum(a, b) + r
        c = np.asarray(g["c"], float)
        r = np.linalg.norm(g["half"])
        return c - r, c + r


# ------------------------------------------------------------------ field -> mesh
def build_field(vols, vox=VOX):
    lo = np.min([v.bbox()[0] for v in vols if v.op == "add"], axis=0) - 0.04
    hi = np.max([v.bbox()[1] for v in vols if v.op == "add"], axis=0) + 0.04
    n = np.ceil((hi - lo) / vox).astype(int) + 1
    F = np.full(n, 1.0, np.float32)
    lab = np.full(n, -1, np.int16)
    best = np.full(n, 1e9, np.float32)
    for i, v in enumerate(vols):
        b0, b1 = v.bbox()
        pad = v.k + 0.02
        i0 = np.clip(np.floor((b0 - pad - lo) / vox).astype(int), 0, n - 1)
        i1 = np.clip(np.ceil((b1 + pad - lo) / vox).astype(int) + 1, 1, n)
        sl = tuple(slice(a, b) for a, b in zip(i0, i1))
        axes = [lo[k] + vox * np.arange(i0[k], i1[k]) for k in range(3)]
        X, Y, Z = np.meshgrid(*axes, indexing="ij")
        p = np.stack([X, Y, Z], -1)
        d = v.sdf(p).astype(np.float32)
        if v.op == "add":
            F[sl] = smin(F[sl], d, v.k)
            score = np.abs(d) - v.bias
            m = score < best[sl]
            if v.only is not None:      # label only where this volume is the actual outer surface region
                m &= d < v.only
            best[sl] = np.where(m, score, best[sl])
            lab[sl] = np.where(m, i, lab[sl])
        elif v.op == "sub":
            F[sl] = smax(F[sl], -d, v.k)
    return F, lab, lo, vox


def extract(F, lo, vox, target, regions=()):
    from skimage.measure import marching_cubes, label as cc_label
    import pyfqmr
    # keep only the main connected solid (drop specks)
    solid = F < 0
    L, nl = cc_label(solid, return_num=True, connectivity=1)
    if nl > 1:
        sizes = np.bincount(L.ravel())
        sizes[0] = 0
        keep = sizes.argmax()
        F = np.where((L == keep) | ~solid, F, np.abs(F) + vox)
    verts, faces, _, _ = marching_cubes(F, 0.0, spacing=(vox, vox, vox), allow_degenerate=False)
    verts = verts + lo
    faces = faces[:, ::-1].copy()          # outward winding
    # regional budgets: the face and hands get denser triangles than the clothes. Each region is simplified on
    # its own with its border frozen, then the pieces are welded back together (no cracks).
    cen = verts[faces].mean(1)
    owner = np.full(len(faces), -1)
    for k, (fn, _) in enumerate(regions):
        owner = np.where((owner < 0) & fn(cen), k, owner)
    pieces = [(owner == k, t) for k, (_, t) in enumerate(regions)] + [(owner < 0, target)]
    Vs, Fs, off = [], [], 0
    for mask, tgt in pieces:
        if not mask.any():
            continue
        sub = faces[mask]
        used, inv = np.unique(sub, return_inverse=True)
        s = pyfqmr.Simplify()
        s.setMesh(verts[used].astype(np.float64), inv.reshape(-1, 3).astype(np.int32))
        s.simplify_mesh(target_count=int(tgt), aggressiveness=6, preserve_border=True, verbose=False)
        v, f, _ = s.getMesh()
        Vs.append(np.asarray(v, float))
        Fs.append(np.asarray(f, np.int64) + off)
        off += len(v)
    V = np.vstack(Vs)
    Fc = np.vstack(Fs)
    # weld identical border vertices
    key = np.round(V / 1e-6).astype(np.int64)
    _, first, inv = np.unique(key, axis=0, return_index=True, return_inverse=True)
    V = V[first]
    Fc = inv.reshape(-1)[Fc]
    Fc = Fc[(Fc[:, 0] != Fc[:, 1]) & (Fc[:, 1] != Fc[:, 2]) & (Fc[:, 0] != Fc[:, 2])]
    return cleanup(V, Fc)


def cleanup(V, Fc, tol=0.0018, passes=4):
    """collapse sliver edges (< tol) left by surface extraction / welding; drop degenerate faces and unused verts"""
    for _ in range(passes):
        E = np.concatenate([Fc[:, [0, 1]], Fc[:, [1, 2]], Fc[:, [2, 0]]])
        L = np.linalg.norm(V[E[:, 0]] - V[E[:, 1]], axis=1)
        short = E[L < tol]
        if not len(short):
            break
        parent = np.arange(len(V))

        def find(i):
            while parent[i] != i:
                parent[i] = parent[parent[i]]
                i = parent[i]
            return i
        taken = np.zeros(len(V), bool)
        for a, b in short:
            if taken[a] or taken[b]:
                continue
            ra, rb = find(a), find(b)
            if ra != rb:
                parent[rb] = ra
                V[ra] = (V[ra] + V[rb]) / 2
                taken[a] = taken[b] = True
        root = np.array([find(i) for i in range(len(V))])
        Fc = root[Fc]
        Fc = Fc[(Fc[:, 0] != Fc[:, 1]) & (Fc[:, 1] != Fc[:, 2]) & (Fc[:, 0] != Fc[:, 2])]
    # drop zero-area faces, duplicate faces and unused vertices
    a, b, c = V[Fc[:, 0]], V[Fc[:, 1]], V[Fc[:, 2]]
    Fc = Fc[np.linalg.norm(np.cross(b - a, c - a), axis=1) > 1e-9]
    Fc = np.unique(Fc, axis=0)
    used, inv = np.unique(Fc, return_inverse=True)
    return V[used], inv.reshape(-1, 3)


def sample_grid(G, lo, vox, P):
    idx = np.clip(np.round((P - lo) / vox).astype(int), 0, np.array(G.shape) - 1)
    return G[idx[:, 0], idx[:, 1], idx[:, 2]]


def label_vertices(vols, lab, lo, vox, P, Nrm):
    """volume index per vertex: sample the label grid slightly inside the surface (robust at blends)"""
    a = sample_grid(lab, lo, vox, P - Nrm * vox * 0.8)
    b = sample_grid(lab, lo, vox, P)
    return np.where(a >= 0, a, b)


def vertex_normals(P, I):
    N = np.zeros_like(P)
    T = I.reshape(-1, 3)
    fn = np.cross(P[T[:, 1]] - P[T[:, 0]], P[T[:, 2]] - P[T[:, 0]])
    for k in range(3):
        np.add.at(N, T[:, k], fn)
    ln = np.linalg.norm(N, axis=1, keepdims=True)
    N = np.where(ln > 1e-12, N / np.maximum(ln, 1e-12), np.array([0.0, 1.0, 0.0]))
    return N


# ------------------------------------------------------------------ skinning
def bone_segments(J, ends):
    """segment per bone: from its joint to its child joint (or an explicit end point)."""
    child = {}
    for b, p in BONES:
        if p and p not in child:
            child[p] = b
    seg = {}
    for b, _ in BONES:
        a = J[b]
        if b in ends:
            e = ends[b]
        elif b in ("LeftShoulder", "RightShoulder"):
            e = J[b.replace("Shoulder", "UpperArm")]
        elif b == "Hips":
            e = J["Spine"]
        elif b == "Root":
            e = J["Hips"]
        elif b in child:
            e = J[child[b]]
        else:
            e = a + v3(0, 0.05, 0)
        seg[b] = (a, e)
    return seg


GROUPS = {
    "head": ["Head", "Neck"], "neck": ["Neck", "Head", "UpperChest"],
    # torso clothing follows the trunk only (never a thigh or upper arm); trousers (pelvis) follow the thighs
    "torso": ["Hips", "Spine", "Chest", "UpperChest", "Neck", "LeftShoulder", "RightShoulder"],
    "upper": ["Chest", "UpperChest", "Neck", "LeftShoulder", "RightShoulder", "Spine"],
    "pelvis": ["Hips", "Spine", "LeftUpperLeg", "RightUpperLeg"],
}
for S in ("Left", "Right"):
    GROUPS["arm_" + S] = [S + "Shoulder", S + "UpperArm", S + "LowerArm", S + "Hand", "UpperChest"]
    GROUPS["hand_" + S] = [S + "Hand", S + "LowerArm"]
    GROUPS["leg_" + S] = [S + "UpperLeg", S + "LowerLeg", S + "Foot", "Hips"]
    GROUPS["foot_" + S] = [S + "Foot", S + "Toes", S + "LowerLeg"]


def seg_dist(P, a, b):
    ab = b - a
    t = np.clip(((P - a) @ ab) / max(ab @ ab, 1e-12), 0, 1)
    return np.linalg.norm(P - (a + t[:, None] * ab), axis=1)


def skin_weights(P, I, groups, J, ends, heat=2.0, sigma=0.0, mask_after=False):
    """Bone-heat skinning (the method behind Blender's automatic weights): each vertex is attached to its nearest
    allowed bone with strength 1/d^2 and the weights diffuse over the mesh by solving (L + H) w = H p per bone,
    which gives smooth, artefact-free transitions. Groups restrict which bones a surface may be attached to."""
    import scipy.sparse as sp
    from scipy.sparse.linalg import splu
    names = [b for b, _ in BONES]
    seg = bone_segments(J, ends)
    D = np.stack([seg_dist(P, *seg[b]) for b in names], 1)
    allow = np.zeros_like(D, bool)
    for gname in set(groups):
        rows = np.array([g == gname for g in groups])
        cols = [names.index(b) for b in GROUPS[gname]]
        allow[np.ix_(rows, cols)] = True
    allow[:, names.index("Root")] = False
    Dm = np.where(allow, D, 1e9)
    dmin = Dm.min(1)
    near = Dm <= dmin[:, None] * 1.0001 + 1e-9
    n = len(P)
    T = I.reshape(-1, 3)
    rows = np.concatenate([T[:, 0], T[:, 1], T[:, 2], T[:, 1], T[:, 2], T[:, 0]])
    cols = np.concatenate([T[:, 1], T[:, 2], T[:, 0], T[:, 0], T[:, 1], T[:, 2]])
    A = sp.coo_matrix((np.ones(len(rows)), (rows, cols)), shape=(n, n)).tocsr()
    A.data[:] = 1.0
    deg = np.asarray(A.sum(1)).ravel()
    # scale the Laplacian by mean edge length^2 so it is comparable with 1/d^2
    E = np.concatenate([T[:, [0, 1]], T[:, [1, 2]]])
    el2 = float(np.mean(np.sum((P[E[:, 0]] - P[E[:, 1]]) ** 2, axis=1)))
    Lap = (sp.diags(deg) - A) / el2
    h = heat / np.maximum(dmin, 0.01) ** 2
    M = (Lap + sp.diags(h)).tocsc()
    lu = splu(M)
    Wt = np.zeros((n, len(names)))
    for j in range(len(names)):
        pj = near[:, j].astype(float)
        if not pj.any():
            continue
        Wt[:, j] = lu.solve(h * pj)
    Wt = np.clip(Wt, 0, None)
    if mask_after:
        Wt = np.where(allow, Wt, 0)
    # smooth range limit: a bone's influence fades out between dmin+near and dmin+far from it (kills leakage
    # through fused armpits / hems without creating hard edges)
    near_r, far_r = 0.035, 0.14
    fade = np.clip((dmin[:, None] + far_r - D) / (far_r - near_r), 0.0, 1.0)
    fade = fade * fade * (3 - 2 * fade)
    Wt = Wt * fade
    Wt /= np.maximum(Wt.sum(1, keepdims=True), 1e-12)
    order = np.argsort(-Wt, axis=1)[:, :4]
    Jt = order.astype(np.uint16)
    Wv = np.take_along_axis(Wt, order, 1)
    Wv = np.where(Wv < 0.01, 0, Wv)
    Wv = (Wv / Wv.sum(1, keepdims=True)).astype(np.float32)
    Wv[:, 0] += 1.0 - Wv.sum(1)
    return Jt, Wv
