"""Roads/ and Sidewalks/ modules.

Module conventions
------------------
* Segment modules (straight roads, sidewalks, composite streets) run along
  local +Z from z=0 to z=L. Ports: (0,0,0) facing -Z and (0,0,L) facing +Z.
* Node modules (intersections, sharp corner, dead end) are 12 x 12 m,
  centred on the origin, ports at the middle of each open side (+-6 m).
* Sidewalk modules sit on the road's right (+X) side: local x=0 is the curb
  face (road module edge, x=3.75 in road space), x=2.25 the property line.
  For the left side rotate 180 deg about Y.
* Asphalt y=0, sidewalks/lots y=0.15. Rural roads blend shoulders up to 0.15.
"""
import math

import numpy as np

from veil_mesh.mesh import MB, T, Ry, nrm
from veil_mesh.materials import m01, mt
from veil_mesh.gltf import COL_KEY
from veil_mesh.kit import (ROAD_HALF, GUTTER, EDGE, CURB_H, CURB_W, SW_W, ROW_HALF, SEG, NODE, LOT_Y,
                           MARK_Y, DECAL_Y, model, col_box, curb_chamfer_col)

ASPHALT = {"clean": "Road_Asphalt", "cracked": "Road_AsphaltCracked"}


def rng_of(name):
    import zlib
    return np.random.default_rng(zlib.crc32(name.encode()))


# ============================================================================
# Building blocks
# ============================================================================
def road_strip(mb, col, z0, z1, asphalt="Road_Asphalt"):
    """7.0 m asphalt + two 0.25 m gutters, along Z."""
    mb.ground_poly(m01(asphalt), [(-ROAD_HALF, z0), (ROAD_HALF, z0), (ROAD_HALF, z1), (-ROAD_HALF, z1)])
    for s in (-1, 1):
        xa, xb = sorted((s * ROAD_HALF, s * EDGE))
        mb.ground_poly(m01("Road_CurbConcrete"), [(xa, z0), (xb, z0), (xb, z1), (xa, z1)])
    if col is not None:
        col.ground_poly(COL_KEY, [(-EDGE, z0), (EDGE, z0), (EDGE, z1), (-EDGE, z1)])


def dashed_center(mb, z0, z1, dash=3.0, gap=2.0, offset=1.0):
    m = m01("Road_MarkingYellow")
    z = z0 + offset
    while z < z1 - 0.1:
        ze = min(z + dash, z1)
        mb.ground_poly(m, [(-0.06, z), (0.06, z), (0.06, ze), (-0.06, ze)], y=MARK_Y)
        z += dash + gap


def double_yellow(mb, z0, z1):
    m = m01("Road_MarkingYellow")
    for x in (-0.16, 0.06):
        mb.ground_poly(m, [(x, z0), (x + 0.1, z0), (x + 0.1, z1), (x, z1)], y=MARK_Y)


def edge_lines(mb, z0, z1):
    m = m01("Road_MarkingWhite")
    for x in (-3.36, 3.24):
        mb.ground_poly(m, [(x, z0), (x + 0.12, z0), (x + 0.12, z1), (x, z1)], y=MARK_Y)


def sidewalk_strip(mb, col, L, stations=None, ramp_x=1.0, top="Road_SidewalkConcrete", cracked=None):
    """Sidewalk along Z on the road's right side.

    stations: list of (z, curb_height) describing curb drops (driveways,
    ramps). Default: a full-height curb over the whole length."""
    if stations is None:
        stations = [(0.0, CURB_H), (L, CURB_H)]
    xs = [0.0, CURB_W, ramp_x, SW_W]
    curb_m, top_m = m01("Road_CurbConcrete"), m01(top)
    for i in range(len(stations) - 1):
        (za, ha), (zb, hb) = stations[i], stations[i + 1]
        if zb - za < 1e-6:
            continue

        def prof(h):
            return [h, h + (CURB_H - h) * (CURB_W / ramp_x), CURB_H, CURB_H]
        pa, pb = prof(ha), prof(hb)
        for k in range(3):
            mat = curb_m if k == 0 else top_m
            if k > 0 and cracked is not None:
                mat = cracked(za, zb) or top_m
            mb.quad(mat, [xs[k], pa[k], za], [xs[k], pa[k], zb], [xs[k + 1], pb[k + 1], zb], [xs[k + 1], pa[k + 1], za],
                    n=nrm([-(pa[k + 1] - pa[k]) / (xs[k + 1] - xs[k]), 1, 0]))
        if max(ha, hb) > 0.005:  # curb face
            mb.quad(curb_m, [0, 0, zb], [0, 0, za], [0, ha, za], [0, hb, zb], n=(-1, 0, 0))
        if col is not None:
            ca = [(-2.33 * ha, 0.0), (ha, ha), (ramp_x, CURB_H), (SW_W, CURB_H)]
            cb = [(-2.33 * hb, 0.0), (hb, hb), (ramp_x, CURB_H), (SW_W, CURB_H)]
            for k in range(3):
                col.quad(COL_KEY, [ca[k][0], ca[k][1], za], [cb[k][0], cb[k][1], zb],
                         [cb[k + 1][0], cb[k + 1][1], zb], [ca[k + 1][0], ca[k + 1][1], za], n=(0, 1, 0))


