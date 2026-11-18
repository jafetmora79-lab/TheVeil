"""Read-only export of the Sarah PS2 head UV layout as a 1024x1024 PNG (outlines on transparent) + an annotated guide.
   blender -b creatures/humans/sarah/CHR_Sarah_PS2_phase2.blend -P creatures/tools/export_head_uv_template.py -- <template.png> <guide.png>
Does not modify or save the blend, the UVs, the textures or the rig."""
import bpy, sys, numpy as np

OUT_T, OUT_G = sys.argv[sys.argv.index("--") + 1], sys.argv[sys.argv.index("--") + 2]
N = 1024
head = bpy.data.objects["Sarah_Head"]
me = head.data
uv = me.uv_layers.active.data
polys = [[(uv[l].uv[0], uv[l].uv[1]) for l in p.loop_indices] for p in me.polygons]
print("HEAD UV polys", len(polys), "uv layer", me.uv_layers.active.name)


def line(buf, a, b, col, w=2):
    x0, y0 = a[0] * (N - 1), (1 - a[1]) * (N - 1)
    x1, y1 = b[0] * (N - 1), (1 - b[1]) * (N - 1)
    n = int(max(abs(x1 - x0), abs(y1 - y0)) * 2) + 2
    xs = np.linspace(x0, x1, n).round().astype(int)
    ys = np.linspace(y0, y1, n).round().astype(int)
    for dx in range(-(w // 2), w // 2 + 1):
        for dy in range(-(w // 2), w // 2 + 1):
            xx = np.clip(xs + dx, 0, N - 1)
            yy = np.clip(ys + dy, 0, N - 1)
            buf[yy, xx] = col


def fill_tri(buf, tri, col):
    pts = np.array([[t[0] * (N - 1), (1 - t[1]) * (N - 1)] for t in tri])
    x0, x1 = int(max(0, pts[:, 0].min())), int(min(N - 1, pts[:, 0].max()))
    y0, y1 = int(max(0, pts[:, 1].min())), int(min(N - 1, pts[:, 1].max()))
    if x1 < x0 or y1 < y0:
        return
    xs, ys = np.meshgrid(np.arange(x0, x1 + 1), np.arange(y0, y1 + 1))
    a, b, c = pts
    d = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
    if abs(d) < 1e-9:
        return
    w0 = ((b[1] - c[1]) * (xs - c[0]) + (c[0] - b[0]) * (ys - c[1])) / d
    w1 = ((c[1] - a[1]) * (xs - c[0]) + (a[0] - c[0]) * (ys - c[1])) / d
    m = (w0 >= 0) & (w1 >= 0) & (1 - w0 - w1 >= 0)
    buf[ys[m], xs[m]] = col


def save(buf, path):
    img = bpy.data.images.new("uvexport", N, N, alpha=True)
    img.pixels[:] = buf[::-1].reshape(-1)
    img.filepath_raw = path
    img.file_format = 'PNG'
    img.save()


# 1) the template: island outlines only, on a fully transparent background
t = np.zeros((N, N, 4), dtype=np.float32)
for poly in polys:
    for i in range(len(poly)):
        line(t, poly[i], poly[(i + 1) % len(poly)], (1, 1, 1, 1), 2)
save(t, OUT_T)

# 2) an annotated guide: islands tinted by area, plus landmark markers computed from the real head geometry
g = np.zeros((N, N, 4), dtype=np.float32)
g[...] = (.12, .12, .14, 1)
for poly in polys:
    cu = sum(p[0] for p in poly) / len(poly)
    cv = sum(p[1] for p in poly) / len(poly)
    if cu < .63:
        tint = (.20, .30, .55, 1)                                            # blue: FRONT of the face
    elif cv >= .5:
        tint = (.25, .50, .30, 1) if cu < .82 else (.20, .50, .50, 1)       # green: LEFT side+ear, teal: RIGHT side+ear
    else:
        tint = (.60, .40, .20, 1) if cu < .88 else (.45, .30, .55, 1)       # orange: BACK of head, purple: top/underside
    for k in range(1, len(poly) - 1):
        fill_tri(g, (poly[0], poly[k], poly[k + 1]), tint)
for poly in polys:
    for i in range(len(poly)):
        line(g, poly[i], poly[(i + 1) % len(poly)], (.95, .95, .95, 1), 2)
xmin, xmax, zmin, zbrow, zmax = head["uv_front"]
cx = (xmin + xmax) / 2
ez = 1.534


def U(x):
    return (x - xmin) / (xmax - xmin) * .62


def V(z):
    return .80 * (z - zmin) / (zbrow - zmin) if z <= zbrow else .80 + .20 * (z - zbrow) / (zmax - zbrow)


def mark(x, z, col, r=7):
    px, py = int(U(x) * (N - 1)), int((1 - V(z)) * (N - 1))
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            if dx * dx + dy * dy <= r * r and 0 <= px + dx < N and 0 <= py + dy < N:
                g[py + dy, px + dx] = col


mark(-0.029, ez, (1, .9, .1, 1)); mark(0.03, ez, (1, .9, .1, 1))                 # yellow: eye centres
mark(cx - .0335, ez + .0188 + .006, (.9, .4, .1, 1)); mark(cx + .0335, ez + .0188 + .006, (.9, .4, .1, 1))   # orange: brows
mark(cx, ez - .043, (1, .3, .3, 1))                                               # red: nose tip
mark(cx, ez - .0715, (1, .3, 1, 1))                                               # magenta: mouth line
save(g, OUT_G)
print("EXPORTED", OUT_T, OUT_G, head["uv_layout"])
