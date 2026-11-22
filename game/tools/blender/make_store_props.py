"""THE VEIL - interior props for the gas station and the clothing stores (review notes #42 / #43: "give inside assets to this place and make it lootable"):
a double-sided stocked gondola shelf, a counter with a register, a clothes rack with hanging garments, a table of folded clothes, a shoe shelf.
   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --python game/tools/blender/make_store_props.py
Output: game/prototypes/store_props/ST_*.glb (front +Z in Godot, origin = floor level at the centre)."""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import make_story_props as P
import make_market_props as M

OUT = os.path.join(P.ROOT, "game", "prototypes", "store_props")
os.makedirs(OUT, exist_ok=True)
P.OUT = OUT
COLS = M.COLS


def Y(g):          # Godot (x, y, z) centre -> the Acc call order (Blender: x, -z, y)
    return (g[0], -g[2], g[1])


def gb(A, c, s, m, **kw):
    A.box((c[0], -c[2], c[1]), (s[0], s[2], s[1]), m, **kw)


def pal():
    return M.pal()


def shelf(fname, W=1.2, D=0.55, H=1.55, seed=1):
    P.reset()
    random.seed(seed)
    A = M.Acc()
    p = pal()
    metal = M.metal()
    dark = M.solid("dark", (0.07, 0.08, 0.09), 0.6)
    for sx in (-1, 1):
        gb(A, (sx * (W / 2 - 0.015), H / 2, 0), (0.03, H, D), metal)                         # the end frames
    gb(A, (0, H / 2 + 0.05, 0), (W - 0.06, H - 0.1, 0.03), dark)                              # the pegboard spine
    gb(A, (0, 0.05, 0), (W, 0.1, D), dark)                                                    # base
    zs = [0.22, 0.58, 0.94, 1.3]
    for z in zs:
        for side in (-1, 1):
            gb(A, (0, z, side * D * 0.25), (W - 0.06, 0.02, D * 0.46), metal)
            gb(A, (0, z + 0.03, side * D * 0.5), (W - 0.06, 0.05, 0.015), p["white"])         # the price lip
            x = -W / 2 + 0.08
            while x < W / 2 - 0.07:
                kind = random.choice(["bag", "box", "tin", "bottle"])
                col = p[random.choice(COLS)]
                zz = side * D * 0.28
                if kind == "bag":
                    gb(A, (x, z + 0.11, zz), (0.14, 0.2, 0.05), col)
                    x += 0.16
                elif kind == "box":
                    gb(A, (x, z + 0.09, zz), (0.1, 0.16, 0.08), col)
                    x += 0.12
                elif kind == "tin":
                    A.cyl((x, -zz, z + 0.06), 0.035, 0.1, col, seg=6)
                    x += 0.085
                else:
                    A.cyl((x, -zz, z + 0.1), 0.03, 0.18, col, seg=6)
                    x += 0.075
    A.build("Shelf")
    P.export("ST_Shelf.glb")


def counter(fname):
    P.reset()
    A = M.Acc()
    p = pal()
    wood = M.wood((0.7, 0.6, 0.5, 1))
    top = M.solid("countertop", (0.18, 0.18, 0.2), 0.4)
    dark = M.solid("dark", (0.07, 0.08, 0.09), 0.6)
    L, D, H = 1.9, 0.7, 1.05
    gb(A, (0, H / 2 - 0.03, 0), (L, H - 0.06, D), wood)
    gb(A, (0, H - 0.02, 0.02), (L + 0.06, 0.04, D + 0.06), top)
    gb(A, (0, 0.04, 0.0), (L - 0.1, 0.08, D - 0.1), dark)                                     # kick
    gb(A, (-0.55, H + 0.1, -0.05), (0.38, 0.12, 0.3), dark)                                  # the till
    gb(A, (-0.55, H + 0.27, -0.1), (0.3, 0.2, 0.03), M.solid("screen", (0.2, 0.5, 0.45), 0.3, 0.0, (0.2, 0.7, 0.6, 1)), rx=0.0)
    gb(A, (0.35, H + 0.12, 0.0), (0.4, 0.2, 0.2), p["red"])                                   # a rack of lottery slips / sweets on the counter
    for i in range(4):
        gb(A, (0.2 + i * 0.1, H + 0.26, 0.0), (0.08, 0.1, 0.06), p[COLS[i]])
    gb(A, (0.85, H + 0.06, 0.1), (0.2, 0.1, 0.2), p["white"])                                 # a tip jar / pen pot
    A.build("Counter")
    P.export("ST_Counter.glb")


