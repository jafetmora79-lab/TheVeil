"""Pack 08 item models (priority order). Each function returns a writer spec (see inv_geom.finish).

All original designs: no real brands, no functional weapon mechanisms. Dimensions in metres, lightly exaggerated
(thicker edges, chunkier grips) for first-person readability.
"""
import math

import numpy as np

from inv_geom import G, finish, rot, nrm

V = lambda *a: np.array(a, float)
FLAT = np.column_stack([V(1, 0, 0), V(0, 0, -1), V(0, 1, 0)])       # outline x -> X, outline y -> -Z, thickness -> +Y
SIDE = np.column_stack([V(0, 0, -1), V(0, 1, 0), V(1, 0, 0)])       # outline x -> -Z, outline y -> Y, thickness -> +X


def circle(r, n, cx=0.0, cy=0.0, a0=0.0):
    return [(cx + r * math.cos(a0 + 2 * math.pi * k / n), cy + r * math.sin(a0 + 2 * math.pi * k / n)) for k in range(n)]


# ======================================================================= A. essential story & exploration
def _key_blade(g, origin, Rm, face="brass", length=0.036, w=0.0085, t=0.0028, teeth=(0, 1, 0, 2, 1, 0, 1)):
    pts = [(-w / 2, 0.0)]
    n = len(teeth)
    for i, d in enumerate(teeth):                     # cut profile along one edge
        y = 0.004 + (length - 0.01) * i / n
        pts.append((-w / 2 + 0.0012 * d, y))
        pts.append((-w / 2 + 0.0012 * d, y + (length - 0.01) / n * 0.6))
    pts += [(-w / 2 + 0.0015, length - 0.002), (0.0, length), (w / 2, length - 0.004), (w / 2, 0.0)]
    g.extrude(pts, 0, t, origin, Rm, face, "steel" if face != "brass" else "brass")


def house_key(g=None, origin=V(0, 0, 0), Rm=FLAT):
    own = g is None
    g = g or G()
    bow = circle(0.0135, 10, 0, -0.012)
    g.extrude(bow, 0, 0.0032, origin, Rm, "brass", "brass")
    g.extrude([(-0.005, -0.002), (0.005, -0.002), (0.005, 0.002), (-0.005, 0.002)], 0, 0.0034, origin, Rm, "brass", "brass")
    _key_blade(g, origin + Rm @ V(0, 0.001, 0), Rm)
    g.extrude(circle(0.0035, 8, 0, -0.017), 0.0031, 0.0036, origin, Rm, "plastic_black", "plastic_black")   # punched hole
    return finish("INV_HouseKey", g, "Story_Items", "Brass house key with a round bow.", grip=V(0, 0.002, 0.012)) if own else g


def car_key(g=None, origin=V(0, 0, 0), Rm=FLAT):
    own = g is None
    g = g or G()
    head = [(-0.016, -0.03), (0.016, -0.03), (0.019, -0.012), (0.013, 0.0), (-0.013, 0.0), (-0.019, -0.012)]
    g.extrude(head, -0.003, 0.0095, origin, Rm, "fob", "rubber", back_rect="rubber")
    g.extrude(circle(0.004, 8, 0, -0.024), 0.0095, 0.0105, origin, Rm, "steel_dark", "steel_dark")
    _key_blade(g, origin + Rm @ V(0, 0.0, 0.002), Rm, face="steel", length=0.05, w=0.0095, t=0.0026, teeth=(1, 0, 2, 1, 1, 0, 2, 0))
    return finish("INV_CarKey", g, "Story_Items", "Older-sedan ignition key: chunky black rubber head, steel blade.",
                  grip=V(0, 0.004, 0.015)) if own else g


def keyring():
    g = G()
    g.ring(V(0, 0, 0), V(0, 1, 0), 0.0135, 0.0165, 0.0025, "steel", "chrome", seg=16)
    house_key(g, V(0.012, 0.0026, -0.016), FLAT @ np.array(rot(roll=-25)))
    car_key(g, V(-0.010, 0.0052, -0.012), FLAT @ np.array(rot(roll=30)))
    tag = [(-0.012, 0.0), (0.012, 0.0), (0.012, 0.022), (0.0, 0.03), (-0.012, 0.022)]
    g.extrude(tag, 0, 0.002, V(-0.014, 0.011, 0.012), FLAT @ np.array(rot(roll=150)), "keytag", "plastic_red", back_rect="plastic_red")
    return finish("INV_Keyring", g, "Story_Items", "Steel split ring with house key, car key and a red HOME tag.", grip=V(0, 0.004, 0))


def flashlight():
    g = G()
    z = lambda t: V(0, 0.032, 0) + V(0, 0, -t)         # long axis along -Z, lying on its side
    p0, ax = z(0), V(0, 0, -1)
    prof = [(0.000, 0.012), (0.004, 0.0175), (0.022, 0.0175), (0.024, 0.0185), (0.026, 0.0185), (0.028, 0.019), (0.150, 0.019),
            (0.175, 0.029), (0.188, 0.031), (0.196, 0.031)]
    rects = ["rubber", "rubber_grip", "steel", "steel", "steel_dark", "rubber_grip", "plastic_black", "chrome", "chrome"]
    g.lathe(p0, ax, prof, "plastic_black", seg=12, rects=rects, caps=(True, False), cap_rect="rubber")
    g.lathe(z(0.194), ax, [(0.0, 0.0255), (0.004, 0.0255)], "chrome", seg=12, caps=(False, True), cap_rect="flash_lens")   # recessed lens
    g.lathe(z(0.196), ax, [(0.0, 0.031), (0.0, 0.0255)], "chrome", seg=12, caps=(False, False))
    g.box(z(0.120) + V(0, 0.020, 0), (0.012, 0.006, 0.020), "plastic_red", taper=(0.8, 0.8))                       # switch
    g.box(z(0.060) + V(0, 0.0185, 0), (0.016, 0.003, 0.05), "plastic_gray")                                           # battery door
    g.box(z(0.002) + V(0, -0.006, 0.004), (0.006, 0.004, 0.012), "rubber")                                              # lanyard loop
    return finish("INV_Flashlight", g, "Story_Items", "Two-cell flashlight: knurled grip, red thumb switch, battery door, flared head, recessed lens.",
                  grip=V(0, 0.032, -0.09), extra_nodes=[("Beam_Origin", V(0, 0.032, -0.2))], holdable=True,
                  grip_note="palm around the body at Grip, thumb on the switch; beam leaves Beam_Origin along -Z")


