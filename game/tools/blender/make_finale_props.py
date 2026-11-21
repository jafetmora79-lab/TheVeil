"""THE VEIL - the finale's places, modelled in Blender and exported as GLBs (game/prototypes/story_props/): the closed-off district (precast concrete walls, chain-link fence,
a hinged steel checkpoint gate, signs, the passage hut with its heavy steel door), a hinged steel door, and the ancient chamber (pillar, the great seal frame and slab, the control
pedestals with levers and a wheel, the doorway slab, fallen stone). Uses the game's own textures.
   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --python game/tools/blender/make_finale_props.py
Conventions as make_story_props.py: Blender -Y front -> Godot +Z front; X right; Z up (-> Godot Y). Origin at the bottom centre unless a part says it is a pivot (hinge)."""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_story_props import *          # helpers: mat, box, cyl, empty, reset, export, OUT, TEX
from make_story_props import _uv_box
from mathutils import Vector

random.seed(404)
T_STORE = lambda col=(0.75, 0.75, 0.72, 1): mat("Concrete", "Commercial/T_Com_StorageConcrete.png", col, 0.95)
T_DIRTY = lambda col=(0.7, 0.7, 0.68, 1): mat("ConcreteDirty", "Commercial/T_Com_IndustrialWallDirty.png", col, 0.95)
T_FOUND = lambda col=(0.8, 0.8, 0.78, 1): mat("ConcreteFound", "Architecture/T_Arch_ConcreteFoundation.png", col, 0.95)
T_STONE = lambda col=(0.7, 0.66, 0.6, 1): mat("OldStone", "Horror/T_Hor_DampWall.png", (col[0] * 0.8, col[1] * 0.8, col[2] * 0.78, 1), 1.0)
T_DAMP = lambda col=(0.6, 0.65, 0.62, 1): mat("DampStone", "Horror/T_Hor_DampWall.png", col, 1.0)
T_RUST = lambda col=(0.85, 0.7, 0.6, 1): mat("RustMetal", "Furniture/T_Furn_MetalRusted.png", col, 0.85, 0.3)
T_STEEL = lambda col=(0.55, 0.57, 0.6, 1): mat("SteelBrushed", "Furniture/T_Furn_MetalBrushed.png", col, 0.7, 0.5)
BLACK = lambda: mat("Black", None, (0.03, 0.03, 0.035, 1), 0.7, 0.2)
HAZ = lambda: mat("Hazard", "Roads/T_Road_MarkingYellow.png", (1, 1, 1, 1), 0.9)


def fit_uv(ob, size):
    me = ob.data
    bm = bmesh.new()
    bm.from_mesh(me)
    uv = bm.loops.layers.uv.verify()
    for f in bm.faces:
        for l in f.loops:
            l[uv].uv = (l.vert.co.x / size[0] + 0.5, l.vert.co.z / size[2] + 0.5)
    bm.to_mesh(me)
    bm.free()