def drop_stations(L, center, width, flare, low):
    """Curb profile with a dropped section (driveway apron / curb ramp)."""
    a, b = center - width / 2, center + width / 2
    return [(0.0, CURB_H), (a - flare, CURB_H), (a, low), (b, low), (b + flare, CURB_H), (L, CURB_H)]


# ---- node modules (12 x 12) -------------------------------------------------
R_FILLET = 1.5


def _ramp_h(t, ramp):
    if not ramp:
        return CURB_H
    d = abs(t - 1.25 * math.pi)
    k = 1.0 if d < 0.26 else max(0.0, 1 - (d - 0.26) / 0.35)
    return CURB_H * (1 - k)


def _curb_face(mb, col, a, b, ha, hb, o):
    """Vertical curb face along 2D edge a->b (x,z), outward normal o toward the road."""
    if max(ha, hb) > 0.005:
        mb.quad(m01("Road_CurbConcrete"), [a[0], 0, a[1]], [b[0], 0, b[1]], [b[0], hb, b[1]], [a[0], ha, a[1]],
                n=(o[0], 0, o[1]))
    if col is not None and max(ha, hb) > 0.005:
        k = 2.33
        col.quad(COL_KEY, [a[0] + o[0] * k * ha, 0, a[1] + o[1] * k * ha], [b[0] + o[0] * k * hb, 0, b[1] + o[1] * k * hb],
                 [b[0] - o[0] * 0.01, hb, b[1] - o[1] * 0.01], [a[0] - o[0] * 0.01, ha, a[1] - o[1] * 0.01], n=(0, 1, 0))


def _gp(mb, col, mat, pts, heights=None):
    mb.ground_poly(m01(mat), pts, heights=heights)
    if col is not None:
        col.ground_poly(COL_KEY, pts, heights=heights)


def corner_quadrant(mb, col, sx, sz, ramp=True, seg=8):
    """Rounded curb corner between two open arms, quadrant (sx, sz)."""
    E, H, r, b = EDGE, ROW_HALF, R_FILLET, CURB_W
    C = (E + r, E + r)
    ts = [math.pi + (0.5 * math.pi) * i / seg for i in range(seg + 1)]   # 180..270 deg

    def P(x, z):
        return (sx * x, sz * z)

    arc_r = [(C[0] + r * math.cos(t), C[1] + r * math.sin(t)) for t in ts]
    arc_i = [(C[0] + (r - b) * math.cos(t), C[1] + (r - b) * math.sin(t)) for t in ts]
    hs = [_ramp_h(t, ramp) for t in ts]
    # asphalt fillet
    fil = [(E, E), (E + r, E)] + list(reversed(arc_r))[1:-1] + [(E, E + r)]
    _gp(mb, col, "Road_Asphalt", [P(*p) for p in fil])
    # curb band ring + faces
    for i in range(seg):
        q = [arc_r[i], arc_r[i + 1], arc_i[i + 1], arc_i[i]]
        hh = [hs[i], hs[i + 1], hs[i + 1], hs[i]]
        _gp(mb, col, "Road_CurbConcrete", [P(*p) for p in q], hh)
        tm = (ts[i] + ts[i + 1]) / 2
        _curb_face(mb, col, P(*arc_r[i]), P(*arc_r[i + 1]), hs[i], hs[i + 1], (sx * math.cos(tm), sz * math.sin(tm)))
    # straight curb bands
    _gp(mb, col, "Road_CurbConcrete", [P(E + r, E), P(H, E), P(H, E + b), P(E + r, E + b)])
    _curb_face(mb, col, P(E + r, E), P(H, E), CURB_H, CURB_H, (0, -sz))
    _gp(mb, col, "Road_CurbConcrete", [P(E, E + r), P(E + b, E + r), P(E + b, H), P(E, H)])
    _curb_face(mb, col, P(E, E + r), P(E, H), CURB_H, CURB_H, (-sx, 0))
    # sidewalk remainder (slopes down to the ramp at the arc)
    rem = [(E + r, E + b), (H, E + b), (H, H), (E + b, H)] + list(arc_i)
    rh = [CURB_H] * 4 + hs
    # arc_i runs 180->270: starts at (E+b, E+r) and ends at (E+r, E+b) (closing point dropped)
    _gp(mb, col, "Road_SidewalkConcrete", [P(*p) for p in rem[:-1]], rh[:-1])


