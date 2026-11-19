"""Minimal, spec-compliant glTF 2.0 binary (GLB) + OBJ/MTL writers.

Collision follows Godot's import naming: a node named "<x>-colonly" becomes a
StaticBody3D with a trimesh shape (mesh removed); "-convcolonly" becomes a
convex shape. Collision meshes carry no material.
"""
import hashlib
import json
import math
import os
import struct

import numpy as np

from .materials import MATS, RES_ROOT, V2

COL_KEY = "__collision__"


def _pad(b, ch=b"\x00"):
    return b + ch * ((4 - len(b) % 4) % 4)


def yaw_quat(a):
    return [0.0, math.sin(a / 2), 0.0, math.cos(a / 2)]


class GLBWriter:
    def __init__(self, glb_path):
        self.path = glb_path
        self.dir = os.path.dirname(glb_path)
        self.bin = bytearray()
        self.j = {"asset": {"version": "2.0", "generator": "THE VEIL veil_mesh (Pack 02)"},
                  "scene": 0, "scenes": [{"nodes": []}], "nodes": [], "meshes": [], "accessors": [],
                  "bufferViews": [], "buffers": []}
        self.mat_index = {}
        self.tex_index = {}
        self.img_index = {}
        self.samplers = {}
        self.used_mats = []
        self.uses_transform = False

    # -- buffers ---------------------------------------------------------------
    def _view(self, data, target):
        off = len(self.bin)
        self.bin += _pad(data)
        self.j["bufferViews"].append({"buffer": 0, "byteOffset": off, "byteLength": len(data), "target": target})
        return len(self.j["bufferViews"]) - 1

    def _acc(self, arr, comp, typ, target, minmax=False):
        arr = np.ascontiguousarray(arr)
        v = self._view(arr.tobytes(), target)
        a = {"bufferView": v, "componentType": comp, "count": int(arr.shape[0]), "type": typ}
        if minmax:
            a["min"] = [float(x) for x in arr.min(0)]
            a["max"] = [float(x) for x in arr.max(0)]
        self.j["accessors"].append(a)
        return len(self.j["accessors"]) - 1

    # -- materials ---------------------------------------------------------------
    def _sampler(self, repeat):
        key = repeat
        if key not in self.samplers:
            wrap = 10497 if repeat else 33071
            self.j.setdefault("samplers", []).append({"magFilter": 9728, "minFilter": 9986, "wrapS": wrap, "wrapT": wrap})
            self.samplers[key] = len(self.j["samplers"]) - 1
        return self.samplers[key]

    def _material(self, name):
        if name in self.mat_index:
            return self.mat_index[name]
        s = MATS[name]
        m = {"name": name, "pbrMetallicRoughness": {"metallicFactor": float(s["metal"]), "roughnessFactor": float(s["rough"])}}
        if "color" in s:
            m["pbrMetallicRoughness"]["baseColorFactor"] = [float(c) for c in s["color"]]
        if s.get("png"):
            uri = os.path.relpath(s["png"], self.dir).replace(os.sep, "/")
            if uri not in self.img_index:
                self.j.setdefault("images", []).append({"uri": uri})
                self.img_index[uri] = len(self.j["images"]) - 1
            tkey = (uri, s["repeat"])
            if tkey not in self.tex_index:
                self.j.setdefault("textures", []).append({"source": self.img_index[uri], "sampler": self._sampler(s["repeat"])})
                self.tex_index[tkey] = len(self.j["textures"]) - 1
            ti = {"index": self.tex_index[tkey]}
            if tuple(s["uv"]) != (1.0, 1.0):
                ti["extensions"] = {"KHR_texture_transform": {"scale": [float(s["uv"][0]), float(s["uv"][1])]}}
                self.uses_transform = True
            m["pbrMetallicRoughness"]["baseColorTexture"] = ti
            if "emission" in s:
                m["emissiveTexture"] = dict(ti)
        if "emission" in s:
            m["emissiveFactor"] = [float(min(1.0, c)) for c in s["emission"]]
        if s["alpha"] != "OPAQUE":
            m["alphaMode"] = s["alpha"]
            if s["alpha"] == "MASK":
                m["alphaCutoff"] = 0.5
        if s["double"]:
            m["doubleSided"] = True
        if s.get("unshaded"):
            m.setdefault("extensions", {})["KHR_materials_unlit"] = {}
            self.j.setdefault("extensionsUsed", [])
            if "KHR_materials_unlit" not in self.j["extensionsUsed"]:
                self.j["extensionsUsed"].append("KHR_materials_unlit")
        self.j.setdefault("materials", []).append(m)
        self.mat_index[name] = len(self.j["materials"]) - 1
        self.used_mats.append(name)
        return self.mat_index[name]

    # -- meshes / nodes ------------------------------------------------------------
    def add_mesh(self, name, mb):
        prims = []
        for mat, g in mb.parts.items():
            if not g["i"]:
                continue
            P = np.asarray(g["p"], np.float32)
            N = np.asarray(g["n"], np.float32)
            UV = np.asarray(g["uv"], np.float32)
            I = np.asarray(g["i"], np.uint32 if len(P) > 65535 else np.uint16)
            attrs = {"POSITION": self._acc(P, 5126, "VEC3", 34962, True),
                     "NORMAL": self._acc(N, 5126, "VEC3", 34962)}
            if mat != COL_KEY:
                attrs["TEXCOORD_0"] = self._acc(UV, 5126, "VEC2", 34962)
            prim = {"attributes": attrs, "indices": self._acc(I, 5125 if I.dtype == np.uint32 else 5123, "SCALAR", 34963),
                    "mode": 4}
            if mat != COL_KEY:
                prim["material"] = self._material(mat)
            prims.append(prim)
        if not prims:
            return None
        self.j["meshes"].append({"name": name, "primitives": prims})
        return len(self.j["meshes"]) - 1

    def add_node(self, spec, parent=None):
        node = {"name": spec["name"]}
        if spec.get("mb") is not None:
            mi = self.add_mesh(spec["name"], spec["mb"])
            if mi is not None:
                node["mesh"] = mi
        if spec.get("t") is not None and any(abs(v) > 1e-9 for v in spec["t"]):
            node["translation"] = [float(v) for v in spec["t"]]
        if spec.get("yaw"):
            node["rotation"] = yaw_quat(spec["yaw"])
        self.j["nodes"].append(node)
        idx = len(self.j["nodes"]) - 1
        for ch in spec.get("children", []):
            node.setdefault("children", []).append(self.add_node(ch))
        return idx

    def write(self, root_spec):
        root = self.add_node(root_spec)
        self.j["scenes"][0]["nodes"] = [root]
        if self.uses_transform:
            self.j.setdefault("extensionsUsed", []).append("KHR_texture_transform")
        self.j["buffers"] = [{"byteLength": len(self.bin)}]
        js = _pad(json.dumps(self.j, separators=(",", ":")).encode("utf-8"), b" ")
        bn = _pad(bytes(self.bin))
        total = 12 + 8 + len(js) + 8 + len(bn)
        with open(self.path, "wb") as f:
            f.write(struct.pack("<III", 0x46546C67, 2, total))
            f.write(struct.pack("<II", len(js), 0x4E4F534A) + js)
            f.write(struct.pack("<II", len(bn), 0x004E4942) + bn)
        return self.used_mats


