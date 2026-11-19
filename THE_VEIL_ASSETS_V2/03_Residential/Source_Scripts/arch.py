"""Architectural building blocks for Pack 03 (walls, openings, doors, windows,
roofs, stairs, porches, chimneys). Everything is built in metres, Y up.

Interactive parts are returned as separate node specs whose origin is the
pivot (hinge line, slide origin) with glTF `extras` describing the motion:
    {"veil_interact": "hinge", "axis": "y", "open_deg": 95}
    {"veil_interact": "slide", "axis": "x", "distance": 0.9}
Collision follows the Godot import naming convention used by Pack 02.
"""
import math

import numpy as np

from res_materials import m01, mt, mr  # noqa: E402  (sets up the shared Pack 02 import path)
from veil_mesh.mesh import MB, T, Ry, Rx, Rz, nrm  # noqa: E402
from veil_mesh.gltf import COL_KEY  # noqa: E402

# ---------------------------------------------------------------- standards
EXT_T = 0.20          # exterior wall thickness
INT_T = 0.12          # interior partition thickness
DOOR_W, DOOR_H = 0.95, 2.10
EXT_DOOR_W, EXT_DOOR_H = 1.00, 2.15
RISE, TREAD = 0.18, 0.28
FLOOR_Y = 0.60        # ground floor finished level above the lot
STOREY = 3.00         # floor-to-floor
CEIL_H = 2.60         # finished ceiling height

TRIM = m01("Arch_TrimPainted")
GLASS = m01("Arch_WindowGlassDirty")
DRYWALL = m01("Int_DrywallLight")
WOOD_D = m01("Furn_WoodDark")
WOOD_L = m01("Furn_WoodLight")
WOOD_P = m01("Furn_WoodPainted")
METAL = m01("Furn_MetalBrushed")


def frame_2d(p0, p1):
    """4x4 transform: local +X along p0->p1 (in the XZ plane), local +Z = left normal."""
    dx, dz = p1[0] - p0[0], p1[1] - p0[1]
    L = math.hypot(dx, dz)
    dx, dz = dx / L, dz / L
    nx, nz = -dz, dx
    M = np.array([[dx, 0, nx, p0[0]], [0, 1, 0, 0], [dz, 0, nz, p0[1]], [0, 0, 0, 1.0]])
    return M, L


def rects_minus(full, holes):
    """Split rect (u0,u1,v0,v1) minus non-overlapping opening rects into pieces."""
    u0, u1, v0, v1 = full
    hs = sorted([h for h in holes if h[1] > u0 and h[0] < u1], key=lambda h: h[0])
    out = []
    cur = u0
    for (a, b, c, d) in hs:
        a, b = max(a, u0), min(b, u1)
        if a > cur + 1e-6:
            out.append((cur, a, v0, v1))
        if c > v0 + 1e-6:
            out.append((a, b, v0, min(c, v1)))
        if d < v1 - 1e-6:
            out.append((a, b, max(d, v0), v1))
        cur = b
    if cur < u1 - 1e-6:
        out.append((cur, u1, v0, v1))
    return out


def wall(mb, col, p0, p1, y0, y1, t, mat_pos, mat_neg, openings=(), ext=None, reveal=TRIM, uoff=0.0,
         faces=("pos", "neg"), col_wall=True):
    """Straight wall from p0 to p1 (XZ). Faces: +n side (left of travel) and -n side.

    openings: list of (u0, u1, v0, v1) with u measured from p0 and v absolute heights.
    ext: {"pos": (e0, e1), "neg": (e0, e1)} - extend (+) / shrink (-) each face at
         its ends so exterior corners mitre cleanly.
    """
    M, L = frame_2d(p0, p1)
    ext = ext or {}
    loc, lcol = MB(), MB()
    for side, mat, z, nz in (("pos", mat_pos, t / 2, 1), ("neg", mat_neg, -t / 2, -1)):
        if side not in faces or mat is None:
            continue
        e0, e1 = ext.get(side, (0.0, 0.0))
        for (a, b, c, d) in rects_minus((-e0, L + e1, y0, y1), openings):
            pts = [[a, c, z], [b, c, z], [b, d, z], [a, d, z]]
            uv = [((p[0] + uoff) * nz, -p[1]) for p in pts]
            loc.quad(mat, *pts, n=(0, 0, nz), uv=uv)
    for (a, b, c, d) in openings:          # reveals (jambs, head, sill)
        a2, b2 = max(a, 0), min(b, L)
        loc.quad(reveal, [a2, c, -t / 2], [a2, c, t / 2], [a2, d, t / 2], [a2, d, -t / 2], n=(1, 0, 0))
        loc.quad(reveal, [b2, c, t / 2], [b2, c, -t / 2], [b2, d, -t / 2], [b2, d, t / 2], n=(-1, 0, 0))
        if d < y1 - 1e-6:
            loc.quad(reveal, [a2, d, -t / 2], [a2, d, t / 2], [b2, d, t / 2], [b2, d, -t / 2], n=(0, -1, 0))
        if c > y0 + 1e-6:
            loc.quad(reveal, [a2, c, t / 2], [a2, c, -t / 2], [b2, c, -t / 2], [b2, c, t / 2], n=(0, 1, 0))
    if col is not None and col_wall:
        for (a, b, c, d) in rects_minus((0, L, y0, y1), openings):
            lcol.box(COL_KEY, (a, c, -t / 2), (b, d, t / 2), skip=())
    mb.merge(loc, M)
    if col is not None:
        col.merge(lcol, M)
    return M, L


