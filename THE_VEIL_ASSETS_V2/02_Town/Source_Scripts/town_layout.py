"""Greyhaven town layout: places Pack 02 kit modules and props, generates the
terrain, building-placement zones and the Godot scene.

World frame: X = east, -Z = north, Y up, metres. Streets sit on a grid of
intersection centres; spacing = 12 m node + n x 10 m modules.

Opening-sequence route (all drivable):
  PLAYER_HOME (Maple Ave) -> Maple Ave -> Oak St (south) -> Main St
  -> SUPERMARKET parking (north side of Main) ; GAME_SHOP is directly across
  Main St (south side), ~40 m on foot via the Main & Oak crosswalks.
"""
import json
import math
import os
import zlib

import numpy as np

from veil_mesh.mesh import MB, T, Ry
from veil_mesh.materials import m01, mt, TOWN, V2, RES_ROOT, MATS
from veil_mesh.gltf import GLBWriter, write_glb_import, COL_KEY
from veil_mesh.kit import LOT_Y, ROW_HALF, EDGE

LAYOUT_DIR = os.path.join(TOWN, "Town_Layout")
SCENE_DIR = os.path.join(TOWN, "Godot_Scenes")
BOUNDS = (-160.0, -160.0, 220.0, 80.0)          # x0, z0, x1, z1
CORE = (-92.0, -134.0, 136.0, 40.0)               # town core; outside = woods

# ---------------------------------------------------------------------------
# Street network
# ---------------------------------------------------------------------------
NODES = {  # id: (x, z, module, open arms, (street along Z, street along X))
    "N1": (-62, 0, "T", "EWN", ("BIRCH LN", "MAIN ST")),
    "N2": (0, 0, "X", "NSEW", ("OAK ST", "MAIN ST")),
    "N3": (62, 0, "T", "EWN", ("CEDAR ST", "MAIN ST")),
    "N4": (124, 0, "T", "EWN", ("QUARRY RD", "MAIN ST")),
    "N5": (-62, -52, "T", "NSE", ("BIRCH LN", "ELM ST")),
    "N6": (0, -52, "X", "NSEW", ("OAK ST", "ELM ST")),
    "N7": (62, -52, "T", "NSW", ("CEDAR ST", "ELM ST")),
    "N8": (-62, -104, "T", "EWS", ("BIRCH LN", "MAPLE AVE")),
    "N9": (0, -104, "T", "EWS", ("OAK ST", "MAPLE AVE")),
    "N10": (62, -104, "L", "WS", ("CEDAR ST", "MAPLE AVE")),
    "N11": (-94, -104, "D", "E", ("", "MAPLE AVE")),
    "N12": (0, 32, "D", "N", ("OAK ST", "")),
}
STREET_SIGN_PAIRS = sorted({v[4] for v in NODES.values() if v[4][0] and v[4][1]})

# edge: (id, A, B, style, street name)
#   style: "main" road+sidewalks (commercial), "comp_com"/"comp_res" composite,
#          "res" unmarked road + sidewalks, "conn" dashed road + sidewalks
EDGES = [
    ("MAIN_W", "N1", "N2", "main", "MAIN ST"),
    ("MAIN_C", "N2", "N3", "main", "MAIN ST"),
    ("MAIN_E", "N3", "N4", "comp_com", "MAIN ST"),
    ("BIRCH_S", "N1", "N5", "res", "BIRCH LN"),
    ("OAK_N1", "N2", "N6", "conn", "OAK ST"),
    ("CEDAR_S", "N3", "N7", "comp_res", "CEDAR ST"),
    ("ELM_W", "N5", "N6", "res", "ELM ST"),
    ("ELM_E", "N6", "N7", "res", "ELM ST"),
    ("BIRCH_N", "N5", "N8", "res", "BIRCH LN"),
    ("OAK_N2", "N6", "N9", "conn", "OAK ST"),
    ("CEDAR_N", "N7", "N10", "res", "CEDAR ST"),
    ("MAPLE_W", "N8", "N9", "res", "MAPLE AVE"),
    ("MAPLE_E", "N9", "N10", "res", "MAPLE AVE"),
    ("MAPLE_X", "N8", "N11", "comp_res", "MAPLE AVE"),
    ("OAK_S", "N2", "N12", "conn", "OAK ST"),
]

# rural chains start at a node arm and run outward:  (id, node, arm, pieces, terminus zone)
#   pieces: "T" transition, "R" rural straight, "CR"/"CL" gentle curve right/left
RURAL = [
    ("MILL_RD", "N1", "W", ["T", "R", "R", "CR", "R", "R", "R"], "WOODS_TRAILHEAD"),
    ("ROUTE_9", "N4", "E", ["T", "R", "R", "CR", "R", "R"], "ESCAPE_ROUTE_EAST"),
    ("QUARRY_RD", "N4", "N", ["T", "R", "R", "R", "CR", "R", "R"], "QUARRY_ENTRANCE"),
]

DIRS = {"N": (0, -1), "S": (0, 1), "E": (1, 0), "W": (-1, 0)}


def yaw_for(d):
    return math.atan2(d[0], d[1])


def rot(yaw, x, z):
    c, s = math.cos(yaw), math.sin(yaw)
    return (c * x + s * z, -s * x + c * z)


def rng_of(s):
    return np.random.default_rng(zlib.crc32(s.encode()))


class Layout:
    def __init__(self, manifest):
        self.man = {m["name"]: m for m in manifest}
        self.items = []
        self.zones = []
        self.journey = []
        self.lights = []
        self.counter = {}
        self.drive_links = []   # (driveway-transition placement, lot placement) for the validator
        self.occupied_rects = []

    # ---- placement -----------------------------------------------------------
    def place(self, model, group, x, z, yaw=0.0, y=None, tag=None, **meta):
        """y=None: road-level groups sit at 0, everything else on the 0.15 m
        sidewalk/lot level. An explicit y is a height above that level."""
        assert model in self.man, model
        base = 0.0 if group in ("Roads", "Sidewalks", "Lots", "Markings") else LOT_Y
        y = base if y is None else (y if group in ("Roads", "Sidewalks", "Lots", "Markings") else LOT_Y + y)
        k = self.counter.get(model, 0) + 1
        self.counter[model] = k
        it = dict(model=model, group=group, x=round(x, 4), y=round(y, 4), z=round(z, 4),
                  yaw=round(yaw, 6), name=f"{model}_{k:03d}", tag=tag, **meta)
        self.items.append(it)
        return it

    def world_rect(self, it):
        fp = self.man[it["model"]].get("footprint")
        if not fp:
            return None
        x0, z0, x1, z1 = fp
        pts = [rot(it["yaw"], x, z) for x, z in ((x0, z0), (x1, z0), (x1, z1), (x0, z1))]
        xs = [p[0] + it["x"] for p in pts]
        zs = [p[1] + it["z"] for p in pts]
        return (round(min(xs), 4), round(min(zs), 4), round(max(xs), 4), round(max(zs), 4))

    def free(self, x, z, margin=1.0):
        for r in self.occupied_rects:
            if r[0] - margin <= x <= r[2] + margin and r[1] - margin <= z <= r[3] + margin:
                return False
        return True


# ---------------------------------------------------------------------------
# Street building
# ---------------------------------------------------------------------------
NODE_MODEL = {"X": "RD_Intersection_4Way_12m", "T": "RD_Intersection_T_12m", "L": "RD_Corner_Sharp_12m",
              "D": "RD_DeadEnd_12m"}
NODE_BASE_ARMS = {"X": "NSEW", "T": "SEW", "L": "SE", "D": "S"}


def node_yaw(kind, arms):
    base = NODE_BASE_ARMS[kind]
    for k in range(4):
        a = -k * math.pi / 2
        got = set()
        for b in base:
            dx, dz = rot(a, *DIRS[b])
            for nm, (ex, ez) in DIRS.items():
                if abs(dx - ex) < 1e-6 and abs(dz - ez) < 1e-6:
                    got.add(nm)
        if got == set(arms):
            return a
    raise ValueError((kind, arms))


