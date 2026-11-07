"""House plans. Coordinates are wall centrelines in the house-local frame:
x across the frontage (centred on the zone), z = depth from the zone front
line (street toward -z), y up from lot level. Ground floor = 0.6.

Room finishes reference Pack 01 ids ('Int_CarpetWorn'), Pack 02 ('Town_...')
or Pack 03 ('Res_WoodPanel').
"""
from arch import FLOOR_Y, CEIL_H, STOREY

TOP0 = FLOOR_Y + CEIL_H + 0.12          # eave line of a single-storey house (3.32)
F1 = FLOOR_Y + STOREY                    # first-floor level (3.6)
TOP1 = F1 + 2.5 + 0.12                   # eave line of a two-storey house (6.22)


def R(id, lvl, rect, type, floor, wall, **kw):
    return dict(id=id, lvl=lvl, rect=rect, type=type, floor=floor, wall=wall, **kw)


def D(a, b, at, w=0.9, h=2.1, kind="door", into=None, **kw):
    return dict(a=a, b=b, at=at, w=w, h=h, kind=kind, into=into or b, **kw)


def DX(room, side, at, w=1.0, h=2.15, kind="door", style="front", into=None, **kw):
    return dict(room=room, side=side, at=at, w=w, h=h, kind=kind, style=style, into=into or room, **kw)


def Wn(room, side, at, w=1.1, h=1.3, sill=0.85, style="double_hung", **kw):
    return dict(room=room, side=side, at=at, w=w, h=h, sill=sill, style=style, kind="window", **kw)


GARAGE = dict(floor="Int_BasementConcrete", wall="Com_StorageConcrete", y=0.02, h=2.9, ceil="Int_DrywallLight")

# ----------------------------------------------------------------------------
# 1. RANCH - single storey, low hip roof, front-gabled attached garage
# ----------------------------------------------------------------------------
RANCH = dict(
    name="RES_House_Ranch", title="Single-storey ranch house", width=11.0, levels={0: (FLOOR_Y, CEIL_H)},
    garage_x=-3.0,
    rooms=[
        R("GAR", 0, (-5.0, 2.0, -1.0, 8.0), "garage", **GARAGE),
        R("LIV", 0, (-1.0, 2.4, 3.2, 6.2), "living", "Int_CarpetWorn", "Int_WallpaperFaded"),
        R("BED2", 0, (3.2, 2.4, 6.0, 6.2), "bedroom", "Int_CarpetWorn", "Int_DrywallLight"),
        R("KIT", 0, (-1.0, 6.2, 2.2, 11.8), "kitchen", "Int_Linoleum", "Int_DrywallLight"),
        R("HALL", 0, (2.2, 6.2, 3.4, 9.4), "hall", "Int_FloorboardsOld", "Int_DrywallLight"),
        R("BATH", 0, (3.4, 6.2, 6.0, 8.4), "bathroom", "Int_Linoleum", "Int_TilesBathroom"),
        R("BED1", 0, (3.4, 8.4, 6.0, 11.8), "bedroom", "Int_FloorboardsOld", "Int_WallpaperPatterned"),
        R("LAU", 0, (2.2, 9.4, 3.4, 11.8), "laundry", "Int_Linoleum", "Int_DrywallLight"),
    ],
    doors=[
        DX("LIV", "F", 0.3, name="Front"),
        DX("GAR", "F", -3.0, w=2.8, h=2.2, kind="garage", name="Garage"),
        DX("LAU", "B", 2.8, w=0.9, h=2.1, style="back", name="Back"),
        D("LIV", "KIT", 0.4, w=1.6, h=2.2, kind="arch", name="LivKit"),
        D("LIV", "HALL", 2.7, w=0.9, h=2.2, kind="arch", name="LivHall"),
        D("LIV", "BED2", 5.2, into="BED2", name="Bed2"),
        D("HALL", "BATH", 7.3, w=0.8, into="BATH", name="Bath"),
        D("HALL", "BED1", 8.9, into="BED1", name="Bed1"),
        D("HALL", "LAU", 2.8, w=0.85, into="LAU", name="Laundry"),
        D("GAR", "KIT", 7.3, into="GAR", name="GarageKitchen"),
    ],
    windows=[
        Wn("LIV", "F", 2.3, w=1.4, h=1.4, sill=0.7, style="picture"), Wn("BED2", "F", 4.6, w=1.2), Wn("BED2", "R", 4.3, w=1.0),
        Wn("KIT", "B", 0.6, w=1.2, h=1.0, sill=1.05), Wn("BATH", "R", 7.3, w=0.6, h=0.6, sill=1.4),
        Wn("BED1", "R", 10.1, w=1.0), Wn("BED1", "B", 4.7, w=1.2), Wn("GAR", "L", 5.0, w=0.8, h=0.6, sill=1.4),
    ],
    porches=[
        dict(rect=(-0.8, 1.2, 2.0, 2.4), deck_y=0.58, steps=("z0", 0.3, 1.2), rails=("x0", "x1", "z0"),
             columns=[(-0.7, 1.3), (1.9, 1.3)], roof=("shed", (-0.8, 1.2, 2.0, 2.4), 2.95, 3.2, "z1", {})),
        dict(rect=(2.0, 11.8, 3.6, 12.8), deck_y=0.58, steps=("x0", 12.3, 0.9), rails=("x1", "z1"), columns=[], skirt=True),
    ],
    roofs=[
        ("hip", (-1.1, 2.3, 6.1, 11.9), TOP0, 24, {}),
        ("gable", (-5.1, 1.9, -0.9, 8.1), FLOOR_Y - 0.58 + 2.9 + 0.12 + 0.0, 30, "z", {}),
    ],
    ext=dict(siding="Arch_SidingWhite", trim="Arch_TrimPainted", roof="Arch_RoofShinglesDarkGray", door="Town_PaintRed",
             foundation="Arch_ConcreteFoundation"),
    colorways={"B": dict(siding="Arch_SidingBlue", door="Town_PaintYellow", roof="Arch_RoofShinglesBrown"),
               "C": dict(siding="Arch_SidingGreen", door="Town_PaintWhite")},
)



BASE = "Int_BasementConcrete"