def casing(mb, M, u0, u1, v0, v1, side_z, nz, mat=TRIM, w=0.09, sill=True, head_cap=True):
    """Trim boards around an opening on one face of a wall (local frame M)."""
    loc = MB()
    d = 0.025
    z0, z1 = (side_z, side_z + d * nz) if nz > 0 else (side_z + d * nz, side_z)
    loc.box(mat, (u0 - w, v0 if not sill else v0 - 0.02, z0), (u0, v1 + w, z1), skip=())
    loc.box(mat, (u1, v0 if not sill else v0 - 0.02, z0), (u1 + w, v1 + w, z1), skip=())
    loc.box(mat, (u0, v1, z0), (u1, v1 + w, z1), skip=())
    if head_cap:
        zc0, zc1 = (side_z, side_z + 0.05 * nz) if nz > 0 else (side_z + 0.05 * nz, side_z)
        loc.box(mat, (u0 - w - 0.03, v1 + w, zc0), (u1 + w + 0.03, v1 + w + 0.035, zc1), skip=())
    if sill:
        zs0, zs1 = (side_z, side_z + 0.07 * nz) if nz > 0 else (side_z + 0.07 * nz, side_z)
        loc.box(mat, (u0 - w - 0.02, v0 - 0.045, zs0), (u1 + w + 0.02, v0, zs1), skip=())
    mb.merge(loc, M)


# ---------------------------------------------------------------- doors
def panel_door_leaf(w, h, paint, style="interior", t=0.045, knob_side="r"):
    """Leaf in pivot space: hinge line at x=0 (z=0), leaf along +X, y up."""
    mb = MB()
    mb.box(paint, (0.005, 0.01, -t / 2), (w - 0.005, h - 0.005, t / 2), skip=())
    panels = {"interior": [(0.1, 1.15, 0.95), (1.25, 2.0, 0.95)], "front": [(0.1, 1.0, 0.95)],
              "back": [(0.1, 0.95, 0.95)], "shaker": [(0.12, h - 0.12, 0.95)]}.get(style, [])
    for (ya, yb, fr) in panels:
        for k, (xa, xb) in enumerate(((0.1, w / 2 - 0.04), (w / 2 + 0.04, w - 0.1))):
            for zs in (1, -1):
                z0, z1 = (t / 2, t / 2 + 0.012) if zs > 0 else (-t / 2 - 0.012, -t / 2)
                mb.box(paint, (xa, ya, z0), (xb, min(yb, h - 0.1), z1), skip=())
    if style in ("front", "back"):   # upper glazing
        g0 = 1.25 if style == "front" else 1.05
        mb.box(GLASS, (0.16, g0, -0.008), (w - 0.16, h - 0.16, 0.008), skip=())
        for xs in (w / 2,):
            mb.box(paint, (xs - 0.02, g0, -t / 2), (xs + 0.02, h - 0.16, t / 2), skip=())
    kx = w - 0.07 if knob_side == "r" else 0.07
    for zs in (1, -1):
        k = MB()
        k.cyl(METAL, (0, 0, 0), 0.03, 0.06, seg=8, caps=("top",))
        mb.merge(k, T(kx, 0.95, zs * t / 2) @ Rx(zs * math.pi / 2))
    mb.box(METAL, (kx - 0.025, 0.85, -t / 2 - 0.005), (kx + 0.025, 1.05, t / 2 + 0.005), skip=())
    return mb


