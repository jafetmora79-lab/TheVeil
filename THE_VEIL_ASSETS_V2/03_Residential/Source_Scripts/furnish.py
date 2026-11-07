"""Furniture layouts per house plan.

Entries (house-local frame, rooms from plans.py):
  ("Model", ROOM, "wall", side, at)            floor item, back against wall side F/B/L/R, `at` = x (F/B) or z (L/R)
  ("Model", ROOM, "wall", side, at, extra)      extra: dict(off=+m from the wall, yaw=deg added)
  ("Model", ROOM, "c", (x, z), yaw_deg)         free-standing at an absolute point
  ("Model", ROOM, "mount", side, at, y)         wall-mounted (y = height above the room floor; default from the model)
  ("Model", ROOM, "on", index, (dx, dz), yaw)   sits on top of a previously placed item (index in this list)
"""
import math

SIDE_YAW = {"F": 0.0, "B": math.pi, "L": math.pi / 2, "R": -math.pi / 2}


def _wall_half(house, room, side, at):
    """0.1 for exterior walls, 0.06 for partitions."""
    for (r, s, axis, c, lo, hi) in house.ext_pieces:
        if r["id"] == room["id"] and s == side and lo - 0.01 <= at <= hi + 0.01:
            return 0.10
    return 0.06


def _door_zone_points(house):
    """Per floor height: sample points of door passages (0.9 m each side) and leaf swing arcs."""
    import numpy as np
    zones = []
    for dr in house.meta["doors"]:
        if dr["kind"] == "garage":
            n = np.array(dr["normal"])
            t = np.array([-n[1], n[0]])
            c0 = np.array([dr["center"][0], dr["center"][2]])
            pts = [c0 + t * s_ + n * a_ for s_ in np.linspace(-dr["w"] / 2, dr["w"] / 2, 7) for a_ in np.linspace(-2.5, 0.0, 8)]
            zones.append((0.0, pts))
            continue
        n = np.array(dr["normal"])
        t = np.array([-n[1], n[0]])
        c0 = np.array([dr["center"][0], dr["center"][2]])
        pts = [c0 + t * s_ + n * a_ for s_ in np.linspace(-dr["w"] / 2 + 0.05, dr["w"] / 2 - 0.05, 5) for a_ in np.linspace(-0.95, 0.95, 12)]
        if "hinge" in dr:
            hp = np.array(dr["hinge"])
            for ang in np.linspace(0, abs(dr["open_deg"]), 10):
                yaw = dr["yaw"] + math.radians(ang) * (1 if dr["open_deg"] > 0 else -1)
                v = np.array([math.cos(yaw), -math.sin(yaw)])
                for rr in (0.3, 0.6, dr["leaf"]):
                    pts.append(hp + v * rr)
        if dr.get("steps"):
            for a_ in np.linspace(0, dr["steps"]["run"] + 0.9, 8):
                for s_ in np.linspace(-dr["w"] / 2, dr["w"] / 2, 4):
                    pts.append(c0 + t * s_ + n * dr["steps"]["side"] * a_)
        zones.append((dr["center"][1], pts))
    return zones


def _stair_rects(house):
    """Stair footprints + approach/arrival zones, with the floor height they block."""
    out = []
    for s in house.meta["stairs"]:
        a, b, c, d = s["foot"]
        out.append((s["y_from"], (a - 0.05, b - 0.05, c + 0.05, d + 0.05)))
        ap = {"+z": (a, b - 1.0, c, b), "-z": (a, d, c, d + 1.0), "+x": (a - 1.0, b, a, d), "-x": (c, b, c + 1.0, d)}[s["dir"]]
        out.append((s["y_from"], ap))
        va, vb, vc, vd = s["void"]
        out.append((s["y_to"], (va - 0.3, vb - 0.3, vc + 0.3, vd + 0.3)))
        ar = {"+z": (a, d, c, d + 1.0), "-z": (a, b - 1.0, c, b), "+x": (c, b, c + 1.0, d), "-x": (a - 1.0, b, a, d)}[s["dir"]]
        out.append((s["y_to"], ar))
    return out


