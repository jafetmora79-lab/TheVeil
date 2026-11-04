"""THE VEIL - z-fighting scan (no rendering): finds opaque triangles that are coplanar (< 0.4 mm apart), face the
same way, overlap by more than 4 cm^2, show different texels at the overlap, and are open in front (not a hidden
contact face). Those flicker in the Compatibility renderer.
    python3 THE_VEIL_ASSETS_V2/Source_Scripts/zfight_scan.py THE_VEIL_ASSETS_V2/04_Commercial/*/*.glb
Prints one line per file with hits; writes zfight_scan.json next to the current directory.
"""
import sys, os, json, numpy as np
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "02_Town", "Source_Scripts"))
import validate_town as VT
def qm(q):
    x,y,z,w=q
    return np.array([[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],[2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],[2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]])
def tris_uv(path):
    js,b=VT.read_glb(path); out=[]
    def walk(i,M):
        n=js['nodes'][i]; L=np.eye(4)
        if 'rotation' in n: L[:3,:3]=qm(n['rotation'])
        if 'scale' in n: L[:3,:3]=L[:3,:3]@np.diag(n['scale'])
        if 'translation' in n: L[:3,3]=n['translation']
        M2=M@L
        if 'mesh' in n and 'colonly' not in n['name'] and 'skin' not in n:
            for p in js['meshes'][n['mesh']]['primitives']:
                if 'material' not in p: continue
                P=VT.accessor(js,b,p['attributes']['POSITION']); I=VT.accessor(js,b,p['indices']).reshape(-1,3)
                UV=VT.accessor(js,b,p['attributes']['TEXCOORD_0']) if 'TEXCOORD_0' in p['attributes'] else np.zeros((len(P),2))
                Pw=P@M2[:3,:3].T+M2[:3,3]
                mat=js['materials'][p['material']]
                out.append((mat['name'], bool(mat.get('doubleSided')), Pw[I], mat.get('alphaMode','OPAQUE'), UV[I]))
        for c in n.get('children',[]): walk(c,M2)
    for r in js['scenes'][0]['nodes']: walk(r,np.eye(4))
    return out
MIN_A = 0.0004
BAR = np.array([(a, b) for a in np.linspace(0.08, 0.84, 6) for b in np.linspace(0.08, 0.84, 6) if a + b < 0.92])
def inside(P, A, B, C, n):
    # P: (k,3) points, triangle ABC with normal n -> bool (k,)
    def s(p, q, r): return (np.cross(q - p, r - p) @ n)
    return (s(A, B, P) >= -1e-7) & (s(B, C, P) >= -1e-7) & (s(C, A, P) >= -1e-7)
CONE = None
def visible(T, n, c, reach=0.03):
    """open in front: >= 3 of 5 rays in a 40-degree cone around n travel > reach without hitting anything"""
    a = np.array([1.0, 0, 0]) if abs(n[0]) < 0.9 else np.array([0, 1.0, 0])
    u = np.cross(n, a); u /= np.linalg.norm(u); v = np.cross(n, u)
    dirs = [n] + [n * 0.77 + 0.64 * (np.cos(k * 1.57) * u + np.sin(k * 1.57) * v) for k in range(4)]
    e1 = T[:, 1] - T[:, 0]; e2 = T[:, 2] - T[:, 0]
    o = c + n * 1e-3
    free = 0
    for d in dirs:
        h = np.cross(d, e2); a_ = (e1 * h).sum(1); m = np.abs(a_) > 1e-12
        f = np.zeros_like(a_); f[m] = 1 / a_[m]
        s = o - T[:, 0]; uu = f * (s * h).sum(1); q = np.cross(s, e1); vv = f * (q @ d); t = f * (e2 * q).sum(1)
        hit = m & (uu >= 0) & (vv >= 0) & (uu + vv <= 1) & (t > 1e-5) & (t < reach)
        free += int(not hit.any())
    return free >= 3