def battery(name="INV_FlashlightBattery", r=0.0165, L=0.061, label="battery"):
    g = G()
    p0 = V(0, r, 0)
    g.lathe(p0, V(0, 0, -1), [(0.0, r * 0.92), (0.002, r), (L - 0.002, r), (L, r * 0.92)], label, seg=12,
            rects=["steel", label, "steel"], cap_rect="steel")
    g.cyl(p0 + V(0, 0, -L), p0 + V(0, 0, -L - 0.003), r * 0.32, r * 0.3, "chrome", seg=8, cap_rect="chrome")
    return finish(name, g, "Story_Items", "D-size cell for the flashlight (original label).")


def radio():
    g = G()
    W_, H_, D_ = 0.062, 0.15, 0.036
    c = V(0, H_ / 2, 0)
    g.box(c, (W_, H_, D_), "plastic_black", faces={"+z": "plastic_black"}, taper=(0.94, 0.94))
    g.decal(c + V(0, 0.032, D_ / 2), 0.05, 0.05, V(0, 0, 1), V(0, 1, 0), "radio_face")
    g.decal(c + V(0, -0.035, D_ / 2), 0.046, 0.05, V(0, 0, 1), V(0, 1, 0), "grille")
    g.cyl(c + V(-0.018, H_ / 2 - 0.004, 0), c + V(-0.018, H_ / 2 + 0.10, 0), 0.0065, 0.0045, "rubber", seg=8)       # antenna
    g.cyl(c + V(0.016, H_ / 2 - 0.004, 0), c + V(0.016, H_ / 2 + 0.014, 0), 0.008, 0.008, "rubber_grip", seg=10, cap_rect="plastic_gray")
    g.box(c + V(-W_ / 2 - 0.002, 0.015, 0), (0.006, 0.04, 0.02), "plastic_gray")                                      # push-to-talk
    g.box(c + V(0, 0.02, -D_ / 2 - 0.004), (0.03, 0.07, 0.008), "plastic_black", taper=(0.9, 1.0))                     # belt clip
    g.box(c + V(0, -H_ / 2 + 0.004, 0.0), (W_ * 1.02, 0.008, D_ * 1.04), "rubber")                                      # rubber foot
    return finish("INV_HandheldRadio", g, "Story_Items", "Two-way handheld radio: antenna, channel knob, LCD + keypad, speaker grille, PTT, belt clip.",
                  grip=c + V(0, -0.02, 0), holdable=True, grip_note="palm on the back/side, thumb on the side push-to-talk")


def folded_note():
    g = G()
    w, h = 0.09, 0.06
    g.box(V(0, 0.0005, h / 4), (w, 0.001, h / 2), "paper_yellow", faces={"+y": "note"})
    Rm = rot(pitch=-14)
    g.box(V(0, 0.0005, -h / 4) + Rm @ V(0, 0, 0) + V(0, 0.003, 0), (w, 0.001, h / 2), "paper_yellow", Rm=Rm, faces={"+y": "note"})
    return finish("INV_FoldedNote", g, "Story_Items", "Note folded once, half lifted.", grip=V(0, 0.002, 0), holdable=True)


def _book(g, c, size, cover, page="page_edge", spine_rect="plastic_blue", strap=False):
    w, t, d = size                       # w across, t thickness, d length (along Z)
    g.box(c + V(0, t / 2, 0), (w - 0.004, t - 0.004, d - 0.006), "paper_white", faces={"+x": page, "-x": page, "+z": page, "-z": page})
    for y in (0.001, t - 0.001):
        g.box(c + V(0, y, 0), (w, 0.0025, d), spine_rect, faces={"+y": cover, "-y": cover})
    g.box(c + V(-w / 2 + 0.002, t / 2, 0), (0.006, t, d), spine_rect)
    if strap:
        g.box(c + V(w * 0.35, t / 2, 0), (0.022, t + 0.003, 0.02), "leather_brown")
        g.box(c + V(w * 0.42, t + 0.002, 0), (0.016, 0.006, 0.016), "brass", faces={"+y": "padlock"})


def notebook():
    g = G()
    _book(g, V(0, 0, 0), (0.105, 0.016, 0.148), "notebook_cover", spine_rect="plastic_blue")
    for k in range(7):                  # wire spiral along the spine
        g.ring(V(-0.052, 0.008, -0.06 + k * 0.02), V(0, 0, 1), 0.006, 0.0075, 0.002, "steel", seg=8)
    return finish("INV_Notebook", g, "Story_Items", "Spiral pocket notebook: card cover, page block, wire spine.", grip=V(-0.02, 0.008, 0.0), holdable=True,
                  grip_note="held open in the left hand; cover hinges on the -X spine")


def pen():
    g = G()
    p0 = V(0, 0.0055, 0)
    g.lathe(p0, V(0, 0, -1), [(0.0, 0.0), (0.006, 0.0022), (0.014, 0.0045), (0.12, 0.0048), (0.135, 0.0048), (0.138, 0.003)], "ink_blue",
            rects=["steel", "plastic_white", "ink_blue", "plastic_white", "plastic_white"], seg=8)
    g.box(p0 + V(0, 0.005, -0.112), (0.0025, 0.002, 0.04), "chrome")
    return finish("INV_Pen", g, "Story_Items", "Ballpoint pen with clip.", grip=V(0, 0.005, -0.03))


def town_map():
    g = G()
    w, d = 0.115, 0.165
    for k, (dy, dx) in enumerate(((0.0, 0.0), (0.0022, 0.002), (0.0044, -0.0015))):
        g.box(V(dx, 0.0011 + dy, 0), (w, 0.0022, d), "paper_yellow", faces={"+y": "map" if k == 2 else "paper_yellow"})
    return finish("INV_TownMap", g, "Story_Items", "Folded Greyhaven street map (printed from the town's real road layout).",
                  grip=V(0, 0.003, 0.04), holdable=True)