def place_all(house, layout, fmeta, report=None):
    """Place every entry; a piece that collides slides along its wall (or spirals outward if free-standing)
    until it clears walls, other furniture, door passages/swings and stair zones. Returns instances:
    dict(model, x, y, z, yaw, room, footprint=(x0,z0,x1,z1) or None, top_y)."""
    rooms = {r["id"]: r for r in house.p["rooms"]}
    zones = _door_zone_points(house)
    stairs = _stair_rects(house)
    out = []
    report = report if report is not None else []

    def fp_of(pos, yaw, w, d):
        c, s_ = abs(math.cos(yaw)), abs(math.sin(yaw))
        ex, ez = (w * c + d * s_) / 2, (w * s_ + d * c) / 2
        return (pos[0] - ex, pos[1] - ez, pos[0] + ex, pos[1] + ez)

    def ok(fp, r, fy, model):
        a, b, c, d = fp
        x0, z0, x1, z1 = r.get("walk", r["rect"])
        if a < x0 + 0.05 or b < z0 + 0.05 or c > x1 - 0.05 or d > z1 - 0.05:
            return False
        for o in out:
            if o["footprint"] and abs(o["floor_y"] - fy) < 0.05:
                e, f, g, h = o["footprint"]
                if min(c, g) - max(a, e) > 0.02 and min(d, h) - max(b, f) > 0.02:
                    return False
        for (zy, pts) in zones:
            if abs(zy - fy) > 0.7:
                continue
            for p in pts:
                if a - 0.05 < p[0] < c + 0.05 and b - 0.05 < p[1] < d + 0.05:
                    return False
        for (sy, (e, f, g, h)) in stairs:
            if abs(sy - fy) < 0.05 and min(c, g) - max(a, e) > 0 and min(d, h) - max(b, f) > 0:
                return False
        return True

    FALLBACK = {"RES_Sofa_Plaid": "RES_Sofa_Loveseat_Leather", "RES_Bathtub": "RES_ShowerStall",
                "RES_Bed_Double": "RES_Bed_Single", "RES_Bed_Double_Unmade": "RES_Bed_Single", "RES_Counter_Base_1.2": "RES_Counter_Base_0.6",
                "RES_Wardrobe": "RES_Dresser", "RES_Dresser_Mirror": "RES_Dresser", "RES_TV_CRT_Console": "RES_TV_CRT_Small",
                "RES_Bookshelf_Tall": "RES_Bookshelf_Low", "RES_Workbench": "RES_Shelving_Metal", "RES_DiningTable_Rect": "RES_DiningTable_Round"}
    expanded = []
    for e in layout:
        expanded.append(e)
    for e in expanded:
        res = _place_one(e, layout, out, rooms, house, fmeta, ok, fp_of, report)
        tried = [e[0]]
        while res is None and e[2] in ("wall", "c") and FALLBACK.get(e[0]) and FALLBACK[e[0]] not in tried:
            e = (FALLBACK[e[0]],) + tuple(e[1:])
            tried.append(e[0])
            res = _place_one(e, layout, out, rooms, house, fmeta, ok, fp_of, report, quiet=True, idx=layout.index(expanded[expanded.index(e)]) if False else None)
            if res is not None:
                report.append(f"substituted {tried[0]} -> {e[0]} in {e[1]}")
        if res is None:
            report.append(f"dropped {tried[0]} in {e[1]}")
            continue
        res["_idx"] = layout.index(next(x for x in layout if x[1:] == e[1:] or x is e)) if any(x[1:] == e[1:] for x in layout) else None
        out.append(res)
    return out


def _place_one(e, layout, out, rooms, house, fmeta, ok, fp_of, report, quiet=False, idx=None):
    if True:
        model, rid, mode = e[0], e[1], e[2]
        r = rooms[rid]
        fy = house.floor_y(r)
        w, d, h = fmeta[model]["size"]
        x0, z0, x1, z1 = r["rect"]
        meta = fmeta[model]
        floor_item = mode in ("wall", "c") and not meta.get("floor_layer")
        if mode in ("wall", "mount"):
            side, at = e[3], e[4]
            extra = e[5] if len(e) > 5 and isinstance(e[5], dict) else {}
            yaw = SIDE_YAW[side] + math.radians(extra.get("yaw", 0.0))
            wh = _wall_half(house, r, side, at)
            off = (wh + d / 2 + 0.002) if mode == "mount" else (wh + d / 2 + 0.015 + extra.get("off", 0.0))
            y = fy
            if mode == "mount":
                my = e[5] if len(e) > 5 and not isinstance(e[5], dict) else meta.get("mount_y", 1.5)
                y = fy + my
            placed = None
            sides = [side] + ([q for q in "FBLR" if q != side] if floor_item else [])
            for side in sides:
              yaw = SIDE_YAW[side] + math.radians(extra.get("yaw", 0.0))
              wh = _wall_half(house, r, side, at)
              off = (wh + d / 2 + 0.002) if mode == "mount" else (wh + d / 2 + 0.015 + extra.get("off", 0.0))
              span = (x0, x1) if side in "FB" else (z0, z1)
              at0 = at if side == e[3] else (span[0] + span[1]) / 2
              for k in [0] + [s_ * q for q in range(1, 41) for s_ in (1, -1)]:
                a2 = at0 + 0.1 * k
                if not (span[0] <= a2 <= span[1]):
                    continue
                pos = {"F": (a2, z0 + off), "B": (a2, z1 - off), "L": (x0 + off, a2), "R": (x1 - off, a2)}[side]
                if not floor_item or ok(fp_of(pos, yaw, w, d), r, fy, model):
                    placed = pos
                    break
              if placed is not None:
                break
            if placed is None:
                return None
            if side != e[3]:
                report.append(f"moved {model} in {rid} to wall {side}")
            pos = placed
        elif mode == "c":
            base, yaw, y = e[3], math.radians(e[4] if len(e) > 4 else 0.0), fy
            placed = None
            cands = [(0.0, 0.0)] + [(rr * math.cos(t), rr * math.sin(t)) for rr in (0.15, 0.3, 0.45, 0.6, 0.8, 1.0, 1.25, 1.5, 1.8, 2.2)
                                    for t in [k * math.pi / 6 for k in range(12)]]
            for (dx, dz) in cands:
                pos = (base[0] + dx, base[1] + dz)
                if not floor_item or ok(fp_of(pos, yaw, w, d), r, fy, model):
                    placed = pos
                    break
            if placed is None:
                return None
            if placed != tuple(base):
                report.append(f"moved {model} in {rid} by {math.hypot(placed[0] - base[0], placed[1] - base[1]):.2f} m")
            pos = placed
        elif mode == "on":
            idx = e[3]
            if e[3] >= len(layout) or not any(o.get("_idx") == e[3] for o in out):
                report.append(f"dropped {model} (its base item #{e[3]} was dropped)")
                return None
            base = [o for o in out if o.get("_idx") == e[3]][0]
            dx, dz = e[4]
            c, s_ = math.cos(base["yaw"]), math.sin(base["yaw"])
            pos = (base["x"] + c * dx + s_ * dz, base["z"] - s_ * dx + c * dz)
            yaw = base["yaw"] + math.radians(e[5] if len(e) > 5 else 0.0)
            y = base["top_y"]
        else:
            raise ValueError(mode)
        top = meta.get("surface_y")
        return dict(model=model, x=float(pos[0]), y=float(y), z=float(pos[1]), yaw=float(yaw), room=rid,
                    footprint=fp_of(pos, yaw, w, d) if floor_item else None, floor_y=fy,
                    top_y=float(y + (top if top else h)), mount=mode == "mount", on=mode == "on")
    return out