# ----------------------------------------------------------------------------
# 2. TWO-STOREY family house - side gable, full porch, basement, 3 bedrooms
# ----------------------------------------------------------------------------
TWO_STOREY = dict(
    name="RES_House_TwoStorey", title="Two-storey suburban family house", width=9.0,
    levels={0: (FLOOR_Y, CEIL_H), 1: (F1, 2.5)}, garage_x=None,
    rooms=[
        R("FOY", 0, (-1.2, 3.4, 1.2, 9.4), "hall", "Int_FloorboardsOld", "Int_WallpaperFaded"),
        R("LIV", 0, (-4.5, 3.4, -1.2, 8.4), "living", "Int_CarpetWorn", "Int_WallpaperPatterned"),
        R("DIN", 0, (-4.5, 8.4, -1.2, 11.4), "dining", "Int_FloorboardsOld", "Int_WallpaperFaded"),
        R("DEN", 0, (1.2, 3.4, 4.5, 6.9), "study", "Int_CarpetWorn", "Res_WoodPanel"),
        R("KIT", 0, (1.2, 6.9, 4.5, 11.4), "kitchen", "Int_TilesKitchen", "Int_DrywallLight"),
        R("BHAL", 0, (-1.2, 9.4, 1.2, 11.4), "hall", "Int_Linoleum", "Int_DrywallLight"),
        R("UHAL", 1, (-1.2, 3.4, 1.2, 11.4), "hall", "Int_CarpetWorn", "Int_DrywallLight"),
        R("BED1", 1, (-4.5, 3.4, -1.2, 7.6), "bedroom", "Int_CarpetWorn", "Int_WallpaperFaded"),
        R("BED2", 1, (-4.5, 7.6, -1.2, 11.4), "bedroom", "Int_FloorboardsOld", "Int_WallpaperPatterned"),
        R("BED3", 1, (1.2, 3.4, 4.5, 7.4), "bedroom", "Int_CarpetWorn", "Int_DrywallLight"),
        R("BATH2", 1, (1.2, 7.4, 4.5, 11.4), "bathroom", "Int_Linoleum", "Int_TilesBathroom"),
    ],
    stairs=[
        # one flight, widened to 1.12 m; the basement flight that dropped from the foyer to a dead end is gone
        dict(rect=(0.0, 4.6, 1.12, 9.2), **{"from": 0, "to": 1}, dir="+z", void_len=3.6, open=("l",)),
    ],
    doors=[
        DX("FOY", "F", -0.3, name="Front"), DX("BHAL", "B", 0.0, w=0.9, h=2.1, style="back", name="Back"),
        D("FOY", "LIV", 5.0, w=1.4, h=2.2, kind="arch", name="FoyLiv"), D("LIV", "DIN", -2.85, w=1.6, h=2.2, kind="arch", name="LivDin"),
        D("FOY", "BHAL", 0.0, w=2.2, h=2.2, kind="arch", name="FoyBack"), D("DIN", "BHAL", 10.4, into="DIN", name="DinBack"),
        D("BHAL", "KIT", 10.4, into="KIT", name="Kitchen"), D("DEN", "KIT", 2.85, into="DEN", name="Den"),
        D("UHAL", "BED1", 4.3, into="BED1", name="Bed1"), D("UHAL", "BED2", 10.3, into="BED2", name="Bed2"),
        D("UHAL", "BED3", 4.3, w=0.8, into="BED3", name="Bed3"), D("UHAL", "BATH2", 10.3, w=0.8, into="BATH2", name="Bath"),
    ],
    windows=[
        Wn("LIV", "F", -2.85, w=1.2), Wn("DEN", "F", 2.85, w=1.2), Wn("BED1", "F", -2.85), Wn("BED3", "F", 2.85),
        Wn("UHAL", "F", 0.0, w=0.7, h=1.0, sill=1.0), Wn("LIV", "L", 6.0), Wn("DIN", "L", 10.0), Wn("DIN", "B", -2.85),
        Wn("KIT", "R", 9.0), Wn("KIT", "B", 2.85, w=1.0, h=1.0, sill=1.05), Wn("BED1", "L", 5.5), Wn("BED2", "L", 9.5),
        Wn("BED2", "B", -2.85), Wn("BED3", "R", 5.4), Wn("BATH2", "R", 9.4, w=0.6, h=0.7, sill=1.3), Wn("BATH2", "B", 3.0, w=0.8),
    ],
    porches=[
        dict(rect=(-4.5, 2.0, 4.5, 3.4), deck_y=0.58, risers=3, steps=("z0", -3.0, 1.2), rails=("x0", "x1", "z0"),
             columns=[(-4.4, 2.1), (-1.6, 2.1), (1.6, 2.1), (4.4, 2.1)], col_h=2.6,
             roof=("shed", (-4.5, 2.0, 4.5, 3.4), 3.2, 3.45, "z1", {})),
        dict(rect=(-0.8, 11.4, 0.8, 12.4), deck_y=0.58, steps=("x1", 11.9, 0.9), rails=("x0", "z1"), columns=[]),
    ],
    roofs=[("gable", (-4.6, 3.3, 4.6, 11.5), TOP1, 38, "x", {})],
    chimneys=[(-4.85, 7.0, 0.5, 1.0, 8.9)],
    ext=dict(siding="Arch_SidingBlue", trim="Arch_TrimPainted", roof="Arch_RoofShinglesDarkGray", door="Town_PaintBlack",
             foundation="Arch_ConcreteFoundation", shutters=True),
    colorways={"B": dict(siding="Arch_SidingWhite", door="Town_PaintGreen", roof="Arch_RoofShinglesBrown")},
)

