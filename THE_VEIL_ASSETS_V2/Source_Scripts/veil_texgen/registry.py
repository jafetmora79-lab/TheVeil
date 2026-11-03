"""Single source of truth for Pack 01: every texture, its spec, and the
material preset it uses. build_library.py and validate_library.py both read
this file, so the manifest, materials and checks can never drift apart."""
from . import gen_architecture as A
from . import gen_roads as B
from . import gen_ground as C
from . import gen_interiors as D
from . import gen_furniture as E
from . import gen_commercial as F
from . import gen_horror as G

# World texel density shared by EVERY asset pack: 64 texels per metre.
TEXEL_DENSITY = 64

# Godot BaseMaterial3D.TextureFilter values
NEAREST_MIP = 2          # TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
NEAREST_MIP_ANISO = 4    # TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC

# Reusable material presets (also exported as .tres templates).
PRESETS = {
    "VEIL_Painted":       dict(roughness=0.88, metallic=0.0, specular=0.35, filter=NEAREST_MIP),
    "VEIL_Wood":          dict(roughness=0.85, metallic=0.0, specular=0.3, filter=NEAREST_MIP),
    "VEIL_Masonry":       dict(roughness=0.95, metallic=0.0, specular=0.25, filter=NEAREST_MIP),
    "VEIL_Roof":          dict(roughness=0.92, metallic=0.0, specular=0.3, filter=NEAREST_MIP_ANISO),
    "VEIL_Ground":        dict(roughness=0.97, metallic=0.0, specular=0.2, filter=NEAREST_MIP_ANISO),
    "VEIL_Floor":         dict(roughness=0.75, metallic=0.0, specular=0.4, filter=NEAREST_MIP_ANISO),
    "VEIL_Ceramic":       dict(roughness=0.35, metallic=0.0, specular=0.6, filter=NEAREST_MIP_ANISO),
    "VEIL_Fabric":        dict(roughness=1.0, metallic=0.0, specular=0.15, filter=NEAREST_MIP),
    "VEIL_Leather":       dict(roughness=0.6, metallic=0.0, specular=0.4, filter=NEAREST_MIP),
    "VEIL_Plastic":       dict(roughness=0.55, metallic=0.0, specular=0.45, filter=NEAREST_MIP),
    "VEIL_Rubber":        dict(roughness=0.9, metallic=0.0, specular=0.2, filter=NEAREST_MIP),
    "VEIL_Metal_Bare":    dict(roughness=0.45, metallic=0.75, specular=0.5, filter=NEAREST_MIP),
    "VEIL_Metal_Painted": dict(roughness=0.7, metallic=0.2, specular=0.4, filter=NEAREST_MIP),
    "VEIL_Metal_Rusted":  dict(roughness=0.9, metallic=0.3, specular=0.3, filter=NEAREST_MIP),
    "VEIL_Glass":         dict(roughness=0.12, metallic=0.0, specular=0.7, filter=NEAREST_MIP,
                               transparency="blend", cull="disabled"),
    "VEIL_Decal_Blend":   dict(roughness=0.8, metallic=0.0, specular=0.3, filter=NEAREST_MIP,
                               transparency="blend", repeat=False),
    "VEIL_Overlay_Blend": dict(roughness=0.9, metallic=0.0, specular=0.2, filter=NEAREST_MIP,
                               transparency="blend"),
    "VEIL_Marking":       dict(roughness=0.8, metallic=0.0, specular=0.3, filter=NEAREST_MIP_ANISO,
                               transparency="blend"),
    "VEIL_Cutout":        dict(roughness=0.9, metallic=0.0, specular=0.2, filter=NEAREST_MIP,
                               transparency="scissor", cull="disabled", repeat=False),
    "VEIL_Sign":          dict(roughness=0.7, metallic=0.2, specular=0.4, filter=NEAREST_MIP,
                               transparency="scissor", repeat=False),
}