def wallet():
    g = G()
    g.box(V(0, 0.009, 0), (0.11, 0.018, 0.09), "leather_brown", faces={"-x": "wallet_inside"}, taper=(0.98, 0.98))
    g.box(V(0.0, 0.018, 0), (0.104, 0.0015, 0.084), "leather_brown")
    g.box(V(0.054, 0.009, 0), (0.004, 0.016, 0.092), "leather_black")
    return finish("INV_Wallet", g, "Story_Items", "Worn bifold leather wallet with cards peeking out.")


def wristwatch():
    g = G()
    c = V(0, 0.03, 0)
    g.cyl(c + V(0, -0.0045, 0), c + V(0, 0.0045, 0), 0.0195, 0.0185, "steel", seg=14, cap_rect="watch_face")
    g.cyl(c + V(0.019, 0, 0), c + V(0.024, 0, 0), 0.0028, 0.0028, "chrome", seg=6)
    loop = [c + V(0, -0.03 * math.cos(a), 0.022 * math.sin(a)) for a in np.linspace(0.35, 2 * math.pi - 0.35, 14)]
    g.sweep(loop, 0.0035, "leather_black", seg=5, squash=3.2)
    return finish("INV_Wristwatch", g, "Story_Items", "Steel wristwatch on a black strap; hands read 6:42.")


# ======================================================================= B. survival & medical
def first_aid_kit():
    g = G()
    c = V(0, 0.045, 0)
    g.box(c + V(0, -0.017, 0), (0.26, 0.056, 0.17), "plastic_white", taper=(1.0, 1.0))
    g.box(c + V(0, 0.022, 0), (0.256, 0.024, 0.166), "plastic_white", taper=(0.95, 0.94))
    g.box(c + V(0, 0.010, 0), (0.262, 0.004, 0.172), "plastic_red")                                   # seam band
    g.decal(c + V(0, 0.034, 0), 0.07, 0.07, V(0, 1, 0), V(0, 0, -1), "firstaid")
    g.decal(c + V(0, -0.012, 0.085), 0.04, 0.04, V(0, 0, 1), V(0, 1, 0), "firstaid")
    for sx in (-1, 1):
        g.box(c + V(sx * 0.07, 0.006, 0.088), (0.026, 0.028, 0.008), "plastic_gray")                 # latches
    g.sweep([c + V(-0.05, 0.034, -0.03), c + V(-0.04, 0.052, -0.03), c + V(0.04, 0.052, -0.03), c + V(0.05, 0.034, -0.03)], 0.006,
            "plastic_red", seg=6)
    return finish("INV_FirstAidKit", g, "Medical", "Hard-shell first-aid case: lid seam, two latches, carry handle, red cross.",
                  grip=c + V(0, 0.05, -0.03))


def bandage_roll():
    g = G()
    g.cyl(V(-0.025, 0.03, 0), V(0.025, 0.03, 0), 0.03, 0.03, "bandage", seg=12, cap_rect="bandage_end")
    g.box(V(0.0, 0.0012, 0.045), (0.05, 0.0018, 0.04), "bandage")
    return finish("INV_BandageRoll", g, "Medical", "Gauze bandage roll with a loose tail.")


def medicine_bottle():
    g = G()
    g.lathe(V(0, 0, 0), V(0, 1, 0), [(0.0, 0.019), (0.004, 0.021), (0.058, 0.021), (0.064, 0.016), (0.066, 0.016)], "plastic_orange",
            rects=["plastic_orange", "med_label", "plastic_orange", "plastic_orange"], seg=12, cap_rect="plastic_orange")
    g.lathe(V(0, 0.064, 0), V(0, 1, 0), [(0.0, 0.019), (0.018, 0.019), (0.02, 0.017)], "plastic_white", seg=14, cap_rect="plastic_white")
    return finish("INV_MedicineBottle", g, "Medical", "Amber pill bottle with child-safe cap and prescription label.")


def painkillers():
    g = G()
    g.box(V(0, 0.025, 0), (0.08, 0.05, 0.022), "plastic_white", faces={"+z": "pill_box", "-z": "pill_box"})
    g.box(V(0, 0.052, 0.006), (0.08, 0.004, 0.01), "plastic_white", Rm=rot(pitch=30))
    g.box(V(0.03, 0.035, -0.002), (0.05, 0.03, 0.002), "aluminum", Rm=rot(roll=-75))                 # blister sheet sliding out
    for k in range(3):
        g.cyl(V(0.04, 0.02 + k * 0.012, 0.0), V(0.044, 0.02 + k * 0.012, 0.0), 0.004, 0.003, "glass_clear", seg=6)
    return finish("INV_PainkillerPack", g, "Medical", "Painkiller carton with a blister strip sliding out.")


def water_bottle():
    g = G()
    prof = [(0.0, 0.03), (0.004, 0.033), (0.03, 0.033), (0.035, 0.031), (0.04, 0.033), (0.13, 0.033), (0.17, 0.022), (0.185, 0.013), (0.19, 0.013)]
    g.lathe(V(0, 0, 0), V(0, 1, 0), prof, "glass_clear", seg=12, rects=["glass_clear", "glass_clear", "glass_clear", "glass_clear", "water_label",
                                                                        "glass_clear", "glass_clear", "glass_clear"], cap_rect="glass_clear")
    g.lathe(V(0, 0.19, 0), V(0, 1, 0), [(0.0, 0.0145), (0.016, 0.0145), (0.018, 0.013)], "plastic_blue", seg=12, cap_rect="plastic_blue")
    return finish("INV_WaterBottle", g, "Food_And_Supplies", "Half-litre spring-water bottle with ribbed waist and blue cap.")


def canned_food(label="can_label", name="INV_CannedFood"):
    g = G()
    g.lathe(V(0, 0, 0), V(0, 1, 0), [(0.0, 0.035), (0.004, 0.038), (0.008, 0.038), (0.102, 0.038), (0.106, 0.038), (0.11, 0.035)], "steel",
            rects=["steel", "steel", label, "steel", "steel"], seg=14, cap_rect="steel")
    g.ring(V(0, 0.109, 0.016), V(0, 1, 0), 0.006, 0.0095, 0.0015, "aluminum", seg=8)               # pull tab
    return finish(name, g, "Food_And_Supplies", "Tin of beans with an original label and pull tab.")


