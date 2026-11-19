"""Material bridge: Pack 01 library + the few Pack 02 additions.

Every GLB material is *named after* its Godot .tres (e.g. "M_Road_Asphalt").
The generated .glb.import files tell Godot to use those external .tres
resources, so imported models share the exact Pack 01 materials (filtering,
roughness, uv1_scale) instead of duplicating them.
"""
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
V2 = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
TOWN = os.path.join(V2, "02_Town")
RES_ROOT = "res://THE_VEIL_ASSETS_V2"

_man = json.load(open(os.path.join(V2, "Documentation", "TEXTURE_MANIFEST.json")))
PACK01 = {m["id"]: m for m in _man["textures"]}
PRESETS01 = _man["presets"]

MATS = {}


def _reg(name, **kw):
    MATS[name] = dict(name=name, **kw)
    return name


def m01(tex_id):
    """Material for a Pack 01 texture id, e.g. m01('Road_Asphalt')."""
    name = "M_" + tex_id
    if name not in MATS:
        t = PACK01[tex_id]
        pre = PRESETS01[t["preset"]]
        alpha = {"none": "OPAQUE", "blend": "BLEND", "scissor": "MASK"}[t["transparency"]]
        _reg(name, png=os.path.join(V2, t["file"]), tres=t["intended_material"], uv=tuple(t["recommended_uv_scale"]),
             alpha=alpha, double=pre.get("cull") == "disabled", repeat=pre.get("repeat", True),
             rough=pre["roughness"], metal=pre["metallic"], pack="01")
    return name


# ---- Pack 02 additions (textures in 02_Town/Textures) -----------------------
TOWN_MAT_SPECS = {
    # name: (texture or None, uv scale, alpha, double, repeat, roughness, metallic, extra)
    "SignAtlas": ("SignAtlas", 1.0, "OPAQUE", False, False, 0.65, 0.2, {}),
    "PaintRed": ("PaintRed", 2.0, "OPAQUE", False, True, 0.6, 0.15, {}),
    "PaintOrange": ("PaintOrange", 2.0, "OPAQUE", False, True, 0.7, 0.0, {}),
    "PaintNavy": ("PaintNavy", 2.0, "OPAQUE", False, True, 0.6, 0.15, {}),
    "PaintBlack": ("PaintBlack", 2.0, "OPAQUE", False, True, 0.6, 0.2, {}),
    "PaintYellow": ("PaintYellow", 2.0, "OPAQUE", False, True, 0.6, 0.15, {}),
    "PaintGreen": ("PaintGreen", 2.0, "OPAQUE", False, True, 0.65, 0.15, {}),
    "PaintWhite": ("PaintWhite", 2.0, "OPAQUE", False, True, 0.6, 0.1, {}),
    "HazardStripe": ("HazardStripe", 1.0, "OPAQUE", False, True, 0.7, 0.1, {}),
    "ChainLink": ("ChainLink", 2.0, "MASK", True, True, 0.5, 0.6, {}),
    "Puddle": ("Puddle", 1.0, "BLEND", False, False, 0.1, 0.0, {}),
    "ManholeCover": ("ManholeCover", 1.0, "OPAQUE", False, False, 0.55, 0.6, {}),
    "DrainGrate": ("DrainGrate", 1.0, "OPAQUE", False, False, 0.55, 0.6, {}),
    "UtilityCover": ("UtilityCover", 1.0, "OPAQUE", False, False, 0.55, 0.6, {}),
    "PineNeedles": ("PineNeedles", 0.5, "OPAQUE", False, True, 0.95, 0.0, {}),
    "GrassCards": ("GrassCards", 1.0, "MASK", True, False, 0.95, 0.0, {}),
    "FlowerBed": ("FlowerBed", 1.0, "OPAQUE", False, True, 0.95, 0.0, {}),
    "Ivy": ("Ivy", 1.0, "MASK", True, True, 0.9, 0.0, {}),
    "Rock": ("Rock", 1.0, "OPAQUE", False, True, 0.95, 0.0, {}),
    "PoleWood": ("PoleWood", 1.0, "OPAQUE", False, True, 0.9, 0.0, {}),
    "StumpTop": ("StumpTop", 1.0, "OPAQUE", False, False, 0.9, 0.0, {}),
    "VentGrille": ("VentGrille", 2.0, "OPAQUE", False, True, 0.6, 0.4, {}),
    "LampGlow": ("LampGlow", 2.0, "OPAQUE", False, True, 0.3, 0.0, {"emission": (1.0, 0.78, 0.45), "energy": 1.6}),
    # untextured
    "LensRed": (None, 1.0, "OPAQUE", False, True, 0.2, 0.0, {"color": (0.55, 0.12, 0.1, 1), "emission": (1.0, 0.18, 0.12), "energy": 1.4}),
    "LensAmber": (None, 1.0, "OPAQUE", False, True, 0.2, 0.0, {"color": (0.45, 0.3, 0.08, 1)}),
    "LensGreen": (None, 1.0, "OPAQUE", False, True, 0.2, 0.0, {"color": (0.1, 0.3, 0.2, 1)}),
    "ZoneMarker": (None, 1.0, "BLEND", True, True, 1.0, 0.0, {"color": (0.95, 0.75, 0.25, 0.22), "unshaded": True}),
    "ZoneMarkerHero": (None, 1.0, "BLEND", True, True, 1.0, 0.0, {"color": (0.35, 0.8, 0.95, 0.25), "unshaded": True}),
}


