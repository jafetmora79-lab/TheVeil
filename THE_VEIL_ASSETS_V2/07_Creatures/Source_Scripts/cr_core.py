"""THE VEIL - Pack 07 creature core: custom skeletons, posing / IK, baked animation clips, skinned GLB writer.

Builds on the Pack 06 character core (chr_core: SkinMesh lofts, rings, tube frames, the GLB node layout and the
LBS test helper). What Pack 06 never needed and this adds:
  * arbitrary custom skeletons (Rig) instead of the shared humanoid one;
  * forward kinematics, an analytic two-bone leg IK (planted feet) and baked keyframe clips;
  * a GLB writer with several materials (tiling hide + detail atlas), emissive masks, sockets and animations;
  * Godot .import files that remap materials to external .tres, keep every bone track and set loop modes.

Conventions (same as the Pack 06 characters, so a shared controller can drive both):
  metres, +Y up, the creature faces +Z (glTF / Godot model front), origin on the ground under the body centre.
  Every bone rest rotation is identity; joints are positioned by translation only.
"""
import hashlib
import json
import math
import os
import struct
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
V2 = os.path.normpath(os.path.join(HERE, "..", ".."))
CR = os.path.join(V2, "07_Creatures")
RES_ROOT = "res://THE_VEIL_ASSETS_V2"
for p in (os.path.join(V2, "06_Characters", "Source_Scripts"), os.path.join(V2, "Source_Scripts"),
          os.path.join(V2, "02_Town", "Source_Scripts"), os.path.join(V2, "08_Inventory", "Source_Scripts")):
    if p not in sys.path:
        sys.path.insert(0, p)

from chr_core import SkinMesh, ring, tube_frame, nrm, v3, rot, _pad  # noqa: E402,F401

I3 = np.eye(3)


def res_of(abs_path):
    return RES_ROOT + "/" + os.path.relpath(abs_path, V2).replace(os.sep, "/")


# ------------------------------------------------------------------ rotations
def quat(R):
    """3x3 rotation -> glTF quaternion (x, y, z, w)."""
    m = R
    t = m[0, 0] + m[1, 1] + m[2, 2]
    if t > 0:
        s = math.sqrt(t + 1.0) * 2
        w, x, y, z = 0.25 * s, (m[2, 1] - m[1, 2]) / s, (m[0, 2] - m[2, 0]) / s, (m[1, 0] - m[0, 1]) / s
    elif m[0, 0] > m[1, 1] and m[0, 0] > m[2, 2]:
        s = math.sqrt(1.0 + m[0, 0] - m[1, 1] - m[2, 2]) * 2
        w, x, y, z = (m[2, 1] - m[1, 2]) / s, 0.25 * s, (m[0, 1] + m[1, 0]) / s, (m[0, 2] + m[2, 0]) / s
    elif m[1, 1] > m[2, 2]:
        s = math.sqrt(1.0 + m[1, 1] - m[0, 0] - m[2, 2]) * 2
        w, x, y, z = (m[0, 2] - m[2, 0]) / s, (m[0, 1] + m[1, 0]) / s, 0.25 * s, (m[1, 2] + m[2, 1]) / s
    else:
        s = math.sqrt(1.0 + m[2, 2] - m[0, 0] - m[1, 1]) * 2
        w, x, y, z = (m[1, 0] - m[0, 1]) / s, (m[0, 2] + m[2, 0]) / s, (m[1, 2] + m[2, 1]) / s, 0.25 * s
    q = np.array([x, y, z, w])
    return q / np.linalg.norm(q)


def qmat(q):
    x, y, z, w = q
    return np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                     [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                     [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])


def R(axis, deg):
    """Rotation about axis (degrees); zero angle / zero axis -> identity."""
    if abs(deg) < 1e-9 or np.linalg.norm(axis) < 1e-9:
        return I3.copy()
    return rot(axis, deg)


def Rxyz(x=0.0, y=0.0, z=0.0):
    return R((0, 1, 0), y) @ R((1, 0, 0), x) @ R((0, 0, 1), z)


def frame2(d, s):
    """Orthonormal frame with first column d and second column s orthogonalised against d."""
    d = nrm(np.asarray(d, float))
    s = np.asarray(s, float) - np.dot(s, d) * d
    s = nrm(s)
    return np.column_stack([d, s, np.cross(d, s)])