def node_module(arms, ramps=True, asphalt="Road_Asphalt"):
    """Generic 12x12 node: arms is a subset of N,S,E,W (N = -Z)."""
    E, H, G = EDGE, ROW_HALF, GUTTER
    mb, col = MB(), MB()
    closed = [s for s in "NSEW" if s not in arms]
    # centre asphalt, shrunk where a side is closed (that side gets a gutter)
    x0 = -E + (G if "W" in closed else 0)
    x1 = E - (G if "E" in closed else 0)
    z0 = -E + (G if "N" in closed else 0)
    z1 = E - (G if "S" in closed else 0)
    mb.ground_poly(m01(asphalt), [(x0, z0), (x1, z0), (x1, z1), (x0, z1)])
    col.ground_poly(COL_KEY, [(x0, z0), (x1, z0), (x1, z1), (x0, z1)])
    # arms
    for a in arms:
        rot = {"S": 0, "N": math.pi, "E": math.pi / 2, "W": -math.pi / 2}[a]
        p, pc = MB(), MB()
        road_strip(p, pc, E, H, asphalt)
        mb.merge(p, Ry(rot))
        col.merge(pc, Ry(rot))
    # closed sides
    # where two closed sides meet, the second one must not overlap the first
    done = []
    for s in closed:
        closed_side_safe(mb, col, s, arms, done)
        done.append(s)
    # rounded corners between adjacent open arms
    for (sx, sz, ax, az) in ((1, 1, "E", "S"), (-1, 1, "W", "S"), (1, -1, "E", "N"), (-1, -1, "W", "N")):
        if ax in arms and az in arms:
            corner_quadrant(mb, col, sx, sz, ramp=ramps)
    return mb, col


def closed_side_safe(mb, col, side, arms, done):
    """Straight curb + sidewalk strip along a side that has no arm.

    Ownership rules (so neighbouring pieces never overlap or leave gaps):
    * gutters stop at +-E where the neighbour is an open arm (the arm owns its
      gutter) and at E-G where a perpendicular closed strip was built first;
    * the first closed strip of a corner owns the corner block; later strips
      stop at its curb band (E+b)."""
    E, H, b, G = EDGE, ROW_HALF, CURB_W, GUTTER
    rot = {"N": 0, "E": -math.pi / 2, "S": math.pi, "W": math.pi / 2}[side]
    left = {"N": "W", "E": "N", "S": "E", "W": "S"}[side]
    right = {"N": "E", "E": "S", "S": "W", "W": "N"}[side]
    lo_open, hi_open = left in arms, right in arms
    lo_done, hi_done = left in done, right in done
    gx0 = -E + G if lo_done else -E
    gx1 = E - G if hi_done else E
    bx0 = -H if lo_open else (-E if lo_done else -E - b)
    bx1 = H if hi_open else (E if hi_done else E + b)
    sx0 = -E - b if lo_done else -H
    sx1 = E + b if hi_done else H
    f0 = -H if lo_open else -E
    f1 = H if hi_open else E
    p, pc = MB(), MB()
    _gp(p, pc, "Road_CurbConcrete", [(gx0, -E), (gx1, -E), (gx1, -E + G), (gx0, -E + G)])
    _gp(p, pc, "Road_CurbConcrete", [(bx0, -E - b), (bx1, -E - b), (bx1, -E), (bx0, -E)], [CURB_H] * 4)
    _gp(p, pc, "Road_SidewalkConcrete", [(sx0, -H), (sx1, -H), (sx1, -E - b), (sx0, -E - b)], [CURB_H] * 4)
    _curb_face(p, pc, (f0, -E), (f1, -E), CURB_H, CURB_H, (0, 1))
    mb.merge(p, Ry(rot))
    col.merge(pc, Ry(rot))


# ============================================================================
# ROAD MODULES
# ============================================================================
def rd_straight(variant="clean", marking="dashed", name=None):
    name = name or "RD_Straight_2Lane_10m" + {"clean": "", "cracked": "_Cracked", "patched": "_Patched"}[variant]
    rng = rng_of(name)
    mb, col = MB(), MB()
    road_strip(mb, col, 0, SEG, ASPHALT.get(variant, "Road_Asphalt"))
    if marking == "dashed":
        dashed_center(mb, 0, SEG)
    elif marking == "double":
        double_yellow(mb, 0, SEG)
    if variant == "patched":
        _patch(mb, [(-2.6, 2.0), (-0.6, 1.8), (-0.4, 4.2), (-2.8, 4.4)])
        _patch(mb, [(0.8, 6.2), (3.2, 6.0), (3.3, 7.6), (1.6, 8.1), (0.7, 7.5)])
        _puddle(mb, 2.6, 3.0, 1.6, 1.0)
    return model(name, mb, col, meta=dict(kind="segment", length=SEG, width=2 * EDGE, port_type="road",
                                          ports=[((0, 0, 0), (0, 0, -1)), ((0, 0, SEG), (0, 0, 1))],
                                          footprint=(-EDGE, 0, EDGE, SEG)))


def _patch(mb, pts):
    mb.ground_poly(m01("Road_RoadPatch"), pts, y=DECAL_Y)