def door_node(name, hinge_pos, yaw, w, h, paint, style="interior", open_deg=95.0, kind="hinge"):
    """Hinged door node. The leaf closes along local +X; rotate about Y to open."""
    leaf = panel_door_leaf(w, h, paint, style)
    c = MB()
    c.box(COL_KEY, (0, 0, -0.03), (w, h, 0.03), skip=())
    return {"name": name, "t": hinge_pos, "yaw": yaw, "mb": leaf,
            "extras": {"veil_interact": "hinge", "axis": "y", "open_deg": open_deg, "width": w, "height": h},
            "children": [{"name": name + "_Col-convcolonly", "mb": c}]}


def slider_node(name, pos, yaw, w, h, mat, distance, glass=True):
    leaf = MB()
    fr = 0.05
    leaf.box(METAL if glass else mat, (0, 0, -0.025), (w, fr, 0.025), skip=())
    leaf.box(METAL if glass else mat, (0, h - fr, -0.025), (w, h, 0.025), skip=())
    leaf.box(METAL if glass else mat, (0, fr, -0.025), (fr, h - fr, 0.025), skip=())
    leaf.box(METAL if glass else mat, (w - fr, fr, -0.025), (w, h - fr, 0.025), skip=())
    if glass:
        leaf.box(GLASS, (fr, fr, -0.006), (w - fr, h - fr, 0.006), skip=())
    else:
        leaf.box(mat, (fr, fr, -0.012), (w - fr, h - fr, 0.012), skip=())
    c = MB()
    c.box(COL_KEY, (0, 0, -0.03), (w, h, 0.03), skip=())
    return {"name": name, "t": pos, "yaw": yaw, "mb": leaf,
            "extras": {"veil_interact": "slide", "axis": "x", "distance": distance},
            "children": [{"name": name + "_Col-convcolonly", "mb": c}]}


def garage_door_node(name, pos, yaw, w, h):
    leaf = MB()
    pts = [[0, 0, 0.0], [w, 0, 0.0], [w, h, 0.0], [0, h, 0.0]]
    leaf.quad(mr("GarageDoor"), *pts, n=(0, 0, -1), uv=[(p[0], -p[1]) for p in pts])
    leaf.quad(mt("PaintWhite"), *[[p[0], p[1], 0.04] for p in pts], n=(0, 0, 1))
    leaf.box(METAL, (w / 2 - 0.15, 0.25, -0.03), (w / 2 + 0.15, 0.29, 0.0), skip=())
    c = MB()
    c.box(COL_KEY, (0, 0, 0), (w, h, 0.04), skip=())
    return {"name": name, "t": pos, "yaw": yaw, "mb": leaf,
            "extras": {"veil_interact": "slide", "axis": "y", "distance": h - 0.15, "note": "sectional: raise along Y"},
            "children": [{"name": name + "_Col-convcolonly", "mb": c}]}


# ---------------------------------------------------------------- windows
def window_unit(w, h, t=EXT_T, style="double_hung", sash_node=None):
    """Window filling an opening in opening-local space: u 0..w, v 0..h, wall
    thickness centred on z=0. Returns (static MB, [interactive node specs])."""
    mb = MB()
    fr = 0.05
    nodes = []
    if style == "boarded":
        planks = m01("Arch_WoodPlanksAged")
        mb.box(m01("Road_RoadPatch"), (0, 0, -0.01), (w, h, 0.0), skip=())   # dark void behind
        for k, a in enumerate((0.12, -0.18, 0.05)):
            b = MB()
            b.box(planks, (-0.15, -0.09, 0.0), (w + 0.15, 0.09, 0.025), skip=())
            b2 = MB()
            b2.merge(b, T(w / 2, h * (0.25 + 0.25 * k), t / 2 + 0.005) @ Rz(a) @ T(-w / 2, 0, 0))
            mb.merge(b2)
        return mb, nodes
    mb.box(TRIM, (0, 0, -0.04), (w, fr, 0.04), skip=())
    mb.box(TRIM, (0, h - fr, -0.04), (w, h, 0.04), skip=())
    mb.box(TRIM, (0, fr, -0.04), (fr, h - fr, 0.04), skip=())
    mb.box(TRIM, (w - fr, fr, -0.04), (w, h - fr, 0.04), skip=())
    if style == "picture":
        mb.box(GLASS, (fr, fr, -0.005), (w - fr, h - fr, 0.005), skip=())
        return mb, nodes
    # double hung: fixed upper sash + sliding lower sash
    mid = h / 2
    up = MB()
    up.box(TRIM, (fr, mid, 0.0), (w - fr, mid + 0.04, 0.03), skip=())
    up.box(GLASS, (fr, mid + 0.04, 0.012), (w - fr, h - fr, 0.018), skip=())
    up.box(TRIM, ((w) / 2 - 0.015, mid, 0.0), ((w) / 2 + 0.015, h - fr, 0.03), skip=())   # muntin
    mb.merge(up)
    lo = MB()
    lo.box(TRIM, (fr, 0.0, -0.03), (w - fr, 0.06, 0.0), skip=())
    lo.box(TRIM, (fr, mid - fr - 0.04, -0.03), (w - fr, mid - fr, 0.0), skip=())
    lo.box(GLASS, (fr, 0.06, -0.018), (w - fr, mid - fr - 0.04, -0.012), skip=())
    lo.box(TRIM, (w / 2 - 0.015, 0.06, -0.03), (w / 2 + 0.015, mid - fr - 0.04, 0.0), skip=())
    if sash_node:
        nodes.append({"name": sash_node, "t": (0, fr, 0), "mb": lo,
                      "extras": {"veil_interact": "slide", "axis": "y", "distance": mid - fr - 0.06}})
    else:
        lo2 = MB()
        lo2.merge(lo, T(0, fr, 0))
        mb.merge(lo2)
    return mb, nodes