def smooth(x):
    x = min(1.0, max(0.0, x))
    return x * x * (3 - 2 * x)


def ease(t, t0, t1):
    """0 before t0, smooth ramp to 1 at t1."""
    if t1 <= t0:
        return 1.0 if t >= t1 else 0.0
    return smooth((t - t0) / (t1 - t0))


def pulse(t, t0, t1, t2, t3):
    """Smooth 0 -> 1 (t0..t1), hold, 1 -> 0 (t2..t3)."""
    return ease(t, t0, t1) * (1.0 - ease(t, t2, t3))


# ------------------------------------------------------------------ rig
class Rig:
    def __init__(self, name):
        self.name = name
        self.bones = []          # [(name, parent)] parents first
        self.J = {}              # bone -> world rest joint position
        self.tips = {}           # bone -> world rest end point (for chains / feet)

    def add(self, name, parent, pos, tip=None):
        assert name not in self.J, name
        assert parent is None or parent in self.J, (name, parent)
        self.bones.append((name, parent))
        self.J[name] = np.asarray(pos, float)
        if tip is not None:
            self.tips[name] = np.asarray(tip, float)
        return name

    def chain(self, names, parent, pts):
        """Add bones names[k] at pts[k]; pts has len(names)+1 (last = tip)."""
        p = parent
        for k, n in enumerate(names):
            self.add(n, p, pts[k], tip=pts[k + 1])
            p = n
        return names

    @property
    def names(self):
        return [b for b, _ in self.bones]

    def parent(self, b):
        return dict(self.bones)[b]

    def index(self):
        return {b: k for k, b in enumerate(self.names)}

    def fk(self, local, trans=None):
        trans = trans or {}
        Rw, Pw = {}, {}
        for b, p in self.bones:
            Rl = local.get(b, I3)
            off = self.J[b] - (self.J[p] if p else 0.0) + np.asarray(trans.get(b, (0, 0, 0)), float)
            if p:
                Pw[b] = Pw[p] + Rw[p] @ off
                Rw[b] = Rw[p] @ Rl
            else:
                Pw[b] = off
                Rw[b] = Rl
        return Rw, Pw

    def to_local(self, b, Rw_b, Rw):
        p = self.parent(b)
        return (Rw[p].T @ Rw_b) if p else Rw_b

    def deform(self, P, Jt, Wt, local, trans=None):
        """Linear blend skinning of rest positions P with the given pose."""
        Rw, Pw = self.fk(local, trans)
        names = self.names
        S = np.zeros((len(names), 3, 4))
        for k, b in enumerate(names):
            S[k, :, :3] = Rw[b]
            S[k, :, 3] = Pw[b] - Rw[b] @ self.J[b]
        Ph = np.c_[P, np.ones(len(P))]
        out = np.zeros((len(P), 3))
        for q in range(4):
            out += Wt[:, q:q + 1] * np.einsum("nij,nj->ni", S[Jt[:, q]], Ph)
        return out


