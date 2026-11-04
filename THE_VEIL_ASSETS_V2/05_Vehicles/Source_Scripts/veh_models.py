"""Pack 05 vehicle geometry.

A body is lofted through cross-section stations (front bumper -> rear): each station is an 8-point ring
(underside edge, sill, beltline, roof/hood edge on each side + a crowned centre). Wheel arches are real notches
(stations follow a semicircle). Bands of the loft are routed to parts:

    Body (static)  |  Door_FL/FR/RL/RR (hinge at front edge, rotate local Y)  |  Hood (hinge at rear edge, local X)
    Trunk (hinge at front edge, local X)  |  Tailgate (hinge at bottom, local X)  |  RearDoor_L/R (outer edge, local Y)
    Wheel_FL/FR/RL/RR (node at the wheel centre: spin local X, steer local Y)  |  SteeringWheel (spin local Z = column)

Every part is its own node whose origin is its pivot. Three materials per vehicle: atlas (opaque), glass (alpha),
lights (emissive). Units are metres, +Y up, forward = -Z (Godot), origin = ground level, midway between the axles.
"""
import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
V2 = os.path.normpath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(V2, "08_Inventory", "Source_Scripts"))
sys.path.insert(0, os.path.join(V2, "02_Town", "Source_Scripts"))

import veh_atlas as VA  # noqa: E402
import inv_geom  # noqa: E402

inv_geom.R = lambda n: n if isinstance(n, tuple) else VA.R(n)   # Pack 08 helpers, Pack 05 atlas
from inv_geom import G, nrm, rot  # noqa: E402
from veil_mesh.mesh import MB  # noqa: E402
from veil_mesh.gltf import COL_KEY  # noqa: E402

V = lambda *a: np.array(a, float)  # noqa: E731
RR = VA.R


def Rx(deg):
    a = math.radians(deg)
    return np.array([[1, 0, 0], [0, math.cos(a), -math.sin(a)], [0, math.sin(a), math.cos(a)]])


def Ry(deg):
    a = math.radians(deg)
    return np.array([[math.cos(a), 0, math.sin(a)], [0, 1, 0], [-math.sin(a), 0, math.cos(a)]])


def quat(Rm):
    m = np.asarray(Rm, float)
    t = np.trace(m)
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
    return [float(x), float(y), float(z), float(w)]


class Mats:
    def __init__(self, weathered=False):
        self.atlas = "M_Veh_Atlas_Weathered" if weathered else "M_Veh_Atlas"
        self.glass = "M_Veh_Glass_Dirty" if weathered else "M_Veh_Glass"
        self.lights = "M_Veh_Lights_Off" if weathered else "M_Veh_Lights"


class Part:
    def __init__(self, name, pivot=(0, 0, 0), Rrest=None, axis=None, role=""):
        self.name, self.pivot = name, np.asarray(pivot, float)
        self.Rrest = np.eye(3) if Rrest is None else np.asarray(Rrest, float)
        self.mb = MB()
        self.gs = {}
        self.axis, self.role = axis, role
        self.squash = False