def shutters(mb, M, u0, u1, v0, v1, z):
    w = 0.42
    for (a, b) in ((u0 - 0.1 - w, u0 - 0.1), (u1 + 0.1, u1 + 0.1 + w)):
        loc = MB()
        pts = [[a, v0, z], [b, v0, z], [b, v1, z], [a, v1, z]]
        loc.quad(mr("Shutter"), *pts, n=(0, 0, 1 if z > 0 else -1), uv=[(0, 1), (1, 1), (1, 0), (0, 0)])
        loc.box(mr("Shutter"), (a, v0, min(0, z) if z < 0 else z - 0.03), (b, v1, z if z > 0 else z + 0.03),
                skip=("+z", "-z", "-y"))         # front = the louvre quad, back = against the wall
        mb.merge(loc, M)


# ---------------------------------------------------------------- stairs
def stair(mb, col, origin, yaw, width, n, rise=RISE, tread=TREAD, mat_tread=WOOD_D, mat_side=WOOD_P,
          rail=True, open_sides=("r",)):
    """Straight stair. Local: base at origin, climbing along +Z, x across 0..width.
    Collision is a single walkable ramp (~33 deg) instead of steps."""
    loc, lc = MB(), MB()
    for k in range(n):
        y = (k + 1) * rise
        z0, z1 = k * tread, (k + 1) * tread
        loc.box(mat_tread, (0.003, y - 0.04, z0 - 0.02), (width - 0.003, y, z1), skip=("-y",))     # tread with nosing (ends just inside the stringers)
        loc.quad(mat_side, [width, y - rise, z0], [0, y - rise, z0], [0, y - 0.04, z0], [width, y - 0.04, z0], n=(0, 0, -1))
    L = n * tread
    H = n * rise
    for xs, nx in ((0.0, -1), (width, 1)):       # sloped stringer boards on both sides
        loc.quad(mat_side, [xs, 0.0, 0.0], [xs, H - 0.2, L], [xs, H + 0.05, L], [xs, 0.25, 0.0], n=(nx, 0, 0))
    if rail:
        for side in open_sides:
            xr = width - 0.05 if side == "r" else 0.05
            loc.tube(WOOD_D, [(xr, 0.95, 0.1), (xr, H + 0.9, L)], 0.025, 5)
            for k in range(0, n, 2):
                y = (k + 1) * rise
                loc.box(WOOD_P, (xr - 0.015, y, k * tread + 0.12), (xr + 0.015, y + 0.88, k * tread + 0.15), skip=())
            loc.box(WOOD_D, (xr - 0.05, 0, 0.0), (xr + 0.05, 1.05, 0.1), skip=())
    lc.quad(COL_KEY, [0, 0, -0.05], [width, 0, -0.05], [width, H, L], [0, H, L], n=(0, 1, 0))
    # (no one-sided guard face here any more: game/world/stair_assist.gd lays a SOLID guard along every open side;
    # this face sat 2 cm outside it and, pushing the other way, wedged anyone walking close to the rail)
    M = T(*origin) @ Ry(yaw)
    mb.merge(loc, M)
    if col is not None:
        col.merge(lc, M)
    return L, H


