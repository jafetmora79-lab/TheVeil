"""Fills the empty woods with trees (run once; idempotent via the "forest_filled" flag in game/world/scatter.json).
The first scatter only planted a band of woods along the roads (so the forest looked like squares / strips); this plants the rest of the
woods ground (the Overgrown / Leaves / Dead-vegetation cells of generated/TOWN_Ground_Game.glb, i.e. everything that is not road, lot,
lawn or built) on a jittered grid, keeping 3.5 m clear of anything that is not woods and 4 m from an existing tree.
New trees get a 5th field = 1: "no collision" (they are deeper than the world edge lets the player go; saves ~thousands of shapes).
   python game/tools/fill_forest.py
"""
import json, math, random, struct, sys
import numpy as np

SC = "game/world/scatter.json"
GLB = "game/world/generated/TOWN_Ground_Game.glb"
d = json.load(open(SC))
if d.get("forest_filled"):
    sys.exit("already filled")

# ---- the woods cells of the ground mesh -> a 1 m grid
b = open(GLB, "rb").read()
jl = struct.unpack("<I", b[12:16])[0]
j = json.loads(b[20:20 + jl])
bin0 = 20 + jl + 8
mats = [m["name"] for m in j["materials"]]
mesh = next(m for m in j["meshes"] if "Col" not in m["name"])
X0, Z0, X1, Z1 = -160, -160, 400, 600
nx, nz = X1 - X0, Z1 - Z0
free = np.zeros((nz, nx), bool)
solid = np.zeros((nz, nx), bool)          # ground that exists but is not woods (roads, lots, lawn...)
def acc(i):
    a = j["accessors"][i]; v = j["bufferViews"][a["bufferView"]]
    return a, bin0 + v.get("byteOffset", 0) + a.get("byteOffset", 0)
for p in mesh["primitives"]:
    name = mats[p["material"]]
    pa, po = acc(p["attributes"]["POSITION"])
    pos = np.frombuffer(b, "<f4", pa["count"] * 3, po).reshape(-1, 3)
    ia, io = acc(p["indices"])
    idx = np.frombuffer(b, {5123: "<u2", 5125: "<u4"}[ia["componentType"]], ia["count"], io).astype(int)
    tri = pos[idx].reshape(-1, 3, 3)
    mn, mx = tri.min(1), tri.max(1)
    woods = name in ("M_Grnd_GrassOvergrown", "M_Grnd_LeavesFallen", "M_Grnd_DeadVegetation")
    for lo, hi in zip(mn, mx):
        i0, i1 = int(math.floor(lo[0] - X0)), int(math.ceil(hi[0] - X0))
        k0, k1 = int(math.floor(lo[2] - Z0)), int(math.ceil(hi[2] - Z0))
        (free if woods else solid)[max(k0, 0):k1, max(i0, 0):i1] = True
free &= ~solid
print("woods cells", int(free.sum()), "m2")

# ---- existing trees
trees = [i for i in d["items"] if i[0].startswith("VG_Tree")]
cell = 8.0
grid = {}
def put(t):
    grid.setdefault((int(t[1] // cell), int(t[2] // cell)), []).append(t)
for t in trees:
    put(t)
def close(x, z, r):
    for gx in range(int(x // cell) - 1, int(x // cell) + 2):
        for gz in range(int(z // cell) - 1, int(z // cell) + 2):
            for t in grid.get((gx, gz), []):
                if math.hypot(t[1] - x, t[2] - z) < r:
                    return True
    return False
def clear(x, z, m):
    i, k = int(x - X0), int(z - Z0)
    m = int(math.ceil(m))
    if i - m < 0 or k - m < 0 or i + m >= nx or k + m >= nz:
        return False
    return free[k - m:k + m + 1, i - m:i + m + 1].all()

random.seed(4021)
add = []
step = 6.5
z = Z0 + 3.0
while z < Z1:
    x = X0 + 3.0
    while x < X1:
        px, pz = x + random.uniform(-2.6, 2.6), z + random.uniform(-2.6, 2.6)
        if clear(px, pz, 3.5) and not close(px, pz, 4.0):
            r = random.random()
            mdl = ("VG_Tree_Pine" if r < 0.55 else "VG_Tree_DeciduousSmall" if r < 0.70 else
                   "VG_Tree_DeciduousLarge" if r < 0.82 else "VG_Tree_Dead" if r < 0.93 else "VG_Tree_Overgrown")
            t = [mdl, round(px, 3), round(pz, 3), round(random.random() * math.tau, 4), 1]
            add.append(t); put(t)
        x += step
    z += step
d["items"].extend(add)
d["forest_filled"] = True
json.dump(d, open(SC, "w"), separators=(",", ":"))
print("added", len(add), "trees; now", len(trees) + len(add))