class Vehicle:
    """one vehicle: parts + markers + collision boxes -> GLB spec"""

    def __init__(self, name, mats, paint, cfg):
        self.name, self.M, self.paint_rect, self.c = name, mats, paint, cfg
        self.parts = {}
        self.markers = []
        self.cols = []
        self.part("Body", role="static body")
        self.glass_rect = {"windshield": "glass"}
        self.skip_glass = set()

    # ------------------------------------------------------------------ plumbing
    def part(self, name, pivot=(0, 0, 0), Rrest=None, axis=None, role=""):
        if name not in self.parts:
            self.parts[name] = Part(name, pivot, Rrest, axis, role)
        return self.parts[name]

    def g(self, part="Body", kind="atlas"):
        p = self.parts[part]
        if kind not in p.gs:               # one G per (part, material), all writing into the part's mesh
            gg = G()
            gg.mb = p.mb
            gg.g = p.mb._g(getattr(self.M, kind))
            p.gs[kind] = gg
        return p.gs[kind]

    def marker(self, name, p):
        self.markers.append((name, np.asarray(p, float)))

    def col(self, name, mn, mx):
        self.cols.append((name, mn, mx))

    def qo(self, part, kind, ps, rect, hint):
        ps = [np.asarray(p, float) for p in ps]
        n = np.cross(ps[1] - ps[0], ps[2] - ps[0])
        if np.linalg.norm(n) < 1e-12:
            n = np.cross(ps[2] - ps[0], ps[3] - ps[0])
            if np.linalg.norm(n) < 1e-12:
                return
        if np.dot(n, hint) < 0:
            n = -n
        self.g(part, kind).quad(ps, RR(rect), n=nrm(n))

    # ------------------------------------------------------------------ profile
    def st(self, z):
        c = self.c
        k = np.array(c["keys"], float)
        belt, top, hw, hwt = (float(np.interp(z, k[:, 0], k[:, i])) for i in (1, 2, 3, 4))
        yb = c["yb"]
        for zc, yc, ra in c["arches"]:
            if abs(z - zc) <= ra:
                yb = max(yb, yc + math.sqrt(max(ra * ra - (z - zc) ** 2, 0.0)))
        return dict(z=z, belt=belt, top=top, hw=hw, hwt=hwt, yb=yb)

    def ringp(self, s, sgn):
        z, sill = s["z"], self.c.get("sill", 0.07)
        crown = self.c.get("crown", 0.03) * (1.0 if s["top"] - s["belt"] > 0.1 else 0.4)
        return dict(P0=V(sgn * (s["hw"] - 0.05), s["yb"], z), P1=V(sgn * s["hw"], s["yb"] + sill, z), P2=V(sgn * s["hw"], s["belt"], z),
                    P3=V(sgn * s["hwt"], s["top"], z), C=V(0, s["top"] + crown, z))

    def stations(self):
        c = self.c
        zs = [k[0] for k in c["keys"]]
        for d in c.get("doors", []):
            zs += [d[2], d[3]]
        for k in ("hood", "trunk", "windshield", "rear_window", "cabin"):
            if c.get(k):
                zs += list(c[k])
        for zc, yc, ra in c["arches"]:
            zs += [zc - ra * math.cos(t) for t in np.linspace(0, math.pi, 9)]
        for a, b in c.get("extra_glass", []):
            zs += [a, b]
        zs = sorted(z for z in zs if c["z_front"] - 1e-6 <= z <= c["z_end"] + 1e-6)
        out = []
        for z in zs:
            if not out or z - out[-1] > 2e-3:
                out.append(z)
        return [self.st(z) for z in out]

    def owner_side(self, zm, sgn):
        for name, side, z0, z1 in self.c.get("doors", []):
            if side == sgn and z0 <= zm <= z1:
                return name
        return "Body"

    def owner_top(self, zm):
        for key, nm in (("hood", "Hood"), ("trunk", "Trunk")):
            r = self.c.get(key)
            if r and r[0] <= zm <= r[1]:
                return nm
        return "Body"

    def inr(self, zm, key):
        r = self.c.get(key)
        return bool(r) and r[0] <= zm <= r[1]

    def paint(self, zm, band, owner):
        f = self.c.get("paint_fn")
        return f(zm, band, owner) if f else self.paint_rect

    # ------------------------------------------------------------------ body loft
    def loft(self):
        c = self.c
        S = self.stations()
        self.S = S
        for a, b in zip(S[:-1], S[1:]):
            zm = (a["z"] + b["z"]) / 2
            for sgn in (-1, 1):
                A, B = self.ringp(a, sgn), self.ringp(b, sgn)
                own = self.owner_side(zm, sgn)
                h = V(sgn, 0, 0)
                self.qo(own, "atlas", [A["P0"], B["P0"], B["P1"], A["P1"]], self.paint(zm, "lower", own), h + V(0, -0.6, 0))
                self.qo(own, "atlas", [A["P1"], B["P1"], B["P2"], A["P2"]], self.paint(zm, "side", own), h)
                greenhouse = (a["top"] - a["belt"] > 0.08) and (b["top"] - b["belt"] > 0.08)
                glass = greenhouse and (own != "Body" or any(x0 <= zm <= x1 for x0, x1 in c.get("extra_glass", [])))
                if glass and own not in self.skip_glass:
                    self.qo(own, "glass", [A["P2"], B["P2"], B["P3"], A["P3"]], "glass", h + V(0, 0.4, 0))
                elif not glass:
                    self.qo(own, "atlas", [A["P2"], B["P2"], B["P3"], A["P3"]], self.paint(zm, "upper", own), h + V(0, 0.4, 0))
                # cabin inner trim where no door covers the side
                if own == "Body" and self.inr(zm, "cabin"):
                    k = c["inset"]
                    fl = c["interior"]["floor"]
                    q = lambda s_, y, wk: V(sgn * (s_[wk] - k), y, s_["z"])  # noqa: E731
                    self.qo("Body", "atlas", [q(a, fl, "hw"), q(b, fl, "hw"), q(b, b["belt"], "hw"), q(a, a["belt"], "hw")], "dash", V(-sgn, 0, 0))
                    if greenhouse and not glass:
                        self.qo("Body", "atlas", [q(a, a["belt"], "hw"), q(b, b["belt"], "hw"), q(b, b["top"] - 0.03, "hwt"), q(a, a["top"] - 0.03, "hwt")],
                                "headliner", V(-sgn, -0.3, 0))
            L, Rr = self.ringp(a, -1), self.ringp(a, 1)
            L2, R2 = self.ringp(b, -1), self.ringp(b, 1)
            own = self.owner_top(zm)
            glass = self.inr(zm, "windshield") or self.inr(zm, "rear_window")
            kind, rect = ("glass", self.glass_rect["windshield"] if self.inr(zm, "windshield") else "glass") if glass else ("atlas", self.paint(zm, "top", own))
            if not (glass and own in self.skip_glass):
                self.qo(own, kind, [L["P3"], L2["P3"], L2["C"], L["C"]], rect, V(0, 1, 0))
                self.qo(own, kind, [L["C"], L2["C"], R2["P3"], Rr["P3"]], rect, V(0, 1, 0))
            if own in ("Hood", "Trunk"):        # underside skin of the lid
                d = V(0, -0.02, 0)
                self.qo(own, "atlas", [L["P3"] + d, L2["P3"] + d, R2["P3"] + d, Rr["P3"] + d], "steel_dark", V(0, -1, 0))
            self.qo("Body", "atlas", [Rr["P0"], R2["P0"], L2["P0"], L["P0"]], "underside", V(0, -1, 0))
        if c.get("cap_front", True):
            self.cap(S[0], -1)
        if c.get("cap_rear", True):
            self.cap(S[-1], 1)

    def cap(self, s, dz):
        L, Rr = self.ringp(s, -1), self.ringp(s, 1)
        poly = [L["P0"], L["P1"], L["P2"], L["P3"], L["C"], Rr["P3"], Rr["P2"], Rr["P1"], Rr["P0"]]
        cen = np.mean(poly, axis=0)
        u0, v0, u1, v1 = RR(self.paint(s["z"], "cap", "Body"))
        xs, ys = [p[0] for p in poly], [p[1] for p in poly]
        uv = lambda p: (u0 + (u1 - u0) * (p[0] - min(xs)) / (max(xs) - min(xs)), v1 - (v1 - v0) * (p[1] - min(ys)) / (max(ys) - min(ys)))  # noqa: E731
        g = self.g("Body")
        n = V(0, 0, dz)
        for i in range(len(poly)):
            p, q = poly[i], poly[(i + 1) % len(poly)]
            g.tri([cen, p, q], [n] * 3, [uv(cen), uv(p), uv(q)])

    # ------------------------------------------------------------------ parts
    def doors(self):
        c = self.c
        fl = c["interior"]["floor"]
        for name, sgn, z0, z1 in c.get("doors", []):
            a, b = self.st(z0), self.st(z1)
            ymid = (a["yb"] + a["belt"]) / 2
            p = self.part(name, V(sgn * a["hw"], ymid, z0), axis="local +Y (hinge, front edge)", role="door")
            k = c["inset"]
            ia, ib = sgn * (a["hw"] - k), sgn * (b["hw"] - k)
            ybot = max(fl + 0.04, a["yb"] + 0.07)
            self.qo(name, "atlas", [V(ia, ybot, z0 + 0.02), V(ib, ybot, z1 - 0.02), V(ib, b["belt"] - 0.01, z1 - 0.02), V(ia, a["belt"] - 0.01, z0 + 0.02)],
                    "doorpanel", V(-sgn, 0, 0))
            # thickness: top sill strip, front / rear / bottom edges
            self.qo(name, "atlas", [V(sgn * a["hw"], a["belt"], z0), V(sgn * b["hw"], b["belt"], z1), V(ib, b["belt"] - 0.01, z1), V(ia, a["belt"] - 0.01, z0)],
                    "trim_black", V(0, 1, 0))
            for z, s_ in ((z0, a), (z1, b)):
                xo, xi = sgn * s_["hw"], sgn * (s_["hw"] - k)
                self.qo(name, "atlas", [V(xo, s_["yb"] + 0.07, z), V(xi, s_["yb"] + 0.07, z), V(xi, s_["belt"], z), V(xo, s_["belt"], z)],
                        self.paint_rect, V(0, 0, 1 if z == z1 else -1))
            self.qo(name, "atlas", [V(sgn * a["hw"], a["yb"] + 0.07, z0), V(sgn * b["hw"], b["yb"] + 0.07, z1), V(ib, b["yb"] + 0.07, z1), V(ia, a["yb"] + 0.07, z0)],
                    "underside", V(0, -1, 0))
            # exterior handle
            hz = z1 - 0.16
            s_ = self.st(hz)
            self.g(name).box(V(sgn * (s_["hw"] + 0.012), s_["belt"] - 0.075, hz), (0.024, 0.035, 0.15), c.get("handle", "chrome"))
            if name.endswith(("FL", "FR")) or c.get("mirror_on_door") == name:
                mz = z0 + 0.14
                s_ = self.st(mz)
                hb = V(sgn * (s_["hw"] + 0.10), s_["belt"] + 0.09, mz)
                self.g(name).box(V(sgn * (s_["hw"] + 0.04), s_["belt"] + 0.05, mz), (0.08, 0.03, 0.06), "trim_black")
                self.g(name).box(hb, c.get("mirror_size", (0.10, 0.12, 0.08)), self.paint_rect, faces={"+z": "mirror"})

    def wheels(self):
        c = self.c
        r, w = c["wheel_r"], c["wheel_w"]
        for nm, z in (("F", c["axle_f"]), ("R", c["axle_r"])):
            for side, sgn in (("L", -1), ("R", 1)):
                hw = self.st(z)["hw"]
                x = sgn * (hw - w / 2 - 0.02)
                p = self.part(f"Wheel_{nm}{side}", V(x, r, z), axis="spin local X" + (", steer local Y" if nm == "F" else ""), role="wheel")
                g = self.g(p.name)
                axis = V(sgn, 0, 0)
                p0 = p.pivot - axis * w / 2
                prof = [(0, r * 0.66), (0.012, r * 0.94), (0.035, r), (w - 0.035, r), (w - 0.012, r * 0.94), (w, r * 0.66)]
                g.lathe(p0, axis, prof, "sidewall", seg=16, rects=["sidewall", "sidewall", "tread", "sidewall", "sidewall"],
                        cap_rect=c.get("hubcap", "hubcap"))
                if c.get("flat_tires"):
                    p.squash = True
                # wheelhouse liner + axle stub (body)
                zc, yc, ra = [a for a in c["arches"] if abs(a[0] - z) < 1e-6][0]
                xl = sgn * (hw - w - 0.07)
                self.qo("Body", "atlas", [V(xl, c["yb"] - 0.06, zc - ra), V(xl, c["yb"] - 0.06, zc + ra), V(xl, yc + ra + 0.01, zc + ra), V(xl, yc + ra + 0.01, zc - ra)],
                        "wheelwell", V(sgn, 0, 0))
            self.g("Body").cyl(V(-(self.st(z)["hw"] - w - 0.07), r, z), V(self.st(z)["hw"] - w - 0.07, r, z), 0.045, 0.045, "underside", seg=6)

    def lid(self, key, name, hinge_end):
        r = self.c.get(key)
        if not r:
            return
        z = r[1] if hinge_end == "rear" else r[0]
        s = self.st(z)
        self.part(name, V(0, s["top"], z), axis="local +X (hinge, " + ("rear" if hinge_end == "rear" else "front") + " edge)", role="lid")

    # ------------------------------------------------------------------ dressing helpers
    def bay(self, z0, z1, floor_y, rect_floor, rect_wall):
        """inward-facing open-top tub (engine bay / trunk well), hidden inside the body until a lid opens"""
        s0, s1 = self.st(z0), self.st(z1)
        hw = min(s0["hw"], s1["hw"]) - self.c["wheel_w"] - 0.10
        top = min(s0["belt"], s1["belt"]) - 0.01
        g = self.g("Body")
        hs = min(s0["hwt"], s1["hwt"]) - 0.01          # flanges: bay rim -> under the outer skin
        for sgn in (-1, 1):
            self.qo("Body", "atlas", [V(sgn * hw, top, z0), V(sgn * hw, top, z1), V(sgn * hs, top, z1), V(sgn * hs, top, z0)], "underside", V(0, 1, 0))
        for z, d in ((z0, -1), (z1, 1)):
            self.qo("Body", "atlas", [V(-hs, top, z), V(hs, top, z), V(hs, top, z + d * 0.12), V(-hs, top, z + d * 0.12)], "underside", V(0, 1, 0))
        g.quad([V(-hw, floor_y, z1), V(hw, floor_y, z1), V(hw, floor_y, z0), V(-hw, floor_y, z0)], RR(rect_floor), n=V(0, 1, 0))
        self.qo("Body", "atlas", [V(-hw, floor_y, z0), V(hw, floor_y, z0), V(hw, top, z0), V(-hw, top, z0)], rect_wall, V(0, 0, 1))
        self.qo("Body", "atlas", [V(hw, floor_y, z1), V(-hw, floor_y, z1), V(-hw, top, z1), V(hw, top, z1)], rect_wall, V(0, 0, -1))
        for sgn in (-1, 1):
            self.qo("Body", "atlas", [V(sgn * hw, floor_y, z0), V(sgn * hw, floor_y, z1), V(sgn * hw, top, z1), V(sgn * hw, top, z0)], rect_wall, V(-sgn, 0, 0))

    def front_end(self, hl_y, hl_x, hl_size=(0.36, 0.15), grille=(0.56, 0.14), bumper_rect=None, plate=True):
        c = self.c
        s = self.S[0]
        z = s["z"] - 0.004
        gl = self.g("Body", "lights")
        for sgn in (-1, 1):
            gl.decal(V(sgn * hl_x, hl_y, z), hl_size[0], hl_size[1], V(0, 0, -1), V(0, 1, 0), "headlight")
            self.marker(f"Marker_Headlight_{'L' if sgn < 0 else 'R'}", V(sgn * hl_x, hl_y, z - 0.02))
        self.g("Body").decal(V(0, hl_y, z), grille[0], grille[1], V(0, 0, -1), V(0, 1, 0), "grille")
        by = c["yb"] + 0.13
        self.g("Body").box(V(0, by, s["z"] + 0.03), (2 * s["hw"] + 0.06, 0.17, 0.14), bumper_rect or self.paint_rect, faces={"-z": bumper_rect or self.paint_rect})
        self.g("Body").box(V(0, by + 0.01, s["z"] - 0.042), (2 * s["hw"] + 0.02, 0.04, 0.02), "trim_black")
        if plate:
            self.g("Body").decal(V(0, by - 0.035, s["z"] - 0.041), 0.30, 0.15, V(0, 0, -1), V(0, 1, 0), c.get("plate", "plate"), lift=0.002)

    def rear_end(self, tl_y, tl_x, tl_size=(0.34, 0.15), plate_y=None, bumper_rect=None, z=None):
        c = self.c
        s = self.S[-1] if z is None else self.st(z)
        zz = s["z"] + 0.004
        gl = self.g("Body", "lights")
        for sgn in (-1, 1):
            gl.decal(V(sgn * tl_x, tl_y, zz), tl_size[0], tl_size[1], V(0, 0, 1), V(0, 1, 0), c.get("taillight", "taillight"))
            self.marker(f"Marker_Taillight_{'L' if sgn < 0 else 'R'}", V(sgn * tl_x, tl_y, zz + 0.02))
        by = c["yb"] + 0.13
        self.g("Body").box(V(0, by, s["z"] - 0.03), (2 * s["hw"] + 0.06, 0.17, 0.14), bumper_rect or self.paint_rect)
        self.g("Body").box(V(0, by + 0.01, s["z"] + 0.042), (2 * s["hw"] + 0.02, 0.04, 0.02), "trim_black")
        if plate_y is not None:
            self.g("Body").decal(V(0, plate_y, zz), 0.30, 0.15, V(0, 0, 1), V(0, 1, 0), c.get("plate", "plate"))

    def greenhouse_trim(self):
        """A-pillars (sweeps along the windshield edges), B-pillars, wipers, roof drip rails"""
        c = self.c
        w0, w1 = c["windshield"]
        for sgn in (-1, 1):
            pts = [self.ringp(self.st(z), sgn)["P3"] for z in np.linspace(w0, w1, 4)]
            self.g("Body").sweep(pts, 0.032, self.paint(w0 + 0.01, "pillar", "Body"), seg=5)
            for name, sd, z0, z1 in c.get("doors", []):
                if sd == sgn and name.endswith(("FL", "FR")) and any(d[0].endswith(("RL", "RR")) for d in c["doors"]):
                    s = self.st(z1)
                    self.g("Body").sweep([V(sgn * (s["hw"] - 0.01), s["belt"], z1), V(sgn * (s["hwt"] - 0.005), s["top"] - 0.01, z1)], 0.035, "trim_black", seg=4)
        s = self.st(w0)
        for x in (-0.28, 0.22):
            self.g("Body").box(V(x, s["top"] + 0.02, w0 + 0.06), (0.52, 0.012, 0.025), "trim_black", Rm=rot(yaw=6))

    # ------------------------------------------------------------------ interior
    def seat(self, x, z, y, w, back_h=0.60, rect="fabric_seat", head=True, depth=0.50, lean=13):
        g = self.g("Body")
        g.box(V(x, y + 0.07, z), (w, 0.14, depth), rect, faces={"+y": "seat" if w < 0.8 else "bench"})
        Rm = rot(pitch=lean)
        bc = V(x, y + 0.14, z + depth / 2 - 0.04) + Rm @ V(0, back_h / 2, 0)
        g.box(bc, (w, back_h, 0.11), rect, Rm=Rm, faces={"-z": "seat" if w < 0.8 else "bench"})
        if head:
            g.box(bc + Rm @ V(0, back_h / 2 + 0.09, 0.0), (min(w * 0.55, 0.28), 0.16, 0.09), rect, Rm=Rm)

    def interior(self):
        c, I = self.c, self.c["interior"]
        g = self.g("Body")
        fl = I["floor"]
        z0, z1 = c["cabin"]
        s0 = self.st(z0)
        hwf = min(self.st(z)["hw"] for z in np.linspace(z0, z1, 6)) - c["inset"]
        wliner = lambda z: self.st(z)["hw"] - c["wheel_w"] - 0.08  # noqa: E731
        cuts = sorted({z0, z1} | {b for zc, yc, ra in c["arches"] for b in (zc - ra, zc + ra) if z0 < b < z1})
        for a, b in zip(cuts[:-1], cuts[1:]):
            m = (a + b) / 2
            inside = any(abs(m - zc) < ra for zc, yc, ra in c["arches"])
            hx = min(wliner(a), wliner(b)) if inside else hwf
            g.box(V(0, fl - 0.02, m), (2 * hx, 0.04, b - a), "carpet")
        self.rear_w = 2 * hwf
        for zc, yc, ra in c["arches"]:
            a, b = max(zc - ra, z0), min(zc + ra, z1)
            if b - a > 0.02:
                xl = min(wliner(a), wliner(b))
                self.rear_w = min(self.rear_w, 2 * xl - 0.02)
                for sgn in (-1, 1):
                    g.box(V(sgn * (xl + hwf) / 2, (fl + yc + ra + 0.05) / 2, (a + b) / 2), (hwf - xl, yc + ra + 0.05 - fl, b - a), "carpet",
                          skip=("-y", "+x" if sgn > 0 else "-x"))
        # firewall + headliner
        self.qo("Body", "atlas", [V(-hwf, fl, z0), V(hwf, fl, z0), V(hwf, s0["belt"], z0), V(-hwf, s0["belt"], z0)], "dash", V(0, 0, 1))
        rf0, rf1 = I["roof"]
        t0, t1 = self.st(rf0), self.st(rf1)
        hy = min(t0["top"], t1["top"]) - 0.05
        hwr = min(t0["hwt"], t1["hwt"]) - 0.04
        g.quad([V(-hwr, hy, rf0), V(hwr, hy, rf0), V(hwr, hy, rf1), V(-hwr, hy, rf1)], RR("headliner"), n=V(0, -1, 0))
        # dashboard, cluster hood, centre stack, glovebox, vents
        dz0, dz1, dy0, dy1 = I["dash"]
        dw = hwf - 0.02
        g.box(V(0, (dy0 + dy1) / 2, (dz0 + dz1) / 2), (2 * dw, dy1 - dy0, dz1 - dz0), "dash")
        dx = I["driver_x"]
        # instrument pod: raised so the gauges are seen between the hub and the top of the rim
        g.box(V(dx, dy1 + 0.01, dz1 - 0.07), (0.42, 0.14, 0.14), "dash", taper=(1.0, 0.8))
        g.decal(V(dx, dy1 + 0.0, dz1 + 0.0), 0.38, 0.11, V(0, 0, 1), V(0, 1, 0), "cluster", lift=0.002)
        self.targets = {"cluster": [dx, dy1 + 0.0, dz1 + 0.002], "mirror": list(I["mirror"]), "wheel_hub": list(I["wheel_c"])}
        g.decal(V(0, (dy0 + dy1) / 2, dz1), 0.18, 0.27, V(0, 0, 1), V(0, 1, 0), "stack", lift=0.002)
        g.decal(V(-dx, dy0 + 0.14, dz1), 0.36, 0.17, V(0, 0, 1), V(0, 1, 0), "glovebox", lift=0.002)
        for x in (-dw + 0.12, dw - 0.12):
            g.decal(V(x, dy1 - 0.06, dz1), 0.16, 0.08, V(0, 0, 1), V(0, 1, 0), "vent", lift=0.002)
        # steering column + wheel (own pivot node)
        wc = V(*I["wheel_c"])
        t = I.get("column_tilt", 24)
        Rw = Rx(-t)
        zl = Rw @ V(0, 0, 1)
        g.cyl(wc - zl * 0.05, wc - zl * 0.32, 0.035, 0.05, "dash", seg=8)
        sw = self.part("SteeringWheel", wc, Rrest=Rw, axis="spin local Z (column axis)", role="steering")
        gw = self.g("SteeringWheel")
        xl, yl = Rw @ V(1, 0, 0), Rw @ V(0, 1, 0)
        rr = I.get("wheel_rad", 0.18)
        ring = [wc + (xl * math.cos(a) + yl * math.sin(a)) * rr for a in np.linspace(0, 2 * math.pi, 17)]
        gw.sweep(ring, 0.017, "rubber", seg=5, caps=False)
        gw.cyl(wc - zl * 0.03, wc + zl * 0.03, 0.055, 0.05, "trim_black", seg=8)
        for a in (180, 0, -90):
            d = xl * math.cos(math.radians(a)) + yl * math.sin(math.radians(a))
            gw.box(wc + d * rr * 0.55, (0.03, 0.03, 0.03), "trim_black")
            gw.sweep([wc + d * 0.04, wc + d * (rr - 0.01)], 0.012, "trim_black", seg=4, caps=False)
        # pedals (automatic: brake + accelerator)
        pz, py = I["pedals"]
        g.box(V(dx + 0.02, py, pz), (0.11, 0.07, 0.025), "pedal", Rm=rot(pitch=-30))
        g.box(V(dx + 0.17, py - 0.02, pz + 0.02), (0.06, 0.13, 0.02), "pedal", Rm=rot(pitch=-25))
        # seats
        sx = I["seat_x"]
        sz, sy = I["seat_front"]
        if I.get("bench_front"):
            self.seat(0, sz, sy, 2 * hwf - 0.12, rect=I.get("seat_rect", "fabric_gray"), head=False)
        else:
            for x in (-sx, sx):
                self.seat(x, sz, sy, 0.50, rect=I.get("seat_rect", "fabric_seat"))
            # console + gear selector
            cz0, cz1 = dz1, sz + 0.15
            g.box(V(0, fl + 0.11, (cz0 + cz1) / 2), (0.2, 0.22, cz1 - cz0), "trim_black")
            g.decal(V(0, fl + 0.221, cz0 + 0.18), 0.08, 0.04, V(0, 1, 0), V(0, 0, -1), "shifter", lift=0.001)
            g.cyl(V(0, fl + 0.22, cz0 + 0.26), V(0, fl + 0.36, cz0 + 0.24), 0.012, 0.012, "chrome", seg=6)
            g.box(V(0, fl + 0.38, cz0 + 0.24), (0.04, 0.06, 0.05), "trim_black")
        if I.get("rear_seat"):
            rz, ry = I["rear_seat"]
            self.seat(0, rz, ry, min(2 * hwf - 0.14, self.rear_w), rect=I.get("seat_rect", "fabric_seat"), back_h=0.52, lean=16)
            self.marker("Marker_Seat_Rear_L", V(-sx, ry + 0.14, rz))
            self.marker("Marker_Seat_Rear_R", V(sx, ry + 0.14, rz))
        if I.get("parcel"):
            pz0, pz1 = I["parcel"]
            py_ = min(self.st(pz0)["belt"], self.st(pz1)["belt"]) - 0.01
            g.quad([V(-hwf, py_, pz1), V(hwf, py_, pz1), V(hwf, py_, pz0), V(-hwf, py_, pz0)], RR("trim_black"), n=V(0, 1, 0))
        # rear-view mirror
        mx, my, mz = I["mirror"]
        g.cyl(V(mx, hy, mz - 0.02), V(mx, my + 0.03, mz), 0.008, 0.008, "trim_black", seg=5)
        g.box(V(mx, my, mz), (0.25, 0.07, 0.03), "trim_black", faces={"+z": "mirror"})
        # markers
        hip_y = sy + 0.16
        self.marker("Marker_Seat_Driver", V(-sx if not I.get("bench_front") else dx, hip_y, sz))
        self.marker("Marker_Seat_Passenger", V(sx if not I.get("bench_front") else -dx, hip_y, sz))
        self.marker("Marker_Camera_FirstPerson", V(dx, hip_y + I.get("eye_up", 0.66), sz + 0.10))
        ez = (c["doors"][0][2] + c["doors"][0][3]) / 2 if c.get("doors") else sz
        self.marker("Marker_Entry_Driver", V(-(s0["hw"] + 0.65), 0.0, ez))
        self.marker("Marker_Entry_Passenger", V(s0["hw"] + 0.65, 0.0, ez))

    def underside(self, z0, z1):
        hw = self.st((z0 + z1) / 2)["hw"]
        y = self.c["yb"] - 0.06
        g = self.g("Body")
        g.cyl(V(-hw * 0.45, y, z0), V(-hw * 0.45, y, z1), 0.035, 0.035, "rust", seg=6)
        g.box(V(-hw * 0.45, y, z1 - 0.55), (0.24, 0.12, 0.5), "rust")
        g.box(V(hw * 0.35, self.c["yb"] - 0.07, (z0 + z1) / 2 + 0.6), (0.5, 0.12, 0.6), "underside")

    # ------------------------------------------------------------------ export
    def spec(self, pose=None, sink=0.0):
        pose = pose or {}
        children = []
        for name, p in self.parts.items():
            mb = p.mb
            for mat, gg in mb.parts.items():
                if not gg["p"]:
                    continue
                Pp = np.asarray(gg["p"], float) - p.pivot
                Pp = Pp @ p.Rrest            # == (Rrest^T (p - pivot)) row-wise
                Nn = np.asarray(gg["n"], float) @ p.Rrest
                if p.squash:
                    m = Pp[:, 1] < 0
                    Pp[m, 1] *= 0.78
                gg["p"] = Pp.tolist()
                gg["n"] = Nn.tolist()
            Rnode = p.Rrest @ pose.get(name, np.eye(3))
            node = {"name": name, "mb": mb, "t": tuple(float(v) for v in p.pivot), "role": p.role, "axis": p.axis}
            if not np.allclose(Rnode, np.eye(3)):
                node["q"] = quat(Rnode)
            children.append(node)
        for nm, mn, mx in self.cols:
            cm = MB()
            cm.box(COL_KEY, tuple(mn), tuple(mx), skip=())
            children.append({"name": nm + "-convcolonly", "mb": cm})
        for nm, p in self.markers:
            children.append({"name": nm, "t": tuple(float(v) for v in p)})
        root = {"name": self.name, "children": children}
        if sink:
            root["t"] = (0.0, -float(sink), 0.0)
        return root


