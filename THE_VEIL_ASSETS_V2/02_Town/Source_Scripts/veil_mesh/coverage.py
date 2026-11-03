"""Top-down surface coverage test: every point of a module footprint must be
covered by exactly one walkable surface (0 = hole, >1 = overlapping faces).
Paint markings, decals and props are layered on purpose and excluded."""
import numpy as np

LAYERED = ("Marking", "Puddle", "RoadPatch", "DrainGrate", "ManholeCover", "UtilityCover")


def coverage(mb, footprint, step=0.05, inset=0.03, exclude=LAYERED, max_y=0.2):
    # samples are offset by an irrational amount so they never sit exactly on
    # a shared triangle edge (which would double-count)
    x0, z0, x1, z1 = footprint
    xs = np.arange(x0 + inset + 0.00731, x1 - inset, step)
    zs = np.arange(z0 + inset + 0.01173, z1 - inset, step)
    X, Z = np.meshgrid(xs, zs)
    cnt = np.zeros(X.shape, int)
    for mat, g in mb.parts.items():
        if any(e in mat for e in exclude):
            continue
        P = np.asarray(g["p"])
        N = np.asarray(g["n"])
        I = np.asarray(g["i"]).reshape(-1, 3)
        for t in I:
            a, b, c = P[t]
            n = np.cross(b - a, c - a)
            if abs(n[1]) < 0.2 * (np.linalg.norm(n) + 1e-12):  # vertical faces (curb faces) don't cover
                continue
            if n[1] < 0:          # downward faces (box bottoms) are not walkable surfaces
                continue
            if max(a[1], b[1], c[1]) > max_y:   # raised props (wheel stops) sit on top of the ground
                continue
            mnx, mxx = min(a[0], b[0], c[0]), max(a[0], b[0], c[0])
            mnz, mxz = min(a[2], b[2], c[2]), max(a[2], b[2], c[2])
            sel = (X >= mnx - 1e-9) & (X <= mxx + 1e-9) & (Z >= mnz - 1e-9) & (Z <= mxz + 1e-9)
            if not sel.any():
                continue
            px, pz = X[sel], Z[sel]
            d = (b[2] - c[2]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[2] - c[2])
            if abs(d) < 1e-12:
                continue
            l1 = ((b[2] - c[2]) * (px - c[0]) + (c[0] - b[0]) * (pz - c[2])) / d
            l2 = ((c[2] - a[2]) * (px - c[0]) + (a[0] - c[0]) * (pz - c[2])) / d
            l3 = 1 - l1 - l2
            inside = (l1 >= -1e-9) & (l2 >= -1e-9) & (l3 >= -1e-9)
            sub = cnt[sel]
            sub += inside
            cnt[sel] = sub
    holes = int((cnt == 0).sum())
    over = int((cnt > 1).sum())
    return holes, over, cnt.size, (X, Z, cnt)