# ----------------------------------------------------------------------------
# 3. FARMHOUSE - older wooden, steep gable, wraparound porch, rusty tin roof, attic
# ----------------------------------------------------------------------------
FARMHOUSE = dict(
    name="RES_House_Farmhouse", title="Older wooden farmhouse", width=12.4,
    levels={0: (FLOOR_Y, CEIL_H), 1: (F1, 2.4), 2: (6.15, 2.4)}, garage_x=None,
    rooms=[
        R("PAR", 0, (-5.0, 3.0, -1.2, 7.0), "living", "Int_FloorboardsOld", "Int_WallpaperFaded"),
        R("DIN", 0, (-5.0, 7.0, -1.2, 10.0), "dining", "Int_FloorboardsOld", "Int_WallpaperPatterned"),
        R("HAL", 0, (-1.2, 3.0, 1.2, 10.0), "hall", "Int_FloorboardsOld", "Int_DrywallLight"),
        R("STU", 0, (1.2, 3.0, 5.0, 6.5), "study", "Int_CarpetWorn", "Res_WoodPanel"),
        R("KIT", 0, (1.2, 6.5, 5.0, 10.0), "kitchen", "Int_Linoleum", "Int_DrywallLight"),
        R("MUD", 0, (1.2, 10.0, 3.2, 13.2), "laundry", "Int_Linoleum", "Res_WoodPanel"),
        R("BATH", 0, (3.2, 10.0, 5.0, 13.2), "bathroom", "Int_Linoleum", "Int_TilesBathroom"),
        R("UHAL", 1, (-1.2, 3.0, 1.2, 10.0), "hall", "Int_FloorboardsOld", "Int_DrywallLight"),
        R("BED1", 1, (-5.0, 3.0, -1.2, 7.0), "bedroom", "Int_FloorboardsOld", "Int_WallpaperFaded"),
        R("BED2", 1, (-5.0, 7.0, -1.2, 10.0), "bedroom", "Int_CarpetWorn", "Int_WallpaperPatterned"),
        R("BATH2", 1, (1.2, 3.0, 5.0, 5.0), "bathroom", "Int_Linoleum", "Int_TilesBathroom"),
        R("STOR", 1, (1.2, 5.0, 5.0, 10.0), "storage", "Int_FloorboardsOld", "Res_WoodPanel"),
        R("ATTIC", 2, (-5.0, 3.0, 5.0, 10.0), "attic", "Res_Insulation", "Arch_WoodPlanksAged", walk=(-4.6, 4.75, 4.6, 8.25)),
    ],
    stairs=[
        dict(rect=(0.22, 4.3, 1.12, 8.9), **{"from": 0, "to": 1}, dir="+z", void_len=3.4, open=("l",)),
        dict(rect=(1.5, 5.1, 2.45, 8.0), **{"from": 1, "to": 2}, dir="-z", tread=0.24, risers=12, void_len=2.9, open=("r",), arrive=0.1),
    ],
    doors=[
        DX("HAL", "F", -0.4, name="Front"), DX("MUD", "B", 2.2, w=0.9, h=2.1, style="back", name="Back"),
        D("HAL", "PAR", 5.0, w=1.4, h=2.2, kind="arch", name="Parlor"), D("HAL", "DIN", 8.6, into="DIN", name="Dining"),
        D("HAL", "KIT", 9.45, into="KIT", name="Kitchen"), D("KIT", "STU", 3.0, into="STU", name="Study"),
        D("KIT", "MUD", 2.2, w=1.0, into="MUD", name="Mud"), D("MUD", "BATH", 11.6, w=0.8, into="BATH", name="Bath"),
        D("UHAL", "BED1", 4.0, into="BED1", name="Bed1"), D("UHAL", "BED2", 9.2, into="BED2", name="Bed2"),
        D("UHAL", "BATH2", 3.9, w=0.8, into="BATH2", name="Bath2"), D("UHAL", "STOR", 9.5, w=0.8, into="STOR", name="Storage"),
    ],
    windows=[
        Wn("PAR", "F", -3.1, w=1.1, h=1.6, sill=0.6), Wn("STU", "F", 3.1, w=1.1, h=1.6, sill=0.6), Wn("PAR", "L", 4.0, h=1.6, sill=0.6),
        Wn("DIN", "L", 8.5, h=1.6, sill=0.6), Wn("KIT", "R", 8.2), Wn("STU", "R", 4.8), Wn("BATH", "R", 11.6, w=0.6, h=0.7, sill=1.3),
        Wn("MUD", "B", 2.6, w=0.7, h=0.9, sill=1.1), Wn("BED1", "F", -3.1, h=1.4), Wn("BATH2", "F", 3.1, w=0.7, h=0.9, sill=1.2),
        Wn("UHAL", "F", 0.0, w=0.8, h=1.3), Wn("BED1", "L", 5.0), Wn("BED2", "L", 8.5), Wn("STOR", "R", 7.5, w=0.9),
        Wn("DIN", "B", -3.1), Wn("BED2", "B", -3.1),
    ],
    porches=[
        dict(rect=(-5.0, 1.4, 5.0, 3.0), deck_y=0.58, risers=3, steps=("z0", 0.0, 1.6), rails=("x0", "z0"),
             columns=[(-4.9, 1.5), (-2.0, 1.5), (2.0, 1.5), (4.9, 1.5)], col_h=2.5,
             roof=("shed", (-5.0, 1.4, 5.0, 3.0), 3.05, 3.35, "z1", {})),
        dict(rect=(5.0, 1.4, 6.4, 6.5), deck_y=0.58, rails=("x1",), columns=[(6.3, 3.5), (6.3, 6.4)], col_h=2.5, skirt=True,
             roof=("shed", (5.0, 1.4, 6.4, 6.5), 3.05, 3.35, "x0", {})),
        dict(rect=(1.4, 13.2, 3.0, 14.0), deck_y=0.58, risers=3, steps=("x0", 13.6, 0.8), rails=("x1", "z1"), columns=[]),
    ],
    roofs=[("gable", (-5.1, 2.9, 5.1, 10.1), 6.12, 50, "x", dict(attic=True)),
           ("gable", (1.1, 9.9, 5.1, 13.3), TOP0, 40, "z", {})],
    chimneys=[(-5.4, 5.0, 0.6, 0.9, 10.4)],
    ext=dict(siding="Arch_SidingWhite", trim="Arch_TrimPainted", roof="Furn_MetalRusted", door="Town_PaintRed",
             foundation="Arch_BrickWeatheredBrown", chimney="Arch_BrickWeatheredBrown"),
    colorways={},
)

