"""THE VEIL - Pack 07 organic geometry on top of chr_core.SkinMesh.

sweep()   one smooth lofted tube along a path (parallel-transported ring frames, so long tentacles never twist),
          with per-ring radii, a per-angle profile function for ridges / lumps / flattened bellies and a tapered
          tip. Weights come from a callable so a vertex can blend between bones by position or by length.
chain_w() weights along a bone chain by arc length (rigid mid-segment, smooth blend across each joint).
orb()     low-poly ellipsoid (eyes, sensory nodes, cores).
plate()   bevelled armour plate (tapered oriented box) - overlapping plates read as chitin / shell / growths.
"""
import math

import numpy as np

from cr_core import SkinMesh, nrm, tube_frame  # noqa: F401


def resample(pts, n):
    """Catmull-Rom through pts, n evenly spaced (by parameter) samples."""
    P = [np.asarray(p, float) for p in pts]
    P = [2 * P[0] - P[1]] + P + [2 * P[-1] - P[-2]]
    segs = len(P) - 3
    out = []
    for k in range(n):
        u = k / (n - 1) * segs
        i = min(int(u), segs - 1)
        t = u - i
        p0, p1, p2, p3 = P[i], P[i + 1], P[i + 2], P[i + 3]
        out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t +
                          (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3))
    return np.array(out)


def round_corners(pts, d, min_turn_deg=25.0):
    """Replace each sharp interior point by two points d before / after it along its segments (clamped to 40 % of
    each segment), so a swept tube turns with a radius larger than its own and the inner crease never folds."""
    P = [np.asarray(p, float) for p in pts]
    out = [P[0]]
    for i in range(1, len(P) - 1):
        a, b = P[i] - P[i - 1], P[i + 1] - P[i]
        la, lb = np.linalg.norm(a), np.linalg.norm(b)
        turn = math.degrees(math.acos(max(-1.0, min(1.0, float(np.dot(a, b) / max(la * lb, 1e-12))))))
        dd = d[i] if isinstance(d, (list, tuple)) else d
        if turn < min_turn_deg or dd <= 0:
            out.append(P[i])
            continue
        out.append(P[i] - a / la * min(dd, 0.4 * la))
        out.append(P[i] + b / lb * min(dd, 0.4 * lb))
    out.append(P[-1])
    return out


def arclen(C):
    d = np.r_[0.0, np.cumsum(np.linalg.norm(np.diff(C, axis=0), axis=1))]
    return d / max(d[-1], 1e-9), d[-1]


def frames(C, front=(0.0, 0.0, 1.0)):
    """Parallel-transported (a, b) ring bases along C with a x b = tangent."""
    n = len(C)
    T = []
    for i in range(n):
        d = C[min(i + 1, n - 1)] - C[max(i - 1, 0)]
        T.append(nrm(d))
    a, b = tube_frame(T[0], front)
    A, B = [a], [b]
    for i in range(1, n):
        t0, t1 = T[i - 1], T[i]
        ax = np.cross(t0, t1)
        s = np.linalg.norm(ax)
        a = A[-1]
        if s > 1e-9:
            ang = math.atan2(s, np.dot(t0, t1))
            k = ax / s
            a = a * math.cos(ang) + np.cross(k, a) * math.sin(ang) + k * np.dot(k, a) * (1 - math.cos(ang))
        a = nrm(a - np.dot(a, t1) * t1)
        A.append(a)
        B.append(np.cross(t1, a))
    return np.array(T), np.array(A), np.array(B)


def sweep(sm, C, radii, weight, rect, n=8, prof=None, tip=0.0, base_cap=False, front=(0.0, 0.0, 1.0), phase=0.0):
    """Loft a tube along path C (m,3).
    radii: list of r or (ra, rb) per ring (ra along the frame's a axis = back, rb along b = side).
    prof(i, s, theta) -> radius multiplier (ridges, lumps, asymmetry); theta 0 = back (a), pi = front.
    weight(p, s) -> {bone: w} per vertex (s = normalised length 0..1).
    tip > 0 closes the end with a short cone of that length; base_cap closes the start with a flat fan."""
    C = np.asarray(C, float)
    S, _ = arclen(C)
    T, A, B = frames(C, front)
    rings, ws = [], []
    for i in range(len(C)):
        r = radii[i]
        ra, rb = (r, r) if np.isscalar(r) else r
        pts = []
        for k in range(n):
            th = phase + 2 * math.pi * k / n
            f = prof(i, S[i], th) if prof else 1.0
            pts.append(C[i] + A[i] * ra * f * math.cos(th) + B[i] * rb * f * math.sin(th))
        rings.append(np.array(pts))
        ws.append([weight(p, S[i]) for p in pts])
    cap_top = None
    if tip > 0:
        tp = C[-1] + T[-1] * tip
        cap_top = (tp, weight(tp, 1.0), ((rect[0] + rect[2]) / 2, rect[1]))
    cap_bot = None
    if base_cap:
        cap_bot = (C[0] - T[0] * 1e-3, weight(C[0], 0.0), ((rect[0] + rect[2]) / 2, rect[3]))
    sm.loft(rings, ws, rect, cap_top=cap_top, cap_bot=cap_bot)
    return rings