L = {}

L["Ranch"] = [
    ("RES_Rug_Oval", "LIV", "c", (1.1, 4.3), 90), ("RES_Sofa_Plaid", "LIV", "wall", "L", 4.3),
    ("RES_CoffeeTable_Wood", "LIV", "c", (0.75, 4.3), 90), ("RES_TVStand", "LIV", "wall", "R", 3.35),
    ("RES_TV_CRT_Small", "LIV", "on", 3, (0.0, -0.05), 0), ("RES_Armchair_Recliner", "LIV", "c", (2.3, 5.4), -150),
    ("RES_Lamp_Floor", "LIV", "c", (-0.65, 2.8), 0), ("RES_Curtains_Gingham", "LIV", "mount", "F", 2.3, 0.0),
    ("RES_Picture_Family", "LIV", "mount", "L", 4.3), ("RES_WallClock", "LIV", "mount", "B", 2.0),
    ("RES_Fridge_TopFreezer", "KIT", "wall", "B", -0.52), ("RES_Counter_Sink", "KIT", "wall", "B", 0.5),
    ("RES_Stove_Electric", "KIT", "wall", "B", 1.6), ("RES_WallCabinet_0.8", "KIT", "mount", "B", 1.65),
    ("RES_DiningTable_Round", "KIT", "c", (0.6, 8.3), 0), ("RES_DiningChair_Wood", "KIT", "c", (0.6, 7.55), 0),
    ("RES_DiningChair_Wood", "KIT", "c", (0.6, 9.05), 180), ("RES_DishRack", "KIT", "on", 11, (0.3, 0.0), 0),
    ("RES_TrashCan_Pedal", "KIT", "wall", "R", 6.6),
    ("RES_Bed_Single", "BED2", "wall", "R", 3.7), ("RES_Nightstand", "BED2", "wall", "R", 5.0),
    ("RES_Dresser", "BED2", "wall", "B", 4.75), ("RES_Poster_Band", "BED2", "mount", "B", 4.75, 1.7),
    ("RES_Bathtub", "BATH", "wall", "B", 4.7), ("RES_Toilet", "BATH", "wall", "R", 6.85), ("RES_BathSink_Pedestal", "BATH", "wall", "F", 5.2),
    ("RES_Mirror_Bathroom", "BATH", "mount", "F", 5.2), ("RES_TowelRack", "BATH", "mount", "R", 6.55),
    ("RES_Bed_Double", "BED1", "wall", "R", 10.1), ("RES_Nightstand", "BED1", "wall", "R", 8.95),
    ("RES_Nightstand", "BED1", "wall", "R", 11.25), ("RES_Wardrobe", "BED1", "wall", "L", 10.9), ("RES_Lamp_Table", "BED1", "on", 29, (0, 0), 0),
    ("RES_LaundryBasket", "LAU", "wall", "L", 10.0), ("RES_Shelving_Metal", "GAR", "wall", "B", -4.35),
    ("RES_WashingMachine", "GAR", "wall", "B", -3.3), ("RES_Dryer", "GAR", "wall", "B", -2.55), ("RES_Workbench", "GAR", "wall", "L", 6.2),
    ("RES_WaterHeater", "GAR", "wall", "L", 4.4), ("RES_ElectricalPanel", "GAR", "mount", "L", 3.2), ("RES_Toolbox", "GAR", "on", 37, (0.4, 0.0), 0),
]

L["TwoStorey"] = [
    ("RES_Rug_Rect", "LIV", "c", (-3.0, 7.0), 0), ("RES_Sofa_Plaid", "LIV", "wall", "L", 7.0),
    ("RES_CoffeeTable_Wood", "LIV", "c", (-3.2, 7.0), 90), ("RES_TV_CRT_Console", "LIV", "wall", "R", 7.3),
    ("RES_Bookshelf_Tall", "LIV", "wall", "F", -3.9),
    ("RES_Lamp_Floor", "LIV", "c", (-1.6, 3.8), 0), ("RES_Painting_Barn", "LIV", "mount", "L", 4.2, 1.7),
    ("RES_DiningTable_Round", "DIN", "c", (-3.3, 9.7), 0), ("RES_DiningChair_Wood", "DIN", "c", (-3.3, 8.95), 0),
    ("RES_DiningChair_Wood", "DIN", "c", (-4.05, 9.8), 90), ("RES_Curtains_Plaid", "DIN", "mount", "B", -2.85, 0.0),
    ("RES_Desk", "DEN", "wall", "R", 5.1), ("RES_DeskChair_Office", "DEN", "c", (3.5, 5.1), 90),
    ("RES_Bookshelf_Low", "DEN", "wall", "F", 2.85, dict(off=0.0)), ("RES_Armchair_Recliner", "DEN", "c", (2.0, 4.8), 120),
    ("RES_Fridge_Retro", "KIT", "wall", "R", 7.5), ("RES_Counter_Base_1.2", "KIT", "wall", "R", 8.6),
    ("RES_Stove_Harvest", "KIT", "wall", "B", 3.95), ("RES_Counter_Sink", "KIT", "wall", "B", 2.85),
    ("RES_Microwave", "KIT", "on", 16, (0.0, 0.0), 0),
    ("RES_WallCabinet_0.8", "KIT", "mount", "B", 1.75), ("RES_TrashCan_Pedal", "KIT", "wall", "B", 1.6),
    ("RES_CoatRack_Wall", "FOY", "mount", "L", 3.9), ("RES_ShoeRack", "BHAL", "wall", "L", 10.4),
    ("RES_Bed_Double", "BED1", "wall", "L", 5.5), ("RES_Nightstand", "BED1", "wall", "L", 4.3), ("RES_Dresser_Mirror", "BED1", "wall", "R", 6.2),
    ("RES_Bed_Single", "BED2", "wall", "L", 9.4), ("RES_Desk", "BED2", "wall", "B", -2.6), ("RES_StorageChest", "BED2", "c", (-3.5, 8.3), 0),
    ("RES_Bed_Single", "BED3", "wall", "R", 5.4), ("RES_Wardrobe", "BED3", "wall", "F", 1.95),
    ("RES_Bathtub", "BATH2", "wall", "B", 3.6), ("RES_Toilet", "BATH2", "wall", "R", 8.2), ("RES_BathSink_Vanity", "BATH2", "wall", "F", 3.3),
    ("RES_MedicineCabinet", "BATH2", "mount", "F", 3.3),
]