def edge_frame(A, B):
    ax, az = NODES[A][:2]
    bx, bz = NODES[B][:2]
    L = math.hypot(bx - ax, bz - az)
    d = ((bx - ax) / L, (bz - az) / L)
    yaw = yaw_for(d)
    lx = rot(yaw, 1, 0)   # local +X (sidewalk side "A") in world
    start = (ax + d[0] * 6, az + d[1] * 6)
    end_node = NODES[B][2]
    length = L - 6 - 6
    return dict(d=d, yaw=yaw, lx=lx, start=start, n=int(round(length / 10)), L=length)


def world_side(fr, side):
    """'A' = road-local +X side, 'B' = -X; also accept world N/S/E/W."""
    if side in ("A", "B"):
        return side
    v = DIRS[side]
    return "A" if v[0] * fr["lx"][0] + v[1] * fr["lx"][1] > 0 else "B"


def build_streets(L, lots):
    # nodes
    for nid, (x, z, kind, arms, names) in NODES.items():
        L.place(NODE_MODEL[kind], "Roads", x, z, node_yaw(kind, arms), tag=nid)
    # driveway overrides from lots
    overrides = {}
    for lot in lots:
        if lot.get("edge"):
            overrides[(lot["edge"], lot["k"], lot["side"])] = "SW_DrivewayTransition_10m"
    def put(key, mdl):
        assert overrides.get(key, mdl) == mdl, f"sidewalk override conflict at {key}"
        overrides[key] = mdl
    overrides[("OAK_S", 1, "W")] = "SW_DrivewayTransition_10m"   # alley entrance
    put(("MAIN_C", 0, "N"), "SW_DrivewayTransition_10m")  # supermarket lot entries
    put(("MAIN_C", 2, "N"), "SW_DrivewayTransition_10m")
    put(("MAIN_W", 2, "S"), "SW_CurbRamp_10m")            # mid-block crossing
    put(("MAIN_W", 2, "N"), "SW_CurbRamp_10m")
    put(("OAK_N2", 2, "W"), "SW_StormDrain_10m")
    put(("OAK_N2", 2, "E"), "SW_StormDrain_10m")
    put(("ELM_W", 1, "S"), "SW_StormDrain_10m")
    put(("MAPLE_E", 1, "N"), "SW_StormDrain_10m")
    cracked = {("BIRCH_S", 1, "A"), ("BIRCH_S", 2, "B"), ("ELM_W", 3, "A"), ("MAPLE_W", 1, "B"),
               ("OAK_N1", 1, "A"), ("CEDAR_N", 2, "B")}
    road_var = {("ELM_W", 2): "RD_Straight_2Lane_10m_Patched", ("MAIN_W", 1): "RD_Straight_2Lane_10m_Cracked",
                ("MAIN_W", 3): "RD_Straight_2Lane_10m_Cracked", ("MAIN_C", 3): "RD_Straight_2Lane_10m_Patched",
                ("OAK_N1", 2): "RD_Straight_2Lane_10m_Cracked", ("MAPLE_W", 3): "RD_Straight_2Lane_10m_Patched",
                ("BIRCH_N", 1): "RD_Straight_2Lane_10m_Cracked"}
    frames = {}
    for (eid, A, B, style, street) in EDGES:
        fr = edge_frame(A, B)
        frames[eid] = fr
        resolved = {}
        for (e, k, s), mdl in overrides.items():
            if e == eid:
                resolved[(k, world_side(fr, s))] = mdl
        for k in range(fr["n"]):
            sx = fr["start"][0] + fr["d"][0] * 10 * k
            sz = fr["start"][1] + fr["d"][1] * 10 * k
            if style.startswith("comp"):
                mdl = "RD_Street_Commercial_10m" if style == "comp_com" else "RD_Street_Residential_10m"
                if not any((k, s) in resolved for s in "AB"):
                    L.place(mdl, "Roads", sx, sz, fr["yaw"], tag=f"{eid}:{k}")
                    continue
            base = {"main": "RD_Straight_2Lane_10m", "conn": "RD_Straight_2Lane_10m",
                    "res": "RD_Straight_2Lane_10m_Unmarked"}.get(style, "RD_Straight_2Lane_10m_Unmarked")
            L.place(road_var.get((eid, k), base), "Roads", sx, sz, fr["yaw"], tag=f"{eid}:{k}")
            for side in "AB":
                sw = resolved.get((k, side))
                if sw is None:
                    sw = "SW_Straight_10m_Cracked" if (eid, k, side) in cracked else "SW_Straight_10m"
                if side == "A":
                    ox, oz = rot(fr["yaw"], EDGE, 0)
                    L.place(sw, "Sidewalks", sx + ox, sz + oz, fr["yaw"], tag=f"{eid}:{k}:A")
                else:
                    ox, oz = rot(fr["yaw"], -EDGE, 10)
                    L.place(sw, "Sidewalks", sx + ox, sz + oz, fr["yaw"] + math.pi, tag=f"{eid}:{k}:B")
    # rural chains
    for (rid, nid, arm, pieces, term) in RURAL:
        x, z = NODES[nid][0] + DIRS[arm][0] * 6, NODES[nid][1] + DIRS[arm][1] * 6
        d = DIRS[arm]
        for i, p in enumerate(pieces):
            yaw = yaw_for(d)
            if p in ("T", "R"):
                L.place("RD_Transition_UrbanToRural_10m" if p == "T" else "RD_Shoulder_Rural_10m", "Roads", x, z, yaw,
                        tag=f"{rid}:{i}")
                x, z = x + d[0] * 10, z + d[1] * 10
            else:
                mdl = "RD_Curve_Gentle_Right_30m" if p == "CR" else "RD_Curve_Gentle_Left_30m"
                L.place(mdl, "Roads", x, z, yaw, tag=f"{rid}:{i}")
                ex = -24 if p == "CR" else 24
                ox, oz = rot(yaw, ex, 24)
                x, z = x + ox, z + oz
                nd = rot(yaw, -1 if p == "CR" else 1, 0)
                d = (round(nd[0]), round(nd[1]))
        L.zones_pending = getattr(L, "zones_pending", [])
        L.zones_pending.append((term, x, z, d))
    return frames


# ---------------------------------------------------------------------------
# Lots and building zones
# ---------------------------------------------------------------------------
def lot_rect(fr, s0, s1, side, depth=20.0):
    sgn = 1 if side == "A" else -1
    pts = []
    for s in (s0, s1):
        for lat in (ROW_HALF, ROW_HALF + depth):
            x = fr["start"][0] - fr["d"][0] * 6 + fr["d"][0] * s + fr["lx"][0] * lat * sgn
            z = fr["start"][1] - fr["d"][1] * 6 + fr["d"][1] * s + fr["lx"][1] * lat * sgn
            pts.append((x, z))
    xs, zs = [p[0] for p in pts], [p[1] for p in pts]
    return (min(xs), min(zs), max(xs), max(zs))


def at(fr, s, lat, side):
    sgn = 1 if side == "A" else -1
    x = fr["start"][0] - fr["d"][0] * 6 + fr["d"][0] * s + fr["lx"][0] * lat * sgn
    z = fr["start"][1] - fr["d"][1] * 6 + fr["d"][1] * s + fr["lx"][1] * lat * sgn
    return x, z


def residential_lots(frames):
    """(edge, side, along-range from node A centre, driveway module k)."""
    spec = []
    five = [((6, 22), 0), ((22, 39), 2), ((39, 56), 4)]
    four = [((6, 26), 0), ((26, 46), 3)]
    for e, side in (("ELM_W", "N"), ("ELM_E", "N"), ("MAPLE_W", "S"), ("MAPLE_W", "N"), ("MAPLE_E", "S"), ("MAPLE_E", "N")):
        for (rng_, k) in five:
            spec.append((e, side, rng_, k))
    spec += [("MAPLE_X", "N", (6, 26), 0), ("MAPLE_X", "S", (6, 26), 1), ("BIRCH_N", "W", (6, 26), 0),
             ("CEDAR_N", "E", (6, 26), 0), ("CEDAR_N", "E", (26, 46), 3)]
    lots = []
    n = 0
    for (e, side, (s0, s1), k) in spec:
        fr = frames[e] if frames else None
        n += 1
        lots.append(dict(id=f"HOUSE_{n:02d}", edge=e, side=side, s0=s0, s1=s1, k=k))
    # the protagonist's home: Maple Ave south side, middle lot of the east block
    for lot in lots:
        if lot["edge"] == "MAPLE_E" and lot["side"] == "S" and lot["k"] == 2:
            lot["id"] = "PLAYER_HOME"
    return lots