def ik_leg(rig, Rw, Pw, local, upper, lower, foot, target_contact, foot_R=None, pole_bias=None):
    """Analytic two-bone IK: upper (hip->knee) and lower (knee->ankle) reach the ankle that puts the foot's rest
    contact point (rig.tips[foot]) on target_contact, with the foot bone held at world rotation foot_R.
    The bend plane follows the parent's rotation (rest knee direction), so knees never flip.
    Writes local rotations into `local` and returns (Rw, Pw) recomputed."""
    p = rig.parent(upper)
    foot_R = I3 if foot_R is None else foot_R
    H0, K0, A0 = rig.J[upper], rig.J[lower], rig.J[foot]
    tip0 = rig.tips[foot]
    L1, L2 = np.linalg.norm(K0 - H0), np.linalg.norm(A0 - K0)
    H = Pw[p] + Rw[p] @ (H0 - rig.J[p])
    T = np.asarray(target_contact, float) - foot_R @ (tip0 - A0)
    mid0 = (H0 + A0) / 2
    pole0 = K0 + (K0 - mid0) * 3.0 + (pole_bias if pole_bias is not None else 0.0)
    pole = Pw[p] + Rw[p] @ (pole0 - rig.J[p])
    d = T - H
    dist = np.linalg.norm(d)
    dist_c = min(max(dist, abs(L1 - L2) + 1e-3), L1 + L2 - 1e-4)
    dh = d / max(dist, 1e-9)
    a = (L1 * L1 - L2 * L2 + dist_c * dist_c) / (2 * dist_c)
    h = math.sqrt(max(L1 * L1 - a * a, 0.0))
    pd = pole - H
    pd = nrm(pd - np.dot(pd, dh) * dh)
    K = H + dh * a + pd * h
    A = H + dh * dist_c
    n0 = nrm(np.cross(K0 - H0, A0 - H0))
    n1 = nrm(np.cross(K - H, A - H))
    Ru = frame2(K - H, n1) @ frame2(K0 - H0, n0).T
    Rl = frame2(A - K, n1) @ frame2(A0 - K0, n0).T
    Rw2 = dict(Rw)
    Rw2[upper] = Ru
    local[upper] = Rw[p].T @ Ru
    local[lower] = Ru.T @ Rl
    local[foot] = Rl.T @ foot_R
    return local


def aim_chain(rig, local, Rw, bones, axis_world, degs):
    """Bend a chain: bone k gets a local rotation of degs[k] about axis_world expressed in its parent frame."""
    for b, d in zip(bones, degs):
        p = rig.parent(b)
        ax = Rw[p].T @ np.asarray(axis_world, float) if p else axis_world
        local[b] = local.get(b, I3) @ R(ax, d)
    return local


# ------------------------------------------------------------------ clips
class Clip:
    def __init__(self, name, times, rots, trans, loop):
        self.name, self.times, self.rots, self.trans, self.loop = name, times, rots, trans, loop

    @property
    def duration(self):
        return float(self.times[-1])


def bake(rig, name, fn, dur, fps=20, loop=False):
    """fn(t) -> (local rotations {bone: 3x3}, translation offsets {bone: vec3}). Samples [0, dur] at fps.
    Looping clips copy frame 0 onto the last frame so the cycle is seamless."""
    n = max(2, int(round(dur * fps)))
    times = np.linspace(0.0, dur, n + 1)
    frames = [fn(float(t)) for t in times]
    if loop:
        frames[-1] = frames[0]
    rots, trans = {}, {}
    for b in rig.names:
        Q = np.array([quat(f[0].get(b, I3)) for f in frames])
        for k in range(1, len(Q)):
            if np.dot(Q[k], Q[k - 1]) < 0:
                Q[k] = -Q[k]
        rots[b] = Q
    tb = sorted({b for f in frames for b in f[1]})
    for b in tb:
        trans[b] = np.array([np.asarray(f[1].get(b, (0, 0, 0)), float) for f in frames])
    return Clip(name, times, rots, trans, loop), frames