# ====================================================================== the vehicles
def sedan_cfg():
    return dict(
        z_front=-2.36, z_end=2.36, yb=0.22, sill=0.07, crown=0.03, inset=0.07,
        keys=[(-2.36, 0.66, 0.70, 0.80, 0.74), (-2.28, 0.72, 0.76, 0.875, 0.84), (-0.76, 0.86, 0.89, 0.885, 0.85),
              (-0.06, 0.89, 1.41, 0.885, 0.66), (0.95, 0.92, 1.40, 0.885, 0.66), (1.55, 0.94, 0.98, 0.885, 0.84),
              (2.28, 0.95, 0.97, 0.875, 0.84), (2.36, 0.90, 0.92, 0.80, 0.74)],
        arches=[(-1.36, 0.22, 0.43), (1.36, 0.22, 0.43)], axle_f=-1.36, axle_r=1.36, wheel_r=0.31, wheel_w=0.20,
        doors=[("Door_FL", -1, -0.86, 0.24), ("Door_FR", 1, -0.86, 0.24), ("Door_RL", -1, 0.24, 0.90), ("Door_RR", 1, 0.24, 0.90)],
        hood=(-2.28, -0.76), trunk=(1.55, 2.28), windshield=(-0.76, -0.06), rear_window=(0.95, 1.55), cabin=(-0.76, 1.55),
        interior=dict(floor=0.30, roof=(-0.06, 0.95), dash=(-0.72, -0.40, 0.60, 0.92), driver_x=-0.37, seat_x=0.37,
                      wheel_c=(-0.37, 0.87, -0.27), pedals=(-0.62, 0.40), seat_front=(0.05, 0.36), rear_seat=(0.80, 0.34),
                      parcel=(1.22, 1.55), mirror=(0.0, 1.27, -0.12)),
    )


