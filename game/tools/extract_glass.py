"""Extract window-glass panes from the Pack 04 building GLBs -> game/data/glass_panes.json.
The glass is a material inside each building's exterior mesh and has no collision above the sills, so cameras
and line-of-sight checks went straight through it. The game turns these boxes into thin static colliders.
Run: python3 game/tools/extract_glass.py   (from the repository root)"""
import glob, json, os, struct
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
GLASS = ("WindowGlass", "Glass")


def load(p):
    b = open(p, "rb").read()
    jl = struct.unpack("<I", b[12:16])[0]
    js = json.loads(b[20:20 + jl])
    off = 20 + jl
    bl = struct.unpack("<I", b[off:off + 4])[0]
    return js, b[off + 8:off + 8 + bl]


def acc(js, binb, i):
    a = js["accessors"][i]
    bv = js["bufferViews"][a["bufferView"]]
    n = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[a["type"]]
    dt = {5126: np.float32, 5125: np.uint32, 5123: np.uint16, 5121: np.uint8}[a["componentType"]]
    o = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    arr = np.frombuffer(binb, dt, a["count"] * n, o)
    return arr.reshape(-1, n) if n > 1 else arr


def node_mats(js):
    """world matrix of every node (scene root = identity)"""
    M = {}

    def local(n):
        if "matrix" in n:
            return np.array(n["matrix"]).reshape(4, 4).T
        t = np.eye(4)
        x, y, z, w = n.get("rotation", [0, 0, 0, 1])
        R = np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                      [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                      [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])
        S = np.diag(n.get("scale", [1, 1, 1]))
        t[:3, :3] = R @ S
        t[:3, 3] = n.get("translation", [0, 0, 0])
        return t

    def walk(i, parent):
        m = parent @ local(js["nodes"][i])
        M[i] = m
        for c in js["nodes"][i].get("children", []):
            walk(c, m)

    for r in js["scenes"][js.get("scene", 0)]["nodes"]:
        walk(r, np.eye(4))
    return M


def panes(path):
    js, binb = load(path)
    mats = [m["name"] for m in js.get("materials", [])]
    M = node_mats(js)
    out = []
    for ni, n in enumerate(js["nodes"]):
        if "mesh" not in n or n["name"].startswith("INT_"):
            continue                                   # doors are separate (they move); only fixed panes here
        for pr in js["meshes"][n["mesh"]]["primitives"]:
            if pr.get("material") is None or not any(g in mats[pr["material"]] for g in GLASS):
                continue
            P = acc(js, binb, pr["attributes"]["POSITION"]).astype(float)
            P = (M[ni] @ np.c_[P, np.ones(len(P))].T).T[:, :3]
            I = acc(js, binb, pr["indices"]).reshape(-1, 3)
            # connected components over shared (rounded) positions
            key = {tuple(np.round(p, 3)): k for k, p in enumerate(P)}
            canon = np.array([key[tuple(np.round(p, 3))] for p in P])
            parent = list(range(len(P)))

            def find(a):
                while parent[a] != a:
                    parent[a] = parent[parent[a]]
                    a = parent[a]
                return a
            for t in I:
                a, b, c = (find(canon[v]) for v in t)
                parent[b] = a
                parent[find(c)] = a
            groups = {}
            for t in I:
                groups.setdefault(find(canon[t[0]]), []).extend(t.tolist())
            for vs in groups.values():
                Q = P[np.unique(vs)]
                mn, mx = Q.min(0), Q.max(0)
                if (mx - mn).max() < 0.15:
                    continue
                out.append([np.round(mn, 3).tolist(), np.round(mx, 3).tolist()])
    return out


res = {}
for p in sorted(glob.glob(os.path.join(ROOT, "THE_VEIL_ASSETS_V2/04_Commercial/**/COM_*.glb"), recursive=True)):
    if "Furnishing" in p or "/Merchandise/" in p or "/Shared_Props/" in p:
        continue                                   # buildings only: prop glass (coolers, cases) stays click-through
    pp = panes(p)
    if pp:
        res["res://" + os.path.relpath(p, ROOT).replace(os.sep, "/")] = pp
json.dump(res, open(os.path.join(ROOT, "game/data/glass_panes.json"), "w"), indent=1)
for k, v in res.items():
    print(os.path.basename(k), len(v), "panes")