def energy_snack():
    g = G()
    g.box(V(0, 0.011, 0), (0.042, 0.022, 0.11), "plastic_orange", faces={"+y": "snack", "-y": "snack"})
    for s in (-1, 1):
        g.box(V(0, 0.011, s * 0.062), (0.044, 0.004, 0.016), "plastic_orange", taper=(1.0, 1.0))
    return finish("INV_EnergySnack", g, "Food_And_Supplies", "Oat energy bar in a crimped wrapper.")


def backpack():
    g = G()
    c = V(0, 0.21, 0)
    g.box(c, (0.30, 0.42, 0.15), "canvas_olive", taper=(0.82, 0.85))
    g.box(c + V(0, 0.19, 0), (0.25, 0.05, 0.14), "canvas_olive", taper=(0.7, 0.7))                  # rounded top
    g.box(c + V(0, -0.08, 0.09), (0.22, 0.17, 0.05), "canvas_olive", taper=(0.9, 0.8))             # front pocket
    g.decal(c + V(0, -0.05, 0.116), 0.04, 0.04, V(0, 0, 1), V(0, 1, 0), "bag_patch")
    g.box(c + V(0, 0.005, 0.111), (0.21, 0.006, 0.006), "steel_dark")                                 # zips
    g.box(c + V(0, 0.15, 0.064), (0.24, 0.006, 0.006), "steel_dark")
    g.box(c + V(0.08, 0.157, 0.07), (0.012, 0.022, 0.004), "plastic_black")                           # zip pull
    for sx in (-1, 1):
        strap = [c + V(sx * 0.08, 0.19, -0.075), c + V(sx * 0.09, 0.14, -0.11), c + V(sx * 0.1, 0.0, -0.12), c + V(sx * 0.11, -0.14, -0.1),
                 c + V(sx * 0.12, -0.19, -0.07)]
        g.sweep(strap, 0.016, "canvas_navy", seg=4, squash=0.3)
        g.box(c + V(sx * 0.11, -0.11, -0.112), (0.034, 0.024, 0.01), "plastic_black")               # buckle
        g.box(c + V(sx * 0.13, -0.08, 0.0), (0.03, 0.12, 0.10), "canvas_olive", taper=(0.8, 0.8))      # side pockets
    g.sweep([c + V(-0.04, 0.215, -0.02), c + V(-0.02, 0.245, -0.02), c + V(0.02, 0.245, -0.02), c + V(0.04, 0.215, -0.02)], 0.008,
            "canvas_navy", seg=5)
    return finish("INV_SmallBackpack", g, "Food_And_Supplies", "Small daypack: main body, front and side pockets, zips, shoulder straps with buckles, grab loop.",
                  grip=c + V(0, 0.23, -0.02))


def emergency_lantern():
    g = G()
    g.lathe(V(0, 0, 0), V(0, 1, 0), [(0.0, 0.055), (0.035, 0.055), (0.04, 0.045)], "plastic_dark_green", seg=12, cap_rect="plastic_dark_green")
    g.lathe(V(0, 0.04, 0), V(0, 1, 0), [(0.0, 0.04), (0.05, 0.044), (0.1, 0.04)], "lantern_face", seg=12, caps=(False, False))
    for k in range(6):
        a = 2 * math.pi * k / 6
        g.box(V(0.046 * math.cos(a), 0.09, 0.046 * math.sin(a)), (0.008, 0.1, 0.008), "plastic_dark_green", Rm=rot(yaw=-math.degrees(a)))
    g.lathe(V(0, 0.14, 0), V(0, 1, 0), [(0.0, 0.05), (0.02, 0.05), (0.035, 0.02)], "plastic_dark_green", seg=12, cap_rect="plastic_gray")
    g.sweep([V(-0.035, 0.168, 0), V(-0.03, 0.215, 0), V(0.0, 0.232, 0), V(0.03, 0.215, 0), V(0.035, 0.168, 0)], 0.0045, "steel", seg=6)
    g.box(V(0.0, 0.015, 0.056), (0.022, 0.014, 0.006), "plastic_orange")                               # switch
    return finish("INV_EmergencyLantern", g, "Food_And_Supplies", "Battery camping lantern: base, caged glowing globe, cap, wire handle.",
                  grip=V(0, 0.22, 0), extra_nodes=[("Light_Origin", V(0, 0.09, 0))])


def spare_batteries():
    g = G()
    g.box(V(0, 0.0015, 0), (0.07, 0.003, 0.11), "cardboard", faces={"+y": "battery9"})
    g.box(V(0, 0.012, 0.008), (0.06, 0.018, 0.07), "glass_clear", skip=("-y",))
    for k in range(4):
        p = V(-0.022 + k * 0.0147, 0.01, 0.043)
        g.lathe(p, V(0, 0, -1), [(0.0, 0.0068), (0.049, 0.0068), (0.05, 0.004)], "battery", seg=8, rects=["battery", "steel"], cap_rect="steel")
    return finish("INV_SpareBatteries", g, "Food_And_Supplies", "Blister pack of four AA cells on a card.")


# ======================================================================= C. tools
def screwdriver():
    g = G()
    p0 = V(0, 0.016, 0)
    g.lathe(p0, V(0, 0, -1), [(0.0, 0.012), (0.004, 0.015), (0.07, 0.016), (0.088, 0.012), (0.095, 0.007)], "plastic_yellow",
            rects=["plastic_yellow", "rubber_grip", "plastic_yellow", "plastic_yellow"], seg=8, smooth=False, cap_rect="plastic_yellow")
    g.cyl(p0 + V(0, 0, -0.095), p0 + V(0, 0, -0.19), 0.0035, 0.0035, "chrome", seg=6)
    g.box(p0 + V(0, 0, -0.196), (0.009, 0.0022, 0.014), "chrome", taper=(0.7, 1.0))
    return finish("INV_Screwdriver", g, "Tools", "Flat-head screwdriver, faceted yellow handle with rubber grip.", grip=p0 + V(0, 0, -0.04), holdable=True)