def zone(L, zid, kind, rect, front, access, pack, height, hero=False, note=""):
    L.zones.append(dict(id=zid, type=kind, rect=[round(v, 3) for v in rect], front=front,
                        access=[round(access[0], 3), round(access[1], 3)], pack=pack, height=height, hero=hero, note=note))


def build_lots(L, frames, lots):
    for lot in lots:
        fr = frames[lot["edge"]]
        side = world_side(fr, lot["side"])
        rect = lot_rect(fr, lot["s0"], lot["s1"], side)
        lot["rect"] = rect
        lot["sideAB"] = side
        drv_s = 6 + 10 * lot["k"] + 5
        # driveway from the property line 8 m into the lot
        dx, dz = at(fr, drv_s, ROW_HALF, side)
        sgn = 1 if side == "A" else -1
        dyaw = yaw_for((fr["lx"][0] * sgn, fr["lx"][1] * sgn))
        drv = L.place("RD_Driveway_3x8m", "Lots", dx, dz, dyaw, tag=lot["id"])
        lot["driveway"] = drv
        L.drive_links.append((f"{lot['edge']}:{lot['k']}:{side}", drv["name"]))
        # house zone: 6 m front setback, 12 m deep, 2 m side yards
        hz0, hz1 = lot["s0"] + 2.0, lot["s1"] - 2.0
        zr = None
        pts = [at(fr, s, lat, side) for s in (hz0, hz1) for lat in (ROW_HALF + 6, ROW_HALF + 18)]
        zr = (min(p[0] for p in pts), min(p[1] for p in pts), max(p[0] for p in pts), max(p[1] for p in pts))
        front = {"A": (fr["lx"][0] * -1, fr["lx"][1] * -1), "B": fr["lx"]}[side]
        acc = at(fr, drv_s, ROW_HALF + 8, side)
        zone(L, lot["id"], "residential_house", zr, front, acc, "Pack 03", 7.0, hero=lot["id"] == "PLAYER_HOME",
             note="Protagonist's house + sedan on the driveway" if lot["id"] == "PLAYER_HOME" else "")
        if lot["id"] == "PLAYER_HOME":
            L.journey.append(("1_WAKE_UP_HOME", zr[0] + (zr[2] - zr[0]) / 2, zr[1] + (zr[3] - zr[1]) / 2))
            L.journey.append(("2_SEDAN_ON_DRIVEWAY", *at(fr, drv_s, ROW_HALF + 4, side)))


def build_commercial(L, frames):
    # Main St north, block x 6..56: supermarket + parking lot (4 x 10 m modules)
    for i, cx in enumerate((11, 21, 31, 41)):
        it = L.place("RD_ParkingLot_10x20m", "Lots", cx, -6, math.pi, tag="SUPERMARKET_LOT")
    for cx in (11, 21, 31, 41):
        L.place("SW_ParkingLotEdge_10m", "Lots", cx + 5, -26, -math.pi / 2, tag="SUPERMARKET_LOT")
    L.drive_links.append(("MAIN_C:0:N", "RD_ParkingLot_10x20m_001"))
    L.drive_links.append(("MAIN_C:2:N", "RD_ParkingLot_10x20m_003"))
    zone(L, "SUPERMARKET", "supermarket", (12, -45, 54, -27), (0, 1), (31, -26.5), "Pack 04", 7.5, hero=True,
         note="Entrance faces the parking lot (south)")
    zone(L, "MUNICIPAL_ARCHIVE", "civic_archive", (-48, -42, -16, -14), (0, 1), (-28.75, -6.2), "Pack 04", 9.0,
         note="Set back behind a lawn; the walkway enters through the gap in the brick wall at x=-28.75")
    zone(L, "GAME_SHOP", "storefront_videogames", (8, 7, 20, 19), (0, -1), (14, 6.5), "Pack 04", 5.0, hero=True,
         note="Independent video game shop, directly across Main St from the supermarket")
    zone(L, "STOREFRONT_A", "storefront", (21, 7, 34, 19), (0, -1), (27.5, 6.5), "Pack 04", 5.0)
    zone(L, "STOREFRONT_B", "storefront", (35, 7, 55, 19), (0, -1), (45, 6.5), "Pack 04", 5.5)
    zone(L, "PHARMACY", "pharmacy", (-30, 7, -8, 18), (0, -1), (-19, 6.5), "Pack 04", 5.5, hero=True)
    zone(L, "STOREFRONT_C", "storefront", (-55, 7, -31, 18), (0, -1), (-43, 6.5), "Pack 04", 5.0)
    zone(L, "STOREFRONT_D", "storefront", (69, 7, 92, 20), (0, -1), (80, 6.5), "Pack 04", 5.0)
    zone(L, "COMMERCIAL_SPARE", "commercial_spare", (70, -44, 116, -12), (0, 1), (93, -6.5), "Pack 04", 6.0,
         note="Reserved (e.g. diner / hardware store)")
    # alley behind the south-west stores, entered from Oak St
    for k in range(5):
        L.place("RD_Alley_4x10m", "Lots", -6 - 10 * k, 21, -math.pi / 2, tag="ALLEY")
    L.drive_links.append(("OAK_S:1:W", "RD_Alley_4x10m_001"))
    L.journey.append(("3_DRIVE_MAPLE_TO_OAK", 0, -104))
    L.journey.append(("4_OAK_TO_MAIN", 0, 0))
    L.journey.append(("5_SUPERMARKET_PARKING", 31, -16))
    L.journey.append(("6_GAME_SHOP_ENTRANCE", 14, 6.5))


def gas_forecourt():
    mb, col = MB(), MB()
    pts = [(130, -40), (166, -40), (166, -6), (130, -6)]
    mb.ground_poly(m01("Com_GasStationPavement"), pts, y=LOT_Y)
    col.ground_poly(COL_KEY, pts, y=LOT_Y)
    w = m01("Road_MarkingWhite")
    for x in (154.0, 156.5, 159.0, 161.5, 164.0):   # parking stalls by the shop
        mb.ground_poly(w, [(x, -22), (x + 0.1, -22), (x + 0.1, -17), (x, -17)], y=LOT_Y + 0.006)
    for (cx, cz) in ((138, -16), (146, -16)):        # pump islands (canopy goes in Pack 04)
        mb.box(m01("Road_CurbConcrete"), (cx - 0.6, LOT_Y, cz - 3.0), (cx + 0.6, LOT_Y + 0.15, cz + 3.0))
        col.box(COL_KEY, (cx - 0.6, LOT_Y, cz - 3.0), (cx + 0.6, LOT_Y + 0.15, cz + 3.0), skip=())
    return {"name": "TOWN_GasForecourt", "children": [{"name": "TOWN_GasForecourt_Mesh", "mb": mb},
                                                       {"name": "TOWN_GasForecourt_Col-colonly", "mb": col}]}


def build_outskirts(L):
    zone(L, "GAS_STATION", "gas_station", (148, -38, 164, -26), (0, 1), (140, -6.5), "Pack 04", 5.0,
         note="Corner lot: vehicle entrances from Route 9 (south) and Quarry Rd (west)")
    zone(L, "GAS_PUMP_CANOPY", "gas_canopy", (134, -22, 150, -10), (0, 1), (142, -6.5), "Pack 04", 5.5)
    L.items.append(dict(model="TOWN_GasForecourt", group="Lots", x=0, y=0, z=0, yaw=0, name="TOWN_GasForecourt_001",
                        tag="GAS_STATION", rect=(130, -40, 166, -6)))
    for (term, x, z, d) in L.zones_pending:
        if term == "QUARRY_ENTRANCE":
            zone(L, term, "quarry_entrance", (x, z - 12, x + 28, z + 12), (-1, 0), (x + 0.5, z), "future", 0.0,
                 note="Quarry itself is NOT in Pack 02; gated gravel apron only")
        elif term == "ESCAPE_ROUTE_EAST":
            zone(L, term, "route_exit", (x - 6, z, x + 6, z + 14), (0, -1), (x, z + 0.5), "future", 0.0,
                 note="Route 9 leaves town here - future escape route")
        else:
            zone(L, term, "trailhead", (x - 8, z - 14, x + 8, z), (0, 1), (x, z - 0.5), "future", 0.0,
                 note="Mill Rd ends at the woods")
    zone(L, "FARMHOUSE", "residential_sparse", (151, -98, 165, -84), (0, 1), (158, -77), "Pack 03", 7.0,
         note="Sparse property on Quarry Rd")
    L.place("RD_Driveway_3x8m", "Lots", 158, -76, math.pi, tag="FARMHOUSE")
    zone(L, "MILL_HOUSE", "residential_sparse", (-98, 14, -86, 26), (0, -1), (-93, 13.5), "Pack 03", 7.0,
         note="Sparse property on Mill Rd near the woods")
    L.place("RD_Driveway_3x8m", "Lots", -93, 6, 0.0, tag="MILL_HOUSE")