def chain_w(stops, blend=0.08):
    """stops: [(s_start, bone)] sorted by s; bone k owns [s_k, s_k+1). Returns weight(p, s) blending over +-blend
    around each joint."""
    def f(p, s):
        k = 0
        while k + 1 < len(stops) and s >= stops[k + 1][0]:
            k += 1
        w = {stops[k][1]: 1.0}
        # blend towards the previous bone near the start, next bone near the end
        if k > 0 and s - stops[k][0] < blend:
            t = 0.5 + 0.5 * (s - stops[k][0]) / blend
            w = {stops[k][1]: t, stops[k - 1][1]: 1 - t}
        elif k + 1 < len(stops) and stops[k + 1][0] - s < blend:
            t = 0.5 + 0.5 * (stops[k + 1][0] - s) / blend
            w = {stops[k][1]: t, stops[k + 1][1]: 1 - t}
        return w
    return f


def stops_from_joints(C, joint_pts, bones):
    """Arc-length positions (normalised along C) closest to each joint point -> chain_w stops."""
    S, _ = arclen(C)
    out = []
    for jp, b in zip(joint_pts, bones):
        i = int(np.argmin(np.linalg.norm(C - np.asarray(jp, float), axis=1)))
        out.append((float(S[i]), b))
    out[0] = (0.0, out[0][1])
    return out


def orb(sm, c, r, w, rect, n=6, m=4, axis=(0, 0, 1), squash=(1.0, 1.0, 1.0)):
    """Low-poly ellipsoid around c; r scalar; axis = pole direction; squash = (a, b, pole) scale."""
    ax = nrm(np.asarray(axis, float))
    a, b = tube_frame(ax, (0, 1, 0) if abs(ax[1]) < 0.9 else (1, 0, 0))
    rings = []
    for i in range(1, m):
        ph = math.pi * i / m
        z = -math.cos(ph) * r * squash[2]
        rr = math.sin(ph) * r
        rings.append(np.array([np.asarray(c, float) + ax * z + a * rr * squash[0] * math.cos(2 * math.pi * k / n)
                               + b * rr * squash[1] * math.sin(2 * math.pi * k / n) for k in range(n)]))
    ws = [w] * len(rings)
    u0, v0, u1, v1 = rect
    sm.loft(rings, ws, rect, cap_top=(np.asarray(c, float) + ax * r * squash[2], w, ((u0 + u1) / 2, v0 + (v1 - v0) * 0.1)),
            cap_bot=(np.asarray(c, float) - ax * r * squash[2], w, ((u0 + u1) / 2, v1 - (v1 - v0) * 0.1)))


def basis(fwd, up=(0, 1, 0)):
    """3x3 columns (x, y, z) with z = fwd, y ~ up."""
    z = nrm(np.asarray(fwd, float))
    x = np.cross(np.asarray(up, float), z)
    if np.linalg.norm(x) < 1e-6:
        x = np.cross((1.0, 0.0, 0.0), z)
    x = nrm(x)
    return np.column_stack([x, np.cross(z, x), z])


def plate(sm, c, size, w, rect, normal, along, taper=(0.7, 0.8)):
    """Armour plate: thin box whose local y = surface normal, local z = along; top face tapered (bevel look)."""
    y = nrm(np.asarray(normal, float))
    z = np.asarray(along, float) - np.dot(along, y) * y
    z = nrm(z)
    x = np.cross(y, z)
    M = np.column_stack([x, y, z])
    sm.box(c, size, w, rect, M=M, taper=taper, skip=("-y",))