# ------------------------------------------------------------------ precast concrete wall, 4 m (a panel wall with seams, pilasters, a coping and rebar stubs)
def concrete_wall(fname, broken=False):
    reset()
    L, Th, H = 4.0, 0.4, 3.2
    c = T_STORE()
    box("Panel", (L - 0.3, Th, H - 0.15), (0, 0, (H - 0.15) / 2 + 0.0), c, scale=1.5)
    for sx in (-1, 1):                                          # pilasters
        box("Pilaster", (0.4, Th + 0.14, H), (sx * (L / 2 - 0.2), 0, H / 2), T_DIRTY(), scale=1.2)
    box("Footing", (L, Th + 0.3, 0.22), (0, 0, 0.11), T_FOUND(), scale=1.2)
    box("Coping", (L, Th + 0.14, 0.14), (0, 0, H + 0.07), T_DIRTY(), scale=1.2)
    for z in (0.8, 1.6, 2.4):                                   # shuttering seams
        box("Seam", (L - 0.3, 0.012, 0.02), (0, -Th / 2 - 0.004, z), BLACK(), scale=1.0)
    for x in (-1.0, 0.0, 1.0):
        box("SeamV", (0.02, 0.012, H - 0.3), (x, -Th / 2 - 0.004, H / 2), BLACK(), scale=1.0)
    for i in range(14):                                         # tie holes
        box("Tie", (0.03, 0.012, 0.03), (random.uniform(-1.8, 1.8), -Th / 2 - 0.005, random.uniform(0.3, 2.9)), BLACK(), scale=1.0)
    for x in (-1.4, -0.6, 0.5, 1.5):                            # rebar stubs standing up out of the coping
        r = cyl("Rebar", 0.012, random.uniform(0.18, 0.4), (x, random.uniform(-0.05, 0.05), H + 0.14 + 0.15), T_RUST(), seg=6)
        r.rotation_euler = (random.uniform(-0.3, 0.3), random.uniform(-0.3, 0.3), 0)
    if broken:                                                  # a missing corner and a crack
        box("Hole", (0.9, Th + 0.1, 0.8), (1.3, 0, H - 0.2), mat("Void", None, (0.02, 0.02, 0.02, 1), 1.0), scale=1.0)
    export(fname)


# ------------------------------------------------------------------ chain-link fence section, 4 m
def fence_section(fname):
    reset()
    L, H = 4.0, 3.0
    steel = T_STEEL((0.45, 0.47, 0.5, 1))
    for x in (-L / 2 + 0.06, 0.0, L / 2 - 0.06):
        cyl("Post", 0.05, H + 0.3, (x, 0, (H + 0.3) / 2), steel, seg=8)
    box("TopRail", (L, 0.05, 0.05), (0, 0, H), steel, scale=0.4)
    box("BotRail", (L, 0.05, 0.05), (0, 0, 0.15), steel, scale=0.4)
    link = mat("Link", None, (0.5, 0.52, 0.55, 1), 0.6, 0.6)
    n = 16                                                      # diamond mesh as thin crossing bars (low poly)
    for i in range(n):
        x = -L / 2 + 0.1 + i * (L - 0.2) / (n - 1)
        for sgn in (-1, 1):
            b = box("Link", (0.012, 0.012, 3.2), (x, 0.0, H / 2 + 0.07), link, scale=0.3)
            b.rotation_euler = (0, sgn * 0.62, 0)
    for k in range(3):                                          # barbed wire on outriggers
        z = H + 0.12 + k * 0.1
        box("Barb", (L, 0.012, 0.012), (0, 0.18, z), BLACK(), scale=0.3)
    for x in (-L / 2 + 0.06, 0.0, L / 2 - 0.06):
        o = box("Outrigger", (0.04, 0.4, 0.04), (x, 0.1, H + 0.15), steel, scale=0.3)
        o.rotation_euler = (math.radians(40), 0, 0)
    export(fname)