L["Farmhouse"] = [
    ("RES_Rug_Oval", "PAR", "c", (-3.1, 5.0), 0), ("RES_Sofa_Loveseat_Leather", "PAR", "wall", "L", 5.0),
    ("RES_Armchair_Wingback", "PAR", "c", (-2.0, 4.0), -120), ("RES_CoffeeTable_Wood", "PAR", "c", (-3.3, 5.0), 90),
    ("RES_TV_CRT_Console", "PAR", "wall", "B", -3.1), ("RES_Painting_Barn", "PAR", "mount", "L", 5.0, 1.75),
    ("RES_DiningTable_Round", "DIN", "c", (-3.5, 8.5), 0), ("RES_DiningChair_Vinyl", "DIN", "c", (-3.5, 7.75), 0),
    ("RES_DiningChair_Vinyl", "DIN", "c", (-4.25, 8.6), 90), ("RES_Bookshelf_Tall", "STU", "wall", "R", 4.3),
    ("RES_Desk", "STU", "wall", "F", 3.0), ("RES_DeskChair_Office", "STU", "c", (3.0, 4.2), 180),
    ("RES_Fridge_TopFreezer", "KIT", "wall", "R", 7.2), ("RES_Counter_Sink", "KIT", "wall", "R", 8.4), ("RES_Stove_Harvest", "KIT", "wall", "R", 9.5),
    ("RES_DiningTable_Round", "KIT", "c", (2.6, 8.0), 0), ("RES_WashingMachine", "MUD", "wall", "L", 12.6), ("RES_Dryer", "MUD", "wall", "L", 11.8),
    ("RES_ShoeRack", "MUD", "wall", "B", 1.9, dict(off=0.0)), ("RES_Bathtub", "BATH", "wall", "R", 11.6, dict(yaw=0)), ("RES_Toilet", "BATH", "wall", "B", 4.4),
    ("RES_Bed_Double", "BED1", "wall", "L", 5.0), ("RES_Wardrobe", "BED1", "wall", "R", 6.4), ("RES_Nightstand", "BED1", "wall", "L", 3.7),
    ("RES_Bed_Single", "BED2", "wall", "L", 8.5), ("RES_Dresser", "BED2", "wall", "B", -3.0),
    ("RES_BathSink_Pedestal", "BATH2", "wall", "R", 4.0), ("RES_Toilet", "BATH2", "wall", "F", 4.4),
    ("RES_StorageChest", "STOR", "wall", "R", 6.0), ("RES_CardboardBox_Stack", "STOR", "c", (4.4, 8.9), 10),
    ("RES_CardboardBox_Open", "ATTIC", "c", (-2.5, 6.5), 25), ("RES_CardboardBox_Closed", "ATTIC", "c", (-3.3, 6.9), -10),
    ("RES_StorageChest", "ATTIC", "c", (3.4, 6.6), 90), ("RES_Mattress_Bare", "ATTIC", "c", (-0.5, 7.0), 85),
]

L["Bungalow"] = [
    ("RES_Rug_Oval", "LIV", "c", (-2.0, 5.1), 0), ("RES_Sofa_Plaid", "LIV", "wall", "L", 5.1),
    ("RES_CoffeeTable_Wood", "LIV", "c", (-3.0, 5.1), 90), ("RES_TVStand", "LIV", "wall", "R", 6.2),
    ("RES_TV_CRT_Small", "LIV", "on", 3, (0, -0.05), 0), ("RES_Armchair_Recliner", "LIV", "c", (-0.75, 4.05), -90),
    ("RES_Lamp_Floor", "LIV", "c", (-4.1, 6.6), 0), ("RES_Curtains_Gingham", "LIV", "mount", "F", -0.6, 0.0),
    ("RES_DiningTable_Rect", "DIN", "c", (-2.95, 9.6), 90), ("RES_DiningChair_Wood", "DIN", "c", (-3.55, 9.3), 90),
    ("RES_DiningChair_Wood", "DIN", "c", (-2.35, 9.9), -90), ("RES_Bookshelf_Low", "DIN", "wall", "L", 8.2),
    ("RES_Counter_Sink", "KIT", "wall", "F", -0.75), ("RES_Fridge_Retro", "KIT", "wall", "R", 7.45),
    ("RES_Stove_Electric", "KIT", "wall", "R", 8.35), ("RES_Counter_Base_0.6", "KIT", "wall", "R", 9.15),
    ("RES_Bed_Double", "BED1", "wall", "R", 4.9), ("RES_Nightstand", "BED1", "wall", "R", 3.75), ("RES_Dresser", "BED1", "wall", "F", 1.4, dict(off=0.0)),
    ("RES_Bathtub", "BATH", "wall", "R", 7.7, dict(yaw=0)), ("RES_Toilet", "BATH", "wall", "B", 4.0), ("RES_BathSink_Pedestal", "BATH", "wall", "F", 4.0),
    ("RES_Bed_Single", "BED2", "wall", "R", 10.1), ("RES_Wardrobe", "BED2", "wall", "B", 2.7),
]

