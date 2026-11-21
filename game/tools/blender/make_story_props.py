"""THE VEIL - story props modelled in Blender and exported as GLBs: nailed planks (barricades), the power-station control cabinet, metal sliding doors,
a vent duct with a hinged grate, a duct run, and sheets of paper. Uses the game's own textures.
   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --python game/tools/blender/make_story_props.py
Output: game/prototypes/story_props/*.glb  (Godot: front faces +Z, up +Y; origin at the bottom centre unless noted).
Blender frame used here: X right, Y into the wall (+Y), Z up; the FRONT of a prop faces -Y (the exporter turns that into +Z in Godot)."""
import bpy, bmesh, math, os, random
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
TEX = os.path.join(ROOT, "THE_VEIL_ASSETS_V2", "01_Textures")
OUT = os.path.join(ROOT, "game", "prototypes", "story_props")
os.makedirs(OUT, exist_ok=True)
random.seed(77)
_mats = {}


def mat(name, tex=None, col=(0.5, 0.5, 0.5, 1.0), rough=0.9, metal=0.0, emit=None):
    key = (name, tex)
    if key in _mats:
        return _mats[key]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    bsdf.inputs["Base Color"].default_value = col
    if tex:
        path = tex if os.path.isabs(tex) else os.path.join(TEX, tex)
        img = bpy.data.images.load(path)
        node = m.node_tree.nodes.new("ShaderNodeTexImage")
        node.image = img
        node.interpolation = "Closest"
        # tint the texture with the colour (so one wood texture can read as fresh or dark)
        mix = m.node_tree.nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.blend_type = "MULTIPLY"
        mix.inputs[0].default_value = 1.0
        mix.inputs[7].default_value = col
        m.node_tree.links.new(node.outputs["Color"], mix.inputs[6])
        m.node_tree.links.new(mix.outputs[2], bsdf.inputs["Base Color"])
    if emit:
        bsdf.inputs["Emission Color"].default_value = emit
        bsdf.inputs["Emission Strength"].default_value = 1.0
    _mats[key] = m
    return m


def reset():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    for c in list(bpy.data.collections):
        bpy.data.collections.remove(c)


def _uv_box(bm, scale):
    uv = bm.loops.layers.uv.verify()
    for f in bm.faces:
        n = f.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        for l in f.loops:
            p = l.vert.co
            if ax == 0:
                l[uv].uv = (p.y / scale, p.z / scale)
            elif ax == 1:
                l[uv].uv = (p.x / scale, p.z / scale)
            else:
                l[uv].uv = (p.x / scale, p.y / scale)


def box(name, size, center, m, pivot=None, scale=1.0, parent=None, rot=(0, 0, 0), jag=0.0):
    """A box of `size` centred at `center` (world), object origin at `pivot` (default: the centre)."""
    pivot = Vector(pivot) if pivot is not None else Vector(center)
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2])) + (Vector(center) - pivot)
    if jag > 0.0:                                     # a splintered end: the +X end verts are pulled about
        for v in bm.verts:
            if v.co.x > 0:
                v.co.x += random.uniform(-jag, jag) * 0.5
                v.co.y += random.uniform(-jag, jag) * 0.15
    _uv_box(bm, scale)
    bm.normal_update()
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    ob.location = pivot
    ob.rotation_euler = rot
    me.materials.append(m)
    if parent is not None:
        ob.parent = parent
    return ob


def cyl(name, r, h, center, m, axis="Z", pivot=None, seg=12, parent=None):
    pivot = Vector(pivot) if pivot is not None else Vector(center)
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r, radius2=r, depth=h)
    rot = {"Z": None, "X": ((0, 1, 0), math.pi / 2), "Y": ((1, 0, 0), math.pi / 2)}[axis]
    if rot:
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=__import__("mathutils").Matrix.Rotation(rot[1], 3, rot[0]))
    for v in bm.verts:
        v.co += Vector(center) - pivot
    uv = bm.loops.layers.uv.verify()
    for f in bm.faces:
        for l in f.loops:
            l[uv].uv = (l.vert.co.x / 0.5, l.vert.co.z / 0.5)
    bm.normal_update()
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    ob.location = pivot
    me.materials.append(m)
    if parent is not None:
        ob.parent = parent
    return ob


def empty(name, loc):
    e = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(e)
    e.location = loc
    return e