def build_sedan(name, mats, paint="paint_sedan", cfg_mod=None, glass_rect="glass", skip_glass=()):
    c = sedan_cfg()
    if cfg_mod:
        c.update(cfg_mod)
    v = Vehicle(name, mats, paint, c)
    v.glass_rect["windshield"] = glass_rect
    v.skip_glass = set(skip_glass)
    v.lid("hood", "Hood", "rear")
    v.lid("trunk", "Trunk", "front")
    v.doors()
    v.loft()
    v.wheels()
    v.greenhouse_trim()
    v.front_end(hl_y=0.58, hl_x=0.56)
    v.rear_end(tl_y=0.80, tl_x=0.60, plate_y=0.66)
    v.g("Trunk").decal(V(0.5, v.st(2.2)["top"] + 0.005, 2.2), 0.14, 0.05, V(0, 1, 0), V(0, 0, -1), "badge")
    v.bay(-2.18, -0.86, 0.48, "engine", "underside")
    v.bay(1.62, 2.22, 0.44, "carpet", "carpet")
    v.interior()
    v.underside(-0.4, 2.2)
    v.col("Collision_Lower", (-0.89, 0.22, -2.40), (0.89, 0.95, 2.40))
    v.col("Collision_Cabin", (-0.68, 0.95, -0.40), (0.68, 1.42, 1.25))
    return v


