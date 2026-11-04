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
    g=GLB(os.path.join(CHR,'Marcus','CHR_Marcus_v4.glb'))
    js=g.js; nodes=js['nodes']; G,parents=node_globals(js)
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
        p=2*math.pi*float(t)/.72; s=math.sin(p)
        desired={}
        for side,sign in [('Left',1),('Right',-1)]:
            swing=sign*s
            for bone,angle in [('UpperLeg',-38*swing),('LowerLeg',-38*swing-(22+52*max(0,-swing))),('Foot',12+18*swing),('Toes',-8*max(0,swing))]:
                i=names[side+bone]
                # Delta in world X, converted to the actual imported bone basis.
                desired[i]=mul(axis(0,angle),rest[i])
            for bone,angle in [('UpperArm',30*swing-12),('LowerArm',30*swing-12-72-12*swing),('Hand',-8)]:
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
    values=[base+[.012*math.sin(2*math.pi*float(t)/.72),.025+.035*(1-math.cos(4*math.pi*float(t)/.72)),0] for t in times]
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