def _puddle(mb, cx, cz, w, d):
    m = mt("Puddle")
    pts = [(cx - w / 2, cz - d / 2), (cx + w / 2, cz - d / 2), (cx + w / 2, cz + d / 2), (cx - w / 2, cz + d / 2)]
    for (i, j, k) in ((0, 1, 2), (0, 2, 3)):
        tri = [np.array([pts[q][0], DECAL_Y + 0.001, pts[q][1]]) for q in (i, j, k)]
        uv = [((p[0] - pts[0][0]) / w, (p[2] - pts[0][1]) / d) for p in tri]
        mb.tri(m, *tri, n=(0, 1, 0), uv=uv)


def rd_node(name, arms, ports, crosswalks=False, ramps=True):
    mb, col = node_module(arms, ramps=ramps)
    return model(name, mb, col, meta=dict(kind="node", width=NODE, port_type="urban", ports=ports,
                                          footprint=(-6, -6, 6, 6)))


PORT = {"N": ((0, 0, -6), (0, 0, -1)), "S": ((0, 0, 6), (0, 0, 1)), "E": ((6, 0, 0), (1, 0, 0)),
        "W": ((-6, 0, 0), (-1, 0, 0))}


def rd_intersection_4way():
    return rd_node("RD_Intersection_4Way_12m", "NSEW", [PORT[a] for a in "NSEW"])


def rd_intersection_t():
    return rd_node("RD_Intersection_T_12m", "SEW", [PORT[a] for a in "SEW"])


def rd_corner_sharp():
    return rd_node("RD_Corner_Sharp_12m", "SE", [PORT[a] for a in "SE"])


def rd_dead_end():
    mb, col = node_module("S", ramps=False)
    # turning-hammerhead paint + end-of-road reflector posts are separate props
    return model("RD_DeadEnd_12m", mb, col, meta=dict(kind="node", width=NODE, port_type="urban",
                                                       ports=[PORT["S"]], footprint=(-6, -6, 6, 6)))


# ---- rural road with shoulders + gentle curves ---------------------------
RURAL_PROFILE = [  # (lateral distance from centre, height, material) - mirrored both sides
    (0.0, 0.0, "Road_Asphalt"), (ROAD_HALF, 0.0, "Road_Gravel"), (4.75, 0.10, "Grnd_GrassOvergrown"), (6.0, 0.15, None)]


def _rural_cross(mb, col, pts_fn, n_steps, s_len):
    """Sweep the rural cross-section along a path. pts_fn(i, d) -> (x, z)."""
    for side in (-1, 1):
        for k in range(len(RURAL_PROFILE) - 1):
            d0, h0, mat = RURAL_PROFILE[k]
            d1, h1, _ = RURAL_PROFILE[k + 1]
            for i in range(n_steps):
                a0, a1 = pts_fn(i, side * d0), pts_fn(i + 1, side * d0)
                b0, b1 = pts_fn(i, side * d1), pts_fn(i + 1, side * d1)
                quad = [a0, a1, b1, b0]
                hh = [h0, h0, h1, h1]
                mb.ground_poly(m01(mat), quad, heights=hh)
                col.ground_poly(COL_KEY, quad, heights=hh)


def rd_rural_straight():
    name = "RD_Shoulder_Rural_10m"
    mb, col = MB(), MB()
    _rural_cross(mb, col, lambda i, d: (d, i * SEG), 1, SEG)
    edge_lines(mb, 0, SEG)
    dashed_center(mb, 0, SEG)
    return model(name, mb, col, meta=dict(kind="segment", length=SEG, width=12, port_type="rural",
                                          ports=[((0, 0, 0), (0, 0, -1)), ((0, 0, SEG), (0, 0, 1))],
                                          footprint=(-6, 0, 6, SEG)))


def rd_transition():
    """Urban (curb + sidewalk) at z=0 -> rural (shoulders) at z=10."""
    name = "RD_Transition_UrbanToRural_10m"
    mb, col = MB(), MB()
    # asphalt through
    mb.ground_poly(m01("Road_Asphalt"), [(-ROAD_HALF, 0), (ROAD_HALF, 0), (ROAD_HALF, SEG), (-ROAD_HALF, SEG)])
    col.ground_poly(COL_KEY, [(-ROAD_HALF, 0), (ROAD_HALF, 0), (ROAD_HALF, SEG), (-ROAD_HALF, SEG)])
    dashed_center(mb, 0, SEG)
    edge_lines(mb, 5.0, SEG)
    for s in (-1, 1):
        part, pc = MB(), MB()
        # urban half (z 0..5): gutter + sidewalk
        part.ground_poly(m01("Road_CurbConcrete"), [(ROAD_HALF, 0), (EDGE, 0), (EDGE, 5), (ROAD_HALF, 5)])
        pc.ground_poly(COL_KEY, [(ROAD_HALF, 0), (EDGE, 0), (EDGE, 5), (ROAD_HALF, 5)])
        sw, swc = MB(), MB()
        sidewalk_strip(sw, swc, 5.0)
        part.merge(sw, T(EDGE, 0, 0))
        pc.merge(swc, T(EDGE, 0, 0))
        # sidewalk end face (curb returns to grade)
        part.quad(m01("Road_CurbConcrete"), [EDGE, 0, 5], [4.75, 0.10, 5], [4.75, CURB_H, 5], [EDGE, CURB_H, 5], n=(0, 0, 1))
        # rural half (z 5..10)
        rp, rpc = MB(), MB()
        _rural_cross_side(rp, rpc, 5.0, SEG)
        part.merge(rp)
        pc.merge(rpc)
        M = np.eye(4) if s > 0 else np.diag([-1.0, 1, 1, 1])
        mb.merge(part, M)
        col.merge(pc, M)
    return model(name, mb, col, meta=dict(kind="segment", length=SEG, width=12, port_type="urban>rural",
                                          ports=[((0, 0, 0), (0, 0, -1)), ((0, 0, SEG), (0, 0, 1))],
                                          footprint=(-6, 0, 6, SEG)))


