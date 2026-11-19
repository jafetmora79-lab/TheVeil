"""Sarah head v5 (grey, no painting): clean UV layout for the approved head v4l, a thin hair cap fitted to it, and the ponytail refitted to the new skull.
   blender -b head_v4l.blend -P build_sarah_head_v5.py -- <out.blend> <uv_layout.json>
UV layout (0-1): front u .00-.62 (v .08-1, brow-to-chin ~80%), left side u .64-.82 / right side u .82-1 (v .50-1), back u .64-.88 v 0-.5, top u .88-1 v .27-.49, neck/under u .88-1 v .02-.24."""
import bpy, bmesh, sys, os, json, math
import numpy as np
from mathutils import Vector

a = sys.argv[sys.argv.index("--") + 1:]
OUT, UVJSON = a[0], a[1]
head = bpy.data.objects["Sarah_Head_v4"]
head.name = head.data.name = "Sarah_Head"
for _l in list(head.data.uv_layers):
    head.data.uv_layers.remove(_l)
bm = bmesh.new()
bm.from_mesh(head.data)
bm.faces.ensure_lookup_table()
uvl = bm.loops.layers.uv.new("UVMap")


def lerp(a, b, t):
    return a + (b - a) * t


XH, ZLO, ZHI = .090, 1.43, 1.66
groups = {}
for f in bm.faces:
    c = f.calc_center_median()
    n = f.normal
    if abs(c.x) > .058 and -.014 < c.y < .042 and 1.528 < c.z < 1.592 and f.calc_center_median().z > 1.52:
        g = "earL" if c.x > 0 else "earR"
    elif c.z < 1.452:
        g = "neck"
    elif n.z > .72:
        g = "top"
    elif n.z < -.6:
        g = "neck"
    elif abs(n.x) > abs(n.y) + .15 and abs(c.x) > .05:
        g = "left" if c.x > 0 else "right"
    elif n.y < 0:
        g = "front"
    else:
        g = "back"
    groups[f.index] = g
    for l in f.loops:
        co = l.vert.co
        if g in ("earL", "earR"):
            u0 = .02 if g == "earL" else .16
            u = u0 + (co.y + .014) / .056 * .12
            v = .01 + (co.z - 1.528) / .064 * .06
        elif g == "front":
            u = lerp(.01, .61, (co.x + XH) / (2 * XH))
            v = .08 + (co.z - ZLO) / (ZHI - ZLO) * .91
        elif g in ("left", "right"):
            u0, u1 = (.64, .82) if g == "left" else (.82, 1.0)
            t = (co.y + .12) / .22                      # front of head -> back
            t = 1 - t if g == "right" else t
            u = lerp(u0 + .01, u1 - .01, t)
            v = lerp(.51, .99, (co.z - 1.40) / (ZHI - 1.40))
        elif g == "back":
            u = lerp(.65, .87, (co.x + XH) / (2 * XH))
            v = lerp(.01, .49, (co.z - ZLO) / (ZHI - ZLO))
        elif g == "top":
            u = lerp(.89, .99, (co.x + XH) / (2 * XH))
            v = lerp(.28, .48, (co.y + .12) / .22)
        else:
            u = lerp(.89, .99, (co.x + XH) / (2 * XH))
            v = lerp(.03, .23, (co.y + .12) / .22)
        l[uvl].uv = (min(max(u, 0), 1), min(max(v, 0), 1))
json.dump([[[list(l[uvl].uv) for l in f.loops] for f in bm.faces], [groups[f.index] for f in bm.faces]], open(UVJSON, "w"))
bm.to_mesh(head.data)

# ----------------------------------------------------------------------------------------------- hair cap
cap_faces = []
for f in bm.faces:
    c = f.calc_center_median()
    if groups[f.index] in ("neck", "earL", "earR"):
        continue
    ear = abs(c.x) > .062 and -.012 < c.y < .040 and 1.53 < c.z < 1.59
    if ear:
        continue
    if c.z > 1.605 or (c.y > .0 and c.z > 1.535) or (abs(c.x) > .05 and c.z > 1.598):
        cap_faces.append(f)
cm = bpy.data.meshes.new("Sarah_HairCap")
cb = bmesh.new()
vmap = {}
cl = cb.loops.layers.uv.new("UVMap")
for f in cap_faces:
    vs = []
    for v in f.verts:
        if v.index not in vmap:
            vmap[v.index] = cb.verts.new(v.co + v.normal * .0 + Vector((0, 0, 0)))
        vs.append(vmap[v.index])
    nf = cb.faces.new(vs)
    for lo, ln in zip(f.loops, nf.loops):
        ln[cl].uv = lo[uvl].uv
cb.verts.ensure_lookup_table()
# push the cap outward from the head centre so it sits as a thin shell over the skull
cen = Vector((0, -.01, 1.55))
for v in cb.verts:
    d = v.co - cen
    d.z *= .8
    v.co = v.co + d.normalized() * .004
cb.normal_update()
cb.to_mesh(cm)
cb.free()
cap = bpy.data.objects.new("Sarah_HairCap", cm)
bpy.context.scene.collection.objects.link(cap)
for p in cm.polygons:
    p.use_smooth = False
bm.free()

# ------------------------------------------------------------------------------------------ ponytail refit
path = os.path.abspath("creatures/humans/sarah/CHR_Sarah_v3.blend")
with bpy.data.libraries.load(path, link=False) as (src, dst):
    dst.objects = ["Sarah_Hair"]
pt = dst.objects[0]
bpy.context.scene.collection.objects.link(pt)
pt.parent = None
for md in list(pt.modifiers):
    pt.modifiers.remove(md)
for vg in list(pt.vertex_groups):
    pt.vertex_groups.remove(vg)
pt.name = "Sarah_Hair_Ponytail"
pv = np.array([v.co[:] for v in pt.data.vertices])
print("PONY before", pv.min(0).round(3), pv.max(0).round(3))
for v in pt.data.vertices:
    v.co.y += .035           # new skull is deeper at the back
    v.co.z += .004
pv = np.array([v.co[:] for v in pt.data.vertices])
print("PONY after", pv.min(0).round(3), pv.max(0).round(3))
print("HEAD tris", sum(len(p.vertices) - 2 for p in head.data.polygons), "CAP tris", sum(len(p.vertices) - 2 for p in cm.polygons))
for o in list(bpy.data.objects):
    if o.name not in ("Sarah_Head", "Sarah_HairCap", "Sarah_Hair_Ponytail"):
        bpy.data.objects.remove(o)
bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(OUT))