def railing(mb, col, p0, p1, y, h=0.95, mat=WOOD_D, post=WOOD_P):
    M, L = frame_2d(p0, p1)
    loc, lc = MB(), MB()
    loc.box(mat, (0, y + h - 0.05, -0.03), (L, y + h, 0.03), skip=())
    k = 0.06
    while k < L - 0.03:
        loc.box(post, (k - 0.015, y, -0.015), (k + 0.015, y + h - 0.05, 0.015), skip=("-y", "+y"))
        k += 0.14
    lc.box(COL_KEY, (0, y, -0.04), (L, y + h, 0.04), skip=())
    mb.merge(loc, M)
    if col is not None:
        col.merge(lc, M)


# ---------------------------------------------------------------- roofs
def _roof_quad(mb, mat, pts, u_axis, n):
    """Roof surface with UVs: u along the eave direction, v down the slope (metres)."""
    pts = [np.asarray(p, float) for p in pts]
    ua = nrm(u_axis)
    # slope direction: perpendicular to u in the plane
    sv = nrm(np.cross(n, ua))
    o = pts[0]
    uv = [(float(np.dot(p - o, ua)), float(-np.dot(p - o, sv))) for p in pts]
    mb.quad(mat, *pts, n=n, uv=uv)


def gable_roof(mb, col, rect, base_y, pitch_deg, ridge="x", overhang=0.35, rake=0.25, mat=None, gable_mat=None,
               soffit=TRIM, fascia=TRIM, thick=0.14, attic=False, attic_mat=None, gutters=True, ends=(True, True)):
    """Symmetric gable over rect (x0,z0,x1,z1) = OUTER wall faces. ridge 'x' or 'z'."""
    x0, z0, x1, z1 = rect
    if ridge == "z":   # build with ridge along x in a rotated frame
        loc, lc = MB(), MB()
        gable_roof(loc, lc, (z0, -x1, z1, -x0), base_y, pitch_deg, "x", overhang, rake, mat, gable_mat, soffit, fascia,
                   thick, attic, attic_mat, gutters, ends)
        R = Ry(-math.pi / 2)      # frame x -> world z, frame z -> world -x
        mb.merge(loc, R)
        if col is not None:
            col.merge(lc, R)
        return
    tn = math.tan(math.radians(pitch_deg))
    zm = (z0 + z1) / 2
    half = (z1 - z0) / 2
    ry = base_y + half * tn
    ex0, ex1 = x0 - rake, x1 + rake
    ez0, ez1 = z0 - overhang, z1 + overhang
    ey = base_y - overhang * tn
    for (za, zb) in ((ez0, zm), (ez1, zm)):      # two slopes
        sgn = -1 if za < zm else 1
        n = nrm((0, 1.0, tn if sgn > 0 else -tn))
        top = [[ex0, ey, za], [ex1, ey, za], [ex1, ry, zb], [ex0, ry, zb]]
        _roof_quad(mb, mat, top, (1, 0, 0), n)
        bot = [[p[0], p[1] - thick, p[2]] for p in top]
        mb.quad(soffit, *bot, n=(-n[0], -n[1], -n[2]))
        mb.quad(fascia, [ex0, ey - thick, za], [ex1, ey - thick, za], [ex1, ey, za], [ex0, ey, za], n=(0, 0, sgn))
        if gutters:
            mb.box(mt("PaintWhite"), (ex0, ey - thick - 0.1, za + (0 if sgn > 0 else -0.12)), (ex1, ey - thick + 0.02, za + (0.12 if sgn > 0 else 0)),
                   skip=())
            for xd in (ex0 + 0.15, ex1 - 0.2):
                mb.box(mt("PaintWhite"), (xd, 0.0, za + (0.0 if sgn > 0 else -0.08)), (xd + 0.06, ey - thick - 0.1, za + (0.08 if sgn > 0 else 0.0)),
                       skip=("-y",))
        for xe, sx in ((ex0, -1), (ex1, 1)):    # rake edges
            mb.quad(fascia, [xe, ey - thick, za], [xe, ry - thick, zb], [xe, ry, zb], [xe, ey, za], n=(sx, 0, 0))
        if col is not None and attic:
            col.quad(COL_KEY, *bot, n=(0, -1, 0))
    for xw, sx, on in ((x0, -1, ends[0]), (x1, 1, ends[1])):     # gable triangles
        if not on:
            continue
        tri = [[xw, base_y, z0], [xw, base_y, z1], [xw, ry - thick * 0.7, zm]]
        mb.tri(gable_mat, *tri, n=(sx, 0, 0), uv=[(p[2] * -sx, -p[1]) for p in tri])
        if attic:
            tri2 = [[xw - sx * EXT_T, base_y, z0 + 0.0], [xw - sx * EXT_T, base_y, z1], [xw - sx * EXT_T, ry - thick, zm]]
            mb.tri(attic_mat or m01("Arch_WoodPlanksAged"), *tri2, n=(-sx, 0, 0), uv=[(p[2], -p[1]) for p in tri2])
            if col is not None:
                col.tri(COL_KEY, *tri2, n=(-sx, 0, 0))
    if attic:   # visible rafters / sheathing from inside
        am = attic_mat or m01("Arch_WoodPlanksAged")
        for (za, zb, s) in ((z0, zm, -1), (z1, zm, 1)):
            n_in = nrm((0, -1.0, -tn if s > 0 else tn))
            pts = [[x0 + EXT_T, base_y + 0.05, za], [x1 - EXT_T, base_y + 0.05, za], [x1 - EXT_T, ry - thick - 0.05, zb],
                   [x0 + EXT_T, ry - thick - 0.05, zb]]
            mb.quad(am, *pts, n=n_in)
    return ry