L["Abandoned"] = [
    ("RES_CardboardBox_Open", "LIV", "c", (0.1, 4.0), 30), ("RES_Newspaper", "LIV", "c", (-1.0, 5.6), 40),
    ("RES_Armchair_Wingback", "LIV", "c", (0.05, 7.95), 200), ("RES_Mattress_Bare", "BED2", "c", (1.4, 8.7), 92),
    ("RES_DiningTable_Rect", "ROOM", "c", (2.05, 6.0), 90), ("RES_DiningChair_Wood", "ROOM", "c", (1.4, 4.6), 70),
    ("RES_CardboardBox_Stack", "ROOM", "c", (3.0, 7.9), 12), ("RES_Stove_Electric", "KIT", "wall", "B", -2.4),
    ("RES_Counter_Sink", "KIT", "wall", "B", -0.9), ("RES_Fridge_TopFreezer", "KIT", "wall", "R", 10.0),
    ("RES_Bed_Single", "BED1", "wall", "R", 5.4), ("RES_Dresser", "BED1", "wall", "F", 1.3, dict(off=0.0)),
    ("RES_CardboardBox_Closed", "BED2", "c", (2.5, 8.6), 15), ("RES_Toilet", "BATH", "wall", "R", 10.5),
    ("RES_BathSink_Pedestal", "BATH", "wall", "B", 0.0),
]

L["SplitLevel"] = [
    ("RES_Rug_Rect", "LIV", "c", (-4.4, 5.0), 0), ("RES_Sofa_Plaid", "LIV", "wall", "L", 5.0),
    ("RES_CoffeeTable_Wood", "LIV", "c", (-6.4, 5.0), 90), ("RES_TV_CRT_Console", "LIV", "c", (-2.4, 5.2), -90),
    ("RES_Armchair_Recliner", "LIV", "c", (-3.6, 3.9), -160), ("RES_Lamp_Floor", "LIV", "c", (-7.1, 3.4), 0),
    ("RES_Fridge_TopFreezer", "KIT", "wall", "L", 7.8), ("RES_Counter_Sink", "KIT", "wall", "B", -3.0),
    ("RES_Stove_Electric", "KIT", "wall", "B", -4.3), ("RES_Counter_Base_1.2", "KIT", "wall", "B", -1.85),
    ("RES_DiningTable_Rect", "KIT", "c", (-5.0, 8.9), 0), ("RES_DiningChair_Vinyl", "KIT", "c", (-5.4, 8.25), 0),
    ("RES_DiningChair_Vinyl", "KIT", "c", (-4.6, 9.55), 180),
    ("RES_Sofa_Loveseat_Leather", "DEN", "wall", "L", 7.8), ("RES_TV_CRT_Small", "DEN", "c", (1.55, 7.8), -90),
    ("RES_Bookshelf_Low", "DEN", "wall", "B", 0.3), ("RES_Workbench", "GAR", "wall", "B", 5.0), ("RES_Shelving_Metal", "GAR", "wall", "R", 6.5),
    ("RES_WashingMachine", "LAU", "wall", "B", 6.4), ("RES_Dryer", "LAU", "wall", "B", 4.3), ("RES_WaterHeater", "LAU", "wall", "R", 9.0),
    ("RES_Bed_Double", "BED1", "wall", "B", 0.45), ("RES_Nightstand", "BED1", "wall", "B", -0.7),
    ("RES_Bed_Single", "BED2", "wall", "R", 4.6), ("RES_Dresser", "BED2", "wall", "F", 5.5),
    ("RES_Bed_Single", "BED3", "wall", "L", 8.2), ("RES_Desk", "BED3", "wall", "B", 0.5),
    ("RES_Bathtub", "BATH", "wall", "R", 7.8, dict(yaw=0)), ("RES_Toilet", "BATH", "wall", "B", 5.6), ("RES_BathSink_Vanity", "BATH", "wall", "F", 6.0, dict(off=0.0)),
]

L["Cottage"] = [
    ("RES_Rug_Oval", "LIV", "c", (-1.5, 5.2), 90), ("RES_Sofa_Loveseat_Leather", "LIV", "wall", "L", 5.2),
    ("RES_Armchair_Wingback", "LIV", "c", (-0.2, 4.2), -130), ("RES_TV_CRT_Small", "LIV", "c", (-0.3, 6.3), -110),
    ("RES_Lamp_Floor", "LIV", "c", (-3.3, 3.9), 0), ("RES_Curtains_Gingham", "LIV", "mount", "F", -3.0, 0.0),
    ("RES_Fridge_Retro", "KIT", "wall", "L", 8.0), ("RES_Counter_Sink", "KIT", "wall", "B", -1.8), ("RES_Stove_Harvest", "KIT", "wall", "B", -3.0),
    ("RES_DiningTable_Round", "KIT", "c", (-1.5, 8.55), 0),     # clear of the chimney stack (x -1.2, z 9.4)
    ("RES_Bed_Double", "BED", "wall", "R", 3.55), ("RES_Nightstand", "BED", "wall", "R", 4.75), ("RES_Wardrobe", "BED", "wall", "B", 1.6, dict(off=0.0)),
    ("RES_ShowerStall", "BATH", "wall", "F", 1.3),
    ("RES_Toilet", "BATH", "wall", "B", 1.3), ("RES_BathSink_Pedestal", "BATH", "wall", "F", 0.4),
    ("RES_Bed_Single", "BED2", "wall", "R", 8.4),
]

