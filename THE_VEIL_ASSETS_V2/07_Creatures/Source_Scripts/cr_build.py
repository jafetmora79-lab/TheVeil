"""THE VEIL - Pack 07 shared build steps: tentacle chains, procedural motion layers, export.

Every creature uses the same recipe:
  1. a custom Rig (cr_core) with identity rest rotations,
  2. meshes swept along the bones (cr_geo) and skinned by arc length / position,
  3. clips baked from pose functions: body layer -> leg IK for planted feet -> tentacle / appendage layers,
  4. export: GLB (textures embedded for the browser gallery), .glb.import (external .tres, loop modes),
     .tres materials and lossless PNG imports.
The tentacle chain + wave/curl/droop layers are shared by the Colossus and the Mist Tentacles.
"""
import json
import math
import os

import numpy as np

import cr_core as C
import cr_geo as G

TEX = os.path.join(C.CR, "Textures")
MAT = os.path.join(C.CR, "Shared_Materials")
ANIM = os.path.join(C.CR, "Animations")


# ------------------------------------------------------------------ shared textures
def shared_tentacle_texture():
    """T_Crt_Tentacle (64 x 128 tiling skin, u around / v along) shared by the Colossus and the Mist Tentacles."""
    import cr_tex as X
    os.makedirs(TEX, exist_ok=True)
    tv = X.Canvas(64, 128, seed="tentacle")
    X.paint_tentacle(tv.region(0, 0, 64, 128), "tentacle")
    out = (os.path.join(TEX, "T_Crt_Tentacle.png"), os.path.join(TEX, "T_Crt_Tentacle_Emit.png"))
    tv.save(*out)
    return out


# ------------------------------------------------------------------ tentacles
def tentacle_chain(rig, prefix, parent, path_pts, nb, samples=None):
    """Bones evenly spaced by arc length along a smooth path. Returns (bones, joint points, dense path)."""
    Cd = G.resample(path_pts, samples or max(4 * nb + 1, 12))
    S, _ = G.arclen(Cd)
    jp = []
    for k in range(nb + 1):
        s = k / nb
        i = int(np.searchsorted(S, s))
        i = min(max(i, 1), len(S) - 1)
        t = (s - S[i - 1]) / max(S[i] - S[i - 1], 1e-9)
        jp.append(Cd[i - 1] + (Cd[i] - Cd[i - 1]) * t)
    bones = [f"{prefix}_{k + 1:02d}" for k in range(nb)]
    rig.chain(bones, parent, jp)
    return bones, jp, Cd


def tentacle_mesh(sm, Cd, bones, jp, r0, rtip, rect, n=8, ridge=0.07, parent=None, front=(0.0, -1.0, 0.0),
                  ridges=14.0, flat=0.85, seed=0.0, tip=None, tile_m=None, root_blend=0.1, flare=0.0):
    """Tapered, ridged tentacle along Cd. ridge = ring bulge amplitude; flat < 1 flattens the underside a little;
    a slow lumpy twist breaks perfect symmetry."""
    stops = G.stops_from_joints(Cd, jp[:-1], bones)
    wf = G.chain_w(stops, blend=0.5 / len(bones))
    if parent:
        base_w = wf

        def wf(p, s):  # noqa: F811  (root ring held by the parent so the base stays seated in its orifice)
            if s < root_blend:
                t = C.smooth(s / root_blend)
                w = {k: v * t for k, v in base_w(p, s).items()}
                w[parent] = w.get(parent, 0.0) + (1.0 - t)
                return w
            return base_w(p, s)
    S, L = G.arclen(Cd)
    if tile_m:
        rect = (rect[0], rect[1], rect[2], rect[1] + L / tile_m)
    radii = [(rtip + (r0 - rtip) * (1 - s) ** 0.9) * (1.0 + flare * math.exp(-(s / 0.05) ** 2)) for s in S]

    def prof(i, s, th):
        under = 1.0 - (1.0 - flat) * max(0.0, -math.cos(th)) ** 2       # theta = pi is the underside
        rr = 1.0 + ridge * max(0.0, math.sin(s * ridges * math.pi * 2 + seed)) ** 3
        lump = 1.0 + 0.05 * math.sin(th * 2 + s * 9 + seed * 2)
        return under * rr * lump
    G.sweep(sm, Cd, radii, wf, rect, n=n, prof=prof, tip=tip if tip is not None else rtip * 2.5, front=front)
    return L