# ---------------------------------------------------------------------------
# Props
# ---------------------------------------------------------------------------
def build_props(L, frames, lots):
    rng = rng_of("greyhaven_props")
    # -- street lights ------------------------------------------------------
    driveway_s = {}
    for lot in lots:
        driveway_s.setdefault(lot["edge"], []).append((6 + 10 * lot["k"] + 5, lot["sideAB"]))
    for (eid, A, B, style, street) in EDGES:
        fr = frames[eid]
        commercial = style in ("main", "comp_com")
        step = 20 if commercial else 25
        s = 8.0
        side = "A"
        while s < 6 + fr["L"] - 1:
            if any(abs(s - ds) < 3 and dsd == side for ds, dsd in driveway_s.get(eid, [])):
                s += 3
            lat = EDGE + (0.5 if commercial else 1.9)
            x, z = at(fr, s, lat, side)
            sgn = 1 if side == "A" else -1
            to_road = (-fr["lx"][0] * sgn, -fr["lx"][1] * sgn)
            mdl = "SP_Lamp_Commercial" if commercial else "SP_Lamp_Residential"
            it = L.place(mdl, "StreetProps", x, z, yaw_for(to_road), tag=eid)
            L.lights.append(it)
            side = "B" if side == "A" else "A"
            s += step
    # -- stop signs, street names, hydrants at nodes -------------------------
    for nid, (x, z, kind, arms, names) in NODES.items():
        if kind == "D":
            continue
        stem = [a for a in arms if (kind == "T" and DIRS[a] == tuple(-v for v in DIRS[[b for b in "NSEW" if b not in arms][0]]))]
        stop_arms = arms if kind == "X" else (stem if kind == "T" else [])
        if nid == "N2":
            stop_arms = []   # signalised
        for a in stop_arms:
            d = DIRS[a]
            t = (-d[0], -d[1])                       # approach travel direction
            right = (-t[1], t[0])                     # Godot: facing +Z, right is -X
            px, pz = x + d[0] * 6.8 + right[0] * 4.6, z + d[1] * 6.8 + right[1] * 4.6
            L.place("SP_Sign_Stop", "StreetProps", px, pz, yaw_for(d), tag=nid)
        a_name, b_name = names
        if a_name and b_name:
            corners = [(sx, sz) for sx in (1, -1) for sz in (1, -1)]
            cx, cz = corners[zlib.crc32(nid.encode()) % 4]
            mdl = f"SP_Sign_StreetName_{a_name.split()[0].title()}_{b_name.split()[0].title()}"
            if mdl in L.man:
                L.place(mdl, "StreetProps", x + cx * 5.4, z + cz * 5.4, 0.0, tag=nid)
        if nid in ("N1", "N3", "N5", "N6", "N9", "N10"):
            L.place("SP_FireHydrant", "StreetProps", x - 5.2, z + 6.8 if nid != "N10" else z + 7.5, 0.0, tag=nid)
    # signals at Main & Oak
    L.place("SP_TrafficLight_MastArm", "StreetProps", -5.0, 5.0, 0.0, tag="N2")
    L.place("SP_TrafficLight_MastArm", "StreetProps", 5.0, -5.0, math.pi, tag="N2")
    L.place("SP_TrafficLight_MastArm", "StreetProps", 5.0, 5.0, math.pi / 2, tag="N2")
    L.place("SP_TrafficLight_MastArm", "StreetProps", -5.0, -5.0, -math.pi / 2, tag="N2")
    # crosswalks + stop bars at Main & Oak and Main & Cedar
    for (nx, nz, arms_) in ((0, 0, "NSEW"), (62, 0, "EW"), (-62, 0, "E")):
        for a in arms_:
            d = DIRS[a]
            L.place("SW_Crosswalk_7m", "Markings", nx + d[0] * EDGE, nz + d[1] * EDGE, yaw_for(d), tag="crosswalk")
    L.place("SW_Crosswalk_7m", "Markings", -32.125, 0.0, math.pi / 2, tag="midblock_MAIN_W")  # between the curb ramps
    # speed limits / dead ends / one-way / parking
    L.place("SP_Sign_SpeedLimit25", "StreetProps", -72, 4.8, math.pi / 2 * -1 + math.pi, tag="MILL_RD")
    L.place("SP_Sign_SpeedLimit25", "StreetProps", 134, -4.8, -math.pi / 2, tag="ROUTE_9")
    L.place("SP_Sign_SpeedLimit25", "StreetProps", 128.8, -12, math.pi, tag="QUARRY_RD")
    L.place("SP_Sign_SpeedLimit25", "StreetProps", 30, -98.6 - 0.5, 0.0, tag="MAPLE_E")
    L.place("SP_Sign_DeadEnd", "StreetProps", -70, -98.8, math.pi / 2, tag="MAPLE_X")
    L.place("SP_Sign_DeadEnd", "StreetProps", -4.7, 9, 0.0, tag="OAK_S")
    L.place("SP_Sign_OneWay", "StreetProps", -7.2, 19.0, -math.pi / 2, tag="ALLEY")
    L.place("SP_Sign_Yield", "StreetProps", -5.8, 23.6, -math.pi / 2, tag="ALLEY")
    for x in (12, 28, 44):
        L.place("SP_Sign_Parking2HR", "StreetProps", x, -26.5, 0.0, tag="SUPERMARKET_LOT")
    L.place("SP_Sign_NoParking", "StreetProps", -4.5, 4.6 + 4, math.pi, tag="N2")
    # -- Main St furniture ----------------------------------------------------
    for x in (-44, -20, 26, 50):
        L.place("SP_TrashBin_Public", "Interactive", x, 5.2 if x < 0 else -5.2 if x > 40 else 5.2, 0.0, tag="MAIN")
    L.place("SP_Bench_Wood", "StreetProps", -24, 5.3, 0.0, tag="MAIN")
    L.place("SP_Bench_Wood", "StreetProps", 40, -5.3, math.pi, tag="MAIN")
    L.place("SP_Sign_BusStop", "StreetProps", -10, 4.3, math.pi, tag="MAIN")
    L.place("SP_BusShelter", "StreetProps", 92, 4.9 + 0.3, math.pi, tag="MAIN_E")
    L.place("SP_NewspaperBox", "Interactive", 17.5, 5.4, math.pi, tag="GAME_SHOP")
    L.place("SP_NewspaperBox", "Interactive", -15.0, 5.4, math.pi, tag="PHARMACY")
    L.place("SP_BikeRack", "StreetProps", 22.5, 5.5, 0.0, tag="GAME_SHOP")
    for x in (28.5, 34.5, 40.5, 46.5, -50, -38, -26):
        L.place("SP_ParkingMeter", "StreetProps", x, 4.3, 0.0, tag="MAIN")
    L.place("SP_PhoneBooth", "Interactive", 163.5, -9, math.pi, tag="GAS_STATION")
    for (x, z) in ((132, -8), (164, -8), (132, -38)):
        L.lights.append(L.place("SP_Lamp_Commercial", "StreetProps", x, z, yaw_for((0, -1)), tag="GAS_STATION"))
    # -- alley / service -------------------------------------------------------
    for x in (-20, -44):
        L.place("SP_Dumpster", "Interactive", x, 24.6, math.pi, tag="ALLEY")
    L.place("SP_Dumpster", "Interactive", 8.6, -41.0, math.pi / 2, tag="SUPERMARKET")
    L.place("SP_Dumpster", "Interactive", 164.5, -39, -math.pi / 2, tag="GAS_STATION")
    for x in (-28, -52):
        L.place("UT_ACUnit_Exterior", "Utilities", x, 19.8 + 0.2, 0.0, tag="ALLEY")
    L.place("UT_ACUnit_Exterior", "Utilities", 9.5, -34.0, math.pi / 2, tag="SUPERMARKET")
    L.place("UT_Transformer_PadMount", "Utilities", 9.0, -30.2, math.pi / 2, tag="SUPERMARKET")
    L.place("UT_ElectricalCabinet", "Utilities", 9.0, -37.2, math.pi / 2, tag="SUPERMARKET")
    L.place("UT_UtilityAccessCover", "StreetProps", 4.9, 12.0, 0.0, y=0.0, tag="OAK_S")
    L.place("UT_UtilityAccessCover", "StreetProps", 60.0 - 5.0, -30.0, 0.0, y=0.0, tag="CEDAR_S")
    # manholes / grates in the roadway
    for (x, z) in ((-31, 0.0), (31, 1.5), (0, -30), (0, -80), (-31, -52), (31, -104), (93, 0)):
        L.place("SP_ManholeCover", "Markings", x, z, 0.0, tag="road")
    for (x, z) in ((-9.0, -2.6), (59.3, -82.0)):
        L.place("SP_DrainGrate", "Markings", x, z, 0.0, tag="road")
    # puddles / patches for variety
    for (x, z) in ((-60.0, -30.2), (19.0, -55.2), (2.8, 18.0), (-40, 21.0)):
        L.place("RD_Puddle_A" if x < 0 else "RD_Puddle_B", "Markings", x, z, rng.random() * 3.0, y=LOT_Y if z > 19 else 0.0, tag="decal")
    for (x, z) in ((-12.0, -51.0), (48.0, -106.0), (-62.0, -82.0), (100, -1.0)):
        L.place("RD_RoadPatch_B" if x > 0 else "RD_RoadPatch_A", "Markings", x, z, rng.random() * 3.0, tag="decal")
    # road works on Elm St: cones + barrier (interactive)
    for k in range(5):
        L.place("SP_TrafficCone", "Interactive", -44 + k * 1.6, -54.2, 0.0, tag="ROADWORKS")
    L.place("SP_RoadBarrier", "Interactive", -37, -55.0, 0.0, tag="ROADWORKS")
    L.place("SP_RoadBarrier", "Interactive", 0, 36.0, 0.0, tag="OAK_S_END")
    for k in range(3):
        L.place("SP_TrafficCone", "Interactive", -2 + 2 * k, 34.5, 0.0, tag="OAK_S_END")
    # -- utility poles + power/telephone lines -------------------------------
    # Lines run along local +Z; poles share the same crossarm axis. Maple (north
    # verge) and Elm (south verge) lines run east along +X: line yaw = +90 deg,
    # pole yaw = +-90 deg so the crossarm lies across the street and the
    # streetlight arm (+X local) reaches over the roadway.
    for (z_line, pole_yaw) in ((-110.7, -math.pi / 2), (-45.3, math.pi / 2)):
        prev = None
        for x in range(-50, 51, 25):
            mdl = "SP_UtilityPole_Streetlight" if (x == 25 and z_line < -100) else "UT_UtilityPole"
            pole = L.place(mdl, "Utilities", x, z_line, pole_yaw, tag="POLES")
            if mdl == "SP_UtilityPole_Streetlight":
                L.lights.append(pole)
            if prev is not None:
                L.place("UT_PowerLine_Span25m", "Utilities", prev, z_line, math.pi / 2, tag="LINES")
                L.place("UT_TelephoneLine_Span25m", "Utilities", prev, z_line, math.pi / 2, tag="LINES")
            prev = x
    L.place("UT_Transformer_PoleMount", "Utilities", 25 + 0.14, -110.7, math.pi / 2, y=7.6, tag="POLES")
    L.place("UT_JunctionBox", "Utilities", -25 + 0.15, -110.7, math.pi / 2, y=1.2, tag="POLES")
    # rural poles (streetlight arm over the road) on Quarry Rd and Mill Rd
    for z in (-14.0, -44.0):
        L.lights.append(L.place("SP_UtilityPole_Streetlight", "Utilities", 129.6, z, math.pi, tag="QUARRY_RD"))
    L.place("UT_PowerLine_Span30m", "Utilities", 129.6, -14.0, math.pi, tag="QUARRY_RD")
    L.lights.append(L.place("SP_UtilityPole_Streetlight", "Utilities", -84, 5.6, math.pi / 2, tag="MILL_RD"))
    # -- lot dressing: mailboxes, water meters, fences, yard plants -----------
    for lot in lots:
        fr = frames[lot["edge"]]
        side = lot["sideAB"]
        drv_s = 6 + 10 * lot["k"] + 5
        r = rng_of(lot["id"])
        sgn = 1 if side == "A" else -1
        out = (fr["lx"][0] * sgn, fr["lx"][1] * sgn)
        to_road = (-out[0], -out[1])
        mx, mz = at(fr, drv_s + 2.3, ROW_HALF + 0.5, side)
        L.place("SP_Mailbox_Residential", "StreetProps", mx, mz, yaw_for(to_road), tag=lot["id"])
        wx, wz = at(fr, drv_s - 2.4, ROW_HALF + 0.6, side)
        L.place("UT_WaterMeter", "StreetProps", wx, wz, 0.0, tag=lot["id"])
        # front yard tree + bushes
        ts = lot["s0"] + 3.5 if drv_s - lot["s0"] > 7 else lot["s1"] - 3.5
        tx, tz = at(fr, ts, ROW_HALF + 3.2, side)
        L.place("VG_Tree_DeciduousLarge" if r.random() < 0.45 else "VG_Tree_DeciduousSmall", "Vegetation", tx, tz,
                r.random() * 6.28, tag=lot["id"])
        for _ in range(2):
            bs = r.uniform(lot["s0"] + 3, lot["s1"] - 3)
            if abs(bs - drv_s) > 3:
                bx, bz = at(fr, bs, ROW_HALF + 4.9, side)
                L.place("VG_Bush" if r.random() < 0.7 else "VG_FlowerPatch", "Vegetation", bx, bz, r.random() * 6.28,
                        tag=lot["id"])
        # front boundary: picket fence / hedge / nothing, with gaps for driveway + path
        style = ["picket", "hedge", "none", "picket", "none"][zlib.crc32(lot["id"].encode()) % 5]
        if lot["id"] == "PLAYER_HOME":
            style = "picket"
        path_s = (lot["s0"] + lot["s1"]) / 2 if abs((lot["s0"] + lot["s1"]) / 2 - drv_s) > 3.5 else lot["s0"] + 4
        fence_run(L, fr, side, lot["s0"] + 0.25, lot["s1"] - 0.25, ROW_HALF + 0.25, style,
                  gaps=[(drv_s - 1.75, drv_s + 1.75)], gate=(path_s if style == "picket" else None), tag=lot["id"])
        # back boundary: weathered privacy fence (or chain link)
        back_style = "privacy" if zlib.crc32((lot["id"] + "b").encode()) % 3 else "chain"
        fence_run(L, fr, side, lot["s0"] + 0.25, lot["s1"] - 0.25, ROW_HALF + 19.6, back_style, gaps=[],
                  gate=None, tag=lot["id"], gate_model="FN_FenceGate_Privacy_1.25m")
    # -- archive lawn: brick wall, railing, ivy ------------------------------------
    for k in range(6):
        L.place("FN_BrickWall_2.5m", "Fences", -50 + 2.5 * k, -6.8, 0.0, tag="ARCHIVE")
        L.place("FN_BrickWall_2.5m", "Fences", -27.5 + 2.5 * k, -6.8, 0.0, tag="ARCHIVE")
    L.place("FN_MetalRailing_2.5m", "Fences", -35, -6.8, 0.0, tag="ARCHIVE")
    L.place("FN_MetalRailing_2.5m", "Fences", -32.5, -6.8, 0.0, tag="ARCHIVE")
    L.place("VG_IvyPatch", "Vegetation", -45, -6.6, 0.0, tag="ARCHIVE")
    L.place("VG_IvyPatch", "Vegetation", -22, -6.6, 0.0, tag="ARCHIVE")
    for x in (-44, -20):
        L.place("VG_Tree_DeciduousLarge", "Vegetation", x, -11, 0.7, tag="ARCHIVE")
    for x in (-52, -12):
        L.place("FN_HedgeBoundary_2.5m", "Fences", x, -44, 0.0, tag="ARCHIVE")
    # -- supermarket lot planting strip, gas station chain link, quarry gate --------
    for z in (-10, -16, -22):
        L.place("VG_Bush", "Vegetation", 51, z, z * 0.3, tag="SUPERMARKET_LOT")
    L.place("VG_Tree_DeciduousSmall", "Vegetation", 51.5, -19, 1.0, tag="SUPERMARKET_LOT")
    for k in range(14):
        L.place("FN_ChainLink_2.5m", "Fences", 131 + 2.5 * k, -40.6, 0.0, tag="GAS_STATION")
    L.place("FN_Post_ChainLink", "Fences", 166, -40.6, 0.0, tag="GAS_STATION")
    q = [z for z in L.zones if z["id"] == "QUARRY_ENTRANCE"][0]
    qx0, qz0, qx1, qz1 = q["rect"]
    fx = qx0 + 2.0                                   # fence line across the road end, sections run along +Z
    zc = (qz0 + qz1) / 2                             # road centreline
    for k in range(3):                               # south run (ends 4.5 m before the centreline)
        L.place("FN_ChainLink_2.5m", "Fences", fx, qz0 + 2.5 * k, -math.pi / 2, tag="QUARRY")
    L.place("FN_Post_ChainLink", "Fences", fx, qz0 + 7.5, -math.pi / 2, tag="QUARRY")
    for dz in (-3.0, 0.0, 3.0):                      # vehicle opening closed by barriers
        L.place("SP_RoadBarrier", "Interactive", fx + 0.6, zc + dz, math.pi / 2, tag="QUARRY")
    L.place("FN_FenceGate_Privacy_1.25m", "Interactive", fx, zc + 4.5, -math.pi / 2, tag="QUARRY")
    for k in range(3):                               # north run after the pedestrian gate
        L.place("FN_ChainLink_2.5m", "Fences", fx, zc + 5.75 + 2.5 * k, -math.pi / 2, tag="QUARRY")
    L.place("FN_Post_ChainLink", "Fences", fx, zc + 13.25, -math.pi / 2, tag="QUARRY")
    for k, (dx, dz) in enumerate(((8, -6), (14, 4), (20, -2), (11, 8))):
        L.place("VG_GravelPile" if k % 2 else "VG_RocksSmall", "Vegetation", qx0 + dx, (qz0 + qz1) / 2 + dz, k, tag="QUARRY")
    for k in range(8):
        L.place("FN_RetainingWall_2.5m", "Fences", qx1 - 3, qz0 + 2 + 2.5 * k, -math.pi / 2, tag="QUARRY")