def build_police(name, mats):
    c = dict(
        z_front=-2.50, z_end=2.50, yb=0.23, sill=0.07, crown=0.03, inset=0.07,
        keys=[(-2.50, 0.68, 0.72, 0.84, 0.78), (-2.42, 0.74, 0.78, 0.92, 0.88), (-0.80, 0.88, 0.91, 0.93, 0.89),
              (-0.08, 0.91, 1.46, 0.93, 0.70), (0.98, 0.94, 1.45, 0.93, 0.70), (1.62, 0.96, 1.00, 0.93, 0.88),
              (2.42, 0.97, 0.99, 0.92, 0.88), (2.50, 0.92, 0.94, 0.84, 0.78)],
        arches=[(-1.45, 0.23, 0.45), (1.45, 0.23, 0.45)], axle_f=-1.45, axle_r=1.45, wheel_r=0.33, wheel_w=0.22, hubcap="rim_face",
        doors=[("Door_FL", -1, -0.92, 0.26), ("Door_FR", 1, -0.92, 0.26), ("Door_RL", -1, 0.26, 0.97), ("Door_RR", 1, 0.26, 0.97)],
        hood=(-2.42, -0.80), trunk=(1.62, 2.42), windshield=(-0.80, -0.08), rear_window=(0.98, 1.62), cabin=(-0.80, 1.62),
        plate="plate_police", handle="trim_black",
        interior=dict(floor=0.31, roof=(-0.08, 0.98), dash=(-0.76, -0.44, 0.62, 0.94), driver_x=-0.40, seat_x=0.40,
                      wheel_c=(-0.40, 0.89, -0.31), pedals=(-0.66, 0.42), seat_front=(0.02, 0.37), rear_seat=(0.82, 0.35),
                      parcel=(1.26, 1.62), mirror=(0.0, 1.31, -0.14), seat_rect="fabric_gray"),
    )
    white = lambda zm, band, own: "paint_white" if (own.startswith("Door") and band in ("side", "lower")) or band == "top" and own == "Body" and -0.08 <= zm <= 0.98 else "paint_black"  # noqa: E731
    c["paint_fn"] = white
    v = Vehicle(name, mats, "paint_black", c)
    v.lid("hood", "Hood", "rear")
    v.lid("trunk", "Trunk", "front")
    v.doors()
    v.loft()
    v.wheels()
    v.greenhouse_trim()
    v.front_end(hl_y=0.60, hl_x=0.60, bumper_rect="trim_black")
    v.rear_end(tl_y=0.82, tl_x=0.64, plate_y=0.68, bumper_rect="trim_black")
    for name_, sgn, z0, z1 in c["doors"]:
        zc = (z0 + z1) / 2
        s = v.st(zc)
        big = name_.endswith(("FL", "FR"))
        v.g(name_).decal(V(sgn * s["hw"], (s["yb"] + s["belt"]) / 2 + 0.04, zc), 0.92 if big else 0.62, 0.23 if big else 0.09,
                         V(sgn, 0, 0), V(0, 1, 0), "police_door" if big else "police_small", lift=0.003)
    # roof: lightbar, number, A-pillar spotlight, antenna; push bar; partition
    rz = 0.40
    v.g("Body").box(V(0, 1.475 + 0.045, rz), (1.20, 0.09, 0.26), "trim_black", faces={"+y": "trim_black"})
    for dz in (-1, 1):
        v.g("Body", "lights").decal(V(0, 1.52, rz + dz * 0.131), 1.16, 0.08, V(0, 0, dz), V(0, 1, 0), "lightbar", lift=0.001)
    for sx in (-1, 1):
        v.g("Body", "lights").decal(V(sx * 0.601, 1.52, rz), 0.24, 0.08, V(sx, 0, 0), V(0, 1, 0), "lightbar", lift=0.001)
    v.g("Body").box(V(0, 1.47, rz), (0.30, 0.02, 0.06), "trim_black")
    v.g("Body").decal(V(0, 1.476, 0.75), 0.40, 0.26, V(0, 1, 0), V(0, 0, -1), "police_roof", lift=0.004)
    s = v.st(-0.70)
    v.g("Body").cyl(V(-(s["hw"] + 0.02), s["top"] + 0.02, -0.70), V(-(s["hw"] + 0.02), s["top"] + 0.02, -0.82), 0.06, 0.07, "chrome", seg=8, cap_rect="lens_white")
    v.g("Body").cyl(V(0.3, 1.47, 1.20), V(0.3, 1.82, 1.22), 0.004, 0.003, "trim_black", seg=4)
    zf = -2.50
    for sx in (-0.42, 0.42):
        v.g("Body").box(V(sx, 0.58, zf - 0.16), (0.06, 0.48, 0.06), "trim_black")
    v.g("Body").box(V(0, 0.75, zf - 0.17), (0.98, 0.06, 0.05), "trim_black")
    v.g("Body").box(V(0, 0.45, zf - 0.17), (0.98, 0.06, 0.05), "trim_black")
    v.bay(-2.32, -0.92, 0.50, "engine", "underside")
    v.bay(1.70, 2.36, 0.45, "carpet", "carpet")
    v.interior()
    for x in np.linspace(-0.78, 0.78, 9):          # prisoner partition behind the front seats
        v.g("Body").cyl(V(x, 0.62, 0.42), V(x, 1.36, 0.42), 0.008, 0.008, "steel_dark", seg=4, caps=(False, False))
    for y in (0.62, 0.99, 1.36):
        v.g("Body").cyl(V(-0.80, y, 0.42), V(0.80, y, 0.42), 0.012, 0.012, "steel_dark", seg=4)
    v.underside(-0.4, 2.3)
    v.col("Collision_Lower", (-0.95, 0.23, -2.70), (0.95, 0.97, 2.55))
    v.col("Collision_Cabin", (-0.72, 0.97, -0.42), (0.72, 1.57, 1.30))
    return v