def bone_dirs(rig, bones):
    out = []
    for k, b in enumerate(bones):
        nxt = rig.J[bones[k + 1]] if k + 1 < len(bones) else rig.tips[b]
        out.append(C.nrm(nxt - rig.J[b]))
    return out


def side_axes(d, up=(0.0, 1.0, 0.0)):
    """(lift axis, sweep axis) for a bone direction d: rotating about lift bends the bone up/down,
    about sweep bends it sideways."""
    lift = np.cross(d, up)
    if np.linalg.norm(lift) < 1e-6:
        lift = np.cross(d, (1.0, 0.0, 0.0))
    lift = C.nrm(lift)
    sweep = C.nrm(np.cross(lift, d))
    return lift, sweep


def cyc(freq, period):
    """Frequency snapped to a whole number of cycles per loop period (seamless loops)."""
    if not period:
        return freq
    return max(1, round(freq * period)) / period


def wave(rig, local, bones, t, amp=8.0, amp2=6.0, freq=0.5, lag=0.7, phase=0.0, grow=1.0, period=None):
    """Travelling wave along a chain (rotations about each bone's rest lift / sweep axes, in local space - identity
    rest rotations mean rest axes are world axes). With period set, both components complete whole cycles."""
    dirs = bone_dirs(rig, bones)
    f1, f2 = cyc(freq, period), cyc(freq * 0.73, period)
    n = len(bones)
    for k, (b, d) in enumerate(zip(bones, dirs)):
        lift, sw = side_axes(d)
        g = (0.45 + 0.55 * k / max(1, n - 1)) ** grow
        a1 = amp * g * math.sin(2 * math.pi * f1 * t - k * lag + phase)
        a2 = amp2 * g * math.cos(2 * math.pi * f2 * t - k * lag * 0.8 + phase * 1.7)
        local[b] = local.get(b, C.I3) @ C.R(lift, a1) @ C.R(sw, a2)
    return local


def curl(rig, local, bones, degs, axis="lift", up=(0.0, 1.0, 0.0)):
    """Add a per-bone bend (list of degrees, or one value for all) about each bone's rest lift or sweep axis."""
    dirs = bone_dirs(rig, bones)
    if np.isscalar(degs):
        degs = [degs] * len(bones)
    for b, d, a in zip(bones, dirs, degs):
        lift, sw = side_axes(d, up)
        local[b] = local.get(b, C.I3) @ C.R(lift if axis == "lift" else sw, a)
    return local


def bend_world(rig, local, trans, b, axis_world, deg):
    """Rotate bone b by deg about a world axis (pre-multiplied in world space, converted to local)."""
    Rw, _ = rig.fk(local, trans)
    p = rig.parent(b)
    Rpar = Rw[p] if p else C.I3
    local[b] = Rpar.T @ C.R(axis_world, deg) @ Rw[b]
    return local


def aim_world(rig, local, trans, b, target_dir, amt):
    """Turn bone b (minimal rotation, applied in world space) so its current direction moves amt (0..1) of the way
    toward target_dir."""
    if amt <= 1e-6:
        return local
    Rw, _ = rig.fk(local, trans)
    nxt = rig.tips.get(b)
    kids = [c for c, p in rig.bones if p == b]
    rest = (rig.J[kids[0]] if kids else nxt) - rig.J[b]
    cur = C.nrm(Rw[b] @ rest)
    tgt = C.nrm(np.asarray(target_dir, float))
    ang = math.degrees(math.acos(max(-1.0, min(1.0, float(np.dot(cur, tgt))))))
    ax = np.cross(cur, tgt)
    if np.linalg.norm(ax) < 1e-8 or ang < 1e-4:
        return local
    return bend_world(rig, local, trans, b, C.nrm(ax), ang * min(1.0, amt))