# ------------------------------------------------------------------ the checkpoint gate: a double steel gate on hinged leaves (GateL/GateR pivot at their hinge edges)
def steel_gate(fname):
    reset()
    W, H = 5.0, 3.2
    steel = T_STEEL((0.5, 0.52, 0.55, 1))
    rust = T_RUST((0.8, 0.65, 0.55, 1))
    for sx in (-1, 1):                                          # massive posts with hinge pins
        box("Post", (0.4, 0.4, H + 0.2), (sx * (W / 2 + 0.2), 0, (H + 0.2) / 2), T_DIRTY(), scale=1.0)
        box("PostCap", (0.5, 0.5, 0.1), (sx * (W / 2 + 0.2), 0, H + 0.25), T_FOUND(), scale=1.0)
    box("Lintel", (W + 0.8, 0.3, 0.3), (0, 0, H + 0.15), T_DIRTY(), scale=1.0)
    for sx, nm in ((-1, "GateL"), (1, "GateR")):
        hx = sx * W / 2                                         # the hinge edge
        piv = (hx, -0.05, 0.0)
        leaf = empty(nm, piv)
        w = W / 2 - 0.04
        cx = hx - sx * w / 2
        # frame
        for (sz, pz, nmz) in ((0.1, 0.25, "Bot"), (0.1, H - 0.4, "Top"), (0.1, H * 0.5, "Mid")):
            b = box(nmz, (w, 0.06, sz), (cx, -0.05, pz), rust, pivot=piv, parent=leaf, scale=0.5)
        for sxx in (-1, 1):
            box("Style", (0.1, 0.06, H - 0.5), (cx + sxx * (w / 2 - 0.05), -0.05, (H - 0.5) / 2 + 0.25), rust, pivot=piv, parent=leaf, scale=0.5)
        for i in range(1, 9):                                   # bars
            box("Bar", (0.035, 0.035, H - 0.65), (cx - w / 2 + i * w / 9, -0.05, (H - 0.65) / 2 + 0.3), steel, pivot=piv, parent=leaf, scale=0.3)
        d = box("Brace", (math.hypot(w, H - 0.7), 0.04, 0.07), (cx, -0.09, H * 0.5), rust, parent=leaf, scale=0.5)
        d.rotation_euler = (0, math.atan2(H - 0.7, w) * (1 if sx < 0 else -1), 0)
        # hinges: knuckles on the post side, a strap across the leaf
        for hz in (0.5, H * 0.5, H - 0.5):
            cyl("Hinge", 0.05, 0.18, (hx, -0.05, hz), BLACK(), seg=8, pivot=piv, parent=leaf)
            box("Strap", (0.5, 0.03, 0.09), (hx - sx * 0.25, -0.09, hz), BLACK(), pivot=piv, parent=leaf, scale=0.3)
        # the latch / bolt at the free edge
        box("Latch", (0.14, 0.08, 0.2), (hx - sx * (w + 0.0), -0.1, H * 0.45), BLACK(), pivot=piv, parent=leaf, scale=0.3)
    # a chain through the two leaves and a padlock
    cyl("Chain", 0.012, 0.5, (0, -0.12, H * 0.45), BLACK(), axis="X", seg=6)
    box("Padlock", (0.12, 0.05, 0.16), (0, -0.12, H * 0.45 - 0.1), mat("Brass", None, (0.55, 0.42, 0.15, 1), 0.5, 0.6), scale=0.2)
    export(fname)