# ----------------------------------------------------------------------------
# 4. BRICK BUNGALOW - front gable, gabled porch on tapered brick piers
# ----------------------------------------------------------------------------
BUNGALOW = dict(
    name="RES_House_Bungalow", title="Modest brick bungalow", width=9.0, levels={0: (FLOOR_Y, CEIL_H)}, garage_x=None,
    rooms=[
        R("LIV", 0, (-4.5, 3.2, 0.6, 7.0), "living", "Int_FloorboardsOld", "Int_WallpaperPatterned"),
        R("BED1", 0, (0.6, 3.2, 4.5, 6.6), "bedroom", "Int_CarpetWorn", "Int_WallpaperFaded"),
        R("DIN", 0, (-4.5, 7.0, -1.4, 11.4), "dining", "Int_FloorboardsOld", "Res_WoodPanel"),
        R("KIT", 0, (-1.4, 7.0, 0.6, 11.4), "kitchen", "Int_TilesKitchen", "Int_DrywallLight"),
        R("HALL", 0, (0.6, 6.6, 1.8, 11.4), "hall", "Int_FloorboardsOld", "Int_DrywallLight"),
        R("BATH", 0, (1.8, 6.6, 4.5, 8.8), "bathroom", "Int_TilesKitchen", "Int_TilesBathroom"),
        R("BED2", 0, (1.8, 8.8, 4.5, 11.4), "bedroom", "Int_CarpetWorn", "Int_DrywallLight"),
    ],
    doors=[
        DX("LIV", "F", -2.6, name="Front"), DX("KIT", "B", -0.4, w=0.9, h=2.1, style="back", name="Back"),
        D("LIV", "DIN", -3.0, w=1.6, h=2.2, kind="arch", name="LivDin"), D("DIN", "KIT", 9.2, w=1.2, h=2.2, kind="arch", name="DinKit"),
        D("LIV", "BED1", 4.6, into="BED1", name="Bed1"), D("KIT", "HALL", 10.6, w=0.85, into="HALL", name="KitHall"),
        D("HALL", "BED1", 1.2, w=0.8, into="BED1", name="Bed1Hall"), D("HALL", "BATH", 7.7, w=0.8, into="BATH", name="Bath"),
        D("HALL", "BED2", 10.0, into="BED2", name="Bed2"),
    ],
    windows=[
        Wn("LIV", "F", -0.6, w=1.5, h=1.4, sill=0.7), Wn("BED1", "F", 2.55, w=1.3), Wn("LIV", "L", 5.0), Wn("DIN", "L", 9.2, w=1.4),
        Wn("BED1", "R", 4.9), Wn("BATH", "R", 7.7, w=0.6, h=0.7, sill=1.3), Wn("BED2", "R", 10.1), Wn("KIT", "B", 0.25, w=0.6, h=0.9, sill=1.1),
        Wn("DIN", "B", -3.0), Wn("BED2", "B", 3.15, w=0.9),
    ],
    porches=[
        dict(rect=(-4.5, 1.4, 1.6, 3.2), deck_y=0.58, risers=3, steps=("z0", -2.6, 1.3), rails=("x0", "x1", "z0"),
             columns=[(-4.3, 1.6), (-0.5, 1.6), (1.4, 1.6)], col_h=2.4, col_mat="Arch_BrickRed", deck="Int_FloorboardsOld",
             roof=("gable", (-4.6, 1.3, 1.7, 3.2), 3.0, 30, "z", dict(gutters=False))),
        dict(rect=(-1.4, 11.4, 0.6, 12.3), deck_y=0.58, steps=("x0", 11.85, 0.85), rails=("x1", "z1"), columns=[]),
    ],
    roofs=[("gable", (-4.6, 3.1, 4.6, 11.5), TOP0, 30, "z", {})],
    chimneys=[(-4.85, 5.2, 0.6, 1.0, 4.9)],
    ext=dict(siding="Arch_BrickRed", gable="Arch_RoofShinglesBrown", trim="Arch_TrimPainted", roof="Arch_RoofShinglesBrown",
             door="Town_PaintGreen", foundation="Arch_BrickWeatheredBrown", chimney="Arch_BrickRed"),
    colorways={"B": dict(siding="Arch_BrickWeatheredBrown", gable="Arch_SidingWhite", roof="Arch_RoofShinglesDarkGray",
                         door="Town_PaintNavy", chimney="Arch_BrickWeatheredBrown")},
)

# ----------------------------------------------------------------------------
# 5. ABANDONED - weathered two-storey, boarded windows, rot and damp (no supernatural)
# ----------------------------------------------------------------------------
ABANDONED = dict(
    name="RES_House_Abandoned", title="Weathered abandoned house", width=7.0,
    levels={0: (FLOOR_Y, CEIL_H), 1: (F1, 2.5)}, garage_x=None,
    rooms=[
        R("LIV", 0, (-3.5, 3.4, 0.6, 8.6), "living", "Hor_WoodDarkened", "Int_PlasterDamaged"),
        R("ROOM", 0, (0.6, 3.4, 3.5, 8.6), "dining", "Int_FloorboardsOld", "Int_WallpaperFaded"),
        R("KIT", 0, (-3.5, 8.6, 3.5, 11.4), "kitchen", "Int_Linoleum", "Hor_DampWall"),
        R("UHAL", 1, (-3.5, 3.4, -1.3, 11.4), "hall", "Hor_WoodDarkened", "Int_PlasterDamaged"),
        R("BED1", 1, (-1.3, 3.4, 3.5, 7.6), "bedroom", "Int_FloorboardsOld", "Int_WallpaperPatterned"),
        R("BED2", 1, (-1.3, 7.6, 3.5, 9.8), "bedroom", "Hor_WoodDarkened", "Int_PlasterDamaged"),
        R("BATH", 1, (-1.3, 9.8, 3.5, 11.4), "bathroom", "Int_Linoleum", "Hor_DampWall"),
    ],
    stairs=[dict(rect=(-3.45, 4.45, -2.5, 8.55), **{"from": 0, "to": 1}, dir="+z", tread=0.24, open=("r",))],
    doors=[
        DX("LIV", "F", -1.8, name="Front", paint="Hor_WoodDarkened"), DX("KIT", "B", 1.0, w=0.9, h=2.1, style="back", name="Back"),
        D("LIV", "ROOM", 6.0, w=1.4, h=2.2, kind="arch", name="LivRoom"), D("LIV", "KIT", -1.0, into="KIT", name="Kitchen"),
        D("ROOM", "KIT", 2.0, w=1.2, h=2.2, kind="arch", name="RoomKit"),
        D("UHAL", "BED1", 4.4, into="BED1", name="Bed1"), D("UHAL", "BED2", 8.9, into="BED2", name="Bed2"),
        D("UHAL", "BATH", 10.6, w=0.8, into="BATH", name="Bath"),
    ],
    windows=[
        Wn("LIV", "F", 0.0, w=1.0, style="boarded"), Wn("ROOM", "F", 2.0, w=1.0, style="boarded"), Wn("LIV", "L", 6.0, style="boarded"),
        Wn("ROOM", "R", 6.0, style="boarded"), Wn("KIT", "B", -2.0, w=0.9, h=1.0, sill=1.05, style="boarded"),
        Wn("BED1", "F", 1.1, w=1.0, style="picture"), Wn("UHAL", "F", -2.4, w=0.7), Wn("BED1", "R", 5.5, style="boarded"),
        Wn("BED2", "R", 8.7, w=0.9), Wn("BATH", "B", 1.0, w=0.6, h=0.7, sill=1.3), Wn("UHAL", "L", 8.0, w=0.8, style="boarded"),
    ],
    porches=[
        dict(rect=(-3.5, 1.8, 3.5, 3.4), deck_y=0.58, risers=3, steps=("z0", -1.8, 1.2), rails=("x0", "x1"),
             columns=[(-3.4, 1.9), (3.4, 1.9)], col_h=2.55, deck="Hor_WoodDarkened",
             roof=("shed", (-3.5, 1.8, 3.5, 3.4), 3.1, 3.4, "z1", {})),
        dict(rect=(0.2, 11.4, 1.8, 12.3), deck_y=0.58, steps=("x1", 11.85, 0.85), rails=("x0",), columns=[], deck="Hor_WoodDarkened"),
    ],
    roofs=[("gable", (-3.6, 3.3, 3.6, 11.5), TOP1, 40, "x", {})],
    chimneys=[(1.6, 9.8, 0.5, 0.5, 9.6)],
    ext=dict(siding="Arch_WoodPlanksAged", trim="Arch_WoodPlanksAged", roof="Arch_RoofTilesWeathered", door="Hor_WoodDarkened",
             foundation="Arch_BrickWeatheredBrown", chimney="Arch_BrickWeatheredBrown"),
    colorways={},
)

