"""Original Eddie mesh study. Python 3 + numpy + Pillow. No existing cast code/assets used.
Y up, +Z forward, metres. Explicit contour loops and garment seams, no SDF/voxel/primitive boolean pipeline.
"""
from pathlib import Path
import math,json,struct,io
import numpy as np
from PIL import Image,ImageDraw
OUT=Path(__file__).resolve().parent
# Each island has an intentional 64px tile in a 256px atlas. Pixel marks are drawn, never random noise.
colors=['#d5a47e','#372d32','#497b77','#304658','#eee1bb','#232934','#b56b49','#2c4141','#9b765e','#729c91','#be9866','#eee1bb','#161f2a','#e9c66a','#466176','#6a5147']
at=Image.new('RGB',(256,256));d=ImageDraw.Draw(at)
for i,c in enumerate(colors):
 x=(i%4)*64;y=(i//4)*64;d.rectangle((x,y,x+63,y+63),fill=c)
 if i in (2,3):
  # sewn edge, doubled hem, a few discrete wear pixels
  shade='#3b6664' if i==2 else '#263b4b'
  for xx in (5,58): d.line((x+xx,y+4,x+xx,y+59),fill=shade,width=2)
  for yy in (5,57): d.line((x+4,y+yy,x+59,y+yy),fill=shade,width=2)
  for yy in range(10,54,6):d.point((x+8,y+yy),fill='#78948b' if i==2 else '#586b79')
 if i==4:
  # original cartridge/ghost emblem; no third-party logo
  d.rectangle((x+19,y+18,x+44,y+43),fill='#394a51');d.rectangle((x+23,y+14,x+40,y+19),fill='#394a51')
  d.rectangle((x+24,y+25,x+27,y+29),fill='#e9c66a');d.rectangle((x+36,y+25,x+39,y+29),fill='#e9c66a')
  d.rectangle((x+27,y+38,x+36,y+40),fill='#e9c66a')
  d.rectangle((x+17,y+49,x+46,y+51),fill='#b56b49')
at.save(OUT/'Eddie_Atlas.png')
parts=[]
def mesh(name,v,f,tile=0,uv=None):
 v=np.array(v,float);f=np.array(f,int)
 if uv is None:
  span=np.ptp(v,axis=0);axes=np.argsort(span)[-2:];uv=(v[:,axes]-v[:,axes].min(0))/np.maximum(span[axes],1e-7)
 uv=np.array(uv,float); tx=tile%4;ty=tile//4
 uv=np.column_stack(((tx*64+2+uv[:,0]*59)/256,1-(ty*64+2+(1-uv[:,1])*59)/256))
 parts.append(dict(name=name,v=v,f=f,uv=uv,tile=tile));return parts[-1]
def loops(name,rings,tile=0,n=16,power=1,phase=0,cap=True):
 # rings = (centre xyz, halfwidth x, halfdepth z); each contour is independently art-directed
 v=[];uv=[]
 for j,(c,w,h) in enumerate(rings):
  for i in range(n):
   a=2*math.pi*i/n+phase;s=math.sin(a);co=math.cos(a)
   v.append(np.array(c)+[math.copysign(abs(s)**power,s)*w,0,math.copysign(abs(co)**power,co)*h]);uv.append([i/(n-1),j/(len(rings)-1)])
 f=[]
 for j in range(len(rings)-1):
  for i in range(n):
   a=j*n+i;b=j*n+(i+1)%n;c=b+n;dd=a+n
   f.extend([(a,b,c),(a,c,dd)])
 if cap:
  f += [(0,i+1,i) for i in range(1,n-1)]
  a=(len(rings)-1)*n;f += [(a,a+i,a+i+1) for i in range(1,n-1)]
 return mesh(name,v,f,tile,uv)
def ell(name,c,s,tile,n=16,k=8):
 rings=[]
 for j in range(k+1):
  a=-math.pi/2+math.pi*(j+.035)/(k+.07)
  rings.append(((c[0],c[1]+s[1]*math.sin(a),c[2]),s[0]*math.cos(a),s[2]*math.cos(a)))
 return loops(name,rings,tile,n)
def ribbon(name,pts,width,tile):
 v=[]
 for p in pts:v.extend([(p[0],p[1]-width/2,p[2]),(p[0],p[1]+width/2,p[2])])
 f=[]
 for i in range(len(pts)-1):a=2*i;f.extend([(a,a+2,a+3),(a,a+3,a+1)])
 return mesh(name,v,f,tile)
def panel(name,pts,tile):return mesh(name,pts,[(0,i,i+1) for i in range(1,len(pts)-1)],tile)
# Design sheet in geometry: 1.73m tall, 5.8 heads; comfortable adult proportions with broad cheek planes.
loops('Head_contour',[
 ((0,1.403,.032),.066,.071),((0,1.418,.033),.099,.087),((0,1.449,.028),.125,.100),
 ((0,1.488,.023),.143,.111),((0,1.531,.015),.148,.119),((0,1.575,.008),.143,.120),
 ((0,1.618,.001),.131,.109),((0,1.649,-.004),.106,.089),((0,1.669,-.008),.052,.047)],0,24,.80)
loops('Neck', [((0,1.321,0),.060,.058),((0,1.39,.008),.057,.058),((0,1.436,.012),.064,.063)],0,12)
# Short nose: shallow bridge -> broad tip; side/profile depth deliberately restrained.
loops('Nose',[((0,1.487,.119),.025,.008),((0,1.501,.132),.028,.020),((0,1.516,.136),.021,.022),((0,1.548,.119),.014,.007)],0,10)
for s in (-1,1):
 ell('Ear_'+str(s),(s*.147,1.518,.006),(.024,.039,.021),0,12,6)
 ell('Ear_inset_'+str(s),(s*.159,1.518,.020),(.008,.022,.004),8,10,4)
 # Eyes seated in the broad front planes, cream eyes and dark modest pupils.
 ell('Eye_socket_'+str(s),(s*.063,1.553,.113),(.043,.029,.010),8,16,6)
 ell('Eye_'+str(s),(s*.063,1.555,.121),(.034,.020,.007),11,16,6)
 ell('Pupil_'+str(s),(s*.060,1.554,.128),(.010,.014,.003),12,12,6)
 ell('Eye_glint_'+str(s),(s*.060-.003,1.559,.131),(.003,.004,.001),11,8,4)
 brow=[(s*.027,1.587+(s==1)*.008,.123),(s*.061,1.591+(s==1)*.010,.125),(s*.099,1.581+(s==1)*.007,.111)]
 ribbon('Raised_brow_'+str(s),brow,.010,1)
 # subtle lower lid, no exaggerated bags
 ribbon('Lower_lid_'+str(s),[(s*.036,1.533,.125),(s*.069,1.530,.126),(s*.094,1.537,.115)],.003,8)
ribbon('Half_smile',[(-.044,1.463,.121),(-.017,1.458,.132),(.011,1.458,.133),(.037,1.465,.125)],.004,15)
ribbon('Lower_lip',[(-.022,1.450,.129),(.005,1.448,.132),(.025,1.453,.128)],.003,8)
# Unified cap: irregular hem over ears and back, with explicitly modelled swept forelock strips.
v=[];f=[];n=24
for j in range(5):
 t=j/4
 for i in range(n):
  a=2*math.pi*i/n;s=math.sin(a);co=math.cos(a)
  hem=1.565+.054*max(co,0)-.018*max(-co,0)
  # top ring is small but nonzero, creating a facet rather than needle pole
  r=math.cos(t*1.49)
  v.append((s*.158*r-.018*t,hem+(1.714-hem)*math.sin(t*1.49),-.008+co*.131*r))
for j in range(4):
 for i in range(n):a=j*n+i;b=j*n+(i+1)%n;f.extend([(a,b,b+n),(a,b+n,a+n)])
f += [(96,96+i,96+i+1) for i in range(1,23)]
mesh('Hair_cap',v,f,1)
# Three broad tapered sweeps, not a pile of spheres/spikes.
for q,pts in enumerate([
 [(-.123,1.643,.090),(-.090,1.689,.112),(-.025,1.704,.123),(.070,1.674,.125),(.121,1.608,.104)],
 [(-.101,1.661,.111),(-.055,1.693,.137),(.013,1.682,.151),(.081,1.639,.139)],
 [(-.075,1.657,.134),(-.016,1.675,.153),(.043,1.650,.157),(.088,1.599,.123)]
]):
 vv=[]
 for j,p in enumerate(pts):
  w=.020*(1-j/len(pts))+.006
  vv.extend([(p[0],p[1]-w,p[2]),(p[0],p[1]+w,p[2]-.008),(p[0],p[1],p[2]+.014)])
 ff=[]
 for j in range(len(pts)-1):
  for a,b in [(0,2),(2,1),(1,0)]:ff.extend([(j*3+a,(j+1)*3+a,(j+1)*3+b),(j*3+a,(j+1)*3+b,j*3+b)])
 ff.extend([(0,1,2),((len(pts)-1)*3,(len(pts)-1)*3+2,(len(pts)-1)*3+1)])
 mesh('Swept_lock_'+str(q),vv,ff,1 if q!=1 else 15)
# Tee torso: intentional pear-shaped hanging hem, broad shoulders, narrowing collar.
loops('Tee_body',[((0,.881,0),.169,.102),((0,.912,0),.184,.115),((0,1.04,-.008),.185,.115),((0,1.18,-.013),.206,.116),((0,1.275,-.019),.207,.101),((0,1.326,-.013),.115,.074)],11,20,.68)
# Overshirt panels wrap the sides and back. Front opening defined by actual mesh boundary.
v=[];uv=[];n=21
for j,(y,w,dep) in enumerate([(.898,.192,.145),(.94,.196,.149),(1.065,.199,.150),(1.20,.219,.148),(1.282,.217,.128),(1.32,.119,.088)]):
 for i in range(n):
  a=.36+(2*math.pi-.72)*i/(n-1)
  v.append((math.sin(a)*w,y,-.016+math.cos(a)*dep));uv.append((i/(n-1),j/5))
f=[]
for j in range(5):
 for i in range(n-1):a=j*n+i;f.extend([(a,a+1,a+1+n),(a,a+1+n,a+n)])
mesh('Open_overshirt',v,f,2,uv)
for s in (-1,1):
 panel('Folded_collar_'+str(s),[(s*.052,1.328,.064),(s*.108,1.316,.069),(s*.137,1.257,.105),(s*.080,1.276,.115)],9)
 panel('Pocket_'+str(s),[(s*.10,1.188,.151),(s*.177,1.183,.133),(s*.176,1.111,.136),(s*.139,1.098,.150),(s*.101,1.111,.157)],2)
 ribbon('Pocket_flap_'+str(s),[(s*.104,1.174,.159),(s*.14,1.168,.156),(s*.173,1.172,.141)],.010,9)
 # Sleeves: broad shoulder drapes into elbow, cuff break conceals separate forearm loop.
 loops('Sleeve_'+str(s),[((s*.18,1.283,-.011),.064,.086),((s*.234,1.265,-.010),.083,.087),((s*.281,1.17,-.005),.077,.082),((s*.322,1.073,.004),.067,.070),((s*.330,1.051,.006),.069,.073)],2,12,.8)
 loops('Rolled_cuff_'+str(s),[((s*.324,1.082,.004),.071,.074),((s*.338,1.044,.007),.073,.075),((s*.337,1.031,.008),.061,.063)],9,12,.8)
 loops('Forearm_'+str(s),[((s*.337,1.052,.008),.050,.049),((s*.356,.989,.018),.048,.045),((s*.375,.920,.027),.036,.035),((s*.38,.899,.029),.033,.034)],0,12,.85)
 # Palm contour, thumb and four short separate fingers with real three-dimensional silhouettes.
 loops('Palm_'+str(s),[((s*.38,.918,.028),.032,.030),((s*.389,.876,.035),.039,.028),((s*.393,.836,.037),.035,.024)],0,12,.65)
 for k in range(4):
  x=s*(.367+k*.017);length=[.045,.055,.051,.039][k]
  loops('Finger_%s_%s'%(s,k),[((x,.847,.037),.009,.013),((x+s*.002,.820,.043),.009,.012),((x+s*.002,.847-length,.042),.007,.009)],0,8)
 loops('Thumb_'+str(s),[((s*.359,.878,.047),.014,.016),((s*.345,.853,.060),.014,.015),((s*.347,.830,.064),.010,.010)],0,8)
 # Jeans contoured around hip, knee and taper, with small deliberate front knee fold.
 loops('Jeans_leg_'+str(s),[((s*.091,.934,0),.096,.108),((s*.099,.83,0),.099,.109),((s*.105,.671,.001),.084,.092),((s*.11,.502,.018),.077,.084),((s*.115,.463,.009),.081,.079),((s*.118,.429,-.005),.073,.077),((s*.12,.25,-.008),.066,.072),((s*.122,.147,-.006),.067,.071)],3,16,.72)
 loops('Trouser_cuff_'+str(s),[((s*.122,.176,-.005),.070,.075),((s*.122,.144,-.005),.071,.076)],14,16,.72)
 loops('Sneaker_'+str(s),[((s*.123,.026,.053),.079,.151),((s*.123,.052,.055),.084,.155),((s*.123,.095,.046),.080,.143),((s*.123,.132,.005),.064,.086),((s*.123,.155,-.018),.054,.060)],5,16,.65)
 loops('Rubber_sole_'+str(s),[((s*.123,.012,.055),.082,.154),((s*.123,.036,.055),.086,.157),((s*.123,.048,.055),.085,.156)],11,16,.65)
 panel('Shoe_tongue_'+str(s),[(s*.123-.034,.115,.10),(s*.123+.034,.115,.10),(s*.123+.035,.072,.171),(s*.123-.035,.072,.171)],6)
 for yy,zz in [(.106,.117),(.094,.137),(.082,.155)]:ribbon('Laces',[(s*.123-.026,yy,zz),(s*.123+.026,yy,zz)],.006,11)
panel('Original_cartridge_emblem',[(-.047,1.228,.108),(.047,1.228,.108),(.047,1.106,.112),(-.047,1.106,.112)],4)
# Tiny enamel pin and hanging employee badge, distinct at conversational distance.
ell('Pin',(-.165,1.224,.097),(.012,.012,.004),13,10,4)
panel('Badge',[(.109,1.10,.135),(.161,1.10,.123),(.162,1.064,.125),(.108,1.064,.138)],4)
ribbon('Badge_stripe',[(.115,1.075,.140),(.155,1.075,.131)],.006,6)
for p in parts:
 if p['name'].startswith(('Head','Nose','Ear','Eye','Pupil','Raised','Lower_lid','Half_smile','Lower_lip','Hair','Swept')):p['v'][:,1]-=.023
# Thin rounded-square acetate spectacles: clear openings, no opaque fake lenses.
def tube_path(name,pts,r,tile):
 vv=[];ff=[]
 for j,pt in enumerate(pts):
  tangent=np.array(pts[(j+1)%len(pts)])-np.array(pts[j-1]);tangent/=np.linalg.norm(tangent)
  u=np.cross(tangent,[0,0,1]);u/=max(np.linalg.norm(u),1e-8);w=np.cross(tangent,u)
  for k in range(6):vv.append(np.array(pt)+r*(math.cos(k*math.pi/3)*u+math.sin(k*math.pi/3)*w))
 for j in range(len(pts)):
  for k in range(6):
   a=j*6+k;b=j*6+(k+1)%6;c=((j+1)%len(pts))*6+(k+1)%6;dd=((j+1)%len(pts))*6+k
   ff.extend([(a,b,c),(a,c,dd)])
 return mesh(name,vv,ff,tile)
for sx in (-1,1):
 pts=[]
 for k in range(16):
  a=2*math.pi*k/16;co=math.cos(a);si=math.sin(a)
  x=sx*.063+math.copysign(abs(co)**.6,co)*.041
  pts.append((x,1.532+math.copysign(abs(si)**.6,si)*.027,.139-.08*abs(x)))
 tube_path('Spectacle_frame_'+str(sx),pts,.0035,7)
 ribbon('Spectacle_arm_'+str(sx),[(sx*.102,1.541,.132),(sx*.148,1.538,.065),(sx*.155,1.526,.009)],.006,7)
ribbon('Spectacle_bridge',[(-.022,1.539,.141),(0,1.545,.147),(.022,1.539,.141)],.005,7)
# Correct all winding using mesh component signed volumes (open panels retain outward manually).
for p in parts:
 v=p['v'];f=p['f'];vol=np.sum(np.einsum('ij,ij->i',v[f[:,0]],np.cross(v[f[:,1]],v[f[:,2]])))/6
 if vol<0:p['f']=f[:,[0,2,1]]
# GLB with per-part nodes, one embedded atlas, smooth angle-weighted vertex normals.
binbuf=bytearray();views=[];acc=[]
def add(data,typ,ctype,mins=None,maxs=None):
 while len(binbuf)%4:binbuf.append(0)
 off=len(binbuf);binbuf.extend(data.tobytes());views.append(dict(buffer=0,byteOffset=off,byteLength=data.nbytes))
 a=dict(bufferView=len(views)-1,componentType=ctype,count=len(data),type=typ)
 if mins is not None:a.update(min=mins,max=maxs)
 acc.append(a);return len(acc)-1
meshes=[];nodes=[]
allv=[];allf=[];alluv=[];offset=0
for pp in parts:
 allv.extend(pp['v']);allf.extend(pp['f']+offset);alluv.extend(pp['uv']);offset+=len(pp['v'])
export_parts=[dict(name='Eddie_Prototype',v=np.array(allv),f=np.array(allf),uv=np.array(alluv))]
for p in export_parts:
 v=p['v'].astype('<f4');f=p['f'];norm=np.zeros_like(v)
 fn=np.cross(v[f[:,1]]-v[f[:,0]],v[f[:,2]]-v[f[:,0]])
 for i in range(3):np.add.at(norm,f[:,i],fn)
 norm/=np.maximum(np.linalg.norm(norm,axis=1,keepdims=True),1e-9)
 pos=add(v,'VEC3',5126,v.min(0).tolist(),v.max(0).tolist());nn=add(norm,'VEC3',5126);uv=add(p['uv'].astype('<f4'),'VEC2',5126);idx=add(f.astype('<u2').ravel(),'SCALAR',5123)
 meshes.append(dict(name=p['name'],primitives=[dict(attributes=dict(POSITION=pos,NORMAL=nn,TEXCOORD_0=uv),indices=idx,material=0)]));nodes.append(dict(name=p['name'],mesh=len(meshes)-1))
while len(binbuf)%4:binbuf.append(0)
img=(OUT/'Eddie_Atlas.png').read_bytes();views.append(dict(buffer=0,byteOffset=len(binbuf),byteLength=len(img)));binbuf.extend(img)
g=dict(asset=dict(version='2.0',generator='THE VEIL / original Eddie contour study'),scene=0,scenes=[dict(nodes=list(range(len(nodes))))],nodes=nodes,meshes=meshes,accessors=acc,bufferViews=views,buffers=[dict(byteLength=len(binbuf))],images=[dict(bufferView=len(views)-1,mimeType='image/png')],samplers=[dict(magFilter=9728,minFilter=9728,wrapS=33071,wrapT=33071)],textures=[dict(sampler=0,source=0)],materials=[dict(name='Eddie_pixel_atlas',doubleSided=True,pbrMetallicRoughness=dict(baseColorTexture=dict(index=0),metallicFactor=0,roughnessFactor=1))])
j=json.dumps(g,separators=(',',':')).encode();j+=b' '*((-len(j))%4);binbuf+=b'\0'*((-len(binbuf))%4)
raw=struct.pack('<III',0x46546c67,2,12+8+len(j)+8+len(binbuf))+struct.pack('<II',len(j),0x4e4f534a)+j+struct.pack('<II',len(binbuf),0x004e4942)+binbuf
(OUT/'Eddie_Prototype.glb').write_bytes(raw)
# Portable editable topology source, in addition to this fully reproducible script.
with (OUT/'Eddie_Editable.obj').open('w') as o:
 o.write('# Y up; metres; +Z forward. Atlas UVs.\nmtllib Eddie_Editable.mtl\n');off=1
 for p in parts:
  o.write('o '+p['name']+'\nusemtl Eddie_pixel_atlas\n')
  for v in p['v']:o.write('v '+' '.join(map(str,v))+'\n')
  for uv in p['uv']:o.write('vt '+' '.join(map(str,uv))+'\n')
  for face in p['f']:o.write('f '+' '.join('%d/%d'%(i+off,i+off) for i in face)+'\n')
  off+=len(p['v'])
(OUT/'Eddie_Editable.mtl').write_text('newmtl Eddie_pixel_atlas\nKd 1 1 1\nKs 0 0 0\nmap_Kd Eddie_Atlas.png\n')
report=dict(vertices=sum(len(p['v']) for p in parts),triangles=sum(len(p['f']) for p in parts),objects=len(parts),height_m=float(max(p['v'][:,1].max() for p in parts)),glb_bytes=len(raw),rigged=False,engine_import_test='NOT RUN: Godot executable unavailable')
(OUT/'validation.json').write_text(json.dumps(report,indent=2));print(report)
# Single inspection contact sheet, rasterized directly from exported mesh data.
def render(yaw):
 W,H=440,650;im=np.full((H,W,3),[39,44,48],np.uint8);depth=np.full((H,W),-1e6,float)
 a=math.radians(yaw);R=np.array([[math.cos(a),0,-math.sin(a)],[0,1,0],[math.sin(a),0,math.cos(a)]])
 light=np.array([-.4,.7,1]);light/=np.linalg.norm(light)
 for p in parts:
  v=p['v']@R.T;vv=v.copy();vv[:,0]=vv[:,0]*335+W/2;vv[:,1]=H-40-vv[:,1]*335
  for face in p['f']:
   pts=vv[face];nrm=np.cross(v[face[1]]-v[face[0]],v[face[2]]-v[face[0]]);nrm/=max(np.linalg.norm(nrm),1e-9)
   # two-sided preview matches GLB
   shade=.65+.35*max(0,np.dot(nrm,light))
   x0=max(0,int(np.floor(pts[:,0].min())));x1=min(W-1,int(np.ceil(pts[:,0].max())));y0=max(0,int(np.floor(pts[:,1].min())));y1=min(H-1,int(np.ceil(pts[:,1].max())))
   if x1<x0 or y1<y0:continue
   X,Y=np.meshgrid(np.arange(x0,x1+1)+.5,np.arange(y0,y1+1)+.5)
   x,y=pts[:,0],pts[:,1];den=(y[1]-y[2])*(x[0]-x[2])+(x[2]-x[1])*(y[0]-y[2])
   if abs(den)<1e-8:continue
   b0=((y[1]-y[2])*(X-x[2])+(x[2]-x[1])*(Y-y[2]))/den;b1=((y[2]-y[0])*(X-x[2])+(x[0]-x[2])*(Y-y[2]))/den;b2=1-b0-b1
   z=b0*pts[0,2]+b1*pts[1,2]+b2*pts[2,2];mask=(b0>=0)&(b1>=0)&(b2>=0)&(z>depth[y0:y1+1,x0:x1+1])
   uv=p['uv'][face];U=b0*uv[0,0]+b1*uv[1,0]+b2*uv[2,0];V=b0*uv[0,1]+b1*uv[1,1]+b2*uv[2,1]
   tex=np.array(at)[np.clip(((1-V)*256).astype(int),0,255),np.clip((U*256).astype(int),0,255)]
   im[y0:y1+1,x0:x1+1][mask]=(tex*shade).astype(np.uint8)[mask];depth[y0:y1+1,x0:x1+1][mask]=z[mask]
 return Image.fromarray(im)
if __name__=='__main__':
 sheet=Image.new('RGB',(1320,650))
 for k,a in enumerate([0,-35,-90]):sheet.paste(render(a),(440*k,0))
 sheet.save(OUT/'inspection.png')