# ---- reconstruction pass: lived-in additions, appended so every earlier placement (and the story coordinates
# taken from it) stays exactly where it was. ("on", "<model>") sits on the latest earlier piece of that model in
# the same room.
def _extend(key, items):
    lay = L[key]
    for e in items:
        if e[2] == "on" and isinstance(e[3], str):
            e = e[:3] + (max(i for i, x in enumerate(lay) if x[0] == e[3] and x[1] == e[1]),) + e[4:]
        lay.append(e)


# Cottage - a small working-class home: a lived-in front room, a working kitchen, one couple's bedroom and a
# spare room used for storage and a single bed
_extend("Cottage", [
    ("RES_CoffeeTable_Wood", "LIV", "c", (-2.45, 5.2), 90), ("RES_Newspaper", "LIV", "on", "RES_CoffeeTable_Wood", (0.1, 0.0), 20),
    ("RES_SideTable_Drawer", "LIV", "c", (-3.4, 6.55), 0), ("RES_Lamp_Table", "LIV", "on", "RES_SideTable_Drawer", (0.0, 0.0), 0),
    ("RES_Picture_Landscape", "LIV", "mount", "L", 4.1, 1.65), ("RES_WallClock", "LIV", "mount", "B", 0.25),
    ("RES_DiningChair_Wood", "KIT", "c", (-1.5, 7.8), 0),
    ("RES_WallCabinet_0.8", "KIT", "mount", "B", -0.55),
    ("RES_DishRack", "KIT", "on", "RES_Counter_Sink", (0.3, 0.0), 0), ("RES_Kettle", "KIT", "on", "RES_Stove_Harvest", (-0.15, 0.1), 30),
    ("RES_TrashCan_Pedal", "KIT", "wall", "L", 10.85), ("RES_WallCalendar", "KIT", "mount", "L", 7.4),
    ("RES_MedicineCabinet", "BATH", "mount", "F", 0.4, 1.55), ("RES_TowelRack", "BATH", "mount", "R", 8.3),
    ("RES_Lamp_Table", "BED", "on", "RES_Nightstand", (0.0, 0.0), 0), ("RES_Picture_Family", "BED", "mount", "L", 3.2, 1.6),
    ("RES_Nightstand", "BED2", "wall", "R", 9.75), ("RES_AlarmClock", "BED2", "on", "RES_Nightstand", (0.0, 0.0), -15),
    ("RES_Poster_Band", "BED2", "mount", "L", 8.3, 1.7),
    ("RES_CoatRack_Wall", "HALL", "mount", "F", 0.9), ("RES_ShoeRack", "HALL", "wall", "F", 0.9, dict(off=0.0)),
])

# TwoStorey - a family residence: furnished halls, a full dining set, a kitchen table, three distinct bedrooms
# (parents, a teenager, a younger child) and a used basement
_extend("TwoStorey", [
    ("RES_SideTable_Drawer", "LIV", "c", (-4.1, 4.35), 0), ("RES_Lamp_Table", "LIV", "on", "RES_SideTable_Drawer", (0.0, 0.0), 0),
    ("RES_Curtains_Plaid", "LIV", "mount", "F", -2.85, 0.0), ("RES_Picture_Family", "LIV", "mount", "R", 7.4, 1.6),
    ("RES_WallClock", "LIV", "mount", "B", -1.6), ("RES_Newspaper", "LIV", "on", "RES_CoffeeTable_Wood", (0.1, -0.1), 35),
    ("RES_DiningChair_Wood", "DIN", "c", (-2.55, 9.7), -90), ("RES_DiningChair_Wood", "DIN", "c", (-3.3, 10.45), 180),
    ("RES_Dishes_Set", "DIN", "on", "RES_DiningTable_Round", (0.0, 0.0), 0), ("RES_Picture_Landscape", "DIN", "mount", "R", 9.2, 1.6),
    ("RES_Bookshelf_Tall", "DEN", "wall", "L", 5.6), ("RES_Lamp_Floor", "DEN", "c", (1.6, 3.85), 0),
    ("RES_Radio", "DEN", "on", "RES_Desk", (0.35, 0.0), 0), ("RES_WallCalendar", "DEN", "mount", "L", 4.1),
    ("RES_WallCabinet_0.4", "KIT", "mount", "B", 4.05),
    ("RES_Kettle", "KIT", "on", "RES_Stove_Harvest", (-0.15, 0.1), 20), ("RES_DishRack", "KIT", "on", "RES_Counter_Sink", (0.3, 0.0), 0),
    ("RES_Picture_Landscape", "FOY", "mount", "L", 8.3, 1.6),
    ("RES_Picture_Family", "UHAL", "mount", "L", 7.4, 1.6), ("RES_Bookshelf_Low", "UHAL", "wall", "B", -0.5),
    ("RES_Nightstand", "BED1", "wall", "L", 6.75), ("RES_Lamp_Table", "BED1", "on", "RES_Nightstand", (0.0, 0.0), 0),
    ("RES_Wardrobe", "BED1", "wall", "B", -3.7), ("RES_Curtains_Gingham", "BED1", "mount", "F", -2.85, 0.0),
    ("RES_Nightstand", "BED2", "wall", "L", 10.75), ("RES_Lamp_Table", "BED2", "on", "RES_Desk", (0.3, 0.0), 0),
    ("RES_Poster_Band", "BED2", "mount", "R", 8.4, 1.7), ("RES_Bookshelf_Low", "BED2", "wall", "F", -2.2),
    ("RES_GameConsole", "BED2", "on", "RES_Desk", (-0.25, 0.0), 0),
    ("RES_Nightstand", "BED3", "wall", "R", 6.65), ("RES_AlarmClock", "BED3", "on", "RES_Nightstand", (0.0, 0.0), 15),
    ("RES_Dresser", "BED3", "wall", "B", 3.4), ("RES_Picture_Landscape", "BED3", "mount", "L", 6.4, 1.6),
    ("RES_StorageBin", "BED3", "c", (2.0, 6.7), 0),
    ("RES_TowelRack", "BATH2", "mount", "L", 8.5), ("RES_LaundryBasket", "BATH2", "wall", "F", 1.9),
])