def fence_run(L, fr, side, s0, s1, lat, style, gaps, gate, tag, gate_model="FN_GardenGate_1.25m"):
    if style == "none":
        return
    sec = {"picket": "FN_Picket_2.5m", "hedge": "FN_HedgeBoundary_2.5m", "privacy": "FN_Privacy_2.5m",
           "chain": "FN_ChainLink_2.5m"}[style]
    post = {"picket": "FN_Post_Picket", "privacy": "FN_Post_Privacy", "chain": "FN_Post_ChainLink"}.get(style)
    d = fr["d"]
    yaw = yaw_for((d[0], d[1])) - math.pi / 2      # section local +X along the street direction
    s = s0
    group = "Fences"
    while s + 2.5 <= s1 + 1e-6:
        if gate is not None and s <= gate < s + 2.5:
            x, z = at(fr, s, lat, side)
            L.place(gate_model, "Interactive", x, z, yaw, tag=tag)
            if post:
                x2, z2 = at(fr, s + 1.25, lat, side)
                L.place(post, group, x2, z2, yaw, tag=tag)
            s += 1.25
            gate = None
            continue
        if any(not (s + 2.5 <= a or s >= b) for a, b in gaps):
            if post:
                x, z = at(fr, s, lat, side)
                L.place(post, group, x, z, yaw, tag=tag)
            s += 1.25
            continue
        x, z = at(fr, s, lat, side)
        L.place(sec, group, x, z, yaw, tag=tag)
        s += 2.5
    if post:
        x, z = at(fr, s, lat, side)
        L.place(post, group, x, z, yaw, tag=tag)