def mt(name):
    """Pack 02 material by short name, e.g. mt('PaintRed') -> 'M_Town_PaintRed'."""
    full = "M_Town_" + name
    if full not in MATS:
        tex, uv, alpha, dbl, rep, rough, metal, extra = TOWN_MAT_SPECS[name]
        png = os.path.join(TOWN, "Textures", f"T_Town_{tex}.png") if tex else None
        _reg(full, png=png, tres=f"02_Town/Materials/{full}.tres", uv=(uv, uv), alpha=alpha, double=dbl,
             repeat=rep, rough=rough, metal=metal, pack="02", **extra)
    return full


def all_town_materials():
    return [mt(k) for k in TOWN_MAT_SPECS]


def fmt(v):
    s = f"{v:.4f}".rstrip("0").rstrip(".")
    return s if s not in ("", "-0") else "0"


def town_tres(spec):
    """Write a Pack 02 .tres in the same style as Pack 01 materials."""
    lines = []
    has_tex = spec.get("png") is not None
    res_png = RES_ROOT + "/" + os.path.relpath(spec["png"], V2).replace(os.sep, "/") if has_tex else None
    if has_tex:
        lines += ['[gd_resource type="StandardMaterial3D" load_steps=2 format=3]', "",
                  f'[ext_resource type="Texture2D" path="{res_png}" id="1_albedo"]', ""]
    else:
        lines += ['[gd_resource type="StandardMaterial3D" format=3]', ""]
    lines += ["[resource]", f'resource_name = "{spec["name"]}"']
    if spec["alpha"] == "BLEND":
        lines.append("transparency = 1")
    elif spec["alpha"] == "MASK":
        lines += ["transparency = 2", "alpha_scissor_threshold = 0.5"]
    if spec.get("unshaded"):
        lines.append("shading_mode = 0")
    if spec["double"]:
        lines.append("cull_mode = 2")
    if "color" in spec:
        c = spec["color"]
        lines.append(f"albedo_color = Color({fmt(c[0])}, {fmt(c[1])}, {fmt(c[2])}, {fmt(c[3])})")
    if has_tex:
        lines.append('albedo_texture = ExtResource("1_albedo")')
    if spec["metal"] > 0:
        lines.append(f"metallic = {fmt(spec['metal'])}")
    lines.append("metallic_specular = 0.4")
    lines.append(f"roughness = {fmt(spec['rough'])}")
    if "emission" in spec:
        e = spec["emission"]
        lines += ["emission_enabled = true", f"emission = Color({fmt(e[0])}, {fmt(e[1])}, {fmt(e[2])}, 1)",
                  f"emission_energy_multiplier = {fmt(spec.get('energy', 1.0))}"]
        if has_tex:
            lines.append('emission_texture = ExtResource("1_albedo")')
    if spec["uv"] != (1.0, 1.0):
        lines.append(f"uv1_scale = Vector3({fmt(spec['uv'][0])}, {fmt(spec['uv'][1])}, 1)")
    if has_tex:
        lines.append("texture_filter = 2")
    if not spec["repeat"]:
        lines.append("texture_repeat = false")
    return "\n".join(lines) + "\n"