# ------------------------------------------------------------------ GLB
def write_glb(path, name, rig, prims, materials, sockets=(), clips=(), extras=None):
    """prims: [(material name, (P, N, UV, J, Wt, I))]; materials: {name: dict(albedo=png bytes, emit=png bytes|None,
    emit_factor=(r,g,b), repeat=bool, rough=float, double=bool)}; sockets: [(name, bone, world pos)].
    Node layout follows chr_core.write_glb: node 0 = scene root holding the joint hierarchy, sockets are plain child
    nodes of joints (Godot imports them as extra bones), the skinned mesh node sits at the scene root."""
    binb = bytearray()
    views, accs = [], []

    def view(data, target=None):
        off = len(binb)
        binb.extend(_pad(bytes(data)))
        v = {"buffer": 0, "byteOffset": off, "byteLength": len(data)}
        if target:
            v["target"] = target
        views.append(v)
        return len(views) - 1

    def acc(arr, comp, typ, target=None, minmax=False):
        arr = np.ascontiguousarray(arr)
        a = {"bufferView": view(arr.tobytes(), target), "componentType": comp, "count": int(arr.shape[0]), "type": typ}
        if minmax:
            mm = arr.reshape(arr.shape[0], -1)
            a["min"] = [float(x) for x in mm.min(0)]
            a["max"] = [float(x) for x in mm.max(0)]
        accs.append(a)
        return len(accs) - 1

    names = rig.names
    nodes = [{"name": name, "children": []}]
    jnode = {}
    for b, p in rig.bones:
        jnode[b] = len(nodes)
        t = rig.J[b] - (rig.J[p] if p else 0.0)
        nd = {"name": b}
        if np.abs(t).max() > 1e-9:
            nd["translation"] = [float(x) for x in t]
        nodes.append(nd)
    for b, p in rig.bones:
        (nodes[jnode[p]] if p else nodes[0]).setdefault("children", []).append(jnode[b])
    for (sn, sb, wp) in sockets:
        nodes.append({"name": sn, "translation": [float(x) for x in (np.asarray(wp, float) - rig.J[sb])]})
        nodes[jnode[sb]].setdefault("children", []).append(len(nodes) - 1)
    ibm = np.zeros((len(names), 16), np.float32)
    for k, b in enumerate(names):
        M = np.eye(4)
        M[:3, 3] = -rig.J[b]
        ibm[k] = M.T.reshape(-1)
    ibm_acc = acc(ibm, 5126, "MAT4")
    # materials / textures
    gl_mats, images, textures, samplers, img_of, mat_of = [], [], [], [], {}, {}

    def texture(png, repeat):
        key = hashlib.md5(png).hexdigest()
        if key not in img_of:
            images.append({"bufferView": view(png), "mimeType": "image/png"})
            img_of[key] = len(images) - 1
        wrap = 10497 if repeat else 33071
        smp = None
        for k, s in enumerate(samplers):
            if s["wrapS"] == wrap:
                smp = k
        if smp is None:
            samplers.append({"magFilter": 9728, "minFilter": 9984, "wrapS": wrap, "wrapT": wrap})
            smp = len(samplers) - 1
        for k, t in enumerate(textures):
            if t["source"] == img_of[key] and t["sampler"] == smp:
                return k
        textures.append({"sampler": smp, "source": img_of[key]})
        return len(textures) - 1
    gl_prims = []
    for mname, arrays in prims:
        P, N, UV, Jt, Wt, I = arrays
        if mname not in mat_of:
            s = materials[mname]
            m = {"name": mname, "pbrMetallicRoughness": {"baseColorTexture": {"index": texture(s["albedo"], s.get("repeat", False))},
                                                         "metallicFactor": 0.0, "roughnessFactor": float(s.get("rough", 0.9))}}
            if s.get("emit") is not None:
                m["emissiveTexture"] = {"index": texture(s["emit"], s.get("repeat", False))}
                m["emissiveFactor"] = [float(c) for c in s.get("emit_factor", (0.5, 0.5, 0.5))]
            if s.get("double"):
                m["doubleSided"] = True
            gl_mats.append(m)
            mat_of[mname] = len(gl_mats) - 1
        gl_prims.append({"attributes": {"POSITION": acc(P, 5126, "VEC3", 34962, True), "NORMAL": acc(N, 5126, "VEC3", 34962),
                                        "TEXCOORD_0": acc(UV, 5126, "VEC2", 34962), "JOINTS_0": acc(Jt, 5123, "VEC4", 34962),
                                        "WEIGHTS_0": acc(Wt, 5126, "VEC4", 34962)},
                         "indices": acc(I, 5125, "SCALAR", 34963), "material": mat_of[mname], "mode": 4})
    for k, im in enumerate(images):
        im["name"] = f"{name}_img{k}"
    mesh_node = len(nodes)
    nodes.append({"name": name + "_Mesh", "mesh": 0, "skin": 0})
    if extras:
        nodes[0]["extras"] = extras
    anims = []
    for c in clips:
        samp, chans = [], []
        t_full = acc(np.asarray(c.times, np.float32), 5126, "SCALAR", None, True)
        t_two = acc(np.asarray([c.times[0], c.times[-1]], np.float32), 5126, "SCALAR", None, True)
        for b in names:
            Q = c.rots[b].astype(np.float32)
            const = np.abs(Q - Q[0]).max() < 1e-6
            samp.append({"input": t_two if const else t_full, "output": acc(Q[[0, -1]] if const else Q, 5126, "VEC4"),
                         "interpolation": "LINEAR"})
            chans.append({"sampler": len(samp) - 1, "target": {"node": jnode[b], "path": "rotation"}})
        for b, Tr in c.trans.items():
            p = rig.parent(b)
            base = rig.J[b] - (rig.J[p] if p else 0.0)
            out = (Tr + base).astype(np.float32)
            const = np.abs(out - out[0]).max() < 1e-6
            samp.append({"input": t_two if const else t_full, "output": acc(out[[0, -1]] if const else out, 5126, "VEC3"),
                         "interpolation": "LINEAR"})
            chans.append({"sampler": len(samp) - 1, "target": {"node": jnode[b], "path": "translation"}})
        anims.append({"name": c.name, "samplers": samp, "channels": chans})
    j = {
        "asset": {"version": "2.0", "generator": "THE VEIL cr_core (Pack 07)"},
        "scene": 0, "scenes": [{"nodes": [0, mesh_node]}], "nodes": nodes,
        "meshes": [{"name": name + "_Mesh", "primitives": gl_prims}],
        "skins": [{"name": name + "_Skin", "joints": [jnode[b] for b in names], "skeleton": jnode[names[0]],
                   "inverseBindMatrices": ibm_acc}],
        "materials": gl_mats, "textures": textures, "samplers": samplers, "images": images,
        "accessors": accs, "bufferViews": views, "buffers": [{"byteLength": len(binb)}],
    }
    if anims:
        j["animations"] = anims
    js = _pad(json.dumps(j, separators=(",", ":")).encode(), b" ")
    out = struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(binb))
    out += struct.pack("<II", len(js), 0x4E4F534A) + js + struct.pack("<II", len(binb), 0x004E4942) + bytes(binb)
    with open(path, "wb") as f:
        f.write(out)


