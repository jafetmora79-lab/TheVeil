"""THE VEIL - the car-repair parts as real models (review: "the starter relay looks like a black box"): the relay itself (black plastic body, a printed label, brass blades) and the
relay / fuse box it goes into (ribbed housing with relay sockets and coloured fuses, a hinged lid with a printed diagram and a latch).
   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --python game/tools/blender/make_car_parts.py
Output: game/props/car_parts/CAR_StarterRelay.glb, CAR_RelayBox.glb (objects Shell and Lid).  Built in Godot axes through b() (Blender (x, y, z) = Godot (x, -z, y))."""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import make_story_props as P
import make_market_props as M
DIR = os.path.join(P.ROOT, "game", "props", "car_parts")
TEX = os.path.join(DIR, "tex")
P.OUT = DIR


def mats():
    return {"plastic": M.solid("plastic", (0.1, 0.1, 0.11), 0.55), "grey": M.solid("greyplastic", (0.2, 0.21, 0.23), 0.5), "brass": M.solid("brass", (0.78, 0.6, 0.25), 0.35, 0.9),
            "dark": M.solid("darkslot", (0.02, 0.02, 0.025), 0.8), "wire": M.solid("wire", (0.05, 0.05, 0.05), 0.6),
            "red": M.solid("fred", (0.85, 0.12, 0.1), 0.4), "blue": M.solid("fblue", (0.15, 0.3, 0.85), 0.4), "yellow": M.solid("fyellow", (0.95, 0.8, 0.15), 0.4),
            "green": M.solid("fgreen", (0.2, 0.7, 0.3), 0.4), "tan": M.solid("ftan", (0.75, 0.6, 0.4), 0.4)}


def g(a, c, s, m, **kw):
    """box in GODOT axes: centre c, size s"""
    a.box((c[0], -c[2], c[1]), (s[0], s[2], s[1]), m, **kw)


def relay():
    P.reset()
    A = M.Acc()
    m = mats()
    label = P.mat("RelayLabel", os.path.join(TEX, "relay_label.png"), (1, 1, 1, 1), 0.6)
    g(A, (0, 0.017, 0), (0.034, 0.030, 0.026), m["plastic"])                  # the body
    g(A, (0, 0.033, 0), (0.030, 0.004, 0.022), m["plastic"])                  # a stepped top
    g(A, (0, 0.034, 0), (0.014, 0.003, 0.012), m["grey"])                      # the date boss
    g(A, (0, 0.017, -0.0132), (0.028, 0.022, 0.0008), label, front=(0, 0.017, 0.028, 0.022))   # the printed label on the front (-z)
    for sx in (-1, 1):                                                         # ribs down the sides
        for k in (-1, 0, 1):
            g(A, (sx * 0.0175, 0.017, k * 0.007), (0.002, 0.024, 0.003), m["plastic"])
    g(A, (0.0, 0.006, 0.0142), (0.012, 0.012, 0.003), m["grey"])               # the mounting tab behind
    for (x, z) in ((-0.009, -0.007), (0.009, -0.007), (0.0, 0.007), (-0.009, 0.007)):
        g(A, (x, -0.006, z), (0.0065 if z < 0 else 0.0055, 0.014, 0.0016), m["brass"])   # the blades
    A.build("Relay")
    P.export("CAR_StarterRelay.glb")


def relay_box():
    P.reset()
    m = mats()
    S = M.Acc()
    # the housing: back plate, four walls, a rim, mounting ears, two latch posts; inside, two relay sockets and a row of fuses
    g(S, (0, 0, 0.04), (0.24, 0.16, 0.02), m["grey"])
    for sy in (-1, 1):
        g(S, (0, sy * 0.075, 0), (0.24, 0.01, 0.10), m["grey"])
    for sx in (-1, 1):
        g(S, (sx * 0.115, 0, 0), (0.01, 0.16, 0.10), m["grey"])
    for k in range(5):
        g(S, (-0.096 + k * 0.048, 0.081, 0.0), (0.012, 0.004, 0.09), m["grey"])         # ribs on the top wall
    for sy in (-1, 1):                                                          # the rim round the opening (a frame: the box stays open)
        g(S, (0, sy * 0.0815, -0.0505), (0.245, 0.012, 0.004), m["grey"])
    for sx in (-1, 1):
        g(S, (sx * 0.1165, 0, -0.0505), (0.012, 0.165, 0.004), m["grey"])
    for sx in (-1, 1):
        g(S, (sx * 0.135, 0, 0.04), (0.035, 0.05, 0.012), m["grey"])               # mounting ears
        g(S, (sx * 0.0, -0.082 if sx < 0 else 0.082, -0.03), (0.02, 0.006, 0.012), m["grey"])
    for sx in (-1, 1):                                                          # relay sockets (the second one holds the relay)
        g(S, (sx * 0.05, 0.03, 0.0315), (0.06, 0.05, 0.004), m["dark"])
        for (dx, dz) in ((-0.009, -0.008), (0.009, -0.008), (0.0, 0.008)):
            g(S, (sx * 0.05 + dx, 0.03, 0.028), (0.006, 0.012, 0.003), m["brass"])
    fcols = ["red", "blue", "yellow", "green", "tan", "red", "yellow", "blue"]
    for i, c in enumerate(fcols):
        g(S, (-0.095 + i * 0.027, -0.035, 0.022), (0.018, 0.026, 0.012), m[c])         # fuses
        g(S, (-0.095 + i * 0.027, -0.035, 0.0305), (0.02, 0.03, 0.004), m["dark"])
    for i in range(4):                                                          # wires out of the bottom
        S.cyl((-0.09 + i * 0.06, 0.0, -0.032 * 0 + 0.0), 0.004, 0.06, m["wire"], seg=5)
    for i in range(4):
        S.cyl((-0.09 + i * 0.06, 0.0, 0.0), 0.004, 0.0, m["wire"], seg=5) if False else None
    S.build("Shell")
    L = M.Acc()
    lidtex = P.mat("RelayLidTex", os.path.join(TEX, "relay_box_lid.png"), (1, 1, 1, 1), 0.6)
    g(L, (0, 0, 0), (0.25, 0.17, 0.012), m["grey"])
    g(L, (0, 0, -0.0066), (0.23, 0.15, 0.0012), lidtex, front=(0, 0, 0.23, 0.15))          # the printed diagram on the outer face
    for sx in (-1, 1):
        g(L, (sx * 0.12, 0, 0.008), (0.01, 0.17, 0.012), m["grey"])
    for sy in (-1, 1):
        g(L, (0, sy * 0.08, 0.008), (0.25, 0.01, 0.012), m["grey"])
    g(L, (0, -0.092, -0.006), (0.05, 0.016, 0.012), m["grey"])                  # the latch tab
    g(L, (0, 0.085, 0.0), (0.18, 0.012, 0.012), m["plastic"])                   # the hinge barrel
    L.build("Lid")
    P.export("CAR_RelayBox.glb")


relay()
relay_box()