def adjustable_wrench():
    g = G()
    head = [(-0.006, 0.0), (0.006, 0.0), (0.008, 0.14), (0.022, 0.16), (0.024, 0.19), (0.008, 0.2), (0.008, 0.183), (-0.004, 0.18),
            (-0.012, 0.196), (-0.026, 0.188), (-0.022, 0.158), (-0.008, 0.142)]
    g.extrude(head, 0, 0.01, V(0, 0, 0.09), FLAT, "steel", "steel_dark")
    g.cyl(V(-0.003, 0.005, -0.06), V(0.009, 0.005, -0.06), 0.0055, 0.0055, "steel_dark", seg=8)
    g.extrude(circle(0.004, 8, 0.0, 0.01), 0.009, 0.0105, V(0, 0, 0.09), FLAT, "plastic_black", "plastic_black")
    return finish("INV_AdjustableWrench", g, "Tools", "Adjustable wrench with knurled worm wheel and hang hole.", grip=V(0, 0.005, 0.05), holdable=True)


def hammer():
    g = G()
    p0 = V(0, 0.017, 0.15)
    g.lathe(p0, V(0, 0, -1), [(0.0, 0.016), (0.01, 0.017), (0.12, 0.015), (0.27, 0.013)], "wood_handle", seg=8, squash=0.75, cap_rect="wood_dark",
            rects=["wood_handle", "rubber_grip", "wood_handle"])
    h = p0 + V(0, 0, -0.285)
    g.box(h, (0.026, 0.03, 0.034), "steel_dark")
    g.cyl(h + V(0.012, 0, 0), h + V(0.06, 0, 0), 0.015, 0.017, "steel", seg=8, cap_rect="chrome")
    g.box(h + V(-0.04, 0.0, 0), (0.06, 0.022, 0.014), "steel", taper=(0.5, 0.9), Rm=rot(roll=90 - 12))
    return finish("INV_Hammer", g, "Tools", "Claw hammer: wooden handle with grip band, steel head and curved claw.", grip=p0 + V(0, 0, -0.06), holdable=True)


def crowbar():
    g = G()
    y = 0.012
    path = [V(0, y, 0.30), V(0, y, -0.22), V(0, y + 0.012, -0.262), V(0, y + 0.04, -0.29), V(0, y + 0.075, -0.292), V(0, y + 0.1, -0.272)]
    g.sweep(path, 0.0105, "axe_red", seg=6)
    g.box(V(0, y + 0.002, 0.315), (0.024, 0.008, 0.04), "steel_worn", taper=(0.85, 1.0))                    # flat pry end
    g.box(V(0, y + 0.112, -0.262), (0.022, 0.03, 0.009), "steel_worn", Rm=rot(pitch=-35))                   # split claw
    return finish("INV_Crowbar", g, "Tools", "Red-painted crowbar: hex shaft, gooseneck with split claw, flat chisel end; paint worn at the ends.",
                  grip=V(0, y, 0.18), holdable=True, grip_note="two-hand or one-hand grip near the chisel end; hook toward -Z")


def pliers():
    g = G()
    for s in (-1, 1):
        g.sweep([V(s * 0.006, 0.008, 0.0), V(s * 0.014, 0.008, 0.06), V(s * 0.02, 0.008, 0.13)], 0.0062, "plastic_red", seg=6)
        g.extrude([(s * 0.0, 0.0), (s * 0.009, 0.0), (s * 0.006, 0.05), (s * 0.001, 0.055)] if s > 0 else
                  [(0.0, 0.0), (0.001, 0.055), (-0.006, 0.05), (-0.009, 0.0)], 0.002, 0.0095, V(0, 0, 0.0), FLAT, "steel", "steel_dark")
    g.cyl(V(0, 0.0, -0.002), V(0, 0.012, -0.002), 0.0075, 0.0075, "steel_dark", seg=8, cap_rect="chrome")
    return finish("INV_Pliers", g, "Tools", "Combination pliers with red handles.", grip=V(0, 0.008, 0.08), holdable=True)


def pocketknife():
    g = G()
    hnd = [(-0.009, 0.0), (0.009, 0.0), (0.011, 0.04), (0.009, 0.085), (-0.009, 0.085), (-0.011, 0.04)]
    g.extrude(hnd, 0, 0.012, V(0, 0, 0.04), FLAT, "wood_handle", "wood_dark")
    for yy in (0.002, 0.08):
        g.extrude([(-0.0095, yy), (0.0095, yy), (0.0095, yy + 0.008), (-0.0095, yy + 0.008)], -0.0005, 0.0125, V(0, 0, 0.04), FLAT, "chrome", "chrome")
    blade = [(-0.007, 0.0), (0.008, 0.0), (0.008, 0.05), (0.0, 0.072), (-0.007, 0.055)]
    g.extrude(blade, 0.004, 0.0072, V(0, 0, 0.04 - 0.085), FLAT, "knife_side", "steel")
    return finish("INV_Pocketknife", g, "Tools", "Folding pocketknife, blade open, wooden scales and steel bolsters.", grip=V(0, 0.006, 0.0), holdable=True)


def duct_tape():
    g = G()
    g.ring(V(0, 0, 0), V(0, 1, 0), 0.037, 0.052, 0.048, "tape_gray", rect_top="tape_side", seg=16, inner_rect="cardboard")
    g.box(V(0.052, 0.024, 0.02), (0.002, 0.046, 0.04), "tape_gray", Rm=rot(yaw=20))
    return finish("INV_DuctTape", g, "Tools", "Roll of grey duct tape on a cardboard core, loose end lifted.")


def rope_bundle():
    g = G()
    for k in range(5):
        ang = k * 0.5
        pts = [V(0.1 * math.cos(t) * (1 + 0.03 * k), 0.012 + 0.016 * k + 0.004 * math.sin(3 * t), 0.065 * math.sin(t) + 0.004 * k)
               for t in np.linspace(0, 2 * math.pi, 17)]
        R_ = rot(yaw=math.degrees(ang) * 0.1)
        g.sweep([R_ @ p for p in pts], 0.0105, "rope", seg=6, caps=False)
    for s in (-1, 1):
        g.sweep([V(s * 0.1, 0.0, -0.02), V(s * 0.115, 0.04, 0.0), V(s * 0.1, 0.09, 0.02)], 0.012, "rope", seg=6)
    g.ring(V(0.1, 0.0, 0.0), V(0, 1, 0), 0.002, 0.016, 0.09, "rope", seg=8)
    return finish("INV_RopeBundle", g, "Tools", "Coiled length of natural-fibre rope with binding wraps.", grip=V(0, 0.09, 0))