def _rural_cross_side(mb, col, z0, z1):
    for k in range(len(RURAL_PROFILE) - 1):
        d0, h0, mat = RURAL_PROFILE[k]
        d1, h1, _ = RURAL_PROFILE[k + 1]
        if d0 < ROAD_HALF:
            continue
        q = [(d0, z0), (d0, z1), (d1, z1), (d1, z0)]
        mb.ground_poly(m01(mat), q, heights=[h0, h0, h1, h1])
        col.ground_poly(COL_KEY, q, heights=[h0, h0, h1, h1])


CURVE_R = 24.0


def rd_curve(direction):
    """Gentle 90-degree rural curve, centreline radius 24 m, 30 x 30 footprint.
    Entry at the origin travelling +Z. 'Right' bends toward -X (right-hand side
    when driving +Z in Godot's Y-up frame); 'Left' toward +X."""
    sgn = -1 if direction == "Right" else 1
    name = f"RD_Curve_Gentle_{direction}_30m"
    R = CURVE_R
    n = 12
    cx = sgn * R
    # explicit, readable parametrisation
    def P(i, d):
        t = (math.pi / 2) * i / n
        if sgn > 0:   # left: centre (+R, 0); start angle 180 deg, sweep toward 90 deg
            a = math.pi - t
            rad = R - d       # +d (x>0 side at the entry) is the inside of a left curve
        else:         # right: centre (-R, 0); start angle 0, sweep toward 90 deg
            a = t
            rad = R + d       # +d is the outside of a right curve
        return (cx + rad * math.cos(a), rad * math.sin(a))
    mb, col = MB(), MB()
    _rural_cross(mb, col, P, n, None)
    # markings: centre dashes and edge lines along the arc
    ym, yw = m01("Road_MarkingYellow"), m01("Road_MarkingWhite")
    for i in range(n):
        if i % 2 == 0:
            mb.ground_poly(ym, [P(i, -0.06), P(i + 1, -0.06), P(i + 1, 0.06), P(i, 0.06)], y=MARK_Y)
        for d0 in (-3.36, 3.24):
            mb.ground_poly(yw, [P(i, d0), P(i + 1, d0), P(i + 1, d0 + 0.12), P(i, d0 + 0.12)], y=MARK_Y)
    # ground fill for the rest of the 30 x 30 footprint (inside and outside the bend)
    gm = "Grnd_GrassOvergrown"
    inner = [P(i, 6 * sgn) for i in range(n + 1)]
    outer = [P(i, -6 * sgn) for i in range(n + 1)]
    _fill(mb, col, gm, [(cx, 0.0)] + inner)
    _fill(mb, col, gm, outer + [(-6.0 * sgn, 30.0)])
    exitp = ((sgn * R, 0, R), (sgn, 0, 0))
    fp = (-6, 0, 24, 30) if sgn > 0 else (-24, 0, 6, 30)
    return model(name, mb, col, meta=dict(kind="curve", radius=R, port_type="rural",
                                          ports=[((0, 0, 0), (0, 0, -1)), exitp], footprint=fp))


def _fill(mb, col, mat, pts):
    mb.ground_poly(m01(mat), pts, y=LOT_Y)
    col.ground_poly(COL_KEY, pts, y=LOT_Y)


# ---- composite streets ---------------------------------------------------------
def rd_street(kind):
    name = f"RD_Street_{kind}_10m"
    mb, col = MB(), MB()
    if kind == "Residential":
        road_strip(mb, col, 0, SEG, "Road_Asphalt")
    else:
        road_strip(mb, col, 0, SEG, "Road_AsphaltCracked")
        double_yellow(mb, 0, SEG)
        for x in (-2.1, 2.0):  # faded parking-lane edge lines
            mb.ground_poly(m01("Road_MarkingWhite"), [(x, 0.5), (x + 0.1, 0.5), (x + 0.1, 9.5), (x, 9.5)], y=MARK_Y)
    for side in (1, -1):
        sw, swc = MB(), MB()
        sidewalk_strip(sw, swc, SEG, top="Road_SidewalkConcrete" if kind == "Residential" else "Com_StorefrontConcrete")
        M = T(EDGE, 0, 0) if side > 0 else T(-EDGE, 0, SEG) @ Ry(math.pi)
        mb.merge(sw, M)
        col.merge(swc, M)
    return model(name, mb, col, meta=dict(kind="segment", length=SEG, width=12, port_type="urban",
                                          ports=[((0, 0, 0), (0, 0, -1)), ((0, 0, SEG), (0, 0, 1))],
                                          footprint=(-6, 0, 6, SEG)))