def write_import(glb_path, mat_tres, clips):
    """Godot 4.3 scene import: external .tres materials, all clips imported with every bone track kept,
    loop modes set per clip, embedded images discarded (the .tres materials own the textures)."""
    res = res_of(glb_path)
    md5 = hashlib.md5(res.encode("utf-8")).hexdigest()
    dest = f"res://.godot/imported/{os.path.basename(glb_path)}-{md5}.scn"
    an = ",\n".join(f'"{c.name}": {{\n"settings/loop_mode": {1 if c.loop else 0}\n}}' for c in clips)
    ms = ",\n".join(f'"{m}": {{\n"use_external/enabled": true,\n"use_external/path": "{res_of(t)}"\n}}' for m, t in mat_tres.items())
    sub = "{\n\"animations\": {\n" + an + "\n},\n\"materials\": {\n" + ms + "\n}\n}"
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
animation/import=true
animation/fps=30
animation/trimming=false
animation/remove_immutable_tracks=false
animation/import_rest_as_RESET=true
import_script/path=""
_subresources={sub}
gltf/naming_version=1
gltf/embedded_image_handling=0
"""
    with open(glb_path + ".import", "w", newline="\n") as f:
        f.write(txt)


def write_tres(path, name, albedo_png, emit_png=None, emit_energy=0.6, repeat=False, rough=0.9):
    ext = [f'[ext_resource type="Texture2D" path="{res_of(albedo_png)}" id="1_albedo"]']
    if emit_png:
        ext.append(f'[ext_resource type="Texture2D" path="{res_of(emit_png)}" id="2_emit"]')
    body = [f'resource_name = "{name}"', 'albedo_texture = ExtResource("1_albedo")', "metallic_specular = 0.3",
            f"roughness = {rough}"]
    if emit_png:
        body += ["emission_enabled = true", "emission = Color(1, 1, 1, 1)",
                 f"emission_energy_multiplier = {emit_energy}", 'emission_texture = ExtResource("2_emit")']
    body += ["texture_filter = 2", f"texture_repeat = {'true' if repeat else 'false'}"]
    txt = (f'[gd_resource type="StandardMaterial3D" load_steps={len(ext) + 1} format=3]\n\n' + "\n".join(ext) +
           "\n\n[resource]\n" + "\n".join(body) + "\n")
    with open(path, "w", newline="\n") as f:
        f.write(txt)


def write_png_import(png):
    from build_library import write_import as _wi
    _wi(png, res_of(png))
