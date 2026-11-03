"""Turn furniture placements into (a) a static batched mesh per house and (b) instance lists for scenes."""
import math

import res_materials  # noqa: F401
from veil_mesh.mesh import MB, T, Ry
from veil_mesh.gltf import COL_KEY

_cache = {}


def specs():
    import furniture
    if not _cache:
        for fn in furniture.FURNITURE:
            m = fn()
            _cache[m["name"]] = m
    return _cache


def batch(instances, name):
    """Merge every piece (moving parts in their closed pose) into one visual MB + one trimesh collider."""
    sp = specs()
    vis, col = MB(), MB()
    for it in instances:
        M = T(it["x"], it["y"], it["z"]) @ Ry(it["yaw"])
        for ch in sp[it["model"]]["children"]:
            mb = ch.get("mb")
            if mb is None:
                continue
            Mc = M @ T(*(ch.get("t") or (0, 0, 0))) @ Ry(ch.get("yaw") or 0.0)
            if "colonly" in ch["name"]:
                if it.get("footprint"):              # only floor-standing pieces block the player
                    col.merge(_retag(mb), Mc)
            else:
                vis.merge(mb, Mc)
    children = [{"name": name + "_Mesh", "mb": vis}]
    if col.tri_count():
        children.append({"name": name + "_Col-colonly", "mb": col})
    return {"name": name, "children": children}


def _retag(mb):
    out = MB()
    for mat, g in mb.parts.items():
        d = out._g(COL_KEY)
        base = len(d["p"])
        d["p"] += g["p"]
        d["n"] += g["n"]
        d["uv"] += g["uv"]
        d["i"] += [i + base for i in g["i"]]
    return out