def scan(path):
    parts = tris_uv(path)
    parts = [(nm, t, uv) for nm, ds, t, am, uv in parts if am == 'OPAQUE']
    if not parts: return []
    T = np.concatenate([t for _, t, _ in parts]); own = np.concatenate([[nm] * len(t) for nm, t, _ in parts])
    UV = np.concatenate([uv for _, _, uv in parts])
    e1 = T[:, 1] - T[:, 0]; e2 = T[:, 2] - T[:, 0]; N = np.cross(e1, e2); A2 = np.linalg.norm(N, axis=1)
    ok = A2 > 2e-6
    T, own, N, A2, UV = T[ok], own[ok], N[ok], A2[ok], UV[ok]
    Nn = N / A2[:, None]; D = (Nn * T[:, 0]).sum(1)
    key = {}
    for i in range(len(T)):
        k = (tuple(np.round(Nn[i], 2)), int(np.floor(D[i] / 0.002)))
        key.setdefault(k, []).append(i)
    hits = []
    seen = set()
    for (nk, dk), idx in key.items():
        cand = list(idx)
        for dd in (-1, 1):
            cand += [j for j in key.get((nk, dk + dd), []) if j > max(idx)]
        if len(cand) < 2: continue
        cand = np.array(cand)
        lo = T[cand].min(1); hi = T[cand].max(1)
        for a in range(len(cand)):
            i = cand[a]
            m = np.all(lo[a + 1:] < hi[a] + 5e-4, 1) & np.all(hi[a + 1:] > lo[a] - 5e-4, 1)
            for b in np.nonzero(m)[0] + a + 1:
                j = cand[b]
                if (i, j) in seen: continue
                seen.add((i, j))
                if Nn[i] @ Nn[j] < 0.999 or abs(D[i] - D[j]) > 0.0004: continue
                P = T[i, 0] + BAR[:, :1] * (T[i, 1] - T[i, 0]) + BAR[:, 1:] * (T[i, 2] - T[i, 0])
                ins = inside(P, T[j, 0], T[j, 1], T[j, 2], Nn[i])
                f = ins.mean()
                ov = f * A2[i] / 2
                if ov <= MIN_A: continue
                if own[i] == own[j]:
                    # same material: harmless when both faces show the same texels at the overlap
                    Pi = P[ins]
                    def bary(Tr, Q):
                        v0 = Tr[1] - Tr[0]; v1 = Tr[2] - Tr[0]; v2 = Q - Tr[0]
                        d00 = v0 @ v0; d01 = v0 @ v1; d11 = v1 @ v1; d20 = v2 @ v0; d21 = v2 @ v1
                        den = d00 * d11 - d01 * d01
                        b1 = (d11 * d20 - d01 * d21) / den; b2 = (d00 * d21 - d01 * d20) / den
                        return np.stack([1 - b1 - b2, b1, b2], 1)
                    ui = bary(T[i], Pi) @ UV[i]; uj = bary(T[j], Pi) @ UV[j]
                    if np.abs(ui - uj).max() < 0.004: continue
                c = P[ins].mean(0)
                if not visible(T, Nn[i], c): continue
                hits.append((own[i], own[j], float(ov), [round(float(v), 2) for v in c], [round(float(v), 2) for v in Nn[i]]))
    return hits
if __name__ == '__main__':
    out = {}
    for p in sys.argv[1:]:
        h = scan(p)
        if h:
            pairs = {}
            for a, b, ov, c, n in h:
                k = (str(a), str(b), tuple(n)); pairs.setdefault(k, [0.0, c]); pairs[k][0] += ov
            out[p] = sorted([[k[0], k[1], round(v[0], 4), v[1], list(k[2])] for k, v in pairs.items()], key=lambda r: -r[2])
            print(p, len(h), 'tris', round(sum(x[2] for x in h), 3), 'm2', out[p][:4], flush=True)
    json.dump(out, open('zfight_scan.json', 'w'), indent=1)