def hip_roof(mb, col, rect, base_y, pitch_deg, overhang=0.35, mat=None, soffit=TRIM, fascia=TRIM, thick=0.14, gutters=True):
    x0, z0, x1, z1 = rect
    tn = math.tan(math.radians(pitch_deg))
    w, d = x1 - x0, z1 - z0
    ex0, ex1, ez0, ez1 = x0 - overhang, x1 + overhang, z0 - overhang, z1 + overhang
    ey = base_y - overhang * tn
    half = min(w, d) / 2
    ry = base_y + half * tn
    if w >= d:
        r0, r1 = (x0 + half, (z0 + z1) / 2), (x1 - half, (z0 + z1) / 2)
    else:
        r0, r1 = ((x0 + x1) / 2, z0 + half), ((x0 + x1) / 2, z1 - half)
    A, B, C, D = (ex0, ey, ez0), (ex1, ey, ez0), (ex1, ey, ez1), (ex0, ey, ez1)
    R0, R1 = (r0[0], ry, r0[1]), (r1[0], ry, r1[1])
    if w >= d:
        planes = [([A, B, R1, R0], (1, 0, 0), (0, 1, -tn)), ([C, D, R0, R1], (-1, 0, 0), (0, 1, tn)),
                  ([D, A, R0], (0, 0, -1), (-tn, 1, 0)), ([B, C, R1], (0, 0, 1), (tn, 1, 0))]
    else:
        planes = [([A, B, R0], (1, 0, 0), (0, 1, -tn)), ([C, D, R1], (-1, 0, 0), (0, 1, tn)),
                  ([D, A, R0, R1], (0, 0, -1), (-tn, 1, 0)), ([B, C, R1, R0], (0, 0, 1), (tn, 1, 0))]
    for pts, ua, n in planes:
        n = nrm(n)
        if len(pts) == 4:
            _roof_quad(mb, mat, pts, ua, n)
            mb.quad(soffit, *[[p[0], p[1] - thick, p[2]] for p in pts], n=(-n[0], -n[1], -n[2]))
        else:
            o = np.asarray(pts[0], float)
            sv = nrm(np.cross(n, nrm(ua)))
            uv = [(float(np.dot(np.asarray(p) - o, nrm(ua))), float(-np.dot(np.asarray(p) - o, sv))) for p in pts]
            mb.tri(mat, *pts, n=n, uv=uv)
            mb.tri(soffit, *[[p[0], p[1] - thick, p[2]] for p in pts], n=(-n[0], -n[1], -n[2]))
    for (p, q, nn) in ((A, B, (0, 0, -1)), (B, C, (1, 0, 0)), (C, D, (0, 0, 1)), (D, A, (-1, 0, 0))):
        mb.quad(fascia, [p[0], ey - thick, p[2]], [q[0], ey - thick, q[2]], [q[0], ey, q[2]], [p[0], ey, p[2]], n=nn)
    if gutters:
        for (p, q, nn) in ((A, B, (0, 0, -1)), (C, D, (0, 0, 1))):
            zz = p[2] + nn[2] * 0.06
            mb.box(mt("PaintWhite"), (ex0, ey - thick - 0.1, zz - 0.06), (ex1, ey - thick + 0.02, zz + 0.06), skip=())
        for (xd, zd) in ((ex0 + 0.05, ez0 - 0.06), (ex1 - 0.11, ez1 + 0.0)):
            mb.box(mt("PaintWhite"), (xd, 0.0, zd), (xd + 0.06, ey - thick - 0.1, zd + 0.06), skip=("-y",))
    return ry


