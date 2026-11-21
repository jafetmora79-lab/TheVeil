"""Adds infill trees to game/world/scatter.json (run once; it is idempotent: it refuses to run twice).
A new tree is only added in the middle of woods (>= 5 trees within 10 m and one within 6 m) so it never lands on a road, a lot or in the town.
   python game/tools/densify_trees.py
"""
import json, math, random, sys
p = "game/world/scatter.json"
d = json.load(open(p))
if d.get("densified"):
    sys.exit("already densified")
random.seed(2611)
trees = [i for i in d["items"] if i[0].startswith("VG_Tree")]
cell = 10.0
grid = {}
for t in trees:
    grid.setdefault((int(t[1] // cell), int(t[2] // cell)), []).append(t)
def near(x, z, r):
    out = []
    for gx in range(int(x // cell) - 2, int(x // cell) + 3):
        for gz in range(int(z // cell) - 2, int(z // cell) + 3):
            for t in grid.get((gx, gz), []):
                if math.hypot(t[1] - x, t[2] - z) <= r:
                    out.append(t)
    return out
add = []
for t in trees:
    if random.random() > 0.45:
        continue
    a = random.random() * math.tau
    r = random.uniform(3.0, 7.0)
    x, z = t[1] + math.cos(a) * r, t[2] + math.sin(a) * r
    if len(near(x, z, 10.0)) < 5 or not near(x, z, 6.0) or any(math.hypot(q[1] - x, q[2] - z) < 2.4 for q in near(x, z, 2.4)):
        continue
    add.append([t[0], round(x, 3), round(z, 3), round(random.random() * math.tau, 4)])
    grid.setdefault((int(x // cell), int(z // cell)), []).append(add[-1])
d["items"].extend(add)
d["densified"] = True
json.dump(d, open(p, "w"), separators=(",", ":"))
print("added", len(add), "trees; now", len(trees) + len(add))