# ---------------------------------------------------------------------------
# Terrain
# ---------------------------------------------------------------------------
CELL = 0.5


def terrain(L):
    x0, z0, x1, z1 = BOUNDS
    nx, nz = int((x1 - x0) / CELL), int((z1 - z0) / CELL)
    occ = np.zeros((nz, nx), bool)
    xs = x0 + (np.arange(nx) + 0.5) * CELL
    zs = z0 + (np.arange(nz) + 0.5) * CELL
    for it in L.items:
        r = it.get("rect") or L.world_rect(it)
        it["rect"] = r
        if r is None or it["group"] not in ("Roads", "Sidewalks", "Lots"):
            continue
        i0, i1 = np.searchsorted(xs, r[0] - 1e-6), np.searchsorted(xs, r[2] + 1e-6)
        j0, j1 = np.searchsorted(zs, r[1] - 1e-6), np.searchsorted(zs, r[3] + 1e-6)
        occ[j0:j1, i0:i1] = True
    # material map
    mat = np.full((nz, nx), 0, np.int8)   # 0 grass short
    names = ["Grnd_GrassShort", "Grnd_GrassOvergrown", "Grnd_LeavesFallen", "Grnd_DeadVegetation", "Grnd_GrassDry",
             "Road_Gravel", "Grnd_Soil"]
    X, Z = np.meshgrid(xs, zs)
    cx0, cz0, cx1, cz1 = CORE
    woods = (X < cx0) | (X > cx1) | (Z < cz0) | (Z > cz1)
    h = ((np.floor(X / 8).astype(int) * 73856093) ^ (np.floor(Z / 8).astype(int) * 19349663)) % 100
    mat[woods] = 1
    mat[woods & (h < 30)] = 2
    mat[woods & (h > 88)] = 3
    for zn in L.zones:
        r = zn["rect"]
        inside = (X >= r[0]) & (X <= r[2]) & (Z >= r[1]) & (Z <= r[3])
        if zn["type"].startswith("storefront") or zn["type"] in ("supermarket", "pharmacy", "commercial_spare", "gas_canopy"):
            mat[inside] = 4
        elif zn["type"] in ("quarry_entrance", "trailhead"):
            mat[inside] = 5
        elif zn["type"] == "route_exit":
            mat[inside] = 6
    # commercial back yards between storefront zones and the alley
    back = (X > -56) & (X < 56) & (Z > 6) & (Z < 19)
    mat[back & (mat == 0)] = 4
    mb, col = MB(), MB()
    rects = 0
    for m in range(len(names)):
        grid = (~occ) & (mat == m)
        done = np.zeros_like(grid)
        for j in range(nz):
            i = 0
            while i < nx:
                if grid[j, i] and not done[j, i]:
                    i2 = i
                    while i2 < nx and grid[j, i2] and not done[j, i2]:
                        i2 += 1
                    j2 = j + 1
                    while j2 < nz and grid[j2, i:i2].all() and not done[j2, i:i2].any():
                        j2 += 1
                    done[j:j2, i:i2] = True
                    ax, bx = x0 + i * CELL, x0 + i2 * CELL
                    az, bz = z0 + j * CELL, z0 + j2 * CELL
                    q = [(ax, az), (bx, az), (bx, bz), (ax, bz)]
                    mb.ground_poly(m01(names[m]), q, y=LOT_Y)
                    col.ground_poly(COL_KEY, q, y=LOT_Y)
                    rects += 1
                    i = i2
                else:
                    i += 1
    spec = {"name": "TOWN_Ground", "children": [{"name": "TOWN_Ground_Mesh", "mb": mb},
                                                 {"name": "TOWN_Ground_Col-colonly", "mb": col}]}
    return spec, occ, rects