def shed_roof(mb, col, rect, y_low, y_high, high_side="z0", overhang=0.3, mat=None, soffit=TRIM, fascia=TRIM, thick=0.12):
    """Mono-pitch roof (porches, lean-tos). high_side: edge that meets the house wall."""
    x0, z0, x1, z1 = rect
    if high_side in ("z0", "z1"):
        za, zb = (z1 + overhang, z0) if high_side == "z0" else (z0 - overhang, z1)
        slope = (y_high - y_low) / abs((z1 - z0))
        ya = y_low - overhang * slope
        top = [[x0 - overhang, ya, za], [x1 + overhang, ya, za], [x1 + overhang, y_high, zb], [x0 - overhang, y_high, zb]]
        sg = 1 if za > zb else -1
        n = nrm((0, 1, sg * slope))
        _roof_quad(mb, mat, top, (1, 0, 0), n)
        mb.quad(soffit, *[[p[0], p[1] - thick, p[2]] for p in top], n=(-n[0], -n[1], -n[2]))
        mb.quad(fascia, [x0 - overhang, ya - thick, za], [x1 + overhang, ya - thick, za], [x1 + overhang, ya, za],
                [x0 - overhang, ya, za], n=(0, 0, sg))
        for xe, sx in ((x0 - overhang, -1), (x1 + overhang, 1)):
            mb.quad(fascia, [xe, ya - thick, za], [xe, y_high - thick, zb], [xe, y_high, zb], [xe, ya, za], n=(sx, 0, 0))
        mb.box(mt("PaintWhite"), (x0 - overhang, ya - thick - 0.1, za + (0 if sg > 0 else -0.12)),
               (x1 + overhang, ya - thick + 0.02, za + (0.12 if sg > 0 else 0)), skip=())
    else:
        loc = MB()
        shed_roof(loc, None, (z0, -x1, z1, -x0), y_low, y_high, "z0" if high_side == "x1" else "z1", overhang, mat, soffit, fascia, thick)
        mb.merge(loc, Ry(-math.pi / 2))


# ---------------------------------------------------------------- misc exterior
def chimney(mb, col, x, z, w, d, y_top, mat=None, base=0.0):
    mat = mat or m01("Arch_BrickRed")
    mb.box(mat, (x - w / 2, base, z - d / 2), (x + w / 2, y_top, z + d / 2), skip=("-y",))
    mb.box(m01("Arch_ConcreteFoundation"), (x - w / 2 - 0.06, y_top, z - d / 2 - 0.06), (x + w / 2 + 0.06, y_top + 0.1, z + d / 2 + 0.06))
    mb.box(m01("Road_RoadPatch"), (x - w / 2 + 0.08, y_top + 0.1, z - d / 2 + 0.08), (x + w / 2 - 0.08, y_top + 0.101, z + d / 2 - 0.08),
           skip=("-y",))
    if col is not None:
        col.box(COL_KEY, (x - w / 2, base, z - d / 2), (x + w / 2, y_top, z + d / 2), skip=())


