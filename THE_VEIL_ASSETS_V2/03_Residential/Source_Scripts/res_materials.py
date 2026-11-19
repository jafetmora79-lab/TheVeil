"""Pack 03 material registry - extends the shared Pack 02 registry (veil_mesh.materials.MATS).

Pack 01 materials:  m01("Int_FloorboardsOld")   -> M_Int_FloorboardsOld.tres  (Pack 01)
Pack 02 materials:  mt("PaintRed")              -> M_Town_PaintRed.tres       (Pack 02)
Pack 03 materials:  mr("FabricPlaid")           -> M_Res_FabricPlaid.tres     (this pack)
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "02_Town", "Source_Scripts"))
sys.path.insert(0, os.path.join(HERE, "..", "..", "Source_Scripts"))

from veil_mesh.materials import MATS, V2, _reg, m01, mt, town_tres  # noqa: E402,F401

RES = os.path.join(V2, "03_Residential")

# name: (texture or None, uv scale, alpha, double, repeat, roughness, metallic, extra)
RES_MAT_SPECS = {
    "FabricPlaid": ("FabricPlaid", 1.0, "OPAQUE", False, True, 1.0, 0.0, {}),
    "Quilt": ("Quilt", 1.0, "OPAQUE", False, True, 1.0, 0.0, {}),
    "Gingham": ("Gingham", 1.0, "OPAQUE", True, True, 1.0, 0.0, {}),
    "Formica": ("Formica", 1.0, "OPAQUE", False, True, 0.4, 0.0, {}),
    "Porcelain": ("Porcelain", 2.0, "OPAQUE", False, True, 0.2, 0.0, {}),
    "Mirror": ("Mirror", 1.0, "OPAQUE", False, False, 0.05, 0.6, {}),
    "EnamelHarvest": ("EnamelHarvest", 2.0, "OPAQUE", False, True, 0.35, 0.1, {}),
    "WoodPanel": ("WoodPanel", 1.0, "OPAQUE", False, True, 0.7, 0.0, {}),
    "Insulation": ("Insulation", 1.0, "OPAQUE", False, True, 1.0, 0.0, {}),
    "Pegboard": ("Pegboard", 2.0, "OPAQUE", False, True, 0.9, 0.0, {}),
    "Lattice": ("Lattice", 2.0, "MASK", True, True, 0.9, 0.0, {}),
    "GarageDoor": ("GarageDoor", 1.0, "OPAQUE", False, True, 0.6, 0.2, {}),
    "Shutter": ("Shutter", 1.0, "OPAQUE", False, False, 0.8, 0.0, {}),
    "RugBraided": ("RugBraided", 1.0, "OPAQUE", False, False, 1.0, 0.0, {}),
    "Lampshade": ("Lampshade", 2.0, "OPAQUE", True, True, 0.9, 0.0, {"emission": (1.0, 0.78, 0.5), "energy": 0.6}),
    "DetailAtlas": ("DetailAtlas", 1.0, "OPAQUE", False, False, 0.6, 0.0, {}),
    "DetailAtlasGlow": ("DetailAtlas", 1.0, "OPAQUE", False, False, 0.3, 0.0, {"emission": (1.0, 1.0, 1.0), "energy": 0.9}),
    "BulbGlow": (None, 1.0, "OPAQUE", False, True, 0.3, 0.0, {"color": (1.0, 0.92, 0.75, 1), "emission": (1.0, 0.85, 0.6), "energy": 2.0}),
}


def mr(name):
    full = "M_Res_" + name
    if full not in MATS:
        tex, uv, alpha, dbl, rep, rough, metal, extra = RES_MAT_SPECS[name]
        png = os.path.join(RES, "Textures", f"T_Res_{tex}.png") if tex else None
        _reg(full, png=png, tres=f"03_Residential/Materials/{full}.tres", uv=(uv, uv), alpha=alpha, double=dbl,
             repeat=rep, rough=rough, metal=metal, pack="03", **extra)
    return full


def all_res_materials():
    return [mr(k) for k in RES_MAT_SPECS]


def resolve(name):
    """Register any material name used in a GLB (validator helper)."""
    if name.startswith("M_Res_"):
        return mr(name[6:])
    if name.startswith("M_Town_"):
        return mt(name[7:])
    return m01(name[2:])