# ----------------------------------------------------------------------------
# 6. SPLIT-LEVEL - single-storey living wing + two-storey garage/den/bedroom wing
# ----------------------------------------------------------------------------
LOW = dict(y=0.02, h=2.58)
SPLIT_LEVEL = dict(
    name="RES_House_SplitLevel", title="Split-level suburban house", width=15.2,
    levels={0: (FLOOR_Y, CEIL_H), 1: (2.72, 2.45)}, garage_x=5.0,
    rooms=[
        R("LIV", 0, (-7.5, 3.0, -1.0, 7.2), "living", "Int_CarpetWorn", "Int_WallpaperFaded", siding="Arch_BrickWeatheredBrown"),
        R("KIT", 0, (-7.5, 7.2, -1.0, 11.2), "kitchen", "Int_Linoleum", "Int_DrywallLight", siding="Arch_BrickWeatheredBrown"),
        R("DEN", 0, (-1.0, 2.6, 3.0, 10.0), "family", "Int_CarpetWorn", "Res_WoodPanel", siding="Arch_BrickWeatheredBrown", **LOW),
        R("GAR", 0, (3.0, 2.6, 7.0, 8.0), "garage", floor="Int_BasementConcrete", wall="Com_StorageConcrete", y=0.02, h=2.58,
          siding="Arch_BrickWeatheredBrown"),
        R("LAU", 0, (3.0, 8.0, 7.0, 10.0), "laundry", "Int_Linoleum", "Int_DrywallLight", siding="Arch_BrickWeatheredBrown", **LOW),
        R("BED1", 1, (-1.0, 2.6, 2.0, 6.6), "bedroom", "Int_CarpetWorn", "Int_WallpaperPatterned"),
        R("BED3", 1, (-1.0, 6.6, 2.0, 10.0), "bedroom", "Int_CarpetWorn", "Int_DrywallLight"),
        R("UHAL", 1, (2.0, 2.6, 4.0, 10.0), "hall", "Int_CarpetWorn", "Int_DrywallLight"),
        R("BED2", 1, (4.0, 2.6, 7.0, 6.6), "bedroom", "Int_CarpetWorn", "Int_DrywallLight"),
        R("BATH", 1, (4.0, 6.6, 7.0, 10.0), "bathroom", "Int_Linoleum", "Int_TilesBathroom"),
    ],
    stairs=[dict(rect=(2.0, 4.0, 2.95, 7.8), **{"from": 0, "to": 1}, y_from=0.02, y_to=2.72, dir="+z", tread=0.27,
                 void_len=2.85, open=("l",))],
    doors=[
        DX("LIV", "F", -4.0, name="Front"), DX("GAR", "F", 5.0, w=2.8, h=2.2, kind="garage", name="Garage"),
        DX("KIT", "B", -5.0, w=0.9, h=2.1, style="back", name="Back"), DX("LAU", "B", 5.0, w=0.9, h=2.1, style="back", name="Side"),
        D("LIV", "KIT", -4.2, w=1.6, h=2.2, kind="arch", name="LivKit"), D("LIV", "DEN", 4.9, into="DEN", name="Den"),
        D("DEN", "GAR", 3.1, w=0.8, into="GAR", name="DenGarage"), D("DEN", "LAU", 8.45, w=0.8, into="LAU", name="Laundry"),
        D("UHAL", "BED1", 3.4, w=0.8, into="BED1", name="Bed1"), D("UHAL", "BED3", 8.7, into="BED3", name="Bed3"),
        D("UHAL", "BED2", 4.5, into="BED2", name="Bed2"), D("UHAL", "BATH", 8.5, w=0.8, into="BATH", name="Bath"),
    ],
    windows=[
        Wn("LIV", "F", -6.0, w=1.8, h=1.3, sill=0.7, style="picture"), Wn("LIV", "L", 5.0), Wn("KIT", "L", 9.0), Wn("KIT", "B", -3.0, w=1.2, h=1.0, sill=1.05),
        Wn("DEN", "F", 1.0, w=1.4, h=0.9, sill=1.2), Wn("BED1", "F", 1.0, w=1.3), Wn("BED2", "F", 5.0, w=1.3), Wn("BED2", "R", 4.6),
        Wn("BATH", "R", 8.3, w=0.6, h=0.7, sill=1.3), Wn("BED3", "B", 0.5, w=1.0), Wn("GAR", "R", 5.3, w=0.8, h=0.6, sill=1.5),
    ],
    porches=[
        dict(rect=(-5.4, 1.8, -2.6, 3.0), deck_y=0.58, risers=3, steps=("z0", -4.0, 1.2), rails=("x0", "x1"), columns=[(-5.3, 1.9), (-2.7, 1.9)],
             roof=("shed", (-5.4, 1.8, -2.6, 3.0), 2.95, 3.2, "z1", {})),
        dict(rect=(-5.8, 11.2, -4.2, 12.1), deck_y=0.58, steps=("x1", 11.65, 0.85), rails=("x0", "z1"), columns=[]),
    ],
    roofs=[("hip", (-7.6, 2.9, -0.9, 11.3), TOP0, 22, {}), ("gable", (-1.1, 2.5, 7.1, 10.1), 2.72 + 2.45 + 0.12, 25, "x", {})],
    ext=dict(siding="Arch_SidingBlue", trim="Arch_TrimPainted", roof="Arch_RoofShinglesDarkGray", door="Town_PaintYellow",
             foundation="Arch_ConcreteFoundation"),
    colorways={"B": dict(siding="Arch_SidingGreen", roof="Arch_RoofShinglesBrown", door="Town_PaintRed")},
)