# ---- lots, driveways, alleys, patches, markings -------------------------------
def rd_parking_lot():
    name = "RD_ParkingLot_10x20m"
    mb, col = MB(), MB()
    _fill(mb, col, "Road_ParkingLotAsphalt", [(-5, 0), (5, 0), (5, 20), (-5, 20)])
    w = m01("Road_MarkingWhite")
    for x in (-5.0, -2.5, 0.0, 2.5):
        for (z0, z1) in ((0.3, 5.3), (14.7, 19.7)):
            mb.ground_poly(w, [(x, z0), (x + 0.1, z0), (x + 0.1, z1), (x, z1)], y=LOT_Y + MARK_Y)
    for x in (-3.75, -1.25, 1.25, 3.75):  # concrete wheel stops: the far row only (cars drive in across the
        for z in (19.1,):                    # street-side row, so stops there were driven through)
            mb.box(m01("Road_CurbConcrete"), (x - 0.85, LOT_Y, z - 0.08), (x + 0.85, LOT_Y + 0.1, z + 0.08))
    return model(name, mb, col, meta=dict(kind="lot", footprint=(-5, 0, 5, 20)))


def rd_driveway():
    name = "RD_Driveway_3x8m"
    mb, col = MB(), MB()
    _fill(mb, col, "Road_SidewalkConcrete", [(-1.5, 0), (1.5, 0), (1.5, 8), (-1.5, 8)])
    m = blob_patch(name, (0.2, 5.0), 0.5)
    mb.ground_poly(m01("Road_RoadPatch"), m, y=LOT_Y + DECAL_Y)   # old oil stain
    return model(name, mb, col, meta=dict(kind="lot", footprint=(-1.5, 0, 1.5, 8)))


def blob_patch(name, c, r, n=9):
    rng = rng_of(name + "blob")
    return [(c[0] + r * (0.75 + 0.35 * rng.random()) * math.cos(2 * math.pi * k / n),
             c[1] + r * (0.75 + 0.35 * rng.random()) * math.sin(2 * math.pi * k / n)) for k in range(n)]


def rd_alley():
    name = "RD_Alley_4x10m"
    mb, col = MB(), MB()
    y = LOT_Y
    mb.ground_poly(m01("Road_Gravel"), [(-2, 0), (-1.5, 0), (-1.5, 10), (-2, 10)], y=y)
    mb.ground_poly(m01("Road_Gravel"), [(1.5, 0), (2, 0), (2, 10), (1.5, 10)], y=y)
    mb.ground_poly(m01("Road_AsphaltCracked"), [(-1.5, 0), (-0.25, 0), (-0.25, 10), (-1.5, 10)], heights=[y + 0.03, y, y, y + 0.03])
    mb.ground_poly(m01("Road_AsphaltCracked"), [(0.25, 0), (1.5, 0), (1.5, 10), (0.25, 10)], heights=[y, y + 0.03, y + 0.03, y])
    mb.ground_poly(m01("Road_CurbConcrete"), [(-0.25, 0), (0.25, 0), (0.25, 10), (-0.25, 10)], y=y)  # centre drain
    col.ground_poly(COL_KEY, [(-2, 0), (2, 0), (2, 10), (-2, 10)], y=y)
    pud = MB()
    _puddle(pud, 0.3, 6.5, 1.2, 0.8)
    mb.merge(pud, T(0, y, 0))
    return model(name, mb, col, meta=dict(kind="segment", length=10, width=4, port_type="alley",
                                          ports=[((0, y, 0), (0, 0, -1)), ((0, y, 10), (0, 0, 1))],
                                          footprint=(-2, 0, 2, 10)))


def rd_patch(letter):
    name = f"RD_RoadPatch_{letter}"
    mb = MB()
    pts = blob_patch(name, (0, 0), 1.0 if letter == "A" else 1.7, n=7)
    if letter == "A":
        pts = [(-1.0, -0.7), (1.0, -0.7), (1.0, 0.7), (-1.0, 0.7)]
    mb.ground_poly(m01("Road_RoadPatch"), pts, y=DECAL_Y)
    return model(name, mb, None, meta=dict(kind="decal"))


def decal_puddle(letter):
    name = f"RD_Puddle_{letter}"
    mb = MB()
    w, d = (2.0, 1.4) if letter == "A" else (1.2, 0.8)
    _puddle(mb, 0, 0, w, d)
    return model(name, mb, None, meta=dict(kind="decal"))