# ------------------------------------------------------------------ the passage hut: a concrete bunker head over a stair, a heavy hinged steel door (Door pivots on its hinge edge)
def passage_hut(fname):
    reset()
    W, D, H = 3.4, 2.8, 2.5                                      # outside size; the hut's front faces -Y (toward the district), its back is the +Y wall
    walls = T_STORE((0.7, 0.7, 0.68, 1))
    dirty = T_DIRTY()
    box("Back", (W, 0.3, H), (0, D - 0.15, H / 2), walls, scale=1.5)
    box("SideL", (0.3, D, H), (-W / 2 + 0.15, D / 2, H / 2), walls, scale=1.5)
    box("SideR", (0.3, D, H), (W / 2 - 0.15, D / 2, H / 2), walls, scale=1.5)
    # the front wall with the doorway (1.4 x 2.0)
    fw = (W - 1.4) / 2
    box("FrontL", (fw, 0.3, H), (-W / 2 + fw / 2, 0.15, H / 2), walls, scale=1.5)
    box("FrontR", (fw, 0.3, H), (W / 2 - fw / 2, 0.15, H / 2), walls, scale=1.5)
    box("FrontTop", (1.4, 0.3, H - 2.0), (0, 0.15, 2.0 + (H - 2.0) / 2), walls, scale=1.5)
    box("Roof", (W + 0.5, D + 0.5, 0.25), (0, D / 2 - 0.1, H + 0.12), dirty, scale=1.5)
    box("Parapet", (W + 0.5, 0.1, 0.18), (0, -0.35, H + 0.34), dirty, scale=1.5)
    box("Floor", (W, D, 0.12), (0, D / 2, 0.06), T_FOUND(), scale=1.5)
    box("Step", (1.8, 0.7, 0.16), (0, -0.5, 0.08), T_FOUND(), scale=1.0)
    # the steel frame round the doorway
    steel = T_STEEL((0.45, 0.48, 0.5, 1))
    box("FrameL", (0.1, 0.34, 2.0), (-0.75, 0.15, 1.0), steel, scale=0.5)
    box("FrameR", (0.1, 0.34, 2.0), (0.75, 0.15, 1.0), steel, scale=0.5)
    box("FrameT", (1.6, 0.34, 0.1), (0, 0.15, 2.05), steel, scale=0.5)
    # the heavy door, hinged on the left: pivot at the hinge edge; shown closed (the game swings it)
    piv = (-0.7, -0.08, 0.0)
    door = empty("Door", piv)
    rust = T_RUST((0.7, 0.6, 0.55, 1))
    box("Leaf", (1.4, 0.1, 1.95), (0.0, -0.08, 0.98), rust, pivot=piv, parent=door, scale=0.7)
    for rz in (0.5, 1.0, 1.5):
        box("Rib", (1.3, 0.03, 0.06), (0.0, -0.14, rz), steel, pivot=piv, parent=door, scale=0.4)
    for hz in (0.4, 1.0, 1.6):
        cyl("Hinge", 0.045, 0.2, (-0.7, -0.08, hz), BLACK(), seg=8, pivot=piv, parent=door)
        box("Strap", (0.5, 0.03, 0.1), (-0.45, -0.14, hz), BLACK(), pivot=piv, parent=door, scale=0.3)
    cyl("Wheel", 0.17, 0.05, (0.45, -0.17, 1.0), BLACK(), axis="Y", seg=14, pivot=piv, parent=door)
    for a in range(4):
        sp = box("Spoke", (0.34, 0.03, 0.03), (0.45, -0.2, 1.0), BLACK(), parent=door, scale=0.3)
        sp.rotation_euler = (0, a * math.pi / 4, 0)
    # a caged lamp over the door, hazard stripes on the step, a stencilled plate
    cyl("Lamp", 0.1, 0.12, (0, -0.15, 2.3), mat("LampGlass", None, (0.9, 0.8, 0.5, 1), 0.3, 0.0, (0.9, 0.7, 0.3, 1)), axis="Y", seg=10)
    for i in range(3):
        box("Cage", (0.01, 0.2, 0.22), (-0.1 + i * 0.1, -0.15, 2.3), BLACK(), scale=0.2)
    box("StepHaz", (1.8, 0.02, 0.07), (0, -0.855, 0.12), HAZ(), scale=0.4)
    pl = box("Plate", (0.7, 0.02, 0.45), (1.55, -0.005, 1.5), mat("PlatePassage", os.path.join(OUT, "tex", "sign_passage.png"), (1, 1, 1, 1), 0.9), scale=0.4)
    fit_uv(pl, (0.7, 0.02, 0.45))
    export(fname)


# ------------------------------------------------------------------ a hinged steel door in a frame (1.0 x 2.1), pivot on the hinge edge
def steel_door(fname):
    reset()
    steel = T_STEEL((0.5, 0.55, 0.52, 1))
    paint = mat("DoorPaint", "Commercial/T_Com_MetalDoorPainted.png", (0.7, 0.75, 0.7, 1), 0.7, 0.4)
    box("FrameL", (0.08, 0.2, 2.12), (-0.54, 0, 1.06), steel, scale=0.5)
    box("FrameR", (0.08, 0.2, 2.12), (0.54, 0, 1.06), steel, scale=0.5)
    box("FrameT", (1.16, 0.2, 0.08), (0, 0, 2.16), steel, scale=0.5)
    piv = (-0.5, 0.0, 0.0)
    door = empty("Door", piv)
    box("Leaf", (1.0, 0.05, 2.08), (0.0, 0.0, 1.04), paint, pivot=piv, parent=door, scale=1.0)
    for hz in (0.3, 1.05, 1.8):
        cyl("Hinge", 0.025, 0.14, (-0.5, 0.0, hz), BLACK(), seg=8, pivot=piv, parent=door)
        box("Strap", (0.3, 0.02, 0.07), (-0.34, -0.03, hz), BLACK(), pivot=piv, parent=door, scale=0.3)
    box("Handle", (0.16, 0.05, 0.03), (0.38, -0.05, 1.0), BLACK(), pivot=piv, parent=door, scale=0.3)
    box("Plate", (0.06, 0.02, 0.2), (0.4, -0.03, 1.0), steel, pivot=piv, parent=door, scale=0.3)
    box("Kick", (0.96, 0.02, 0.2), (0.0, -0.03, 0.12), steel, pivot=piv, parent=door, scale=0.3)
    export(fname)