# ----------------------------------------------------------------------------
# 7. COTTAGE - compact storybook cottage, steep cross gables, projecting bay
# ----------------------------------------------------------------------------
COTTAGE = dict(
    name="RES_House_Cottage", title="Compact cottage", width=7.5, levels={0: (FLOOR_Y, CEIL_H)}, garage_x=None,
    rooms=[
        R("LIV", 0, (-3.75, 3.4, 0.8, 7.0), "living", "Int_FloorboardsOld", "Int_WallpaperFaded"),
        R("BED", 0, (0.8, 2.4, 3.75, 7.0), "bedroom", "Int_CarpetWorn", "Int_WallpaperPatterned"),
        R("KIT", 0, (-3.75, 7.0, 0.0, 11.4), "kitchen", "Int_TilesKitchen", "Int_DrywallLight"),
        R("BATH", 0, (0.0, 7.0, 1.8, 9.4), "bathroom", "Int_Linoleum", "Int_TilesBathroom"),
        R("HALL", 0, (0.0, 9.4, 1.8, 11.4), "hall", "Int_Linoleum", "Int_DrywallLight"),
        R("BED2", 0, (1.8, 7.0, 3.75, 11.4), "bedroom", "Int_CarpetWorn", "Int_DrywallLight"),
    ],
    doors=[
        DX("LIV", "F", -1.6, name="Front"), DX("HALL", "B", 0.9, w=0.9, h=2.1, style="back", name="Back"),
        D("LIV", "BED", 5.2, into="BED", name="Bed"), D("LIV", "KIT", -2.0, w=1.4, h=2.2, kind="arch", name="LivKit"),
        D("KIT", "BATH", 8.5, w=0.8, into="KIT", name="Bath"), D("KIT", "HALL", 10.4, w=0.85, into="HALL", name="KitHall"),
        D("HALL", "BED2", 10.4, w=0.85, into="BED2", name="Bed2"),
    ],
    windows=[
        Wn("LIV", "F", -3.0, w=0.9, h=1.3), Wn("BED", "F", 2.27, w=1.2, h=1.4, sill=0.7), Wn("LIV", "L", 5.2, w=0.9),
        Wn("KIT", "L", 9.2, w=0.9), Wn("KIT", "B", -1.8, w=0.9, h=1.0, sill=1.05), Wn("BED", "R", 5.0, w=0.9),
        Wn("BED2", "R", 9.2, w=0.9), Wn("BED2", "B", 2.8, w=0.8),
    ],
    porches=[
        dict(rect=(-2.6, 2.2, -0.6, 3.4), deck_y=0.58, risers=3, steps=("z0", -1.6, 1.2), rails=("x0", "x1"), columns=[(-2.5, 2.3), (-0.7, 2.3)],
             col_h=2.3, roof=("gable", (-2.7, 2.1, -0.5, 3.4), 2.9, 40, "z", dict(gutters=False))),
        dict(rect=(0.1, 11.4, 1.7, 12.3), deck_y=0.58, steps=("x0", 11.85, 0.85), rails=("x1", "z1"), columns=[]),
    ],
    roofs=[("gable", (-3.85, 3.3, 3.85, 11.5), TOP0, 45, "x", {}), ("gable", (0.7, 2.3, 3.85, 7.1), TOP0, 45, "z", {})],
    chimneys=[(-1.2, 9.4, 0.5, 0.5, 6.6, 3.2)],
    ext=dict(siding="Arch_SidingGreen", trim="Arch_TrimPainted", roof="Arch_RoofShinglesBrown", door="Town_PaintYellow",
             foundation="Arch_ConcreteFoundation"),
    colorways={"B": dict(siding="Arch_SidingWhite", roof="Arch_RoofTilesWeathered", door="Town_PaintRed")},
)