def marking(kind):
    name = f"RD_Marking_{kind}"
    mb = MB()
    w, yl = m01("Road_MarkingWhite"), m01("Road_MarkingYellow")
    if kind == "DashedCenter_10m":
        dashed_center(mb, 0, SEG)
    elif kind == "DoubleYellow_10m":
        double_yellow(mb, 0, SEG)
    elif kind == "EdgeLines_10m":
        edge_lines(mb, 0, SEG)
    elif kind == "StopBar_3.5m":
        mb.ground_poly(w, [(0, 0), (ROAD_HALF, 0), (ROAD_HALF, 0.45), (0, 0.45)], y=MARK_Y)
    elif kind == "Arrow_Straight":
        pts = [(-0.15, 0), (0.15, 0), (0.15, 3.0), (0.45, 3.0), (0, 4.0), (-0.45, 3.0), (-0.15, 3.0)]
        mb.ground_poly(w, pts, y=MARK_Y)
    elif kind == "ParkingStall_2.5x5m":
        for x in (0.0, 2.4):
            mb.ground_poly(w, [(x, 0), (x + 0.1, 0), (x + 0.1, 5), (x, 5)], y=MARK_Y)
    return model(name, mb, None, meta=dict(kind="marking"))


def sw_crosswalk():
    """Continental crosswalk spanning the 7 m roadway, 2.25 m deep (fits an
    intersection arm)."""
    name = "SW_Crosswalk_7m"
    mb = MB()
    w = m01("Road_MarkingWhite")
    x = -3.3
    while x < 3.3:
        mb.ground_poly(w, [(x, 0.15), (x + 0.45, 0.15), (x + 0.45, 2.1), (x, 2.1)], y=MARK_Y)
        x += 0.9
    return model(name, mb, None, meta=dict(kind="marking", footprint=(-3.5, 0, 3.5, 2.25)))