def back_wall(v, part, z, dz, hw, hwt, yb, belt, top, win_hw, rect, inset=0.0):
    """cab back with a window hole (pickup): lower panel, two posts, top strip; window = glass"""
    k = inset
    hw, hwt = hw - k, hwt - k
    wy0, wy1 = belt + 0.06, top - 0.08
    n = V(0, 0, dz)
    pts = [[V(-hw, yb, z), V(hw, yb, z), V(hw, wy0, z), V(-hw, wy0, z)],
           [V(-hw, wy0, z), V(-win_hw, wy0, z), V(-win_hw, wy1, z), V(-hwt, top, z)],
           [V(win_hw, wy0, z), V(hw, wy0, z), V(hwt, top, z), V(win_hw, wy1, z)],
           [V(-win_hw, wy1, z), V(win_hw, wy1, z), V(hwt, top, z), V(-hwt, top, z)]]
    for ps in pts:
        v.qo(part, "atlas", ps, rect, n)
    if not k:
        v.qo(part, "glass", [V(-win_hw, wy0, z), V(win_hw, wy0, z), V(win_hw, wy1, z), V(-win_hw, wy1, z)], "glass", n)


def build_pickup(name, mats, flat=False, tailgate_down=False):
    hw = 0.95
    c = dict(
        z_front=-2.62, z_end=0.42, yb=0.42, sill=0.08, crown=0.03, inset=0.07, cap_rear=False,
        keys=[(-2.62, 0.95, 1.00, 0.86, 0.80), (-2.55, 1.04, 1.08, 0.94, 0.90), (-1.02, 1.12, 1.15, hw, 0.91),
              (-0.45, 1.13, 1.80, hw, 0.76), (0.30, 1.14, 1.80, hw, 0.76), (0.42, 1.14, 1.77, hw, 0.77)],
        arches=[(-1.60, 0.42, 0.52), (1.60, 0.42, 0.52)], axle_f=-1.60, axle_r=1.60, wheel_r=0.38, wheel_w=0.24, hubcap="rim_face",
        doors=[("Door_FL", -1, -1.04, 0.30), ("Door_FR", 1, -1.04, 0.30)], mirror_size=(0.12, 0.18, 0.08),
        hood=(-2.55, -1.02), windshield=(-1.02, -0.45), cabin=(-1.02, 0.38), flat_tires=flat,
        interior=dict(floor=0.55, roof=(-0.45, 0.30), dash=(-0.98, -0.66, 0.80, 1.12), driver_x=-0.40, seat_x=0.40,
                      wheel_c=(-0.40, 1.10, -0.53), pedals=(-0.88, 0.66), seat_front=(-0.22, 0.60), bench_front=True,
                      mirror=(0.0, 1.66, -0.38), seat_rect="fabric_gray", column_tilt=28),
    )
    v = Vehicle(name, mats, "paint_pickup", c)
    v.lid("hood", "Hood", "rear")
    v.doors()
    v.loft()
    v.wheels()
    v.greenhouse_trim()
    v.front_end(hl_y=0.86, hl_x=0.62, hl_size=(0.30, 0.18), grille=(0.80, 0.22), bumper_rect="chrome")
    # cab back (outer + inner) with the rear window
    s = v.st(0.42)
    back_wall(v, "Body", 0.42, 1, s["hw"], s["hwt"], c["yb"], s["belt"], s["top"], 0.55, "paint_pickup")
    back_wall(v, "Body", 0.37, -1, s["hw"], s["hwt"], c["interior"]["floor"], s["belt"], s["top"], 0.55, "dash", inset=0.07)
    g = v.g("Body")
    # cargo bed: arch-notched side walls (extruded profile), floor, front wall, wheel tubs, bumper
    zb0, zb1, fl, top = 0.48, 2.62, 0.86, 1.15
    zc, yc, ra = 1.60, 0.42, 0.52
    y0 = 0.50
    th0 = math.asin((y0 - yc) / ra)
    arch = [(zc + ra * math.cos(t), yc + ra * math.sin(t)) for t in np.linspace(math.pi - th0, th0, 9)]
    outline = [(zb0, y0)] + arch + [(zb1, y0), (zb1, top), (zb0, top)]
    Rm = np.array([[0, 0, 1], [0, 1, 0], [1, 0, 0]], float)
    for sgn in (-1, 1):
        x0, x1 = (hw - 0.06, hw) if sgn > 0 else (-hw, -hw + 0.06)
        g.extrude(outline, x0, x1, V(0, 0, 0), Rm, "paint_pickup", "paint_pickup")
        g.box(V(sgn * (hw - 0.03), top + 0.012, (zb0 + zb1) / 2), (0.07, 0.025, zb1 - zb0), "trim_black")
        g.box(V(sgn * (hw - 0.21), fl + 0.08, zc), (0.30, 0.16, 2 * ra - 0.04), "bedliner")
        v.g("Body", "lights").box(V(sgn * (hw - 0.03), 0.98, zb1 + 0.012), (0.07, 0.30, 0.03), "trim_black", faces={"+z": "taillight_tall"})
        v.marker(f"Marker_Taillight_{'L' if sgn < 0 else 'R'}", V(sgn * (hw - 0.03), 0.98, zb1 + 0.05))
    g.box(V(0, fl - 0.03, (zb0 + zb1) / 2), (2 * hw - 0.12, 0.06, zb1 - zb0), "bedliner")
    g.box(V(0, (y0 + top) / 2, zb0 + 0.03), (2 * hw, top - y0, 0.06), "paint_pickup")
    g.box(V(0, 0.55, zb1 + 0.07), (2 * hw + 0.04, 0.14, 0.12), "chrome")
    g.decal(V(0, 0.55, zb1 + 0.131), 0.30, 0.13, V(0, 0, 1), V(0, 1, 0), "plate")
    for sx in (-0.42, 0.42):
        g.box(V(sx, 0.47, -0.1), (0.10, 0.10, 4.9), "underside")
    tg = v.part("Tailgate", V(0, fl - 0.06, zb1 - 0.03), axis="local +X (hinge, bottom edge)", role="tailgate")
    v.g("Tailgate").box(V(0, (fl - 0.06 + top) / 2, zb1 - 0.03), (2 * hw - 0.13, top - fl + 0.06, 0.05), "paint_pickup", faces={"+z": "tailgate"})
    v.g("Tailgate").box(V(0, top - 0.08, zb1 + 0.0), (0.18, 0.04, 0.02), "trim_black")
    v.bay(-2.45, -1.10, 0.62, "engine", "underside")
    v.interior()
    v.underside(-0.6, 2.4)
    v.col("Collision_Lower", (-0.97, 0.42, -2.70), (0.97, 1.15, 2.75))
    v.col("Collision_Cabin", (-0.80, 1.15, -1.0), (0.80, 1.82, 0.44))
    pose = {"Tailgate": Rx(90)} if tailgate_down else {}
    return v, pose