def padlock():
    g = G()
    g.box(V(0, 0.022, 0), (0.05, 0.044, 0.022), "brass", faces={"+z": "padlock"}, taper=(1.0, 1.0))
    g.sweep([V(-0.016, 0.042, 0), V(-0.016, 0.062, 0), V(-0.01, 0.074, 0), V(0.0, 0.077, 0), V(0.01, 0.074, 0), V(0.016, 0.062, 0), V(0.016, 0.042, 0)],
            0.0045, "chrome", seg=8)
    return finish("INV_Padlock", g, "Tools", "Brass padlock with steel shackle.")


def bolt_cutters():
    g = G()
    for s in (-1, 1):
        g.sweep([V(s * 0.012, 0.016, -0.06), V(s * 0.03, 0.016, 0.15), V(s * 0.045, 0.016, 0.45)], 0.011, "steel_dark", seg=6)
        g.cyl(V(s * 0.036, 0.016, 0.28), V(s * 0.046, 0.016, 0.47), 0.016, 0.016, "plastic_red", seg=8, cap_rect="plastic_red")
        g.box(V(s * 0.008, 0.016, -0.1), (0.016, 0.02, 0.07), "steel", taper=(0.6, 1.0))
    g.box(V(0, 0.016, -0.055), (0.05, 0.026, 0.04), "steel_dark")
    g.cyl(V(0, 0.002, -0.055), V(0, 0.03, -0.055), 0.008, 0.008, "chrome", seg=8)
    return finish("INV_BoltCutters", g, "Tools", "Long-handled bolt cutters, red grips.", grip=V(0, 0.016, 0.38), holdable=True)


def portable_fuse():
    g = G()
    p0 = V(0, 0.011, 0)
    g.cyl(p0 + V(0, 0, 0.025), p0 + V(0, 0, -0.025), 0.009, 0.009, "fuse", seg=10, cap_rect="steel")
    for z in (0.03, -0.03):
        g.cyl(p0 + V(0, 0, z - 0.006 * np.sign(z)), p0 + V(0, 0, z + 0.004 * np.sign(z)), 0.0105, 0.0105, "steel", seg=10, cap_rect="chrome")
    return finish("INV_PortableFuse", g, "Tools", "Glass cartridge fuse with metal end caps (30 A).")


def electrical_switch():
    g = G()
    g.box(V(0, 0.012, 0), (0.07, 0.024, 0.115), "plastic_white", faces={"+y": "switch"})
    g.box(V(0, 0.03, -0.01), (0.014, 0.012, 0.022), "plastic_white", Rm=rot(pitch=20))
    for z in (0.048, -0.048):
        g.cyl(V(0, 0.024, z), V(0, 0.027, z), 0.004, 0.004, "steel", seg=6, cap_rect="steel")
    for sx, col in ((-0.015, "copper"), (0.015, "copper")):
        g.sweep([V(sx, 0.006, 0.058), V(sx, 0.004, 0.08), V(sx * 1.6, 0.003, 0.1)], 0.0025, col, seg=5)
    return finish("INV_ElectricalSwitch", g, "Tools", "Wall toggle switch component with mounting screws and wire tails.")


# ======================================================================= D. defensive (props only: no mechanisms)
def baseball_bat():
    g = G()
    p0 = V(0, 0.034, 0.42)
    prof = [(0.0, 0.0), (0.006, 0.021), (0.014, 0.02), (0.02, 0.0135), (0.22, 0.0145), (0.4, 0.022), (0.62, 0.032), (0.80, 0.034), (0.83, 0.03), (0.84, 0.0)]
    g.lathe(p0, V(0, 0, -1), prof, "wood_light", seg=12, rects=["wood_dark", "wood_dark", "wood_light", "tape_gray", "wood_light", "wood_light",
                                                                  "wood_light", "wood_light", "wood_light"])
    return finish("INV_BaseballBat", g, "Weapons", "Wooden baseball bat with taped handle and knob.", grip=p0 + V(0, 0, -0.1), holdable=True,
                  grip_note="two-hand grip just above the knob; barrel toward -Z")


def metal_pipe():
    g = G()
    p0 = V(0, 0.022, 0.28)
    g.lathe(p0, V(0, 0, -1), [(0.0, 0.017), (0.02, 0.017), (0.52, 0.017), (0.56, 0.017)], "steel_worn", seg=8, rects=["rust", "steel_worn", "rust"],
            cap_rect="steel_dark")
    g.lathe(p0 + V(0, 0, -0.53), V(0, 0, -1), [(0.0, 0.022), (0.05, 0.022)], "steel_dark", seg=8, cap_rect="steel_dark")
    return finish("INV_MetalPipe", g, "Weapons", "Length of steel pipe with a coupling and rusty threads.", grip=p0 + V(0, 0, -0.08), holdable=True)


def _axe(name, L, head_scale, handle_rect, cat_desc):
    g = G()
    p0 = V(0, 0.02 * head_scale, L / 2)
    g.lathe(p0, V(0, 0, -1), [(0.0, 0.02), (0.02, 0.018), (0.25 * L, 0.016), (0.9 * L, 0.017), (L, 0.016)], handle_rect, seg=8, squash=0.7,
            rects=[handle_rect, "rubber_grip" if L < 0.5 else handle_rect, handle_rect, handle_rect], cap_rect="wood_dark")
    s = head_scale
    hp = p0 + V(0, 0, -L + 0.04 * s)
    blade = [(-0.02 * s, -0.025 * s), (0.02 * s, -0.025 * s), (0.12 * s, -0.06 * s), (0.135 * s, 0.0), (0.12 * s, 0.06 * s), (0.02 * s, 0.025 * s),
             (-0.02 * s, 0.025 * s)]
    Rm = np.column_stack([V(1, 0, 0), V(0, 0, -1), V(0, 1, 0)])
    g.extrude(blade, -0.011 * s, 0.011 * s, hp, Rm, "axe_red" if name == "INV_FireAxe" else "steel", "steel_dark")
    g.extrude([(0.115 * s, -0.058 * s), (0.135 * s, 0.0), (0.115 * s, 0.058 * s), (0.122 * s, 0.0)], -0.0115 * s, 0.0115 * s, hp, Rm, "chrome", "chrome")
    if name == "INV_FireAxe":
        g.extrude([(-0.02 * s, -0.02 * s), (-0.02 * s, 0.02 * s), (-0.11 * s, 0.004 * s), (-0.11 * s, -0.004 * s)], -0.008, 0.008, hp, Rm, "axe_red", "steel_dark")
    return finish(name, g, "Weapons", cat_desc, grip=p0 + V(0, 0, -0.08), holdable=True, grip_note="handle end at +Z; head toward -Z, edge toward +X")


