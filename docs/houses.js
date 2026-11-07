// THE VEIL - house walkthrough: loads a Pack 03 house shell + its baked furnishing straight from the repository
// (raw.githubusercontent.com, any branch) and lets you walk inside. Nothing in the repository is modified.
import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { PointerLockControls } from 'three/addons/controls/PointerLockControls.js';

const OWNER = 'jafetmora79-lab', REPO = 'TheVeil', DIR = 'THE_VEIL_ASSETS_V2/03_Residential/House_Variants/';
const DEFAULT_BRANCH = 'claude/greyhaven-residential-reconstruction';
const REBUILT = ['Cottage', 'TwoStorey'];
const HOUSES = ['Cottage', 'Cottage_B', 'Cottage_B_Mirror', 'TwoStorey', 'TwoStorey_B', 'TwoStorey_Mirror',
  'Ranch', 'Ranch_B', 'Ranch_C', 'Ranch_C_Mirror', 'Ranch_Mirror', 'Bungalow', 'Bungalow_B', 'Bungalow_B_Mirror',
  'Bungalow_Mirror', 'Farmhouse', 'SplitLevel', 'SplitLevel_B', 'SplitLevel_Mirror', 'Abandoned', 'MillWorker',
  'MillWorker_B', 'PlayerHome'];
const FLOOR = 0.6, EYE = 1.6;

const $ = id => document.getElementById(id);
const params = new URLSearchParams(location.search);
$('branch').value = params.get('branch') || DEFAULT_BRANCH;
for (const h of HOUSES) {
  const design = h.split('_')[0];
  $('house').append(new Option((REBUILT.includes(design) ? '★ ' : '') + h.replaceAll('_', ' '), h));
}
if (params.get('house') && HOUSES.includes(params.get('house'))) $('house').value = params.get('house');

const shellName = h => h === 'PlayerHome' ? 'RES_PlayerHome' : 'RES_House_' + h;
// colourways (_B/_C) share the design's furnishing; mirrors have their own
const furnName = h => h === 'PlayerHome' ? 'RES_PlayerHome_Furnishing'
  : 'RES_House_' + h.split('_')[0] + (h.endsWith('_Mirror') ? '_Mirror' : '') + '_Furnishing';
const url = (branch, file) => `https://raw.githubusercontent.com/${OWNER}/${REPO}/${branch.split('/').map(encodeURIComponent).join('/')}/${DIR}${file}.glb`;

// ---------------------------------------------------------------- scene
const renderer = new THREE.WebGLRenderer({ antialias: false });
renderer.setPixelRatio(Math.min(devicePixelRatio, 1.5));
renderer.outputColorSpace = THREE.SRGBColorSpace;
$('view').append(renderer.domElement);
const scene = new THREE.Scene();
scene.background = new THREE.Color(0x1d2328);
scene.fog = new THREE.Fog(0x1d2328, 30, 90);
const camera = new THREE.PerspectiveCamera(70, 1, 0.05, 300);
scene.add(new THREE.HemisphereLight(0xdfe6ea, 0x3a3328, 1.6));
const sun = new THREE.DirectionalLight(0xffffff, 1.2); sun.position.set(8, 14, -6); scene.add(sun);
const lamp = new THREE.PointLight(0xfff1d6, 6, 9, 1.6); camera.add(lamp); scene.add(camera);   // a torch so rooms are readable
const ground = new THREE.Mesh(new THREE.PlaneGeometry(200, 200), new THREE.MeshLambertMaterial({ color: 0x2e3a2c }));
ground.rotation.x = -Math.PI / 2; ground.position.y = 0.0; scene.add(ground);

const orbit = new OrbitControls(camera, renderer.domElement);
orbit.target.set(0, 2, 7);
const walk = new PointerLockControls(camera, renderer.domElement);
renderer.domElement.addEventListener('click', () => { if (current) walk.lock(); });
walk.addEventListener('lock', () => { orbit.enabled = false; $('cross').style.display = 'block'; });
walk.addEventListener('unlock', () => { orbit.enabled = true; $('cross').style.display = 'none';
  const f = new THREE.Vector3(); camera.getWorldDirection(f); orbit.target.copy(camera.position).addScaledVector(f, 2); });