# ----------------------------------------------------------------------------
# 8. MILL-WORKER house - narrow, deep, tall front gable
# ----------------------------------------------------------------------------
MILL = dict(
    name="RES_House_MillWorker", title="Older mill-worker house", width=6.0,
    levels={0: (FLOOR_Y, CEIL_H), 1: (F1, 2.4)}, garage_x=None,
    rooms=[
        R("PAR", 0, (-3.0, 3.2, 3.0, 8.4), "living", "Int_FloorboardsOld", "Int_WallpaperFaded"),
        R("KIT", 0, (-3.0, 8.4, 1.4, 11.6), "kitchen", "Int_Linoleum", "Int_DrywallLight"),
        R("BATH", 0, (1.4, 8.4, 3.0, 11.6), "bathroom", "Int_Linoleum", "Int_TilesBathroom"),
        R("UHAL", 1, (-3.0, 3.2, -0.8, 11.6), "hall", "Int_FloorboardsOld", "Int_DrywallLight"),
        R("BED1", 1, (-0.8, 3.2, 3.0, 7.6), "bedroom", "Int_CarpetWorn", "Int_WallpaperPatterned"),
        R("BED2", 1, (-0.8, 7.6, 3.0, 11.6), "bedroom", "Int_FloorboardsOld", "Int_WallpaperFaded"),
    ],
    stairs=[dict(rect=(-2.95, 4.3, -2.0, 8.35), **{"from": 0, "to": 1}, dir="+z", tread=0.24, open=("r",))],
    doors=[
        DX("PAR", "F", 0.6, name="Front"), DX("KIT", "B", -1.8, w=0.9, h=2.1, style="back", name="Back"),
        D("PAR", "KIT", -0.8, into="KIT", name="Kitchen"), D("KIT", "BATH", 10.0, w=0.8, into="BATH", name="Bath"),
        D("UHAL", "BED1", 4.2, into="BED1", name="Bed1"), D("UHAL", "BED2", 9.4, into="BED2", name="Bed2"),
    ],
    windows=[
        Wn("PAR", "F", 2.0, w=0.9, h=1.6, sill=0.6), Wn("PAR", "F", -1.4, w=0.8, h=1.6, sill=0.6), Wn("PAR", "R", 6.0, w=0.9),
        Wn("KIT", "L", 10.0, w=0.9), Wn("BATH", "R", 10.0, w=0.5, h=0.7, sill=1.3), Wn("BED1", "F", 1.0, w=1.0, h=1.4),
        Wn("BED1", "R", 5.4, w=0.9), Wn("BED2", "R", 9.6, w=0.9), Wn("UHAL", "L", 6.0, w=0.7), Wn("BED2", "B", 1.0, w=0.9),
    ],
    porches=[
        dict(rect=(-3.0, 1.6, 3.0, 3.2), deck_y=0.58, risers=3, steps=("z0", 0.6, 1.2), rails=("x0", "x1", "z0"),
             columns=[(-2.9, 1.7), (2.9, 1.7)], roof=("shed", (-3.0, 1.6, 3.0, 3.2), 3.1, 3.4, "z1", {})),
        dict(rect=(-2.6, 11.6, -1.0, 12.5), deck_y=0.58, steps=("x1", 12.05, 0.85), rails=("x0", "z1"), columns=[]),
    ],
    roofs=[("gable", (-3.1, 3.1, 3.1, 11.7), 6.12, 42, "z", {})],
    ext=dict(siding="Arch_SidingBlue", trim="Arch_TrimPainted", roof="Arch_RoofShinglesDarkGray", door="Town_PaintWhite",
             foundation="Arch_BrickWeatheredBrown"),
    colorways={"B": dict(siding="Arch_SidingGreen", roof="Arch_RoofTilesWeathered", door="Town_PaintRed")},
)

# ----------------------------------------------------------------------------
# 9. PLAYER HOME - L-shaped ranch, blue siding, flared driveway to a side garage
# ----------------------------------------------------------------------------
PLAYER_HOME = dict(
    name="RES_PlayerHome", title="The protagonist's home", width=13.0, levels={0: (FLOOR_Y, CEIL_H)}, garage_x=4.65,
    driveway_flare=[(-1.0, 2.0), (2.0, 2.0), (5.95, 4.5), (3.35, 4.5)], interactive_windows=True,
    rooms=[
        R("LIV", 0, (-6.5, 2.2, -1.0, 6.6), "living", "Int_CarpetWorn", "Int_WallpaperFaded"),
        R("BED", 0, (-1.0, 4.6, 2.8, 8.4), "bedroom", "Int_FloorboardsOld", "Int_WallpaperPatterned"),
        R("KIT", 0, (-6.5, 6.6, -2.6, 11.6), "kitchen", "Int_Linoleum", "Int_DrywallLight"),
        R("HALL", 0, (-2.6, 6.6, -1.0, 11.6), "hall", "Int_FloorboardsOld", "Int_DrywallLight"),
        R("HALL2", 0, (-1.0, 8.4, 2.8, 9.5), "hall", "Int_FloorboardsOld", "Int_DrywallLight"),
        R("BATH", 0, (-1.0, 9.5, 1.4, 11.6), "bathroom", "Int_Linoleum", "Int_TilesBathroom"),
        R("LAU", 0, (1.4, 9.5, 2.8, 11.6), "laundry", "Int_Linoleum", "Int_DrywallLight"),
        R("GAR", 0, (2.8, 4.5, 6.5, 11.6), "garage", **GARAGE),
    ],
    doors=[
        DX("LIV", "F", -2.6, name="Front"), DX("GAR", "F", 4.65, w=2.6, h=2.2, kind="garage", name="Garage"),
        DX("LAU", "B", 2.1, w=0.8, h=2.1, style="back", name="Back"),
        D("LIV", "HALL", -1.8, w=1.2, h=2.2, kind="arch", name="LivHall"), D("LIV", "KIT", -4.5, w=1.6, h=2.2, kind="arch", name="LivKit"),
        D("HALL", "BED", 7.5, into="BED", name="Bedroom"), D("HALL", "HALL2", 8.95, w=0.95, h=2.2, kind="arch", name="Halls"),
        D("HALL2", "BATH", 0.2, w=0.8, into="BATH", name="Bathroom"), D("HALL2", "LAU", 2.1, w=0.8, into="LAU", name="Laundry"),
        D("LAU", "GAR", 10.6, w=0.85, into="LAU", name="GarageDoorInside"),
    ],
    windows=[
        Wn("LIV", "F", -5.0, w=1.8, h=1.4, sill=0.7, style="picture"), Wn("LIV", "L", 4.4, w=1.1), Wn("KIT", "L", 8.5, w=1.1),
        Wn("KIT", "B", -4.5, w=1.2, h=1.0, sill=1.05), Wn("BED", "F", 0.9, w=1.3), Wn("BATH", "B", 0.2, w=0.6, h=0.7, sill=1.3),
        Wn("GAR", "R", 8.0, w=0.8, h=0.6, sill=1.5), Wn("HALL", "B", -1.8, w=0.6, h=0.9, sill=1.1),
    ],
    porches=[
        dict(rect=(-5.6, 1.0, -1.4, 2.2), deck_y=0.58, risers=3, steps=("z0", -2.6, 1.3), rails=("x0", "x1", "z0"),
             columns=[(-5.5, 1.1), (-1.5, 1.1)], col_h=2.3, roof=("shed", (-5.6, 1.0, -1.4, 2.2), 2.95, 3.2, "z1", {})),
        dict(rect=(1.5, 11.6, 2.7, 12.5), deck_y=0.58, steps=("x0", 12.05, 0.8), rails=("z1",), columns=[]),
    ],
    roofs=[("hip", (-6.6, 4.5, 2.9, 11.7), TOP0, 25, {}), ("gable", (-6.6, 2.1, -0.9, 6.7), TOP0, 30, "z", {}),
           ("gable", (2.7, 4.4, 6.6, 11.7), 0.02 + 2.9 + 0.12, 26, "z", {})],
    chimneys=[(-6.8, 4.4, 0.6, 0.9, 5.4)],
    ext=dict(siding="Arch_SidingBlue", trim="Arch_TrimPainted", roof="Arch_RoofShinglesDarkGray", door="Town_PaintRed",
             foundation="Arch_ConcreteFoundation", shutters=False),
    colorways={},
)