def zones_glb(L):
    mb = MB()
    children = []
    for zn in L.zones:
        x0, z0, x1, z1 = zn["rect"]
        h = max(0.6, zn["height"])
        m = mt("ZoneMarkerHero") if zn["hero"] else mt("ZoneMarker")
        zm = MB()
        zm.box(m, (x0, LOT_Y + 0.02, z0), (x1, LOT_Y + h, z1), skip=("-y",))
        children.append({"name": f"ZONE_{zn['id']}", "mb": zm})
    return {"name": "TOWN_BuildingZones", "children": children}


# ---------------------------------------------------------------------------
# Woods & verges scatter
# ---------------------------------------------------------------------------
def scatter(L, occ):
    rng = rng_of("greyhaven_woods")
    x0, z0, x1, z1 = BOUNDS
    zone_rects = [z["rect"] for z in L.zones]
    lot_rects = [lot for lot in getattr(L, "lot_rects", [])]

    def blocked(x, z, m):
        i, j = int((x - x0) / CELL), int((z - z0) / CELL)
        r = int(m / CELL) + 1
        if i - r < 0 or j - r < 0 or i + r >= occ.shape[1] or j + r >= occ.shape[0]:
            return True
        if occ[j - r:j + r, i - r:i + r].any():
            return True
        for zr in zone_rects + lot_rects:
            if zr[0] - m <= x <= zr[2] + m and zr[1] - m <= z <= zr[3] + m:
                return True
        return False
    cx0, cz0, cx1, cz1 = CORE
    n_trees = 0
    for gz in np.arange(z0 + 4, z1 - 4, 8.0):
        for gx in np.arange(x0 + 4, x1 - 4, 8.0):
            x, z = gx + rng.uniform(-3, 3), gz + rng.uniform(-3, 3)
            in_core = cx0 < x < cx1 and cz0 < z < cz1
            if in_core:
                continue
            if blocked(x, z, 3.5):
                continue
            # thin the woods near the road so drivers see a tree line, not a wall
            roll = rng.random()
            mdl = ("VG_Tree_Pine" if roll < 0.5 else "VG_Tree_DeciduousSmall" if roll < 0.68 else
                   "VG_Tree_DeciduousLarge" if roll < 0.82 else "VG_Tree_Dead" if roll < 0.93 else "VG_Tree_Overgrown")
            L.place(mdl, "Vegetation", x, z, rng.random() * 6.28, tag="WOODS")
            n_trees += 1
    under = ["VG_TallGrassClump", "VG_Weeds", "VG_DeadVegetation", "VG_RocksSmall", "VG_TreeStump", "VG_FallenBranch",
             "VG_FallenLeaves", "VG_DirtMound", "VG_MudPatch", "VG_TallGrassClump", "VG_Weeds"]
    for gz in np.arange(z0 + 2, z1 - 2, 6.0):
        for gx in np.arange(x0 + 2, x1 - 2, 6.0):
            if rng.random() > 0.45:
                continue
            x, z = gx + rng.uniform(-2.5, 2.5), gz + rng.uniform(-2.5, 2.5)
            in_core = cx0 < x < cx1 and cz0 < z < cz1
            if in_core and rng.random() > 0.12:
                continue
            if blocked(x, z, 1.2):
                continue
            L.place(under[int(rng.integers(0, len(under)))], "Vegetation", x, z, rng.random() * 6.28, tag="UNDERGROWTH")
    return n_trees


def merge_scatter(L, spec_fn, paths, chunk=64.0):
    """Static batching: woods/undergrowth scatter is merged into 64 x 64 m chunk
    meshes (one surface per material per chunk) to keep draw calls low on
    integrated GPUs and Android. Collision hulls merge into one trimesh."""
    cache = {}
    groups = {}
    keep = []
    for it in L.items:
        if it.get("tag") in ("WOODS", "UNDERGROWTH"):
            key = (int(math.floor(it["x"] / chunk)), int(math.floor(it["z"] / chunk)))
            groups.setdefault(key, []).append(it)
        else:
            keep.append(it)
    L.merged = []
    for (i, j), items in sorted(groups.items()):
        vis, col = MB(), MB()
        for it in items:
            if it["model"] not in cache:
                cache[it["model"]] = spec_fn[it["model"]]()
            M = T(it["x"], it["y"], it["z"]) @ Ry(it["yaw"])
            for ch in cache[it["model"]]["children"]:
                if ch.get("mb") is None:
                    continue
                (col if "colonly" in ch["name"] else vis).merge(ch["mb"], M)
            it["merged_into"] = f"TOWN_Woods_{i}_{j}"
        name = f"TOWN_Woods_{i}_{j}".replace("-", "m")
        for it in items:
            it["merged_into"] = name
        spec = {"name": name, "children": [{"name": name + "_Mesh", "mb": vis}]}
        if col.tri_count():
            spec["children"].append({"name": name + "_Col-colonly", "mb": col})
        pth = os.path.join(LAYOUT_DIR, name + ".glb")
        write_glb_import(pth, GLBWriter(pth).write(spec))
        paths[name] = RES_ROOT + "/02_Town/Town_Layout/" + name + ".glb"
        L.merged.append(dict(name=name, items=len(items), tris=vis.tri_count(), surfaces=len(vis.parts)))
    L.scatter_items = [it for g in groups.values() for it in g]
    L.items = keep


# ---------------------------------------------------------------------------
# Godot scene
# ---------------------------------------------------------------------------
def fnum(v):
    s = f"{v:.5f}".rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def xform(yaw, x, y, z):
    c, s = math.cos(yaw), math.sin(yaw)
    rows = [c, 0, s, 0, 1, 0, -s, 0, c]
    return "Transform3D(" + ", ".join(fnum(v) for v in rows + [x, y, z]) + ")"


GROUP_PARENT = {
    "Roads": "Static/Roads", "Sidewalks": "Static/Sidewalks", "Lots": "Static/Lots", "Markings": "Static/Markings",
    "StreetProps": "Static/StreetProps", "Utilities": "Static/Utilities", "Vegetation": "Static/Vegetation",
    "Fences": "Static/Fences", "Interactive": "Interactive",
}


