"""Shared dimensions and model-spec helpers for the Greyhaven town kit."""
import math

import numpy as np

from .mesh import MB, T, Ry, nrm
from .gltf import COL_KEY

# ---- Street cross-section standard (metres) --------------------------------
ROAD_HALF = 3.5        # asphalt half width -> 7.0 m two-lane roadway
GUTTER = 0.25          # concrete gutter each side
EDGE = ROAD_HALF + GUTTER   # 3.75: road module half width (7.5 m)
CURB_H = 0.15          # curb height = sidewalk & lot level
CURB_W = 0.20          # curb top band
SW_W = 2.25            # sidewalk module width
ROW_HALF = EDGE + SW_W  # 6.0: street right-of-way half width (12 m)
SEG = 10.0             # straight module length
NODE = 12.0            # intersection / corner / dead-end footprint
LOT_Y = CURB_H         # lots, driveways, parking lots, terrain
MARK_Y = 0.006         # road paint sits 6 mm above asphalt
DECAL_Y = 0.004        # patches/puddles/grates


def model(name, vis, col=None, col_kind="colonly", extra=None, meta=None):
    """Assemble a model spec: <Name> root -> <Name>_Mesh, <Name>_Col-<kind>, extras."""
    children = [{"name": f"{name}_Mesh", "mb": vis}]
    cols = col if isinstance(col, list) else ([col] if col is not None else [])
    for i, c in enumerate(cols):
        children.append({"name": f"{name}_Col{i if len(cols) > 1 else ''}-{col_kind}", "mb": c})
    children += extra or []
    spec = {"name": name, "children": children}
    spec["meta"] = meta or {}
    return spec


def col_box(mn, mx, M=None):
    c = MB()
    c.box(COL_KEY, mn, mx, skip=())
    if M is not None:
        out = MB()
        out.merge(c, M)
        return out
    return c


def col_cyl(base, r, h, seg=8):
    c = MB()
    c.cyl(COL_KEY, base, r, h, seg=seg, caps=("top", "bottom"), smooth=False)
    return c


def marker(name, pos):
    """Empty helper node (attachment points, light positions, hinges)."""
    return {"name": name, "t": tuple(pos)}


def curb_chamfer_col(c, x_edge, z0, z1, top=CURB_H, inward=+1):
    """Walkable collision ramp replacing a vertical curb face.

    Runs from y=0 at 0.35 m into the road to curb height 0.15 m inside the
    sidewalk: ~17 degrees, well under CharacterBody3D's default 45 degree
    floor angle, so the player steps up naturally."""
    xa, xb = x_edge - 0.35 * inward, x_edge + 0.15 * inward
    c.quad(COL_KEY, [xa, 0, z0], [xb, top, z0], [xb, top, z1], [xa, 0, z1], n=(0, 1, 0))
