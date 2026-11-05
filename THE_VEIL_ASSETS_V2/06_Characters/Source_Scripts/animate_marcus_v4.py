"""Build Marcus v4 running variants. Requires numpy and Pillow. Original v4 stays intact."""
import math, os
import numpy as np
from chr_style_from_eddie import GLB, CHR, node_globals, qmat, png, rect, put
from PIL import Image
import io


def mul(a,b):
    x,y,z,w=a; X,Y,Z,W=b
    return np.array([w*X+x*W+y*Z-z*Y,w*Y-x*Z+y*W+z*X,w*Z+x*Y-y*X+z*W,w*W-x*X-y*Y-z*Z])

def axis(k,deg):
    deg = -deg if k == 0 else deg  # Imported Eddie/Marcus face -Z.
    q=np.zeros(4); q[k]=math.sin(math.radians(deg)/2); q[3]=math.cos(math.radians(deg)/2); return q

# Phase, thigh forward, knee flexion, ankle pitch (positive lifts the toe).
# Each leg lands, pushes off, folds back, then drives the knee forward.
STRIDE = np.array([
    (0.00, 31, 18,  8),
    (0.08, 18, 27,  0),
    (0.17,  0, 25,  0),
    (0.26,-21, 29,-15),
    (0.33,-30, 43,-31),
    (0.42,-23, 85,-22),
    (0.52, -4, 99, -8),
    (0.65, 29, 85,  1),
    (0.76, 49, 61,  5),
    (0.88, 43, 30, 12),
    (1.00, 31, 18,  8),
])


def inverse(q):
    return q*np.array([-1,-1,-1,1])/np.dot(q,q)

def scared_face(raw):
    # Use the existing 128x64 UV anchors, palette and one-pixel brush language.
    a=np.asarray(Image.open(io.BytesIO(raw)).convert('RGB')).copy()
    skin='#cf9b78'; dark='#241a16'; shade='#b98264'
    rect(a,49,20,31,15,skin)
    for cx in (56,72):
        rect(a,cx-4,26,9,6,dark)
        rect(a,cx-3,26,7,5,'#e6dccb')
        rect(a,cx-1,27,2,3,'#4a2e22')
        put(a,cx,27,dark)
        for x in range(cx-3,cx+4): put(a,x,33,shade)
    for x in range(51,61):
        y=24-(x-51)//2
        rect(a,x,y,1,2,dark); rect(a,129-x,y,1,2,dark)
    rect(a,62,22,1,2,'#9d6352'); rect(a,66,22,1,2,'#9d6352')
    rect(a,58,45,13,5,skin)
    rect(a,60,45,9,6,'#7a4238'); rect(a,61,46,7,4,dark)
    rect(a,62,46,5,1,'#d8ccb8'); rect(a,62,49,5,1,'#b0705e')
    return png(a)