def write_tscn(L, path, model_paths):
    chunks = [m["name"] for m in getattr(L, "merged", [])]
    used = sorted({it["model"] for it in L.items} | {"TOWN_Ground", "TOWN_BuildingZones"} | set(chunks))
    ids = {m: f"{i + 1}_{m[:24]}" for i, m in enumerate(used)}
    lines = [f'[gd_scene load_steps={len(used) + 4} format=3]', ""]
    for m in used:
        lines.append(f'[ext_resource type="PackedScene" path="{model_paths[m]}" id="{ids[m]}"]')
    lines += ["",
              '[sub_resource type="ProceduralSkyMaterial" id="Sky_Mat"]',
              "sky_top_color = Color(0.32, 0.34, 0.47, 1)",
              "sky_horizon_color = Color(0.78, 0.56, 0.42, 1)",
              "ground_bottom_color = Color(0.14, 0.13, 0.13, 1)",
              "ground_horizon_color = Color(0.6, 0.45, 0.36, 1)",
              "sun_angle_max = 20.0",
              "",
              '[sub_resource type="Sky" id="Sky_Res"]',
              'sky_material = SubResource("Sky_Mat")',
              "",
              '[sub_resource type="Environment" id="Env_Evening"]',
              "background_mode = 2",
              'sky = SubResource("Sky_Res")',
              "ambient_light_source = 3",
              "ambient_light_color = Color(0.55, 0.48, 0.46, 1)",
              "ambient_light_energy = 0.55",
              "tonemap_mode = 2",
              "fog_enabled = true",
              "fog_light_color = Color(0.62, 0.52, 0.47, 1)",
              "fog_density = 0.004",
              "fog_sky_affect = 0.4",
              ""]
    lines += ['[node name="Greyhaven_Town" type="Node3D"]', "",
              '[node name="Environment" type="Node3D" parent="."]', "",
              '[node name="WorldEnvironment" type="WorldEnvironment" parent="Environment"]',
              'environment = SubResource("Env_Evening")', "",
              '[node name="EveningSun" type="DirectionalLight3D" parent="Environment"]',
              xform_dir(-0.21, 2.35).join(["transform = ", ""]),
              "light_color = Color(1, 0.74, 0.5, 1)", "light_energy = 0.85", "shadow_enabled = true",
              "directional_shadow_max_distance = 80.0", ""]
    groups = ["Static", "Static/Terrain", "Static/Roads", "Static/Sidewalks", "Static/Lots", "Static/Markings",
              "Static/StreetProps", "Static/Utilities", "Static/Vegetation", "Static/Vegetation/WoodsChunks",
              "Static/Fences", "Interactive", "Lights",
              "BuildingZones", "BuildingZones/Markers", "Journey"]
    for g in groups:
        parent = "." if "/" not in g else g.rsplit("/", 1)[0]
        lines += [f'[node name="{g.rsplit("/", 1)[-1]}" type="Node3D" parent="{parent}"]', ""]
    lines += [f'[node name="TOWN_Ground" parent="Static/Terrain" instance=ExtResource("{ids["TOWN_Ground"]}")]', ""]
    for c in chunks:
        lines += [f'[node name="{c}" parent="Static/Vegetation/WoodsChunks" instance=ExtResource("{ids[c]}")]', ""]
    for it in L.items:
        par = GROUP_PARENT[it["group"]]
        lines.append(f'[node name="{it["name"]}" parent="{par}" instance=ExtResource("{ids[it["model"]]}")]')
        if it["x"] or it["y"] or it["z"] or it["yaw"]:
            lines.append("transform = " + xform(it["yaw"], it["x"], it["y"], it["z"]))
        if it.get("tag"):
            lines.append(f'metadata/tag = "{it["tag"]}"')
        lines.append("")
    # lights: real OmniLights only on a curated subset (Compatibility renderer budget)
    LIT = ("MAIN_W", "MAIN_C", "MAIN_E", "GAS_STATION", "MAPLE_E", "OAK_N1", "OAK_N2", "OAK_S", "POLES",
           "QUARRY_RD", "MILL_RD")
    for k, it in enumerate(L.lights):
        lp = L.man[it["model"]].get("light")
        if not lp or it.get("tag") not in LIT:
            continue
        lx, lz = rot(it["yaw"], lp[0], lp[2])
        lines += [f'[node name="StreetLight_{k + 1:02d}" type="OmniLight3D" parent="Lights"]',
                  "transform = " + xform(0, it["x"] + lx, it["y"] + lp[1] - 0.3, it["z"] + lz),
                  "light_color = Color(1, 0.8, 0.55, 1)", "light_energy = 1.4", "omni_range = 11.0",
                  "omni_attenuation = 1.4", "distance_fade_enabled = true", "distance_fade_begin = 45.0",
                  "distance_fade_length = 15.0", f'metadata/lamp = "{it["name"]}"', ""]
    lines += [f'[node name="TOWN_BuildingZones" parent="BuildingZones" instance=ExtResource("{ids["TOWN_BuildingZones"]}")]', ""]
    for zn in L.zones:
        x0, z0, x1, z1 = zn["rect"]
        cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
        lines += [f'[node name="{zn["id"]}" type="Marker3D" parent="BuildingZones/Markers"]',
                  "transform = " + xform(0, cx, LOT_Y, cz),
                  f'metadata/zone_id = "{zn["id"]}"', f'metadata/zone_type = "{zn["type"]}"',
                  f'metadata/size = Vector2({fnum(x1 - x0)}, {fnum(z1 - z0)})',
                  f'metadata/front = Vector2({fnum(zn["front"][0])}, {fnum(zn["front"][1])})',
                  f'metadata/access = Vector3({fnum(zn["access"][0])}, {fnum(LOT_Y)}, {fnum(zn["access"][1])})',
                  f'metadata/target_pack = "{zn["pack"]}"', ""]
        lines += [f'[node name="Label" type="Label3D" parent="BuildingZones/Markers/{zn["id"]}"]',
                  "transform = " + xform(0, 0, max(zn["height"], 1.0) + 1.0, 0),
                  "billboard = 1", "pixel_size = 0.02", "font_size = 48", "outline_size = 8",
                  f'text = "{zn["id"]}"', ""]
    for (k, x, z) in L.journey:
        lines += [f'[node name="{k}" type="Marker3D" parent="Journey"]', "transform = " + xform(0, x, LOT_Y, z), ""]
    with open(path, "w", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    return len(used)


def xform_dir(pitch, yaw):
    # rotation: yaw about Y then pitch about local X
    cy, sy = math.cos(yaw), math.sin(yaw)
    cp, sp = math.cos(pitch), math.sin(pitch)
    Ryw = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]])
    Rxp = np.array([[1, 0, 0], [0, cp, -sp], [0, sp, cp]])
    R = Ryw @ Rxp
    vals = list(R.reshape(-1)) + [0, 30, 0]
    return "Transform3D(" + ", ".join(fnum(v) for v in vals) + ")"


# ---------------------------------------------------------------------------
def build(manifest, spec_fn):
    L = Layout(manifest)
    lots = residential_lots(None)
    frames = build_streets(L, lots)
    build_lots(L, frames, lots)
    L.lot_rects = [lot["rect"] for lot in lots]
    build_commercial(L, frames)
    # register the forecourt as a model in the manifest view
    os.makedirs(LAYOUT_DIR, exist_ok=True)
    os.makedirs(SCENE_DIR, exist_ok=True)
    paths = {m["name"]: RES_ROOT + "/" + m["glb"] for m in manifest}
    fc = gas_forecourt()
    p = os.path.join(LAYOUT_DIR, "TOWN_GasForecourt.glb")
    write_glb_import(p, GLBWriter(p).write(fc))
    paths["TOWN_GasForecourt"] = RES_ROOT + "/02_Town/Town_Layout/TOWN_GasForecourt.glb"
    L.man["TOWN_GasForecourt"] = {"name": "TOWN_GasForecourt", "footprint": (130, -40, 166, -6)}
    build_outskirts(L)
    build_props(L, frames, lots)
    ground, occ, nrects = terrain(L)
    n_trees = scatter(L, occ)
    for it in L.items:
        if "rect" not in it or it["rect"] is None:
            it["rect"] = L.world_rect(it)
    merge_scatter(L, spec_fn, paths)
    p = os.path.join(LAYOUT_DIR, "TOWN_Ground.glb")
    write_glb_import(p, GLBWriter(p).write(ground))
    paths["TOWN_Ground"] = RES_ROOT + "/02_Town/Town_Layout/TOWN_Ground.glb"
    zg = zones_glb(L)
    p = os.path.join(LAYOUT_DIR, "TOWN_BuildingZones.glb")
    write_glb_import(p, GLBWriter(p).write(zg))
    paths["TOWN_BuildingZones"] = RES_ROOT + "/02_Town/Town_Layout/TOWN_BuildingZones.glb"
    scene = os.path.join(SCENE_DIR, "Greyhaven_Town.tscn")
    n_res = write_tscn(L, scene, paths)
    data = dict(bounds=BOUNDS, core=CORE, nodes={k: list(v[:4]) + [list(v[4])] for k, v in NODES.items()},
                edges=EDGES, rural=RURAL, zones=L.zones, journey=L.journey, drive_links=L.drive_links,
                placements=[{k: v for k, v in it.items()} for it in L.items],
                merged_scatter=L.merged, scatter_items=[{k: it[k] for k in ("model", "x", "z", "yaw", "tag", "merged_into")}
                                                        for it in L.scatter_items],
                lights=[it["name"] for it in L.lights], terrain_rects=nrects,
                required_routes=[["PLAYER_HOME", z] for z in ("SUPERMARKET", "GAME_SHOP", "PHARMACY", "MUNICIPAL_ARCHIVE",
                                                              "GAS_STATION", "QUARRY_ENTRANCE", "ESCAPE_ROUTE_EAST",
                                                              "WOODS_TRAILHEAD", "FARMHOUSE", "MILL_HOUSE")])
    with open(os.path.join(LAYOUT_DIR, "greyhaven_layout.json"), "w", newline="\n") as f:
        json.dump(data, f, indent=1)
    counts = {}
    for it in L.items:
        counts[it["group"]] = counts.get(it["group"], 0) + 1
    return dict(scene="02_Town/Godot_Scenes/Greyhaven_Town.tscn", instances=len(L.items), groups=counts,
                scatter_merged=dict(items=len(L.scatter_items), chunks=len(L.merged),
                                    surfaces=sum(m["surfaces"] for m in L.merged)),
                zones=len(L.zones), trees_in_woods=n_trees, terrain_rects=nrects, omni_lights=len(L.lights),
                ext_resources=n_res)