def porch(mb, col, rect, deck_y, steps=None, rails=("x0", "x1", "z0"), columns=None, deck_mat=None, skirt=True,
          col_h=2.45, rail_gap=None, step_mat=None, risers=None, col_mat=None, col_w=0.07):
    """Front porch deck. steps: (side, centre, width). rails on open edges except step gap."""
    x0, z0, x1, z1 = rect
    deck_mat = deck_mat or m01("Arch_WoodPlanksAged")
    mb.ground_poly(deck_mat, [(x0, z0), (x1, z0), (x1, z1), (x0, z1)], y=deck_y)
    col.box(COL_KEY, (x0, 0, z0), (x1, deck_y, z1), skip=())
    band = TRIM
    for (p, q, n) in (((x0, z0), (x1, z0), (0, 0, -1)), ((x1, z0), (x1, z1), (1, 0, 0)), ((x0, z1), (x0, z0), (-1, 0, 0))):
        mb.quad(band, [p[0], deck_y - 0.18, p[1]], [q[0], deck_y - 0.18, q[1]], [q[0], deck_y, q[1]], [p[0], deck_y, p[1]], n=n)
        if skirt and deck_y > 0.3:
            pts = [[p[0], 0.0, p[1]], [q[0], 0.0, q[1]], [q[0], deck_y - 0.18, q[1]], [p[0], deck_y - 0.18, p[1]]]
            ua = (q[0] - p[0], q[1] - p[1])
            L = math.hypot(*ua)
            mb.quad(mr("Lattice"), *pts, n=n, uv=[(0, 0), (L, 0), (L, -(deck_y - 0.18)), (0, -(deck_y - 0.18))])
    gap = None
    if steps:
        side, c, w = steps
        n = risers or max(1, int(round(deck_y / 0.15)))
        r = deck_y / n
        sm = step_mat or deck_mat
        for k in range(n):
            if side == "z0":
                zz = z0 - (k + 1) * 0.3
                mb.box(sm, (c - w / 2, 0, zz), (c + w / 2, deck_y - k * r, zz + 0.3), skip=("-y", "+z") if k == 0 else ("-y", "+z"))
            elif side == "x1":
                xx = x1 + k * 0.3
                mb.box(sm, (xx, 0, c - w / 2), (xx + 0.3, deck_y - k * r, c + w / 2), skip=("-y", "-x"))
            else:
                xx = x0 - (k + 1) * 0.3
                mb.box(sm, (xx, 0, c - w / 2), (xx + 0.3, deck_y - k * r, c + w / 2), skip=("-y", "+x"))
        run = n * 0.3
        if side == "z0":
            col.quad(COL_KEY, [c - w / 2, 0, z0 - run - 0.1], [c + w / 2, 0, z0 - run - 0.1], [c + w / 2, deck_y, z0], [c - w / 2, deck_y, z0], n=(0, 1, 0))
            gap = ("z0", c - w / 2, c + w / 2)
        elif side == "x1":
            col.quad(COL_KEY, [x1, deck_y, c - w / 2], [x1 + run + 0.1, 0, c - w / 2], [x1 + run + 0.1, 0, c + w / 2], [x1, deck_y, c + w / 2], n=(0, 1, 0))
            gap = ("x1", c - w / 2, c + w / 2)
        else:
            col.quad(COL_KEY, [x0 - run - 0.1, 0, c - w / 2], [x0, deck_y, c - w / 2], [x0, deck_y, c + w / 2], [x0 - run - 0.1, 0, c + w / 2], n=(0, 1, 0))
            gap = ("x0", c - w / 2, c + w / 2)
    if columns is None:
        columns = [(x0 + 0.1, z0 + 0.1), (x1 - 0.1, z0 + 0.1)]
    cm = col_mat or TRIM
    for (cx, cz) in columns:
        if col_mat is not None:     # tapered bungalow pier
            mb.cyl(cm, (cx, deck_y, cz), col_w * 2.4, col_h * 0.55, seg=4, r_top=col_w * 1.6, caps=("top",), smooth=False, a0=math.pi / 4)
            mb.box(TRIM, (cx - col_w, deck_y + col_h * 0.55, cz - col_w), (cx + col_w, deck_y + col_h - 0.1, cz + col_w), skip=("-y", "+y"))
        else:
            mb.box(TRIM, (cx - 0.11, deck_y, cz - 0.11), (cx + 0.11, deck_y + 0.25, cz + 0.11), skip=("-y",))
            mb.box(TRIM, (cx - col_w, deck_y + 0.25, cz - col_w), (cx + col_w, deck_y + col_h - 0.1, cz + col_w), skip=("-y", "+y"))
        mb.box(TRIM, (cx - 0.1, deck_y + col_h - 0.1, cz - 0.1), (cx + 0.1, deck_y + col_h, cz + 0.1), skip=())
        col.box(COL_KEY, (cx - 0.11, deck_y, cz - 0.11), (cx + 0.11, deck_y + col_h, cz + 0.11), skip=())
    if deck_y > 0.35:
        for r in rails:
            if r == "z0":
                segs = [(x0 + 0.1, x1 - 0.1)]
                if gap and gap[0] == "z0":
                    segs = [(x0 + 0.1, gap[1]), (gap[2], x1 - 0.1)]
                for a, b in segs:
                    if b - a > 0.2:
                        railing(mb, col, (a, z0 + 0.1), (b, z0 + 0.1), deck_y, 0.9, TRIM, TRIM)
            elif r in ("x0", "x1"):
                xx = x0 + 0.1 if r == "x0" else x1 - 0.1
                segs = [(z0 + 0.1, z1 - 0.05)]
                if gap and gap[0] == r:
                    segs = [(z0 + 0.1, gap[1]), (gap[2], z1 - 0.05)]
                for a, b in segs:
                    if b - a > 0.2:
                        railing(mb, col, (xx, a), (xx, b), deck_y, 0.9, TRIM, TRIM)