# ------------------------------------------------------------------ a sign plate on a post (the texture is set per instance in the game)
def sign_plate(fname, tex):
    reset()
    steel = T_STEEL((0.4, 0.42, 0.45, 1))
    cyl("Post", 0.04, 2.4, (0, 0.05, 1.2), steel, seg=8)
    box("Backing", (1.3, 0.03, 0.9), (0, 0, 2.0), steel, scale=0.5)
    face = box("Face", (1.24, 0.012, 0.84), (0, -0.02, 2.0), mat("SignFace_" + os.path.basename(tex), os.path.join(OUT, "tex", tex), (1, 1, 1, 1), 0.8), scale=1.0)
    fit_uv(face, (1.24, 0.012, 0.84))
    for sx in (-0.55, 0.55):
        cyl("Bolt", 0.02, 0.02, (sx, -0.03, 2.35), BLACK(), axis="Y", seg=6)
    export(fname)


# ------------------------------------------------------------------ the ancient chamber
def pillar(fname, height=9.0):
    reset()
    st = T_STONE((0.75, 0.7, 0.64, 1))
    dk = T_DAMP()
    W = 1.0
    box("Plinth", (W + 0.5, W + 0.5, 0.6), (0, 0, 0.3), dk, scale=1.0)
    box("Shaft", (W, W, height - 1.8), (0, 0, 0.6 + (height - 1.8) / 2), st, scale=1.0)
    for i in range(4):                                          # carved rune bands
        z = 1.8 + i * (height - 3.6) / 3.0
        box("Band", (W + 0.08, W + 0.08, 0.14), (0, 0, z), dk, scale=0.6)
        for s in range(5):
            box("Rune", (0.1, 0.02, 0.1), (-0.35 + s * 0.18, -(W / 2 + 0.05), z), BLACK(), scale=0.3)
    box("Cap", (W + 0.5, W + 0.5, 0.5), (0, 0, height - 0.55), dk, scale=1.0)
    box("CapTop", (W + 0.8, W + 0.8, 0.3), (0, 0, height - 0.15), st, scale=1.0)
    export(fname)


def seal_frame(fname):
    reset()
    W, H = 8.8, 7.4                                             # the structure's mouth is 8 x 7: the frame stands round it
    st = T_STONE((0.72, 0.68, 0.62, 1))
    dk = T_DAMP()
    for sx in (-1, 1):
        box("Jamb", (0.9, 1.2, H), (sx * (W / 2 - 0.45), 0, H / 2), st, scale=1.0)
        box("JambBase", (1.3, 1.6, 0.5), (sx * (W / 2 - 0.45), 0, 0.25), dk, scale=1.0)
        for i in range(6):                                      # carved glyph strip down the jamb
            box("Glyph", (0.5, 0.02, 0.3), (sx * (W / 2 - 0.45), -0.61, 1.0 + i * 1.0), BLACK(), scale=0.3)
    box("Lintel", (W + 0.6, 1.4, 1.1), (0, 0, H - 0.1), st, scale=1.0)
    box("LintelCap", (W + 1.0, 1.7, 0.4), (0, 0, H + 0.65), dk, scale=1.0)
    for i in range(9):                                          # a row of carved glyphs along the lintel
        box("Glyph", (0.4, 0.02, 0.4), (-W / 2 + 0.9 + i * 0.85, -0.71, H - 0.1), BLACK(), scale=0.3)
    # a keystone with a ringed eye
    cyl("KeyRing", 0.5, 0.06, (0, -0.72, H - 0.1), dk, axis="Y", seg=20)
    cyl("KeyEye", 0.22, 0.08, (0, -0.74, H - 0.1), BLACK(), axis="Y", seg=14)
    export(fname)