const keys = {};
addEventListener('keydown', e => { keys[e.code] = true; });
addEventListener('keyup', e => { keys[e.code] = false; });

function resize() { renderer.setSize(innerWidth, innerHeight); camera.aspect = innerWidth / innerHeight; camera.updateProjectionMatrix(); }
addEventListener('resize', resize); resize();

// ---------------------------------------------------------------- loading
const loader = new GLTFLoader();
let current = null, shell = null, furn = null, box = null;

function prepare(root) {
  const drop = [];
  root.traverse(o => {
    if (/-(?:conv)?colonly$/i.test(o.name || '')) drop.push(o);         // Godot collision-only meshes
    if (o.isMesh) for (const m of [].concat(o.material)) {
      m.side = THREE.DoubleSide;                                         // walls are seen from inside too
      if (m.map) { m.map.magFilter = THREE.NearestFilter; m.map.minFilter = THREE.NearestMipmapNearestFilter; }
    }
    if (o.isLight) o.intensity = 0;                                      // baked house lights are off in the game too
  });
  drop.forEach(o => o.parent && o.parent.remove(o));
  return root;
}

const load = file => new Promise((ok, fail) => loader.load(url($('branch').value.trim(), file), g => ok(prepare(g.scene)), undefined, fail));

async function show() {
  const h = $('house').value;
  $('status').textContent = 'Loading ' + h + '…';
  if (current) scene.remove(current);
  current = new THREE.Group(); scene.add(current);
  try {
    shell = await load(shellName(h));
    current.add(shell);
  } catch (e) { $('status').textContent = 'Could not load the house: ' + (e.message || e); return; }
  try { furn = await load(furnName(h)); current.add(furn); }
  catch (e) { furn = null; }
  box = new THREE.Box3().setFromObject(shell);
  applyToggles();
  const c = box.getCenter(new THREE.Vector3());
  camera.position.set(c.x + 14, 9, box.min.z - 10);
  orbit.target.copy(c); orbit.update();
  $('status').textContent = `${h}: ${(box.max.x - box.min.x).toFixed(1)} × ${(box.max.z - box.min.z).toFixed(1)} m` +
    (furn ? '' : ' (no furnishing file)') + '. Press “Enter house”.';
  history.replaceState(null, '', `?house=${h}&branch=${encodeURIComponent($('branch').value.trim())}`);
}

function applyToggles() {
  if (furn) furn.visible = $('furn').checked;
  if (shell) shell.traverse(o => { if (/_Exterior$/.test(o.name)) o.visible = !$('roof').checked; });
}

function enter() {
  if (!box) return;
  const c = box.getCenter(new THREE.Vector3());
  // just inside the front wall, looking into the house (the street is toward -z)
  camera.position.set(c.x, FLOOR + EYE, Math.max(box.min.z + 2.2, 3.9));
  camera.lookAt(c.x, FLOOR + EYE, c.z + 4);
  walk.lock();
}

$('load').onclick = show;
$('house').onchange = show;
$('enter').onclick = enter;
$('furn').onchange = applyToggles;
$('roof').onchange = applyToggles;

// ---------------------------------------------------------------- loop
const clock = new THREE.Clock();
renderer.setAnimationLoop(() => {
  const dt = Math.min(clock.getDelta(), 0.05);
  if (walk.isLocked) {
    const sp = (keys.ShiftLeft || keys.ShiftRight ? 5 : 2.2) * dt;
    if (keys.KeyW) walk.moveForward(sp);
    if (keys.KeyS) walk.moveForward(-sp);
    if (keys.KeyD) walk.moveRight(sp);
    if (keys.KeyA) walk.moveRight(-sp);
    if (keys.Space) camera.position.y += sp;
    if (keys.KeyC) camera.position.y -= sp;
  } else orbit.update();
  renderer.render(scene, camera);
});

show();
