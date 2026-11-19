"""Diagnostic: how much real geometry does the protagonist's face have around the eyes, brows and mouth? (Blender, headless)
   blender -b -P protagonist_face_topology.py -- <repo_root>"""
import bpy, sys, os, json
import numpy as np
root = sys.argv[sys.argv.index("--") + 1]
base = os.path.join(root, "creatures/humans/protagonist")
bpy.ops.wm.open_mainfile(filepath=os.path.join(base, "game_ready/protagonist_meshy.blend"))
body = bpy.data.objects["Protagonist_Meshy_Body"]
me = body.data
cap = json.load(open(os.path.join(base, "work/face/face_capture.json")))
RES, CX, CZ, SIZE = cap["res"], cap["cx"], cap["cz"], cap["size"]
V = np.array([v.co[:] for v in me.vertices])
def px(p):
    return ((CX - p[0]) / SIZE * RES + RES / 2, RES / 2 - (p[2] - CZ) / SIZE * RES)
P = np.array([px(v) for v in V])
front = []
edges = set()
for poly in me.polygons:
    if poly.normal.y > 0.0:
        vs = list(poly.vertices)
        for i in range(len(vs)):
            a, b = vs[i], vs[(i + 1) % len(vs)]
            edges.add((min(a, b), max(a, b)))
inview = [(i) for i in range(len(V)) if 0 <= P[i][0] < RES and 0 <= P[i][1] < RES and V[i][1] > 0.0]
def count(box):
    x0, y0, x1, y1 = box
    return sum(1 for i in inview if x0 <= P[i][0] <= x1 and y0 <= P[i][1] <= y1)
boxes = {"left eye": (285, 395, 445, 480), "right eye": (552, 395, 705, 480), "left brow": (262, 318, 462, 400), "right brow": (535, 318, 735, 400),
         "mouth (lips)": (380, 685, 620, 760), "chin": (380, 760, 620, 850), "whole face": (200, 250, 800, 900)}
res = {k: count(b) for k, b in boxes.items()}
tris_face = sum(1 for poly in me.polygons if poly.normal.y > 0 and all(0 <= P[v][0] < RES and 200 <= P[v][1] < 900 and 250 <= P[v][0] < 800 for v in poly.vertices))
print("TOPO", json.dumps(res), "front-facing tris in face area", tris_face, "total verts", len(V))
data = {"P": P.tolist(), "edges": [list(e) for e in edges if e[0] in set(inview) or e[1] in set(inview)], "counts": res, "tris_face": tris_face}
json.dump(data, open(os.path.join(base, "face_geo/topology.json"), "w"))