PLANS = {"Ranch": RANCH, "TwoStorey": TWO_STOREY, "Farmhouse": FARMHOUSE, "Bungalow": BUNGALOW, "Abandoned": ABANDONED,
         "SplitLevel": SPLIT_LEVEL, "Cottage": COTTAGE, "MillWorker": MILL, "PlayerHome": PLAYER_HOME}


# Door swings chosen by an automated search: with the leaf open at 95 deg,
# every hall, stair foot and room stays walkable for a 0.35 m capsule.  name -> (hinge, swings into)
DOOR_SWINGS = {
    "PlayerHome": {
        "Bedroom": ["r", "BED"],
        "GarageDoorInside": ["l", "GAR"]
    },
    "Bungalow": {
        "Front": ["r", "LIV"]
    },
    "Farmhouse": {
        "Kitchen": ["r", "KIT"],
        "Bed2": [
            "r",
            "BED2"
        ],
        "Front": [
            "r",
            "HAL"
        ]
    },
    "MillWorker": {
        "Kitchen": [
            "l",
            "PAR"
        ],
        "Bed1": [
            "r",
            "UHAL"
        ]
    },
    "Cottage": {
        "Back": ["l", "OUT"],
        "KitHall": ["l", "KIT"]
    },
    "TwoStorey": {
        "Back": [
            "l",
            "OUT"
        ],
        "Kitchen": [
            "r",
            "KIT"
        ],
        "Bed2": [
            "r",
            "UHAL"
        ],
        "Bed3": [
            "l",
            "UHAL"
        ],
        "Front": [
            "r",
            "FOY"
        ]
    }
}
for _k, _sw in DOOR_SWINGS.items():
    for _d in PLANS[_k]["doors"]:
        if _d.get("name") in _sw:
            _d["hinge"], _d["into"] = _sw[_d["name"]]


# ----------------------------------------------------------------------------
# Mirroring (true left/right reflection of a plan - never negative node scale,
# which Godot physics does not support)
# ----------------------------------------------------------------------------
def _mr(r):
    x0, z0, x1, z1 = r
    return (-x1, z0, -x0, z1)


def mirror_plan(p):
    import copy
    q = copy.deepcopy(p)
    q["name"] = p["name"] + "_Mirror"
    rooms = {r["id"]: r["rect"] for r in p["rooms"]}
    swap = {"L": "R", "R": "L", "F": "F", "B": "B", "x0": "x1", "x1": "x0", "z0": "z0", "z1": "z1", "l": "r", "r": "l",
            "+x": "-x", "-x": "+x", "+z": "+z", "-z": "-z"}
    for r in q["rooms"]:
        r["rect"] = _mr(r["rect"])
        if "walk" in r:
            r["walk"] = _mr(r["walk"])
    for d in q.get("doors", []):
        if "room" in d:
            if d["side"] in "FB":
                d["at"] = -d["at"]
            d["side"] = swap[d["side"]]
        else:
            ra, rb = rooms[d["a"]], rooms[d["b"]]
            shares_x_edge = abs(ra[2] - rb[0]) < 1e-6 or abs(rb[2] - ra[0]) < 1e-6
            if not shares_x_edge:
                d["at"] = -d["at"]
    for w in q.get("windows", []):
        if w["side"] in "FB":
            w["at"] = -w["at"]
        w["side"] = swap[w["side"]]
    for st in q.get("stairs", []):
        st["rect"] = _mr(st["rect"])
        st["dir"] = swap[st["dir"]]
        st["open"] = tuple(swap[o] for o in st.get("open", ("r",)))
    for po in q.get("porches", []):
        po["rect"] = _mr(po["rect"])
        if po.get("steps"):
            side, c, w = po["steps"]
            po["steps"] = (swap[side], -c if side == "z0" else c, w)
        po["rails"] = tuple(swap[r] for r in po.get("rails", ("x0", "x1", "z0")))
        if po.get("columns") is not None:
            po["columns"] = [(-x, z) for (x, z) in po["columns"]]
        if po.get("roof"):
            po["roof"] = _mirror_roof(po["roof"], swap)
    q["roofs"] = [_mirror_roof(rf, swap) for rf in q.get("roofs", [])]
    q["chimneys"] = [(-c[0],) + tuple(c[1:]) for c in q.get("chimneys", [])]
    if q.get("garage_x") is not None:
        q["garage_x"] = -q["garage_x"]
    if q.get("driveway_flare"):
        q["driveway_flare"] = [(-x, z) for (x, z) in reversed(q["driveway_flare"])]
    q["mirrored"] = True
    _fix_mirror_hinges(p, q)
    return q


def _fix_mirror_hinges(p, q):
    """A wall's run direction can reverse under mirroring, which silently flips the l/r hinge convention.
    Build both plans and pick, per door, the hinge whose leaf pivot is the true reflection of the original."""
    import house
    ha = house.House(p).build()
    hb = house.House(q).build()
    want = {d["name"]: (-d["hinge"][0], d["hinge"][1]) for d in ha.meta["doors"] if "hinge" in d}
    got = {d["name"]: tuple(d["hinge"]) for d in hb.meta["doors"] if "hinge" in d}
    names = [d["name"] for d in hb.meta["doors"]]
    doors = [d for d in q.get("doors", []) if d.get("kind", "door") not in ("arch", "garage", "slider")]
    for name, w in want.items():
        g = got.get(name)
        if g is None or abs(g[0] - w[0]) + abs(g[1] - w[1]) < 1e-3:
            continue
        # match the plan entry by its generated name
        for d in q.get("doors", []):
            if "INT_Door_" + d.get("name", "") == name:
                d["hinge"] = "r" if d.get("hinge", "l") == "l" else "l"


def _mirror_roof(rf, swap):
    rf = list(rf)
    rf[1] = _mr(rf[1])
    if rf[0] == "shed":
        rf[4] = swap[rf[4]]
    return tuple(rf)
