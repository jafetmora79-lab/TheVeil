"""Independent structural checks; deliberately does not claim Godot import/conformance certification."""
import json,struct,io
from pathlib import Path
import numpy as np
from PIL import Image
P=Path(__file__).resolve().parent;b=(P/'Eddie_Prototype.glb').read_bytes()
magic,version,total=struct.unpack_from('<III',b);assert magic==0x46546c67 and version==2 and total==len(b)
n,t=struct.unpack_from('<II',b,12);assert t==0x4e4f534a;g=json.loads(b[20:20+n]);bn,bt=struct.unpack_from('<II',b,20+n);assert bt==0x004e4942;buf=b[28+n:];assert bn==len(buf)
for v in g['bufferViews']:assert v.get('byteOffset',0)+v['byteLength']<=len(buf)
def read(i):
 a=g['accessors'][i];v=g['bufferViews'][a['bufferView']];sz={'SCALAR':1,'VEC2':2,'VEC3':3}[a['type']];dt={5126:'<f4',5123:'<u2'}[a['componentType']]
 ar=np.frombuffer(buf,dtype=dt,count=a['count']*sz,offset=v.get('byteOffset',0)+a.get('byteOffset',0)).reshape(-1,sz);assert np.isfinite(ar).all();return ar
triangles=0;vertices=0
for m in g['meshes']:
 for pr in m['primitives']:
  a=pr['attributes'];v=read(a['POSITION']);uv=read(a['TEXCOORD_0']);normal=read(a['NORMAL']);f=read(pr['indices']).reshape(-1,3)
  assert len(v)==len(uv)==len(normal);assert f.max()<len(v);assert uv.min()>=0 and uv.max()<=1
  areas=np.linalg.norm(np.cross(v[f[:,1]]-v[f[:,0]],v[f[:,2]]-v[f[:,0]]),axis=1);assert areas.min()>1e-12
  assert np.allclose(np.linalg.norm(normal,axis=1),1,atol=1e-4)
  triangles+=len(f);vertices+=len(v)
im=g['images'][0];vv=g['bufferViews'][im['bufferView']];image=Image.open(io.BytesIO(buf[vv['byteOffset']:vv['byteOffset']+vv['byteLength']]));assert image.size==(256,256)
assert g['samplers'][0]['magFilter']==9728 and g['samplers'][0]['minFilter']==9728
r=json.loads((P/'validation.json').read_text());r.update(structural_checks='PASS: GLB chunks, buffer bounds, indices, finite data, nonzero triangle areas, unit normals, UV ranges, embedded PNG and nearest sampler',export_meshes=len(g['meshes']),materials=len(g['materials']),export_vertices=vertices,export_triangles=triangles)
(P/'validation.json').write_text(json.dumps(r,indent=2));print(json.dumps(r,indent=2))
