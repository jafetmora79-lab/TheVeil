#!/usr/bin/env python3
"""THE VEIL - Pack 09 builder: horror atmosphere, Veil mist, corruption, abandoned props, anomalies, effects.

    python3 09_Horror_Atmosphere/Source_Scripts/build_atmosphere.py

Writes textures (+ .import), materials (.tres), static GLBs (+ .import, texture embedded for the browser
gallery), Godot scenes (.tscn) for the mist, lights, effects and reuse-only prop arrangements, 13 atmosphere
presets (.tres) and the atmosphere rig + Greyhaven demo scene. Deterministic. Packs 01-08 are read, never written.
Everything targets the Compatibility renderer: no Decal nodes, no volumetric fog, no GPU particles, no screen /
depth textures; CPUParticles3D with capped counts; unshaded transparent sheets with near-camera fade.
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
V2 = os.path.normpath(os.path.join(HERE, "..", ".."))
P9 = os.path.join(V2, "09_Horror_Atmosphere")
sys.path.insert(0, os.path.join(V2, "02_Town", "Source_Scripts"))
sys.path.insert(0, os.path.join(V2, "Source_Scripts"))
sys.path.insert(0, os.path.join(V2, "08_Inventory", "Source_Scripts"))

import numpy as np  # noqa: E402
from veil_mesh.materials import MATS, _reg, town_tres, RES_ROOT, m01  # noqa: E402
from veil_mesh.mesh import MB  # noqa: E402
from veil_mesh.gltf import GLBWriter, write_glb_import, COL_KEY  # noqa: E402
from build_library import write_import  # noqa: E402
from build_inventory import embed_images  # noqa: E402
import inv_geom  # noqa: E402
from inv_geom import G, finish, rot  # noqa: E402

import veil_textures  # noqa: E402

RES9 = RES_ROOT + "/09_Horror_Atmosphere"
V = lambda *a: np.array(a, float)
MANIFEST = []


def res(p):
    return RES_ROOT + "/" + os.path.relpath(p, V2).replace(os.sep, "/")


def fnum(v):
    s = f"{float(v):.4f}".rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def col(c):
    return "Color(" + ", ".join(fnum(x) for x in (list(c) + [1.0])[:4]) + ")"


def xf(x=0, y=0, z=0, yaw=0.0, pitch=0.0, roll=0.0, s=1.0):
    R = np.array(rot(yaw, pitch, roll)) * s
    return "Transform3D(" + ", ".join(fnum(v) for v in [R[0, 0], R[0, 1], R[0, 2], R[1, 0], R[1, 1], R[1, 2], R[2, 0], R[2, 1], R[2, 2], x, y, z]) + ")"


# ------------------------------------------------------------------ scene writer
class Tscn:
    def __init__(self, root, rtype="Node3D", script=None):
        self.ext, self.sub, self.nodes = [], [], []
        self.ids = {}
        self.root = (root, rtype, script)

    def e(self, path, typ):
        key = (path, typ)
        if key not in self.ids:
            self.ids[key] = f"{len(self.ids) + 1}_{os.path.basename(path).split('.')[0][:20]}"
            self.ext.append(f'[ext_resource type="{typ}" path="{path}" id="{self.ids[key]}"]')
        return f'ExtResource("{self.ids[key]}")'

    def s(self, typ, props):
        sid = f"{typ}_{len(self.sub) + 1}"
        self.sub.append(f'[sub_resource type="{typ}" id="{sid}"]\n' + "\n".join(f"{k} = {v}" for k, v in props.items()))
        return f'SubResource("{sid}")'

    def n(self, name, typ=None, parent=".", props=None, instance=None, groups=None):
        head = f'[node name="{name}"' + (f' type="{typ}"' if typ else "") + f' parent="{parent}"'
        if instance:
            head += f" instance={instance}"
        refs = [k for k, v in (props or {}).items() if str(v).startswith("NodePath(")]
        if refs:  # exported Node references must be declared or Godot leaves them null
            head += " node_paths=PackedStringArray(" + ", ".join(f'"{k}"' for k in refs) + ")"
        if groups:
            head += " groups=[" + ", ".join(f'"{g}"' for g in groups) + "]"
        self.nodes.append(head + "]\n" + "\n".join(f"{k} = {v}" for k, v in (props or {}).items()))

    def write(self, path, root_props=None):
        rn, rt, scr = self.root
        rp = dict(root_props or {})
        if scr:
            rp = {"script": self.e(scr, "Script"), **rp}
        body = [f'[node name="{rn}" type="{rt}"]\n' + "\n".join(f"{k} = {v}" for k, v in rp.items())]
        txt = f"[gd_scene load_steps={len(self.ext) + len(self.sub) + 1} format=3]\n\n" + "\n".join(self.ext) + "\n\n" + \
            "\n\n".join(self.sub) + ("\n\n" if self.sub else "") + "\n\n".join(body + self.nodes) + "\n"
        os.makedirs(os.path.dirname(path), exist_ok=True)
        open(path, "w", newline="\n").write(txt)


# ------------------------------------------------------------------ textures + materials
def build_textures():
    tdir = os.path.join(P9, "Textures")
    made = veil_textures.build(tdir)
    tex = {}
    for name, p, w, h, alpha in made:
        write_import(p, res(p))
        tex[name] = dict(path=p, res=res(p), size=f"{w}x{h}", alpha=alpha)
    return tex


def std_mat(name, tex, png_key, alpha="BLEND", double=True, unshaded=False, color=None, emission=None, energy=1.0, rough=1.0, repeat=False):
    """StandardMaterial3D .tres (registered for the GLB writer + written to Materials/)"""
    kw = dict(png=tex[png_key]["path"] if png_key else None, tres=f"09_Horror_Atmosphere/Materials/{name}.tres", uv=(1.0, 1.0), alpha=alpha,
              double=double, repeat=repeat, rough=rough, metal=0.0, pack="09")
    if unshaded:
        kw["unshaded"] = True
    if color:
        kw["color"] = color
    if emission:
        kw["emission"], kw["energy"] = emission, energy
    _reg(name, **kw)
    p = os.path.join(V2, MATS[name]["tres"])
    os.makedirs(os.path.dirname(p), exist_ok=True)
    txt = town_tres(MATS[name]).replace("texture_filter = 2", "texture_filter = 0")    # small textures: no mipmaps
    open(p, "w", newline="\n").write(txt.rstrip("\n") + "\ndisable_receive_shadows = true\n" if alpha != "OPAQUE" else txt)
    return name


def particle_mat(tex, key, additive=False, frames=1, yaxis=False, color=(1, 1, 1, 1)):
    props = {"transparency": "1", "shading_mode": "0", "vertex_color_use_as_albedo": "true", "albedo_color": col(color),
             "albedo_texture": None, "texture_filter": "0", "billboard_mode": "2" if yaxis else "3", "billboard_keep_scale": "true",
             "disable_receive_shadows": "true"}
    if additive:
        props["blend_mode"] = "1"
    if frames > 1:
        props.update({"particles_anim_h_frames": str(frames), "particles_anim_v_frames": "1", "particles_anim_loop": "false"})
    return props


def shader_mat_tres(path, shader_res, params):
    lines = ['[gd_resource type="ShaderMaterial" load_steps=3 format=3]', "",
             f'[ext_resource type="Shader" path="{shader_res}" id="1_sh"]']
    k = 2
    pv = []
    for name, v in params.items():
        if isinstance(v, str) and v.startswith("res://"):
            lines.append(f'[ext_resource type="Texture2D" path="{v}" id="{k}_t"]')
            pv.append(f'shader_parameter/{name} = ExtResource("{k}_t")')
            k += 1
        else:
            pv.append(f"shader_parameter/{name} = {v}")
    lines[0] = f'[gd_resource type="ShaderMaterial" load_steps={k} format=3]'
    lines += ["", "[resource]", 'render_priority = 0', 'shader = ExtResource("1_sh")'] + pv
    open(path, "w", newline="\n").write("\n".join(lines) + "\n")


# ------------------------------------------------------------------ static GLBs
def export(folder, spec, desc, kind="static", reused=None):
    d = os.path.join(P9, folder)
    os.makedirs(d, exist_ok=True)
    glb = os.path.join(d, spec["name"] + ".glb")
    meta = spec.pop("meta", {})
    used = GLBWriter(glb).write(spec)
    embed_images(glb)
    write_glb_import(glb, used)
    tris = sum(len(g["i"]) // 3 for c in spec["children"] if c.get("mb") is not None and "colonly" not in c["name"]
               for m_, g in c["mb"].parts.items() if m_ != COL_KEY)
    MANIFEST.append(dict(name=spec["name"], folder=folder, glb=os.path.relpath(glb, V2).replace(os.sep, "/"), triangles=tris, kind=kind,
                         materials=used, description=desc, status="new", reused=reused or []))
    return glb


def quad_spec(name, mat, w, h, plane="wall", lift=0.004, uv=(0, 0, 1, 1), extra=None):
    mb = MB()
    u0, v0, u1, v1 = uv
    if plane == "wall":            # faces +Z, bottom edge on y = 0
        pts = [V(-w / 2, 0, lift), V(w / 2, 0, lift), V(w / 2, h, lift), V(-w / 2, h, lift)]
        n = (0, 0, 1)
    else:                          # ground: faces +Y, centred, lifted to avoid z-fighting
        pts = [V(-w / 2, lift, h / 2), V(w / 2, lift, h / 2), V(w / 2, lift, -h / 2), V(-w / 2, lift, -h / 2)]
        n = (0, 1, 0)
    mb.quad(mat, *pts, n=n, uv=[(u0, v1), (u1, v1), (u1, v0), (u0, v0)])
    if extra:
        extra(mb)
    return {"name": name, "children": [{"name": name + "_Mesh", "mb": mb}]}


def cards_spec(name, mat, w, h, count=3, seed=1, radius=0.0):
    """crossed vertical cards (grass, dead foliage)"""
    mb = MB()
    rng = np.random.default_rng(seed)
    for k in range(count):
        a = math.pi * k / count + rng.random() * 0.3
        cx, cz = (rng.random() - 0.5) * radius, (rng.random() - 0.5) * radius
        dx, dz = math.cos(a) * w / 2, math.sin(a) * w / 2
        pts = [V(cx - dx, 0, cz - dz), V(cx + dx, 0, cz + dz), V(cx + dx, h, cz + dz), V(cx - dx, h, cz - dz)]
        n = np.cross(pts[1] - pts[0], pts[3] - pts[0])
        mb.quad(mat, *pts, n=tuple(n / np.linalg.norm(n)), uv=[(0, 1), (1, 1), (1, 0), (0, 0)])
    return {"name": name, "children": [{"name": name + "_Mesh", "mb": mb}]}


def branches(mb, mat, rng, base, n=7, h=0.9, spread=0.5, twist=0.0, r0=0.03):
    tips = []
    for k in range(n):
        a = 2 * math.pi * k / n + rng.random() * 0.5
        pts = [V(*base)]
        p = V(*base)
        d = np.array([math.cos(a) * spread, 1.0, math.sin(a) * spread])
        for s in range(4):
            d = d + np.array([rng.normal(0, 0.25) + twist * math.sin(a + s), rng.normal(0, 0.1), rng.normal(0, 0.25) + twist * math.cos(a + s)])
            p = p + d / np.linalg.norm(d) * h / 4 * (1 - 0.12 * s)
            pts.append(p.copy())
        mb.tube(mat, pts, r0 * (1 - 0.2 * k / n), sides=4)
        tips.append(pts[-1])
    return tips


def build_static(tex):
    reused = []
    # --- materials -------------------------------------------------------------------------------------
    M = {}
    M["streaks"] = std_mat("M_Veil_WallStreaks", tex, "T_Veil_WallStreaks")
    M["blight"] = std_mat("M_Veil_GroundBlight", tex, "T_Veil_GroundBlight", double=False)
    M["crackA"] = std_mat("M_Veil_AsphaltCracks_A", tex, "T_Veil_AsphaltCracks_A", double=False)
    M["crackB"] = std_mat("M_Veil_AsphaltCracks_B", tex, "T_Veil_AsphaltCracks_B", double=False)
    M["markD"] = std_mat("M_Veil_MarkingDamaged", tex, "T_Veil_MarkingDamaged", alpha="MASK", double=False)
    M["markX"] = std_mat("M_Veil_MarkingDistorted", tex, "T_Veil_MarkingDistorted", alpha="MASK", double=False)
    M["window"] = std_mat("M_Veil_WindowStain", tex, "T_Veil_WindowStain")
    M["growth"] = std_mat("M_Veil_Growth", tex, "T_Veil_Growth", alpha="OPAQUE", double=False, rough=0.55, repeat=True)
    M["grass"] = std_mat("M_Veil_WitheredGrass", tex, "T_Veil_WitheredGrass", alpha="MASK")
    M["symbols"] = std_mat("M_Veil_Symbols", tex, "T_Veil_Symbols", alpha="MASK", double=False)
    M["shadow"] = std_mat("M_Veil_ImpossibleShadow", tex, "T_Veil_Shadow", unshaded=True, color=(0.02, 0.02, 0.03, 0.85))
    M["shaft"] = std_mat("M_Veil_ColdLightShaft", tex, "T_Veil_LightShaft", unshaded=True, color=(0.75, 0.85, 1.0, 0.55))
    M["glow"] = std_mat("M_Veil_FluorescentGlow", tex, "T_Veil_Fluorescent", alpha="OPAQUE", double=False, emission=(0.86, 0.95, 1.0), energy=2.2, repeat=True)
    M["condens"] = std_mat("M_Veil_Condensation", tex, "T_Veil_Condensation")
    stain, residue, foliage, bark = m01("Hor_StainOrganicDark"), m01("Hor_ResidueStrange"), m01("Hor_FoliageDead"), m01("Grnd_TreeBark")
    reused += ["Pack 01 M_Hor_StainOrganicDark", "Pack 01 M_Hor_ResidueStrange", "Pack 01 M_Hor_FoliageDead", "Pack 01 M_Grnd_TreeBark"]
    # wrong-reflection material: GLB carries a plain glass texture for the browser; Godot gets the ShaderMaterial
    _reg("M_Veil_WrongReflection", png=os.path.join(V2, "01_Textures", "Architecture", "T_Arch_WindowGlassDirty.png"),
         tres="09_Horror_Atmosphere/Materials/M_Veil_WrongReflection.tres", uv=(1.0, 1.0), alpha="OPAQUE", double=False, repeat=False,
         rough=0.2, metal=0.0, pack="09")
    shader_mat_tres(os.path.join(P9, "Materials", "M_Veil_WrongReflection.tres"), f"{RES9}/Supernatural_Details/veil_wrong_reflection.gdshader",
                    {"glass_tex": RES_ROOT + "/01_Textures/Architecture/T_Arch_WindowGlassDirty.png", "noise_tex": tex["T_Veil_MistNoise"]["res"],
                     "tint": "Color(0.32, 0.38, 0.4, 1)", "strength": "0.35", "speed": "0.05"})

    # --- corruption ----------------------------------------------------------------------------------------
    C = "Corruption"
    export(C, quad_spec("CORR_WallStain_Dark", stain, 1.3, 1.1), "Dark organic wall stain overlay (Pack 01 stain texture on a wall quad).",
           reused=["Pack 01 Hor_StainOrganicDark"])
    export(C, quad_spec("CORR_WallStreaks_Dark", M["streaks"], 1.2, 2.6), "Dark streaks running down a facade from the roof line.")
    export(C, quad_spec("CORR_Residue_Strange", residue, 0.9, 0.7), "Pale viscous residue smear (Pack 01 texture on a wall quad).",
           reused=["Pack 01 Hor_ResidueStrange"])
    export(C, quad_spec("CORR_Ground_Discoloration", M["blight"], 4.0, 4.0, plane="ground"), "Unnatural drained/ashen ground patch with dark veins.")
    export(C, quad_spec("CORR_Asphalt_Cracks_A", M["crackA"], 4.0, 4.0, plane="ground", lift=0.003), "Cracked asphalt overlay, variation A (cracks + potholes).")
    export(C, quad_spec("CORR_Asphalt_Cracks_B", M["crackB"], 3.0, 5.0, plane="ground", lift=0.003), "Cracked asphalt overlay, variation B.")
    export(C, quad_spec("CORR_Marking_Damaged", M["markD"], 0.6, 3.0, plane="ground", lift=0.007), "Chipped, grimy road centre-line segments.")
    export(C, quad_spec("CORR_Marking_Distorted", M["markX"], 1.4, 2.8, plane="ground", lift=0.007), "Road arrow smeared into a slow S - subtly wrong.")
    export(C, quad_spec("CORR_Window_Discoloration", M["window"], 1.0, 1.25, lift=0.012), "Seeping damp discoloration overlay for window panes.")
    for nm, n, seed, desc in (("CORR_Organic_Growth", 9, 3, "Clustered dark organic growths for wall bases, kerbs and corners."),
                              ("CORR_Organic_Growth_Small", 4, 5, "Small cluster of dark organic growths.")):
        mb = MB()
        rng = np.random.default_rng(seed)
        for k in range(n):
            r = 0.05 + rng.random() * (0.14 if n > 5 else 0.08)
            mb.lump(M["growth"], (rng.normal(0, 0.22 if n > 5 else 0.1), r * 0.55, rng.normal(0, 0.12 if n > 5 else 0.06)), (r, r * 0.7, r * 0.9), rng,
                    subdiv=1, jitter=0.25)
        export(C, {"name": nm, "children": [{"name": nm + "_Mesh", "mb": mb}]}, desc)
    mb = MB()
    rng = np.random.default_rng(11)
    tips = branches(mb, bark, rng, (0, 0, 0), n=8, h=0.85, spread=0.55)
    for t in tips[:5]:
        mb.quad(foliage, t + V(-0.18, -0.15, 0), t + V(0.18, -0.15, 0), t + V(0.18, 0.18, 0), t + V(-0.18, 0.18, 0), n=(0, 0, 1),
                uv=[(0, 1), (1, 1), (1, 0), (0, 0)])
    export(C, {"name": "CORR_Dead_Shrub", "children": [{"name": "CORR_Dead_Shrub_Mesh", "mb": mb}]},
           "Dead shrub: bare twisted branches with a few curled dead-leaf cards (Pack 01 bark + dead foliage).", reused=["Pack 01 Grnd_TreeBark", "Hor_FoliageDead"])
    mb = MB()
    rng = np.random.default_rng(23)
    tips = branches(mb, bark, rng, (0, 0, 0), n=6, h=1.3, spread=0.35, twist=0.35, r0=0.045)
    for k, t in enumerate(tips):
        mb.lump(M["growth"], tuple(t * 0.55), (0.07, 0.05, 0.07), rng, subdiv=1, jitter=0.3)
        if k % 2 == 0:
            mb.lump(M["growth"], tuple(t), (0.05, 0.05, 0.05), rng, subdiv=1, jitter=0.3)
    mb.lump(M["growth"], (0, 0.08, 0), (0.22, 0.1, 0.2), rng, subdiv=1, jitter=0.25)
    export(C, {"name": "CORR_Corrupted_Vegetation", "children": [{"name": "CORR_Corrupted_Vegetation_Mesh", "mb": mb}]},
           "Corrupted shrub: corkscrewed branches knotted with dark growths at the joints and base.")
    export(C, cards_spec("CORR_Withered_Grass", M["grass"], 0.9, 0.45, count=4, seed=4, radius=0.3), "Withered grass clump (crossed cutout cards).")
    export(C, cards_spec("CORR_Withered_Grass_Patch", M["grass"], 1.2, 0.4, count=9, seed=8, radius=1.4), "Wider patch of withered grass cards.")

    # --- supernatural details --------------------------------------------------------------------------------
    S = "Supernatural_Details"
    export(S, quad_spec("SUP_ImpossibleShadow_Wall", M["shadow"], 0.9, 2.3, lift=0.006),
           "A tall soft shadow on a wall with nothing to cast it (abstract shape, unshaded).")
    export(S, quad_spec("SUP_ImpossibleShadow_Ground", M["shadow"], 0.9, 3.6, plane="ground", lift=0.008),
           "A long shadow stretched across the ground from nowhere.")
    export(S, quad_spec("SUP_Markings_Wall", M["symbols"], 1.0, 1.0, lift=0.008), "Abstract scratched/painted marks on a wall (no defined meaning).")
    export(S, quad_spec("SUP_Markings_Pavement", M["symbols"], 2.2, 2.2, plane="ground", lift=0.008), "The same abstract marks on pavement.")
    export(S, quad_spec("SUP_WrongReflection_Pane", "M_Veil_WrongReflection", 1.0, 1.25, lift=0.014),
           "Window/mirror pane whose reflection drifts and smears (shader in Godot; plain dirty glass in the browser).", kind="shader-driven")
    export(S, quad_spec("SUP_ColdLightShaft", M["shaft"], 1.1, 2.4, lift=0.02),
           "Cold light card that leaks from a doorway (pair with ColdLightLeak.tscn).")

    # --- lighting fixture -------------------------------------------------------------------------------------
    g = G()
    g.box(V(0, 0.03, 0), (0.22, 0.05, 1.24), "plastic_white", taper=(0.9, 0.98))
    g.box(V(0, 0.0, 0.0), (0.2, 0.012, 1.2), "steel")
    spec = finish("LGT_FluorescentFixture", g, "Lighting", "Ceiling fluorescent fixture.", col=False)
    mb = MB()
    for x in (-0.05, 0.05):
        mb.cyl(M["glow"], (0, 0, 0), 0.016, 1.12, seg=6, caps=("top", "bottom"))
    tube = MB()
    from veil_mesh.mesh import Rx, T
    for x in (-0.05, 0.05):
        tube.merge(mb, T(x, -0.01, 0.56) @ Rx(-math.pi / 2))
    spec["children"].insert(1, {"name": "LGT_FluorescentFixture_Tubes", "mb": tube})
    spec.pop("meta")
    export("Lighting", spec, "Ceiling fluorescent fixture with emissive tubes (pair with FluorescentFlicker.tscn).")

    # --- abandoned props (new geometry where nothing reusable exists; Pack 08 atlas material) ---------------
    A = "Abandoned_Props"
    g = G()                       # shopping cart, lying on its side
    Rm = np.array(rot(roll=90))
    def cart_pt(x, y, z):
        return Rm @ V(x, y, z) + V(0.45, 0, 0)
    bars = []
    for y in (0.35, 0.62, 0.9):
        bars.append([cart_pt(-0.25, y, 0.45), cart_pt(0.25, y, 0.45), cart_pt(0.3, y, -0.4), cart_pt(-0.3, y, -0.4), cart_pt(-0.25, y, 0.45)])
    for x in np.linspace(-0.28, 0.28, 6):
        bars.append([cart_pt(x, 0.35, -0.4), cart_pt(x, 0.9, -0.42)])
        bars.append([cart_pt(x * 0.9, 0.35, 0.45), cart_pt(x * 0.9, 0.9, 0.47)])
    for z in np.linspace(-0.4, 0.45, 6):
        for sx in (-1, 1):
            bars.append([cart_pt(sx * (0.3 - 0.06 * (z + 0.4)), 0.35, z), cart_pt(sx * (0.3 - 0.06 * (z + 0.4)), 0.9, z)])
    bars.append([cart_pt(-0.26, 0.95, -0.5), cart_pt(0.26, 0.95, -0.5)])
    for sx in (-1, 1):
        bars.append([cart_pt(sx * 0.25, 0.08, 0.4), cart_pt(sx * 0.25, 0.35, 0.4)])
        bars.append([cart_pt(sx * 0.28, 0.08, -0.38), cart_pt(sx * 0.28, 0.35, -0.38)])
        bars.append([cart_pt(sx * 0.26, 0.9, -0.42), cart_pt(sx * 0.26, 0.95, -0.5)])
    for b in bars:
        g.sweep(b, 0.006, "chrome", seg=4, caps=False)
    g.cyl(cart_pt(-0.26, 0.95, -0.5), cart_pt(0.26, 0.95, -0.5), 0.016, 0.016, "plastic_red", seg=8)
    for sx in (-1, 1):
        for z in (0.4, -0.38):
            c = cart_pt(sx * 0.26, 0.05, z)
            g.cyl(c + Rm @ V(-0.015, 0, 0), c + Rm @ V(0.015, 0, 0), 0.05, 0.05, "rubber", seg=10, cap_rect="plastic_gray")
    s = finish("ABN_ShoppingCart_Overturned", g, A, "Overturned shopping cart.")
    s.pop("meta")
    export(A, s, "Overturned shopping cart: wire basket, handle bar, castors (Pack 08 atlas material).", reused=["Pack 08 M_Inv_Atlas"])
    g = G()                       # spilled grocery bags
    for (x, z, yaw, tip) in ((0, 0, 10, 0), (0.42, 0.1, -25, 78)):
        R = np.array(rot(yaw=yaw, roll=tip))
        g.box(R @ V(0, 0.17, 0) + V(x, 0.0 if tip == 0 else 0.03, z), (0.3, 0.34, 0.18), "cardboard", Rm=R, skip=("+y",), taper=(1.03, 1.03))
    for k, (x, z) in enumerate(((0.75, 0.0), (0.85, 0.25), (0.62, 0.32), (0.95, -0.12))):
        R = np.array(rot(yaw=k * 47, roll=90))
        g.lathe(V(x, 0.038, z), R @ V(0, 1, 0), [(0.0, 0.035), (0.11, 0.035)], "can_label" if k % 2 == 0 else "can_label2", seg=10, cap_rect="steel")
    g.box(V(0.6, 0.012, -0.25), (0.05, 0.024, 0.13), "snack", Rm=np.array(rot(yaw=30)))
    s = finish("ABN_GroceryBags_Spilled", g, A, "Spilled grocery bags.")
    s.pop("meta")
    export(A, s, "Two paper grocery bags, one tipped over, cans and a snack rolled out (Pack 08 labels).", reused=["Pack 08 M_Inv_Atlas"])
    g = G()                       # scattered papers
    rng = np.random.default_rng(9)
    for k in range(9):
        R = np.array(rot(yaw=rng.random() * 360, pitch=rng.normal(0, 3)))
        g.box(V(rng.normal(0, 0.45), 0.001 + 0.0012 * k, rng.normal(0, 0.35)), (0.21, 0.001, 0.29), "paper_white", Rm=R,
              faces={"+y": ["note", "newspaper", "poster", "paper_old"][k % 4]})
    s = finish("ABN_ScatteredPapers", g, A, "Scattered papers.", col=False)
    s.pop("meta")
    export(A, s, "Loose papers, flyers and newspaper pages scattered on the ground (Pack 08 decals).", reused=["Pack 08 M_Inv_Atlas"])
    g = G()                       # broken window panel
    for (c, sz) in (((0, 0.04, 0), (1.0, 0.08, 0.06)), ((0, 1.21, 0), (1.0, 0.08, 0.06)), ((-0.46, 0.625, 0), (0.08, 1.25, 0.06)),
                    ((0.46, 0.625, 0), (0.08, 1.25, 0.06)), ((0, 0.625, 0), (0.04, 1.1, 0.045))):
        g.box(V(*c), sz, "wood_dark")
    for pts in (([-0.42, 0.08], [-0.02, 0.08], [-0.1, 0.5], [-0.42, 0.7]), ([0.02, 1.17], [0.42, 1.17], [0.42, 0.85], [0.2, 1.0]),
                ([0.02, 0.08], [0.25, 0.08], [0.06, 0.3])):
        g.extrude([tuple(p) for p in pts], -0.004, 0.004, V(0, 0, 0), np.eye(3), "glass_clear", "glass_clear")
    for k in range(6):
        g.box(V(-0.3 + k * 0.13, 0.004, 0.25 + (k % 3) * 0.08), (0.08, 0.004, 0.05), "glass_clear", Rm=np.array(rot(yaw=k * 33)))
    s = finish("ABN_BrokenWindowPanel", g, A, "Broken window panel.")
    s.pop("meta")
    export(A, s, "Fallen window sash with mostly smashed panes and shards on the floor.", reused=["Pack 08 M_Inv_Atlas"])
    g = G()                       # fallen bicycle (lying on its side)
    Rm = np.array(rot(roll=90))
    bp = lambda x, y, z: Rm @ V(x, y, z) + V(0.34, 0, 0)
    for zc in (0.52, -0.52):
        g.ring(bp(0, 0.34, zc), Rm @ V(1, 0, 0), 0.30, 0.34, 0.03, "rubber", rect_top="rubber", seg=18)
        for k in range(8):
            a = math.pi * k / 8
            g.sweep([bp(0, 0.34 + 0.3 * math.cos(a), zc + 0.3 * math.sin(a)), bp(0, 0.34 - 0.3 * math.cos(a), zc - 0.3 * math.sin(a))], 0.003, "steel", seg=3, caps=False)
    frame = [[bp(0, 0.34, -0.52), bp(0, 0.66, -0.25), bp(0, 0.66, 0.3), bp(0, 0.34, 0.52)], [bp(0, 0.34, -0.52), bp(0, 0.4, 0.0), bp(0, 0.66, 0.3)],
             [bp(0, 0.4, 0.0), bp(0, 0.66, -0.25)], [bp(0, 0.66, -0.25), bp(0, 0.78, -0.3)], [bp(0, 0.66, 0.3), bp(0, 0.86, 0.36)]]
    for f in frame:
        g.sweep(f, 0.016, "plastic_blue", seg=5)
    g.box(bp(0, 0.8, -0.3), (0.1, 0.04, 0.22), "leather_black")
    g.cyl(bp(-0.24, 0.88, 0.36), bp(0.24, 0.88, 0.36), 0.012, 0.012, "steel", seg=6, cap_rect="rubber_grip")
    s = finish("ABN_FallenBicycle", g, A, "Fallen bicycle.")
    s.pop("meta")
    export(A, s, "Bicycle dropped on its side: two spoked wheels, blue frame, saddle, handlebars.", reused=["Pack 08 M_Inv_Atlas"])
    return M, reused


# ------------------------------------------------------------------ scenes
def particles(t, name, parent, mat_props, amount, lifetime, box, quad=(1, 1), props=None, groups=None, tex=None, extra=None):
    mp = dict(mat_props)
    mp["albedo_texture"] = t.e(tex, "Texture2D")
    m = t.s("StandardMaterial3D", mp)
    q = t.s("QuadMesh", {"material": m, "size": f"Vector2({fnum(quad[0])}, {fnum(quad[1])})"})
    p = {"amount": str(amount), "lifetime": fnum(lifetime), "preprocess": fnum(lifetime), "mesh": q, "emission_shape": "3",
         "emission_box_extents": f"Vector3({fnum(box[0])}, {fnum(box[1])}, {fnum(box[2])})"}
    p.update(props or {})
    t.n(name, "CPUParticles3D", parent, p, groups=groups)


def fade_ramp(t, peak=1.0):
    return t.s("Gradient", {"offsets": "PackedFloat32Array(0, 0.2, 0.8, 1)",
                            "colors": f"PackedColorArray(1, 1, 1, 0, 1, 1, 1, {fnum(peak)}, 1, 1, 1, {fnum(peak)}, 1, 1, 1, 0)"})


def build_scenes(tex, M):
    out = []
    noise = tex["T_Veil_MistNoise"]["res"]
    # ---- Veil mist ---------------------------------------------------------------------------------------
    t = Tscn("VeilMist", script=f"{RES9}/Fog/veil_mist.gd")
    sh = t.e(f"{RES9}/Fog/veil_mist_layer.gdshader", "Shader")
    nz = t.e(noise, "Texture2D")
    t.n("Layers", "Node3D")
    for k, (sc, ff) in enumerate(((0.05, 55.0), (0.035, 50.0), (0.025, 45.0))):
        m = t.s("ShaderMaterial", {"render_priority": str(k), "shader": sh, "shader_parameter/noise_tex": nz, "shader_parameter/noise_scale": fnum(sc),
                                   "shader_parameter/far_fade": fnum(ff), "shader_parameter/density": "0.6"})
        pm = t.s("PlaneMesh", {"size": "Vector2(110, 110)"})
        t.n(f"Layer{k}", "MeshInstance3D", "Layers", {"transform": xf(0, 0.4 + k * 0.5, 0), "mesh": pm, "material_override": m,
                                                       "cast_shadow": "0", "extra_cull_margin": "4.0"})
    particles(t, "FogCards", ".", particle_mat(tex, "T_Veil_FogCard", color=(0.62, 0.66, 0.64, 0.35)), 16, 24.0, (28, 1.2, 28), quad=(1, 1),
              tex=tex["T_Veil_FogCard"]["res"],
              props={"transform": xf(0, 0.8, 0), "direction": "Vector3(1, 0, 0.3)", "spread": "180.0", "gravity": "Vector3(0, 0, 0)",
                     "initial_velocity_min": "0.15", "initial_velocity_max": "0.5", "scale_amount_min": "6.0", "scale_amount_max": "11.0",
                     "color_ramp": fade_ramp(t, 1.0), "cast_shadow": "0"})
    p = os.path.join(P9, "Fog", "VeilMist.tscn")
    t.write(p, {"density": "0.6", "cards": "16"})
    out.append(p)
    # ---- local fog patch ------------------------------------------------------------------------------------
    t = Tscn("VeilFogPatch", script=f"{RES9}/Fog/veil_mist.gd")
    sh = t.e(f"{RES9}/Fog/veil_mist_layer.gdshader", "Shader")
    nz = t.e(noise, "Texture2D")
    t.n("Layers", "Node3D")
    for k in range(2):
        m = t.s("ShaderMaterial", {"render_priority": str(k), "shader": sh, "shader_parameter/noise_tex": nz, "shader_parameter/noise_scale": "0.12",
                                   "shader_parameter/far_fade": "7.0", "shader_parameter/near_fade": "1.0", "shader_parameter/near_full": "4.0"})
        t.n(f"Layer{k}", "MeshInstance3D", "Layers", {"mesh": t.s("PlaneMesh", {"size": "Vector2(14, 14)"}), "material_override": m, "cast_shadow": "0"})
    particles(t, "FogCards", ".", particle_mat(tex, "T_Veil_FogCard", color=(0.62, 0.66, 0.64, 0.35)), 6, 18.0, (5, 0.6, 5), tex=tex["T_Veil_FogCard"]["res"],
              props={"spread": "180.0", "gravity": "Vector3(0, 0, 0)", "initial_velocity_min": "0.05", "initial_velocity_max": "0.2",
                     "scale_amount_min": "3.0", "scale_amount_max": "5.0", "color_ramp": fade_ramp(t, 1.0), "cast_shadow": "0"})
    p = os.path.join(P9, "Fog", "VeilFogPatch.tscn")
    t.write(p, {"density": "0.7", "height": "1.0", "cards": "6", "follow_camera": "false"})
    out.append(p)
    # ---- mist boundary -------------------------------------------------------------------------------------
    sh_path = f"{RES9}/Fog/veil_mist_boundary.gdshader"
    t = Tscn("VeilMistBoundary")
    m = t.s("ShaderMaterial", {"shader": t.e(sh_path, "Shader"), "shader_parameter/noise_tex": t.e(noise, "Texture2D"), "shader_parameter/curtain_height": "14.0"})
    cyl = t.s("CylinderMesh", {"top_radius": "40.0", "bottom_radius": "40.0", "height": "14.0", "radial_segments": "32", "rings": "1",
                                "cap_top": "false", "cap_bottom": "false"})
    t.n("Curtain", "MeshInstance3D", ".", {"transform": xf(0, 7, 0), "mesh": cyl, "material_override": m, "cast_shadow": "0"})
    p = os.path.join(P9, "Fog", "VeilMistBoundary.tscn")
    t.write(p, {"metadata/note": '"Scale X/Z to resize the ring (radius 40 m at scale 1). Marks where the Veil begins."'})
    out.append(p)
    shader_mat_tres(os.path.join(P9, "Materials", "M_Veil_MistLayer.tres"), f"{RES9}/Fog/veil_mist_layer.gdshader", {"noise_tex": noise, "density": "0.6"})
    shader_mat_tres(os.path.join(P9, "Materials", "M_Veil_MistBoundary.tres"), sh_path, {"noise_tex": noise, "curtain_height": "14.0"})

    # ---- lights with flicker ------------------------------------------------------------------------------------
    fl = f"{RES9}/Lighting/veil_flicker.gd"
    lamp = RES_ROOT + "/02_Town/Street_Props/SP_Lamp_Residential.glb"
    for name, mode, colr, energy, glb, y, extra in (
            ("FlickerStreetlight", 1, (1.0, 0.8, 0.55), 1.4, lamp, 4.85, {}),
            ("DimStreetlight", 4, (0.75, 0.8, 0.9), 0.45, lamp, 4.85, {}),
            ("FluorescentFlicker", 2, (0.86, 0.95, 1.0), 1.1, f"{RES9}/Lighting/LGT_FluorescentFixture.glb", -0.05, {"ceiling": True})):
        t = Tscn(name)
        t.n("Fixture", None, ".", {}, instance=t.e(glb, "PackedScene"))
        lp = {"transform": xf(0, y, 0), "light_color": col(colr), "light_energy": fnum(energy), "omni_range": "11.0" if "Street" in name else "7.0",
              "omni_attenuation": "1.4", "shadow_enabled": "false", "distance_fade_enabled": "true", "distance_fade_begin": "40.0", "distance_fade_length": "15.0"}
        t.n("Light", "OmniLight3D", ".", lp)
        t.n("Flicker", "Node", "Light", {"script": t.e(fl, "Script"), "mode": str(mode), "seed": str(len(name))})
        p = os.path.join(P9, "Lighting", name + ".tscn")
        t.write(p)
        out.append(p)
    t = Tscn("ColdLightLeak")
    t.n("Shaft", None, ".", {"transform": xf(0, 0, 0.3)}, instance=t.e(f"{RES9}/Supernatural_Details/SUP_ColdLightShaft.glb", "PackedScene"))
    t.n("Light", "SpotLight3D", ".", {"transform": xf(0, 1.9, -0.2, pitch=-35), "light_color": col((0.62, 0.74, 1.0)), "light_energy": "1.6",
                                      "spot_range": "7.0", "spot_angle": "38.0", "shadow_enabled": "false"})
    t.n("Flicker", "Node", "Light", {"script": t.e(fl, "Script"), "mode": "4", "seed": "5"})
    p = os.path.join(P9, "Supernatural_Details", "ColdLightLeak.tscn")
    t.write(p, {"metadata/note": '"Place in a doorway facing out (+Z); cold light breathing from a room that should be dark."'})
    out.append(p)

    # ---- environmental effects -------------------------------------------------------------------------------------
    FX = "Environmental_Effects"
    specs = [
        ("DustMotes", "T_Veil_Dust", dict(), 40, 8.0, (3, 1.5, 3), (1, 1), {"transform": xf(0, 1.6, 0), "spread": "180.0", "gravity": "Vector3(0, 0.02, 0)",
         "initial_velocity_min": "0.02", "initial_velocity_max": "0.08", "scale_amount_min": "0.015", "scale_amount_max": "0.035"}, ["veil_dust"], 0.8),
        ("DriftingLeaves", "T_Veil_Leaves", dict(frames=4), 24, 9.0, (10, 2.5, 10), (1, 1), {"transform": xf(0, 3, 0), "direction": "Vector3(1, 0, 0.25)",
         "spread": "25.0", "gravity": "Vector3(0, -0.45, 0)", "initial_velocity_min": "0.5", "initial_velocity_max": "1.4", "angular_velocity_min": "-90.0",
         "angular_velocity_max": "90.0", "scale_amount_min": "0.1", "scale_amount_max": "0.18", "anim_offset_max": "1.0"}, ["veil_leaves"], 1.0),
        ("LightRain", "T_Veil_Rain", dict(yaxis=True), 300, 1.1, (12, 0.5, 12), (0.02, 0.55), {"transform": xf(0, 9, 0), "direction": "Vector3(0.08, -1, 0)",
         "spread": "3.0", "gravity": "Vector3(0, -2, 0)", "initial_velocity_min": "9.0", "initial_velocity_max": "11.0"}, ["veil_rain"], 0.7),
        ("DrippingWater", "T_Veil_Drip", dict(), 5, 1.3, (0.3, 0.02, 0.3), (1, 1), {"spread": "0.0", "direction": "Vector3(0, -1, 0)",
         "gravity": "Vector3(0, -9.8, 0)", "initial_velocity_min": "0.0", "initial_velocity_max": "0.2", "scale_amount_min": "0.025", "scale_amount_max": "0.035"},
         None, 1.0),
        ("ElectricalSparks", "T_Veil_Spark", dict(additive=True), 28, 0.6, (0.05, 0.05, 0.05), (1, 1), {"explosiveness": "0.85", "direction": "Vector3(0, 0.5, 1)",
         "spread": "55.0", "gravity": "Vector3(0, -9.8, 0)", "initial_velocity_min": "1.5", "initial_velocity_max": "4.0", "scale_amount_min": "0.02",
         "scale_amount_max": "0.045"}, None, 1.0),
        ("DistantMist", "T_Veil_FogCard", dict(color=(0.6, 0.64, 0.64, 0.4)), 24, 40.0, (60, 3, 60), (1, 1), {"transform": xf(0, 3, 0), "spread": "180.0",
         "gravity": "Vector3(0, 0, 0)", "initial_velocity_min": "0.2", "initial_velocity_max": "0.6", "scale_amount_min": "14.0", "scale_amount_max": "24.0"},
         None, 1.0),
    ]
    for name, tk, mk, amount, life, box, quad, props, groups, peak in specs:
        t = Tscn(name)
        props = dict(props)
        props["color_ramp"] = fade_ramp(t, peak)
        props["cast_shadow"] = "0"
        particles(t, "Particles", ".", particle_mat(tex, tk, **mk), amount, life, box, quad=quad, props=props, groups=groups, tex=tex[tk]["res"])
        if name == "ElectricalSparks":
            t.n("SparkLight", "OmniLight3D", ".", {"light_color": col((0.7, 0.85, 1.0)), "light_energy": "1.2", "omni_range": "3.5", "shadow_enabled": "false"})
            t.n("Flicker", "Node", "SparkLight", {"script": t.e(fl, "Script"), "mode": "2", "seed": "9"})
        p = os.path.join(P9, FX, name + ".tscn")
        t.write(p)
        out.append(p)
    t = Tscn("WindowCondensation")
    t.n("Glass", "MeshInstance3D", ".", {"transform": xf(0, 0.625, 0.01), "mesh": t.s("QuadMesh", {"size": "Vector2(1, 1.25)"}),
                                          "material_override": t.e(res(os.path.join(V2, MATS[M["condens"]]["tres"])), "Material"), "cast_shadow": "0"})
    p = os.path.join(P9, FX, "WindowCondensation.tscn")
    t.write(p)
    out.append(p)
    t = Tscn("Puddles_Dripping")
    for k, (g_, x, z, yaw) in enumerate((("RD_Puddle_A", 0, 0, 0), ("RD_Puddle_B", 1.6, 0.7, 40))):
        t.n(f"Puddle{k}", None, ".", {"transform": xf(x, 0, z, yaw=yaw)}, instance=t.e(RES_ROOT + f"/02_Town/Roads/{g_}.glb", "PackedScene"))
    t.n("Drip", None, ".", {"transform": xf(0.2, 3.0, 0.1)}, instance=t.e(res(os.path.join(P9, FX, "DrippingWater.tscn")), "PackedScene"))
    p = os.path.join(P9, FX, "Puddles_Dripping.tscn")
    t.write(p)
    out.append(p)

    # ---- abandoned arrangements reusing Packs 02 / 03 / 08 ------------------------------------------------------
    A = "Abandoned_Props"
    sp = RES_ROOT + "/02_Town/Street_Props/"
    reuse = {
        "ABN_FallenStreetSign": [("SP_Sign_Stop", sp + "SP_Sign_Stop.glb", xf(0, 0.06, 0, yaw=20, pitch=-88))],
        "ABN_DamagedStreetlight": [("Lamp", sp + "SP_Lamp_Residential.glb", xf(0, 0, 0, roll=14))],
        "ABN_EmptyBarricade": [("Barrier", sp + "SP_RoadBarrier.glb", xf(0, 0.37, 0, pitch=-90)), ("Barrier2", sp + "SP_RoadBarrier.glb", xf(2.2, 0, 0.4, yaw=-25))],
        "ABN_RoadCones_Abandoned": [("Cone0", sp + "SP_TrafficCone.glb", xf(0, 0.17, 0, yaw=30, roll=90)), ("Cone1", sp + "SP_TrafficCone.glb", xf(0.9, 0, 0.4)),
                                    ("Cone2", sp + "SP_TrafficCone.glb", xf(1.5, 0.17, -0.3, yaw=-70, roll=90))],
        "ABN_BrokenElectricalBox": [("Cabinet", RES_ROOT + "/02_Town/Utilities/UT_ElectricalCabinet.glb", xf(0, 0, 0, yaw=0, roll=3))],
        "ABN_DisplacedFurniture": [("Sofa", RES_ROOT + "/03_Residential/Furniture/RES_Sofa_Plaid.glb", xf(0, 0, 0, yaw=37)),
                                   ("Chair", RES_ROOT + "/03_Residential/Furniture/RES_DiningChair_Wood.glb", xf(1.4, 0.23, 0.6, yaw=-20, pitch=-90)),
                                   ("Lamp", RES_ROOT + "/03_Residential/Furniture/RES_Lamp_Floor.glb", xf(-1.1, 0.12, 0.8, yaw=60, roll=86)),
                                   ("Bin", RES_ROOT + "/03_Residential/Furniture/RES_TrashCan_Pedal.glb", xf(0.7, 0.13, -0.9, roll=90))],
        "ABN_PersonalBelongings": [(n, RES_ROOT + f"/08_Inventory/{f}/{n}.glb", xf(x, 0, z, yaw=yw)) for n, f, x, z, yw in (
            ("INV_SmallBackpack", "Food_And_Supplies", 0, 0, 80), ("INV_Wallet", "Story_Items", 0.45, 0.2, 30), ("INV_Keyring", "Story_Items", 0.35, -0.25, -40),
            ("INV_FoldedNote", "Story_Items", -0.4, 0.3, 15), ("INV_Photograph", "Puzzle_Items", -0.25, -0.35, -60), ("INV_WaterBottle", "Food_And_Supplies", 0.6, -0.05, 0))],
    }
    for name, items in reuse.items():
        t = Tscn(name)
        for nn, path, tr in items:
            t.n(nn, None, ".", {"transform": tr}, instance=t.e(path, "PackedScene"))
        if name == "ABN_DamagedStreetlight":
            t.n("Light", "OmniLight3D", ".", {"transform": xf(1.17, 4.7, 0), "light_color": col((1.0, 0.78, 0.5)), "light_energy": "1.0",
                                              "omni_range": "9.0", "shadow_enabled": "false"})
            t.n("Flicker", "Node", "Light", {"script": t.e(fl, "Script"), "mode": "3", "seed": "3"})
        if name == "ABN_BrokenElectricalBox":
            t.n("Sparks", None, ".", {"transform": xf(0.3, 1.1, 0.36)}, instance=t.e(res(os.path.join(P9, FX, "ElectricalSparks.tscn")), "PackedScene"))
        p = os.path.join(P9, A, name + ".tscn")
        t.write(p, {"metadata/reuses": '"' + ", ".join(sorted({os.path.basename(x[1]) for x in items})) + '"'})
        out.append(p)
    return out


# ------------------------------------------------------------------ presets + rig
PRESETS = {   # name: values (anything not given keeps the VeilAtmospherePreset default = normal evening)
    "STATE_NORMAL": dict(preset_name="NORMAL - ordinary Friday evening"),
    "STATE_UNEASY": dict(preset_name="UNEASY", sky_top=(0.14, 0.16, 0.26), sky_horizon=(0.52, 0.38, 0.34), ambient_color=(0.36, 0.36, 0.42),
                         ambient_energy=0.45, sun_energy=0.35, sun_pitch=-4.0, fog_color=(0.48, 0.47, 0.5), fog_density=0.008, mist_enabled=True,
                         mist_density=0.15, mist_height=0.8, mist_cards=4, flicker_amount=0.15, streetlight_energy=0.95, leaves=True),
    "STATE_VEIL_APPROACHING": dict(preset_name="VEIL_APPROACHING", sky_top=(0.12, 0.13, 0.16), sky_horizon=(0.38, 0.4, 0.42), ground_horizon=(0.3, 0.32, 0.33),
                                   ambient_color=(0.34, 0.36, 0.4), ambient_energy=0.42, sun_color=(0.7, 0.72, 0.78), sun_energy=0.22, sun_pitch=-3.0,
                                   fog_color=(0.5, 0.53, 0.55), fog_density=0.02, fog_sky_affect=0.7, mist_enabled=True, mist_density=0.45,
                                   mist_height=1.4, mist_speed=1.3, mist_cards=12, flicker_amount=0.35, streetlight_energy=0.85, corruption_level=1),
    "STATE_VEIL_ACTIVE": dict(preset_name="VEIL_ACTIVE", sky_top=(0.2, 0.22, 0.24), sky_horizon=(0.42, 0.45, 0.46), ground_horizon=(0.38, 0.41, 0.42),
                              ambient_color=(0.36, 0.39, 0.42), ambient_energy=0.46, sun_color=(0.62, 0.66, 0.72), sun_energy=0.12, sun_shadows=False,
                              fog_color=(0.52, 0.56, 0.57), fog_density=0.055, fog_height=4.0, fog_height_density=0.08, fog_sky_affect=1.0,
                              mist_enabled=True, mist_color=(0.6, 0.64, 0.64), mist_density=0.8, mist_height=2.2, mist_speed=1.0, mist_cards=24,
                              flicker_amount=0.6, streetlight_energy=0.7, corruption_level=2),
    "STATE_CORRUPTED": dict(preset_name="CORRUPTED", sky_top=(0.08, 0.08, 0.1), sky_horizon=(0.22, 0.21, 0.24), ground_horizon=(0.16, 0.15, 0.17),
                            ground_bottom=(0.04, 0.04, 0.05), ambient_color=(0.3, 0.29, 0.34), ambient_energy=0.38, sun_color=(0.55, 0.5, 0.6),
                            sun_energy=0.08, sun_shadows=False, fog_color=(0.3, 0.3, 0.34), fog_density=0.04, fog_sky_affect=1.0, mist_enabled=True,
                            mist_color=(0.42, 0.42, 0.46), mist_density=0.6, mist_height=1.2, mist_speed=0.6, mist_cards=16, flicker_amount=0.85,
                            streetlight_energy=0.5, window_glow=0.2, corruption_level=3, dust=True),
    "LGT_Ordinary_Evening": dict(preset_name="Ordinary evening (6:42 PM)"),
    "LGT_Night_Residential": dict(preset_name="Night residential street", sky_top=(0.04, 0.05, 0.1), sky_horizon=(0.12, 0.13, 0.2), ground_horizon=(0.08, 0.08, 0.1),
                                  ambient_color=(0.3, 0.33, 0.42), ambient_energy=0.42, sun_color=(0.55, 0.62, 0.85), sun_energy=0.18, sun_pitch=-40.0,
                                  sun_yaw=140.0, fog_color=(0.12, 0.13, 0.18), fog_density=0.006, streetlight_energy=1.15),
    "LGT_Empty_Supermarket": dict(preset_name="Empty supermarket (interior)", background_is_sky=False, background_color=(0.03, 0.03, 0.035),
                                  ambient_color=(0.55, 0.6, 0.6), ambient_energy=0.5, sun_energy=0.0, sun_shadows=False, fog_color=(0.3, 0.32, 0.32),
                                  fog_density=0.012, flicker_amount=0.3),
    "LGT_Dark_Video_Game_Shop": dict(preset_name="Dark video game shop (interior)", background_is_sky=False, background_color=(0.02, 0.02, 0.03),
                                     ambient_color=(0.3, 0.3, 0.42), ambient_energy=0.38, sun_energy=0.0, sun_shadows=False, fog_color=(0.08, 0.08, 0.12),
                                     fog_density=0.01, flicker_amount=0.4, streetlight_energy=0.8),
    "LGT_Abandoned_House": dict(preset_name="Abandoned house (interior)", background_is_sky=False, background_color=(0.02, 0.02, 0.02),
                                ambient_color=(0.34, 0.32, 0.3), ambient_energy=0.36, sun_color=(0.55, 0.6, 0.7), sun_energy=0.1, sun_pitch=-30.0,
                                fog_color=(0.16, 0.15, 0.14), fog_density=0.02, dust=True, corruption_level=1),
    "LGT_Mist_Roadway": dict(preset_name="Mist-covered roadway", sky_top=(0.18, 0.2, 0.22), sky_horizon=(0.44, 0.47, 0.48), ambient_color=(0.38, 0.4, 0.43),
                             ambient_energy=0.5, sun_color=(0.68, 0.7, 0.76), sun_energy=0.15, sun_shadows=False, fog_color=(0.54, 0.57, 0.58),
                             fog_density=0.045, fog_sky_affect=1.0, mist_enabled=True, mist_density=0.7, mist_height=1.8, mist_cards=20,
                             flicker_amount=0.4, streetlight_energy=0.8),
    "LGT_Corrupted_Neighborhood": dict(preset_name="Corrupted neighbourhood", sky_top=(0.1, 0.09, 0.12), sky_horizon=(0.26, 0.24, 0.27),
                                       ambient_color=(0.32, 0.3, 0.36), ambient_energy=0.4, sun_color=(0.6, 0.52, 0.62), sun_energy=0.1, sun_shadows=False,
                                       fog_color=(0.3, 0.29, 0.33), fog_density=0.03, mist_enabled=True, mist_color=(0.44, 0.43, 0.47), mist_density=0.45,
                                       mist_height=1.0, mist_cards=10, flicker_amount=0.8, streetlight_energy=0.55, corruption_level=3, dust=True),
    "LGT_Deep_Veil": dict(preset_name="Deep supernatural mist", sky_top=(0.3, 0.32, 0.33), sky_horizon=(0.46, 0.49, 0.5), ground_horizon=(0.44, 0.47, 0.48),
                          ambient_color=(0.42, 0.45, 0.47), ambient_energy=0.5, sun_energy=0.0, sun_shadows=False, fog_color=(0.56, 0.59, 0.6),
                          fog_density=0.09, fog_height=6.0, fog_height_density=0.12, fog_sky_affect=1.0, mist_enabled=True, mist_color=(0.64, 0.68, 0.68),
                          mist_density=0.95, mist_height=2.8, mist_speed=0.8, mist_cards=32, flicker_amount=0.7, streetlight_energy=0.6, corruption_level=2),
}


def preset_tres(path, vals):
    script = f"{RES9}/Atmosphere_Presets/veil_atmosphere_preset.gd"
    lines = ['[gd_resource type="Resource" script_class="VeilAtmospherePreset" load_steps=2 format=3]', "",
             f'[ext_resource type="Script" path="{script}" id="1_s"]', "", "[resource]", 'script = ExtResource("1_s")']
    for k, v in vals.items():
        if isinstance(v, tuple):
            lines.append(f"{k} = {col(v)}")
        elif isinstance(v, bool):
            lines.append(f"{k} = {'true' if v else 'false'}")
        elif isinstance(v, str):
            lines.append(f'{k} = "{v}"')
        else:
            lines.append(f"{k} = {fnum(v) if isinstance(v, float) else v}")
    open(path, "w", newline="\n").write("\n".join(lines) + "\n")


def build_presets_and_rig():
    d = os.path.join(P9, "Atmosphere_Presets")
    for name, vals in PRESETS.items():
        preset_tres(os.path.join(d, name + ".tres"), vals)
    env = os.path.join(d, "ENV_Veil_Base.tres")
    open(env, "w", newline="\n").write("""[gd_resource type="Environment" load_steps=3 format=3]

