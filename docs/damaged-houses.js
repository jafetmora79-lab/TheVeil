import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';

// Immutable game commit: model previews do not change if the active game branch moves.
const revision = 'c733eadc94acfd77f5517003fae6dae6c9ce6caf';
const variants = {HOUSE_09:'Ranch_C_Mirror', HOUSE_11:'Cottage_B_Mirror', HOUSE_14:'TwoStorey',
  HOUSE_17:'TwoStorey_B', HOUSE_18:'Ranch_B', EXT_HOUSE_02:'TwoStorey', EXT_HOUSE_12:'Ranch_B',
  EXT_HOUSE_19:'Ranch_C_Mirror', EXT_HOUSE_29:'Cottage_B_Mirror'};
const houses = ['HOUSE_09','HOUSE_11','HOUSE_14','HOUSE_17','HOUSE_18',
  'EXT_HOUSE_02','EXT_HOUSE_12','EXT_HOUSE_19','EXT_HOUSE_29'];
const $ = id => document.getElementById(id);
const scene = new THREE.Scene();
scene.background = new THREE.Color(0x242a2c);
const camera = new THREE.PerspectiveCamera(60, 1, 0.05, 250);
const renderer = new THREE.WebGLRenderer({ antialias: false });
renderer.setPixelRatio(Math.min(devicePixelRatio, 1.5));
renderer.outputColorSpace = THREE.SRGBColorSpace;
$('view').append(renderer.domElement);
scene.add(new THREE.HemisphereLight(0xf1ece3, 0x53505a, 2.5));
const sun = new THREE.DirectionalLight(0xffe3c2, 2); sun.position.set(-8, 15, -10); scene.add(sun);
const controls = new OrbitControls(camera, renderer.domElement);
controls.enableDamping = true;
controls.minDistance = 1;
controls.maxDistance = 110;
const ground = new THREE.Mesh(new THREE.PlaneGeometry(150, 150),
  new THREE.MeshLambertMaterial({color:0x353c38}));
ground.rotation.x = -Math.PI/2; ground.position.y = -0.025; scene.add(ground);
const loader = new GLTFLoader();
let current = null;
let loading = 0;
function resize(){const w=innerWidth,h=innerHeight;renderer.setSize(w,h);camera.aspect=w/h;camera.updateProjectionMatrix();}
addEventListener('resize',resize);resize();
function frame(){
  if(!current)return;
  const box = new THREE.Box3().setFromObject(current);
  const center=box.getCenter(new THREE.Vector3());
  const distance=Math.max(10,box.getSize(new THREE.Vector3()).length()*0.85);
  controls.target.copy(center);
  camera.position.copy(center).add(new THREE.Vector3(distance*.7,distance*.52,-distance));
  controls.update();
}
const materialsByVariant = new Map();
async function originalMaterials(id){
  const variant = variants[id];
  if(materialsByVariant.has(variant)) return materialsByVariant.get(variant);
  const base = `https://raw.githubusercontent.com/jafetmora79-lab/TheVeil/${revision}/THE_VEIL_ASSETS_V2/03_Residential/House_Variants/`;
  const design = variant.split('_')[0];
  const furnishing = `RES_House_${design}${variant.endsWith('_Mirror')?'_Mirror':''}_Furnishing.glb`;
  const roots = await Promise.all([`RES_House_${variant}.glb`, furnishing].map(name=>loader.loadAsync(base+name)));
  const map = new Map();
  for(const {scene: donor} of roots) donor.traverse(node=>{
    if(!node.isMesh) return;
    for(const material of [].concat(node.material)) if(material) map.set(material.name, material);
  });
  materialsByVariant.set(variant,map);
  return map;
}
async function show(){
  const id=$('house').value;
  const turn=++loading;
  $('status').textContent=`Loading ${id}…`;
  try {
    const [gltf, materials] = await Promise.all([
      loader.loadAsync(`https://raw.githubusercontent.com/jafetmora79-lab/TheVeil/${revision}/game/world/destroyed/${id}.glb`),
      originalMaterials(id)
    ]);
    if(turn!==loading)return;
    if(current)scene.remove(current);
    current=gltf.scene;
    let restored=0;
    current.traverse(n=>{if(n.isMesh){
      n.material = [].concat(n.material).map(m=>{
        const gameMaterial = materials.get(m.name);
        if(gameMaterial){restored++;return gameMaterial;}
        return m;
      });
      if(n.material.length===1)n.material=n.material[0];
      for(const m of [].concat(n.material)){
        m.side=THREE.DoubleSide;
        if(m.map){m.map.magFilter=THREE.NearestFilter;m.map.minFilter=THREE.NearestMipmapNearestFilter;}
      }
    }});
    scene.add(current);
    current.traverse(n=>{if(n.name.endsWith('-colonly')||n.name.endsWith('-convcolonly'))n.visible=false;});
    toggleRoof();frame();
    $('status').textContent=`${id.replaceAll('_',' ')} · damaged model · ${restored} materials restored`;
    history.replaceState(null,'',`?house=${id}`);
  } catch(error){if(turn===loading)$('status').textContent=`Cannot load ${id}: ${error.message||error}`;}

}
function toggleRoof(){if(current)current.traverse(n=>{
  if(n.isMesh&&/Exterior|Roof/i.test(n.name))n.visible=$('roof').checked;
});}
for(const id of houses)$('house').add(new Option(id.replaceAll('_',' '),id));
const initial=new URLSearchParams(location.search).get('house');
if(houses.includes(initial))$('house').value=initial;
$('house').onchange=show;$('roof').onchange=toggleRoof;$('reset').onclick=frame;
renderer.setAnimationLoop(()=>{controls.update();renderer.render(scene,camera);});
show();