def build_van(name, mats):
    hw = 1.0
    c = dict(
        z_front=-2.45, z_end=2.95, yb=0.40, sill=0.08, crown=0.04, inset=0.07, cap_rear=False,
        keys=[(-2.45, 0.92, 0.96, 0.92, 0.86), (-2.38, 1.00, 1.04, 0.99, 0.95), (-1.85, 1.10, 1.13, hw, 0.96),
              (-1.22, 1.12, 2.20, hw, 0.94), (2.90, 1.12, 2.22, hw, 0.94), (2.95, 1.12, 2.19, 0.995, 0.935)],
        arches=[(-1.75, 0.40, 0.48), (1.75, 0.40, 0.48)], axle_f=-1.75, axle_r=1.75, wheel_r=0.36, wheel_w=0.22,
        doors=[("Door_FL", -1, -1.22, -0.40), ("Door_FR", 1, -1.22, -0.40)], extra_glass=[(-1.85, -1.22)],
        hood=(-2.38, -1.85), windshield=(-1.85, -1.22), cabin=(-1.85, -0.40), mirror_size=(0.12, 0.22, 0.08),
        interior=dict(floor=0.55, roof=(-1.22, -0.42), dash=(-1.80, -1.50, 0.92, 1.12), driver_x=-0.45, seat_x=0.45,
                      wheel_c=(-0.45, 1.16, -1.30), pedals=(-1.68, 0.64), seat_front=(-0.92, 0.80), mirror=(0.0, 2.02, -1.12),
                      seat_rect="fabric_gray", column_tilt=34, eye_up=0.68),
    )
    v = Vehicle(name, mats, "paint_van", c)
    v.lid("hood", "Hood", "rear")
    v.doors()
    v.loft()
    v.wheels()
    v.greenhouse_trim()
    v.front_end(hl_y=0.80, hl_x=0.64, hl_size=(0.30, 0.17), grille=(0.70, 0.20), bumper_rect="trim_gray")
    # livery on the cargo sides (follows the slight tumblehome)
    for sgn in (-1, 1):
        y = 1.62
        x = sgn * (hw - 0.06 * (y - 1.12) / 1.08)
        n = nrm(V(sgn * 1.08, 0.06, 0))
        v.g("Body").decal(V(x, y, 1.15), 2.4, 0.8, n, V(0, 1, 0), "van_brand", lift=0.012)
    # rear: header, sill, step bumper, two hinged doors (outer-edge hinges)
    zr = 2.95
    g = v.g("Body")
    g.box(V(0, 2.15, zr - 0.03), (2 * 0.94, 0.08, 0.06), "paint_van")
    g.box(V(0, 0.46, zr - 0.03), (2 * 0.99, 0.12, 0.06), "paint_van")
    g.box(V(0, 0.42, zr + 0.09), (2 * hw, 0.12, 0.16), "trim_black")
    g.decal(V(0, 0.42, zr + 0.171), 0.30, 0.12, V(0, 0, 1), V(0, 1, 0), "plate", lift=0.002)
    for sgn, nm in ((-1, "RearDoor_L"), (1, "RearDoor_R")):
        v.part(nm, V(sgn * 0.985, 1.33, zr), axis="local +Y (hinge, outer edge)", role="door")
        gd = v.g(nm)
        gd.box(V(sgn * 0.495, 1.33, zr - 0.005), (0.97, 1.62, 0.04), "paint_van", faces={"-z": "cargo_wall"})
        gd.box(V(-sgn * 0.0 + sgn * 0.06, 1.25, zr + 0.022), (0.02, 0.04, 0.16), "chrome", Rm=rot(roll=90))
        v.g(nm, "lights").decal(V(sgn * 0.93, 0.86, zr + 0.0155), 0.09, 0.36, V(0, 0, 1), V(0, 1, 0), "taillight_tall", lift=0.002)
        v.marker(f"Marker_Taillight_{'L' if sgn < 0 else 'R'}", V(sgn * 0.93, 0.86, zr + 0.05))
    v.g("RearDoor_L").decal(V(-0.50, 1.75, zr + 0.0155), 0.80, 0.23, V(0, 0, 1), V(0, 1, 0), "van_rear", lift=0.002)
    # cargo compartment: plywood floor, metal walls, ceiling, wheel tubs, partition
    cz0, cz1 = -0.36, 2.90
    hi = hw - 0.06
    g.box(V(0, 0.55, (cz0 + cz1) / 2), (2 * hi, 0.06, cz1 - cz0), "plywood")
    for sgn in (-1, 1):
        v.qo("Body", "atlas", [V(sgn * hi, 0.58, cz0), V(sgn * hi, 0.58, cz1), V(sgn * (hi - 0.05), 2.12, cz1), V(sgn * (hi - 0.05), 2.12, cz0)], "cargo_wall", V(-sgn, 0, 0))
        g.box(V(sgn * (hi - 0.16), 0.73, 1.75), (0.30, 0.30, 0.92), "cargo_wall")
    g.quad([V(-hi, 2.12, cz0), V(hi, 2.12, cz0), V(hi, 2.12, cz1), V(-hi, 2.12, cz1)], RR("cargo_wall"), n=V(0, -1, 0))
    g.box(V(0, 1.35, -0.38), (2 * hi, 1.56, 0.04), "cargo_wall", faces={"-z": "dash"})
    v.bay(-2.30, -1.92, 0.66, "engine", "underside")
    v.interior()
    v.underside(-1.0, 2.6)
    v.col("Collision_Lower", (-1.01, 0.40, -2.62), (1.01, 1.12, 3.11))
    v.col("Collision_Upper", (-0.96, 1.12, -1.6), (0.96, 2.24, 2.95))
    return v