[sub_resource type="ProceduralSkyMaterial" id="ProceduralSkyMaterial_1"]
sky_top_color = Color(0.2, 0.24, 0.38, 1)
sky_horizon_color = Color(0.78, 0.52, 0.36, 1)
ground_bottom_color = Color(0.08, 0.08, 0.09, 1)
ground_horizon_color = Color(0.32, 0.28, 0.26, 1)
sun_angle_max = 20.0

[sub_resource type="Sky" id="Sky_1"]
sky_material = SubResource("ProceduralSkyMaterial_1")
radiance_size = 0

[resource]
background_mode = 2
sky = SubResource("Sky_1")
ambient_light_source = 2
ambient_light_color = Color(0.42, 0.4, 0.44, 1)
ambient_light_energy = 0.55
reflected_light_source = 1
tonemap_mode = 0
fog_enabled = true
fog_light_color = Color(0.55, 0.5, 0.5, 1)
fog_density = 0.004
fog_sky_affect = 0.4
""")
    t = Tscn("VeilAtmosphereRig")
    t.n("WorldEnvironment", "WorldEnvironment", ".", {"environment": t.e(res(env), "Environment")})
    t.n("Sun", "DirectionalLight3D", ".", {"transform": xf(0, 30, 0, yaw=225, pitch=-8), "light_color": col((1.0, 0.66, 0.42)), "light_energy": "0.6",
                                           "shadow_enabled": "true", "directional_shadow_mode": "0", "directional_shadow_max_distance": "45.0"})
    t.n("Mist", None, ".", {}, instance=t.e(f"{RES9}/Fog/VeilMist.tscn", "PackedScene"))
    for nm, scene, grp in (("Rain", "LightRain", "veil_rain"), ("Dust", "DustMotes", "veil_dust"), ("Leaves", "DriftingLeaves", "veil_leaves")):
        t.n(nm, None, "Mist", {}, instance=t.e(f"{RES9}/Environmental_Effects/{scene}.tscn", "PackedScene"), groups=[grp])
    states = ", ".join(t.e(f"{RES9}/Atmosphere_Presets/{s}.tres", "Resource") for s in
                       ("STATE_NORMAL", "STATE_UNEASY", "STATE_VEIL_APPROACHING", "STATE_VEIL_ACTIVE", "STATE_CORRUPTED"))
    t.n("Atmosphere", "Node", ".", {"script": t.e(f"{RES9}/Atmosphere_Presets/veil_atmosphere.gd", "Script"),
                                    "states": f"[{states}]", "world_environment": 'NodePath("../WorldEnvironment")', "sun": 'NodePath("../Sun")',
                                    "mist": 'NodePath("../Mist")'})
    rig = os.path.join(P9, "Godot_Scenes", "VeilAtmosphere.tscn")
    t.write(rig)
    # demo: Pack 02 town + Pack 03 houses + rig + a little set dressing near the player's street
    t = Tscn("Greyhaven_Veil_Demo")
    t.n("Town", None, ".", {}, instance=t.e(RES_ROOT + "/03_Residential/Residential_Scenes/Greyhaven_Town_With_Houses.tscn", "PackedScene"))
    t.n("VeilAtmosphere", None, ".", {}, instance=t.e(res(rig), "PackedScene"))
    t.n("Boundary", None, ".", {"transform": xf(30, 0, -60, s=2.2)}, instance=t.e(f"{RES9}/Fog/VeilMistBoundary.tscn", "PackedScene"),
        groups=["veil_corruption"])
    t.nodes[-1] += "\nmetadata/veil_level = 1"
    dressing = [("CORR_Asphalt_Cracks_A", "Corruption", 22, -104, 0, 1), ("CORR_Marking_Damaged", "Corruption", 0, -104, 90, 1),
                ("CORR_Ground_Discoloration", "Corruption", 38, -84, 0, 2), ("CORR_Corrupted_Vegetation", "Corruption", 23, -95, 0, 2),
                ("CORR_Withered_Grass_Patch", "Corruption", 26, -95.5, 30, 1), ("CORR_Dead_Shrub", "Corruption", 40, -95, 0, 1),
                ("CORR_Organic_Growth", "Corruption", 36.8, -96.5, 0, 3), ("SUP_Markings_Pavement", "Supernatural_Details", 12, -104, 15, 3),
                ("SUP_ImpossibleShadow_Ground", "Supernatural_Details", 31, -102, 70, 3)]
    for k, (nm, f, x, z, yaw, lvl) in enumerate(dressing):
        t.n(f"{nm}_{k}", None, ".", {"transform": xf(x, 0.15, z, yaw=yaw)}, instance=t.e(f"{RES9}/{f}/{nm}.glb", "PackedScene"), groups=["veil_corruption"])
        t.nodes[-1] += f"\nmetadata/veil_level = {lvl}"
    for k, (nm, f, x, z, yaw, lvl) in enumerate((("ABN_ShoppingCart_Overturned", "Abandoned_Props", 20, -101, 40, 2),
                                                   ("ABN_GroceryBags_Spilled", "Abandoned_Props", 33.5, -97, -20, 2),
                                                   ("ABN_FallenBicycle", "Abandoned_Props", 45, -98.5, 75, 2),
                                                   ("ABN_RoadCones_Abandoned", "Abandoned_Props", 5, -101, 0, 2))):
        ext = ".glb" if nm.startswith(("ABN_Shopping", "ABN_Grocery", "ABN_Fallen")) else ".tscn"
        t.n(f"{nm}_{k}", None, ".", {"transform": xf(x, 0.15, z, yaw=yaw)}, instance=t.e(f"{RES9}/{f}/{nm}{ext}", "PackedScene"), groups=["veil_corruption"])
        t.nodes[-1] += f"\nmetadata/veil_level = {lvl}"
    t.n("Camera", "Camera3D", ".", {"transform": xf(31, 1.75, -100, yaw=180), "current": "true", "far": "400.0"})
    t.write(os.path.join(P9, "Godot_Scenes", "Greyhaven_Veil_Demo.tscn"))
    return rig


def main():
    tex = build_textures()
    # Pack 08 atlas material must be registered for props that reuse it
    _reg("M_Inv_Atlas", png=os.path.join(V2, "08_Inventory", "Textures", "T_Inv_Atlas.png"), tres="08_Inventory/Shared_Materials/M_Inv_Atlas.tres",
         uv=(1.0, 1.0), alpha="OPAQUE", double=False, repeat=False, rough=0.8, metal=0.0, pack="08")
    M, reused = build_static(tex)
    scenes = build_scenes(tex, M)
    build_presets_and_rig()
    import json
    doc = os.path.join(P9, "Documentation")
    os.makedirs(doc, exist_ok=True)
    json.dump({"pack": "THE VEIL - Pack 09 Horror Atmosphere", "glbs": MANIFEST, "textures": {k: {"file": os.path.relpath(v["path"], V2), "size": v["size"]}
              for k, v in tex.items()}, "scenes": [os.path.relpath(p, V2) for p in scenes], "presets": list(PRESETS), "reused_materials": reused},
              open(os.path.join(doc, "ATMOSPHERE_MANIFEST.json"), "w", newline="\n"), indent=1)
    print(f"{len(tex)} textures, {len(MANIFEST)} GLBs, {len(scenes)} effect/prop scenes, {len(PRESETS)} presets")


if __name__ == "__main__":
    main()