def seal_slab(fname):
    reset()
    st = T_STONE((0.62, 0.58, 0.54, 1))
    iron = T_RUST((0.55, 0.5, 0.45, 1))
    W, H, Th = 8.0, 5.0, 0.6
    box("Slab", (W, Th, H), (0, 0, 0), st, scale=1.5)                # centred (the game moves it)
    for z in (-1.7, 0.0, 1.7):                                  # riveted iron bands across
        box("Band", (W + 0.1, Th + 0.1, 0.26), (0, 0, z), iron, scale=0.8)
        for x in range(-3, 4):
            cyl("Rivet", 0.05, 0.06, (x * 1.1, -(Th / 2 + 0.06), z), BLACK(), axis="Y", seg=6)
    cyl("Disc", 1.5, 0.05, (0, -Th / 2 - 0.03, 0.0), T_DAMP(), axis="Y", seg=28)      # a carved rune disc
    for k in range(8):
        a = k * math.tau / 8
        b = box("Spoke", (0.1, 0.03, 1.2), (math.sin(a) * 0.8, -Th / 2 - 0.06, math.cos(a) * 0.8), BLACK(), scale=0.3)
        b.rotation_euler = (0, a, 0)
    for sx in (-3.0, 3.0):                                      # lifting eyes with chain
        cyl("Eye", 0.2, 0.12, (sx, 0, H / 2 + 0.1), iron, axis="Y", seg=10)
        for j in range(4):
            cyl("Link", 0.045, 0.2, (sx, 0, H / 2 + 0.35 + j * 0.22), BLACK(), seg=6)
    export(fname)


def control_pedestal(fname, wheel=False):
    reset()
    st = T_STONE((0.7, 0.66, 0.6, 1))
    dk = T_DAMP()
    iron = T_RUST((0.6, 0.55, 0.5, 1))
    box("Base", (1.1, 1.1, 0.25), (0, 0, 0.125), dk, scale=1.0)
    box("Column", (0.8, 0.8, 0.75), (0, 0, 0.62), st, scale=1.0)
    top = box("Top", (1.0, 1.0, 0.18), (0, 0, 1.08), dk, scale=1.0)
    box("Face", (0.7, 0.05, 0.5), (0, -0.42, 0.7), iron, scale=0.5)                    # an iron plate on the front with a dial slot
    for i in range(3):                                          # three rune lamps (the game lights them as the control is worked)
        lm = mat("RuneMat%d" % (i + 1), None, (0.1, 0.12, 0.2, 1), 0.4)
        cyl("Rune%d" % (i + 1), 0.05, 0.04, (-0.2 + i * 0.2, -0.46, 0.85), lm, axis="Y", seg=10)
    if not wheel:
        piv = (0, -0.1, 1.17)
        lev = box("Lever", (0.09, 0.09, 0.7), (0, -0.1, 1.17 + 0.35), iron, pivot=piv, scale=0.4)
        cyl("Knob", 0.07, 0.1, (0, -0.1, 1.17 + 0.72), BLACK(), pivot=piv, seg=10, parent=lev)
        lev.rotation_euler = (math.radians(-35), 0, 0)
        box("Quadrant", (0.5, 0.03, 0.2), (0, -0.1, 1.2), BLACK(), scale=0.3)
    else:
        piv = (0, -0.1, 1.5)
        box("Hub", (0.25, 0.25, 0.9), (0, 0.0, 1.5 - 0.45 + 0.0), iron, scale=0.4)
        wh = empty("Wheel", piv)
        cyl("Rim", 0.5, 0.08, (0, -0.1, 1.5), iron, axis="Y", seg=20, pivot=piv, parent=wh)
        cyl("Hole", 0.42, 0.1, (0, -0.1, 1.5), mat("WheelVoid", None, (0.02, 0.02, 0.02, 1), 1.0), axis="Y", seg=20, pivot=piv, parent=wh)
        for a in range(4):
            sp = box("Spoke", (0.06, 0.06, 0.95), (0, -0.1, 1.5), iron, pivot=piv, parent=wh, scale=0.3)
            sp.rotation_euler = (0, a * math.pi / 4, 0)
        cyl("Handle", 0.04, 0.3, (0.48, -0.1, 1.5), BLACK(), axis="Y", seg=6, pivot=piv, parent=wh)
    # cables from the base into the floor
    for x in (-0.3, 0.3):
        cyl("Cable", 0.03, 0.5, (x, 0.45, 0.3), BLACK(), seg=6).rotation_euler = (math.radians(60), 0, 0)
    export(fname)