L["MillWorker"] = [
    ("RES_Rug_Oval", "PAR", "c", (0.6, 6.2), 0), ("RES_Sofa_Plaid", "PAR", "wall", "R", 6.0),
    ("RES_CoffeeTable_Wood", "PAR", "c", (1.4, 6.0), 90), ("RES_Armchair_Recliner", "PAR", "c", (2.2, 4.1), -140),
    ("RES_TV_CRT_Console", "PAR", "c", (-1.0, 6.2), 90), ("RES_Lamp_Floor", "PAR", "c", (2.5, 3.7), 0),
    ("RES_Fridge_Retro", "KIT", "wall", "L", 9.2), ("RES_Counter_Sink", "KIT", "wall", "B", -0.6), ("RES_Stove_Electric", "KIT", "wall", "B", 0.6, dict(off=0.0)),
    ("RES_DiningTable_Round", "KIT", "c", (-0.6, 9.6), 0), ("RES_Toilet", "BATH", "wall", "B", 2.2), ("RES_BathSink_Pedestal", "BATH", "wall", "R", 9.2),
    ("RES_Bed_Double", "BED1", "wall", "R", 5.4), ("RES_Dresser", "BED1", "wall", "F", 0.7, dict(off=0.0)),
    ("RES_Bed_Single", "BED2", "wall", "R", 9.4), ("RES_Wardrobe", "BED2", "wall", "B", 0.6),
]

# ---------------------------------------------------------------------------
# PLAYER HOME - lived-in, ordinary Friday evening (environmental storytelling)
# ---------------------------------------------------------------------------
L["PlayerHome"] = [
    # living room: TV left on (evening news), plaid sofa, newspaper, game console, keys by the front door
    ("RES_Rug_Oval", "LIV", "c", (-4.1, 4.4), 90),                         # 0
    ("RES_Sofa_Plaid", "LIV", "wall", "L", 4.4),                            # 1
    ("RES_CoffeeTable_Wood", "LIV", "c", (-4.7, 4.4), 90),                 # 2
    ("RES_Newspaper", "LIV", "on", 2, (0.1, 0.2), 15),                     # 3
    ("RES_TVStand", "LIV", "wall", "R", 3.2),                               # 4
    ("RES_TV_CRT_Small", "LIV", "on", 4, (0.0, -0.05), 0),                 # 5  (on: evening news)
    ("RES_GameConsole", "LIV", "c", (-1.9, 4.0), -90),  # 6
    ("RES_Armchair_Recliner", "LIV", "c", (-2.6, 5.5), -125),              # 7
    ("RES_Lamp_Floor", "LIV", "c", (-6.05, 2.7), 0),                       # 8
    ("RES_Curtains_Gingham", "LIV", "mount", "F", -5.0, 0.0),              # 9
    ("RES_Picture_Family", "LIV", "mount", "L", 2.9, 1.6),                 # 10 (off the side window)
    ("RES_CoatRack_Wall", "LIV", "mount", "F", -1.45, 1.65),  # 11 car keys
    ("RES_ShoeRack", "LIV", "wall", "R", 2.75),  # 12
    ("RES_WallClock", "LIV", "mount", "B", -5.4),                          # 13
    # kitchen / dining: dishes in the rack, cereal box, kettle, calendar with Friday circled, radio
    ("RES_Fridge_Retro", "KIT", "wall", "L", 7.25),                         # 14
    ("RES_Counter_Base_1.2", "KIT", "wall", "B", -6.0 + 0.6),             # 15
    ("RES_Counter_Sink", "KIT", "wall", "B", -4.2),                         # 16
    ("RES_Stove_Electric", "KIT", "wall", "B", -3.2),                       # 17
    ("RES_WallCabinet_0.8", "KIT", "mount", "B", -5.95),                   # 18 (off the kitchen window)
    ("RES_DishRack", "KIT", "on", 16, (0.32, 0.0), 0),                     # 19
    ("RES_Kettle", "KIT", "on", 17, (-0.15, 0.1), 30),                     # 20
    ("RES_CerealBox", "KIT", "on", 15, (-0.3, 0.05), 10),                  # 21
    ("RES_Radio", "KIT", "on", 15, (0.25, -0.1), -5),                      # 22
    ("RES_DiningTable_Round", "KIT", "c", (-4.6, 8.5), 0),                 # 23
    ("RES_DiningChair_Wood", "KIT", "c", (-4.6, 7.75), 0),                 # 24
    ("RES_DiningChair_Wood", "KIT", "c", (-5.35, 8.6), 90),                # 25
    ("RES_Dishes_Set", "KIT", "on", 23, (0.15, 0.1), 0),                   # 26
    ("RES_WallCalendar", "KIT", "mount", "R", 7.4),                        # 27
    ("RES_TrashCan_Pedal", "KIT", "wall", "R", 10.9),                       # 28
    # bedroom: where the player wakes - unmade bed, alarm clock 6:47 PM, desk with PC, posters, dresser
    ("RES_Bed_Double_Unmade", "BED", "wall", "R", 6.9),                    # 29
    ("RES_Nightstand", "BED", "wall", "R", 5.5),                            # 30
    ("RES_AlarmClock", "BED", "on", 30, (0.0, 0.05), 0),                   # 31
    ("RES_Lamp_Table", "BED", "on", 30, (0.12, -0.05), 0),                 # 32
    ("RES_Desk_Computer", "BED", "wall", "F", 0.9),  # 33  under the front window
    ("RES_DeskChair_Office", "BED", "c", (0.9, 5.6), 0),                   # 34
    ("RES_Dresser", "BED", "wall", "L", 5.8),  # 35
    ("RES_Poster_Band", "BED", "mount", "B", 1.3, 1.7),                    # 36
    ("RES_Blanket_Folded", "BED", "on", 35, (0.2, 0.0), 0),                # 37
    # bathroom
    ("RES_Bathtub", "BATH", "wall", "B", 0.6),                              # 38
    ("RES_Toilet", "BATH", "wall", "L", 10.4),                              # 39
    ("RES_BathSink_Pedestal", "BATH", "wall", "R", 10.2),                   # 40
    ("RES_MedicineCabinet", "BATH", "mount", "R", 10.2),                   # 41
    ("RES_TowelRack", "BATH", "mount", "F", 0.6),                          # 42
    # laundry / mudroom
    ("RES_LaundryBasket", "LAU", "wall", "L", 10.6),  # 43
    # garage: workbench, shelves, water heater, breaker panel, boxes, toolbox
    ("RES_Workbench", "GAR", "wall", "R", 9.4),                             # 44
    ("RES_Toolbox", "GAR", "on", 44, (0.4, 0.0), 0),                       # 45
    ("RES_Shelving_Metal", "GAR", "wall", "B", 5.6),                        # 46
    ("RES_WaterHeater", "GAR", "wall", "R", 7.2),                           # 47
    ("RES_ElectricalPanel", "GAR", "mount", "R", 6.0),                     # 48
    ("RES_CardboardBox_Stack", "GAR", "c", (3.4, 5.4), 15),                # 49
    ("RES_WashingMachine", "GAR", "wall", "B", 4.0),                        # 50
    ("RES_StorageBin", "GAR", "c", (3.4, 6.2), 0),  # 51
]