def clothes_rack(fname, seed=2):
    P.reset()
    random.seed(seed)
    A = M.Acc()
    p = pal()
    chrome = M.solid("frame", (0.72, 0.74, 0.78), 0.35, 0.8)
    W = 1.3
    for sx in (-1, 1):
        A.cyl((sx * (W / 2 - 0.03), 0.0, 0.8), 0.015, 1.6, chrome, seg=6)                    # the uprights (two feet each)
        gb(A, (sx * (W / 2 - 0.03), 0.02, 0), (0.05, 0.04, 0.55), chrome)
    for z in (1.5, 1.28):
        A.cyl((0, 0.0, z), 0.012, W, chrome, seg=6, axis="X")                                # the rails
    # garments hanging on the rails: flat panels with sleeves, in a row
    for rail, (z0, side) in enumerate(((1.5, -0.05), (1.28, 0.05))):
        x = -W / 2 + 0.1
        while x < W / 2 - 0.08:
            col = p[random.choice(COLS)]
            h = random.uniform(0.62, 0.78)
            gb(A, (x, z0 - h / 2 - 0.05, side), (0.07, h, 0.5), col)                           # the body, seen edge-on in a packed rail
            gb(A, (x, z0 - 0.08, side), (0.075, 0.05, 0.62), col)                              # the shoulders / sleeves
            gb(A, (x, z0 - 0.02, side), (0.01, 0.04, 0.1), chrome)                             # the hanger hook
            x += 0.085
    gb(A, (0, 1.64, 0), (W, 0.025, 0.12), p["white"])                                        # a header board
    A.build("Rack")
    P.export("ST_ClothesRack.glb")


def fold_table(fname, seed=3):
    P.reset()
    random.seed(seed)
    A = M.Acc()
    p = pal()
    wood = M.wood()
    L, D, H = 1.3, 0.85, 0.85
    for sx in (-1, 1):
        for sz in (-1, 1):
            gb(A, (sx * (L / 2 - 0.05), H / 2 - 0.02, sz * (D / 2 - 0.05)), (0.06, H - 0.04, 0.06), wood)
    gb(A, (0, H - 0.02, 0), (L, 0.04, D), wood)
    for i in range(3):                                                                        # stacks of folded clothes
        for j in range(2):
            col = p[random.choice(COLS)]
            n = random.randint(3, 6)
            for k in range(n):
                gb(A, (-0.42 + i * 0.42, H + 0.03 + k * 0.045, -0.2 + j * 0.4), (0.32, 0.04, 0.26), p[random.choice(COLS)] if k % 2 else col)
    gb(A, (0.0, H + 0.12, -0.38), (0.4, 0.2, 0.02), p["cream"])                              # a sale card
    A.build("FoldTable")
    P.export("ST_FoldTable.glb")


def shoe_shelf(fname, seed=4):
    P.reset()
    random.seed(seed)
    A = M.Acc()
    p = pal()
    metal = M.metal()
    W, D, H = 1.3, 0.4, 1.25
    for sx in (-1, 1):
        gb(A, (sx * (W / 2 - 0.015), H / 2, 0), (0.03, H, D), metal)
    gb(A, (0, H / 2, D / 2 - 0.01), (W, H, 0.02), M.solid("dark", (0.07, 0.08, 0.09), 0.6))
    for z in (0.05, 0.4, 0.75, 1.1):
        gb(A, (0, z, 0), (W - 0.06, 0.025, D), metal)
        x = -W / 2 + 0.12
        while x < W / 2 - 0.1:
            col = p[random.choice(COLS)]
            gb(A, (x, z + 0.07, -0.02), (0.1, 0.1, 0.27), col)                                # the shoe
            gb(A, (x, z + 0.025, -0.02), (0.1, 0.02, 0.29), p["white"])                        # its sole
            x += 0.13
    A.build("ShoeShelf")
    P.export("ST_ShoeShelf.glb")


shelf("")
counter("")
clothes_rack("")
fold_table("")
shoe_shelf("")