# ============================================================================
# SIDEWALK MODULES
# ============================================================================
def sw_module(name, L, stations=None, ramp_x=1.0, cracked=False, extra=None):
    mb, col = MB(), MB()
    crack_fn = None
    if cracked:
        rng = rng_of(name)
        bad = set(int(v) for v in rng.choice(int(L), size=max(1, int(L) // 3), replace=False))
        crack_fn = lambda za, zb: m01("Road_ConcreteCracked") if int(za) in bad else None  # noqa: E731
    if cracked:
        st = [(float(z), CURB_H) for z in range(int(L) + 1)]
        sidewalk_strip(mb, col, L, st, ramp_x, cracked=crack_fn)
    else:
        sidewalk_strip(mb, col, L, stations, ramp_x)
    if extra:
        extra(mb, col)
    return model(name, mb, col, meta=dict(kind="sidewalk", length=L, width=SW_W, port_type="sidewalk",
                                          ports=[((0, 0, 0), (0, 0, -1)), ((0, 0, L), (0, 0, 1))],
                                          footprint=(0, 0, SW_W, L)))


def sw_storm_drain():
    def extra(mb, col):
        # dark inlet recess cut into the curb face + grate in the gutter
        tar = m01("Road_RoadPatch")
        mb.quad(tar, [0.004, 0.025, 6.1], [0.004, 0.025, 3.9], [0.004, 0.115, 3.9], [0.004, 0.115, 6.1], n=(-1, 0, 0))
        g = mt("DrainGrate")
        quad = [(-0.5, 4.3), (-0.02, 4.3), (-0.02, 5.7), (-0.5, 5.7)]
        for (i, j, k) in ((0, 1, 2), (0, 2, 3)):
            tri = [np.array([quad[q][0], DECAL_Y, quad[q][1]]) for q in (i, j, k)]
            uv = [((p[2] - 4.3) / 1.4, (p[0] + 0.5) / 0.48) for p in tri]
            mb.tri(g, *tri, n=(0, 1, 0), uv=uv)
        mb.box(m01("Road_CurbConcrete"), (0.0, 0.115, 3.85), (0.06, CURB_H, 6.15), skip=("-y", "+y"))
    return sw_module("SW_StormDrain_10m", SEG, extra=extra)


def sw_curb_only():
    """Road-edge curb with no sidewalk (curb + 0.25 m top band), for verges."""
    name = "SW_Curb_10m"
    mb, col = MB(), MB()
    cm = m01("Road_CurbConcrete")
    mb.ground_poly(cm, [(0, 0), (0.25, 0), (0.25, SEG), (0, SEG)], y=CURB_H)
    mb.quad(cm, [0, 0, SEG], [0, 0, 0], [0, CURB_H, 0], [0, CURB_H, SEG], n=(-1, 0, 0))
    col.ground_poly(COL_KEY, [(0.15, 0), (0.25, 0), (0.25, SEG), (0.15, SEG)], y=CURB_H)
    curb_chamfer_col(col, 0.0, 0, SEG)
    return model(name, mb, col, meta=dict(kind="sidewalk", length=SEG, width=0.25, port_type="curb",
                                          ports=[((0, 0, 0), (0, 0, -1)), ((0, 0, SEG), (0, 0, 1))],
                                          footprint=(0, 0, 0.25, SEG)))


def sw_gutter():
    name = "SW_Gutter_10m"
    mb, col = MB(), MB()
    cm = m01("Road_CurbConcrete")
    mb.ground_poly(cm, [(0, 0), (0.25, 0), (0.25, SEG), (0, SEG)], heights=[0.0, -0.03, -0.03, 0.0])
    mb.ground_poly(cm, [(0.25, 0), (0.5, 0), (0.5, SEG), (0.25, SEG)], heights=[-0.03, 0.0, 0.0, -0.03])
    col.ground_poly(COL_KEY, [(0, 0), (0.5, 0), (0.5, SEG), (0, SEG)])
    return model(name, mb, col, meta=dict(kind="sidewalk", length=SEG, width=0.5, port_type="gutter",
                                          ports=[((0, 0, 0), (0, 0, -1)), ((0, 0, SEG), (0, 0, 1))],
                                          footprint=(0, 0, 0.5, SEG)))


def sw_corner():
    name = "SW_Corner_Rounded"
    mb, col = MB(), MB()
    corner_quadrant(mb, col, 1, 1, ramp=True)
    # recentre so the module's outer corner is at the origin-facing quadrant
    return model(name, mb, col, meta=dict(kind="sidewalk", footprint=(EDGE, EDGE, ROW_HALF, ROW_HALF),
                                          note="Quadrant (+X,+Z) of a 12 m node: curb arc r=1.5 m with ramp"))


def sw_parking_edge():
    name = "SW_ParkingLotEdge_10m"
    mb, col = MB(), MB()
    cm = m01("Road_CurbConcrete")
    mb.box(cm, (-0.1, LOT_Y, 0), (0.1, LOT_Y + 0.15, SEG), skip=("-y", "-z", "+z"))
    mb.ground_poly(m01("Grnd_GrassDry"), [(0.1, 0), (1.0, 0), (1.0, SEG), (0.1, SEG)], y=LOT_Y)
    col.box(COL_KEY, (-0.1, LOT_Y, 0), (0.1, LOT_Y + 0.15, SEG), skip=())
    return model(name, mb, col, col_kind="convcolonly",
                 meta=dict(kind="sidewalk", length=SEG, footprint=(-0.1, 0, 1.0, SEG),
                           note="Raised 15 cm lot-edge curb (car stop) + 0.9 m dry-grass strip"))


ROAD_MODELS = [
    ("Roads", lambda: rd_straight("clean")),
    ("Roads", lambda: rd_straight("cracked")),
    ("Roads", lambda: rd_straight("patched")),
    ("Roads", lambda: rd_straight("clean", marking="none", name="RD_Straight_2Lane_10m_Unmarked")),
    ("Roads", rd_intersection_4way),
    ("Roads", rd_intersection_t),
    ("Roads", lambda: rd_curve("Left")),
    ("Roads", lambda: rd_curve("Right")),
    ("Roads", rd_corner_sharp),
    ("Roads", rd_dead_end),
    ("Roads", lambda: rd_street("Residential")),
    ("Roads", lambda: rd_street("Commercial")),
    ("Roads", rd_parking_lot),
    ("Roads", rd_driveway),
    ("Roads", rd_alley),
    ("Roads", rd_rural_straight),
    ("Roads", rd_transition),
    ("Roads", lambda: rd_patch("A")),
    ("Roads", lambda: rd_patch("B")),
    ("Roads", lambda: decal_puddle("A")),
    ("Roads", lambda: decal_puddle("B")),
    ("Roads", lambda: marking("DashedCenter_10m")),
    ("Roads", lambda: marking("DoubleYellow_10m")),
    ("Roads", lambda: marking("EdgeLines_10m")),
    ("Roads", lambda: marking("StopBar_3.5m")),
    ("Roads", lambda: marking("Arrow_Straight")),
    ("Roads", lambda: marking("ParkingStall_2.5x5m")),
    ("Sidewalks", lambda: sw_module("SW_Straight_10m", SEG)),
    ("Sidewalks", lambda: sw_module("SW_Straight_5m", 5.0)),
    ("Sidewalks", lambda: sw_module("SW_Straight_2m", 2.0)),
    ("Sidewalks", lambda: sw_module("SW_Straight_10m_Cracked", SEG, cracked=True)),
    ("Sidewalks", lambda: sw_module("SW_DrivewayTransition_10m", SEG, drop_stations(SEG, 5.0, 3.0, 0.6, 0.02), ramp_x=1.0)),
    ("Sidewalks", lambda: sw_module("SW_CurbRamp_10m", SEG, drop_stations(SEG, 5.0, 1.8, 0.9, 0.0), ramp_x=1.5)),
    ("Sidewalks", sw_storm_drain),
    ("Sidewalks", sw_curb_only),
    ("Sidewalks", sw_gutter),
    ("Sidewalks", sw_corner),
    ("Sidewalks", sw_parking_edge),
    ("Sidewalks", sw_crosswalk),
]