CATEGORY_DIR = {
    "Architecture": "Architecture", "Roads": "Roads", "Ground": "Ground", "Interiors": "Interiors",
    "Furniture": "Furniture", "Commercial": "Commercial", "Horror": "Horror",
}
PREFIX = {"Architecture": "Arch", "Roads": "Road", "Ground": "Grnd", "Interiors": "Int",
          "Furniture": "Furn", "Commercial": "Com", "Horror": "Hor"}

# (category, short name, generator, (w, h), tiles, preset, description)
#   tiles: "uv" = seamless both ways, "none" = 0..1 unwrap / decal
TEXTURES = [
    # A. Exterior house materials ----------------------------------------------
    ("Architecture", "SidingWhite", A.siding_white, (128, 128), "uv", "VEIL_Painted", "Painted lap siding, white; 16px (25cm) boards with lip shadow, butt joints, paint chips."),
    ("Architecture", "SidingBlue", A.siding_blue, (128, 128), "uv", "VEIL_Painted", "Painted lap siding, faded blue."),
    ("Architecture", "SidingGreen", A.siding_green, (128, 128), "uv", "VEIL_Painted", "Painted lap siding, muted sage green."),
    ("Architecture", "WoodPlanksAged", A.wood_planks_aged, (128, 128), "uv", "VEIL_Wood", "Weathered grey planks with grain, knots, gaps, rusty nails, splits."),
    ("Architecture", "BrickRed", A.brick_red, (128, 128), "uv", "VEIL_Masonry", "Running-bond red brick, hand-varied widths, recessed mortar."),
    ("Architecture", "BrickWeatheredBrown", A.brick_weathered_brown, (128, 128), "uv", "VEIL_Masonry", "Weathered brown brick, chipped corners, eroded mortar, efflorescence."),
    ("Architecture", "ConcreteFoundation", A.concrete_foundation, (128, 128), "uv", "VEIL_Masonry", "Board-formed poured concrete with form seams, tie holes, pits, hairline cracks."),
    ("Architecture", "RoofShinglesDarkGray", A.roof_shingles_darkgray, (128, 128), "uv", "VEIL_Roof", "3-tab asphalt shingles, dark grey, granule sparkle and slot cuts."),
    ("Architecture", "RoofShinglesBrown", A.roof_shingles_brown, (128, 128), "uv", "VEIL_Roof", "Dimensional (laminated) asphalt shingles, brown, random tab widths."),
    ("Architecture", "RoofTilesWeathered", A.roof_tiles_weathered, (128, 128), "uv", "VEIL_Roof", "Barrel clay tiles, terracotta, lichen colonies, cracked/chipped tiles."),
    ("Architecture", "TrimPainted", A.trim_painted, (64, 64), "uv", "VEIL_Painted", "Cream exterior trim paint over wood; streaks, dirt, small chips."),
    ("Architecture", "WindowGlassDirty", A.window_glass_dirty, (64, 64), "none", "VEIL_Glass", "One window pane (0..1 UV): tinted glass, reflection bands, edge grime, drips."),
    # B. Streets and sidewalks ------------------------------------------------
    ("Roads", "Asphalt", B.asphalt, (256, 256), "uv", "VEIL_Ground", "Road asphalt with clustered aggregate stones and wear patches."),
    ("Roads", "AsphaltCracked", B.asphalt_cracked, (256, 256), "uv", "VEIL_Ground", "Asphalt with alligator cracking, long cracks and a small pothole."),
    ("Roads", "SidewalkConcrete", B.sidewalk_concrete, (128, 128), "uv", "VEIL_Ground", "1m sidewalk slabs, tooled joints, trowel margins, broom finish."),
    ("Roads", "ConcreteCracked", B.concrete_cracked, (128, 128), "uv", "VEIL_Ground", "Flatwork concrete with crack network and spalls exposing aggregate."),
    ("Roads", "CurbConcrete", B.curb_concrete, (64, 64), "uv", "VEIL_Ground", "Cast concrete curb, joint every 1m (x=32), tyre scuffs, chips."),
    ("Roads", "ParkingLotAsphalt", B.parking_lot_asphalt, (256, 256), "uv", "VEIL_Ground", "Lighter worn asphalt with sealcoat patches and oil stains."),
    ("Roads", "MarkingYellow", B.road_marking_yellow, (64, 64), "uv", "VEIL_Marking", "Faded yellow road paint, alpha wear holes. Use on thin quads over asphalt."),
    ("Roads", "MarkingWhite", B.road_marking_white, (64, 64), "uv", "VEIL_Marking", "Faded white road paint, alpha wear holes."),
    ("Roads", "Gravel", B.gravel, (128, 128), "uv", "VEIL_Ground", "Mixed warm/cool gravel stones lit from top-left."),
    ("Roads", "DirtRoad", B.dirt_road, (256, 256), "uv", "VEIL_Ground", "Packed dirt with dry-mud cracking, puddle hollows, pebbles."),
    ("Roads", "RoadPatch", B.road_patch, (128, 128), "uv", "VEIL_Ground", "Dark patched asphalt with glossy tar-snake crack sealant."),
    # C. Ground and vegetation -------------------------------------------------
    ("Ground", "GrassShort", C.grass_short, (128, 128), "uv", "VEIL_Ground", "Mown lawn: short blades on a jittered grid, yellowed patches."),
    ("Ground", "GrassOvergrown", C.grass_overgrown, (128, 128), "uv", "VEIL_Ground", "Long leaning blades, deep shadows, sparse weed flowers."),
    ("Ground", "GrassDry", C.grass_dry, (128, 128), "uv", "VEIL_Ground", "Straw-coloured grass with bare soil patches."),
    ("Ground", "Mud", C.mud, (128, 128), "uv", "VEIL_Ground", "Wet mud with standing water and sky glints."),
    ("Ground", "Soil", C.soil, (128, 128), "uv", "VEIL_Ground", "Tilled soil clods, pebbles, root fibres."),
    ("Ground", "LeavesFallen", C.leaves_fallen, (128, 128), "uv", "VEIL_Ground", "Layered fallen leaves (rust/ochre/brown) over dark soil."),
    ("Ground", "Moss", C.moss, (64, 64), "uv", "VEIL_Ground", "Moss cushions with sporophyte tips."),
    ("Ground", "TreeBark", C.tree_bark, (128, 128), "uv", "VEIL_Wood", "Vertically furrowed bark plates with lichen. V runs up the trunk."),
    ("Ground", "HedgeFoliage", C.hedge_foliage, (128, 128), "uv", "VEIL_Ground", "Dense layered leaf clusters for hedge/bush blocks."),
    ("Ground", "DeadVegetation", C.dead_vegetation, (128, 128), "uv", "VEIL_Ground", "Mat of dead stalks, twigs and decayed leaves."),
    # D. Interior floors and walls --------------------------------------------
    ("Interiors", "DrywallLight", D.drywall_light, (128, 128), "uv", "VEIL_Painted", "Light painted drywall, orange-peel texture, faint scuffs."),
    ("Interiors", "WallpaperFaded", D.wallpaper_faded, (128, 128), "uv", "VEIL_Painted", "Faded rose striped wallpaper with sprigs; 1m strips, one off-register."),
    ("Interiors", "WallpaperPatterned", D.wallpaper_patterned, (128, 128), "uv", "VEIL_Painted", "Green damask wallpaper, hand-authored ochre medallion in half-drop repeat."),
    ("Interiors", "FloorboardsOld", D.floorboards_old, (128, 128), "uv", "VEIL_Floor", "Old warm floorboards, mixed widths, staggered joints, nails, worn varnish."),
    ("Interiors", "CarpetWorn", D.carpet_worn, (128, 128), "uv", "VEIL_Fabric", "Loop-pile carpet with faint lattice, worn path and stains."),
    ("Interiors", "TilesKitchen", D.tiles_kitchen, (128, 128), "uv", "VEIL_Ceramic", "Cream/teal checker floor tiles, glaze highlights, grimy grout."),
    ("Interiors", "TilesBathroom", D.tiles_bathroom, (128, 128), "uv", "VEIL_Ceramic", "Glossy subway wall tiles, running bond, mildew in grout."),
    ("Interiors", "Linoleum", D.linoleum, (128, 128), "uv", "VEIL_Floor", "Marbled faux-tile sheet linoleum with heel scuffs."),
    ("Interiors", "BasementConcrete", D.basement_concrete, (128, 128), "uv", "VEIL_Floor", "Dark basement slab: trowel swirls, damp tide-lines, efflorescence, cracks."),
    ("Interiors", "PlasterDamaged", D.plaster_damaged, (128, 128), "uv", "VEIL_Masonry", "Cracked plaster with holes exposing scratch coat and wooden lath."),
    # E. Furniture and household ----------------------------------------------
    ("Furniture", "WoodLight", E.wood_light, (64, 64), "uv", "VEIL_Wood", "Light oak-like wood grain."),
    ("Furniture", "WoodDark", E.wood_dark, (64, 64), "uv", "VEIL_Wood", "Dark walnut-like wood with open pores."),
    ("Furniture", "WoodPainted", E.wood_painted, (64, 64), "uv", "VEIL_Painted", "Mustard painted wood, brush strokes, chips to bare wood."),
    ("Furniture", "LeatherWorn", E.leather_worn, (64, 64), "uv", "VEIL_Leather", "Pebbled leather, creases, worn and crazed patches."),
    ("Furniture", "FabricUpholstery", E.fabric_upholstery, (64, 64), "uv", "VEIL_Fabric", "Olive tweed twill with coloured slubs and pilling."),
    ("Furniture", "Denim", E.denim, (64, 64), "uv", "VEIL_Fabric", "Diagonal denim twill with slubs and fading."),
    ("Furniture", "PlasticDirty", E.plastic_dirty, (32, 32), "uv", "VEIL_Plastic", "Off-white aged plastic, smudges, scratches."),
    ("Furniture", "MetalBrushed", E.metal_brushed, (64, 64), "uv", "VEIL_Metal_Bare", "Brushed steel streaks with soft highlight band."),
    ("Furniture", "MetalRusted", E.metal_rusted, (64, 64), "uv", "VEIL_Metal_Rusted", "Steel with rust blooms, pitting and rust runs."),
    ("Furniture", "Rubber", E.rubber, (32, 32), "uv", "VEIL_Rubber", "Charcoal rubber with diamond grip pattern."),
    ("Furniture", "Cardboard", E.cardboard, (64, 64), "uv", "VEIL_Fabric", "Kraft cardboard: corrugation, fibres, fold crease, water ring."),
    # F. Commercial --------------------------------------------------------------
    ("Commercial", "SupermarketFloorTiles", F.supermarket_floor_tiles, (128, 128), "uv", "VEIL_Floor", "VCT floor tiles with chip flecks, wax sheen, scuffs."),
    ("Commercial", "StorefrontBrick", F.storefront_brick, (128, 128), "uv", "VEIL_Masonry", "Uniform buff face brick, dark mortar, clean commercial look."),
    ("Commercial", "StorefrontConcrete", F.storefront_concrete, (128, 128), "uv", "VEIL_Masonry", "2m precast panel: reveal joints, bolt caps, drip stains."),
    ("Commercial", "CeilingTiles", F.ceiling_tiles, (128, 128), "uv", "VEIL_Painted", "Drop-ceiling acoustic tiles with fissures and T-bar grid (1m tiles)."),
    ("Commercial", "MetalShelving", F.metal_shelving, (64, 64), "uv", "VEIL_Metal_Painted", "Painted gondola steel with pegboard holes and scratches."),
    ("Commercial", "MetalDoorPainted", F.metal_door_painted, (64, 128), "none", "VEIL_Metal_Painted", "Full 1x2m steel door face (0..1 UV): two recessed panels, latch wear, kick scuffs, rust."),
    ("Commercial", "GasStationPavement", F.gas_station_pavement, (256, 256), "uv", "VEIL_Ground", "2m concrete forecourt slabs with sealed joints, oil stains, tyre marks."),
    ("Commercial", "SignageBacking", F.signage_backing, (64, 64), "uv", "VEIL_Metal_Painted", "Chalky painted sheet metal with riveted seam and rust bleed."),
    ("Commercial", "StorageConcrete", F.storage_concrete, (128, 128), "uv", "VEIL_Masonry", "Painted concrete-block (CMU) wall, running bond."),
    ("Commercial", "IndustrialWallDirty", F.industrial_wall_dirty, (128, 128), "uv", "VEIL_Metal_Rusted", "Corrugated metal cladding, grime and rust streaks, riveted lap seam."),
    # G. Special horror ---------------------------------------------------------
    ("Horror", "StainOrganicDark", G.stain_organic_dark, (64, 64), "none", "VEIL_Decal_Blend", "Decal: unnaturally dark organic stain with droplets and runs."),
    ("Horror", "DampWall", G.damp_wall, (128, 128), "uv", "VEIL_Painted", "Drywall with damp blotches, tide lines, mildew, blisters."),
    ("Horror", "ResidueStrange", G.residue_strange, (64, 64), "none", "VEIL_Decal_Blend", "Decal: pale viscous residue smear with drips."),
    ("Horror", "FoliageDead", G.foliage_dead, (64, 64), "none", "VEIL_Cutout", "Cutout card: dead branch with curled leaves (alpha scissor)."),
    ("Horror", "WarningSignWeathered", G.warning_sign_weathered, (64, 64), "none", "VEIL_Sign", "Weathered warning plate: hazard triangle, abstract lettering, rust, bolt holes."),
    ("Horror", "GroundMistCorrupted", G.ground_mist_corrupted, (128, 128), "uv", "VEIL_Ground", "Post-mist ground: drained ash grass, dark veins, cold dew. Story-beat only."),
    ("Horror", "WoodDarkened", G.wood_darkened, (128, 128), "uv", "VEIL_Wood", "Darkened/rotted planks with damp sheen and fungal spots."),
    ("Horror", "GrimeAbandoned", G.grime_abandoned, (128, 128), "uv", "VEIL_Overlay_Blend", "Tileable grime overlay (alpha) for next_pass layering on any wall."),
]

# Opaque prop atlas: 4x4 grid of 64px cells (power-of-two aligned -> no
# mip bleeding). 32px textures are tiled 2x2 inside their cell so texel
# density stays at 64 px/m.
ATLASES = {
    "ATLAS_Props_Opaque": dict(size=(256, 256), cell=64, alpha=False, preset="VEIL_Wood", cells=[
        "Furn_WoodLight", "Furn_WoodDark", "Furn_WoodPainted", "Furn_LeatherWorn",
        "Furn_FabricUpholstery", "Furn_Denim", "Furn_PlasticDirty", "Furn_MetalBrushed",
        "Furn_MetalRusted", "Furn_Rubber", "Furn_Cardboard", "Com_MetalShelving",
        "Com_SignageBacking", "Arch_TrimPainted", None, None]),
    "ATLAS_Horror_Decals": dict(size=(128, 128), cell=64, alpha=True, preset="VEIL_Decal_Blend", cells=[
        "Hor_StainOrganicDark", "Hor_ResidueStrange", "Hor_FoliageDead", "Hor_WarningSignWeathered"]),
}


def texture_id(cat, short):
    return f"{PREFIX[cat]}_{short}"


def transparency_of(preset):
    return PRESETS[preset].get("transparency", "none")