def fire_axe():
    return _axe("INV_FireAxe", 0.78, 1.25, "wood_light", "Fire axe: long ash handle, red head with pick spike, bright edge.")


def hatchet():
    return _axe("INV_UtilityHatchet", 0.34, 0.85, "wood_handle", "Utility hatchet: short handle with rubber grip, steel head.")


def handgun():
    g = G()
    g.box(V(0, 0.105, -0.02), (0.026, 0.03, 0.18), "gunmetal", taper=(0.9, 0.95))                    # slide (simplified)
    g.box(V(0, 0.082, -0.02), (0.024, 0.02, 0.16), "plastic_black")                                    # frame
    grip = [(-0.02, 0.0), (0.016, 0.0), (0.024, 0.11), (-0.012, 0.11)]
    g.extrude(grip, -0.0135, 0.0135, V(0, 0.0, 0.03), SIDE @ np.array(rot(roll=0)), "rubber_grip", "plastic_black")
    g.sweep([V(0, 0.072, -0.005), V(0, 0.05, -0.008), V(0, 0.048, -0.04), V(0, 0.072, -0.05)], 0.0035, "plastic_black", seg=5)
    g.box(V(0, 0.062, -0.025), (0.006, 0.016, 0.006), "steel_dark", Rm=rot(pitch=12))
    g.cyl(V(0, 0.104, -0.11), V(0, 0.104, -0.113), 0.006, 0.006, "plastic_black", seg=8, cap_rect="plastic_black")
    g.box(V(0, 0.122, -0.1), (0.004, 0.005, 0.006), "steel_dark")
    g.box(V(0, 0.122, 0.06), (0.014, 0.005, 0.006), "steel_dark")
    return finish("INV_Handgun", g, "Weapons", "Simplified, unbranded prop handgun (no mechanism detail).", grip=V(0, 0.05, 0.035), holdable=True,
                  grip_note="hand around the grip, muzzle toward -Z; prop only - no firing logic")


def ammo_box():
    g = G()
    g.box(V(0, 0.016, 0), (0.08, 0.032, 0.055), "cardboard", faces={"+y": "ammo_label", "+z": "ammo_label", "-z": "ammo_label"})
    g.box(V(0, 0.0335, 0.0), (0.081, 0.003, 0.056), "plastic_dark_green")
    return finish("INV_AmmoBox", g, "Weapons", "Small card box of generic ammunition (prop).")


def ammo_pickup():
    g = G()
    for k, (x, z, yaw) in enumerate(((0.0, 0.0, 0), (0.013, 0.006, 25), (-0.012, 0.01, -15), (0.004, -0.014, 70))):
        R_ = np.array(rot(yaw=yaw))
        p0 = V(x, 0.0048, z)
        g.lathe(p0, R_ @ V(0, 0, -1), [(0.0, 0.0048), (0.019, 0.0048), (0.021, 0.0042), (0.028, 0.0022), (0.029, 0.0)], "brass",
                rects=["brass", "brass", "copper", "copper"], seg=8, cap_rect="brass")
    return finish("INV_AmmoPickup", g, "Weapons", "A few loose generic cartridges (pickup prop).")


# ======================================================================= E. story & puzzle props
def cassette():
    g = G()
    g.box(V(0, 0.0063, 0), (0.1, 0.0125, 0.064), "plastic_black", taper=(1.0, 1.0))
    g.decal(V(0, 0.0125, -0.008), 0.088, 0.034, V(0, 1, 0), V(0, 0, -1), "cassette")
    for x in (-0.022, 0.022):
        g.decal(V(x, 0.0128, 0.004), 0.016, 0.016, V(0, 1, 0), V(0, 0, -1), "tape_reel")
    g.box(V(0, 0.0063, 0.03), (0.06, 0.012, 0.006), "plastic_black", taper=(1.0, 1.0))
    return finish("INV_CassetteTape", g, "Puzzle_Items", "Audio cassette: shell, two reel windows, label area.")


def vhs():
    g = G()
    g.box(V(0, 0.0125, 0), (0.187, 0.025, 0.103), "plastic_black", faces={"-z": "vhs"})
    g.decal(V(0, 0.0251, 0.012), 0.12, 0.04, V(0, 1, 0), V(0, 0, -1), "vhs")
    for x in (-0.05, 0.05):
        g.decal(V(x, 0.0253, -0.02), 0.035, 0.035, V(0, 1, 0), V(0, 0, -1), "tape_reel")
    return finish("INV_VHSTape", g, "Puzzle_Items", "VHS cassette with spine label and reel window.")


def photograph():
    g = G()
    g.box(V(0, 0.0004, 0), (0.1, 0.0008, 0.08), "paper_white", faces={"+y": "photo"})
    return finish("INV_Photograph", g, "Puzzle_Items", "Snapshot of a Greyhaven street with a house.", grip=V(0, 0.001, 0.02), holdable=True)


def torn_photograph():
    g = G()
    out = [(-0.05, -0.04), (0.03, -0.04), (0.036, -0.03), (0.028, -0.018), (0.038, -0.004), (0.03, 0.01), (0.04, 0.024), (0.032, 0.04), (-0.05, 0.04)]
    g.extrude(out, 0, 0.0008, V(0, 0, 0), FLAT, "photo_torn", "paper_white", back_rect="paper_white")
    return finish("INV_TornPhotograph", g, "Puzzle_Items", "Photograph torn down one side.", grip=V(0, 0.001, 0.0), holdable=True)


