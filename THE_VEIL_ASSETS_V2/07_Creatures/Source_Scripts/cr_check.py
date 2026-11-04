"""THE VEIL - Pack 07 animation / skinning checks (pure numpy, run on the baked frames).

For every clip frame the skinned mesh is deformed with linear blend skinning and checked for:
  * ground penetration (lowest vertex),
  * planted feet (contact points of the listed feet stay on their target, within tolerance),
  * stretching: 1 + (deformed - rest edge length) / max(rest length, edge_floor); limbs that tear away from the
    body show up here, while sub-centimetre edges at hidden roots / tips cannot dominate the ratio,
  * loop continuity (first and last frame identical for looping clips).
"""
import numpy as np

import cr_core as C


def mesh_arrays(meshes, rig):
    bi = rig.index()
    Ps, Js, Ws, Is, off = [], [], [], [], 0
    for m, sm in meshes.items():
        if not sm.tri_count():
            continue
        P, N, UV, J, Wt, I = sm.finish(bi)
        Ps.append(P)
        Js.append(J)
        Ws.append(Wt)
        Is.append(I.reshape(-1, 3) + off)
        off += len(P)
    return np.vstack(Ps).astype(float), np.vstack(Js).astype(int), np.vstack(Ws).astype(float), np.vstack(Is)


def edges(I):
    E = np.vstack([I[:, [0, 1]], I[:, [1, 2]], I[:, [2, 0]]])
    E.sort(1)
    return np.unique(E, axis=0)


def foot_contacts(rig, local, trans, feet):
    Rw, Pw = rig.fk(local, trans)
    return {f: Pw[f] + Rw[f] @ (rig.tips[f] - rig.J[f]) for f in feet}


def check_clip(rig, arrays, frames, every=1, edge_floor=0.05):
    P, Jt, Wt, I = arrays
    E = edges(I)
    L0 = np.linalg.norm(P[E[:, 0]] - P[E[:, 1]], axis=1)
    keep = L0 > 1e-4
    E, L0 = E[keep], L0[keep]
    D0 = np.maximum(L0, edge_floor)          # tiny edges (hidden roots, tips) measured against a floor length
    out = {"min_y": 1e9, "max_stretch": 0.0, "p999_stretch": 0.0, "min_squash": 1e9}
    for k in range(0, len(frames), every):
        local, trans = frames[k]
        D = rig.deform(P, Jt, Wt, local, trans)
        out["min_y"] = min(out["min_y"], float(D[:, 1].min()))
        L = np.linalg.norm(D[E[:, 0]] - D[E[:, 1]], axis=1)
        r = (L - L0) / D0 + 1.0
        out["max_stretch"] = max(out["max_stretch"], float(r.max()))
        out["p999_stretch"] = max(out["p999_stretch"], float(np.percentile(r, 99.9)))
        out["min_squash"] = min(out["min_squash"], float(np.percentile(r, 0.1)))
    return out


def loop_ok(clip):
    for b, Q in clip.rots.items():
        if abs(abs(float(np.dot(Q[0], Q[-1]))) - 1.0) > 1e-5:
            return False
    for b, T in clip.trans.items():
        if np.abs(T[0] - T[-1]).max() > 1e-5:
            return False
    return True


def feet_report(rig, frames, feet, rest_contacts=None, planted_only=True, tol_y=0.03):
    """Max contact height of the lowest foot per frame, plus max slip of feet that stay on the ground between
    consecutive frames (in-place locomotion slides feet backwards on purpose, so slip is only meaningful for
    standing clips)."""
    worst_low, max_float, slip = 0.0, 0.0, 0.0
    prev = None
    for local, trans in frames:
        fc = foot_contacts(rig, local, trans, feet)
        ys = [p[1] for p in fc.values()]
        worst_low = min(worst_low, min(ys))
        max_float = max(max_float, min(ys))
        if prev is not None:
            for f, p in fc.items():
                if p[1] < tol_y and prev[f][1] < tol_y:
                    slip = max(slip, float(np.linalg.norm(p - prev[f])))
        prev = fc
    return {"lowest_contact_y": worst_low, "highest_lowest_foot_y": max_float, "planted_slip": slip}