def export(fname):
    bpy.ops.object.select_all(action="DESELECT")
    path = os.path.join(OUT, fname)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_apply=True, export_yup=True, use_selection=False)
    print("EXPORTED", path, os.path.getsize(path) // 1024, "KB")


WOOD = lambda col=(0.62, 0.55, 0.47, 1): mat("PlankWood", "Architecture/T_Arch_WoodPlanksAged.png", col, 0.95)
DARKWOOD = lambda: mat("PlankDark", "Furniture/T_Furn_WoodDark.png", (0.85, 0.8, 0.75, 1), 0.95)
IRON = lambda: mat("Nail", None, (0.12, 0.11, 0.1, 1), 0.5, 0.8)


# ------------------------------------------------------------------ nailed planks (barricades)
def plank(fname, length, width=0.15, thick=0.035, broken=False, dark=False):
    reset()
    m = DARKWOOD() if dark else WOOD()
    box("Plank", (length, thick, width), (0, 0, 0), m, scale=0.5, jag=0.12 if broken else 0.0)
    if broken:
        # a second splintered shard hanging off the end
        box("Splinter", (0.22, thick * 0.8, width * 0.45), (length / 2 + 0.05, 0, -width * 0.2), m, scale=0.5, rot=(0, 0.35, 0), jag=0.05)
    for x in (-length / 2 + 0.1, length / 2 - 0.1):          # nails: heads on the front (-Y)
        cyl("NailHead", 0.014, 0.008, (x, -thick / 2 - 0.004, 0.0), IRON(), axis="Y", seg=8)
    export(fname)


# ------------------------------------------------------------------ the control cabinet (power station)
def power_control(fname):
    reset()
    body = mat("CabMetal", "Commercial/T_Com_MetalDoorPainted.png", (0.55, 0.62, 0.58, 1), 0.7, 0.3)
    dark = mat("CabDark", "Furniture/T_Furn_MetalRusted.png", (0.35, 0.35, 0.35, 1), 0.8, 0.4)
    black = mat("CabBlack", None, (0.03, 0.03, 0.035, 1), 0.6)
    cream = mat("DialFace", None, (0.78, 0.74, 0.62, 1), 0.9)
    red = mat("Red", None, (0.7, 0.08, 0.06, 1), 0.5)
    yellow = mat("Yellow", None, (0.75, 0.58, 0.08, 1), 0.5)
    W, H, D = 1.9, 2.3, 0.5
    box("Body", (W, D, H), (0, D / 2, H / 2), body, scale=1.2)
    box("Base", (W + 0.06, D + 0.06, 0.1), (0, D / 2, 0.05), dark, scale=1.0)
    box("Hood", (W + 0.08, D + 0.08, 0.08), (0, D / 2, H + 0.04), dark, scale=1.0)
    # upper panel: three gauges
    for i, x in enumerate((-0.6, 0.0, 0.6)):
        cyl("DialRim%d" % i, 0.21, 0.04, (x, -0.02, 1.85), black, axis="Y", seg=18)
        cyl("DialFace%d" % i, 0.18, 0.045, (x, -0.025, 1.85), cream, axis="Y", seg=18)
        for t in range(9):                                  # tick marks
            a = math.radians(-120 + t * 30)
            box("Tick", (0.012, 0.012, 0.03), (x + math.sin(a) * 0.145, -0.052, 1.85 + math.cos(a) * 0.145), black, rot=(0, -a, 0), scale=1.0)
        piv = (x, -0.056, 1.85)
        needle = box("Needle%d" % (i + 1), (0.012, 0.01, 0.15), (x, -0.056, 1.85 + 0.075), red, pivot=piv, scale=1.0)
        needle.rotation_euler = (0, math.radians(-70), 0)
    # a warning plate
    box("WarnPlate", (0.7, 0.01, 0.22), (0.0, -0.005, 1.5), mat("Warn", "Horror/T_Hor_WarningSignWeathered.png", (1, 1, 1, 1), 0.9), scale=0.5)
    # indicator lamps (each its own object + material, so the game can light them)
    for i in range(6):
        x = -0.75 + i * 0.3
        lm = mat("LampMat%d" % (i + 1), None, (0.25, 0.04, 0.03, 1), 0.4)
        cyl("Lamp%d" % (i + 1), 0.045, 0.04, (x, -0.02, 1.28), lm, axis="Y", seg=12)
        cyl("LampRing%d" % i, 0.058, 0.02, (x, -0.012, 1.28), black, axis="Y", seg=12)
    # three breaker switches
    for i, x in enumerate((-0.55, 0.0, 0.55)):
        box("SwHousing%d" % i, (0.22, 0.07, 0.42), (x, -0.035, 0.78), black, scale=0.5)
        box("SwSlot%d" % i, (0.06, 0.01, 0.3), (x, -0.074, 0.78), dark, scale=0.5)
        piv = (x, -0.09, 0.78)
        lev = box("Switch%d" % (i + 1), (0.05, 0.05, 0.2), (x, -0.09, 0.78 + 0.1), yellow, pivot=piv, scale=0.5)
        lev.rotation_euler = (math.radians(-35), 0, 0)
    # the main lever: a big knife-switch on the lower panel
    box("LeverPlate", (0.5, 0.06, 0.62), (0, -0.03, 0.3), black, scale=0.5)
    box("LeverSlot", (0.08, 0.01, 0.5), (0, -0.065, 0.3), dark, scale=0.5)
    piv = (0, -0.1, 0.1)
    main = box("MainLever", (0.07, 0.07, 0.5), (0, -0.1, 0.1 + 0.25), red, pivot=piv, scale=0.5)
    cyl("MainKnob", 0.06, 0.1, (0, -0.1, 0.1 + 0.55), red, axis="Z", pivot=piv, seg=10, parent=main)
    main.rotation_euler = (math.radians(-40), 0, 0)
    # the side cabinet door seams, hinges and a handle
    box("Seam", (0.012, 0.01, H - 0.2), (0, -0.003, H / 2), black, scale=1.0)
    box("Handle", (0.05, 0.05, 0.28), (0.1, -0.04, 1.1), dark, scale=0.5)
    # conduits and cable runs up out of the top
    for x in (-0.7, -0.5, 0.45, 0.7):
        cyl("Conduit", 0.04, 0.9, (x, D / 2, H + 0.5), dark, seg=8)
    for i, x in enumerate((-0.25, 0.1, 0.25)):
        pts = [(x, 0.15 + 0.05 * i, H), (x + 0.1, 0.25, H + 0.35), (x + 0.2, 0.35, H + 0.7)]
        for a, b in zip(pts, pts[1:]):
            mid = [(a[k] + b[k]) / 2 for k in range(3)]
            ln = math.dist(a, b)
            c = cyl("Cable", 0.022, ln, mid, black, seg=6)
            d = Vector(b) - Vector(a)
            c.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    # hazard stripes along the base
    box("Hazard", (W - 0.1, 0.01, 0.1), (0, -0.003, 0.17), mat("Hazard", "Roads/T_Road_MarkingYellow.png", (1, 1, 1, 1), 0.9), scale=0.4)
    export(fname)


# ------------------------------------------------------------------ metal sliding door (frame fills the opening to the ceiling: nothing above it)
def sliding_door(fname, width=2.0, height=3.2, rusty=False):
    reset()
    steel = mat("DoorSteel" + ("R" if rusty else ""), "Furniture/T_Furn_MetalRusted.png" if rusty else "Commercial/T_Com_MetalDoorPainted.png",
                (0.8, 0.7, 0.6, 1) if rusty else (0.6, 0.66, 0.64, 1), 0.7, 0.4)
    frame = mat("DoorFrame", "Furniture/T_Furn_MetalBrushed.png", (0.45, 0.47, 0.5, 1), 0.7, 0.5)
    black = mat("DoorBlack", None, (0.03, 0.03, 0.035, 1), 0.6)
    glass = mat("DoorGlass", None, (0.05, 0.1, 0.12, 1), 0.2)
    haz = mat("DoorHazard", "Roads/T_Road_MarkingYellow.png", (1, 1, 1, 1), 0.9)
    T = 0.28                                                   # the frame's depth (it sits in the wall)
    hw = width / 2
    # frame: two posts, a full-width header up to the ceiling, a sill
    box("PostL", (0.14, T, height), (-hw - 0.07, 0, height / 2), frame, pivot=(0, 0, 0), scale=0.6)
    box("PostR", (0.14, T, height), (hw + 0.07, 0, height / 2), frame, pivot=(0, 0, 0), scale=0.6)
    box("Header", (width + 0.28, T, 0.34), (0, 0, height - 0.17), frame, pivot=(0, 0, 0), scale=0.6)
    box("Sill", (width, T, 0.04), (0, 0, 0.02), dark_ := mat("Sill", None, (0.2, 0.2, 0.2, 1), 0.7, 0.5), pivot=(0, 0, 0), scale=0.6)
    # surface-mounted track hood on the front, wide enough for both leaves to slide into
    box("Hood", (width * 2 + 0.3, 0.16, 0.2), (0, -T / 2 - 0.08, height - 0.4), frame, pivot=(0, 0, 0), scale=0.6)
    lh = height - 0.52
    for side, nm in ((-1, "LeafL"), (1, "LeafR")):
        cx = side * hw / 2
        piv = (cx, -T / 2 - 0.045, lh / 2 + 0.05)
        leaf = box(nm, (hw + 0.06, 0.07, lh), piv, steel, pivot=piv, scale=0.7)
        # rib panels, a window slot, hazard stripes, a handle
        off = lambda dx, dy, dz: (dx, dy, dz)
        for r in (-0.5, 0.0, 0.5):
            box("Rib", (0.025, 0.012, lh - 0.3), (cx + r * hw / 2, piv[1] - 0.04, piv[2]), frame, pivot=piv, parent=leaf, scale=0.5)
        box("Win", (0.14, 0.012, 0.5), (cx - side * 0.12, piv[1] - 0.039, piv[2] + 0.55), glass, pivot=piv, parent=leaf, scale=0.5)
        box("Haz", (hw + 0.04, 0.012, 0.22), (cx, piv[1] - 0.039, 0.22), haz, pivot=piv, parent=leaf, scale=0.4)
        box("Handle", (0.04, 0.06, 0.6), (cx - side * (hw / 2 - 0.08), piv[1] - 0.06, piv[2] - 0.1), black, pivot=piv, parent=leaf, scale=0.5)
        for rz in (-0.5, 0.5):
            for rx in (-0.4, 0.4):
                cyl("Rivet", 0.012, 0.012, (cx + rx * hw / 2, piv[1] - 0.04, piv[2] + rz), black, axis="Y", pivot=piv, seg=6, parent=leaf)
    # a status light box over the door
    box("Status", (0.3, 0.06, 0.14), (0, -T / 2 - 0.19, height - 0.15), black, pivot=(0, 0, 0), scale=0.5)
    cyl("StatusLamp", 0.035, 0.03, (-0.08, -T / 2 - 0.225, height - 0.15), mat("DoorLampMat", None, (0.7, 0.08, 0.05, 1), 0.4), axis="Y", pivot=(0, 0, 0), seg=10)
    export(fname)


# ------------------------------------------------------------------ vent duct with a hinged grate (the skitters' way out)
def vent_duct(fname):
    reset()
    metal = mat("DuctMetal", "Furniture/T_Furn_MetalBrushed.png", (0.55, 0.57, 0.6, 1), 0.7, 0.5)
    rust = mat("DuctRust", "Furniture/T_Furn_MetalRusted.png", (0.9, 0.8, 0.7, 1), 0.85, 0.3)
    dark = mat("DuctInside", None, (0.015, 0.015, 0.02, 1), 1.0)
    W, H, L = 1.4, 0.95, 0.9
    # the duct (open at the front): four walls and a dark back, sticking out of the wall plate
    box("Top", (W, L, 0.04), (0, L / 2, H), metal, pivot=(0, 0, 0), scale=0.6)
    box("Bottom", (W, L, 0.04), (0, L / 2, 0.02), metal, pivot=(0, 0, 0), scale=0.6)
    box("SideL", (0.04, L, H), (-W / 2 + 0.02, L / 2, H / 2), metal, pivot=(0, 0, 0), scale=0.6)
    box("SideR", (0.04, L, H), (W / 2 - 0.02, L / 2, H / 2), metal, pivot=(0, 0, 0), scale=0.6)
    box("Back", (W, 0.02, H), (0, L, H / 2), dark, pivot=(0, 0, 0), scale=0.6)
    # wall plate (frame round the opening, bolts)
    box("PlateT", (W + 0.4, 0.05, 0.2), (0, -0.03, H + 0.1), rust, pivot=(0, 0, 0), scale=0.6)
    box("PlateB", (W + 0.4, 0.05, 0.2), (0, -0.03, -0.1), rust, pivot=(0, 0, 0), scale=0.6)
    box("PlateL", (0.2, 0.05, H), (-W / 2 - 0.1, -0.03, H / 2), rust, pivot=(0, 0, 0), scale=0.6)
    box("PlateR", (0.2, 0.05, H), (W / 2 + 0.1, -0.03, H / 2), rust, pivot=(0, 0, 0), scale=0.6)
    # the grate: a frame and vertical bars, hinged on its top edge
    piv = (0, -0.07, H)
    g = box("Grate", (W, 0.03, 0.05), (0, -0.07, H - 0.025), rust, pivot=piv, scale=0.6)
    box("GrateB", (W, 0.03, 0.05), (0, -0.07, 0.025), rust, pivot=piv, parent=g, scale=0.6)
    for i in range(9):
        x = -W / 2 + 0.07 + i * (W - 0.14) / 8
        box("Bar", (0.03, 0.03, H - 0.05), (x, -0.07, H / 2), rust, pivot=piv, parent=g, scale=0.6)
    box("GrateMid", (W, 0.03, 0.04), (0, -0.07, H / 2), rust, pivot=piv, parent=g, scale=0.6)
    export(fname)


def duct_run(fname, length=3.0):
    reset()
    metal = mat("RunMetal", "Furniture/T_Furn_MetalBrushed.png", (0.5, 0.52, 0.55, 1), 0.7, 0.5)
    rust = mat("RunRust", "Furniture/T_Furn_MetalRusted.png", (0.9, 0.8, 0.7, 1), 0.85, 0.3)
    W, H = 0.9, 0.7
    # along X, centred, bottom at z 0 (the run sits on the ceiling, hung from brackets)
    box("Top", (length, W, 0.03), (0, 0, H), metal, pivot=(0, 0, 0), scale=0.6)
    box("Bottom", (length, W, 0.03), (0, 0, 0), metal, pivot=(0, 0, 0), scale=0.6)
    box("SideA", (length, 0.03, H), (0, -W / 2, H / 2), metal, pivot=(0, 0, 0), scale=0.6)
    box("SideB", (length, 0.03, H), (0, W / 2, H / 2), metal, pivot=(0, 0, 0), scale=0.6)
    for x in (-length / 2 + 0.05, 0.0, length / 2 - 0.05):
        box("Flange", (0.06, W + 0.12, H + 0.12), (x, 0, H / 2), rust, pivot=(0, 0, 0), scale=0.5)
    for x in (-length / 3, length / 3):
        box("Hanger", (0.05, 0.05, 0.4), (x, 0, H + 0.2), rust, pivot=(0, 0, 0), scale=0.5)
    export(fname)


# ------------------------------------------------------------------ paper
def paper(fname, tex, count=1, spread=0.0):
    reset()
    m = mat("Paper_" + os.path.basename(tex), tex, (1, 1, 1, 1), 1.0)
    w, h = 0.21, 0.297
    for i in range(count):
        a = random.uniform(0, math.tau)
        r = random.uniform(0, spread)
        me = bpy.data.meshes.new("Sheet%d" % i)
        bm = bmesh.new()
        grid = bmesh.ops.create_grid(bm, x_segments=3, y_segments=4, size=0.5)
        for v in bm.verts:
            v.co.x *= w * 2
            v.co.y *= h * 2
            v.co.z = 0.002 + 0.012 * math.sin(v.co.x * 14 + i) * math.cos(v.co.y * 9) + i * 0.0035   # a little curl, and each sheet sits on the last
        uv = bm.loops.layers.uv.verify()
        for f in bm.faces:
            for l in f.loops:
                l[uv].uv = (l.vert.co.x / w + 0.5, l.vert.co.y / h + 0.5)
        bm.normal_update()
        bm.to_mesh(me)
        bm.free()
        ob = bpy.data.objects.new("Sheet%d" % i, me)
        bpy.context.scene.collection.objects.link(ob)
        ob.location = (math.cos(a) * r, math.sin(a) * r, 0)
        ob.rotation_euler = (0, 0, random.uniform(0, math.tau))
        me.materials.append(m)
        mm = ob.data.materials[0]
        mm.use_backface_culling = False
    export(fname)


if __name__ == "__main__":
    plank("PRP_Plank_1.0.glb", 1.0)
    plank("PRP_Plank_1.4.glb", 1.4)
    plank("PRP_Plank_1.0_Broken.glb", 1.0, broken=True)
    plank("PRP_Plank_1.6_Dark.glb", 1.6, dark=True)
    power_control("FAC_PowerControl.glb")
    sliding_door("FAC_SlidingDoor.glb", 2.0, 3.2)
    sliding_door("FAC_SlidingDoor_Rust.glb", 2.4, 2.9, rusty=True)
    vent_duct("FAC_VentDuct.glb")
    duct_run("FAC_DuctRun_3m.glb", 3.0)
    T = os.path.join(ROOT, "game", "prototypes", "story_props", "tex")
    paper("PRP_Paper_Sheet_A.glb", os.path.join(T, "paper_a.png"), 1)
    paper("PRP_Paper_Pile_A.glb", os.path.join(T, "paper_a.png"), 5, 0.22)
    paper("PRP_Paper_Pile_B.glb", os.path.join(T, "paper_b.png"), 6, 0.3)
    paper("PRP_Paper_Pile_C.glb", os.path.join(T, "paper_c.png"), 4, 0.25)