def build(scared=False):
    source=os.path.join(CHR,'Marcus','CHR_Marcus_v4.glb')
    if not os.path.exists(source): source=os.path.join(CHR,'Marcus','CHR_Marcus.glb')
    g=GLB(source)
    js=g.js; nodes=js['nodes']; _,parents=node_globals(js)
    names={n.get('name'):i for i,n in enumerate(nodes)}
    rest={}
    def rq(i):
        if i not in rest: rest[i]=mul(rq(parents[i]) if i in parents else [0,0,0,1],nodes[i].get('rotation',[0,0,0,1]))
        return rest[i]
    for i in range(len(nodes)): rq(i)
    times=np.linspace(0,.72,25,dtype=np.float32)
    tracks={}
    def acc(a,typ):
        a=np.asarray(a,dtype=np.float32).reshape(len(a),-1); k=len(js['accessors']); A={'componentType':5126,'count':len(a),'type':typ}
        if typ=='SCALAR': A.update(min=[float(a.min())],max=[float(a.max())])
        js['accessors'].append(A); g.data[k]=a; return k
    for t in times:
        phase=float(t)/.72
        desired={}
        for side,sign in [('Left',1),('Right',-1)]:
            leg_phase=(phase+(0 if sign==1 else .5)) % 1
            thigh,flex,pitch=(np.interp(leg_phase,STRIDE[:,0],STRIDE[:,col]) for col in (1,2,3))
            swing=thigh/45
            # The shin rotates back relative to the thigh. Positive flexion
            # here means heel toward the back of the thigh on this -Z rig.
            for bone,angle in [('UpperLeg',-thigh),('LowerLeg',-thigh+flex),('Foot',-pitch),('Toes',-pitch*.5)]:
                i=names[side+bone]
                # Delta in world X, converted to the actual imported bone basis.
                desired[i]=mul(axis(0,angle),rest[i])
            for bone,angle in [('UpperArm',30*swing-12),('LowerArm',30*swing-12-72-12*swing),('Hand',18*swing-76)]:
                i=names[side+bone]
                direction=qmat(rest[i])[:,1]
                lower=math.degrees(math.atan2(-.98,-sign*.18)-math.atan2(direction[1],direction[0]))
                desired[i]=mul(axis(0,angle),mul(axis(2,lower),rest[i]))
        for name,angle in [('Hips',9),('Spine',7),('Chest',5),('UpperChest',3),('Neck',-8),('Head',-12)]:
            i=names[name]; desired[i]=mul(axis(0,angle),rest[i])
        animated={}
        def aq(i):
            if i not in animated:
                parent=aq(parents[i]) if i in parents else np.array([0,0,0,1])
                if i in desired:
                    q=mul(inverse(parent),desired[i]); q/=np.linalg.norm(q)
                    tracks.setdefault(i,[]).append(q)
                    animated[i]=desired[i]
                else: animated[i]=mul(parent,nodes[i].get('rotation',[0,0,0,1]))
            return animated[i]
        for i in range(len(nodes)): aq(i)
    anim={'name':'Run_Scared' if scared else 'Run','samplers':[],'channels':[],'extras':{'loop':True,'in_place':True,'cycle_seconds':.72}}
    ti=acc(times,'SCALAR')
    def channel(i,path,values,typ):
        si=len(anim['samplers']); anim['samplers'].append({'input':ti,'output':acc(values,typ),'interpolation':'LINEAR'}); anim['channels'].append({'sampler':si,'target':{'node':i,'path':path}})
    for i,values in tracks.items():
        for k in range(1,len(values)):
            if np.dot(values[k-1],values[k])<0: values[k]=-values[k]
        values[-1]=values[0].copy(); channel(i,'rotation',values,'VEC4')
    hips=names['Hips']; base=np.array(nodes[hips]['translation'])
    # Keep the support boot at floor level. Leave a small flight arc after toe-off.
    shoe=nodes[names['Marcus_Shoes']]
    skin=js['skins'][shoe['skin']]
    bind=g.acc(skin['inverseBindMatrices']).reshape(-1,4,4).transpose(0,2,1)
    sole=[]
    for primitive in js['meshes'][shoe['mesh']]['primitives']:
        a=primitive['attributes']
        v=g.acc(a['POSITION'])
        sole.append((np.c_[v,np.ones(len(v))],g.acc(a['JOINTS_0']),g.acc(a['WEIGHTS_0'])))
    values=[]
    for k,t in enumerate(times):
        posed=[dict(n) for n in nodes]
        for i,rotations in tracks.items(): posed[i]['rotation']=rotations[k]
        world,_=node_globals({'nodes':posed})
        matrices=np.array([world[i]@m for i,m in zip(skin['joints'],bind)])
        lowest=min(np.einsum('vbi,vi,vb->v',matrices[joints,1,:],v,weights).min() for v,joints,weights in sole)
        half_phase=(float(t)/.72) % .5
        flight=max(0,min(1,(half_phase-.33)/.17))
        height=.075*math.sin(math.pi*flight)
        values.append(base+[.012*math.sin(2*math.pi*float(t)/.72),height-lowest,0])
    values[-1]=values[0].copy(); channel(hips,'translation',values,'VEC3')
    js['animations']=[anim]
    images=[g.image(i) for i in range(len(js['images']))]
    if scared:
        i=next(i for i,x in enumerate(js['images']) if x['name']=='T_Marcus_Head'); images[i]=scared_face(images[i])
    out=os.path.join(CHR,'Marcus','CHR_Marcus_v4_'+('Scared_Run' if scared else 'Run')+'.glb')
    g.write(out,images)
    print(out)
    return out

if __name__=='__main__':
    build(); build(True)