# ====================================================================== props (vehicle atlas)
def finish_prop(name, g, extra=()):
    P = np.array(g.g["p"])
    mn, mx = P.min(0), P.max(0)
    off = np.array([-(mn[0] + mx[0]) / 2, -mn[1], -(mn[2] + mx[2]) / 2])
    for p in g.g["p"]:
        p[0] += off[0]
        p[1] += off[1]
        p[2] += off[2]
    mn, mx = mn + off, mx + off
    cm = MB()
    cm.box(COL_KEY, tuple(mn), tuple(mx), skip=())
    ch = [{"name": name + "_Mesh", "mb": g.mb}, {"name": name + "_Col-convcolonly", "mb": cm},
          {"name": "Inspect_Center", "t": tuple(float(v) for v in (mn + mx) / 2)}]
    for nm, p in extra:
        ch.append({"name": nm, "t": tuple(float(v) for v in np.asarray(p) + off)})
    return {"name": name, "children": ch}, [round(float(v), 3) for v in mx - mn]


def props(mats):
    out = []
    A = mats.atlas
    def mk():                                # noqa: E306
        g = G()
        g.g = g.mb._g(A)
        return g
    # worn tyre lying flat
    g = mk()
    g.ring(V(0, 0, 0), V(0, 1, 0), 0.21, 0.31, 0.20, "tread", rect_top="sidewall", seg=16, inner_rect="rubber")
    out.append(("TRN_Tire", finish_prop("TRN_Tire", g), "Loose worn tyre lying flat (185/65 R14 class)."))
    # compact spare tyre on a black steel rim, standing
    g = mk()
    r, w = 0.30, 0.13
    prof = [(0, r * 0.68), (0.01, r * 0.95), (0.03, r), (w - 0.03, r), (w - 0.01, r * 0.95), (w, r * 0.68)]
    g.lathe(V(-w / 2, r, 0), V(1, 0, 0), prof, "sidewall", seg=14, rects=["sidewall", "sidewall", "tread", "sidewall", "sidewall"], cap_rect="rim_face")
    out.append(("TRN_SpareTire", finish_prop("TRN_SpareTire", g), "Compact spare wheel: narrow tyre on a black steel rim, standing."))
    # bare steel wheel rim lying flat
    g = mk()
    rr = 0.19
    g.lathe(V(0, 0, 0), V(0, 1, 0), [(0, rr), (0.02, rr * 0.96), (0.11, rr * 0.96), (0.13, rr)], "steel_dark", seg=14, cap_rect="rim_face")
    out.append(("TRN_WheelRim", finish_prop("TRN_WheelRim", g), "Bare 14-inch steel wheel rim lying flat."))
    # jerry-style plastic gas can
    g = mk()
    g.box(V(0, 0.17, 0), (0.17, 0.34, 0.32), "gascan_red", faces={"+x": "gascan_label", "-x": "gascan_label"})
    g.sweep([V(0, 0.34, -0.10), V(0, 0.41, -0.06), V(0, 0.41, 0.06), V(0, 0.34, 0.10)], 0.016, "gascan_red", seg=5)
    g.cyl(V(0, 0.32, -0.13), V(0, 0.42, -0.19), 0.022, 0.016, "amber", seg=6)
    g.cyl(V(0, 0.34, 0.12), V(0, 0.37, 0.12), 0.025, 0.025, "trim_black", seg=6)
    out.append(("TRN_GasCan", finish_prop("TRN_GasCan", g, extra=[("Grip", (0, 0.41, 0))]), "Red 5-gallon plastic gas can with spout and carry handle."))
    # roadside emergency warning triangle
    g = mk()
    s, h0 = 0.43, 0.04
    pts = [V(-s / 2, h0, 0), V(s / 2, h0, 0), V(0, h0 + s * math.sqrt(3) / 2, 0)]
    for a, b in ((0, 1), (1, 2), (2, 0)):
        p, q = pts[a], pts[b]
        d = q - p
        L = np.linalg.norm(d)
        ang = math.degrees(math.atan2(d[1], d[0]))
        g.box((p + q) / 2, (L + 0.04, 0.05, 0.02), "reflector_red", Rm=rot(roll=ang))
    g.box(V(0, 0.01, 0), (0.30, 0.02, 0.18), "steel_dark")
    g.box(V(0, 0.03, 0), (0.03, 0.04, 0.03), "steel_dark")
    out.append(("TRN_EmergencyTriangle", finish_prop("TRN_EmergencyTriangle", g), "Folding roadside warning triangle on a steel stand."))
    return out