def chain_points(rig, local, trans, bones):
    Rw, Pw = rig.fk(local, trans)
    pts = [Pw[b] for b in bones]
    last = bones[-1]
    pts.append(Pw[last] + Rw[last] @ (rig.tips[last] - rig.J[last]))
    return np.array(pts)


def floor_clamp(rig, local, trans, bones, floor, step=4.0, rad=None):
    """Deterministic ground guard: walk down the chain and, wherever a joint (or the tip) would dip below
    floor + its radius, bend that bone's parent segment back up in small steps."""
    rad = rad or [0.0] * (len(bones) + 1)
    pts = chain_points(rig, local, trans, bones)
    if all(pts[i][1] >= floor + rad[i] for i in range(len(pts))):
        return local
    for k in range(len(bones)):
        for _ in range(60):
            pts = chain_points(rig, local, trans, bones)
            low = [i for i in range(k + 1, len(pts)) if pts[i][1] < floor + rad[i]]
            if not low:
                break
            Rw, Pw = rig.fk(local, trans)
            d = pts[k + 1] - pts[k]
            ax = np.cross(d, (0.0, 1.0, 0.0))
            if np.linalg.norm(ax) < 1e-6:
                break
            local = bend_world(rig, local, trans, bones[k], C.nrm(ax), step)   # +angle about d x up lifts d
    return local


# ------------------------------------------------------------------ export
def finish(meshes, rig):
    bi = rig.index()
    return [(m, sm.finish(bi)) for m, sm in meshes.items() if sm.tri_count()]


def export(name, folder, rig, meshes, mats, sockets, clips, extras):
    """mats: {material name: dict(albedo=path, emit=path|None, emit_factor, emit_energy, repeat, rough)}.
    Writes <folder>/<name>.glb + .import, Shared_Materials/<mat>.tres, PNG .import files, Animations/<name>_clips.json."""
    for d in (TEX, MAT, ANIM, os.path.join(C.CR, folder)):
        os.makedirs(d, exist_ok=True)
    prims = finish(meshes, rig)
    gl_mats, tres = {}, {}
    for m, s in mats.items():
        alb = open(s["albedo"], "rb").read()
        emit = open(s["emit"], "rb").read() if s.get("emit") else None
        gl_mats[m] = dict(albedo=alb, emit=emit, emit_factor=s.get("emit_factor", (0.5, 0.5, 0.5)),
                          repeat=s.get("repeat", False), rough=s.get("rough", 0.9))
        tp = os.path.join(MAT, m + ".tres")
        C.write_tres(tp, m, s["albedo"], s.get("emit"), s.get("emit_energy", 0.6), s.get("repeat", False), s.get("rough", 0.9))
        tres[m] = tp
        for png in (s["albedo"], s.get("emit")):
            if png:
                C.write_png_import(png)
    glb = os.path.join(C.CR, folder, name + ".glb")
    C.write_glb(glb, name, rig, prims, gl_mats, sockets, clips, extras)
    used = [m for m, _ in prims]
    C.write_import(glb, {m: tres[m] for m in used}, clips)
    info = {"model": os.path.relpath(glb, C.V2).replace(os.sep, "/"), "fps_baked": round((len(clips[0].times) - 1) / clips[0].duration, 3) if clips else None,
            "clips": [{"name": c.name, "duration_s": round(c.duration, 3), "loop": c.loop, "keys": len(c.times)} for c in clips]}
    with open(os.path.join(ANIM, name + "_clips.json"), "w", newline="\n") as f:
        json.dump(info, f, indent=2)
        f.write("\n")
    tris = sum(len(a[5]) // 3 for _, a in prims)
    return glb, tris