def doorway_slab(fname):
    reset()
    st = T_STONE((0.62, 0.58, 0.54, 1))
    dk = T_DAMP()
    W, H, Th = 4.0, 4.0, 0.4
    box("Slab", (W, Th, H), (0, 0, H / 2), st, scale=1.2)
    box("Border", (W - 0.3, 0.03, 0.14), (0, -Th / 2 - 0.01, H - 0.3), dk, scale=0.5)
    box("BorderB", (W - 0.3, 0.03, 0.14), (0, -Th / 2 - 0.01, 0.3), dk, scale=0.5)
    cyl("Ring", 0.35, 0.06, (0, -Th / 2 - 0.03, H / 2), dk, axis="Y", seg=20)
    cyl("RingHole", 0.2, 0.08, (0, -Th / 2 - 0.04, H / 2), BLACK(), axis="Y", seg=14)
    for i in range(7):
        box("Glyph", (0.25, 0.02, 0.25), (-1.5 + i * 0.5, -Th / 2 - 0.012, H - 0.9), BLACK(), scale=0.3)
    export(fname)


def rock(fname, size=1.0, seed=1):
    reset()
    random.seed(seed)
    me = bpy.data.meshes.new("Rock")
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=1, radius=size / 2)
    for v in bm.verts:
        v.co *= Vector((random.uniform(0.8, 1.25), random.uniform(0.7, 1.2), random.uniform(0.6, 1.1)))
    _uv_box(bm, 1.0)
    bm.normal_update()
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("Rock", me)
    bpy.context.scene.collection.objects.link(ob)
    ob.location = (0, 0, size * 0.3)
    me.materials.append(T_STONE((0.6, 0.57, 0.52, 1)))
    export(fname)


if __name__ == "__main__":
    concrete_wall("DST_ConcreteWall_4m.glb")
    concrete_wall("DST_ConcreteWall_4m_Broken.glb", broken=True)
    fence_section("DST_FenceSection_4m.glb")
    steel_gate("DST_SteelGate.glb")
    passage_hut("DST_PassageHut.glb")
    steel_door("PRP_SteelDoor_Hinged.glb")
    sign_plate("DST_Sign_Restricted.glb", "sign_restricted.png")
    sign_plate("DST_Sign_Order.glb", "sign_order.png")
    sign_plate("DST_Sign_Danger.glb", "sign_danger.png")
    pillar("ANC_Pillar.glb", 9.0)
    seal_frame("ANC_SealFrame.glb")
    seal_slab("ANC_SealSlab.glb")
    control_pedestal("ANC_ControlLever.glb")
    control_pedestal("ANC_ControlWheel.glb", wheel=True)
    doorway_slab("ANC_DoorwaySlab.glb")
    rock("ANC_Rock_A.glb", 1.1, 1)
    rock("ANC_Rock_B.glb", 0.7, 2)
    rock("ANC_Rock_C.glb", 1.6, 3)