def res_of(abs_path):
    return RES_ROOT + "/" + os.path.relpath(abs_path, V2).replace(os.sep, "/")


def write_glb_import(glb_path, used_mats):
    res = res_of(glb_path)
    md5 = hashlib.md5(res.encode("utf-8")).hexdigest()
    dest = f"res://.godot/imported/{os.path.basename(glb_path)}-{md5}.scn"
    subs = []
    for m in used_mats:
        tres = RES_ROOT + "/" + MATS[m]["tres"]
        subs.append(f'"{m}": {{\n"use_external/enabled": true,\n"use_external/path": "{tres}"\n}}')
    sub = "{\n\"materials\": {\n" + ",\n".join(subs) + "\n}\n}" if subs else "{}"
    txt = f"""[remap]

importer="scene"
importer_version=1
type="PackedScene"
path="{dest}"

[deps]

source_file="{res}"
dest_files=["{dest}"]

[params]

nodes/root_type=""
nodes/root_name=""
nodes/apply_root_scale=true
nodes/root_scale=1.0
meshes/ensure_tangents=false
meshes/generate_lods=false
meshes/create_shadow_meshes=true
meshes/light_baking=1
meshes/lightmap_texel_size=0.2
meshes/force_disable_compression=false
skins/use_named_skins=true
animation/import=false
import_script/path=""
_subresources={sub}
gltf/naming_version=1
gltf/embedded_image_handling=1
"""
    with open(glb_path + ".import", "w", newline="\n") as f:
        f.write(txt)


def write_obj(obj_path, name, nodes):
    """OBJ + MTL export (visual meshes only, node transforms baked)."""
    from .mesh import T, Ry
    mtl_path = obj_path[:-4] + ".mtl"
    lines = [f"# THE VEIL Pack 02 - {name}", f"mtllib {os.path.basename(mtl_path)}", f"o {name}"]
    vo = 1
    used = []

    def walk(spec, M):
        nonlocal vo
        M2 = M @ T(*(spec.get("t") or (0, 0, 0))) @ Ry(spec.get("yaw") or 0)
        if spec.get("mb") is not None and not spec["name"].endswith("colonly"):
            for mat, g in spec["mb"].parts.items():
                if mat == COL_KEY or not g["i"]:
                    continue
                if mat not in used:
                    used.append(mat)
                P = np.asarray(g["p"])
                Pw = (np.c_[P, np.ones(len(P))] @ M2.T)[:, :3]
                Nw = np.asarray(g["n"]) @ M2[:3, :3].T
                lines.append(f"g {spec['name']}_{mat}")
                lines.append(f"usemtl {mat}")
                for p in Pw:
                    lines.append(f"v {p[0]:.4f} {p[1]:.4f} {p[2]:.4f}")
                for u in g["uv"]:
                    s = MATS[mat]["uv"]
                    lines.append(f"vt {u[0] * s[0]:.4f} {1 - u[1] * s[1]:.4f}")
                for n in Nw:
                    lines.append(f"vn {n[0]:.4f} {n[1]:.4f} {n[2]:.4f}")
                I = g["i"]
                for t in range(0, len(I), 3):
                    a, b, c = (I[t] + vo, I[t + 1] + vo, I[t + 2] + vo)
                    lines.append(f"f {a}/{a}/{a} {b}/{b}/{b} {c}/{c}/{c}")
                vo += len(P)
        for ch in spec.get("children", []):
            walk(ch, M2)
    walk(nodes, np.eye(4))
    with open(obj_path, "w", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    ml = []
    for m in used:
        s = MATS[m]
        ml += [f"newmtl {m}", "Ka 0 0 0", "Kd 1 1 1", "Ks 0 0 0", "illum 1"]
        if s.get("png"):
            ml.append(f"map_Kd {os.path.relpath(s['png'], os.path.dirname(obj_path)).replace(os.sep, '/')}")
        if s["alpha"] != "OPAQUE" and s.get("png"):
            ml.append(f"map_d {os.path.relpath(s['png'], os.path.dirname(obj_path)).replace(os.sep, '/')}")
        ml.append("")
    with open(mtl_path, "w", newline="\n") as f:
        f.write("\n".join(ml))