# ---------------------------------------------------------------------------
def check(house, inst, fmeta):
    """Static furniture checks: inside its room, no overlaps, door passages and swing arcs clear."""
    import numpy as np
    issues = []
    rooms = {r["id"]: r for r in house.p["rooms"]}
    fl = [i for i in inst if i["footprint"]]
    for i in fl:
        r = rooms[i["room"]]["rect"]
        a, b, c, d = i["footprint"]
        if a < r[0] + 0.04 or b < r[1] + 0.04 or c > r[2] - 0.04 or d > r[3] - 0.04:
            issues.append(f"{i['model']} in {i['room']} pokes through a wall {tuple(round(v, 2) for v in i['footprint'])}")
    for k, i in enumerate(fl):
        for j in fl[k + 1:]:
            if i["room"] != j["room"] or abs(i["floor_y"] - j["floor_y"]) > 0.05:
                continue
            a, b, c, d = i["footprint"]
            e, f, g, h = j["footprint"]
            ox, oz = min(c, g) - max(a, e), min(d, h) - max(b, f)
            if ox > 0.03 and oz > 0.03 and not (fmeta[i["model"]].get("chairs") or fmeta[j["model"]].get("chairs")):
                issues.append(f"{i['model']} overlaps {j['model']} in {i['room']}")
    for dr in house.meta["doors"]:
        if dr["kind"] == "garage":
            continue
        n = np.array(dr["normal"])
        t = np.array([-n[1], n[0]])
        c0 = np.array([dr["center"][0], dr["center"][2]])
        pts = []
        for s_ in np.linspace(-dr["w"] / 2 + 0.1, dr["w"] / 2 - 0.1, 5):     # passage 0.9 m each side of the opening
            for a_ in np.linspace(-0.9, 0.9, 10):
                pts.append(c0 + t * s_ + n * a_)
        if "hinge" in dr:                                                 # swing arc of the leaf
            hp = np.array(dr["hinge"])
            for ang in np.linspace(0, abs(dr["open_deg"]), 10):
                yaw = dr["yaw"] + math.radians(ang) * (1 if dr["open_deg"] > 0 else -1)
                v = np.array([math.cos(yaw), -math.sin(yaw)])
                for rr in (0.4, dr["leaf"] - 0.05):
                    pts.append(hp + v * rr)
        for i in fl:
            if abs(i["floor_y"] - dr["center"][1]) > 0.7:
                continue
            a, b, c, d = i["footprint"]
            if any(a < p[0] < c and b < p[1] < d for p in pts):
                issues.append(f"{i['model']} in {i['room']} blocks {dr['name']}")
    return issues


# Curtains are 1.9 m drops hung from the floor line by default, so on most windows the rod sat below the window head
# and the cloth pooled on the floor. Hang each one 8 cm above the head of the window it dresses.
def _hang_curtains():
    import plans
    for key, lay in L.items():
        wins = plans.PLANS[key].get("windows", [])
        for i, e in enumerate(lay):
            if e[2] != "mount" or not e[0].startswith("RES_Curtains"):
                continue
            w = next((w for w in wins if w["room"] == e[1] and w["side"] == e[3] and abs(w["at"] - e[4]) < 0.3), None)
            if w is not None:
                lay[i] = e[:5] + (round(max(0.0, w["sill"] + w["h"] + 0.08 - 1.9), 3),)


_hang_curtains()