def newspaper():
    g = G()
    g.box(V(0, 0.004, 0), (0.29, 0.008, 0.2), "paper_old", faces={"+y": "newspaper"})
    g.box(V(0.0, 0.0085, 0.0), (0.287, 0.002, 0.197), "paper_old", faces={"+y": "newspaper"}, Rm=rot(roll=1.2))
    return finish("INV_Newspaper", g, "Puzzle_Items", "Folded local newspaper (GAZETTE masthead, original).")


def missing_poster():
    g = G()
    g.box(V(0, 0.0005, 0.02), (0.215, 0.001, 0.24), "paper_yellow", faces={"+y": "poster"})
    g.box(V(0.08, 0.004, -0.115), (0.06, 0.001, 0.04), "paper_yellow", Rm=rot(pitch=25, yaw=-30))     # curled corner
    for x in (-0.09, 0.09):
        g.box(V(x, 0.0012, 0.135), (0.03, 0.0008, 0.012), "tape_gray")
    return finish("INV_MissingPoster", g, "Puzzle_Items", "Generic missing-person poster (no identity; story assigns it).")


def access_card():
    g = G()
    r = 0.003
    out = [(-0.0428 + r, -0.027), (0.0428 - r, -0.027), (0.0428, -0.027 + r), (0.0428, 0.027 - r), (0.0428 - r, 0.027), (-0.0428 + r, 0.027),
           (-0.0428, 0.027 - r), (-0.0428, -0.027 + r)]
    g.extrude(out, 0, 0.0012, V(0, 0, 0), FLAT @ np.array(rot(roll=-90)), "card", "plastic_white", back_rect="plastic_white")
    g.extrude(circle(0.003, 8, 0.036, 0.0), 0.0011, 0.0014, V(0, 0, 0), FLAT @ np.array(rot(roll=-90)), "plastic_black", "plastic_black")
    return finish("INV_SecurityAccessCard", g, "Puzzle_Items", "Plastic security access card with chip and photo box.", grip=V(0, 0.001, 0.02), holdable=True)


def rusty_key():
    g = G()
    g.ring(V(0, 0, 0.045), V(0, 1, 0), 0.008, 0.014, 0.005, "rust", seg=12)
    g.cyl(V(0, 0.0025, 0.032), V(0, 0.0025, -0.045), 0.0028, 0.0028, "rust", seg=6)
    g.box(V(0.006, 0.0025, -0.04), (0.012, 0.005, 0.012), "rust")
    g.box(V(0.009, 0.0025, -0.03), (0.006, 0.005, 0.004), "rust")
    return finish("INV_RustyKey", g, "Puzzle_Items", "Old iron skeleton key, rusted.", grip=V(0, 0.003, 0.04), holdable=True)


def locked_diary():
    g = G()
    _book(g, V(0, 0, 0), (0.12, 0.032, 0.165), "diary_cover", spine_rect="purple_cover", strap=True)
    return finish("INV_LockedDiary", g, "Puzzle_Items", "Clothbound diary held shut by a strap and a small brass lock.", grip=V(-0.03, 0.016, 0.0), holdable=True)


def strange_emblem():
    g = G()
    g.lathe(V(0, 0, 0), V(0, 1, 0), [(0.0, 0.03), (0.004, 0.032), (0.007, 0.03)], "metal_strange", seg=16, cap_rect="emblem")
    g.ring(V(0, 0.0035, -0.034), V(1, 0, 0), 0.004, 0.0065, 0.004, "metal_strange", seg=8)
    return finish("INV_StrangeEmblem", g, "Puzzle_Items", "Heavy metal medallion with concentric relief (meaning not defined by the story).")


def mysterious_artifact():
    g = G()
    g.lathe(V(0, 0, 0), V(0, 1, 0), [(0.0, 0.0), (0.012, 0.022), (0.035, 0.03), (0.06, 0.02), (0.075, 0.0)], "stone_dark", seg=6, smooth=False,
            rects=["stone_dark", "artifact", "artifact", "stone_dark"])
    g.ring(V(0, 0.032, 0), V(0, 1, 0), 0.029, 0.033, 0.008, "metal_strange", seg=6)
    return finish("INV_MysteriousArtifact", g, "Puzzle_Items", "Small faceted dark object bound by a metal band (function undefined).")


def evidence_envelope():
    g = G()
    g.box(V(0, 0.003, 0), (0.23, 0.006, 0.16), "cardboard", faces={"+y": "envelope"})
    g.decal(V(0.04, 0.0062, 0.03), 0.07, 0.035, V(0, 1, 0), V(0, 0, -1), "evidence_label")
    g.box(V(0, 0.0065, -0.075), (0.23, 0.001, 0.02), "plastic_red")                                         # sealing tape
    return finish("INV_EvidenceEnvelope", g, "Puzzle_Items", "Sealed manila evidence envelope with tape seal and label.")


ITEMS = [  # (priority, fn)
    (1, house_key), (1, car_key), (1, keyring), (1, flashlight), (1, battery), (1, radio), (1, folded_note), (1, notebook), (1, pen),
    (1, town_map), (1, wallet), (1, wristwatch), (1, first_aid_kit), (1, bandage_roll), (1, medicine_bottle), (1, painkillers),
    (1, water_bottle), (1, canned_food), (1, energy_snack), (1, backpack), (1, emergency_lantern), (1, spare_batteries), (1, crowbar),
    (2, screwdriver), (2, adjustable_wrench), (2, hammer), (2, pliers), (2, pocketknife), (2, duct_tape), (2, rope_bundle), (2, padlock),
    (2, bolt_cutters), (2, portable_fuse), (2, electrical_switch), (2, baseball_bat), (2, metal_pipe), (2, fire_axe), (2, hatchet),
    (2, handgun), (2, ammo_box), (2, ammo_pickup),
    (3, cassette), (3, vhs), (3, photograph), (3, torn_photograph), (3, newspaper), (3, missing_poster), (3, access_card), (3, rusty_key),
    (3, locked_diary), (3, strange_emblem), (3, mysterious_artifact), (3, evidence_envelope),
]
FOLDER = {"Story_Items": "Story_Items", "Medical": "Medical", "Food_And_Supplies": "Food_And_Supplies", "Tools": "Tools",
          "Weapons": "Weapons", "Puzzle_Items": "Puzzle_Items"}
